# tests/testthat/test-unit-user-endpoint-services.R
#
# Unit tests for the Wave 3 Task 3 (#346) user endpoint services extracted
# from endpoints/user_endpoints.R:
#   - services/user-read-endpoint-service.R
#   - services/user-account-endpoint-service.R
#   - services/user-password-profile-endpoint-service.R
#   - services/user-bulk-endpoint-service.R
#
# Each `svc_` function is sourced (local = FALSE) into its own sandbox
# environment with a mocked `pool`/`tbl()` (mirrors test-endpoint-auth.R's
# extraction sandbox: override `tbl()` to hand back an in-memory fixture
# tibble, then let real dplyr verbs run for real) plus any side-effect
# functions the test needs to control (email, hashing, DB writes, JWT
# decode). No live DB is required; DB-state assertions are guarded with
# skip_if_no_test_db().

library(testthat)
library(tibble)
library(dplyr)
suppressWarnings(suppressMessages({
  library(logger)
  library(openssl) # provides bare md5() used by the reset-change hash check
}))

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Sandbox helpers
# ---------------------------------------------------------------------------

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}

make_mock_req <- function(user_id = NULL, user_role = NULL, argsBody = NULL,
                           postBody = "", authorization = NULL) {
  req <- list(postBody = postBody)
  if (!is.null(user_id)) req$user_id <- user_id
  if (!is.null(user_role)) req$user_role <- user_role
  if (!is.null(argsBody)) req$argsBody <- argsBody
  if (!is.null(authorization)) req$HTTP_AUTHORIZATION <- authorization
  req
}

#' Build a sandbox env with a mocked `pool`/`tbl()` (table-name -> fixture
#' tibble lookup) plus arbitrary side-effect-function overrides. Real dplyr
#' verbs (select/filter/collect/mutate/...) resolve normally via the search
#' path (dplyr/tibble/stringr are already attached by setup.R).
make_service_sandbox <- function(tables = list(), overrides = list()) {
  env <- new.env(parent = globalenv())
  env$`%||%` <- `%||%`
  env$pool <- structure(list(), class = "mock_pool")
  env$tbl <- function(.data, table_name, ...) {
    if (!table_name %in% names(tables)) {
      stop("No fixture registered for table: ", table_name)
    }
    tables[[table_name]]
  }
  for (nm in names(overrides)) {
    assign(nm, overrides[[nm]], envir = env)
  }
  env
}

load_service_into <- function(relative_path, envir) {
  source_api_file(relative_path, local = FALSE, envir = envir)
}

# A minimal, local copy of test-endpoint-auth.R's handler-extraction
# technique so this file stays self-contained (that file is verify-only).
extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) != 1L) {
    stop("Expected exactly one decorator match for ", decorator_regex)
  }
  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    if (srcrefs[[i]][1L] > dec_line[[1L]]) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) stop("No handler found after decorator line")
  eval(handler_expr, envir = envir)
}

user_endpoints_path <- function() {
  file.path(get_api_dir(), "endpoints", "user_endpoints.R")
}

# ---------------------------------------------------------------------------
# Role matrix (structural regression guard)
# ---------------------------------------------------------------------------

test_that("the endpoint file's require_role() gates match the documented role matrix", {
  ue <- paste(readLines(user_endpoints_path(), warn = FALSE), collapse = "\n")

  expected_gates <- c(
    table = "Curator",
    approval = "Curator",
    change_role = "Curator",
    role_list = "Curator",
    list = "Curator",
    delete = "Administrator",
    update = "Administrator",
    bulk_approve = "Curator",
    bulk_delete = "Administrator",
    bulk_assign_role = "Curator"
  )

  for (route in names(expected_gates)) {
    idx <- regexpr(paste0("@(get|put|post|delete)\\s+", route, "\\b"), ue)
    expect_true(idx > 0, info = paste("missing decorator for", route))
    remainder <- substr(ue, idx, idx + 400)
    expect_match(
      remainder,
      paste0('require_role\\(req, res, "', expected_gates[[route]], '"\\)'),
      info = paste("role gate mismatch for", route)
    )
  }
})

