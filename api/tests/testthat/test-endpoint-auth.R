library(testthat)

`%||%` <- function(a, b) if (is.null(a)) b else a

extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) != 1L) {
    stop(
      "Expected exactly one decorator match for ",
      decorator_regex,
      ", found ",
      length(dec_line),
      "."
    )
  }
  dec_line <- dec_line[[1L]]

  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for ", file_path)
  }

  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    start_line <- srcrefs[[i]][1L]
    if (start_line > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }

  eval(handler_expr, envir = envir)
}

make_mock_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res
}

make_mock_req <- function(
  post_body = "",
  content_type = NULL,
  user_id = NULL,
  user_role = NULL,
  authorization = NULL
) {
  req <- list(postBody = post_body)
  if (!is.null(content_type)) {
    req$CONTENT_TYPE <- content_type
    req$HTTP_CONTENT_TYPE <- content_type
  }
  if (!is.null(user_id)) {
    req$user_id <- user_id
  }
  if (!is.null(user_role)) {
    req$user_role <- user_role
  }
  if (!is.null(authorization)) {
    req$HTTP_AUTHORIZATION <- authorization
  }
  req
}

auth_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "authentication_endpoints.R")
}

user_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "user_endpoints.R")
}

make_signup_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- `%||%`
  env$db_execute_statement <- function(...) {
    stop("db_execute_statement should not be called for request validation tests")
  }
  env$email_registration_request <- function(...) {
    stop("email_registration_request should not be called for request validation tests")
  }
  env$send_noreply_email <- function(...) {
    stop("send_noreply_email should not be called for request validation tests")
  }
  env
}

make_password_update_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- `%||%`
  env$`%>%` <- magrittr::`%>%`
  env$pool <- structure(list(), class = "mock_pool")
  env$tbl <- function(.data, ...) {
    structure(
      list(
        data = tibble::tibble(
          user_id = integer(),
          user_name = character(),
          password = character(),
          approved = integer(),
          first_name = character(),
          family_name = character(),
          email = character()
        )
      ),
      class = "mock_tbl"
    )
  }
  env$select <- function(.data, ...) .data
  env$filter <- function(.data, ...) .data
  env$collect <- function(.data, ...) .data$data
  env$verify_password <- function(...) FALSE
  env$hash_password <- function(...) {
    stop("hash_password should not be called for request validation tests")
  }
  env$user_update_password <- function(...) {
    stop("user_update_password should not be called for request validation tests")
  }
  env
}

extract_post_signup <- function(envir) {
  extract_plumber_handler(
    auth_file_path(),
    decorator_regex = "^#\\*\\s+@post\\s+signup\\s*$",
    envir = envir
  )
}

extract_put_password_update <- function(envir) {
  extract_plumber_handler(
    user_file_path(),
    decorator_regex = "^#\\*\\s+@put\\s+password/update\\s*$",
    envir = envir
  )
}

test_that("authentication endpoints expose the hard-cut route surface", {
  src <- readLines(auth_file_path(), warn = FALSE)
  password_src <- readLines(user_file_path(), warn = FALSE)
  signup_idx <- grep("^#\\*\\s+@post\\s+signup\\s*$", src)
  password_idx <- grep("^#\\*\\s+@put\\s+password/update\\s*$", password_src)

  expect_true(any(grepl("^#\\*\\s+@post\\s+signup\\s*$", src)))
  expect_false(any(grepl("^#\\*\\s+@get\\s+signup\\s*$", src)))

  expect_true(any(grepl("^#\\*\\s+@post\\s+authenticate\\s*$", src)))
  expect_false(any(grepl("^#\\*\\s+@get\\s+authenticate\\s*$", src)))

  expect_length(signup_idx, 1L)
  expect_length(password_idx, 1L)
  signup_idx <- signup_idx[[1L]]
  password_idx <- password_idx[[1L]]

  signup_blob <- paste(src[signup_idx:min(length(src), signup_idx + 35L)], collapse = "\n")
  expect_match(signup_blob, "req\\$HTTP_CONTENT_TYPE")
  expect_match(signup_blob, "res\\$status\\s*<-\\s*415")
  expect_match(signup_blob, "res\\$status\\s*<-\\s*400")

  password_blob <- paste(
    password_src[password_idx:min(length(password_src), password_idx + 35L)],
    collapse = "\n"
  )
  expect_match(password_blob, "req\\$HTTP_CONTENT_TYPE")
  expect_match(password_blob, "res\\$status\\s*<-\\s*415")
  expect_match(password_blob, "res\\$status\\s*<-\\s*400")
})

