# tests/testthat/test-unit-field-key-label.R
# Column labels built from field keys keep their acronyms (ui-quality PUB-09 / S-07):
# tables read "HGNC ID", not "Hgnc id".

library(testthat)
library(dplyr)
library(tidyr)
library(tibble)
library(stringr)

api_dir <- if (basename(getwd()) == "api") {
  getwd()
} else if (file.exists("../../functions/response-fields-helpers.R")) {
  normalizePath("../..")
} else {
  stop("Cannot find api directory")
}
source(file.path(api_dir, "functions", "response-fields-helpers.R"))

test_that("field_key_label upper-cases known acronyms only as whole words", {
  expect_equal(
    field_key_label(c(
      "hgnc_id", "entrez_id", "ucsc_id", "bed_hg19", "pmid", "doi",
      "fdr_bh", "npmi", "symbol", "ndd_phenotype_word", "hpo_mode_of_inheritance_term_name"
    )),
    c(
      "HGNC ID", "Entrez ID", "UCSC ID", "BED hg19", "PMID", "DOI",
      "FDR BH", "NPMI", "Symbol", "NDD phenotype word", "HPO mode of inheritance term name"
    )
  )
  # "id" inside a word is not an acronym
  expect_equal(field_key_label("is_valid"), "Is valid")
})

test_that("generate_tibble_fspec labels columns with field_key_label", {
  fspec <- generate_tibble_fspec(
    tibble(hgnc_id = c("HGNC:1", "HGNC:2"), symbol = c("A", "B")),
    "hgnc_id,symbol"
  )$fspec
  expect_equal(fspec$label, c("HGNC ID", "Symbol"))
})
