# api/tests/testthat/test-unit-publication-date-backfill.R
# NOTE: publication key is `publication_id` (prefixed string, e.g. "PMID:999100"); there is
# no bare numeric PMID column. Seed publication_id + a primary-approved review join.

test_that("backfill selects unverified primary-approved rows and writes both columns", {
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-functions.R"), local = FALSE)
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)

  # info_from_pmid returns one row per fetched PMID with Publication_date +
  # publication_date_source. Override the global binding (the repo convention for
  # mocking sourced-into-global free functions; mirrors
  # test-mcp-service-publication-discovery.R). testthat::local_mocked_bindings cannot
  # target these non-package bindings.
  old_info <- get("info_from_pmid", envir = .GlobalEnv)
  assign("info_from_pmid", function(pmid_value, ...) dplyr::tibble(
    Publication_date = as.Date("2019-03-01"), publication_date_source = "pubmed"
  ), envir = .GlobalEnv)
  withr::defer(assign("info_from_pmid", old_info, envir = .GlobalEnv))

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, publication_id = "PMID:999100", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = FALSE)
    expect_gte(res$targeted, 1L)
    expect_equal(res$verified, 1L)
    got <- DBI::dbGetQuery(conn,
      "SELECT Publication_date, publication_date_source FROM publication WHERE publication_id = 'PMID:999100'")
    expect_equal(got$publication_date_source, "pubmed")
    expect_equal(as.character(got$Publication_date), "2019-03-01")
  })
})

test_that("dry_run reports targets without writing", {
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, publication_id = "PMID:999101", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = TRUE)
    expect_gte(res$targeted, 1L)
    expect_equal(res$verified, 0L)
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999101'")
    expect_true(is.na(got$publication_date_source))
  })
})
