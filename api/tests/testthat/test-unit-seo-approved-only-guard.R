# tests/testthat/test-unit-seo-approved-only-guard.R
#
# Guard (#3 SEO): public /api/seo/* payloads are prerendered for anonymous
# visitors, so their review-derived content (HPO terms, variation terms, PMIDs)
# must come ONLY from approved-primary reviews. Previously entity_hpo_sql /
# entity_variation_sql / entity_pmids_sql / gene_pmids_sql gated on is_active /
# is_reviewed alone, leaking unapproved in-place review edits (Codex PR-1 review).
#
# Pure (no database) — the *_sql() helpers return static strings; runs on host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-seo-approved-only-guard.R')"

source_api_file("services/seo-service.R", local = FALSE)

test_that("every SEO review-derived query gates on review_approved = 1", {
  review_derived <- c("gene_pmids_sql", "entity_hpo_sql", "entity_variation_sql",
                      "entity_pmids_sql", "entity_review_sql")
  for (fn in review_derived) {
    skip_if_not(exists(fn))
    sql <- base::get(fn)()
    expect_true(grepl("review_approved = 1", sql, fixed = TRUE),
                info = paste(fn, "must gate on review_approved = 1"))
  }
})

test_that("SEO connect-table queries reach approval via a review join", {
  skip_if_not(exists("entity_hpo_sql"))
  expect_true(grepl("JOIN ndd_entity_review", entity_hpo_sql(), fixed = TRUE))
  expect_true(grepl("JOIN ndd_entity_review", entity_variation_sql(), fixed = TRUE))
  expect_true(grepl("JOIN ndd_entity_review", entity_pmids_sql(), fixed = TRUE))
  expect_true(grepl("JOIN ndd_entity_review", gene_pmids_sql(), fixed = TRUE))
})
