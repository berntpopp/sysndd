# api/functions/async-job-force-apply-payload.R
#
# Force-apply payload-shape helpers, extracted from async-job-handlers.R to keep
# that oversized file from growing (AGENTS.md soft 600-line ceiling).
#
# These normalize the `auto_fixes` / `critical_entities` tables carried in a
# blocked omim_update job's result into a consistent tibble before the
# force-apply worker reads them. The blocked result builds those tables as
# purrr::transpose() lists of named records, but BOTH
# get_job_status(result_mode = "full") (reading the blocked job's result_json)
# AND the worker (decoding the force-apply payload) parse with
# jsonlite::fromJSON(simplifyVector = TRUE). simplifyVector collapses an array of
# uniform objects into a *data.frame*, so by the time these helpers run the
# table is a data.frame — not the list of records that built it.
#
# The previous helpers iterated with vapply(table, \(x) x$field), which walks a
# data.frame's COLUMNS (atomic vectors); the `x$field` access then crashed the
# force-apply job with "$ operator is invalid for atomic vectors". Accept all
# realistic shapes (data.frame, list-of-records, NULL / empty list) and return a
# uniform tibble so callers can use plain column access.

#' Normalize a force-apply payload table into a tibble.
#'
#' @param x A data.frame, a list of named records (purrr::transpose() shape),
#'   NULL, or an empty list.
#' @return A tibble (possibly zero-row).
.async_job_force_apply_table <- function(x) {
  if (is.null(x) || is.data.frame(x)) {
    return(tibble::as_tibble(x %||% tibble::tibble()))
  }
  if (!is.list(x) || length(x) == 0) {
    return(tibble::tibble())
  }

  rows <- lapply(x, function(rec) {
    if (is.null(rec) || length(rec) == 0) {
      return(NULL)
    }
    tibble::as_tibble(lapply(rec, function(v) if (length(v) == 0) NA else v[[1]]))
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(tibble::tibble())
  }
  dplyr::bind_rows(rows)
}

#' Extract the old/new version remapping table for an auto-fix force-apply.
#'
#' @param auto_fixes_raw The `auto_fixes` field from a blocked job result.
#' @return A tibble with `old_version` / `new_version` character columns.
.async_job_force_apply_auto_fixes <- function(auto_fixes_raw) {
  table <- .async_job_force_apply_table(auto_fixes_raw)
  if (nrow(table) == 0 ||
        !all(c("old_version", "new_version") %in% names(table))) {
    return(tibble::tibble(old_version = character(0), new_version = character(0)))
  }

  tibble::tibble(
    old_version = as.character(table$old_version),
    new_version = as.character(table$new_version)
  )
}

#' Extract the critical disease-ontology version ids from a blocked job result.
#'
#' @param critical_entities_raw The `critical_entities` field from a blocked
#'   job result.
#' @return A character vector of `disease_ontology_id_version` values.
.async_job_force_apply_critical_versions <- function(critical_entities_raw) {
  table <- .async_job_force_apply_table(critical_entities_raw)
  if (nrow(table) == 0 || !"disease_ontology_id_version" %in% names(table)) {
    return(character(0))
  }

  as.character(table$disease_ontology_id_version)
}
