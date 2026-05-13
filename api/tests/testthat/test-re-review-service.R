# tests/testthat/test-re-review-service.R
#
# Unit tests for re-review-service.R — gene-atomic batching (issue #29)
#
# Strategy: temporarily replace db_execute_query in the global environment
# using withr::with_bindings so we can drive the select_matching_entities()
# algorithm without a live database.
# We also verify that batch_preview returns the new boundary_gene / gene_count
# / entity_count fields after the fix.

# Source into .GlobalEnv so that lexical scoping works when we replace
# db_execute_query in .GlobalEnv during tests.
source_api_file("functions/db-helpers.R", local = FALSE, envir = .GlobalEnv)
# logger package is used by re-review-service.R via logger::log_info etc.
if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run re-review-service tests")
}
source_api_file("services/re-review-service.R", local = FALSE, envir = .GlobalEnv)

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
    entity_id                         = c(1L, 2L, 3L, 4L, 5L, 6L),
    hgnc_id                           = c("HGNC:1001", "HGNC:1001", "HGNC:1001",
                                          "HGNC:1002", "HGNC:1002", "HGNC:1002"),
    symbol                            = rep("GENE1", 6),
    disease_ontology_name             = paste0("Disease ", 1:6),
    disease_ontology_id_version       = paste0("OMIM:10000", 1:6),
    hpo_mode_of_inheritance_term_name = rep("Autosomal dominant", 6),
    review_date                       = c("2020-01-01", "2020-02-01", "2020-03-01",
                                          "2020-06-01", "2020-07-01", "2020-08-01"),
    review_id                         = 101L:106L,
    category_id                       = rep(1L, 6),
    status_id                         = 201L:206L,
    stringsAsFactors                  = FALSE
  )
}

# Mock connection — only used as the conn argument; mocked db_execute_query
# ignores the actual connection object.
make_mock_conn <- function() structure(list(), class = "MockPool")

# ---------------------------------------------------------------------------
# with_db_mock: temporarily replace db_execute_query and the where-clause
# helpers in the global environment, restoring them on exit.
# The mock_fn receives each call in sequence; call_count_env$n tracks calls.
# ---------------------------------------------------------------------------
with_db_mock <- function(mock_fn, expr) {
  # Save originals (may be NULL if not yet defined)
  orig_deq  <- if (exists("db_execute_query",        envir = .GlobalEnv)) get("db_execute_query",        envir = .GlobalEnv) else NULL
  orig_bwc  <- if (exists("build_batch_where_clause", envir = .GlobalEnv)) get("build_batch_where_clause", envir = .GlobalEnv) else NULL
  orig_bbp  <- if (exists("build_batch_params",       envir = .GlobalEnv)) get("build_batch_params",       envir = .GlobalEnv) else NULL

  # Install mocks
  assign("db_execute_query",        mock_fn,                              envir = .GlobalEnv)
  assign("build_batch_where_clause", function(criteria, pool) "1=1",      envir = .GlobalEnv)
  assign("build_batch_params",       function(criteria) list(),            envir = .GlobalEnv)

  # Restore on exit (even on error)
  on.exit({
    if (is.null(orig_deq))  rm("db_execute_query",        envir = .GlobalEnv) else assign("db_execute_query",        orig_deq, envir = .GlobalEnv)
    if (is.null(orig_bwc))  rm("build_batch_where_clause", envir = .GlobalEnv) else assign("build_batch_where_clause", orig_bwc, envir = .GlobalEnv)
    if (is.null(orig_bbp))  rm("build_batch_params",       envir = .GlobalEnv) else assign("build_batch_params",       orig_bbp, envir = .GlobalEnv)
  }, add = TRUE)

  force(expr)
}

# Convenience: mock that alternates between gene_rows (call 1) and entity_rows (call 2+)
make_two_call_mock <- function(gene_rows, entity_rows) {
  call_n <- 0L
  function(sql, params = list(), conn = NULL) {
    call_n <<- call_n + 1L
    if (call_n == 1L) tibble::as_tibble(gene_rows)
    else              tibble::as_tibble(entity_rows)
  }
}

# Mock that always returns an empty tibble (no matching genes)
make_empty_mock <- function() {
  function(sql, params = list(), conn = NULL) tibble::tibble()
}

