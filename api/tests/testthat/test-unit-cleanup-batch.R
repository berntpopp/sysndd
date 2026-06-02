source_api_file("functions/response-helpers.R", local = FALSE)

# Mirror the page_size clamp introduced in T8-a (audit #9): junk -> default, bounds, NA-safe.
clamp_page_size <- function(page_size) {
  n <- suppressWarnings(as.integer(page_size))
  if (is.na(n)) n <- 10L
  min(max(n, 1L), 50L)
}

test_that("page_size clamp handles junk, bounds, and NA", {
  expect_equal(clamp_page_size("abc"), 10L)
  expect_equal(clamp_page_size("0"), 1L)
  expect_equal(clamp_page_size("999"), 50L)
  expect_equal(clamp_page_size("25"), 25L)
  expect_equal(clamp_page_size(NA), 10L)
})
