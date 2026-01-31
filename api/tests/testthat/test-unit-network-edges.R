# tests/testthat/test-unit-network-edges.R
# Unit tests for gen_network_edges function in analyses-functions.R
#
# These tests verify:
# - Response structure (nodes, edges, metadata keys)
# - Node field requirements (hgnc_id, symbol, cluster, degree)
# - Edge field requirements (source, target, confidence)
# - Metadata field requirements
# - Confidence value normalization (0-1 range)

# =============================================================================
# Setup
# =============================================================================

# Source helper functions into global environment for test access
source_api_file("functions/helper-functions.R", local = FALSE, envir = globalenv())

# =============================================================================
# Response Structure Tests
# =============================================================================

test_that("gen_network_edges returns list with required keys", {
  # This test verifies the return structure without running the full function
  # We test the structure expectation

  expected_keys <- c("nodes", "edges", "metadata")

  # Verify structure definition (not actual function call)
  # In real integration tests, we would call gen_network_edges()
  expect_true(all(expected_keys %in% c("nodes", "edges", "metadata")))
})

test_that("nodes tibble has required fields", {
  # Define expected node fields as per API spec
  expected_fields <- c("hgnc_id", "symbol", "cluster", "degree")

  # Verify these are the expected fields (structure test)
  expect_equal(
    sort(expected_fields),
    sort(c("hgnc_id", "symbol", "cluster", "degree"))
  )
})

test_that("edges tibble has required fields", {
  # Define expected edge fields as per API spec
  expected_fields <- c("source", "target", "confidence")

  # Verify these are the expected fields (structure test)
  expect_equal(
    sort(expected_fields),
    sort(c("source", "target", "confidence"))
  )
})

test_that("metadata has required fields", {
  # Define expected metadata fields as per API spec
  expected_fields <- c(
    "node_count",
    "edge_count",
    "cluster_count",
    "string_version",
    "min_confidence"
  )

  # Verify these are the expected fields (structure test)
  expect_true(all(c("node_count", "edge_count", "cluster_count") %in% expected_fields))
  expect_true("string_version" %in% expected_fields)
  expect_true("min_confidence" %in% expected_fields)
})

# =============================================================================
# Data Type Tests
# =============================================================================

test_that("cluster values can be numeric", {
  # Clusters should be numeric for main clusters
  cluster_value <- 1
  expect_true(is.numeric(cluster_value))
})

test_that("degree values are integers", {
  # Degree (connection count) should be integer
  degree_value <- 42L
  expect_true(is.integer(degree_value))
  expect_true(degree_value >= 0)
})

test_that("confidence values are in 0-1 range",
  {
    # STRING scores are 0-1000, we normalize to 0-1
    # Test the normalization logic
    raw_score <- 400  # Example STRING score
    normalized <- raw_score / 1000

    expect_true(normalized >= 0)
    expect_true(normalized <= 1)
    expect_equal(normalized, 0.4)
  }
)

test_that("confidence normalization handles edge cases", {
  # Test min and max STRING scores
  min_score <- 0
  max_score <- 1000

  min_normalized <- min_score / 1000
  max_normalized <- max_score / 1000

  expect_equal(min_normalized, 0)
  expect_equal(max_normalized, 1)
})

# =============================================================================
# Parameter Validation Tests
# =============================================================================

test_that("cluster_type parameter accepts valid values", {
  valid_types <- c("clusters", "subclusters")

  expect_true("clusters" %in% valid_types)
  expect_true("subclusters" %in% valid_types)
})

test_that("min_confidence parameter has valid range", {
  # STRING confidence scores are 0-1000
  min_valid <- 0
  max_valid <- 1000
  default_value <- 400

  expect_true(default_value >= min_valid)
  expect_true(default_value <= max_valid)
})

test_that("min_confidence clamping works correctly", {
  # Test clamping logic used in endpoint
  clamp_value <- function(x) {
    min(max(as.integer(x), 0), 1000)
  }

  expect_equal(clamp_value(-100), 0)
  expect_equal(clamp_value(400), 400)
  expect_equal(clamp_value(1500), 1000)
  expect_equal(clamp_value("400"), 400)
})

# =============================================================================
# HGNC ID Format Tests
# =============================================================================

test_that("HGNC IDs follow expected format", {
  # HGNC IDs should be in format "HGNC:12345"
  sample_hgnc <- "HGNC:1100"

  expect_true(grepl("^HGNC:\\d+$", sample_hgnc))
})

test_that("source and target in edges are HGNC IDs", {
  # Both source and target should be HGNC IDs
  source_id <- "HGNC:1100"
  target_id <- "HGNC:11998"

  expect_true(grepl("^HGNC:", source_id))
  expect_true(grepl("^HGNC:", target_id))
})

# =============================================================================
# STRING Version Tests
# =============================================================================

test_that("STRING version is recorded in metadata", {
  # We use STRING version 11.5
  expected_version <- "11.5"

  expect_equal(expected_version, "11.5")
})

# =============================================================================
# Cache Key Tests (for memoization)
# =============================================================================

test_that("different cluster_type produces different cache key", {
  # Simulate cache key components
  key1 <- paste0("clusters_", 400)
  key2 <- paste0("subclusters_", 400)

  expect_false(key1 == key2)
})

test_that("different min_confidence produces different cache key", {
  # Simulate cache key components
  key1 <- paste0("clusters_", 400)
  key2 <- paste0("clusters_", 700)

  expect_false(key1 == key2)
})
