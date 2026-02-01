# Test file: test-llm-benchmark.R
# LLM prompt benchmark tests with ground truth comparison
#
# Purpose: Validate LLM prompt quality by comparing generated summaries
# against known-correct ground truth data from Phase 63 validation.
#
# Usage:
#   # Run all benchmark tests (requires GEMINI_API_KEY)
#   testthat::test_file('tests/testthat/test-llm-benchmark.R')
#
#   # Run only unit tests (no API key needed)
#   testthat::test_file('tests/testthat/test-llm-benchmark.R', filter='fixture')
#
# Ground truth source: .planning/PHASE_63_LLM_PIPELINE_FINAL.md
#
# Scoring methodology (Phase 63):
#   - 9-10: Excellent - all terms verbatim, no hallucinations
#   - 7-8: Good - minor generalizations, no fabrications
#   - 5-6: Acceptable - some inaccuracies but core themes correct
#   - 1-4: Poor - significant hallucinations or missing themes

# Load required packages
library(testthat)
library(tibble)
library(dplyr)
library(jsonlite)

# Determine api directory path (handles testthat working directory changes)
api_dir <- if (basename(getwd()) == "testthat") {
  normalizePath(file.path(getwd(), "..", ".."))
} else if (basename(getwd()) == "tests") {
  normalizePath(file.path(getwd(), ".."))
} else if (file.exists("functions/llm-service.R")) {
  getwd()
} else {
  normalizePath(file.path(getwd(), "api"))
}

# Source LLM functions for benchmarking
original_wd <- getwd()
setwd(api_dir)
tryCatch({
  library(logger)
  library(glue)
  suppressWarnings({
    if (file.exists("functions/llm-service.R")) {
      source("functions/llm-service.R")
    }
    if (file.exists("functions/llm-validation.R")) {
      source("functions/llm-validation.R")
    }
  })
}, error = function(e) {
  message("Note: LLM functions not loaded - ", e$message)
})
setwd(original_wd)


# ==============================================================================
# Test Helpers
# ==============================================================================

#' Skip test if Gemini API is not configured
#'
#' @description Skips the test if GEMINI_API_KEY environment variable is not set.
#' Use this for tests that require actual LLM API calls.
skip_if_no_gemini <- function() {
  skip_if(!exists("is_gemini_configured", mode = "function") || !is_gemini_configured(),
          "GEMINI_API_KEY not configured")
}


#' Load benchmark ground truth data
#'
#' @description Loads the ground truth fixture data for benchmark comparisons.
#' @return List with functional_clusters, phenotype_clusters, and scoring_criteria
load_benchmark_ground_truth <- function() {
  fixture_path <- testthat::test_path("fixtures", "llm-benchmark-ground-truth.json")
  if (!file.exists(fixture_path)) {
    stop("Ground truth fixture not found: ", fixture_path)
  }
  jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
}


# ==============================================================================
# Scoring Functions
# ==============================================================================

