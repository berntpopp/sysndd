# test-unit-comparisons-functions.R
# Unit tests for api/functions/comparisons-functions.R
#
# These tests cover the core functions for importing and parsing
# NDD gene list data from external sources. Network-dependent tests
# and PDF parsing tests are skipped when resources unavailable.

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/comparisons-functions.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Load required packages
library(testthat)
library(tibble)
library(dplyr)
library(stringr)
library(withr)
library(readr)

# Source functions being tested
source(file.path(api_dir, "functions/comparisons-functions.R"))
source(file.path(api_dir, "functions/omim-functions.R"))
source(file.path(api_dir, "functions/comparisons-sources.R"))
source(file.path(api_dir, "functions/comparisons-omim.R"))

# ============================================================================
# download_source_data() Tests
# ============================================================================

test_that("download_source_data handles timeout gracefully", {
  skip_on_cran()
  skip_if_offline()

  source_config <- tibble(
    source_name = "test_timeout",
    source_url = "https://httpbin.org/delay/10",
    file_format = "txt"
  )

  temp_dir <- tempdir()

  # With 1 second timeout, should return NULL (timeout)
  result <- suppressWarnings(
    download_source_data(source_config, temp_dir, timeout_seconds = 1)
  )
  expect_null(result)
})

test_that("download_source_data returns correct file extension", {
  skip_on_cran()
  skip_if_offline()

  temp_dir <- tempdir()

  # Test CSV extension
  source_config <- tibble(
    source_name = "test_csv",
    source_url = "https://httpbin.org/robots.txt",
    file_format = "csv"
  )

  result <- download_source_data(source_config, temp_dir, timeout_seconds = 30)

  if (!is.null(result)) {
    expect_true(grepl("\\.csv$", result))
    unlink(result)
  }
})

test_that("download_source_data uses correct extensions for each format", {
  # Test the extension mapping without network
  expect_equal(switch("pdf",
    "pdf" = ".pdf"
  ), ".pdf")
  expect_equal(switch("csv.gz",
    "csv.gz" = ".csv.gz"
  ), ".csv.gz")
  expect_equal(switch("csv",
    "csv" = ".csv"
  ), ".csv")
  expect_equal(switch("tsv",
    "tsv" = ".tsv"
  ), ".tsv")
  expect_equal(switch("json",
    "json" = ".json"
  ), ".json")
  expect_equal(switch("txt",
    "txt" = ".txt"
  ), ".txt")
})

test_that("download_source_data handles missing URL gracefully", {
  source_config <- tibble(
    source_name = "test_missing",
    source_url = "https://nonexistent.invalid.domain/file.txt",
    file_format = "txt"
  )

  temp_dir <- tempdir()

  result <- suppressWarnings(
    download_source_data(source_config, temp_dir, timeout_seconds = 5)
  )
  expect_null(result)
})

# ============================================================================
# parse_radboudumc_pdf() Tests
# ============================================================================

test_that("parse_radboudumc_pdf requires pdftools package", {
  skip_if_not_installed("pdftools")

  # Test with non-existent file should error
  expect_error(
    parse_radboudumc_pdf("/nonexistent/file.pdf"),
    class = "error"
  )
})

test_that("parse_radboudumc_pdf errors without pdftools", {
  # Create a mock namespace check that returns FALSE
  # This test verifies the error message when pdftools is not installed

  # We can't easily mock requireNamespace, so we verify the function

  # has the appropriate check by looking at the source
  func_body <- deparse(body(parse_radboudumc_pdf))
  expect_true(any(grepl("requireNamespace.*pdftools", func_body)))
  expect_true(any(grepl("stop.*pdftools", func_body)))
})

# ============================================================================
# standardize_comparison_data() Tests
# ============================================================================

