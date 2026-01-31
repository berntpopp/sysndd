# tests/testthat/helper-db-mock.R
# Database mocking utilities using dittodb
#
# IMPORTANT: All database connections MUST be created INSIDE with_mock_db() blocks
# to be properly intercepted by dittodb.

library(dittodb)
library(DBI)
# RMariaDB is loaded when needed in the actual functions

#' Create a mock database connection for testing
#'
#' This function creates a mock MariaDB connection that dittodb can intercept.
#' MUST be called inside a with_mock_db() block.
#'
#' @return A DBI connection object (mocked by dittodb)
mock_db_connection <- function() {
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = "sysndd_test",
    user = "test",
    password = "test",
    host = "localhost",
    port = 3306
  )
}

#' Helper to mock the global 'dw' config object
#'
#' Database functions reference a global 'dw' object for connection params.
#' This creates a minimal mock version for testing.
#'
#' @return A list mimicking the dw config object
mock_dw_config <- function() {
  list(
    dbname = "sysndd_test",
    user = "test",
    password = "test",
    server = "localhost",
    host = "localhost",
    port = 3306,
    api_base_url = "http://localhost:7778"
  )
}

#' Helper to mock the global 'pool' object
#'
#' Many functions use a global 'pool' for database queries.
#' For unit tests, we need to mock this.
#'
#' NOTE: This is tricky with pool package. For functions that use pool %>% tbl(),
#' consider using local_mocked_bindings() instead of dittodb for those specific cases.
#'
#' @param test_env Environment to assign the mock pool to
mock_pool_for_tests <- function(test_env = parent.frame()) {
  # Create a mock pool that returns tibbles instead of actual DB queries
  # This is used when dittodb cannot intercept pool connections
  withr::local_options(
    list(dittodb.mock.pool = TRUE),
    .local_envir = test_env
  )
}

#' Set up fixtures directory for dittodb
#'
#' dittodb looks for fixtures in tests/testthat/ by default.
#' This ensures the fixtures directory structure exists.
setup_db_fixtures <- function() {
  fixtures_dir <- file.path("tests", "testthat", "fixtures", "sysndd_test")
  if (!dir.exists(fixtures_dir)) {
    dir.create(fixtures_dir, recursive = TRUE)
  }
  invisible(fixtures_dir)
}

# Note: To record fixtures from a real database:
# 1. Ensure you have a test database with sample data
# 2. Use start_db_capturing() before running queries
# 3. Queries will be saved to tests/testthat/sysndd_test/
# 4. Use stop_db_capturing() when done
# 5. Fixtures are then available for with_mock_db() blocks
