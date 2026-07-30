# api/tests/testthat/test-unit-gnomad-clinvar-summary.R

source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad-clinvar.R", local = FALSE)

clinvar_fixture <- list(
  list(
    clinical_significance = "Pathogenic",
    major_consequence = "frameshift_variant",
    in_gnomad = FALSE,
    gold_stars = 1
  ),
  list(
    clinical_significance = "Pathogenic",
    major_consequence = "stop_gained",
    in_gnomad = FALSE,
    gold_stars = 2
  ),
  list(
    clinical_significance = "Pathogenic/Likely pathogenic",
    major_consequence = "splice_donor_variant",
    in_gnomad = TRUE,
    gold_stars = 3
  ),
  list(
    clinical_significance = "Likely pathogenic",
    major_consequence = "missense_variant",
    in_gnomad = FALSE,
    gold_stars = 1
  ),
  list(
    clinical_significance = "Uncertain significance",
    major_consequence = "missense_variant",
    in_gnomad = TRUE,
    gold_stars = 0
  ),
  list(
    clinical_significance = "Likely benign",
    major_consequence = "synonymous_variant",
    in_gnomad = TRUE,
    gold_stars = 1
  ),
  list(
    clinical_significance = "Benign/Likely benign",
    major_consequence = "inframe_deletion",
    in_gnomad = TRUE,
    gold_stars = 1
  ),
  list(
    clinical_significance = "Benign",
    major_consequence = "intron_variant",
    in_gnomad = TRUE,
    gold_stars = 2
  ),
  list(
    clinical_significance = "Conflicting classifications of pathogenicity",
    major_consequence = "inframe_insertion",
    in_gnomad = FALSE,
    gold_stars = 1
  ),
  list(
    clinical_significance = "not provided",
    major_consequence = "3_prime_UTR_variant",
    in_gnomad = FALSE,
    gold_stars = 0
  )
)

describe("summarise_gnomad_clinvar_variants", {
  it("preserves the five primary ClinVar class counts", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_equal(summary$counts$pathogenic, 3)
    expect_equal(summary$counts$likely_pathogenic, 1)
    expect_equal(summary$counts$vus, 1)
    expect_equal(summary$counts$likely_benign, 2)
    expect_equal(summary$counts$benign, 1)
  })

  it("returns normalized global consequence counts", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)
    counts <- setNames(
      vapply(summary$consequence_counts, `[[`, numeric(1), "count"),
      vapply(summary$consequence_counts, `[[`, character(1), "key")
    )

    expect_equal(counts[["lof"]], 2)
    expect_equal(counts[["missense"]], 2)
    expect_equal(counts[["splice"]], 1)
    expect_equal(counts[["inframe_indel"]], 2)
    expect_equal(counts[["synonymous"]], 1)
    expect_equal(counts[["intronic"]], 1)
    expect_equal(counts[["utr"]], 1)
  })

  it("returns per-class consequence breakdowns with labels and short labels", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)
    pathogenic <- summary$class_breakdowns$pathogenic
    pathogenic_counts <- setNames(
      vapply(pathogenic$consequences, `[[`, numeric(1), "count"),
      vapply(pathogenic$consequences, `[[`, character(1), "key")
    )

    expect_equal(pathogenic$label, "Pathogenic")
    expect_equal(pathogenic$short_label, "P")
    expect_equal(pathogenic$count, 3)
    expect_equal(pathogenic_counts[["lof"]], 2)
    expect_equal(pathogenic_counts[["splice"]], 1)
  })

  it("counts conflicting classifications as a primary class", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_equal(summary$counts$conflicting, 1)
    expect_equal(summary$class_breakdowns$conflicting$label, "Conflicting classifications")
    expect_equal(summary$class_breakdowns$conflicting$short_label, "CONF")
    expect_equal(summary$class_breakdowns$conflicting$count, 1)
  })

  it("keeps unmapped classifications visible outside the primary chips", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_null(summary$other_classifications$conflicting_classifications_of_pathogenicity)
    expect_equal(summary$other_classifications$not_provided, 1)
  })

  it("reports quality counts without changing variant_count semantics", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_equal(summary$variant_count, length(clinvar_fixture))
    expect_equal(summary$quality_counts$in_gnomad, 5)
    expect_equal(summary$quality_counts$review_stars$`0`, 2)
    expect_equal(summary$quality_counts$review_stars$`1`, 5)
    expect_equal(summary$quality_counts$review_stars$`2`, 2)
    expect_equal(summary$quality_counts$review_stars$`3`, 1)
    expect_equal(summary$quality_counts$review_stars$`4`, 0)
  })
})