test_that("signup handler only accepts JSON request bodies", {
  skip_if_not_installed("jsonlite")

  handler <- extract_post_signup(make_signup_sandbox())

  non_json_req <- make_mock_req(
    post_body = '{"user_name":"validuser"}',
    content_type = "text/plain"
  )
  non_json_res <- make_mock_res()
  handler(req = non_json_req, res = non_json_res)
  expect_equal(non_json_res$status, 415L)

  malformed_req <- make_mock_req(
    post_body = '{"user_name":',
    content_type = "application/json"
  )
  malformed_res <- make_mock_res()
  handler(req = malformed_req, res = malformed_res)
  expect_equal(malformed_res$status, 400L)

  empty_req <- make_mock_req(
    post_body = "{}",
    content_type = "application/json"
  )
  empty_res <- make_mock_res()
  handler(req = empty_req, res = empty_res)
  expect_equal(empty_res$status, 400L)
})

test_that("signup handler rejects non-scalar required field values", {
  skip_if_not_installed("jsonlite")

  handler <- extract_post_signup(make_signup_sandbox())

  nested_req <- make_mock_req(
    post_body = paste0(
      '{"user_name":{"nested":"value"},"first_name":"Ada","family_name":"Lovelace",',
      '"email":"ada@example.org","orcid":"0000-0000-0000-000X",',
      '"comment":"This comment is long enough.","terms_agreed":"accepted"}'
    ),
    content_type = "application/json"
  )
  nested_res <- make_mock_res()

  expect_no_error(handler(req = nested_req, res = nested_res))
  expect_equal(nested_res$status, 400L)
  expect_match(nested_res$body, "single string value")
})

test_that("password update handler only accepts JSON request bodies", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("magrittr")

  handler <- extract_put_password_update(make_password_update_sandbox())

  non_json_req <- make_mock_req(
    post_body = '{"user_id_pass_change":1,"old_pass":"OldPass1!","new_pass_1":"NewPass1!","new_pass_2":"NewPass1!"}',
    content_type = "text/plain",
    user_id = 1L,
    user_role = "Viewer"
  )
  non_json_res <- make_mock_res()
  handler(req = non_json_req, res = non_json_res)
  expect_equal(non_json_res$status, 415L)

  malformed_req <- make_mock_req(
    post_body = '{"user_id_pass_change":1',
    content_type = "application/json",
    user_id = 1L,
    user_role = "Viewer"
  )
  malformed_res <- make_mock_res()
  handler(req = malformed_req, res = malformed_res)
  expect_equal(malformed_res$status, 400L)

  empty_req <- make_mock_req(
    post_body = "{}",
    content_type = "application/json",
    user_id = 1L,
    user_role = "Viewer"
  )
  empty_res <- make_mock_res()
  handler(req = empty_req, res = empty_res)
  expect_equal(empty_res$status, 400L)
})

test_that("password update handler rejects non-scalar password fields", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("magrittr")

  handler <- extract_put_password_update(make_password_update_sandbox())

  nested_req <- make_mock_req(
    post_body = paste0(
      '{"user_id_pass_change":1,"old_pass":{"nested":"value"},',
      '"new_pass_1":"NewPass1!","new_pass_2":"NewPass1!"}'
    ),
    content_type = "application/json",
    user_id = 1L,
    user_role = "Viewer"
  )
  nested_res <- make_mock_res()

  nested_result <- NULL
  expect_no_error({
    nested_result <- handler(req = nested_req, res = nested_res)
  })
  expect_equal(nested_res$status, 400L)
  expect_match(nested_result$error, "scalar strings")
})

test_that("password update handler rejects non-integerish user ids", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("magrittr")

  handler <- extract_put_password_update(make_password_update_sandbox())

  decimal_req <- make_mock_req(
    post_body = paste0(
      '{"user_id_pass_change":1.5,"old_pass":"OldPass1!",',
      '"new_pass_1":"NewPass1!","new_pass_2":"NewPass1!"}'
    ),
    content_type = "application/json",
    user_id = 1L,
    user_role = "Viewer"
  )
  decimal_res <- make_mock_res()

  decimal_result <- NULL
  expect_no_error({
    decimal_result <- handler(req = decimal_req, res = decimal_res)
  })
  expect_equal(decimal_res$status, 400L)
  expect_match(decimal_result$error, "scalar integer value")
})
