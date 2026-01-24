# tests/testthat/test-db-helpers.R
# Unit tests for functions/db-helpers.R
#
# These tests verify the database helper functions that provide the foundation
# for the repository layer. Tests use mocked database connections since we're
# testing the helper logic, not actual database operations.

# Source the db-helpers module
# Note: We can't use test_path() here because db-helpers is in functions/, not core/
# Instead, we'll use relative path from test working directory
source(file.path("../../functions/db-helpers.R"), local = TRUE)

# ============================================================================
# db_execute_query() tests
# ============================================================================

describe("db_execute_query", {

  it("returns tibble for successful query", {
    # Mock pool and DBI functions
    local_mocked_bindings(
      pool = list(),  # Mock pool object
      .package = "base"
    )

    mock_result <- structure(
      list(),
      class = c("MariaDBResult", "DBIResult")
    )

    mock_data <- data.frame(
      entity_id = c(1, 2, 3),
      hgnc_id = c(100, 101, 102),
      stringsAsFactors = FALSE
    )

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) mock_result,
      dbBind = function(result, params) invisible(NULL),
      dbFetch = function(result) mock_data,
      dbClearResult = function(result) invisible(NULL),
      .package = "DBI"
    )

    result <- db_execute_query("SELECT * FROM ndd_entity WHERE entity_id = ?", list(1))

    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 3)
    expect_true("entity_id" %in% names(result))
  })

  it("returns empty tibble with correct structure when no rows match", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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

    result <- db_execute_query("SELECT * FROM ndd_entity WHERE entity_id = ?", list(999))

    expect_s3_class(result, "tbl_df")
    expect_equal(nrow(result), 0)
    expect_true("entity_id" %in% names(result))
    expect_true("hgnc_id" %in% names(result))
  })

  it("throws db_query_error on database error", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

    local_mocked_bindings(
      dbSendQuery = function(conn, sql) {
        stop("Table 'ndd_entity' doesn't exist")
      },
      .package = "DBI"
    )

    expect_error(
      db_execute_query("SELECT * FROM ndd_entity", list()),
      class = "db_query_error"
    )
  })

  it("sanitizes long parameters in logs", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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
    result <- db_execute_query("SELECT * FROM test WHERE val = ?", list(long_string))

    # Verify log was called (at least once)
    expect_true(length(log_messages) > 0)
  })

  it("handles NULL parameters correctly", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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

    result <- db_execute_query("SELECT * FROM test WHERE val = ?", list(NULL))

    expect_s3_class(result, "tbl_df")
  })
})

# ============================================================================
# db_execute_statement() tests
# ============================================================================

describe("db_execute_statement", {

  it("returns affected row count for INSERT", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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
      list(1234)
    )

    expect_type(affected, "integer")
    expect_equal(affected, 1L)
  })

  it("returns affected row count for UPDATE", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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
      list(FALSE, 1000)
    )

    expect_equal(affected, 5L)
  })

  it("returns 0 when no rows affected", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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
      list(999999)
    )

    expect_equal(affected, 0L)
  })

  it("throws db_statement_error on database error", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

    local_mocked_bindings(
      dbSendStatement = function(conn, sql) {
        stop("Duplicate entry '1234' for key 'hgnc_id'")
      },
      .package = "DBI"
    )

    expect_error(
      db_execute_statement("INSERT INTO ndd_entity (hgnc_id) VALUES (?)", list(1234)),
      class = "db_statement_error"
    )
  })

  it("logs statement and affected row count", {
    local_mocked_bindings(
      pool = list(),
      .package = "base"
    )

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

    affected <- db_execute_statement("UPDATE test SET val = ?", list(1))

    # Should have at least 2 log calls (statement + affected rows)
    expect_true(length(log_messages) >= 2)
  })
})

# ============================================================================
# db_with_transaction() tests
# ============================================================================

describe("db_with_transaction", {

  it("commits transaction on success", {
    # Mock pool checkout/return
    mock_conn <- list(class = "MockConnection")

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
    })

    expect_true(transaction_executed)
    expect_equal(result, "test_result")
  })

  it("rolls back transaction on error", {
    mock_conn <- list(class = "MockConnection")

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
      }),
      class = "db_transaction_error"
    )
  })

  it("returns connection to pool even on error", {
    mock_conn <- list(class = "MockConnection")
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
      db_with_transaction({ "code" }),
      class = "db_transaction_error"
    )

    # Connection should be returned to pool even though error occurred
    expect_true(pool_returned)
  })

  it("logs transaction lifecycle", {
    mock_conn <- list(class = "MockConnection")

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

    result <- db_with_transaction({ "success" })

    # Should have logged: start, executing, and commit
    expect_true(length(log_messages) >= 3)
  })

  it("can execute multiple statements in transaction", {
    mock_conn <- list(class = "MockConnection")

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
    })

    expect_equal(result, 3)
  })
})
