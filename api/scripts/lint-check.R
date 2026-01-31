#!/usr/bin/env Rscript
#
# lint-check.R
#
# Comprehensive linting script for SysNDD API
# Checks all R files in the API directory for style and quality issues
#
# Usage:
#   Rscript scripts/lint-check.R
#   Rscript scripts/lint-check.R --fix    # Also run styler to fix issues
#
# Author: SysNDD Development Team
# Following Google R Style Guide and tidyverse conventions

# Load required libraries
if (!require("lintr", quietly = TRUE)) {
  message("Installing lintr package...")
  install.packages("lintr", repos = "https://cran.r-project.org")
  library(lintr)
}

if (!require("here", quietly = TRUE)) {
  message("Installing here package...")
  install.packages("here", repos = "https://cran.r-project.org")
  library(here)
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
fix_issues <- "--fix" %in% args

# Set working directory to API root
api_root <- here::here("api")
if (!dir.exists(api_root)) {
  api_root <- "."
}
setwd(api_root)

# Define files to lint
lint_files <- c(
  # Main entry point
  "start_sysndd_api.R",
  
  # All endpoint files
  list.files("endpoints", pattern = "\\.R$", full.names = TRUE, recursive = TRUE),
  
  # All function files
  list.files("functions", pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
)

# Filter out files that don't exist
lint_files <- lint_files[file.exists(lint_files)]

cat("SysNDD API Linting Report\n")
cat("========================\n")
cat("Checking", length(lint_files), "R files...\n\n")

# Function to run lintr on a single file
lint_single_file <- function(file_path) {
  cat("Checking:", file_path, "\n")
  
  # Run lintr
  lint_results <- lintr::lint(file_path)
  
  if (length(lint_results) == 0) {
    cat("  ✓ No issues found\n")
    return(0)
  } else {
    cat("  ⚠", length(lint_results), "issue(s) found:\n")
    
    # Print lint results
    for (lint_item in lint_results) {
      cat("    Line", lint_item$line_number, ":", lint_item$message, "\n")
    }
    
    return(length(lint_results))
  }
}

# Run linting on all files
total_issues <- 0
files_with_issues <- 0

for (file_path in lint_files) {
  issues_in_file <- lint_single_file(file_path)
  total_issues <- total_issues + issues_in_file
  
  if (issues_in_file > 0) {
    files_with_issues <- files_with_issues + 1
  }
  
  cat("\n")
}

# Summary
cat("Linting Summary\n")
cat("===============\n")
cat("Files checked:", length(lint_files), "\n")
cat("Files with issues:", files_with_issues, "\n")
cat("Total issues:", total_issues, "\n")

# Run styler if --fix flag is provided
if (fix_issues) {
  cat("\n")
  if (!require("styler", quietly = TRUE)) {
    message("Installing styler package...")
    install.packages("styler", repos = "https://cran.r-project.org")
    library(styler)
  }
  
  cat("Running styler to fix formatting issues...\n")
  
  # Style all files
  for (file_path in lint_files) {
    cat("Styling:", file_path, "\n")
    styler::style_file(file_path, transformers = styler::tidyverse_style())
  }
  
  cat("✓ Code formatting completed\n")
  cat("Re-run without --fix flag to check for remaining issues\n")
}

# Exit with appropriate code
if (total_issues > 0 && !fix_issues) {
  cat("\n⚠ Found", total_issues, "linting issues. Run with --fix to auto-format code.\n")
  quit(status = 1)
} else if (total_issues == 0) {
  cat("\n✓ All files pass linting checks!\n")
  quit(status = 0)
} else {
  quit(status = 0)
}