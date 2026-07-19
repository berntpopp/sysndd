# tests/testthat/test-unit-endpoint-functions.R
# Tests for pure aspects of api/functions/endpoint-functions.R and the
# phenotype/panels domain modules split out of it (#346 Wave 4 Task 6):
#   - functions/phenotype-endpoint-functions.R (generate_phenotype_entities_list)
#   - functions/panels-endpoint-functions.R (generate_panels_list)
#
# These functions rely heavily on database access, so we test:
# 1. Input parameter handling through helper function integration
# 2. Return structure validation patterns
# 3. Helper function dependencies (already tested in test-unit-helper-functions.R)
# 4. Direct behavior against a real test DB when available (skip on host, which
#    has no RMariaDB): filter/sort validation, approved-view sourcing, empty/
#    meta/xlsx-compatible shape, and injection-rejecting identifiers.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(tidyr)
library(DBI)

# Source helper functions first (they are dependencies)
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/endpoint-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}

# Source helper functions which endpoint-functions.R depends on
source(file.path(api_dir, "functions", "helper-functions.R"))
# validate_query_column() (used by generate_sort_expressions/
# generate_filter_expressions) signals rejection via stop_for_bad_request().
source(file.path(api_dir, "core", "errors.R"))

# Direct-source both modules that used to live in endpoint-functions.R so the
# structural/text-based assertions below can target the module each function
# actually lives in now. helper-functions.R (sourced above) already provides
# response-helpers.R / data-helpers.R (generate_filter_expressions,
# generate_sort_expressions, generate_xlsx_bin, ...) as transitive dependencies.
source(file.path(api_dir, "functions", "phenotype-endpoint-functions.R"))
source(file.path(api_dir, "functions", "panels-endpoint-functions.R"))
# Single mapping authority: category normalization defers to the real function
# (no local case_when reimplementation), see test below (#583).
source(file.path(api_dir, "functions", "category-normalization.R"))

# Note: endpoint-functions.R has global dependencies (pool, dw)
# We test it by examining structure and testing through helper integration

# =============================================================================
# Return structure validation tests
# =============================================================================

# Endpoint list-generator source files, spanning the #346 Wave 4 Task 6 split.
endpoint_module_files <- c(
  file.path(api_dir, "functions", "endpoint-functions.R"),
  file.path(api_dir, "functions", "phenotype-endpoint-functions.R"),
  file.path(api_dir, "functions", "panels-endpoint-functions.R")
)

test_that("endpoint return structure follows expected pattern", {
  # All endpoint functions should return a list with: links, meta, data
  # We verify this by examining the function code structure, across every
  # module the original endpoint-functions.R file was split into.
  endpoint_code <- unlist(lapply(endpoint_module_files, readLines))

  # Check for expected return structure
  return_patterns <- grep("return_list\\s*<-\\s*list\\(", endpoint_code, value = TRUE)

  expect_true(length(return_patterns) > 0)

  has_links <- any(grepl("links\\s*=\\s*links", endpoint_code))
  has_meta <- any(grepl("meta\\s*=\\s*meta", endpoint_code))
  has_data <- any(grepl("data\\s*=", endpoint_code))

  expect_true(has_links, "Endpoint functions should return 'links'")
  expect_true(has_meta, "Endpoint functions should return 'meta'")
  expect_true(has_data, "Endpoint functions should return 'data'")
})

test_that("endpoint functions use consistent unique identifiers", {
  # Check that endpoints use appropriate unique identifiers for pagination,
  # across every module the original endpoint-functions.R file was split into.
  endpoint_code <- unlist(lapply(endpoint_module_files, readLines))

  # Look for unique_id parameter in sort expressions
  unique_id_patterns <- grep("unique_id\\s*=\\s*\"", endpoint_code, value = TRUE)

  # Should find unique identifiers in code
  expect_true(length(unique_id_patterns) > 0)

  # Check for expected identifiers
  has_symbol <- any(grepl("\"symbol\"", unique_id_patterns))
  has_entity_id <- any(grepl("\"entity_id\"", unique_id_patterns))

  expect_true(has_symbol || has_entity_id,
              "Endpoints should use symbol or entity_id as unique identifier")
})

