# tests/testthat/test-unit-external-url-encoding-guard.R
#
# Guard (LOW-5): external URL path/query segments built from caller input must
# be URL-encoded (utils::URLencode(x, reserved = TRUE)) so an odd/hostile
# identifier cannot alter the request, matching hpo-functions / ols-functions.
#
# Source scan — runs on host.

test_that("hgnc-functions.R URL-encodes every interpolated segment", {
  body <- paste(readLines(file.path(get_api_dir(), "functions", "hgnc-functions.R"),
                          warn = FALSE), collapse = "\n")
  # Robust to line-wrapping: there is at least one URLencode per genenames.org
  # search-URL builder (each interpolated identifier segment is encoded).
  n_urls <- length(gregexpr("rest.genenames.org/search/", body, fixed = TRUE)[[1]])
  n_encode <- length(gregexpr("URLencode", body, fixed = TRUE)[[1]])
  expect_gte(n_urls, 4)
  expect_gte(n_encode, n_urls)
})

test_that("oxo-functions.R URL-encodes the fromId segment", {
  src <- readLines(file.path(get_api_dir(), "functions", "oxo-functions.R"), warn = FALSE)
  from_id_line <- grep("fromId=", src, value = TRUE)
  expect_gt(length(from_id_line), 0)
  for (line in from_id_line) {
    expect_true(grepl("URLencode", line),
                info = paste("oxo URL segment not URL-encoded:", trimws(line)))
  }
})
