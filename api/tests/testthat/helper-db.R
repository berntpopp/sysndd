# tests/testthat/helper-db.R
# Database connection helpers for tests
#
# These functions provide isolated test database access with proper cleanup.
# Uses config::get() to load sysndd_db_test configuration.

#' Get test database connection
#'
#' Creates a DBI connection to the test database.
#' Caller is responsible for disconnecting.
#'
#' @return DBI connection to test database
#' @examples
#' con <- get_test_db_connection()
#' # ... use connection ...
#' DBI::dbDisconnect(con)
get_test_db_connection <- function() {
  # Load test config from api/config.yml
  config_path <- if (file.exists("config.yml")) {
    "config.yml"
  } else if (file.exists("../config.yml")) {
    "../config.yml"
  } else {
    stop("config.yml not found. Run tests from api/ directory.")
  }

  test_config <- config::get("sysndd_db_test", file = config_path)

  if (is.null(test_config)) {
    stop("sysndd_db_test configuration not found in config.yml")
  }

  DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = as.integer(test_config$port)
  )
}


#' Check if test database is available
#'
#' Attempts to connect to test database and returns TRUE/FALSE.
#' Used internally by skip_if_no_test_db().
#'
#' @return Logical indicating if test DB is available
test_db_available <- function() {
  tryCatch({
    con <- get_test_db_connection()
    DBI::dbDisconnect(con)
    TRUE
  }, error = function(e) {
    FALSE
  })
}


#' Skip test if test database unavailable
#'
#' Call at the start of integration tests that require database.
#' Provides informative skip message.
#'
#' @examples
#' test_that("database query works", {
#'   skip_if_no_test_db()
#'   # ... test code ...
#' })
skip_if_no_test_db <- function() {
  if (!test_db_available()) {
    testthat::skip("Test database (sysndd_db_test) not available")
  }
}


#' Run code with test database transaction (auto-rollback)
#'
#' Wraps code in a transaction that is always rolled back,
#' ensuring tests don't leave data in the database.
#'
#' @param code Code block to execute within transaction
#' @return Result of code block
#'
#' @examples
#' test_that("entity creation works", {
#'   with_test_db_transaction({
#'     con <- getOption(".test_db_con")
#'     # ... insert data ...
#'     # Transaction will be rolled back after test
#'   })
#' })
with_test_db_transaction <- function(code) {
  skip_if_no_test_db()

  con <- get_test_db_connection()
  withr::defer(DBI::dbDisconnect(con))

  DBI::dbBegin(con)
  withr::defer(DBI::dbRollback(con))

  # Make connection available to code block
  withr::local_options(list(.test_db_con = con))

  force(code)
}


#' Get test configuration value
#'
#' Helper to access test config values (secret, etc.)
#'
#' @param key Configuration key to retrieve
#' @return Configuration value
get_test_config <- function(key = NULL) {
  config_path <- if (file.exists("config.yml")) {
    "config.yml"
  } else if (file.exists("../config.yml")) {
    "../config.yml"
  } else {
    stop("config.yml not found")
  }

  config <- config::get("sysndd_db_test", file = config_path)

  if (is.null(key)) {
    return(config)
  }

  config[[key]]
}
