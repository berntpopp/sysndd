# helper-fixtures.R
# Phase B B2 — fail-loud fixture presence checks for external-API tests.
#
# The pre-existing helper-mock-apis.R::skip_if_no_fixtures_or_network() silently
# skips tests when fixtures are missing. That masks bit-rot: a fixture directory
# that becomes empty (e.g. a failed `make refresh-fixtures`, or an incomplete
# merge) looks like "network unavailable" and the test suite stays green while
# coverage silently drops.
#
# skip_if_no_fixtures(subdir) is the strict replacement. It:
#   - fails loudly via testthat::fail() with a clear, actionable message if
#     the fixture directory does not exist OR is empty OR contains only
#     .gitkeep placeholder files;
#   - returns invisibly otherwise.
#
# Per Phase B spec §4.4 rule 1, an empty-or-.gitkeep-only directory is treated
# as "missing" — the fail path must fire in that case.
#
# Usage (at the top of the first test_that() in an external-API test file):
#
#   test_that("fixtures are present before running any external-API tests", {
#     skip_if_no_fixtures("pubmed")
#     succeed()
#   })
#
# Or inside any individual test:
#
#   test_that("pubtator search returns results", {
#     skip_if_no_fixtures("pubtator")
#     with_pubtator_mock({ ... })
#   })

# Files that should be ignored when checking whether a fixture directory is
# "populated". .gitkeep is the only placeholder convention in this repo;
# hidden files like .DS_Store are nobody's fixture so we ignore them too.
.sysndd_fixture_placeholder_patterns <- c(
  "^\\.gitkeep$",
  "^\\.DS_Store$"
)

#' List real (non-placeholder) fixture files under a subdir.
#'
#' @param subdir The leaf directory under tests/testthat/fixtures/
#'   (e.g. "pubmed", "pubtator").
#' @return A character vector of absolute file paths. Zero-length if
#'   the directory is empty, non-existent, or contains only placeholders.
#' @keywords internal
.sysndd_list_fixtures <- function(subdir) {
  root <- testthat::test_path("fixtures", subdir)
  if (!dir.exists(root)) {
    return(character(0))
  }
  files <- list.files(
    root,
    all.files = FALSE,
    full.names = TRUE,
    recursive = TRUE,
    include.dirs = FALSE
  )
  if (length(files) == 0L) {
    return(character(0))
  }
  # Strip any files whose basename matches a placeholder pattern.
  basenames <- basename(files)
  is_placeholder <- Reduce(
    `|`,
    lapply(.sysndd_fixture_placeholder_patterns, function(pat) grepl(pat, basenames)),
    init = rep(FALSE, length(basenames))
  )
  files[!is_placeholder]
}

#' Fail the test loudly if fixtures for `subdir` are missing.
#'
#' **This is NOT a silent skip.** The point is to make "empty fixture dir"
#' impossible to overlook. If no real fixture files are present under
#' `tests/testthat/fixtures/<subdir>/`, the test fails with an actionable
#' message telling the developer how to regenerate fixtures.
#'
#' @param subdir One of "pubmed" or "pubtator" (or any future external-API
#'   fixture namespace — no hardcoded allowlist).
#' @return Invisibly TRUE if fixtures are present. On failure the function
#'   calls `testthat::fail()` (which throws an expectation failure that
#'   halts the enclosing `test_that()` block) and then `stop()` as a
#'   belt-and-braces guard for callers using the helper outside a
#'   `test_that()` scope.
#' @export
skip_if_no_fixtures <- function(subdir) {
  if (!is.character(subdir) || length(subdir) != 1L || !nzchar(subdir)) {
    stop(
      "skip_if_no_fixtures(): `subdir` must be a single non-empty string ",
      "(e.g. \"pubmed\" or \"pubtator\")."
    )
  }

  files <- .sysndd_list_fixtures(subdir)
  if (length(files) > 0L) {
    return(invisible(TRUE))
  }

  root <- testthat::test_path("fixtures", subdir)
  msg <- paste0(
    "Missing httptest2 fixtures for `", subdir, "`.\n",
    "  Expected at least one non-placeholder file under: ", root, "\n",
    "  (`.gitkeep`-only directories are treated as empty per Phase B B2 spec.)\n",
    "  To regenerate fixtures, run: make refresh-fixtures\n",
    "  See api/tests/testthat/fixtures/README.md for details."
  )
  # `testthat::fail()` produces an expectation failure that the testthat
  # reporter surfaces loudly and that halts the enclosing test_that() block.
  # `stop()` after it guarantees the caller sees a hard error if this helper
  # is ever invoked outside a testthat scope (e.g. from the R REPL).
  testthat::fail(msg)
  stop(msg, call. = FALSE)
}

#' Return the path to a specific captured fixture file, if present.
#'
#' Convenience accessor for tests that need to read a captured response
#' body directly (e.g. to test a parser without having to call a live
#' production function). Returns NULL if the file is missing.
#'
#' @param subdir Fixture namespace ("pubmed" or "pubtator").
#' @param name Relative path under the namespace directory.
#' @return Absolute file path as character, or NULL if missing.
#' @export
fixture_path <- function(subdir, name) {
  p <- testthat::test_path("fixtures", subdir, name)
  if (!file.exists(p)) {
    return(NULL)
  }
  p
}
