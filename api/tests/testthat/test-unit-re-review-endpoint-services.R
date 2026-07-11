# tests/testthat/test-unit-re-review-endpoint-services.R
#
# Unit tests for the endpoint-orchestration layer extracted from
# api/endpoints/re_review_endpoints.R (#346):
#   - services/re-review-query-endpoint-service.R    (read-only handlers)
#   - services/re-review-workflow-endpoint-service.R (lifecycle/batch/
#     assignment/recalculation handlers)
#
# Strategy mirrors test-re-review-service.R / test-re-review-refusal-service.R:
# swap db_execute_query/db_execute_statement and, where the svc_ wrapper's
# only job is to derive arguments and forward to an existing domain function
# (batch_create, batch_preview, batch_reassign, batch_archive, entity_assign,
# batch_recalculate, refuse_re_review_entity, clear_re_review_refusal), swap
# THAT function in .GlobalEnv and capture the call. This keeps the suite
# host-runnable without a database.
#
# A handful of handlers (svc_re_review_table_query, the assignment_table DB
# halves, svc_re_review_approve, svc_re_review_batch_apply/assign/unassign)
# build a `pool %>% tbl(...)` dbplyr pipeline copied verbatim from the
# pre-extraction endpoint; that needs a live connection dbplyr can translate
# SQL against, so those cases are guarded with skip_if_no_test_db() rather
# than reimplemented against a mock.
#
# Run with:
#   cd api && Rscript --no-init-file -e \
#     "testthat::test_file('tests/testthat/test-unit-re-review-endpoint-services.R')"

source_api_file("core/errors.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/db-helpers.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/response-helpers.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/pagination-helpers.R", local = FALSE, envir = .GlobalEnv)
source_api_file("functions/response-fields-helpers.R", local = FALSE, envir = .GlobalEnv)

if (!requireNamespace("logger", quietly = TRUE)) {
  stop("logger package not available — cannot run re-review endpoint service tests")
}

# re-review-selection-service.R must be sourced before re-review-service.R:
# svc_re_review_submit() below calls re_review_filter_submit_fields()
# (moved to the selection module in #346 Wave 4) directly, unmocked.
source_api_file("services/re-review-selection-service.R", local = FALSE, envir = .GlobalEnv)
source_api_file("services/re-review-service.R", local = FALSE, envir = .GlobalEnv)
source_api_file("services/re-review-refusal-service.R", local = FALSE, envir = .GlobalEnv)
source_api_file("services/re-review-query-endpoint-service.R", local = FALSE, envir = .GlobalEnv)
source_api_file("services/re-review-workflow-endpoint-service.R", local = FALSE, envir = .GlobalEnv)

# ---------------------------------------------------------------------------
# Mocking helpers
# ---------------------------------------------------------------------------

#' Temporarily rebind one or more .GlobalEnv functions, restoring the
#' originals (or removing the binding if it did not previously exist) on
#' exit — even on error. A single `on.exit()` registered on this function's
#' own frame handles the restoration for every binding.
#'
#' @param bindings Named list of replacement functions, e.g.
#'   list(db_execute_statement = function(...) NULL).
with_global_bindings <- function(bindings, expr) {
  had_original <- sapply(names(bindings), exists, envir = .GlobalEnv)
  originals <- lapply(names(bindings), function(nm) {
    if (had_original[[nm]]) get(nm, envir = .GlobalEnv) else NULL
  })
  names(originals) <- names(bindings)

  for (nm in names(bindings)) {
    assign(nm, bindings[[nm]], envir = .GlobalEnv)
  }

  on.exit({
    for (nm in names(bindings)) {
      if (had_original[[nm]]) {
        assign(nm, originals[[nm]], envir = .GlobalEnv)
      } else if (exists(nm, envir = .GlobalEnv)) {
        rm(list = nm, envir = .GlobalEnv)
      }
    }
  }, add = TRUE)

  force(expr)
}

make_mock_conn <- function() structure(list(), class = "MockPool")

# A statement mock that records every (sql, params) call it received.
make_statement_recorder <- function(return_value = 1L) {
  calls <- new.env(parent = emptyenv())
  calls$log <- list()
  fn <- function(sql, params = list(), conn = NULL) {
    calls$log[[length(calls$log) + 1L]] <- list(sql = sql, params = params)
    return_value
  }
  list(fn = fn, calls = calls)
}

# ===========================================================================
# Query service — pure predicates (query predicates / assignment scoping)
# ===========================================================================

