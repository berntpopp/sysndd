# functions/file-functions.R

require(tidyverse)
require(readr)
require(stringr)
require(fs)
require(lubridate)


#' Replace multiple strings in a text file
#'
#' This function takes in the path to a text file and two vectors: one of strings
#' to find and one of strings to replace them with. It replaces each instance of
#' each string to find with the corresponding string to replace it with, and writes
#' the result to a new text file.
#'
#' @param input_file A character string specifying the path to the text file to
#'   modify.
#' @param output_file A character string specifying the path to write the modified
#'   text file to.
#' @param find_vector A character vector of strings to find in the text file.
#' @param replace_vector A character vector of strings to replace the found strings
#'   with. Must be the same length as find_vector.
#'
#' @importFrom readr read_file write_file
#' @importFrom stringr str_replace_all
#' @importFrom magrittr %>%
#'
#' @return Writes the modified text to a file. No value is returned.
#' @export
#'
#' @examples
#' \dontrun{
#' replace_strings("input.txt", "output.txt",
#'   c("find_this", "find_that"),
#'   c("replace_with_this", "replace_with_that"))
#' }
replace_strings <- function(input_file, output_file, find_vector, replace_vector) {
  # Read the file as a character vector
  text <- read_file(input_file)

  # Check that the find and replace vectors are the same length
  if (length(find_vector) != length(replace_vector)) {
    stop("Find and replace vectors must be the same length")
  }

  # Replace the strings
  new_text <- text
  for (i in seq_along(find_vector)) {
    new_text <- str_replace_all(new_text, pattern = find_vector[i],
        replacement = as.character(replace_vector[i]))
  }

  # Write the new text to a file
  write_file(new_text, output_file)
}


#' Check the age of the most recent file in a directory
#'
#' This function checks the age of the most recent file with a given basename in a
#' specified directory. It returns TRUE if the newest file is younger than the
#' specified duration (in months), and FALSE otherwise.
#'
#' @param file_basename A string. The basename of the files to check.
#' This should be in the format "filename.", e.g. "hpo_list_kidney."
#'
#' @param folder A string. The directory where the files are located.
#'
#' @param months A numeric. The number of months to compare the file's age with.
#'
#' @return A logical. Returns TRUE if the most recent file is younger than the
#' specified number of months, and FALSE otherwise.
#'
#' @examples
#' \dontrun{
#' check_file_age("hpo_list_kidney", "shared/", 1)
#' }
#'
#' @importFrom fs dir_ls
#' @importFrom stringr str_extract
#' @importFrom lubridate as.Date interval months
#'
#' @export
check_file_age <- function(file_basename, folder, months) {

  # Construct the regex pattern for the files
  pattern <- paste0(file_basename, "\\.\\d{4}-\\d{2}-\\d{2}")

  # Get the list of files
  files <- dir_ls(folder, regexp = pattern)

  # If there are no files, we set the time to the start of Unix epoch
  if (length(files) == 0) {
    newest_date <- as.Date("1970-01-01")
  } else {
    # Extract the dates from the file names
    dates <- str_extract(files, "\\d{4}-\\d{2}-\\d{2}")

    # Convert the dates to Date objects
    dates <- as.Date(dates)

    # Get the newest date
    newest_date <- max(dates, na.rm = TRUE)
  }

  # Get the current date
  current_date <- Sys.Date()

  # Compute the difference in months between the current time and the newest file time
  time_diff <- interval(newest_date, current_date) / months(1)

  # Return TRUE if the newest file is older than the specified number of months, and FALSE otherwise
  return(time_diff < months)
}


#' Get the name of the most recent file in a directory
#'
#' This function gets the name of the most recent file with a given basename in a
#' specified directory. It returns the full name of the most recent file.
#'
#' @param file_basename A string. The basename of the files to check.
#' This should be in the format "filename.", e.g. "hpo_list_kidney."
#'
#' @param folder A string. The directory where the files are located.
#'
#' @return A string. Returns the full name of the most recent file.
#'
#' @examples
#' \dontrun{
#' get_newest_file("hpo_list_kidney", "shared/")
#' }
#'
#' @importFrom fs dir_ls
#' @importFrom stringr str_extract
#' @importFrom lubridate as.Date
#'
#' @export
get_newest_file <- function(file_basename, folder) {

  # Construct the regex pattern for the files
  pattern <- paste0(file_basename, "\\.\\d{4}-\\d{2}-\\d{2}")

  # Get the list of files
  files <- dir_ls(folder, regexp = pattern)

  # If there are no files, return NULL
  if (length(files) == 0) {
    return(NULL)
  } else {
    # Extract the dates from the file names
    dates <- str_extract(files, "\\d{4}-\\d{2}-\\d{2}")

    # Convert the dates to Date objects
    dates <- as.Date(dates)

    # Get the newest date
    newest_date <- max(dates, na.rm = TRUE)

    # Get the file(s) with the newest date
    newest_files <- files[dates == newest_date]

    # Return the full name of the most recent file
    return(newest_files)
  }
}


#' Download and Save JSON from PanelApp API Endpoint
#'
#' This function queries the specified PanelApp API endpoint and saves the
#' JSON response to a local file. The saved filename will include the current
#' date in ISO 8601 format. If the `gzip` argument is set to TRUE (default),
#' the file will be saved with a .json.gz extension in gzipped format. Otherwise,
#' it will be saved with a .json extension.
#'
#' @param api_url A character string representing the API endpoint URL from which 
#'        the JSON response will be fetched.
#' @param save_path A character string representing the base path (including filename 
#'        without date) where the JSON response will be saved. The current date in 
#'        ISO 8601 format will be appended to the filename before the extension.
#' @param gzip A logical value indicating whether the JSON file should be gzipped. 
#'        Defaults to TRUE.
#' @return A character string representing the saved filename if successful, 
#'         or an error message otherwise.
#'
#' @examples
#' \dontrun{
#'   api_url <- "https://panelapp.genomicsengland.co.uk/api/v1/panels/283/?format=json"
#'   save_path <- "/path/to/your/directory/283.json"
#'   result <- download_and_save_json(api_url, save_path)
#'   print(result)
#' }
#'
#' @export
download_and_save_json <- function(api_url, save_path, gzip = TRUE) {
  # Get the current date in ISO 8601 format
  date_iso <- format(Sys.Date(), "%Y-%m-%d")

  # Determine the extension based on the gzip argument
  extension <- ifelse(gzip, ".json.gz", ".json")

  # Append the date to the filename before the determined extension
  save_path_with_date <- sub("\\.json$", paste0(".", date_iso, extension), save_path)

  response <- GET(api_url)
  if (status_code(response) == 200) {
    content <- rawToChar(response$content)

    if (gzip) {
      # Write and gzip the content
      gzcon <- gzfile(save_path_with_date, "w")
      writeLines(content, con = gzcon)
      close(gzcon)
    } else {
      writeLines(content, con = save_path_with_date)
    }

    return(save_path_with_date)
  } else {
    return(paste("Failed to fetch data from", api_url))
  }
}
