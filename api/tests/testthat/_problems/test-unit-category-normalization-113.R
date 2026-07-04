# Extracted from test-unit-category-normalization.R:113

# prequel ----------------------------------------------------------------------
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/category-normalization.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}
library(testthat)
library(tibble)
library(dplyr)
source(file.path(api_dir, "functions/category-normalization.R"))

# test -------------------------------------------------------------------------
fixture <- tibble(
    symbol = c("GENE1", "GENE2", "GENE3", "GENE4"),
    list = c("ndd_genehub", "ndd_genehub", "radboudumc_ID", "radboudumc_ID"),
    category = c("high", "low", "strong", "unknown")
  )
result <- normalize_comparison_categories(fixture)
expect_equal(result$category, c("Definitive", "Definitive", "Definitive", "Definitive"))
