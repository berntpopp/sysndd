# tests/testthat/test-unit-entity-creation.R
# Unit tests for entity creation logic
#
# These tests validate the response aggregation logic used in entity creation,
# specifically the direct_approval flow that combines responses from:
# - Entity creation (post_db_entity)
# - Review creation (put_post_db_review)
# - Review approval (put_db_review_approve)
# - Status creation (put_post_db_status)
# - Status approval (put_db_status_approve)

library(testthat)
library(dplyr)
library(tibble)
library(stringr)

# =============================================================================
# Response Aggregation Tests
# =============================================================================

test_that("direct approval includes review approval in aggregation", {
  # Simulate the responses from entity creation endpoint
  response_publication <- list(status = 200, message = "OK. Publications created.")
  response_review <- list(status = 200, message = "OK. Review created.")
  response_publication_conn <- list(status = 200, message = "OK. Publications connected.")
  response_phenotype_connections <- list(status = 200, message = "OK. Phenotypes connected.")
  resp_variation_ontology_conn <- list(status = 200, message = "OK. Variation ontology connected.")
  response_review_approve <- list(status = 200, message = "OK. Review approved.")

  # Simulate the aggregation logic from entity_endpoints.R (lines 382-397)
  direct_approval <- TRUE
  response_review_post <- tibble::as_tibble(response_publication) %>%
    bind_rows(tibble::as_tibble(response_review)) %>%
    bind_rows(tibble::as_tibble(response_publication_conn)) %>%
    bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
    bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_review_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify review approval is included in aggregation
  expect_equal(response_review_post$status, 200)
  expect_true(grepl("Review approved", response_review_post$message))
})

test_that("review approval failure surfaces in aggregated response", {
  # Simulate the responses where review approval fails
  response_publication <- list(status = 200, message = "OK. Publications created.")
  response_review <- list(status = 200, message = "OK. Review created.")
  response_publication_conn <- list(status = 200, message = "OK. Publications connected.")
  response_phenotype_connections <- list(status = 200, message = "OK. Phenotypes connected.")
  resp_variation_ontology_conn <- list(status = 200, message = "OK. Variation ontology connected.")
  response_review_approve <- list(status = 500, message = "Error approving review.")

  # Simulate the aggregation logic
  direct_approval <- TRUE
  response_review_post <- tibble::as_tibble(response_publication) %>%
    bind_rows(tibble::as_tibble(response_review)) %>%
    bind_rows(tibble::as_tibble(response_publication_conn)) %>%
    bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
    bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_review_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify failure status surfaces via max(status)
  expect_equal(response_review_post$status, 500)
  expect_true(grepl("Error approving review", response_review_post$message))
})