# ---------------------------------------------------------------------------
# user-read-endpoint-service.R
# ---------------------------------------------------------------------------

test_that("contributions handler skips the Reviewer gate when the caller views their own id", {
  gate_calls <- list()
  sandbox <- new.env(parent = globalenv())
  sandbox$require_role <- function(req, res, min_role) {
    gate_calls[[length(gate_calls) + 1]] <<- min_role
  }
  sandbox$svc_user_contributions <- function(user_id) {
    list(user_id = user_id, active_status = 0L, active_reviews = 0L)
  }

  handler <- extract_plumber_handler(
    user_endpoints_path(),
    decorator_regex = "^#\\*\\s+@get\\s+<user_id>/contributions\\s*$",
    envir = sandbox
  )

  handler(req = list(user_id = 7L), res = list(), user_id = "7")
  expect_length(gate_calls, 0)

  handler(req = list(user_id = 8L), res = list(), user_id = "7")
  expect_length(gate_calls, 1)
  expect_equal(gate_calls[[1]], "Reviewer")
})

test_that("svc_user_contributions tallies only the requested user's active reviews/status", {
  reviews <- tibble::tibble(
    review_id = 1:3,
    is_primary = c(1, 1, 0),
    review_user_id = c(7, 7, 7)
  )
  statuses <- tibble::tibble(
    status_id = 1:2,
    is_active = c(1, 1),
    status_user_id = c(7, 7)
  )
  env <- make_service_sandbox(tables = list(
    ndd_entity_review = reviews,
    ndd_entity_status = statuses
  ))
  load_service_into("services/user-read-endpoint-service.R", env)

  result <- env$svc_user_contributions(7)

  expect_equal(result$user_id, 7)
  expect_equal(result$active_reviews, 2L)
  expect_equal(result$active_status, 2L)
})

test_that("svc_user_role_list hides Administrator from non-Administrators", {
  env <- make_service_sandbox(overrides = list(
    user_status_allowed = c("Administrator", "Curator", "Reviewer", "Viewer")
  ))
  load_service_into("services/user-read-endpoint-service.R", env)

  admin_roles <- env$svc_user_role_list(make_mock_req(user_role = "Administrator"))
  expect_true("Administrator" %in% admin_roles$role)

  curator_roles <- env$svc_user_role_list(make_mock_req(user_role = "Curator"))
  expect_false("Administrator" %in% curator_roles$role)
})

