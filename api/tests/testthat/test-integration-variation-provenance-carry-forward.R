# api/tests/testthat/test-integration-variation-provenance-carry-forward.R
#
# Real-RMariaDB regression coverage for variation_provenance_carry_forward_entity()
# (#608 gap closure).
#
# WHY THIS EXISTS
# ----------------
# #608's write-reconciliation state machine (functions/variation-provenance-reconcile.R)
# guarantees that a machine-derived, unconfirmed annotation can never silently become
# curator-authored -- because the ABSENCE of an assertion row for a term means
# "curator-authored". functions/entity-rename-service.R breaks that guarantee: a
# disease-ontology rename creates a brand-new entity_id and copies the curated
# ndd_review_variation_ontology_connect rows onto it, but says nothing about the
# assertion rows that carry provenance. Since assertions are keyed on entity_id, the
# new entity ends up with NO assertion rows at all -- which, under the feature's own
# contract, means every copied term now reads as curator-authored. A rename is not an
# act of confirmation; this file proves the fix (variation_provenance_carry_forward_entity())
# preserves state and attribution exactly, without ever promoting/demoting anything.
#
# The fixture DDL deliberately runs on its own connection: MySQL DDL commits
# implicitly, while each test below uses with_test_db_transaction() to call the real
# function directly against seeded rows.

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)
source_api_file("functions/variation-provenance-carry-forward.R", local = FALSE)

# ---------------------------------------------------------------------------
# Schema fixture
# ---------------------------------------------------------------------------

vpcf_ensure_schema <- function() {
  conn <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  ensure_test_user_table(conn)

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

  vpcf_apply_provenance_migration(conn)

  invisible(TRUE)
}

# The two provenance tables (#608, migration 047) are created by APPLYING the real
# migration rather than a hand-written CREATE TABLE IF NOT EXISTS pair, mirroring
# test-integration-review-write-atomicity.R's rationale: several test files share this
# test database and each other's fixture tables, so the only way to guarantee the
# assertion table's chk_confirmed_attribution CHECK and uq_assertion UNIQUE key exactly
# match what this test relies on is to apply migration 047 itself. Its CREATEs are
# guarded on an information_schema existence count, so this is idempotent.
vpcf_apply_provenance_migration <- function(conn) {
  if (!exists("split_sql_statements", mode = "function")) {
    source_api_file("functions/migration-runner.R", local = FALSE, envir = .GlobalEnv)
  }

  candidates <- c(
    file.path(get_api_dir(), "..", "db", "migrations", "047_add_variation_ontology_provenance.sql"),
    file.path(get_api_dir(), "db", "migrations", "047_add_variation_ontology_provenance.sql")
  )
  migration_path <- candidates[file.exists(candidates)]
  if (length(migration_path) == 0L) {
    stop("variation-ontology-provenance migration file is missing: ", candidates[[1L]])
  }

  sql <- paste(readLines(migration_path[[1L]], warn = FALSE), collapse = "\n")
  for (statement in split_sql_statements(sql)) {
    DBI::dbExecute(conn, statement, immediate = TRUE)
  }

  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Seed helpers
# ---------------------------------------------------------------------------

#' Seed one old/new entity pair plus one vario_id, all marker-keyed so
#' parallel test_that() blocks never collide.
vpcf_seed <- function(conn, marker) {
  user_id <- 987800L + marker
  old_entity_id <- as.integer(740000L + marker)
  new_entity_id <- as.integer(750000L + marker)
  vario_id <- sprintf("VariO:%04d", marker %% 10000L)

  DBI::dbExecute(
    conn,
    "INSERT IGNORE INTO `user` (user_id, user_name) VALUES (?, ?)",
    params = list(user_id, sprintf("vpcf-user-%d", marker))
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity (entity_id, entry_user_id) VALUES (?, ?)",
    params = list(old_entity_id, user_id)
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO ndd_entity (entity_id, entry_user_id) VALUES (?, ?)",
    params = list(new_entity_id, user_id)
  )
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_list (vario_id) VALUES (?)",
    params = list(vario_id)
  )
  DBI::dbExecute(conn, "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (1)")
  # modifier 5 ('absent') is the other half of the (vario_id, modifier_id)
  # assertion identity -- needed for the present/absent independence test.
  DBI::dbExecute(conn, "INSERT IGNORE INTO modifier_list (modifier_id) VALUES (5)")

  list(
    user_id = user_id,
    old_entity_id = old_entity_id,
    new_entity_id = new_entity_id,
    vario_id = vario_id
  )
}

