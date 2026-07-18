# tests/testthat/test-integration-analysis-snapshot-release-repository.R
#
# Integration tests for the analysis-snapshot RELEASE repository (#573 Slice
# A / Task A3): insert / get / list / get_file / get_bundle / publish /
# set_doi / delete_draft / exists / referenced_snapshot_ids, against the real
# test database (sysndd_db_test).
#
# IMPORTANT (verified live against RMariaDB, not just inferred from
# comments): analysis_release_insert() wraps its writes in ONE
# DBI::dbWithTransaction(conn, {...}). Calling dbBegin() on a connection that
# already has an open transaction raises "Nested transactions not
# supported" — the exact trap already documented in
# test-integration-additive-ontology-terms.R / test-integration-
# ontology-mapping-refresh.R. So this file does NOT wrap
# analysis_release_insert() in with_test_db_transaction() (which itself opens
# a transaction on its own connection). Instead, mirroring the additive-
# ontology-terms pattern: a single plain connection is used for the whole
# test, and the test's own release row(s) are cleaned up via withr::defer()
# (children cascade via the migration's ON DELETE CASCADE FKs). The
# read/update/delete repository functions issue single, non-transactional
# statements, so they are safe to call on that same plain connection too.
#
# DDL-auto-commit note: ensure_test_release_schema() (helper-db.R) applies
# migration 045's CREATE TABLE IF NOT EXISTS statements on their OWN
# short-lived connection, opened and closed BEFORE any of the above — DDL
# auto-commits in MySQL and cannot be part of a rolled-back transaction.

release_repo_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(release_repo_test_wd), testthat::teardown_env())

