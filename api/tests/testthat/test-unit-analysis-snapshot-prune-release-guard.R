# tests/testthat/test-unit-analysis-snapshot-prune-release-guard.R
#
# Integration test for the #573 Slice A / Task A8 prune-protection guard:
# analysis_snapshot_prune() (functions/analysis-snapshot-repository.R) must
# never delete a superseded snapshot manifest row that a published/draft
# analysis-snapshot RELEASE still references via
# analysis_snapshot_release_member.snapshot_id. A release freezes its own
# content-addressed copies of a snapshot's payload, so release INTEGRITY does
# not depend on the source manifest row surviving -- but the LIVE
# reproducibility endpoint for that still-cited snapshot
# (GET /api/analysis/<type>/reproducibility) would start 503-ing
# (`snapshot_missing`) if its manifest row disappeared out from under it.
#
# Against the real test database (sysndd_db_test). Seeds the minimal public
# analysis-snapshot manifest schema (migration 024) and the release schema
# (migration 045) via the ensure_test_*_schema() helpers in helper-db.R, then
# exercises analysis_snapshot_prune() on a single plain (non-transactional)
# connection -- mirroring test-integration-analysis-snapshot-release-
# repository.R's pattern. The release/member row is created via the real,
# already-tested analysis_release_insert() repository function (A3) rather
# than hand-rolled SQL, since analysis_snapshot_release_member has no FK to
# analysis_snapshot_manifest (see migration 045) -- only the manifest rows
# (which analysis_release_insert() knows nothing about) are inserted directly.

prune_release_guard_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(prune_release_guard_test_wd), testthat::teardown_env())

source(file.path("functions", "db-helpers.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-repository.R"), local = TRUE)

# Test-only ids namespaced so a rerun only ever touches its own rows.
PRUNE_TEST_ANALYSIS_TYPE <- "functional_clusters"
PRUNE_TEST_PARAMETER_HASH <- analysis_release_sha256("prune-release-guard-test-params")
PRUNE_TEST_RELEASE_ID <- "asr_prunetest00000001"

.prune_guard_cleanup <- function(conn) {
  DBI::dbExecute(
    conn,
    "DELETE FROM analysis_snapshot_release WHERE release_id = ?",
    params = unname(list(PRUNE_TEST_RELEASE_ID))
  )
  DBI::dbExecute(
    conn,
    "DELETE FROM analysis_snapshot_manifest WHERE analysis_type = ? AND parameter_hash = ?",
    params = unname(list(PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH))
  )
}

.insert_prune_test_manifest_row <- function(conn, status, superseded_at, activated_at, generated_at, label) {
  DBI::dbExecute(
    conn,
    "INSERT INTO analysis_snapshot_manifest
       (analysis_type, parameter_hash, schema_version, data_class, status,
        public_ready, activated_at, generated_at, superseded_at,
        parameters_json, input_hash, payload_hash)
     VALUES (?, ?, '1.2', 'curated_derived_analysis', ?,
             ?, ?, ?, ?,
             '{}', ?, ?)",
    params = unname(list(
      PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH, status,
      if (status == "public_ready") 1L else 0L,
      activated_at, generated_at, superseded_at,
      analysis_release_sha256(paste0("input-", label)),
      analysis_release_sha256(paste0("payload-", label))
    ))
  )
  as.numeric(DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS id")$id[[1]])
}

.insert_prune_test_release_row <- function(conn, referenced_snapshot_id) {
  release_head <- list(
    release_id = PRUNE_TEST_RELEASE_ID,
    manifest_schema_version = "1.0",
    content_digest = analysis_release_sha256("prune-test-digest"),
    manifest_sha256 = analysis_release_sha256("prune-test-manifest"),
    bundle_sha256 = analysis_release_sha256("prune-test-bundle"),
    bundle_gzip = memCompress(charToRaw("prune-test-bundle-contents"), type = "gzip"),
    license = "CC-BY-4.0"
  )
  members <- list(list(
    analysis_type = PRUNE_TEST_ANALYSIS_TYPE,
    parameter_hash = PRUNE_TEST_PARAMETER_HASH,
    snapshot_id = referenced_snapshot_id,
    input_hash = analysis_release_sha256("member-input"),
    payload_hash = analysis_release_sha256("member-payload"),
    schema_version = "1.2",
    role = "layer"
  ))
  analysis_release_insert(release_head, members, files = list(), conn = conn)
  invisible(TRUE)
}

test_that("analysis_snapshot_prune never deletes a snapshot a release still references", {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_analysis_snapshot_manifest_schema(schema_conn)
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  .prune_guard_cleanup(conn) # pre-clean any leftovers from a crashed run
  withr::defer(.prune_guard_cleanup(conn))

  now <- Sys.time()
  old_superseded <- format(now - (30 * 86400), "%Y-%m-%d %H:%M:%OS6", tz = "UTC") # well past the 14-day default

  # A recent public_ready row so keep_public_ready's recency retention alone
  # cannot explain either superseded row surviving -- it always wins the
  # keep_rows LIMIT and is not a prune candidate (status filter excludes it).
  .insert_prune_test_manifest_row(
    conn, "public_ready",
    superseded_at = NA_character_, activated_at = format(now, "%Y-%m-%d %H:%M:%OS6", tz = "UTC"),
    generated_at = format(now, "%Y-%m-%d %H:%M:%OS6", tz = "UTC"), label = "kept-recent"
  )

  referenced_id <- .insert_prune_test_manifest_row(
    conn, "superseded",
    superseded_at = old_superseded, activated_at = NA_character_, generated_at = old_superseded,
    label = "referenced"
  )
  unreferenced_id <- .insert_prune_test_manifest_row(
    conn, "superseded",
    superseded_at = old_superseded, activated_at = NA_character_, generated_at = old_superseded,
    label = "unreferenced"
  )

  .insert_prune_test_release_row(conn, referenced_id)

  analysis_snapshot_prune(
    PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH,
    keep_public_ready = 1L, keep_superseded_days = 14L,
    conn = conn
  )

  surviving_ids <- DBI::dbGetQuery(
    conn,
    "SELECT snapshot_id FROM analysis_snapshot_manifest
      WHERE analysis_type = ? AND parameter_hash = ?",
    params = unname(list(PRUNE_TEST_ANALYSIS_TYPE, PRUNE_TEST_PARAMETER_HASH))
  )$snapshot_id

  # The release-referenced snapshot survives even though it is superseded and
  # well past the retention window -- a still-cited row is never a prune
  # target, matching the release repository's contract that release integrity
  # does not depend on the source snapshot row but the live reproducibility
  # endpoint for that snapshot would 503 if it vanished.
  expect_true(referenced_id %in% surviving_ids)
  # The unreferenced superseded snapshot IS pruned (baseline prune behavior
  # unchanged for a snapshot no release cites).
  expect_false(unreferenced_id %in% surviving_ids)
})
