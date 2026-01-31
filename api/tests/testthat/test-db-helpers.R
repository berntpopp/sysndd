# tests/testthat/test-db-helpers.R
# Unit tests for functions/db-helpers.R
#
# These tests verify the database helper functions that provide the foundation
# for the repository layer. Tests use mocked DBI functions and dependency
# injection via the conn parameter to avoid needing the global pool.

# Source the db-helpers module using helper-paths.R
# Use local = FALSE to make functions available in test scope
source_api_file("functions/db-helpers.R", local = FALSE)

# ============================================================================
# db_execute_query() tests
# ============================================================================

describe("db_execute_query", {

  it("returns tibble for successful query", {
    # Create mock connection object
    mock_conn <- structure(list(), class = "MockConnection")

    mock_result <- structure(
      list(),
      class = c("MariaDBResult", "DBIResult")
    )

    mock_data <- data.frame(
      entity_id = c(1, 2, 3),
      hgnc_id = c(100, 101, 102),
      stringsAsFactors = FALSE
    )

    # Mock DBI functions
    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Call with explicit connection (dependency injection)
    result <- db_execute_query(
      "SELECT * FROM ndd_entity WHERE entity_id = ?",
      list(1),
      conn = mock_conn
    )

    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 3)
    expect_true("entity_id" %in% names(result))
  })

  it("returns empty tibble with correct structure when no rows match", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    # Empty data.frame with correct column structure
    mock_data <- data.frame(
      entity_id = integer(),
      hgnc_id = integer(),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    result <- db_execute_query(
      "SELECT * FROM ndd_entity WHERE entity_id = ?",
      list(999),
      conn = mock_conn
    )

    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 0)
    expect_true("entity_id" %in% names(result))
    expect_true("hgnc_id" %in% names(result))
  })

  it("throws db_query_error on database error", {
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) {
        stop("Table 'ndd_entity' doesn't exist")
      },
      .package = "DBI"
    )

    expect_error(
      db_execute_query("SELECT * FROM ndd_entity", list(), conn = mock_conn),
      class = "db_query_error"
    )
  })

  it("sanitizes long parameters in logs", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))
    mock_data <- data.frame(id = 1, stringsAsFactors = FALSE)

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Capture log messages
    log_messages <- character()
    local_mocked_bindings(
      log_debug = function(msg, ...) {
        log_messages <<- c(log_messages, msg)
        invisible(NULL)
      },
      .package = "logger"
    )

    # Execute query with long string parameter
    long_string <- paste(rep("x", 100), collapse = "")
    result <- db_execute_query(
      "SELECT * FROM test WHERE val = ?",
      list(long_string),
      conn = mock_conn
    )

    # Verify log was called (at least once)
    expect_true(length(log_messages) > 0)
  })

  it("handles NULL parameters correctly", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))
    mock_data <- data.frame(id = 1, stringsAsFactors = FALSE)

    # Track if dbBind was called with NULL
    bind_params <- NULL

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) {
        bind_params <<- params
        invisible(NULL)
      },
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    result <- db_execute_query(
      "SELECT * FROM test WHERE val = ?",
      list(NULL),
      conn = mock_conn
    )

    expect_s3_class(result, "tbl_df")
  })

  it("works without parameters", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))
    mock_data <- data.frame(count = 42L, stringsAsFactors = FALSE)

    bind_called <- FALSE

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) {
        bind_called <<- TRUE
        invisible(NULL)
      },
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    result <- db_execute_query("SELECT COUNT(*) as count FROM test", conn = mock_conn)

    expect_s3_class(result, "tbl_df")
    expect_equal(result$count[1], 42L)
    # dbBind should not be called when no params
    expect_false(bind_called)
  })
})

# ============================================================================
# db_execute_statement() tests
# ============================================================================

describe("db_execute_statement", {

  it("returns affected row count for INSERT", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    affected <- db_execute_statement(
      "INSERT INTO ndd_entity (hgnc_id) VALUES (?)",
      list(1234),
      conn = mock_conn
    )

    expect_type(affected, "integer")
    expect_equal(affected, 1L)
  })

  it("returns affected row count for UPDATE", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 5L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    affected <- db_execute_statement(
      "UPDATE ndd_entity SET is_active = ? WHERE hgnc_id > ?",
      list(FALSE, 1000),
      conn = mock_conn
    )

    expect_equal(affected, 5L)
  })

  it("returns 0 when no rows affected", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 0L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    affected <- db_execute_statement(
      "DELETE FROM ndd_entity WHERE entity_id = ?",
      list(999999),
      conn = mock_conn
    )

    expect_equal(affected, 0L)
  })

  it("throws db_statement_error on database error", {
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) {
        stop("Duplicate entry '1234' for key 'hgnc_id'")
      },
      .package = "DBI"
    )

    expect_error(
      db_execute_statement(
        "INSERT INTO ndd_entity (hgnc_id) VALUES (?)",
        list(1234),
        conn = mock_conn
      ),
      class = "db_statement_error"
    )
  })

  it("logs statement and affected row count", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 3L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Capture log messages
    log_messages <- character()
    local_mocked_bindings(
      log_debug = function(msg, ...) {
        log_messages <<- c(log_messages, msg)
        invisible(NULL)
      },
      .package = "logger"
    )

    affected <- db_execute_statement(
      "UPDATE test SET val = ?",
      list(1),
      conn = mock_conn
    )

    # Should have at least 2 log calls (statement + affected rows)
    expect_true(length(log_messages) >= 2)
  })
})

# ============================================================================
# db_with_transaction() tests
# ============================================================================

