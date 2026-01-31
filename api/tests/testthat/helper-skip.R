# tests/testthat/helper-skip.R
# Utility for skipping slow tests

#' Skip test unless RUN_SLOW_TESTS environment variable is set
#'
#' Use this for tests that take >5 seconds (DB operations, external APIs)
skip_if_not_slow_tests <- function() {
  testthat::skip_if_not(
    Sys.getenv("RUN_SLOW_TESTS") == "true",
    "Slow test - set RUN_SLOW_TESTS=true to run"
  )
}
