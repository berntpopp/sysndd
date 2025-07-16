#!/usr/bin/env Rscript
#
# lint-and-fix.R
#
# Combined linting and styling script for SysNDD API
# One-stop solution for code quality and formatting
#
# Usage:
#   Rscript scripts/lint-and-fix.R
#   Rscript scripts/lint-and-fix.R --check-only    # Only check, don't fix
#
# Author: SysNDD Development Team
# Integrates lintr and styler for comprehensive code quality

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check-only" %in% args

cat("SysNDD API Code Quality Suite\n")
cat("=============================\n")
cat("Combining linting and styling for optimal code quality\n\n")

# Set working directory to API root
if (!require("here", quietly = TRUE)) {
  message("Installing here package...")
  install.packages("here", repos = "https://cran.r-project.org")
  library(here)
}

api_root <- here::here("api")
if (!dir.exists(api_root)) {
  api_root <- "."
}
setwd(api_root)

# Step 1: Run initial linting check
cat("Step 1: Initial Linting Check\n")
cat("-----------------------------\n")

# Source the lint-check script functions
source("scripts/lint-check.R", local = TRUE)

if (check_only) {
  cat("CHECK-ONLY mode: Will identify issues but not fix them\n\n")
  
  # Run lint check without fixing
  initial_lint_result <- system("Rscript scripts/lint-check.R", intern = FALSE)
  
  if (initial_lint_result == 0) {
    cat("\n✓ All code passes linting checks!\n")
    cat("✓ No styling needed\n")
  } else {
    cat("\n⚠ Issues found. Run without --check-only to fix automatically\n")
  }
  
  quit(status = initial_lint_result)
}

# Step 2: Apply code styling
cat("\nStep 2: Apply Code Styling\n")
cat("--------------------------\n")

style_result <- system("Rscript scripts/style-code.R", intern = FALSE)

if (style_result != 0) {
  cat("❌ Styling failed\n")
  quit(status = 1)
}

# Step 3: Re-run linting check
cat("\nStep 3: Final Linting Verification\n")
cat("----------------------------------\n")

final_lint_result <- system("Rscript scripts/lint-check.R", intern = FALSE)

# Step 4: Summary report
cat("\nFinal Report\n")
cat("============\n")

if (final_lint_result == 0) {
  cat("✅ SUCCESS: All code passes quality checks!\n")
  cat("   • Code formatting: ✓ Applied\n")
  cat("   • Linting rules: ✓ Passed\n")
  cat("   • Style guide: ✓ Compliant\n")
  cat("\nYour API code is ready for development and deployment.\n")
} else {
  cat("⚠️  PARTIAL SUCCESS: Styling applied, but some linting issues remain\n")
  cat("   • Code formatting: ✓ Applied\n")
  cat("   • Linting rules: ⚠ Some issues need manual review\n")
  cat("\nPlease review the linting issues above and fix manually.\n")
  cat("Common issues that require manual fixes:\n")
  cat("  - Logic errors or unused variables\n")
  cat("  - Complex naming that needs human judgment\n")
  cat("  - API-specific patterns that need custom handling\n")
}

cat("\nQuick Commands for Future Use:\n")
cat("  • Check only: Rscript scripts/lint-and-fix.R --check-only\n")
cat("  • Full fix:   Rscript scripts/lint-and-fix.R\n")
cat("  • Lint only:  Rscript scripts/lint-check.R\n")
cat("  • Style only: Rscript scripts/style-code.R\n")

quit(status = final_lint_result)