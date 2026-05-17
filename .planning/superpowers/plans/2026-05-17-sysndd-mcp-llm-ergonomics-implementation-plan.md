# SysNDD MCP LLM Ergonomics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise the SysNDD MCP server to a >9/10 LLM-consumer experience by fixing validation false negatives/crashes, aligning advertised MCP capabilities with implemented methods, adding schemas/read-only metadata, and improving cross-tool navigation and batching.

**Architecture:** Keep the existing read-only R MCP sidecar and public-data repository gate. Add small service-layer helpers for validation and entity decoration, plus a SysNDD MCP compatibility shim around `mcptools` for resources, tool metadata, tool-visible errors, and optional structured output. Preserve JSON text as the default result mode.

**Tech Stack:** R, `testthat`, `ellmer`, `mcptools`, `jsonlite`, `httr2`, Docker Compose, MySQL-backed SysNDD public views.

---

## File Map

- Modify `api/services/mcp-service.R`: validation helpers, PMID normalization, category validation, entity row decoration, search metadata, `get_entities_context`.
- Modify `api/services/mcp-tools.R`: tool wrappers, unknown-argument handling, `symbol` alias, tool metadata output schemas, read-only annotations, static resource request shim.
- Modify `api/scripts/mcp-smoke.R`: wire checks for resources, metadata, malformed PMID, category validation, and alias behavior.
- Modify `api/config/mcp/resources/sysndd-schema.md`: update tool guide for batch entity lookup and static-resource contract.
- Modify `api/tests/testthat/test-mcp-helpers.R`: helper tests for PMID/category/error serialization.
- Modify `api/tests/testthat/test-mcp-service.R`: service tests for false-negative fixes, entity decoration, search metadata, and batch entities.
- Modify `api/tests/testthat/test-mcp-tools.R`: registry/shim tests for tool metadata, resources, alias/unknown args, structured output.
- Modify `documentation/03-api.qmd`, `documentation/09-deployment.qmd`, and `AGENTS.md`: durable docs for the improved MCP contract.

## Task 1: Service Validation And Entity Decoration

**Files:**
- Modify: `api/services/mcp-service.R`
- Test: `api/tests/testthat/test-mcp-helpers.R`
- Test: `api/tests/testthat/test-mcp-service.R`

- [ ] **Step 1: Write failing helper tests for PMID and category validation**

Add these tests to `api/tests/testthat/test-mcp-helpers.R`:

```r
test_that("PMID normalization rejects malformed identifiers with a stable MCP error", {
  source("../../services/mcp-service.R")

  expect_equal(mcp_normalize_pmid("12345678"), "PMID:12345678")
  expect_equal(mcp_normalize_pmid("PMID:12345678"), "PMID:12345678")
  expect_equal(mcp_normalize_pmid("https://pubmed.ncbi.nlm.nih.gov/12345678/"), "PMID:12345678")

  expect_error(
    mcp_normalize_pmid("notapmid"),
    class = "mcp_tool_error"
  )

  err <- tryCatch(mcp_normalize_pmid("notapmid"), mcp_tool_error = function(e) unclass(e))
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "pmid")
})

test_that("MCP category validation rejects unsupported public categories", {
  source("../../services/mcp-service.R")

  expect_equal(mcp_validate_category(NULL), NULL)
  expect_equal(mcp_validate_category("Definitive"), "Definitive")

  err <- tryCatch(mcp_validate_category("BogusCategory"), mcp_tool_error = function(e) unclass(e))
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "category")
  expect_true("Definitive" %in% err$error$allowed_values)
})
```

- [ ] **Step 2: Write failing service tests for entity decoration and phenotype category rejection**

Append to `api/tests/testthat/test-mcp-service.R`:

