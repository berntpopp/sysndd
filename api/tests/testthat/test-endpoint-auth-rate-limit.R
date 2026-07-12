# Regression tests for public authentication admission throttling (#550).

extract_post_handler <- function(file_path, decorator_regex, envir) {
  lines <- readLines(file_path, warn = FALSE)
  decorator_line <- grep(decorator_regex, lines)
  if (length(decorator_line) != 1L) {
    stop("Expected exactly one matching Plumber decorator")
  }

  parsed <- parse(file = file_path, keep.source = TRUE)
  refs <- attr(parsed, "srcref")
  handler <- which(vapply(refs, function(ref) ref[[1L]] > decorator_line[[1L]], logical(1)))[[1L]]
  eval(parsed[[handler]], envir = envir)
}

auth_rate_limit_api_dir <- function() {
  staged_api_dir <- Sys.getenv("SYSNDD_API_DIR", "")
  if (nzchar(staged_api_dir)) return(staged_api_dir)
  if (exists("get_api_dir")) return(get_api_dir())
  normalizePath(file.path(getwd(), "..", ".."), mustWork = FALSE)
}

mock_rate_limit_res <- function() {
  res <- new.env(parent = emptyenv())
  res$status <- 200L
  res$body <- NULL
  res$headers <- list()
  res$setHeader <- function(name, value) res$headers[[name]] <- value
  res
}

make_auth_rate_limit_guard <- function(limit = 2L) {
  attempts <- 0L
  function(req, res) {
    attempts <<- attempts + 1L
    if (attempts <= limit) return(list(admitted = TRUE))
    res$status <- 429L
    res$setHeader("Retry-After", "60")
    list(admitted = FALSE, response = list(
      error = "RATE_LIMITED",
      message = "Too many requests. Please retry shortly.",
      retry_after = 60L
    ))
  }
}

make_auth_rate_limit_req <- function(body) {
  list(
    postBody = body,
    HTTP_CONTENT_TYPE = "application/json",
    CONTENT_TYPE = "application/json",
    HTTP_X_FORWARDED_FOR = "203.0.113.8",
    REMOTE_ADDR = "172.18.0.5"
  )
}

auth_rate_limit_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a
  env$`%>%` <- magrittr::`%>%`
  env$account_field_has_control_char <- function(...) FALSE
  env$is_valid_email <- function(...) TRUE
  env$db_execute_statement <- function(...) invisible(NULL)
  env$email_registration_request <- function(...) "email"
  env$send_noreply_email <- function(...) invisible(NULL)
  env$auth_signin <- function(...) list(access_token = "token")
  env$svc_user_password_reset_request <- function(...) list(message = "accepted")
  env$auth_endpoint_admission_guard <- make_auth_rate_limit_guard()
  env
}

signup_payload <- paste0(
  '{"user_name":"validuser","first_name":"Ada","family_name":"Lovelace",',
  '"email":"ada@example.org","orcid":"0000-0000-0000-000X",',
  '"comment":"This comment is long enough.","terms_agreed":"accepted"}'
)

test_that("signup is admitted N times then blocks before insert or email work", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("magrittr")
  env <- auth_rate_limit_sandbox()
  handler <- extract_post_handler(
    file.path(auth_rate_limit_api_dir(), "endpoints", "authentication_endpoints.R"),
    "^#\\*\\s+@post\\s+signup\\s*$", env
  )

  for (i in 1:2) expect_no_error(handler(make_auth_rate_limit_req(signup_payload), mock_rate_limit_res()))
  res <- mock_rate_limit_res()
  denied <- handler(make_auth_rate_limit_req(signup_payload), res)
  expect_equal(res$status, 429L)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(denied$error, "RATE_LIMITED")
  expect_false(grepl("ada@example.org", paste(unlist(denied), collapse = " "), fixed = TRUE))
})

test_that("authenticate is admitted N times then blocks before credential verification", {
  skip_if_not_installed("jsonlite")
  env <- auth_rate_limit_sandbox()
  handler <- extract_post_handler(
    file.path(auth_rate_limit_api_dir(), "endpoints", "authentication_endpoints.R"),
    "^#\\*\\s+@post\\s+authenticate\\s*$", env
  )
  body <- '{"user_name":"validuser","password":"not-a-real-password"}'

  for (i in 1:2) expect_equal(handler(make_auth_rate_limit_req(body), mock_rate_limit_res()), "token")
  res <- mock_rate_limit_res()
  denied <- handler(make_auth_rate_limit_req(body), res)
  expect_equal(res$status, 429L)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(denied$error, "RATE_LIMITED")
  expect_false(grepl("not-a-real-password", paste(unlist(denied), collapse = " "), fixed = TRUE))
})

test_that("reset request is admitted N times then blocks before reset service", {
  env <- auth_rate_limit_sandbox()
  handler <- extract_post_handler(
    file.path(auth_rate_limit_api_dir(), "endpoints", "user_endpoints.R"),
    "^#\\*\\s+@post\\s+password/reset/request\\s*$", env
  )
  body <- '{"email":"ada@example.org"}'

  for (i in 1:2) expect_equal(handler(make_auth_rate_limit_req(body), mock_rate_limit_res())$message, "accepted")
  res <- mock_rate_limit_res()
  denied <- handler(make_auth_rate_limit_req(body), res)
  expect_equal(res$status, 429L)
  expect_equal(res$headers[["Retry-After"]], "60")
  expect_equal(denied$error, "RATE_LIMITED")
  expect_false(grepl("ada@example.org", paste(unlist(denied), collapse = " "), fixed = TRUE))
})

test_that("protected auth route sources remain body-only and do not log raw credentials", {
  auth_lines <- readLines(file.path(auth_rate_limit_api_dir(), "endpoints", "authentication_endpoints.R"))
  user_lines <- readLines(file.path(auth_rate_limit_api_dir(), "endpoints", "user_endpoints.R"))
  auth_source <- paste(auth_lines, collapse = "\n")
  reset_source <- paste(user_lines, collapse = "\n")

  expect_false(grepl("argsQuery", auth_source, fixed = TRUE))
  expect_false(grepl("argsQuery", reset_source, fixed = TRUE))
  expect_true(grepl("req\\$postBody", auth_source))
  expect_true(grepl("svc_user_password_reset_request\\(req, res\\)", reset_source))
})
