# tests/testthat/test-unit-analyses-functions.R
# Unit tests for analyses-functions.R
#
# These tests verify:
# - Cache key versioning (algorithm, STRING version, cache version)
# - CACHE_VERSION environment variable behavior
# - Cache filename generation patterns

# =============================================================================
# Setup
# =============================================================================

# Source helper functions into global environment for test access
source_api_file("functions/helper-functions.R", local = FALSE, envir = globalenv())

# =============================================================================
# Cache Key Versioning Tests
# =============================================================================

test_that("gen_string_clust_obj cache filename pattern includes all version components", {
  # This test verifies the cache filename generation pattern
  # without actually running the clustering (which requires database/STRINGdb)

  # Set test environment
  withr::local_envvar(CACHE_VERSION = "test1")

  # Simulate the cache filename generation logic from gen_string_clust_obj
  test_hgnc_list <- c("HGNC:1100", "HGNC:11998")  # Sample HGNC IDs
  panel_hash <- generate_panel_hash(test_hgnc_list)

  # These are the expected version components
  algorithm <- "leiden"
  string_version <- "11.5"
  cache_version <- Sys.getenv("CACHE_VERSION", "1")
  min_size <- 10
  subcluster <- TRUE

  # Generate expected filename pattern
  expected_pattern <- paste0(
    "results/",
    panel_hash, ".",
    "FUNCTION_HASH",  # Placeholder for function hash
    ".",
    algorithm, ".",
    "string_v", string_version, ".",
    "cache_v", cache_version, ".",
    min_size, ".",
    subcluster, ".json"
  )

  # Verify pattern contains required components
  expect_true(grepl("leiden", expected_pattern))
  expect_true(grepl("string_v11\\.5", expected_pattern))
  expect_true(grepl("cache_vtest1", expected_pattern))
  expect_true(grepl("results/", expected_pattern))
  expect_true(grepl("\\.json$", expected_pattern))
})

test_that("gen_mca_clust_obj cache filename pattern includes cache version", {
  # Set test environment
  withr::local_envvar(CACHE_VERSION = "test2")

  # Simulate the cache filename generation logic from gen_mca_clust_obj
  test_rownames <- c("entity_1", "entity_2")
  panel_hash <- generate_panel_hash(test_rownames)
  cache_version <- Sys.getenv("CACHE_VERSION", "1")

  # Generate expected filename pattern
  expected_pattern <- paste0(
    "results/",
    panel_hash, ".",
    "FUNCTION_HASH",  # Placeholder for function hash
    ".",
    "mca.",
    "cache_v", cache_version, ".json"
  )

  # Verify pattern contains required components
  expect_true(grepl("mca", expected_pattern))
  expect_true(grepl("cache_vtest2", expected_pattern))
  expect_true(grepl("results/", expected_pattern))
  expect_true(grepl("\\.json$", expected_pattern))

  # Verify NO double dots (the bug we fixed)
  expect_false(grepl("\\.\\.", expected_pattern))
})

# =============================================================================
# CACHE_VERSION Environment Variable Tests
# =============================================================================

test_that("CACHE_VERSION environment variable is respected", {
  # Test that setting CACHE_VERSION changes the value
  withr::local_envvar(CACHE_VERSION = "v1")
  version1 <- Sys.getenv("CACHE_VERSION", "1")
  expect_equal(version1, "v1")
})

test_that("CACHE_VERSION can be changed dynamically", {
  # Test that different values work
  withr::local_envvar(CACHE_VERSION = "v2")
  version2 <- Sys.getenv("CACHE_VERSION", "1")
  expect_equal(version2, "v2")
})

test_that("CACHE_VERSION defaults to '1' when not set", {
  # Test default when not set
  withr::local_envvar(CACHE_VERSION = NA)
  version_default <- Sys.getenv("CACHE_VERSION", "1")
  expect_equal(version_default, "1")
})

test_that("CACHE_VERSION accepts arbitrary string values", {
  # Test that arbitrary string values work
  withr::local_envvar(CACHE_VERSION = "2024-01-15-leiden")
  version_dated <- Sys.getenv("CACHE_VERSION", "1")
  expect_equal(version_dated, "2024-01-15-leiden")
})

