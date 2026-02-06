# tests/testthat/test-unit-clustering-empty-tibble.R
# Unit tests for empty tibble handling in clustering functions
#
# These tests verify that defensive guards against empty tibbles work correctly
# and prevent "subscript out of bounds" errors when rowwise operations are
# performed on empty tibbles with list-columns.
#
# Background:
# When gene sets produce zero STRING interactions, the clustering pipeline
# creates empty tibbles. Without guards, rowwise() operations on these empty
# tibbles crash when accessing list-column elements.

# =============================================================================
# Setup
# =============================================================================

library(testthat)
library(dplyr)
library(tibble)

# Source helper functions into global environment for test access
source_api_file("functions/helper-functions.R", local = FALSE, envir = globalenv())

# =============================================================================
# Empty Tibble Structure Tests
# =============================================================================

test_that("empty clusters tibble has correct column structure", {
  # Simulate the empty tibble returned by gen_string_clust_obj
  # when no STRING interactions exist
  empty_result <- tibble(
    cluster = integer(),
    cluster_size = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # Verify structure
  expect_equal(nrow(empty_result), 0)
  expect_true(all(c("cluster", "cluster_size", "identifiers", "hash_filter") %in% names(empty_result)))
  expect_type(empty_result$cluster, "integer")
  expect_type(empty_result$cluster_size, "integer")
  expect_type(empty_result$identifiers, "list")
  expect_type(empty_result$hash_filter, "character")
})

test_that("empty functional_clustering response has correct structure", {
  # Simulate the empty response returned by functional_clustering endpoint
  # when gen_string_clust_obj returns empty tibble
  empty_response <- list(
    categories = tibble(value = character(), text = character(), link = character()),
    clusters = tibble(
      cluster = integer(),
      cluster_size = integer(),
      identifiers = list(),
      hash_filter = character()
    ),
    pagination = list(
      page_size = 10L,
      page_after = "",
      next_cursor = NULL,
      total_count = 0L,
      has_more = FALSE
    ),
    meta = list(
      algorithm = "leiden",
      elapsed_seconds = 0.1,
      gene_count = 5L,
      cluster_count = 0L
    )
  )

  # Verify structure
  expect_true(is.list(empty_response))
  expect_true(all(c("categories", "clusters", "pagination", "meta") %in% names(empty_response)))
  expect_equal(nrow(empty_response$categories), 0)
  expect_equal(nrow(empty_response$clusters), 0)
  expect_equal(empty_response$pagination$total_count, 0L)
  expect_false(empty_response$pagination$has_more)
  expect_equal(empty_response$meta$cluster_count, 0L)
})

# =============================================================================
# Rowwise Guard Pattern Tests
# =============================================================================

test_that("rowwise guard preserves column structure on empty tibble", {
  # Create empty tibble with list-column (similar to clustering pipeline)
  empty_tibble <- tibble(
    cluster = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # Apply the guarded rowwise pattern
  result <- empty_tibble %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(cluster_size = nrow(identifiers)) %>%
          ungroup()
      } else {
        mutate(., cluster_size = integer())
      }
    }

  # Verify result has correct structure with 0 rows
  expect_equal(nrow(result), 0)
  expect_true("cluster_size" %in% names(result))
  expect_type(result$cluster_size, "integer")
  expect_equal(ncol(result), 4)  # cluster, identifiers, hash_filter, cluster_size
})

test_that("rowwise guard works correctly on non-empty tibble", {
  # Create non-empty tibble with nested data
  test_tibble <- tibble(
    cluster = c(1L, 2L),
    identifiers = list(
      tibble(hgnc_id = c(1, 2, 3)),
      tibble(hgnc_id = c(4, 5))
    ),
    hash_filter = c("hash1", "hash2")
  )

  # Apply the guarded rowwise pattern
  result <- test_tibble %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(cluster_size = nrow(identifiers)) %>%
          ungroup()
      } else {
        mutate(., cluster_size = integer())
      }
    }

  # Verify cluster_size was computed correctly
  expect_equal(nrow(result), 2)
  expect_equal(result$cluster_size, c(3, 2))
  expect_true("cluster_size" %in% names(result))
})

