# functions/data-helpers.R
#### Hashing, file generation, and data utility helpers
#### (generate_panel_hash, generate_json_hash, generate_function_hash,
####  generate_xlsx_bin, post_db_hash)
#### Split from helper-functions.R in v11.0 phase D2.
####
#### Dependencies (loaded by start_sysndd_api.R):
####   openssl (sha256), stringr, openxlsx (write.xlsx), jsonlite (toJSON, fromJSON),
####   dplyr, tibble, rlang


#' Generate a hash for a HGNC gene or entity list
#'
#' @description
#' This function generates a hash for a list of HGNC gene or entity identifiers.
#' It removes the "HGNC:" prefix if present, sorts the identifiers, concatenates
#' them, and computes the SHA-256 hash.
#'
#' @param identifier_list A character vector containing the HGNC gene or entity
#'   identifiers for which to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' genes <- c("HGNC:12345", "HGNC:67890")
#' generate_panel_hash(genes)
#'
#' @export
generate_panel_hash <- function(identifier_list) {
  # remove hgnc pre-attachment if present,
  # sort, concatenate and compute sha256 hash
  list_hash <- identifier_list %>%
    str_remove("HGNC:") %>%
    sort() %>%
    str_c(collapse = ",") %>%
    sha256()

  # return result
  return(list_hash)
}


#' Generate a hash for a JSON object
#'
#' @description
#' This function generates a hash for a JSON object. It computes the SHA-256
#' hash for the given JSON input.
#'
#' @param json_input A character string containing the JSON object for which
#'   to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' json_string <- '{"key": "value"}'
#' generate_json_hash(json_string)
#'
#' @export
generate_json_hash <- function(json_input) {
  # compute sha256 hash
  json_hash <- json_input %>%
    sha256()

  # return result
  return(json_hash)
}


#' Generate a hash for a function
#'
#' @description
#' This function generates a hash for a given function. It deparses the function
#' input and computes the SHA-256 hash.
#'
#' @param function_input A function object for which to generate the hash.
#'
#' @return
#' A character string containing the computed SHA-256 hash.
#'
#' @examples
#' sample_function <- function(x) { x + 1 }
#' generate_function_hash(sample_function)
#'
#' @export
generate_function_hash <- function(function_input) {
  # deparse function, compute sha256 hash
  function_hash <- function_input %>%
    deparse1() %>%
    sha256()

  # return result
  return(function_hash)
}


#' Generate an xlsx file and return its binary info
#'
#' @description
#'
#' generate_xlsx_bin is an R function that creates a temporary
#' Excel (xlsx) file with three sheets:'data', 'meta', and 'links',
#' populated with the corresponding data from a given data object.
#' The function then reads the binary content of the generated
#' xlsx file and returns it. The temporary file is deleted
#' once the binary content is read.
#' The function performs the following steps:
#'
#' 1. Generate a temporary xlsx file path.
#' 2. Write the 'data' element of the data object to the 'data' sheet.
#' 3. Write the 'meta' element of the data object to the 'meta' sheet,
#' excluding the 'fspec' column if present.
#' 4. Write the 'links' element of the data object to the 'links' sheet.
#' 5. Read the binary content of the generated xlsx file.
#' 6. Delete the temporary xlsx file.
#' 7. Return the binary content of the file.
#'
#' @param data_object A list containing three elements: 'data', 'meta', and 'links', each containing a data frame to be written to the respective sheets in the output Excel file. # nolint: line_length_linter
#' @param file_base_name A string representing the base name to be used for the temporary Excel file.
#'
#' @return The binary content of the generated xlsx file as a raw vector
#' @export
generate_xlsx_bin <- function(data_object, file_base_name) {
  # generate excel file output
  xlsx_file <- file.path(
    tempdir(),
    paste0(file_base_name, ".xlsx")
  )

  # Convert nested data columns to JSON strings for Excel compatibility
  data_export <- data_object$data %>%
    mutate(across(where(is.list), ~ sapply(., function(x) {
      if (is.null(x) || (is.atomic(x) && length(x) == 1)) {
        as.character(x)
      } else {
        jsonlite::toJSON(x, auto_unbox = TRUE)
      }
    })))

  write.xlsx(data_export,
    xlsx_file,
    sheetName = "data",
    append = FALSE
  )

  # Convert nested fspec column to JSON string for Excel export
  # This preserves all metadata - requires JSON parsing on import
  meta_export <- data_object$meta %>%
    mutate(across(where(is.list), ~ sapply(., function(x) {
      if (is.null(x) || (is.atomic(x) && length(x) == 1)) {
        as.character(x)
      } else {
        jsonlite::toJSON(x, auto_unbox = TRUE)
      }
    })))

  write.xlsx(
    meta_export,
    xlsx_file,
    sheetName = "meta",
    append = TRUE
  )

  write.xlsx(data_object$links,
    xlsx_file,
    sheetName = "links",
    append = TRUE
  )

  # Read in the raw contents of the binary file
  bin <- readBin(xlsx_file, "raw", n = file.info(xlsx_file)$size)

  # Check file existence and delete
  if (file.exists(xlsx_file)) {
    file.remove(xlsx_file)
  }

  # return the binary contents
  return(bin)
}


