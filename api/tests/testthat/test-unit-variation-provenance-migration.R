# tests/testthat/test-unit-variation-provenance-migration.R
#
# Migration smoke test for 047_add_variation_ontology_provenance.sql (#608).
#
# Applies migration 047 directly to the test database (mirroring the
# apply_test_analysis_snapshot_release_migration() / apply-through-
# split_sql_statements() idiom in test-unit-analysis-snapshot-release-migration.R)
# and asserts the two provenance tables exist, enforce their identity/FK/CHECK
# constraints (including the charset derivation the migration's FK depends on),
# and that the migration text never touches ndd_review_variation_ontology_connect.
#
# Migration 047 has FKs to `ndd_entity`, `variation_ontology_list`,
# `modifier_list`, and `user`. This file creates ALL FOUR of those fixture
# tables itself (ensure_test_user_table() for `user`, plus
# ensure_variation_provenance_fk_fixture_tables() for the other three, mirrored
# on the stripped-down shapes api/tests/testthat/test-integration-review-write-
# atomicity.R happens to use) rather than relying on that other file having
# already created them. Review finding I1 (2026-07-30 review-foundation.md):
# an earlier revision of this file only *checked* for those three tables and
# `skip()`ped if absent, so running this file alone (or with that file
# excluded/reordered) skipped past the table-existence assertions straight to
# the identity/FK/CHECK/idempotency block with zero of it actually executing,
# while still reporting green. Creating the fixtures here makes that skip path
# unreachable and this file self-sufficient in isolation.
#
# Because the migration's CREATE TABLE statements are guarded via
# information_schema existence checks (DDL auto-commits and cannot be rolled
# back), the test drops the two provenance tables itself at the end so reruns
# stay idempotent.

migration_test_api_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
source(file.path(migration_test_api_dir, "functions", "migration-manifest.R"), local = FALSE)

test_that("migration manifest tracks the latest migration", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "053_fix_variation_agreement_constraint_guard.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 51L)
})

test_that("migration 047 never mentions ndd_review_variation_ontology_connect", {
  sql <- read_variation_provenance_migration_sql()
  expect_false(grepl("ndd_review_variation_ontology_connect", sql, fixed = TRUE))
})

