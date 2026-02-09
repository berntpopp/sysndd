# test-unit-transaction-patterns.R
# Static analysis tests ensuring all db_with_transaction callers use the
# function-based pattern: db_with_transaction(function(txn_conn) { ... })
#
# The expression-based pattern db_with_transaction({ ... }) causes inner
# db_execute_* calls to acquire separate pool connections, providing ZERO
# atomicity. This test prevents regressions.

library(testthat)

# Directories to scan (relative to API root)
scan_dirs <- c("functions", "services", "endpoints", "core")

# Helper: read all R files from directories
read_all_r_files <- function() {
  api_dir <- get_api_dir()
  all_files <- character(0)
  for (d in scan_dirs) {
    dir_path <- file.path(api_dir, d)
    if (dir.exists(dir_path)) {
      r_files <- list.files(dir_path, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
      all_files <- c(all_files, r_files)
    }
  }
  all_files
}

# Helper: check if a line is a comment (starts with # or #' after whitespace)
is_comment_line <- function(line) {
  grepl("^\\s*#", line)
}

# Helper: extract actual (non-comment) transaction calls from a file
find_transaction_calls <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE)
  results <- list()

  # Find all lines that contain a db_with_transaction( call
  txn_indices <- grep("db_with_transaction\\(", lines)

  for (idx in txn_indices) {
    line <- lines[idx]

    # Skip comment lines and roxygen documentation
    if (is_comment_line(line)) next

    uses_function <- grepl("db_with_transaction\\(\\s*function\\s*\\(", line)
    results <- c(results, list(list(
      file = file_path,
      line = idx,
      text = trimws(line),
      uses_function = uses_function
    )))
  }

  results
}

# Helper: find end of a paren-delimited call starting from a line with db_execute_*
# Returns the line index where the matching closing paren is found
find_call_end <- function(block_lines, start_j) {
  paren_depth <- 0
  for (k in start_j:length(block_lines)) {
    line <- block_lines[k]
    paren_depth <- paren_depth + nchar(gsub("[^(]", "", line)) - nchar(gsub("[^)]", "", line))
    if (paren_depth <= 0) return(k)
  }
  return(length(block_lines))
}

# Test 1: Every db_with_transaction call uses function(txn_conn) pattern
test_that("All db_with_transaction calls use function-based pattern", {
  r_files <- read_all_r_files()
  expect_true(length(r_files) > 0, label = "Found R source files to scan")

  all_calls <- list()
  for (f in r_files) {
    all_calls <- c(all_calls, find_transaction_calls(f))
  }

  expect_true(length(all_calls) > 0, label = "Found db_with_transaction calls")

  broken_calls <- Filter(function(x) !x$uses_function, all_calls)

  if (length(broken_calls) > 0) {
    msgs <- vapply(broken_calls, function(x) {
      rel_path <- sub(paste0(get_api_dir(), "/"), "", x$file)
      sprintf("  %s:%d => %s", rel_path, x$line, x$text)
    }, character(1))
    fail(paste0(
      "Found ", length(broken_calls),
      " db_with_transaction call(s) using expression pattern instead of function:\n",
      paste(msgs, collapse = "\n")
    ))
  }

  expect_equal(length(broken_calls), 0,
    label = paste("All", length(all_calls), "transaction calls use function pattern")
  )
})


# Test 2: Every db_execute_* inside a transaction block passes conn =
test_that("All db_execute_* calls inside transactions pass conn parameter", {
  r_files <- read_all_r_files()
  violations <- character(0)

  for (file_path in r_files) {
    lines <- readLines(file_path, warn = FALSE)
    rel_path <- sub(paste0(get_api_dir(), "/"), "", file_path)

    # Find transaction start lines (code only, not comments)
    txn_starts <- grep("db_with_transaction\\(\\s*function\\s*\\(txn_conn\\)", lines)
    txn_starts <- txn_starts[!vapply(lines[txn_starts], is_comment_line, logical(1))]

    for (start_idx in txn_starts) {
      # Track brace depth to find the transaction block extent
      brace_depth <- 0
      end_idx <- start_idx
      started <- FALSE

      for (i in start_idx:length(lines)) {
        line <- lines[i]
        opens <- nchar(gsub("[^{]", "", line))
        closes <- nchar(gsub("[^}]", "", line))
        brace_depth <- brace_depth + opens - closes
        if (opens > 0) started <- TRUE
        if (started && brace_depth <= 0) {
          end_idx <- i
          break
        }
      }

      # Scan the transaction block for db_execute_* without conn =
      block_lines <- lines[start_idx:end_idx]
      for (j in seq_along(block_lines)) {
        line <- block_lines[j]
        actual_line <- start_idx + j - 1

        # Skip comment lines
        if (is_comment_line(line)) next

        # Check if line has a db_execute call
        if (grepl("db_execute_(query|statement)\\(", line)) {
          # Find the end of this specific function call (matching parens)
          call_end_j <- find_call_end(block_lines, j)
          call_text <- paste(block_lines[j:call_end_j], collapse = " ")

          if (!grepl("conn\\s*=", call_text)) {
            violations <- c(violations,
              sprintf("  %s:%d => %s", rel_path, actual_line, trimws(line))
            )
          }
        }
      }
    }
  }

  if (length(violations) > 0) {
    fail(paste0(
      "Found ", length(violations),
      " db_execute_* call(s) inside transactions without conn = parameter:\n",
      paste(violations, collapse = "\n")
    ))
  }
})


# Test 3: No undefined 'conn' references inside transaction blocks
test_that("No transaction blocks reference bare 'conn' (should be txn_conn)", {
  r_files <- read_all_r_files()
  violations <- character(0)

  for (file_path in r_files) {
    lines <- readLines(file_path, warn = FALSE)
    rel_path <- sub(paste0(get_api_dir(), "/"), "", file_path)

    # Find transaction blocks (code only)
    txn_starts <- grep("db_with_transaction\\(\\s*function\\s*\\(txn_conn\\)", lines)
    txn_starts <- txn_starts[!vapply(lines[txn_starts], is_comment_line, logical(1))]

    for (start_idx in txn_starts) {
      brace_depth <- 0
      end_idx <- start_idx
      started <- FALSE

      for (i in start_idx:length(lines)) {
        line <- lines[i]
        opens <- nchar(gsub("[^{]", "", line))
        closes <- nchar(gsub("[^}]", "", line))
        brace_depth <- brace_depth + opens - closes
        if (opens > 0) started <- TRUE
        if (started && brace_depth <= 0) {
          end_idx <- i
          break
        }
      }

      block_lines <- lines[(start_idx + 1):end_idx]
      for (j in seq_along(block_lines)) {
        line <- block_lines[j]
        actual_line <- start_idx + j

        # Skip comment lines
        if (is_comment_line(line)) next

        # Check for conn = conn (undefined variable) — should be conn = txn_conn
        if (grepl("conn\\s*=\\s*conn\\b", line)) {
          violations <- c(violations,
            sprintf("  %s:%d => %s", rel_path, actual_line, trimws(line))
          )
        }
      }
    }
  }

  if (length(violations) > 0) {
    fail(paste0(
      "Found ", length(violations),
      " reference(s) to undefined 'conn' inside transaction blocks:\n",
      paste(violations, collapse = "\n")
    ))
  }
})
