# api/tests/testthat/test-unit-gnomad-clinvar-summary.R

source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-gnomad.R", local = FALSE)

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

  it("keeps unmapped classifications visible outside the five primary chips", {
    summary <- summarise_gnomad_clinvar_variants(clinvar_fixture)

    expect_equal(summary$other_classifications$conflicting_classifications_of_pathogenicity, 1)
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
