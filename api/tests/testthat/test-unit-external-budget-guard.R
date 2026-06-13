# tests/testthat/test-unit-external-budget-guard.R
#
# Static guard (#344): every external HTTP fetcher must derive its timeout and
# retry window from external_proxy_budget(), never hardcode a numeric literal.
# A bypass re-introduced the head-of-line-blocking bug once already (GeneReviews,
# PR #389) after the original isolation work (PR #386) had fixed it.
#
# Pure test (no DB / no network) — runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-external-budget-guard.R')"

external_fetcher_files <- function() {
  fdir <- file.path(get_api_dir(), "functions")
  files <- list.files(fdir, pattern = "^external-proxy-.*\\.R$", full.names = TRUE)
  files <- c(files, file.path(fdir, "genereviews-lookup.R"))
  files <- files[file.exists(files)]
  # external-proxy-functions.R legitimately DEFINES the numeric budget defaults.
  files[!grepl("external-proxy-functions\\.R$", files)]
}

test_that("no external fetcher hardcodes req_timeout(<number>)", {
  offenders <- character()
  for (f in external_fetcher_files()) {
    src <- readLines(f, warn = FALSE)
    hits <- grep("req_timeout\\(\\s*[0-9]", src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(basename(f), ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "Hardcoded req_timeout literals (use external_proxy_budget()):",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("no external fetcher hardcodes max_seconds=<number>", {
  offenders <- character()
  for (f in external_fetcher_files()) {
    src <- readLines(f, warn = FALSE)
    hits <- grep("max_seconds\\s*=\\s*[0-9]", src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(basename(f), ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "Hardcoded max_seconds literals (use external_proxy_budget()):",
      paste(offenders, collapse = " | ")
    )
  )
})
