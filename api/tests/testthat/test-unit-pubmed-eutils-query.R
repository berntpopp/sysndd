# test-unit-pubmed-eutils-query.R
#
# Regression guard (#494): the PubMed E-utilities helpers must attach an NCBI
# `api_key` (and optional `email`/`tool`) from the environment so the
# publication-date backfill runs at the keyed 10 req/s ceiling instead of the
# anonymous 3 req/s cap that 429s large EFetch batches into a whole-job
# "systemic outage". Mirrors the existing genereviews_eutils_query() pattern.
#
# Pure helpers (no DB / no network) — runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-pubmed-eutils-query.R')"

api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/publication-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

library(stringr)

# publication-functions.R conditionally sources db-helpers.R (RMariaDB) only when
# db_execute_query is undefined; pre-stub so it loads without RMariaDB.
if (!exists("db_execute_query", mode = "function", envir = globalenv())) {
  assign("db_execute_query",
    function(...) stop("db_execute_query stub"),
    envir = globalenv()
  )
}

original_wd <- getwd()
setwd(api_dir)
source("functions/publication-functions.R")
setwd(original_wd)

# ---------------------------------------------------------------------------
# pubmed_eutils_query(): appends tool/email/api_key from env
# ---------------------------------------------------------------------------

test_that("pubmed_eutils_query preserves caller params and always sets tool", {
  withr::local_envvar(NCBI_API_KEY = "", NCBI_EUTILS_EMAIL = "")
  q <- pubmed_eutils_query(list(db = "pubmed", id = "111,222"))
  expect_identical(q$db, "pubmed")
  expect_identical(q$id, "111,222")
  expect_identical(q$tool, "sysndd")
})

test_that("pubmed_eutils_query omits api_key and email when env is unset", {
  withr::local_envvar(NCBI_API_KEY = "", NCBI_EUTILS_EMAIL = "")
  q <- pubmed_eutils_query(list(db = "pubmed"))
  expect_null(q$api_key)
  expect_null(q$email)
})

test_that("pubmed_eutils_query adds api_key when NCBI_API_KEY is set", {
  withr::local_envvar(NCBI_API_KEY = "test-key-123", NCBI_EUTILS_EMAIL = "")
  q <- pubmed_eutils_query(list(db = "pubmed"))
  expect_identical(q$api_key, "test-key-123")
})

test_that("pubmed_eutils_query adds email when NCBI_EUTILS_EMAIL is set", {
  withr::local_envvar(NCBI_API_KEY = "", NCBI_EUTILS_EMAIL = "curator@example.org")
  q <- pubmed_eutils_query(list(db = "pubmed"))
  expect_identical(q$email, "curator@example.org")
})

test_that("pubmed_eutils_query does not override an explicit tool", {
  withr::local_envvar(NCBI_API_KEY = "", NCBI_EUTILS_EMAIL = "")
  q <- pubmed_eutils_query(list(db = "pubmed", tool = "backfill"))
  expect_identical(q$tool, "backfill")
})

# ---------------------------------------------------------------------------
# pubmed_min_request_interval(): faster pacing when an API key is present
# ---------------------------------------------------------------------------

test_that("pubmed_min_request_interval throttles to ~3 req/s without a key", {
  withr::local_envvar(NCBI_API_KEY = "")
  interval <- pubmed_min_request_interval()
  # Anonymous NCBI cap is 3 req/s -> at least ~0.33s between requests.
  expect_gte(interval, 0.33)
})

test_that("pubmed_min_request_interval speeds up with a key but stays under 10 req/s", {
  withr::local_envvar(NCBI_API_KEY = "test-key-123")
  interval <- pubmed_min_request_interval()
  # Keyed cap is 10 req/s; stay strictly above 0.1s (i.e. below 10 req/s) with margin.
  expect_gt(interval, 0.1)
  expect_lt(interval, 0.33)
})
