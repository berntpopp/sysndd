# helper-mock-apis.R
# httptest2 configuration and convenience functions for external API mocking
#
# Usage:
#   with_pubmed_mock({ ... })   - Run code with PubMed API mocked
#   with_pubtator_mock({ ... }) - Run code with PubTator API mocked
#
# First run with fixtures missing: Records live API responses
# Subsequent runs: Replays recorded responses (no network calls)

library(httptest2)

# Configure redactor to remove any sensitive data from fixtures
# PubMed and PubTator don't require API keys, but this is good practice
httptest2::set_redactor(function(resp) {
  # Redact any email addresses that might appear in responses
  resp <- httptest2::gsub_response(
    resp,
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    "REDACTED@example.com"
  )
  # Redact any api_key parameters if they appear
  resp <- httptest2::gsub_response(
    resp,
    "api_key=[^&]+",
    "api_key=REDACTED"
  )
  resp
})

#' Run tests with PubMed API mocked
#'
#' Uses fixtures from tests/testthat/fixtures/pubmed/
#' First run records responses, subsequent runs replay them
#'
#' @param code Test code to run
#' @export
with_pubmed_mock <- function(code) {
  httptest2::with_mock_dir(
    testthat::test_path("fixtures", "pubmed"),
    code
  )
}

#' Run tests with PubTator API mocked
#'
#' Uses fixtures from tests/testthat/fixtures/pubtator/
#' First run records responses, subsequent runs replay them
#'
#' @param code Test code to run
#' @export
with_pubtator_mock <- function(code) {
  httptest2::with_mock_dir(
    testthat::test_path("fixtures", "pubtator"),
    code
  )
}

#' Skip test if network is unavailable and fixtures don't exist
#'
#' Use this for tests that need to record fixtures initially
#'
#' @param fixture_path Path to fixture directory
#' @export
skip_if_no_fixtures_or_network <- function(fixture_path) {
  # Check for fixture files (excluding .gitkeep)
  fixture_files <- list.files(fixture_path, pattern = "\\.(json|R)$")
  fixtures_exist <- length(fixture_files) > 0

  if (!fixtures_exist) {
    # Try a quick network check
    network_ok <- tryCatch({
      con <- url("https://www.ncbi.nlm.nih.gov", "rb")
      close(con)
      TRUE
    }, error = function(e) FALSE)

    if (!network_ok) {
      testthat::skip("No fixtures and no network access - cannot record or mock")
    }
  }
}

## -----------------------------------------------------------------------
## Mock helpers for external proxy endpoint testing
## -----------------------------------------------------------------------

#' Mock for a successful gnomAD constraint response
#'
#' Simulates a successful gnomAD API response with constraint metrics
#'
#' @param symbol Gene symbol
#' @return List with gnomAD constraint data
#' @export
mock_gnomad_constraints_success <- function(symbol) {
  list(
    source = "gnomad",
    gene_symbol = symbol,
    gene_id = "ENSG00000012048",
    constraints = list(
      pLI = 0.0,
      oe_lof = 0.48,
      oe_lof_upper = 0.61,
      mis_z = 2.55,
      exp_lof = 52.1,
      obs_lof = 25
    )
  )
}

#' Mock for a "not found" response
#'
#' Simulates an API response when gene is not found in the source
#'
#' @param source_name Name of the API source
#' @return List with found = FALSE
#' @export
mock_source_not_found <- function(source_name) {
  list(found = FALSE, source = source_name)
}

#' Mock for an error response
#'
#' Simulates an API error response
#'
#' @param source_name Name of the API source
#' @return List with error = TRUE
#' @export
mock_source_error <- function(source_name) {
  list(error = TRUE, source = source_name, message = paste(source_name, "unavailable"))
}
