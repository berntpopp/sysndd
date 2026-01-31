# tests/testthat/helper-paths.R
# Robust path resolution for tests
#
# This helper provides portable path resolution that works across:
# - Interactive R sessions in api/ directory
# - testthat::test_dir() from api/ directory
# - Running tests from tests/testthat/ directory
# - Docker container execution (/app)

#' Get the API directory path
#'
#' Works in multiple contexts:
#' - Interactive R session in api/ directory
#' - testthat::test_dir() from api/ directory
#' - Running tests from tests/testthat/ directory
#' - Docker container execution
#'
#' @return Absolute path to api directory
get_api_dir <- function() {
  # Check multiple possible locations
  candidates <- c(
    getwd(),                              # Current directory IS api/
    file.path(getwd(), ".."),             # Parent is api/ (from tests/)
    file.path(getwd(), "..", ".."),       # Grandparent is api/ (from tests/testthat/)
    "/app"                                # Docker container path

  )

  for (dir in candidates) {
    # Check for a known file that exists in api/
    if (file.exists(file.path(dir, "functions", "db-helpers.R")) ||
        file.exists(file.path(dir, "functions", "helper-functions.R")) ||
        file.exists(file.path(dir, "start_sysndd_api.R"))) {
      return(normalizePath(dir))
    }
  }

  stop(
    "Cannot find api directory. Tried:\n",
    paste("  -", candidates, collapse = "\n"),
    "\n\nEnsure tests are run from api/ directory or Docker container."
  )
}

#' Source an API file with robust path resolution
#'
#' @param relative_path Path relative to api/ directory (e.g., "functions/db-helpers.R")
#' @param local Whether to source into local environment (default: TRUE)
#' @param envir Environment to source into when local = FALSE
#'
#' @return Invisibly returns the path that was sourced
source_api_file <- function(relative_path, local = TRUE, envir = parent.frame()) {

  api_dir <- get_api_dir()
  full_path <- file.path(api_dir, relative_path)

  if (!file.exists(full_path)) {
    stop("File not found: ", full_path, "\n",
         "API directory: ", api_dir)
  }

  if (local) {
    source(full_path, local = TRUE)
  } else {
    source(full_path, local = envir)
  }

  invisible(full_path)
}

#' Check if running inside Docker container
#'
#' @return TRUE if running in Docker, FALSE otherwise
is_docker <- function() {
  file.exists("/.dockerenv") || file.exists("/app/start_sysndd_api.R")
}

#' Skip test if not in Docker (for integration tests requiring database)
#'
#' @param message Optional custom skip message
skip_if_not_docker <- function(message = "Test requires Docker environment") {

  if (!is_docker()) {
    testthat::skip(message)
  }
}
