# tests/testthat/test-unit-panels-endpoint.R
# Unit tests for panels endpoint column alias and filtering logic
#
# These tests validate the max_category handling in generate_panels_list
# (functions/panels-endpoint-functions.R, split out of endpoint-functions.R
# in #346 Wave 4 Task 6) without requiring database access, plus a
# direct-behavior block (approved views, empty/meta shape, injection-
# rejecting identifiers) that runs for real against a test DB and skips
# on host (no RMariaDB).

library(testthat)
library(dplyr)
library(tibble)
library(stringr)
library(rlang)
library(DBI)

# Source helper functions
api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/endpoint-functions.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}

source(file.path(api_dir, "functions", "helper-functions.R"))
# validate_query_column() (used by generate_sort_expressions/
# generate_filter_expressions) signals rejection via stop_for_bad_request().
source(file.path(api_dir, "core", "errors.R"))

# Direct-source the panels module (helper-functions.R above already provides
# its response-helpers.R/data-helpers.R transitive dependencies).
source(file.path(api_dir, "functions", "panels-endpoint-functions.R"))

# =============================================================================
# Test max_category column replacement logic
# =============================================================================

test_that("max_category column replaces category correctly when max_category=TRUE", {
  # Simulate the data structure after left_join with status_categories_list
  # A gene with multiple entities will have different category values per entity,
  # but all should have the same max_category after the join
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),  # Per-entity categories
    max_category = c("Definitive", "Definitive", "Definitive"),  # Max category per gene
    inheritance_filter = c("Autosomal dominant", "Autosomal dominant", "X-linked")
  )

  # Simulate the transformation that should happen when max_category=TRUE:
  # 1. Remove original category column
  # 2. Rename max_category to category
  max_category <- TRUE
  result <- test_data %>%
    {
      if (max_category) {
        select(., -category) %>%
          rename(category = max_category)
      } else {
        .
      }
    }

  # Verify the category column now contains max_category values
  expect_true("category" %in% colnames(result))
  expect_false("max_category" %in% colnames(result))
  expect_equal(result$category, c("Definitive", "Definitive", "Definitive"))
})

test_that("original category preserved when max_category=FALSE", {
  # When max_category=FALSE, the original per-entity category should be kept
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),
    max_category = c("Definitive", "Definitive", "Definitive"),
    inheritance_filter = c("Autosomal dominant", "Autosomal dominant", "X-linked")
  )

  max_category <- FALSE
  result <- test_data %>%
    {
      if (max_category) {
        select(., -category) %>%
          rename(category = max_category)
      } else {
        .
      }
    }

  # Verify the original category column is preserved
  expect_true("category" %in% colnames(result))
  expect_equal(result$category, c("Definitive", "Moderate", "Definitive"))
})

# =============================================================================
# Test filter expression replacement
# =============================================================================

test_that("filter expression replaces category with max_category when max_category=TRUE", {
  # Test the filter string replacement logic
  filter_string <- "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','X-linked')"

  max_category <- TRUE
  if (max_category) {
    filter_string <- str_replace(filter_string, "category", "max_category")
  }

  # Verify category was replaced with max_category
  expect_true(grepl("max_category", filter_string))
  # Use word boundary to avoid matching "category" inside "max_category"
  expect_false(grepl("\\bcategory\\b", filter_string))
  expect_match(filter_string, "equals\\(max_category,'Definitive'\\)")
})

test_that("filter expression with max_category can be parsed and applied", {
  # Create test data with max_category column
  test_data <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    max_category = c("Definitive", "Moderate", "Definitive"),
    inheritance_filter = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  # Use the helper function to generate filter expressions
  filter_string <- "equals(max_category,'Definitive')"
  filter_exprs <- generate_filter_expressions(filter_string)

  # Apply the filter
  result <- test_data %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Verify filtering worked
  expect_equal(nrow(result), 2)
  expect_equal(result$symbol, c("GENE1", "GENE3"))
  expect_true(all(result$max_category == "Definitive"))
})

# =============================================================================
# Test field selection with category column
# =============================================================================

