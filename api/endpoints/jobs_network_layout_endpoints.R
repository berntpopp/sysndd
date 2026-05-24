# api/endpoints/jobs_network_layout_endpoints.R
#
# Admin endpoints for GeneNetworks display layout artifact jobs.

job_network_layout_payload_value <- function(payload, field, default) {
  value <- payload[[field]]
  if (is.null(value) || length(value) == 0) {
    return(default)
  }
  if (is.list(value)) {
    return(value[[1]])
  }
  value[[1]]
}

job_network_layout_submit_params <- function(payload) {
  list(
    cluster_type = as.character(job_network_layout_payload_value(payload, "cluster_type", "clusters")),
    min_confidence = as.integer(job_network_layout_payload_value(payload, "min_confidence", 400L)),
    max_edges = as.integer(job_network_layout_payload_value(payload, "max_edges", 10000L)),
    force = isTRUE(job_network_layout_payload_value(payload, "force", FALSE))
  )
}

#* Submit gene network layout prewarm job
#*
#* @tag jobs
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @post /submit
function(req, res) {
  require_role(req, res, "Administrator")

  payload <- req$argsBody
  if (is.null(payload)) {
    payload <- list()
  }
  params <- job_network_layout_submit_params(payload)

  submitted <- async_job_service_submit(
    job_type = "network_layout_prewarm",
    request_payload = params,
    submitted_by = req$user$user_id %||% NULL
  )

  job <- submitted$job
  job_id <- job$job_id[[1]]
  status_url <- paste0("/api/jobs/", job_id, "/status")

  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
  res$setHeader("Location", status_url)
  res$setHeader("Retry-After", "10")

  list(
    job_id = job_id,
    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
    job_status = job$status[[1]],
    status_url = status_url
  )
}