#' Score a functional cluster summary against ground truth
#'
#' @description Evaluates a functional cluster summary on a 1-10 scale based on:
#'   - Pathway accuracy (verbatim matches from ground_truth_pathways)
#'   - Theme coverage (overlap with ground_truth_themes)
#'   - No hallucinated pathways (not in ground truth)
#'
#' @param summary List with summary, pathways, key_themes fields
#' @param ground_truth List with ground_truth_pathways, ground_truth_themes fields
#' @return List with score (1-10), reasoning (character), details (list)
score_functional_summary <- function(summary, ground_truth) {
  if (is.null(summary) || is.null(ground_truth)) {
    return(list(
      score = 1L,
      reasoning = "NULL summary or ground truth provided",
      details = list()
    ))
  }

  # Extract pathways from summary (handle both list and character vector)
  summary_pathways <- if (!is.null(summary$pathways)) {
    unlist(summary$pathways)
  } else {
    character(0)
  }

  # Extract themes from summary
  summary_themes <- if (!is.null(summary$key_themes)) {
    unlist(summary$key_themes)
  } else {
    character(0)
  }

  # Get ground truth data
  gt_pathways <- unlist(ground_truth$ground_truth_pathways)
  gt_themes <- unlist(ground_truth$ground_truth_themes)

  # Score pathway accuracy (case-insensitive verbatim match)
  pathway_matches <- sum(tolower(summary_pathways) %in% tolower(gt_pathways))
  pathway_total <- length(summary_pathways)
  hallucinated_pathways <- summary_pathways[!tolower(summary_pathways) %in% tolower(gt_pathways)]

  # Score theme coverage (partial match allowed)
  theme_matches <- sum(sapply(summary_themes, function(theme) {
    any(sapply(gt_themes, function(gt) {
      grepl(tolower(gt), tolower(theme), fixed = TRUE) ||
        grepl(tolower(theme), tolower(gt), fixed = TRUE)
    }))
  }))
  theme_total <- length(summary_themes)

  # Calculate component scores
  pathway_score <- if (pathway_total == 0) {
    5  # Neutral if no pathways
  } else if (length(hallucinated_pathways) > 0) {
    max(1, 5 - length(hallucinated_pathways))  # Penalize hallucinations heavily
  } else {
    min(10, 5 + (pathway_matches / max(1, length(gt_pathways))) * 5)
  }

  theme_score <- if (theme_total == 0) {
    5  # Neutral if no themes
  } else {
    min(10, 5 + (theme_matches / theme_total) * 5)
  }

  # Final score is weighted average
  final_score <- round((pathway_score * 0.6 + theme_score * 0.4))

  # Generate reasoning
  reasoning_parts <- c()
  if (pathway_total > 0) {
    reasoning_parts <- c(reasoning_parts,
      sprintf("Pathways: %d/%d matched", pathway_matches, pathway_total))
    if (length(hallucinated_pathways) > 0) {
      reasoning_parts <- c(reasoning_parts,
        sprintf("Hallucinated: %s", paste(hallucinated_pathways, collapse = ", ")))
    }
  }
  if (theme_total > 0) {
    reasoning_parts <- c(reasoning_parts,
      sprintf("Themes: %d/%d covered", theme_matches, theme_total))
  }

  reasoning <- paste(reasoning_parts, collapse = "; ")

  return(list(
    score = as.integer(final_score),
    reasoning = reasoning,
    details = list(
      pathway_matches = pathway_matches,
      pathway_total = pathway_total,
      hallucinated_pathways = hallucinated_pathways,
      theme_matches = theme_matches,
      theme_total = theme_total,
      pathway_score = pathway_score,
      theme_score = theme_score
    )
  ))
}


