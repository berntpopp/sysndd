# Read-Only MCP API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a private or bearer-protected read-only MCP sidecar for approved public SysNDD data.

**Architecture:** Start with a mandatory Phase 0 `mcptools` HTTP transport spike and stop if it cannot prove an initialize -> tools/list -> tools/call flow and output shape. If the spike passes, add R repository/service/tool layers that read only approved public views and primary approved reviews, then run MCP in a separate sidecar process using the existing API image. The MCP surface exposes only explicit read-only tools plus static schema resources.

**Tech Stack:** R, testthat, DBI/RMariaDB/pool, jsonlite, memoise, ellmer, mcptools, Docker Compose, Traefik.

---

## File Structure

- Create `api/scripts/mcp-transport-spike.R`: throwaway-but-repeatable protocol probe that installs/loads `mcptools`, starts a minimal HTTP MCP server in a child R process, performs JSON-RPC initialize/list/call requests, records session/header/output behavior, and exits non-zero on unacceptable behavior.
- Create `api/tests/testthat/test-mcp-helpers.R`: TDD coverage for normalization, validation, truncation, error objects, and JSON envelope helpers.
- Create `api/tests/testthat/test-mcp-service.R`: TDD coverage for service shaping using stub repository functions and in-memory rows.
- Create `api/tests/testthat/test-mcp-repository.R`: TDD coverage that repository SQL uses parameterized public-data gates and never calls write helpers.
- Create `api/tests/testthat/test-mcp-tools.R`: TDD coverage for registered tool names, JSON/text output fallback, disabled built-in R session tools, and static resource definitions.
- Create `api/functions/mcp-repository.R`: read-only parameterized SQL helpers over `ndd_entity_view`, `non_alt_loci_set`, primary approved reviews, publication, phenotype, disease, variation, and comparison views.
- Create `api/services/mcp-service.R`: input validation, normalization, shaping, caps, truncation, cache wrappers, stable `schema_version`, and tool error payloads.
- Create `api/services/mcp-tools.R`: `ellmer::tool()` definitions, output serialization selected from spike result, static MCP resources if supported by chosen transport, and a registry that exposes only SysNDD tools.
- Create `api/config/mcp/resources/sysndd-schema.md`: static text for `sysndd://schema/overview` and `sysndd://schema/tool-guide`.
- Create `api/start_sysndd_mcp.R`: MCP sidecar entrypoint that bootstraps libraries/modules/pool/globals, skips migrations and Plumber endpoints, disables built-in R session tools, and starts the MCP server.
- Modify `api/bootstrap/init_libraries.R`: attach `ellmer`/`mcptools` only after the spike chooses `mcptools`, or keep runtime loading inside MCP-specific files if preferable.
- Modify `api/bootstrap/load_modules.R`: include MCP repository/service files in the function/service source order without exposing Plumber endpoints.
- Modify `api/bootstrap/create_pool.R`: allow `MCP_DB_POOL_SIZE` to drive the sidecar pool size while preserving `DB_POOL_SIZE` for the API.
- Modify `docker-compose.yml`: add a separate `mcp` service on backend plus proxy only when protected; mount only needed MCP/API files; set `MCP_DB_POOL_SIZE=2`; use private/internal or static bearer Traefik middleware; add a meaningful health check.
- Modify `docker-compose.override.yml` if needed for local `/mcp` development behind a static local bearer token.
- Modify `Makefile`: add `mcp-transport-spike` and optional local `test-mcp-smoke` targets; keep `make test-api-fast` focused on unit/service coverage if protocol smoke is local-only.
- Modify `api/renv.lock`: add the package source/version proven by the spike (`mcptools` and any direct dependency such as `ellmer` if not already locked).
- Modify `documentation/03-api.qmd`, `documentation/09-deployment.qmd`, `README.md`, and `AGENTS.md`: document read-only scope, private/bearer-protected route, sidecar behavior, public-data gate, deferred parameterized resources, and prohibited providers/actions.

---

### Task 0: Phase 0 MCP Transport Spike Gate

