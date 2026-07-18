# tests/testthat/test-integration-analysis-release-endpoints.R
#
# Integration tests for the PUBLIC read routes of immutable analysis-snapshot
# releases (#573 Slice A / Task A6): the 6 routes appended to
# `endpoints/analysis_endpoints.R` -- releases, releases/latest,
# releases/<release_id>, releases/<release_id>/manifest.json,
# releases/<release_id>/file, releases/<release_id>/bundle.
#
# Seeds a release DIRECTLY via the A3 repository (analysis_release_insert),
# NOT the A4 build orchestrator, to avoid needing the (very complex)
# analysis_snapshot_* source tables -- mirrors the fixture style already
# used by test-integration-analysis-snapshot-release-repository.R.
#
# DDL / transaction traps (verified live against RMariaDB, same as the A3/A4
# repository & build tests): analysis_release_insert() opens its own
# DBI::dbWithTransaction() and cannot be nested inside
# with_test_db_transaction(); ensure_test_release_schema() applies DDL
# (auto-commits) on its OWN short-lived connection first. So this file uses a
# single plain connection for the whole test and cleans up via DELETE
# (children cascade via the migration's ON DELETE CASCADE FKs), never
# with_test_db_transaction().
#
# Handler-extraction idiom (mirrors test-endpoint-analysis-snapshot-read.R,
# which is NOT a helper-*.R file so is not auto-loaded -- this file keeps its
# own copy): each route handler is extracted from
# endpoints/analysis_endpoints.R by decorator regex + brace-depth scan, then
# eval()'d and called directly with a fake `res` -- no live plumber router
# needed. The extracted closure's enclosing environment is the (per-call,
# throwaway) frame the extraction helper sources `analysis_endpoints.R`
# into, whose lexical PARENT is wherever the extraction helper itself was
# DEFINED (this file's own top level) -- a `source(x, local = TRUE)` inside a
# `test_that()` block does NOT land on that chain (verified empirically: a
# test_that()-local source() is invisible to a sibling top-level closure).
# So, exactly like the reference file's `assign(..., envir = .GlobalEnv)`
# pattern, every free variable an extracted handler references at call time
# (svc_release_*, analysis_release_*, stop_for_not_found, `pool`) is bound
# straight into `.GlobalEnv` here via base `source(file, local = FALSE)` --
# every environment chain in R eventually passes through `.GlobalEnv`, so
# this is reachable regardless of exactly which frame testthat runs the
# test_that() block in. `pool` mirrors the production endpoint's `conn =
# pool` global (see endpoints/seo_endpoints.R), bound to the SAME real
# test-DB connection used to seed the fixture. Newly-added globals are
# removed again on teardown so they don't leak into sibling test files in a
# full-suite run.

release_endpoint_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(release_endpoint_test_wd), testthat::teardown_env())

release_a6_globals_before <- ls(envir = .GlobalEnv)
source(file.path("core", "errors.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-presets.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-release-manifest.R"), local = FALSE)
source(file.path("functions", "analysis-snapshot-release-repository.R"), local = FALSE)
source(file.path("services", "analysis-snapshot-release-service.R"), local = FALSE)
release_a6_new_globals <- setdiff(ls(envir = .GlobalEnv), release_a6_globals_before)
withr::defer(
  rm(list = intersect(release_a6_new_globals, ls(envir = .GlobalEnv)), envir = .GlobalEnv),
  testthat::teardown_env()
)

# --------------------------------------------------------------------------- #
# Fixture builders (mirrors test-integration-analysis-snapshot-release-repository.R)
# --------------------------------------------------------------------------- #

TEST_RELEASE_ID <- "asr_test0000000601"
TEST_DRAFT_RELEASE_ID <- "asr_test0000000602"