#' Score a phenotype cluster summary against ground truth
#'
#' @description Evaluates a phenotype cluster summary on a 1-10 scale based on:
#'   - Phenotype accuracy (terms from ground_truth_phenotypes_enriched)
#'   - No molecular/gene terms present (automatic penalty)
#'   - Clinical pattern matches expected
#'
#' @param summary List with summary, key_phenotype_themes, clinical_pattern fields
#' @param ground_truth List with ground_truth_phenotypes_enriched, expected_clinical_pattern
#' @return List with score (1-10), reasoning (character), details (list)
score_phenotype_summary <- function(summary, ground_truth) {
  if (is.null(summary) || is.null(ground_truth)) {
    return(list(
      score = 1L,
      reasoning = "NULL summary or ground truth provided",
      details = list()
    ))
  }

  # Forbidden molecular terms (from llm-judge.R)
  forbidden_terms <- c(
    "gene", "protein", "pathway", "signaling", "transcription",
    "chromatin", "histone", "methylation", "enzyme", "receptor",
    "kinase", "mTOR", "MAPK", "DNA repair", "RNA processing"
  )

  # Get summary text and themes
  summary_text <- paste(
    summary$summary %||% "",
    paste(unlist(summary$key_phenotype_themes %||% summary$key_themes %||% list()), collapse = " "),
    collapse = " "
  )

  # Check for forbidden terms
  forbidden_found <- sapply(forbidden_terms, function(term) {
    grepl(term, summary_text, ignore.case = TRUE)
  })
  forbidden_count <- sum(forbidden_found)

  # Get phenotype themes
  summary_phenotypes <- unlist(summary$key_phenotype_themes %||% summary$key_themes %||% list())

  # Get ground truth phenotypes

  gt_phenotypes <- unlist(ground_truth$ground_truth_phenotypes_enriched)

  # Score phenotype accuracy (partial match)
  phenotype_matches <- sum(sapply(summary_phenotypes, function(pheno) {
    any(sapply(gt_phenotypes, function(gt) {
      grepl(tolower(gt), tolower(pheno), fixed = TRUE) ||
        grepl(tolower(pheno), tolower(gt), fixed = TRUE)
    }))
  }))
  phenotype_total <- length(summary_phenotypes)

  # Check clinical pattern match
  clinical_pattern <- summary$clinical_pattern %||% ""
  expected_pattern <- ground_truth$expected_clinical_pattern %||% ""
  pattern_match <- if (nchar(expected_pattern) > 0 && nchar(clinical_pattern) > 0) {
    grepl(tolower(expected_pattern), tolower(clinical_pattern), fixed = TRUE) ||
      grepl(tolower(clinical_pattern), tolower(expected_pattern), fixed = TRUE)
  } else {
    TRUE  # Skip if not specified
  }

  # Calculate component scores
  forbidden_penalty <- min(5, forbidden_count * 2)  # Heavy penalty for molecular terms
  phenotype_score <- if (phenotype_total == 0) {
    5
  } else {
    min(10, 5 + (phenotype_matches / phenotype_total) * 5)
  }
  pattern_score <- if (pattern_match) 10 else 5

  # Final score
  final_score <- max(1, round((phenotype_score * 0.5 + pattern_score * 0.2) - forbidden_penalty + 3))
  final_score <- min(10, max(1, final_score))

  # Generate reasoning
  reasoning_parts <- c()
  if (forbidden_count > 0) {
    reasoning_parts <- c(reasoning_parts,
      sprintf("FORBIDDEN TERMS: %d found", forbidden_count))
  }
  if (phenotype_total > 0) {
    reasoning_parts <- c(reasoning_parts,
      sprintf("Phenotypes: %d/%d matched", phenotype_matches, phenotype_total))
  }
  if (nchar(expected_pattern) > 0) {
    reasoning_parts <- c(reasoning_parts,
      sprintf("Pattern: %s", if (pattern_match) "matched" else "mismatch"))
  }

  reasoning <- paste(reasoning_parts, collapse = "; ")

  return(list(
    score = as.integer(final_score),
    reasoning = reasoning,
    details = list(
      forbidden_count = forbidden_count,
      forbidden_found = names(forbidden_found)[forbidden_found],
      phenotype_matches = phenotype_matches,
      phenotype_total = phenotype_total,
      pattern_match = pattern_match,
      phenotype_score = phenotype_score,
      pattern_score = pattern_score
    )
  ))
}


# ==============================================================================
# Mock Cluster Data Generators
# ==============================================================================

#' Create mock functional cluster data from ground truth
#'
#' @description Creates a cluster_data structure suitable for prompt building
#' based on ground truth data. Used for benchmark testing.
#'
#' @param ground_truth List with ground_truth_pathways, ground_truth_themes
#' @param cluster_number Integer cluster number
#' @return List with identifiers and term_enrichment tibbles
create_mock_functional_cluster <- function(ground_truth, cluster_number = 1L) {
  # Create mock gene identifiers
  mock_genes <- tibble::tibble(
    hgnc_id = seq_len(10),
    symbol = paste0("GENE", seq_len(10))
  )

  # Create mock enrichment from ground truth pathways
  pathways <- unlist(ground_truth$ground_truth_pathways)
  themes <- unlist(ground_truth$ground_truth_themes)

  enrichment_rows <- tibble::tibble(
    category = c(rep("KEGG", length(pathways)), rep("GO:BP", length(themes))),
    term = c(pathways, paste0("GO:", seq_along(themes))),
    description = c(pathways, themes),
    fdr = c(rep(1e-15, length(pathways)), rep(1e-10, length(themes))),
    number_of_genes = rep(5L, length(pathways) + length(themes))
  )

  list(
    identifiers = mock_genes,
    term_enrichment = enrichment_rows,
    cluster_number = cluster_number
  )
}


