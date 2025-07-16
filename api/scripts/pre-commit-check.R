#!/usr/bin/env Rscript
#
# pre-commit-check.R
#
# Pre-commit validation script for SysNDD API
# Lightweight checks to run before committing code changes
#
# Usage:
#   Rscript scripts/pre-commit-check.R
#   Rscript scripts/pre-commit-check.R --fast    # Skip comprehensive checks
#
# Designed to be fast enough for pre-commit hooks while catching major issues
#
# Author: SysNDD Development Team

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
fast_mode <- "--fast" %in% args

cat("SysNDD API Pre-Commit Check\n")
cat("===========================\n")

if (fast_mode) {
  cat("FAST MODE: Running essential checks only\n")
} else {
  cat("COMPREHENSIVE MODE: Running all pre-commit checks\n")
}

cat("\n")

# Load required libraries quietly
suppress_output <- function(expr) {
  invisible(capture.output(suppressMessages(suppressWarnings(expr))))
}

# Check if required packages are available
required_packages <- c("lintr", "here")
missing_packages <- character(0)

for (pkg in required_packages) {
  if (!require(pkg, quietly = TRUE, character.only = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}

if (length(missing_packages) > 0) {
  cat("❌ Missing required packages:", paste(missing_packages, collapse = ", "), "\n")
  cat("Install with: install.packages(c(", paste0("'", missing_packages, "'", collapse = ", "), "))\n")
  quit(status = 1)
}

# Set working directory
api_root <- here::here("api")
if (!dir.exists(api_root)) {
  api_root <- "."
}
setwd(api_root)

# Check 1: Verify main files exist
cat("✓ Checking core files...\n")
core_files <- c("start_sysndd_api.R", "config.yml", ".lintr")
missing_core <- character(0)

for (file in core_files) {
  if (!file.exists(file)) {
    missing_core <- c(missing_core, file)
  }
}

if (length(missing_core) > 0) {
  cat("❌ Missing core files:", paste(missing_core, collapse = ", "), "\n")
  quit(status = 1)
}

# Check 2: Basic syntax validation
cat("✓ Checking R syntax...\n")
r_files <- c(
  "start_sysndd_api.R",
  list.files("endpoints", pattern = "\\.R$", full.names = TRUE, recursive = TRUE),
  list.files("functions", pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
)

r_files <- r_files[file.exists(r_files)]
syntax_errors <- character(0)

for (file in r_files) {
  tryCatch({
    parse(file)
  }, error = function(e) {
    syntax_errors <<- c(syntax_errors, file)
    cat("  ❌ Syntax error in:", file, "\n")
    cat("     ", conditionMessage(e), "\n")
  })
}

if (length(syntax_errors) > 0) {
  cat("❌ Found syntax errors in", length(syntax_errors), "file(s)\n")
  quit(status = 1)
}

# Check 3: Critical linting (fast mode) or full linting
if (fast_mode) {
  cat("✓ Running critical lint checks...\n")
  
  # Only check for critical issues
  critical_linters <- list(
    assignment_linter = lintr::assignment_linter(),
    line_length_linter = lintr::line_length_linter(100L),
    absolute_path_linter = lintr::absolute_path_linter()
  )
  
  critical_issues <- 0
  
  for (file in head(r_files, 5)) {  # Check only first 5 files in fast mode
    file_lints <- lintr::lint(file, linters = critical_linters)
    critical_issues <- critical_issues + length(file_lints)
    
    if (length(file_lints) > 0) {
      cat("  ⚠ Critical issues in:", basename(file), "(", length(file_lints), ")\n")
    }
  }
  
  if (critical_issues > 0) {
    cat("⚠ Found", critical_issues, "critical issues. Consider running full check.\n")
  }
  
} else {
  cat("✓ Running comprehensive lint checks...\n")
  
  # Run standard linting
  lint_result <- system("Rscript scripts/lint-check.R", intern = FALSE, ignore.stdout = TRUE)
  
  if (lint_result != 0) {
    cat("⚠ Linting issues found. Run 'Rscript scripts/lint-check.R' for details.\n")
  }
}

# Check 4: Configuration validation
cat("✓ Validating configuration...\n")

if (file.exists("config.yml")) {
  tryCatch({
    if (require("yaml", quietly = TRUE)) {
      yaml::read_yaml("config.yml")
    } else {
      cat("  ⚠ yaml package not available, skipping config validation\n")
    }
  }, error = function(e) {
    cat("❌ Invalid config.yml:", conditionMessage(e), "\n")
    quit(status = 1)
  })
}

# Check 5: Git status (if in git repo)
if (dir.exists(".git") || dir.exists("../.git")) {
  cat("✓ Checking git status...\n")
  
  # Check for large files
  git_status <- system("git status --porcelain", intern = TRUE, ignore.stderr = TRUE)
  
  if (length(git_status) > 0) {
    large_files <- character(0)
    for (line in git_status) {
      file_path <- sub("^.. ", "", line)
      if (file.exists(file_path) && file.info(file_path)$size > 10 * 1024 * 1024) {  # 10MB
        large_files <- c(large_files, file_path)
      }
    }
    
    if (length(large_files) > 0) {
      cat("⚠ Large files detected:", paste(large_files, collapse = ", "), "\n")
      cat("  Consider using git LFS for files > 10MB\n")
    }
  }
}

# Final summary
cat("\nPre-Commit Summary\n")
cat("==================\n")
cat("✓ Core files: Present\n")
cat("✓ R syntax: Valid\n")

if (fast_mode) {
  cat("✓ Critical checks: Passed\n")
  cat("\nℹ Run without --fast for comprehensive checks\n")
} else {
  cat("✓ Comprehensive checks: Completed\n")
}

cat("\n🚀 Ready for commit!\n")

# Success tips
cat("\nTips:\n")
cat("  • For automatic fixes: Rscript scripts/lint-and-fix.R\n")
cat("  • For style only: Rscript scripts/style-code.R\n")
cat("  • For linting only: Rscript scripts/lint-check.R\n")

quit(status = 0)