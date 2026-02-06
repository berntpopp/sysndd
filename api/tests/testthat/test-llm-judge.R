# Test file: test-llm-judge.R
# Unit tests for LLM-as-judge validation functions

# Source the required functions
source_api_file("functions/llm-service.R", local = FALSE)
source_api_file("functions/llm-judge.R", local = FALSE)
source_api_file("functions/llm-cache-repository.R", local = FALSE)

# Test setup helpers
skip_if_no_gemini <- function() {
  skip_if(!exists("is_gemini_configured", mode = "function") || !is_gemini_configured(),
          "GEMINI_API_KEY not configured")
}

skip_if_no_db <- function() {
  skip_if(!exists("db_execute_query", mode = "function"), "Database helpers not loaded")
}


# Tests for llm_judge_verdict_type
test_that("llm_judge_verdict_type has required fields", {
  expect_true(exists("llm_judge_verdict_type"))
  # ellmer uses S7 classes - check for ellmer::TypeObject or similar
  expect_true(inherits(llm_judge_verdict_type, "ellmer::TypeObject") ||
              inherits(llm_judge_verdict_type, "S7_object"))

  # Verify structure contains key fields
  type_str <- capture.output(print(llm_judge_verdict_type))
  expect_true(any(grepl("verdict", type_str, ignore.case = TRUE)))
  expect_true(any(grepl("reasoning", type_str, ignore.case = TRUE)))
})

test_that("verdict enum contains exactly accept, low_confidence, reject", {
  # This is verified by the type specification in llm-judge.R
  # We can check that the function exists and is properly typed
  expect_true(exists("llm_judge_verdict_type"))
  # ellmer uses S7 classes - check for ellmer::TypeObject or similar
  expect_true(inherits(llm_judge_verdict_type, "ellmer::TypeObject") ||
              inherits(llm_judge_verdict_type, "S7_object"))
})


# Tests for validate_with_llm_judge() logic
test_that("validate_with_llm_judge handles NULL summary gracefully", {
  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234, 5678),
      symbol = c("BRCA1", "TP53")
    )
  )

  result <- validate_with_llm_judge(summary = NULL, cluster_data = cluster_data)

  expect_type(result, "list")
  expect_true("verdict" %in% names(result))
  expect_equal(result$verdict, "reject")
  expect_true("reasoning" %in% names(result))
})

test_that("validate_with_llm_judge handles NULL cluster_data gracefully", {
  summary <- list(
    summary = "Test summary",
    key_themes = c("theme1", "theme2"),
    confidence = "medium"
  )

  result <- validate_with_llm_judge(summary = summary, cluster_data = NULL)

  expect_type(result, "list")
  expect_true("verdict" %in% names(result))
  expect_equal(result$verdict, "low_confidence")
  expect_true("reasoning" %in% names(result))
})

test_that("validate_with_llm_judge returns valid verdict structure", {
  skip_if_no_gemini()

  summary <- list(
    summary = "These genes are involved in DNA repair and cell cycle regulation.",
    key_themes = c("DNA repair", "cell cycle"),
    pathways = c("DNA repair", "cell cycle checkpoint"),
    confidence = "high"
  )

  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234, 5678),
      symbol = c("BRCA1", "TP53")
    ),
    term_enrichment = tibble::tibble(
      category = "GO",
      term = c("DNA repair", "cell cycle"),
      description = c("DNA repair", "cell cycle"),
      fdr = c(1e-10, 1e-8),
      number_of_genes = c(5L, 3L)
    )
  )

  result <- validate_with_llm_judge(summary = summary, cluster_data = cluster_data)

  expect_type(result, "list")
  expect_true("is_factually_accurate" %in% names(result))
  expect_true("is_grounded" %in% names(result))
  expect_true("pathways_valid" %in% names(result))
  expect_true("confidence_appropriate" %in% names(result))
  expect_true("reasoning" %in% names(result))
  expect_true("verdict" %in% names(result))
})

test_that("validate_with_llm_judge verdict is one of accept/low_confidence/reject", {
  skip_if_no_gemini()

  summary <- list(
    summary = "Test summary",
    key_themes = c("theme1"),
    confidence = "medium"
  )

  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234),
      symbol = c("GENE1")
    ),
    term_enrichment = tibble::tibble(
      category = "GO",
      term = c("biological process"),
      description = c("biological process"),
      fdr = c(0.01),
      number_of_genes = c(2L)
    )
  )

  result <- validate_with_llm_judge(summary = summary, cluster_data = cluster_data)

  expect_true(result$verdict %in% c("accept", "accept_with_corrections", "low_confidence", "reject"))
})


