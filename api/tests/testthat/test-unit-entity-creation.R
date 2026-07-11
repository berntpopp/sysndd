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
#
# Also covers svc_entity_create_full's operation-order contract (#346, Wave 4
# Task 2 split into services/entity-creation-service.R): publication
# preparation before the transaction, entity/review/status writes and commit
# inside one transaction, and rollback on a failure at any write step.

library(testthat)
library(dplyr)
library(tibble)
library(stringr)

# Source dependencies for svc_entity_create_full (production order:
# entity-service.R before entity-creation-service.R, see load_modules.R).
source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/entity-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/status-repository.R", local = FALSE)
source_api_file("functions/phenotype-repository.R", local = FALSE)
source_api_file("functions/ontology-repository.R", local = FALSE)
source_api_file("functions/publication-repository.R", local = FALSE)
source_api_file("services/entity-service.R", local = FALSE)
source_api_file("services/entity-creation-service.R", local = FALSE)

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

# =============================================================================
# svc_entity_create_full Operation-Order Tests (#346, Wave 4 Task 2)
# =============================================================================
#
# svc_entity_create_full moved from entity-service.R to
# entity-creation-service.R. These tests pin down the exact behavior-preserving
# operation order it must keep: publication validation runs BEFORE the
# transaction opens (to keep transactions short), entity -> review ->
# publication/phenotype/variation-ontology connections -> status are written
# inside ONE transaction that then commits, and a failure at any write step
# aborts the whole transaction (nothing after it runs, nothing commits).

entity_creation_order_fixture <- function() {
  list(
    entity_data = list(
      hgnc_id = 1,
      disease_ontology_id_version = "MONDO:0000001",
      hpo_mode_of_inheritance_term = "HP:0000006",
      ndd_phenotype = "Definitive"
    ),
    review_data = list(synopsis = "Test", review_user_id = 1),
    status_data = list(category_id = 1, problematic = 0, status_user_id = 1),
    publications = tibble::tibble(
      publication_id = "PMID:123", publication_type = "additional_references"
    ),
    phenotypes = tibble::tibble(phenotype_id = "HP:0001249", modifier_id = "1"),
    variation_ontology = tibble::tibble(vario_id = "VariO:0001", modifier_id = "1")
  )
}

test_that("svc_entity_create_full preps publications before the transaction and writes/commits entity->review->status in order", {
  fn <- svc_entity_create_full
  call_order <- character(0)
  record <- function(step) call_order <<- c(call_order, step)

  mockery::stub(fn, "svc_entity_validate", function(entity_data) {
    record("validate")
    TRUE
  })
  mockery::stub(fn, "svc_entity_check_duplicate", function(entity_data, pool) {
    record("check_duplicate")
    NULL
  })
  mockery::stub(fn, "publication_validate_ids", function(publication_ids) {
    record("publication_validate_ids")
    TRUE
  })
  mockery::stub(fn, "db_with_transaction", function(code, pool_obj = NULL) {
    record("transaction_begin")
    result <- code("txn_conn")
    record("transaction_commit")
    result
  })
  mockery::stub(fn, "entity_create", function(entity_data, conn = NULL) {
    record("entity_create")
    101L
  })
  mockery::stub(fn, "review_create", function(review_data, conn = NULL) {
    record("review_create")
    202L
  })
  mockery::stub(
    fn, "publication_connect_to_review",
    function(review_id, entity_id, publications, conn = NULL) {
      record("publication_connect")
      invisible(NULL)
    }
  )
  mockery::stub(
    fn, "phenotype_connect_to_review",
    function(review_id, entity_id, phenotypes, conn = NULL) {
      record("phenotype_connect")
      invisible(NULL)
    }
  )
  mockery::stub(
    fn, "variation_ontology_connect_to_review",
    function(review_id, entity_id, variation_ontology, conn = NULL) {
      record("variation_ontology_connect")
      invisible(NULL)
    }
  )
  mockery::stub(fn, "status_create", function(status_data, conn = NULL) {
    record("status_create")
    303L
  })

  fixture <- entity_creation_order_fixture()
  result <- fn(
    entity_data = fixture$entity_data,
    review_data = fixture$review_data,
    status_data = fixture$status_data,
    publications = fixture$publications,
    phenotypes = fixture$phenotypes,
    variation_ontology = fixture$variation_ontology,
    pool = "fake_pool"
  )

  expect_equal(result$status, 200)
  expect_equal(result$entry$entity_id, 101L)
  expect_equal(result$entry$review_id, 202L)
  expect_equal(result$entry$status_id, 303L)

  # Publication preparation (Phase 1) happens strictly before the
  # transaction opens (Phase 2) so transactions stay short.
  expect_lt(
    which(call_order == "publication_validate_ids"),
    which(call_order == "transaction_begin")
  )

  # Inside the transaction: entity -> review -> connections -> status,
  # then commit. No write happens outside transaction_begin/commit.
  transaction_span <- seq(
    which(call_order == "transaction_begin"),
    which(call_order == "transaction_commit")
  )
  expect_equal(
    call_order[transaction_span],
    c(
      "transaction_begin",
      "entity_create",
      "review_create",
      "publication_connect",
      "phenotype_connect",
      "variation_ontology_connect",
      "status_create",
      "transaction_commit"
    )
  )
})

