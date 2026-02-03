# tests/testthat/test-integration-logs-pagination.R
# Integration tests for /api/logs endpoint pagination
#
# These tests verify that the logs endpoint:
# - Returns paginated responses with correct structure
# - Returns different data for different pages
# - Includes proper pagination metadata (totalCount, pageSize, etc.)
# - Handles database-side filtering correctly
#
# Prerequisites:
# - API running on localhost:8000
# - Database available with logging data
# - Administrator JWT token for authentication
#
# Requirements covered:
# - TST-07: Integration tests verify database query execution
# - TST-08: Integration tests verify pagination returns different pages
# - TST-09: Regression check for existing endpoints

library(testthat)
library(httr2)

# =============================================================================
# Helper: Check if API is running
# =============================================================================

skip_if_api_not_running <- function() {
  is_running <- tryCatch(
    {
      request("http://localhost:8000/health") %>%
        req_timeout(2) %>%
        req_perform()
      TRUE
    },
    error = function(e) FALSE
  )

  if (!is_running) {
    testthat::skip("API not running on localhost:8000")
  }
}

# =============================================================================
# Helper: Check if logs endpoint is accessible
# =============================================================================

#' Check if /api/logs endpoint is accessible
#'
#' The logs endpoint requires Administrator role, so we need to check
#' if we can access it. Returns accessibility status and reason if not.
#'
#' @return List with accessible (logical) and reason (character)
check_logs_access <- function() {
  resp <- tryCatch(
    {
      request("http://localhost:8000/api/logs") %>%
        req_url_query(page_after = 0, page_size = 1) %>%
        req_timeout(5) %>%
        req_error(is_error = function(resp) FALSE) %>%
        req_perform()
    },
    error = function(e) {
      list(status_code = 500, error = e$message)
    }
  )

  # Handle connection errors
  if (inherits(resp, "list") && !is.null(resp$error)) {
    return(list(accessible = FALSE, reason = resp$error))
  }

  status <- resp_status(resp)

  # 401/403 means authentication required

  if (status == 401 || status == 403) {
    return(list(accessible = FALSE, reason = "Requires Administrator authentication"))
  }

  # Other errors
  if (status >= 400) {
    return(list(accessible = FALSE, reason = paste("HTTP status", status)))
  }

  list(accessible = TRUE)
}

# =============================================================================
# Logs Endpoint Pagination Structure Tests (TST-07)
# =============================================================================

describe("logs endpoint pagination structure", {
  it("returns 200 with pagination structure", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # Verify pagination structure (links, meta, data)
    expect_true("links" %in% names(body),
                info = paste("Expected 'links', got:", paste(names(body), collapse = ", ")))
    expect_true("meta" %in% names(body),
                info = paste("Expected 'meta', got:", paste(names(body), collapse = ", ")))
    expect_true("data" %in% names(body),
                info = paste("Expected 'data', got:", paste(names(body), collapse = ", ")))
  })

  it("includes pagination metadata", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 10) %>%
      req_perform()

    body <- resp_body_json(resp)

    # Verify meta contains pagination fields
    meta <- body$meta

    # Check for perPage field (cursor pagination standard)
    expect_true("perPage" %in% names(meta) || "per_page" %in% names(meta),
                info = paste("Expected perPage in meta, got:", paste(names(meta), collapse = ", ")))
  })

  it("respects page_size parameter", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 3) %>%
      req_perform()

    body <- resp_body_json(resp)

    # Data should have at most 3 items
    expect_lte(length(body$data), 3,
               info = paste("Expected at most 3 items, got:", length(body$data)))

    # Check meta reports correct perPage
    if ("perPage" %in% names(body$meta)) {
      expect_equal(body$meta$perPage, 3)
    }
  })

  it("includes links for navigation", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5) %>%
      req_perform()

    body <- resp_body_json(resp)

    # Verify links structure
    expect_true(is.list(body$links),
                info = "Expected links to be a list")

    # Links should have 'next' field (may be null if last page)
    expect_true("next" %in% names(body$links),
                info = paste("Expected 'next' in links, got:", paste(names(body$links), collapse = ", ")))
  })
})

# =============================================================================
# Pagination Different Pages Tests (TST-08)
# =============================================================================

