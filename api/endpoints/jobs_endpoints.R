# api/endpoints/jobs_endpoints.R
#
# Async job submission and status polling endpoints.
# Submits durable worker jobs and returns HTTP 202 Accepted for long-running operations.
#
# Endpoints:
#   POST /api/jobs/clustering/submit - Submit functional clustering job
#   POST /api/jobs/phenotype_clustering/submit - Submit phenotype clustering job
#   GET /api/jobs/<job_id>/status - Poll job status and retrieve results
#
# Dependencies:
#   - pool (global database connection pool)
#   - create_job, get_job_status, check_duplicate_job (from job-manager.R)
#   - durable handlers registered in functions/async-job-handlers.R
#
# Handler bodies were extracted to services/job-*-service.R (issue #346, Wave
# 3, Task 5) to keep this file a thin route table. Each shell below keeps its
# original decorators, formals, and role gate, and delegates the rest to the
# matching svc_ function.

## -------------------------------------------------------------------##
## Job Submission Endpoints
## -------------------------------------------------------------------##

#* Submit Functional Clustering Job
#*
#* Submits an async job to compute functional clustering via STRING-db. The
#* clustering gene universe (#574) is resolved from one of three mutually
#* exclusive JSON body selectors:
#*   - `genes`: an explicit array of HGNC ids to cluster.
#*   - `category_filter`: an array of curated SysNDD confidence categories
#*     (e.g. `["Definitive"]`); resolved entity-level (>=1 NDD entity in a
#*     selected category, `ndd_phenotype = 1`) against the live
#*     `ndd_entity_view`, validated against the live active
#*     `ndd_entity_status_categories_list`. A category run rejects with 400
#*     when `category_filter` is empty, contains an unknown/inactive value
#*     (the allowed active set is named in the error), or resolves fewer
#*     than 2 genes.
#*   - neither: the existing default all-NDD-genes universe.
#* Supplying both `genes` and a non-empty `category_filter` is a 400.
#*
#* Every submit records selector/fingerprint provenance -- `selector`
#* (`kind`: `explicit`|`category`|`all_ndd`, plus `category_filter` for
#* category runs), `resolved_gene_count`, `gene_list_sha256`,
#* `intended_fingerprint`, and `source_data_version` -- in the durable job
#* payload; the job result `meta` additionally carries `effective_fingerprint`
#* (the STRING `weight_channel` actually observed on the computed result),
#* recorded on both a cache-hit (immediate) response and a worker-run
#* (cache-miss) job.
#*
#* Results from this endpoint (including category-filtered runs) are never
#* `public_ready` -- they are ephemeral job results, distinct from the public
#* `analysis_snapshot_*` layer.
#*
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @param genes Optional JSON array of explicit HGNC ids. Mutually exclusive
#*   with `category_filter`.
#* @param category_filter Optional JSON array of curated SysNDD confidence
#*   categories (e.g. `["Definitive"]`). Mutually exclusive with `genes`.
#* @param algorithm Optional clustering algorithm string, `"leiden"`
#*   (default) or `"walktrap"`.
#* @post /clustering/submit
function(req, res) {
  svc_job_submit_functional_clustering(req, res)
}

## -------------------------------------------------------------------##
## Phenotype Clustering Submission
## -------------------------------------------------------------------##

#* Submit Phenotype Clustering Job
#*
#* Submits an async job to compute phenotype clustering via MCA.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /phenotype_clustering/submit
function(req, res) {
  svc_job_submit_phenotype_clustering(req, res)
}

## -------------------------------------------------------------------##
## Ontology Update Submission
## -------------------------------------------------------------------##

#* Submit Ontology Update Job
#*
#* Submits an async job to update disease ontology data from MONDO and OMIM sources.
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /ontology_update/submit
function(req, res) {
  require_role(req, res, "Administrator")
  svc_job_submit_ontology_update(res)
}

## -------------------------------------------------------------------##
## HGNC Data Update Submission
## -------------------------------------------------------------------##

#* Submit HGNC Data Update Job
#*
#* Submits an async job to download and update HGNC gene data.
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /hgnc_update/submit
function(req, res) {
  require_role(req, res, "Administrator")
  svc_job_submit_hgnc_update(res)
}

## -------------------------------------------------------------------##
## Comparisons Data Update Submission
## -------------------------------------------------------------------##

#* Submit Comparisons Data Update Job
#*
#* Submits an async job to refresh the comparisons data from all external
#* NDD databases (Radboud, Gene2Phenotype, PanelApp, SFARI, Geisinger,
#* OMIM NDD, Orphanet).
#*
#* Requires Administrator role.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @post /comparisons_update/submit
function(req, res) {
  require_role(req, res, "Administrator")
  svc_job_submit_comparisons_update(res)
}

## -------------------------------------------------------------------##
## Job History
## -------------------------------------------------------------------##

#* Get Job History
#*
#* Returns a list of recent jobs for admin review.
#* Requires Administrator role.
#*
#* @tag jobs
#* @serializer json list(na="string")
#* @get /history
function(req, res, limit = 20) {
  require_role(req, res, "Administrator")
  svc_job_get_history(limit)
}

## -------------------------------------------------------------------##
## Job Status Polling
## -------------------------------------------------------------------##

#* Get Job Status
#*
#* Poll job status and retrieve results when complete.
#* Returns Retry-After header for running jobs.
#*
#* @tag jobs
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @get /<job_id>/status
function(job_id, result_mode = "summary", req, res) {
  svc_job_get_status(job_id, result_mode, req, res)
}
