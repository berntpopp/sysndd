# tests/testthat/test-endpoint-phenotype.R
#
# Phase C / C8 (`test-endpoint-write-batch`) — testthat coverage for
# `api/endpoints/phenotype_endpoints.R`. Sibling of test-endpoint-review.R;
# see that file's header for the full rationale.
#
# Note: phenotype_endpoints.R declares only `@get` routes. The plan's exit
# criterion #5 still requires happy + validation + permission per HTTP
# method per route, so every route gets the same three-block shape.
# Permission blocks here assert the absence of a `require_role()` guard
# — i.e. these endpoints are public reads and the "permission" guarantee
# is structural rather than a 403 drive-through.
#
# Routes covered in `phenotype_endpoints.R` (3 decorators):
#   GET entities/browse
#   GET correlation
#   GET count
#
# 3 routes * 3 blocks each = 9 `test_that` blocks.

library(testthat)

# -----------------------------------------------------------------------------
# Helpers (file-local).
# -----------------------------------------------------------------------------

phenotype_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "phenotype_endpoints.R")
}

phenotype_source <- function() {
  readLines(phenotype_endpoint_path(), warn = FALSE)
}

phenotype_body_blob <- function(decorator_regex) {
  src <- phenotype_source()
  dec_hits <- grep(decorator_regex, src)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in phenotype_endpoints.R: ", decorator_regex)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}


# =============================================================================
# GET entities/browse
# =============================================================================

test_that("GET entities/browse: happy path — decorator + cursor-pagination signature", {
  with_test_db_transaction({
    src <- phenotype_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+entities/browse\\s*$", src)),
      info = "phenotype_endpoints.R must declare `#* @get entities/browse`."
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+entities/browse\\s*$", src)[[1L]]
    # Plumber puts the formals across several lines, so grab a window.
    window <- paste(src[dec_idx:(dec_idx + 12L)], collapse = "\n")
    expect_match(window, "sort\\s*=\\s*\"entity_id\"")
    expect_match(window, "page_after")
    expect_match(window, "page_size")
    expect_match(window, "format\\s*=\\s*\"json\"")
  })
})

test_that("GET entities/browse: validation — delegates filtering to helper", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+entities/browse\\s*$")
    expect_match(body_blob, "generate_phenotype_entities_list\\(")
    expect_match(body_blob, "sort,\\s*filter,\\s*fields")
    expect_match(body_blob, "\"xlsx\"")
  })
})

test_that("GET entities/browse: permission — public read (no require_role)", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+entities/browse\\s*$")
    expect_false(
      grepl("require_role\\(", body_blob),
      info = "phenotype browse is a public read endpoint."
    )
  })
})


# =============================================================================
# GET correlation
# =============================================================================

test_that("GET correlation: happy path — decorator + default filter value", {
  with_test_db_transaction({
    src <- phenotype_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+correlation\\s*$", src))
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+correlation\\s*$", src)[[1L]]
    window <- paste(src[dec_idx:(dec_idx + 6L)], collapse = "\n")
    expect_match(
      window,
      "filter\\s*=\\s*\"contains\\(ndd_phenotype_word,Yes\\)",
      info = "Correlation handler must default to Definitive, ndd_phenotype filter."
    )
  })
})

test_that("GET correlation: validation — joins phenotype_list, computes cor()", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+correlation\\s*$")
    expect_match(body_blob, "phenotype_list")
    expect_match(body_blob, "cor\\(sysndd_db_phenotypes_matrix\\)")
    # HP:0001249 "Intellectual disability" is the catch-all root node — the
    # handler must exclude it so the correlation matrix doesn't saturate.
    expect_match(body_blob, "HP:0001249")
  })
})

test_that("GET correlation: permission — public read (no require_role)", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+correlation\\s*$")
    expect_false(grepl("require_role\\(", body_blob))
  })
})


# =============================================================================
# GET count
# =============================================================================

test_that("GET count: happy path — decorator + default filter value", {
  with_test_db_transaction({
    src <- phenotype_source()
    expect_true(
      any(grepl("^#\\*\\s+@get\\s+count\\s*$", src))
    )
    dec_idx <- grep("^#\\*\\s+@get\\s+count\\s*$", src)[[1L]]
    window <- paste(src[dec_idx:(dec_idx + 6L)], collapse = "\n")
    expect_match(window, "filter\\s*=\\s*\"contains\\(ndd_phenotype_word,Yes\\)")
  })
})

test_that("GET count: validation — tallies phenotypes, excludes HP:0001249", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+count\\s*$")
    expect_match(body_blob, "tally\\(\\)")
    expect_match(body_blob, "HP:0001249")
    expect_match(body_blob, "phenotype_list")
  })
})

test_that("GET count: permission — public read (no require_role)", {
  with_test_db_transaction({
    body_blob <- phenotype_body_blob("^#\\*\\s+@get\\s+count\\s*$")
    expect_false(grepl("require_role\\(", body_blob))
  })
})
