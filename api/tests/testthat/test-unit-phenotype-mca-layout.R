# The positional supplementary-block contract for the phenotype MCA (#630).

source_api_file("functions/analysis-phenotype-mca-prep.R", local = FALSE)

mk <- function(cols) {
  m <- as.data.frame(stats::setNames(
    lapply(cols, function(x) if (grepl("count$", x)) 1L else "AD"), cols
  ), stringsAsFactors = FALSE)
  m$`Seizures` <- "yes"
  m
}

test_that("the expected layout passes", {
  expect_true(phenotype_mca_assert_supplementary_layout(
    mk(PHENOTYPE_MCA_SUPPLEMENTARY_COLUMNS)
  ))
})

test_that("a reordered supplementary block is rejected, not silently accepted", {
  swapped <- PHENOTYPE_MCA_SUPPLEMENTARY_COLUMNS[c(1, 3, 2, 4)]
  expect_error(
    phenotype_mca_assert_supplementary_layout(mk(swapped)),
    "supplementary layout drifted"
  )
})

test_that("the retired phenotype_non_id_count name is rejected", {
  legacy <- c("hpo_mode_of_inheritance_term_name", "phenotype_non_id_count",
              "phenotype_id_count", "gene_entity_count")
  expect_error(
    phenotype_mca_assert_supplementary_layout(mk(legacy)),
    "supplementary layout drifted"
  )
})

test_that("an extra leading column is rejected", {
  extra <- c("unexpected_count", PHENOTYPE_MCA_SUPPLEMENTARY_COLUMNS)
  expect_error(
    phenotype_mca_assert_supplementary_layout(mk(extra)),
    "supplementary layout drifted"
  )
})
