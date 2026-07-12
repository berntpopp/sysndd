# api/services/admin-publication-refresh-endpoint-service.R
#
# Service layer for POST /admin/publications/refresh, extracted from
# api/endpoints/admin_endpoints.R (issue #346, Wave 3).
#
# `create_job()` (functions/job-manager.R) is a durable-job compatibility
# facade: it always routes through `async_job_service_submit(job_type =
# operation, request_payload = params)` and never references its
# `executor_fn` formal. The ~90-line inline `executor_fn` this endpoint used
# to pass (PubMed fetch + UPDATE + Sys.sleep(0.35) rate limiting) was
# therefore dead code -- unreachable, and already diverged from the live
# implementation (missing the `publication_date_source` column write). The
# real, currently-executed handler is
# `.async_job_run_publication_refresh()` in functions/async-job-handlers.R
# (registered in `async_job_handler_registry`), which already has the
# publication_date_source fix, the same 350ms rate limit, and its own DB
# connection lifecycle -- mirroring the pattern already documented in
# AGENTS.md for `comparisons_update`'s dead `executor_fn`. Dropping the dead
# copy here does not change observable behavior; it was never called.
#
# `require_role(req, res, "Administrator")` stays inline in the endpoint
# shell. All DB-facing collaborators are injectable (default = the real
# global function) so unit tests can supply fakes without a live database.

#' Validate the optional `not_updated_since` date filter.
#'
#' @return List(valid, error, date). `date` is `NULL` when no/empty filter
#'   was supplied (valid, no filtering); `error` is set only when invalid.
#' @export
svc_admin_publication_refresh_validate_date <- function(not_updated_since) {
  if (is.null(not_updated_since) || !nzchar(not_updated_since)) {
    return(list(valid = TRUE, error = NULL, date = NULL))
  }

  filter_date <- tryCatch(as.Date(not_updated_since), error = function(e) NULL)

  if (is.null(filter_date) || is.na(filter_date)) {
    return(list(
      valid = FALSE,
      error = "Invalid date format for not_updated_since. Use YYYY-MM-DD.",
      date = NULL
    ))
  }

  list(valid = TRUE, error = NULL, date = as.character(filter_date))
}

#' Resolve the PMID set to refresh from the raw request body.
#'
#' Applies the date filter (fetching publications older than `filter_date`
#' and intersecting with any explicit `pmids`) and the opt-in `all=true`
#' full-corpus enumeration. Mirrors the original endpoint's three modes:
#' explicit PMIDs, date filter, or full-corpus refresh.
#'
#' @return List(pmids, message, count). `message` is non-NULL (with `count`)
#'   when the caller should return early with a 200 "nothing to do" response
#'   instead of submitting a job.
#' @export
svc_admin_publication_refresh_resolve_pmids <- function(pmids, filter_date, refresh_all,
                                                          query_fn = db_execute_query) {
  if (!is.null(filter_date)) {
    filtered_pubs <- query_fn(
      "SELECT publication_id FROM publication WHERE update_date < ?",
      list(filter_date)
    )

    if (nrow(filtered_pubs) == 0) {
      return(list(
        pmids = NULL,
        message = "No publications need refreshing",
        filter_date = filter_date,
        count = 0
      ))
    }

    filtered_pmids <- filtered_pubs$publication_id

    if (is.null(pmids) || length(pmids) == 0) {
      pmids <- filtered_pmids
    } else {
      pmids <- intersect(pmids, filtered_pmids)
      if (length(pmids) == 0) {
        return(list(
          pmids = NULL,
          message = "No matching publications need refreshing",
          filter_date = filter_date,
          count = 0
        ))
      }
    }
  }

  # Opt-in full-corpus refresh: enumerate server-side (client need not fetch all PMIDs).
  if (refresh_all && (is.null(pmids) || length(pmids) == 0)) {
    pmids <- query_fn("SELECT publication_id FROM publication")$publication_id
  }

  list(pmids = pmids, message = NULL, filter_date = filter_date, count = NULL)
}

#' 350ms-per-PMID (+ overhead) time estimate, matching the NCBI EUtils
#' rate limit the durable handler self-throttles to.
#' @export
svc_admin_publication_refresh_estimate_seconds <- function(pmids) {
  ceiling(length(pmids) * 0.4)
}

#' POST /admin/publications/refresh body.
#'
#' Supports three modes: explicit `pmids`, a `not_updated_since` date filter,
#' or opt-in `all=true` full-corpus refresh. Submits the durable
#' `publication_refresh` job (202) unless a duplicate is already running,
#' capacity is exceeded (503, surfaced by `create_job_fn`), or no PMIDs
#' resolve (400/200 per the original contract).
#'
#' @export
svc_admin_publication_refresh_submit <- function(req, res,
                                                   query_fn = db_execute_query,
                                                   duplicate_check_fn = check_duplicate_job,
                                                   create_job_fn = create_job) {
  # CRITICAL: Extract request body BEFORE any async submission -- the request
  # object cannot cross process/worker boundaries.
  body <- req$body
  pmids <- body$pmids
  not_updated_since <- body$not_updated_since
  refresh_all <- isTRUE(body$all)

  date_check <- svc_admin_publication_refresh_validate_date(not_updated_since)
  if (!date_check$valid) {
    res$status <- 400
    return(list(error = date_check$error))
  }

  resolved <- svc_admin_publication_refresh_resolve_pmids(
    pmids, date_check$date, refresh_all, query_fn = query_fn
  )
  if (!is.null(resolved$message)) {
    res$status <- 200
    return(list(
      message = resolved$message,
      filter_date = resolved$filter_date,
      count = resolved$count
    ))
  }
  pmids <- resolved$pmids

  # Validate input - at least one PMID required. An empty request still 400s
  # (safety guard); full-corpus refresh requires the explicit all=true flag.
  if (is.null(pmids) || length(pmids) == 0) {
    res$status <- 400
    return(list(error = "No PMIDs provided and no date filter specified"))
  }

  dup_check <- duplicate_check_fn("publication_refresh", list(pmids = pmids))
  if (dup_check$duplicate) {
    return(list(
      job_id = dup_check$existing_job_id,
      status = "already_running",
      message = "A publication refresh job is already running with these PMIDs"
    ))
  }

  estimated_seconds <- svc_admin_publication_refresh_estimate_seconds(pmids)

  result <- create_job_fn(
    operation = "publication_refresh",
    params = list(pmids = pmids),
    timeout_ms = 7200000 # 2 hours timeout for large batches (4547 pubs ~27 min)
  )

  # Check for capacity error
  if (!is.null(result$error)) {
    res$status <- 503
    return(result)
  }

  result$estimated_seconds <- estimated_seconds
  res$status <- 202
  result
}