source(file.path("functions", "analysis-snapshot-presets.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = TRUE)
source(file.path("functions", "analysis-snapshot-release-repository.R"), local = TRUE)

# Test-only release ids in a namespaced form production content-digest ids
# (`asr_<16 hex>`) never produce, so tests add/remove only their own rows.
TEST_RELEASE_ID <- "asr_test0000000001"
TEST_RELEASE_ID_2 <- "asr_test0000000002"

.delete_test_releases <- function(conn) {
  DBI::dbExecute(
    conn,
    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
    params = unname(list(TEST_RELEASE_ID, TEST_RELEASE_ID_2))
  )
}

make_gzip_file <- function(file_path, text, media_type = "application/json") {
  raw_bytes <- charToRaw(text)
  list(
    file_path = file_path,
    content_sha256 = analysis_release_sha256(raw_bytes),
    byte_size = length(raw_bytes),
    media_type = media_type,
    content_gzip = memCompress(raw_bytes, type = "gzip")
  )
}

make_manifest_file <- function(release_id) {
  manifest_json <- analysis_snapshot_canonical_json(list(
    release_id = release_id,
    release_version = "v1",
    files = list(list(path = "functional_clusters/payload.json", sha256 = "abc", bytes = 10L))
  ))
  make_gzip_file("manifest.json", manifest_json)
}

make_members <- function() {
  list(
    list(
      analysis_type = "functional_clusters",
      parameter_hash = analysis_release_sha256("functional_clusters-params"),
      snapshot_id = 101L,
      input_hash = analysis_release_sha256("functional_clusters-input"),
      payload_hash = analysis_release_sha256("functional_clusters-payload"),
      schema_version = "1.2",
      reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
      role = "layer"
    ),
    list(
      analysis_type = "phenotype_clusters",
      parameter_hash = analysis_release_sha256("phenotype_clusters-params"),
      snapshot_id = 202L,
      input_hash = analysis_release_sha256("phenotype_clusters-input"),
      payload_hash = analysis_release_sha256("phenotype_clusters-payload"),
      schema_version = "2.0",
      reproducibility_hash = analysis_release_sha256("phenotype_clusters-repro"),
      role = "layer"
    )
  )
}

make_release_head <- function(release_id) {
  list(
    release_id = release_id,
    release_version = "v1",
    title = "Test release",
    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
    manifest_sha256 = analysis_release_sha256(paste0("manifest-", release_id)),
    bundle_sha256 = analysis_release_sha256(paste0("bundle-", release_id)),
    bundle_gzip = memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip"),
    source_data_version = "srcv1",
    license = "CC-BY-4.0"
  )
}

test_that("analysis-snapshot release repository round-trips insert/get/list/get_file/get_bundle/publish/set_doi", {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  .delete_test_releases(conn) # pre-clean any leftovers from a crashed run
  withr::defer(.delete_test_releases(conn)) # post-clean (restore prior table state)

  head1 <- make_release_head(TEST_RELEASE_ID)
  members <- make_members()
  payload_text <- "{\"a\":1}"
  files <- list(make_manifest_file(TEST_RELEASE_ID), make_gzip_file("functional_clusters/payload.json", payload_text))

  returned_id <- analysis_release_insert(head1, members, files, conn)
  expect_equal(returned_id, TEST_RELEASE_ID)

  # Re-inserting the identical PK is a DB-level integrity error (not this
  # repository's job to dedupe) -- idempotency is analysis_release_exists()'s
  # job for callers, verified separately below.
  expect_true(analysis_release_exists(TEST_RELEASE_ID, conn = conn))
  expect_false(analysis_release_exists("asr_does_not_exist", conn = conn))

  # --- draft visibility -----------------------------------------------------
  expect_null(analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn))

  draft <- analysis_release_get(TEST_RELEASE_ID, include_draft = TRUE, conn = conn)
  expect_false(is.null(draft))
  expect_equal(draft$status, "draft")
  expect_equal(draft$file_count, 2L)
  expect_false(is.null(draft$manifest))
  expect_equal(draft$manifest$release_id, TEST_RELEASE_ID)

  published_ids_before <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
  expect_false(TEST_RELEASE_ID %in% published_ids_before)

  all_ids_before <- vapply(analysis_release_list(NULL, conn = conn), function(r) r$release_id, character(1))
  expect_true(TEST_RELEASE_ID %in% all_ids_before) # status=NULL returns every status

  # --- get_file: exact round-trip, unknown path, draft-hidden ---------------
  payload_file <- analysis_release_get_file(
    TEST_RELEASE_ID, "functional_clusters/payload.json",
    include_draft = TRUE, conn = conn
  )
  expect_false(is.null(payload_file))
  expect_equal(rawToChar(payload_file$bytes), payload_text)
  expect_equal(payload_file$content_sha256, analysis_release_sha256(charToRaw(payload_text)))
  expect_equal(payload_file$media_type, "application/json")

  expect_null(analysis_release_get_file(
    TEST_RELEASE_ID, "does/not/exist.json",
    include_draft = TRUE, conn = conn
  ))
  expect_null(analysis_release_get_file(
    TEST_RELEASE_ID, "functional_clusters/payload.json",
    include_draft = FALSE, conn = conn
  ))

  # --- get_bundle: verbatim bytes, draft-hidden ------------------------------
  bundle <- analysis_release_get_bundle(TEST_RELEASE_ID, include_draft = TRUE, conn = conn)
  expect_false(is.null(bundle))
  expect_identical(bundle$bytes, head1$bundle_gzip)
  expect_equal(bundle$sha256, head1$bundle_sha256)
  expect_equal(bundle$filename, paste0(TEST_RELEASE_ID, ".tar.gz"))
  expect_null(analysis_release_get_bundle(TEST_RELEASE_ID, include_draft = FALSE, conn = conn))

  # --- publish ----------------------------------------------------------------
  expect_true(analysis_release_publish(TEST_RELEASE_ID, conn = conn))
  # already published: flipping again is a no-op
  expect_false(analysis_release_publish(TEST_RELEASE_ID, conn = conn))

  published <- analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn)
  expect_false(is.null(published))
  expect_equal(published$status, "published")
  expect_false(is.na(published$published_at))
  expect_false(is.null(published$manifest))

  published_ids_after <- vapply(analysis_release_list("published", conn = conn), function(r) r$release_id, character(1))
  expect_true(TEST_RELEASE_ID %in% published_ids_after)
  entry <- analysis_release_list("published", conn = conn)[[which(published_ids_after == TEST_RELEASE_ID)]]
  expect_equal(length(entry$layers), 2L)
  expect_setequal(
    vapply(entry$layers, function(l) l$analysis_type, character(1)),
    c("functional_clusters", "phenotype_clusters")
  )
  expect_setequal(
    vapply(entry$layers, function(l) as.integer(l$snapshot_id), integer(1)),
    c(101L, 202L)
  )

  # --- set_doi: additive, never touches content_digest/manifest_sha256 -------
  before_digest <- published$content_digest
  before_manifest_sha <- published$manifest_sha256
  ok <- analysis_release_set_doi(
    TEST_RELEASE_ID,
    list(zenodo_record_id = "123456", version_doi = "10.5281/zenodo.123456"),
    conn = conn
  )
  expect_true(ok)

  with_doi <- analysis_release_get(TEST_RELEASE_ID, include_draft = FALSE, conn = conn)
  expect_equal(with_doi$zenodo_record_id, "123456")
  expect_equal(with_doi$version_doi, "10.5281/zenodo.123456")
  expect_true(is.na(with_doi$concept_doi)) # untouched (not provided)
  expect_equal(with_doi$content_digest, before_digest)
  expect_equal(with_doi$manifest_sha256, before_manifest_sha)

  # set_doi on an unrelated/nonexistent id is a no-op
  expect_false(analysis_release_set_doi(
    "asr_does_not_exist",
    list(zenodo_record_id = "999"),
    conn = conn
  ))
  # empty doi_fields is a no-op
  expect_false(analysis_release_set_doi(TEST_RELEASE_ID, list(), conn = conn))

  # --- delete_draft refuses a published row -----------------------------------
  expect_false(analysis_release_delete_draft(TEST_RELEASE_ID, conn = conn))
  expect_true(analysis_release_exists(TEST_RELEASE_ID, conn = conn))

  # --- referenced_snapshot_ids --------------------------------------------------
  snap_ids <- analysis_release_referenced_snapshot_ids(conn = conn)
  expect_true(all(c(101L, 202L) %in% snap_ids))
})

