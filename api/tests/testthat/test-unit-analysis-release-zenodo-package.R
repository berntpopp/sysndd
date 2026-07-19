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
#
# The fetch/download/extract-verify helpers and the safety validator
# (`analysis_release_zenodo_fetch_head`, `_download_bundle`,
# `_extract_and_verify`, `_validate_staging`, plus release-id-shape
# validation) live in the sibling
# `analysis-snapshot-release-zenodo-verify.R` and are covered by
# `test-unit-analysis-release-zenodo-verify.R`; this file covers the
# builders, checksums/tarball, and the `analysis_release_zenodo_package()`
# orchestrator (including the staging-directory delete guard, which is
# exercised only through the orchestrator).

library(testthat)

source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)

# --------------------------------------------------------------------------- #
# Shared fixture helper -- a valid stubbed published release (README.md +
# manifest.json + checksums.sha256, tarred), for orchestrator-level tests
# that need `analysis_release_zenodo_package()` to reach its staging/tar
# steps. Deliberately uses plain `tempfile()`-rooted names, NOT
# `withr::local_tempdir()`, inside the returned closures where relevant --
# see the shared cleanup-timing note in `test-unit-analysis-release-zenodo-
# verify.R`'s `make_well_formed_staging()` comment.
# --------------------------------------------------------------------------- #

