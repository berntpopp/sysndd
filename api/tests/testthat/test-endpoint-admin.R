library(testthat)

admin_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "admin_endpoints.R")
}

admin_source <- function() {
  readLines(admin_endpoint_path(), warn = FALSE)
}

admin_body_blob <- function(decorator_regex) {
  src <- admin_source()
  dec_hits <- grep(decorator_regex, src)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in admin_endpoints.R: ", decorator_regex)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}

admin_body_blob_exact <- function(decorator) {
  src <- admin_source()
  dec_hits <- grep(decorator, src, fixed = TRUE)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in admin_endpoints.R: ", decorator)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}

expect_admin_guard <- function(body_blob) {
  expect_match(body_blob, "require_role\\(")
  expect_match(body_blob, "Administrator")
}

test_that("admin_endpoints.R exposes ontology async and force-apply route surface", {
  with_test_db_transaction({
    src <- admin_source()
    expect_true(any(grepl("^#\\*\\s+@put\\s+update_ontology_async\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@put\\s+force_apply_ontology\\s*$", src)))
  })
})

test_that("admin ontology mutation routes require Administrator role", {
  with_test_db_transaction({
    expect_admin_guard(admin_body_blob("^#\\*\\s+@put\\s+update_ontology_async\\s*$"))
    expect_admin_guard(admin_body_blob("^#\\*\\s+@put\\s+force_apply_ontology\\s*$"))
  })
})

test_that("force_apply_ontology validates blocked_job_id before job submission", {
  with_test_db_transaction({
    body <- admin_body_blob("^#\\*\\s+@put\\s+force_apply_ontology\\s*$")
    expect_match(body, "blocked_job_id")
    expect_match(body, "400")
    expect_match(body, "create_job|async_job_service_submit|submit_async_job|enqueue")
  })
})

# Source-level (no DB) so it always runs, including in CI without a test DB.
test_that("force_apply_ontology reads the blocked job in full mode", {
  body <- admin_body_blob("^#\\*\\s+@put\\s+force_apply_ontology\\s*$")
  # #470 review A1: the handler inspects blocked_job$result to confirm the job
  # was "blocked", but get_job_status() omits the parsed result in summary mode.
  # Without result_mode = "full" the blocked check returns 409 every time, so
  # Force Apply could never resolve a block. Lock the full-mode lookup in place.
  expect_match(
    body,
    "get_job_status\\(\\s*blocked_job_id\\s*,\\s*result_mode\\s*=\\s*[\"']full[\"']"
  )
  expect_match(body, "Referenced job was not blocked")
})

test_that("NDDScore admin routes keep Administrator guard and async job boundary", {
  with_test_db_transaction({
    src <- admin_source()
    nddscore_decorators <- grep(
      "^#\\*\\s+@(post|put|get).*nddscore",
      src,
      value = TRUE,
      ignore.case = TRUE
    )
    expect_gt(length(nddscore_decorators), 0L)
    nddscore_blocks <- lapply(nddscore_decorators, function(decorator) {
      admin_body_blob_exact(decorator)
    })
    expect_true(any(vapply(nddscore_blocks, grepl, logical(1), pattern = "require_role\\(")))
    expect_true(any(vapply(
      nddscore_blocks,
      grepl,
      logical(1),
      pattern = "nddscore_import|async_job_service_submit|async"
    )))
  })
})
