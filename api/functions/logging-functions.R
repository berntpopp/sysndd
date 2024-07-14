#### This file holds logging functions

#' Read and Combine Log Files into a Tibble
#'
#' @description
#' `read_log_files` reads log files from a specified folder, combines them into a tibble, 
#' and adds metadata including the filename and last modification time. It allows for 
#' customizable regular expressions, delimiters, quotes, and column names.
#' The function performs the following operations:
#' 1. Validates the folder path and the regular expression for file selection.
#' 2. Lists all log files in the specified folder based on the regular expression.
#' 3. Reads each log file into a tibble, adding columns for the file name and last modified time.
#' 4. Combines all the individual tibbles into a single tibble.
#' 5. Sorts the combined tibble by the last modification time, with the newest entries on top.
#'
#' @param folder_path A string specifying the path to the folder containing log files.
#' @param regexp Regular expression pattern to match log file names. Default is "plumber_*".
#' @param delim The field delimiter in the log files. Default is ";".
#' @param quote The quoting character in the log files. Default is "'".
#' @param col_names A comma-separated string of column names for the log files. 
#'   Default includes standard log fields: "remote_addr,http_user_agent,http_host,
#'   request_method,path_info,query_string,postbody,status,duration".
#'
#' @return A tibble where each row is a log entry, augmented with columns for the file name 
#'   and last modified time. The tibble is sorted by the last modification time in descending order.
#'
#' @examples
#' # Example usage of read_log_files
#' combined_logs <- read_log_files(
#'   folder_path = "path/to/logs",
#'   regexp = "plumber_*",
#'   delim = ";",
#'   quote = "'"
#' )
#'
#' @export
read_log_files <- function(folder_path, regexp = "plumber_*", delim = ";", quote = "'", 
                           col_names = "remote_addr,http_user_agent,http_host,request_method,path_info,query_string,postbody,status,duration") {
  # Parameter Validation
  if (!dir.exists(folder_path)) {
    stop("The specified folder does not exist.")
  }

  # Validate col_names
  col_names_vec <- unlist(strsplit(col_names, ","))
  if (length(col_names_vec) == 0 || any(col_names_vec == "")) {
    stop("Column names must be a non-empty, comma-separated string.")
  }
  if (anyDuplicated(col_names_vec)) {
    stop("Duplicate column names are not allowed.")
  }

  # List all log files in the folder based on the provided regular expression
  log_files <- fs::dir_ls(folder_path, regexp = regexp)
  if (length(log_files) == 0) {
    stop("No files found matching the specified pattern.")
  }

  # Function to read a single log file and return a tibble
  read_log_file <- function(file_path) {
    tryCatch({
      file_name <- fs::path_file(file_path)
      file_mod_time <- fs::file_info(file_path)$modification_time

      # Read the log file into a tibble with show_col_types set to FALSE
      log_data <- read_delim(file_path, delim = delim, quote = quote, 
                            escape_double = FALSE, col_names = FALSE, 
                            trim_ws = TRUE, show_col_types = FALSE)

      # Handle missing columns
      if (ncol(log_data) != length(col_names_vec)) {
        warning(sprintf("Column count mismatch in file '%s'", file_path))
        return(NULL)
      }

      # Assign column names
      setNames(log_data, col_names_vec) %>%
        mutate(filename = file_name, last_modified = file_mod_time)
    }, error = function(e) {
      warning(sprintf("Failed to read file '%s': %s", file_path, e$message))
      return(NULL)
    })
  }

  # Read all files, combine into a single tibble, and sort by last_modified
  combined_logs <- map_dfr(log_files, read_log_file) %>%
    arrange(desc(last_modified))

  # Add a unique identifier (row number) as the first column
  combined_logs <- combined_logs %>% 
    mutate(row_id = row_number())

  # Rearrange columns to move row_id to the first position
  combined_logs <- combined_logs %>% 
    select(row_id, everything())

  return(combined_logs)
}


#' Convert Empty Strings to a Placeholder
#'
#' @description
#' `convert_empty` is a helper function designed to handle empty strings in log data.
#' It replaces any empty string with a specified placeholder, "-" by default. This function
#' is particularly useful when processing log files or data where empty fields need to be
#' represented by a placeholder for better readability or consistency.
#'
#' @param string A character string to be checked for emptiness.
#'
#' @return The original string if it is not empty; otherwise, returns the placeholder "-".
#'
#' @examples
#' convert_empty("") # returns "-"
#' convert_empty("example") # returns "example"
#'
#' @export
convert_empty <- function(string) {
  if (string == "") {
    "-"
  } else {
    string
  }
}


#' Log Message to Database
#'
#' @description
#' `log_message_to_db` logs a message to the specified database logging table.
#' This function connects to the database, inserts the log message, and then disconnects.
#'
#' @param address A character string containing the IP address.
#' @param agent A character string containing the user agent.
#' @param host A character string containing the host.
#' @param request_method A character string containing the request method.
#' @param path A character string containing the path.
#' @param query A character string containing the query string.
#' @param post A character string containing the post body.
#' @param status A character string containing the response status.
#' @param duration A numeric value containing the request duration.
#' @param file A character string containing the log file name.
#' @param modified A character string containing the last modified time.
#'
#' @examples
#' log_message_to_db("127.0.0.1", "user_agent", "localhost", "GET", "/path", "query", "post_body", "200", 0.123, "logfile.log", "2024-07-07 12:34:56")
#'
#' @export
log_message_to_db <- function(address, agent, host, request_method, path, query, post, status, duration, file, modified) {
  con <- NULL
  tryCatch({
    con <- dbConnect(RMariaDB::MariaDB(),
                     dbname = dw$dbname,
                     user = dw$user,
                     password = dw$password,
                     host = dw$host,
                     port = dw$port)
    query <- sprintf("INSERT INTO logging (timestamp, address, agent, host, request_method, path, query, post, status, duration, file, modified) VALUES (NOW(), '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %f, '%s', '%s')",
                     address, agent, host, request_method, path, query, post, status, duration, file, modified)

    dbExecute(con, query)
  }, error = function(e) {
    warning(sprintf("Failed to log message to database: %s", e$message))
  }, finally = {
    if (!is.null(con)) {
      dbDisconnect(con)
    }
  })
}
