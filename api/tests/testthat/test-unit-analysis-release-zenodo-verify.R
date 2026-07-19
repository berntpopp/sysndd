# Unit tests for the analysis-snapshot RELEASE Zenodo fetch/extract-verify
# helpers and safety validator (#573 Slice C, Codex round-1 hardening):
# api/functions/analysis-snapshot-release-zenodo-verify.R.
#
# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
# (`http_get_json`/`http_download`) so tests supply plain stub closures
# instead of a mocking library. This file sources the MAIN
# `analysis-snapshot-release-zenodo-package.R` (not `-verify.R` directly)
# because that file defines `%||%` and guard-sources BOTH `-docs.R` and
# `-verify.R` into the same target environment -- mirrors
# `test-unit-analysis-release-zenodo-package.R`'s sourcing.
#
# Covers: release-id shape validation (path/filename/marker-injection guard,
# including `download_bundle`'s own defense-in-depth check, Codex round-3
# item 2, MEDIUM), `fetch_head`/`download_bundle` URL-building,
# `extract_and_verify` (checksum coverage + path-traversal rejection), and
# the safety validator `validate_staging` (case-insensitive forbidden-name
# matching, the file-type allowlist, and symlink rejection).
#
# The non-regular-file (FIFO) extraction-guard regression test (Codex
# round-3 item 1, HIGH) lives in the sibling
# test-unit-analysis-release-zenodo-verify-round3.R, split out to keep this
# file under the repo's 600-line soft ceiling (mirrors the round-2
# `-upload-doi-safety.R` split precedent). Both files share
# `build_fixture_bundle()` from `analysis-release-zenodo-verify-fixtures.R`.

library(testthat)

source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)

# --------------------------------------------------------------------------- #
# Shared fixture helpers
# --------------------------------------------------------------------------- #

