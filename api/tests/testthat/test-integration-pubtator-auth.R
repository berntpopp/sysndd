library(testthat)
library(httr2)

api_url <- function(path) {
  origin <- Sys.getenv("API_URL", "http://localhost:7778")
  prefix <- Sys.getenv("API_PATH_PREFIX", "/api")
  paste0(origin, prefix, path)
}

api_request <- function(path) {
  req <- httr2::request(api_url(path))
  host_header <- Sys.getenv("API_HOST_HEADER", "")
  if (nzchar(host_header)) {
    req <- httr2::req_headers(req, Host = host_header)
  }
  req
}

skip_if_no_api <- function() {
  tryCatch({
    resp <- api_request("/health/") |>
      httr2::req_timeout(5) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) != 200) {
      skip("API not responding")
    }
  }, error = function(e) {
    skip(paste("API not available:", conditionMessage(e)))
  })
}

test_that("unauthenticated PubTator mutation POSTs are rejected before side effects", {
  skip_if_no_api()
  paths <- c(
    "/publication/pubtator/backfill-genes",
    "/publication/pubtator/update",
    "/publication/pubtator/update/submit",
    "/publication/pubtator/clear-cache"
  )

  for (path in paths) {
    resp <- api_request(path) |>
      httr2::req_method("POST") |>
      httr2::req_body_json(list(query = "BRCA1", max_pages = 1L, clear_old = FALSE)) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 401L, info = path)
  }
})
