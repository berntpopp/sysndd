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
