library(testthat)

source_api_file("functions/ontology-functions.R", local = FALSE)
source_api_file("functions/metadata-refresh.R", local = FALSE)

PENDING_CSV <- Sys.getenv("OMIM_SNAPSHOT_PENDING_CSV", "")

test_that("additive path makes new OMIM terms appear against the production snapshot", {
  if (PENDING_CSV == "" || !file.exists(PENDING_CSV)) {
    skip("Set OMIM_SNAPSHOT_PENDING_CSV to the pending CSV path to run this test")
  }

  # Do NOT wrap in with_test_db_transaction(): apply_additive_ontology_terms()
  # opens its own DBI::dbWithTransaction internally and nesting dbBegin on the
  # same connection raises "Nested transactions not supported". Run against the
  # real connection and delete exactly the additive (net-new) rows we inserted in
  # a withr::defer cleanup so the snapshot is restored.
  if (!test_db_available()) {
    testthat::skip("Test database (sysndd_db_test) not available")
  }
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))

  if (!DBI::dbExistsTable(conn, "disease_ontology_set")) {
    testthat::skip("disease_ontology_set not initialized on this test DB; skip.")
  }

  current <- DBI::dbGetQuery(conn, "SELECT * FROM disease_ontology_set")
  update <- readr::read_csv(PENDING_CSV, na = "NULL", show_col_types = FALSE)

  additive <- extract_additive_ontology_terms(update, current)
  expect_true(all(c("OMIM:621533", "OMIM:621608") %in% additive$disease_ontology_id_version))

  # Cleanup: remove exactly the net-new versions this test inserts. These are
  # absent from `current` by construction (extract_additive's anti-join), so the
  # delete restores the table to its prior state and never touches a row an
  # entity references (entities point at the retained old versions).
  inserted_ids <- unique(as.character(additive$disease_ontology_id_version))
  withr::defer({
    if (length(inserted_ids) > 0) {
      in_clause <- paste0("('", paste(gsub("'", "''", inserted_ids), collapse = "','"), "')")
      DBI::dbExecute(
        conn,
        paste0("DELETE FROM disease_ontology_set WHERE disease_ontology_id_version IN ", in_clause)
      )
    }
  })

  # Pass the additive rows as-is (the CSV column set), mirroring production
  # apply_additive_terms_on_block(). The snapshot's disease_ontology_set carries
  # the migration-036 projection columns (UMLS/MedGen/NCIT/GARD/
  # ontology_mapping_release) that the pending CSV does not; reindexing to
  # colnames(current) would request columns absent from `additive`. Those
  # projection columns are nullable and default to NULL on append.
  inserted <- apply_additive_ontology_terms(conn, additive)
  expect_gt(inserted, 0L)

  got <- DBI::dbGetQuery(
    conn,
    "SELECT disease_ontology_id FROM disease_ontology_set WHERE disease_ontology_id IN ('OMIM:621533','OMIM:621608')"
  )
  expect_setequal(got$disease_ontology_id, c("OMIM:621533", "OMIM:621608"))

  # Re-run is a no-op (idempotent live anti-join)
  expect_equal(apply_additive_ontology_terms(conn, additive), 0L)
})
