# functions/category-normalization.R
#### This file holds category normalization helper functions

#' Normalize Comparison Categories
#'
#' @description
#' This function normalizes source-specific category values to standard SysNDD
#' categories. External databases use different category naming conventions and
#' confidence levels, which this function maps to the standard categories:
#' Definitive, Moderate, Limited, Refuted, and "not applicable".
#'
#' @param data A data frame containing `list` and `category` columns.
#'   The `list` column specifies the source database (e.g., "gene2phenotype",
#'   "panelapp", "sfari"), and the `category` column contains the source-specific
#'   category value.
#'
#' @return A data frame with the `category` column normalized to standard
#'   SysNDD categories. The returned data frame is ungrouped.
#'
#' @details
#' **Mapping rules:**
#' - **gene2phenotype** (case-insensitive):
#'   - "strong", "definitive" → "Definitive"
#'   - "limited" → "Limited"
#'   - "moderate" → "Moderate"
#'   - "refuted", "disputed" → "Refuted"
#'   - "both rd and if" → "Definitive"
#' - **panelapp** (confidence levels 1-3):
#'   - "3" → "Definitive"
#'   - "2" → "Limited"
#'   - "1" → "Refuted"
#' - **sfari** (gene scores 1-3):
#'   - "1" → "Definitive"
#'   - "2" → "Moderate"
#'   - "3" → "Limited"
#'   - NA → "Definitive"
#' - **geisinger_DBD**: All entries → "Definitive"
#' - **radboudumc_ID**: All entries → "Definitive"
#' - **SysNDD, omim_ndd, orphanet_id**: Categories unchanged
#'
#' @export
#'
#' @examples
#' # Normalize categories from multiple sources
#' data <- tibble::tibble(
#'   symbol = c("GENE1", "GENE1", "GENE2"),
#'   list = c("SysNDD", "gene2phenotype", "panelapp"),
#'   category = c("Definitive", "strong", "3")
#' )
#' normalize_comparison_categories(data)
normalize_comparison_categories <- function(data) {
  data %>%
    mutate(category = case_when(
      # gene2phenotype mappings (new 2026 format uses lowercase)
      list == "gene2phenotype" & tolower(category) == "strong" ~ "Definitive",
      list == "gene2phenotype" & tolower(category) == "definitive" ~ "Definitive",
      list == "gene2phenotype" & tolower(category) == "limited" ~ "Limited",
      list == "gene2phenotype" & tolower(category) == "moderate" ~ "Moderate",
      list == "gene2phenotype" & tolower(category) == "refuted" ~ "Refuted",
      list == "gene2phenotype" & tolower(category) == "disputed" ~ "Refuted",
      list == "gene2phenotype" & tolower(category) == "both rd and if" ~ "Definitive",
      # panelapp mappings (confidence levels 1-3)
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "panelapp" & category == "2" ~ "Limited",
      list == "panelapp" & category == "1" ~ "Refuted",
      # sfari mappings (gene scores 1-3)
      list == "sfari" & category == "1" ~ "Definitive",
      list == "sfari" & category == "2" ~ "Moderate",
      list == "sfari" & category == "3" ~ "Limited",
      list == "sfari" & is.na(category) ~ "Definitive",
      # geisinger_DBD - all entries are high confidence
      list == "geisinger_DBD" ~ "Definitive",
      # radboudumc_ID - all entries are high confidence
      list == "radboudumc_ID" ~ "Definitive",
      # omim_ndd and orphanet_id already have "Definitive" set
      # SysNDD uses standard categories
      TRUE ~ category
    ))
}
