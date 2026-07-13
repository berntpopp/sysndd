library(testthat)

source_api_file(
  "functions/mcp-readonly-provisioner.R", local = FALSE, envir = .GlobalEnv
)
source_api_file(
  "functions/mcp-readonly-provisioner-quarantine.R", local = FALSE,
  envir = .GlobalEnv
)

recovery_path <- file.path(
  get_api_dir(), "functions", "mcp-readonly-provisioner-recovery.R"
)
if (file.exists(recovery_path)) source(recovery_path, local = .GlobalEnv)

test_that("incomplete recovery removes the secret and uses a fresh admin session", {
  expect_true(file.exists(recovery_path))
  expect_true(exists("mcp_readonly_recover_incomplete", mode = "function"))
  if (!exists("mcp_readonly_recover_incomplete", mode = "function")) return()

  parent <- tempfile("mcp-recovery-")
  dir.create(parent, mode = "0700")
  withr::defer(unlink(parent, recursive = TRUE))
  secret <- file.path(parent, "reader-password")
  writeChar("installed-generated-secret", secret, eos = NULL, useBytes = TRUE)
  expect_true(mcp_readonly_remove_secret(secret))
  expect_false(file.exists(secret))
  writeChar("installed-generated-secret", secret, eos = NULL, useBytes = TRUE)

  primary <- structure(list(id = "primary"), class = "mcp_test_conn")
  recovery <- structure(list(id = "recovery"), class = "mcp_test_conn")
  state <- new.env(parent = emptyenv())
  state$executed <- character()
  state$disconnected <- FALSE
  state$removed <- FALSE

  query_fn <- function(conn, sql, params) {
    if (identical(conn$id, "primary")) stop("connection lost")
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("PROCESSLIST", sql, fixed = TRUE)) {
      return(data.frame(ID = integer()))
    }
    if (grepl("role_edges", sql, fixed = TRUE)) return(data.frame())
    if (grepl("proxies_priv", sql, fixed = TRUE)) return(data.frame())
    stop("unexpected recovery query")
  }
  execute_fn <- function(conn, sql, params) {
    if (identical(conn$id, "primary")) stop("connection lost")
    state$executed <- c(state$executed, sql)
    1L
  }
  quote_account_fn <- function(conn, user, host) {
    paste0("'", user, "'@'", host, "'")
  }

  result <- mcp_readonly_recover_incomplete(
    conn = primary,
    password_output_path = secret,
    query_fn = query_fn,
    execute_fn = execute_fn,
    quote_account_fn = quote_account_fn,
    recovery_conn_factory = function() recovery,
    disconnect_fn = function(conn) {
      state$disconnected <- identical(conn$id, "recovery")
    },
    remove_secret_fn = function(path) {
      state$removed <- TRUE
      mcp_readonly_remove_secret(path)
    }
  )

  expect_true(result)
  expect_false(file.exists(secret))
  expect_true(state$removed)
  expect_true(state$disconnected)
  expect_true(any(grepl(
    "ALTER USER 'sysndd_mcp'@'%' ACCOUNT LOCK", state$executed, fixed = TRUE
  )))
  expect_true(any(grepl("REVOKE ALL PRIVILEGES", state$executed, fixed = TRUE)))
})

test_that("reconcile wires independent recovery before final unlock", {
  reconcile_formals <- names(formals(mcp_readonly_reconcile))
  reconcile_body <- paste(deparse(body(mcp_readonly_reconcile)), collapse = "\n")

  expect_true("recovery_conn_factory" %in% reconcile_formals)
  expect_true("remove_secret_fn" %in% reconcile_formals)
  expect_match(reconcile_body, "mcp_readonly_recover_incomplete", fixed = TRUE)
  expect_lt(
    regexpr("mcp_readonly_recover_incomplete", reconcile_body, fixed = TRUE)[[1L]],
    regexpr("ACCOUNT UNLOCK", reconcile_body, fixed = TRUE)[[1L]]
  )
})

test_that("independent recovery continues after a malformed catalog row", {
  primary <- structure(list(id = "primary"), class = "mcp_test_conn")
  recovery <- structure(list(id = "recovery"), class = "mcp_test_conn")
  executed <- character()

  query_fn <- function(conn, sql, params) {
    if (identical(conn$id, "primary")) stop("connection lost")
    if (grepl("FROM mysql.user", sql, fixed = TRUE)) {
      return(data.frame(User = "sysndd_mcp", Host = "%"))
    }
    if (grepl("role_edges", sql, fixed = TRUE)) {
      return(data.frame(
        FROM_USER = I(list(7, "surviving'role")),
        FROM_HOST = I(list("%", "%")),
        TO_USER = I(list("sysndd_mcp", "sysndd_mcp")),
        TO_HOST = I(list("%", "%"))
      ))
    }
    if (grepl("proxies_priv", sql, fixed = TRUE)) return(data.frame())
    if (grepl("PROCESSLIST", sql, fixed = TRUE)) {
      return(data.frame(ID = integer()))
    }
    stop("unexpected recovery query")
  }
  execute_fn <- function(conn, sql, params) {
    if (identical(conn$id, "primary")) stop("connection lost")
    executed <<- c(executed, sql)
    1L
  }
  quote_account_fn <- function(conn, user, host) {
    mcp_readonly_quote_account(DBI::ANSI(), user, host)
  }

  expect_warning(
    result <- mcp_readonly_recover_incomplete(
      conn = primary,
      password_output_path = "/absent/reader-password",
      query_fn = query_fn,
      execute_fn = execute_fn,
      quote_account_fn = quote_account_fn,
      recovery_conn_factory = function() recovery,
      disconnect_fn = function(conn) invisible(TRUE),
      remove_secret_fn = function(path) invisible(TRUE)
    ),
    "quarantine failed"
  )

  expect_false(result)
  expect_true(any(executed == paste(
    "REVOKE 'surviving''role'@'%' FROM 'sysndd_mcp'@'%'"
  )))
  expect_true(any(executed == paste(
    "REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'sysndd_mcp'@'%'"
  )))
})
