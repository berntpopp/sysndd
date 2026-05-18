# SysNDD MCP Analysis Research Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add read-only MCP tools that expose SysNDD analysis context, NDDScore model-derived predictions, and cache-only LLM summaries for bounded gene-centered research workflows.

**Architecture:** Keep the existing private read-only R MCP sidecar. Add a focused MCP analysis repository layer for DB/cache reads, service-layer shaping with explicit data-class provenance, and tool registrations with schemas/read-only annotations. MCP must not call Gemini, expose LLM prompts, write data, call live external providers, or expose admin-only workflows.

**Tech Stack:** R, testthat, DBI/RMariaDB, pool, dplyr/dbplyr, jsonlite, ellmer, mcptools, Plumber-side existing repositories, MySQL current-release views, SysNDD MCP static resources.

---

## File Map

- Create `api/functions/mcp-analysis-repository.R`: read-only repository helpers for analysis catalog metadata, NDDScore active-release context, curation comparisons, phenotype/correlation summaries, gene network cache-safe reads, and validated LLM summary cache reads.
- Modify `api/functions/analyses-functions.R`: extract shared `mcp_analysis_build_phenotype_cluster_input()`, `generate_phenotype_correlations()`, and `generate_phenotype_functional_cluster_correlation()` helpers so endpoints and MCP use one implementation.
- Modify `api/endpoints/analysis_endpoints.R` and `api/endpoints/phenotype_endpoints.R`: replace inline phenotype correlation and phenotype-functional correlation bodies with shared helper calls.
- Create `api/tests/testthat/test-mcp-analysis-repository.R`: repository tests for SQL boundaries, cache-only LLM reads, NDDScore current views, and comparison/analysis public-data gates.
- Create `api/tests/testthat/test-mcp-analysis-service.R`: service tests for provenance envelopes, analysis catalog, NDDScore labels, comparison context, phenotype analysis modes, network unavailable behavior, cache-only LLM summaries, and gene research aggregation.
- Modify `api/bootstrap/load_modules.R`: source `functions/mcp-analysis-repository.R` after `functions/mcp-repository.R` and before services.
- Modify `api/services/mcp-service.R`: add data-class helpers and new service entrypoints.
- Modify `api/services/mcp-tools.R`: register six new tools, output schemas, argument validation, capability text, and resource text.
- Modify `api/config/mcp/resources/sysndd-schema.md`: document analysis tools, data classes, and cache-only LLM summary semantics.
- Modify `api/scripts/mcp-smoke.R`: add smoke calls for analysis catalog, gene research context, NDDScore, and invalid mode errors.
- Modify `api/tests/testthat/test-mcp-tools.R`: assert the expanded registry, metadata, read-only annotations, and no LLM/external prompt/query exposure.
- Modify `documentation/03-api.qmd`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`, and `AGENTS.md`: durable docs for MCP v1.2 analysis scope.

## Task 1: Data Classification Helpers

**Files:**
- Modify: `api/services/mcp-service.R`
- Create: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Write failing tests for data-class envelopes**

Create `api/tests/testthat/test-mcp-analysis-service.R` with:

```r
test_that("MCP analysis data-class envelopes distinguish curated, derived, ML, and LLM data", {
  source("../../services/mcp-service.R")

  curated <- mcp_analysis_provenance(
    data_class = "curated_sysndd_evidence",
    source = "SysNDD",
    source_table_or_view = "ndd_entity_view",
    generated_by = "human_curation"
  )
  expect_equal(curated$data_class, "curated_sysndd_evidence")
  expect_equal(curated$curation_effect, "curated_evidence")
  expect_false(curated$not_evidence_tier)

  ml <- mcp_analysis_provenance(
    data_class = "ml_prediction",
    source = "NDDScore",
    source_table_or_view = "nddscore_gene_prediction_current",
    generated_by = "nddscore_model"
  )
  expect_equal(ml$curation_effect, "none")
  expect_true(ml$not_evidence_tier)
  expect_match(ml$limitations[[1]], "Not an evidence tier", fixed = TRUE)

  llm <- mcp_analysis_provenance(
    data_class = "llm_generated_summary",
    source = "SysNDD LLM summary cache",
    source_table_or_view = "llm_cluster_summary_cache",
    generated_by = "admin_llm_workflow"
  )
  expect_true(llm$not_evidence_tier)
  expect_match(llm$limitations[[1]], "Cache-only", fixed = TRUE)
})
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because `mcp_analysis_provenance()` does not exist.

- [ ] **Step 3: Add data-class constants and helper**

In `api/services/mcp-service.R`, update the MCP schema version and add the new
analysis constants near the MCP constants:

```r
MCP_SCHEMA_VERSION <- "1.2"

MCP_ANALYSIS_DATA_CLASSES <- c(
  "curated_sysndd_evidence",
  "curated_derived_analysis",
  "ml_prediction",
  "llm_generated_summary",
  "external_reference_identifier",
  "operational_metadata"
)

mcp_analysis_provenance <- function(data_class,
                                    source,
                                    source_table_or_view,
                                    generated_by,
                                    filters = list(),
                                    limitations = list()) {
  data_class <- mcp_validate_enum(data_class, MCP_ANALYSIS_DATA_CLASSES, "data_class")

  if (identical(data_class, "curated_sysndd_evidence")) {
    curation_effect <- "curated_evidence"
    not_evidence_tier <- FALSE
  } else {
    curation_effect <- "none"
    not_evidence_tier <- TRUE
  }

  class_limitations <- switch(
    data_class,
    ml_prediction = list(
      "ML prediction; model-derived; separate from curated SysNDD evidence; Not an evidence tier."
    ),
    llm_generated_summary = list(
      "LLM-generated cached summary; admin-generated; Cache-only; does not change curated SysNDD evidence."
    ),
    curated_derived_analysis = list(
      "Derived analysis for hypothesis generation; correlations, clusters, and networks are not causal claims."
    ),
    external_reference_identifier = list(
      "External reference identifier stored in SysNDD; no live external provider call was made by MCP."
    ),
    list()
  )

  list(
    schema_version = MCP_SCHEMA_VERSION,
    data_class = data_class,
    curation_effect = curation_effect,
    not_evidence_tier = not_evidence_tier,
    source = source,
    provenance = list(
      source_table_or_view = source_table_or_view,
      filters = filters,
      generated_by = generated_by
    ),
    limitations = c(class_limitations, limitations)
  )
}
```

- [ ] **Step 4: Audit every schema-version-coupled site**

Run:

```bash
rg -n "1\\.1|MCP_SCHEMA_VERSION" api/services/mcp-*.R api/tests/testthat/test-mcp-*.R api/config/mcp api/start_sysndd_mcp.R AGENTS.md documentation/03-api.qmd documentation/09-deployment.qmd
```

Update every explicit `1.1` MCP contract reference to `1.2` in the same commit
as the constant change. Existing tests should assert against
`MCP_SCHEMA_VERSION`, not a hard-coded `"1.1"`.

