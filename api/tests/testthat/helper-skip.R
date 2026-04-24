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

skip_if_sysndd_api_not_running <- function(base_url = "http://localhost:8000") {
  is_running <- tryCatch(
    {
      resp <- httr2::request(paste0(base_url, "/api/version")) %>%
        httr2::req_timeout(2) %>%
        httr2::req_perform()
      body <- httr2::resp_body_json(resp)

      identical(httr2::resp_status(resp), 200L) &&
        is.list(body) &&
        "title" %in% names(body) &&
        identical(body$title[[1]], "SysNDD API")
    },
    error = function(e) FALSE
  )

  if (!is_running) {
    testthat::skip(sprintf("SysNDD API not running on %s", base_url))
  }
}