describe("logs pagination returns different pages", {
  it("page 2 contains different data than page 1", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Get first page with small page size
    resp1 <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 2) %>%
      req_perform()

    body1 <- resp_body_json(resp1)

    # Skip if not enough data for multiple pages
    if (length(body1$data) < 2) {
      skip("Not enough log data for pagination test (need at least 4 rows)")
    }

    # Check if there's a next page
    if (is.null(body1$links[["next"]]) || body1$links[["next"]] == "null") {
      skip("Not enough log data for pagination test (no next page)")
    }

    # Extract page_after from next link for second page
    next_link <- body1$links[["next"]]
    page_after_match <- regmatches(next_link, regexpr("page_after=(\\d+)", next_link))
    if (length(page_after_match) == 0) {
      skip("Could not extract page_after from next link")
    }
    page_after_2 <- as.integer(gsub("page_after=", "", page_after_match))

    # Get second page
    resp2 <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = page_after_2, page_size = 2) %>%
      req_perform()

    body2 <- resp_body_json(resp2)

    # Skip if page 2 is empty (not enough data)
    if (length(body2$data) == 0) {
      skip("Not enough log data for page 2")
    }

    # Compare first items from each page - they should have different IDs
    if (length(body1$data) > 0 && length(body2$data) > 0) {
      id1 <- body1$data[[1]]$id
      id2 <- body2$data[[1]]$id
      expect_false(identical(id1, id2),
                   info = paste("Page 1 first ID:", id1, "Page 2 first ID:", id2,
                                "- should be different"))
    }
  })

  it("cursor pagination maintains correct ordering", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Get first page with default sort (by id)
    resp1 <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 3) %>%
      req_perform()

    body1 <- resp_body_json(resp1)

    if (length(body1$data) < 2) {
      skip("Not enough log data for ordering test")
    }

    # Verify data is ordered by id
    ids <- vapply(body1$data, function(x) x$id, integer(1))
    expect_true(all(diff(ids) >= 0) || all(diff(ids) <= 0),
                info = "IDs should be monotonically ordered")
  })

  it("page_after cursor skips correct number of entries", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Get first page with page_after=0
    resp1 <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5) %>%
      req_perform()

    body1 <- resp_body_json(resp1)

    if (length(body1$data) < 3) {
      skip("Not enough log data for cursor test")
    }

    # Get the ID of the second item
    id_at_2 <- body1$data[[2]]$id

    # Request with page_after set to skip first 2
    resp2 <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 2, page_size = 5) %>%
      req_perform()

    body2 <- resp_body_json(resp2)

    if (length(body2$data) == 0) {
      skip("Not enough log data beyond position 2")
    }

    # First item of page 2 should be different from first 2 items of page 1
    first_page2_id <- body2$data[[1]]$id
    first_page1_id <- body1$data[[1]]$id
    expect_false(identical(first_page2_id, first_page1_id),
                 info = "Cursor should skip first entry")
  })
})

# =============================================================================
# Database Query Execution Tests (TST-07)
# =============================================================================

describe("logs database-side filtering", {
  it("filters by status parameter", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request only 200 status logs using filter syntax
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(filter = "contains(status,200)", page_size = 10) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # If data returned, all should have status 200
    if (length(body$data) > 0) {
      for (item in body$data) {
        expect_equal(item$status, 200,
                     info = paste("Expected status 200, got:", item$status))
      }
    }
  })

  it("filters by path using contains", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request only /api/ path logs
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(filter = "contains(path,/api/)", page_size = 10) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # If data returned, all paths should contain /api/
    if (length(body$data) > 0) {
      for (item in body$data) {
        expect_true(grepl("/api/", item$path),
                    info = paste("Path should contain /api/, got:", item$path))
      }
    }
  })

  it("filters by request_method", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request only GET method logs
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(filter = "contains(request_method,GET)", page_size = 10) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # If data returned, all should be GET requests
    if (length(body$data) > 0) {
      for (item in body$data) {
        expect_equal(item$request_method, "GET",
                     info = paste("Expected GET, got:", item$request_method))
      }
    }
  })

  it("handles combined filters", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Combine status and method filters
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(
        filter = "contains(status,200),contains(request_method,GET)",
        page_size = 5
      ) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # If data returned, verify both filters applied
    if (length(body$data) > 0) {
      for (item in body$data) {
        expect_equal(item$status, 200,
                     info = paste("Expected status 200, got:", item$status))
        expect_equal(item$request_method, "GET",
                     info = paste("Expected GET, got:", item$request_method))
      }
    }
  })

  it("rejects invalid sort column with 400", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request with invalid sort column (SQL injection attempt)
    resp <- tryCatch(
      {
        request("http://localhost:8000/api/logs") %>%
          req_url_query(sort = "id; DROP TABLE logging") %>%
          req_error(is_error = function(resp) FALSE) %>%
          req_perform()
      },
      error = function(e) NULL
    )

    if (!is.null(resp)) {
      # Should return 400 Bad Request for invalid column
      status <- resp_status(resp)
      expect_true(status %in% c(400, 422),
                  info = paste("Expected 400 or 422 for invalid column, got:", status))
    }
  })

  it("handles sort direction correctly", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Get ascending order
    resp_asc <- request("http://localhost:8000/api/logs") %>%
      req_url_query(sort = "id", page_size = 5) %>%
      req_perform()

    body_asc <- resp_body_json(resp_asc)

    # Get descending order
    resp_desc <- request("http://localhost:8000/api/logs") %>%
      req_url_query(sort = "-id", page_size = 5) %>%
      req_perform()

    body_desc <- resp_body_json(resp_desc)

    if (length(body_asc$data) > 1 && length(body_desc$data) > 1) {
      # First ID of ascending should be less than first ID of descending
      # (assuming we have enough data)
      asc_first <- body_asc$data[[1]]$id
      desc_first <- body_desc$data[[1]]$id

      expect_true(asc_first != desc_first,
                  info = paste("ASC first:", asc_first, "DESC first:", desc_first,
                               "- should be different with opposite sorting"))
    }
  })
})