#' Insert one assertion row directly (bypassing the reconciliation state
#' machine entirely -- this file tests the carry-forward copy, not the
#' planner/applier already covered by test-unit-variation-provenance-reconcile.R
#' and test-integration-review-write-atomicity.R).
vpcf_insert_assertion <- function(conn, entity_id, vario_id, modifier_id, state,
                                  confirmed_by = NA_integer_, confirmed_at = NA_character_,
                                  rejected_reason = NA_character_) {
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_assertion
       (entity_id, vario_id, modifier_id, state, confirmed_by, confirmed_at, rejected_reason)
     VALUES (?, ?, ?, ?, ?, ?, ?)",
    params = list(
      as.integer(entity_id), vario_id, as.integer(modifier_id), state,
      confirmed_by, confirmed_at, rejected_reason
    )
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

vpcf_insert_evidence <- function(conn, assertion_id, source_type = "literature",
                                 source_key = "PMID:1", batch_id = "batch-1",
                                 source_version = "v1", evidence_summary = "seed evidence",
                                 evidence_strength = 3L, evidence_json = '{"n":1}') {
  DBI::dbExecute(
    conn,
    "INSERT INTO variation_ontology_evidence
       (assertion_id, source_type, source_key, batch_id, source_version,
        evidence_summary, evidence_strength, evidence_json)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(
      as.integer(assertion_id), source_type, source_key, batch_id,
      source_version, evidence_summary, as.integer(evidence_strength), evidence_json
    )
  )
  as.integer(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1L]])
}

vpcf_assertion_row <- function(conn, entity_id, vario_id, modifier_id) {
  DBI::dbGetQuery(
    conn,
    "SELECT assertion_id, state, confirmed_by, confirmed_at, rejected_reason
       FROM variation_ontology_assertion
      WHERE entity_id = ? AND vario_id = ? AND modifier_id = ?",
    params = list(as.integer(entity_id), vario_id, as.integer(modifier_id))
  )
}

vpcf_assertion_count <- function(conn, entity_id) {
  DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM variation_ontology_assertion WHERE entity_id = ?",
    params = list(as.integer(entity_id))
  )$n[[1L]]
}

vpcf_evidence_count_for_entity <- function(conn, entity_id) {
  DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n
       FROM variation_ontology_evidence e
       JOIN variation_ontology_assertion a ON a.assertion_id = e.assertion_id
      WHERE a.entity_id = ?",
    params = list(as.integer(entity_id))
  )$n[[1L]]
}

vpcf_db_ready <- test_db_available()
if (isTRUE(vpcf_db_ready)) {
  vpcf_ensure_schema()
}

# ===========================================================================
# Tests
# ===========================================================================

test_that("#608: a confirmed assertion carries forward to the new entity with its ORIGINAL confirmed_by/confirmed_at, not re-attributed to the renaming user", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 201L)
    original_curator_id <- fixture$user_id

    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "confirmed", confirmed_by = original_curator_id,
      confirmed_at = "2024-01-15 10:30:00"
    )
    old_row <- vpcf_assertion_row(conn, fixture$old_entity_id, fixture$vario_id, 1L)

    carried <- variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )
    expect_identical(as.integer(carried), 1L)

    new_row <- vpcf_assertion_row(conn, fixture$new_entity_id, fixture$vario_id, 1L)
    expect_equal(nrow(new_row), 1L)
    expect_equal(new_row$state, "confirmed")
    # ORIGINAL attribution survives -- NOT re-attributed to whoever ran the rename.
    expect_equal(as.integer(new_row$confirmed_by), as.integer(original_curator_id))
    expect_false(is.na(new_row$confirmed_at))
    expect_equal(new_row$confirmed_at, old_row$confirmed_at)
    # Not the same row -- a genuinely new assertion_id on the new entity.
    expect_false(identical(new_row$assertion_id, old_row$assertion_id))
  })
})

test_that("ANTI-LAUNDERING #608: an active_unconfirmed (machine-derived, unconfirmed) assertion carries forward through a rename STILL active_unconfirmed -- never silently promoted to curator-authored", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 202L)

    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "active_unconfirmed"
    )

    carried <- variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )
    expect_identical(as.integer(carried), 1L)

    new_row <- vpcf_assertion_row(conn, fixture$new_entity_id, fixture$vario_id, 1L)
    expect_equal(nrow(new_row), 1L)
    # THE regression assertion: still machine-derived and unconfirmed, not
    # curator-authored, after crossing the rename boundary.
    expect_equal(new_row$state, "active_unconfirmed")
    expect_true(is.na(new_row$confirmed_by))
    expect_true(is.na(new_row$confirmed_at))
  })
})

