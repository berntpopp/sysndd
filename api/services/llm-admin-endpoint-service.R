# services/llm-admin-endpoint-service.R
#
# Service layer for the Administrator-only LLM admin surface (config, cache,
# regeneration, logs, validation, prompt templates). Extracted from
# endpoints/llm_admin_endpoints.R (issue #346) to keep the endpoint file a
# thin decorator/role-gate shell. Each function wraps the already-loaded
# functions/llm-*.R repository/config layer (get_cache_statistics(),
# get_cached_summaries_paginated(), clear_llm_cache(), llm_model_config_*(),
# llm_regenerate_from_snapshot(), etc.) — no new SQL, no new Gemini calls.
#
# Response shape: a function that can return a non-200 status returns
# `list(http_status = <int>, body = <list>)` (see `.svc_llm_admin_result()`);
# the endpoint sets `res$status <- outcome$http_status` and returns
# `outcome$body` unchanged, so JSON output is byte-identical to the
# pre-refactor inline handler. Always-200 functions return the body directly.
#
# `svc_llm_admin_*` prefix avoids shadowing repository/service functions in
# the global environment (AGENTS.md service-prefix invariant).

#' Build a `list(http_status, body)` envelope.
#' @keywords internal
.svc_llm_admin_result <- function(http_status, ...) {
  list(http_status = http_status, body = list(...))
}

## -------------------------------------------------------------------##
## Shared helpers
## -------------------------------------------------------------------##

#' Resolve the runtime config list used for Gemini model resolution.
#'
#' base:: namespacing is required: the live runtime attaches packages (e.g.
#' via biomaRt/AnnotationDbi) that mask base `exists`/`get` with S4 generics
#' that reject the `inherits=` argument, which otherwise 500s this endpoint.
#'
#' @return The `dw` config list from .GlobalEnv, or NULL when absent.
#' @export
svc_llm_admin_runtime_config <- function() {
  if (base::exists("dw", envir = .GlobalEnv, inherits = FALSE)) {
    return(base::get("dw", envir = .GlobalEnv, inherits = FALSE))
  }
  NULL
}

## -------------------------------------------------------------------##
## LLM Configuration
## -------------------------------------------------------------------##

#' Build the GET /config response body.
#' @export
svc_llm_admin_get_config <- function() {
  runtime_config <- svc_llm_admin_runtime_config()
  resolved <- llm_model_config_resolve(config = runtime_config)

  available_models <- lapply(list_gemini_models(), function(name) {
    info <- get_gemini_model_metadata(name)
    list(
      model_id = name,
      display_name = info$display_name,
      description = info$description,
      rpm_limit = info$rpm_limit,
      rpd_limit = info$rpd_limit,
      recommended_for = info$recommended_for,
      status = info$status,
      allowed = info$allowed
    )
  })

  list(
    gemini_configured = is_gemini_configured(),
    current_model = resolved$model,
    source = resolved$source,
    default_model = resolved$default_model,
    valid = resolved$valid,
    operator_allowed = resolved$operator_allowed,
    warning = resolved$warning,
    available_models = available_models,
    rate_limit = GEMINI_RATE_LIMIT
  )
}

#' Validate + apply a PUT /config model change (session-only, not persisted).
#'
#' @param model Character Gemini model id requested by the admin.
#' @return `list(http_status, body)`. 400 on an invalid model.
#' @export
svc_llm_admin_update_config <- function(model) {
  runtime_config <- svc_llm_admin_runtime_config()
  validation <- llm_model_config_validate(model, config = runtime_config)
  if (!isTRUE(validation$valid)) {
    return(.svc_llm_admin_result(
      400,
      error = "INVALID_MODEL",
      error_code = validation$error_code,
      message = validation$message,
      available_models = list_gemini_models()
    ))
  }

  # Set environment variable (session-only, not persisted)
  Sys.setenv(GEMINI_MODEL = model)
  logger::log_info("LLM model changed to: {model}")

  .svc_llm_admin_result(
    200,
    success = TRUE,
    message = paste("Model changed to", model),
    model = model
  )
}

## -------------------------------------------------------------------##
## LLM Cache
## -------------------------------------------------------------------##

#' Build the GET /cache/stats response body.
#' @export
svc_llm_admin_cache_stats <- function() {
  get_cache_statistics()
}

#' Resolve the legacy page/per_page pagination contract (D5 limit/offset
#' aliases). Shared by the cache-summaries and generation-logs listings.
#' @keywords internal
.svc_llm_admin_resolve_pagination <- function(page, per_page, limit, offset) {
  page_val     <- suppressWarnings(as.integer(page))
  per_page_val <- suppressWarnings(as.integer(per_page))
  limit_val    <- suppressWarnings(as.integer(limit))
  offset_val   <- suppressWarnings(as.integer(offset))

  if (is.na(per_page_val) || per_page_val < 1L) {
    per_page_val <- if (!is.na(limit_val) && limit_val >= 1L) min(limit_val, 500L) else 50L
  } else {
    per_page_val <- min(per_page_val, 500L)
  }
  if (is.na(page_val) || page_val < 1L) {
    page_val <- if (!is.na(offset_val) && offset_val >= 0L) {
      floor(offset_val / max(per_page_val, 1L)) + 1L
    } else {
      1L
    }
  }
  list(page = page_val, per_page = per_page_val)
}

