# tests/testthat/test-unit-phenotype-clustering-approved-guard.R
#
# Guard (#3, Codex PR-2): the PUBLIC /api/jobs/phenotype_clustering/submit path
# builds its review set from ndd_entity_review. It must gate on
# review_approved == 1 (not is_primary alone), or a public clustering job — and
# the per-cluster phenotype stats it returns — leaks UNAPPROVED curation, the
# same class the served-snapshot path already gates.
#
# Source scan — runs on host. #346 Wave 3 Task 5 moved the handler body (and
# this guarded `dplyr::filter(is_primary == 1, review_approved == 1)` call)
# out of endpoints/jobs_endpoints.R and into
# api/services/job-phenotype-submission-service.R
# (svc_job_submit_phenotype_clustering()); the endpoint shell now only
# delegates. Scan the service file so this guard stays meaningful instead of
# vacuously succeeding on a file with zero is_primary matches.

test_that("phenotype_clustering submit gates the review set on review_approved", {
  src <- readLines(
    file.path(get_api_dir(), "services", "job-phenotype-submission-service.R"),
    warn = FALSE
  )
  body <- paste(src, collapse = "\n")

  # The extracted service must still be the code the public submit endpoint
  # actually calls (guards against a future re-inline that would make this
  # scan target stale again).
  endpoint_src <- readLines(file.path(get_api_dir(), "endpoints", "jobs_endpoints.R"), warn = FALSE)
  expect_true(
    any(grepl("svc_job_submit_phenotype_clustering", endpoint_src)),
    info = "jobs_endpoints.R must delegate /phenotype_clustering/submit to svc_job_submit_phenotype_clustering"
  )

  # The scan itself must actually find at least one is_primary filter here —
  # otherwise the loop below would vacuously succeed() again.
  expect_true(
    grepl("is_primary", body, fixed = TRUE),
    info = "job-phenotype-submission-service.R must build the review set from is_primary"
  )

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
