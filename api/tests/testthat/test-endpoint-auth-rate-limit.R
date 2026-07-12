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

test_that("mounted auth routes suppress credential logging and pre-handler parsing", {
  skip_if_not_installed("plumber")

  source(file.path(
    auth_rate_limit_api_dir(), "functions", "per-caller-throttle.R"
  ), local = FALSE)
  source(file.path(
    auth_rate_limit_api_dir(), "functions", "auth-endpoint-throttle.R"
  ), local = FALSE)
  source(file.path(
    auth_rate_limit_api_dir(), "core", "logging_sanitizer.R"
  ), local = FALSE)
  source(file.path(
    auth_rate_limit_api_dir(), "core", "filters.R"
  ), local = FALSE)

  old_guard <- get0("auth_endpoint_admission_guard", envir = .GlobalEnv,
                    inherits = FALSE)
  had_guard <- exists("auth_endpoint_admission_guard", envir = .GlobalEnv,
                      inherits = FALSE)
  on.exit({
    if (had_guard) {
      assign("auth_endpoint_admission_guard", old_guard, envir = .GlobalEnv)
    } else if (exists("auth_endpoint_admission_guard", envir = .GlobalEnv,
                      inherits = FALSE)) {
      rm("auth_endpoint_admission_guard", envir = .GlobalEnv)
    }
  }, add = TRUE)

  auth_router <- plumber::plumb(file.path(
    auth_rate_limit_api_dir(), "endpoints", "authentication_endpoints.R"
  ))
  user_router <- plumber::plumb(file.path(
    auth_rate_limit_api_dir(), "endpoints", "user_endpoints.R"
  ))

  expect_s3_class(auth_router$routes$signup$parsers, "plumber_parsed_parsers")
  expect_s3_class(auth_router$routes$authenticate$parsers, "plumber_parsed_parsers")
  expect_s3_class(
    user_router$routes$password$reset$request$parsers,
    "plumber_parsed_parsers"
  )

  logged_post_body <- NULL
  root_router <- plumber::pr()
  root_router <- plumber::pr_mount(root_router, "/api/auth", auth_router)
  root_router <- plumber::pr_hook(root_router, "postroute", function(req, res) {
    logged_post_body <<- sanitize_post_body_for_log(req)
  })

  admitted_body_reads <- 0L
  admitted_req <- new.env(parent = emptyenv())
  admitted_req$REQUEST_METHOD <- "POST"
  admitted_req$PATH_INFO <- "/api/auth/authenticate"
  admitted_req$HTTP_CONTENT_TYPE <- "application/json"
  admitted_req$QUERY_STRING <- ""
  admitted_input <- new.env(parent = emptyenv())
  admitted_input$read <- function() charToRaw('["validuser","real-password"]')
  admitted_input$rewind <- function() invisible(NULL)
  admitted_input$read_lines <- function() {
    admitted_body_reads <<- admitted_body_reads + 1L
    '["validuser","real-password"]'
  }
  admitted_req$rook.input <- admitted_input

  admitted_response <- root_router$call(admitted_req)
  expect_equal(admitted_response$status, 400L)
  expect_equal(admitted_body_reads, 1L)
  expect_equal(logged_post_body, "[AUTH_REQUEST_BODY]")
  expect_false(grepl("real-password", logged_post_body, fixed = TRUE))

  sanitized_admitted <- sanitize_request(admitted_req)
  expect_equal(sanitized_admitted$body, "[AUTH_REQUEST_BODY]")
  expect_null(sanitized_admitted$argsBody)
  expect_false(grepl(
    "real-password", paste(unlist(sanitized_admitted), collapse = " "),
    fixed = TRUE
  ))

  auth_endpoint_rate_limit_reset()
  on.exit(auth_endpoint_rate_limit_reset(), add = TRUE)
  for (i in seq_len(AUTH_ENDPOINT_PER_CALLER_MAX)) {
    expect_true(auth_endpoint_rate_limit("unknown")$allowed)
  }

  post_body_reads <- 0L
  req <- new.env(parent = emptyenv())
  req$REQUEST_METHOD <- "POST"
  req$PATH_INFO <- "/api/auth/authenticate"
  req$HTTP_CONTENT_TYPE <- "application/json"
  req$QUERY_STRING <- ""
  rook_input <- new.env(parent = emptyenv())
  rook_input$read <- function() charToRaw("{")
  rook_input$rewind <- function() invisible(NULL)
  rook_input$read_lines <- function() {
    post_body_reads <<- post_body_reads + 1L
    "{"
  }
  req$rook.input <- rook_input

  response <- root_router$call(req)
  expect_equal(response$status, 429L)
  expect_equal(response$headers[["Retry-After"]], "60")
  expect_match(paste(unlist(response$body), collapse = " "), "RATE_LIMITED", fixed = TRUE)
  expect_equal(post_body_reads, 0L)
  expect_equal(logged_post_body, "[AUTH_REQUEST_BODY]")
})

test_that("mounted auth exceptions never send credentials to error logging", {
  skip_if_not_installed("plumber")

  source(file.path(auth_rate_limit_api_dir(), "functions", "per-caller-throttle.R"),
         local = FALSE)
  source(file.path(auth_rate_limit_api_dir(), "functions", "auth-endpoint-throttle.R"),
         local = FALSE)
  source(file.path(auth_rate_limit_api_dir(), "core", "logging_sanitizer.R"),
         local = FALSE)
  source(file.path(auth_rate_limit_api_dir(), "core", "filters.R"),
         local = FALSE)

  old_log_error <- get0("log_error", envir = .GlobalEnv, inherits = FALSE)
  had_log_error <- exists("log_error", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    if (had_log_error) assign("log_error", old_log_error, envir = .GlobalEnv) else
      rm("log_error", envir = .GlobalEnv)
    auth_endpoint_rate_limit_reset()
  }, add = TRUE)

  captured_error_log <- NULL
  assign("log_error", function(...) captured_error_log <<- list(...), envir = .GlobalEnv)
  auth_endpoint_rate_limit_reset()

  child <- plumber::pr()
  child <- plumber::pr_post(
    child,
    "/explode",
    function(req, res) {
      admission <- auth_endpoint_admission_guard(req, res)
      if (!admission$admitted) return(admission$response)
      stop("database unavailable")
    },
    parsers = "auth_body_raw"
  )
  child <- plumber::pr_set_error(child, errorHandler)
  root <- plumber::pr_mount(plumber::pr(), "/api/auth", child)

  req <- new.env(parent = emptyenv())
  req$REQUEST_METHOD <- "POST"
  req$PATH_INFO <- "/api/auth/explode"
  req$HTTP_CONTENT_TYPE <- "application/json"
  req$QUERY_STRING <- ""
  rook_input <- new.env(parent = emptyenv())
  rook_input$read <- function() {
    charToRaw('{"user_name":"validuser","password":"exception-secret"}')
  }
  rook_input$rewind <- function() invisible(NULL)
  rook_input$read_lines <- function() {
    '{"user_name":"validuser","password":"exception-secret"}'
  }
  req$rook.input <- rook_input

  response <- root$call(req)
  expect_equal(response$status, 500L)
  expect_equal(captured_error_log$request$body, "[AUTH_REQUEST_BODY]")
  expect_null(captured_error_log$request$argsBody)
  expect_false(grepl(
    "exception-secret", paste(unlist(captured_error_log), collapse = " "),
    fixed = TRUE
  ))
})
