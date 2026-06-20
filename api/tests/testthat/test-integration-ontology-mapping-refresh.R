# test-integration-ontology-mapping-refresh.R
#
# End-to-end integration tests for the disease cross-ontology mapping refresh
# orchestrator (WP-H, H3). Exercises disease_ontology_mapping_refresh_run()
# with:
#   - download stubs that return the mondo-mini fixtures (no network calls),
#   - table-level cleanup via DELETE (not wrapping in with_test_db_transaction
#     because the orchestrator's own DBI::dbWithTransaction would conflict),
#   - explicit skip if the test DB or required tables are absent.
#
# The dedicated test DB (sysndd_db_test) is NOT provisioned with migration 036
# on this host during development, so these tests SKIP locally. In CI the test
# DB has the full schema applied and the tests run. Do NOT fake the test DB —
# the skip is correct.
#
# Note: we do NOT wrap calls to disease_ontology_mapping_refresh_run() in
# with_test_db_transaction() because the orchestrator calls DBI::dbWithTransaction
# internally, which would raise "Nested transactions not supported" against a
# plain MySQL connection. Instead, each test cleans up its tables explicitly at
# the end via withr::defer(). Tests that only call lower-level repository
# functions (mondo_index_write, disease_mapping_write) still use the rollback
# pattern through with_test_db_transaction().
#
# Two orchestrator scenarios are covered:
#   1. Full rebuild — stubs return fixture paths → tables populated, success
#      meta row written.
#   2. No-op 304 path — stubs signal not_modified + tables populated →
#      skipped meta row, no term churn.
#
# One low-level scenario:
#   3. Inactive entity resolution — disease_mapping_for_entity(0) returns
#      status="missing" when entity_id is not in ndd_entity_view.

library(testthat)
library(tibble)

