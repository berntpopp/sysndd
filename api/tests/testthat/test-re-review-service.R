# tests/testthat/test-re-review-service.R
#
# Unit tests for re-review-service.R — gene-atomic batching (issue #29)
#
# Strategy: use local_mocked_bindings to mock db_execute_query so we can
# drive the select_matching_entities() algorithm without a live database.
# We also verify that batch_preview returns the new boundary_gene / gene_count
# / entity_count fields after the fix.

source_api_file("functions/db-helpers.R", local = FALSE)
# logger package is used by re-review-service.R via logger::log_info etc.
if (!requireNamespace("logger", quietly = TRUE)) {
  skip("logger package not available")
}
source_api_file("services/re-review-service.R", local = FALSE)

# ---------------------------------------------------------------------------
# Helpers — synthetic entity data frames returned by the mocked DB queries
# ---------------------------------------------------------------------------

# Two genes (HGNC:1001, HGNC:1002), three entities each.
# Genes are discovered in order HGNC:1001 first (oldest review_date).
make_gene_rows <- function() {
  data.frame(
    hgnc_id           = c("HGNC:1001", "HGNC:1002"),
    first_review_date = c("2020-01-01", "2020-06-01"),
    stringsAsFactors  = FALSE
  )
}

make_entity_rows <- function() {
  data.frame(
    entity_id                      = c(1L, 2L, 3L, 4L, 5L, 6L),
    hgnc_id                        = c("HGNC:1001", "HGNC:1001", "HGNC:1001",
                                       "HGNC:1002", "HGNC:1002", "HGNC:1002"),
    symbol                         = rep("GENE1", 6),
    disease_ontology_name          = paste0("Disease ", 1:6),
    disease_ontology_id_version    = paste0("OMIM:10000", 1:6),
    hpo_mode_of_inheritance_term_name = rep("Autosomal dominant", 6),
    review_date                    = c("2020-01-01", "2020-02-01", "2020-03-01",
                                       "2020-06-01", "2020-07-01", "2020-08-01"),
    review_id                      = 101L:106L,
    category_id                    = rep(1L, 6),
    status_id                      = 201L:206L,
    stringsAsFactors               = FALSE
  )
}

# Mock connection — only used as the conn argument; mocked db_execute_query
# ignores the actual connection object.
make_mock_conn <- function() structure(list(), class = "MockPool")

# ---------------------------------------------------------------------------
# Helper: set up mocks that simulate the gene-LIMIT SQL + entity expansion.
# call_count allows the caller to distinguish first call (gene list query)
# from second call (entity rows query).
# ---------------------------------------------------------------------------
with_gene_atomic_mocks <- function(expr, gene_rows = make_gene_rows(),
                                   entity_rows = make_entity_rows()) {
  call_count <- 0L
  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        # First call: the gene-discovery SELECT → return gene rows
        return(tibble::as_tibble(gene_rows))
      } else {
        # Second call: the entity-expansion SELECT → return entity rows
        return(tibble::as_tibble(entity_rows))
      }
    },
    build_batch_where_clause = function(criteria, pool) "1=1",
    build_batch_params       = function(criteria) list(),
    .package                 = NULL # bindings in global env (sourced service)
  )
  force(expr)
}

# ---------------------------------------------------------------------------
# W3.2 failing tests (these fail before the fix because select_matching_entities
# doesn't exist yet — source_api_file above will error on that missing function)
# ---------------------------------------------------------------------------

context("re-review-service: gene-atomic batching (issue #29)")

test_that("select_matching_entities exists after fix", {
  expect_true(
    exists("select_matching_entities", mode = "function"),
    info = "select_matching_entities() must be defined in re-review-service.R"
  )
})