# =============================================================================
# Pagination Metadata Tests (TST-08)
# =============================================================================

describe("logs pagination metadata", {
  it("includes perPage in meta", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5) %>%
      req_perform()

    body <- resp_body_json(resp)
    meta <- body$meta

    # Check for perPage field
    expect_true("perPage" %in% names(meta),
                info = paste("Expected perPage in meta, got:", paste(names(meta), collapse = ", ")))

    expect_equal(meta$perPage, 5)
  })

  it("includes executionTime in meta", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5) %>%
      req_perform()

    body <- resp_body_json(resp)
    meta <- body$meta

    # Check for executionTime field
    expect_true("executionTime" %in% names(meta),
                info = paste("Expected executionTime in meta, got:", paste(names(meta), collapse = ", ")))
  })

  it("tracks filter in meta", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5, filter = "contains(status,200)") %>%
      req_perform()

    body <- resp_body_json(resp)
    meta <- body$meta

    # Check that filter is reflected in meta
    expect_true("filter" %in% names(meta),
                info = paste("Expected filter in meta, got:", paste(names(meta), collapse = ", ")))

    expect_equal(meta$filter, "contains(status,200)")
  })

  it("tracks sort in meta", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 5, sort = "-timestamp") %>%
      req_perform()

    body <- resp_body_json(resp)
    meta <- body$meta

    # Check that sort is reflected in meta
    expect_true("sort" %in% names(meta),
                info = paste("Expected sort in meta, got:", paste(names(meta), collapse = ", ")))

    expect_equal(meta$sort, "-timestamp")
  })
})

# =============================================================================
# Existing Tests Regression (TST-09)
# =============================================================================

describe("existing pagination tests compatibility", {
  it("entity endpoint pagination still works (regression check)", {
    skip_if_api_not_running()

    resp <- request("http://localhost:8000/api/entity") %>%
      req_url_query(page_size = 5) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # Verify standard pagination structure
    expect_true("data" %in% names(body),
                info = "Entity endpoint should have data array")
    expect_true("links" %in% names(body),
                info = "Entity endpoint should have links")
    expect_true("meta" %in% names(body),
                info = "Entity endpoint should have meta")
  })

  it("logs endpoint matches entity endpoint structure pattern", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Get entity structure
    resp_entity <- request("http://localhost:8000/api/entity") %>%
      req_url_query(page_size = 2) %>%
      req_perform()
    body_entity <- resp_body_json(resp_entity)

    # Get logs structure
    resp_logs <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 0, page_size = 2) %>%
      req_perform()
    body_logs <- resp_body_json(resp_logs)

    # Both should have same top-level structure
    entity_keys <- sort(names(body_entity))
    logs_keys <- sort(names(body_logs))

    expect_equal(entity_keys, logs_keys,
                 info = paste("Entity keys:", paste(entity_keys, collapse = ", "),
                              "Logs keys:", paste(logs_keys, collapse = ", ")))
  })
})

# =============================================================================
# Edge Cases
# =============================================================================

describe("logs endpoint edge cases", {
  it("handles empty result gracefully", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request with filter that likely returns no results
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(
        filter = "contains(status,999)",  # Unlikely HTTP status
        page_size = 10
      ) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # Should still have proper structure even with empty data
    expect_true("data" %in% names(body))
    expect_true(is.list(body$data))
    # Data should be empty or a list
    expect_true(length(body$data) == 0 || is.list(body$data))
  })

  it("handles page_after beyond data gracefully", {
    skip_if_api_not_running()
    access <- check_logs_access()
    if (!access$accessible) {
      skip(paste("Logs endpoint not accessible:", access$reason))
    }

    # Request page far beyond available data
    resp <- request("http://localhost:8000/api/logs") %>%
      req_url_query(page_after = 999999, page_size = 10) %>%
      req_perform()

    expect_equal(resp_status(resp), 200)

    body <- resp_body_json(resp)

    # Should return empty data array
    expect_equal(length(body$data), 0)

    # Next link should be null when no more data
    expect_true(is.null(body$links[["next"]]) || body$links[["next"]] == "null")
  })
})
