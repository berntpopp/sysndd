# api/functions/ontology-status-service.R
#
# Derives a visible "is the disease dictionary stale / blocked?" signal from
# async job history. Table MAX(update_date) is NOT used as the applied signal,
# because additive auto-apply (#470) stamps new rows with today's date while
# critical staged changes may remain unresolved.

#' Pure derivation of the dictionary status from normalized job records.
#' @keywords internal
#' @export
derive_ontology_dictionary_status <- function(jobs, now, stale_after_days = 30) {
  empty <- list(
    blocked = FALSE, blocked_job_id = NA_character_, stale = FALSE,
    last_full_apply_at = NA, last_additive_apply_at = NA,
    latest_blocked_omim_update_at = NA,
    critical_count = 0L, auto_fixable_count = 0L, additive_applied = 0L
  )
  # Empty-jobs is the safe fallback for two cases: (a) a fresh deploy with no
  # job history yet, and (b) a transient DB/read error in the IO wrapper
  # (ontology_dictionary_status sets jobs <- list() when get_history() errors).
  # In both cases the contract mandates a SAFE payload (blocked = FALSE,
  # stale = FALSE) so the admin page never shows a false-alarm banner.
  # Do NOT change stale to TRUE here — this is intentional error-safe design.
  if (length(jobs) == 0) return(empty)

  ats <- as.POSIXct(vapply(jobs, function(j) as.numeric(j$completed_at), numeric(1)),
                    origin = "1970-01-01", tz = "UTC")
  ord <- order(ats, decreasing = TRUE)
  jobs <- jobs[ord]

  is_full_apply <- function(j) {
    (identical(j$operation, "omim_update") && identical(j$result_status, "success")) ||
      (identical(j$operation, "force_apply_ontology") && identical(j$result_status, "success"))
  }
  pick_at <- function(pred) {
    for (j in jobs) if (isTRUE(pred(j))) return(j$completed_at)
    NA
  }

  fresh_blocked <- Filter(function(j) {
    identical(j$operation, "omim_update") && identical(j$result_status, "blocked") &&
      isTRUE(j$pending_csv_fresh)
  }, jobs)
  any_blocked_at <- pick_at(function(j) {
    identical(j$operation, "omim_update") && identical(j$result_status, "blocked")
  })
  last_full <- pick_at(is_full_apply)

  out <- empty
  out$last_full_apply_at <- last_full
  out$last_additive_apply_at <- pick_at(function(j) {
    identical(j$operation, "omim_update") &&
      isTRUE(as.numeric(j$additive_applied %||% 0) > 0)
  })
  out$latest_blocked_omim_update_at <- any_blocked_at

  if (length(fresh_blocked) > 0) {
    b <- fresh_blocked[[1]]
    out$blocked <- TRUE
    out$blocked_job_id <- b$job_id
    out$critical_count <- as.integer(b$critical_count %||% 0)
    out$auto_fixable_count <- as.integer(b$auto_fixable_count %||% 0)
    out$additive_applied <- as.integer(b$additive_applied %||% 0)
  }

  stale_cut <- now - stale_after_days * 24 * 3600
  out$stale <- out$blocked ||
    (!is.na(any_blocked_at) && (is.na(last_full) || any_blocked_at > last_full)) ||
    is.na(last_full) ||
    (!is.na(last_full) && last_full < stale_cut)

  out
}

#' IO wrapper: build normalized job records from job history + result_json +
#' pending-CSV freshness, then derive the status. Adds DB-derived fields.
#' @export
ontology_dictionary_status <- function(history_limit = 100L,
                                       get_history = get_job_history,
                                       get_status = get_job_status,
                                       now = Sys.time(),
                                       csv_fresh = .ontology_status_csv_fresh,
                                       db_lookup = .ontology_status_db_lookup,
                                       stale_after_days = as.numeric(
                                         Sys.getenv("ONTOLOGY_DICTIONARY_STALE_AFTER_DAYS", "30"))) {
  hist <- tryCatch(get_history(history_limit), error = function(e) NULL)
  jobs <- list()
  if (!is.null(hist) && nrow(hist) > 0) {
    relevant <- hist[hist$operation %in% c("omim_update", "force_apply_ontology") &
                       hist$status == "completed", , drop = FALSE]
    for (i in seq_len(nrow(relevant))) {
      jid <- relevant$job_id[[i]]
      full <- tryCatch(get_status(jid, result_mode = "full"), error = function(e) NULL)
      res <- full$result
      rs <- if (is.list(res)) (res$status[[1]] %||% NA_character_) else NA_character_
      csv_path <- if (is.list(res)) res$pending_csv_path else NULL
      jobs[[length(jobs) + 1]] <- list(
        operation = relevant$operation[[i]],
        job_id = jid,
        completed_at = as.POSIXct(relevant$completed_at[[i]], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        result_status = rs,
        critical_count = if (is.list(res)) res$critical_count else 0,
        auto_fixable_count = if (is.list(res)) res$auto_fixable_count else 0,
        additive_applied = if (is.list(res)) (res$additive_applied %||% 0) else 0,
        pending_csv_fresh = identical(rs, "blocked") && isTRUE(csv_fresh(csv_path, now))
      )
    }
  }

  status <- derive_ontology_dictionary_status(jobs, now, stale_after_days)
  db <- tryCatch(db_lookup(), error = function(e) list(last_applied = NA, max_omim_id = NA))
  status$disease_ontology_last_applied <- db$last_applied
  status$max_omim_id <- db$max_omim_id
  status
}

#' @keywords internal
.ontology_status_csv_fresh <- function(csv_path, now = Sys.time()) {
  if (is.null(csv_path) || length(csv_path) == 0) return(FALSE)
  csv_path <- csv_path[[1]]
  if (is.na(csv_path) || !file.exists(csv_path)) return(FALSE)
  age_h <- as.numeric(difftime(now, file.info(csv_path)$mtime, units = "hours"))
  !is.na(age_h) && age_h <= 48
}

#' @keywords internal
.ontology_status_db_lookup <- function() {
  row <- pool %>%
    dplyr::tbl("disease_ontology_set") %>%
    dplyr::summarise(
      last_applied = max(update_date, na.rm = TRUE),
      max_omim_id = max(disease_ontology_id, na.rm = TRUE)
    ) %>%
    dplyr::collect()
  list(
    last_applied = as.character(row$last_applied[[1]]),
    max_omim_id = as.character(row$max_omim_id[[1]])
  )
}