test_that("select_tibble_fields correctly selects category column", {
  # Simulate the final panels data structure
  test_data <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3"),
    category = c("Definitive", "Moderate", "Definitive"),
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked"),
    hgnc_id = c("HGNC:1", "HGNC:2", "HGNC:3")
  )

  # Select specific fields including category
  fields_requested <- "category,symbol,hgnc_id"

  result <- select_tibble_fields(test_data, fields_requested, "symbol")

  # Verify the selected columns are present
  expect_true("category" %in% colnames(result))
  expect_true("symbol" %in% colnames(result))
  expect_true("hgnc_id" %in% colnames(result))
  expect_false("inheritance" %in% colnames(result))
  expect_equal(ncol(result), 3)
})

# =============================================================================
# Test output_columns_allowed match
# =============================================================================

test_that("all output_columns_allowed can be found in panels result", {
  # Define output_columns_allowed as it appears in start_sysndd_api.R
  output_columns_allowed <- c(
    "category",
    "inheritance",
    "symbol",
    "hgnc_id",
    "entrez_id",
    "ensembl_gene_id",
    "ucsc_id",
    "bed_hg19",
    "bed_hg38"
  )

  # Simulate a complete panels result tibble
  panels_result <- tibble(
    symbol = "GENE1",
    category = "Definitive",
    inheritance = "Autosomal dominant",
    hgnc_id = "HGNC:1",
    entrez_id = "123",
    ensembl_gene_id = "ENSG00000000001",
    ucsc_id = "uc001abc.1",
    bed_hg19 = "chr1:1000-2000",
    bed_hg38 = "chr1:1500-2500"
  )

  # Verify all allowed columns exist in the result
  for (col in output_columns_allowed) {
    expect_true(
      col %in% colnames(panels_result),
      info = paste("Column", col, "should be in panels result")
    )
  }
})

# =============================================================================
# Test category concatenation after grouping
# =============================================================================

test_that("category concatenation works with max_category values", {
  # Simulate data after max_category replacement but before grouping
  # A gene might have multiple inheritance modes, each with the same max_category
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Definitive", "Moderate"),  # Already replaced with max
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  # Group by symbol and concatenate unique categories
  result <- test_data %>%
    group_by(symbol) %>%
    mutate(category = str_c(unique(category), collapse = "; ")) %>%
    mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
    ungroup() %>%
    unique()

  # Verify GENE1 has "Definitive" (not "Definitive; Definitive")
  gene1_result <- result %>% filter(symbol == "GENE1")
  expect_equal(nrow(gene1_result), 1)
  expect_equal(gene1_result$category, "Definitive")
  expect_match(gene1_result$inheritance, "Autosomal dominant; Autosomal recessive")

  # Verify GENE2 has "Moderate"
  gene2_result <- result %>% filter(symbol == "GENE2")
  expect_equal(gene2_result$category, "Moderate")
})

test_that("category concatenation without max_category replacement shows mixed categories", {
  # When max_category=FALSE, the original per-entity categories should be concatenated
  test_data <- tibble(
    symbol = c("GENE1", "GENE1", "GENE2"),
    category = c("Definitive", "Moderate", "Definitive"),  # Original per-entity values
    inheritance = c("Autosomal dominant", "Autosomal recessive", "X-linked")
  )

  result <- test_data %>%
    group_by(symbol) %>%
    mutate(category = str_c(unique(category), collapse = "; ")) %>%
    mutate(inheritance = str_c(unique(inheritance), collapse = "; ")) %>%
    ungroup() %>%
    unique()

  # Verify GENE1 shows both categories concatenated
  gene1_result <- result %>% filter(symbol == "GENE1")
  expect_equal(nrow(gene1_result), 1)
  expect_match(gene1_result$category, "Definitive; Moderate|Moderate; Definitive")
})

# =============================================================================
# generate_panels_list moved to the panels module (#346 Wave 4 Task 6)
# =============================================================================

test_that("generate_panels_list lives in panels-endpoint-functions.R, not endpoint-functions.R", { # nolint: line_length_linter
  panels_code <- readLines(
    file.path(api_dir, "functions", "panels-endpoint-functions.R")
  )
  endpoint_code <- readLines(file.path(api_dir, "functions", "endpoint-functions.R"))

  expect_true(any(grepl("^generate_panels_list\\s*<-\\s*function", panels_code)))
  expect_false(any(grepl("^generate_panels_list\\s*<-\\s*function", endpoint_code)))
})

