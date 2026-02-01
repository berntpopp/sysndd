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
library(RMariaDB)
library(logger)
library(rlang)
library(tibble)

#' Get database connection (pool or fallback to direct connection for daemons)
#'
#' In main process, returns the global pool. In mirai daemons (where pool
#' doesn't exist), uses daemon_db_conn if available, otherwise creates a new connection.
#'
#' @return Pool object or direct DBI connection
#' @keywords internal
get_db_connection <- function() {
  message("[get_db_connection] ENTRY")
  # If pool exists in global environment, use it (main process)
  if (base::exists("pool", envir = .GlobalEnv) && !is.null(base::get("pool", envir = .GlobalEnv))) {
    return(base::get("pool", envir = .GlobalEnv))
  }

  # If daemon_db_conn exists in global environment, validate and use it
  if (base::exists("daemon_db_conn", envir = .GlobalEnv) && !is.null(base::get("daemon_db_conn", envir = .GlobalEnv))) {
    conn <- base::get("daemon_db_conn", envir = .GlobalEnv)

    # Validate connection is still alive (fixes "bad_weak_ptr" errors)
    conn_valid <- tryCatch({
      DBI::dbIsValid(conn)
    }, error = function(e) {
      message("[get_db_connection] Connection validation failed: ", e$message)
      FALSE
    })

    if (conn_valid) {
      return(conn)
    } else {
      message("[get_db_connection] daemon_db_conn invalid, will create new connection")
      # Remove invalid connection
      base::rm("daemon_db_conn", envir = .GlobalEnv)
    }
  }

  # Fallback for mirai daemons: create direct connection from config.yml
  # This is needed because mirai daemons run in separate R processes without
  # access to the main process's pool object

  # First try environment variables (for CI and explicit config)
  host <- Sys.getenv("MYSQL_HOST", "")
  port <- as.integer(Sys.getenv("MYSQL_PORT", "3306"))
  dbname <- Sys.getenv("MYSQL_DATABASE", "")
  user <- Sys.getenv("MYSQL_USER", "")
  password <- Sys.getenv("MYSQL_PASSWORD", "")

  # If env vars not set, read from config.yml (primary config for Docker)
  if (user == "" || dbname == "") {
    config_path <- if (file.exists("/app/config.yml")) "/app/config.yml" else "config.yml"
    if (file.exists(config_path) && requireNamespace("config", quietly = TRUE)) {
      cfg <- config::get(file = config_path)
      # Read sysndd_db section if it exists
      db_config <- cfg$sysndd_db %||% cfg
      host <- db_config$host %||% host %||% "mysql"
      port <- as.integer(db_config$port %||% port %||% 3306)
      dbname <- db_config$dbname %||% dbname %||% "sysndd_db"
      user <- db_config$user %||% user
      password <- db_config$password %||% password
    }
  }

  # Create direct connection
  message("[get_db_connection] Creating new daemon connection to ", host, ":", port, "/", dbname)
  conn <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = host,
    port = port,
    dbname = dbname,
    user = user,
    password = password
  )

  # Store in global environment for reuse within this daemon
  base::assign("daemon_db_conn", conn, envir = .GlobalEnv)
  message("[get_db_connection] New daemon connection created and stored")

  return(conn)
}

#' Execute a SELECT query and return results as a tibble
#'
#' Uses the global pool object (or provided connection) to execute parameterized
#' SELECT queries. Automatically handles connection cleanup and provides
#' structured error handling.
#'
#' @param sql Character string with SQL query. Use ? for positional placeholders.
#' @param params Unnamed list of parameters in placeholder order. Default: list()
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'   This parameter enables dependency injection for testing.
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
#'
#' # With explicit connection (for testing)
#' db_execute_query("SELECT 1", list(), conn = mock_conn)
#' }
#'
#' @export
db_execute_query <- function(sql, params = list(), conn = NULL) {
  message("[db_execute_query] ENTRY - sql: ", substr(sql, 1, 50))
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
    params = paste(sanitized_params, collapse = ", ")
  )

  tryCatch(
    {
      # Determine if we have a pool or a direct connection
      use_pool <- if (is.null(conn)) get_db_connection() else conn
      is_pool_obj <- inherits(use_pool, "Pool")
      is_direct_conn <- inherits(use_pool, "MariaDBConnection") || inherits(use_pool, "DBIConnection")

      # Check if this is the daemon_db_conn (managed externally, don't disconnect)
      is_daemon_conn <- base::exists("daemon_db_conn", envir = .GlobalEnv) &&
                        identical(use_pool, base::get("daemon_db_conn", envir = .GlobalEnv))

      if (is_pool_obj) {
        # For pool objects: checkout connection, use it, return it
        use_conn <- pool::poolCheckout(use_pool)
        on.exit(pool::poolReturn(use_conn), add = TRUE)
      } else if (is_direct_conn && !is_daemon_conn && is.null(conn)) {
        # Direct connection created by get_db_connection() fallback - disconnect after use
        use_conn <- use_pool
        on.exit(DBI::dbDisconnect(use_conn), add = TRUE)
      } else {
        # Direct connection provided by caller or daemon_db_conn (managed externally)
        use_conn <- use_pool
      }

      # Send parameterized query to connection
      result <- DBI::dbSendQuery(use_conn, sql)

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
    },
    error = function(e) {
      log_error("Query execution failed: {e$message}",
        sql = sql,
        params = paste(sanitized_params, collapse = ", ")
      )

      rlang::abort(
        message = paste("Database query failed:", e$message),
        class = "db_query_error",
        sql = sql,
        original_error = e$message
      )
    }
  )
}

