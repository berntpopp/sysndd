# api/functions/async-job-maintenance-handlers.R
#
# Durable async job handlers for maintenance/operational refresh families:
# database backup create/restore and publication metadata refresh/backfill.
#
# Worker-executed code (#346 Wave 4 split of async-job-handlers.R). The
# `async_job_handler_registry` list in functions/async-job-handlers.R
# references these handler functions by bare symbol, and R evaluates a
# list() literal's elements eagerly at construction time — so this file
# MUST be sourced BEFORE functions/async-job-handlers.R at every worker
# entrypoint (API bootstrap does not need it; the API never dispatches
# handlers, only submits jobs).

.async_job_run_backup_create <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  # Resolve DB credentials from runtime config, not the job payload (#535 P1-1).
  db_config <- async_job_worker_db_config()

  output_path <- file.path(payload$backup_dir, payload$backup_filename)
  result <- execute_mysqldump(
    db_config,
    output_path,
    progress_fn = progress,
    compress = TRUE,
    create_latest_link = TRUE
  )

  if (!isTRUE(result$success)) {
    stop(paste("Backup failed:", result$error), call. = FALSE)
  }

  list(
    status = "completed",
    filename = basename(result$file),
    size_bytes = result$size_bytes,
    compressed = result$compressed
  )
}

.async_job_run_backup_restore <- function(job, payload, state, worker_config) {
  progress <- .async_job_progress_reporter(job$job_id[[1]])

  # Resolve DB credentials from runtime config, not the job payload (#535 P1-1).
  db_config <- async_job_worker_db_config()

  progress("pre_backup", "Creating pre-restore safety backup...", 1, 4)
  pre_restore_filename <- sprintf("pre-restore_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
  pre_restore_path <- file.path(payload$backup_dir, pre_restore_filename)

  pre_result <- execute_mysqldump(
    db_config,
    pre_restore_path,
    progress_fn = NULL,
    compress = TRUE,
    create_latest_link = FALSE
  )

  if (!isTRUE(pre_result$success)) {
    stop(
      paste("Pre-restore backup failed - cannot proceed with restore:", pre_result$error),
      call. = FALSE
    )
  }

  progress(
    "pre_backup_done",
    sprintf("Pre-restore backup created (%.1f MB)", pre_result$size_bytes / 1024 / 1024),
    2, 4
  )
  progress("restoring", sprintf("Restoring from %s...", basename(payload$restore_file)), 3, 4)

  restore_result <- execute_restore(
    db_config,
    payload$restore_file,
    progress_fn = NULL
  )

  if (!isTRUE(restore_result$success)) {
    stop(
      paste(
        "Restore failed:",
        restore_result$error,
        "- pre-restore backup available at:",
        basename(pre_result$file)
      ),
      call. = FALSE
    )
  }

  # A restored dump may re-import credential-bearing async_jobs rows (#535 H5);
  # scrub them before reporting completion. The scrub RUNS regardless of the
  # job's eventual status, so the credentials are redacted either way; the next
  # API-startup scrub is an additional idempotent backstop. The restore itself
  # succeeded, so a scrub failure must NOT fail the job — it is logged at WARN
  # (the worker log survives the restore) and also surfaced in the result.
  # NOTE: a *full* restore replaces async_jobs, deleting this job's own row, so
  # result_json (incl. post_restore_scrub) may be lost when the worker's
  # completion UPDATE finds 0 rows (the restore-fencing limitation tracked as
  # S3). The WARN log is therefore the reliable signal. Retry once on a fresh
  # runtime-config connection since the restore may have invalidated the pool.
  scrub_outcome <- tryCatch(
    {
      async_job_scrub_payload_credentials()
      "ok"
    },
    error = function(e1) {
      tryCatch(
        {
          con <- async_job_db_connect()
          on.exit(tryCatch(DBI::dbDisconnect(con), error = function(e) NULL), add = TRUE)
          async_job_scrub_payload_credentials(conn = con)
          "ok"
        },
        error = function(e2) {
          logger::log_warn(
            "[backup-restore] post-restore credential scrub FAILED after retry: {conditionMessage(e2)}"
          )
          paste0("failed: ", conditionMessage(e2))
        }
      )
    }
  )

  progress("complete", "Restore completed successfully", 4, 4)

  list(
    status = "completed",
    pre_restore_backup = basename(pre_result$file),
    restored_from = basename(payload$restore_file),
    post_restore_scrub = scrub_outcome
  )
}

.async_job_run_publication_refresh <- function(job, payload, state, worker_config) {
  reporter <- .async_job_progress_reporter(job$job_id[[1]])
  pmids <- payload$pmids
  total <- length(pmids)
  results <- vector("list", total)

  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = payload$db_config$dbname,
    user = payload$db_config$user,
    password = payload$db_config$password,
    host = payload$db_config$host,
    port = payload$db_config$port
  )
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  for (i in seq_along(pmids)) {
    pmid <- pmids[i]
    reporter("fetch", sprintf("Fetching %s (%d/%d)", pmid, i, total), current = i, total = total)

    results[[i]] <- tryCatch(
      {
        info <- info_from_pmid(pmid)
        rows_affected <- db_execute_statement(
          "UPDATE publication SET
            Title = ?,
            Abstract = ?,
            Publication_date = ?,
            publication_date_source = ?,
            Journal = ?,
            Keywords = ?,
            Lastname = ?,
            Firstname = ?,
            update_date = NOW()
          WHERE publication_id = ?",
          list(
            info$Title[1],
            info$Abstract[1],
            info$Publication_date[1],
            info$publication_date_source[1],
            info$Journal[1],
            info$Keywords[1],
            info$Lastname[1],
            info$Firstname[1],
            pmid
          ),
          conn = sysndd_db
        )

        list(
          pmid = pmid,
          status = if (rows_affected > 0) "updated" else "not_found",
          title = info$Title[1]
        )
      },
      error = function(e) {
        list(
          pmid = pmid,
          status = "error",
          error = conditionMessage(e)
        )
      }
    )

    if (i < total) {
      Sys.sleep(0.35)
    }
  }

  list(
    total = total,
    success = sum(vapply(results, function(r) identical(r$status, "updated"), logical(1))),
    failed = sum(vapply(results, function(r) identical(r$status, "error"), logical(1))),
    not_found = sum(vapply(results, function(r) identical(r$status, "not_found"), logical(1))),
    results = results
  )
}