source_api_file("functions/disease-ontology-mapping-refresh.R", local = FALSE)
source_api_file("functions/mondo-index-builder.R", local = FALSE)
source_api_file("functions/disease-ontology-mapping-builder.R", local = FALSE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.fixture_obo_path <- function() {
  testthat::test_path("fixtures", "mondo-mini.obo")
}

.fixture_sssom_path <- function() {
  testthat::test_path("fixtures", "mondo-mini.sssom.tsv")
}

# Stub: fake download_obo_fn returning a 200 result pointing at the fixture.
.stub_obo_200 <- function(obo_url = NULL) {
  list(
    path          = .fixture_obo_path(),
    etag          = "\"mini-etag-v1\"",
    last_modified = "Sat, 10 May 2026 00:00:00 GMT",
    not_modified  = FALSE,
    status        = 200L
  )
}

# Stub: fake download_obo_fn returning a 304 (not-modified) result.
.stub_obo_304 <- function(obo_url = NULL) {
  list(
    path          = NULL,
    etag          = "\"mini-etag-v1\"",
    last_modified = "Sat, 10 May 2026 00:00:00 GMT",
    not_modified  = TRUE,
    status        = 304L
  )
}

# Temporarily override a function in the global environment for the duration
# of the current test_that block (uses withr::defer_parent for cleanup).
.override_global_fn <- function(name, stub_fn) {
  old_val <- if (exists(name, envir = .GlobalEnv, inherits = FALSE)) {
    get(name, envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  assign(name, stub_fn, envir = .GlobalEnv)
  withr::defer_parent(
    if (is.null(old_val)) {
      if (exists(name, envir = .GlobalEnv, inherits = FALSE)) {
        rm(list = name, envir = .GlobalEnv)
      }
    } else {
      assign(name, old_val, envir = .GlobalEnv)
    }
  )
  invisible(NULL)
}

# Get a live (non-transactional) test DB connection.
# Returns NULL + skip if test DB is unavailable.
.get_direct_test_conn <- function() {
  if (!test_db_available()) {
    testthat::skip("Test database (sysndd_db_test) not available")
  }
  get_test_db_connection()
}

# Seed disease_ontology_set with a minimal OMIM row.
.seed_disease_ontology_set_omim <- function(conn, disease_id = "OMIM:618524") {
  existing <- tryCatch(
    DBI::dbGetQuery(
      conn,
      "SELECT disease_ontology_id FROM disease_ontology_set
       WHERE disease_ontology_id = ? LIMIT 1",
      params = unname(list(disease_id))
    ),
    error = function(e) data.frame()
  )
  if (nrow(existing) > 0L) {
    return(invisible(TRUE))
  }
  tryCatch(
    DBI::dbExecute(
      conn,
      paste0(
        "INSERT INTO disease_ontology_set (disease_ontology_id, disease_ontology_name) ",
        "VALUES (?, ?)"
      ),
      params = unname(list(disease_id, "CTNNB1 syndrome (test seed)"))
    ),
    error = function(e) {
      message("[H3] disease_ontology_set seed failed (may already exist or schema differs): ",
              conditionMessage(e))
    }
  )
  invisible(TRUE)
}

# Clean out the mapping tables between tests.
.cleanup_mapping_tables <- function(conn) {
  tryCatch(DBI::dbExecute(conn, "DELETE FROM disease_ontology_mapping_meta"),
           error = function(e) NULL)
  tryCatch(DBI::dbExecute(conn, "DELETE FROM disease_ontology_mapping"),
           error = function(e) NULL)
  tryCatch(DBI::dbExecute(conn, "DELETE FROM mondo_xref"),
           error = function(e) NULL)
  tryCatch(DBI::dbExecute(conn, "DELETE FROM mondo_term"),
           error = function(e) NULL)
}

# ---------------------------------------------------------------------------
# Scenario 1: Full rebuild with mini fixtures
# ---------------------------------------------------------------------------

test_that("full refresh run populates tables and writes a success meta row", {
  conn <- .get_direct_test_conn()
  withr::defer(DBI::dbDisconnect(conn))

  if (!DBI::dbExistsTable(conn, "mondo_term")) {
    testthat::skip(
      "mondo_term table not found — migration 036 not applied on test DB; skip."
    )
  }
  if (!DBI::dbExistsTable(conn, "disease_ontology_mapping_meta")) {
    testthat::skip(
      "disease_ontology_mapping_meta not found — migration 036 not applied; skip."
    )
  }
  if (!DBI::dbExistsTable(conn, "disease_ontology_set")) {
    testthat::skip(
      "disease_ontology_set not found — base schema not initialized on this test DB; skip."
    )
  }

  withr::defer(.cleanup_mapping_tables(conn))

  # Override download_mondo_sssom_full for the duration of this test.
  .override_global_fn(
    "download_mondo_sssom_full",
    function(...) .fixture_sssom_path()
  )

  # Seed disease_ontology_set row so projection UPDATE can find a target.
  .seed_disease_ontology_set_omim(conn)

  result <- disease_ontology_mapping_refresh_run(
    job             = list(job_id = "test-h3-full"),
    payload         = list(force = TRUE),
    pool_obj        = conn,
    checkout_fn     = function(p) p,
    return_fn       = function(conn) invisible(NULL),
    try_lock_fn     = function(conn) TRUE,
    release_lock_fn = function(conn) TRUE,
    download_obo_fn = .stub_obo_200,
    write_meta_fn   = .disease_ontology_mapping_write_meta
  )

  # 1a. Orchestrator reports success.
  expect_equal(result$status, "success",
    label = "result$status should be 'success'")
  expect_true(isTRUE(result$success),
    label = "result$success should be TRUE")
  expect_equal(result$reason, "rebuilt",
    label = "result$reason should be 'rebuilt'")

  # 1b. mondo_term table populated (mini OBO has 3 terms).
  term_count <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM mondo_term"
  )$n[[1]]
  expect_gte(as.integer(term_count), 1L,
    label = "mondo_term should have rows after rebuild")

  # 1c. mondo_xref table populated.
  xref_count <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM mondo_xref"
  )$n[[1]]
  expect_gte(as.integer(xref_count), 1L,
    label = "mondo_xref should have rows after rebuild")

  # 1d. disease_ontology_mapping populated with active rows.
  mapping_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM disease_ontology_mapping WHERE is_active = 1"
  )$n[[1]]
  expect_gte(as.integer(mapping_count), 1L,
    label = "disease_ontology_mapping should have active rows after rebuild")

  # 1e. disease_ontology_mapping_meta has a success row.
  meta_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM disease_ontology_mapping_meta WHERE status = 'success'"
  )$n[[1]]
  expect_gte(as.integer(meta_count), 1L,
    label = "disease_ontology_mapping_meta should have a status='success' row")

  # 1f. Provenance: release_version matches the mini OBO data-version header.
  meta_row <- DBI::dbGetQuery(
    conn,
    "SELECT mondo_release_version FROM disease_ontology_mapping_meta
     WHERE status = 'success' ORDER BY build_started_at DESC LIMIT 1"
  )
  expect_equal(meta_row$mondo_release_version[[1]], "2026-05-05",
    label = "meta row should record release_version from mini OBO header")

  # 1g. result counts are non-negative.
  expect_gte(result$mondo_term_count, 1L,
    label = "result$mondo_term_count should be >= 1")
  expect_gte(result$mapping_count, 1L,
    label = "result$mapping_count should be >= 1")
})

# ---------------------------------------------------------------------------
# Scenario 2: 304 no-op path (OBO unchanged + tables populated → skip)
# ---------------------------------------------------------------------------

