# test-integration-mondo-index.R
# Integration tests for MONDO index write (B5) and disease mapping derive+write (B6).
# Requires a test DB with migration 036 applied (mondo_term, mondo_xref,
# disease_ontology_mapping tables must exist).

library(testthat)
library(tibble)

source_api_file("functions/mondo-index-builder.R", local = FALSE)
source_api_file("functions/disease-ontology-mapping-builder.R", local = FALSE)

# ---------------------------------------------------------------------------
# B5: mondo_index_write — DB integration test
# ---------------------------------------------------------------------------

test_that("mondo_index_write inserts terms and xrefs in a test transaction", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Check that the tables exist (migration 036 must be applied)
    if (!DBI::dbExistsTable(conn, "mondo_term")) {
      testthat::skip("mondo_term table not found — migration 036 not applied on test DB")
    }

    # Build minimal parsed OBO
    parsed_obo <- list(
      version = "2026-05-05",
      terms   = tibble::tibble(
        mondo_id    = c("MONDO:0032745", "MONDO:0000003"),
        label       = c("CTNNB1 syndrome", "obsolete entity"),
        definition  = c("A syndrome.", NA_character_),
        is_obsolete = c(0L, 1L),
        replaced_by = c(NA_character_, "MONDO:0032745")
      ),
      xrefs = tibble::tibble(
        mondo_id     = "MONDO:0032745",
        target_prefix = "OMIM",
        target_id    = "OMIM:618524",
        predicate    = "equivalentTo",
        origin       = "obo_xref",
        source       = NA_character_,
        target_label = NA_character_
      )
    )
    sssom_tbl <- tibble::tibble(
      mondo_id     = "MONDO:0032745",
      target_prefix = "Orphanet",
      target_id    = "Orphanet:530983",
      predicate    = "exactMatch",
      source       = "semapv:ManualMappingCuration",
      target_label = "CTNNB1 syndrome label"
    )

    mondo_index_write(conn, parsed_obo, sssom_tbl, "2026-05-05")

    term_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM mondo_term")$n
    expect_equal(term_count, 2L)

    xref_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM mondo_xref")$n
    expect_gte(xref_count, 1L)

    # OMIM xref should be present
    omim_xref <- DBI::dbGetQuery(
      conn,
      "SELECT * FROM mondo_xref WHERE target_id = 'OMIM:618524' LIMIT 1"
    )
    expect_equal(nrow(omim_xref), 1L)
    expect_equal(omim_xref$mondo_id, "MONDO:0032745")
  })
})

test_that("mondo_index_write uses DELETE not TRUNCATE (rollback-safe)", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    if (!DBI::dbExistsTable(conn, "mondo_term")) {
      testthat::skip("mondo_term table not found — migration 036 not applied on test DB")
    }

    # Insert a row to verify it gets replaced, not accumulated
    DBI::dbExecute(
      conn,
      paste0(
        "INSERT INTO mondo_term (mondo_id, label, is_obsolete) ",
        "VALUES ('MONDO:9999999', 'sentinel', 0)"
      )
    )

    pre_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM mondo_term")$n
    expect_equal(pre_count, 1L)

    # Write new set — DELETE should remove sentinel
    parsed_obo <- list(
      version = "2026-05-05",
      terms   = tibble::tibble(
        mondo_id    = "MONDO:0032745",
        label       = "CTNNB1 syndrome",
        definition  = NA_character_,
        is_obsolete = 0L,
        replaced_by = NA_character_
      ),
      xrefs = tibble::tibble(
        mondo_id = character(), target_prefix = character(), target_id = character(),
        predicate = character(), origin = character(), source = character(),
        target_label = character()
      )
    )
    sssom_tbl <- tibble::tibble(
      mondo_id = character(), target_prefix = character(), target_id = character(),
      predicate = character(), source = character(), target_label = character()
    )
    mondo_index_write(conn, parsed_obo, sssom_tbl, "2026-05-05")

    post_count <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM mondo_term")$n
    expect_equal(post_count, 1L)
    expect_equal(
      DBI::dbGetQuery(conn, "SELECT mondo_id FROM mondo_term LIMIT 1")$mondo_id,
      "MONDO:0032745"
    )
  })
})

# ---------------------------------------------------------------------------
# B6: disease_mapping_derive + disease_mapping_write — DB integration test
# ---------------------------------------------------------------------------

