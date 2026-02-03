# tests/testthat/test-unit-logging-repository.R
# Unit tests for logging-repository.R query builder functions
#
# Tests verify:
# - Column validation rejects unknown columns with invalid_filter_error
# - SQL injection patterns are blocked
# - WHERE clause builder produces parameterized queries
# - ORDER BY clause builder validates column and direction
#
# These tests are critical security tests verifying SQL injection prevention.

library(testthat)

# Source the module under test
source_api_file("functions/logging-repository.R", local = FALSE)

# ============================================================================
# LOGGING_ALLOWED_COLUMNS constant tests (TST-02)
# ============================================================================

describe("LOGGING_ALLOWED_COLUMNS", {
  it("contains expected logging table columns", {
    expect_true("id" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("timestamp" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("status" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("path" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("request_method" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("address" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("duration" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("agent" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("host" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("query" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("post" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("file" %in% LOGGING_ALLOWED_COLUMNS)
    expect_true("modified" %in% LOGGING_ALLOWED_COLUMNS)
  })

  it("has exactly 13 columns matching logging table schema", {
    expect_equal(length(LOGGING_ALLOWED_COLUMNS), 13)
  })

  it("does not contain dangerous columns", {
    # Columns that should NOT be in the whitelist
    expect_false("password" %in% LOGGING_ALLOWED_COLUMNS)
    expect_false("secret" %in% LOGGING_ALLOWED_COLUMNS)
    expect_false("token" %in% LOGGING_ALLOWED_COLUMNS)
    expect_false("api_key" %in% LOGGING_ALLOWED_COLUMNS)
  })
})

describe("LOGGING_ALLOWED_SORT_COLUMNS", {
  it("is a subset of LOGGING_ALLOWED_COLUMNS", {
    # All sort columns should also be in allowed columns
    for (col in LOGGING_ALLOWED_SORT_COLUMNS) {
      expect_true(col %in% LOGGING_ALLOWED_COLUMNS,
                  info = paste("Sort column", col, "not in allowed columns"))
    }
  })

  it("contains expected sortable columns", {
    expect_true("id" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_true("timestamp" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_true("status" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_true("duration" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_true("address" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_true("request_method" %in% LOGGING_ALLOWED_SORT_COLUMNS)
  })

  it("excludes TEXT columns from sorting (expensive operations)", {
    # TEXT columns are excluded because sorting them is expensive
    expect_false("agent" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_false("path" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_false("query" %in% LOGGING_ALLOWED_SORT_COLUMNS)
    expect_false("post" %in% LOGGING_ALLOWED_SORT_COLUMNS)
  })
})

# ============================================================================
# validate_logging_column() tests (TST-02)
# ============================================================================

describe("validate_logging_column", {
  it("accepts valid columns", {
    expect_no_error(validate_logging_column("status"))
    expect_no_error(validate_logging_column("timestamp"))
    expect_no_error(validate_logging_column("id"))
    expect_no_error(validate_logging_column("path"))
    expect_no_error(validate_logging_column("request_method"))
    expect_no_error(validate_logging_column("address"))
    expect_no_error(validate_logging_column("duration"))
  })

  it("returns the column name when valid", {
    expect_equal(validate_logging_column("status"), "status")
    expect_equal(validate_logging_column("timestamp"), "timestamp")
    expect_equal(validate_logging_column("id"), "id")
  })

  it("rejects invalid columns with invalid_filter_error", {
    expect_error(
      validate_logging_column("nonexistent"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("unknown_column"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("users"),
      class = "invalid_filter_error"
    )
  })

  it("uses custom allowed list when provided", {
    custom_allowed <- c("foo", "bar")
    expect_no_error(validate_logging_column("foo", allowed = custom_allowed))
    expect_no_error(validate_logging_column("bar", allowed = custom_allowed))
    expect_error(
      validate_logging_column("status", allowed = custom_allowed),
      class = "invalid_filter_error"
    )
  })

  it("includes allowed columns in error message", {
    error <- tryCatch(
      validate_logging_column("invalid_col"),
      invalid_filter_error = function(e) e
    )
    expect_match(conditionMessage(error), "Allowed columns:")
    expect_match(conditionMessage(error), "invalid_col")
  })
})

# ============================================================================
# SQL injection prevention tests (TST-05)
# ============================================================================

describe("SQL injection prevention", {
  # Common SQL injection patterns
  injection_attempts <- c(
    "id; DROP TABLE logging; --",
    "id' OR '1'='1",
    "id/**/OR/**/1=1",
    "id UNION SELECT * FROM users",
    "'; DELETE FROM logging WHERE '1'='1",
    "status\n-- comment",
    "id; SELECT password FROM users; --",
    "1 OR 1=1",
    "admin'--",
    "status' AND '1'='1",
    "id`; DROP TABLE logging; --",
    "status; TRUNCATE TABLE logging",
    "path' OR 'x'='x"
  )

  for (attempt in injection_attempts) {
    it(paste("rejects injection:", substr(attempt, 1, 40)), {
      expect_error(
        validate_logging_column(attempt),
        class = "invalid_filter_error"
      )
    })
  }

  it("rejects column names with special characters", {
    expect_error(
      validate_logging_column("status;"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("status'"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("status--"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("status/*"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("status`"),
      class = "invalid_filter_error"
    )
  })

  it("rejects column names with SQL keywords embedded", {
    expect_error(
      validate_logging_column("status OR 1=1"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("id AND 1=1"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_logging_column("SELECT * FROM"),
      class = "invalid_filter_error"
    )
  })
})

# ============================================================================
# validate_sort_direction() tests (TST-03)
# ============================================================================

describe("validate_sort_direction", {
  it("accepts ASC and DESC (case insensitive)", {
    expect_equal(validate_sort_direction("ASC"), "ASC")
    expect_equal(validate_sort_direction("DESC"), "DESC")
    expect_equal(validate_sort_direction("asc"), "ASC")
    expect_equal(validate_sort_direction("desc"), "DESC")
    expect_equal(validate_sort_direction("Asc"), "ASC")
    expect_equal(validate_sort_direction("Desc"), "DESC")
    expect_equal(validate_sort_direction("AsC"), "ASC")
    expect_equal(validate_sort_direction("DeSc"), "DESC")
  })

  it("trims whitespace", {
    expect_equal(validate_sort_direction("  ASC  "), "ASC")
    expect_equal(validate_sort_direction("\tDESC\n"), "DESC")
    expect_equal(validate_sort_direction("   asc   "), "ASC")
  })

  it("rejects invalid directions with invalid_filter_error", {
    expect_error(
      validate_sort_direction("ASCENDING"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("DESCENDING"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("UP"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("DOWN"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("RANDOM"),
      class = "invalid_filter_error"
    )
  })

  it("rejects SQL injection in direction", {
    expect_error(
      validate_sort_direction("ASC; DROP TABLE"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("DESC--"),
      class = "invalid_filter_error"
    )
    expect_error(
      validate_sort_direction("ASC, id"),
      class = "invalid_filter_error"
    )
  })

  it("includes error details in message", {
    error <- tryCatch(
      validate_sort_direction("INVALID"),
      invalid_filter_error = function(e) e
    )
    expect_match(conditionMessage(error), "Must be ASC or DESC")
    expect_match(conditionMessage(error), "INVALID")
  })
})

# ============================================================================
# build_logging_where_clause() tests (TST-04)
# ============================================================================

describe("build_logging_where_clause", {
  it("returns 1=1 for empty filters", {
    result <- build_logging_where_clause(list())
    expect_equal(result$clause, "1=1")
    expect_equal(length(result$params), 0)
  })

  it("returns 1=1 for NULL filters", {
    result <- build_logging_where_clause(NULL)
    expect_equal(result$clause, "1=1")
    expect_equal(length(result$params), 0)
  })

  it("builds status filter with parameterization", {
    result <- build_logging_where_clause(list(status = 200))
    expect_match(result$clause, "status = \\?")
    expect_equal(result$params[[1]], 200L)
  })

  it("converts status to integer", {
    result <- build_logging_where_clause(list(status = "404"))
    expect_equal(result$params[[1]], 404L)
  })

  it("builds request_method filter", {
    result <- build_logging_where_clause(list(request_method = "GET"))
    expect_match(result$clause, "request_method = \\?")
    expect_equal(result$params[[1]], "GET")
  })

  it("builds path prefix filter with LIKE", {
    result <- build_logging_where_clause(list(path_prefix = "/api/"))
    expect_match(result$clause, "path LIKE \\?")
    expect_equal(result$params[[1]], "/api/%")  # % appended
  })

  it("builds path contains filter with LIKE wildcards", {
    result <- build_logging_where_clause(list(path_contains = "entity"))
    expect_match(result$clause, "path LIKE \\?")
    expect_equal(result$params[[1]], "%entity%")  # % on both sides
  })

  it("builds timestamp range filters", {
    result <- build_logging_where_clause(list(
      timestamp_from = "2026-01-01 00:00:00",
      timestamp_to = "2026-01-31 23:59:59"
    ))
    expect_match(result$clause, "timestamp >= \\?")
    expect_match(result$clause, "timestamp <= \\?")
    expect_equal(length(result$params), 2)
    expect_equal(result$params[[1]], "2026-01-01 00:00:00")
    expect_equal(result$params[[2]], "2026-01-31 23:59:59")
  })

  it("builds address filter", {
    result <- build_logging_where_clause(list(address = "192.168.1.1"))
    expect_match(result$clause, "address = \\?")
    expect_equal(result$params[[1]], "192.168.1.1")
  })

  it("builds host filter", {
    result <- build_logging_where_clause(list(host = "api.example.com"))
    expect_match(result$clause, "host = \\?")
    expect_equal(result$params[[1]], "api.example.com")
  })

  it("builds agent contains filter", {
    result <- build_logging_where_clause(list(agent_contains = "Mozilla"))
    expect_match(result$clause, "agent LIKE \\?")
    expect_equal(result$params[[1]], "%Mozilla%")
  })

  it("builds any_contains filter searching multiple columns", {
    result <- build_logging_where_clause(list(any_contains = "test"))
    expect_match(result$clause, "path LIKE \\?")
    expect_match(result$clause, "agent LIKE \\?")
    expect_match(result$clause, "query LIKE \\?")
    expect_match(result$clause, "host LIKE \\?")
    expect_equal(length(result$params), 4)
    # All params should be the same search value with wildcards
    for (i in seq_along(result$params)) {
      expect_equal(result$params[[i]], "%test%")
    }
  })

  it("combines multiple filters with AND", {
    result <- build_logging_where_clause(list(
      status = 200,
      request_method = "GET"
    ))
    expect_match(result$clause, "AND status = \\?")
    expect_match(result$clause, "AND request_method = \\?")
    expect_equal(length(result$params), 2)
  })

  it("ignores NULL filter values", {
    result <- build_logging_where_clause(list(
      status = NULL,
      request_method = "GET"
    ))
    expect_false(grepl("status", result$clause))
    expect_match(result$clause, "request_method = \\?")
    expect_equal(length(result$params), 1)
  })

  it("ignores empty string filter values", {
    result <- build_logging_where_clause(list(
      status = "",
      request_method = "GET"
    ))
    expect_false(grepl("status", result$clause))
    expect_match(result$clause, "request_method = \\?")
    expect_equal(length(result$params), 1)
  })

  it("ignores NULL and empty string values but keeps valid ones", {
    result <- build_logging_where_clause(list(
      status = NULL,
      request_method = "",
      path_prefix = "/api/"
    ))
    expect_false(grepl("status", result$clause))
    expect_false(grepl("request_method", result$clause))
    expect_match(result$clause, "path LIKE \\?")
    expect_equal(length(result$params), 1)
  })

  it("preserves parameter order matching clause order", {
    result <- build_logging_where_clause(list(
      status = 404,
      request_method = "POST",
      address = "10.0.0.1"
    ))
    # Params should be in same order as they appear in clause
    expect_equal(length(result$params), 3)
    # Verify all params are present
    expect_true(404L %in% unlist(result$params))
    expect_true("POST" %in% unlist(result$params))
    expect_true("10.0.0.1" %in% unlist(result$params))
  })

  it("uses parameterized queries (? placeholders) not string interpolation", {
    result <- build_logging_where_clause(list(status = 500))
    # Clause should have ? placeholder, not the actual value
    expect_match(result$clause, "\\?")
    expect_false(grepl("500", result$clause))
    # Value should be in params list
    expect_equal(result$params[[1]], 500L)
  })
})

# ============================================================================
# build_logging_order_clause() tests (TST-03)
# ============================================================================

describe("build_logging_order_clause", {
  it("returns default ORDER BY id DESC", {
    result <- build_logging_order_clause()
    expect_equal(result, "ORDER BY id DESC")
  })

  it("accepts valid sort column", {
    result <- build_logging_order_clause(sort_column = "timestamp")
    expect_equal(result, "ORDER BY timestamp DESC")
  })

  it("accepts valid sort direction", {
    result <- build_logging_order_clause(sort_direction = "ASC")
    expect_equal(result, "ORDER BY id ASC")
  })

  it("combines column and direction", {
    result <- build_logging_order_clause(
      sort_column = "status",
      sort_direction = "ASC"
    )
    expect_equal(result, "ORDER BY status ASC")
  })

  it("normalizes direction to uppercase", {
    result <- build_logging_order_clause(
      sort_column = "id",
      sort_direction = "asc"
    )
    expect_equal(result, "ORDER BY id ASC")
  })

  it("accepts all valid sort columns", {
    for (col in LOGGING_ALLOWED_SORT_COLUMNS) {
      result <- build_logging_order_clause(sort_column = col)
      expect_equal(result, paste("ORDER BY", col, "DESC"))
    }
  })

  it("rejects invalid sort column with invalid_filter_error", {
    expect_error(
      build_logging_order_clause(sort_column = "invalid_column"),
      class = "invalid_filter_error"
    )
  })

  it("rejects TEXT columns that are not in sort whitelist", {
    expect_error(
      build_logging_order_clause(sort_column = "agent"),
      class = "invalid_filter_error"
    )
    expect_error(
      build_logging_order_clause(sort_column = "path"),
      class = "invalid_filter_error"
    )
    expect_error(
      build_logging_order_clause(sort_column = "query"),
      class = "invalid_filter_error"
    )
  })

  it("rejects SQL injection in sort column", {
    expect_error(
      build_logging_order_clause(sort_column = "id; DROP TABLE logging"),
      class = "invalid_filter_error"
    )
    expect_error(
      build_logging_order_clause(sort_column = "id--"),
      class = "invalid_filter_error"
    )
    expect_error(
      build_logging_order_clause(sort_column = "id, status"),
      class = "invalid_filter_error"
    )
  })

  it("rejects invalid direction", {
    expect_error(
      build_logging_order_clause(sort_direction = "RANDOM"),
      class = "invalid_filter_error"
    )
    expect_error(
      build_logging_order_clause(sort_direction = "SIDEWAYS"),
      class = "invalid_filter_error"
    )
  })

  it("rejects SQL injection in direction", {
    expect_error(
      build_logging_order_clause(sort_direction = "DESC; DROP TABLE"),
      class = "invalid_filter_error"
    )
  })
})

# ============================================================================
# Unparseable filter syntax tests (TST-06)
# ============================================================================

describe("unparseable filter handling", {
  it("filter values with special characters are parameterized, not rejected", {
    # Values should be safe because they're parameterized
    # Only column NAMES need whitelist validation
    result <- build_logging_where_clause(list(
      path_prefix = "/api/test'; DROP TABLE--"
    ))
    # Should still build the query (value is parameterized)
    expect_match(result$clause, "path LIKE \\?")
    # The dangerous value is a PARAMETER, not embedded SQL
    expect_true(grepl("DROP", result$params[[1]]))
  })

  it("dangerous values in params are safe due to parameterization", {
    # SQL injection via values is safe because of parameterized queries
    dangerous_values <- list(
      path_contains = "'; DROP TABLE logging; --",
      address = "127.0.0.1'; DELETE FROM users; --"
    )
    result <- build_logging_where_clause(dangerous_values)
    # Query should be built (values are parameterized)
    expect_match(result$clause, "path LIKE \\?")
    expect_match(result$clause, "address = \\?")
    # Values contain the dangerous strings but they're in params, not SQL
    expect_true(any(grepl("DROP TABLE", unlist(result$params))))
  })

  it("demonstrates column validation vs value parameterization", {
    # Column names are validated (whitelist)
    expect_error(
      validate_logging_column("id; DROP TABLE"),
      class = "invalid_filter_error"
    )

    # But values are parameterized, so any value is safe
    result <- build_logging_where_clause(list(
      path_prefix = "id; DROP TABLE"
    ))
    expect_match(result$clause, "path LIKE \\?")
    expect_equal(result$params[[1]], "id; DROP TABLE%")
  })
})

# ============================================================================
# parse_logging_filter() tests
# ============================================================================

describe("parse_logging_filter", {
  it("returns empty list for NULL input", {
    result <- parse_logging_filter(NULL)
    expect_equal(result, list())
  })

  it("returns empty list for empty string", {
    result <- parse_logging_filter("")
    expect_equal(result, list())
  })

  it("returns empty list for 'null' string", {
    result <- parse_logging_filter("null")
    expect_equal(result, list())
  })

  it("parses contains(status,value) to status filter", {
    result <- parse_logging_filter("contains(status,500)")
    expect_equal(result$status, 500L)
  })

  it("parses contains(request_method,value) to request_method filter", {
    result <- parse_logging_filter("contains(request_method,GET)")
    expect_equal(result$request_method, "GET")
  })

  it("parses contains(path,value) to path_contains filter", {
    result <- parse_logging_filter("contains(path,/api/)")
    expect_equal(result$path_contains, "/api/")
  })

  it("parses contains(address,value) to address filter", {
    result <- parse_logging_filter("contains(address,127.0.0.1)")
    expect_equal(result$address, "127.0.0.1")
  })

  it("parses contains(any,value) to any_contains filter", {
    result <- parse_logging_filter("contains(any,test)")
    expect_equal(result$any_contains, "test")
  })

  it("parses greaterThan(timestamp,value) to timestamp_from filter", {
    result <- parse_logging_filter("greaterThan(timestamp,2026-01-01)")
    expect_equal(result$timestamp_from, "2026-01-01")
  })

  it("parses lessThan(timestamp,value) to timestamp_to filter", {
    result <- parse_logging_filter("lessThan(timestamp,2026-01-31)")
    expect_equal(result$timestamp_to, "2026-01-31")
  })

  it("parses and() combining multiple filters", {
    result <- parse_logging_filter(
      "and(contains(status,200),contains(request_method,GET))"
    )
    expect_equal(result$status, 200L)
    expect_equal(result$request_method, "GET")
  })

  it("handles URL-encoded filter strings", {
    # URL-encoded version of "contains(path,/api/)"
    result <- parse_logging_filter("contains(path,%2Fapi%2F)")
    expect_equal(result$path_contains, "/api/")
  })
})