test_that("svc_re_review_table_filter_mode: refused takes priority over curate", {
  expect_equal(svc_re_review_table_filter_mode(curate = FALSE, refused = FALSE), "reviewer_queue")
  expect_equal(svc_re_review_table_filter_mode(curate = TRUE, refused = FALSE), "curate")
  expect_equal(svc_re_review_table_filter_mode(curate = FALSE, refused = TRUE), "refused")
  expect_equal(svc_re_review_table_filter_mode(curate = TRUE, refused = TRUE), "refused")
})

test_that("svc_re_review_table_scope_to_user: only the plain reviewer queue scopes to self", {
  expect_true(svc_re_review_table_scope_to_user(curate = FALSE, refused = FALSE))
  expect_false(svc_re_review_table_scope_to_user(curate = TRUE, refused = FALSE))
  expect_false(svc_re_review_table_scope_to_user(curate = FALSE, refused = TRUE))
  expect_false(svc_re_review_table_scope_to_user(curate = TRUE, refused = TRUE))
})

# ===========================================================================
# Query service — cursor envelope (pure, operates on a collected data frame)
# ===========================================================================

test_that("svc_re_review_paginate wraps generate_cursor_pag_inf_safe in a links/meta/data envelope", {
  df <- tibble::tibble(re_review_entity_id = 1:5, symbol = paste0("GENE", 1:5))

  result <- svc_re_review_paginate(df, page_size = "all", page_after = 0)

  expect_named(result, c("links", "meta", "data"))
  expect_equal(nrow(result$data), 5L)
  expect_equal(result$data$re_review_entity_id, 1:5)
})

test_that("svc_re_review_paginate respects a numeric page_size cursor window", {
  df <- tibble::tibble(re_review_entity_id = 1:10)

  result <- svc_re_review_paginate(df, page_size = 3, page_after = 0)

  expect_equal(nrow(result$data), 3L)
  expect_equal(result$data$re_review_entity_id, 1:3)
})

# ===========================================================================
# Query service — legacy assignment array shape (pure, two collected inputs)
# ===========================================================================

test_that("svc_re_review_assignment_table_combine returns a bare, user-sorted data frame", {
  assignment_user_df <- tibble::tibble(
    assignment_id = c(2L, 1L),
    user_id = c(9L, 3L),
    user_name = c("bob", "alice"),
    re_review_batch = c(20L, 10L)
  )
  entity_connect_summary_df <- tibble::tibble(
    re_review_batch = c(10L, 20L),
    re_review_review_saved = c(1L, 0L),
    re_review_status_saved = c(1L, 0L),
    re_review_submitted = c(1L, 0L),
    re_review_approved = c(0L, 0L),
    entity_count = c(4L, 2L)
  )

  result <- svc_re_review_assignment_table_combine(assignment_user_df, entity_connect_summary_df)

  # Legacy contract: a bare data frame (serializes as a JSON array), not a
  # list(data = ...) envelope.
  expect_true(is.data.frame(result))
  expect_false(is.list(result) && !is.data.frame(result))
  expect_named(
    result,
    c(
      "assignment_id", "user_id", "user_name", "re_review_batch",
      "re_review_review_saved", "re_review_status_saved",
      "re_review_submitted", "re_review_approved", "entity_count"
    )
  )
  # arrange(user_id) ascending.
  expect_equal(result$user_id, c(3L, 9L))
  expect_equal(result$entity_count, c(4L, 2L))
})

# ===========================================================================
# Workflow service — submit allowlisting / unnamed DB params
# ===========================================================================

test_that("svc_re_review_submit builds an allowlisted, unnamed-param UPDATE", {
  rec <- make_statement_recorder(return_value = 1L)

  with_global_bindings(list(db_execute_statement = rec$fn), {
    result <- svc_re_review_submit(list(re_review_entity_id = 42L, re_review_submitted = 1L))
  })

  expect_equal(result, 1L)
  expect_length(rec$calls$log, 1L)
  call <- rec$calls$log[[1L]]
  expect_match(call$sql, "UPDATE re_review_entity_connect SET re_review_submitted = \\? WHERE re_review_entity_id = \\?")
  # Params must be unnamed for the anonymous `?` placeholders (DBI::dbBind contract).
  expect_null(names(call$params))
  expect_equal(call$params, list(1L, 42L))
})

test_that("svc_re_review_submit rejects a mass-assignment field before touching the DB", {
  rec <- make_statement_recorder()

  with_global_bindings(list(db_execute_statement = rec$fn), {
    expect_error(
      svc_re_review_submit(list(re_review_entity_id = 42L, re_review_approved = 1L)),
      class = "error_400"
    )
  })

  expect_length(rec$calls$log, 0L) # no SQL executed
})

