library(testthat)
library(httr2)

skip_if_no_api <- function() {
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  tryCatch({
    resp <- httr2::request(paste0(api_url, "/health/")) |>
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
  api_url <- Sys.getenv("API_URL", "http://localhost:7778")
  paths <- c(
    "/api/publication/pubtator/backfill-genes",
    "/api/publication/pubtator/update",
    "/api/publication/pubtator/update/submit",
    "/api/publication/pubtator/clear-cache"
  )

  for (path in paths) {
    resp <- httr2::request(paste0(api_url, path)) |>
      httr2::req_method("POST") |>
      httr2::req_body_json(list(query = "BRCA1", max_pages = 1L, clear_old = FALSE)) |>
      httr2::req_perform()
    expect_equal(httr2::resp_status(resp), 401L, info = path)
  }
})
