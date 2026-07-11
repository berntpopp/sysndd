# api/functions/async-job-db-config.R
#
# Single source of truth for how a durable async job handler obtains the
# database credentials it needs. The worker holds the same `dw` runtime config
# object the API read `dw$password` from at submit time, so handlers resolve
# credentials HERE at run time instead of receiving them through the job
# payload (which persists in async_jobs.request_payload_json). Introduced for
# #535 P1-1 (backup family); extended to all durable families in S2b.
#
# NOTE: `config::get` masks `base::get` in the loaded API/worker env (its
# signature has no `envir`/`mode` arg), so we look `dw` up with the fully
# qualified `base::exists` / `base::get` against `.GlobalEnv` — never a bare
# `get("dw", ...)`, which would raise `unused argument (envir = ...)`.

#' Resolve DB connection config for a durable worker handler.
#'
#' @param runtime_config Optional injected config list (for tests). When NULL,
#'   the worker/API global `dw` is used.
#' @return list(dbname, host, user, password, port) with `port` a positive
#'   integer. Errors (without echoing any credential value) when the config is
#'   unavailable or a required field is missing/empty.
#' @export
async_job_worker_db_config <- function(runtime_config = NULL) {
  cfg <- runtime_config
  if (is.null(cfg)) {
    if (!base::exists("dw", envir = .GlobalEnv, inherits = FALSE)) {
      stop("async_job_worker_db_config(): 'dw' runtime config unavailable in this process",
           call. = FALSE)
    }
    cfg <- base::get("dw", envir = .GlobalEnv, inherits = FALSE)
  }

  out <- list(
    dbname   = cfg$dbname,
    host     = cfg$host,
    user     = cfg$user,
    password = cfg$password,
    port     = cfg$port
  )

  # Validate required scalar fields WITHOUT echoing any credential value.
  for (field in c("dbname", "host", "user", "password")) {
    value <- out[[field]]
    if (is.null(value) || length(value) != 1L || is.na(value) ||
        !nzchar(as.character(value))) {
      stop(sprintf("async_job_worker_db_config(): missing or empty '%s'", field),
           call. = FALSE)
    }
  }

  port_int <- suppressWarnings(as.integer(out$port))
  if (length(port_int) != 1L || is.na(port_int) || port_int <= 0L) {
    stop("async_job_worker_db_config(): 'port' is not a positive integer", call. = FALSE)
  }
  out$port <- port_int

  out
}