```r
test_that("find_entities_by_phenotype rejects invalid category instead of returning a false negative", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  err <- tryCatch(
    mcp_find_entities_by_phenotype("HP:0001250", category = "BogusCategory"),
    mcp_tool_error = function(e) unclass(e)
  )

  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "category")
})

test_that("list and find entity rows include resource URIs and suggested tools", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  rows <- tibble::tibble(
    entity_id = 10L,
    symbol = "MECP2",
    hgnc_id = "HGNC:6990",
    disease_ontology_id_version = "MONDO:1",
    disease_ontology_name = "Rett syndrome",
    hpo_mode_of_inheritance_term_name = "X-linked dominant",
    category = "Definitive",
    ndd_phenotype_word = "Yes"
  )

  decorated <- mcp_decorate_entity_records(rows)

  expect_equal(decorated[[1]]$resource_uri, "sysndd://entity/10")
  expect_equal(decorated[[1]]$suggested_tools, list("get_entity_context", "get_entities_context"))
})
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-helpers.R'); testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected: failures mention missing `mcp_validate_category`, missing `mcp_decorate_entity_records`, malformed PMID handling, and invalid category not rejected.

- [ ] **Step 4: Implement validation and entity decoration**

In `api/services/mcp-service.R`:

```r
MCP_ALLOWED_ENTITY_CATEGORIES <- c("Definitive", "Moderate", "Limited", "Refuted")
```

Add:

```r
mcp_validate_category <- function(category, argument = "category") {
  if (is.null(category) || !nzchar(trimws(as.character(category)[1]))) return(NULL)
  value <- as.character(category)[1]
  if (!value %in% MCP_ALLOWED_ENTITY_CATEGORIES) {
    stop(mcp_error(
      "invalid_input",
      sprintf("%s must be one of: %s", argument, paste(MCP_ALLOWED_ENTITY_CATEGORIES, collapse = ", ")),
      list(argument = argument, allowed_values = as.list(MCP_ALLOWED_ENTITY_CATEGORIES))
    ))
  }
  value
}

mcp_decorate_entity_records <- function(rows) {
  lapply(mcp_rows_to_records(rows), function(item) {
    c(item, list(
      resource_uri = mcp_resource_uri("entity", item$entity_id),
      suggested_tools = list("get_entity_context", "get_entities_context")
    ))
  })
}
```

Replace `mcp_normalize_pmid()` with an implementation that uses `regexpr(..., perl = TRUE)`, checks for `-1L`, and stops with `mcp_error("invalid_input", ...)` before any repository call.

Use `mcp_validate_category()` in `mcp_list_gene_entities()` and `mcp_find_entities_by_phenotype()`. Use `mcp_decorate_entity_records()` in `mcp_list_gene_entities()`, `mcp_find_entities_by_phenotype()`, and `mcp_find_entities_by_disease()`.

- [ ] **Step 5: Run tests and verify they pass**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-helpers.R'); testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected: all MCP helper/service tests pass.

- [ ] **Step 6: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-helpers.R api/tests/testthat/test-mcp-service.R
git commit -m "fix: harden MCP validation and entity navigation"
```

## Task 2: Search Metadata And Batch Entity Context

**Files:**
- Modify: `api/services/mcp-service.R`
- Test: `api/tests/testthat/test-mcp-service.R`

- [ ] **Step 1: Write failing tests for unified search meta and batch entities**

Append to `api/tests/testthat/test-mcp-service.R`:

```r
test_that("search_sysndd reports returned count and has_more metadata", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_search <- mcp_repo_search
  assign("mcp_repo_search", function(query, types, limit) {
    tibble::tibble(
      type = rep("gene", 3),
      id = c("SCN1A", "SCN1B", "SCN2A"),
      label = c("SCN1A", "SCN1B", "SCN2A"),
      description = c("one", "two", "three"),
      match_tier = c("exact_identifier", "contains", "contains")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_repo_search", old_search, envir = .GlobalEnv))

  result <- mcp_search_sysndd("SCN", types = c("gene"), limit = 2L)

  expect_equal(length(result$matches), 2L)
  expect_equal(result$meta$limit, 2L)
  expect_equal(result$meta$offset, 0L)
  expect_equal(result$meta$returned, 2L)
  expect_equal(result$meta$total, 3L)
  expect_true(result$meta$has_more)
})

test_that("batch entity context preserves order and returns per-entity errors", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")

  old_context <- mcp_repo_get_entity_context
  old_phenotypes <- mcp_repo_get_entity_phenotypes
  old_variation <- mcp_repo_get_entity_variation
  old_publications <- mcp_repo_get_entity_publications
  assign("mcp_repo_get_entity_context", function(entity_id) {
    if (identical(entity_id, 999L)) return(tibble::tibble())
    tibble::tibble(
      entity_id = entity_id,
      symbol = "SCN1A",
      hgnc_id = "HGNC:10585",
      category = "Definitive",
      synopsis = "Public synopsis",
      review_date = as.Date("2025-01-01")
    )
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_entity_phenotypes", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_variation", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_entity_publications", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_get_entity_context", old_context, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_phenotypes", old_phenotypes, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_variation", old_variation, envir = .GlobalEnv)
    assign("mcp_repo_get_entity_publications", old_publications, envir = .GlobalEnv)
  })

  result <- mcp_get_entities_context(c(10L, 999L, 11L), include_publications = FALSE)

  expect_equal(result$meta$requested, 3L)
  expect_equal(result$meta$returned, 2L)
  expect_equal(result$meta$errors, 1L)
  expect_equal(result$entities[[1]]$entity$entity_id, 10L)
  expect_equal(result$entities[[2]]$entity_id, 999L)
  expect_equal(result$entities[[2]]$error$code, "not_found")
  expect_equal(result$entities[[3]]$entity$entity_id, 11L)
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected: failures for missing `mcp_get_entities_context` and old search metadata.

- [ ] **Step 3: Implement search metadata and batch entity context**

In `mcp_search_sysndd()`, request `limit + 1L` from the repository, keep only the first `limit` records, and return:

```r
meta = list(
  limit = limit,
  offset = 0L,
  returned = length(records),
  total = nrow(rows),
  has_more = nrow(rows) > limit
)
```

Add `mcp_get_entities_context()`:

```r
mcp_get_entities_context <- function(entity_ids,
                                     include_publications = TRUE,
                                     include_phenotypes = TRUE,
                                     include_variants = TRUE,
                                     publication_limit = 10L) {
  if (is.null(entity_ids)) {
    stop(mcp_error("invalid_input", "entity_ids must contain at least one entity ID", list(argument = "entity_ids")))
  }
  ids <- suppressWarnings(as.integer(unlist(entity_ids, use.names = FALSE)))
  if (length(ids) == 0L || any(is.na(ids)) || any(ids < 1L)) {
    stop(mcp_error("invalid_input", "entity_ids must be positive integers", list(argument = "entity_ids")))
  }
  if (length(ids) > 20L) {
    stop(mcp_error("invalid_input", "entity_ids supports at most 20 IDs per call", list(argument = "entity_ids", max = 20L)))
  }
  publication_limit <- mcp_validate_limit(publication_limit, default = 10L, max = 25L, name = "publication_limit")
  entities <- lapply(ids, function(entity_id) {
    tryCatch(
      mcp_get_entity_context(entity_id, include_publications, include_phenotypes, include_variants, publication_limit),
      mcp_tool_error = function(e) list(entity_id = entity_id, error = unclass(e)$error)
    )
  })
  returned <- sum(vapply(entities, function(item) is.null(item$error), logical(1)))
  list(
    schema_version = MCP_SCHEMA_VERSION,
    entities = entities,
    meta = list(requested = length(ids), returned = returned, errors = length(ids) - returned, max_entity_ids = 20L)
  )
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected: all MCP service tests pass.

- [ ] **Step 5: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-service.R
git commit -m "feat: add MCP entity batch context"
```

## Task 3: MCP Tool Metadata, Alias Handling, And Resource Methods

**Files:**
- Modify: `api/services/mcp-tools.R`
- Test: `api/tests/testthat/test-mcp-tools.R`

- [ ] **Step 1: Write failing tool registry tests**

Update `api/tests/testthat/test-mcp-tools.R`:

```r
test_that("MCP registry exposes entity batch tool and rich metadata", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool_names <- vapply(registry$tools, function(x) x@name %||% x$name %||% "", character(1))

  expect_true("get_entities_context" %in% tool_names)
  expect_false(any(grepl("session|code|sql|admin|review|job|log|user", tool_names, ignore.case = TRUE)))

  metadata <- mcp_tool_metadata(registry$tools)
  expect_true(all(vapply(metadata, function(x) isTRUE(x$annotations$readOnlyHint), logical(1))))
  expect_true(all(vapply(metadata, function(x) !is.null(x$outputSchema), logical(1))))

  search <- metadata[[which(vapply(metadata, `[[`, character(1), "name") == "search_sysndd")]]
  expect_true(nzchar(search$inputSchema$properties$types$description))

  batch_pubs <- metadata[[which(vapply(metadata, `[[`, character(1), "name") == "get_publications_context")]]
  expect_true(nzchar(batch_pubs$inputSchema$properties$pmids$description))
})