- [ ] **Step 5: Run the test and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/services/mcp-service.R api/services/mcp-tools.R api/config/mcp/resources/sysndd-schema.md api/tests/testthat/test-mcp-*.R AGENTS.md documentation/03-api.qmd documentation/09-deployment.qmd
git commit -m "feat: add MCP analysis provenance helpers"
```

## Task 2: Analysis Repository Layer

**Files:**
- Create: `api/functions/mcp-analysis-repository.R`
- Create: `api/tests/testthat/test-mcp-analysis-repository.R`
- Modify: `api/bootstrap/load_modules.R`

- [ ] **Step 1: Write repository boundary tests**

Create `api/tests/testthat/test-mcp-analysis-repository.R`:

```r
test_that("MCP LLM summary repository is cache-only and validated by default", {
  source("../../functions/mcp-analysis-repository.R")

  sql_seen <- character()
  old_query <- get0("db_execute_query", envir = .GlobalEnv, ifnotfound = NULL)
  assign("db_execute_query", function(sql, params = list()) {
    sql_seen <<- c(sql_seen, sql)
    tibble::tibble(
      cache_id = 7L,
      cluster_type = "functional",
      cluster_number = 3L,
      cluster_hash = "abc",
      model_name = "gemini-3-flash",
      prompt_version = "1.0",
      summary_json = "{\"summary\":\"cached\"}",
      tags = "[\"synaptic\"]",
      is_current = 1L,
      validation_status = "validated",
      created_at = as.POSIXct("2026-05-01 00:00:00", tz = "UTC"),
      validated_at = as.POSIXct("2026-05-02 00:00:00", tz = "UTC")
    )
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_query)) rm("db_execute_query", envir = .GlobalEnv) else assign("db_execute_query", old_query, envir = .GlobalEnv)
  )

  result <- mcp_analysis_repo_get_cached_llm_summaries("functional", cluster_hashes = "abc")

  expect_equal(nrow(result), 1L)
  expect_true(any(grepl("llm_cluster_summary_cache", sql_seen, fixed = TRUE)))
  expect_true(any(grepl("validation_status = 'validated'", sql_seen, fixed = TRUE)))
  expect_false(any(grepl("get_or_generate_summary|chat_google_gemini|llm-service", sql_seen)))
})

test_that("MCP NDDScore repository delegates to active current-view helpers", {
  source("../../functions/mcp-analysis-repository.R")

  old_detail <- get0("nddscore_repo_gene_detail", envir = .GlobalEnv, ifnotfound = NULL)
  assign("nddscore_repo_gene_detail", function(hgnc_id_or_symbol) {
    list(
      gene = tibble::tibble(hgnc_id = "HGNC:61", gene_symbol = "ABCD1", ndd_score = 0.7),
      hpo_predictions = tibble::tibble(phenotype_id = "HP:0001250", probability = 0.4)
    )
  }, envir = .GlobalEnv)
  withr::defer(
    if (is.null(old_detail)) rm("nddscore_repo_gene_detail", envir = .GlobalEnv) else assign("nddscore_repo_gene_detail", old_detail, envir = .GlobalEnv)
  )

  result <- mcp_analysis_repo_get_nddscore_gene("HGNC:61")
  expect_equal(result$gene$gene_symbol[[1]], "ABCD1")
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
```

Expected: FAIL because the repository file/functions are absent.

- [ ] **Step 3: Implement repository helpers**

Create `api/functions/mcp-analysis-repository.R`:

```r
# Read-only MCP analysis repository helpers.

mcp_analysis_repo_current_release <- function() {
  nddscore_repo_current_release()
}

mcp_analysis_repo_get_nddscore_gene <- function(gene) {
  nddscore_repo_gene_detail(gene)
}

mcp_analysis_repo_get_nddscore_genes <- function(filters = list(),
                                                 sort = "rank",
                                                 page = 1L,
                                                 page_size = 25L) {
  nddscore_repo_genes(filters = filters, sort = sort, page = page, page_size = page_size)
}

mcp_analysis_repo_get_comparison_metadata <- function() {
  db_execute_query(
    "SELECT last_full_refresh, last_refresh_status, sources_count, rows_imported
     FROM comparisons_metadata
     ORDER BY id DESC
     LIMIT 1",
    unname(list())
  )
}

mcp_analysis_repo_get_comparison_rows <- function(hgnc_id = NULL,
                                                  sources = NULL,
                                                  category = NULL,
                                                  limit = 25L,
                                                  offset = 0L) {
  filters <- character()
  params <- list()

  if (!is.null(hgnc_id)) {
    filters <- c(filters, "hgnc_id = ?")
    params <- c(params, list(hgnc_id))
  }
  if (!is.null(category)) {
    filters <- c(filters, "category = ?")
    params <- c(params, list(category))
  }
  if (length(sources %||% character()) > 0L) {
    bind_marks <- paste(rep("?", length(sources)), collapse = ", ")
    filters <- c(filters, sprintf("list IN (%s)", bind_marks))
    params <- c(params, as.list(sources))
  }

  where <- if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else ""
  db_execute_query(
    paste(
      "SELECT hgnc_id, disease_ontology_id, inheritance, category, pathogenicity_mode, list, version",
      "FROM ndd_database_comparison_view",
      where,
      "ORDER BY hgnc_id, list, disease_ontology_id",
      "LIMIT ? OFFSET ?"
    ),
    unname(c(params, list(limit, offset)))
  )
}

mcp_analysis_repo_count_comparison_rows <- function(hgnc_id = NULL,
                                                    sources = NULL,
                                                    category = NULL) {
  filters <- character()
  params <- list()
  if (!is.null(hgnc_id)) {
    filters <- c(filters, "hgnc_id = ?")
    params <- c(params, list(hgnc_id))
  }
  if (!is.null(category)) {
    filters <- c(filters, "category = ?")
    params <- c(params, list(category))
  }
  if (length(sources %||% character()) > 0L) {
    bind_marks <- paste(rep("?", length(sources)), collapse = ", ")
    filters <- c(filters, sprintf("list IN (%s)", bind_marks))
    params <- c(params, as.list(sources))
  }
  where <- if (length(filters) > 0L) paste("WHERE", paste(filters, collapse = " AND ")) else ""
  rows <- db_execute_query(
    paste("SELECT COUNT(*) AS total FROM ndd_database_comparison_view", where),
    unname(params)
  )
  as.integer(rows$total[[1]] %||% 0L)
}

mcp_analysis_repo_get_gene_external_identifiers <- function(hgnc_id) {
  db_execute_query(
    "
      SELECT hgnc_id, symbol, omim_id, ensembl_gene_id, uniprot_ids,
             STRING_id, mgd_id, rgd_id, mane_select,
             alphafold_id
      FROM non_alt_loci_set
      WHERE hgnc_id = ?
      LIMIT 1",
    unname(list(hgnc_id))
  )
}

mcp_analysis_repo_get_cached_llm_summaries <- function(cluster_type,
                                                       cluster_hashes = NULL,
                                                       cluster_numbers = NULL,
                                                       require_validated = TRUE,
                                                       limit = 10L) {
  filters <- c("cluster_type = ?", "is_current = TRUE")
  params <- list(cluster_type)
  if (isTRUE(require_validated)) {
    filters <- c(filters, "validation_status = 'validated'")
  }
  if (length(cluster_hashes %||% character()) > 0L) {
    bind_marks <- paste(rep("?", length(cluster_hashes)), collapse = ", ")
    filters <- c(filters, sprintf("cluster_hash IN (%s)", bind_marks))
    params <- c(params, as.list(cluster_hashes))
  }
  if (length(cluster_numbers %||% integer()) > 0L) {
    bind_marks <- paste(rep("?", length(cluster_numbers)), collapse = ", ")
    filters <- c(filters, sprintf("cluster_number IN (%s)", bind_marks))
    params <- c(params, as.list(cluster_numbers))
  }

  db_execute_query(
    paste(
      "SELECT cache_id, cluster_type, cluster_number, cluster_hash, model_name, prompt_version,",
      "summary_json, tags, is_current, validation_status, created_at, validated_at",
      "FROM llm_cluster_summary_cache",
      "WHERE", paste(filters, collapse = " AND "),
      "ORDER BY validated_at DESC, created_at DESC",
      "LIMIT ?"
    ),
    unname(c(params, list(limit)))
  )
}

mcp_analysis_repo_network_cache_hit <- function(cluster_type = "clusters",
                                                min_confidence = 400L) {
  if (!requireNamespace("memoise", quietly = TRUE)) return(FALSE)
  if (!exists("gen_network_edges_mem", mode = "function")) return(FALSE)
  if (!memoise::is.memoised(gen_network_edges_mem)) return(FALSE)
  checker <- memoise::has_cache(gen_network_edges_mem)
  isTRUE(checker(cluster_type = cluster_type, min_confidence = min_confidence))
}
```

- [ ] **Step 4: Source the repository during bootstrap**

In `api/bootstrap/load_modules.R`, add `"functions/mcp-analysis-repository.R"` immediately after `"functions/mcp-repository.R"`.

- [ ] **Step 5: Run repository tests and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/functions/mcp-analysis-repository.R api/bootstrap/load_modules.R api/tests/testthat/test-mcp-analysis-repository.R
git commit -m "feat: add MCP analysis repository reads"
```

## Task 3: Catalog, NDDScore, And Comparison Services

**Files:**
- Modify: `api/services/mcp-service.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Add failing service tests**

Append to `api/tests/testthat/test-mcp-analysis-service.R`:

```r
test_that("analysis catalog advertises approved scope B tools and data classes", {
  source("../../services/mcp-service.R")

  catalog <- mcp_get_sysndd_analysis_catalog()
  ids <- vapply(catalog$analyses, `[[`, character(1), "analysis_id")

  expect_equal(catalog$schema_version, MCP_SCHEMA_VERSION)
  expect_true("nddscore" %in% ids)
  expect_true("gene_research_context" %in% ids)
  expect_true("cached_llm_summaries" %in% ids)
  expect_false(any(grepl("generate|prompt|gemini", ids, ignore.case = TRUE)))
})

test_that("NDDScore MCP context is always marked as ML prediction and not evidence tier", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_release <- mcp_analysis_repo_current_release
  old_gene <- mcp_analysis_repo_get_nddscore_gene
  assign("mcp_analysis_repo_current_release", function() {
    tibble::tibble(release_id = "rel1", version = "2026.05", is_active = 1L)
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_nddscore_gene", function(gene) {
    list(
      gene = tibble::tibble(hgnc_id = "HGNC:61", gene_symbol = "ABCD1", ndd_score = 0.7),
      hpo_predictions = tibble::tibble(phenotype_id = "HP:0001250", probability = 0.4)
    )
  }, envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_current_release", old_release, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_nddscore_gene", old_gene, envir = .GlobalEnv)
  })

  result <- mcp_get_nddscore_context(gene = "HGNC:61")

  expect_equal(result$data_class, "ml_prediction")
  expect_equal(result$curation_effect, "none")
  expect_true(result$not_evidence_tier)
  expect_match(result$notice, "Separate from curated SysNDD evidence", fixed = TRUE)
})

