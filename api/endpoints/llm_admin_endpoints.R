# api/endpoints/llm_admin_endpoints.R
#
# LLM Administration endpoints for managing configuration, prompts, cache, and
# logs. All endpoints require Administrator role. Required modules (including
# services/llm-admin-endpoint-service.R) are sourced by start_sysndd_api.R
# before endpoints are loaded. Each handler below is a thin decorator +
# Administrator role gate that delegates to the matching svc_llm_admin_*
# function in services/llm-admin-endpoint-service.R (issue #346).

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

  svc_llm_admin_get_config()
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

  outcome <- svc_llm_admin_update_config(model)
  res$status <- outcome$http_status
  outcome$body
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

  svc_llm_admin_cache_stats()
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

  svc_llm_admin_cache_summaries(
    cluster_type = cluster_type,
    validation_status = validation_status,
    page = page,
    per_page = per_page,
    limit = limit,
    offset = offset
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

  outcome <- svc_llm_admin_clear_cache(cluster_type)
  res$status <- outcome$http_status
  outcome$body
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

  # Snapshot-driven (#488): never recompute clustering here.
  outcome <- svc_llm_admin_regenerate(
    cluster_type = cluster_type,
    force = force,
    regenerate_from_snapshot = llm_regenerate_from_snapshot
  )
  res$status <- outcome$http_status
  outcome$body
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

  svc_llm_admin_generation_logs(
    cluster_type = cluster_type,
    status = status,
    from_date = from_date,
    to_date = to_date,
    page = page,
    per_page = per_page,
    limit = limit,
    offset = offset
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

  user_id <- req$user_id # token identity, threaded through for attribution
  outcome <- svc_llm_admin_validate_cache(cache_id, action, user_id)
  res$status <- outcome$http_status
  outcome$body
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

  svc_llm_admin_get_prompts()
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

  if (is.null(template)) { # fall back to the JSON body when query params are absent
    body <- req$body
    template <- body$template
    version <- body$version %||% version
    description <- body$description %||% description
  }

  outcome <- svc_llm_admin_update_prompt(type, template, version, description)
  res$status <- outcome$http_status
  outcome$body
}