# A well-formed Zenodo staging directory: the expected top-level docs plus the
# nested analysis_snapshot_release/ subdir with its own manifest+checksums.
#
# Deliberately uses plain `tempfile()`, NOT `withr::local_tempdir()`: the
# latter schedules cleanup via `withr::defer(..., envir = parent.frame())`,
# and `parent.frame()` evaluated INSIDE this helper resolves to this
# function's own (short-lived) call frame, not the calling `test_that()`
# block -- so the directory would be deleted the instant this helper
# returns, before the caller can use it. Session tempdir cleanup at process
# exit is sufficient for a short-lived test run.
make_well_formed_staging <- function() {
  staging <- file.path(tempdir(), paste0("zenodo_staging_", as.integer(stats::runif(1, 1, 1e9))))
  dir.create(staging, recursive = TRUE)
  for (name in c(
    "README.md", "DATA_CARD.md", "SCHEMA.md", "CHANGELOG.md", "CITATION.cff",
    "datapackage.json", "zenodo_metadata.json", "checksums.sha256"
  )) {
    writeLines("placeholder content", file.path(staging, name))
  }
  dir.create(file.path(staging, "analysis_snapshot_release"))
  writeLines('{"release_id":"asr_test"}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
  writeLines("deadbeef  manifest.json", file.path(staging, "analysis_snapshot_release", "checksums.sha256"))
  staging
}

# build_fixture_bundle() (tar.gz + inner checksums.sha256 builder, shared
# with the sibling test-unit-analysis-release-zenodo-verify-round3.R) now
# lives in analysis-release-zenodo-verify-fixtures.R -- extracted (Codex
# round-3 hardening) to keep both consuming test files under the repo's
# 600-line soft ceiling.
source_api_file("tests/testthat/analysis-release-zenodo-verify-fixtures.R", local = FALSE)

# --------------------------------------------------------------------------- #
# Release-id shape validation (item 2) -- exercised via fetch_head(), the
# public entry point for the REQUEST-arg validation.
# --------------------------------------------------------------------------- #

test_that("fetch_head: rejects a release_id containing '..' (path traversal shape) before calling http_get_json", {
  called <- FALSE
  stub_get_json <- function(url) {
    called <<- TRUE
    list()
  }
  expect_error(
    analysis_release_zenodo_fetch_head("http://localhost:7778", "../evil", http_get_json = stub_get_json),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

test_that("fetch_head: rejects a release_id containing an embedded newline before calling http_get_json", {
  called <- FALSE
  stub_get_json <- function(url) {
    called <<- TRUE
    list()
  }
  expect_error(
    analysis_release_zenodo_fetch_head(
      "http://localhost:7778", "asr_1234567890abcd\nrm -rf /", http_get_json = stub_get_json
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

test_that("fetch_head: rejects a release_id containing shell metacharacters before calling http_get_json", {
  called <- FALSE
  stub_get_json <- function(url) {
    called <<- TRUE
    list()
  }
  expect_error(
    analysis_release_zenodo_fetch_head(
      "http://localhost:7778", "asr_1234567890abcd;rm -rf /", http_get_json = stub_get_json
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

test_that("fetch_head: rejects an uppercase / wrong-length release_id", {
  stub_get_json <- function(url) list()
  expect_error(
    analysis_release_zenodo_fetch_head("http://localhost:7778", "ASR_DEADBEEFCAFEBABE", http_get_json = stub_get_json),
    "Invalid analysis-snapshot release id"
  )
  expect_error(
    analysis_release_zenodo_fetch_head("http://localhost:7778", "asr_short", http_get_json = stub_get_json),
    "Invalid analysis-snapshot release id"
  )
})

test_that("fetch_head: accepts 'latest' and a well-formed asr_<16 hex> id", {
  stub_get_json <- function(url) list(release_id = "ok")
  expect_no_error(
    analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
  )
  expect_no_error(
    analysis_release_zenodo_fetch_head(
      "http://localhost:7778", "asr_deadbeefcafebabe", http_get_json = stub_get_json
    )
  )
})

# --------------------------------------------------------------------------- #
# fetch_head / download_bundle -- DI seams, no real network
# --------------------------------------------------------------------------- #

test_that("fetch_head: builds the /releases/latest URL and passes the stub's JSON through", {
  captured_url <- NULL
  stub_get_json <- function(url) {
    captured_url <<- url
    list(release_id = "asr_abcdef0123456789", bundle_sha256 = "deadbeef")
  }
  head <- analysis_release_zenodo_fetch_head("http://localhost:7778", "latest", http_get_json = stub_get_json)
  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/latest")
  expect_identical(head$release_id, "asr_abcdef0123456789")
})

test_that("fetch_head: builds the /releases/<id> URL for an explicit release_id (trailing slash tolerated)", {
  captured_url <- NULL
  stub_get_json <- function(url) {
    captured_url <<- url
    list(release_id = "asr_0000000000000000")
  }
  head <- analysis_release_zenodo_fetch_head(
    "http://localhost:7778/", "asr_0000000000000000", http_get_json = stub_get_json
  )
  expect_identical(captured_url, "http://localhost:7778/api/analysis/releases/asr_0000000000000000")
  expect_identical(head$release_id, "asr_0000000000000000")
})

test_that("download_bundle: builds the /releases/<id>/bundle URL and streams the stub's content through", {
  captured <- new.env()
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "bundle.tar.gz")
  stub_download <- function(url, destfile) {
    assign("url", url, envir = captured)
    assign("destfile", destfile, envir = captured)
    writeBin(as.raw(c(1, 2, 3)), destfile)
  }
  result <- analysis_release_zenodo_download_bundle(
    "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
  )
  expect_identical(get("url", envir = captured), "http://localhost:7778/api/analysis/releases/asr_0000000000000000/bundle")
  expect_identical(get("destfile", envir = captured), dest)
  expect_identical(result, dest)
  expect_true(file.exists(dest))
})

test_that("download_bundle: errors when the injected downloader produces an empty file", {
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "empty.tar.gz")
  stub_download <- function(url, destfile) {
    file.create(destfile)
  }
  expect_error(
    analysis_release_zenodo_download_bundle(
      "http://localhost:7778", "asr_0000000000000000", dest, http_download = stub_download
    ),
    "empty"
  )
})

# --------------------------------------------------------------------------- #
# download_bundle: release_id shape validation (Codex round-3 item 2,
# MEDIUM). The package orchestrator already re-validates the RESOLVED id
# before calling download_bundle(), but this exported helper can be called
# directly, so it must reject a malformed id itself, before it is ever
# interpolated into the bundle URL and before http_download is invoked.
# --------------------------------------------------------------------------- #

test_that("download_bundle: rejects a malformed release_id ('asr_x') before calling http_download", {
  called <- FALSE
  stub_download <- function(url, destfile) {
    called <<- TRUE
    file.create(destfile)
  }
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "bundle.tar.gz")
  expect_error(
    analysis_release_zenodo_download_bundle(
      "http://localhost:7778", "asr_x", dest, http_download = stub_download
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
  expect_false(file.exists(dest))
})

test_that("download_bundle: rejects a release_id containing '..' (path traversal shape) before calling http_download", {
  called <- FALSE
  stub_download <- function(url, destfile) {
    called <<- TRUE
    file.create(destfile)
  }
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "bundle.tar.gz")
  expect_error(
    analysis_release_zenodo_download_bundle(
      "http://localhost:7778", "../evil", dest, http_download = stub_download
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

test_that("download_bundle: rejects a release_id containing a quote before calling http_download", {
  called <- FALSE
  stub_download <- function(url, destfile) {
    called <<- TRUE
    file.create(destfile)
  }
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "bundle.tar.gz")
  expect_error(
    analysis_release_zenodo_download_bundle(
      "http://localhost:7778", "asr_1234567890abcd'; rm -rf /", dest, http_download = stub_download
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

test_that("download_bundle: rejects 'latest' (a bundle URL always targets a concrete id)", {
  called <- FALSE
  stub_download <- function(url, destfile) {
    called <<- TRUE
    file.create(destfile)
  }
  work_dir <- withr::local_tempdir()
  dest <- file.path(work_dir, "bundle.tar.gz")
  expect_error(
    analysis_release_zenodo_download_bundle(
      "http://localhost:7778", "latest", dest, http_download = stub_download
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(called)
})

# --------------------------------------------------------------------------- #
# extract_and_verify
# --------------------------------------------------------------------------- #

test_that("extract_and_verify: passes with a matching bundle_sha256 and matching inner checksums", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(work_dir)
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  exdir <- file.path(work_dir, "extracted")
  result_dir <- analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)

  expect_identical(normalizePath(result_dir), normalizePath(exdir))
  expect_true(file.exists(file.path(result_dir, "a.txt")))
  expect_true(file.exists(file.path(result_dir, "b.txt")))
})

test_that("extract_and_verify: FAILS when the inner checksums.sha256 doesn't match file content", {
  work_dir <- withr::local_tempdir()
  bad_sha <- strrep("0", 64L)
  bundle_path <- build_fixture_bundle(work_dir, a_sha_override = bad_sha)
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_bad_inner")
    ),
    "mismatch"
  )
})

test_that("extract_and_verify: FAILS with a wrong expected_bundle_sha256 (outer verification)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(work_dir)

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, strrep("f", 64L), exdir = file.path(work_dir, "extracted_bad_outer")
    ),
    "checksum mismatch"
  )
})

test_that("extract_and_verify: FAILS when checksums.sha256 omits a line for a present file (coverage gap, item 4)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(work_dir, omit_checksum_for = "b.txt")
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_coverage_gap")
    ),
    "not listed in checksums.sha256"
  )
})

test_that("extract_and_verify: FAILS when a checksums.sha256 entry contains a '../' path (traversal, item 4)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(
    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ../evil.txt")
  )
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_traversal")
    ),
    "path traversal rejected"
  )
})

test_that("extract_and_verify: FAILS when a checksums.sha256 entry contains a backslash '..\\' traversal (Codex round-2 item 4, MEDIUM)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(
    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ..\\escape.txt")
  )
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_backslash_checksum_traversal")
    ),
    "path traversal rejected"
  )
})

test_that("extract_and_verify: FAILS when a checksums.sha256 entry is a UNC path (Codex round-2 item 4, MEDIUM)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(
    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  \\\\host\\share\\evil.txt")
  )
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_unc_traversal")
    ),
    "path traversal rejected"
  )
})

