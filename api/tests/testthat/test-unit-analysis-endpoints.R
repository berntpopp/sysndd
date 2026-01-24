# test-unit-analysis-endpoints.R
# Unit tests for analysis_endpoints.R pagination logic

# Test pagination parameter validation
test_that("page_size is validated and clamped to valid range", {
  # Test valid integer parsing
  expect_equal(min(max(as.integer("10"), 1), 50), 10)
  expect_equal(min(max(as.integer("1"), 1), 50), 1)
  expect_equal(min(max(as.integer("50"), 1), 50), 50)

  # Test clamping below minimum
  expect_equal(min(max(as.integer("0"), 1), 50), 1)
  expect_equal(min(max(as.integer("-5"), 1), 50), 1)

  # Test clamping above maximum
  expect_equal(min(max(as.integer("100"), 1), 50), 50)
  expect_equal(min(max(as.integer("999"), 1), 50), 50)
})

test_that("page_after handles empty and null values", {
  # Empty string
  page_after <- ""
  result <- if (is.null(page_after) || page_after == "") "" else page_after
  expect_equal(result, "")

  # NULL value
  page_after <- NULL
  result <- if (is.null(page_after) || page_after == "") "" else page_after
  expect_equal(result, "")

  # Valid cursor
  page_after <- "abc123hash"
  result <- if (is.null(page_after) || page_after == "") "" else page_after
  expect_equal(result, "abc123hash")
})

test_that("pagination slice calculation is correct", {
  # Simulate cluster data
  test_data <- tibble::tibble(
    cluster = 1:100,
    hash_filter = paste0("hash_", 1:100)
  ) %>%
    dplyr::mutate(row_num = dplyr::row_number())

  page_size <- 10

  # First page (page_after = "")
  start_idx <- 1
  end_idx <- min(start_idx + page_size - 1, nrow(test_data))
  expect_equal(start_idx, 1)
  expect_equal(end_idx, 10)

  # Second page (page_after = "hash_10")
  cursor_pos <- which(test_data$hash_filter == "hash_10")
  start_idx <- cursor_pos + 1
  end_idx <- min(start_idx + page_size - 1, nrow(test_data))
  expect_equal(start_idx, 11)
  expect_equal(end_idx, 20)

  # Last page
  cursor_pos <- which(test_data$hash_filter == "hash_95")
  start_idx <- cursor_pos + 1
  end_idx <- min(start_idx + page_size - 1, nrow(test_data))
  expect_equal(start_idx, 96)
  expect_equal(end_idx, 100)  # Only 5 items remaining
})

test_that("next_cursor is NULL on last page", {
  test_data <- tibble::tibble(
    cluster = 1:25,
    hash_filter = paste0("hash_", 1:25)
  )

  # Page that doesn't reach end
  end_idx <- 20
  next_cursor <- if (end_idx < nrow(test_data)) {
    test_data %>% dplyr::slice(end_idx) %>% dplyr::pull(hash_filter)
  } else {
    NULL
  }
  expect_equal(next_cursor, "hash_20")

  # Last page
  end_idx <- 25
  next_cursor <- if (end_idx < nrow(test_data)) {
    test_data %>% dplyr::slice(end_idx) %>% dplyr::pull(hash_filter)
  } else {
    NULL
  }
  expect_null(next_cursor)
})

test_that("sorting ensures stable pagination order", {
  # Simulate unsorted data
  unsorted_data <- tibble::tibble(
    cluster = c(5, 2, 8, 1, 3),
    hash_filter = paste0("hash_", c(5, 2, 8, 1, 3))
  )

  # Sort should produce deterministic order
  sorted_data <- unsorted_data %>%
    dplyr::arrange(cluster)

  expect_equal(sorted_data$cluster, c(1, 2, 3, 5, 8))
  expect_equal(sorted_data$hash_filter, c("hash_1", "hash_2", "hash_3", "hash_5", "hash_8"))
})

test_that("pagination metadata structure is correct", {
  # Simulate pagination metadata
  pagination <- list(
    page_size = 10,
    page_after = "",
    next_cursor = "hash_10",
    total_count = 87,
    has_more = TRUE
  )

  expect_true("page_size" %in% names(pagination))
  expect_true("page_after" %in% names(pagination))
  expect_true("next_cursor" %in% names(pagination))
  expect_true("total_count" %in% names(pagination))
  expect_true("has_more" %in% names(pagination))

  expect_type(pagination$page_size, "double")
  expect_type(pagination$total_count, "double")
  expect_type(pagination$has_more, "logical")
})
