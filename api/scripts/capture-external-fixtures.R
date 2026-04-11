#!/usr/bin/env Rscript
# capture-external-fixtures.R
#
# Phase B B2 — Real-network fixture capture for PubMed and PubTator.
#
# This script makes live HTTP requests to the NCBI eUtils PubMed API and the
# NCBI PubTator3 API, and saves the raw responses to
# `api/tests/testthat/fixtures/{pubmed,pubtator}/` using httptest2's on-disk
# mock-directory format (`httptest2::with_mock_dir`). Subsequent test runs that
# wrap httr2 calls in `with_mock_dir()` will replay these fixtures instead of
# hitting the network.
#
# Usage (from repo root):
#   make refresh-fixtures
# or, directly via docker (no host-side R deps needed):
#   docker run --rm \
#     -v "$(pwd)/api/tests/testthat/fixtures:/fixtures" \
#     -v "$(pwd)/api/scripts:/scripts" \
#     sysndd-api:latest \
#     Rscript /scripts/capture-external-fixtures.R /fixtures
#
# Requirements: httr2, httptest2, jsonlite. All present in the sysndd-api image.
#
# Safety:
# - Never commits API keys — redactor strips `api_key=` parameters and emails.
# - Uses polite rate limiting (NCBI recommends <= 3 req/sec without key).
# - Queries chosen to be stable, public, and small (BRCA1 + fixed PMIDs).

suppressPackageStartupMessages({
  library(httr2)
  library(httptest2)
  library(jsonlite)
})

# -----------------------------------------------------------------------------
# CLI arg: output directory (defaults to api/tests/testthat/fixtures)
#
# Fallback resolution when no arg is given: prefer the script's own directory
# via sys.frame(1)$ofile (works when sourced); fall back to Rscript's own
# --file= argument (works when invoked as `Rscript path/to/script.R`); fall
# back to "." as a last resort. We deliberately avoid the `%||%` rlang helper
# here so the script has zero R-package dependencies beyond what's imported
# at the top of the file (httr2, httptest2, jsonlite) — see Copilot review
# comment #2 on PR #236.
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  fixtures_root <- normalizePath(args[1], mustWork = FALSE)
} else {
  # Resolve the script file path without depending on rlang's %||%.
  script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(script_file) || !nzchar(script_file)) {
    # Rscript sets its own `--file=` entry in commandArgs(trailingOnly = FALSE).
    full_args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", full_args, value = TRUE)
    if (length(file_arg) >= 1) {
      script_file <- sub("^--file=", "", file_arg[1])
    } else {
      script_file <- "."
    }
  }
  fixtures_root <- normalizePath(
    file.path(dirname(script_file), "..", "tests", "testthat", "fixtures"),
    mustWork = FALSE
  )
}

if (!dir.exists(fixtures_root)) {
  stop("Fixtures root does not exist: ", fixtures_root)
}

pubmed_dir   <- file.path(fixtures_root, "pubmed")
pubtator_dir <- file.path(fixtures_root, "pubtator")
dir.create(pubmed_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(pubtator_dir, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# Redactor: strip any api_key parameter (NCBI accepts api_key=... to raise rate
# limits). Even if no key is set in this env, mirror what helper-mock-apis.R
# does so captured fixtures are safe to commit unconditionally.
# -----------------------------------------------------------------------------
redactor <- function(resp) {
  resp <- httptest2::gsub_response(resp, "api_key=[^&\"]+", "api_key=REDACTED")
  resp <- httptest2::gsub_response(
    resp,
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    "REDACTED@example.com"
  )
  resp
}
httptest2::set_redactor(redactor)

polite_sleep <- function(seconds = 0.4) Sys.sleep(seconds)

# Safe wrapper: if a request fails, print a clear error and continue so that
# at least partial captures commit.
try_request <- function(label, req_expr) {
  message("  -> ", label)
  tryCatch(
    {
      resp <- eval(req_expr)
      polite_sleep()
      invisible(resp)
    },
    error = function(e) {
      message("    ERROR capturing ", label, ": ", conditionMessage(e))
      invisible(NULL)
    }
  )
}

# User agent recommended by NCBI.
ua <- "sysndd-ci-fixture-capture/1.0 (https://sysndd.clinicalgenetics.dev)"

# -----------------------------------------------------------------------------
# 1) PubMed eUtils capture
#
# httptest2::start_capturing() tees httr2 responses to a directory, naming
# files after a stable hash of the request URL + method. The captured files
# then replay automatically inside with_mock_dir(pubmed_dir, ...).
# -----------------------------------------------------------------------------
message("[1/2] Capturing PubMed eUtils fixtures into ", pubmed_dir)

# httptest2 writes captures to the first directory in .mockPaths(). Stack our
# target on top so saved files land under fixtures/pubmed/*.
old_mock_paths <- httptest2::.mockPaths()
httptest2::.mockPaths(pubmed_dir)
httptest2::start_capturing(simplify = FALSE)
on.exit(try(httptest2::stop_capturing(), silent = TRUE), add = TRUE)

# 1a) esearch for a known-good PMID ("PMID[PMID]" exact-match form used by
# check_pmid()).
try_request("esearch PMID 33054928", quote({
  request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") |>
    req_url_query(
      db = "pubmed",
      term = "33054928[PMID]",
      retmode = "xml"
    ) |>
    req_user_agent(ua) |>
    req_perform()
}))

# 1b) efetch XML for the same PMID — this is the payload that
# easyPubMed::fetch_pubmed_data() ultimately parses.
try_request("efetch PMID 33054928", quote({
  request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi") |>
    req_url_query(
      db = "pubmed",
      id = "33054928",
      retmode = "xml",
      rettype = "xml"
    ) |>
    req_user_agent(ua) |>
    req_perform()
}))

# 1c) esearch for a nonsense query — expected to return count=0.
try_request("esearch empty-results query", quote({
  request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") |>
    req_url_query(
      db = "pubmed",
      term = "xyzzy12345nonexistent98765[PMID]",
      retmode = "xml"
    ) |>
    req_user_agent(ua) |>
    req_perform()
}))

httptest2::stop_capturing()
httptest2::.mockPaths(old_mock_paths)

# -----------------------------------------------------------------------------
# 2) PubTator3 BioCJSON + search capture
# -----------------------------------------------------------------------------
message("[2/2] Capturing PubTator3 fixtures into ", pubtator_dir)

old_mock_paths <- httptest2::.mockPaths()
httptest2::.mockPaths(pubtator_dir)
httptest2::start_capturing(simplify = FALSE)

# 2a) search for "BRCA1" page 1 — returns JSON with `total_pages`.
try_request("pubtator search BRCA1 p1", quote({
  request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/") |>
    req_url_query(text = "BRCA1", page = "1") |>
    req_user_agent(ua) |>
    req_perform()
}))

# 2b) search nonsense query — returns empty.
try_request("pubtator search empty", quote({
  request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/") |>
    req_url_query(text = "xyzzy12345nonexistent98765", page = "1") |>
    req_user_agent(ua) |>
    req_perform()
}))

# 2c) biocjson export for a known PMID — returns annotated JSON document.
try_request("pubtator biocjson PMID 33054928", quote({
  request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson") |>
    req_url_query(pmids = "33054928") |>
    req_user_agent(ua) |>
    req_perform()
}))

httptest2::stop_capturing()
httptest2::.mockPaths(old_mock_paths)

message("Capture complete.")
message("PubMed fixtures: ", length(list.files(pubmed_dir, recursive = TRUE)))
message("PubTator fixtures: ", length(list.files(pubtator_dir, recursive = TRUE)))