test_that("curation comparison context returns bounded rows with derived-analysis labels", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_rows <- mcp_analysis_repo_get_comparison_rows
  old_count <- mcp_analysis_repo_count_comparison_rows
  old_meta <- mcp_analysis_repo_get_comparison_metadata
  assign("mcp_analysis_repo_get_comparison_rows", function(...) {
    tibble::tibble(hgnc_id = "HGNC:61", list = "SysNDD", category = "Definitive")
  }, envir = .GlobalEnv)
  assign("mcp_analysis_repo_count_comparison_rows", function(...) 1L, envir = .GlobalEnv)
  assign("mcp_analysis_repo_get_comparison_metadata", function() tibble::tibble(last_refresh_status = "success"), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_analysis_repo_get_comparison_rows", old_rows, envir = .GlobalEnv)
    assign("mcp_analysis_repo_count_comparison_rows", old_count, envir = .GlobalEnv)
    assign("mcp_analysis_repo_get_comparison_metadata", old_meta, envir = .GlobalEnv)
  })

  result <- mcp_get_curation_comparison_context(gene = "HGNC:61")
  expect_equal(result$data_class, "curated_derived_analysis")
  expect_equal(result$rows[[1]]$hgnc_id, "HGNC:61")
  expect_equal(result$meta$total, 1L)
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because service functions are absent.

- [ ] **Step 3: Implement catalog, NDDScore, and comparison services**

Add to `api/services/mcp-service.R`:

