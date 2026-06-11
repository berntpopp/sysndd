# tests/testthat/test-mcp-search-analysis-fixes.R
#
# Regression tests for issue #353 MCP search + derived-analysis benchmark fixes:
#   - structuredContent renders null scalars as JSON null (not `{}`)
#   - top-level publication_type is promoted from the first non-empty link row
#   - find_entities_by_* echo the requested term + resolution flag on zero results
#   - get_gene_research_context collapses all snapshot-unavailable codes to
#     "temporarily_unavailable" instead of falling through to "error"

test_that("structuredContent serializes null scalars as JSON null, not {}", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-tool-core.R"), local = TRUE)
  source(file.path(api_dir, "services", "mcp-tools.R"), local = TRUE)

  payload <- list(
    schema_version = MCP_SCHEMA_VERSION,
    publication_type = NULL,
    title = "Example"
  )

  response <- mcp_tool_result_response(1L, payload)
  structured <- response$result$structuredContent

  # The structured form must be a parsed list mirroring the null-safe text, so a
  # NULL scalar round-trips to JSON null rather than the `{}` transport artifact.
  expect_true("publication_type" %in% names(structured))
  expect_null(structured$publication_type)

  rendered <- jsonlite::toJSON(structured, auto_unbox = TRUE, null = "null", na = "null")
  expect_true(grepl("\"publication_type\":null", rendered, fixed = TRUE))
  expect_false(grepl("\"publication_type\":{}", rendered, fixed = TRUE))
})

test_that("mcp_first_nonempty_value skips NA and empty leading values", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)

  expect_equal(mcp_first_nonempty_value(c(NA, "", "Review", "Original")), "Review")
  expect_null(mcp_first_nonempty_value(c(NA, "", "  ")))
  expect_null(mcp_first_nonempty_value(NULL))
  expect_null(mcp_first_nonempty_value(character()))
})

