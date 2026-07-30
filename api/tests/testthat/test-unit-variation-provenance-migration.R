# tests/testthat/test-unit-variation-provenance-migration.R
#
# Migration smoke test for 047_add_variation_ontology_provenance.sql (#608).
#
# Applies migration 047 directly to the test database (mirroring the
# apply_test_analysis_snapshot_release_migration() / apply-through-
# split_sql_statements() idiom in test-unit-analysis-snapshot-release-migration.R)
# and asserts the two provenance tables exist, enforce their identity/CHECK
# constraints, and that the migration text never touches
# ndd_review_variation_ontology_connect. Migration 047 has FKs to `ndd_entity`,
# `variation_ontology_list`, `modifier_list`, and `user`, so this test seeds
# minimal rows in each (creating the user fixture table via
# ensure_test_user_table() first) and cleans them up. Because the migration's
# CREATE TABLE statements are guarded via information_schema existence checks
# (DDL auto-commits and cannot be rolled back), the test drops the two
# provenance tables itself at the end so reruns stay idempotent.

migration_test_api_dir <- Sys.getenv("MCP_API_TEST_ROOT", get_api_dir())
source(file.path(migration_test_api_dir, "functions", "migration-manifest.R"), local = FALSE)

variation_provenance_migration_path <- function() {
  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "047_add_variation_ontology_provenance.sql"),
    file.path(get_api_dir(), "db", "migrations", "047_add_variation_ontology_provenance.sql")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  candidates[[1]]
}

read_variation_provenance_migration_sql <- function() {
  migration_path <- variation_provenance_migration_path()
  if (!file.exists(migration_path)) {
    stop("variation-ontology-provenance migration file is missing: ", migration_path)
  }

  paste(readLines(migration_path, warn = FALSE), collapse = "\n")
}

apply_variation_provenance_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  sql <- read_variation_provenance_migration_sql()
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

drop_variation_provenance_tables <- function(conn) {
  # Children first, then the parent (FK ON DELETE CASCADE dependency order).
  for (tbl in c("variation_ontology_evidence", "variation_ontology_assertion")) {
    if (DBI::dbExistsTable(conn, tbl)) {
      DBI::dbExecute(conn, paste0("DROP TABLE `", tbl, "`"), immediate = TRUE)
    }
  }
  invisible(TRUE)
}

#' Insert a row into `table` using only the given values whose column name
#' actually exists on the live table. Mirrors review_write_insert_entity() in
#' test-integration-review-write-atomicity.R, because this test DB's FK-target
#' tables may be either the full production schema or a stripped-down fixture
#' left behind by another test (e.g. `ndd_entity` here has just `entity_id`
#' and `entry_user_id`; `variation_ontology_list` and `modifier_list` have
#' just their primary key column) -- never assume the fuller shape.
insert_only_existing_columns <- function(conn, table, values) {
  fields <- DBI::dbListFields(conn, table)
  values <- values[names(values) %in% fields]
  if (length(values) == 0) {
    return(invisible(NULL))
  }

  sql <- sprintf(
    "INSERT INTO `%s` (%s) VALUES (%s)",
    table,
    paste(names(values), collapse = ", "),
    paste(rep("?", length(values)), collapse = ", ")
  )
  DBI::dbExecute(conn, sql, params = unname(values))
}