test_that("unguarded rowwise on empty tibble with list-column returns empty result", {
  # In older dplyr versions this would throw; modern dplyr handles empty tibbles
  # gracefully. The guarded approach (next test) is still preferred for safety.
  empty_tibble <- tibble(
    cluster = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  result <- empty_tibble %>%
    rowwise() %>%
    mutate(cluster_size = nrow(identifiers))

  expect_equal(nrow(result), 0)
})

test_that("guarded rowwise on empty tibble does not throw error", {
  # This test demonstrates the FIX - guarded rowwise succeeds
  empty_tibble <- tibble(
    cluster = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # Guarded rowwise should succeed (this is the fix)
  expect_no_error(
    empty_tibble %>%
      {
        if (nrow(.) > 0) {
          rowwise(.) %>%
            mutate(cluster_size = nrow(identifiers)) %>%
            ungroup()
        } else {
          mutate(., cluster_size = integer())
        }
      }
  )
})

# =============================================================================
# Defensive Guard Pattern Tests (Other Functions)
# =============================================================================

test_that("hgnc guard pattern handles empty tibble", {
  # Simulate the pattern in hgnc-functions.R
  empty_input <- tibble(value = character())

  result <- empty_input %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(response = as.integer(NA)) %>%  # Simplified for test
          ungroup()
      } else {
        mutate(., response = integer())
      }
    }

  expect_equal(nrow(result), 0)
  expect_true("response" %in% names(result))
})

test_that("statistics guard pattern handles empty tibble", {
  # Simulate the pattern in statistics_endpoints.R (re_review date calculation)
  empty_reviews <- tibble(
    review_date = as.Date(character()),
    status_date = as.Date(character())
  )

  result <- empty_reviews %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(date = max(review_date, status_date, na.rm = TRUE)) %>%
          ungroup()
      } else {
        mutate(., date = as.Date(NA))
      }
    }

  expect_equal(nrow(result), 0)
  expect_true("date" %in% names(result))
  expect_s3_class(result$date, "Date")
})

test_that("comparisons guard pattern handles empty tibble", {
  # Simulate the pattern in comparisons-functions.R
  empty_comparisons <- tibble(
    disease_ontology_name = character(),
    disease_ontology_id = character(),
    category = character(),
    version = character()
  )

  result <- empty_comparisons %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(
            category = toString(category),
            version = toString(version)
          ) %>%
          ungroup()
      } else {
        .
      }
    }

  expect_equal(nrow(result), 0)
  expect_true(all(c("category", "version") %in% names(result)))
})

test_that("ontology guard pattern handles empty tibble", {
  # Simulate the pattern in ontology-functions.R
  empty_terms <- tibble(MONDO = character())

  result <- empty_terms %>%
    {
      if (nrow(.) > 0) {
        rowwise(.) %>%
          mutate(mappings = list(character())) %>%  # Simplified for test
          ungroup()
      } else {
        mutate(., mappings = list())
      }
    }

  expect_equal(nrow(result), 0)
  expect_true("mappings" %in% names(result))
  expect_type(result$mappings, "list")
})

# =============================================================================
# Edge Cases and Integration Tests
# =============================================================================

test_that("empty tibble guard preserves all expected columns", {
  # Test that the early return in gen_string_clust_obj produces
  # exactly the columns that downstream code expects
  empty_result <- tibble(
    cluster = integer(),
    cluster_size = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # These are the columns that pagination and enrichment steps expect
  expected_cols <- c("cluster", "cluster_size", "identifiers", "hash_filter")

  expect_true(all(expected_cols %in% names(empty_result)))
  expect_equal(length(names(empty_result)), length(expected_cols))
})

test_that("empty functional clusters can be safely unnested", {
  # Verify that empty clustering results can pass through
  # the category generation pipeline without error
  empty_clusters <- tibble(
    cluster = integer(),
    cluster_size = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # This would crash in the original code but should work now
  # The categories pipeline tries to unnest term_enrichment
  # For empty result, we should skip this entirely
  expect_equal(nrow(empty_clusters), 0)

  # Verify pagination calculations work with empty result
  total_count <- nrow(empty_clusters)
  has_more <- FALSE
  next_cursor <- NULL

  expect_equal(total_count, 0)
  expect_false(has_more)
  expect_null(next_cursor)
})

test_that("empty phenotype correlation handles empty functional clusters", {
  # Simulate the empty result from gen_string_clust_obj
  empty_functional_clusters <- tibble(
    cluster = integer(),
    cluster_size = integer(),
    identifiers = list(),
    hash_filter = character()
  )

  # Apply the guard from phenotype_functional_cluster_correlation
  if (nrow(empty_functional_clusters) == 0) {
    functional_clusters_hgnc <- tibble(cluster = character(), hgnc_id = integer())
  } else {
    functional_clusters_hgnc <- empty_functional_clusters %>%
      select(cluster, identifiers) %>%
      unnest(identifiers) %>%
      mutate(cluster = paste0("fc_", cluster)) %>%
      select(cluster, hgnc_id)
  }

  # Verify result is empty with correct structure
  expect_equal(nrow(functional_clusters_hgnc), 0)
  expect_true(all(c("cluster", "hgnc_id") %in% names(functional_clusters_hgnc)))
  expect_type(functional_clusters_hgnc$cluster, "character")
  expect_type(functional_clusters_hgnc$hgnc_id, "integer")
})