test_that("get_publication_context promotes publication_type from a non-NULL link row", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "functions", "mcp-repository.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-record-service.R"), local = .GlobalEnv)

  old_repo <- get0("mcp_repo_get_publication_context", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_repo_get_publication_context", function(publication_id) {
    tibble::tibble(
      publication_id = c("123", "123"),
      Title = c("Example", "Example"),
      Abstract = c(NA_character_, NA_character_),
      Journal = c("J", "J"),
      Publication_date = c("2020", "2020"),
      publication_date_source = c(NA_character_, NA_character_),
      Lastname = c("Doe", "Doe"),
      Firstname = c("J", "J"),
      Keywords = c(NA_character_, NA_character_),
      entity_id = c(10L, 11L),
      symbol = c("AAA", "BBB"),
      hgnc_id = c("1", "2"),
      disease_ontology_name = c("d1", "d2"),
      category = c("Definitive", "Definitive"),
      # First link row has a NULL/NA publication_type; the second carries "Review".
      publication_type = c(NA_character_, "Review"),
      curation_review_date = c("2021", "2021")
    )
  }, envir = .GlobalEnv)
  on.exit(
    {
      if (is.null(old_repo)) {
        rm("mcp_repo_get_publication_context", envir = .GlobalEnv)
      } else {
        assign("mcp_repo_get_publication_context", old_repo, envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  result <- mcp_get_publication_context("123", abstract_mode = "metadata")

  # Top-level scalar must be the first non-empty link value, not the NULL first row.
  expect_equal(result$publication_type, "Review")
  # Per-link values remain intact for callers that need the full distribution.
  expect_true("Review" %in% unlist(result$publication_types))
})

test_that("find_entities_by_phenotype echoes the term and resolution flag on zero hits", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-record-service.R"), local = .GlobalEnv)

  empty_rows <- tibble::tibble(
    entity_id = integer(),
    symbol = character(),
    hgnc_id = character(),
    disease_ontology_id_version = character(),
    disease_ontology_name = character(),
    hpo_mode_of_inheritance_term_name = character(),
    category = character(),
    ndd_phenotype_word = character(),
    phenotype_id = character(),
    HPO_term = character(),
    modifier_name = character()
  )

  old_find <- get0("mcp_repo_find_entities_by_phenotype", envir = .GlobalEnv, ifnotfound = NULL)
  old_count <- get0("mcp_repo_count_entities_by_phenotype", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_repo_find_entities_by_phenotype", function(...) empty_rows, envir = .GlobalEnv)
  assign("mcp_repo_count_entities_by_phenotype", function(...) 0L, envir = .GlobalEnv)
  on.exit(
    {
      if (is.null(old_find)) rm("mcp_repo_find_entities_by_phenotype", envir = .GlobalEnv) else assign("mcp_repo_find_entities_by_phenotype", old_find, envir = .GlobalEnv)
      if (is.null(old_count)) rm("mcp_repo_count_entities_by_phenotype", envir = .GlobalEnv) else assign("mcp_repo_count_entities_by_phenotype", old_count, envir = .GlobalEnv)
    },
    add = TRUE
  )

  result <- mcp_find_entities_by_phenotype("HP:9999999")
  expect_equal(result$meta$returned, 0L)
  expect_equal(result$meta$query_echo, "HP:9999999")
  expect_false(result$meta$query_resolved)
  expect_equal(result$resolved_phenotypes, list())
  expect_equal(result$phenotype, "HP:9999999")
})

test_that("find_entities_by_disease echoes the term and resolution flag on zero hits", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-record-service.R"), local = .GlobalEnv)

  empty_rows <- tibble::tibble(
    entity_id = integer(),
    symbol = character(),
    hgnc_id = character(),
    disease_ontology_id_version = character(),
    disease_ontology_name = character(),
    hpo_mode_of_inheritance_term_name = character(),
    category = character(),
    ndd_phenotype_word = character()
  )

  old_find <- get0("mcp_repo_find_entities_by_disease", envir = .GlobalEnv, ifnotfound = NULL)
  old_count <- get0("mcp_repo_count_entities_by_disease", envir = .GlobalEnv, ifnotfound = NULL)
  assign("mcp_repo_find_entities_by_disease", function(...) empty_rows, envir = .GlobalEnv)
  assign("mcp_repo_count_entities_by_disease", function(...) 0L, envir = .GlobalEnv)
  on.exit(
    {
      if (is.null(old_find)) rm("mcp_repo_find_entities_by_disease", envir = .GlobalEnv) else assign("mcp_repo_find_entities_by_disease", old_find, envir = .GlobalEnv)
      if (is.null(old_count)) rm("mcp_repo_count_entities_by_disease", envir = .GlobalEnv) else assign("mcp_repo_count_entities_by_disease", old_count, envir = .GlobalEnv)
    },
    add = TRUE
  )

  result <- mcp_find_entities_by_disease("nonexistent disorder")
  expect_equal(result$meta$returned, 0L)
  expect_equal(result$disease, "nonexistent disorder")
  expect_equal(result$meta$query_echo, "nonexistent disorder")
  expect_false(result$meta$query_resolved)
  expect_equal(result$resolved_diseases, list())
})

test_that("research-context sections map all snapshot-unavailable codes to temporarily_unavailable", {
  api_dir <- get_api_dir()
  source(file.path(api_dir, "services", "mcp-service.R"), local = .GlobalEnv)
  source(file.path(api_dir, "services", "mcp-research-context-service.R"), local = .GlobalEnv)

  make_section <- function(code) {
    mcp_section_call("phenotype", function() {
      stop(mcp_error(code, "snapshot not serviceable", list(argument = "mode")))
    })
  }

  for (code in c("snapshot_missing", "snapshot_stale", "source_version_mismatch", "temporarily_unavailable")) {
    section <- make_section(code)
    expect_equal(section$status, "temporarily_unavailable")
    # The specific code is preserved in the section value for callers that need it.
    expect_equal(section$value$error$code, code)
  }

  # A non-snapshot recoverable error still surfaces as "error".
  other <- mcp_section_call("phenotype", function() {
    stop(mcp_error("invalid_input", "bad mode", list(argument = "mode")))
  })
  expect_equal(other$status, "error")
})