# ===========================================================================
# Workflow service — unsubmit
# ===========================================================================

test_that("svc_re_review_unsubmit resets re_review_submitted with a coerced integer id", {
  rec <- make_statement_recorder(return_value = 1L)

  with_global_bindings(list(db_execute_statement = rec$fn), {
    result <- svc_re_review_unsubmit("7")
  })

  expect_equal(result, 1L)
  call <- rec$calls$log[[1L]]
  expect_match(call$sql, "SET re_review_submitted = 0 WHERE re_review_entity_id = \\?")
  expect_equal(call$params, list(7L))
})

# ===========================================================================
# Workflow service — refusal errors
# ===========================================================================

test_that("svc_re_review_refuse rejects a non-integer id before calling the domain service", {
  called <- FALSE
  fake_refuse <- function(...) {
    called <<- TRUE
    list(status = 200, message = "should not be reached")
  }

  with_global_bindings(list(refuse_re_review_entity = fake_refuse), {
    # as.integer("not-an-id") legitimately warns "NAs introduced by coercion"
    # (same as the pre-extraction endpoint body) — suppress it here so the
    # test asserts only the classed-error contract, not that unrelated warning.
    suppressWarnings(
      expect_error(svc_re_review_refuse("not-an-id", 7L, NULL), class = "error_400")
    )
  })
  expect_false(called)
})

test_that("svc_re_review_refuse maps a 404 domain result to stop_for_not_found", {
  fake_refuse <- function(...) list(status = 404, message = "Re-review item not found")

  with_global_bindings(list(refuse_re_review_entity = fake_refuse), {
    expect_error(svc_re_review_refuse(42L, 7L, "too complex"), class = "error_404")
  })
})

test_that("svc_re_review_refuse maps an already-refused (409) domain result to a 400", {
  fake_refuse <- function(...) list(status = 409, message = "Re-review item is already marked as refused")

  with_global_bindings(list(refuse_re_review_entity = fake_refuse), {
    expect_error(svc_re_review_refuse(42L, 7L, NULL), class = "error_400")
  })
})

test_that("svc_re_review_refuse returns message + entry on success", {
  fake_refuse <- function(re_review_entity_id, user_id, reason, pool) {
    expect_equal(re_review_entity_id, 42L)
    expect_equal(user_id, 7L)
    expect_equal(reason, "needs a specialist")
    list(status = 200, message = "Re-review item refused and flagged for specialist attention",
         entry = list(re_review_entity_id = 42L))
  }

  with_global_bindings(list(refuse_re_review_entity = fake_refuse), {
    result <- svc_re_review_refuse(42L, 7L, "needs a specialist")
  })

  expect_equal(result$message, "Re-review item refused and flagged for specialist attention")
  expect_equal(result$entry$re_review_entity_id, 42L)
})

test_that("svc_re_review_refuse_clear maps a 404 domain result and returns entry on success", {
  fake_clear_404 <- function(...) list(status = 404, message = "Re-review item not found")
  with_global_bindings(list(clear_re_review_refusal = fake_clear_404), {
    expect_error(svc_re_review_refuse_clear(99L), class = "error_404")
  })

  fake_clear_ok <- function(re_review_entity_id, pool) {
    list(status = 200, message = "Re-review refusal cleared", entry = list(re_review_entity_id = re_review_entity_id))
  }
  with_global_bindings(list(clear_re_review_refusal = fake_clear_ok), {
    result <- svc_re_review_refuse_clear(99L)
  })
  expect_equal(result$entry$re_review_entity_id, 99L)
})

# ===========================================================================
# Workflow service — criteria mapping
# ===========================================================================

test_that("svc_re_review_extract_criteria maps body fields and defaults batch_size to 20L", {
  criteria <- svc_re_review_extract_criteria(list(
    date_range = list(start = "2020-01-01", end = "2021-01-01"),
    gene_list = list(1L, 2L),
    status_filter = 3L,
    disease_id = "OMIM:123456"
  ))

  expect_equal(criteria$date_range$start, "2020-01-01")
  expect_equal(criteria$gene_list, list(1L, 2L))
  expect_equal(criteria$status_filter, 3L)
  expect_equal(criteria$disease_id, "OMIM:123456")
  expect_equal(criteria$batch_size, 20L)
})