# Durable verified publication-date backfill (#460). Worker-executed; needs NCBI
# egress (already on the `proxy` network). Opens its own DB connection from
# payload$db_config (mirroring .async_job_run_publication_refresh) and delegates to
# the shared backfill_publication_dates_run(). A benign single-flight skip
# (lock_held) returns successfully; a hard DB failure OR a systemic fetch outage
# (every targeted PMID failed to fetch -> classed publication_backfill_systemic_failure)
# propagates and marks the job failed (observable in job history). A partial fetch
# failure returns success with skipped_count/skipped_pmids/skipped_errors in the summary.
.async_job_run_publication_date_backfill <- function(job, payload, state, worker_config) {
  reporter <- .async_job_progress_reporter(job$job_id[[1]])

  sysndd_db <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = payload$db_config$dbname,
    user = payload$db_config$user,
    password = payload$db_config$password,
    host = payload$db_config$host,
    port = payload$db_config$port
  )
  on.exit(DBI::dbDisconnect(sysndd_db), add = TRUE)

  res <- backfill_publication_dates_run(
    sysndd_db,
    limit = payload$limit,
    dry_run = isTRUE(payload$dry_run),
    progress = function(step, message, current = NULL, total = NULL) {
      reporter(step, message, current = current, total = total)
    }
  )

  list(status = "success", summary = res)
}