**Files:**
- Create: `api/scripts/mcp-transport-spike.R`
- Modify: `Makefile`
- Potentially modify after pass: `api/renv.lock`

- [ ] **Step 1: Write the spike script before production MCP files**

Create `api/scripts/mcp-transport-spike.R` with a minimal SysNDD-flavored `get_sysndd_stats` tool and an HTTP JSON-RPC probe. The child server must return JSON-serialized text unless native structured content is proven.

```r
#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
port <- as.integer(Sys.getenv("MCP_SPIKE_PORT", "8797"))
host <- "127.0.0.1"
endpoint <- sprintf("http://%s:%d/mcp", host, port)

required <- c("ellmer", "mcptools", "httr2", "jsonlite", "callr")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0L) {
  stop("Missing required packages for MCP spike: ", paste(missing, collapse = ", "))
}

server_file <- tempfile("sysndd-mcp-spike-", fileext = ".R")
writeLines(c(
  "library(ellmer)",
  "library(mcptools)",
  "library(jsonlite)",
  "tool <- ellmer::tool(function() {",
  "  jsonlite::toJSON(list(schema_version = '1.0', entity_count = 0L), auto_unbox = TRUE)",
  "}, name = 'get_sysndd_stats', description = 'Return a tiny read-only SysNDD stats payload')",
  sprintf("mcptools::mcp_server(tools = list(tool), transport = mcptools::transport_http(host = '127.0.0.1', port = %d, path = '/mcp'))", port)
), server_file)

proc <- callr::r_bg(function(path) source(path), args = list(server_file), supervise = TRUE)
on.exit({
  if (proc$is_alive()) proc$kill()
  unlink(server_file)
}, add = TRUE)

deadline <- Sys.time() + 15
ready <- FALSE
while (Sys.time() < deadline && !ready) {
  Sys.sleep(0.25)
  ready <- tryCatch({
    req <- httr2::request(endpoint) |>
      httr2::req_method("GET") |>
      httr2::req_timeout(2)
    resp <- httr2::req_perform(req)
    httr2::resp_status(resp) %in% c(200L, 405L)
  }, error = function(e) FALSE)
}
if (!ready) stop("MCP spike server did not become reachable")

rpc <- function(method, params = NULL, id = 1L, extra_headers = list()) {
  body <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) body$params <- params
  req <- httr2::request(endpoint) |>
    httr2::req_headers(`Content-Type` = "application/json", `MCP-Protocol-Version` = "2025-11-25") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(5)
  for (nm in names(extra_headers)) req <- httr2::req_headers(req, !!nm := extra_headers[[nm]])
  resp <- httr2::req_perform(req)
  list(
    status = httr2::resp_status(resp),
    headers = httr2::resp_headers(resp),
    body = jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
  )
}

init <- rpc("initialize", list(
  protocolVersion = "2025-11-25",
  capabilities = list(),
  clientInfo = list(name = "sysndd-spike", version = "0.1.0")
), 1L)
if (init$status >= 400L || is.null(init$body$result)) stop("initialize failed")
session_id <- init$headers[["mcp-session-id"]]

headers <- if (!is.null(session_id)) list(`MCP-Session-Id` = session_id) else list()
listed <- rpc("tools/list", id = 2L, extra_headers = headers)
tools <- listed$body$result$tools %||% list()
tool_names <- vapply(tools, function(x) x$name %||% "", character(1))
if (!"get_sysndd_stats" %in% tool_names) stop("tools/list did not expose get_sysndd_stats")

called <- rpc("tools/call", list(name = "get_sysndd_stats", arguments = list()), 3L, headers)
if (called$status >= 400L || is.null(called$body$result)) stop("tools/call failed")

get_resp <- httr2::request(endpoint) |> httr2::req_method("GET") |> httr2::req_perform()
get_status <- httr2::resp_status(get_resp)
if (!get_status %in% c(200L, 405L)) stop("GET returned unexpected status: ", get_status)

result <- called$body$result
has_structured <- !is.null(result$structuredContent)
has_text_json <- any(vapply(result$content %||% list(), function(item) {
  identical(item$type, "text") && grepl("^\\s*\\{", item$text %||% "")
}, logical(1)))
if (!has_structured && !has_text_json) stop("Tool output is neither structuredContent nor JSON text")

cat(jsonlite::toJSON(list(
  ok = TRUE,
  mcptools_version = as.character(utils::packageVersion("mcptools")),
  session_header_issued = !is.null(session_id),
  get_status = get_status,
  output_mode = if (has_structured) "structuredContent" else "json_text"
), auto_unbox = TRUE, pretty = TRUE))
cat("\n")
```