test_that("#608: evidence rows carry forward attached to the NEW assertion_id, with evidence fields preserved verbatim", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 203L)

    old_assertion_id <- vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "active_unconfirmed"
    )
    vpcf_insert_evidence(
      conn, old_assertion_id,
      source_type = "external_database", source_key = "PMID:99887766",
      batch_id = "batch-2026-07-30", source_version = "v3",
      evidence_summary = "carry-forward evidence summary", evidence_strength = 2L,
      evidence_json = '{"tool":"pubtator","hits":3}'
    )

    variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )

    new_row <- vpcf_assertion_row(conn, fixture$new_entity_id, fixture$vario_id, 1L)
    new_evidence <- DBI::dbGetQuery(
      conn,
      "SELECT source_type, source_key, batch_id, source_version,
              evidence_summary, evidence_strength, evidence_json
         FROM variation_ontology_evidence
        WHERE assertion_id = ?",
      params = list(as.integer(new_row$assertion_id))
    )

    expect_equal(nrow(new_evidence), 1L)
    expect_equal(new_evidence$source_type, "external_database")
    expect_equal(new_evidence$source_key, "PMID:99887766")
    expect_equal(new_evidence$batch_id, "batch-2026-07-30")
    expect_equal(new_evidence$source_version, "v3")
    expect_equal(new_evidence$evidence_summary, "carry-forward evidence summary")
    expect_equal(as.integer(new_evidence$evidence_strength), 2L)
    expect_match(as.character(new_evidence$evidence_json), "pubtator")

    # The OLD evidence row is untouched, still attached to the OLD assertion.
    expect_equal(
      vpcf_evidence_count_for_entity(conn, fixture$old_entity_id),
      1L
    )
  })
})

test_that("#608: 'present' (modifier 1) and 'absent' (modifier 5) for the same vario_id carry forward as two independent rows", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 204L)

    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "active_unconfirmed"
    )
    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 5L,
      state = "confirmed", confirmed_by = fixture$user_id,
      confirmed_at = "2023-06-01 00:00:00"
    )

    carried <- variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )
    expect_identical(as.integer(carried), 2L)

    present <- vpcf_assertion_row(conn, fixture$new_entity_id, fixture$vario_id, 1L)
    absent <- vpcf_assertion_row(conn, fixture$new_entity_id, fixture$vario_id, 5L)

    expect_equal(nrow(present), 1L)
    expect_equal(nrow(absent), 1L)
    expect_equal(present$state, "active_unconfirmed")
    expect_true(is.na(present$confirmed_by))
    expect_equal(absent$state, "confirmed")
    expect_equal(as.integer(absent$confirmed_by), as.integer(fixture$user_id))
    expect_false(identical(present$assertion_id, absent$assertion_id))
  })
})

test_that("#608: carrying forward twice is idempotent -- same row counts, no error, no duplicates", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 205L)

    old_confirmed_id <- vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "confirmed", confirmed_by = fixture$user_id,
      confirmed_at = "2022-03-03 03:03:03"
    )
    vpcf_insert_evidence(conn, old_confirmed_id, source_key = "PMID:555", batch_id = "batch-x")
    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 5L,
      state = "active_unconfirmed"
    )

    first <- variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )
    count_after_first <- vpcf_assertion_count(conn, fixture$new_entity_id)
    evidence_after_first <- vpcf_evidence_count_for_entity(conn, fixture$new_entity_id)

    second <- NULL
    expect_no_error(
      second <- variation_provenance_carry_forward_entity(
        fixture$old_entity_id, fixture$new_entity_id, conn = conn
      )
    )
    count_after_second <- vpcf_assertion_count(conn, fixture$new_entity_id)
    evidence_after_second <- vpcf_evidence_count_for_entity(conn, fixture$new_entity_id)

    expect_identical(as.integer(first), as.integer(second))
    expect_identical(count_after_first, count_after_second)
    expect_identical(evidence_after_first, evidence_after_second)
    expect_equal(count_after_second, 2L)
    expect_equal(evidence_after_second, 1L)
  })
})

test_that("#608: an entity with zero assertion rows carries forward zero rows and does not error (the normal case today -- the backfill has not run)", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 206L)
    # Deliberately NO assertion seeded.

    carried <- NULL
    expect_no_error(
      carried <- variation_provenance_carry_forward_entity(
        fixture$old_entity_id, fixture$new_entity_id, conn = conn
      )
    )

    expect_identical(as.integer(carried), 0L)
    expect_equal(vpcf_assertion_count(conn, fixture$new_entity_id), 0L)
    expect_equal(vpcf_assertion_count(conn, fixture$old_entity_id), 0L)
  })
})

test_that("#608: the source entity's assertion rows are left in place after carry-forward -- this is a copy, not a migration", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    fixture <- vpcf_seed(conn, 207L)

    vpcf_insert_assertion(
      conn, fixture$old_entity_id, fixture$vario_id, modifier_id = 1L,
      state = "confirmed", confirmed_by = fixture$user_id,
      confirmed_at = "2021-09-09 09:09:09"
    )

    variation_provenance_carry_forward_entity(
      fixture$old_entity_id, fixture$new_entity_id, conn = conn
    )

    old_row <- vpcf_assertion_row(conn, fixture$old_entity_id, fixture$vario_id, 1L)
    expect_equal(nrow(old_row), 1L)
    expect_equal(old_row$state, "confirmed")
    expect_equal(as.integer(old_row$confirmed_by), as.integer(fixture$user_id))
    expect_equal(vpcf_assertion_count(conn, fixture$old_entity_id), 1L)
  })
})
