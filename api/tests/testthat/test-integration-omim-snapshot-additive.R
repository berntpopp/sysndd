library(testthat)

source_api_file("functions/ontology-functions.R", local = FALSE)
source_api_file("functions/metadata-refresh.R", local = FALSE)

PENDING_CSV <- Sys.getenv("OMIM_SNAPSHOT_PENDING_CSV", "")

test_that("additive path makes new OMIM terms appear against the production snapshot", {
  if (PENDING_CSV == "" || !file.exists(PENDING_CSV)) {
    skip("Set OMIM_SNAPSHOT_PENDING_CSV to the pending CSV path to run this test")
  }
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    current <- DBI::dbGetQuery(conn, "SELECT * FROM disease_ontology_set")
    update <- readr::read_csv(PENDING_CSV, na = "NULL", show_col_types = FALSE)

    additive <- extract_additive_ontology_terms(update, current)
    expect_true(all(c("OMIM:621533", "OMIM:621608") %in% additive$disease_ontology_id_version))

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
})