- [ ] **Step 2: Add the Makefile target**

Add:

```make
.PHONY: mcp-transport-spike
mcp-transport-spike:
	cd api && Rscript scripts/mcp-transport-spike.R
```

- [ ] **Step 3: Run the spike and record the result**

Run: `make mcp-transport-spike`

Expected:
- PASS with JSON including `ok: true`, `mcptools_version`, `get_status` of `200` or `405`, session behavior, and `output_mode`.
- If packages are missing, install/add them through `renv` first, then rerun.
- If HTTP initialize/list/call cannot be proven, stop production implementation and update the plan/spec outcome instead of adding production MCP files.

- [ ] **Step 4: Commit the spike gate**

```bash
git add api/scripts/mcp-transport-spike.R Makefile api/renv.lock
git commit -m "test: add MCP transport spike gate"
```

### Task 1: MCP Helpers and Service Contracts

**Files:**
- Create: `api/tests/testthat/test-mcp-helpers.R`
- Create: `api/services/mcp-service.R`
- Modify: `api/bootstrap/load_modules.R`

- [ ] **Step 1: Write failing helper tests**

```r
test_that("MCP identifier helpers normalize supported gene and PMID inputs", {
  source("services/mcp-service.R")
  expect_equal(mcp_normalize_gene_input("HGNC:1234"), list(kind = "hgnc_id", value = 1234L))
  expect_equal(mcp_normalize_gene_input("1234"), list(kind = "hgnc_id", value = 1234L))
  expect_equal(mcp_normalize_gene_input("MECP2"), list(kind = "symbol", value = "MECP2"))
  expect_equal(mcp_normalize_pmid("https://pubmed.ncbi.nlm.nih.gov/12345678/"), "12345678")
  expect_error(mcp_validate_limit(51, max = 50), class = "mcp_tool_error")
})

test_that("MCP envelopes include schema version and truncation metadata", {
  source("services/mcp-service.R")
  truncated <- mcp_truncate_text(paste(rep("x", 20), collapse = ""), 10)
  expect_true(truncated$truncated)
  expect_equal(nchar(truncated$text), 10)
  err <- mcp_error("invalid_input", "Bad input", fields = list(argument = "query"))
  expect_equal(err$schema_version, "1.0")
  expect_equal(err$error$code, "invalid_input")
})
```

- [ ] **Step 2: Run and verify RED**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-helpers.R')"`

Expected: FAIL because `services/mcp-service.R` does not exist or helper functions are undefined.

- [ ] **Step 3: Implement minimal helpers**

Add functions in `api/services/mcp-service.R`:

