source_api_file("functions/pubtator-gene-summary.R", local = FALSE)

test_that("summary cols list excludes nested publications/entities", {
  expect_true(all(c(
    "gene_symbol", "gene_name", "hgnc_id", "gene_normalized_id",
    "publication_count", "entities_count", "is_novel", "oldest_pub_date", "pmids"
  ) %in% PUBTATOR_GENE_SUMMARY_COLS))
  expect_false("publications" %in% PUBTATOR_GENE_SUMMARY_COLS)
  expect_false("entities" %in% PUBTATOR_GENE_SUMMARY_COLS)
})

test_that("pubtator_gene_summary_refresh materializes via a single GROUP BY swap", {
  captured <- character(0)
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) {
      captured[[length(captured) + 1L]] <<- statement
      1L
    },
    dbWithTransaction = function(conn, code) code,
    dbGetQuery = function(conn, statement, ...) data.frame(n = 352L),
    .package = "DBI"
  )

  res <- pubtator_gene_summary_refresh(conn = NULL)

  expect_true(res$success)
  expect_equal(res$genes, 352L)

  sqls <- paste(captured, collapse = "\n")
  # widen group_concat so the pmids list is not truncated
  expect_match(sqls, "group_concat_max_len", fixed = TRUE)
  # atomic replace
  expect_match(sqls, "DELETE FROM pubtator_gene_summary", fixed = TRUE)
  expect_match(sqls, "INSERT INTO pubtator_gene_summary", fixed = TRUE)
  # the aggregation contract
  expect_match(sqls, "FROM pubtator_human_gene_entity_view", fixed = TRUE)
  expect_match(sqls, "GROUP BY gene_symbol", fixed = TRUE)
  expect_match(sqls, "COUNT(DISTINCT pmid)", fixed = TRUE)
  expect_match(sqls, "COUNT(DISTINCT entity_id)", fixed = TRUE)
  expect_match(sqls, "GROUP_CONCAT(DISTINCT pmid", fixed = TRUE)
})

test_that("pubtator_genes_summary_base degrades to an empty, column-correct set when the live view is absent (no 500)", {
  # Cold start where pubtator_gene_summary is empty AND the live aggregation's
  # pubtator_human_gene_entity_view does not exist (fresh deploy / CI / isolated
  # stack). The endpoint must return an empty result, not surface a 500.
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) 0L,
    dbGetQuery = function(conn, statement, ...) {
      stop("Table 'sysndd_db.pubtator_human_gene_entity_view' doesn't exist")
    },
    .package = "DBI"
  )

  # A dummy non-pool connection: the summary-table read via dplyr::tbl() errors
  # (caught -> NULL), then the live aggregation throws (mocked above). The
  # function must swallow both and return a clean empty set.
  res <- pubtator_genes_summary_base(structure(list(), class = "DummyConn"))

  expect_type(res, "list")
  expect_identical(res$source, "empty")
  expect_equal(nrow(res$data), 0L)
  expect_true(all(PUBTATOR_GENE_SUMMARY_COLS %in% colnames(res$data)))
})
