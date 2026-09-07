source_api_file("functions/external-proxy-functions.R", local = FALSE)
source_api_file("functions/external-proxy-clinvar-traits.R", local = FALSE)

test_that("enrich_variants_with_clinvar_traits handles NULL and empty input", {
  expect_identical(enrich_variants_with_clinvar_traits(NULL), list())
  expect_identical(enrich_variants_with_clinvar_traits(list()), list())
})

test_that("enrich_variants_with_clinvar_traits handles variants without variation IDs", {
  input <- list(
    list(variant_id = "1-100-A-T", clinvar_variation_id = NULL),
    list(variant_id = "1-200-G-C", clinvar_variation_id = "")
  )
  res <- enrich_variants_with_clinvar_traits(input)
  expect_equal(length(res), 2)
  expect_identical(res[[1]]$conditions, list())
  expect_identical(res[[1]]$mondo_ids, list())
  expect_identical(res[[1]]$omim_ids, list())
  expect_identical(res[[2]]$conditions, list())
})

test_that("enrich_variants_with_clinvar_traits successfully extracts traits for known variation ID", {
  skip_if_offline()
  # Use variation 40562 (PTPN11 c.1510A>G p.Met504Val Noonan syndrome)
  input <- list(
    list(
      variant_id = "12-112489086-A-G",
      clinvar_variation_id = "40562",
      clinical_significance = "Pathogenic"
    )
  )
  res <- enrich_variants_with_clinvar_traits(input)
  expect_equal(length(res), 1)
  expect_true("Noonan syndrome" %in% unlist(res[[1]]$conditions))
  expect_true("MONDO:0018997" %in% unlist(res[[1]]$mondo_ids))
  expect_true("PS163950" %in% unlist(res[[1]]$omim_ids))
})

test_that("is_clinvar_placeholder_trait correctly identifies placeholders", {
  placeholders <- c(
    "not provided", "Not provided", "NOT PROVIDED",
    "not specified", "Not specified", "NOT SPECIFIED",
    "See cases", "see cases", "not reported",
    "unknown", "unspecified", "none", "-", ".", "", "NA"
  )
  for (p in placeholders) {
    expect_true(is_clinvar_placeholder_trait(p), info = paste("Failed for:", p))
  }

  expect_true(is_clinvar_placeholder_trait(NULL))
  expect_true(is_clinvar_placeholder_trait(NA))

  informative <- c(
    "Noonan syndrome", "Coffin-Siris syndrome 1",
    "ARID1B-Related Disorder", "Inborn genetic diseases",
    "Ataxia, not otherwise specified"
  )
  for (inf in informative) {
    expect_false(is_clinvar_placeholder_trait(inf), info = paste("Failed for:", inf))
  }
})

test_that("normalize_clinvar_trait_name normalizes placeholders to 'Not provided'", {
  expect_equal(normalize_clinvar_trait_name("not provided"), "Not provided")
  expect_equal(normalize_clinvar_trait_name("not specified"), "Not provided")
  expect_equal(normalize_clinvar_trait_name("See cases"), "Not provided")
  expect_equal(normalize_clinvar_trait_name(""), "Not provided")
  expect_equal(normalize_clinvar_trait_name("Coffin-Siris syndrome 1"), "Coffin-Siris syndrome 1")
})