```r
MCP_SCHEMA_VERSION <- "1.0"

mcp_error <- function(code, message, fields = list()) {
  structure(
    list(schema_version = MCP_SCHEMA_VERSION, error = c(list(code = code, message = message), fields)),
    class = c("mcp_tool_error", "error", "condition")
  )
}

mcp_validate_limit <- function(limit, default = 25L, max = 50L, name = "limit") {
  if (is.null(limit)) limit <- default
  limit <- suppressWarnings(as.integer(limit))
  if (is.na(limit) || limit < 1L || limit > max) {
    stop(mcp_error("invalid_input", sprintf("%s must be between 1 and %d", name, max), list(argument = name)))
  }
  limit
}

mcp_validate_offset <- function(offset) {
  offset <- if (is.null(offset)) 0L else suppressWarnings(as.integer(offset))
  if (is.na(offset) || offset < 0L) {
    stop(mcp_error("invalid_input", "offset must be a non-negative integer", list(argument = "offset")))
  }
  offset
}

mcp_normalize_gene_input <- function(gene) {
  gene <- trimws(as.character(gene)[1])
  if (!nzchar(gene) || nchar(gene) > 100L) {
    stop(mcp_error("invalid_input", "gene must be a non-empty string up to 100 characters", list(argument = "gene")))
  }
  hgnc <- sub("^HGNC:", "", toupper(gene))
  if (grepl("^[0-9]+$", hgnc)) return(list(kind = "hgnc_id", value = as.integer(hgnc)))
  list(kind = "symbol", value = toupper(gene))
}

mcp_normalize_pmid <- function(pmid) {
  value <- trimws(as.character(pmid)[1])
  match <- regmatches(value, regexpr("[0-9]{1,9}", value))
  if (!nzchar(match)) {
    stop(mcp_error("invalid_input", "pmid must contain a PubMed identifier", list(argument = "pmid")))
  }
  match
}

mcp_truncate_text <- function(text, max_chars) {
  text <- if (is.null(text) || is.na(text)) "" else as.character(text)
  max_chars <- as.integer(max_chars)
  truncated <- nchar(text) > max_chars
  list(text = substr(text, 1L, max_chars), truncated = truncated, max_chars = max_chars)
}
```

- [ ] **Step 4: Wire service file into bootstrap after the spike passes**

Add `services/mcp-service.R` to `service_files` in `api/bootstrap/load_modules.R` after existing public services.

- [ ] **Step 5: Run and verify GREEN**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-helpers.R')"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/tests/testthat/test-mcp-helpers.R api/services/mcp-service.R api/bootstrap/load_modules.R
git commit -m "feat: add MCP service helpers"
```

### Task 2: Read-Only Repository Public-Data Gate

**Files:**
- Create: `api/tests/testthat/test-mcp-repository.R`
- Create: `api/functions/mcp-repository.R`
- Modify: `api/bootstrap/load_modules.R`

- [ ] **Step 1: Write failing repository tests**

```r
test_that("MCP repository queries use approved public views and primary approved review gates", {
  source("functions/mcp-repository.R")
  captured <- list()
  with_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      captured[[length(captured) + 1L]] <<- list(sql = sql, params = params)
      tibble::tibble()
    },
    {
      mcp_repo_get_entity_context(123L)
      mcp_repo_get_gene_entities(1L, limit = 10L, offset = 0L)
      mcp_repo_get_publication_context("123456")
    }
  )
  sql <- paste(vapply(captured, `[[`, character(1), "sql"), collapse = "\n")
  expect_match(sql, "ndd_entity_view")
  expect_match(sql, "is_primary\\s*=\\s*1")
  expect_match(sql, "review_approved\\s*=\\s*1")
  expect_false(grepl("INSERT|UPDATE|DELETE|DROP|ALTER", sql, ignore.case = TRUE))
  expect_true(all(vapply(captured, function(x) is.list(x$params), logical(1))))
})
```

- [ ] **Step 2: Run and verify RED**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-repository.R')"`

Expected: FAIL because repository functions are undefined.

- [ ] **Step 3: Implement read-only repository helpers**

Implement only `SELECT` helpers using `db_execute_query()` with `?` placeholders:

```r
mcp_repo_resolve_gene <- function(normalized_gene) { ... }
mcp_repo_search <- function(query, types, limit) { ... }
mcp_repo_get_gene_entities <- function(hgnc_id, category = NULL, ndd_phenotype = "any", limit = 25L, offset = 0L) { ... }
mcp_repo_get_gene_comparisons <- function(hgnc_id, limit = 25L) { ... }
mcp_repo_get_entity_context <- function(entity_id) { ... }
mcp_repo_get_entity_phenotypes <- function(entity_id) { ... }
mcp_repo_get_entity_variation <- function(entity_id) { ... }
mcp_repo_get_entity_publications <- function(entity_id, limit = 10L) { ... }
mcp_repo_get_publication_context <- function(pmid) { ... }
mcp_repo_find_entities_by_phenotype <- function(phenotype, modifier, category, limit, offset) { ... }
mcp_repo_find_entities_by_disease <- function(disease, limit, offset) { ... }
mcp_repo_get_stats <- function() { ... }
```

