# Focused request-service coverage for password-reset JSON validation (#550).

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
  env$svc_user_password_reset_request(list(
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
