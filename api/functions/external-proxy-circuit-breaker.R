# functions/external-proxy-circuit-breaker.R
#
# In-memory circuit breaker for external proxy upstreams (#663).
# Prevents cascading worker stalls when an upstream provider is degraded or down.
#
# States:
#   - CLOSED: Normal operation. Upstream requests are permitted.
#   - OPEN: Upstream is failing. Requests short-circuit immediately with 503.
#   - HALF-OPEN: Cooldown elapsed; a single probe request is permitted to test recovery.

.external_proxy_cb_env <- new.env(parent = emptyenv())

#' Get circuit breaker configuration for an external API
#'
#' @param source Upstream provider name (e.g., "gnomad", "ensembl", "uniprot").
#' @return Named list with `threshold` and `cooldown_seconds`.
#' @noRd
.external_proxy_cb_get_config <- function(source) {
  src_upper <- toupper(as.character(source %||% "DEFAULT")[[1]])
  threshold_env <- Sys.getenv(
    paste0("EXTERNAL_PROXY_CB_", src_upper, "_THRESHOLD"),
    Sys.getenv("EXTERNAL_PROXY_CB_FAILURE_THRESHOLD", "5")
  )
  cooldown_env <- Sys.getenv(
    paste0("EXTERNAL_PROXY_CB_", src_upper, "_COOLDOWN_SECONDS"),
    Sys.getenv("EXTERNAL_PROXY_CB_COOLDOWN_SECONDS", "60")
  )

  threshold <- suppressWarnings(as.integer(threshold_env))
  if (is.na(threshold) || threshold < 1L) threshold <- 5L

  cooldown <- suppressWarnings(as.numeric(cooldown_env))
  if (is.na(cooldown) || cooldown <= 0) cooldown <- 60

  list(threshold = threshold, cooldown_seconds = cooldown)
}

#' Check whether the circuit breaker is OPEN for an external source
#'
#' @param source Upstream provider name.
#' @param now Current POSIXct time (injectable for testing).
#' @return Logical: TRUE if circuit is open (requests should short-circuit), FALSE otherwise.
#' @export
external_proxy_cb_is_open <- function(source, now = Sys.time()) {
  if (is.null(source) || !nzchar(source)) {
    return(FALSE)
  }
  src_key <- tolower(as.character(source)[[1]])
  cb <- .external_proxy_cb_env[[src_key]]
  if (is.null(cb)) {
    return(FALSE)
  }

  if (identical(cb$state, "CLOSED")) {
    return(FALSE)
  }

  cfg <- .external_proxy_cb_get_config(src_key)
  elapsed <- as.numeric(difftime(now, cb$last_failure_time, units = "secs"))

  if (identical(cb$state, "OPEN")) {
    if (elapsed >= cfg$cooldown_seconds) {
      cb$state <- "HALF-OPEN"
      .external_proxy_cb_env[[src_key]] <- cb
      return(FALSE)
    }
    return(TRUE)
  }

  if (identical(cb$state, "HALF-OPEN")) {
    return(TRUE)
  }

  FALSE
}

#' Record an upstream success in the circuit breaker
#'
#' @param source Upstream provider name.
#' @param now Current POSIXct time.
#' @export
external_proxy_cb_record_success <- function(source, now = Sys.time()) {
  if (is.null(source) || !nzchar(source)) return(invisible(NULL))
  src_key <- tolower(as.character(source)[[1]])
  cb <- .external_proxy_cb_env[[src_key]]

  if (!is.null(cb) && !identical(cb$state, "CLOSED")) {
    message(sprintf(
      "[external-proxy] source=%s event=circuit_breaker_recovered state=CLOSED previous_state=%s failures_cleared=%d",
      src_key, cb$state, cb$failure_count
    ))
  }

  .external_proxy_cb_env[[src_key]] <- list(
    state = "CLOSED",
    failure_count = 0L,
    last_success_time = now,
    last_failure_time = if (!is.null(cb)) cb$last_failure_time else NULL
  )
  invisible(NULL)
}

