# functions/db-helpers.R
#
# Core database helper functions for the repository layer.
# All repository functions should use these helpers for database operations.
#
# Key features:
# - Parameterized queries via dbBind() for SQL injection prevention
# - Automatic connection cleanup via on.exit()
# - Structured error handling via rlang::abort()
# - DEBUG-level logging with parameter sanitization
# - Transaction support with automatic rollback on errors

library(DBI)
library(pool)
library(logger)
library(rlang)
library(tibble)

#' Execute a SELECT query and return results as a tibble
#'
#' Uses the global pool object to execute parameterized SELECT queries.
#' Automatically handles connection cleanup and provides structured error handling.
#'
#' @param sql Character string with SQL query. Use ? for positional placeholders.
#' @param params Unnamed list of parameters in placeholder order. Default: list()
#'
#' @return Tibble of query results. Returns empty tibble (0 rows) if no matches,
#'   never returns NULL.
#'
#' @details
#' - Uses DBI::dbSendQuery() + DBI::dbBind() for parameterized queries
#' - Registers cleanup via on.exit() to ensure result is cleared even on error
#' - Logs query at DEBUG level with sanitized parameters
#' - On error: logs error details and throws db_query_error with structured info
#'
#' @examples
#' \dontrun{
#' # Single parameter
#' db_execute_query("SELECT * FROM ndd_entity WHERE entity_id = ?", list(5))
#'
#' # Multiple parameters (positional order matters)
#' db_execute_query(
#'   "SELECT * FROM ndd_entity WHERE hgnc_id = ? AND is_active = ?",
#'   list(1234, TRUE)
#' )
#'
#' # No parameters
#' db_execute_query("SELECT COUNT(*) as total FROM ndd_entity")
#' }
#'
#' @export
db_execute_query <- function(sql, params = list()) {
  # Sanitize parameters for logging (redact long strings)
  sanitized_params <- lapply(params, function(p) {
    if (is.character(p) && nchar(p) > 50) {
      "[REDACTED]"
    } else if (is.null(p)) {
      "NULL"
    } else {
      as.character(p)
    }
  })

  log_debug("Executing query: {sql}",
            params = paste(sanitized_params, collapse = ", "))

  tryCatch({
    # Send parameterized query to pool
    result <- DBI::dbSendQuery(pool, sql)

    # Register cleanup on exit (even if error occurs)
    on.exit(DBI::dbClearResult(result), add = TRUE)

    # Bind parameters if provided
    if (length(params) > 0) {
      DBI::dbBind(result, params)
    }

    # Fetch all results
    data <- DBI::dbFetch(result)

    # Convert to tibble and ensure we return tibble even if empty
    # (DBI returns data.frame, we want consistent tibble interface)
    return(tibble::as_tibble(data))

  }, error = function(e) {
    log_error("Query execution failed: {e$message}",
              sql = sql,
              params = paste(sanitized_params, collapse = ", "))

    rlang::abort(
      message = paste("Database query failed:", e$message),
      class = "db_query_error",
      sql = sql,
      original_error = e$message
    )
  })
}