test_that("non-direct approval excludes review approval from aggregation", {
  # Simulate the responses for normal (non-direct) approval flow
  response_publication <- list(status = 200, message = "OK. Publications created.")
  response_review <- list(status = 200, message = "OK. Review created.")
  response_publication_conn <- list(status = 200, message = "OK. Publications connected.")
  response_phenotype_connections <- list(status = 200, message = "OK. Phenotypes connected.")
  resp_variation_ontology_conn <- list(status = 200, message = "OK. Variation ontology connected.")

  # Simulate the aggregation logic WITHOUT direct approval
  direct_approval <- FALSE
  response_review_post <- tibble::as_tibble(response_publication) %>%
    bind_rows(tibble::as_tibble(response_review)) %>%
    bind_rows(tibble::as_tibble(response_publication_conn)) %>%
    bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
    bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
    {
      if (direct_approval) {
        # This branch should NOT execute
        bind_rows(., tibble::as_tibble(list(status = 999, message = "Should not appear")))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify review approval is NOT included
  expect_equal(response_review_post$status, 200)
  expect_false(grepl("Should not appear", response_review_post$message))
})

test_that("direct approval includes status approval in final aggregation", {
  # Simulate the responses for final aggregation (entity + review + status)
  response_entity <- list(status = 200, message = "OK. Entry created.")
  response_review_post <- list(status = 200, message = "OK. Review steps completed.")
  response_status_post <- list(status = 200, message = "OK. Status created.")
  response_status_approve <- list(status = 200, message = "OK. Status approved.")

  # Simulate the final aggregation logic from entity_endpoints.R (lines 488-501)
  direct_approval <- TRUE
  response <- tibble::as_tibble(response_entity) %>%
    bind_rows(tibble::as_tibble(response_review_post)) %>%
    bind_rows(tibble::as_tibble(response_status_post)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_status_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify status approval is included
  expect_equal(response$status, 200)
  expect_true(grepl("Status approved", response$message))
})

test_that("status approval failure surfaces in final response", {
  # Simulate the responses where status approval fails
  response_entity <- list(status = 200, message = "OK. Entry created.")
  response_review_post <- list(status = 200, message = "OK. Review steps completed.")
  response_status_post <- list(status = 200, message = "OK. Status created.")
  response_status_approve <- list(status = 500, message = "Error approving status.")

  # Simulate the final aggregation logic
  direct_approval <- TRUE
  response <- tibble::as_tibble(response_entity) %>%
    bind_rows(tibble::as_tibble(response_review_post)) %>%
    bind_rows(tibble::as_tibble(response_status_post)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_status_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify failure status surfaces via max(status)
  expect_equal(response$status, 500)
  expect_true(grepl("Error approving status", response$message))
})

test_that("successful direct approval aggregation has all messages", {
  # Simulate complete successful direct approval flow
  response_publication <- list(status = 200, message = "Publications OK")
  response_review <- list(status = 200, message = "Review OK")
  response_publication_conn <- list(status = 200, message = "Publications connected OK")
  response_phenotype_connections <- list(status = 200, message = "Phenotypes OK")
  resp_variation_ontology_conn <- list(status = 200, message = "Variation ontology OK")
  response_review_approve <- list(status = 200, message = "Review approved OK")

  direct_approval <- TRUE
  response_review_post <- tibble::as_tibble(response_publication) %>%
    bind_rows(tibble::as_tibble(response_review)) %>%
    bind_rows(tibble::as_tibble(response_publication_conn)) %>%
    bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
    bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_review_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify all messages are present in aggregation
  expect_equal(response_review_post$status, 200)
  expect_true(grepl("Publications OK", response_review_post$message))
  expect_true(grepl("Review OK", response_review_post$message))
  expect_true(grepl("Review approved OK", response_review_post$message))
})

test_that("multiple failures aggregate to highest status code", {
  # Simulate multiple failures in direct approval flow
  response_publication <- list(status = 200, message = "OK")
  response_review <- list(status = 404, message = "Review not found")
  response_publication_conn <- list(status = 200, message = "OK")
  response_phenotype_connections <- list(status = 500, message = "Database error")
  resp_variation_ontology_conn <- list(status = 200, message = "OK")
  response_review_approve <- list(status = 403, message = "Forbidden")

  direct_approval <- TRUE
  response_review_post <- tibble::as_tibble(response_publication) %>%
    bind_rows(tibble::as_tibble(response_review)) %>%
    bind_rows(tibble::as_tibble(response_publication_conn)) %>%
    bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
    bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
    {
      if (direct_approval) {
        bind_rows(., tibble::as_tibble(response_review_approve))
      } else {
        .
      }
    } %>%
    dplyr::select(status, message) %>%
    mutate(status = max(status)) %>%
    mutate(message = str_c(message, collapse = "; ")) %>%
    unique()

  # Verify max(status) picks highest error code (500)
  expect_equal(response_review_post$status, 500)
  # All error messages should be present
  expect_true(grepl("Review not found", response_review_post$message))
  expect_true(grepl("Database error", response_review_post$message))
  expect_true(grepl("Forbidden", response_review_post$message))
})
