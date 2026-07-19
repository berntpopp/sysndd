# tests/testthat/analysis-release-zenodo-verify-fixtures.R
#
# Shared fixture builder for the analysis-snapshot RELEASE Zenodo
# fetch/extract-verify tests (#573 Slice C). Extracted out of
# test-unit-analysis-release-zenodo-verify.R (Codex round-3 hardening) so
# BOTH that file and the sibling
# test-unit-analysis-release-zenodo-verify-round3.R can build the same
# fixture bundle without duplicating it -- mirrors the `pubmed-xml-fixtures.R`
# precedent. NOT a `helper-*.R` file: testthat's helper auto-load only runs
# under `test_dir()`, not `test_file()` (see AGENTS.md's single-test
# shortcuts), so every consumer explicitly `source_api_file()`s this path.
#
# Requires `%||%` (defined in analysis-snapshot-release-zenodo-common.R,
# guard-sourced by -package.R) to already be in scope -- callers source
# `functions/analysis-snapshot-release-zenodo-package.R` first.

# Builds a tiny tar.gz with two files + a matching (or deliberately wrong,
# omitted, duplicated, or traversal-shaped) inner checksums.sha256, mirroring
# the shape of a real release bundle (files directly at the archive root --
# NOT nested under a named subdirectory, unlike the sibling nddscore
# archive).
#
# @param omit_checksum_for character vector of "a.txt"/"b.txt" to leave OUT
#   of checksums.sha256 while still including the file in the tar (proves
#   the coverage gap check, item 4).
# @param extra_checksum_lines extra raw lines appended verbatim to
#   checksums.sha256 (proves the path-traversal + duplicate-entry checks,
#   item 4, and the non-regular-file guard, round-3 item 1).
build_fixture_bundle <- function(
    dir, a_sha_override = NULL, b_sha_override = NULL,
    omit_checksum_for = character(0), extra_checksum_lines = character(0)) {
  src <- file.path(dir, paste0("src_", as.integer(stats::runif(1, 1, 1e9))))
  dir.create(src, recursive = TRUE)
  writeLines("file A content", file.path(src, "a.txt"))
  writeLines("file B content", file.path(src, "b.txt"))
  a_sha <- a_sha_override %||% digest::digest(file = file.path(src, "a.txt"), algo = "sha256")
  b_sha <- b_sha_override %||% digest::digest(file = file.path(src, "b.txt"), algo = "sha256")

  lines <- character(0)
  if (!("a.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(a_sha, "  a.txt"))
  if (!("b.txt" %in% omit_checksum_for)) lines <- c(lines, paste0(b_sha, "  b.txt"))
  lines <- c(lines, extra_checksum_lines)
  cat(paste0(paste(lines, collapse = "\n"), "\n"), file = file.path(src, "checksums.sha256"))

  bundle_path <- file.path(dir, paste0("bundle_", basename(src), ".tar.gz"))
  withr::with_dir(src, {
    utils::tar(
      tarfile = bundle_path, files = c("a.txt", "b.txt", "checksums.sha256"),
      compression = "gzip", tar = "internal"
    )
  })
  bundle_path
}