test_that("svc_re_review_extract_criteria honors an explicit batch_size", {
  criteria <- svc_re_review_extract_criteria(list(batch_size = 50L))
  expect_equal(criteria$batch_size, 50L)
})

# ===========================================================================
# Workflow service — batch create/preview/recalculate forward derived
# criteria to the existing domain functions (status propagation included:
# these domain functions already embed `status` in their return body, and
# the svc_ wrapper is a pure pass-through of that shape).
# ===========================================================================

test_that("svc_re_review_batch_create derives criteria and forwards assigned_user_id/batch_name", {
  captured <- NULL
  fake_create <- function(criteria, assigned_user_id, batch_name, pool) {
    captured <<- list(criteria = criteria, assigned_user_id = assigned_user_id, batch_name = batch_name)
    list(status = 200, message = "Batch created successfully", entry = list(batch_id = 1L))
  }

  body <- list(gene_list = list("HGNC:1"), assigned_user_id = 9L, batch_name = "My batch")
  with_global_bindings(list(batch_create = fake_create), {
    result <- svc_re_review_batch_create(body, pool = make_mock_conn())
  })

  expect_equal(captured$criteria$gene_list, list("HGNC:1"))
  expect_equal(captured$criteria$batch_size, 20L)
  expect_equal(captured$assigned_user_id, 9L)
  expect_equal(captured$batch_name, "My batch")
  expect_equal(result$status, 200)
})

test_that("svc_re_review_batch_preview forwards derived criteria and its batch_size", {
  captured <- NULL
  fake_preview <- function(criteria, batch_size, pool) {
    captured <<- list(criteria = criteria, batch_size = batch_size)
    list(status = 200, data = tibble::tibble())
  }

  with_global_bindings(list(batch_preview = fake_preview), {
    svc_re_review_batch_preview(list(status_filter = 2L, batch_size = 5L), pool = make_mock_conn())
  })

  expect_equal(captured$criteria$status_filter, 2L)
  expect_equal(captured$batch_size, 5L)
})

test_that("svc_re_review_batch_recalculate 400s before calling the domain function when re_review_batch is missing", {
  called <- FALSE
  fake_recalc <- function(...) {
    called <<- TRUE
    list(status = 200)
  }

  with_global_bindings(list(batch_recalculate = fake_recalc), {
    result <- svc_re_review_batch_recalculate(list(gene_list = list("HGNC:1")), pool = make_mock_conn())
  })

  expect_false(called)
  expect_equal(result$status, 400L)
  expect_match(result$message, "re_review_batch is required")
})

test_that("svc_re_review_batch_recalculate coerces the batch id and forwards criteria", {
  captured <- NULL
  fake_recalc <- function(batch_id, criteria, pool) {
    captured <<- list(batch_id = batch_id, criteria = criteria)
    list(status = 200, message = "Batch recalculated successfully", entry = list(batch_id = batch_id))
  }

  with_global_bindings(list(batch_recalculate = fake_recalc), {
    result <- svc_re_review_batch_recalculate(list(re_review_batch = "15", disease_id = "OMIM:1"), pool = make_mock_conn())
  })

  expect_equal(captured$batch_id, 15L)
  expect_equal(captured$criteria$disease_id, "OMIM:1")
  expect_equal(result$status, 200)
})

# ===========================================================================
# Workflow service — batch reassign / archive: thin integer-coercing
# pass-throughs to the existing domain functions.
# ===========================================================================

test_that("svc_re_review_batch_reassign coerces ids and forwards to batch_reassign", {
  captured <- NULL
  fake_reassign <- function(batch_id, new_user_id, pool) {
    captured <<- list(batch_id = batch_id, new_user_id = new_user_id)
    list(status = 200, message = "Batch reassigned successfully")
  }

  with_global_bindings(list(batch_reassign = fake_reassign), {
    result <- svc_re_review_batch_reassign("15", "8", pool = make_mock_conn())
  })

  expect_equal(captured$batch_id, 15L)
  expect_equal(captured$new_user_id, 8L)
  expect_equal(result$status, 200)
})

test_that("svc_re_review_batch_archive coerces the id and forwards to batch_archive", {
  captured <- NULL
  fake_archive <- function(batch_id, pool) {
    captured <<- batch_id
    list(status = 200, message = "Batch archived successfully")
  }

  with_global_bindings(list(batch_archive = fake_archive), {
    result <- svc_re_review_batch_archive("15", pool = make_mock_conn())
  })

  expect_equal(captured, 15L)
  expect_equal(result$status, 200)
})