#' Execute an INSERT/UPDATE/DELETE statement and return affected row count
#'
#' Uses the global pool object (or provided connection) to execute parameterized
#' DML statements. Automatically handles connection cleanup and provides
#' structured error handling.
#'
#' @param sql Character string with SQL statement. Use ? for positional placeholders.
#' @param params Unnamed list of parameters in placeholder order. Default: list()
#' @param conn Optional database connection or pool object. If NULL, uses global pool.
#'   This parameter enables dependency injection for testing.
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
#'
#' # With explicit connection (for testing)
#' db_execute_statement("DELETE FROM test WHERE id = ?", list(1), conn = mock_conn)
#' }
#'
#' @export
db_execute_statement <- function(sql, params = list(), conn = NULL) {
  message("[db_execute_statement] ENTRY - sql: ", substr(sql, 1, 50))
  # Sanitize parameters for logging (redact long strings)
  sanitized_params <- lapply(params, function(p) {
    if (is.null(p) || (length(p) == 1 && is.na(p))) {
      "NULL"
    } else if (is.character(p) && !is.na(p) && nchar(p) > 50) {
      "[REDACTED]"
    } else {
      as.character(p)
    }
  })

  log_debug("Executing statement: {sql}",
    params = paste(sanitized_params, collapse = ", ")
  )

  tryCatch(
    {
      # Determine if we have a pool or a direct connection
      use_pool <- if (is.null(conn)) get_db_connection() else conn
      is_pool_obj <- inherits(use_pool, "Pool")
      is_direct_conn <- inherits(use_pool, "MariaDBConnection") || inherits(use_pool, "DBIConnection")

      # Check if this is the daemon_db_conn (managed externally, don't disconnect)
      is_daemon_conn <- base::exists("daemon_db_conn", envir = .GlobalEnv) &&
                        identical(use_pool, base::get("daemon_db_conn", envir = .GlobalEnv))

      if (is_pool_obj) {
        # For pool objects: checkout connection, use it, return it
        use_conn <- pool::poolCheckout(use_pool)
        on.exit(pool::poolReturn(use_conn), add = TRUE)
      } else if (is_direct_conn && !is_daemon_conn && is.null(conn)) {
        # Direct connection created by get_db_connection() fallback - disconnect after use
        use_conn <- use_pool
        on.exit(DBI::dbDisconnect(use_conn), add = TRUE)
      } else {
        # Direct connection provided by caller or daemon_db_conn (managed externally)
        use_conn <- use_pool
      }

      # Send parameterized statement to connection
      result <- DBI::dbSendStatement(use_conn, sql)

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
    },
    error = function(e) {
      log_error("Statement execution failed: {e$message}",
        sql = sql,
        params = paste(sanitized_params, collapse = ", ")
      )

      rlang::abort(
        message = paste("Database statement failed:", e$message),
        class = "db_statement_error",
        sql = sql,
        original_error = e$message
      )
    }
  )
}

#' Execute code within a database transaction
#'
#' Wraps code in a database transaction with automatic commit on success
#' and automatic rollback on any error. Uses the global pool object or
#' provided pool.
#'
#' @param code Expression to execute within the transaction
#' @param pool_obj Optional pool object. If NULL, uses global pool.
#'   This parameter enables dependency injection for testing.
#'
#' @return Result of the code execution
#'
#' @details
#' - Checks out a connection from the pool
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
db_with_transaction <- function(code, pool_obj = NULL) {
  # Use provided pool or fallback to global pool or create direct connection
  use_pool <- if (!is.null(pool_obj)) pool_obj else get_db_connection()
  is_pool_obj <- inherits(use_pool, "Pool")
  is_direct_conn <- inherits(use_pool, "MariaDBConnection") || inherits(use_pool, "DBIConnection")
  created_direct_conn <- FALSE

  log_debug("Starting database transaction")

  if (is_pool_obj) {
    # Check out a connection from the pool
    conn <- pool::poolCheckout(use_pool)
    # Register return on exit (even if error occurs)
    on.exit(pool::poolReturn(conn), add = TRUE)
  } else if (is_direct_conn && is.null(pool_obj)) {
    # Direct connection created by get_db_connection() - we need to disconnect later
    conn <- use_pool
    created_direct_conn <- TRUE
    on.exit(DBI::dbDisconnect(conn), add = TRUE)
  } else {
    # Direct connection provided by caller
    conn <- use_pool
  }

  tryCatch(
    {
      # Execute code within transaction
      # dbWithTransaction handles BEGIN, COMMIT, and ROLLBACK automatically
      result <- DBI::dbWithTransaction(conn, {
        log_debug("Executing code within transaction")
        # If code is a function, call it with the connection
        # Otherwise evaluate the expression
        if (is.function(code)) {
          code(conn)
        } else {
          force(code)
        }
      })

      log_debug("Transaction committed successfully")

      return(result)
    },
    error = function(e) {
      # Transaction automatically rolled back by dbWithTransaction
      log_warn("Transaction rolled back due to error: {e$message}")

      rlang::abort(
        message = paste("Transaction failed:", e$message),
        class = "db_transaction_error",
        original_error = e$message
      )
    }
  )
}
