# api/services/admin-diagnostics-endpoint-service.R
#
# Service layer for the Administrator/public diagnostics family (OpenAPI
# spec passthrough, API version, annotation update dates, SMTP connectivity
# test) extracted from api/endpoints/admin_endpoints.R (issue #346, Wave 3).
#
# `svc_admin_openapi_spec()`, `svc_admin_api_version()`, and
# `svc_admin_annotation_dates()` back PUBLIC routes; their behavior/contract
# is unchanged, only relocated. `svc_admin_smtp_test()` backs an
# Administrator-gated route; the `require_role()` gate itself stays inline in
# the endpoint shell.

#' GET /openapi.json body.
#'
#' Returns the already-enhanced OpenAPI spec from the root router. Must call
#' `getApiSpec()` exactly once: `root`'s `pr_set_api_spec` callback already
#' applies `enhance_openapi_spec()`, so re-enhancing here would double-apply
#' it.
#'
#' @param root The root plumber router (global, holds all mounted endpoints).
#' @export
svc_admin_openapi_spec <- function(root) {
  root$getApiSpec()
}

#' GET /admin/api_version body.
#' @export
svc_admin_api_version <- function(version) {
  list(api_version = version)
}

#' GET /admin/annotation_dates body.
#'
#' Prefers job-history completion timestamps over file metadata, falling back
#' to file dates for fresh installs with no job runs yet.
#'
#' @export
svc_admin_annotation_dates <- function(data_dir = "data/",
                                        history_fn = get_job_history) {
  history <- tryCatch(history_fn(100), error = function(e) {
    data.frame(
      operation = character(0),
      status = character(0),
      completed_at = character(0),
      stringsAsFactors = FALSE
    )
  })

  omim_job <- svc_admin_last_successful_run("omim_update", history)
  ontology_job <- svc_admin_last_successful_run(
    c("ontology_update", "force_apply_ontology"), history
  )
  hgnc_job <- svc_admin_last_successful_run("hgnc_update", history)

  null_coalesce <- function(a, b) if (!is.na(a)) a else b

  list(
    omim_update = null_coalesce(
      omim_job, svc_admin_date_from_filename(data_dir, "^mim2gene\\..*\\.txt$")
    ),
    mondo_update = null_coalesce(
      ontology_job, svc_admin_latest_file_date(data_dir, "^mondo")
    ),
    hgnc_update = null_coalesce(
      hgnc_job, svc_admin_latest_file_date(data_dir, "^hgnc|^non_alt_loci")
    ),
    disease_ontology_update = null_coalesce(
      ontology_job,
      svc_admin_date_from_filename(data_dir, "^disease_ontology_set\\..*\\.csv$")
    )
  )
}

#' Most recent `completed_at` for a completed job matching `operations`.
#' @keywords internal
svc_admin_last_successful_run <- function(operations, hist) {
  if (nrow(hist) == 0) return(NA)
  matches <- hist[hist$operation %in% operations & hist$status == "completed", ]
  if (nrow(matches) == 0) return(NA)
  valid <- matches[!is.na(matches$completed_at), ]
  if (nrow(valid) == 0) return(NA)
  sorted <- valid[order(valid$completed_at, decreasing = TRUE), ]
  sorted$completed_at[1]
}

#' Most recent mtime (formatted) among files matching `pattern` in `data_dir`.
#' @keywords internal
svc_admin_latest_file_date <- function(data_dir, pattern) {
  files <- list.files(data_dir, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) return(NA)
  file_info <- file.info(files)
  if (nrow(file_info) == 0) return(NA)
  latest <- files[which.max(file_info$mtime)]
  format(file_info[latest, "mtime"], "%Y-%m-%d %H:%M:%S")
}

#' Latest YYYY-MM-DD token embedded in a filename matching `pattern`.
#' @keywords internal
svc_admin_date_from_filename <- function(data_dir, pattern) {
  files <- list.files(data_dir, pattern = pattern, full.names = FALSE)
  if (length(files) == 0) return(NA)
  dates <- regmatches(files, regexpr("\\d{4}-\\d{2}-\\d{2}", files))
  if (length(dates) == 0) return(NA)
  max(dates)
}

#' GET /admin/smtp/test body.
#'
#' Attempts a raw socket connection to the configured SMTP host/port. Does
#' not send any email.
#'
#' @export
svc_admin_smtp_test <- function(req, res, dw, connect_fn = socketConnection, close_fn = close) {
  smtp_host <- dw$mail_noreply_host
  smtp_port <- as.integer(dw$mail_noreply_port)

  tryCatch(
    {
      con <- connect_fn(
        host = smtp_host,
        port = smtp_port,
        open = "r+",
        blocking = TRUE,
        timeout = 5
      )
      close_fn(con)

      list(success = TRUE, host = smtp_host, port = smtp_port, error = NULL)
    },
    error = function(e) {
      list(success = FALSE, host = smtp_host, port = smtp_port, error = e$message)
    }
  )
}