build_fake_release_stubs <- function(work_dir, release_id = "asr_deadbeefcafebabe", bundle_sha256_override = NULL) {
  bundle_src <- file.path(work_dir, paste0("bundle_src_", as.integer(stats::runif(1, 1, 1e9))))
  dir.create(bundle_src)
  writeLines("# SysNDD analysis-snapshot release", file.path(bundle_src, "README.md"))
  writeLines(sprintf('{"release_id":"%s"}', release_id), file.path(bundle_src, "manifest.json"))
  readme_sha <- digest::digest(file = file.path(bundle_src, "README.md"), algo = "sha256")
  manifest_sha <- digest::digest(file = file.path(bundle_src, "manifest.json"), algo = "sha256")
  cat(
    paste0(readme_sha, "  README.md\n", manifest_sha, "  manifest.json\n"),
    file = file.path(bundle_src, "checksums.sha256")
  )

  bundle_path <- file.path(work_dir, paste0("bundle_", basename(bundle_src), ".tar.gz"))
  withr::with_dir(bundle_src, {
    utils::tar(
      tarfile = bundle_path, files = c("README.md", "manifest.json", "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  bundle_sha256 <- bundle_sha256_override %||% digest::digest(file = bundle_path, algo = "sha256")

  fake_head <- list(
    release_id = release_id,
    created_at = "2026-07-15T10:00:00Z",
    license = "CC-BY-4.0",
    source_data_version = "v42",
    bundle_sha256 = bundle_sha256
  )
  list(
    stub_get_json = function(url) fake_head,
    stub_download = function(url, destfile) file.copy(bundle_path, destfile, overwrite = TRUE),
    fake_head = fake_head
  )
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

test_that("make_tarball: packaging the SAME staged content twice produces a byte-identical archive (item 5)", {
  # A FIXED staging directory name (not withr::local_tempdir()'s randomized
  # basename) is essential here: the tar entry names are
  # `basename(staging_dir)/...`, so two DIFFERENT staging dirs would embed
  # two different names into the archive and legitimately produce different
  # bytes. Reusing the SAME staging_dir across two build passes mirrors the
  # real operator flow (a fixed `--staging-dir` rebuilt on every run).
  root <- file.path(tempdir(), paste0("zenodo_determinism_", as.integer(stats::runif(1, 1, 1e9))))
  rebuild_staging <- function() {
    unlink(root, recursive = TRUE, force = TRUE)
    dir.create(root, recursive = TRUE)
    writeLines("hello", file.path(root, "README.md"))
    dir.create(file.path(root, "sub"))
    writeLines("nested content", file.path(root, "sub", "b.txt"))
    root
  }

  archive_dir <- file.path(withr::local_tempdir(), "archive")

  rebuild_staging()
  result1 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run1.tar.gz"))
  sha1 <- digest::digest(file = result1$archive_path, algo = "sha256")

  Sys.sleep(1.2) # ensure real wall-clock time actually advances between builds

  rebuild_staging()
  result2 <- analysis_release_zenodo_make_tarball(root, file.path(archive_dir, "run2.tar.gz"))
  sha2 <- digest::digest(file = result2$archive_path, algo = "sha256")

  expect_identical(sha1, sha2)
  unlink(root, recursive = TRUE, force = TRUE)
})

# --------------------------------------------------------------------------- #
# package(): full orchestration with stubbed HTTP
# --------------------------------------------------------------------------- #

test_that("package(): fetches, verifies, re-stages, validates, and tars a fake published release", {
  work_dir <- withr::local_tempdir()
  stubs <- build_fake_release_stubs(work_dir)

  staging_dir <- file.path(work_dir, "staging")
  archive_dir <- file.path(work_dir, "archive")

  result <- analysis_release_zenodo_package(
    api_base_url = "http://localhost:7778",
    release_id = "latest",
    staging_dir = staging_dir,
    archive_dir = archive_dir,
    http_get_json = stubs$stub_get_json,
    http_download = stubs$stub_download
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
  stubs <- build_fake_release_stubs(
    work_dir, release_id = "asr_baadf00dbaadf00d", bundle_sha256_override = strrep("f", 64L)
  )

  expect_error(
    analysis_release_zenodo_package(
      api_base_url = "http://localhost:7778",
      release_id = "latest",
      staging_dir = file.path(work_dir, "staging2"),
      archive_dir = file.path(work_dir, "archive2"),
      http_get_json = stubs$stub_get_json,
      http_download = stubs$stub_download
    ),
    "checksum mismatch"
  )
})

test_that("package(): rejects a malformed RESOLVED release_id from the head before downloading (item 2, defense-in-depth)", {
  work_dir <- withr::local_tempdir()
  download_called <- FALSE
  fake_head <- list(release_id = "asr_not-a-valid-id!!", bundle_sha256 = strrep("0", 64L))
  stub_get_json <- function(url) fake_head
  stub_download <- function(url, destfile) {
    download_called <<- TRUE
  }

  staging_dir <- file.path(work_dir, "staging_bad_resolved_id")
  expect_error(
    analysis_release_zenodo_package(
      api_base_url = "http://localhost:7778",
      release_id = "latest",
      staging_dir = staging_dir,
      archive_dir = file.path(work_dir, "archive_bad_resolved_id"),
      http_get_json = stub_get_json,
      http_download = stub_download
    ),
    "Invalid analysis-snapshot release id"
  )
  expect_false(download_called)
  expect_false(dir.exists(staging_dir))
})

# --------------------------------------------------------------------------- #
# package(): staging-directory delete guard (item 1, BLOCKER)
# --------------------------------------------------------------------------- #

test_that("package(): refuses to delete a pre-existing non-empty staging dir without the ownership sentinel", {
  work_dir <- withr::local_tempdir()
  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_ffffffffffffffff")

  staging_dir <- file.path(work_dir, "staging_important")
  dir.create(staging_dir, recursive = TRUE)
  writeLines("do not delete me", file.path(staging_dir, "keep.txt"))

  expect_error(
    analysis_release_zenodo_package(
      api_base_url = "http://localhost:7778",
      release_id = "latest",
      staging_dir = staging_dir,
      archive_dir = file.path(work_dir, "archive_guard"),
      http_get_json = stubs$stub_get_json,
      http_download = stubs$stub_download
    ),
    "refusing to delete"
  )

  # The pre-existing directory and its content are untouched.
  expect_true(dir.exists(staging_dir))
  expect_true(file.exists(file.path(staging_dir, "keep.txt")))
  expect_identical(readLines(file.path(staging_dir, "keep.txt")), "do not delete me")
})

test_that("package(): an EMPTY pre-existing staging dir (no sentinel needed) is accepted and populated", {
  work_dir <- withr::local_tempdir()
  stubs <- build_fake_release_stubs(work_dir, release_id = "asr_1234567890abcdef")

  staging_dir <- file.path(work_dir, "staging_empty")
  dir.create(staging_dir, recursive = TRUE)

  result <- analysis_release_zenodo_package(
    api_base_url = "http://localhost:7778",
    release_id = "latest",
    staging_dir = staging_dir,
    archive_dir = file.path(work_dir, "archive_empty"),
    http_get_json = stubs$stub_get_json,
    http_download = stubs$stub_download
  )

  expect_true(file.exists(result$zenodo_metadata_path))
})

test_that("package(): re-running against a staging dir it previously created (has the sentinel) succeeds and replaces it", {
  work_dir <- withr::local_tempdir()
  staging_dir <- file.path(work_dir, "staging_reuse")
  archive_dir <- file.path(work_dir, "archive_reuse")

  stubs1 <- build_fake_release_stubs(work_dir, release_id = "asr_1111111111111111")
  result1 <- analysis_release_zenodo_package(
    api_base_url = "http://localhost:7778",
    release_id = "latest",
    staging_dir = staging_dir,
    archive_dir = archive_dir,
    http_get_json = stubs1$stub_get_json,
    http_download = stubs1$stub_download
  )
  expect_identical(result1$release_id, "asr_1111111111111111")

  # Second run against the SAME staging_dir (now sentinel-marked by the
  # first run) must succeed -- the delete guard only blocks a dir it did NOT
  # create, not a re-run against its own prior output.
  stubs2 <- build_fake_release_stubs(work_dir, release_id = "asr_2222222222222222")
  result2 <- analysis_release_zenodo_package(
    api_base_url = "http://localhost:7778",
    release_id = "latest",
    staging_dir = staging_dir,
    archive_dir = archive_dir,
    http_get_json = stubs2$stub_get_json,
    http_download = stubs2$stub_download
  )
  expect_identical(result2$release_id, "asr_2222222222222222")

  # The second run's content replaced the first's.
  manifest <- jsonlite::fromJSON(
    file.path(staging_dir, "analysis_snapshot_release", "manifest.json"), simplifyVector = TRUE
  )
  expect_identical(manifest$release_id, "asr_2222222222222222")
})
