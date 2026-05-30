# functions/async-job-analysis-snapshot-handlers.R

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

.async_job_run_analysis_snapshot_refresh <- function(job, payload, state, worker_config) {
  analysis_type <- as.character(payload$analysis_type[[1]] %||% payload$analysis_type)
  params <- payload$params %||% list()
  progress <- .async_job_progress_reporter(job$job_id[[1]], throttle_seconds = 2)

  progress("snapshot_start", paste("Refreshing analysis snapshot", analysis_type), current = 0, total = 3)
  normalized <- analysis_snapshot_normalize_params(analysis_type, params)
  progress("snapshot_build", paste("Building analysis snapshot", analysis_type), current = 1, total = 3)
  result <- analysis_snapshot_refresh(
    analysis_type = normalized$analysis_type,
    params = normalized$params,
    job_id = job$job_id[[1]]
  )
  progress("snapshot_complete", paste("Analysis snapshot refreshed", analysis_type), current = 3, total = 3)

  result
}
