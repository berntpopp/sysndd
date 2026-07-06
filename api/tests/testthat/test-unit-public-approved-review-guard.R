# Guard (#3): every public review-derived read must gate on review_approved,
# not is_primary alone. Enforced by a source scan of entity_endpoints.R.
test_that("entity_endpoints.R never filters ndd_entity_review by is_primary alone", {
  src <- paste(readLines("../../endpoints/entity_endpoints.R", warn = FALSE), collapse = "\n")
  # No bare `filter(is_primary)` / `filter(... is_primary)` without review_approved
  bad <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", src)[[1]]
  if (bad[1] != -1) {
    for (i in seq_along(bad)) {
      frag <- substr(src, bad[i], bad[i] + attr(bad, "match.length")[i] - 1)
      expect_true(grepl("review_approved", frag),
                  info = paste("is_primary filter without review_approved:", frag))
    }
  }
  succeed()
})

test_that("primary_approved_reviews carries both predicates", {
  skip_if_not(exists("primary_approved_reviews"))
  body <- paste(deparse(body(primary_approved_reviews)), collapse = " ")
  expect_true(grepl("is_primary", body))
  expect_true(grepl("review_approved", body))
})
