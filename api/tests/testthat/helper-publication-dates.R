# tests/testthat/helper-publication-dates.R
#
# Seeds a publication linked to a primary-approved review so it is selected by the
# verified-date backfill target query (publication + ndd_review_publication_join
# is_reviewed = 1 + ndd_entity_review is_primary = 1, review_approved = 1). Used by
# the publication-date backfill tests (#460).
#
# The publication key is the prefixed string `publication_id` (e.g. "PMID:999100");
# there is no bare numeric PMID column. FOREIGN_KEY_CHECKS is disabled because the
# synthetic entity_id / review_user_id do not reference real ndd_entity / user rows;
# the whole insert runs inside the test's rolled-back transaction.
#' Skip a backfill DB test when the publication/review schema is not initialized.
#'
#' Mirrors the repo convention (`test-integration-entity-rename.R`,
#' `test-unit-metadata-refresh.R`): the default local/PR test DB (`sysndd_db_test`)
#' starts empty, so DB-schema tests skip gracefully unless the required tables are
#' present. Keeps `make test-api-fast` / `make ci-local` green on the empty profile
#' while still running for real against an initialized DB.
skip_if_missing_publication_backfill_schema <- function(conn) {
  required_tables <- c(
    "publication",
    "ndd_review_publication_join",
    "ndd_entity_review"
  )
  missing_tables <- required_tables[!vapply(
    required_tables,
    function(table) DBI::dbExistsTable(conn, table),
    logical(1)
  )]

  if (length(missing_tables) > 0) {
    testthat::skip(paste(
      "Test database schema is not initialized; missing table(s):",
      paste(missing_tables, collapse = ", ")
    ))
  }
}

seed_primary_approved_publication <- function(conn, publication_id, source = NULL,
                                              pub_date = NULL) {
  source_val <- if (is.null(source)) NA_character_ else as.character(source)
  pub_date_val <- if (is.null(pub_date)) NA_character_ else as.character(pub_date)
  num <- as.integer(gsub("\\D", "", publication_id))

  DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
  on.exit(try(DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1"), silent = TRUE), add = TRUE)

  DBI::dbExecute(
    conn,
    "INSERT INTO publication (publication_id, Publication_date, publication_date_source)
       VALUES (?, ?, ?)",
    params = unname(list(publication_id, pub_date_val, source_val))
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity_review
       (review_id, entity_id, review_user_id, is_primary, review_approved)
       VALUES (?, ?, ?, 1, 1)",
    params = unname(list(num, num, 1L))
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_review_publication_join
       (review_id, entity_id, publication_id, is_reviewed)
       VALUES (?, ?, ?, 1)",
    params = unname(list(num, num, publication_id))
  )
  invisible(publication_id)
}