describe("db_with_transaction", {

  it("commits transaction on success", {
    # Create a mock pool object
    mock_pool <- structure(list(), class = "MockPool")
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      poolCheckout = function(pool) mock_conn,
      poolReturn = function(conn) invisible(NULL),
      .package = "pool"
    )

    transaction_executed <- FALSE

    local_mocked_bindings(
      dbWithTransaction = function(conn, code) {
        transaction_executed <<- TRUE
        force(code)
      },
      .package = "DBI"
    )

    result <- db_with_transaction({
      "test_result"
    }, pool_obj = mock_pool)

    expect_true(transaction_executed)
    expect_equal(result, "test_result")
  })

  it("rolls back transaction on error", {
    mock_pool <- structure(list(), class = "MockPool")
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      poolCheckout = function(pool) mock_conn,
      poolReturn = function(conn) invisible(NULL),
      .package = "pool"
    )

    # Simulate transaction rollback by throwing error from dbWithTransaction
    local_mocked_bindings(
      dbWithTransaction = function(conn, code) {
        # Force evaluation of code to trigger error
        tryCatch(
          force(code),
          error = function(e) {
            # dbWithTransaction would rollback here
            stop("Transaction rolled back: ", e$message)
          }
        )
      },
      .package = "DBI"
    )

    expect_error(
      db_with_transaction({
        stop("Simulated error in transaction")
      }, pool_obj = mock_pool),
      class = "db_transaction_error"
    )
  })

  it("returns connection to pool even on error", {
    mock_pool <- structure(list(), class = "MockPool")
    mock_conn <- structure(list(), class = "MockConnection")
    pool_returned <- FALSE

    local_mocked_bindings(
      poolCheckout = function(pool) mock_conn,
      poolReturn = function(conn) {
        pool_returned <<- TRUE
        invisible(NULL)
      },
      .package = "pool"
    )

    local_mocked_bindings(
      dbWithTransaction = function(conn, code) {
        stop("Transaction error")
      },
      .package = "DBI"
    )

    expect_error(
      db_with_transaction({ "code" }, pool_obj = mock_pool),
      class = "db_transaction_error"
    )

    # Connection should be returned to pool even though error occurred
    expect_true(pool_returned)
  })

  it("logs transaction lifecycle", {
    mock_pool <- structure(list(), class = "MockPool")
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      poolCheckout = function(pool) mock_conn,
      poolReturn = function(conn) invisible(NULL),
      .package = "pool"
    )

    local_mocked_bindings(
      dbWithTransaction = function(conn, code) force(code),
      .package = "DBI"
    )

    log_messages <- character()
    local_mocked_bindings(
      log_debug = function(msg, ...) {
        log_messages <<- c(log_messages, msg)
        invisible(NULL)
      },
      log_warn = function(msg, ...) {
        log_messages <<- c(log_messages, msg)
        invisible(NULL)
      },
      .package = "logger"
    )

    result <- db_with_transaction({ "success" }, pool_obj = mock_pool)

    # Should have logged: start, executing, and commit
    expect_true(length(log_messages) >= 3)
  })

  it("can execute multiple statements in transaction", {
    mock_pool <- structure(list(), class = "MockPool")
    mock_conn <- structure(list(), class = "MockConnection")

    local_mocked_bindings(
      poolCheckout = function(pool) mock_conn,
      poolReturn = function(conn) invisible(NULL),
      .package = "pool"
    )

    statements_executed <- 0

    local_mocked_bindings(
      dbWithTransaction = function(conn, code) {
        force(code)
      },
      .package = "DBI"
    )

    # Mock the statement execution tracking
    result <- db_with_transaction({
      statements_executed <- statements_executed + 1
      statements_executed <- statements_executed + 1
      statements_executed <- statements_executed + 1
      statements_executed
    }, pool_obj = mock_pool)

    expect_equal(result, 3)
  })
})

# ============================================================================
# db_execute_statement() NA handling tests
# ============================================================================

describe("db_execute_statement NA parameter handling", {

  it("handles NA values in parameters without error", {
    # The sanitized_params logic should not throw "missing value where
    # TRUE/FALSE needed" when parameters contain NA values

    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Test with NA character value - this was causing the original bug
    expect_no_error(
      db_execute_statement(
        "INSERT INTO test (col1, col2) VALUES (?, ?)",
        list("value1", NA_character_),
        conn = mock_conn
      )
    )
  })

  it("handles mixed NA types in parameters", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Test with various NA types
    expect_no_error(
      db_execute_statement(
        "INSERT INTO test (a, b, c, d) VALUES (?, ?, ?, ?)",
        list(NA_character_, NA_integer_, NA_real_, NA),
        conn = mock_conn
      )
    )
  })

  it("handles NULL values in parameters", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    expect_no_error(
      db_execute_statement(
        "INSERT INTO test (col1, col2) VALUES (?, ?)",
        list("value1", NULL),
        conn = mock_conn
      )
    )
  })

  it("handles long strings that need redaction", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Long string > 50 chars should be redacted in logs but not cause errors
    long_string <- paste(rep("a", 100), collapse = "")
    expect_no_error(
      db_execute_statement(
        "INSERT INTO test (col1) VALUES (?)",
        list(long_string),
        conn = mock_conn
      )
    )
  })

  it("handles combination of NA, NULL, long strings, and normal values", {
    mock_conn <- structure(list(), class = "MockConnection")
    mock_result <- structure(list(), class = c("MariaDBResult", "DBIResult"))

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbGetRowsAffected = function(result) 1L,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    # Complex combination of parameter types
    long_json <- paste0('{"data": "', paste(rep("x", 100), collapse = ""), '"}')
    expect_no_error(
      db_execute_statement(
        "INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)",
        list("normal", NA_character_, NULL, 42, long_json),
        conn = mock_conn
      )
    )
  })
})
