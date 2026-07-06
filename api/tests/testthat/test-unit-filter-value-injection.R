# tests/testthat/test-unit-filter-value-injection.R
#
# Guard for the filter/hash VALUE injection (RCE/SQLi) closed alongside the #1
# hash-column RCE. User-supplied filter values and attacker-stored hash values
# are pasted into R source that reaches rlang::parse_exprs() at the caller
# (endpoint-functions.R:64/291/632 filter() runs IN R after collect()), so an
# unescaped quote/backslash is arbitrary code execution.
#
# PURE (no database) — runs on the host:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-filter-value-injection.R')"

library(stringr)
library(dplyr)
library(tidyr)
library(tibble)
library(rlang)
library(jsonlite)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/response-helpers.R", local = FALSE)

# ---------------------------------------------------------------------------
# escape_r_string_literal — the core neutralizer
# ---------------------------------------------------------------------------

test_that("escape_r_string_literal neutralizes string-literal breakout", {
  payload <- "a'); system('touch /tmp/pwn'); c('"
  esc <- escape_r_string_literal(payload)
  expr_str <- paste0("hgnc_id %in% c('", esc, "')")
  exprs <- rlang::parse_exprs(expr_str)

  # A successful breakout parses into MULTIPLE top-level expressions (the
  # injected system(...) call). Escaped, it stays a single %in% expression.
  expect_length(exprs, 1)
  expect_true(grepl("%in%", paste(deparse(exprs[[1]]), collapse = " ")))
})

test_that("escape_r_string_literal preserves the value as data (no functional loss)", {
  payload <- "O'Brien-1a"
  esc <- escape_r_string_literal(payload)
  parsed <- rlang::parse_exprs(paste0("x %in% c('", esc, "')"))[[1]]
  expect_equal(eval(parsed[[3]]), payload)
})

test_that("escape_r_string_literal escapes backslash before quote", {
  expect_equal(escape_r_string_literal("a\\b"), "a\\\\b")
  expect_equal(escape_r_string_literal("a'b"), "a\\'b")
})

# ---------------------------------------------------------------------------
# generate_filter_expressions — direct path strips backslash
# ---------------------------------------------------------------------------

test_that("direct-path filter value cannot retain a backslash", {
  out <- generate_filter_expressions("contains(symbol,'a\\b')", allowed_columns = NULL)
  expect_false(any(grepl("\\\\", out)),
    info = "a backslash in a filter value could escape the closing quote")
})

# ---------------------------------------------------------------------------
# Static guard: the hash-expansion path must validate columns and escape values
# ---------------------------------------------------------------------------

test_that("hash-filter expansion validates columns and escapes stored values", {
  src <- paste(readLines(file.path(get_api_dir(), "functions", "response-helpers.R"),
                         warn = FALSE), collapse = "\n")
  # Stored hash values must be escaped before the paste0(... c('...')).
  expect_true(grepl("escape_r_string_literal", src),
    info = "hash-stored values must be escaped before parse_exprs")
  # Stored hash column names must be validated as bare identifiers.
  expect_true(grepl("validate_query_column\\(hash_col", src),
    info = "hash column names must be validated before building the expression")
  # The raw unescaped paste of as.list(...)[[1]] must be gone.
  expect_false(grepl("str_c\\(as\\.list\\(table_hash_filter_value\\)", src),
    info = "raw stored values must not be pasted into the filter expression")
})
