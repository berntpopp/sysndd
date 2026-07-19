# test-unit-comparisons-crosswalk.R
# Unit tests for the declarative evidence-tier crosswalk + mapping version
# (issue #583/#586). The crosswalk is the single display source of truth; the
# guard tests below drive the executable normalizer from its rows so the display
# can never drift from normalize_comparison_categories().
library(testthat)
library(tibble)
library(dplyr)
api_dir <- if (basename(getwd()) == "testthat") normalizePath(file.path(getwd(), "..", "..")) else getwd()
source(file.path(api_dir, "functions/category-normalization.R"))

test_that("mapping_version is a non-empty scalar and matches the crosswalk", {
  expect_true(nzchar(COMPARISON_CATEGORY_MAPPING_VERSION))
  cw <- comparison_category_crosswalk()
  expect_identical(cw$mapping_version, COMPARISON_CATEGORY_MAPPING_VERSION)
  expect_true(all(c("mapping_version", "tiers", "sources", "notes", "non_tier_fillers") %in% names(cw)))
})

test_that("every crosswalk rule agrees with the executable normalizer (no drift)", {
  cw <- comparison_category_crosswalk()
  for (src in cw$sources) {
    for (rule in src$rules) {
      if (rule$rule_kind == "passthrough") {
        # passthrough (SysNDD/omim_ndd/orphanet_id): the normalizer returns the
        # native category UNCHANGED. Probe a representative tier and assert identity
        # (do NOT compare to the crosswalk's intentionally-null normalized_tier).
        got_pt <- normalize_comparison_categories(
          tibble(symbol = "G", list = src$list, category = "Definitive")
        )$category[[1]]
        expect_identical(got_pt, "Definitive",
          info = sprintf("%s passthrough identity", src$list))
        next
      }
      # Build a probe native value per rule_kind
      probe <- switch(rule$rule_kind,
        missing = NA_character_,
        case_insensitive = toupper(rule$native_value),  # exercise casing
        fallback = "Totally Unknown Tier XYZ",            # arbitrary -> fallback tier
        all_values = "any arbitrary value",               # arbitrary -> single tier
        rule$native_value                                  # exact / passthrough
      )
      got <- normalize_comparison_categories(
        tibble(symbol = "G", list = src$list, category = probe)
      )$category[[1]]
      expect_identical(got, rule$normalized_tier,
        info = sprintf("%s / %s (%s)", src$list, rule$native_value, rule$rule_kind))
    }
  }
})

test_that("PanelApp crosswalk encodes the full ordinal and never Refuted", {
  cw <- comparison_category_crosswalk()
  pa <- Filter(function(s) s$list == "panelapp", cw$sources)[[1]]
  tiers <- vapply(pa$rules, function(r) r$normalized_tier, character(1))
  expect_setequal(tiers, c("Definitive", "Moderate", "Limited"))
  expect_false("Refuted" %in% tiers)
})

test_that("crosswalk serializes SFARI missing native value as JSON null (na=null)", {
  cw <- comparison_category_crosswalk()
  # mirror the endpoint serializer contract
  j <- jsonlite::toJSON(cw, auto_unbox = TRUE, na = "null")
  parsed <- jsonlite::fromJSON(j, simplifyVector = FALSE)
  expect_identical(parsed$mapping_version, COMPARISON_CATEGORY_MAPPING_VERSION)
  sfari <- Filter(function(s) s$list == "sfari", parsed$sources)[[1]]
  missing_rule <- Filter(function(r) identical(r$rule_kind, "missing"), sfari$rules)[[1]]
  expect_null(missing_rule$native_value)   # NA -> JSON null, not "NA"
})
