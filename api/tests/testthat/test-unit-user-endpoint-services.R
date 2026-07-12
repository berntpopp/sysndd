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