test_that("MCP static resource handlers list and read schema resources", {
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  listed <- mcp_handle_resources_list(1L)
  uris <- vapply(listed$result$resources, `[[`, character(1), "uri")
  expect_true("sysndd://schema/overview" %in% uris)
  expect_true("sysndd://schema/tool-guide" %in% uris)

  read <- mcp_handle_resources_read(2L, "sysndd://schema/tool-guide")
  expect_match(read$result$contents[[1]]$text, "tool-guide", fixed = TRUE)

  missing <- mcp_handle_resources_read(3L, "sysndd://schema/missing")
  expect_equal(missing$error$code, -32002)
})

test_that("MCP tool wrappers accept symbol alias and reject unknown parameters visibly", {
  source("../../functions/mcp-repository.R")
  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  old_resolve <- mcp_repo_resolve_gene
  old_entities <- mcp_repo_get_gene_entities
  old_comparisons <- mcp_repo_get_gene_comparisons
  assign("mcp_repo_resolve_gene", function(normalized_gene) {
    tibble::tibble(hgnc_id = "HGNC:18704", symbol = "NAA10", name = "NAA10")
  }, envir = .GlobalEnv)
  assign("mcp_repo_get_gene_entities", function(...) tibble::tibble(), envir = .GlobalEnv)
  assign("mcp_repo_get_gene_comparisons", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_repo_resolve_gene", old_resolve, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_entities", old_entities, envir = .GlobalEnv)
    assign("mcp_repo_get_gene_comparisons", old_comparisons, envir = .GlobalEnv)
  })

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  tool <- registry$tool_functions$get_gene_context

  parsed <- jsonlite::fromJSON(tool(symbol = "NAA10"), simplifyVector = FALSE)
  expect_equal(parsed$gene$symbol, "NAA10")

  err <- jsonlite::fromJSON(tool(foo = "NAA10"), simplifyVector = FALSE)
  expect_equal(err$error$code, "invalid_input")
  expect_equal(err$error$argument, "foo")
})
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
```

Expected: failures for missing metadata helpers, missing resource handlers, missing `get_entities_context`, and old wrapper signatures.

- [ ] **Step 3: Implement metadata and resource helpers**

In `api/services/mcp-tools.R`:

- Add `mcp_tool_annotations()` returning read-only/idempotent hints.
- Add `mcp_output_schema(name)` returning a compact root object schema with `schema_version`.
- Add `mcp_tool_metadata(tools)` that starts from `mcptools:::tool_as_json()`, fills blank array descriptions, adds annotations and output schema.
- Add `mcp_jsonrpc_response(id, result = NULL, error = NULL)`.
- Add `mcp_handle_resources_list(id)` and `mcp_handle_resources_read(id, uri)`.
- Add `mcp_patch_mcptools_protocol(registry, instructions)` that patches:
  - `capabilities` for SysNDD instructions.
  - `get_mcptools_tools_as_json` or `tool_as_json` for metadata.
  - `handle_http_request_message` for `resources/list` and `resources/read`.
  - `as_tool_call_result` only if structured output mode needs a real MCP result object.

- [ ] **Step 4: Implement safe argument wrappers**

Add helper:

```r
mcp_unknown_arg_error <- function(provided, expected) {
  unknown <- setdiff(provided, expected)
  if (length(unknown) > 0L) {
    stop(mcp_error(
      "invalid_input",
      sprintf("Unknown parameter '%s'. Expected: %s", unknown[[1]], paste(expected, collapse = ", ")),
      list(argument = unknown[[1]], expected_arguments = as.list(expected))
    ))
  }
}
```

Replace per-tool wrapper functions with `...` signatures where needed, validate names, and call the service functions. `get_gene_context` should map `symbol` to `gene` when `gene` is absent.

- [ ] **Step 5: Register get_entities_context and metadata**

Add the `get_entities_context` `ellmer::tool()` with `entity_ids` array description, passthrough flags, and publication limit. Return `tool_functions` from `mcp_build_tool_registry()` for direct tests:

```r
list(tools = tools, resources = mcp_static_resources(), tool_functions = list(...))
```

- [ ] **Step 6: Run tool tests and verify they pass**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
```