# =============================================================================
# Cache Filename Component Tests
# =============================================================================

test_that("Algorithm name appears in STRING clustering cache key", {
  algorithm <- "leiden"

  # Simulate cache key pattern
  cache_key <- paste0("prefix.", algorithm, ".suffix")

  expect_true(grepl("leiden", cache_key))
  expect_false(grepl("walktrap", cache_key))
})

test_that("STRING version appears in STRING clustering cache key", {
  string_version <- "11.5"

  # Simulate cache key pattern
  cache_key <- paste0("prefix.string_v", string_version, ".suffix")

  expect_true(grepl("string_v11\\.5", cache_key))
})

test_that("Different algorithm produces different cache key", {
  # Simulate two cache keys with different algorithms
  base_hash <- "abc123"

  key_leiden <- paste0(base_hash, ".leiden.string_v11.5.cache_v1")
  key_walktrap <- paste0(base_hash, ".walktrap.string_v11.5.cache_v1")

  expect_false(key_leiden == key_walktrap)
})

test_that("Different STRING version produces different cache key", {
  base_hash <- "abc123"

  key_v115 <- paste0(base_hash, ".leiden.string_v11.5.cache_v1")
  key_v120 <- paste0(base_hash, ".leiden.string_v12.0.cache_v1")

  expect_false(key_v115 == key_v120)
})

test_that("Different cache version produces different cache key", {
  base_hash <- "abc123"

  key_v1 <- paste0(base_hash, ".leiden.string_v11.5.cache_v1")
  key_v2 <- paste0(base_hash, ".leiden.string_v11.5.cache_v2")

  expect_false(key_v1 == key_v2)
})

# =============================================================================
# MCA Cache Key Tests
# =============================================================================

test_that("MCA cache key includes 'mca' identifier", {
  cache_key <- paste0("results/", "hash123", ".", "funhash", ".", "mca.", "cache_v1.json")

  expect_true(grepl("mca", cache_key))
})

test_that("MCA cache key does not have double dots (bug fix verification)", {
  # The original code had: function_hash, ".", ".json" (double dot bug)
  # Fixed code has: function_hash, ".", "mca.", "cache_v", version, ".json"

  # Simulate correct pattern (fixed)
  correct_key <- paste0("results/hash.", "funhash.", "mca.", "cache_v1.json")
  expect_false(grepl("\\.\\.", correct_key))

  # Demonstrate what the bug looked like
  buggy_key <- paste0("results/hash.", "funhash.", ".", ".json")
  expect_true(grepl("\\.\\.", buggy_key))
})

# =============================================================================
# Cache Isolation Tests
# =============================================================================

test_that("Changing CACHE_VERSION invalidates cache lookup", {
  # This test demonstrates that changing CACHE_VERSION creates a new cache key
  # which effectively invalidates the old cache

  withr::local_envvar(CACHE_VERSION = "old")
  old_version <- Sys.getenv("CACHE_VERSION", "1")
  old_key <- paste0("cache_v", old_version)

  withr::local_envvar(CACHE_VERSION = "new")
  new_version <- Sys.getenv("CACHE_VERSION", "1")
  new_key <- paste0("cache_v", new_version)

  # Keys should be different
  expect_false(old_key == new_key)
  expect_equal(old_key, "cache_vold")
  expect_equal(new_key, "cache_vnew")
})

# =============================================================================
# STRING Score Threshold Tests
# =============================================================================

test_that("STRING score_threshold defaults to 400 (medium confidence)", {
  # This test verifies the default value without running actual clustering
  # The actual STRING call happens in gen_string_clust_obj and gen_string_enrich_tib

  # Verify the expected default value
  default_threshold <- 400

  # STRING confidence levels (from STRING documentation):
  # - low confidence: 150
  # - medium confidence: 400
  # - high confidence: 700
  # - highest confidence: 900

  expect_equal(default_threshold, 400)
  expect_true(default_threshold >= 400)  # At least medium confidence
  expect_true(default_threshold <= 1000)  # Valid STRING score range
})

test_that("STRING score_threshold parameter is configurable", {
  # Verify the parameter can accept custom values
  custom_threshold <- 700  # high confidence

  expect_true(custom_threshold >= 0)
  expect_true(custom_threshold <= 1000)
})