#' Derive the legacy `total` field from a repository pagination result.
#' @keywords internal
.svc_llm_admin_total_from_result <- function(result) {
  if (!is.null(result$total)) {
    result$total
  } else if (is.data.frame(result$data)) {
    nrow(result$data)
  } else {
    length(result$data)
  }
}

#' Build the GET /cache/summaries response body (paginated).
#'
#' Preserves the legacy `{data, total, page, per_page}` envelope expected by
#' `useLlmAdmin.ts` / `types/llm.ts::PaginatedCacheSummaries`.
#' @export
svc_llm_admin_cache_summaries <- function(cluster_type = NULL, validation_status = NULL,
                                           page = NULL, per_page = NULL,
                                           limit = NULL, offset = NULL) {
  resolved <- .svc_llm_admin_resolve_pagination(page, per_page, limit, offset)

  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(validation_status) && validation_status == "") validation_status <- NULL

  result <- get_cached_summaries_paginated(
    cluster_type = cluster_type,
    validation_status = validation_status,
    page = resolved$page,
    per_page = resolved$per_page
  )

  list(
    data     = result$data,
    total    = .svc_llm_admin_total_from_result(result),
    page     = resolved$page,
    per_page = resolved$per_page
  )
}

#' Validate + apply a DELETE /cache request.
#'
#' @param cluster_type One of "all", "functional", "phenotype".
#' @return `list(http_status, body)`. 400 on an invalid cluster_type.
#' @export
svc_llm_admin_clear_cache <- function(cluster_type = "all") {
  valid_types <- c("all", "functional", "phenotype")
  if (!cluster_type %in% valid_types) {
    return(.svc_llm_admin_result(
      400,
      error = "INVALID_CLUSTER_TYPE",
      message = paste("Invalid cluster_type. Valid options:", paste(valid_types, collapse = ", "))
    ))
  }

  result <- clear_llm_cache(cluster_type)
  .svc_llm_admin_result(
    200,
    success = TRUE,
    message = paste("Cache cleared:", result$count, "entries deleted"),
    cleared_count = result$count
  )
}

## -------------------------------------------------------------------##
## LLM Regeneration (snapshot-driven, #488)
## -------------------------------------------------------------------##

#' Trigger snapshot-driven LLM batch regeneration for one or more cluster
#' types.
#'
#' Never recomputes clustering: each cluster type is driven from the
#' PUBLISHED analysis snapshot via `regenerate_from_snapshot()` (defaults to
#' the real `llm_regenerate_from_snapshot()`), so generated summaries' hashes
#' match what serving looks up. A cluster type without a public-ready
#' snapshot fails the whole request with 409 (no partial regeneration).
#'
#' @param regenerate_from_snapshot Injectable dependency; defaults to the real
#'   `llm_regenerate_from_snapshot()` (functions/llm-regenerate-helpers.R).
#' @return 503 if Gemini is not configured, 400 on an invalid cluster_type,
#'   409 when a snapshot is not ready, 202 Accepted otherwise.
#' @export
svc_llm_admin_regenerate <- function(cluster_type = "all", force = FALSE,
                                      regenerate_from_snapshot = llm_regenerate_from_snapshot) {
  if (!is_gemini_configured()) {
    return(.svc_llm_admin_result(
      503,
      error = "GEMINI_NOT_CONFIGURED",
      message = "GEMINI_API_KEY environment variable is not set. LLM features are disabled."
    ))
  }

  valid_types <- c("all", "functional", "phenotype")
  if (!cluster_type %in% valid_types) {
    return(.svc_llm_admin_result(
      400,
      error = "INVALID_CLUSTER_TYPE",
      message = paste("Invalid cluster_type. Valid options:", paste(valid_types, collapse = ", "))
    ))
  }

  # Coerce force robustly (Plumber query params arrive as strings; NA -> FALSE).
  force <- isTRUE(suppressWarnings(as.logical(force)))

  cluster_types_to_process <- if (cluster_type == "all") {
    c("functional", "phenotype")
  } else {
    cluster_type
  }

  # Generate a parent job_id for tracking
  parent_job_id <- uuid::UUIDgenerate()

  results <- list()
  for (ct in cluster_types_to_process) {
    outcome <- tryCatch(
      regenerate_from_snapshot(ct, parent_job_id = parent_job_id, force = force),
      error = function(e) {
        logger::log_warn("Snapshot-driven regeneration failed for {ct}: {conditionMessage(e)}")
        list(ready = FALSE, reason = "error", cluster_type = ct, error = conditionMessage(e))
      }
    )

    if (!isTRUE(outcome$ready)) {
      return(.svc_llm_admin_result(
        409,
        error = "SNAPSHOT_NOT_READY",
        message = paste0(
          "No public-ready analysis snapshot is available for '", ct,
          "' clusters. Refresh the analysis snapshot (POST /api/admin/analysis/snapshots/refresh) ",
          "before regenerating summaries."
        ),
        cluster_type = ct,
        reason = outcome$reason %||% "snapshot_not_ready"
      ))
    }

    results[[ct]] <- outcome$result
  }

  .svc_llm_admin_result(
    202,
    job_id = parent_job_id,
    status = "accepted",
    status_url = paste0("/api/jobs/", parent_job_id),
    cluster_types = cluster_types_to_process,
    force = force,
    results = results
  )
}

