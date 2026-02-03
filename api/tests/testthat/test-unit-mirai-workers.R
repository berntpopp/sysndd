# tests/testthat/test-unit-mirai-workers.R
# Unit tests for MIRAI_WORKERS environment variable parsing
#
# Tests verify that the worker count configuration:
# - Defaults to 2 when not set
# - Handles invalid (non-numeric) values by falling back to default
# - Bounds values to 1-8 range
#
# Note: These tests verify the parsing PATTERN since the actual logic
# is inline in start_sysndd_api.R. The tests document expected behavior.

library(testthat)
library(withr)

# ============================================================================
# Helper: Parse MIRAI_WORKERS as implemented in start_sysndd_api.R
# ============================================================================

#' Parse MIRAI_WORKERS environment variable
#'
#' This function replicates the logic from start_sysndd_api.R for testing.
#' The actual implementation is inline in the API startup script.
#'
#' @return Integer worker count (1-8)
parse_mirai_workers <- function() {
  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))
  if (is.na(worker_count)) worker_count <- 2L
  max(1L, min(worker_count, 8L))
}

# ============================================================================
# MIRAI_WORKERS Parsing Tests (TST-01)
# ============================================================================

describe("MIRAI_WORKERS parsing", {

  it("defaults to 2 when not set", {
    withr::local_envvar(MIRAI_WORKERS = NA)  # Unset

    result <- parse_mirai_workers()
    expect_equal(result, 2L)
  })

  it("defaults to 2 when set to empty string", {
    withr::local_envvar(MIRAI_WORKERS = "")

    result <- parse_mirai_workers()
    expect_equal(result, 2L)
  })

  it("parses valid integer values", {
    withr::local_envvar(MIRAI_WORKERS = "4")
    expect_equal(parse_mirai_workers(), 4L)

    withr::local_envvar(MIRAI_WORKERS = "1")
    expect_equal(parse_mirai_workers(), 1L)

    withr::local_envvar(MIRAI_WORKERS = "8")
    expect_equal(parse_mirai_workers(), 8L)
  })

  it("handles non-numeric values by defaulting to 2", {
    withr::local_envvar(MIRAI_WORKERS = "abc")
    expect_equal(parse_mirai_workers(), 2L)

    withr::local_envvar(MIRAI_WORKERS = "two")
    expect_equal(parse_mirai_workers(), 2L)

    withr::local_envvar(MIRAI_WORKERS = "4.5")  # Float strings
    expect_equal(parse_mirai_workers(), 4L)  # as.integer truncates
  })

  it("bounds value to minimum of 1", {
    withr::local_envvar(MIRAI_WORKERS = "0")
    expect_equal(parse_mirai_workers(), 1L)

    withr::local_envvar(MIRAI_WORKERS = "-1")
    expect_equal(parse_mirai_workers(), 1L)

    withr::local_envvar(MIRAI_WORKERS = "-99")
    expect_equal(parse_mirai_workers(), 1L)
  })

  it("bounds value to maximum of 8", {
    withr::local_envvar(MIRAI_WORKERS = "9")
    expect_equal(parse_mirai_workers(), 8L)

    withr::local_envvar(MIRAI_WORKERS = "10")
    expect_equal(parse_mirai_workers(), 8L)

    withr::local_envvar(MIRAI_WORKERS = "100")
    expect_equal(parse_mirai_workers(), 8L)
  })

  it("handles edge cases at boundaries", {
    # Exactly at minimum
    withr::local_envvar(MIRAI_WORKERS = "1")
    expect_equal(parse_mirai_workers(), 1L)

    # Exactly at maximum
    withr::local_envvar(MIRAI_WORKERS = "8")
    expect_equal(parse_mirai_workers(), 8L)

    # One below minimum (should bound)
    withr::local_envvar(MIRAI_WORKERS = "0")
    expect_equal(parse_mirai_workers(), 1L)

    # One above maximum (should bound)
    withr::local_envvar(MIRAI_WORKERS = "9")
    expect_equal(parse_mirai_workers(), 8L)
  })

  it("handles whitespace around value", {
    withr::local_envvar(MIRAI_WORKERS = "  4  ")
    expect_equal(parse_mirai_workers(), 4L)

    withr::local_envvar(MIRAI_WORKERS = "\t3\n")
    expect_equal(parse_mirai_workers(), 3L)
  })

  it("handles mixed valid and invalid characters", {
    # as.integer will fail on these, so should default to 2
    withr::local_envvar(MIRAI_WORKERS = "4workers")
    expect_equal(parse_mirai_workers(), 2L)

    withr::local_envvar(MIRAI_WORKERS = "workers4")
    expect_equal(parse_mirai_workers(), 2L)
  })
})