#' Execute an INSERT/UPDATE/DELETE statement and return affected row count
#'
#' Uses the global pool object to execute parameterized DML statements.
#' Automatically handles connection cleanup and provides structured error handling.
#'
#' @param sql Character string with SQL statement. Use ? for positional placeholders.
#' @param params Unnamed list of parameters in placeholder order. Default: list()
#'
#' @return Integer count of rows affected by the statement
#'
#' @details
#' - Uses DBI::dbSendStatement() + DBI::dbBind() for parameterized statements
#' - Registers cleanup via on.exit() to ensure result is cleared even on error
#' - Logs statement at DEBUG level with sanitized parameters
#' - Logs affected row count at DEBUG level after execution
#' - On error: logs error details and throws db_statement_error with structured info
#'
#' @examples
#' \dontrun{
#' # INSERT
#' rows <- db_execute_statement(
#'   "INSERT INTO ndd_entity (hgnc_id, ndd_phenotype) VALUES (?, ?)",
#'   list(1234, "Intellectual disability")
#' )
#'
#' # UPDATE
#' rows <- db_execute_statement(
#'   "UPDATE ndd_entity SET is_active = ? WHERE entity_id = ?",
#'   list(FALSE, 5)
#' )
#'
#' # DELETE
#' rows <- db_execute_statement(
#'   "DELETE FROM ndd_entity WHERE entity_id = ?",
#'   list(5)
#' )
#' }
#'
#' @export
db_execute_statement <- function(sql, params = list()) {
  # Sanitize parameters for logging (redact long strings)
  sanitized_params <- lapply(params, function(p) {
    if (is.character(p) && nchar(p) > 50) {
      "[REDACTED]"
    } else if (is.null(p)) {
      "NULL"
    } else {
      as.character(p)
    }
  })

  log_debug("Executing statement: {sql}",
            params = paste(sanitized_params, collapse = ", "))

  tryCatch({
    # Send parameterized statement to pool
    result <- DBI::dbSendStatement(pool, sql)

    # Register cleanup on exit (even if error occurs)
    on.exit(DBI::dbClearResult(result), add = TRUE)

    # Bind parameters if provided
    if (length(params) > 0) {
      DBI::dbBind(result, params)
    }

    # Get affected row count
    affected <- DBI::dbGetRowsAffected(result)

    log_debug("Statement affected {affected} rows")

    return(affected)

  }, error = function(e) {
    log_error("Statement execution failed: {e$message}",
              sql = sql,
              params = paste(sanitized_params, collapse = ", "))

    rlang::abort(
      message = paste("Database statement failed:", e$message),
      class = "db_statement_error",
      sql = sql,
      original_error = e$message
    )
  })
}

#' Execute code within a database transaction
#'
#' Wraps code in a database transaction with automatic commit on success
#' and automatic rollback on any error. Uses the global pool object.
#'
#' @param code Expression to execute within the transaction
#'
#' @return Result of the code execution
#'
#' @details
#' - Checks out a connection from the global pool
#' - Registers connection return via on.exit() for cleanup
#' - Uses DBI::dbWithTransaction() for automatic commit/rollback
#' - Logs transaction lifecycle (start/commit/rollback) at DEBUG level
#' - On error: logs warning with error details and throws db_transaction_error
#'
#' @examples
#' \dontrun{
#' # Create entity with related records (all-or-nothing)
#' result <- db_with_transaction({
#'   # Insert entity
#'   entity_id <- db_execute_statement(
#'     "INSERT INTO ndd_entity (hgnc_id) VALUES (?)",
#'     list(1234)
#'   )
#'
#'   # Get the new entity_id
#'   id_result <- db_execute_query("SELECT LAST_INSERT_ID() as id")
#'   entity_id <- id_result$id[1]
#'
#'   # Insert related review
#'   db_execute_statement(
#'     "INSERT INTO ndd_entity_review (entity_id, synopsis) VALUES (?, ?)",
#'     list(entity_id, "Test synopsis")
#'   )
#'
#'   # Return the entity_id
#'   entity_id
#' })
#' }
#'
#' @export
db_with_transaction <- function(code) {
  log_debug("Starting database transaction")

  # Check out a connection from the pool
  conn <- pool::poolCheckout(pool)

  # Register return on exit (even if error occurs)
  on.exit(pool::poolReturn(conn), add = TRUE)

  tryCatch({
    # Execute code within transaction
    # dbWithTransaction handles BEGIN, COMMIT, and ROLLBACK automatically
    result <- DBI::dbWithTransaction(conn, {
      log_debug("Executing code within transaction")
      force(code)
    })

    log_debug("Transaction committed successfully")

    return(result)

  }, error = function(e) {
    # Transaction automatically rolled back by dbWithTransaction
    log_warn("Transaction rolled back due to error: {e$message}")

    rlang::abort(
      message = paste("Transaction failed:", e$message),
      class = "db_transaction_error",
      original_error = e$message
    )
  })
}