#' Create mock phenotype cluster data from ground truth
#'
#' @description Creates a cluster_data structure for phenotype clusters
#' based on ground truth data. Used for benchmark testing.
#'
#' @param ground_truth List with ground_truth_phenotypes_enriched/depleted
#' @param cluster_number Integer cluster number
#' @return List with identifiers and quali_inp_var tibbles
create_mock_phenotype_cluster <- function(ground_truth, cluster_number = 1L) {
  # Create mock entity identifiers
  mock_entities <- tibble::tibble(
    entity_id = seq_len(20)
  )

  # Create mock phenotype data from ground truth
  enriched <- unlist(ground_truth$ground_truth_phenotypes_enriched)
  depleted <- unlist(ground_truth$ground_truth_phenotypes_depleted)

  phenotype_rows <- tibble::tibble(
    variable = c(enriched, depleted),
    v.test = c(rep(5.0, length(enriched)), rep(-3.0, length(depleted))),
    p.value = rep(1e-10, length(enriched) + length(depleted))
  )

  list(
    identifiers = mock_entities,
    quali_inp_var = phenotype_rows,
    cluster_number = cluster_number
  )
}


# ==============================================================================
# Unit Tests - Fixture Loading (no API key required)
# ==============================================================================

test_that("ground truth fixture loads correctly", {
  ground_truth <- load_benchmark_ground_truth()

  # Verify structure
  expect_true("functional_clusters" %in% names(ground_truth))
  expect_true("phenotype_clusters" %in% names(ground_truth))
  expect_true("scoring_criteria" %in% names(ground_truth))

  # Verify functional clusters
  fc <- ground_truth$functional_clusters
  expect_true("1" %in% names(fc))
  expect_true("3" %in% names(fc))

  # Verify phenotype clusters
  pc <- ground_truth$phenotype_clusters
  expect_true("3" %in% names(pc))
  expect_true("4" %in% names(pc))
})


test_that("ground truth fixture contains Phase 63 documented data", {
  ground_truth <- load_benchmark_ground_truth()

  # Functional cluster 1 - Developmental/Growth Signaling
  fc1 <- ground_truth$functional_clusters[["1"]]
  expect_false(isTRUE(fc1$ground_truth_pending))
  expect_equal(fc1$phase_63_score, 10)
  expect_true("PI3K-Akt signaling pathway" %in% unlist(fc1$ground_truth_pathways))
  expect_true("Ras signaling pathway" %in% unlist(fc1$ground_truth_pathways))

  # Functional cluster 3 - Chromatin/Epigenetic
  fc3 <- ground_truth$functional_clusters[["3"]]
  expect_false(isTRUE(fc3$ground_truth_pending))
  expect_equal(fc3$phase_63_score, 10)
  expect_true("Lysine degradation" %in% unlist(fc3$ground_truth_pathways))
  expect_true("Cell cycle" %in% unlist(fc3$ground_truth_pathways))

  # Phenotype cluster 3 - Progressive/Metabolic
  pc3 <- ground_truth$phenotype_clusters[["3"]]
  expect_false(isTRUE(pc3$ground_truth_pending))
  expect_equal(pc3$phase_63_score, 10)
  expect_true("Progressive" %in% unlist(pc3$ground_truth_phenotypes_enriched))

  # Phenotype cluster 4 - Syndromic Malformations
  pc4 <- ground_truth$phenotype_clusters[["4"]]
  expect_false(isTRUE(pc4$ground_truth_pending))
  expect_equal(pc4$phase_63_score, 9)
})


test_that("ground truth fixture marks pending clusters correctly", {
  ground_truth <- load_benchmark_ground_truth()

  # Check functional cluster 2 is pending
  fc2 <- ground_truth$functional_clusters[["2"]]
  expect_true(isTRUE(fc2$ground_truth_pending))
  expect_null(fc2$phase_63_score)

  # Check phenotype cluster 1 is pending
  pc1 <- ground_truth$phenotype_clusters[["1"]]
  expect_true(isTRUE(pc1$ground_truth_pending))
  expect_null(pc1$phase_63_score)
})


test_that("scoring criteria has required thresholds", {
  ground_truth <- load_benchmark_ground_truth()
  criteria <- ground_truth$scoring_criteria

  expect_true("thresholds" %in% names(criteria))

  thresholds <- criteria$thresholds
  expect_true("excellent" %in% names(thresholds))
  expect_true("good" %in% names(thresholds))
  expect_true("acceptable" %in% names(thresholds))
  expect_true("poor" %in% names(thresholds))

  # Verify threshold values
  expect_equal(thresholds$excellent$min, 9)
  expect_equal(thresholds$good$min, 7)
  expect_equal(thresholds$acceptable$min, 5)
  expect_equal(thresholds$poor$min, 1)
})


# ==============================================================================
# Unit Tests - Scoring Functions (no API key required)
# ==============================================================================

