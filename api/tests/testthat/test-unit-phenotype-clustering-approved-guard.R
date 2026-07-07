# tests/testthat/test-unit-phenotype-clustering-approved-guard.R
#
# Guard (#3, Codex PR-2): the PUBLIC /api/jobs/phenotype_clustering/submit path
# builds its review set from ndd_entity_review. It must gate on
# review_approved == 1 (not is_primary alone), or a public clustering job — and
# the per-cluster phenotype stats it returns — leaks UNAPPROVED curation, the
# same class the served-snapshot path already gates.
#
# Source scan — runs on host.

test_that("phenotype_clustering submit gates the review set on review_approved", {
  src <- readLines(file.path(get_api_dir(), "endpoints", "jobs_endpoints.R"), warn = FALSE)
  body <- paste(src, collapse = "\n")

  # Every ndd_entity_review filter on is_primary in this file must also carry
  # review_approved (the submit path builds review_id sets for clustering input).
  matches <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", body)[[1]]
  if (matches[1] != -1) {
    lens <- attr(matches, "match.length")
    for (i in seq_along(matches)) {
      frag <- substr(body, matches[i], matches[i] + lens[i] - 1)
      expect_true(grepl("review_approved", frag),
                  info = paste("is_primary filter without review_approved:", frag))
    }
  }
  succeed()
})
