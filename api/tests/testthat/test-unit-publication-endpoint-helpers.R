source_api_file("functions/publication-endpoint-helpers.R", local = FALSE)

test_that("publication_stats_response returns core publication counters", {
  queries <- list()
  query_fn <- function(sql, params = list()) {
    queries[[length(queries) + 1L]] <<- list(sql = sql, params = params)
    if (grepl("COUNT\\(\\*\\) as total", sql)) {
      return(data.frame(total = 12L))
    }
    if (grepl("MIN\\(update_date\\)", sql)) {
      return(data.frame(oldest_update = as.Date("2023-01-02")))
    }
    if (grepl("outdated_count", sql)) {
      return(data.frame(outdated_count = 3L))
    }
    stop("unexpected query")
  }

  result <- publication_stats_response(query_fn = query_fn)

  expect_equal(result$total, 12L)
  expect_equal(result$oldest_update, "2023-01-02")
  expect_equal(result$outdated_count, 3L)
  expect_null(result$filtered_count)
  expect_length(queries, 3L)
})

test_that("publication_stats_response includes valid optional date filter", {
  query_fn <- function(sql, params = list()) {
    if (grepl("filtered_count", sql)) {
      expect_equal(params, list("2024-05-19"))
      return(data.frame(filtered_count = 7L))
    }
    if (grepl("COUNT\\(\\*\\) as total", sql)) {
      return(data.frame(total = 12L))
    }
    if (grepl("MIN\\(update_date\\)", sql)) {
      return(data.frame(oldest_update = as.Date("2023-01-02")))
    }
    if (grepl("outdated_count", sql)) {
      return(data.frame(outdated_count = 3L))
    }
    stop("unexpected query")
  }

  result <- publication_stats_response(
    not_updated_since = "2024-05-19",
    query_fn = query_fn
  )

  expect_equal(result$filtered_count, 7L)
  expect_equal(result$filter_date, "2024-05-19")
})

test_that("publication_stats_response ignores invalid optional date filter", {
  result <- publication_stats_response(
    not_updated_since = "not-a-date",
    query_fn = function(sql, params = list()) {
      if (grepl("filtered_count", sql)) {
        stop("filtered query should not run")
      }
      if (grepl("COUNT\\(\\*\\) as total", sql)) {
        return(data.frame(total = 12L))
      }
      if (grepl("MIN\\(update_date\\)", sql)) {
        return(data.frame(oldest_update = as.Date("2023-01-02")))
      }
      if (grepl("outdated_count", sql)) {
        return(data.frame(outdated_count = 3L))
      }
      stop("unexpected query")
    }
  )

  expect_null(result$filtered_count)
  expect_null(result$filter_date)
})