## -------------------------------------------------------------------##
## LLM Logs
## -------------------------------------------------------------------##

#' Build the GET /logs response body (paginated).
#'
#' Preserves the legacy `{data, total, page, per_page}` envelope expected by
#' `useLlmAdmin.ts` / `types/llm.ts::PaginatedLogs`.
#' @export
svc_llm_admin_generation_logs <- function(cluster_type = NULL, status = NULL,
                                           from_date = NULL, to_date = NULL,
                                           page = NULL, per_page = NULL,
                                           limit = NULL, offset = NULL) {
  resolved <- .svc_llm_admin_resolve_pagination(page, per_page, limit, offset)

  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(status) && status == "") status <- NULL
  if (!is.null(from_date) && from_date == "") from_date <- NULL
  if (!is.null(to_date) && to_date == "") to_date <- NULL

  result <- get_generation_logs_paginated(
    cluster_type = cluster_type,
    status = status,
    from_date = from_date,
    to_date = to_date,
    page = resolved$page,
    per_page = resolved$per_page
  )

  list(
    data     = result$data,
    total    = .svc_llm_admin_total_from_result(result),
    page     = resolved$page,
    per_page = resolved$per_page
  )
}

## -------------------------------------------------------------------##
## LLM Validation
## -------------------------------------------------------------------##

#' Validate or reject a cached summary (manual admin override).
#'
#' @param user_id Requesting admin's user id (attribution; may be NULL).
#' @return 400 on an invalid action, 500 when the repository update fails,
#'   200 with the new validation_status otherwise.
#' @export
svc_llm_admin_validate_cache <- function(cache_id, action, user_id = NULL) {
  valid_actions <- c("validate", "reject")
  if (!action %in% valid_actions) {
    return(.svc_llm_admin_result(
      400,
      error = "INVALID_ACTION",
      message = paste("Invalid action. Valid options:", paste(valid_actions, collapse = ", "))
    ))
  }

  new_status <- if (action == "validate") "validated" else "rejected"
  validated_by <- if (!is.null(user_id)) as.character(user_id) else NULL

  success <- update_validation_status(
    cache_id = as.integer(cache_id),
    validation_status = new_status,
    validated_by = validated_by
  )

  if (!success) {
    return(.svc_llm_admin_result(
      500,
      error = "UPDATE_FAILED",
      message = "Failed to update validation status"
    ))
  }

  .svc_llm_admin_result(
    200,
    success = TRUE,
    message = paste("Cache entry", action, "d"),
    cache_id = as.integer(cache_id),
    validation_status = new_status
  )
}

## -------------------------------------------------------------------##
## LLM Prompt Templates
## -------------------------------------------------------------------##

#' Build the GET /prompts response body.
#' @export
svc_llm_admin_get_prompts <- function() {
  get_all_prompt_templates()
}

#' Validate + "save" a PUT /prompts/<type> request.
#'
#' Custom prompt templates are not yet persisted to the database (templates
#' are built into the code); this records the request and returns success,
#' matching the pre-refactor behaviour. `template`/`version`/`description`
#' are already body-resolved by the endpoint shell (query params or JSON
#' body, whichever the caller supplied).
#'
#' @return 400 on an invalid type or missing template/version, 200 otherwise.
#' @export
svc_llm_admin_update_prompt <- function(type, template = NULL, version = NULL,
                                         description = NULL) {
  valid_types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )
  if (!type %in% valid_types) {
    return(.svc_llm_admin_result(
      400,
      error = "INVALID_PROMPT_TYPE",
      message = paste("Invalid prompt type. Valid options:", paste(valid_types, collapse = ", "))
    ))
  }

  if (is.null(template) || template == "") {
    return(.svc_llm_admin_result(
      400,
      error = "MISSING_TEMPLATE",
      message = "Template content is required"
    ))
  }

  if (is.null(version) || version == "") {
    return(.svc_llm_admin_result(
      400,
      error = "MISSING_VERSION",
      message = "Version is required"
    ))
  }

  # Log the update (actual persistence would require database schema extension)
  logger::log_info("Prompt template update requested: type={type}, version={version}")

  # Currently returns success but template is not persisted
  # Future: Add llm_prompt_templates table and save_prompt_template() function
  .svc_llm_admin_result(
    200,
    success = TRUE,
    message = paste(
      "Prompt template", type, "version", version,
      "recorded (note: custom templates not yet persisted)"
    ),
    type = type,
    version = version
  )
}