test_that("score_functional_summary scores perfect match correctly", {
  summary <- list(
    pathways = c("PI3K-Akt signaling pathway", "Ras signaling pathway"),
    key_themes = c("growth signaling", "developmental regulation")
  )

  ground_truth <- list(
    ground_truth_pathways = c("PI3K-Akt signaling pathway", "Ras signaling pathway", "Pathways in cancer"),
    ground_truth_themes = c("growth signaling", "developmental regulation", "cancer pathways")
  )

  result <- score_functional_summary(summary, ground_truth)

  expect_gte(result$score, 8)  # Should be high score
  expect_equal(result$details$pathway_matches, 2)
  expect_equal(length(result$details$hallucinated_pathways), 0)
})


test_that("score_functional_summary penalizes hallucinated pathways", {
  summary <- list(
    pathways = c("PI3K-Akt signaling pathway", "Made up pathway", "Another fake pathway"),
    key_themes = c("growth signaling")
  )

  ground_truth <- list(
    ground_truth_pathways = c("PI3K-Akt signaling pathway", "Ras signaling pathway"),
    ground_truth_themes = c("growth signaling")
  )

  result <- score_functional_summary(summary, ground_truth)

  expect_lte(result$score, 6)  # Should be lower due to hallucinations
  expect_equal(length(result$details$hallucinated_pathways), 2)
  expect_true(grepl("Hallucinated", result$reasoning))
})


test_that("score_phenotype_summary scores perfect match correctly", {
  summary <- list(
    key_phenotype_themes = c("Progressive", "metabolic", "regression"),
    clinical_pattern = "progressive metabolic/degenerative"
  )

  ground_truth <- list(
    ground_truth_phenotypes_enriched = c("Progressive", "early mortality", "mitochondrial", "metabolic", "regression"),
    expected_clinical_pattern = "progressive metabolic/degenerative"
  )

  result <- score_phenotype_summary(summary, ground_truth)

  expect_gte(result$score, 7)  # Should be high score
  expect_equal(result$details$forbidden_count, 0)
  expect_true(result$details$pattern_match)
})


test_that("score_phenotype_summary heavily penalizes molecular terms", {
  summary <- list(
    summary = "These genes are involved in chromatin remodeling and transcription regulation.",
    key_phenotype_themes = c("Progressive", "metabolic")
  )

  ground_truth <- list(
    ground_truth_phenotypes_enriched = c("Progressive", "metabolic"),
    expected_clinical_pattern = "progressive"
  )

  result <- score_phenotype_summary(summary, ground_truth)

  expect_lte(result$score, 5)  # Should be heavily penalized
  expect_gt(result$details$forbidden_count, 0)
  expect_true(grepl("FORBIDDEN", result$reasoning))
})


test_that("score_phenotype_summary handles empty ground truth", {
  summary <- list(
    key_phenotype_themes = c("seizures", "developmental delay")
  )

  ground_truth <- list(
    ground_truth_phenotypes_enriched = list(),
    expected_clinical_pattern = NULL
  )

  result <- score_phenotype_summary(summary, ground_truth)

  expect_type(result$score, "integer")
  expect_gte(result$score, 1)
  expect_lte(result$score, 10)
})


# ==============================================================================
# Unit Tests - Mock Cluster Generation (no API key required)
# ==============================================================================

test_that("create_mock_functional_cluster creates valid structure", {
  ground_truth <- list(
    ground_truth_pathways = c("Pathway A", "Pathway B"),
    ground_truth_themes = c("theme1", "theme2", "theme3")
  )

  cluster_data <- create_mock_functional_cluster(ground_truth, cluster_number = 5L)

  expect_true("identifiers" %in% names(cluster_data))
  expect_true("term_enrichment" %in% names(cluster_data))
  expect_equal(cluster_data$cluster_number, 5L)

  # Check identifiers structure
  expect_true("hgnc_id" %in% names(cluster_data$identifiers))
  expect_true("symbol" %in% names(cluster_data$identifiers))

  # Check enrichment structure
  expect_true("category" %in% names(cluster_data$term_enrichment))
  expect_true("term" %in% names(cluster_data$term_enrichment))
  expect_true("fdr" %in% names(cluster_data$term_enrichment))
})