test_that("generate_phenotype_entities_list moved to the phenotype module", {
  phenotype_code <- readLines(file.path(api_dir, "functions", "phenotype-endpoint-functions.R"))
  endpoint_code <- readLines(file.path(api_dir, "functions", "endpoint-functions.R"))
  expect_true(any(grepl("^generate_phenotype_entities_list\\s*<-\\s*function", phenotype_code)))
  expect_false(any(grepl("^generate_phenotype_entities_list\\s*<-\\s*function", endpoint_code)))
})

test_that("phenotype module sources the review-approved connect view (migration 042)", {
  # Migration 042 gated ndd_review_phenotype_connect_view on review_approved = 1
  # to stop unapproved review content leaking through the public phenotype
  # browse/count/correlation endpoints; the split must keep reading the
  # approved *_view, never the raw ndd_review_phenotype_connect table.
  phenotype_text <- paste(
    readLines(file.path(api_dir, "functions", "phenotype-endpoint-functions.R")),
    collapse = " "
  )
  expect_match(phenotype_text, "ndd_review_phenotype_connect_view")
  expect_match(phenotype_text, "ndd_entity_view")
  expect_false(grepl("tbl\\(\"ndd_review_phenotype_connect\"\\)", phenotype_text))
})

# =============================================================================
# Parameter validation tests
# =============================================================================

test_that("sort expression parsing works for endpoint default sorts", {
  # Test the sort parameters used by endpoint functions
  sort_exprs <- generate_sort_expressions("symbol", unique_id = "symbol")
  expect_true("symbol" %in% sort_exprs)

  sort_exprs2 <- generate_sort_expressions("entity_id", unique_id = "entity_id")
  expect_true("entity_id" %in% sort_exprs2)

  sort_exprs3 <- generate_sort_expressions("category_id,-n", unique_id = "category_id")
  expect_true("category_id" %in% sort_exprs3)
  expect_true("desc(n)" %in% sort_exprs3)
})

test_that("filter expressions handle empty/null correctly", {
  # Endpoint functions pass various filter states
  expect_equal(generate_filter_expressions(""), "")
  expect_equal(generate_filter_expressions("null"), "")
})

test_that("URLdecoded filters are handled", {
  # Some endpoints URLdecode filters before processing
  # Test that our helper still works with decoded strings
  filter_decoded <- "equals(category,'Definitive')"
  filter_exprs <- generate_filter_expressions(filter_decoded)

  expect_true(length(filter_exprs) > 0)
  expect_true(any(grepl("Definitive", filter_exprs)))
})

# =============================================================================
# generate_tibble_fspec() integration
# =============================================================================

test_that("fspec generation works with endpoint-like data", {
  # Create tibble similar to endpoint output
  endpoint_like_data <- tibble(
    entity_id = 1:5,
    symbol = c("BRCA1", "TP53", "EGFR", "KRAS", "PTEN"),
    category = c("Definitive", "Definitive", "Moderate", "Limited", "Definitive"),
    ndd_phenotype_word = c("Yes", "Yes", "No", "Yes", "No")
  )

  fspec_result <- generate_tibble_fspec(
    endpoint_like_data,
    "entity_id,symbol,category,ndd_phenotype_word"
  )

  expect_true("fspec" %in% names(fspec_result))
  expect_true("key" %in% names(fspec_result$fspec))
  expect_true("filterable" %in% names(fspec_result$fspec))
  expect_true("sortable" %in% names(fspec_result$fspec))
})