```r
mcp_get_sysndd_analysis_catalog <- function(include_unavailable = FALSE) {
  analyses <- list(
    list(analysis_id = "gene_research_context", tool = "get_gene_research_context", data_class = "operational_metadata", payload_shape = "mixed_labeled_sections", availability = "available"),
    list(analysis_id = "nddscore", tool = "get_nddscore_context", data_class = "ml_prediction", availability = "available"),
    list(analysis_id = "curation_comparisons", tool = "get_curation_comparison_context", data_class = "curated_derived_analysis", availability = "available"),
    list(analysis_id = "phenotype_analysis", tool = "get_phenotype_analysis_context", data_class = "curated_derived_analysis", availability = "available"),
    list(analysis_id = "gene_network", tool = "get_gene_network_context", data_class = "curated_derived_analysis", availability = "cache_hit_only"),
    list(analysis_id = "cached_llm_summaries", tool = "get_gene_research_context", data_class = "llm_generated_summary", availability = "cache_only")
  )
  if (!isTRUE(include_unavailable)) {
    analyses <- Filter(function(x) !identical(x$availability, "unavailable"), analyses)
  }
  list(
    schema_version = MCP_SCHEMA_VERSION,
    analyses = analyses,
    contract = list(
      llm_generation = "never",
      llm_summaries = "current validated cache only",
      live_external_providers = "never",
      evidence_boundary = "ML and LLM outputs do not change curated SysNDD evidence"
    )
  )
}

mcp_nddscore_release_record <- function(release) {
  if (is.null(release) || nrow(release) == 0L) return(NULL)
  keep <- intersect(
    c(
      "release_id", "score_schema_version", "version", "release_created_at",
      "n_genes", "n_hpo_predictions", "n_hpo_terms", "n_features",
      "hpo_threshold", "calibration_method", "version_doi", "concept_doi",
      "source_record_id", "import_completed_at", "activated_at"
    ),
    names(release)
  )
  mcp_rows_to_records(release[keep])[[1]]
}

mcp_get_nddscore_context <- function(gene = NULL,
                                     mode = NULL,
                                     risk_tier = NULL,
                                     confidence_tier = NULL,
                                     known_sysndd_gene = NULL,
                                     hpo_terms = NULL,
                                     search = NULL,
                                     sort = "rank",
                                     page = 1L,
                                     page_size = 25L) {
  mode <- mode %||% if (!is.null(gene)) "gene" else "ranked_genes"
  mode <- mcp_validate_enum(mode, c("gene", "ranked_genes", "release"), "mode")
  page <- suppressWarnings(as.integer(page %||% 1L))
  if (is.na(page) || page < 1L) {
    stop(mcp_error("invalid_input", "page must be a positive integer", list(argument = "page")))
  }
  page_size <- mcp_validate_limit(page_size, default = 25L, max = 50L, name = "page_size")
  release <- mcp_analysis_repo_current_release()
  if (is.null(release) || nrow(release) == 0L) {
    stop(mcp_error("temporarily_unavailable", "No active NDDScore release is available.", list(argument = "release")))
  }
  envelope <- mcp_analysis_provenance("ml_prediction", "NDDScore", "nddscore_*_current", "nddscore_model")
  release_record <- mcp_nddscore_release_record(release)

  if (identical(mode, "release")) {
    return(c(envelope, list(release = release_record, notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.")))
  }

  if (identical(mode, "gene")) {
    if (is.null(gene)) {
      stop(mcp_error("invalid_input", "gene is required when mode is gene", list(argument = "gene")))
    }
    detail <- mcp_analysis_repo_get_nddscore_gene(gene)
    if (is.null(detail$gene) || nrow(detail$gene) == 0L) {
      stop(mcp_error("not_found", sprintf("NDDScore gene '%s' was not found.", gene), list(argument = "gene")))
    }
    return(c(envelope, list(
      notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
      release = release_record,
      gene = mcp_rows_to_records(detail$gene)[[1]],
      hpo_predictions = if (is.null(detail$hpo_predictions)) list() else mcp_rows_to_records(detail$hpo_predictions)
    )))
  }

  filters <- Filter(Negate(is.null), list(
    risk_tier = risk_tier,
    confidence_tier = confidence_tier,
    known_sysndd_gene = known_sysndd_gene,
    hpo_terms = hpo_terms,
    search = search
  ))
  result <- tryCatch(
    mcp_analysis_repo_get_nddscore_genes(filters = filters, sort = sort, page = page, page_size = page_size),
    error = function(e) stop(mcp_error("invalid_input", conditionMessage(e), list(argument = "sort_or_filter")))
  )
  c(envelope, list(
    notice = "NDDScore is an ML prediction layer. Separate from curated SysNDD evidence. Not an evidence tier.",
    release = release_record,
    genes = mcp_rows_to_records(result$data),
    meta = list(total = result$total, page = result$page, page_size = result$page_size, has_more = result$page * result$page_size < result$total)
  ))
}

mcp_get_curation_comparison_context <- function(gene = NULL,
                                                mode = NULL,
                                                sources = NULL,
                                                category = NULL,
                                                limit = 25L,
                                                offset = 0L) {
  mode <- mode %||% if (!is.null(gene)) "gene_sources" else "browse"
  if (mode %in% c("source_overlap", "source_similarity")) {
    stop(mcp_error("unsupported_mode", "Comparison plot modes are not exposed through MCP v1.2; use gene_sources or browse.", list(argument = "mode")))
  }
  mode <- mcp_validate_enum(mode, c("gene_sources", "browse"), "mode")
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  offset <- mcp_validate_offset(offset)
  category <- if (is.null(category)) NULL else mcp_validate_query(category, min_chars = 1L, max_chars = 100L, argument = "category")

  hgnc_id <- NULL
  if (!is.null(gene)) {
    hgnc_id <- mcp_resolve_gene_one(gene)$hgnc_id
  }

  rows <- mcp_analysis_repo_get_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category, limit = limit, offset = offset)
  total <- mcp_analysis_repo_count_comparison_rows(hgnc_id = hgnc_id, sources = sources, category = category)
  meta <- mcp_analysis_repo_get_comparison_metadata()
  envelope <- mcp_analysis_provenance("curated_derived_analysis", "SysNDD comparison view", "ndd_database_comparison_view", "sysndd_import_pipeline")
  c(envelope, list(
    mode = mode,
    rows = mcp_rows_to_records(rows),
    comparison_metadata = mcp_rows_to_records(meta),
    meta = list(total = total, limit = limit, offset = offset, has_more = offset + limit < total),
    notice = "Comparison sources are cross-references and do not alter curated SysNDD classifications."
  ))
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat: add MCP catalog NDDScore and comparison services"
```

## Task 4: Cache-Only LLM Summary Service

