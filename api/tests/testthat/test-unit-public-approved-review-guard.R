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

test_that("the current_review=FALSE legacy branches gate on approved reviews", {
  # The `current_review = FALSE` branches read the connect tables directly
  # (is_active / is_reviewed). Being public, they must ALSO restrict to
  # approved-primary review ids, or they leak unapproved curation (Codex
  # re-review). Each of the three legacy branches must reference the gate.
  src <- paste(readLines("../../endpoints/entity_endpoints.R", warn = FALSE), collapse = "\n")

  # No connect-table read may filter is_active/is_reviewed without an
  # approved-primary review gate on the same statement.
  ungated_active <- grepl("filter\\(is_active == 1\\)\\s*%>%", src)
  expect_false(ungated_active,
    info = "a connect read filters is_active == 1 with no approved-review gate")
  expect_false(grepl("filter\\(is_reviewed == 1\\)\\s*%>%", src),
    info = "a publication read filters is_reviewed == 1 with no approved-review gate")

  # Each of the 3 legacy branches pulls approved review ids.
  n_gate <- length(gregexpr("approved_review_ids <- primary_approved_reviews", src)[[1]])
  expect_gte(n_gate, 3)
})