test_that("extract_and_verify: FAILS when a TAR MEMBER path itself contains backslash traversal (Codex round-2 item 4, MEDIUM)", {
  # On this Linux host, a backslash is an ordinary filename character (not a
  # separator), so a file can genuinely be named with a leading `..\` --
  # proving the traversal guard on the TAR MEMBER LIST (not just the
  # checksums.sha256 entries) also splits on `\`, not only `/`.
  work_dir <- withr::local_tempdir()
  src <- file.path(work_dir, "src_backslash_member")
  dir.create(src, recursive = TRUE)
  weird_name <- "..\\evil_member.txt"
  writeLines("payload", file.path(src, weird_name))
  weird_sha <- digest::digest(file = file.path(src, weird_name), algo = "sha256")
  cat(paste0(weird_sha, "  ", weird_name, "\n"), file = file.path(src, "checksums.sha256"))

  bundle_path <- file.path(work_dir, "bundle_backslash_member.tar.gz")
  withr::with_dir(src, {
    utils::tar(
      tarfile = bundle_path, files = c(weird_name, "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_backslash_member")
    ),
    "path traversal rejected"
  )
})

test_that("extract_and_verify: FAILS when the bundle contains a symlinked member (Codex round-2 item 1, HIGH) -- rejected BEFORE hashing", {
  # A symlinked release member must be rejected the instant it is seen in the
  # EXTRACTED tree, before `digest::digest(file = ...)` (which follows
  # symlinks transparently) is ever called on it. Proven here by giving the
  # symlink a deliberately WRONG checksum entry (all zeros): if the rejection
  # ran AFTER hashing, this would fail with a checksum "mismatch" instead --
  # the assertion below pins the failure to the symlink rejection specifically.
  work_dir <- withr::local_tempdir()
  outside_target <- file.path(work_dir, "outside_secret.txt")
  writeLines("host-readable content outside the archive", outside_target)

  src <- file.path(work_dir, "src_symlink_member")
  dir.create(src, recursive = TRUE)
  writeLines("normal file content", file.path(src, "a.txt"))
  link_path <- file.path(src, "evil_link")
  skip_if_not(
    isTRUE(file.symlink(outside_target, link_path)),
    "host does not support creating symlinks (e.g. some restricted CI runners)"
  )

  a_sha <- digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
  cat(
    paste0(a_sha, "  a.txt\n", strrep("0", 64L), "  evil_link\n"),
    file = file.path(src, "checksums.sha256")
  )

  bundle_path <- file.path(work_dir, "bundle_symlink_member.tar.gz")
  withr::with_dir(src, {
    utils::tar(
      tarfile = bundle_path, files = c("a.txt", "evil_link", "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_symlink_member")
    ),
    "symlinks"
  )
})

test_that("extract_and_verify: FAILS when checksums.sha256 lists the same file twice (duplicate entry, item 4)", {
  work_dir <- withr::local_tempdir()
  known_a_content_file <- tempfile()
  writeLines("file A content", known_a_content_file)
  known_a_sha <- digest::digest(file = known_a_content_file, algo = "sha256")
  unlink(known_a_content_file)

  bundle_path <- build_fixture_bundle(
    work_dir, extra_checksum_lines = paste0(known_a_sha, "  a.txt")
  )
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  expect_error(
    analysis_release_zenodo_extract_and_verify(
      bundle_path, expected_sha, exdir = file.path(work_dir, "extracted_duplicate")
    ),
    "duplicate entries"
  )
})

# --------------------------------------------------------------------------- #
# validate_staging -- THE SAFETY VALIDATOR
# --------------------------------------------------------------------------- #

test_that("validate_staging: passes on a well-formed staging dir", {
  staging <- make_well_formed_staging()
  expect_no_error(analysis_release_zenodo_validate_staging(staging))
})

test_that("validate_staging: FAILS when a .env file is planted", {
  staging <- make_well_formed_staging()
  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".env"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
})

test_that("validate_staging: FAILS when an UPPERCASE .ENV file is planted (item 3, case-insensitivity)", {
  staging <- make_well_formed_staging()
  writeLines("SECRET=1", file.path(staging, "analysis_snapshot_release", ".ENV"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "private files")
})

test_that("validate_staging: FAILS when a doc contains an absolute host path + dev username", {
  staging <- make_well_formed_staging()
  writeLines("built at /home/bernt-popp/development/sysndd on this host", file.path(staging, "README.md"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
})

test_that("validate_staging: FAILS when a doc contains a token-shaped string", {
  staging <- make_well_formed_staging()
  writeLines("ZENODO_TOKEN=abc123", file.path(staging, "DATA_CARD.md"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "sensitive")
})

test_that("validate_staging: FAILS when an expected top-level doc is missing", {
  staging <- make_well_formed_staging()
  file.remove(file.path(staging, "SCHEMA.md"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
})

test_that("validate_staging: FAILS when the nested manifest.json is missing", {
  staging <- make_well_formed_staging()
  file.remove(file.path(staging, "analysis_snapshot_release", "manifest.json"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "missing")
})

test_that("validate_staging: FAILS when a .pem file is planted (item 3, file-type allowlist)", {
  staging <- make_well_formed_staging()
  writeLines("-----BEGIN PRIVATE KEY-----", file.path(staging, "analysis_snapshot_release", "key.pem"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
})

test_that("validate_staging: FAILS when a .csv file is planted (item 3, file-type allowlist)", {
  staging <- make_well_formed_staging()
  writeLines("a,b,c", file.path(staging, "secret.csv"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
})

test_that("validate_staging: FAILS when an extensionless file is planted (item 3, file-type allowlist)", {
  staging <- make_well_formed_staging()
  writeLines("token-shaped-secret", file.path(staging, "analysis_snapshot_release", "credentials"))
  expect_error(analysis_release_zenodo_validate_staging(staging), "unexpected type/suffix")
})

test_that("validate_staging: FAILS when a symlink is planted (item 3, symlink rejection)", {
  staging <- make_well_formed_staging()
  target <- tempfile()
  writeLines("outside the staging tree", target)
  link <- file.path(staging, "escape.md")
  skip_if_not(
    isTRUE(file.symlink(target, link)),
    "host does not support creating symlinks (e.g. some restricted CI runners)"
  )
  expect_error(analysis_release_zenodo_validate_staging(staging), "symlinks")
})