test_that("svc_entity_create_full rolls back the whole transaction when any write step fails", {
  # Canonical in-transaction write order (mirrors the function body).
  write_steps <- c(
    "entity_create", "review_create", "publication_connect_to_review",
    "phenotype_connect_to_review", "variation_ontology_connect_to_review",
    "status_create"
  )

  for (failing_step in write_steps) {
    fn <- svc_entity_create_full
    call_order <- character(0)
    record <- function(step) call_order <<- c(call_order, step)

    make_step <- function(step_name, retval) {
      force(step_name)
      force(retval)
      function(...) {
        if (identical(step_name, failing_step)) {
          stop(paste("Simulated failure in", step_name))
        }
        record(step_name)
        retval
      }
    }

    mockery::stub(fn, "svc_entity_validate", function(entity_data) TRUE)
    mockery::stub(fn, "svc_entity_check_duplicate", function(entity_data, pool) NULL)
    mockery::stub(fn, "publication_validate_ids", function(publication_ids) TRUE)
    mockery::stub(fn, "db_with_transaction", function(code, pool_obj = NULL) {
      record("transaction_begin")
      tryCatch(
        {
          result <- code("txn_conn")
          record("transaction_commit")
          result
        },
        error = function(e) {
          rlang::abort(
            message = paste("Transaction failed:", e$message),
            class = "db_transaction_error"
          )
        }
      )
    })
    mockery::stub(fn, "entity_create", make_step("entity_create", 101L))
    mockery::stub(fn, "review_create", make_step("review_create", 202L))
    mockery::stub(
      fn, "publication_connect_to_review",
      make_step("publication_connect_to_review", NULL)
    )
    mockery::stub(
      fn, "phenotype_connect_to_review",
      make_step("phenotype_connect_to_review", NULL)
    )
    mockery::stub(
      fn, "variation_ontology_connect_to_review",
      make_step("variation_ontology_connect_to_review", NULL)
    )
    mockery::stub(fn, "status_create", make_step("status_create", 303L))

    fixture <- entity_creation_order_fixture()
    result <- fn(
      entity_data = fixture$entity_data,
      review_data = fixture$review_data,
      status_data = fixture$status_data,
      publications = fixture$publications,
      phenotypes = fixture$phenotypes,
      variation_ontology = fixture$variation_ontology,
      pool = "fake_pool"
    )

    expect_equal(result$status, 500, info = failing_step)
    expect_true(
      grepl("rolled back", result$message, ignore.case = TRUE),
      info = failing_step
    )
    # Nothing commits, and nothing AFTER the failing step in the canonical
    # order ever runs (the transaction aborts at the first failure).
    expect_false("transaction_commit" %in% call_order, info = failing_step)
    steps_before_failure <- write_steps[seq_len(match(failing_step, write_steps) - 1)]
    expect_equal(
      call_order,
      c("transaction_begin", steps_before_failure),
      info = failing_step
    )
  }
})
