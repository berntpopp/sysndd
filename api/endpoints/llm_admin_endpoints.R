# api/endpoints/llm_admin_endpoints.R
#
# LLM Administration endpoints for managing configuration, prompts, cache, and logs.
# All endpoints require Administrator role.

# Note: All required modules (db-helpers.R, middleware.R, llm-service.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.

llm_admin_runtime_config <- function() {
  # base:: namespacing is required: the live runtime attaches packages (e.g. via
  # biomaRt/AnnotationDbi) that mask base `exists`/`get` with S4 generics that
  # reject the `inherits=` argument, which otherwise 500s this endpoint.
  if (base::exists("dw", envir = .GlobalEnv, inherits = FALSE)) {
    return(base::get("dw", envir = .GlobalEnv, inherits = FALSE))
  }
  NULL
}


## -------------------------------------------------------------------##
## LLM Configuration Endpoints
## -------------------------------------------------------------------##

#* Get LLM configuration
#*
#* Returns API status, resolved model source, validation state, available
#* models, and rate limits. Restricted to Administrator role.
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @get /config
function(req, res) {
  require_role(req, res, "Administrator")

  runtime_config <- llm_admin_runtime_config()
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


#* Update LLM model selection
#*
#* Changes the session-only Gemini model for summary generation.
#* Restricted to Administrator role.
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @put /config
function(req, res, model) {
  require_role(req, res, "Administrator")

  runtime_config <- llm_admin_runtime_config()
  validation <- llm_model_config_validate(model, config = runtime_config)
  if (!isTRUE(validation$valid)) {
    available <- list_gemini_models()
    res$status <- 400
    return(list(
      error = "INVALID_MODEL",
      error_code = validation$error_code,
      message = validation$message,
      available_models = available
    ))
  }

  # Set environment variable (session-only, not persisted)
  Sys.setenv(GEMINI_MODEL = model)
  log_info("LLM model changed to: {model}")

  list(
    success = TRUE,
    message = paste("Model changed to", model),
    model = model
  )
}


## -------------------------------------------------------------------##
## LLM Cache Endpoints
## -------------------------------------------------------------------##

#* Get LLM cache statistics
#*
#* Returns aggregate statistics about cached summaries and generation logs.
#* Used by admin dashboard to display system health and usage metrics.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - total_entries: Integer, total current cache entries
#* - by_status: Object with pending, validated, rejected counts
#* - by_type: Object with functional, phenotype counts
#* - last_generation: Timestamp of most recent generation
#* - total_tokens_input: Integer, sum of input tokens
#* - total_tokens_output: Integer, sum of output tokens
#* - estimated_cost_usd: Number, estimated API cost
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @get /cache/stats
function(req, res) {
  require_role(req, res, "Administrator")

  get_cache_statistics()
}


#* Get cached summaries (paginated)
#*
#* Returns paginated list of cached summaries for admin browser.
#* Supports filtering by cluster type and validation status.
#*
#* # `Query Parameters`
#* @param cluster_type:character Filter by "functional" or "phenotype"
#* @param validation_status:character Filter by "pending", "validated", "rejected"
#* @param page:int Page number (default: 1)
#* @param per_page:int Items per page (default: 50, max: 500)
#* @param limit:int Alias for per_page (D5 pagination contract, default: 50)
#* @param offset:int Alias for (page-1) * per_page; rounded DOWN to the
#*   nearest page boundary when not a multiple of per_page (default: 0)
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* Legacy pagination envelope expected by `useLlmAdmin.ts` /
#* `types/llm.ts::PaginatedCacheSummaries`:
#* - data: Array of cache entries
#* - total: Integer total count
#* - page: Current page number
#* - per_page: Items per page
#*
#* @tag llm-admin
#* @serializer json list(na="string")
#* @get /cache/summaries
function(req, res, cluster_type = NULL, validation_status = NULL,
         page = NULL, per_page = NULL, limit = NULL, offset = NULL) {
  require_role(req, res, "Administrator")

  # Frontend uses page/per_page; limit/offset are aliases added by D5 for the
  # pagination contract. Coerce via suppressWarnings so non-numeric inputs
  # degrade to NA (then fall back to defaults) rather than propagating NA.
  page_val     <- suppressWarnings(as.integer(page))
  per_page_val <- suppressWarnings(as.integer(per_page))
  limit_val    <- suppressWarnings(as.integer(limit))
  offset_val   <- suppressWarnings(as.integer(offset))

  # Resolve effective page/per_page (legacy contract wins; fall back to
  # limit/offset, then defaults).
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

  # Convert empty strings to NULL
  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(validation_status) && validation_status == "") validation_status <- NULL

  result <- get_cached_summaries_paginated(
    cluster_type = cluster_type,
    validation_status = validation_status,
    page = page_val,
    per_page = per_page_val
  )

  # Preserve legacy response shape {data, total, page, per_page} expected by
  # useLlmAdmin.ts / types/llm.ts::PaginatedCacheSummaries.
  total_val <- if (!is.null(result$total)) {
    result$total
  } else if (is.data.frame(result$data)) {
    nrow(result$data)
  } else {
    length(result$data)
  }
  list(
    data     = result$data,
    total    = total_val,
    page     = page_val,
    per_page = per_page_val
  )
}