# ---------------------------------------------------------------------------
# Tests
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

  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()
  call_n      <- 0L

  mock_fn <- function(sql, params = list(), conn = NULL) {
    call_n <<- call_n + 1L
    if (call_n == 1L) tibble::as_tibble(gene_rows) else tibble::as_tibble(entity_rows)
  }

  with_db_mock(mock_fn, {
    result <- select_matching_entities(
      criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
      batch_size = 4L,
      conn       = make_mock_conn()
    )
  })

  # Both DB calls must have been made
  expect_equal(call_n, 2L)

  # With batch_size=4 and 3 entities per gene, the soft LIMIT must include
  # gene HGNC:1001 fully (3 entities), then detect overflow when adding HGNC:1002
  # (total=6 > 4), include all of HGNC:1002 anyway, set boundary_gene = "HGNC:1002".
  expect_equal(result$entity_count,  6L)
  expect_equal(result$gene_count,    2L)
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

  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  with_db_mock(make_two_call_mock(gene_rows, entity_rows), {
    result <- select_matching_entities(
      criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
      batch_size = 20L,
      conn       = make_mock_conn()
    )
  })

  expect_equal(result$entity_count, 6L)
  expect_equal(result$gene_count,   2L)
  expect_true(is.na(result$boundary_gene))
})

test_that("select_matching_entities returns empty list when no genes found", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  with_db_mock(make_empty_mock(), {
    result <- select_matching_entities(
      criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
      batch_size = 20L,
      conn       = make_mock_conn()
    )
  })

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

  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  with_db_mock(make_two_call_mock(gene_rows, entity_rows), {
    result <- batch_preview(
      criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
      batch_size = 4L,
      pool       = make_mock_conn()
    )
  })

  expect_equal(result$status, 200L)
  expect_true("boundary_gene" %in% names(result))
  expect_true("gene_count"    %in% names(result))
  expect_true("entity_count"  %in% names(result))
  expect_false(is.na(result$boundary_gene))
  expect_equal(result$gene_count,   2L)
  expect_equal(result$entity_count, 6L)
})

test_that("batch_preview atomicity: entity count must be gene-atomic (never splits a gene)", {
  skip_if_not(
    exists("select_matching_entities", mode = "function"),
    "select_matching_entities not yet implemented"
  )

  gene_rows   <- make_gene_rows()
  entity_rows <- make_entity_rows()

  with_db_mock(make_two_call_mock(gene_rows, entity_rows), {
    result <- batch_preview(
      criteria   = list(date_range = list(start = "2020-01-01", end = "2030-12-31")),
      batch_size = 4L,
      pool       = make_mock_conn()
    )
  })

  ent_count <- nrow(result$data)

  # With batch_size=4 and 3 entities per gene, the algorithm must return
  # either 3 (gene A only) or 6 (both genes), never 4 (would split gene B).
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

test_that("available_entities searches and paginates manual-pick candidates", {
  calls <- list()
  mock_fn <- function(sql, params = list(), conn = NULL) {
    calls[[length(calls) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("COUNT\\(\\*\\) AS total", sql)) {
      return(tibble::tibble(total = 85L))
    }
    tibble::tibble(
      entity_id = 1307L,
      hgnc_id = "HGNC:12760",
      gene_symbol = "BRWD1",
      disease_ontology_name = "autism spectrum disorder",
      review_date = "2014-03-04",
      status_name = "Limited"
    )
  }

  orig_deq <- if (exists("db_execute_query", envir = .GlobalEnv)) {
    get("db_execute_query", envir = .GlobalEnv)
  } else {
    NULL
  }
  assign("db_execute_query", mock_fn, envir = .GlobalEnv)
  on.exit({
    if (is.null(orig_deq)) {
      rm("db_execute_query", envir = .GlobalEnv)
    } else {
      assign("db_execute_query", orig_deq, envir = .GlobalEnv)
    }
  }, add = TRUE)

  result <- available_entities(
    query = "autism",
    page = 2L,
    page_size = 5L,
    pool = make_mock_conn()
  )

  expect_equal(result$status, 200L)
  expect_equal(result$meta$total, 85L)
  expect_equal(result$meta$page, 2L)
  expect_equal(result$meta$page_size, 5L)
  expect_equal(result$meta$total_pages, 17L)
  expect_equal(result$data$entity_id, 1307L)
  expect_equal(length(calls), 2L)
  expect_match(calls[[1L]]$sql, "CAST\\(e.entity_id AS CHAR\\) LIKE")
  expect_match(calls[[1L]]$sql, "re_review_entity_connect")
  expect_equal(calls[[1L]]$params, rep(list("%autism%"), 5L))
  expect_equal(tail(calls[[2L]]$params, 2L), list(5L, 5L))
})
