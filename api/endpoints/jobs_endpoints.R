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
#* Submits an async job to compute functional clustering via STRING-db.
#* Returns immediately with job ID for status polling.
#*
#* @tag jobs
#* @serializer json list(na="string")
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