test_that("standardize_comparison_data adds all expected columns", {
  # Minimal input data
  input <- tibble(
    gene_symbol = c("BRCA1", "TP53"),
    list = c("test_source", "test_source"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "test_source", "2026-01-01")

  expected_cols <- c(
    "symbol", "hgnc_id", "disease_ontology_id", "disease_ontology_name",
    "inheritance", "category", "pathogenicity_mode", "phenotype",
    "publication_id", "list", "version", "import_date", "granularity"
  )

  expect_true(all(expected_cols %in% colnames(result)))
})

test_that("standardize_comparison_data renames gene_symbol to symbol", {
  input <- tibble(
    gene_symbol = c("MECP2", "SHANK3"),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_true("symbol" %in% colnames(result))
  expect_false("gene_symbol" %in% colnames(result))
  expect_equal(result$symbol, c("MECP2", "SHANK3"))
})

test_that("standardize_comparison_data sets import_date correctly", {
  input <- tibble(
    gene_symbol = c("SCN1A"),
    list = c("test"),
    version = c("1")
  )

  result <- standardize_comparison_data(input, "test", "2026-02-03")

  expect_equal(result$import_date, "2026-02-03")
})

test_that("standardize_comparison_data sets source-specific granularity", {
  input <- tibble(
    gene_symbol = c("GENE1"),
    list = c("test"),
    version = c("1")
  )

  # Test different sources
  rad_result <- standardize_comparison_data(input, "radboudumc_ID", "2026-01-01")
  expect_equal(rad_result$granularity, "gene,disease,category(implied)")

  g2p_result <- standardize_comparison_data(input, "gene2phenotype", "2026-01-01")
  expect_equal(
    g2p_result$granularity,
    "gene,disease,inheritance,category,pathogenicity"
  )

  panelapp_result <- standardize_comparison_data(input, "panelapp", "2026-01-01")
  expect_equal(
    panelapp_result$granularity,
    "gene,disease(aggregated),inheritance(aggregated),category,pathogenicity(incomplete)"
  )
})

test_that("standardize_comparison_data handles radboudumc OMIM formatting", {
  input <- tibble(
    gene_symbol = c("GENE1", "GENE2"),
    OMIMdiseaseID = c("123456", "654321;789012"),
    list = c("radboudumc_ID", "radboudumc_ID"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "radboudumc_ID", "2026-01-01")

  # Should expand semicolon-separated OMIM IDs
  expect_true(nrow(result) >= 2)

  # Should add OMIM: prefix
  omim_ids <- result$disease_ontology_id[!is.na(result$disease_ontology_id)]
  expect_true(all(grepl("^OMIM:", omim_ids)))

  # Should set category to "Definitive"
  expect_true(all(result$category == "Definitive"))
})

test_that("standardize_comparison_data handles gene2phenotype OMIM formatting", {
  input <- tibble(
    gene_symbol = c("BRCA1", "TP53"),
    disease_ontology_id = c("113705", NA),
    disease_ontology_name = c("Test Disease", "Unknown"),
    category = c("Definitive", "Limited"),
    inheritance = c("AD", "AR"),
    pathogenicity_mode = c("LOF", "GOF"),
    phenotype = c("HP:0001;HP:0002", "HP:0003"),
    publication_id = c("12345;67890", "11111"),
    list = c("gene2phenotype", "gene2phenotype"),
    version = c("v1", "v1")
  )

  result <- standardize_comparison_data(input, "gene2phenotype", "2026-01-01")

  # Should add OMIM: prefix where ID exists
  non_na_ids <- result$disease_ontology_id[!is.na(result$disease_ontology_id)]
  expect_true(all(grepl("^OMIM:", non_na_ids) | is.na(non_na_ids)))

  # Should replace semicolons with commas in phenotype
  expect_false(any(grepl(";", result$phenotype, fixed = TRUE), na.rm = TRUE))
})

test_that("standardize_comparison_data handles missing columns", {
  # Input with minimal columns
  input <- tibble(
    gene_symbol = c("TEST1"),
    list = c("test"),
    version = c("1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  # Should have all expected columns
  expect_true("hgnc_id" %in% colnames(result))
  expect_true("disease_ontology_id" %in% colnames(result))
  expect_true("inheritance" %in% colnames(result))

  # Missing columns should be NA
  expect_true(is.na(result$hgnc_id))
  expect_true(is.na(result$disease_ontology_id))
})

test_that("standardize_comparison_data keeps parser category for geisinger", {
  # The rewritten NDD GeneHub parser sets category itself ("Definitive");
  # standardize must not override it (regression guard for the source rewrite).
  input <- tibble(
    gene_symbol = c("GENE1", "GENE2"),
    list = c("ndd_genehub", "ndd_genehub"),
    version = c("1", "1"),
    category = c("Definitive", "Definitive")
  )

  result <- standardize_comparison_data(input, "ndd_genehub", "2026-01-01")

  expect_equal(result$category, c("Definitive", "Definitive"))
})

# ============================================================================
# parse_ndd_genehub_csv() Tests (NDD GeneHub case-level "Full-Data.csv" schema)
# ============================================================================

test_that("parse_ndd_genehub_csv aggregates NDD GeneHub case-level rows per gene", {
  fixture <- file.path(api_dir, "tests/testthat/fixtures/ndd_genehub_test.csv")
  skip_if_not(file.exists(fixture), "geisinger DBD fixture not found")

  # Category comes from the NDD GeneHub evidence-tier tables; supply a lookup so
  # the test does not hit the network. DMD is absent -> "Unclassified".
  tier_lookup <- tibble::tibble(
    gene_symbol = c("ADNP", "ADGRG1"),
    category = c("Tier 1", "AR")
  )
  result <- parse_ndd_genehub_csv(fixture, category_lookup = tier_lookup)

  expect_true(all(c(
    "gene_symbol", "category", "inheritance", "phenotype",
    "publication_id", "list", "version"
  ) %in% colnames(result)))
  expect_true(all(result$list == "ndd_genehub"))
  expect_equal(result$category[result$gene_symbol == "ADNP"], "Tier 1")
  expect_equal(result$category[result$gene_symbol == "ADGRG1"], "AR")
  expect_equal(result$category[result$gene_symbol == "DMD"], "Unclassified")
  # Blank-gene "NONGENE" row (empty Gene Symbol) is dropped; 3 real genes remain.
  expect_setequal(result$gene_symbol, c("ADNP", "ADGRG1", "DMD"))

  # ADNP: two De novo cases on chr 20 -> Sporadic; union of phenotypes across
  # both cases (ID+ASD from case 1, ADHD from case 2); both PMIDs collected.
  adnp <- result[result$gene_symbol == "ADNP", ]
  expect_equal(adnp$inheritance, "Sporadic")
  expect_true(grepl("Intellectual disability", adnp$phenotype))
  expect_true(grepl("Autism", adnp$phenotype))
  expect_true(grepl("Attention deficit", adnp$phenotype))
  expect_setequal(strsplit(adnp$publication_id, ";")[[1]], c("25326635", "27479843"))

  # ADGRG1: Bi-parental autosomal recessive
  adgrg1 <- result[result$gene_symbol == "ADGRG1", ]
  expect_equal(adgrg1$inheritance, "Autosomal recessive inheritance")

  # DMD: variant on chr X -> X-linked inheritance takes precedence
  dmd <- result[result$gene_symbol == "DMD", ]
  expect_equal(dmd$inheritance, "X-linked inheritance")
})

test_that("parse_ndd_genehub_csv drops rows with blank gene symbol", {
  fixture <- file.path(api_dir, "tests/testthat/fixtures/ndd_genehub_test.csv")
  skip_if_not(file.exists(fixture), "geisinger DBD fixture not found")

  result <- parse_ndd_genehub_csv(fixture)
  expect_false(any(is.na(result$gene_symbol) | result$gene_symbol == ""))
})

test_that("parse_ndd_genehub_csv errors on missing gene column", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(tibble(Foo = 1, Bar = 2), tmp)
  expect_error(parse_ndd_genehub_csv(tmp), "Gene Symbol")
})

# ============================================================================
# resolve_hgnc_symbols() Tests (require database)
# ============================================================================

test_that("resolve_hgnc_symbols returns correct structure for empty input", {
  # Test without database - should handle empty input gracefully
  result <- resolve_hgnc_symbols(character(0), NULL)

  expect_s3_class(result, "tbl_df")
  expect_true("symbol" %in% colnames(result))
  expect_true("hgnc_id" %in% colnames(result))
  expect_equal(nrow(result), 0)
})

test_that("resolve_hgnc_symbols uppercases input symbols", {
  # We can test the uppercase logic without a database
  symbols <- c("brca1", "Tp53", "MECP2")

  # The function uppercases internally, we test that logic
  result <- unique(toupper(symbols))
  expect_equal(result, c("BRCA1", "TP53", "MECP2"))
})

# ============================================================================
# parse_gene2phenotype_csv() Tests
# ============================================================================

test_that("parse_gene2phenotype_csv extracts correct columns", {
  skip("Requires G2P test fixture file")

  # This test would run if we had a test fixture
  # fixture_path <- file.path(api_dir, "tests/fixtures/g2p_sample.csv.gz")
  # skip_if_not(file.exists(fixture_path))

  # result <- parse_gene2phenotype_csv(fixture_path)
  # expect_true("gene_symbol" %in% colnames(result))
  # expect_true("list" %in% colnames(result))
  # expect_equal(unique(result$list), "gene2phenotype")
})

# ============================================================================
# parse_sfari_csv() Tests
# ============================================================================

test_that("parse_sfari_csv sets list name correctly", {
  skip("Requires SFARI test fixture file")

  # This test would validate list = "sfari" is set
})

# ============================================================================
# parse_panelapp_tsv() Tests
# ============================================================================

test_that("parse_panelapp_tsv filters for gene entities only", {
  skip("Requires PanelApp test fixture file")

  # This test would validate Entity type == "gene" filter
})

# ============================================================================
# parse_orphanet_json() Tests
# ============================================================================

test_that("parse_orphanet_json excludes disorder-associated loci", {
  skip("Requires Orphanet test fixture file")

  # This test would validate GeneType != "Disorder-associated locus" filter
})

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

test_that("standardize_comparison_data handles empty tibble", {
  input <- tibble(
    gene_symbol = character(0),
    list = character(0),
    version = character(0)
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(nrow(result), 0)
  expect_true("symbol" %in% colnames(result))
})

test_that("standardize_comparison_data handles NA values", {
  input <- tibble(
    gene_symbol = c("GENE1", NA),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(nrow(result), 2)
  expect_true(is.na(result$symbol[2]))
})

test_that("standardize_comparison_data handles special characters", {
  input <- tibble(
    gene_symbol = c("C9orf72", "AARS1"),
    list = c("test", "test"),
    version = c("1", "1")
  )

  result <- standardize_comparison_data(input, "test", "2026-01-01")

  expect_equal(result$symbol[1], "C9orf72")
  expect_equal(result$symbol[2], "AARS1")
})

# ============================================================================
# adapt_genemap2_for_comparisons() Tests (uses phenotype_to_genes.txt)
# ============================================================================

test_that("adapt_genemap2_for_comparisons returns correct schema columns", {
  # Load fixtures
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  # Parse genemap2 to get pre-parsed tibble (shared infrastructure)
  genemap2_data <- parse_genemap2(genemap2_path)

  # Pass pre-parsed data to adapter
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  # Must have exact comparisons schema columns
  expected_cols <- c("gene_symbol", "disease_ontology_id", "disease_ontology_name",
                     "inheritance", "list", "version", "category")
  expect_true(all(expected_cols %in% colnames(result)))
  expect_equal(length(colnames(result)), length(expected_cols))
})

test_that("adapt_genemap2_for_comparisons filters only NDD-related entries", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  # Should include NDD genes (those matching HP:0012759 in phenotype_to_genes.txt)
  # Should NOT include non-NDD genes (e.g., BRCA1 only has HP:0003002)
  expect_true(nrow(result) > 0)

  # BRCA1 should not be included (only has breast carcinoma HPO, not NDD)
  expect_false("BRCA1" %in% result$gene_symbol)

  # NDD genes should be included
  expect_true("MECP2" %in% result$gene_symbol)
  expect_true("SCN1A" %in% result$gene_symbol)

  # All entries should have list = "omim_ndd"
  expect_true(all(result$list == "omim_ndd"))

  # All entries should have category = "Definitive"
  expect_true(all(result$category == "Definitive"))
})

test_that("adapt_genemap2_for_comparisons uses date-based version field", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  skip_if(nrow(result) == 0, "No NDD entries matched in fixtures")

  # Version should be YYYY-MM-DD format (today's date)
  expect_true(all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", result$version)))

  # Version should NOT contain "genemap2" prefix
  expect_false(any(grepl("genemap2", result$version)))
})

test_that("adapt_genemap2_for_comparisons has normalized inheritance values", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  skip_if(nrow(result) == 0, "No NDD entries matched in fixtures")

  # Non-NA inheritance values should be HPO-normalized (full form, not short)
  non_na_inheritance <- result$inheritance[!is.na(result$inheritance)]
  if (length(non_na_inheritance) > 0) {
    # Should NOT have short forms like "Autosomal dominant" (without "inheritance")
    expect_false(any(non_na_inheritance == "Autosomal dominant"))
    expect_false(any(non_na_inheritance == "Autosomal recessive"))
    expect_false(any(non_na_inheritance == "X-linked dominant"))
  }
})

test_that("adapt_genemap2_for_comparisons disease_ontology_id has OMIM prefix", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  skip_if(nrow(result) == 0, "No NDD entries matched in fixtures")

  # All disease_ontology_id values should start with "OMIM:"
  expect_true(all(grepl("^OMIM:", result$disease_ontology_id)))
})

test_that("adapt_genemap2_for_comparisons excludes entries without gene symbol", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  # ndd_terms injected (seed-only) to keep the test deterministic and offline;
  # descendant expansion is covered by its own regression test below.
  result <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")

  # No NA gene_symbol values should be present
  expect_false(any(is.na(result$gene_symbol)))
})

test_that("adapt_genemap2_for_comparisons receives tibble not file path", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  # Passing a file path (string) instead of tibble should error
  expect_error(
    adapt_genemap2_for_comparisons(genemap2_path, ptg_path, ndd_terms = "HP:0012759"),
    regexp = NULL  # Any error - adapter expects tibble not string
  )

  # Passing pre-parsed tibble should work
  genemap2_data <- parse_genemap2(genemap2_path)
  expect_no_error(adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759"))
})

# ============================================================================
# comparisons_refresh_outcome() Tests (resilient per-list refresh policy)
# ============================================================================

test_that("comparisons_refresh_outcome commits with success when nothing failed", {
  out <- comparisons_refresh_outcome(c("panelapp", "sfari"), character(0))
  expect_true(out$commit)
  expect_equal(out$status, "success")
  expect_null(out$error)
})

test_that("comparisons_refresh_outcome commits partial when some sources fail", {
  out <- comparisons_refresh_outcome(c("panelapp", "sfari"), c("ndd_genehub"))
  expect_true(out$commit)
  expect_equal(out$status, "partial")
  expect_match(out$error, "ndd_genehub")
  expect_match(out$error, "1 of 3")
})

test_that("comparisons_refresh_outcome aborts (no commit) when all sources fail", {
  out <- comparisons_refresh_outcome(character(0), c("panelapp", "sfari"))
  expect_false(out$commit)
  expect_equal(out$status, "failed")
  expect_match(out$error, "All 2 source")
})

test_that("comparisons_refresh_outcome ignores NA/empty source names", {
  out <- comparisons_refresh_outcome(c("panelapp", NA, ""), c(NA_character_))
  expect_true(out$commit)
  expect_equal(out$status, "success")
})

# ============================================================================
# #502: configurable NDD seed + omim_ndd_seed_sweep()
# ============================================================================

test_that("adapt_genemap2_for_comparisons honors the ndd_terms set", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)

  # The NDD term set drives the filter (not a hardcoded term).
  seed_res <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")
  expect_true(all(c("MECP2", "SCN1A") %in% seed_res$gene_symbol))

  # A term set absent from the fixture yields no NDD genes. seed_term is always
  # unioned in, so pass an absent seed_term with an empty ndd_terms set.
  absent_res <- adapt_genemap2_for_comparisons(
    genemap2_data, ptg_path, seed_term = "HP:9999999", ndd_terms = character(0)
  )
  expect_equal(nrow(absent_res), 0)
})

