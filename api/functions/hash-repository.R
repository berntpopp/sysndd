# functions/hash-repository.R
#
# Hash domain repository - handles database operations for table hash caching.
# Uses db-helpers for parameterized queries and automatic connection cleanup.
#
# Key features:
# - Hash persistence for API response caching
# - Column name validation for security (prevents arbitrary table access)
# - Hash generation happens in endpoint layer (this only handles persistence)
# - All queries use parameterized SQL via db_execute_query/db_execute_statement

library(tibble)
library(logger)

#' Find hash record by hash value
#'
#' Retrieves hash record including JSON text and target endpoint.
#' Used to retrieve cached API responses by hash.
#'
#' @param hash_value Character SHA-256 hash value
#' @return Tibble with hash_id, hash_256, json_text, target_endpoint.
#'   Returns empty tibble if hash not found.
#'
#' @examples
#' \dontrun{
#' cached <- hash_find_by_value("abc123...")
#' if (nrow(cached) > 0) {
#'   json_response <- cached$json_text[1]
#' }
#' }
#'
#' @export
hash_find_by_value <- function(hash_value) {
  sql <- "SELECT hash_id, hash_256, json_text, target_endpoint FROM table_hash WHERE hash_256 = ?"
  db_execute_query(sql, list(hash_value))
}

#' Check if hash exists
#'
#' Efficient existence check without retrieving full hash data.
#'
#' @param hash_value Character SHA-256 hash value
#' @return Logical TRUE if hash exists, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' if (hash_exists("abc123...")) {
#'   # Hash already cached
#' }
#' }
#'
#' @export
hash_exists <- function(hash_value) {
  sql <- "SELECT 1 FROM table_hash WHERE hash_256 = ? LIMIT 1"
  result <- db_execute_query(sql, list(hash_value))
  nrow(result) > 0
}

#' Create new hash record
#'
#' Stores a hash value with associated JSON text and target endpoint.
#' Used to cache API responses for future retrieval.
#'
#' Note: Hash generation (SHA-256) happens in endpoint layer.
#' This function only handles database persistence.
#'
#' @param hash_value Character SHA-256 hash value
#' @param json_text Character JSON text to cache
#' @param endpoint Character target endpoint name
#'
#' @return Character hash_value (returns the input hash for consistency with existing API pattern)
#'
#' @examples
#' \dontrun{
#' hash_val <- hash_create(
#'   hash_value = "abc123...",
#'   json_text = '{"data": [...]}',
#'   endpoint = "entities"
#' )
#' }
#'
#' @export
hash_create <- function(hash_value, json_text, endpoint) {
  # Validate hash_value is not empty
  if (is.null(hash_value) || is.na(hash_value) || nchar(hash_value) == 0) {
    rlang::abort(
      message = "hash_value cannot be NULL, NA, or empty",
      class = "hash_validation_error"
    )
  }

  sql <- "INSERT INTO table_hash (hash_256, json_text, target_endpoint) VALUES (?, ?, ?)"

  db_execute_statement(sql, list(hash_value, json_text, endpoint))

  # Return hash_value for consistency with existing API pattern
  # (existing code expects hash value back, not hash_id)
  hash_value
}

#' Validate column names against whitelist
#'
#' Security check to ensure only allowed column names are used in hash operations.
#' Prevents arbitrary table/column access via hash endpoint.
#'
#' @param column_names Character vector of column names to validate
#' @param allowed_columns Character vector of allowed column names
#'
#' @return Logical TRUE if all columns are valid
#' @throws hash_column_validation_error if any column is not in allowed list
#'
#' @examples
#' \dontrun{
#' hash_validate_columns(
#'   c("entity_id", "hgnc_id"),
#'   c("entity_id", "hgnc_id", "symbol", "disease_ontology_id_version")
#' )
#' # Returns TRUE
#'
#' hash_validate_columns(
#'   c("entity_id", "malicious_column"),
#'   c("entity_id", "hgnc_id")
#' )
#' # Throws error with invalid_columns = "malicious_column"
#' }
#'
#' @export
hash_validate_columns <- function(column_names, allowed_columns) {
  # Find invalid columns (not in allowed list)
  invalid <- setdiff(column_names, allowed_columns)

  if (length(invalid) > 0) {
    rlang::abort(
      message = paste(
        "The submitted column names are not in the allowed allowed_columns list:",
        paste(invalid, collapse = ", ")
      ),
      class = "hash_column_validation_error",
      invalid_columns = invalid
    )
  }

  TRUE
}