Every review-derived query must join through `ndd_entity_view` and require:

```sql
ner.is_primary = 1
AND ner.review_approved = 1
```

- [ ] **Step 4: Wire repository file into bootstrap**

Add `functions/mcp-repository.R` to `function_files` after existing public repositories and before services.

- [ ] **Step 5: Run repository tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-repository.R')"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/tests/testthat/test-mcp-repository.R api/functions/mcp-repository.R api/bootstrap/load_modules.R
git commit -m "feat: add read-only MCP repository"
```

### Task 3: MCP Tool Service Shaping and Caching

**Files:**
- Create: `api/tests/testthat/test-mcp-service.R`
- Modify: `api/services/mcp-service.R`

- [ ] **Step 1: Write failing service tests**

```r
test_that("get_gene_context shapes compact public gene payloads", {
  source("services/mcp-service.R")
  with_mocked_bindings(
    mcp_repo_resolve_gene = function(normalized_gene) tibble::tibble(hgnc_id = 1L, symbol = "MECP2", name = "methyl-CpG binding protein 2"),
    mcp_repo_get_gene_entities = function(...) tibble::tibble(entity_id = 10L, symbol = "MECP2", hgnc_id = 1L, disease_ontology_id_version = "MONDO:1", disease_ontology_name = "Rett syndrome", hpo_mode_of_inheritance_term_name = "X-linked dominant", category = "Definitive", ndd_phenotype_word = "yes", synopsis = paste(rep("A", 2000), collapse = "")),
    mcp_repo_get_gene_comparisons = function(...) tibble::tibble(source = "OMIM", present = 1L),
    {
      result <- mcp_get_gene_context("MECP2")
    }
  )
  expect_equal(result$schema_version, "1.0")
  expect_equal(result$gene$symbol, "MECP2")
  expect_true(result$entities[[1]]$synopsis_truncated)
  expect_less_than_or_equal(nchar(result$entities[[1]]$synopsis_excerpt), 1500)
})

test_that("entity context respects include flags and caps publication limits", {
  source("services/mcp-service.R")
  with_mocked_bindings(
    mcp_repo_get_entity_context = function(entity_id) tibble::tibble(entity_id = entity_id, symbol = "MECP2", hgnc_id = 1L, category = "Definitive", status = "active", synopsis = "Public synopsis", review_date = as.Date("2025-01-01")),
    mcp_repo_get_entity_phenotypes = function(...) stop("phenotypes should not be called"),
    mcp_repo_get_entity_variation = function(...) tibble::tibble(),
    mcp_repo_get_entity_publications = function(entity_id, limit) tibble::tibble(publication_id = "1", title = "Paper"),
    {
      result <- mcp_get_entity_context(10L, include_phenotypes = FALSE, publication_limit = 25L)
    }
  )
  expect_equal(result$entity$entity_id, 10L)
  expect_equal(result$phenotypes, list())
})
```

- [ ] **Step 2: Run and verify RED**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`

Expected: FAIL because shaping functions are undefined/incomplete.

- [ ] **Step 3: Implement service tools**

Implement:

```r
mcp_search_sysndd <- function(query, types = NULL, limit = 10L) { ... }
mcp_get_gene_context <- function(gene, include_entities = TRUE, include_comparisons = TRUE, entity_limit = 10L) { ... }
mcp_get_entity_context <- function(entity_id, include_publications = TRUE, include_phenotypes = TRUE, include_variants = TRUE, publication_limit = 10L) { ... }
mcp_list_gene_entities <- function(gene, category = NULL, ndd_phenotype = "any", limit = 25L, offset = 0L) { ... }
mcp_get_publication_context <- function(pmid, abstract_max_chars = 2000L) { ... }
mcp_find_entities_by_phenotype <- function(phenotype, modifier = "present", category = "Definitive", limit = 25L, offset = 0L) { ... }
mcp_find_entities_by_disease <- function(disease, limit = 25L, offset = 0L) { ... }
mcp_get_sysndd_stats <- function() { ... }
```