#' Record an upstream failure in the circuit breaker
#'
#' Only 502, 503, 504, 429, timeouts, and network exceptions trip the breaker.
#' Client errors (e.g. 400, 404) do not indicate upstream unhealthiness.
#'
#' @param source Upstream provider name.
#' @param status HTTP status code or integer.
#' @param message Error message details.
#' @param now Current POSIXct time.
#' @export
external_proxy_cb_record_failure <- function(source, status = 503L, message = NULL, now = Sys.time()) {
  if (is.null(source) || !nzchar(source)) return(invisible(NULL))
  src_key <- tolower(as.character(source)[[1]])

  status_int <- suppressWarnings(as.integer(status))
  if (is.na(status_int)) status_int <- 503L

  # Trip breaker only for transient/server errors or timeouts
  should_count <- status_int %in% c(429L, 500L, 502L, 503L, 504L) ||
    (!is.null(message) && grepl("timeout|timed out|refused|reset|unavailable", message, ignore.case = TRUE))

  if (!should_count) {
    return(invisible(NULL))
  }

  cfg <- .external_proxy_cb_get_config(src_key)
  cb <- .external_proxy_cb_env[[src_key]]
  if (is.null(cb)) {
    cb <- list(state = "CLOSED", failure_count = 0L, last_failure_time = now)
  }

  cb$failure_count <- cb$failure_count + 1L
  cb$last_failure_time <- now

  if (identical(cb$state, "HALF-OPEN") || cb$failure_count >= cfg$threshold) {
    old_state <- cb$state
    cb$state <- "OPEN"
    message(sprintf(
      paste0(
        "[external-proxy] source=%s event=circuit_breaker_tripped state=OPEN ",
        "previous_state=%s consecutive_failures=%d threshold=%d cooldown_s=%g"
      ),
      src_key, old_state, cb$failure_count, cfg$threshold, cfg$cooldown_seconds
    ))
  }

  .external_proxy_cb_env[[src_key]] <- cb
  invisible(NULL)
}

#' Get status of all circuit breakers for monitoring
#'
#' @return Named list of circuit breaker statuses.
#' @export
external_proxy_cb_status <- function() {
  res <- list()
  for (src in names(.external_proxy_cb_env)) {
    cb <- .external_proxy_cb_env[[src]]
    cfg <- .external_proxy_cb_get_config(src)
    res[[src]] <- list(
      state = cb$state,
      consecutive_failures = cb$failure_count,
      threshold = cfg$threshold,
      cooldown_seconds = cfg$cooldown_seconds,
      last_failure_time = if (!is.null(cb$last_failure_time)) {
        format(cb$last_failure_time, "%Y-%m-%dT%H:%M:%SZ")
      } else {
        NULL
      },
      last_success_time = if (!is.null(cb$last_success_time)) {
        format(cb$last_success_time, "%Y-%m-%dT%H:%M:%SZ")
      } else {
        NULL
      }
    )
  }
  res
}

#' Alias for external_proxy_cb_status suitable for cheap routes
#' @export
circuit_breaker_status <- external_proxy_cb_status

#' Generate a standardized 503 circuit breaker open response
#'
#' @param source Upstream provider name.
#' @return Named list representing an error response.
#' @export
external_proxy_cb_error <- function(source) {
  src_str <- as.character(source %||% "unknown")[[1]]
  if (exists("external_proxy_log_event", mode = "function")) {
    external_proxy_log_event(
      source = src_str,
      event = "circuit_breaker_short_circuit",
      status = 503L,
      detail = "Circuit breaker OPEN"
    )
  }
  list(
    error = TRUE,
    status = 503L,
    source = src_str,
    message = sprintf("Circuit breaker open for %s", src_str),
    circuit_breaker_open = TRUE
  )
}

#' Reset circuit breaker state (useful for tests)
#'
#' @param source Optional source to reset. If NULL, resets all.
#' @export
external_proxy_cb_reset <- function(source = NULL) {
  if (is.null(source)) {
    rm(list = ls(envir = .external_proxy_cb_env), envir = .external_proxy_cb_env)
  } else {
    src_key <- tolower(as.character(source)[[1]])
    if (exists(src_key, envir = .external_proxy_cb_env)) {
      rm(list = src_key, envir = .external_proxy_cb_env)
    }
  }
  invisible(NULL)
}
