# tests/testthat/test-unit-filter-column-allowlist.R
#
# Unit tests for the column allowlist / injection-rejection logic added to
# generate_filter_expressions() and generate_sort_expressions().
#
# These tests are PURE (no database), so they must run on the host:
#   cd /home/bernt-popp/development/sysndd/api && \
#   Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-filter-column-allowlist.R')"

library(stringr)
library(dplyr)
library(tidyr)
library(tibble)
library(rlang)
library(jsonlite)

# errors.R provides stop_for_bad_request(), which validate_query_column() uses
# to signal a 400 (rather than a bare stop() that the global handler maps to 500).
source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)

cols <- c("symbol", "entity_id", "category", "any", "all")

# ---------------------------------------------------------------------------
# validate_query_column
# ---------------------------------------------------------------------------

test_that("validate_query_column accepts bare identifiers", {
  expect_silent(validate_query_column("symbol"))
  expect_silent(validate_query_column("entity_id"))
  expect_silent(validate_query_column("ndd_phenotype_word"))
})

test_that("validate_query_column rejects non-bare tokens (no allowlist)", {
  expect_error(validate_query_column("system('id')"),
               regexp = "column|not allowed|invalid", ignore.case = TRUE)
  expect_error(validate_query_column("symbol);foo"),
               regexp = "column|not allowed|invalid", ignore.case = TRUE)
  expect_error(validate_query_column("`x`"),
               regexp = "column|not allowed|invalid", ignore.case = TRUE)
  expect_error(validate_query_column("pkg::fn"),
               regexp = "column|not allowed|invalid", ignore.case = TRUE)
})

test_that("validate_query_column allows 'any'/'all' unconditionally", {
  expect_no_error(validate_query_column("any", allowed_columns = c("symbol")))
  expect_no_error(validate_query_column("all", allowed_columns = c("symbol")))
})

test_that("validate_query_column enforces allowlist when non-NULL", {
  expect_no_error(validate_query_column("symbol", allowed_columns = cols))
  expect_error(
    validate_query_column("injected", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})

# ---------------------------------------------------------------------------
# generate_filter_expressions — allowlist
# ---------------------------------------------------------------------------

test_that("known columns build expressions", {
  # Correct filter format: operation(column, value)
  out <- generate_filter_expressions("equals(symbol,ARID1B)", allowed_columns = cols)
  expect_true(any(grepl("symbol", out)))
})

test_that("unknown / injected columns are rejected before parse_exprs", {
  # Injected function call — parser extracts 'system' as the column token, which
  # fails the bare-identifier / allowlist check.
  # suppressWarnings: tidyr::separate emits benign "extra pieces" warnings while
  # parsing the malformed injection input; we only care that an error is raised.
  expect_error(
    suppressWarnings(
      generate_filter_expressions("equals(system('id'),x)", allowed_columns = cols)
    ),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
  # Mismatched parentheses — caught by the existing structural guard before
  # the column extraction step; the expression is rejected either way.
  expect_error(
    suppressWarnings(
      generate_filter_expressions("and(symbol);foo, equals, 'x')", allowed_columns = cols)
    )
  )
})

# ---------------------------------------------------------------------------
# generate_sort_expressions — allowlist
# ---------------------------------------------------------------------------

test_that("sort rejects unknown columns", {
  expect_error(
    generate_sort_expressions("-desc(`x`)", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
  expect_no_error(generate_sort_expressions("-symbol", allowed_columns = cols))
})

test_that("allowed_columns = NULL preserves legacy behaviour (no allowlist)", {
  expect_no_error(generate_sort_expressions("-symbol", allowed_columns = NULL))
})

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

test_that("empty / null filter string passes through unchanged", {
  expect_equal(generate_filter_expressions("", allowed_columns = cols), "")
  expect_equal(generate_filter_expressions("null", allowed_columns = cols), "")
})

test_that("injection via filter value does not affect column check", {
  # The column token is 'symbol' (allowed); the value is attacker-controlled
  # but lives inside the filter_value string and never reaches parse_exprs as
  # a column name — only the column token is validated.
  expect_no_error(
    generate_filter_expressions("equals(symbol,DROP TABLE foo)", allowed_columns = cols)
  )
})

test_that("multi-column sort passes when all columns are allowed", {
  expect_no_error(
    generate_sort_expressions("symbol,-entity_id", allowed_columns = cols)
  )
})

test_that("multi-column sort rejects when one column is not allowed", {
  expect_error(
    generate_sort_expressions("symbol,-injected", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})