test_that("create_mock_phenotype_cluster creates valid structure", {
  ground_truth <- list(
    ground_truth_phenotypes_enriched = c("Seizures", "Developmental delay"),
    ground_truth_phenotypes_depleted = c("Tall stature")
  )

  cluster_data <- create_mock_phenotype_cluster(ground_truth, cluster_number = 3L)

  expect_true("identifiers" %in% names(cluster_data))
  expect_true("quali_inp_var" %in% names(cluster_data))
  expect_equal(cluster_data$cluster_number, 3L)

  # Check phenotype data structure
  phenotypes <- cluster_data$quali_inp_var
  expect_true("variable" %in% names(phenotypes))
  expect_true("v.test" %in% names(phenotypes))
  expect_true("p.value" %in% names(phenotypes))

  # Check v.test directions
  expect_true(all(phenotypes$v.test[phenotypes$variable %in% c("Seizures", "Developmental delay")] > 0))
  expect_true(all(phenotypes$v.test[phenotypes$variable == "Tall stature"] < 0))
})


# ==============================================================================
# Integration Tests - Functional Cluster Benchmarks (requires GEMINI_API_KEY)
# ==============================================================================

test_that("functional cluster 1 achieves benchmark score >= 8", {
  skip_if_no_gemini()
  skip_if(!exists("build_cluster_prompt", mode = "function"), "LLM service not loaded")

  ground_truth <- load_benchmark_ground_truth()
  cluster_gt <- ground_truth$functional_clusters[["1"]]

  # Skip if ground truth not yet defined
  skip_if(isTRUE(cluster_gt$ground_truth_pending), "Ground truth pending for cluster 1")

  # Create mock cluster data with known enrichment terms
  cluster_data <- create_mock_functional_cluster(cluster_gt, cluster_number = 1L)

  # Build prompt (verify prompt building works)
  prompt <- build_cluster_prompt(cluster_data, top_n_terms = 20)
  expect_true(nchar(prompt) > 100)

  # Generate summary using actual LLM
  result <- generate_cluster_summary(cluster_data, cluster_type = "functional")

  expect_true(result$success, info = paste("Generation failed:", result$error))

  # Score against ground truth
  score_result <- score_functional_summary(result$summary, cluster_gt)

  # Log score for reporting
  message(sprintf("Functional Cluster 1 score: %d/10 - %s", score_result$score, score_result$reasoning))

  # Assert minimum benchmark score
  expect_gte(score_result$score, 8,
             info = paste("Benchmark failed:", score_result$reasoning))
})


test_that("functional cluster 3 achieves benchmark score >= 8", {
  skip_if_no_gemini()
  skip_if(!exists("build_cluster_prompt", mode = "function"), "LLM service not loaded")

  ground_truth <- load_benchmark_ground_truth()
  cluster_gt <- ground_truth$functional_clusters[["3"]]

  # Skip if ground truth not yet defined
  skip_if(isTRUE(cluster_gt$ground_truth_pending), "Ground truth pending for cluster 3")

  # Create mock cluster data
  cluster_data <- create_mock_functional_cluster(cluster_gt, cluster_number = 3L)

  # Generate summary
  result <- generate_cluster_summary(cluster_data, cluster_type = "functional")

  expect_true(result$success, info = paste("Generation failed:", result$error))

  # Score against ground truth
  score_result <- score_functional_summary(result$summary, cluster_gt)

  message(sprintf("Functional Cluster 3 score: %d/10 - %s", score_result$score, score_result$reasoning))

  expect_gte(score_result$score, 8,
             info = paste("Benchmark failed:", score_result$reasoning))
})


# ==============================================================================
# Integration Tests - Phenotype Cluster Benchmarks (requires GEMINI_API_KEY)
# ==============================================================================

