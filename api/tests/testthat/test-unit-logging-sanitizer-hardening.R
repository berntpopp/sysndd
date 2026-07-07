# tests/testthat/test-unit-logging-sanitizer-hardening.R
#
# Guard (LOW-3): the request-log sanitizer must redact compound sensitive field
# names (access_token, refresh_token, password_hash, api_key, ...) via a
# substring/pattern match — an exact SENSITIVE_FIELDS match missed those — and
# must never retain the raw query string (which can carry tokens in legacy
# transitional flows).
#
# Pure (no database) — runs on host.

library(rlang)
source_api_file("core/logging_sanitizer.R", local = FALSE)

test_that("compound sensitive field names are redacted (substring match)", {
  out <- sanitize_object(list(
    access_token = "a", refresh_token = "b", password_hash = "c",
    api_key = "d", authorization = "e", jwt_secret = "f", normal_field = "keep"
  ))
  for (k in c("access_token", "refresh_token", "password_hash",
              "api_key", "authorization", "jwt_secret")) {
    expect_equal(out[[k]], "[REDACTED]", info = paste("not redacted:", k))
  }
  expect_equal(out$normal_field, "keep")
})

test_that("sanitize_request redacts the query string but keeps empty as NA", {
  redacted <- sanitize_request(list(QUERY_STRING = "token=abc&user=x"))
  expect_equal(redacted$QUERY_STRING, "[REDACTED]")
  expect_true(is.na(sanitize_request(list(QUERY_STRING = ""))$QUERY_STRING))
  expect_true(is.na(sanitize_request(list())$QUERY_STRING))
})