#' Ensure the minimal FK-target rows this migration's tables reference exist,
#' returning their ids. Skips (does not error) if a required FK target table
#' is missing entirely.
seed_variation_provenance_fk_targets <- function(conn) {
  required_tables <- c("ndd_entity", "variation_ontology_list", "modifier_list", "user")
  missing <- required_tables[!vapply(required_tables, DBI::dbExistsTable, logical(1), conn = conn)]
  if (length(missing) > 0) {
    testthat::skip(paste(
      "Required FK target table(s) missing from test DB:",
      paste(missing, collapse = ", ")
    ))
  }

  # Check-before-insert (not just INSERT IGNORE) so a prior interrupted run's
  # leftover row is detected and reused rather than erroring on this rerun,
  # and so cleanup below only removes rows this run actually created.
  test_user_id <- 900001L
  existing_user <- DBI::dbGetQuery(
    conn,
    "SELECT user_id FROM user WHERE user_id = ?",
    params = unname(list(test_user_id))
  )
  created_user <- nrow(existing_user) == 0
  if (created_user) {
    insert_only_existing_columns(
      conn, "user",
      list(user_id = test_user_id, user_name = "vario_provenance_test_user")
    )
  }

  test_vario_id <- "VarioTEST1"
  test_vario_id_2 <- "VarioTEST2"
  created_vario_ids <- character(0)
  for (vid in c(test_vario_id, test_vario_id_2)) {
    existing_vario <- DBI::dbGetQuery(
      conn,
      "SELECT vario_id FROM variation_ontology_list WHERE vario_id = ?",
      params = unname(list(vid))
    )
    if (nrow(existing_vario) == 0) {
      insert_only_existing_columns(
        conn, "variation_ontology_list",
        list(vario_id = vid, vario_name = "provenance test term")
      )
      created_vario_ids <- c(created_vario_ids, vid)
    }
  }

  created_modifier_ids <- integer(0)
  for (mod_id in c(1L, 5L)) {
    existing_mod <- DBI::dbGetQuery(
      conn,
      "SELECT modifier_id FROM modifier_list WHERE modifier_id = ?",
      params = unname(list(mod_id))
    )
    if (nrow(existing_mod) == 0) {
      insert_only_existing_columns(
        conn, "modifier_list",
        list(
          modifier_id = mod_id,
          modifier_name = if (mod_id == 1L) "present" else "absent",
          allowed_variation = 1L
        )
      )
      created_modifier_ids <- c(created_modifier_ids, mod_id)
    }
  }

  test_entity_id <- 920001L
  existing_entity <- DBI::dbGetQuery(
    conn,
    "SELECT entity_id FROM ndd_entity WHERE entity_id = ?",
    params = unname(list(test_entity_id))
  )
  created_entity <- nrow(existing_entity) == 0
  if (created_entity) {
    insert_only_existing_columns(
      conn, "ndd_entity",
      list(entity_id = test_entity_id, entry_user_id = test_user_id)
    )
  }

  # Only rows this function actually created are cleaned up later -- ambient
  # rows in a fuller (e.g. production-shaped) schema copy, or a leftover row
  # from a prior interrupted run, must survive / be reused rather than erroring.
  list(
    user_id = test_user_id,
    vario_id = test_vario_id,
    vario_id_2 = test_vario_id_2,
    entity_id = test_entity_id,
    created_user = created_user,
    created_entity = created_entity,
    created_vario_ids = created_vario_ids,
    created_modifier_ids = created_modifier_ids
  )
}

cleanup_variation_provenance_fk_targets <- function(conn, ids) {
  if (isTRUE(ids$created_entity)) {
    DBI::dbExecute(conn, "DELETE FROM ndd_entity WHERE entity_id = ?", params = unname(list(ids$entity_id)))
  }
  for (vid in ids$created_vario_ids) {
    DBI::dbExecute(conn, "DELETE FROM variation_ontology_list WHERE vario_id = ?", params = unname(list(vid)))
  }
  for (mod_id in ids$created_modifier_ids) {
    DBI::dbExecute(conn, "DELETE FROM modifier_list WHERE modifier_id = ?", params = unname(list(mod_id)))
  }
  if (isTRUE(ids$created_user)) {
    DBI::dbExecute(conn, "DELETE FROM user WHERE user_id = ?", params = unname(list(ids$user_id)))
  }
  invisible(TRUE)
}

test_that("migration manifest expects migration 047 as latest", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "047_add_variation_ontology_provenance.sql")
  expect_equal(EXPECTED_MIGRATION_COUNT, 45L)
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

  # Clean slate: drop any leftovers from a prior interrupted run so the
  # dynamic CREATE TABLE guards actually create fresh tables here. The
  # matching teardown defer is registered further down, AFTER the
  # FK-target-cleanup defer -- withr::defer() unwinds LIFO, and
  # variation_ontology_assertion FKs to ndd_entity, so the assertion/evidence
  # tables must be dropped BEFORE the FK-target cleanup deletes the entity
  # row they reference.
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

  ids <- seed_variation_provenance_fk_targets(conn)
  withr::defer(cleanup_variation_provenance_fk_targets(conn, ids))
  withr::defer(drop_variation_provenance_tables(conn))

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
})
