# Test runner for SysNDD API
# Run with: Rscript -e "testthat::test_dir('tests/testthat')"

library(testthat)

# Set working directory to api/ for correct path resolution
if (basename(getwd()) != "api") {
  stop("Tests must be run from the api/ directory")
}

test_check("sysndd")