test_that("disease_mapping_derive + write populates disease_ontology_mapping", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    if (!DBI::dbExistsTable(conn, "mondo_term") ||
        !DBI::dbExistsTable(conn, "disease_ontology_mapping")) {
      testthat::skip("Required tables not found — migration 036 not applied on test DB")
    }
    if (!DBI::dbExistsTable(conn, "disease_ontology_set")) {
      testthat::skip("disease_ontology_set table not found")
    }

    # Seed mondo_xref with test data
    DBI::dbExecute(conn, "DELETE FROM mondo_xref")
    DBI::dbExecute(conn, "DELETE FROM mondo_term")

    term_row <- data.frame(
      mondo_id        = "MONDO:0032745",
      label           = "CTNNB1 syndrome",
      definition      = "A syndrome.",
      is_obsolete     = 0L,
      replaced_by     = NA_character_,
      release_version = "2026-05-05",
      stringsAsFactors = FALSE
    )
    DBI::dbAppendTable(conn, "mondo_term", term_row)

    xref_rows <- data.frame(
      mondo_id      = c("MONDO:0032745", "MONDO:0032745"),
      target_prefix = c("OMIM", "Orphanet"),
      target_id     = c("OMIM:618524", "Orphanet:530983"),
      target_id_upper = c("OMIM:618524", "ORPHANET:530983"),
      target_label  = c(NA_character_, "CTNNB1 syndrome label"),
      predicate     = c("equivalentTo", "exactMatch"),
      origin        = c("obo_xref", "sssom"),
      source        = c(NA_character_, "semapv:ManualMappingCuration"),
      release_version = c("2026-05-05", "2026-05-05"),
      stringsAsFactors = FALSE
    )
    DBI::dbAppendTable(conn, "mondo_xref", xref_rows)

    # Check if disease_ontology_set has OMIM:618524 test row
    existing <- DBI::dbGetQuery(
      conn,
      "SELECT disease_ontology_id FROM disease_ontology_set
       WHERE disease_ontology_id = 'OMIM:618524' LIMIT 1"
    )

    if (nrow(existing) == 0L) {
      testthat::skip(
        "disease_ontology_set has no OMIM:618524 test row — skip DB write test"
      )
    }

    derived <- disease_mapping_derive(conn, MONDO_TARGET_ALLOWLIST)
    expect_true("disease_ontology_id" %in% names(derived))
    expect_true(any(derived$disease_ontology_id == "OMIM:618524"))

    # Check MONDO mapping row exists
    mondo_row <- derived[
      !is.na(derived$disease_ontology_id) & derived$disease_ontology_id == "OMIM:618524" &
      !is.na(derived$mondo_id),
      ,
      drop = FALSE
    ]
    expect_true(nrow(mondo_row) > 0L)
    expect_true(any(!is.na(derived$target_id) & derived$target_id == "Orphanet:530983"))

    disease_mapping_write(conn, derived, "2026-05-05")

    # Verify disease_ontology_mapping populated
    mapping_count <- DBI::dbGetQuery(
      conn,
      "SELECT COUNT(*) AS n FROM disease_ontology_mapping
       WHERE disease_ontology_id = 'OMIM:618524'"
    )$n
    expect_gte(mapping_count, 1L)

    # Verify sysndd_native row
    native_row <- DBI::dbGetQuery(
      conn,
      "SELECT * FROM disease_ontology_mapping
       WHERE disease_ontology_id = 'OMIM:618524'
         AND source = 'sysndd_native' LIMIT 1"
    )
    expect_equal(nrow(native_row), 1L)
  })
})

test_that("disease_mapping_derive returns native rows for all disease_ontology_ids", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    if (!DBI::dbExistsTable(conn, "mondo_xref") ||
        !DBI::dbExistsTable(conn, "disease_ontology_set")) {
      testthat::skip("Required tables not found")
    }

    # Empty xref table — should still get native rows
    DBI::dbExecute(conn, "DELETE FROM mondo_xref")

    dos_count <- DBI::dbGetQuery(
      conn,
      "SELECT COUNT(DISTINCT disease_ontology_id) AS n FROM disease_ontology_set"
    )$n

    if (dos_count == 0L) {
      testthat::skip("disease_ontology_set is empty")
    }

    derived <- disease_mapping_derive(conn, MONDO_TARGET_ALLOWLIST)
    native_count <- sum(derived$source == "sysndd_native", na.rm = TRUE)
    expect_gte(native_count, 1L)
  })
})
