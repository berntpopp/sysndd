# functions/external-proxy-request-state.R
#
# Per-request external-time accounting + synchronous API lane identity (#344).
#
# Extracted from external-proxy-functions.R to keep that file under the 600-line
# ceiling. This is a distinct concern from the fetch/cache/HTTP machinery: it is
# the request-scoped budgeting state (reset in the preroute hook, incremented by
# the universal proxy wrappers) plus the core/enrichment lane identity used to
# gate startup bootstraps and label request-timing logs.
#
# Sourced by load_modules.R (API + durable worker) and setup_workers.R (mirai)
# BEFORE external-proxy-functions.R, which also guard-sources it so direct-source
# unit tests get these helpers transparently.

# --- Request-scoped external-time accumulator + ceiling (#344) ----------------
# Plumber serves one request at a time per process, so a single module-level
# environment is sufficient (no request-id keying). The preroute hook resets it;
# the two universal proxy wrappers (`memoise_external_success_only` and
# `external_proxy_with_timing`) increment it and short-circuit once the per-request
# ceiling is exceeded, so even single-endpoint external paths (not just the
# multi-source aggregator) cannot occupy a worker for tens of seconds.
external_proxy_request_state <- new.env(parent = emptyenv())
external_proxy_request_state$external_ms <- 0

#' Reset the per-request external-time accumulator (call in the preroute hook).
#' @noRd
external_proxy_request_reset <- function() {
  external_proxy_request_state$external_ms <- 0
  invisible(NULL)
}

#' Add elapsed external time (ms) to the current request total.
#' @noRd
external_proxy_request_add <- function(ms) {
  cur <- external_proxy_request_state$external_ms %||% 0
  external_proxy_request_state$external_ms <- cur + as.numeric(ms %||% 0)
  invisible(NULL)
}

#' Total external time (ms) spent in the current request.
#' @noRd
external_proxy_request_total_ms <- function() {
  external_proxy_request_state$external_ms %||% 0
}

#' Per-request external-time ceiling in ms (env `EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, default 15s).
#' @noRd
external_proxy_request_ceiling_ms <- function() {
  secs <- as.numeric(Sys.getenv("EXTERNAL_PROXY_REQUEST_MAX_SECONDS", "15"))
  if (is.na(secs) || secs <= 0) 15000 else secs * 1000
}

#' TRUE once accumulated external time meets/exceeds the per-request ceiling.
#' @noRd
external_proxy_request_ceiling_exceeded <- function() {
  external_proxy_request_total_ms() >= external_proxy_request_ceiling_ms()
}

#' Would this request cross its external-time ceiling if it spent `pending_ms`
#' more? Lets a multi-call fetcher skip a subsequent best-effort upstream call
#' instead of driving one request through several full provider budgets (#344).
#'
#' Unlike `external_proxy_request_ceiling_exceeded()`, this counts just-elapsed
#' time the wrapping `external_proxy_with_timing()` has not yet accumulated (it
#' adds only after its closure returns).
#'
#' @param pending_ms Milliseconds already spent on the current in-flight call
#'   that are not yet reflected in the accumulator.
#' @return TRUE if `accumulated + pending_ms >= ceiling`.
#' @noRd
external_proxy_request_would_exceed <- function(pending_ms = 0) {
  (external_proxy_request_total_ms() + pending_ms) >= external_proxy_request_ceiling_ms()
}

#' Degraded 503 envelope returned when the per-request external ceiling is hit.
#' @noRd
external_proxy_request_budget_error <- function(source) {
  external_proxy_log_event(
    source = source %||% "external",
    event = "request_budget_exceeded",
    status = 503L
  )
  list(
    error = TRUE,
    status = 503L,
    source = source %||% "external",
    message = "external request budget exceeded for this request",
    request_budget_exceeded = TRUE
  )
}

# --- Synchronous API lane identity (#344) -------------------------------------

#' Which synchronous API lane this process serves (#344).
#'
#' The core lane serves cheap/own-data routes; the enrichment lane serves
#' `/api/external/*` only (Traefik-routed). Lane identity gates startup
#' bootstraps (only the core lane owns them) and labels request-timing logs.
#'
#' @return "core" (default) or "enrichment", lowercased from the API_LANE env.
#' @export
api_lane <- function() {
  lane <- tolower(trimws(Sys.getenv("API_LANE", "core")))
  if (identical(lane, "enrichment")) "enrichment" else "core"
}

#' @rdname api_lane
#' @export
api_lane_is_enrichment <- function() identical(api_lane(), "enrichment")
