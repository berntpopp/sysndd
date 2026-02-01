# Test file: test-llm-batch.R
# Unit tests for LLM batch generator functions

# Source the required functions
source_api_file("functions/llm-service.R", local = FALSE)
source_api_file("functions/llm-batch-generator.R", local = FALSE)
source_api_file("functions/llm-cache-repository.R", local = FALSE)
source_api_file("functions/job-progress.R", local = FALSE)

# Skip if database not available (integration tests)
skip_if_no_db <- function() {
  skip_if(!exists("db_execute_query", mode = "function"), "Database helpers not loaded")
}

# Skip if Gemini API not configured
skip_if_no_gemini <- function() {
  skip_if(!is_gemini_configured(), "GEMINI_API_KEY not set")
}

# Mock function for testing
mock_get_cached_summary <- function(cluster_hash, require_validated = FALSE) {
  # Return NULL to simulate cache miss
  NULL
}

mock_get_cached_summary_hit <- function(cluster_hash, require_validated = FALSE) {
  # Return a cached result to simulate cache hit
  tibble::tibble(
    cache_id = 123L,
    cluster_hash = cluster_hash,
    summary_json = '{"summary": "test", "tags": ["test"]}',
    validation_status = "pending"
  )
}


test_that("trigger_llm_batch_generation returns skipped when GEMINI_API_KEY not set", {
  # Temporarily unset GEMINI_API_KEY
  original_key <- Sys.getenv("GEMINI_API_KEY")
  Sys.unsetenv("GEMINI_API_KEY")

  # Create mock clusters
  clusters <- tibble::tibble(
    cluster_number = 1L,
    symbols = "BRCA1,TP53",
    term_enrichment = "{}"
  )

  result <- trigger_llm_batch_generation(
    clusters = clusters,
    cluster_type = "functional",
    parent_job_id = "test-123"
  )

  expect_true(result$skipped)
  expect_match(result$reason, "GEMINI_API_KEY")

  # Restore original key
  if (nchar(original_key) > 0) {
    Sys.setenv(GEMINI_API_KEY = original_key)
  }
})


test_that("trigger_llm_batch_generation accepts valid cluster tibble structure", {
  skip_if_no_gemini()

  # Create mock clusters with required columns
  clusters <- tibble::tibble(
    cluster_number = c(1L, 2L),
    symbols = c("BRCA1,TP53", "MECP2,FOXG1"),
    term_enrichment = c("{}", "{}")
  )

  # Function should not error when GEMINI_API_KEY is set
  # Note: Actual job creation requires mirai daemons, so we just test that it doesn't error
  expect_error(
    trigger_llm_batch_generation(
      clusters = clusters,
      cluster_type = "functional",
      parent_job_id = "test-123"
    ),
    NA  # Expect no error
  )
})


test_that("llm_batch_executor handles empty cluster list", {
  # Create empty cluster tibble
  empty_clusters <- tibble::tibble(
    cluster_number = integer(0),
    symbols = character(0),
    term_enrichment = character(0)
  )

  params <- list(
    clusters = empty_clusters,
    cluster_type = "functional",
    parent_job_id = "test-123",
    .__job_id__ = "executor-test-123"
  )

  # Mock create_progress_reporter to avoid file I/O
  mock_reporter <- function(job_id, throttle_seconds = 2) {
    function(step, message, current = NULL, total = NULL) {
      invisible(NULL)
    }
  }

  # Use mockery::stub() for mocking in non-package code
  mockery::stub(llm_batch_executor, "create_progress_reporter", mock_reporter)

  result <- llm_batch_executor(params)

  expect_equal(result$total, 0L)
  expect_equal(result$succeeded, 0L)
  expect_equal(result$failed, 0L)
  expect_equal(result$skipped, 0L)
})


test_that("llm_batch_executor returns correct summary structure", {
  # Create mock cluster with single entry
  clusters <- tibble::tibble(
    cluster_number = 1L,
    symbols = "BRCA1,TP53",
    term_enrichment = "{}"
  )

  params <- list(
    clusters = clusters,
    cluster_type = "functional",
    parent_job_id = "test-123",
    .__job_id__ = "executor-test-456"
  )

  # Mock functions to avoid actual LLM calls and database
  mock_reporter <- function(job_id, throttle_seconds = 2) {
    function(step, message, current = NULL, total = NULL) {
      invisible(NULL)
    }
  }

  # Use mockery::stub() for mocking in non-package code
  mockery::stub(llm_batch_executor, "create_progress_reporter", mock_reporter)
  mockery::stub(llm_batch_executor, "get_cached_summary", mock_get_cached_summary_hit)
  mockery::stub(llm_batch_executor, "generate_cluster_hash", function(...) "mock-hash-123")

  result <- llm_batch_executor(params)

  # Verify result structure
  expect_true("total" %in% names(result))
  expect_true("succeeded" %in% names(result))
  expect_true("failed" %in% names(result))
  expect_true("skipped" %in% names(result))

  expect_equal(result$total, 1L)
  expect_equal(result$skipped, 1L)  # Should skip because mock returns cached result
})


test_that("llm_batch_executor skips cached clusters correctly", {
  # Create mock cluster
  clusters <- tibble::tibble(
    cluster_number = 1L,
    symbols = "BRCA1,TP53",
    term_enrichment = "{}"
  )

  params <- list(
    clusters = clusters,
    cluster_type = "functional",
    parent_job_id = "test-123",
    .__job_id__ = "executor-test-789"
  )

  # Mock functions
  mock_reporter <- function(job_id, throttle_seconds = 2) {
    function(step, message, current = NULL, total = NULL) {
      invisible(NULL)
    }
  }

  # Use mockery::stub() for mocking in non-package code
  mockery::stub(llm_batch_executor, "create_progress_reporter", mock_reporter)
  mockery::stub(llm_batch_executor, "get_cached_summary", mock_get_cached_summary_hit)
  mockery::stub(llm_batch_executor, "generate_cluster_hash", function(...) "mock-hash-456")

  result <- llm_batch_executor(params)

  # Verify that cluster was skipped (found in cache)
  expect_equal(result$skipped, 1L)
  expect_equal(result$succeeded, 0L)
  expect_equal(result$failed, 0L)
})


test_that("llm_batch_executor handles NULL cluster_hash gracefully", {
  # Create mock cluster with missing required columns to trigger hash generation failure
  clusters <- tibble::tibble(
    cluster_number = 1L,
    symbols = "BRCA1,TP53",
    term_enrichment = "{}"
  )

  params <- list(
    clusters = clusters,
    cluster_type = "functional",
    parent_job_id = "test-123",
    .__job_id__ = "executor-test-999"
  )

  # Mock functions
  mock_reporter <- function(job_id, throttle_seconds = 2) {
    function(step, message, current = NULL, total = NULL) {
      invisible(NULL)
    }
  }

  mock_generate_hash_fail <- function(...) {
    stop("Hash generation failed")
  }

  # Use mockery::stub() for mocking in non-package code
  mockery::stub(llm_batch_executor, "create_progress_reporter", mock_reporter)
  mockery::stub(llm_batch_executor, "generate_cluster_hash", mock_generate_hash_fail)

  # Should not error - should handle gracefully and count as failed
  result <- llm_batch_executor(params)

  # Verify that cluster was counted as failed
  expect_equal(result$failed, 1L)
  expect_equal(result$succeeded, 0L)
  expect_equal(result$skipped, 0L)
})
