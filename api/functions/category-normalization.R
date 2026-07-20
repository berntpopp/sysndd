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
#' - **panelapp** (Genomics England confidence 1-3; Red/Amber/Green):
#'   - "3" (Green) → "Definitive"
#'   - "2" (Amber) → "Moderate"
#'   - "1" (Red)   → "Limited"   (low evidence, NOT Refuted — issue #583)
#' - **sfari** (gene scores 1-3):
#'   - "1" → "Definitive"
#'   - "2" → "Moderate"
#'   - "3" → "Limited"
#'   - NA → "Definitive"
#' - **ndd_genehub** (NDD GeneHub evidence tiers → normalized scale):
#'   - "Tier 1", "AR" → "Definitive"
#'   - "Tier 2" → "Moderate"
#'   - "Tier 3", "Tier 4", "Missense" → "Limited"
#'   - any other tier (e.g. "Unclassified") → "Limited"
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
      # panelapp mappings (Genomics England confidence: 3=Green, 2=Amber, 1=Red)
      # Full ordinal: Green->Definitive, Amber->Moderate, Red->Limited. Red is LOW
      # evidence, NOT affirmative refutation (issue #583). No panelapp tier maps to Refuted.
      list == "panelapp" & category == "3" ~ "Definitive",
      list == "panelapp" & category == "2" ~ "Moderate",
      list == "panelapp" & category == "1" ~ "Limited",
      # sfari mappings (gene scores 1-3)
      list == "sfari" & category == "1" ~ "Definitive",
      list == "sfari" & category == "2" ~ "Moderate",
      list == "sfari" & category == "3" ~ "Limited",
      list == "sfari" & is.na(category) ~ "Definitive",
      # ndd_genehub - map NDD GeneHub evidence tiers to the normalized scale
      list == "ndd_genehub" & category %in% c("Tier 1", "AR") ~ "Definitive",
      list == "ndd_genehub" & category == "Tier 2" ~ "Moderate",
      list == "ndd_genehub" & category %in% c("Tier 3", "Tier 4", "Missense") ~ "Limited",
      list == "ndd_genehub" ~ "Limited",
      # radboudumc_ID - all entries are high confidence
      list == "radboudumc_ID" ~ "Definitive",
      # omim_ndd and orphanet_id already have "Definitive" set
      # SysNDD uses standard categories
      TRUE ~ category
    ))
}

#### Mapping policy version + declarative crosswalk (issue #583/#586) ####

# Single policy identifier surfaced to consumers so frozen downstream
# comparisons can distinguish old from new normalization policy. Bump the date
# and suffix whenever a mapping rule changes.
COMPARISON_CATEGORY_MAPPING_VERSION <- "2026-07-19.583-panelapp-ordinal"

#' Declarative evidence-tier crosswalk (single display source of truth).
#'
#' Serialized by GET /api/comparisons/crosswalk and rendered by the frontend
#' tier-mapping help. A guard test (test-unit-comparisons-crosswalk.R) drives
#' `normalize_comparison_categories()` from these rows so the display can never
#' drift from the executable normalizer. `rule_kind` tells the guard how to
#' probe each rule: exact | case_insensitive | missing | fallback | all_values
#' | passthrough.
#' @export
comparison_category_crosswalk <- function() {
  rule <- function(native_value, native_label, normalized_tier, rule_kind, note = NA_character_) {
    list(native_value = native_value, native_label = native_label,
         normalized_tier = normalized_tier, rule_kind = rule_kind, note = note)
  }
  list(
    mapping_version = COMPARISON_CATEGORY_MAPPING_VERSION,
    tiers = list(
      list(tier = "Definitive", definition = "Strong, established gene-disease evidence."),
      list(tier = "Moderate",   definition = "Moderate evidence."),
      list(tier = "Limited",    definition = "Limited / low evidence."),
      list(tier = "Refuted",    definition = "Evidence disputes the association.")
    ),
    sources = list(
      list(list = "panelapp", label = "PanelApp", rules = list(
        rule("3", "Green (3)", "Definitive", "exact"),
        rule("2", "Amber (2)", "Moderate",   "exact"),
        rule("1", "Red (1)",   "Limited",    "exact", "Red = low evidence, not Refuted.")
      )),
      list(list = "gene2phenotype", label = "Gene2Phenotype", rules = list(
        rule("strong",         "strong",         "Definitive", "case_insensitive"),
        rule("definitive",     "definitive",     "Definitive", "case_insensitive"),
        rule("moderate",       "moderate",       "Moderate",   "case_insensitive"),
        rule("limited",        "limited",        "Limited",    "case_insensitive"),
        rule("disputed",       "disputed",       "Refuted",    "case_insensitive"),
        rule("refuted",        "refuted",        "Refuted",    "case_insensitive"),
        rule("both rd and if", "both RD and IF", "Definitive", "case_insensitive")
      )),
      list(list = "sfari", label = "SFARI Gene", rules = list(
        rule("1", "score 1", "Definitive", "exact"),
        rule("2", "score 2", "Moderate",   "exact"),
        rule("3", "score 3", "Limited",    "exact"),
        rule(NA_character_, "ungraded (NA)", "Definitive", "missing")
      )),
      list(list = "ndd_genehub", label = "NDD GeneHub", rules = list(
        rule("Tier 1",  "Tier 1", "Definitive", "exact"),
        rule("AR",      "AR",     "Definitive", "exact"),
        rule("Tier 2",  "Tier 2", "Moderate",   "exact"),
        rule("Tier 3",  "Tier 3", "Limited",    "exact"),
        rule("Tier 4",  "Tier 4", "Limited",    "exact"),
        rule("Missense", "Missense", "Limited",  "exact"),
        rule("*",       "other / Unclassified", "Limited", "fallback")
      )),
      list(list = "radboudumc_ID", label = "Radboudumc ID", rules = list(
        rule("*", "any (ungraded inclusion list)", "Definitive", "all_values",
             "Ungraded inclusion list -> implied Definitive for comparability.")
      )),
      list(list = "SysNDD", label = "SysNDD", rules = list(
        rule("*", "native SysNDD category", NA_character_, "passthrough",
             "SysNDD categories pass through unchanged.")
      )),
      list(list = "omim_ndd", label = "OMIM NDD", rules = list(
        rule("*", "already-normalized (Definitive) inclusion list", NA_character_, "passthrough",
             "OMIM-NDD rows are seeded as Definitive at write time; passthrough here.")
      )),
      list(list = "orphanet_id", label = "Orphanet ID", rules = list(
        rule("*", "native Orphanet category", NA_character_, "passthrough",
             "Orphanet categories pass through unchanged.")
      ))
    ),
    non_tier_fillers = list(
      list(value = "not applicable", meaning = "Source has no gradeable category for this gene."),
      list(value = "not listed", meaning = "Gene is absent from this source's list (pivot fill), not a mapping.")
    ),
    notes = list(
      "PanelApp Red/1 normalizes to Limited (low evidence), never Refuted.",
      paste0("Ungraded inclusion lists (Radboudumc, OMIM NDD, Orphanet) receive an implied ",
             "Definitive for comparability, not a native equivalent tier."),
      "Only explicit source-native disputed/refuted assertions (e.g. Gene2Phenotype) map to Refuted.",
      "`not applicable` and `not listed` are non-tier fillers, not normalized mappings."
    )
  )
}