Expected: all MCP tool registry tests pass.

- [ ] **Step 7: Commit**

```bash
git add api/services/mcp-tools.R api/tests/testthat/test-mcp-tools.R
git commit -m "feat: enrich MCP metadata and resources"
```

## Task 4: Wire Smoke And Runtime Entrypoint

**Files:**
- Modify: `api/start_sysndd_mcp.R`
- Modify: `api/scripts/mcp-smoke.R`

- [ ] **Step 1: Update smoke tests for live protocol behavior**

Extend `api/scripts/mcp-smoke.R` to:

- assert instructions mention `research`.
- assert `tools/list` includes `get_entities_context`.
- assert every tool has `annotations.readOnlyHint = TRUE`.
- assert every tool has `outputSchema`.
- assert array parameter descriptions are non-empty.
- call `resources/list` and `resources/read`.
- call malformed PMID and invalid phenotype category and assert no JSON-RPC `error`.
- call `get_gene_context` with `symbol = "NAA10"` and assert success.

- [ ] **Step 2: Run smoke test and verify it fails before runtime patch**

Run:

```bash
MCP_URL=http://127.0.0.1:8787 make test-mcp-smoke
```

Expected: failure on missing wire-level metadata/resources or missing new runtime patch.

- [ ] **Step 3: Wire the protocol patch at startup**

In `api/start_sysndd_mcp.R`, replace:

```r
mcp_patch_mcptools_instructions()
```

with:

```r
mcp_patch_mcptools_protocol(registry = registry, instructions = mcp_server_instructions())
```

Keep `mcptools::mcp_server(..., session_tools = FALSE)`.

- [ ] **Step 4: Rebuild/restart MCP sidecar and run smoke**

Run:

```bash
COMPOSE_PROJECT_NAME=sysndd docker compose -f docker-compose.yml -f docker-compose.override.yml up -d --build --no-deps --force-recreate mcp
MCP_URL=http://127.0.0.1:8787 make test-mcp-smoke
```

Expected: smoke passes.

- [ ] **Step 5: Commit**

```bash
git add api/start_sysndd_mcp.R api/scripts/mcp-smoke.R
git commit -m "test: verify MCP protocol ergonomics"
```

## Task 5: Documentation And Final Verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `api/config/mcp/resources/sysndd-schema.md`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/09-deployment.qmd`

- [ ] **Step 1: Update docs**

Document:

- `get_entities_context`.
- static `resources/list` / `resources/read`.
- tool-visible error envelopes.
- read-only annotations and output schemas.
- `symbol` alias for `get_gene_context`.
- research-use disclaimer and date/citation contract.

- [ ] **Step 2: Run focused MCP tests**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-helpers.R'); testthat::test_file('tests/testthat/test-mcp-service.R')"
```

Expected: pass.

If host lacks `ellmer`, run tool tests in the MCP container after copying the updated files:

```bash
docker cp api/tests/testthat/test-mcp-tools.R sysndd-mcp-1:/tmp/tests/testthat/test-mcp-tools.R
docker cp api/services/mcp-service.R sysndd-mcp-1:/tmp/services/mcp-service.R
docker cp api/services/mcp-tools.R sysndd-mcp-1:/tmp/services/mcp-tools.R
docker exec sysndd-mcp-1 Rscript --no-init-file -e "setwd('/tmp/tests/testthat'); testthat::test_file('test-mcp-tools.R')"
```

Expected: pass.

- [ ] **Step 3: Run repo checks**

Run:

```bash
MCP_URL=http://127.0.0.1:8787 make test-mcp-smoke
make test-api-fast
make lint-api
git diff --check
```

Expected: all pass.

- [ ] **Step 4: Commit docs**

```bash
git add AGENTS.md api/config/mcp/resources/sysndd-schema.md documentation/03-api.qmd documentation/09-deployment.qmd
git commit -m "docs: document MCP ergonomics contract"
```

- [ ] **Step 5: Push branch**

```bash
git status --short
git push
```

Expected: clean worktree after push.
