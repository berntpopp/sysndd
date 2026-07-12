# tests/testthat/test-unit-job-payload-credential-guard.R
#
# #535 P1-1 regression guard. The backup job family must never again marshal a
# DB credential into a durable job payload, and no NEW credential-in-payload
# site may appear anywhere in functions/ services/ endpoints/. The remaining
# offenders are the S2b-pending families, frozen here as an EXACT
# "basename | line" set (not just counts, so removing one and adding one in the
# same file still fails): S2b removes entries as it migrates each family to
# async_job_worker_db_config(); a NEW leak breaks the assertion.
#
# The guard is a heuristic — it detects the direct `X = <var>$password` /
# `X = <var>[["password"]]` / `X = <var>[['password']]` marshaling forms and a
# `db_config = dw` bypass. It does NOT track arbitrary indirection (e.g.
# `cfg <- dw; db_config = cfg`, or `password = cfg$secret`); catching those
# needs parsed R expressions and is out of proportion for a regression guard.
# The STRONG guarantees are the exact-string assertions on the (fixed) backup
# path below plus the frozen offender set. Static, host-runnable.

library(testthat)

# "password = <var>$password" or "password = <var>[['password']]" (either quote), and db_password.
.cred_pattern <- paste0(
  "(password|db_password)[[:space:]]*=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*",
  "(\\$|\\[\\[[\"'])(password|db_password)"
)

.scan_files <- function() {
  dirs <- c("../../functions", "../../services", "../../endpoints")
  files <- unlist(lapply(dirs, function(d) list.files(d, pattern = "\\.R$", full.names = TRUE)))
  # The clean runtime resolver/connector and the generic DB helper are not payloads.
  files[!basename(files) %in% c("async-job-db-config.R", "db-helpers.R")]
}

.scan_cred_lines <- function() {
  out <- character(0)
  for (f in .scan_files()) {
    hits <- grep(.cred_pattern, readLines(f, warn = FALSE), value = TRUE)
    if (length(hits)) out <- c(out, paste(basename(f), trimws(hits), sep = " | "))
  }
  sort(out)
}

# Positive control: a migrated durable-handler file must open its worker
# connection via the run-time resolver, not a payload-supplied credential.
.expect_resolves_creds <- function(rel) {
  blob <- paste(readLines(file.path("../..", rel), warn = FALSE), collapse = "\n")
  expect_true(
    grepl("async_job_db_connect\\(", blob),
    info = paste(rel, "must open its worker connection via async_job_db_connect()")
  )
}

test_that("the fixed backup path carries no DB credential in its job payload", {
  bs <- readLines("../../services/backup-endpoint-service.R", warn = FALSE)
  blob <- paste(bs, collapse = "\n")
  expect_false(grepl("\\.svc_backup_db_config", blob))
  expect_false(grepl("db_config[[:space:]]*=", blob))  # no db_config assignment/param
  expect_false(grepl("dw\\$", blob))                    # backup submit never reads dw
  expect_equal(sum(grepl(.cred_pattern, bs)), 0L)
  expect_equal(sum(grepl(.cred_pattern, readLines("../../functions/backup-functions.R", warn = FALSE))), 0L)

  # Both backup handlers resolve creds at run time via the resolver (not payload).
  mh <- readLines("../../functions/async-job-maintenance-handlers.R", warn = FALSE)
  expect_gte(sum(grepl("async_job_worker_db_config\\(", mh)), 2L)
})

test_that("credential-in-payload line set matches the frozen S2b-pending list", {
  expected <- sort(c(
    "llm-batch-generator.R | db_password = db_cfg$password",
    "llm-batch-generator.R | password = db_config$db_password",
    "publication-admin-endpoint-service.R | db_password = dw$db_password,",
    "publication-admin-endpoint-service.R | db_password = dw$password",
    "pubtator-functions.R | password = db_config$db_password,",
    "pubtatornidd-nightly.R | db_password = dw_config$password"
  ))
  actual <- .scan_cred_lines()
  expect_identical(
    actual, expected,
    info = paste(
      "Credential-in-payload set changed. Added a site -> resolve via",
      "async_job_worker_db_config() instead of putting the password in the",
      "payload. Migrated a family in S2b -> update this frozen set. 'backup*'",
      "must never appear here."
    )
  )
  expect_false(any(grepl("backup", actual)))
})

test_that("migrated durable handlers resolve DB creds at run time via the resolver", {
  .expect_resolves_creds("functions/async-job-omim-apply.R")
  .expect_resolves_creds("functions/async-job-provider-handlers.R")
  .expect_resolves_creds("functions/comparisons-functions.R")
  .expect_resolves_creds("functions/async-job-maintenance-handlers.R")
})

test_that("no site passes a raw dw/config object as a db_config (bypass tripwire)", {
  offenders <- Filter(function(f) {
    any(grepl("db_config[[:space:]]*(=|<-)[[:space:]]*dw\\b", readLines(f, warn = FALSE)))
  }, .scan_files())
  expect_equal(
    length(offenders), 0L,
    info = paste("raw dw passed as db_config in:", paste(basename(offenders), collapse = ", "))
  )
})
