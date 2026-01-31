#!/usr/bin/env Rscript
#
# style-code.R
#
# Automated code formatting script for SysNDD API
# Formats all R files according to tidyverse style guide
#
# Usage:
#   Rscript scripts/style-code.R
#   Rscript scripts/style-code.R --dry-run    # Preview changes without applying
#
# Author: SysNDD Development Team
# Following tidyverse style guide conventions

# Load required libraries
if (!require("styler", quietly = TRUE)) {
  message("Installing styler package...")
  install.packages("styler", repos = "https://cran.r-project.org")
  library(styler)
}

if (!require("here", quietly = TRUE)) {
  message("Installing here package...")
  install.packages("here", repos = "https://cran.r-project.org")
  library(here)
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

# Set working directory to API root
api_root <- here::here("api")
if (!dir.exists(api_root)) {
  api_root <- "."
}
setwd(api_root)

# Define files to style
style_files <- c(
  # Main entry point
  "start_sysndd_api.R",
  
  # All endpoint files
  list.files("endpoints", pattern = "\\.R$", full.names = TRUE, recursive = TRUE),
  
  # All function files
  list.files("functions", pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
)

# Filter out files that don't exist
style_files <- style_files[file.exists(style_files)]

# Custom styler configuration for API context
api_style <- function() {
  styler::tidyverse_style(
    # Use 2-space indentation (consistent with current codebase)
    indent_by = 2,
    
    # Keep function arguments aligned (good for API documentation)
    reindention = styler::specify_reindention(
      regex_pattern = "^#'",
      indention = 0,
      comments_only = TRUE
    )
  )
}

cat("SysNDD API Code Styling\n")
cat("=======================\n")

if (dry_run) {
  cat("DRY RUN MODE - No files will be modified\n")
}

cat("Styling", length(style_files), "R files...\n\n")

# Function to style a single file
style_single_file <- function(file_path) {
  cat("Processing:", file_path, "\n")
  
  if (dry_run) {
    # In dry run mode, check what would be changed
    original_code <- readLines(file_path, warn = FALSE)
    styled_code <- styler::style_text(original_code, transformers = api_style())
    
    # Compare original and styled
    if (!identical(original_code, as.character(styled_code))) {
      cat("  → Would be modified\n")
      return(1)
    } else {
      cat("  ✓ Already properly formatted\n")
      return(0)
    }
  } else {
    # Actually style the file
    result <- styler::style_file(file_path, transformers = api_style())
    
    if (any(result$changed)) {
      cat("  ✓ Formatted\n")
      return(1)
    } else {
      cat("  ✓ No changes needed\n")
      return(0)
    }
  }
}

# Process all files
files_changed <- 0
files_processed <- 0

for (file_path in style_files) {
  changes <- style_single_file(file_path)
  files_changed <- files_changed + changes
  files_processed <- files_processed + 1
}

# Summary
cat("\nStyling Summary\n")
cat("===============\n")
cat("Files processed:", files_processed, "\n")

if (dry_run) {
  cat("Files that would be changed:", files_changed, "\n")
  if (files_changed > 0) {
    cat("\nRun without --dry-run to apply formatting changes\n")
  } else {
    cat("\n✓ All files are already properly formatted!\n")
  }
} else {
  cat("Files modified:", files_changed, "\n")
  if (files_changed > 0) {
    cat("\n✓ Code formatting completed successfully!\n")
    cat("Consider running 'Rscript scripts/lint-check.R' to verify code quality\n")
  } else {
    cat("\n✓ All files were already properly formatted!\n")
  }
}

# Exit successfully
quit(status = 0)