# The vocabulary fixture is shared with the TypeScript client
# (app/src/types/clinvarSignificance.spec.ts, via
# app/src/test-utils/clinvarVocabularyFixture.ts). Both suites assert their own
# production table against it in BOTH directions, so the two tables cannot
# drift. Add a new term to the fixture first, then to both tables. See #607.
clinvar_vocabulary <- jsonlite::fromJSON(
  testthat::test_path("fixtures", "clinvar-significance-vocabulary.json"),
  simplifyVector = FALSE
)

clinvar_expected_key <- function(class_name) {
  switch(class_name,
    pathogenic = "pathogenic",
    likely_pathogenic = "likely_pathogenic",
    vus = "vus",
    likely_benign = "likely_benign",
    benign = "benign",
    conflicting = "conflicting",
    NA_character_
  )
}

describe("normalize_clinvar_classification", {
  it("matches the shared cross-language vocabulary fixture", {
    entries <- c(
      clinvar_vocabulary$terms,
      clinvar_vocabulary$normalization_variants,
      clinvar_vocabulary$aggregate_terms
    )

    for (entry in entries) {
      expected <- clinvar_expected_key(entry$class)
      actual <- normalize_clinvar_classification(entry$raw)

      if (is.na(expected)) {
        expect_true(
          startsWith(actual, "other:"),
          info = paste0(entry$raw, " should be an other:* key, got ", actual)
        )
      } else {
        expect_equal(actual, expected, info = entry$raw)
      }
    }
  })

  it("never routes an unresolvable term into a primary class", {
    primary_keys <- names(clinvar_primary_classes)

    for (raw in clinvar_vocabulary$unknown_terms) {
      actual <- normalize_clinvar_classification(raw)
      expect_false(actual %in% primary_keys, info = paste0(raw, " -> ", actual))
      expect_true(startsWith(actual, "other:"), info = paste0(raw, " -> ", actual))
    }
  })

  it("does not classify a conflicting term as pathogenic (issue #607)", {
    expect_equal(
      normalize_clinvar_classification("Conflicting classifications of pathogenicity"),
      "conflicting"
    )
    expect_equal(
      normalize_clinvar_classification("Conflicting_interpretations_of_pathogenicity"),
      "conflicting"
    )
  })

  it("poisons the whole aggregate when one token is unresolvable", {
    expect_true(
      startsWith(
        normalize_clinvar_classification("Pathogenic/Totally new ClinVar term 2027"),
        "other:"
      )
    )
  })

  it("handles NULL, NA and empty input", {
    expect_equal(normalize_clinvar_classification(NULL), "other:unknown")
    expect_equal(normalize_clinvar_classification(NA), "other:unknown")
    expect_equal(normalize_clinvar_classification(""), "other:unknown")
  })

  it("keeps the production table exactly in sync with the fixture (both directions)", {
    fixture_keys <- vapply(clinvar_vocabulary$terms, function(entry) {
      key <- gsub("_", " ", tolower(entry$raw), fixed = TRUE)
      trimws(gsub("\\s+", " ", key))
    }, character(1))

    table_keys <- names(clinvar_significance_table)

    expect_equal(sort(setdiff(table_keys, fixture_keys)), character(0))
    expect_equal(sort(setdiff(fixture_keys, table_keys)), character(0))
  })
})