test_that("migration 047 creates the assertion + evidence tables with working constraints", {
  skip_if_no_test_db()

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))

  ensure_test_user_table(conn)
  ensure_variation_provenance_fk_fixture_tables(conn)

  # Teardown is registered BEFORE the destructive drop below, not after the
  # assertions. Any expectation failure or DB error in between aborts this
  # block, and a restore registered later would simply never run -- leaving the
  # shared schema destroyed for every later file AND every subsequent run,
  # which is the exact failure this teardown exists to prevent.
  #
  # Both steps live in ONE handler because their order is load-bearing:
  # variation_ontology_assertion FKs to ndd_entity, so the assertion/evidence
  # tables must be dropped and rebuilt BEFORE the FK-target cleanup deletes the
  # entity row they reference. `fk_target_ids` is filled in further down; the
  # handler reads it at unwind time, and stays a no-op if seeding never got
  # that far.
  fk_target_ids <- NULL
  withr::defer({
    # tryCatch(finally = ), not two sequential calls: the FK-target cleanup has
    # to run even when the restore THROWS -- and the restore's new replay guard
    # throws precisely when the schema has drifted, which is the worst moment to
    # also leave fixture rows behind. `finally` still lets the restore error
    # propagate, so a failed restore is never silent.
    tryCatch(
      restore_variation_provenance_tables(conn),
      finally = if (!is.null(fk_target_ids)) {
        cleanup_variation_provenance_fk_targets(conn, fk_target_ids)
      }
    )
  })

  # Clean slate: drop any leftovers from a prior interrupted run so the
  # dynamic CREATE TABLE guards actually create fresh tables here.
  drop_variation_provenance_tables(conn)

  apply_variation_provenance_migration(conn)

  expect_true(DBI::dbExistsTable(conn, "variation_ontology_assertion"))
  expect_true(DBI::dbExistsTable(conn, "variation_ontology_evidence"))

  assertion_cols <- DBI::dbListFields(conn, "variation_ontology_assertion")
  expect_true(all(c(
    "assertion_id", "entity_id", "vario_id", "modifier_id", "state",
    "confirmed_by", "confirmed_at", "rejected_reason", "created_at", "updated_at"
  ) %in% assertion_cols))

  evidence_cols <- DBI::dbListFields(conn, "variation_ontology_evidence")
  expect_true(all(c(
    "evidence_id", "assertion_id", "source_type", "source_key", "batch_id",
    "source_version", "evidence_summary", "evidence_strength", "evidence_json", "created_at"
  ) %in% evidence_cols))

  # --- I2 fix: all five FKs actually exist, naming referenced table/column ---
  fk_info <- DBI::dbGetQuery(
    conn,
    "SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
     FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME IN ('variation_ontology_assertion', 'variation_ontology_evidence')
       AND REFERENCED_TABLE_NAME IS NOT NULL"
  )
  fk_actual <- setNames(
    paste(fk_info$COLUMN_NAME, fk_info$REFERENCED_TABLE_NAME, fk_info$REFERENCED_COLUMN_NAME, sep = "->"),
    fk_info$CONSTRAINT_NAME
  )
  fk_expected <- c(
    fk_assertion_entity   = "entity_id->ndd_entity->entity_id",
    fk_assertion_vario    = "vario_id->variation_ontology_list->vario_id",
    fk_assertion_modifier = "modifier_id->modifier_list->modifier_id",
    fk_assertion_user     = "confirmed_by->user->user_id",
    fk_evidence_assertion = "assertion_id->variation_ontology_assertion->assertion_id"
  )
  expect_setequal(names(fk_actual), names(fk_expected))
  expect_equal(fk_actual[names(fk_expected)], fk_expected)

  # --- I2 fix: the charset derivation is meaningful, not decorative -- the
  # FK column on the new table must carry the SAME charset/collation as the
  # referenced variation_ontology_list.vario_id column, whatever that is live.
  vario_charset_info <- DBI::dbGetQuery(
    conn,
    "SELECT TABLE_NAME, CHARACTER_SET_NAME, COLLATION_NAME FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'vario_id'
       AND TABLE_NAME IN ('variation_ontology_list', 'variation_ontology_assertion')"
  )
  expect_equal(nrow(vario_charset_info), 2L)
  expect_equal(length(unique(vario_charset_info$CHARACTER_SET_NAME)), 1L)
  expect_equal(length(unique(vario_charset_info$COLLATION_NAME)), 1L)

  ids <- seed_variation_provenance_fk_targets(conn)
  fk_target_ids <- ids

  # --- Identity: present (1) and absent (5) are independent assertion rows ---
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
     VALUES (?, ?, 1, 'suggested')",
    params = unname(list(ids$entity_id, ids$vario_id))
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
     VALUES (?, ?, 5, 'suggested')",
    params = unname(list(ids$entity_id, ids$vario_id))
  )

  row_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM variation_ontology_assertion WHERE entity_id = ? AND vario_id = ?",
    params = unname(list(ids$entity_id, ids$vario_id))
  )$n
  expect_equal(as.integer(row_count), 2L)

  # Re-inserting the identical (entity_id, vario_id, modifier_id) triple violates uq_assertion.
  expect_error(
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
       VALUES (?, ?, 1, 'suggested')",
      params = unname(list(ids$entity_id, ids$vario_id))
    )
  )

  # --- chk_strength_range rejects evidence_strength = 5 (valid range is 0-4) ---
  assertion_id <- as.integer(DBI::dbGetQuery(
    conn,
    "SELECT assertion_id FROM variation_ontology_assertion WHERE entity_id = ? AND vario_id = ? AND modifier_id = 1",
    params = unname(list(ids$entity_id, ids$vario_id))
  )$assertion_id[1])

  expect_error(
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_evidence
         (assertion_id, source_type, source_key, batch_id, evidence_summary, evidence_strength)
       VALUES (?, 'literature', 'pubmed', 'batch-1', 'test evidence', 5)",
      params = unname(list(assertion_id))
    )
  )

  # A valid strength (within 0-4) succeeds.
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_evidence
       (assertion_id, source_type, source_key, batch_id, evidence_summary, evidence_strength)
     VALUES (?, 'literature', 'pubmed', 'batch-1', 'test evidence', 4)",
    params = unname(list(assertion_id))
  )

  # --- evidence_summary is NOT NULL: an explicit NULL is rejected ---
  # `evidence_summary` is a STORED column, not a projection of `evidence_json`:
  # the hot read path (functions/variation-provenance-repository.R) selects it
  # and deliberately never selects `evidence_json`, so a NULL that slipped in
  # would render a provenance line with no supporting text -- a silent, not a
  # loud, failure. Explicit NULL (rather than an omitted column) is what makes
  # this assertion sql_mode-independent: a single-row INSERT of NULL into a
  # NOT NULL column errors in every mode, whereas an omitted column only
  # errors under STRICT_TRANS_TABLES and would otherwise insert ''.
  expect_error(
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_evidence
         (assertion_id, source_type, source_key, batch_id, evidence_summary, evidence_strength)
       VALUES (?, 'literature', 'pubmed', 'batch-summary-null', NULL, 3)",
      params = unname(list(assertion_id))
    )
  )

  # --- chk_confirmed_attribution rejects state = 'confirmed' with NULL confirmed_by ---
  # Uses a second vario_id (modifier_id 1, already FK-valid) so this insert collides
  # with neither uq_assertion nor fk_assertion_modifier, isolating the CHECK failure.
  expect_error(
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at)
       VALUES (?, ?, 1, 'confirmed', NULL, NULL)",
      params = unname(list(ids$entity_id, ids$vario_id_2))
    )
  )

  # --- I2 fix: fk_assertion_entity is actually enforced on INSERT, not just
  # declared in the schema. Deleting the FK fragments from the migration's
  # CONCAT() would still pass every assertion above this one.
  bogus_entity_id <- 999999998L
  expect_error(
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
       VALUES (?, ?, 1, 'suggested')",
      params = unname(list(bogus_entity_id, ids$vario_id))
    )
  )

  # --- I2 fix: positive path -- state='confirmed' WITH a valid confirmed_by
  # and confirmed_at is ACCEPTED. Closes the implementer-flagged gap: a
  # chk_confirmed_attribution that rejected every legitimate confirm (not just
  # the NULL-attribution case above) would otherwise still pass this suite.
  # Reuses (entity_id, vario_id_2, modifier_id=1) -- the immediately preceding
  # NULL-attribution attempt on this exact key was rejected, so no row exists
  # for it yet and this insert cannot collide with uq_assertion.
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion
       (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at)
     VALUES (?, ?, 1, 'confirmed', ?, NOW())",
    params = unname(list(ids$entity_id, ids$vario_id_2, ids$user_id))
  )
  confirmed_row <- DBI::dbGetQuery(
    conn,
    "SELECT state, confirmed_by FROM variation_ontology_assertion
     WHERE entity_id = ? AND vario_id = ? AND modifier_id = 1",
    params = unname(list(ids$entity_id, ids$vario_id_2))
  )
  expect_equal(confirmed_row$state, "confirmed")
  expect_equal(as.integer(confirmed_row$confirmed_by), ids$user_id)

  # --- Idempotency: applying the migration again does not duplicate the tables ---
  apply_variation_provenance_migration(conn)

  expect_true(DBI::dbExistsTable(conn, "variation_ontology_assertion"))
  expect_true(DBI::dbExistsTable(conn, "variation_ontology_evidence"))

  table_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'variation_ontology_assertion'"
  )$n
  expect_equal(as.integer(table_count), 1L)

  # The rows from before the second apply must still be present (a real re-CREATE would
  # have dropped/recreated the table and lost them).
  row_count_after <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM variation_ontology_assertion WHERE entity_id = ? AND vario_id = ?",
    params = unname(list(ids$entity_id, ids$vario_id))
  )$n
  expect_equal(as.integer(row_count_after), 2L)

  # --- fk_evidence_assertion really cascades ---
  # ON DELETE CASCADE is declared inside the migration's CONCAT()-built DDL, so
  # -- exactly like the FKs asserted from information_schema above -- deleting
  # the clause would still pass every other assertion in this file. Evidence is
  # meaningless without the assertion that owns it, so an orphan row would be a
  # provenance record attached to nothing.
  #
  # Runs last, on a key no earlier block touched (vario_id_2 + modifier 5), so
  # the DELETE cannot perturb the counts asserted above.
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion (entity_id, vario_id, modifier_id, state)
     VALUES (?, ?, 5, 'suggested')",
    params = unname(list(ids$entity_id, ids$vario_id_2))
  )
  cascade_assertion_id <- as.integer(DBI::dbGetQuery(
    conn,
    "SELECT assertion_id FROM variation_ontology_assertion
     WHERE entity_id = ? AND vario_id = ? AND modifier_id = 5",
    params = unname(list(ids$entity_id, ids$vario_id_2))
  )$assertion_id[1])

  evidence_total_before <- as.integer(DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM variation_ontology_evidence"
  )$n)

  # Two rows, because a cascade that deleted only one would still satisfy a
  # bare "the row is gone" check. Distinct source_key values keep them clear of
  # uq_evidence (assertion_id, source_key, batch_id).
  for (evidence_source_key in c("clinvar", "gene2phenotype")) {
    DBI::dbExecute(
      conn,
      "INSERT INTO variation_ontology_evidence
         (assertion_id, source_type, source_key, batch_id, evidence_summary, evidence_strength)
       VALUES (?, 'external_database', ?, 'batch-cascade', 'cascade evidence', 2)",
      params = unname(list(cascade_assertion_id, evidence_source_key))
    )
  }

  owned_evidence <- function() {
    as.integer(DBI::dbGetQuery(
      conn,
      "SELECT COUNT(*) AS n FROM variation_ontology_evidence WHERE assertion_id = ?",
      params = unname(list(cascade_assertion_id))
    )$n)
  }
  expect_equal(owned_evidence(), 2L)

  DBI::dbExecute(
    conn,
    "DELETE FROM variation_ontology_assertion WHERE assertion_id = ?",
    params = unname(list(cascade_assertion_id))
  )

  expect_equal(owned_evidence(), 0L)

  # ...and it removed EXACTLY those two rows -- the evidence belonging to the
  # assertions seeded earlier in this test is untouched.
  evidence_total_after <- as.integer(DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM variation_ontology_evidence"
  )$n)
  expect_equal(evidence_total_after, evidence_total_before)
})
