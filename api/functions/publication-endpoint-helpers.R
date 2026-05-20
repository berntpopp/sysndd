# api/functions/publication-endpoint-helpers.R

publication_stats_response <- function(not_updated_since = NULL,
                                       query_fn = db_execute_query) {
  total_result <- query_fn(
    "SELECT COUNT(*) as total FROM publication"
  )
  oldest_result <- query_fn(
    "SELECT MIN(update_date) as oldest_update FROM publication"
  )
  outdated_result <- query_fn(
    "SELECT COUNT(*) as outdated_count FROM publication WHERE update_date < DATE_SUB(NOW(), INTERVAL 1 YEAR)"
  )

  result <- list(
    total = as.integer(total_result$total[1]),
    oldest_update = as.character(oldest_result$oldest_update[1]),
    outdated_count = as.integer(outdated_result$outdated_count[1])
  )

  if (!is.null(not_updated_since) && nzchar(not_updated_since)) {
    filter_date <- tryCatch(
      as.Date(not_updated_since),
      error = function(e) NULL
    )

    if (!is.null(filter_date) && !is.na(filter_date)) {
      filtered_result <- query_fn(
        "SELECT COUNT(*) as filtered_count FROM publication WHERE update_date < ?",
        list(as.character(filter_date))
      )
      result$filtered_count <- as.integer(filtered_result$filtered_count[1])
      result$filter_date <- as.character(filter_date)
    }
  }

  result
}
