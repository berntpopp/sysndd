# tests/testthat/helper-variation-provenance-migration.R
#
# Schema helpers for test-unit-variation-provenance-migration.R: apply migration
# 047 from source, drop the two provenance tables, and -- the part that matters
# -- PUT THEM BACK.
#
# Extracted from the test file so it stays under the 600-line ceiling, and so
# the drop/restore contract (the delicate half) reads on its own. testthat
# auto-loads helper-*.R, and helper-paths.R -- which defines get_api_dir(),
# called below at CALL time, not load time -- sorts before this file.
#
# These functions define no tests and touch no database until called, so being
# loaded for every file in the directory costs nothing.

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

#' Teardown: drop this file's tables, then PUT THE SCHEMA BACK.
#'
#' This file re-applies migration 047 from scratch to verify its DDL, so it must
#' start from a clean slate -- but it must not LEAVE one. The bare drop was
#' written when the test database had no provenance tables at all, so dropping
#' was "remove what I created". Since #612 the suite runs against a fully
#' migrated database, and a bare drop instead DESTROYS REAL SCHEMA: every later
#' file that touches an assertion then fails with
#' "Table 'variation_ontology_assertion' doesn't exist" -- and so does every
#' subsequent run against that database, because nothing ever puts it back.
#' That is exactly how test-integration-entity-rename.R started returning 500s.
restore_variation_provenance_tables <- function(conn) {
  drop_variation_provenance_tables(conn)

  # Re-apply through the REAL migration runner, not by hand. 047 alone is not
  # the current shape: 049 adds variation_ontology_evidence.origin_review_id,
  # and every later reader of that column fails without it. Clearing exactly
  # these two rows from schema_version and letting run_migrations() re-apply
  # them uses the same code path production does, so the restored DDL cannot
  # drift from the migrations.
  #
  # (An earlier comment here claimed 049's PREPARE/EXECUTE guard "does not
  # survive naive statement splitting". That is wrong, and worth correcting
  # rather than deleting: split_sql_statements() DOES split 049 on `;` +
  # newline, and it works because SET/PREPARE/EXECUTE/DEALLOCATE are session
  # scoped, so they remain valid as sequential statements on one connection.
  # The reason to use the runner is completeness across migrations, not
  # splitting.)
  migrations_dir <- dirname(variation_provenance_migration_path())
  affected <- list.files(migrations_dir, pattern = "^(047|049)_.*[.]sql$")

  if (DBI::dbExistsTable(conn, "schema_version") && length(affected) > 0L) {
    DBI::dbExecute(
      conn,
      paste0(
        "DELETE FROM schema_version WHERE filename IN (",
        paste(rep("?", length(affected)), collapse = ", "), ")"
      ),
      params = unname(as.list(affected))
    )
  }

  if (!exists("run_migrations", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }
  replayed <- run_migrations(migrations_dir = migrations_dir, conn = conn)

  # run_migrations() applies EVERY file missing from schema_version, not an
  # allowlist. On a healthy database that is exactly the two rows deleted above;
  # anything else means the shared schema had drifted before this file ran, and
  # a teardown quietly re-applying unrelated migrations is not something to
  # discover later. Name it here.
  replayed_files <- if (is.null(replayed$filenames)) character(0) else replayed$filenames
  unexpected <- setdiff(replayed_files, affected)
  if (length(unexpected) > 0) {
    stop(
      "restore_variation_provenance_tables(): expected to re-apply only ",
      paste(affected, collapse = ", "), " but the runner also applied ",
      paste(unexpected, collapse = ", "),
      ". The test database's schema_version had drifted before this file ran.",
      call. = FALSE
    )
  }

  # Verify, do not assume. A restore that silently comes back INCOMPLETE is
  # worse than no restore: the table exists, so nothing looks wrong, and the
  # failure surfaces later as an opaque "Unknown column" in an unrelated file.
  # Fail here, naming the gap, so the next reader is not sent hunting.
  restored <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'variation_ontology_evidence'
        AND COLUMN_NAME = 'origin_review_id'"
  )$n[[1]]
  if (as.integer(restored) != 1L) {
    stop(
      "restore_variation_provenance_tables(): re-applied the migrations but ",
      "variation_ontology_evidence.origin_review_id (migration 049) is missing. ",
      "The shared test schema is now incomplete for every later file.",
      call. = FALSE
    )
  }

  invisible(TRUE)
}

#' Ensure the three non-`user` FK-target tables migration 047 references exist,
#' creating minimal fixtures if not. Mirrors ensure_test_user_table()'s own
#' idiom and the exact stripped-down shapes
#' test-integration-review-write-atomicity.R already uses in this test DB
#' (`CREATE TABLE IF NOT EXISTS`, so if that file's fuller/differently-shaped
#' tables already exist, this is a no-op and their shape wins -- consistent
#' with insert_only_existing_columns() below tolerating either shape). This is
#' the I1 fix (review-foundation.md, 2026-07-30): without creating these here,
#' this file's own constraint verification silently no-ops if it is ever run
#' without that other file having run first.
ensure_variation_provenance_fk_fixture_tables <- function(conn) {
  statements <- c(
    "CREATE TABLE IF NOT EXISTS ndd_entity (
       entity_id INT NOT NULL PRIMARY KEY,
       entry_user_id INT NULL
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS variation_ontology_list (
       vario_id VARCHAR(10) NOT NULL PRIMARY KEY
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
    "CREATE TABLE IF NOT EXISTS modifier_list (
       modifier_id INT NOT NULL PRIMARY KEY
     ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
  )
  for (statement in statements) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
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
#' returning their ids. The four FK-target tables themselves are guaranteed to
#' exist by the caller (ensure_test_user_table() +
#' ensure_variation_provenance_fk_fixture_tables(), both called before this),
#' so there is no longer a missing-table skip path here (I1 fix).
seed_variation_provenance_fk_targets <- function(conn) {
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
