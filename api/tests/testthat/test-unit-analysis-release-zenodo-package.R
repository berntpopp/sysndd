# Unit tests for the analysis-snapshot RELEASE Zenodo packager (#573 Slice C
# / Task C1): api/functions/analysis-snapshot-release-zenodo-package.R.
#
# Pure, DB-free, NO NETWORK: every HTTP boundary is an injectable seam
# (`http_get_json`/`http_download`) so tests supply plain stub closures
# instead of a mocking library, mirroring the `nddscore_download_archive(...,
# http_download = .nddscore_http_download)` DI pattern already used by
# `functions/nddscore-release-source.R`. Fixture tarballs are built inline
# with `utils::tar()` -- no dependency on a real published release or a
# running API.

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

# Builds a tiny tar.gz with two files + a matching (or deliberately wrong)
# inner checksums.sha256, mirroring the shape of a real release bundle (files
# directly at the archive root -- NOT nested under a named subdirectory,
# unlike the sibling nddscore archive).
build_fixture_bundle <- function(dir, a_sha_override = NULL, b_sha_override = NULL) {
  src <- file.path(dir, paste0("src_", as.integer(stats::runif(1, 1, 1e9))))
  dir.create(src, recursive = TRUE)
  writeLines("file A content", file.path(src, "a.txt"))
  writeLines("file B content", file.path(src, "b.txt"))
  a_sha <- a_sha_override %||% digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")
  cat(
    paste0(a_sha, "  a.txt\n", b_sha, "  b.txt\n"),
    file = file.path(src, "checksums.sha256")
  )

  bundle_path <- file.path(dir, paste0("bundle_", basename(src), ".tar.gz"))
  withr::with_dir(src, {
    utils::tar(
      tarfile = bundle_path, files = c("a.txt", "b.txt", "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  bundle_path
}

# --------------------------------------------------------------------------- #
# build_metadata
# --------------------------------------------------------------------------- #

test_that("build_metadata: exact keys/values for a fully-populated head", {
  head <- list(
    release_id = "asr_abc1234567890abc",
    created_at = "2026-07-15T10:00:00Z",
    license = "CC-BY-4.0",
    source_data_version = "v42"
  )
  metadata <- analysis_release_zenodo_build_metadata(head)

  expect_identical(metadata$title, "SysNDD analysis-snapshot release asr_abc1234567890abc, 2026-07-15")
  expect_identical(metadata$upload_type, "dataset")
  expect_true(is.character(metadata$description) && length(metadata$description) == 1L)
  expect_true(grepl("<p>", metadata$description, fixed = TRUE))
  expect_identical(metadata$creators, list(list(name = "Popp, Bernt", orcid = "0000-0002-3679-1081")))
  expect_true("SysNDD" %in% unlist(metadata$keywords))
  expect_identical(metadata$access_right, "open")
  expect_identical(metadata$license, "CC-BY-4.0")
  expect_identical(metadata$version, "v42")
  expect_identical(metadata$language, "eng")
  expect_false("doi" %in% names(metadata))
})

test_that("build_metadata: a non-default head license carries through, not hardcoded", {
  head <- list(release_id = "asr_deadbeefdeadbeef", created_at = "2026-01-01T00:00:00Z", license = "mit")
  metadata <- analysis_release_zenodo_build_metadata(head)
  expect_identical(metadata$license, "mit")
})

test_that("build_metadata: falls back to cc-by-4.0 license and release_id version when head omits both", {
  head <- list(release_id = "asr_0000000000000000", created_at = "2026-02-02T00:00:00Z")
  metadata <- analysis_release_zenodo_build_metadata(head)
  expect_identical(metadata$license, "cc-by-4.0")
  expect_identical(metadata$version, "asr_0000000000000000")
})

test_that("build_metadata: explicit version/license_id args override head values", {
  head <- list(release_id = "asr_1111111111111111", created_at = "2026-03-03T00:00:00Z", license = "mit")
  metadata <- analysis_release_zenodo_build_metadata(head, version = "9.9.9", license_id = "cc0-1.0")
  expect_identical(metadata$version, "9.9.9")
  expect_identical(metadata$license, "cc0-1.0")
})

# --------------------------------------------------------------------------- #
# build_datapackage
# --------------------------------------------------------------------------- #

test_that("build_datapackage excludes checksums.sha256/datapackage.json and reports correct resource fields", {
  staging <- withr::local_tempdir()
  dir.create(file.path(staging, "analysis_snapshot_release"), recursive = TRUE)
  writeLines("hello", file.path(staging, "README.md"))
  writeLines('{"a":1}', file.path(staging, "analysis_snapshot_release", "manifest.json"))
  cat("deadbeef  README.md\n", file = file.path(staging, "checksums.sha256"))
  writeLines("{}", file.path(staging, "datapackage.json"))

  dp <- analysis_release_zenodo_build_datapackage(
    staging, name = "test-pkg", version = "v1", release_id = "asr_test"
  )

  expect_identical(dp$profile, "data-package")
  expect_identical(dp$name, "test-pkg")
  expect_identical(dp$id, "asr_test")
  expect_identical(dp$version, "v1")
  expect_identical(
    dp$licenses,
    list(list(name = "CC-BY-4.0", path = "https://creativecommons.org/licenses/by/4.0/"))
  )

  resource_paths <- vapply(dp$resources, function(r) r$path, character(1))
  expect_false("checksums.sha256" %in% resource_paths)
  expect_false("datapackage.json" %in% resource_paths)
  expect_true("README.md" %in% resource_paths)
  expect_true("analysis_snapshot_release/manifest.json" %in% resource_paths)

  readme_resource <- dp$resources[[which(resource_paths == "README.md")]]
  expect_identical(readme_resource$bytes, as.numeric(file.info(file.path(staging, "README.md"))$size))
  expect_identical(
    readme_resource$hash,
    digest::digest(file = file.path(staging, "README.md"), algo = "sha256")
  )
  expect_identical(readme_resource$mediatype, "application/octet-stream")
  expect_identical(readme_resource$name, "README-md")
})

# --------------------------------------------------------------------------- #
# write_checksums
# --------------------------------------------------------------------------- #

test_that("write_checksums: classic sha256sum format, excludes itself, deterministic sorted order", {
  staging <- withr::local_tempdir()
  writeLines("a", file.path(staging, "b.txt"))
  writeLines("b", file.path(staging, "a.txt"))
  out_path <- analysis_release_zenodo_write_checksums(staging)

  expect_identical(out_path, file.path(staging, "checksums.sha256"))
  lines <- readLines(out_path)
  expect_length(lines, 2L)
  expect_true(grepl("  a\\.txt$", lines[[1]]))
  expect_true(grepl("  b\\.txt$", lines[[2]]))
  expect_identical(
    lines[[1]],
    paste0(digest::digest(file = file.path(staging, "a.txt"), algo = "sha256"), "  a.txt")
  )

  raw_content <- readChar(out_path, file.info(out_path)$size, useBytes = TRUE)
  expect_true(endsWith(raw_content, "\n"))

  # Re-running never emits a self-referential line for checksums.sha256 itself.
  analysis_release_zenodo_write_checksums(staging)
  lines2 <- readLines(file.path(staging, "checksums.sha256"))
  expect_false(any(grepl("checksums\\.sha256", lines2)))
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
      "http://localhost:7778", "asr_x", dest, http_download = stub_download
    ),
    "empty"
  )
})

# --------------------------------------------------------------------------- #
# make_tarball
# --------------------------------------------------------------------------- #

test_that("make_tarball: single top-level dir, plus a sibling .sha256 file with the correct digest", {
  staging <- withr::local_tempdir()
  writeLines("hello", file.path(staging, "README.md"))

  archive_dir <- file.path(withr::local_tempdir(), "archive")
  archive_path <- file.path(archive_dir, "asr_test.tar.gz")
  result <- analysis_release_zenodo_make_tarball(staging, archive_path)

  expect_true(file.exists(result$archive_path))
  expect_true(file.exists(result$archive_sha256_path))
  expect_identical(result$archive_sha256_path, paste0(result$archive_path, ".sha256"))

  sha_line <- readLines(result$archive_sha256_path)
  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
  expect_identical(sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))

  entries <- utils::untar(result$archive_path, list = TRUE)
  # utils::untar(list = TRUE) reports entries with a trailing "/" for dirs.
  top_level_dirs <- unique(sub("^([^/]+)/.*$", "\\1", entries))
  expect_length(top_level_dirs, 1L)
  expect_identical(top_level_dirs, basename(staging))
})

# --------------------------------------------------------------------------- #
# package(): full orchestration with stubbed HTTP
# --------------------------------------------------------------------------- #

test_that("package(): fetches, verifies, re-stages, validates, and tars a fake published release", {
  work_dir <- withr::local_tempdir()

  bundle_src <- file.path(work_dir, "bundle_src")
  dir.create(bundle_src)
  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
  writeLines('{"release_id":"asr_deadbeefcafebabe"}', file.path(bundle_src, "manifest.json"))
  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
  cat(
    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
    file = file.path(bundle_src, "checksums.sha256")
  )

  bundle_path <- file.path(work_dir, "bundle.tar.gz")
  withr::with_dir(bundle_src, {
    utils::tar(
      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  bundle_sha256 <- digest::digest(file = bundle_path, algo = "sha256")

  fake_head <- list(
    release_id = "asr_deadbeefcafebabe",
    created_at = "2026-07-15T10:00:00Z",
    license = "CC-BY-4.0",
    source_data_version = "v42",
    bundle_sha256 = bundle_sha256
  )
  stub_get_json <- function(url) fake_head
  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)

  staging_dir <- file.path(work_dir, "staging")
  archive_dir <- file.path(work_dir, "archive")

  result <- analysis_release_zenodo_package(
    api_base_url = "http://localhost:7778",
    release_id = "latest",
    staging_dir = staging_dir,
    archive_dir = archive_dir,
    http_get_json = stub_get_json,
    http_download = stub_download
  )

  expect_identical(result$release_id, "asr_deadbeefcafebabe")
  expect_identical(result$staging_dir, staging_dir)
  expect_true(file.exists(result$archive_path))
  expect_true(file.exists(result$archive_sha256_path))
  expect_true(file.exists(result$zenodo_metadata_path))

  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "README.md")))
  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "manifest.json")))
  expect_true(file.exists(file.path(staging_dir, "analysis_snapshot_release", "checksums.sha256")))
  expect_true(file.exists(file.path(staging_dir, "checksums.sha256")))
  expect_true(file.exists(file.path(staging_dir, "datapackage.json")))

  metadata <- jsonlite::fromJSON(result$zenodo_metadata_path, simplifyVector = TRUE)
  expect_identical(metadata$license, "CC-BY-4.0")
  expect_identical(metadata$version, "v42")
  expect_false("doi" %in% names(metadata))

  recorded_sha_line <- readLines(result$archive_sha256_path)
  actual_sha <- digest::digest(file = result$archive_path, algo = "sha256")
  expect_identical(recorded_sha_line, paste0(actual_sha, "  ", basename(result$archive_path)))
})

test_that("package(): rejects when the downloaded bundle fails checksum verification", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(work_dir)

  fake_head <- list(
    release_id = "asr_badbundle00000000",
    created_at = "2026-07-15T10:00:00Z",
    bundle_sha256 = strrep("f", 64L)
  )
  stub_get_json <- function(url) fake_head
  stub_download <- function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE)

  expect_error(
    analysis_release_zenodo_package(
      api_base_url = "http://localhost:7778",
      release_id = "latest",
      staging_dir = file.path(work_dir, "staging2"),
      archive_dir = file.path(work_dir, "archive2"),
      http_get_json = stub_get_json,
      http_download = stub_download
    ),
    "checksum mismatch"
  )
})
