# api/endpoints/llm_admin_endpoints.R
#
# LLM Administration endpoints for managing configuration, prompts, cache, and logs.
# All endpoints require Administrator role.
#
# Endpoints:
#   GET  /config              - Get LLM model configuration
#   PUT  /config              - Update model selection
#   GET  /cache/stats         - Get cache statistics
#   GET  /cache/summaries     - Get cached summaries (paginated)
#   DELETE /cache             - Clear cache entries
#   POST /regenerate          - Trigger batch LLM regeneration
#   GET  /logs                - Get generation logs (paginated)
#   POST /cache/:id/validate  - Manual validation of cache entry
#   GET  /prompts             - Get all prompt templates
#   PUT  /prompts/<type>      - Update a prompt template

# Note: All required modules (db-helpers.R, middleware.R, llm-service.R)
# are sourced by start_sysndd_api.R before endpoints are loaded.
# Functions are available in the global environment.


## -------------------------------------------------------------------##
## LLM Configuration Endpoints
## -------------------------------------------------------------------##

#* Get LLM configuration
#*
#* Returns current LLM model configuration including API status,
#* current model, available models, and rate limit settings.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - gemini_configured: Boolean, TRUE if GEMINI_API_KEY is set
#* - current_model: String, current default model name
#* - available_models: Array of model objects with model_id, display_name, etc.
#* - rate_limit: Object with rate limit settings (capacity, fill_time_s, etc.)
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @get /config
function(req, res) {
  require_role(req, res, "Administrator")

  # Build structured model objects for frontend
  model_names <- list_gemini_models()
  model_info <- list(
    "gemini-3-pro-preview" = list(
      display_name = "Gemini 3 Pro Preview",
      description = "Best quality, complex reasoning tasks",
      rpm_limit = 1000,
      rpd_limit = 10000,
      recommended_for = "Complex analysis"
    ),
    "gemini-3-flash-preview" = list(
      display_name = "Gemini 3 Flash Preview",
      description = "Fast and capable for most tasks",
      rpm_limit = 2000,
      rpd_limit = NULL,
      recommended_for = "Fast processing"
    ),
    "gemini-2.5-flash" = list(
      display_name = "Gemini 2.5 Flash",
      description = "Best price-performance balance",
      rpm_limit = 2000,
      rpd_limit = NULL,
      recommended_for = "Cost-effective"
    ),
    "gemini-2.5-pro" = list(
      display_name = "Gemini 2.5 Pro",
      description = "Complex reasoning, stable release",
      rpm_limit = 1000,
      rpd_limit = 5000,
      recommended_for = "Stable production"
    ),
    "gemini-2.5-flash-lite" = list(
      display_name = "Gemini 2.5 Flash Lite",
      description = "Budget option for simple tasks",
      rpm_limit = 4000,
      rpd_limit = NULL,
      recommended_for = "Budget processing"
    )
  )

  available_models <- lapply(model_names, function(name) {
    info <- model_info[[name]]
    if (is.null(info)) {
      info <- list(
        display_name = name,
        description = "Model",
        rpm_limit = 1000,
        rpd_limit = NULL,
        recommended_for = "General use"
      )
    }
    list(
      model_id = name,
      display_name = info$display_name,
      description = info$description,
      rpm_limit = info$rpm_limit,
      rpd_limit = info$rpd_limit,
      recommended_for = info$recommended_for
    )
  })

  list(
    gemini_configured = is_gemini_configured(),
    current_model = get_default_gemini_model(),
    available_models = available_models,
    rate_limit = GEMINI_RATE_LIMIT
  )
}