Each result must include:

```r
list(schema_version = MCP_SCHEMA_VERSION, ...)
```

Use `memoise::memoise()` or a small local cache wrapper for successful results only, with TTLs:

```r
MCP_CACHE_TTLS <- list(
  get_sysndd_stats = 300L,
  search_sysndd = 60L,
  get_gene_context = 300L,
  get_entity_context = 300L,
  get_publication_context = 1800L
)
```

- [ ] **Step 4: Run service tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/tests/testthat/test-mcp-service.R api/services/mcp-service.R
git commit -m "feat: shape MCP read-only context tools"
```

### Task 4: MCP Tool Registry, Static Resources, and Entrypoint

**Files:**
- Create: `api/tests/testthat/test-mcp-tools.R`
- Create: `api/services/mcp-tools.R`
- Create: `api/config/mcp/resources/sysndd-schema.md`
- Create: `api/start_sysndd_mcp.R`
- Modify: `api/bootstrap/load_modules.R`

- [ ] **Step 1: Write failing tool registry tests**

```r
test_that("MCP registry exposes only approved SysNDD tools", {
  source("services/mcp-service.R")
  source("services/mcp-tools.R")
  registry <- mcp_build_tool_registry(output_mode = "json_text")
  names <- vapply(registry$tools, function(x) x@name %||% x$name %||% "", character(1))
  expect_setequal(names, c(
    "search_sysndd", "get_gene_context", "get_entity_context",
    "list_gene_entities", "get_publication_context",
    "find_entities_by_phenotype", "find_entities_by_disease",
    "get_sysndd_stats"
  ))
  expect_false(any(grepl("R|session|code|sql", names, ignore.case = TRUE)))
  expect_true(any(vapply(registry$resources, function(x) identical(x$uri, "sysndd://schema/overview"), logical(1))))
})
```

- [ ] **Step 2: Run and verify RED**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`

Expected: FAIL because registry does not exist.

- [ ] **Step 3: Implement registry and static resources**

Implement a registry that wraps service functions with `ellmer::tool()` and serializes output according to the spike result:

```r
mcp_serialize_result <- function(value, output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  if (identical(output_mode, "structuredContent")) return(value)
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", na = "null")
}

mcp_tool_safe <- function(fn) {
  force(fn)
  function(...) {
    tryCatch(
      mcp_serialize_result(fn(...)),
      mcp_tool_error = function(e) mcp_serialize_result(unclass(e)),
      error = function(e) mcp_serialize_result(mcp_error("temporarily_unavailable", "MCP tool failed"))
    )
  }
}

mcp_build_tool_registry <- function(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text")) {
  tools <- list(
    ellmer::tool(mcp_tool_safe(mcp_search_sysndd), name = "search_sysndd", description = "Search approved public SysNDD genes, entities, diseases, phenotypes, and variants."),
    ellmer::tool(mcp_tool_safe(mcp_get_gene_context), name = "get_gene_context", description = "Get compact approved public context for a SysNDD gene."),
    ellmer::tool(mcp_tool_safe(mcp_get_entity_context), name = "get_entity_context", description = "Get compact approved public context for a SysNDD entity."),
    ellmer::tool(mcp_tool_safe(mcp_list_gene_entities), name = "list_gene_entities", description = "List approved public SysNDD entities for one gene."),
    ellmer::tool(mcp_tool_safe(mcp_get_publication_context), name = "get_publication_context", description = "Get publication metadata linked to approved primary reviews."),
    ellmer::tool(mcp_tool_safe(mcp_find_entities_by_phenotype), name = "find_entities_by_phenotype", description = "Find approved public entities associated with HPO phenotype terms."),
    ellmer::tool(mcp_tool_safe(mcp_find_entities_by_disease), name = "find_entities_by_disease", description = "Find approved public entities by disease ontology identifier or name."),
    ellmer::tool(mcp_tool_safe(mcp_get_sysndd_stats), name = "get_sysndd_stats", description = "Get capped aggregate SysNDD public counts.")
  )
  list(tools = tools, resources = mcp_static_resources())
}
```