test_that("analysis_release_public_head drops operational columns and groups zenodo (H1)", {
  raw_head <- list(
    release_id = "asr_pub", release_version = "v1", title = "T", status = "published",
    content_digest = "digest", created_at = "2026-07-18", published_at = "2026-07-18",
    source_data_version = "srcv", db_release_version = "1.0.0", db_release_commit = "abc",
    manifest_sha256 = "m", bundle_sha256 = "b", license = "CC-BY-4.0",
    file_count = 5L, total_bytes = 100,
    zenodo_record_url = "https://zenodo.org/records/1", version_doi = "10.5281/zenodo.1",
    concept_doi = NA_character_,
    # operational columns that MUST NOT leak publicly:
    created_by_user_id = 42L, last_error_message = "secret internal error", updated_at = "2026-07-18",
    layers = list(list(analysis_type = "functional_clusters")),
    manifest = list(release_id = "asr_pub")
  )

  projected <- analysis_release_public_head(raw_head)

  expect_false("created_by_user_id" %in% names(projected))
  expect_false("last_error_message" %in% names(projected))
  expect_false("updated_at" %in% names(projected))
  # allowlisted fields survive:
  expect_equal(projected$release_id, "asr_pub")
  expect_equal(projected$db_release_version, "1.0.0")
  expect_equal(projected$file_count, 5L)
  # zenodo grouped; NA concept_doi -> NULL (dropped from the group):
  expect_equal(projected$zenodo$record_url, "https://zenodo.org/records/1")
  expect_equal(projected$zenodo$version_doi, "10.5281/zenodo.1")
  expect_null(projected$zenodo$concept_doi)
  # public-safe derived members carried through:
  expect_false(is.null(projected$layers))
  expect_false(is.null(projected$manifest))

  expect_null(analysis_release_public_head(NULL))
})

test_that("analysis_release_delete_draft removes a draft release and its file/member children", {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  .delete_test_releases(conn)
  withr::defer(.delete_test_releases(conn))

  head2 <- make_release_head(TEST_RELEASE_ID_2)
  analysis_release_insert(
    head2,
    list(make_members()[[1]]),
    list(make_manifest_file(TEST_RELEASE_ID_2)),
    conn
  )

  expect_true(analysis_release_exists(TEST_RELEASE_ID_2, conn = conn))
  expect_true(analysis_release_delete_draft(TEST_RELEASE_ID_2, conn = conn))
  expect_false(analysis_release_exists(TEST_RELEASE_ID_2, conn = conn))
  expect_null(analysis_release_get(TEST_RELEASE_ID_2, include_draft = TRUE, conn = conn))

  # children cascaded: no orphaned member/file rows survive
  member_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM analysis_snapshot_release_member WHERE release_id = ?",
    params = unname(list(TEST_RELEASE_ID_2))
  )$n
  file_count <- DBI::dbGetQuery(
    conn,
    "SELECT COUNT(*) AS n FROM analysis_snapshot_release_file WHERE release_id = ?",
    params = unname(list(TEST_RELEASE_ID_2))
  )$n
  expect_equal(as.integer(member_count), 0L)
  expect_equal(as.integer(file_count), 0L)

  # deleting a nonexistent draft is a no-op, not an error
  expect_false(analysis_release_delete_draft(TEST_RELEASE_ID_2, conn = conn))
})
