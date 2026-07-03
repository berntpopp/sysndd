# api/tests/testthat/test-unit-publication-refresh-source.R
test_that("publication_refresh UPDATE persists publication_date_source", {
  src <- readLines(file.path(get_api_dir(), "functions", "async-job-handlers.R"))
  body <- paste(src, collapse = "\n")
  # The publication UPDATE must set publication_date_source, not only Publication_date.
  expect_match(body, "publication_date_source\\s*=", fixed = FALSE)
})
