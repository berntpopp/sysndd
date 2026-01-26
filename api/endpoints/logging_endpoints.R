# api/endpoints/logging_endpoints.R
#
# This file contains all Logging-related endpoints extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Make sure to source any required helpers or libraries at the top if needed.

## -------------------------------------------------------------------##
## Logging section
## -------------------------------------------------------------------##

#* Get Paginated Log Files
#*
#* This endpoint returns paginated log files from the database.
#*
#* # `Details`
#* Reads log entries from the database, applies filtering and pagination, and
#* returns the data as JSON. Takes input parameters for sorting, filtering,
#* field selection, and cursor pagination.
#*
#* # `Return`
#* A cursor pagination object with `links`, `meta`, and `data`.
#*
#* @tag logging
#* @serializer json list(na="string")
#*
#* @param sort:str Column to arrange output by. Default "id".
#* @param filter:str Comma-separated list of filters to apply.
#* @param fields:str Comma-separated list of output columns.
#* @param page_after:str Cursor after which entries are shown.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields to generate field specification for.
#* @param format:str Output format ("json" or "xlsx").
#*
#* @response 200 OK. A cursor pagination object with log entries.
#* @response 403 Forbidden. If user not Admin.
#* @response 500 Internal server error.
#*
#* @get /
function(req,
         res,
         sort = "id",
         filter = "",
         fields = "",
         page_after = 0,
         page_size = 10,
         fspec = "id,timestamp,address,agent,host,request_method,path,query,post,status,duration,file,modified",
         format = "json") {
  require_role(req, res, "Administrator")

  # Set serializer
  res$serializer <- serializers[[format]]

  # Start time
  start_time <- Sys.time()

  # Generate sort expression
  sort_exprs <- generate_sort_expressions(sort, unique_id = "id")
  # Generate filter expression
  filter_exprs <- generate_filter_expressions(filter)

  # Get logs from database
  logs_raw <- pool %>%
    tbl("logging") %>%
    collect()

  # Sort & filter
  logs_raw <- logs_raw %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # Select fields if specified
  if (fields != "") {
    selected_fields <- unlist(strsplit(fields, ","))
    logs_raw <- logs_raw %>%
      select(all_of(selected_fields))
  }

  # Pagination
  log_pagination_info <- generate_cursor_pag_inf(
    logs_raw,
    page_size,
    page_after,
    "id"
  )

  # Field specs
  logs_raw_fspec <- NULL
  if (fspec != "") {
    logs_raw_fspec <- generate_tibble_fspec_mem(logs_raw, fspec)
    logs_raw_fspec$fspec$count_filtered <- logs_raw_fspec$fspec$count
  }

  # Compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

  # Add meta
  meta <- log_pagination_info$meta %>%
    add_column(
      tibble::as_tibble(list(
        "sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = logs_raw_fspec,
        "executionTime" = execution_time
      ))
    )

  # Prepare response
  response <- list(
    links = log_pagination_info$links,
    meta = meta,
    data = log_pagination_info$data
  )

  if (format == "xlsx") {
    creation_date <- strftime(
      as.POSIXlt(Sys.time(), "UTC", "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S"
    )
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
      str_replace_all("_api_", "")
    filename <- file.path(paste0(base_filename, "_", creation_date, ".xlsx"))

    bin <- generate_xlsx_bin(response, base_filename)
    as_attachment(bin, filename)
  } else {
    response
  }
}


#* Delete Log Entries
#*
#* This endpoint deletes log entries from the database.
#*
#* # `Details`
#* Admin only. Can delete all logs or only logs older than a specified number of days.
#* This action cannot be undone.
#*
#* # `Return`
#* A success message with the count of deleted entries.
#*
#* @tag logging
#* @serializer json list(na="string")
#*
#* @param older_than_days:int Optional. Delete only logs older than this many days.
#*   If not provided or 0, deletes all logs.
#*
#* @response 200 OK. Logs deleted successfully.
#* @response 403 Forbidden. If user not Admin.
#* @response 500 Internal server error.
#*
#* @delete /
function(req, res, older_than_days = 0) {
  require_role(req, res, "Administrator")

  tryCatch(
    {
      older_than_days <- as.integer(older_than_days)

      if (older_than_days > 0) {
        # Delete logs older than specified days
        cutoff_date <- Sys.time() - (older_than_days * 24 * 60 * 60)
        cutoff_str <- format(cutoff_date, "%Y-%m-%d %H:%M:%S")

        # Get count of logs to be deleted
        count_result <- db_execute_query(
          "SELECT COUNT(*) as count FROM logging WHERE timestamp < ?",
          list(cutoff_str)
        )
        deleted_count <- count_result$count[1]

        # Delete old logs
        db_execute_statement(
          "DELETE FROM logging WHERE timestamp < ?",
          list(cutoff_str)
        )

        list(
          message = sprintf("Logs older than %d days deleted successfully.", older_than_days),
          deleted_count = deleted_count,
          cutoff_date = cutoff_str
        )
      } else {
        # Delete all logs
        count_result <- db_execute_query(
          "SELECT COUNT(*) as count FROM logging",
          list()
        )
        deleted_count <- count_result$count[1]

        # Delete all logs
        db_execute_statement(
          "DELETE FROM logging",
          list()
        )

        list(
          message = "All logs deleted successfully.",
          deleted_count = deleted_count
        )
      }
    },
    error = function(e) {
      res$status <- 500
      list(error = paste("Failed to delete logs:", e$message))
    }
  )
}
