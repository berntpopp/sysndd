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
    disease_ontology_is_specific = "FALSE",
    hgnc_id = NA_character_,
    hpo_mode_of_inheritance_term = NA_character_,
    DOID = NA_character_,
    Orphanet = NA_character_,
    EFO = NA_character_,
    MONDO = NA_character_,
    is_active = "TRUE",
    update_date = "2026-06-29"
  )
}

test_that("apply_additive_ontology_terms inserts new rows, leaves existing untouched, is idempotent", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    DBI::dbExecute(conn, "DELETE FROM ndd_entity")
    DBI::dbExecute(conn, "DELETE FROM disease_ontology_set")
    DBI::dbAppendTable(conn, "disease_ontology_set", make_row("OMIM:111111", "Existing"))

    additive <- dplyr::bind_rows(
      make_row("OMIM:111111", "Existing renamed"), # already present -> must NOT touch
      make_row("OMIM:621533", "New NDD seizures"),
      make_row("OMIM:621608", "New DEE 122")
    )

    inserted <- apply_additive_ontology_terms(conn, additive)
    expect_equal(inserted, 2L)

    rows <- DBI::dbGetQuery(
      conn,
      "SELECT disease_ontology_id_version, disease_ontology_name FROM disease_ontology_set ORDER BY disease_ontology_id_version"
    )
    expect_setequal(rows$disease_ontology_id_version,
                    c("OMIM:111111", "OMIM:621533", "OMIM:621608"))
    # existing row name preserved (additive insert must not update it)
    expect_equal(rows$disease_ontology_name[rows$disease_ontology_id_version == "OMIM:111111"],
                 "Existing")

    # Re-run is a no-op (live anti-join, no PK violation)
    expect_equal(apply_additive_ontology_terms(conn, additive), 0L)
  })
})

test_that("apply_additive_ontology_terms is a no-op on empty input", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    empty <- make_row("OMIM:1", "x")[0, ]
    expect_equal(apply_additive_ontology_terms(conn, empty), 0L)
  })
})
