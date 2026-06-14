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
