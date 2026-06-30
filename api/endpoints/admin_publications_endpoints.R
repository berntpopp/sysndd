## -------------------------------------------------------------------##
# api/endpoints/admin_publications_endpoints.R
#
# Administrator-only HTTP triggers for the durable verified publication-date
# backfill (#460). Mounted at /api/admin/publications, so:
#   POST /api/admin/publications/verify-dates         (enqueue a backfill job)
#   GET  /api/admin/publications/verify-dates/status  (last-run summary)
#
# The backfill re-fetches PubMed metadata for primary-approved publications whose
# publication_date_source is NULL/invalid and writes both Publication_date and
# publication_date_source, so legacy literature dates become temporally/provenance
# queryable through the API/MCP. The selection/fetch/write logic is the shared
# backfill_publication_dates_run() (also run by the operator CLI
# db/updates/backfill_publication_dates.R). Mounted via mount_endpoint() (RFC 9457
# error handling) and BEFORE /api/admin so the more-specific prefix wins.
## -------------------------------------------------------------------##

#* Enqueue a verified publication-date backfill job (Administrator only)
#*
#* Submits a durable `publication_date_backfill` async job so the worker re-fetches
#* PubMed metadata for primary-approved publications with an unverified
#* publication_date_source and writes both the date and its source. Re-submitting a
#* queued/running backfill returns the existing job (dedup). Pass `dry_run=true` to
#* report the target count without writing; `limit` caps the number of publications.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param limit:int Optional cap on the number of targeted publications.
#* @param dry_run:bool Optional; report targets without writing. Default false.
#*
#* @post /verify-dates
function(req, res, limit = NULL, dry_run = FALSE) {
  require_role(req, res, "Administrator")

  dry_run_flag <- isTRUE(dry_run) ||
    identical(tolower(as.character(dry_run)[[1]]), "true") ||
    identical(as.character(dry_run)[[1]], "1")

  limit_value <- if (is.null(limit) || !nzchar(as.character(limit)[[1]])) {
    NULL
  } else {
    parsed <- suppressWarnings(as.integer(as.character(limit)[[1]]))
    if (is.na(parsed) || parsed < 1L) {
      stop_for_bad_request("limit must be a positive integer")
    }
    parsed
  }

  outcome <- async_job_service_submit(
    job_type = "publication_date_backfill",
    request_payload = list(
      limit = limit_value,
      dry_run = dry_run_flag,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    ),
    queue_name = "default",
    priority = 50L,
    max_attempts = 1L
  )

  job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
  duplicate <- isTRUE(outcome$duplicate)

  res$status <- 202L
  list(
    submitted = !duplicate,
    duplicate = duplicate,
    job_id = job_id,
    dry_run = dry_run_flag,
    message = if (duplicate) {
      "existing queued/running backfill reused"
    } else {
      "verified publication-date backfill job submitted"
    }
  )
}

#* Verified publication-date backfill status (Administrator only)
#*
#* Returns the latest `publication_date_backfill` job (status, timestamps, and the
#* stored run summary: targeted / verified / partial / unresolved) so an operator can
#* watch a backfill progress without DB access.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /verify-dates/status
function(req, res) {
  require_role(req, res, "Administrator")

  rows <- db_execute_query(
    paste(
      "SELECT job_id, status, submitted_at, started_at, completed_at, result_json",
      "FROM async_jobs",
      "WHERE job_type = 'publication_date_backfill'",
      "ORDER BY submitted_at DESC",
      "LIMIT 1"
    )
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(list(
      last_run = NULL,
      message = "no verified publication-date backfill has run yet"
    ))
  }

  row <- rows[1, , drop = FALSE]

  parsed <- tryCatch(
    if (!is.na(row$result_json) && nzchar(row$result_json)) {
      jsonlite::fromJSON(row$result_json, simplifyVector = TRUE)
    } else {
      NULL
    },
    error = function(e) NULL
  )
  run_summary <- if (!is.null(parsed) && !is.null(parsed$summary)) parsed$summary else parsed

  list(
    last_run = list(
      job_id = row$job_id,
      status = row$status,
      submitted_at = as.character(row$submitted_at),
      started_at = as.character(row$started_at),
      completed_at = as.character(row$completed_at),
      summary = run_summary
    )
  )
}