**Files:**
- Modify: `api/services/mcp-service.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Add failing tests for cache-only summary behavior**

Append:

```r
test_that("MCP LLM summary service returns cached validated summaries and never generates", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_cache <- mcp_analysis_repo_get_cached_llm_summaries
  assign("mcp_analysis_repo_get_cached_llm_summaries", function(...) {
    tibble::tibble(
      cache_id = 7L,
      cluster_type = "functional",
      cluster_number = 3L,
      cluster_hash = "abc",
      model_name = "gemini-3-flash",
      prompt_version = "1.0",
      summary_json = "{\"summary\":\"cached summary\"}",
      tags = "[\"synaptic\"]",
      is_current = 1L,
      validation_status = "validated",
      created_at = as.POSIXct("2026-05-01 00:00:00", tz = "UTC"),
      validated_at = as.POSIXct("2026-05-02 00:00:00", tz = "UTC")
    )
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_cached_llm_summaries", old_cache, envir = .GlobalEnv))

  result <- mcp_get_cached_llm_summaries("functional", cluster_hashes = "abc")

  expect_true(result[[1]]$summary_available)
  expect_equal(result[[1]]$data_class, "llm_generated_summary")
  expect_true(result[[1]]$cache_only)
  expect_equal(result[[1]]$summary$summary, "cached summary")
})

test_that("MCP LLM summary service reports cache miss without generation", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_cache <- mcp_analysis_repo_get_cached_llm_summaries
  assign("mcp_analysis_repo_get_cached_llm_summaries", function(...) tibble::tibble(), envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_cached_llm_summaries", old_cache, envir = .GlobalEnv))

  result <- mcp_get_cached_llm_summaries("phenotype", cluster_numbers = 1L)

  expect_false(result[[1]]$summary_available)
  expect_true(result[[1]]$cache_only)
  expect_equal(result[[1]]$data_class, "llm_generated_summary")
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because `mcp_get_cached_llm_summaries()` does not exist.

- [ ] **Step 3: Implement cache-only summary shaping**

Add to `api/services/mcp-service.R`:

```r
mcp_parse_json_field <- function(value, default = list()) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1]]) || !nzchar(as.character(value[[1]]))) {
    return(default)
  }
  tryCatch(jsonlite::fromJSON(as.character(value[[1]]), simplifyVector = FALSE), error = function(e) default)
}

mcp_llm_cache_miss <- function(cluster_type, cluster_hash = NULL, cluster_number = NULL) {
  c(
    mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
    list(
      summary_available = FALSE,
      cache_only = TRUE,
      cluster_type = cluster_type,
      cluster_hash = cluster_hash,
      cluster_number = cluster_number
    )
  )
}

mcp_get_cached_llm_summaries <- function(cluster_type,
                                         cluster_hashes = NULL,
                                         cluster_numbers = NULL,
                                         require_validated = TRUE,
                                         limit = 10L) {
  cluster_type <- mcp_validate_enum(cluster_type, c("functional", "phenotype"), "cluster_type")
  limit <- mcp_validate_limit(limit, default = 10L, max = 20L)
  rows <- mcp_analysis_repo_get_cached_llm_summaries(
    cluster_type = cluster_type,
    cluster_hashes = cluster_hashes,
    cluster_numbers = cluster_numbers,
    require_validated = require_validated,
    limit = limit
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(mcp_llm_cache_miss(
      cluster_type,
      cluster_hash = (cluster_hashes %||% list(NULL))[[1]],
      cluster_number = (cluster_numbers %||% list(NULL))[[1]]
    )))
  }

  lapply(seq_len(nrow(rows)), function(i) {
    row <- mcp_row_to_list(rows[i, , drop = FALSE])
    c(
      mcp_analysis_provenance("llm_generated_summary", "SysNDD LLM summary cache", "llm_cluster_summary_cache", "admin_llm_workflow"),
      list(
        summary_available = TRUE,
        cache_only = TRUE,
        cache_id = row$cache_id,
        cluster_type = row$cluster_type,
        cluster_number = row$cluster_number,
        cluster_hash = row$cluster_hash,
        model_name = row$model_name,
        prompt_version = row$prompt_version,
        validation_status = row$validation_status,
        created_at = row$created_at,
        validated_at = row$validated_at,
        tags = mcp_parse_json_field(row$tags, list()),
        summary = mcp_parse_json_field(row$summary_json, list())
      )
    )
  })
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat: expose cache-only MCP LLM summaries"
```

## Task 5: Phenotype And Network Analysis Services

**Files:**
- Modify: `api/functions/mcp-analysis-repository.R`
- Modify: `api/functions/analyses-functions.R`
- Modify: `api/endpoints/analysis_endpoints.R`
- Modify: `api/endpoints/phenotype_endpoints.R`
- Modify: `api/services/mcp-service.R`
- Modify: `api/tests/testthat/test-mcp-analysis-repository.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Add tests for phenotype modes and network no-external guard**

Append to `api/tests/testthat/test-mcp-analysis-service.R`:

```r
test_that("phenotype analysis context validates mode and labels derived analyses", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_corr <- mcp_analysis_repo_get_phenotype_correlations
  assign("mcp_analysis_repo_get_phenotype_correlations", function(...) {
    tibble::tibble(x = "Seizure", x_id = "HP:0001250", y = "Ataxia", y_id = "HP:0001251", value = 0.42)
  }, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_get_phenotype_correlations", old_corr, envir = .GlobalEnv))

  result <- mcp_get_phenotype_analysis_context(mode = "correlations", phenotype = "HP:0001250")
  expect_equal(result$data_class, "curated_derived_analysis")
  expect_equal(result$records[[1]]$value, 0.42)

  err <- tryCatch(
    mcp_get_phenotype_analysis_context(mode = "raw_matrix"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "invalid_input")
})

test_that("gene network context raises temporarily_unavailable when disk cache hit is absent", {
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_has <- mcp_analysis_repo_network_cache_hit
  assign("mcp_analysis_repo_network_cache_hit", function(...) FALSE, envir = .GlobalEnv)
  withr::defer(assign("mcp_analysis_repo_network_cache_hit", old_has, envir = .GlobalEnv))

  err <- tryCatch(
    mcp_get_gene_network_context(gene = "HGNC:61"),
    mcp_tool_error = function(e) unclass(e)
  )
  expect_equal(err$error$code, "temporarily_unavailable")
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because phenotype/network service and repository functions are absent.

- [ ] **Step 3: Add repository helpers**

In `api/functions/mcp-analysis-repository.R`, add bounded helpers:

```r
mcp_analysis_build_phenotype_cluster_input <- function() {
  id_phenotype_ids <- c(
    "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )

  ndd_entity_view_tbl <- pool %>% dplyr::tbl("ndd_entity_view") %>% dplyr::collect()
  primary_reviews <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(is_primary == 1, review_approved == 1) %>%
    dplyr::select(review_id) %>%
    dplyr::collect()
  phenotype_rows <- pool %>% dplyr::tbl("ndd_review_phenotype_connect") %>% dplyr::collect()
  modifier_rows <- pool %>% dplyr::tbl("modifier_list") %>% dplyr::collect()
  phenotype_terms <- pool %>% dplyr::tbl("phenotype_list") %>% dplyr::collect()

  joined <- ndd_entity_view_tbl %>%
    dplyr::left_join(phenotype_rows, by = "entity_id") %>%
    dplyr::left_join(modifier_rows, by = "modifier_id") %>%
    dplyr::left_join(phenotype_terms, by = "phenotype_id") %>%
    dplyr::filter(ndd_phenotype == 1, category == "Definitive") %>%
    dplyr::filter(modifier_name == "present") %>%
    dplyr::filter(review_id %in% primary_reviews$review_id) %>%
    dplyr::select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id, HPO_term, hgnc_id) %>%
    dplyr::group_by(entity_id) %>%
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    dplyr::ungroup() %>%
    unique()

  wider <- joined %>%
    dplyr::mutate(present = "yes") %>%
    dplyr::select(-phenotype_id) %>%
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) %>%
    dplyr::group_by(hgnc_id) %>%
    dplyr::mutate(gene_entity_count = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) %>%
    dplyr::select(-hgnc_id)

  matrix <- wider %>% dplyr::select(-entity_id) %>% as.data.frame()
  row.names(matrix) <- wider$entity_id

  list(
    matrix = matrix,
    entity_gene_map = ndd_entity_view_tbl %>% dplyr::select(entity_id, hgnc_id, symbol)
  )
}

mcp_analysis_repo_get_phenotype_correlations <- function(phenotype = NULL,
                                                         min_abs_correlation = 0.3,
                                                         limit = 25L) {
  if (!exists("generate_phenotype_correlations", mode = "function")) {
    return(NULL)
  }
  melted <- generate_phenotype_correlations(
    filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)",
    min_abs_correlation = min_abs_correlation
  )
  if (is.null(melted) || nrow(melted) == 0L) return(tibble::tibble())
  if (!is.null(phenotype)) {
    melted <- melted %>%
      dplyr::filter(
        x == phenotype | y == phenotype |
          x_id == phenotype | y_id == phenotype |
          stringr::str_detect(x, stringr::fixed(phenotype, ignore_case = TRUE)) |
          stringr::str_detect(y, stringr::fixed(phenotype, ignore_case = TRUE))
      )
  }
  utils::head(melted[order(-abs(melted$value)), ], limit)
}

mcp_analysis_repo_get_network_edges_local <- function(cluster_type = "clusters",
                                                      min_confidence = 400L,
                                                      max_edges = 100L) {
  if (!mcp_analysis_repo_network_cache_hit(cluster_type = cluster_type, min_confidence = min_confidence)) {
    return(NULL)
  }
  network <- gen_network_edges_mem(cluster_type = cluster_type, min_confidence = min_confidence)
  if (!is.null(network$edges) && nrow(network$edges) > max_edges) {
    network$edges <- network$edges[order(-network$edges$confidence), ]
    network$edges <- utils::head(network$edges, max_edges)
  }
  network
}
```

Then add local phenotype-cluster retrieval. This is intentionally not an empty
stub: phenotype clusters are MCA/HCPC-derived from approved phenotype rows and
do not require STRING or external provider calls.

```r
mcp_analysis_repo_get_phenotype_clusters <- function(gene = NULL,
                                                     cluster_id = NULL,
                                                     limit = 25L) {
  if (!exists("gen_mca_clust_obj_mem", mode = "function")) return(tibble::tibble())
  input <- mcp_analysis_build_phenotype_cluster_input()
  if (is.null(input$matrix) || nrow(input$matrix) == 0L) return(tibble::tibble())

  clusters <- gen_mca_clust_obj_mem(input$matrix)
  if (is.null(clusters) || nrow(clusters) == 0L) return(tibble::tibble())

  records <- clusters %>%
    tidyr::unnest(identifiers) %>%
    dplyr::mutate(entity_id = as.integer(entity_id)) %>%
    dplyr::left_join(input$entity_gene_map, by = "entity_id")

  if (!is.null(gene)) {
    resolved <- mcp_resolve_gene_one(gene)
    records <- records %>% dplyr::filter(hgnc_id == resolved$hgnc_id[[1]] | symbol == resolved$symbol[[1]])
  }
  if (!is.null(cluster_id)) {
    records <- records %>% dplyr::filter(as.character(cluster) == as.character(cluster_id))
  }
  utils::head(records, limit)
}

mcp_analysis_repo_get_phenotype_functional_correlations <- function(gene = NULL,
                                                                    limit = 25L) {
  if (!mcp_analysis_repo_network_cache_hit(cluster_type = "clusters", min_confidence = 400L)) {
    return(NULL)
  }
  if (!exists("generate_phenotype_functional_cluster_correlation", mode = "function")) {
    return(NULL)
  }
  # The shared helper is extracted from the current endpoint logic. Returning
  # NULL means MCP should return temporarily_unavailable, not an empty success
  # payload.
  rows <- generate_phenotype_functional_cluster_correlation()
  if (!is.null(gene) && "hgnc_id" %in% names(rows)) {
    resolved <- mcp_resolve_gene_one(gene)
    rows <- rows %>% dplyr::filter(hgnc_id == resolved$hgnc_id[[1]])
  }
  utils::head(rows, limit)
}
```

Extract `generate_phenotype_correlations()` from
`api/endpoints/phenotype_endpoints.R` and
`generate_phenotype_functional_cluster_correlation()` from
`api/endpoints/analysis_endpoints.R` into a shared function file, then update
both endpoints to call the helpers. Do not duplicate endpoint logic in MCP.

- [ ] **Step 4: Add service functions**

In `api/services/mcp-service.R`, add:

```r
mcp_get_phenotype_analysis_context <- function(mode,
                                               gene = NULL,
                                               phenotype = NULL,
                                               min_abs_correlation = 0.3,
                                               cluster_id = NULL,
                                               limit = 25L,
                                               include_cached_llm_summaries = TRUE) {
  mode <- mcp_validate_enum(mode, c("correlations", "clusters", "phenotype_functional_correlations"), "mode")
  limit <- mcp_validate_limit(limit, default = 25L, max = 50L)
  min_abs_correlation <- suppressWarnings(as.numeric(min_abs_correlation))
  if (is.na(min_abs_correlation) || min_abs_correlation < 0 || min_abs_correlation > 1) {
    stop(mcp_error("invalid_input", "min_abs_correlation must be between 0 and 1", list(argument = "min_abs_correlation")))
  }
  envelope <- mcp_analysis_provenance("curated_derived_analysis", "SysNDD phenotype analysis", "approved primary review phenotypes", "deterministic_analysis")

  records <- switch(
    mode,
    correlations = mcp_analysis_repo_get_phenotype_correlations(phenotype = phenotype, min_abs_correlation = min_abs_correlation, limit = limit),
    clusters = mcp_analysis_repo_get_phenotype_clusters(gene = gene, cluster_id = cluster_id, limit = limit),
    phenotype_functional_correlations = mcp_analysis_repo_get_phenotype_functional_correlations(gene = gene, limit = limit)
  )
  if (is.null(records)) {
    stop(mcp_error(
      "temporarily_unavailable",
      "Requested phenotype analysis mode is not available from shared helper/cache-safe data.",
      list(argument = "mode")
    ))
  }

  c(envelope, list(
    mode = mode,
    records = mcp_rows_to_records(records),
    cached_llm_summaries = list(),
    meta = list(limit = limit, returned = nrow(records), min_abs_correlation = min_abs_correlation)
  ))
}

mcp_get_gene_network_context <- function(gene = NULL,
                                         cluster_type = "clusters",
                                         min_confidence = 400L,
                                         max_edges = 100L,
                                         include_cached_llm_summaries = TRUE) {
  cluster_type <- mcp_validate_enum(cluster_type, c("clusters", "subclusters"), "cluster_type")
  min_confidence <- suppressWarnings(as.integer(min_confidence))
  max_edges <- mcp_validate_limit(max_edges, default = 100L, max = 250L, name = "max_edges")
  if (is.na(min_confidence) || min_confidence < 0L || min_confidence > 1000L) {
    stop(mcp_error("invalid_input", "min_confidence must be between 0 and 1000", list(argument = "min_confidence")))
  }
  envelope <- mcp_analysis_provenance("curated_derived_analysis", "SysNDD STRING-derived network analysis", "local STRING/memoise cache", "deterministic_analysis")
  network <- mcp_analysis_repo_get_network_edges_local(cluster_type = cluster_type, min_confidence = min_confidence, max_edges = max_edges)
  if (is.null(network)) {
    stop(mcp_error(
      "temporarily_unavailable",
      "Gene network context is not available from local cache without initializing STRINGdb.",
      list(argument = "gene_network")
    ))
  }
  c(envelope, list(
    section_status = "available",
    nodes = mcp_rows_to_records(network$nodes),
    edges = mcp_rows_to_records(network$edges),
    meta = c(network$metadata %||% list(), list(cluster_type = cluster_type, min_confidence = min_confidence, max_edges = max_edges))
  ))
}
```

- [ ] **Step 5: Run tests and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/functions/mcp-analysis-repository.R api/services/mcp-service.R api/tests/testthat/test-mcp-analysis-repository.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat: add MCP phenotype and network analysis services"
```

## Task 6: Gene Research Context Aggregator

**Files:**
- Modify: `api/services/mcp-service.R`
- Modify: `api/tests/testthat/test-mcp-analysis-service.R`

- [ ] **Step 1: Add failing aggregation tests**

Append:

```r
test_that("gene research context aggregates requested sections with explicit section statuses", {
  source("../../functions/mcp-repository.R")
  source("../../functions/mcp-analysis-repository.R")
  source("../../services/mcp-service.R")

  old_gene <- mcp_get_gene_context
  old_ndd <- mcp_get_nddscore_context
  old_comp <- mcp_get_curation_comparison_context
  old_net <- mcp_get_gene_network_context
  assign("mcp_get_gene_context", function(gene, ...) list(schema_version = MCP_SCHEMA_VERSION, gene = list(hgnc_id = "HGNC:61", symbol = "ABCD1"), entities = list()), envir = .GlobalEnv)
  assign("mcp_get_nddscore_context", function(gene, ...) list(data_class = "ml_prediction", gene = list(hgnc_id = "HGNC:61")), envir = .GlobalEnv)
  assign("mcp_get_curation_comparison_context", function(gene, ...) list(data_class = "curated_derived_analysis", rows = list()), envir = .GlobalEnv)
  assign("mcp_get_gene_network_context", function(gene, ...) list(section_status = "temporarily_unavailable", edges = list()), envir = .GlobalEnv)
  withr::defer({
    assign("mcp_get_gene_context", old_gene, envir = .GlobalEnv)
    assign("mcp_get_nddscore_context", old_ndd, envir = .GlobalEnv)
    assign("mcp_get_curation_comparison_context", old_comp, envir = .GlobalEnv)
    assign("mcp_get_gene_network_context", old_net, envir = .GlobalEnv)
  })

  result <- mcp_get_gene_research_context(
    gene = "HGNC:61",
    sections = c("curated", "comparison", "nddscore", "gene_network")
  )

  expect_equal(result$gene$symbol, "ABCD1")
  expect_equal(result$section_status$curated, "available")
  expect_equal(result$section_status$nddscore, "available")
  expect_equal(result$section_status$gene_network, "temporarily_unavailable")
  expect_false(is.null(result$sections$nddscore))
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: FAIL because `mcp_get_gene_research_context()` does not exist.

- [ ] **Step 3: Implement the aggregator**

Add:

```r
MCP_GENE_RESEARCH_SECTIONS <- c(
  "curated",
  "comparison",
  "nddscore",
  "phenotype_clusters",
  "phenotype_correlations",
  "phenotype_functional_correlations",
  "gene_network",
  "cached_llm_summaries",
  "external_identifiers"
)

mcp_section_call <- function(name, fn) {
  tryCatch(
    list(status = "available", value = fn()),
    mcp_tool_error = function(e) {
      payload <- mcp_error_payload(e)
      status <- if (identical(payload$error$code, "temporarily_unavailable")) "temporarily_unavailable" else "error"
      list(status = status, value = payload)
    },
    error = function(e) list(status = "temporarily_unavailable", value = mcp_error_payload(mcp_error("temporarily_unavailable", conditionMessage(e))))
  )
}

mcp_gene_external_identifier_refs <- function(hgnc_id) {
  rows <- mcp_analysis_repo_get_gene_external_identifiers(hgnc_id)
  if (is.null(rows) || nrow(rows) == 0L) return(list())
  gene <- mcp_row_to_list(rows[1, , drop = FALSE])
  id_fields <- c("omim_id", "ensembl_gene_id", "uniprot_ids", "STRING_id", "mgd_id", "rgd_id", "mane_select", "alphafold_id")
  refs <- lapply(id_fields[id_fields %in% names(gene)], function(field) {
    value <- gene[[field]]
    if (is.null(value) || !nzchar(as.character(value))) return(NULL)
    c(
      mcp_analysis_provenance("external_reference_identifier", "SysNDD gene metadata", "non_alt_loci_set", "sysndd_import_pipeline"),
      list(field = field, value = value)
    )
  })
  Filter(Negate(is.null), refs)
}

mcp_get_gene_research_context <- function(gene,
                                          sections = NULL,
                                          response_mode = "compact",
                                          entity_limit = 10L,
                                          publication_limit = 5L,
                                          include_cached_llm_summaries = TRUE) {
  gene <- mcp_validate_query(gene, min_chars = 2L, max_chars = 100L, argument = "gene")
  sections <- sections %||% c("curated", "comparison", "nddscore", "phenotype_correlations", "gene_network", "external_identifiers")
  invalid <- setdiff(sections, MCP_GENE_RESEARCH_SECTIONS)
  if (length(invalid) > 0L) {
    stop(mcp_error("invalid_input", sprintf("Unsupported section: %s", invalid[[1]]), list(argument = "sections", allowed_values = as.list(MCP_GENE_RESEARCH_SECTIONS))))
  }

  section_status <- setNames(as.list(rep("not_requested", length(MCP_GENE_RESEARCH_SECTIONS))), MCP_GENE_RESEARCH_SECTIONS)
  output_sections <- list()

  curated <- mcp_section_call("curated", function() {
    mcp_get_gene_context(
      gene,
      include_entities = TRUE,
      include_comparisons = FALSE,
      entity_limit = entity_limit,
      response_mode = response_mode,
      expand = "none",
      publication_limit = publication_limit
    )
  })
  section_status$curated <- curated$status
  output_sections$curated <- curated$value
  resolved_gene <- curated$value$gene %||% list()

  if ("comparison" %in% sections) {
    comparison <- mcp_section_call("comparison", function() mcp_get_curation_comparison_context(gene = gene, limit = 25L))
    section_status$comparison <- comparison$status
    output_sections$comparison <- comparison$value
  }
  if ("nddscore" %in% sections) {
    nddscore <- mcp_section_call("nddscore", function() mcp_get_nddscore_context(gene = gene))
    section_status$nddscore <- nddscore$status
    output_sections$nddscore <- nddscore$value
  }
  if ("phenotype_correlations" %in% sections) {
    phenotype <- mcp_section_call("phenotype_correlations", function() mcp_get_phenotype_analysis_context(mode = "correlations", gene = gene, limit = 25L))
    section_status$phenotype_correlations <- phenotype$status
    output_sections$phenotype_correlations <- phenotype$value
  }
  if ("phenotype_clusters" %in% sections) {
    clusters <- mcp_section_call("phenotype_clusters", function() mcp_get_phenotype_analysis_context(mode = "clusters", gene = gene, limit = 25L))
    section_status$phenotype_clusters <- clusters$status
    output_sections$phenotype_clusters <- clusters$value
  }
  if ("phenotype_functional_correlations" %in% sections) {
    pfc <- mcp_section_call("phenotype_functional_correlations", function() mcp_get_phenotype_analysis_context(mode = "phenotype_functional_correlations", gene = gene, limit = 25L))
    section_status$phenotype_functional_correlations <- pfc$status
    output_sections$phenotype_functional_correlations <- pfc$value
  }
  if ("gene_network" %in% sections) {
    network <- mcp_section_call("gene_network", function() mcp_get_gene_network_context(gene = gene))
    section_status$gene_network <- network$status
    output_sections$gene_network <- network$value
  }
  if ("cached_llm_summaries" %in% sections && isTRUE(include_cached_llm_summaries)) {
    cluster_records <- output_sections$phenotype_clusters$records %||% list()
    cluster_numbers <- unique(vapply(cluster_records, function(x) as.integer(x$cluster %||% NA_integer_), integer(1)))
    cluster_numbers <- cluster_numbers[!is.na(cluster_numbers)]
    summaries <- mcp_section_call("cached_llm_summaries", function() {
      if (length(cluster_numbers) == 0L) {
        list(mcp_llm_cache_miss("phenotype"))
      } else {
        mcp_get_cached_llm_summaries("phenotype", cluster_numbers = cluster_numbers, limit = 5L)
      }
    })
    section_status$cached_llm_summaries <- summaries$status
    output_sections$cached_llm_summaries <- summaries$value
  }
  if ("external_identifiers" %in% sections) {
    section_status$external_identifiers <- "available"
    output_sections$external_identifiers <- mcp_gene_external_identifier_refs(resolved_gene$hgnc_id)
  }

  list(
    schema_version = MCP_SCHEMA_VERSION,
    gene = resolved_gene,
    sections = output_sections,
    section_status = section_status,
    meta = list(
      response_mode = response_mode,
      llm_generation = "never",
      cached_llm_summaries = if (isTRUE(include_cached_llm_summaries)) "validated cache only" else "not_requested",
      live_external_provider_calls = "never"
    )
  )
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat: add MCP gene research context"
```

## Task 7: Tool Registry, Schemas, Resources, And Smoke Test

**Files:**
- Modify: `api/services/mcp-tools.R`
- Modify: `api/tests/testthat/test-mcp-tools.R`
- Modify: `api/config/mcp/resources/sysndd-schema.md`
- Modify: `api/scripts/mcp-smoke.R`

- [ ] **Step 1: Update registry tests for the six new tools**

Modify the expected tool set in `api/tests/testthat/test-mcp-tools.R` to include:

```r
c(
  "get_sysndd_analysis_catalog",
  "get_gene_research_context",
  "get_nddscore_context",
  "get_curation_comparison_context",
  "get_phenotype_analysis_context",
  "get_gene_network_context"
)
```

Add assertions:

```r
test_that("MCP analysis tools advertise labels and do not expose LLM generation", {
  skip_if_not_installed("ellmer")

  source("../../services/mcp-service.R")
  source("../../services/mcp-tools.R")

  registry <- mcp_build_tool_registry(output_mode = "json_text")
  metadata <- mcp_tool_metadata(registry$tools)
  names <- vapply(metadata, `[[`, character(1), "name")

  for (tool_name in c("get_nddscore_context", "get_gene_research_context")) {
    item <- metadata[[which(names == tool_name)]]
    expect_true(isTRUE(item$annotations$readOnlyHint))
    expect_false(isTRUE(item$annotations$openWorldHint))
    expect_false(any(grepl("prompt|gemini|generate", names(item$inputSchema$properties), ignore.case = TRUE)))
    expect_false(is.null(item$outputSchema))
  }
})
```

- [ ] **Step 2: Run and confirm RED**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
```

Expected: FAIL because tools are not registered.

- [ ] **Step 3: Register tools in `mcp_build_tool_registry()`**

In `api/services/mcp-tools.R`, add wrapped functions for each new service:

```r
get_sysndd_analysis_catalog_fun <- function(include_unavailable = FALSE) {
  mcp_get_sysndd_analysis_catalog(include_unavailable = include_unavailable)
}

get_gene_research_context_fun <- function(gene = NULL,
                                          sections = NULL,
                                          response_mode = "compact",
                                          entity_limit = 10L,
                                          publication_limit = 5L,
                                          include_cached_llm_summaries = TRUE) {
  if (is.null(gene)) stop(mcp_error("invalid_input", "Missing required parameter 'gene'", list(argument = "gene")))
  mcp_get_gene_research_context(
    gene = gene,
    sections = sections,
    response_mode = response_mode,
    entity_limit = entity_limit,
    publication_limit = publication_limit,
    include_cached_llm_summaries = include_cached_llm_summaries
  )
}

get_nddscore_context_fun <- function(gene = NULL,
                                     mode = NULL,
                                     risk_tier = NULL,
                                     confidence_tier = NULL,
                                     known_sysndd_gene = NULL,
                                     hpo_terms = NULL,
                                     search = NULL,
                                     sort = "rank",
                                     page = 1L,
                                     page_size = 25L) {
  mcp_get_nddscore_context(
    gene = gene,
    mode = mode,
    risk_tier = risk_tier,
    confidence_tier = confidence_tier,
    known_sysndd_gene = known_sysndd_gene,
    hpo_terms = hpo_terms,
    search = search,
    sort = sort,
    page = page,
    page_size = page_size
  )
}
```

Add equivalent wrappers for `get_curation_comparison_context_fun`,
`get_phenotype_analysis_context_fun`, and `get_gene_network_context_fun`.

Register each wrapper with `ellmer::tool()` using descriptions that explicitly
include:

- "Read-only"
- "No LLM generation"
- "NDDScore is ML prediction, not curated evidence" for NDDScore.
- "Cached LLM summaries are admin-generated cache-only" for relevant tools.

Add each wrapper to `registry$tool_functions`.

- [ ] **Step 4: Add output schema names**

Extend `mcp_output_schema()` with cases for the six new tool names. Each schema
must require `schema_version` and allow `error`. For `get_nddscore_context`,
include `data_class`, `curation_effect`, `not_evidence_tier`, and `notice`.

- [ ] **Step 5: Update resources and capabilities**

Update `api/config/mcp/resources/sysndd-schema.md` and
`mcp_get_sysndd_capabilities()` with:

- analysis catalog workflow
- gene research workflow
- data-class definitions
- NDDScore as ML prediction and not evidence tier
- cache-only LLM summary rule
- live external calls disabled
- network cache-unavailable behavior

- [ ] **Step 6: Update smoke test**

In `api/scripts/mcp-smoke.R`, add calls after existing happy-path checks:

```r
call_tool("get_sysndd_analysis_catalog", list())
gene <- "PNKP"
call_tool("get_gene_research_context", list(gene = gene, sections = c("curated", "nddscore")))
nddscore <- call_tool("get_nddscore_context", list(gene = gene), expect_error = TRUE)
stopifnot(isTRUE(is.null(nddscore$isError) || nddscore$isError %in% c(TRUE, FALSE)))
bad_mode <- call_tool("get_phenotype_analysis_context", list(mode = "raw_matrix"), expect_error = TRUE)
stopifnot(isTRUE(bad_mode$isError))
```

Use an existing approved public gene from `search_sysndd(query = "PNKP", types =
c("gene"))` and assert section shape rather than exact NDDScore content, because
local databases may not have an active NDDScore release.

- [ ] **Step 7: Run tool tests and smoke**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
```

Then run the existing MCP smoke command used by the repository:

```bash
make test-api-fast
```

Expected: tool/service tests pass; fast API gate passes. Run the local MCP smoke target if present in the working branch.

- [ ] **Step 8: Commit**

```bash
git add api/services/mcp-tools.R api/services/mcp-service.R api/config/mcp/resources/sysndd-schema.md api/scripts/mcp-smoke.R api/tests/testthat/test-mcp-tools.R api/tests/testthat/test-mcp-analysis-service.R
git commit -m "feat: register MCP analysis research tools"
```

## Task 8: Documentation And Guardrail Verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`

- [ ] **Step 1: Add durable MCP analysis guidance to `AGENTS.md`**

Add a short subsection under the MCP sidecar section:

```markdown
`MCP_SCHEMA_VERSION` is `1.2`. MCP analysis tools expose NDDScore, curation
comparisons, phenotype analyses, gene network context, gene research context,
and current validated cached LLM summaries only. All analysis payloads must
label their data class:
`curated_sysndd_evidence`, `curated_derived_analysis`, `ml_prediction`,
`llm_generated_summary`, `external_reference_identifier`, or
`operational_metadata`. NDDScore is always an ML prediction layer, separate from
curated SysNDD evidence, not an evidence tier, and must not alter curated
classifications. LLM summaries exposed through MCP are admin-generated,
cache-only, current, and validated by default; MCP must never expose an LLM
prompt/query endpoint or trigger Gemini/LLM generation. MCP must not call live
external gene providers; external IDs stored on gene rows may be shown only as
external reference identifiers.
```

- [ ] **Step 2: Update human docs**

In `documentation/03-api.qmd`, document the new MCP tools and the data-class
contract.

In `documentation/08-development.qmd`, add local verification commands:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
make test-api-fast
```

In `documentation/09-deployment.qmd`, document that these MCP tools are
read-only, cache-only for LLM summaries, and live-external-disabled.

- [ ] **Step 3: Run guardrail searches**

Run:

```bash
rg -n "chat_google_gemini|get_or_generate_summary|get_cluster_summary|external_proxy|gnomad|clinvar|uniprot|alphafold|mgi|rgd" api/functions/mcp-analysis-repository.R api/services/mcp-service.R api/services/mcp-tools.R
```

Expected:

- No matches for `chat_google_gemini`, `get_or_generate_summary`, or
  `get_cluster_summary`.
- No live external proxy calls in MCP analysis files.
- Text-only mentions are acceptable only in descriptions that say the calls are
  disabled.

- [ ] **Step 4: Run final verification**

Run:

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-repository.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-analysis-service.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"
cd ..
make test-api-fast
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md documentation/03-api.qmd documentation/08-development.qmd documentation/09-deployment.qmd
git commit -m "docs: document MCP analysis data boundaries"
```

## Final Review Checklist

- [ ] `tools/list` includes the six new analysis tools and no LLM prompt/query/generation tools.
- [ ] All new tools have read-only annotations and output schemas.
- [ ] NDDScore payloads always include `data_class = "ml_prediction"`, `curation_effect = "none"`, and `not_evidence_tier = true`.
- [ ] LLM summary payloads always include `data_class = "llm_generated_summary"`, `cache_only = true`, and either cached metadata or `summary_available = false`.
- [ ] MCP analysis code does not call Gemini, `get_or_generate_summary()`, `get_cluster_summary()`, external proxy helpers, raw SQL/R execution tools, or write helpers.
- [ ] Gene network context returns `temporarily_unavailable` instead of initializing STRINGdb when local/cache-safe data is not available.
- [ ] `get_gene_research_context(gene = "HGNC:61")` returns labeled sections and per-section status.
- [ ] Durable docs explain that ML and LLM data are not curated SysNDD evidence.