test_that("phenotype cluster 3 achieves benchmark score >= 7", {
  skip_if_no_gemini()
  skip_if(!exists("build_phenotype_cluster_prompt", mode = "function"), "LLM service not loaded")

  ground_truth <- load_benchmark_ground_truth()
  cluster_gt <- ground_truth$phenotype_clusters[["3"]]

  # Skip if ground truth not yet defined
  skip_if(isTRUE(cluster_gt$ground_truth_pending), "Ground truth pending for cluster 3")

  # Create mock cluster data
  cluster_data <- create_mock_phenotype_cluster(cluster_gt, cluster_number = 3L)

  # Build prompt (verify prompt building works)
  prompt <- build_phenotype_cluster_prompt(cluster_data, vtest_threshold = 2)
  expect_true(nchar(prompt) > 100)

  # Generate summary
  result <- generate_cluster_summary(cluster_data, cluster_type = "phenotype")

  expect_true(result$success, info = paste("Generation failed:", result$error))

  # Score against ground truth
  score_result <- score_phenotype_summary(result$summary, cluster_gt)

  message(sprintf("Phenotype Cluster 3 score: %d/10 - %s", score_result$score, score_result$reasoning))

  # Phenotype clusters have stricter requirements, so we accept >= 7
  expect_gte(score_result$score, 7,
             info = paste("Benchmark failed:", score_result$reasoning))
})


test_that("phenotype cluster 4 achieves benchmark score >= 7", {
  skip_if_no_gemini()
  skip_if(!exists("build_phenotype_cluster_prompt", mode = "function"), "LLM service not loaded")

  ground_truth <- load_benchmark_ground_truth()
  cluster_gt <- ground_truth$phenotype_clusters[["4"]]

  # Skip if ground truth not yet defined
  skip_if(isTRUE(cluster_gt$ground_truth_pending), "Ground truth pending for cluster 4")

  # Create mock cluster data
  cluster_data <- create_mock_phenotype_cluster(cluster_gt, cluster_number = 4L)

  # Generate summary
  result <- generate_cluster_summary(cluster_data, cluster_type = "phenotype")

  expect_true(result$success, info = paste("Generation failed:", result$error))

  # Score against ground truth
  score_result <- score_phenotype_summary(result$summary, cluster_gt)

  message(sprintf("Phenotype Cluster 4 score: %d/10 - %s", score_result$score, score_result$reasoning))

  expect_gte(score_result$score, 7,
             info = paste("Benchmark failed:", score_result$reasoning))
})


# ==============================================================================
# Batch Benchmark Summary (requires GEMINI_API_KEY)
# ==============================================================================

test_that("batch benchmark summary reports aggregated scores", {
  skip_if_no_gemini()
  skip_if(!exists("generate_cluster_summary", mode = "function"), "LLM service not loaded")

  ground_truth <- load_benchmark_ground_truth()

  # Collect scores for documented clusters only
  scores <- list()

  # Functional clusters with documented ground truth
  for (cluster_id in c("1", "3")) {
    cluster_gt <- ground_truth$functional_clusters[[cluster_id]]
    if (!isTRUE(cluster_gt$ground_truth_pending)) {
      cluster_data <- create_mock_functional_cluster(cluster_gt, cluster_number = as.integer(cluster_id))
      result <- tryCatch({
        generate_cluster_summary(cluster_data, cluster_type = "functional")
      }, error = function(e) list(success = FALSE, error = e$message))

      if (result$success) {
        score_result <- score_functional_summary(result$summary, cluster_gt)
        scores[[paste0("functional_", cluster_id)]] <- score_result$score
        message(sprintf("  Functional %s: %d/10", cluster_id, score_result$score))
      }
    }
  }

  # Phenotype clusters with documented ground truth
  for (cluster_id in c("3", "4")) {
    cluster_gt <- ground_truth$phenotype_clusters[[cluster_id]]
    if (!isTRUE(cluster_gt$ground_truth_pending)) {
      cluster_data <- create_mock_phenotype_cluster(cluster_gt, cluster_number = as.integer(cluster_id))
      result <- tryCatch({
        generate_cluster_summary(cluster_data, cluster_type = "phenotype")
      }, error = function(e) list(success = FALSE, error = e$message))

      if (result$success) {
        score_result <- score_phenotype_summary(result$summary, cluster_gt)
        scores[[paste0("phenotype_", cluster_id)]] <- score_result$score
        message(sprintf("  Phenotype %s: %d/10", cluster_id, score_result$score))
      }
    }
  }

  # Report aggregated results
  if (length(scores) > 0) {
    avg_score <- mean(unlist(scores))
    message(sprintf("\nBenchmark Summary: %.1f/10 average across %d clusters", avg_score, length(scores)))

    # Overall benchmark should average >= 7.5
    expect_gte(avg_score, 7.5,
               info = sprintf("Average score %.1f below benchmark threshold of 7.5", avg_score))
  } else {
    skip("No benchmark scores collected - all API calls failed")
  }
})