#* Update LLM model selection
#*
#* Changes the active Gemini model for summary generation.
#* This is a session-only change; not persisted to config file.
#*
#* # `Request Body`
#* {
#*   "model": "gemini-3-flash-preview"
#* }
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean
#* - message: String confirmation
#* - model: String, the new model name
#*
#* @tag llm-admin
#* @serializer unboxedJSON
#* @put /config
function(req, res, model) {
  require_role(req, res, "Administrator")

  # Validate model against available options
  available <- list_gemini_models()
  if (!model %in% available) {
    res$status <- 400
    return(list(
      error = "INVALID_MODEL",
      message = paste("Invalid model. Available models:", paste(available, collapse = ", ")),
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
#* @param page:int Page number (1-indexed, default: 1)
#* @param per_page:int Entries per page (default: 20)
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - data: Array of cache entries
#* - total: Integer, total matching entries
#* - page: Integer, current page
#* - per_page: Integer, entries per page
#*
#* @tag llm-admin
#* @serializer json list(na="string")
#* @get /cache/summaries
function(req, res, cluster_type = NULL, validation_status = NULL, page = 1, per_page = 20) {
  require_role(req, res, "Administrator")

  # Convert to integer (Plumber passes query params as strings)
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Convert empty strings to NULL
  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(validation_status) && validation_status == "") validation_status <- NULL

  get_cached_summaries_paginated(
    cluster_type = cluster_type,
    validation_status = validation_status,
    page = page,
    per_page = per_page
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

#* Trigger LLM batch regeneration
#*
#* Starts an async job to regenerate LLM summaries for clusters.
#* Returns immediately with job_id for status polling.
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

  # Convert force to logical
  force <- as.logical(force)

  # Fetch cluster data from database (pool not available in daemon)
  # We need to pre-fetch the clustering result for the daemon
  cluster_types_to_process <- if (cluster_type == "all") {
    c("functional", "phenotype")
  } else {
    cluster_type
  }

  # Generate a parent job_id for tracking
  parent_job_id <- uuid::UUIDgenerate()

  # For each cluster type, fetch clusters and trigger generation
  results <- list()
  for (ct in cluster_types_to_process) {
    # Fetch clusters based on type
    # NOTE: Must match exactly how jobs_endpoints.R prepares data for clustering
    # The memoised functions expect specific input formats, not arbitrary params
    clusters <- tryCatch({
      if (ct == "functional") {
        # Functional clusters: need genes_list (HGNC IDs of NDD genes)
        genes_list <- pool %>%
          tbl("ndd_entity_view") %>%
          arrange(entity_id) %>%
          filter(ndd_phenotype == 1) %>%
          select(hgnc_id) %>%
          collect() %>%
          unique() %>%
          pull(hgnc_id)

        # Call memoised function with correct params - returns tibble directly
        gen_string_clust_obj_mem(genes_list)
      } else {
        # Phenotype clusters: need wide phenotypes data frame
        # Build data exactly like analysis_endpoints.R phenotype_clustering

        # Define constants for filtering (same as analysis_endpoints.R)
        id_phenotype_ids <- c(
          "HP:0001249",
          "HP:0001256",
          "HP:0002187",
          "HP:0002342",
          "HP:0006889",
          "HP:0010864"
        )

        # NDD entity categories (NOT phenotype categories!)
        categories <- c("Definitive")

        # Fetch required tables
        ndd_entity_view_tbl <- pool %>%
          tbl("ndd_entity_view") %>%
          collect()

        ndd_entity_review_tbl <- pool %>%
          tbl("ndd_entity_review") %>%
          collect() %>%
          filter(is_primary == 1) %>%
          dplyr::select(review_id)

        ndd_review_phenotype_connect_tbl <- pool %>%
          tbl("ndd_review_phenotype_connect") %>%
          collect()

        modifier_list_tbl <- pool %>%
          tbl("modifier_list") %>%
          collect()

        phenotype_list_tbl <- pool %>%
          tbl("phenotype_list") %>%
          collect()

        # Build the phenotypes data frame (same as analysis_endpoints.R)
        sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
          left_join(ndd_review_phenotype_connect_tbl, by = c("entity_id")) %>%
          left_join(modifier_list_tbl, by = c("modifier_id")) %>%
          left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
          mutate(ndd_phenotype = case_when(
            ndd_phenotype == 1 ~ "Yes",
            ndd_phenotype == 0 ~ "No"
          )) %>%
          filter(ndd_phenotype == "Yes") %>%
          filter(category %in% categories) %>%
          filter(modifier_name == "present") %>%
          filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
          dplyr::select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id, HPO_term, hgnc_id) %>%
          group_by(entity_id) %>%
          mutate(
            phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
            phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
          ) %>%
          ungroup() %>%
          unique()

        sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
          mutate(present = "yes") %>%
          select(-phenotype_id) %>%
          pivot_wider(names_from = HPO_term, values_from = present) %>%
          group_by(hgnc_id) %>%
          mutate(gene_entity_count = n()) %>%
          ungroup() %>%
          relocate(gene_entity_count, .after = phenotype_id_count) %>%
          select(-hgnc_id)

        sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
          select(-entity_id) %>%
          as.data.frame()
        row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

        # Call memoised function with correct params - returns tibble directly
        gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df)
      }
    }, error = function(e) {
      log_warn("Failed to fetch {ct} clusters: {e$message}")
      NULL
    })

    if (!is.null(clusters) && nrow(clusters) > 0) {
      # Trigger LLM batch generation
      result <- trigger_llm_batch_generation(
        clusters = clusters,
        cluster_type = ct,
        parent_job_id = parent_job_id
      )
      results[[ct]] <- result
    } else {
      results[[ct]] <- list(skipped = TRUE, reason = "No clusters found")
    }
  }

  res$status <- 202
  list(
    job_id = parent_job_id,
    status = "accepted",
    status_url = paste0("/api/jobs/", parent_job_id),
    cluster_types = cluster_types_to_process,
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
#* @param page:int Page number (1-indexed, default: 1)
#* @param per_page:int Entries per page (default: 50)
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - data: Array of log entries
#* - total: Integer, total matching entries
#* - page: Integer, current page
#* - per_page: Integer, entries per page
#*
#* @tag llm-admin
#* @serializer json list(na="string")
#* @get /logs
function(req, res, cluster_type = NULL, status = NULL, from_date = NULL, to_date = NULL,
         page = 1, per_page = 50) {
  require_role(req, res, "Administrator")

  # Convert to integer
  page <- as.integer(page)
  per_page <- as.integer(per_page)

  # Convert empty strings to NULL
  if (!is.null(cluster_type) && cluster_type == "") cluster_type <- NULL
  if (!is.null(status) && status == "") status <- NULL
  if (!is.null(from_date) && from_date == "") from_date <- NULL
  if (!is.null(to_date) && to_date == "") to_date <- NULL

  get_generation_logs_paginated(
    cluster_type = cluster_type,
    status = status,
    from_date = from_date,
    to_date = to_date,
    page = page,
    per_page = per_page
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
