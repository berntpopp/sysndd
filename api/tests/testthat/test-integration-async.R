# tests/testthat/test-integration-async.R
# Integration tests for async operations
#
# These tests verify that async job endpoints work correctly:
# - Job submission returns 202 with job_id
# - Job status polling returns valid responses
# - Non-existent jobs return 404

library(testthat)
library(httr2)

# =============================================================================
# Helper: Check if API is running
# =============================================================================

skip_if_api_not_running <- function() {
  is_running <- tryCatch(
    {
      request("http://localhost:8000/health") %>%
        req_timeout(2) %>%
        req_perform()
      TRUE
    },
    error = function(e) FALSE
  )

  if (!is_running) {
    testthat::skip("API not running on localhost:8000")
  }
}

# =============================================================================
# Job Status Endpoint Tests
# =============================================================================

test_that("job status endpoint returns 404 for non-existent job", {
  skip_if_api_not_running()

  # Test with non-existent job ID (should return 404)
  resp <- request("http://localhost:8000/api/jobs/status/nonexistent-job-id-12345") %>%
    req_error(is_error = \(resp) FALSE) %>%
    req_perform()

  expect_equal(resp_status(resp), 404)
})

test_that("job status endpoint accepts valid job ID format", {
  skip_if_api_not_running()

  # Test that endpoint is accessible (will return 404 for fake job, but endpoint works)
  resp <- request("http://localhost:8000/api/jobs/status/test-job-id") %>%
    req_error(is_error = \(resp) FALSE) %>%
    req_perform()

  # Should be 404 (job doesn't exist) not 500 (endpoint broken)
  expect_true(resp_status(resp) %in% c(200, 404))
})

# =============================================================================
# Async Clustering Job Tests (Requires Authentication)
# =============================================================================

test_that("async clustering endpoint requires authentication", {
  skip_if_api_not_running()
  skip("Requires valid JWT token for authentication")

  # This test requires valid JWT token
  # Manual verification:
  # 1. Get JWT token via /api/auth/signin
  # 2. POST to /api/jobs/clustering/submit with Authorization header
  # 3. Verify response is 202 with job_id
  # 4. GET /api/jobs/status/{job_id} to check status
})

test_that("async clustering returns 202 with job_id", {
  skip_if_api_not_running()
  skip("Requires valid JWT token for authentication")

  # Manual test steps:
  # 1. Authenticate: POST /api/auth/signin
  # 2. Submit job: POST /api/jobs/clustering/submit
  # 3. Verify response:
  #    - Status: 202 Accepted
  #    - Body: { "job_id": "...", "status": "submitted", "message": "..." }
})

test_that("async job status polling returns correct states", {
  skip_if_api_not_running()
  skip("Requires valid JWT token and active job")

  # Manual test steps:
  # 1. Submit async job (clustering, ontology_update)
  # 2. Poll status: GET /api/jobs/status/{job_id}
  # 3. Verify status transitions:
  #    - "submitted" -> "running" -> "completed" (success)
  #    - "submitted" -> "running" -> "failed" (error)
  # 4. Verify response structure:
  #    - status: string (submitted|running|completed|failed)
  #    - job_id: string
  #    - result: object (when completed)
  #    - error: string (when failed)
})

# =============================================================================
# Async Ontology Update Job Tests (Requires Authentication + Admin Role)
# =============================================================================

test_that("async ontology update requires administrator role", {
  skip_if_api_not_running()
  skip("Requires administrator JWT token")

  # This test requires administrator role
  # Manual verification:
  # 1. Get JWT token for non-admin user
  # 2. POST to /api/jobs/ontology_update/submit
  # 3. Verify response is 403 Forbidden
  # 4. Repeat with admin token
  # 5. Verify response is 202 Accepted with job_id
})

# =============================================================================
# Job Cleanup Tests
# =============================================================================

test_that("job cleanup removes old completed jobs", {
  skip_if_api_not_running()
  skip("Requires observing job cleanup over time")

  # Manual verification:
  # 1. Submit several jobs
  # 2. Wait for completion
  # 3. Observe job cleanup after 24 hours (per async.R cleanup logic)
  # 4. Verify old jobs return 404 from status endpoint
})

# =============================================================================
# Integration Test Documentation
# =============================================================================

# NOTE: Most async operation tests require:
# 1. Running API server
# 2. Valid JWT authentication token
# 3. Database with actual data
# 4. Time to wait for job completion
#
# These tests are documented here but skipped in automated test runs.
# For manual testing:
#
# Authentication:
#   POST /api/auth/signin
#   Body: { "username": "admin", "password": "..." }
#   Returns: { "access_token": "..." }
#
# Submit clustering job:
#   POST /api/jobs/clustering/submit
#   Headers: Authorization: Bearer {token}
#   Returns: { "job_id": "...", "status": "submitted" }
#
# Check job status:
#   GET /api/jobs/status/{job_id}
#   Returns: { "job_id": "...", "status": "running|completed|failed", ... }
#
# Submit ontology update job (admin only):
#   POST /api/jobs/ontology_update/submit
#   Headers: Authorization: Bearer {admin_token}
#   Returns: { "job_id": "...", "status": "submitted" }
