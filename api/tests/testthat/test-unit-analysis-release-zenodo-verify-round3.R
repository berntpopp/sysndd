# Unit tests for the Codex round-3 hardening of the analysis-snapshot
# RELEASE Zenodo fetch/extract-verify helpers (#573 Slice C):
# api/functions/analysis-snapshot-release-zenodo-verify.R.
#
# Split out of the sibling test-unit-analysis-release-zenodo-verify.R (which
# covers the pre-existing/round-1/round-2 fetch/extract/staging-validator
# behavior) to keep both files under the repo's 600-line soft ceiling --
# mirrors the `-upload.R`/`-upload-doi-safety.R` split precedent. Shares
# `build_fixture_bundle()` (the tar.gz + inner checksums.sha256 builder) via
# `analysis-release-zenodo-verify-fixtures.R`, sourced below, rather than
# duplicating it.
#
# Covers item 1 (HIGH): `.analysis_release_zenodo_reject_unsafe_files()`
# (renamed from `.analysis_release_zenodo_reject_symlinks()`) rejects ANY
# non-regular file under the extracted bundle tree -- not just symlinks --
# so a FIFO/pipe can never reach `digest::digest(file = ...)`, which would
# otherwise block indefinitely reading it.

library(testthat)

source_api_file("functions/analysis-snapshot-release-zenodo-package.R", local = FALSE)
source_api_file("tests/testthat/analysis-release-zenodo-verify-fixtures.R", local = FALSE)

# --------------------------------------------------------------------------- #
# extract_and_verify: non-regular-file (FIFO) rejection (item 1, HIGH)
# --------------------------------------------------------------------------- #

test_that("extract_and_verify: FAILS when a non-regular file (FIFO) sits in the extraction dir (Codex round-3 item 1, HIGH) -- rejected BEFORE any digest read, does not hang", {
  # Proves the round-3 HIGH fix: the extracted-tree guard must reject ANY
  # non-regular file, not just symlinks. A FIFO passes the round-2 guard
  # (which only checked `Sys.readlink()`), and `digest::digest(file = ...)`
  # on a FIFO with no writer connected blocks INDEFINITELY -- a fail-closed
  # violation.
  #
  # The FIFO's name is deliberately listed in the bundle's OWN
  # checksums.sha256 (via `extra_checksum_lines`): absent the guard, the
  # per-line checksum-verification loop inside `extract_and_verify()` would
  # reach `digest::digest(file = <the fifo path>)` and hang forever. This
  # test's own bounded completion (testthat has no per-test timeout, but a
  # hang here would stall/timeout the whole suite run) is therefore direct
  # evidence the non-regular-file guard fires and stops the function BEFORE
  # the checksum loop ever opens the FIFO for reading. This was manually
  # confirmed by driving `analysis_release_zenodo_extract_and_verify()`
  # directly under a bash `timeout` before this test was written.
  #
  # The FIFO is planted directly in the (pre-created) extraction directory --
  # not packed into the tar.gz itself -- because taring/untaring a FIFO node
  # is an orthogonal, less portable concern; planting it here exercises the
  # exact same post-untar guard call site with no risk of the archive step
  # itself blocking.
  work_dir <- withr::local_tempdir()
  fifo_rel_name <- "evil_fifo"
  bundle_path <- build_fixture_bundle(
    work_dir, extra_checksum_lines = paste0(strrep("0", 64L), "  ", fifo_rel_name)
  )
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  exdir <- file.path(work_dir, "extracted_fifo_member")
  dir.create(exdir, recursive = TRUE)
  fifo_path <- file.path(exdir, fifo_rel_name)
  fifo_created <- identical(
    base::system2("mkfifo", shQuote(fifo_path), stdout = FALSE, stderr = FALSE), 0L
  )
  skip_if_not(fifo_created, "host does not support mkfifo (e.g. some restricted/Windows runners)")

  expect_error(
    analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir),
    "non-regular file"
  )
  # The FIFO node itself is untouched (stat'd, never opened for reading),
  # which is exactly why the guard call above returned promptly instead of
  # blocking.
  expect_true(file.exists(fifo_path))
})

test_that("extract_and_verify: a normal bundle with no special files still passes (non-regular-file guard has no false positive)", {
  work_dir <- withr::local_tempdir()
  bundle_path <- build_fixture_bundle(work_dir)
  expected_sha <- digest::digest(file = bundle_path, algo = "sha256")

  exdir <- file.path(work_dir, "extracted_ok")
  expect_no_error(
    analysis_release_zenodo_extract_and_verify(bundle_path, expected_sha, exdir = exdir)
  )
  expect_true(file.exists(file.path(exdir, "a.txt")))
})
