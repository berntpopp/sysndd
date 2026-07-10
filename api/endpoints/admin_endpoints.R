# api/endpoints/admin_endpoints.R
#
# This file contains all Administrator-related endpoints, extracted from the
# original sysndd_plumber.R. It follows the Google R Style Guide conventions
# where possible (e.g., two-space indentation, meaningful function names, etc.).
#
# Route bodies are thin: each decorator/formal/`require_role()` gate stays
# here, but the implementation lives in the matching
# api/services/admin-*-endpoint-service.R file (issue #346, Wave 3):
#   - admin-ontology-endpoint-service.R      ontology/HGNC/deprecated-entity
#   - admin-diagnostics-endpoint-service.R   OpenAPI/version/dates/SMTP
#   - admin-nddscore-endpoint-service.R      NDDScore status/zenodo/import
#   - admin-publication-refresh-endpoint-service.R  publications/refresh
#
# Note: All required modules (db-helpers.R, middleware.R, the services above)
# are sourced by start_sysndd_api.R before endpoints are loaded. Functions
# are available in the global environment.

## -------------------------------------------------------------------##
## Administration section
## -------------------------------------------------------------------##

#* Get OpenAPI specification
#*
#* Returns the enhanced OpenAPI JSON specification for this API.
#* This endpoint is used by the frontend Swagger UI.
#*
#* The spec is enhanced with:
#* - Component schemas from config/openapi/schemas/*.json
#* - RFC 9457 ProblemDetails error responses
#* - Standard error response references on all endpoints
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /openapi.json
function(req, res) {
  # req$pr refers to this sub-router (admin endpoints only); root$getApiSpec()
  # returns the full spec with all mounted endpoints, already enhanced by
  # root's pr_set_api_spec callback.
  svc_admin_openapi_spec(root)
}

#* Updates ontology sets (DEPRECATED — removed)
#*
#* **REMOVED:** This synchronous endpoint has been removed.
#* Use PUT /admin/update_ontology_async instead, which provides progress
#* tracking, auto-fix of version shuffles, and safeguards against
#* critical ontology changes.
#*
#* @tag admin
#* @serializer unboxedJSON
#* @put update_ontology
function(req, res) {
  res$status <- 410L
  list(
    error = "Gone",
    message = "This endpoint is deprecated. Use PUT /api/admin/update_ontology_async"
  )
}

#* Updates OMIM ontology annotations asynchronously
#*
#* Returns immediately with a job_id. Poll GET /api/jobs/{job_id} for status.
#* Uses the new mim2gene.txt + JAX API workflow for OMIM data.
#*
#* Progress steps:
#* 1) Download mim2gene.txt
#* 2) Fetch disease names from JAX API
#* 3) Build and validate ontology set
#* 4) Apply MONDO SSSOM mappings and write to database
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* On success: Returns 202 with job_id and status="accepted".
#* If duplicate job running: Returns existing job_id with status="already_running".
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_ontology_async
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_ontology_update_async(req, res, pool, dw)
}

#* Force-apply a blocked ontology update
#*
#* When an ontology update is blocked due to critical entity-referenced changes,
#* this endpoint force-applies the update by:
#* 1. Applying auto-fix remappings to ndd_entity
#* 2. Writing the new ontology set
#* 3. Inserting compatibility rows (is_active=FALSE) for critical old versions
#* 4. Creating a re-review batch for critical entities
#*
#* Returns immediately with a job_id. Poll GET /api/jobs/{job_id} for status.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Parameters`
#* @param blocked_job_id:character The job_id of the blocked ontology update
#*
#* # `Return`
#* On success: Returns 202 with job_id for the force-apply job.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put force_apply_ontology
function(req, res, blocked_job_id = NULL, assigned_user_id = NULL) {
  require_role(req, res, "Administrator")

  if (is.null(blocked_job_id) || blocked_job_id == "") {
    res$status <- 400L
    return(list(error = "blocked_job_id query parameter is required"))
  }

  prepared <- svc_admin_force_apply_ontology_prepare(
    req, res, blocked_job_id, assigned_user_id, pool
  )
  if (!is.null(prepared$early_return)) {
    return(prepared$early_return)
  }

  # Check for duplicate job
  dup_check <- check_duplicate_job("force_apply_ontology", list())
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "A force-apply job is already running"
    ))
  }

  result <- create_job(
    operation = "force_apply_ontology",
    params = prepared$params
  )

  res$status <- 202
  return(result)
}

#* Updates HGNC data and refreshes the non_alt_loci_set table
#*
#* This endpoint performs an update process by downloading the latest HGNC data,
#* processing it, and updating the non_alt_loci_set table. It is restricted to
#* Administrator users.
#*
#* # `Details`
#* The function downloads the latest HGNC file, processes the gene information,
#* updates STRINGdb identifiers, computes gene coordinates, and then updates
#* the non_alt_loci_set table in the MySQL database with these new values.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role.
#*
#* # `Return`
#* If successful, returns a success message. Otherwise, returns an error message.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put update_hgnc_data
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_hgnc_update(req, res)
}

