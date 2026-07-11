# tests/testthat/test-unit-job-payload-credential-guard.R
#
# #535 P1-1 regression guard. The backup job family must never again marshal a
# DB credential into a durable job payload, and no NEW credential-in-payload
# site may appear anywhere in functions/ services/ endpoints/. The remaining
# offenders are the S2b-pending families, frozen here as an exact (file ->
# count) set: S2b removes entries as it migrates each family to
# async_job_worker_db_config(); a NEW leak (new file OR extra line in a listed
# file) breaks the exact-set assertion. Static, host-runnable.

library(testthat)

# Matches "password = <var>$password" / "db_password = <var>$..." — the pattern a
# submit site uses to read a credential into a config/params list, and the
# handler-side db_config$password reads that depend on it.
.cred_pattern <- "(^|[^A-Za-z_])(password|db_password)[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*\\$(password|db_password)"

.count_cred_lines <- function(path) {
  if (!file.exists(path)) return(0L)
  sum(grepl(.cred_pattern, readLines(path, warn = FALSE)))
}

.scan_cred_offenders <- function() {
  dirs <- c("../../functions", "../../services", "../../endpoints")
  files <- unlist(lapply(dirs, function(d) list.files(d, pattern = "\\.R$", full.names = TRUE)))
  # The clean runtime resolver and the generic DB connection helper are not payloads.
  files <- files[!basename(files) %in% c("async-job-db-config.R", "db-helpers.R")]
  counts <- vapply(files, .count_cred_lines, integer(1))
  names(counts) <- basename(files)
  counts <- counts[counts > 0]
  counts[order(names(counts))]
}

test_that("the fixed backup path carries no DB credential in its job payload", {
  bs <- paste(readLines("../../services/backup-endpoint-service.R"), collapse = "\n")
  expect_false(grepl(".svc_backup_db_config", bs, fixed = TRUE))
  expect_false(grepl("db_config", bs, fixed = TRUE))
  expect_equal(.count_cred_lines("../../services/backup-endpoint-service.R"), 0L)
  expect_equal(.count_cred_lines("../../functions/backup-functions.R"), 0L)

  # Both backup handlers resolve creds at run time via the resolver (not payload).
  mh <- readLines("../../functions/async-job-maintenance-handlers.R", warn = FALSE)
  expect_gte(sum(grepl("async_job_worker_db_config\\(", mh)), 2L)
})

test_that("credential-in-payload offender set matches the frozen S2b-pending list", {
  expected <- c(
    "admin-ontology-endpoint-service.R"            = 1L,
    "admin-publication-refresh-endpoint-service.R" = 1L,
    "admin_publications_endpoints.R"               = 1L,
    "async-job-omim-apply.R"                       = 1L,
    "async-job-provider-handlers.R"                = 1L,
    "comparisons-functions.R"                      = 1L,
    "job-maintenance-submission-service.R"         = 2L,
    "llm-batch-generator.R"                        = 2L,
    "publication-admin-endpoint-service.R"         = 2L,
    "pubtator-functions.R"                         = 1L,
    "pubtatornidd-nightly.R"                       = 1L
  )
  expected <- expected[order(names(expected))]
  actual <- .scan_cred_offenders()
  expect_identical(
    actual, expected,
    info = paste(
      "Credential-in-payload set changed. If you ADDED a site, remove the",
      "credential from the payload (resolve via async_job_worker_db_config).",
      "If you MIGRATED a family in S2b, update this frozen set. 'backup*' must",
      "never appear here."
    )
  )
  expect_false(any(grepl("backup", names(actual))))
})