Create `api/config/mcp/resources/sysndd-schema.md` with two sections:

```markdown
# sysndd://schema/overview

SysNDD represents approved public gene-disease-inheritance entities for neurodevelopmental disorder curation. An entity joins a gene, disease ontology term, inheritance term, NDD phenotype flag, public category/status, primary approved review synopsis, HPO phenotype terms, variation ontology terms, and linked publications.

# sysndd://schema/tool-guide

Use search_sysndd for routing. Use get_gene_context for gene summaries. Use get_entity_context for curated entity summaries. Use get_publication_context for PubMed citation context. Use find_entities_by_phenotype or find_entities_by_disease for constrained discovery.
```

- [ ] **Step 4: Implement sidecar entrypoint**

`api/start_sysndd_mcp.R` must:

```r
source("bootstrap/init_libraries.R", local = FALSE)
source("bootstrap/load_modules.R", local = FALSE)
source("bootstrap/create_pool.R", local = FALSE)
source("bootstrap/init_globals.R", local = FALSE)

bootstrap_init_libraries()
env_mode <- Sys.getenv("ENVIRONMENT", "local")
Sys.setenv(API_CONFIG = if (tolower(env_mode) == "production") "sysndd_db" else if (tolower(env_mode) == "development") "sysndd_db_dev" else "sysndd_db_local")
dw <- config::get(Sys.getenv("API_CONFIG"))
if (!is.null(dw$workdir)) setwd(dw$workdir)

bootstrap_load_modules()
Sys.setenv(DB_POOL_SIZE = Sys.getenv("MCP_DB_POOL_SIZE", "2"))
pool <- bootstrap_create_pool(dw)
globals <- bootstrap_init_globals()

registry <- mcp_build_tool_registry(output_mode = Sys.getenv("MCP_OUTPUT_MODE", "json_text"))
mcptools::mcp_server(
  tools = registry$tools,
  transport = mcptools::transport_http(
    host = Sys.getenv("MCP_HOST", "0.0.0.0"),
    port = as.integer(Sys.getenv("MCP_PORT", "8787")),
    path = Sys.getenv("MCP_PATH", "/mcp")
  )
)
```

Do not call migrations, worker setup, Plumber endpoint mounting, Gemini, or external provider helpers.