#* Retrieves the current API version
#*
#* This endpoint provides the current version of the API. It's a simple utility
#* function that can be useful for clients to check the API version they are
#* interacting with. This can help in ensuring compatibility when multiple
#* versions exist.
#*
#* # `Details`
#* The function no longer calls `apiV()`, but instead references a global
#* variable `sysndd_api_version`. It's primarily for informational purposes.
#*
#* # `Authorization`
#* This endpoint does not require any specific role. It's open for any client
#* or user who needs to know the API version.
#*
#* # `Return`
#* Returns a JSON object with the API version, e.g. {"api_version": "x.y.z"}.
#*
#* @tag admin
#* @serializer unboxedJSON list(na="string")
#* @get api_version
function() {
  svc_admin_api_version(sysndd_api_version)
}

#* Get annotation update dates
#*
#* Returns the last update dates for various annotation sources.
#* Prefers job completion timestamps from job history over file metadata,
#* falling back to file dates for fresh installs with no job runs.
#*
#* # `Return`
#* Returns dates for OMIM (mim2gene), MONDO mappings, and HGNC updates.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @get annotation_dates
function() {
  svc_admin_annotation_dates()
}

#* Get entities using deprecated OMIM IDs
#*
#* Returns entities that reference OMIM IDs marked as "moved/removed" in the
#* latest mim2gene.txt file. Each entity is enriched with MONDO mapping info
#* and replacement suggestions from the EBI OLS4 API.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* Returns a list with:
#* - deprecated_count: Number of deprecated MIM numbers found
#* - affected_entity_count: Number of entities using deprecated OMIM IDs
#* - affected_entities: Array of entities with MONDO deprecation info
#* - mim2gene_date: Date of the mim2gene.txt file used
#*
#* Each affected entity includes:
#* - entity_id, symbol, hgnc_id, disease_ontology_id, disease_ontology_name, category
#* - mondo_id: MONDO term referencing this OMIM (if found)
#* - mondo_label: Label of the MONDO term
#* - deprecation_reason: Reason for deprecation from MONDO
#* - replacement_mondo_id: Suggested replacement MONDO term
#* - replacement_omim_id: Suggested replacement OMIM ID
#*
#* @tag admin
#* @serializer json list(na="string")
#* @get deprecated_entities
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_deprecated_entities(req, res, pool)
}

#* Test SMTP connection status
#*
#* Attempts to connect to the configured SMTP server and returns
#* connection status. Does not send any email.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* # `Return`
#* - success: Boolean indicating if connection succeeded
#* - host: SMTP host that was tested
#* - port: SMTP port that was tested
#* - error: Error message if connection failed (null on success)
#*
#* @tag admin
#* @serializer unboxedJSON
#* @get /smtp/test
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_smtp_test(req, res, dw)
}

## -------------------------------------------------------------------##
## NDDScore Administration Endpoints
## -------------------------------------------------------------------##

#* Get NDDScore import status
#*
#* Returns the active NDDScore release and recent durable import jobs.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @get /nddscore/status
function(req, res, limit = 10L) {
  require_role(req, res, "Administrator")
  svc_admin_nddscore_status(req, res, limit)
}

#* Check NDDScore Zenodo metadata
#*
#* Fetches Zenodo record metadata and compares it with the active release.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @get /nddscore/zenodo
function(req, res, record_id = NULL) {
  require_role(req, res, "Administrator")
  svc_admin_nddscore_zenodo(req, res, record_id)
}

#* Submit NDDScore import job
#*
#* Submits a durable nddscore_import job. Poll the returned status_url.
#*
#* # `Request Body`
#* {
#*   "record_id": "20258027",
#*   "validate_only": false
#* }
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="null")
#* @post /nddscore/import
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_nddscore_import(req, res)
}

#* Refresh publication metadata from PubMed
#*
#* Returns immediately with job_id. Poll GET /api/jobs/{job_id} for status.
#* Rate limited to 3 requests/second (NCBI limit without API key).
#*
#* Supports three modes:
#* 1. Explicit PMIDs: Provide a `pmids` list to refresh
#* 2. Date filter: Provide `not_updated_since` (YYYY-MM-DD) to refresh publications older than that
#* 3. Refresh all: Provide `all=true` to refresh the whole corpus (enumerated server-side)
#*
#* Request body: { pmids?: [...], not_updated_since?: "YYYY-MM-DD", all?: true }.
#* With both a date and pmids, the list is filtered to publications older than the date.
#*
#* Returns 202 Accepted with { job_id, status, estimated_seconds }.
#*
#* # `Authorization`
#* Restricted to Administrator role.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @post /publications/refresh
function(req, res) {
  require_role(req, res, "Administrator")
  svc_admin_publication_refresh_submit(req, res, dw)
}

## Administration section
## -------------------------------------------------------------------##