test_that("fspec generation handles comparison-table-like data", {
  # Test data similar to generate_comparisons_list output
  comparison_data <- tibble(
    symbol = c("BRCA1", "TP53", "EGFR"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3"),
    SysNDD = c("Definitive", "Definitive", "Moderate"),
    gene2phenotype = c("Definitive", "not listed", "Moderate"),
    panelapp = c("Definitive", "Definitive", "not listed")
  )

  fspec_result <- generate_tibble_fspec(
    comparison_data,
    "symbol,SysNDD,gene2phenotype,panelapp"
  )

  expect_true("fspec" %in% names(fspec_result))
  # fspec is a tibble with a count column showing counts for each field
  expect_true("count" %in% names(fspec_result$fspec))
  expect_equal(nrow(fspec_result$fspec), 4)  # 4 fields specified
})

# =============================================================================
# Cursor pagination integration
# =============================================================================

test_that("cursor pagination works with endpoint-like data", {
  endpoint_like_data <- tibble(
    entity_id = 1:20,
    symbol = paste0("GENE", 1:20)
  )
  # Test pagination with page_size
  pag_result <- generate_cursor_pag_inf(
    endpoint_like_data,
    page_size = 5,
    page_after = 0,
    pagination_identifier = "entity_id"
  )
  expect_equal(nrow(pag_result$data), 5)
  expect_true("meta" %in% names(pag_result))
  expect_equal(pag_result$meta$perPage, 5)
  expect_equal(pag_result$meta$totalItems, 20)
})
test_that("cursor pagination handles 'all' page size", {
  # Endpoints use 'all' as a special page_size value
  endpoint_like_data <- tibble(
    symbol = c("BRCA1", "TP53", "EGFR"),
    category = c("Definitive", "Definitive", "Moderate")
  )

  pag_result <- generate_cursor_pag_inf(
    endpoint_like_data,
    page_size = "all",
    page_after = 0,
    pagination_identifier = "symbol"
  )

  expect_equal(nrow(pag_result$data), 3)
  expect_equal(pag_result$meta$totalItems, 3)
})

# =============================================================================
# Field selection integration
# =============================================================================

test_that("field selection works with endpoint defaults", {
  # Test field selection similar to endpoint usage
  endpoint_data <- tibble(
    entity_id = 1:5,
    symbol = c("BRCA1", "TP53", "EGFR", "KRAS", "PTEN"),
    category = c("Definitive", "Definitive", "Moderate", "Limited", "Definitive"),
    hgnc_id = paste0("HGNC:", 1:5),
    ndd_phenotype_word = c("Yes", "Yes", "No", "Yes", "No")
  )
  # Select subset of fields (as endpoints do)
  selected <- select_tibble_fields(
    endpoint_data,
    "entity_id,symbol,category",
    "entity_id"
  )
  expect_equal(ncol(selected), 3)
  expect_true("entity_id" %in% names(selected))
  expect_true("symbol" %in% names(selected))
  expect_true("category" %in% names(selected))
  expect_false("hgnc_id" %in% names(selected))
})
test_that("field selection with empty fields returns all columns", {
  # Endpoints pass empty string to return all fields
  endpoint_data <- tibble(
    symbol = c("BRCA1", "TP53"),
    category = c("Definitive", "Moderate")
  )

  selected <- select_tibble_fields(endpoint_data, "", "symbol")

  expect_equal(ncol(selected), ncol(endpoint_data))
})

# =============================================================================
# Category normalization patterns
# =============================================================================

test_that("normalize_comparison_categories is the single mapping authority", {
  res <- normalize_comparison_categories(
    tibble::tibble(symbol = "G", list = "panelapp", category = "3")
  )
  expect_equal(res$category[[1]], "Definitive")
})

# =============================================================================
# Inheritance pattern normalization
# =============================================================================

test_that("inheritance pattern normalization matches endpoint logic", {
  # Test the pattern used in generate_stat_tibble
  test_inheritance <- c(
    "X-linked dominant inheritance",
    "Autosomal dominant inheritance",
    "Autosomal recessive inheritance",
    "Mitochondrial inheritance"
  )

  normalized <- case_when(
    str_detect(test_inheritance, "X-linked") ~ "X-linked",
    str_detect(test_inheritance, "Autosomal dominant inheritance") ~ "Autosomal dominant",
    str_detect(test_inheritance, "Autosomal recessive inheritance") ~ "Autosomal recessive",
    TRUE ~ "Other"
  )

  expect_equal(normalized[1], "X-linked")
  expect_equal(normalized[2], "Autosomal dominant")
  expect_equal(normalized[3], "Autosomal recessive")
  expect_equal(normalized[4], "Other")
})

# =============================================================================
# Date and time formatting
# =============================================================================

test_that("execution time formatting matches endpoint pattern", {
  # Endpoints format execution time as "X.XX secs"
  start_time <- Sys.time()
  Sys.sleep(0.1)
  end_time <- Sys.time()

  execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

  expect_true(str_detect(execution_time, "\\d+\\.\\d+ secs"))
})

# =============================================================================
# Pivot wider/longer patterns
# =============================================================================

test_that("pivot_wider pattern for comparison table works", {
  # Test the pattern used in generate_comparisons_list
  test_data <- tibble(
    symbol = c("BRCA1", "BRCA1", "TP53", "TP53"),
    list = c("SysNDD", "gene2phenotype", "SysNDD", "panelapp"),
    category = c("Definitive", "Definitive", "Definitive", "Limited")
  )

  wide_data <- test_data %>%
    pivot_wider(
      names_from = list,
      values_from = category,
      values_fill = "not listed"
    )

  expect_equal(nrow(wide_data), 2)
  expect_true("SysNDD" %in% names(wide_data))
  expect_true("gene2phenotype" %in% names(wide_data))
  expect_true("panelapp" %in% names(wide_data))
  expect_equal(wide_data$gene2phenotype[2], "not listed")
})

test_that("pivot_longer pattern for links works", {
  # Test the pattern used in endpoints to build links
  test_links <- tibble(
    first = "link1",
    `next` = "link2",
    prev = "null"
  )

  long_links <- test_links %>%
    pivot_longer(everything(), names_to = "type", values_to = "link")

  expect_equal(nrow(long_links), 3)
  expect_true("type" %in% names(long_links))
  expect_true("link" %in% names(long_links))
  expect_equal(long_links$type, c("first", "next", "prev"))
})

# =============================================================================
# Nested tibble patterns
# =============================================================================

test_that("nested tibble pattern for statistics works", {
  # Test the pattern used in generate_stat_tibble
  test_stats <- tibble(
    category = c("Definitive", "Definitive", "Moderate", "Moderate"),
    inheritance = c("Autosomal dominant", "X-linked", "Autosomal dominant", "X-linked"),
    n = c(100, 50, 30, 20)
  )

  nested_stats <- test_stats %>%
    mutate(category_group = category) %>%
    group_by(category_group) %>%
    nest() %>%
    ungroup() %>%
    select(category = category_group, groups = data)
  expect_equal(nrow(nested_stats), 2)
  expect_true("groups" %in% names(nested_stats))
  expect_true(is.list(nested_stats$groups))
  expect_equal(nrow(nested_stats$groups[[1]]), 2)
})

# =============================================================================
# Filter replacement patterns
# =============================================================================
test_that("filter replacement for 'All' values works", {
  # Test the pattern used in generate_panels_list
  test_filter <- "equals(category,'All'),any(inheritance_filter,'All')"
  category_values <- c("Definitive", "Moderate", "Limited")
  inheritance_values <- c("Autosomal dominant", "Autosomal recessive", "X-linked")

  replaced_filter <- test_filter %>%
    str_replace(
      "category,'All'",
      paste0("category,", paste(category_values, collapse = ","))
    ) %>%
    str_replace(
      "inheritance_filter,'All'",
      paste0("inheritance_filter,", paste(inheritance_values, collapse = ","))
    )

  expect_true(str_detect(replaced_filter, "category,Definitive,Moderate,Limited"))
  expect_true(str_detect(replaced_filter, "inheritance_filter,Autosomal dominant"))
})

# =============================================================================
# Injection-rejecting identifiers (phenotype domain)
# =============================================================================
# generate_phenotype_entities_list() calls generate_sort_expressions()/
# generate_filter_expressions() with no `allowed_columns` (legacy behaviour),
# but validate_query_column() still rejects any non-bare-identifier column
# token regardless of an allowlist (see test-unit-filter-column-allowlist.R).

test_that("phenotype sort rejects a non-bare-identifier column token", {
  expect_error(
    generate_sort_expressions("entity_id); DROP TABLE ndd_entity;--", unique_id = "entity_id"),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})

test_that("phenotype filter rejects an injected column token", {
  expect_error(
    suppressWarnings(generate_filter_expressions("equals(modifier_phenotype_id=1;DROP TABLE x,Yes)")),
    regexp = "column|not allowed|invalid|pieces", ignore.case = TRUE
  )
})

# =============================================================================
# Direct behavior against a real test DB (approved views, empty/meta/xlsx)
# =============================================================================
# Skips on host (no RMariaDB / no test DB). Runs for real inside the API/
# worker container against sysndd_db_test, exercising
# generate_phenotype_entities_list() end to end.

.px_ids <- list(
  hgnc = "HGNC:99941", moi = "HP:9940001",
  ph_ok = "HP:9940010", ph_bad = "HP:9940011", ontology = "OMIM:994001"
)

.px_exec <- function(conn, sql, ...) DBI::dbExecute(conn, sprintf(sql, ...))

.px_insert_id <- function(conn, sql, id_column, ...) {
  .px_exec(conn, sql, ...)
  DBI::dbGetQuery(conn, sprintf("SELECT LAST_INSERT_ID() AS %s", id_column))[[id_column]][[1]]
}
.px_cleanup <- function(conn) {
  ids <- .px_ids
  eid <- DBI::dbGetQuery(conn, sprintf("SELECT entity_id FROM ndd_entity WHERE hgnc_id = '%s'", ids$hgnc))$entity_id # nolint: line_length_linter
  if (length(eid) > 0) {
    w <- paste(eid, collapse = ",")
    for (tbl in c("ndd_review_phenotype_connect", "ndd_entity_status", "ndd_entity_review", "ndd_entity")) {
      .px_exec(conn, "DELETE FROM %s WHERE entity_id IN (%s)", tbl, w)
    }
  }
  .px_exec(conn, "DELETE FROM phenotype_list WHERE phenotype_id IN ('%s', '%s')", ids$ph_ok, ids$ph_bad)
  .px_exec(conn, "DELETE FROM disease_ontology_set WHERE disease_ontology_id_version = '%s'", ids$ontology)
  .px_exec(conn, "DELETE FROM mode_of_inheritance_list WHERE hpo_mode_of_inheritance_term = '%s'", ids$moi)
  .px_exec(conn, "DELETE FROM non_alt_loci_set WHERE hgnc_id = '%s'", ids$hgnc)
  invisible(TRUE)
}
#' Seed one approved entity with an approved AND an unapproved (non-primary)
#' phenotype review tagging different phenotypes, so the test can assert only
#' the approved review's phenotype is visible (migration 042 regression: the
#' *_view is gated on review_approved = 1).
.px_seed <- function(conn) {
  ids <- .px_ids
  .px_exec(conn, "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (1, 'sysndd_phenotype_split_test')")
  .px_exec(conn, "INSERT INTO non_alt_loci_set (hgnc_id, symbol, name) VALUES ('%s', 'SYSNDDPHENOTEST', 'split test gene')", ids$hgnc) # nolint: line_length_linter
  .px_exec(conn, paste(
    "INSERT INTO mode_of_inheritance_list (hpo_mode_of_inheritance_term,",
    "hpo_mode_of_inheritance_term_name, inheritance_filter, inheritance_short_text, is_active, sort)",
    "VALUES ('%s', 'split test inheritance', 'test', 'TST', 1, 9940001)"
  ), ids$moi)
  .px_exec(conn, paste(
    "INSERT INTO disease_ontology_set (disease_ontology_id_version, disease_ontology_id,",
    "disease_ontology_name, disease_ontology_source, disease_ontology_is_specific, hgnc_id,",
    "hpo_mode_of_inheritance_term, is_active)",
    "VALUES ('%s', '994001', 'split test ontology', 'OMIM', 1, '%s', '%s', 1)"
  ), ids$ontology, ids$hgnc, ids$moi)
  for (ph in c(ids$ph_ok, ids$ph_bad)) {
    .px_exec(conn, paste(
      "INSERT INTO phenotype_list (phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms, comment)",
      "VALUES ('%s', 'split test phenotype', 'fixture', '', 'test')"
    ), ph)
  }
  entity_id <- .px_insert_id(conn, paste(
    "INSERT INTO ndd_entity (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version,",
    "ndd_phenotype, entry_user_id, is_active) VALUES ('%s', '%s', '%s', 1, 1, 1)"
  ), "entity_id", ids$hgnc, ids$moi, ids$ontology)
  .px_exec(conn, paste(
    "INSERT INTO ndd_entity_status (entity_id, category_id, is_active, status_user_id,",
    "status_approved, approving_user_id, problematic, comment) VALUES (%d, 1, 1, 1, 1, 1, 0, 'test')"
  ), entity_id)
  ok_review_id <- .px_insert_id(conn, paste(
    "INSERT INTO ndd_entity_review (entity_id, synopsis, is_primary, review_user_id,",
    "review_approved, approving_user_id, comment)",
    "VALUES (%d, 'approved split test synopsis', 1, 1, 1, 1, 'approved')"
  ), "review_id", entity_id)
  .px_exec(conn, paste(
    "INSERT INTO ndd_review_phenotype_connect (review_id, entity_id, phenotype_id, modifier_id)",
    "VALUES (%d, %d, '%s', 1)"
  ), ok_review_id, entity_id, ids$ph_ok)
  # Non-primary, unapproved review on the same entity tagging the OTHER
  # phenotype — the realistic shape migration 042 protects against leaking.
  bad_review_id <- .px_insert_id(conn, paste(
    "INSERT INTO ndd_entity_review (entity_id, synopsis, is_primary, review_user_id,",
    "review_approved, comment)",
    "VALUES (%d, 'unapproved split test synopsis', 0, 1, 0, 'pending')"
  ), "review_id", entity_id)
  .px_exec(conn, paste(
    "INSERT INTO ndd_review_phenotype_connect (review_id, entity_id, phenotype_id, modifier_id)",
    "VALUES (%d, %d, '%s', 1)"
  ), bad_review_id, entity_id, ids$ph_bad)
  entity_id
}

test_that("generate_phenotype_entities_list: approved views, empty/meta/xlsx shape", {
  skip_if_no_test_db()
  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))
  required <- c(
    "ndd_entity_view", "ndd_review_phenotype_connect_view", "ndd_entity", "ndd_entity_review",
    "ndd_entity_status", "ndd_review_phenotype_connect", "phenotype_list",
    "non_alt_loci_set", "mode_of_inheritance_list", "disease_ontology_set"
  )
  missing <- required[!vapply(required, function(t) DBI::dbExistsTable(con, t), logical(1))]
  if (length(missing) > 0) skip(paste("Missing table(s):", paste(missing, collapse = ", ")))

  .px_cleanup(con)
  withr::defer(.px_cleanup(con))
  entity_id <- .px_seed(con)
  test_pool <- pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"), host = get_test_config("host"),
    user = get_test_config("user"), password = get_test_config("password"),
    port = as.integer(get_test_config("port"))
  )
  withr::defer(pool::poolClose(test_pool))
  old_pool <- if (exists("pool", envir = .GlobalEnv)) get("pool", envir = .GlobalEnv) else NULL
  old_dw <- if (exists("dw", envir = .GlobalEnv)) get("dw", envir = .GlobalEnv) else NULL
  assign("pool", test_pool, envir = .GlobalEnv)
  assign("dw", list(api_base_url = "http://localhost:7778"), envir = .GlobalEnv)
  withr::defer({
    if (is.null(old_pool)) rm(pool, envir = .GlobalEnv) else assign("pool", old_pool, envir = .GlobalEnv) # nolint: line_length_linter
    if (is.null(old_dw)) rm(dw, envir = .GlobalEnv) else assign("dw", old_dw, envir = .GlobalEnv)
  })
  # --- approved views: only the approved review's phenotype is visible ---
  result <- generate_phenotype_entities_list(filter = paste0("equals(entity_id,", entity_id, ")"))
  expect_true(is.list(result))
  expect_true(all(c("links", "meta", "data") %in% names(result)))
  expect_s3_class(result$data, "tbl_df")
  expect_equal(nrow(result$data), 1L)
  expect_true(grepl(.px_ids$ph_ok, result$data$modifier_phenotype_id[[1]]))
  expect_false(grepl(.px_ids$ph_bad, result$data$modifier_phenotype_id[[1]]))
  # --- meta shape ---
  expect_true(all(c("sort", "filter", "fields", "fspec", "executionTime") %in% names(result$meta)))
  # --- xlsx-compatible shape: generate_xlsx_bin() must not error on this ---
  # (bare write.xlsx() from the `xlsx` package, normally attached globally by
  # bootstrap/init_libraries.R at API startup — attach it explicitly here.)
  skip_if_not_installed("xlsx")
  library(xlsx)
  xlsx_bin <- generate_xlsx_bin(result, "phenotype_split_test")
  expect_true(is.raw(xlsx_bin))
  expect_gt(length(xlsx_bin), 0L)
  # --- empty behavior: a filter matching nothing still returns valid shape ---
  empty_result <- generate_phenotype_entities_list(filter = "equals(entity_id,-1)")
  expect_equal(nrow(empty_result$data), 0L)
  expect_equal(empty_result$meta$totalItems, 0L)
  # --- injection-rejecting identifiers, exercised through the real function ---
  expect_error(
    generate_phenotype_entities_list(sort = "entity_id);DROP TABLE ndd_entity;--"),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})