.delete_test_a6_releases <- function(conn) {
  DBI::dbExecute(
    conn,
    "DELETE FROM analysis_snapshot_release WHERE release_id IN (?, ?)",
    params = unname(list(TEST_RELEASE_ID, TEST_DRAFT_RELEASE_ID))
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

make_manifest_file <- function(release_id, payload_file) {
  manifest_json <- analysis_snapshot_canonical_json(list(
    release_id = release_id,
    release_version = "v1",
    files = list(list(
      path = payload_file$file_path,
      sha256 = payload_file$content_sha256,
      bytes = payload_file$byte_size
    ))
  ))
  make_gzip_file("manifest.json", manifest_json)
}

make_release_head <- function(release_id, manifest_file) {
  bundle_gzip <- memCompress(charToRaw(paste0("bundle contents for ", release_id)), type = "gzip")
  list(
    release_id = release_id,
    release_version = "v1",
    title = "Test release",
    manifest_schema_version = ANALYSIS_RELEASE_MANIFEST_SCHEMA_VERSION,
    content_digest = analysis_release_sha256(paste0("digest-", release_id)),
    # manifest_sha256 MUST equal the manifest.json FILE's own content_sha256
    # (it is the checksum of that file's bytes) -- reusing it directly here
    # keeps the fixture internally consistent by construction.
    manifest_sha256 = manifest_file$content_sha256,
    bundle_sha256 = analysis_release_sha256(bundle_gzip),
    bundle_gzip = bundle_gzip,
    source_data_version = "srcv1",
    license = "CC-BY-4.0"
  )
}

make_member <- function() {
  list(
    analysis_type = "functional_clusters",
    parameter_hash = analysis_release_sha256("functional_clusters-params"),
    snapshot_id = 601L,
    input_hash = analysis_release_sha256("functional_clusters-input"),
    payload_hash = analysis_release_sha256("functional_clusters-payload"),
    schema_version = "1.2",
    reproducibility_hash = analysis_release_sha256("functional_clusters-repro"),
    role = "layer"
  )
}

# --------------------------------------------------------------------------- #
# Handler extraction idiom (copied from test-endpoint-analysis-snapshot-read.R)
# --------------------------------------------------------------------------- #

release_endpoint_fake_res <- function() {
  env <- new.env(parent = emptyenv())
  env$status <- 200L
  env$headers <- list()
  env$setHeader <- function(name, value) {
    env$headers[[name]] <- value
    invisible(NULL)
  }
  env
}

release_endpoint_handler <- function(decorator_regex) {
  source(file.path("endpoints", "analysis_endpoints.R"), local = TRUE)

  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
  dec_idx <- grep(decorator_regex, src)[[1L]]
  function_start <- dec_idx + which(grepl("^function\\(", src[dec_idx:length(src)]))[[1L]] - 1L
  depth <- 0L
  function_end <- function_start
  for (idx in function_start:length(src)) {
    depth <- depth +
      lengths(regmatches(src[[idx]], gregexpr("\\{", src[[idx]], fixed = FALSE))) -
      lengths(regmatches(src[[idx]], gregexpr("\\}", src[[idx]], fixed = FALSE)))
    if (idx > function_start && depth == 0L) {
      function_end <- idx
      break
    }
  }

  eval(parse(text = paste(src[function_start:function_end], collapse = "\n")))
}

test_that("public analysis-release read routes serve a published release and hide drafts", {
  skip_if_no_test_db()

  schema_conn <- get_test_db_connection()
  ensure_test_release_schema(schema_conn)
  DBI::dbDisconnect(schema_conn)

  conn <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(conn))
  .delete_test_a6_releases(conn) # pre-clean any leftovers from a crashed run
  withr::defer(.delete_test_a6_releases(conn)) # post-clean

  # --- seed one published release: manifest.json + a layer payload + a
  #     reproducibility.json (the brief's own worked path example) ---------
  payload_text <- "{\"a\":1}"
  payload_file <- make_gzip_file("functional_clusters/payload.json", payload_text)
  repro_file <- make_gzip_file("functional_clusters/reproducibility.json", "{\"modularity\":0.42}")
  manifest_file <- make_manifest_file(TEST_RELEASE_ID, payload_file)
  head <- make_release_head(TEST_RELEASE_ID, manifest_file)
  analysis_release_insert(head, list(make_member()), list(manifest_file, payload_file, repro_file), conn)
  expect_true(analysis_release_publish(TEST_RELEASE_ID, conn = conn))

  # --- seed one DRAFT release (never published) -----------------------------
  draft_payload_file <- make_gzip_file("functional_clusters/payload.json", "{\"draft\":true}")
  draft_manifest_file <- make_manifest_file(TEST_DRAFT_RELEASE_ID, draft_payload_file)
  draft_head <- make_release_head(TEST_DRAFT_RELEASE_ID, draft_manifest_file)
  analysis_release_insert(
    draft_head, list(make_member()),
    list(draft_manifest_file, draft_payload_file), conn
  )
  # deliberately never published -- stays status='draft'

  # Bind the global `pool` the handlers reference (mirrors
  # endpoints/seo_endpoints.R's `conn = pool` production pattern). MUST land
  # in .GlobalEnv -- see the file-header comment for why.
  assign("pool", conn, envir = .GlobalEnv)
  withr::defer(if (exists("pool", envir = .GlobalEnv, inherits = FALSE)) rm("pool", envir = .GlobalEnv))

  # =========================================================================
  # releases: lists the published release, hides the draft
  # =========================================================================
  list_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases\\s*$")
  list_result <- list_handler(res = release_endpoint_fake_res())
  listed_ids <- vapply(list_result$releases, function(r) as.character(r$release_id), character(1))
  expect_true(TEST_RELEASE_ID %in% listed_ids)
  expect_false(TEST_DRAFT_RELEASE_ID %in% listed_ids)

  # L2: the pagination object echoes the EFFECTIVE (clamped) values, not the raw request.
  clamped_result <- list_handler(limit = "1000000", offset = "-1", res = release_endpoint_fake_res())
  expect_equal(clamped_result$pagination$limit, 100L)
  expect_equal(clamped_result$pagination$offset, 0L)

  # Public list heads must NOT leak operational columns (H1, via the real service).
  expect_false("created_by_user_id" %in% names(list_result$releases[[1]]))
  expect_false("last_error_message" %in% names(list_result$releases[[1]]))

  # =========================================================================
  # releases/latest
  # =========================================================================
  latest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/latest\\s*$")
  latest_result <- latest_handler(res = release_endpoint_fake_res())
  expect_equal(as.character(latest_result$release_id), TEST_RELEASE_ID)
  expect_false(is.null(latest_result$manifest))

  # =========================================================================
  # releases/<release_id>
  # =========================================================================
  detail_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>\\s*$")
  detail_result <- detail_handler(release_id = TEST_RELEASE_ID, res = release_endpoint_fake_res())
  expect_equal(as.character(detail_result$release_id), TEST_RELEASE_ID)
  expect_equal(detail_result$manifest$release_id, TEST_RELEASE_ID)

  unknown_err <- tryCatch(
    detail_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(unknown_err, "error_404")

  draft_err <- tryCatch(
    detail_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(draft_err, "error_404")

  # =========================================================================
  # releases/<release_id>/manifest.json
  # =========================================================================
  manifest_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/manifest\\.json\\s*$")
  manifest_res <- release_endpoint_fake_res()
  manifest_bytes <- manifest_handler(release_id = TEST_RELEASE_ID, res = manifest_res)
  expect_equal(analysis_release_sha256(manifest_bytes), head$manifest_sha256)
  # Content-Type (application/json) is set by the octet serializer annotation,
  # not a manual header (see the duplicate-header regression guard below); the
  # handler-extraction harness does not run the serializer, so the live
  # dev-stack check + the static guard verify the header.

  manifest_draft_err <- tryCatch(
    manifest_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(manifest_draft_err, "error_404")

  # =========================================================================
  # releases/<release_id>/file?path=...
  # =========================================================================
  file_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/file\\s*$")
  file_res <- release_endpoint_fake_res()
  file_bytes <- file_handler(
    release_id = TEST_RELEASE_ID,
    path = "functional_clusters/payload.json",
    res = file_res
  )
  # the FILE's own content_sha256 (matches the manifest files[] entry),
  # NOT the layer's snapshot payload_hash.
  expect_equal(analysis_release_sha256(file_bytes), payload_file$content_sha256)
  # The per-file route sets its (per-file) media type by assigning a dynamic
  # octet serializer to res$serializer (avoiding a duplicate Content-Type); the
  # handler-extraction harness can at least confirm the handler installed it.
  expect_true(is.function(file_res$serializer))

  # the brief's own worked path example (functional_clusters/reproducibility.json):
  # same arbitrary-path -> own content_sha256 mechanism, a different file.
  repro_res <- release_endpoint_fake_res()
  repro_bytes <- file_handler(
    release_id = TEST_RELEASE_ID,
    path = "functional_clusters/reproducibility.json",
    res = repro_res
  )
  expect_equal(analysis_release_sha256(repro_bytes), repro_file$content_sha256)

  garbage_err <- tryCatch(
    file_handler(release_id = TEST_RELEASE_ID, path = "does/not/exist.json", res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(garbage_err, "error_404")

  file_draft_err <- tryCatch(
    file_handler(
      release_id = TEST_DRAFT_RELEASE_ID,
      path = "functional_clusters/payload.json",
      res = release_endpoint_fake_res()
    ),
    error = function(e) e
  )
  expect_s3_class(file_draft_err, "error_404")

  # =========================================================================
  # releases/<release_id>/bundle
  # =========================================================================
  bundle_handler <- release_endpoint_handler("^#\\*\\s+@get\\s+releases/<release_id>/bundle\\s*$")
  bundle_res <- release_endpoint_fake_res()
  bundle_bytes <- bundle_handler(release_id = TEST_RELEASE_ID, res = bundle_res)
  expect_identical(bundle_bytes, head$bundle_gzip)
  expect_equal(analysis_release_sha256(bundle_bytes), head$bundle_sha256)
  expect_match(bundle_res$headers[["Content-Disposition"]], "^attachment")

  bundle_unknown_err <- tryCatch(
    bundle_handler(release_id = "asr_does_not_exist", res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(bundle_unknown_err, "error_404")

  bundle_draft_err <- tryCatch(
    bundle_handler(release_id = TEST_DRAFT_RELEASE_ID, res = release_endpoint_fake_res()),
    error = function(e) e
  )
  expect_s3_class(bundle_draft_err, "error_404")
})

test_that("releases/latest is declared before releases/<release_id> (plumber declaration-order guard)", {
  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
  latest_idx <- grep("^#\\*\\s+@get\\s+releases/latest\\s*$", src)
  detail_idx <- grep("^#\\*\\s+@get\\s+releases/<release_id>\\s*$", src)

  expect_length(latest_idx, 1L)
  expect_length(detail_idx, 1L)
  expect_lt(latest_idx[[1L]], detail_idx[[1L]])
})

test_that("byte-serving release routes set Content-Type via the serializer, never a duplicate manual header", {
  # Regression guard (found in live dev-stack verification): combining
  # `@serializer octet` with a manual res$setHeader("Content-Type", ...) emits
  # TWO Content-Type headers (the serializer's application/octet-stream + the
  # manual one). The routes must instead set the type THROUGH the serializer:
  # a static `@serializer octet list(type = ...)` for manifest.json/bundle, and
  # a dynamic res$serializer for the per-file route. The handler-extraction
  # tests above cannot observe serializer output, so this scans the source.
  src <- readLines(file.path("endpoints", "analysis_endpoints.R"), warn = FALSE)
  joined <- paste(src, collapse = "\n")

  # No release route may manually set Content-Type (it duplicates the serializer's).
  expect_false(
    any(grepl("setHeader\\(\\s*[\"']Content-Type[\"']", src)),
    info = "a release byte-route sets Content-Type manually -> duplicate header"
  )
  # manifest.json + bundle carry the type on the serializer annotation.
  expect_true(grepl('@serializer octet list(type = "application/json")', joined, fixed = TRUE))
  expect_true(grepl('@serializer octet list(type = "application/gzip")', joined, fixed = TRUE))
  # The per-file route sets its (per-file) type dynamically on res$serializer.
  expect_true(grepl("res$serializer <- plumber::serializer_octet(type = content$media_type)", joined, fixed = TRUE))
})