# ===========================================================================
# Workflow service — entity-assignment validation
# ===========================================================================

test_that("svc_re_review_entities_assign 400s on missing/empty entity_ids without calling entity_assign", {
  called <- FALSE
  fake_assign <- function(...) {
    called <<- TRUE
    list(status = 200)
  }

  with_global_bindings(list(entity_assign = fake_assign), {
    r1 <- svc_re_review_entities_assign(list(user_id = 5L), pool = make_mock_conn())
    r2 <- svc_re_review_entities_assign(list(entity_ids = list(), user_id = 5L), pool = make_mock_conn())
  })

  expect_false(called)
  expect_equal(r1$status, 400L)
  expect_match(r1$message, "entity_ids is required")
  expect_equal(r2$status, 400L)
})

test_that("svc_re_review_entities_assign 400s on missing user_id without calling entity_assign", {
  called <- FALSE
  fake_assign <- function(...) {
    called <<- TRUE
    list(status = 200)
  }

  with_global_bindings(list(entity_assign = fake_assign), {
    result <- svc_re_review_entities_assign(list(entity_ids = list(1L, 2L)), pool = make_mock_conn())
  })

  expect_false(called)
  expect_equal(result$status, 400L)
  expect_match(result$message, "user_id is required")
})

test_that("svc_re_review_entities_assign coerces ids to integer and forwards to entity_assign", {
  captured <- NULL
  fake_assign <- function(entity_ids, user_id, batch_name, pool) {
    captured <<- list(entity_ids = entity_ids, user_id = user_id, batch_name = batch_name)
    list(status = 200, message = "Entities assigned successfully", entry = list(batch_id = 3L))
  }

  body <- list(entity_ids = list("1", "2", "3"), user_id = "9", batch_name = "Priority genes")
  with_global_bindings(list(entity_assign = fake_assign), {
    result <- svc_re_review_entities_assign(body, pool = make_mock_conn())
  })

  expect_equal(captured$entity_ids, c(1L, 2L, 3L))
  expect_equal(captured$user_id, 9L)
  expect_equal(captured$batch_name, "Priority genes")
  expect_equal(result$status, 200)
})

# ===========================================================================
# DB-dependent handlers: dbplyr `pool %>% tbl(...)` pipelines carried over
# verbatim from the pre-extraction endpoint. These need a live connection
# dbplyr can translate SQL against (neither RMariaDB nor dbplyr is installed
# on the host test runner), so they are guarded rather than mocked.
# ===========================================================================

test_that("DB-dependent query/workflow endpoint services are defined", {
  expect_true(exists("svc_re_review_table_query", mode = "function"))
  expect_true(exists("svc_re_review_assignment_entity_summary", mode = "function"))
  expect_true(exists("svc_re_review_assignment_user_table", mode = "function"))
  expect_true(exists("svc_re_review_assignment_table_endpoint", mode = "function"))
  expect_true(exists("svc_re_review_approve", mode = "function"))
  expect_true(exists("svc_re_review_batch_apply", mode = "function"))
  expect_true(exists("svc_re_review_batch_assign", mode = "function"))
  expect_true(exists("svc_re_review_batch_unassign", mode = "function"))
})

test_that("svc_re_review_approve 404s a nonexistent re_review_entity_id against a real DB", {
  # svc_re_review_approve mutates `res$status` directly (reference-semantics
  # Plumber response idiom, see file header) — an environment reproduces
  # that here since plain R lists have value semantics.
  #
  # svc_re_review_approve() calls dplyr::tbl() against a real DBI connection,
  # which needs the {dbplyr} backend package; it is a declared renv dependency
  # (present in the container) but not always installed on a host test
  # runner, so skip gracefully rather than erroring (mirrors the table-
  # presence skip immediately below, which the original author already
  # anticipated in the file-header comment above this section but scoped to
  # "RMariaDB or dbplyr missing" implying with_test_db_transaction() would
  # itself skip first — that assumption doesn't hold on a host with a live
  # DB connection but no {dbplyr}).
  skip_if_not_installed("dbplyr")

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    if (!DBI::dbExistsTable(conn, "re_review_entity_connect")) {
      skip("re_review_entity_connect table not present in this test DB")
    }

    res <- new.env()
    res$status <- 200L

    result <- svc_re_review_approve(
      re_review_id = -999999L,
      status_ok = TRUE,
      review_ok = TRUE,
      user_id = 1L,
      res = res,
      pool = conn
    )

    expect_equal(res$status, 404L)
    expect_equal(result$error, "Re-review record not found")
  })
})