#' Calculate and post a hash for a series of column values
#'
#' This function calculates and posts a hash for a series of column values
#' given as a JSON input. The column names in the JSON input can be
#' controlled with the 'allowed_columns' parameter. The resulting hash is
#' stored in the 'table_hash' table in the database.
#'
#' @param json_data JSON input containing the data to hash
#' @param allowed_columns comma-separated list of column names to allow
#' in the JSON input, defaults to "symbol,hgnc_id,entity_id"
#' @param endpoint endpoint to hash, defaults to "/api/gene"
#'
#' @return A list object with the following components:
#' \item{links}{a tibble with a link to the stored hash in the format
#' "equals(hash, hash_value)"}
#' \item{status}{HTTP status code}
#' \item{message}{message related to the request status}
#' \item{data}{the resulting hash value}
#'
#' @export
#' @seealso generate_json_hash()
post_db_hash <- function(
  json_data,
  allowed_columns = "symbol,hgnc_id,entity_id",
  endpoint = "/api/gene"
) {
  # generate list of allowed term from input
  allowed_col_list <- (allowed_columns %>%
                         str_split(pattern = ","))[[1]]

  ## -------------------------------------------------------------------##
  # block to convert the json list into tibble
  # then sort it
  # check if the column name is in the allowed identifier list
  # then convert back to JSON and hash it
  # '!!!' in arrange needed to evaluate the external variable as column name
  json_tibble <- as_tibble(json_data)
  json_tibble <- json_tibble %>%
    arrange(!!!rlang::parse_exprs((json_tibble %>% colnames())[1]))

  json_sort <- toJSON(json_tibble)
  ## -------------------------------------------------------------------##


  ## -------------------------------------------------------------------##
  # block to generate hash and check if present in data
  json_sort_hash <- as.character(generate_json_hash(json_sort))

  # Check if database is available (pool exists)
  # In mirai daemon context, pool is not available
  db_available <- tryCatch({
    exists("pool") && !is.null(pool)
  }, error = function(e) FALSE)

  if (!db_available) {
    # Database not available (daemon context) - compute hash only
    # The hash string is still usable, just not registered in database
    links <- as_tibble(list(
      "hash" = paste0("equals(hash,", json_sort_hash, ")")
    ))
    return(list(
      links = links,
      status = 200,
      message = "OK. Hash computed (no database).",
      data = json_sort_hash
    ))
  }

  # validate columns using hash repository
  hash_validate_columns(colnames(json_tibble), allowed_col_list)

  # check if hash exists using repository
  hash_already_exists <- hash_exists(json_sort_hash)
  ## -------------------------------------------------------------------##

  if (!hash_already_exists) {
    # use hash repository to create hash
    hash_create(json_sort_hash, as.character(json_sort), endpoint)

    # generate links object
    links <- as_tibble(list(
      "hash" =
        paste0("equals(hash,", json_sort_hash, ")")
    ))

    # generate object to return
    return(list(
      links = links,
      status = 200,
      message = "OK. Hash created.",
      data = json_sort_hash
    ))
  } else {
    # generate links object
    links <- as_tibble(list(
      "hash" =
        paste0("equals(hash,", json_sort_hash, ")")
    ))

    # generate object to return
    return(list(
      links = links,
      status = 200,
      message = "OK. Hash already present.",
      data = json_sort_hash
    ))
  }
}