- [ ] **Step 5: Run tool tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/tests/testthat/test-mcp-tools.R api/services/mcp-tools.R api/config/mcp/resources/sysndd-schema.md api/start_sysndd_mcp.R api/bootstrap/load_modules.R
git commit -m "feat: add MCP tool registry and sidecar entrypoint"
```

### Task 5: Sidecar Compose, Private/Bearer Route, and Smoke Probe

**Files:**
- Modify: `docker-compose.yml`
- Modify: `docker-compose.override.yml`
- Modify: `Makefile`
- Create: `api/scripts/mcp-smoke.R`

- [ ] **Step 1: Write smoke probe**

Create `api/scripts/mcp-smoke.R` that sends initialize and tools/list to `MCP_URL`, adding `Authorization: Bearer $MCP_BEARER_TOKEN` when set, and exits non-zero if approved tool names are missing.

- [ ] **Step 2: Add sidecar service**

Add `mcp` service:

```yaml
mcp:
  build:
    context: ./api/
    args:
      UID: ${HOST_UID:-1000}
      GID: ${HOST_GID:-1000}
  command: ["Rscript", "start_sysndd_mcp.R"]
  restart: unless-stopped
  security_opt:
    - no-new-privileges:true
  volumes:
    - ./api/functions:/app/functions:ro
    - ./api/services:/app/services:ro
    - ./api/bootstrap:/app/bootstrap:ro
    - ./api/config:/app/config:ro
    - ./api/config.yml:/app/config.yml:ro
    - ./api/version_spec.json:/app/version_spec.json:ro
    - ./api/start_sysndd_mcp.R:/app/start_sysndd_mcp.R:ro
  environment:
    ENVIRONMENT: production
    DB_POOL_SIZE: ${MCP_DB_POOL_SIZE:-2}
    MCP_DB_POOL_SIZE: ${MCP_DB_POOL_SIZE:-2}
    MCP_PORT: 8787
    MCP_PATH: /mcp
    MCP_OUTPUT_MODE: ${MCP_OUTPUT_MODE:-json_text}
  networks:
    - backend
    - proxy
  depends_on:
    mysql:
      condition: service_healthy
  healthcheck:
    test: ["CMD", "Rscript", "scripts/mcp-smoke.R"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

Default exposure must be private/internal or bearer-protected. If Traefik exposes `/mcp`, add a bearer middleware or document that it is not public by default.

- [ ] **Step 3: Add local smoke target**

```make
.PHONY: test-mcp-smoke
test-mcp-smoke:
	cd api && MCP_URL=$${MCP_URL:-http://localhost:8787/mcp} Rscript scripts/mcp-smoke.R
```

- [ ] **Step 4: Run compose config validation**

Run: `docker compose config --quiet`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml docker-compose.override.yml Makefile api/scripts/mcp-smoke.R
git commit -m "feat: run MCP as protected sidecar"
```

### Task 6: Documentation and Agent Guardrails

**Files:**
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Update API documentation**

Document:
- `/mcp` is v1 private/internal or static-bearer protected.
- Tools are read-only and limited to approved public data from `ndd_entity_view` and primary approved reviews.
- V1 resources are static schema resources only.
- Tool output is `structuredContent` only if proven; otherwise stable JSON text with `schema_version`.

- [ ] **Step 2: Update deployment docs**

Document:
- `mcp` sidecar process/container and separate DB pool.
- `MCP_DB_POOL_SIZE`, `MCP_PORT`, `MCP_PATH`, `MCP_OUTPUT_MODE`, optional bearer token/proxy config.
- Health check behavior and local smoke command.
- No public unauthenticated exposure by default.

- [ ] **Step 3: Update README and AGENTS.md**

Add durable guardrails:
- MCP must remain separate from Plumber.
- MCP tools must not write DB, call Gemini, call external providers, execute raw SQL/R, or expose draft/review/admin/user/log/job data.
- New MCP tools must enforce active approved public entity data and primary approved reviews.

- [ ] **Step 4: Commit**

```bash
git add documentation/03-api.qmd documentation/09-deployment.qmd README.md AGENTS.md
git commit -m "docs: document read-only MCP sidecar"
```

### Task 7: Final Verification

**Files:**
- No new files unless fixing discovered issues.

- [ ] **Step 1: Run focused MCP tests**

Run:

```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-helpers.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-repository.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
make mcp-transport-spike
docker compose config --quiet
```

Expected: PASS.

- [ ] **Step 2: Run repo API checks**

Run:

```bash
make test-api-fast
make lint-api
```

Expected: PASS.

- [ ] **Step 3: Run broader handoff check if time allows**

Run: `make pre-commit`

Expected: PASS.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git status --short
git diff --stat
git diff --check
```

Expected: only planned files changed, no whitespace errors.

---

## Self-Review

- Spec coverage: The plan starts with the required transport spike, gates production files on an explicit pass/fail result, keeps MCP separate from Plumber, defaults to private/bearer-protected access, limits v1 resources to static schema resources, enforces approved public data through `ndd_entity_view` and primary approved reviews, adds capped JSON-compatible outputs with `schema_version`, prohibits DB writes/external providers/Gemini/raw SQL/R execution, adds caching, and updates docs.
- Placeholder scan: The repository/service steps intentionally use ellipses only where the exact SQL depends on verified local schema columns during implementation; each task still defines concrete function names, contracts, gates, commands, and expected outcomes. Before coding those helpers, inspect the actual table columns with existing migrations/schema and replace ellipses in implementation with explicit SQL.
- Type consistency: Tool and service names match across tests, services, registry, docs, and smoke checks.