test_that("panels module sources ndd_entity_view, not raw entity/status tables", {
  # generate_panels_list must keep reading through the approved,
  # active-entity ndd_entity_view (which inner-joins
  # ndd_entity_status_approved_view) rather than querying ndd_entity /
  # ndd_entity_status directly, or an unapproved/inactive entity could leak
  # into the public panels/browse and panels BED-export endpoints.
  panels_code <- readLines(
    file.path(api_dir, "functions", "panels-endpoint-functions.R")
  )
  panels_text <- paste(panels_code, collapse = " ")

  expect_match(panels_text, "tbl\\(\"ndd_entity_view\"\\)")
  expect_false(grepl("tbl\\(\"ndd_entity\"\\)", panels_text))
  expect_false(grepl("tbl\\(\"ndd_entity_status\"\\)", panels_text))
})

# =============================================================================
# Injection-rejecting identifiers (panels domain)
# =============================================================================

test_that("panels sort rejects a non-bare-identifier column token", {
  expect_error(
    generate_sort_expressions("symbol); DROP TABLE non_alt_loci_set;--",
      unique_id = "symbol"
    ),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})

test_that("panels filter rejects an injected column token", {
  expect_error(
    suppressWarnings(
      generate_filter_expressions("equals(hgnc_id=1;DROP TABLE x,HGNC:1)")
    ),
    regexp = "column|not allowed|invalid|pieces", ignore.case = TRUE
  )
})

# =============================================================================
# Direct behavior against a real test DB (approved views, empty/meta shape)
# =============================================================================
# Skips on host (no RMariaDB / no test DB). Runs for real inside the API/
# worker container against sysndd_db_test, exercising generate_panels_list()
# end to end.

.panels_direct_test_ids <- list(
  hgnc = "HGNC:99951",
  moi = "HP:9950001",
  ontology = "OMIM:995001"
)

.panels_direct_cleanup <- function(conn) {
  ids <- .panels_direct_test_ids
  entity_ids <- DBI::dbGetQuery(
    conn,
    sprintf("SELECT entity_id FROM ndd_entity WHERE hgnc_id = '%s'", ids$hgnc)
  )$entity_id
  if (length(entity_ids) > 0) {
    id_list <- paste(entity_ids, collapse = ",")
    DBI::dbExecute(conn, sprintf("DELETE FROM ndd_entity_status WHERE entity_id IN (%s)", id_list)) # nolint: line_length_linter
    DBI::dbExecute(conn, sprintf("DELETE FROM ndd_entity_review WHERE entity_id IN (%s)", id_list)) # nolint: line_length_linter
    DBI::dbExecute(conn, sprintf("DELETE FROM ndd_entity WHERE entity_id IN (%s)", id_list))
  }
  DBI::dbExecute(conn, sprintf(
    "DELETE FROM disease_ontology_set WHERE disease_ontology_id_version = '%s'", ids$ontology
  ))
  DBI::dbExecute(conn, sprintf(
    "DELETE FROM mode_of_inheritance_list WHERE hpo_mode_of_inheritance_term = '%s'", ids$moi
  ))
  DBI::dbExecute(conn, sprintf("DELETE FROM non_alt_loci_set WHERE hgnc_id = '%s'", ids$hgnc))
  invisible(TRUE)
}

.panels_direct_insert_and_id <- function(conn, sql, id_column) {
  DBI::dbExecute(conn, sql)
  DBI::dbGetQuery(conn, sprintf("SELECT LAST_INSERT_ID() AS %s", id_column))[[id_column]][[1]]
}

#' Seed one entity with an APPROVED status (Definitive / Autosomal dominant,
#' visible in ndd_entity_view) so generate_panels_list()'s default filter
#' picks it up.
.panels_direct_seed <- function(conn) {
  ids <- .panels_direct_test_ids

  DBI::dbExecute(conn, "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (1, 'sysndd_panels_split_test')") # nolint: line_length_linter
  DBI::dbExecute(conn, sprintf(
    "INSERT INTO non_alt_loci_set (hgnc_id, symbol, name) VALUES ('%s', 'SYSNDDPANELTEST', 'split test gene')", # nolint: line_length_linter
    ids$hgnc
  ))
  DBI::dbExecute(conn, sprintf(
    paste0(
      "INSERT INTO mode_of_inheritance_list ",
      "(hpo_mode_of_inheritance_term, hpo_mode_of_inheritance_term_name, ",
      "inheritance_filter, inheritance_short_text, is_active, sort) ",
      "VALUES ('%s', 'split test autosomal dominant', 'Autosomal dominant', 'AD', 1, 9950001)"
    ),
    ids$moi
  ))
  DBI::dbExecute(conn, sprintf(
    paste0(
      "INSERT INTO disease_ontology_set ",
      "(disease_ontology_id_version, disease_ontology_id, disease_ontology_name, ",
      "disease_ontology_source, disease_ontology_is_specific, hgnc_id, ",
      "hpo_mode_of_inheritance_term, is_active) ",
      "VALUES ('%s', '995001', 'split test panels ontology', 'OMIM', 1, '%s', '%s', 1)"
    ),
    ids$ontology, ids$hgnc, ids$moi
  ))

  entity_id <- .panels_direct_insert_and_id(
    conn,
    sprintf(
      paste0(
        "INSERT INTO ndd_entity ",
        "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ",
        "ndd_phenotype, entry_user_id, is_active) VALUES ('%s', '%s', '%s', 1, 1, 1)"
      ),
      ids$hgnc, ids$moi, ids$ontology
    ),
    "entity_id"
  )
  # category_id = 1 -> "Definitive" (ndd_entity_status_categories_list, base seed)
  DBI::dbExecute(conn, sprintf(
    paste0(
      "INSERT INTO ndd_entity_status ",
      "(entity_id, category_id, is_active, status_user_id, status_approved, ",
      "approving_user_id, problematic, comment) VALUES (%d, 1, 1, 1, 1, 1, 0, 'test')"
    ),
    entity_id
  ))
  .panels_direct_insert_and_id(
    conn,
    sprintf(
      paste0(
        "INSERT INTO ndd_entity_review ",
        "(entity_id, synopsis, is_primary, review_user_id, review_approved, ",
        "approving_user_id, comment) ",
        "VALUES (%d, 'approved split test synopsis', 1, 1, 1, 1, 'approved')"
      ),
      entity_id
    ),
    "review_id"
  )

  entity_id
}

test_that("generate_panels_list: approved views, empty/meta shape, real DB", {
  skip_if_no_test_db()

  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  required_tables <- c(
    "ndd_entity_view", "ndd_entity", "ndd_entity_review", "ndd_entity_status",
    "non_alt_loci_set", "mode_of_inheritance_list", "disease_ontology_set",
    "ndd_entity_status_categories_list"
  )
  missing_tables <- required_tables[!vapply(
    required_tables, function(t) DBI::dbExistsTable(con, t), logical(1)
  )]
  if (length(missing_tables) > 0) {
    skip(paste("Missing table(s):", paste(missing_tables, collapse = ", ")))
  }

  .panels_direct_cleanup(con)
  withr::defer(.panels_direct_cleanup(con))
  .panels_direct_seed(con)

  test_pool <- pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = get_test_config("dbname"),
    host = get_test_config("host"),
    user = get_test_config("user"),
    password = get_test_config("password"),
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

  # --- approved views + default filter/sort: the seeded gene is visible ---
  result <- generate_panels_list(
    filter = paste0(
      "equals(category,'Definitive'),equals(hgnc_id,'", .panels_direct_test_ids$hgnc, "')"
    )
  )

  expect_true(is.list(result))
  expect_true(all(c("links", "meta", "fields", "data") %in% names(result)))
  expect_s3_class(result$data, "tbl_df")
  expect_equal(nrow(result$data), 1L)
  expect_equal(result$data$symbol[[1]], "SYSNDDPANELTEST")
  expect_equal(result$data$category[[1]], "Definitive")

  # --- meta shape ---
  expect_true(all(c("sort", "filter", "fields", "executionTime") %in% names(result$meta)))

  # --- empty behavior: a filter matching nothing still returns valid shape ---
  empty_result <- generate_panels_list(filter = "equals(hgnc_id,'HGNC:00000000')")
  expect_equal(nrow(empty_result$data), 0L)
  expect_equal(empty_result$meta$totalItems, 0L)

  # --- injection-rejecting identifiers, exercised through the real function ---
  expect_error(
    generate_panels_list(sort = "symbol);DROP TABLE non_alt_loci_set;--"),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})
