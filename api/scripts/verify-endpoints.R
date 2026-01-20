#!/usr/bin/env Rscript
# api/scripts/verify-endpoints.R
#
# Verifies that all public GET endpoints in the SysNDD API respond correctly.
#
# Usage:
#   Rscript scripts/verify-endpoints.R [--host localhost] [--port 7778]
#
# Prerequisites:
#   - API must be running (Rscript start_sysndd_api.R)
#   - Database must be connected
#
# This script tests public endpoints without authentication and verifies
# that protected endpoints properly return 401 Unauthorized.

## -------------------------------------------------------------------##
# Parse command-line arguments
## -------------------------------------------------------------------##

args <- commandArgs(trailingOnly = TRUE)

# Default values
host <- "localhost"
port <- "7778"

# Parse arguments
if (length(args) > 0) {
  for (i in seq_along(args)) {
    if (args[i] == "--host" && i < length(args)) {
      host <- args[i + 1]
    } else if (args[i] == "--port" && i < length(args)) {
      port <- args[i + 1]
    }
  }
}

base_url <- sprintf("http://%s:%s", host, port)

cat(sprintf("Verifying endpoints at %s\n", base_url))
cat(paste(rep("=", 60), collapse = ""), "\n\n")

## -------------------------------------------------------------------##
# Load required library
## -------------------------------------------------------------------##

if (!requireNamespace("httr2", quietly = TRUE)) {
  stop("Error: httr2 package is required. Install with: install.packages('httr2')")
}

library(httr2)

## -------------------------------------------------------------------##
# Define verification function
## -------------------------------------------------------------------##

verify_endpoint <- function(path, expected_status = 200, description = "") {
  full_url <- paste0(base_url, path)

  result <- tryCatch({
    # Make request without error on non-2xx status
    resp <- httr2::request(full_url) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()

    status <- httr2::resp_status(resp)

    # Check if status matches expected
    if (status == expected_status) {
      list(
        success = TRUE,
        status = status,
        message = sprintf("[OK] %s - %d", path, status)
      )
    } else {
      list(
        success = FALSE,
        status = status,
        message = sprintf("[FAIL] %s - Expected %d, got %d", path, expected_status, status)
      )
    }
  }, error = function(e) {
    list(
      success = FALSE,
      status = NA,
      message = sprintf("[ERROR] %s - %s", path, conditionMessage(e))
    )
  })

  # Print result
  if (!is.na(description) && description != "") {
    cat(sprintf("%-50s %s\n", description, result$message))
  } else {
    cat(result$message, "\n")
  }

  return(result)
}

## -------------------------------------------------------------------##
# Define endpoint test suite
## -------------------------------------------------------------------##

# Public endpoints that should return 200
public_endpoints <- list(
  list(path = "/api/entity/", desc = "Entity root"),
  list(path = "/api/gene/", desc = "Gene root"),
  list(path = "/api/status/", desc = "Status list"),
  list(path = "/api/status/_list", desc = "Status categories"),
  list(path = "/api/ontology/variant", desc = "Variant ontology"),
  list(path = "/api/phenotype/count", desc = "Phenotype count"),
  list(path = "/api/statistics/category_count", desc = "Category statistics"),
  list(path = "/api/panels/options", desc = "Panel options"),
  list(path = "/api/comparisons/options", desc = "Comparison options"),
  list(path = "/api/list/inheritance", desc = "Inheritance list"),
  list(path = "/api/list/phenotype", desc = "Phenotype list"),
  list(path = "/api/list/status", desc = "Status list"),
  list(path = "/api/analysis/functional_clustering", desc = "Functional clustering"),
  list(path = "/api/hash/create", desc = "Hash creation"),
  list(path = "/api/variant/count", desc = "Variant count"),
  list(path = "/api/publication/", desc = "Publication root"),
  list(path = "/api/review/", desc = "Review root"),
  list(path = "/api/re_review/table", desc = "Re-review table"),
  list(path = "/api/logs/", desc = "Logs root")
)

# Protected endpoints that should return 401 (no auth provided)
protected_endpoints <- list(
  list(path = "/api/admin/api_version", desc = "Admin API version"),
  list(path = "/api/user/list", desc = "User list"),
  list(path = "/api/user/table", desc = "User table")
)

# Skip these (POST-only or external dependencies)
# /api/auth/ endpoints are POST-only (signin, signup, authenticate)
# /api/external/ may have external dependencies

## -------------------------------------------------------------------##
# Run verification tests
## -------------------------------------------------------------------##

cat("Testing PUBLIC endpoints (should return 200):\n")
cat(paste(rep("-", 60), collapse = ""), "\n")

public_results <- list()
for (endpoint in public_endpoints) {
  result <- verify_endpoint(endpoint$path, 200, endpoint$desc)
  public_results[[length(public_results) + 1]] <- result
}

cat("\n")
cat("Testing PROTECTED endpoints (should return 401):\n")
cat(paste(rep("-", 60), collapse = ""), "\n")

protected_results <- list()
for (endpoint in protected_endpoints) {
  result <- verify_endpoint(endpoint$path, 401, endpoint$desc)
  protected_results[[length(protected_results) + 1]] <- result
}

## -------------------------------------------------------------------##
# Print summary
## -------------------------------------------------------------------##

cat("\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("SUMMARY\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

public_passed <- sum(sapply(public_results, function(x) x$success))
public_total <- length(public_results)

protected_passed <- sum(sapply(protected_results, function(x) x$success))
protected_total <- length(protected_results)

total_passed <- public_passed + protected_passed
total_tests <- public_total + protected_total

cat(sprintf("Public endpoints:    %d/%d passed\n", public_passed, public_total))
cat(sprintf("Protected endpoints: %d/%d passed\n", protected_passed, protected_total))
cat(sprintf("Total:               %d/%d passed\n", total_passed, total_tests))

if (total_passed == total_tests) {
  cat("\n✓ All endpoint verification tests passed!\n")
  quit(status = 0)
} else {
  cat("\n✗ Some endpoint verification tests failed.\n")
  quit(status = 1)
}