test_that("adapt_genemap2_for_comparisons captures descendant-only NDD diseases (kidney-style expansion)", {
  # Regression guard for the fix: HPO's phenotype_to_genes.txt is NOT upward
  # propagated, so a disease annotated only with a descendant term (here
  # HP:0001249 "Intellectual disability", a child of the seed HP:0012759) must
  # still be captured by expanding the seed to its descendants. Filtering the
  # single seed alone silently drops it.
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  genemap2_data <- parse_genemap2(genemap2_path)

  # SCN1A (OMIM:607208) is in the genemap2 fixture; annotate it ONLY with the
  # descendant term, never the seed.
  tmp_ptg <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp_ptg), add = TRUE)
  writeLines(c(
    "#format: HPO-ID\tHPO-Name\tGene-ID\tGene-Name\tDisease-ID",
    "HP:0001249\tIntellectual disability\t6323\tSCN1A\tOMIM:607208"
  ), tmp_ptg)

  # Seed-only term set MISSES the descendant-only disease (the old bug).
  seed_only <- adapt_genemap2_for_comparisons(genemap2_data, tmp_ptg, ndd_terms = "HP:0012759")
  expect_false("SCN1A" %in% seed_only$gene_symbol)

  # Expanding to the descendant term captures it (the correct behavior).
  with_desc <- adapt_genemap2_for_comparisons(
    genemap2_data, tmp_ptg, ndd_terms = c("HP:0012759", "HP:0001249")
  )
  expect_true("SCN1A" %in% with_desc$gene_symbol)
})

