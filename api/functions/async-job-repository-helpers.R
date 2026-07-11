# functions/async-job-repository-helpers.R
#
# Shared primitives for the durable async-job repository
# (functions/async-job-repository.R): library loads, the db-helpers
# fallback source, the captured base::get bindings (config::get masks
# base::get in the fully loaded API/worker env — see AGENTS.md), the base
# column list, SELECT-clause builders, request field validation, scalar/
# empty-result helpers, queue normalization, and bind-param normalization.
# CRUD/claim/lifecycle/history stay in async-job-repository.R.

library(DBI)
library(tibble)
library(logger)
library(rlang)

if (!exists("db_execute_query", mode = "function") ||
    !exists("db_execute_statement", mode = "function") ||
    !exists("db_with_transaction", mode = "function")) {
  helper_candidates <- c(
    "functions/db-helpers.R",
    "/app/functions/db-helpers.R"
  )

  for (helper_path in helper_candidates) {
    if (file.exists(helper_path)) {
      source(helper_path, local = TRUE)
      break
    }
  }
}

db_execute_query <- base::get("db_execute_query", mode = "function", inherits = TRUE)
db_execute_statement <- base::get("db_execute_statement", mode = "function", inherits = TRUE)
db_with_transaction <- base::get("db_with_transaction", mode = "function", inherits = TRUE)

ASYNC_JOB_BASE_COLUMNS <- c(
  "job_id",
  "job_type",
  "queue_name",
  "priority",
  "status",
  "request_hash",
  "request_payload_json",
  "submitted_by",
  "submitted_at",
  "scheduled_at",
  "started_at",
  "completed_at",
  "claimed_by_worker",
  "claim_token",
  "worker_hostname",
  "worker_pid",
  "last_heartbeat_at",
  "claim_expires_at",
  "attempt_count",
  "max_attempts",
  "next_attempt_at",
  "progress_pct",
  "progress_message",
  "last_error_code",
  "last_error_message",
  "cancelled_by",
  "updated_at"
)

.async_job_select_clause <- function(include_result = FALSE) {
  columns <- ASYNC_JOB_BASE_COLUMNS
  if (isTRUE(include_result)) {
    columns <- c(columns, "result_json")
  }
  paste(columns, collapse = ", ")
}

.async_job_build_select <- function(include_result = FALSE) {
  paste("SELECT", .async_job_select_clause(include_result))
}

.async_job_require_fields <- function(job, required) {
  missing <- required[vapply(required, function(field) {
    !field %in% names(job) || is.null(job[[field]]) || (length(job[[field]]) == 1 && is.na(job[[field]]))
  }, logical(1))]

  if (length(missing) > 0) {
    abort(
      message = paste("Missing required async job fields:", paste(missing, collapse = ", ")),
      class = "async_job_validation_error",
      missing_fields = missing
    )
  }
}

.async_job_scalar <- function(value, default = NULL) {
  if (is.null(value) || length(value) == 0) {
    return(default)
  }
  value[[1]]
}

.async_job_empty_result <- function() {
  tibble::tibble()
}

#' Normalize a claim-queue argument into a non-empty character vector
#'
#' @param queues Character vector, possibly NULL/empty/blank.
#' @return Non-empty character vector; defaults to "default".
.async_job_normalize_queues <- function(queues) {
  queue_values <- as.character(queues %||% "default")
  queue_values <- queue_values[nzchar(queue_values)]
  if (length(queue_values) == 0) {
    queue_values <- "default"
  }
  queue_values
}

#' Normalize a (possibly named) bind-param list/vector for DBI `?` binding
#'
#' `DBI::dbBind()` can fail silently on named lists; always bind unnamed.
#'
#' @param params Named or unnamed list/vector of bind values.
#' @return Unnamed list of bind values.
.async_job_normalize_params <- function(params) {
  unname(as.list(params))
}
