library(testthat)

source_api_file("functions/metadata-refresh.R", local = FALSE)

# Minimal column set matching disease_ontology_set (projection columns from
# migration 036 are intentionally omitted to prove they accept NULL on append).
make_row <- function(idv, name) {
  tibble::tibble(
    disease_ontology_id_version = idv,
    disease_ontology_id = idv,
    disease_ontology_name = name,
    disease_ontology_source = "omim",
    disease_ontology_date = "2026-06-29",
    # is_specific / is_active are integer (tinyint) columns in disease_ontology_set
    # — pass 0L/1L, not the strings "FALSE"/"TRUE" (MySQL rejects those on append).
    disease_ontology_is_specific = 0L,
    hgnc_id = NA_character_,
    hpo_mode_of_inheritance_term = NA_character_,
    DOID = NA_character_,
    Orphanet = NA_character_,
    EFO = NA_character_,
    MONDO = NA_character_,
    is_active = 1L,
    update_date = "2026-06-29"
  )
}

# Test-only OMIM ids in a synthetic 7-digit range production data never uses, so
# the tests add/remove ONLY their own rows — no table wipe, no collision with
# real data, and cleanup restores the table to its prior state.
TEST_IDS <- c("OMIM:9999991", "OMIM:9999992", "OMIM:9999993")
TEST_IDS_IN <- paste0("('", paste(TEST_IDS, collapse = "','"), "')")

# IMPORTANT: these tests do NOT wrap apply_additive_ontology_terms() in
# with_test_db_transaction(). The function opens its OWN DBI::dbWithTransaction
# internally; nesting dbBegin on the same connection raises "Nested transactions
# not supported" (the exact trap documented in
# test-integration-ontology-mapping-refresh.R). So they run against the real
# connection and clean up their test-only rows via withr::defer().
.delete_test_ids <- function(conn) {
  DBI::dbExecute(
    conn,
    paste0("DELETE FROM disease_ontology_set WHERE disease_ontology_id_version IN ", TEST_IDS_IN)
  )
}

test_that("apply_additive_ontology_terms inserts new rows, leaves existing untouched, is idempotent", {
  if (!test_db_available()) {
    testthat::skip("Test database (sysndd_db_test) not available")
  }
  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))

  if (!DBI::dbExistsTable(conn, "disease_ontology_set")) {
    testthat::skip("disease_ontology_set not initialized on this test DB; skip.")
  }

  .delete_test_ids(conn) # pre-clean any leftover from a crashed run
  withr::defer(.delete_test_ids(conn)) # post-clean (restore prior table state)

  # Seed one "existing" test-only row, then run additive with a rename of it plus
  # two genuinely new ids.
  DBI::dbAppendTable(conn, "disease_ontology_set", make_row(TEST_IDS[[1]], "Existing"))

  additive <- dplyr::bind_rows(
    make_row(TEST_IDS[[1]], "Existing renamed"), # already present -> must NOT touch
    make_row(TEST_IDS[[2]], "New NDD seizures"),
    make_row(TEST_IDS[[3]], "New DEE 122")
  )

  inserted <- apply_additive_ontology_terms(conn, additive)
  expect_equal(inserted, 2L)

  rows <- DBI::dbGetQuery(
    conn,
    paste0(
      "SELECT disease_ontology_id_version, disease_ontology_name ",
      "FROM disease_ontology_set WHERE disease_ontology_id_version IN ", TEST_IDS_IN,
      " ORDER BY disease_ontology_id_version"
    )
  )
  expect_setequal(rows$disease_ontology_id_version, TEST_IDS)
  # existing row name preserved (additive insert must not update it)
  expect_equal(
    rows$disease_ontology_name[rows$disease_ontology_id_version == TEST_IDS[[1]]],
    "Existing"
  )

  # Re-run is a no-op (live anti-join against the table, no PK violation)
  expect_equal(apply_additive_ontology_terms(conn, additive), 0L)
})

test_that("apply_additive_ontology_terms is a no-op on empty input", {
  # The empty-input guard returns before opening any transaction, so this needs
  # no DB connection and always runs.
  empty <- make_row("OMIM:1", "x")[0, ]
  expect_equal(apply_additive_ontology_terms(NULL, empty), 0L)
})