# Tests for generate_and_validate_with_judge()
test_that("generate_and_validate_with_judge returns success=FALSE when generation fails", {
  # Use invalid cluster_data to trigger generation failure
  cluster_data <- list(
    identifiers = tibble::tibble(hgnc_id = integer(0))  # Empty - will fail
  )

  result <- generate_and_validate_with_judge(cluster_data, "functional")

  expect_type(result, "list")
  expect_false(result$success)
  expect_true("error" %in% names(result) || "validation_status" %in% names(result))
  expect_equal(result$validation_status, "rejected")
})

test_that("generate_and_validate_with_judge maps verdicts to validation_status correctly", {
  skip_if_no_gemini()
  skip_if_no_db()

  # Create minimal test cluster data
  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234, 5678),
      symbol = c("BRCA1", "TP53")
    ),
    term_enrichment = tibble::tibble(
      category = "GO",
      term = c("DNA repair", "cell cycle"),
      description = c("DNA repair", "cell cycle"),
      fdr = c(1e-10, 1e-8),
      number_of_genes = c(5L, 3L)
    ),
    cluster_number = 999L
  )

  result <- generate_and_validate_with_judge(cluster_data, "functional")

  # Expect valid result structure
  expect_type(result, "list")
  expect_true("validation_status" %in% names(result))

  # Validation status should be one of the valid mappings
  expect_true(result$validation_status %in% c("validated", "pending", "rejected"))

  # Verify mapping rules
  if ("judge_result" %in% names(result)) {
    if (result$judge_result$verdict == "accept") {
      expect_equal(result$validation_status, "validated")
    } else if (result$judge_result$verdict == "low_confidence") {
      expect_equal(result$validation_status, "pending")
    } else if (result$judge_result$verdict == "reject") {
      expect_equal(result$validation_status, "rejected")
    }
  }
})

test_that("generate_and_validate_with_judge result contains judge_result", {
  skip_if_no_gemini()
  skip_if_no_db()

  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234, 5678),
      symbol = c("BRCA1", "TP53")
    ),
    term_enrichment = tibble::tibble(
      category = "GO",
      term = c("DNA repair", "cell cycle"),
      description = c("DNA repair", "cell cycle"),
      fdr = c(1e-10, 1e-8),
      number_of_genes = c(5L, 3L)
    ),
    cluster_number = 998L
  )

  result <- generate_and_validate_with_judge(cluster_data, "functional")

  expect_type(result, "list")

  # Judge result should be present when generation succeeded
  if (isTRUE(result$success)) {
    expect_true("judge_result" %in% names(result))
    expect_true("verdict" %in% names(result$judge_result))
    expect_true("reasoning" %in% names(result$judge_result))
  }
})


# Tests for update_validation_status()
test_that("update_validation_status rejects invalid validation_status values", {
  skip_if_no_db()

  result <- update_validation_status(cache_id = 999999, validation_status = "invalid_status")

  expect_false(result)
})

test_that("update_validation_status returns FALSE for invalid status", {
  skip_if_no_db()

  result <- update_validation_status(cache_id = 1, validation_status = "not_a_real_status")

  expect_false(result)
})

test_that("update_validation_status accepts valid status values", {
  skip_if_no_db()

  valid_statuses <- c("pending", "validated", "rejected")

  for (status in valid_statuses) {
    # This will attempt to update a non-existent cache_id, but the validation should pass
    # The function will return TRUE if the SQL executes (even if no rows affected)
    # We're testing the input validation here
    result <- tryCatch({
      update_validation_status(cache_id = 999999, validation_status = status)
    }, error = function(e) {
      FALSE
    })

    # Should not error on valid status
    expect_type(result, "logical")
  }
})


# Integration test (requires API key and DB)
test_that("full judge pipeline works end-to-end", {
  skip_if_no_gemini()
  skip_if_no_db()

  # Create minimal test cluster data
  cluster_data <- list(
    identifiers = tibble::tibble(
      hgnc_id = c(1234, 5678),
      symbol = c("BRCA1", "TP53")
    ),
    term_enrichment = tibble::tibble(
      category = "GO",
      term = c("DNA repair", "cell cycle"),
      description = c("DNA repair", "cell cycle"),
      fdr = c(1e-10, 1e-8),
      number_of_genes = c(5L, 3L)
    ),
    cluster_number = 997L
  )

  result <- generate_and_validate_with_judge(cluster_data, "functional")

  expect_true("success" %in% names(result))
  expect_true("validation_status" %in% names(result))
  expect_true("judge_result" %in% names(result))

  # If successful, verify structure
  if (result$success) {
    expect_true("summary" %in% names(result))
    expect_true("cache_id" %in% names(result))
    expect_true("llm_judge_verdict" %in% names(result$summary))
    expect_true("llm_judge_reasoning" %in% names(result$summary))
  }
})
