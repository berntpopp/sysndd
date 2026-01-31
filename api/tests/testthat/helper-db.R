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
  # Use get_test_config to find config.yml robustly
  test_config <- get_test_config()

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
#' Falls back to environment variables in CI when config.yml is unavailable.
#'
#' @param key Configuration key to retrieve
#' @return Configuration value or full config list
get_test_config <- function(key = NULL) {

  # First check if running in CI with environment variables set
  # This is the preferred method in GitHub Actions
  if (Sys.getenv("MYSQL_HOST", "") != "") {
    # Build config from environment variables (CI mode)
    config <- list(
      dbtype = "mysql",
      dbname = Sys.getenv("MYSQL_DATABASE", "sysndd_test"),
      user = Sys.getenv("MYSQL_USER", "test"),
      password = Sys.getenv("MYSQL_PASSWORD", "test"),
      host = Sys.getenv("MYSQL_HOST", "127.0.0.1"),
      port = Sys.getenv("MYSQL_PORT", "3306"),
      # Defaults for other values needed by tests
      secret = Sys.getenv("TEST_SECRET", "test-secret-for-ci"),
      salt = Sys.getenv("TEST_SALT", "test-salt")
    )

    if (is.null(key)) {
      return(config)
    }
    return(config[[key]])
  }

  # Try multiple paths to find config.yml
  # testthat changes working directory during tests, so we need robust path handling
  possible_paths <- c(
    "config.yml",                          # Current directory
    "../config.yml",                       # Parent directory
    "../../config.yml",                    # Two levels up (from tests/testthat/)
    file.path(getwd(), "config.yml"),     # Explicit current dir
    file.path(dirname(getwd()), "config.yml"),  # Explicit parent
    # Use test_path to get path relative to tests/testthat/
    if (exists("test_path", mode = "function")) {
      tryCatch(test_path("..", "..", "config.yml"), error = function(e) NULL)
    } else NULL
  )

  # Filter out NULL values
  possible_paths <- possible_paths[!vapply(possible_paths, is.null, logical(1))]

  config_path <- NULL
  for (path in possible_paths) {
    if (!is.null(path) && file.exists(path)) {
      config_path <- path
      break
    }
  }

  if (is.null(config_path)) {
    stop("config.yml not found and MYSQL_HOST env not set. ",
         "Tried paths: ", paste(possible_paths, collapse = ", "))
  }

  config <- config::get("sysndd_db_test", file = config_path)

  if (is.null(key)) {
    return(config)
  }

  config[[key]]
}
