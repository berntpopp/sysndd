# tests/testthat/test-unit-password-reset-request.R
#
# Regression guard for the password-reset REQUEST flow (#-reset-smtp-500).
#
# Root cause this locks: the `POST /api/user/password/reset/request` handler
# used to call send_noreply_email() WITHOUT a tryCatch, so a production SMTP
# outage (Strato) propagated as an opaque HTTP 500 to the user ("Fehlermeldung"
# reported by a locked-out curator). Signup (#470) and admin approval already
# guard their sends; this flow was the one that never was.
#
# The endpoint delegates to process_password_reset_request() (a pure, injectable
# helper) so we can assert the contract without a live SMTP relay or DB:
#   - invalid email syntax            -> 400
#   - unknown (but valid) email       -> 200 generic, NO send attempted
#   - known email + SMTP FAILURE      -> 200 generic, error swallowed (NOT 500)
#   - known email + SMTP success      -> 200, send invoked once with reset subject
# All non-syntactic outcomes share ONE generic response so the endpoint can be
# neither crashed nor used to enumerate accounts.

library(testthat)
library(tibble)
library(dplyr)
suppressWarnings(suppressMessages({
  library(jose)
  library(openssl) # provides bare md5() used by the token hash
}))

# --- Source the units under test -------------------------------------------
source_if <- function(rel) {
  for (p in c(rel, file.path("..", "..", rel), file.path("api", rel))) {
    if (file.exists(p)) {
      source(p, local = FALSE)
      return(invisible(TRUE))
    }
  }
  stop(sprintf("could not locate %s from %s", rel, getwd()))
}
source_if("functions/user-endpoint-helpers.R")
source_if("functions/account-helpers.R") # is_valid_email()
source_if("functions/email-templates.R") # email_password_reset()

# --- Fixtures ---------------------------------------------------------------
fake_dw <- list(
  secret = "unit-test-secret-value-0123456789",
  salt = "unit-test-salt",
  refresh = 3600,
  base_url = "https://example.test"
)

fake_users <- tibble::tibble(
  user_id = c(101L, 7L),
  user_name = c("NBraemswig", "someone"),
  email = c("Nuria.Braemswig@ukmuenster.de", "someone@example.test"),
  password = c("SysnDD0pw!", "plaintextpw")
)

noop_update <- function(user_id, ts) invisible(NULL)

test_that("invalid email syntax returns 400 without attempting a send", {
  sent <- 0L
  res <- process_password_reset_request(
    "not-an-email", fake_users, fake_dw,
    send_email = function(...) sent <<- sent + 1L,
    update_reset_date = noop_update
  )
  expect_equal(res$status, 400L)
  expect_equal(sent, 0L)
})

test_that("unknown (valid) email returns the generic 200 and never sends", {
  sent <- 0L
  res <- process_password_reset_request(
    "nobody@example.test", fake_users, fake_dw,
    send_email = function(...) sent <<- sent + 1L,
    update_reset_date = noop_update
  )
  expect_equal(res$status, 200L)
  expect_equal(sent, 0L)
  expect_true(is.character(res$body$message))
})

test_that("known email whose SMTP send FAILS still returns 200 (no 500) and swallows the error", {
  # This is THE regression: an unguarded send here used to 500 the endpoint.
  res <- expect_no_error(
    process_password_reset_request(
      "nuria.braemswig@ukmuenster.de", fake_users, fake_dw, # different case on purpose
      send_email = function(...) stop("Couldn't connect to server (SMTP down)"),
      update_reset_date = noop_update
    )
  )
  expect_equal(res$status, 200L)
  expect_true(is.character(res$body$message))
})

test_that("known email + working SMTP invokes the mailer once with the reset subject", {
  calls <- list()
  res <- process_password_reset_request(
    "nuria.braemswig@ukmuenster.de", fake_users, fake_dw,
    send_email = function(email_body, email_subject, email_recipient, ...) {
      calls[[length(calls) + 1L]] <<- list(subject = email_subject, to = email_recipient)
      "sent"
    },
    update_reset_date = noop_update
  )
  expect_equal(res$status, 200L)
  expect_length(calls, 1L)
  expect_equal(calls[[1]]$subject, "Reset Your SysNDD Password")
  # Case-insensitive match resolves to the stored (mixed-case) address.
  expect_equal(calls[[1]]$to, "Nuria.Braemswig@ukmuenster.de")
})

test_that("the found + unknown + send-failed responses are byte-identical (anti-enumeration)", {
  unknown <- process_password_reset_request(
    "nobody@example.test", fake_users, fake_dw,
    send_email = function(...) "sent", update_reset_date = noop_update
  )
  found_ok <- process_password_reset_request(
    "nuria.braemswig@ukmuenster.de", fake_users, fake_dw,
    send_email = function(...) "sent", update_reset_date = noop_update
  )
  found_fail <- process_password_reset_request(
    "nuria.braemswig@ukmuenster.de", fake_users, fake_dw,
    send_email = function(...) stop("SMTP down"), update_reset_date = noop_update
  )
  expect_identical(unknown, found_ok)
  expect_identical(unknown, found_fail)
})