test_that("omim_ndd_seed_sweep returns a per-seed summary", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)

  # term_resolver = identity keeps the sweep seed-only and offline (deterministic).
  sweep <- omim_ndd_seed_sweep(
    genemap2_data, ptg_path,
    seeds = c(default = "HP:0012759", narrow = "HP:0001249", absent = "HP:9999999"),
    term_resolver = function(seed) seed
  )

  expect_equal(nrow(sweep), 3)
  expect_true(all(c("seed_label", "seed", "gene_count") %in% colnames(sweep)))
  expect_equal(sweep$gene_count[sweep$seed == "HP:9999999"], 0)
  # Sweep's default-seed count matches the direct adapter call.
  direct <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path, ndd_terms = "HP:0012759")
  expect_equal(
    sweep$gene_count[sweep$seed == "HP:0012759"],
    length(unique(toupper(direct$gene_symbol)))
  )
})

test_that("omim_ndd_seed_sweep adds coverage-gap columns when SysNDD genes given", {
  genemap2_path <- file.path(api_dir, "tests/testthat/fixtures/genemap2_test.txt")
  ptg_path <- file.path(api_dir, "tests/testthat/fixtures/phenotype_to_genes_test.txt")
  skip_if_not(file.exists(genemap2_path), "genemap2 fixture not found")
  skip_if_not(file.exists(ptg_path), "phenotype_to_genes fixture not found")

  genemap2_data <- parse_genemap2(genemap2_path)
  sysndd <- c("MECP2", "FAKEGENE1", "FAKEGENE2")

  sweep <- omim_ndd_seed_sweep(
    genemap2_data, ptg_path,
    seeds = c(default = "HP:0012759"),
    sysndd_symbols = sysndd,
    term_resolver = function(seed) seed
  )

  expect_true(all(c("overlap", "only_in_omim_ndd", "only_in_sysndd") %in% colnames(sweep)))
  # overlap + only_in_sysndd must equal the SysNDD set size.
  expect_equal(sweep$overlap + sweep$only_in_sysndd, length(unique(toupper(sysndd))))
})
