# tests/testthat/test-unit-re-review-submit-allowlist.R
#
# Unit tests for the SET-clause allowlist added to the re-review submit path
# (re_review_submit_allowed_fields() / re_review_filter_submit_fields()).
#
# Prior behavior: PUT /api/re_review/submit built the UPDATE ... SET clause
# from names(submit_data) (attacker-controlled JSON body keys) with values
# bound via `?` but identifiers interpolated raw into SQL. This allowed
# SQL-identifier injection AND mass-assignment of re_review_approved /
# approving_user_id. These tests lock the fix: only the single writable
# column re_review_submitted may pass, and validate_query_column()'s
# "any"/"all" bypass token is also rejected via an explicit setdiff check.
#
# Pure (no database), so this runs on the host:
#   cd /home/bernt-popp/development/sysndd/api && \
#   Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-re-review-submit-allowlist.R')"

# errors.R provides stop_for_bad_request(), used by validate_query_column()
# to signal a 400 instead of a bare stop() the global handler maps to 500.
source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)

if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run re-review-service tests")
}
# re_review_submit_allowed_fields()/re_review_filter_submit_fields() moved to
# re-review-selection-service.R (#346 Wave 4) alongside the other selection
# logic (criteria/parameter builders, matching, preview, available entities).
source_api_file("services/re-review-selection-service.R", local = FALSE)

test_that("re_review_submit_allowed_fields is the tight single-column set", {
  skip_if_not(exists("re_review_submit_allowed_fields"))
  allowed <- re_review_submit_allowed_fields()
  expect_setequal(allowed, "re_review_submitted")
  expect_false("re_review_approved"  %in% allowed)  # no self-approval
  expect_false("approving_user_id"   %in% allowed)
  expect_false("re_review_entity_id" %in% allowed)  # PK / WHERE key
})

test_that("re_review_filter_submit_fields rejects injection + out-of-allowlist keys", {
  skip_if_not(exists("re_review_filter_submit_fields"))
  expect_error(re_review_filter_submit_fields("re_review_submitted = SLEEP(5), x"))
  expect_error(re_review_filter_submit_fields("re_review_approved"))      # mass-assignment
  expect_error(re_review_filter_submit_fields("re_review_review_saved"))  # wrong path
  expect_equal(re_review_filter_submit_fields("re_review_submitted"), "re_review_submitted")
})

test_that("re_review_filter_submit_fields closes the validate_query_column any/all bypass", {
  skip_if_not(exists("re_review_filter_submit_fields"))
  # validate_query_column() itself special-cases "any"/"all" as always-valid
  # (used by generate_filter_expressions/generate_sort_expressions cross-column
  # tokens). A field literally named "any" or "all" must NOT ride that bypass
  # into the re-review SET clause allowlist.
  expect_error(re_review_filter_submit_fields("any"))
  expect_error(re_review_filter_submit_fields("all"))
})

test_that("re_review_filter_submit_fields rejects an empty field set (no malformed SQL)", {
  skip_if_not(exists("re_review_filter_submit_fields"))
  # A body carrying only re_review_entity_id leaves no updatable field -> the
  # SET clause would be empty ("UPDATE ... SET  WHERE ...") and 500 with a
  # driver error. Reject as a clean 400 instead (Codex LOW).
  expect_error(re_review_filter_submit_fields(character(0)))
})
