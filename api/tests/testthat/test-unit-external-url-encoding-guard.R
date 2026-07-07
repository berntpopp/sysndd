# tests/testthat/test-unit-external-url-encoding-guard.R
#
# Guard (LOW-5): external URL path/query segments built from caller input must
# be URL-encoded (utils::URLencode(x, reserved = TRUE)) so an odd/hostile
# identifier cannot alter the request, matching hpo-functions / ols-functions.
#
# Source scan — runs on host.

test_that("hgnc-functions.R URL-encodes every interpolated segment", {
  src <- readLines(file.path(get_api_dir(), "functions", "hgnc-functions.R"), warn = FALSE)
  url_lines <- grep("paste0\\(\"http://rest.genenames.org", src, value = TRUE)
  expect_gt(length(url_lines), 0)
  for (line in url_lines) {
    expect_true(grepl("URLencode", line),
                info = paste("hgnc URL segment not URL-encoded:", trimws(line)))
  }
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