test_that("select_matching_entities returns gene-atomic result with soft LIMIT", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  pool <- make_mock_conn()

  call_count <- 0L
  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      call_count <<- call_count + 1L
      if (call_count == 1L) tibble::as_tibble(gene_rows)
      else                  tibble::as_tibble(entity_rows)
    },
    .package = NULL
  )

  result <- select_matching_entities(
    criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
    batch_size = 4L,
    conn       = pool
  )

  # Both calls must have been made
  expect_equal(call_count, 2L)

  # With batch_size=4 and 3 entities per gene, the soft LIMIT must include
  # gene HGNC:1001 fully (3 entities), then detect overflow when adding HGNC:1002
  # (total=6 > 4), include it fully anyway, and set boundary_gene = "HGNC:1002".
  expect_equal(result$entity_count, 6L)
  expect_equal(result$gene_count,   2L)
  expect_equal(result$boundary_gene, "HGNC:1002")

  # All entities must be present
  expect_equal(sort(result$entities$entity_id), 1L:6L)

  # Each gene must have exactly 3 entities (gene-atomic guarantee)
  per_gene <- table(result$entities$hgnc_id)
  expect_true(all(per_gene == 3L),
              info = paste("Expected 3 entities per gene; got",
                           paste(per_gene, collapse = ",")))
})

test_that("select_matching_entities sets boundary_gene = NA when batch fits cleanly", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  pool <- make_mock_conn()

  call_count <- 0L
  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      call_count <<- call_count + 1L
      if (call_count == 1L) tibble::as_tibble(gene_rows)
      else                  tibble::as_tibble(entity_rows)
    },
    .package = NULL
  )

  result <- select_matching_entities(
    criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
    batch_size = 20L,
    conn       = pool
  )

  expect_equal(result$entity_count, 6L)
  expect_equal(result$gene_count,   2L)
  expect_true(is.na(result$boundary_gene))
})

test_that("select_matching_entities returns empty list when no genes found", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  pool <- make_mock_conn()

  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      tibble::tibble()  # no rows
    },
    .package = NULL
  )

  result <- select_matching_entities(
    criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
    batch_size = 20L,
    conn       = pool
  )

  expect_equal(result$entity_count, 0L)
  expect_equal(result$gene_count,   0L)
  expect_true(is.na(result$boundary_gene))
  expect_equal(nrow(result$entities), 0L)
})

test_that("batch_preview response includes boundary_gene, gene_count, entity_count", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  pool <- make_mock_conn()

  call_count <- 0L
  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      call_count <<- call_count + 1L
      if (call_count == 1L) tibble::as_tibble(gene_rows)
      else                  tibble::as_tibble(entity_rows)
    },
    .package = NULL
  )

  result <- batch_preview(
    criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
    batch_size = 4L,
    pool       = pool
  )

  expect_equal(result$status, 200L)
  expect_true("boundary_gene"  %in% names(result))
  expect_true("gene_count"     %in% names(result))
  expect_true("entity_count"   %in% names(result))
  expect_false(is.na(result$boundary_gene))
  expect_equal(result$gene_count,   2L)
  expect_equal(result$entity_count, 6L)
})

test_that("batch_preview atomicity: entity count must be gene-atomic (never splits a gene)", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  pool <- make_mock_conn()

  call_count <- 0L
  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  local_mocked_bindings(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      call_count <<- call_count + 1L
      if (call_count == 1L) tibble::as_tibble(gene_rows)
      else                  tibble::as_tibble(entity_rows)
    },
    .package = NULL
  )

  result <- batch_preview(
    criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
    batch_size = 4L,
    pool       = pool
  )

  ent_count <- nrow(result$data)

  # With batch_size=4 and 3 entities per gene, the algorithm must return
  # either 3 (gene A only) or 6 (both genes), never 4 (which would split gene B).
  expect_true(
    ent_count %in% c(3L, 6L),
    info = paste("Expected gene-atomic count in {3, 6}; got", ent_count)
  )

  per_gene <- table(result$data$hgnc_id)
  expect_true(
    all(per_gene == 3L),
    info = paste("Expected 3 entities per gene; got", paste(per_gene, collapse = ","))
  )
})