test_that("second run with 304 OBO and populated tables skips rebuild", {
  conn <- .get_direct_test_conn()
  withr::defer(DBI::dbDisconnect(conn))

  if (!DBI::dbExistsTable(conn, "mondo_term")) {
    testthat::skip(
      "mondo_term table not found — migration 036 not applied on test DB; skip."
    )
  }
  if (!DBI::dbExistsTable(conn, "disease_ontology_mapping_meta")) {
    testthat::skip(
      "disease_ontology_mapping_meta not found — migration 036 not applied; skip."
    )
  }
  if (!DBI::dbExistsTable(conn, "disease_ontology_set")) {
    testthat::skip(
      "disease_ontology_set not found — base schema not initialized on this test DB; skip."
    )
  }

  withr::defer(.cleanup_mapping_tables(conn))

  .override_global_fn(
    "download_mondo_sssom_full",
    function(...) .fixture_sssom_path()
  )

  .seed_disease_ontology_set_omim(conn)

  # -----------------------------------------------------------------------
  # Pre-populate tables (full rebuild first).
  # -----------------------------------------------------------------------
  disease_ontology_mapping_refresh_run(
    job             = list(job_id = "test-h3-seed"),
    payload         = list(force = TRUE),
    pool_obj        = conn,
    checkout_fn     = function(p) p,
    return_fn       = function(conn) invisible(NULL),
    try_lock_fn     = function(conn) TRUE,
    release_lock_fn = function(conn) TRUE,
    download_obo_fn = .stub_obo_200,
    write_meta_fn   = .disease_ontology_mapping_write_meta
  )

  term_count_before <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM mondo_term"
  )$n[[1]]
  expect_gte(as.integer(term_count_before), 1L,
    label = "Pre-condition: mondo_term should be populated before 304 test")

  meta_count_before <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM disease_ontology_mapping_meta"
  )$n[[1]]

  # -----------------------------------------------------------------------
  # Second run: OBO 304 + tables already populated → should skip.
  # -----------------------------------------------------------------------
  result2 <- disease_ontology_mapping_refresh_run(
    job             = list(job_id = "test-h3-304"),
    payload         = list(force = FALSE),
    pool_obj        = conn,
    checkout_fn     = function(p) p,
    return_fn       = function(conn) invisible(NULL),
    try_lock_fn     = function(conn) TRUE,
    release_lock_fn = function(conn) TRUE,
    download_obo_fn = .stub_obo_304,
    write_meta_fn   = .disease_ontology_mapping_write_meta
  )

  # 2a. Result reports skipped.
  expect_equal(result2$status, "skipped",
    label = "304 + populated tables → status should be 'skipped'")
  expect_true(isTRUE(result2$success),
    label = "304 skip is a job success, not a failure")
  expect_equal(result2$reason, "not_modified",
    label = "skip reason should be 'not_modified'")

  # 2b. No row churn: mondo_term count unchanged.
  term_count_after <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM mondo_term"
  )$n[[1]]
  expect_equal(
    as.integer(term_count_after),
    as.integer(term_count_before),
    label = "304 skip must not change mondo_term row count"
  )

  # 2c. A meta row with status='skipped' was written.
  meta_count_after <- DBI::dbGetQuery(
    conn, "SELECT COUNT(*) AS n FROM disease_ontology_mapping_meta"
  )$n[[1]]
  expect_gt(
    as.integer(meta_count_after),
    as.integer(meta_count_before),
    label = "304 skip should write a new meta row"
  )
  skip_row <- DBI::dbGetQuery(
    conn,
    "SELECT status FROM disease_ontology_mapping_meta
     WHERE status = 'skipped' ORDER BY build_started_at DESC LIMIT 1"
  )
  expect_equal(nrow(skip_row), 1L,
    label = "A meta row with status='skipped' must exist after 304 run")
})

# ---------------------------------------------------------------------------
# Scenario 3: inactive entity does not leak mappings (WP-D T-D1)
# Uses with_test_db_transaction() since disease_mapping_for_entity does not
# internally call dbWithTransaction.
# ---------------------------------------------------------------------------

test_that("disease_mapping_for_entity returns missing for entity absent from ndd_entity_view", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    if (!exists("disease_mapping_for_entity", mode = "function")) {
      repo_path <- file.path(
        get_api_dir(), "functions", "disease-ontology-mapping-repository.R"
      )
      if (file.exists(repo_path)) {
        source(repo_path, local = FALSE)
      }
    }
    if (!exists("disease_mapping_for_entity", mode = "function")) {
      testthat::skip("disease_mapping_for_entity not available — skip.")
    }
    if (!DBI::dbExistsTable(conn, "disease_ontology_mapping")) {
      testthat::skip(
        "disease_ontology_mapping table not found — migration 036 not applied; skip."
      )
    }
    if (!DBI::dbExistsTable(conn, "ndd_entity_view")) {
      testthat::skip(
        "ndd_entity_view not found — core views (migration 025) not applied; skip."
      )
    }

    # entity_id 0 is guaranteed to be absent from ndd_entity_view.
    result <- disease_mapping_for_entity(entity_id = 0L, conn = conn)

    expect_equal(result$status, "missing",
      label = "entity_id not in ndd_entity_view must return status='missing'")
  })
})