#* Clear LLM cache
#*
#* Deletes cached summaries by cluster type. Use with caution as
#* regeneration requires API calls.
#*
#* # `Query Parameters`
#* @param cluster_type:character One of "all", "functional", "phenotype" (default: "all")
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean
#* - message: String confirmation
#* - cleared_count: Integer, number of entries deleted
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @delete /cache
function(req, res, cluster_type = "all") {
  require_role(req, res, "Administrator")

  # Validate cluster_type
  valid_types <- c("all", "functional", "phenotype")
  if (!cluster_type %in% valid_types) {
    res$status <- 400
    return(list(
      error = "INVALID_CLUSTER_TYPE",
      message = paste("Invalid cluster_type. Valid options:", paste(valid_types, collapse = ", "))
    ))
  }

  result <- clear_llm_cache(cluster_type)

  list(
    success = TRUE,
    message = paste("Cache cleared:", result$count, "entries deleted"),
    cleared_count = result$count
  )
}


## -------------------------------------------------------------------##
## LLM Regeneration Endpoint
## -------------------------------------------------------------------##

#* Trigger LLM batch regeneration (snapshot-driven)
#*
#* Starts async job(s) to regenerate LLM summaries for the PUBLISHED analysis
#* snapshot's clusters. Never recomputes clustering (#488): summaries are keyed
#* to the snapshot's stored `cluster_hash`, so regenerating off an independent
#* recompute produced un-servable summaries and corrupted the served set. If a
#* requested cluster type has no public-ready snapshot, returns 409 (refresh the
#* snapshot first) instead of recomputing.
#*
#* # `Request Body`
#* {
#*   "cluster_type": "all",
#*   "force": false
#* }
#*
#* # `Query Parameters`
#* @param cluster_type:character One of "all", "functional", "phenotype" (default: "all")
#* @param force:boolean If true, regenerate even if cached (default: false)
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return (202 Accepted)`
#* - job_id: UUID of the created job
#* - status: "accepted"
#* - status_url: URL to poll for job status
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @post /regenerate
function(req, res, cluster_type = "all", force = FALSE) {
  require_role(req, res, "Administrator")

  # Check if Gemini is configured
  if (!is_gemini_configured()) {
    res$status <- 503
    return(list(
      error = "GEMINI_NOT_CONFIGURED",
      message = "GEMINI_API_KEY environment variable is not set. LLM features are disabled."
    ))
  }

  # Validate cluster_type
  valid_types <- c("all", "functional", "phenotype")
  if (!cluster_type %in% valid_types) {
    res$status <- 400
    return(list(
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

  # Drive regeneration from the published snapshot for each cluster type so the
  # generated summaries' hashes match what serving looks up (#488). If any
  # requested type lacks a public-ready snapshot, fail fast with 409 rather than
  # partially regenerating (and never recompute clustering here).
  results <- list()
  for (ct in cluster_types_to_process) {
    outcome <- tryCatch(
      llm_regenerate_from_snapshot(ct, parent_job_id = parent_job_id, force = force),
      error = function(e) {
        log_warn("Snapshot-driven regeneration failed for {ct}: {conditionMessage(e)}")
        list(ready = FALSE, reason = "error", cluster_type = ct, error = conditionMessage(e))
      }
    )

    if (!isTRUE(outcome$ready)) {
      res$status <- 409
      return(list(
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

  res$status <- 202
  list(
    job_id = parent_job_id,
    status = "accepted",
    status_url = paste0("/api/jobs/", parent_job_id),
    cluster_types = cluster_types_to_process,
    force = force,
    results = results
  )
}


## -------------------------------------------------------------------##
## LLM Logs Endpoint
## -------------------------------------------------------------------##

#* Get generation logs (paginated)
#*
#* Returns paginated list of LLM generation log entries.
#* Supports filtering by cluster type, status, and date range.
#*
#* # `Query Parameters`
#* @param cluster_type:character Filter by "functional" or "phenotype"
#* @param status:character Filter by "success", "validation_failed", "api_error", "timeout"
#* @param from_date:character Start date filter (YYYY-MM-DD)
#* @param to_date:character End date filter (YYYY-MM-DD)
#* @param page:int Page number (default: 1)
#* @param per_page:int Items per page (default: 50, max: 500)
#* @param limit:int Alias for per_page (D5 pagination contract, default: 50)
#* @param offset:int Alias for (page-1) * per_page; rounded DOWN to the
#*   nearest page boundary when not a multiple of per_page (default: 0)
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* Legacy pagination envelope expected by `useLlmAdmin.ts` /
#* `types/llm.ts::PaginatedLogs`:
#* - data: Array of log entries
#* - total: Integer total count
#* - page: Current page number
#* - per_page: Items per page
#*
#* @tag llm-admin
#* @serializer json list(na="string")
#* @get /logs
function(req, res, cluster_type = NULL, status = NULL, from_date = NULL, to_date = NULL,
         page = NULL, per_page = NULL, limit = NULL, offset = NULL) {
  require_role(req, res, "Administrator")

  # Frontend uses page/per_page; limit/offset are aliases added by D5 for the
  # pagination contract. Coerce via suppressWarnings so non-numeric inputs
  # degrade to NA (then fall back to defaults) rather than propagating NA.
  page_val     <- suppressWarnings(as.integer(page))
  per_page_val <- suppressWarnings(as.integer(per_page))
  limit_val    <- suppressWarnings(as.integer(limit))
  offset_val   <- suppressWarnings(as.integer(offset))

  # Resolve effective page/per_page (legacy contract wins; fall back to
  # limit/offset, then defaults).
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

  # Convert empty strings to NULL
  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(status) && status == "") status <- NULL
  if (!is.null(from_date) && from_date == "") from_date <- NULL
  if (!is.null(to_date) && to_date == "") to_date <- NULL

  result <- get_generation_logs_paginated(
    cluster_type = cluster_type,
    status = status,
    from_date = from_date,
    to_date = to_date,
    page = page_val,
    per_page = per_page_val
  )

  # Preserve legacy response shape {data, total, page} expected by
  # useLlmAdmin.ts / types/llm.ts::PaginatedLogs. per_page included for
  # parity with /cache/summaries.
  total_val <- if (!is.null(result$total)) {
    result$total
  } else if (is.data.frame(result$data)) {
    nrow(result$data)
  } else {
    length(result$data)
  }
  list(
    data     = result$data,
    total    = total_val,
    page     = page_val,
    per_page = per_page_val
  )
}


## -------------------------------------------------------------------##
## LLM Validation Endpoint
## -------------------------------------------------------------------##

#* Manual validation of cache entry
#*
#* Allows admin to manually validate or reject a cached summary.
#*
#* # `Path Parameters`
#* @param cache_id:int ID of the cache entry to validate
#*
#* # `Request Body`
#* {
#*   "action": "validate"
#* }
#*
#* # `Query Parameters`
#* @param action:character One of "validate" or "reject"
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean
#* - message: String confirmation
#* - cache_id: Integer, the updated cache entry ID
#* - validation_status: String, the new status
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @post /cache/<cache_id>/validate
function(req, res, cache_id, action) {
  require_role(req, res, "Administrator")

  # Validate action
  valid_actions <- c("validate", "reject")
  if (!action %in% valid_actions) {
    res$status <- 400
    return(list(
      error = "INVALID_ACTION",
      message = paste("Invalid action. Valid options:", paste(valid_actions, collapse = ", "))
    ))
  }

  # Map action to validation_status
  new_status <- if (action == "validate") "validated" else "rejected"

  # Get user_id from token
  user_id <- req$user_id
  validated_by <- if (!is.null(user_id)) as.character(user_id) else NULL

  # Update validation status
  success <- update_validation_status(
    cache_id = as.integer(cache_id),
    validation_status = new_status,
    validated_by = validated_by
  )

  if (!success) {
    res$status <- 500
    return(list(
      error = "UPDATE_FAILED",
      message = "Failed to update validation status"
    ))
  }

  list(
    success = TRUE,
    message = paste("Cache entry", action, "d"),
    cache_id = as.integer(cache_id),
    validation_status = new_status
  )
}


## -------------------------------------------------------------------##
## LLM Prompt Template Endpoints
## -------------------------------------------------------------------##

#* Get all prompt templates
#*
#* Returns all prompt templates for each type (functional and phenotype,
#* generation and judge). Fetches from database with fallback to hardcoded defaults.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* Object keyed by prompt type, each containing:
#* - template_id: Integer or null
#* - prompt_type: String
#* - version: String
#* - template_text: String, full prompt template
#* - description: String or null
#*
#* @tag llm-admin
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @get /prompts
function(req, res) {
  require_role(req, res, "Administrator")

  # Use get_all_prompt_templates() from llm-service.R which fetches from DB
  # with fallback to hardcoded defaults
  get_all_prompt_templates()
}


#* Update a prompt template
#*
#* Saves a new version of a prompt template. Currently not persisted
#* to database (templates are built into the code).
#*
#* # `Path Parameters`
#* @param type:character Template type (functional_generation, functional_judge,
#*                       phenotype_generation, phenotype_judge)
#*
#* # `Request Body`
#* {
#*   "template": "Your new prompt template...",
#*   "version": "1.1",
#*   "description": "Updated template with better instructions"
#* }
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean
#* - message: String
#* - type: String, the template type
#* - version: String, the new version
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @put /prompts/<type>
function(req, res, type, template = NULL, version = NULL, description = NULL) {
  require_role(req, res, "Administrator")

  # Validate type
  valid_types <- c("functional_generation", "functional_judge",
                   "phenotype_generation", "phenotype_judge")
  if (!type %in% valid_types) {
    res$status <- 400
    return(list(
      error = "INVALID_PROMPT_TYPE",
      message = paste("Invalid prompt type. Valid options:", paste(valid_types, collapse = ", "))
    ))
  }

  # Parse body if parameters not provided
  if (is.null(template)) {
    body <- req$body
    template <- body$template
    version <- body$version %||% version
    description <- body$description %||% description
  }

  # Validate required fields
  if (is.null(template) || template == "") {
    res$status <- 400
    return(list(
      error = "MISSING_TEMPLATE",
      message = "Template content is required"
    ))
  }

  if (is.null(version) || version == "") {
    res$status <- 400
    return(list(
      error = "MISSING_VERSION",
      message = "Version is required"
    ))
  }

  # Log the update (actual persistence would require database schema extension)
  log_info("Prompt template update requested: type={type}, version={version}")

  # Currently returns success but template is not persisted
  # Future: Add llm_prompt_templates table and save_prompt_template() function
  list(
    success = TRUE,
    message = paste("Prompt template", type, "version", version,
                    "recorded (note: custom templates not yet persisted)"),
    type = type,
    version = version
  )
}