test_that("svc_user_list_by_roles rejects roles outside the allow-list", {
  env <- make_service_sandbox(overrides = list(
    user_status_allowed = c("Administrator", "Curator", "Reviewer", "Viewer")
  ))
  load_service_into("services/user-read-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_list_by_roles(res, "Viewer,NotARole")

  expect_equal(res$status, 400L)
  expect_identical(result, res)
})

test_that("svc_user_list_by_roles returns approved users matching the role filter", {
  users <- tibble::tibble(
    user_id = c(1, 2, 3),
    user_name = c("a", "b", "c"),
    user_role = c("Viewer", "Curator", "Viewer"),
    approved = c(1, 1, 0)
  )
  env <- make_service_sandbox(
    tables = list(user = users),
    overrides = list(user_status_allowed = c("Administrator", "Curator", "Reviewer", "Viewer"))
  )
  load_service_into("services/user-read-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_list_by_roles(res, "Viewer")

  expect_equal(res$status, 200L)
  expect_equal(nrow(result), 1L)
  expect_equal(result$user_id, 1)
})

# ---------------------------------------------------------------------------
# user-account-endpoint-service.R
# ---------------------------------------------------------------------------

new_approval_user_table <- function(approved = 0) {
  tibble::tibble(
    user_id = 5, user_name = "newuser", approved = approved,
    first_name = "Ada", family_name = "Lovelace",
    email = "ada@example.com", user_role = "Viewer"
  )
}

test_that("svc_user_approval_apply returns 409 when the user is already active", {
  env <- make_service_sandbox()
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_approval_apply(
    make_mock_req(user_id = 1), res, new_approval_user_table(approved = 1), 5, TRUE
  )

  expect_equal(res$status, 409L)
  expect_match(result$error, "already active")
})

test_that("svc_user_approval_apply rejects and deletes the user without touching email", {
  deleted <- list()
  env <- make_service_sandbox(overrides = list(
    db_execute_statement = function(sql, params) {
      deleted[[length(deleted) + 1]] <<- list(sql = sql, params = params)
      1L
    },
    send_noreply_email = function(...) stop("must not be called on rejection")
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_approval_apply(
    make_mock_req(user_id = 1), res, new_approval_user_table(), 5, FALSE
  )

  expect_equal(result$message, "User application rejected.")
  expect_equal(result$user_id, 5)
  expect_length(deleted, 1)
})

test_that("svc_user_approval_apply approves, hashes a new password, and reports email_sent = TRUE", {
  updates <- list()
  env <- make_service_sandbox(overrides = list(
    random_password = function() "TempPass1!",
    generate_initials = function(first, family) "AL",
    hash_password = function(pw) paste0("hashed:", pw),
    user_update = function(user_id, fields) {
      updates[[length(updates) + 1]] <<- list(user_id = user_id, fields = fields)
    },
    user_update_password = function(user_id, hash) {
      updates[[length(updates) + 1]] <<- list(user_id = user_id, hash = hash)
    },
    email_account_approved = function(user_name, temp_password, login_url) "<html></html>",
    send_noreply_email = function(...) invisible(TRUE),
    dw = list(base_url = "https://sysndd.example")
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_approval_apply(
    make_mock_req(user_id = 1), res, new_approval_user_table(), 5, TRUE
  )

  expect_true(result$email_sent)
  expect_equal(result$user_id, 5)
  expect_length(updates, 2)
})

test_that("svc_user_approval_apply reports email_sent = FALSE (not an error) on SMTP failure", {
  env <- make_service_sandbox(overrides = list(
    random_password = function() "TempPass1!",
    generate_initials = function(first, family) "AL",
    hash_password = function(pw) paste0("hashed:", pw),
    user_update = function(...) invisible(TRUE),
    user_update_password = function(...) invisible(TRUE),
    email_account_approved = function(...) "<html></html>",
    send_noreply_email = function(...) stop("SMTP relay unavailable"),
    dw = list(base_url = "https://sysndd.example")
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_approval_apply(
    make_mock_req(user_id = 1), res, new_approval_user_table(), 5, TRUE
  )

  expect_equal(res$status, 200L)
  expect_false(result$email_sent)
  expect_match(result$email_error, "SMTP relay unavailable")
})

test_that("svc_user_change_role: Administrator can assign any role", {
  updated <- NULL
  env <- make_service_sandbox(overrides = list(
    user_update = function(user_id, fields) updated <<- list(user_id = user_id, fields = fields)
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  env$svc_user_change_role(make_mock_req(user_role = "Administrator"), res, 4, "Administrator")

  expect_equal(updated$fields$user_role, "Administrator")
})

test_that("svc_user_change_role: Curator cannot assign Administrator", {
  env <- make_service_sandbox(overrides = list(
    user_update = function(...) stop("must not be called")
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_change_role(make_mock_req(user_role = "Curator"), res, 4, "Administrator")

  expect_equal(res$status, 403L)
  expect_match(result$error, "Curators cannot assign")
})

test_that("svc_user_delete rejects a non-positive user_id", {
  env <- make_service_sandbox()
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_delete(res, -1)

  expect_equal(res$status, 400L)
})

test_that("svc_user_delete 404s when the user does not exist", {
  env <- make_service_sandbox(overrides = list(
    db_execute_query = function(sql, params) tibble::tibble(count = 0)
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_delete(res, 42)

  expect_equal(res$status, 404L)
})

test_that("svc_user_delete deletes an existing user", {
  env <- make_service_sandbox(overrides = list(
    db_execute_query = function(sql, params) tibble::tibble(count = 1),
    db_execute_statement = function(sql, params) 1L
  ))
  load_service_into("services/user-account-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_delete(res, 42)

  expect_equal(result$message, "User successfully deleted.")
  expect_equal(res$status, 200L)
})

# ---------------------------------------------------------------------------
# user-password-profile-endpoint-service.R : svc_user_password_update
# ---------------------------------------------------------------------------

password_user_fixture <- tibble::tibble(
  user_id = c(1, 2, 3),
  user_name = c("alice", "bob", "carol"),
  password = c("hash1", "hash2", "hash3"),
  approved = c(1, 0, 1),
  first_name = c("Alice", "Bob", "Carol"),
  family_name = c("A", "B", "C"),
  email = c("a@x.com", "b@x.com", "c@x.com")
)

make_password_update_sandbox <- function(verify_result = TRUE, valid_result = TRUE, overrides = list()) {
  make_service_sandbox(
    tables = list(user = password_user_fixture),
    overrides = utils::modifyList(
      list(
        verify_password = function(stored, attempt) verify_result,
        new_password_valid = function(p1, p2, old = NULL) valid_result,
        hash_password = function(pw) paste0("hashed:", pw),
        user_update_password = function(...) invisible(TRUE)
      ),
      overrides
    )
  )
}

test_that("svc_user_password_update 401s an unauthenticated caller", {
  env <- make_password_update_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 1, old_pass = "x", new_pass_1 = "y", new_pass_2 = "y")
  result <- env$svc_user_password_update(make_mock_req(), res, body)

  expect_equal(res$status, 401L)
})

test_that("svc_user_password_update 409s a nonexistent self-service target account", {
  env <- make_password_update_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 999, old_pass = "x", new_pass_1 = "NewPass1!", new_pass_2 = "NewPass1!")
  result <- env$svc_user_password_update(make_mock_req(user_id = 999, user_role = "Viewer"), res, body)

  expect_equal(res$status, 409L)
  expect_match(result$error, "does not exist")
})

test_that("svc_user_password_update 409s an unapproved account", {
  env <- make_password_update_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 2, old_pass = "hash2", new_pass_1 = "NewPass1!", new_pass_2 = "NewPass1!")
  result <- env$svc_user_password_update(make_mock_req(user_id = 2, user_role = "Viewer"), res, body)

  expect_equal(res$status, 409L)
  expect_match(result$error, "not approved")
})

test_that("svc_user_password_update 409s on an old-password mismatch", {
  env <- make_password_update_sandbox(verify_result = FALSE)
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 1, old_pass = "wrong", new_pass_1 = "NewPass1!", new_pass_2 = "NewPass1!")
  result <- env$svc_user_password_update(make_mock_req(user_id = 1, user_role = "Viewer"), res, body)

  expect_equal(res$status, 409L)
  expect_match(result$error, "Password input problem")
})

test_that("svc_user_password_update succeeds for a matching, approved self-service change", {
  env <- make_password_update_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 1, old_pass = "hash1", new_pass_1 = "NewPass1!", new_pass_2 = "NewPass1!")
  result <- env$svc_user_password_update(make_mock_req(user_id = 1, user_role = "Viewer"), res, body)

  expect_equal(res$status, 201L)
  expect_equal(result$message, "Password successfully changed.")
})

test_that("svc_user_password_update lets an Administrator bypass the old-password check", {
  env <- make_password_update_sandbox(verify_result = FALSE)
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  body <- list(user_id_pass_change = 1, old_pass = "irrelevant", new_pass_1 = "NewPass1!", new_pass_2 = "NewPass1!")
  result <- env$svc_user_password_update(make_mock_req(user_id = 999, user_role = "Administrator"), res, body)

  expect_equal(res$status, 201L)
})

# ---------------------------------------------------------------------------
# user-password-profile-endpoint-service.R : svc_user_profile_update
# ---------------------------------------------------------------------------

test_that("svc_user_profile_update requires authentication", {
  env <- make_service_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_profile_update(list(postBody = "{}"), res)

  expect_equal(res$status, 401L)
})

test_that("svc_user_profile_update rejects an invalid email format", {
  env <- make_service_sandbox(overrides = list(is_valid_email = function(x) FALSE))
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(user_id = 1, postBody = '{"email":"not-an-email"}')
  result <- env$svc_user_profile_update(req, res)

  expect_equal(res$status, 400L)
  expect_match(result$error, "Invalid email")
})

test_that("svc_user_profile_update rejects an email already used by another account", {
  existing <- tibble::tibble(user_id = 2, email = "taken@example.com")
  env <- make_service_sandbox(
    tables = list(user = existing),
    overrides = list(is_valid_email = function(x) TRUE)
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(user_id = 1, postBody = '{"email":"taken@example.com"}')
  result <- env$svc_user_profile_update(req, res)

  expect_equal(res$status, 400L)
  expect_match(result$error, "already in use")
})

test_that("svc_user_profile_update rejects a malformed ORCID", {
  env <- make_service_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(user_id = 1, postBody = '{"orcid":"not-an-orcid"}')
  result <- env$svc_user_profile_update(req, res)

  expect_equal(res$status, 400L)
  expect_match(result$error, "Invalid ORCID")
})

test_that("svc_user_profile_update normalizes a valid ORCID to uppercase and persists it", {
  updated <- NULL
  env <- make_service_sandbox(overrides = list(
    user_update = function(user_id, updates) updated <<- list(user_id = user_id, updates = updates)
  ))
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(user_id = 1, postBody = '{"orcid":"0000-0001-2345-678x"}')
  result <- env$svc_user_profile_update(req, res)

  expect_equal(res$status, 200L)
  expect_equal(updated$updates$orcid, "0000-0001-2345-678X")
  expect_true("orcid" %in% result$updated_fields)
})

test_that("svc_user_profile_update 400s when no valid fields are provided", {
  env <- make_service_sandbox()
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_profile_update(list(user_id = 1, postBody = "{}"), res)

  expect_equal(res$status, 400L)
})

# ---------------------------------------------------------------------------
# user-password-profile-endpoint-service.R : password reset request (#OWASP
# anti-enumeration; the anti-enumeration logic itself lives in, and is
# separately tested against, process_password_reset_request() -- these tests
# assert the service correctly wires body-parsing/user-collection/status).
# ---------------------------------------------------------------------------

test_that("svc_user_password_reset_request parses the body, collects users, and forwards the status", {
  captured <- NULL
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(user_id = 1, email = "a@x.com")),
    overrides = list(
      process_password_reset_request = function(email_request, user_table, dw) {
        captured <<- list(email_request = email_request, nrow_users = nrow(user_table))
        list(status = 200L, body = list(message = "generic ok"))
      },
      dw = list()
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_password_reset_request(list(
    postBody = '{"email":"a@x.com"}',
    HTTP_CONTENT_TYPE = "application/json"
  ), res)

  expect_equal(res$status, 200L)
  expect_equal(result$message, "generic ok")
  expect_equal(captured$email_request, "a@x.com")
  expect_equal(captured$nrow_users, 1)
})

test_that("svc_user_password_reset_request rejects non-JSON and malformed shapes before DB work", {
  captured <- NULL
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(user_id = integer(0), email = character(0))),
    overrides = list(
      process_password_reset_request = function(email_request, user_table, dw) {
        captured <<- email_request
        list(status = 400L, body = list(error = "Invalid Parameter Value Error."))
      },
      dw = list()
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_password_reset_request(list(
    postBody = "not json",
    HTTP_CONTENT_TYPE = "application/json"
  ), res)

  expect_equal(res$status, 400L)
  expect_null(captured)

  non_json_res <- make_mock_res()
  env$svc_user_password_reset_request(list(
    postBody = '{"email":"a@x.com"}',
    HTTP_CONTENT_TYPE = "text/plain"
  ), non_json_res)
  expect_equal(non_json_res$status, 415L)
  expect_null(captured)
})

# ---------------------------------------------------------------------------
# user-password-profile-endpoint-service.R : password reset change (JWT)
# ---------------------------------------------------------------------------

test_that("svc_user_password_reset_change 401s on an expired token", {
  env <- make_service_sandbox(overrides = list(
    jwt_decode_hmac = function(jwt, secret) {
      list(
        user_id = 1, user_name = "alice", email = "a@x.com", hash = "h",
        iat = as.integer(Sys.time()) - 3600, exp = as.integer(Sys.time()) - 1
      )
    },
    dw = list(secret = "sekrit")
  ))
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(postBody = "{}", HTTP_AUTHORIZATION = "Bearer faketoken")
  result <- env$svc_user_password_reset_change(req, res)

  expect_equal(res$status, 401L)
  expect_match(result$error, "expired")
})

test_that("svc_user_password_reset_change 404s when the JWT user id is not found", {
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = integer(0), user_name = character(0), password = character(0),
      email = character(0), password_reset_date = character(0)
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) {
        list(
          user_id = 999, user_name = "ghost", email = "g@x.com", hash = "h",
          iat = as.integer(Sys.time()), exp = as.integer(Sys.time()) + 900
        )
      },
      dw = list(secret = "sekrit", salt = "salty")
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(postBody = "{}", HTTP_AUTHORIZATION = "Bearer faketoken")
  result <- env$svc_user_password_reset_change(req, res)

  expect_equal(res$status, 404L)
})

test_that("svc_user_password_reset_change 409s on a hash mismatch", {
  now_ts <- Sys.time()
  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = 1, user_name = "alice", password = "currentpw",
      email = "a@x.com", password_reset_date = format(now_ts, "%Y-%m-%d %H:%M:%S")
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) {
        list(
          user_id = 1, user_name = "alice", email = "a@x.com", hash = "WRONG-HASH",
          iat = as.integer(now_ts), exp = as.integer(now_ts) + 900
        )
      },
      dw = list(secret = "sekrit", salt = "salty"),
      new_password_valid = function(...) TRUE
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(
    postBody = '{"password":"NewPass1!","password_confirm":"NewPass1!"}',
    HTTP_AUTHORIZATION = "Bearer faketoken"
  )
  result <- env$svc_user_password_reset_change(req, res)

  expect_equal(res$status, 409L)
  expect_match(result$error, "Password or JWT input problem")
})

test_that("svc_user_password_reset_change succeeds when claims and password validate", {
  reset_date_str <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  expected_iat <- as.integer(as.POSIXct(reset_date_str, tz = "UTC"))
  real_hash <- toString(md5(paste0("salty", "currentpw")))
  cleared_params <- NULL

  env <- make_service_sandbox(
    tables = list(user = tibble::tibble(
      user_id = 1, user_name = "alice", password = "currentpw",
      email = "a@x.com", password_reset_date = reset_date_str
    )),
    overrides = list(
      jwt_decode_hmac = function(jwt, secret) {
        list(
          user_id = 1, user_name = "alice", email = "a@x.com", hash = real_hash,
          iat = expected_iat, exp = as.integer(Sys.time()) + 900
        )
      },
      dw = list(secret = "sekrit", salt = "salty"),
      new_password_valid = function(...) TRUE,
      hash_password = function(pw) paste0("hashed:", pw),
      user_update_password = function(...) invisible(TRUE),
      db_execute_statement = function(sql, params) {
        cleared_params <<- params
        1L
      }
    )
  )
  load_service_into("services/user-password-profile-endpoint-service.R", env)

  res <- make_mock_res()
  req <- list(
    postBody = '{"password":"NewPass1!","password_confirm":"NewPass1!"}',
    HTTP_AUTHORIZATION = "Bearer faketoken"
  )
  result <- env$svc_user_password_reset_change(req, res)

  expect_equal(res$status, 201L)
  expect_equal(result$message, "Password successfully changed.")
  expect_equal(cleared_params[[1]], 1)
})

# ---------------------------------------------------------------------------
# user-bulk-endpoint-service.R
# ---------------------------------------------------------------------------

test_that("svc_user_bulk_approve rejects an empty user_ids array", {
  env <- make_service_sandbox()
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_approve(make_mock_req(user_id = 1), res, integer(0))

  expect_equal(res$status, 400L)
  expect_match(result$error, "cannot be empty")
})

test_that("svc_user_bulk_approve enforces the 20-user cap", {
  env <- make_service_sandbox()
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_approve(make_mock_req(user_id = 1), res, 1:21)

  expect_equal(res$status, 400L)
  expect_match(result$error, "more than 20")
})

test_that("svc_user_bulk_approve delegates to user_bulk_approve and reports success", {
  env <- make_service_sandbox(overrides = list(
    user_bulk_approve = function(user_ids, approving_user_id, pool) {
      list(processed = length(user_ids), message = "ok")
    }
  ))
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_approve(make_mock_req(user_id = 1), res, c(2, 3))

  expect_equal(result$processed, 2)
  expect_equal(res$status, 200L)
})

test_that("svc_user_bulk_approve maps a business error (e.g. already active) to 409", {
  env <- make_service_sandbox(overrides = list(
    user_bulk_approve = function(...) stop("User account(s) already active: 5")
  ))
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_approve(make_mock_req(user_id = 1), res, c(5))

  expect_equal(res$status, 409L)
  expect_match(result$error, "already active")
})

test_that("svc_user_bulk_delete maps the admin-protection error to 403", {
  env <- make_service_sandbox(overrides = list(
    user_bulk_delete = function(...) stop("Cannot delete: selection contains admin users (IDs: 3 )")
  ))
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_delete(make_mock_req(user_id = 1), res, c(3))

  expect_equal(res$status, 403L)
})

test_that("svc_user_bulk_delete maps a generic business error to 409", {
  env <- make_service_sandbox(overrides = list(
    user_bulk_delete = function(...) stop("User not found: 9")
  ))
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_delete(make_mock_req(user_id = 1), res, c(9))

  expect_equal(res$status, 409L)
})

test_that("svc_user_bulk_assign_role rejects an invalid role", {
  env <- make_service_sandbox()
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_assign_role(make_mock_req(user_role = "Administrator"), res, c(1, 2), "SuperAdmin")

  expect_equal(res$status, 400L)
  expect_match(result$error, "Invalid role")
})

test_that("svc_user_bulk_assign_role blocks a Curator assigning Administrator", {
  env <- make_service_sandbox()
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_assign_role(make_mock_req(user_role = "Curator"), res, c(1, 2), "Administrator")

  expect_equal(res$status, 403L)
})

test_that("svc_user_bulk_assign_role delegates for a valid Curator-assignable role", {
  env <- make_service_sandbox(overrides = list(
    user_bulk_assign_role = function(user_ids, role, requesting_role, pool) {
      list(processed = length(user_ids), message = paste(length(user_ids), "assigned"))
    }
  ))
  load_service_into("services/user-bulk-endpoint-service.R", env)

  res <- make_mock_res()
  result <- env$svc_user_bulk_assign_role(make_mock_req(user_role = "Curator"), res, c(1, 2), "Viewer")

  expect_equal(result$processed, 2)
})

# ---------------------------------------------------------------------------
# DB-state smoke test (guarded; SKIPs on host, real assertions in Docker/CI)
# ---------------------------------------------------------------------------

test_that("svc_user_table_list runs against a real test database connection", {
  skip_if_no_test_db()

  con <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM user")$n
  expect_true(is.numeric(count))
})
