# Per-caller admission throttle for public authentication endpoints (#550).
#
# The generic mechanisms are intentionally shared with the S6 clustering throttle;
# this file supplies an independent auth policy/store so one route class cannot
# consume another class's caller quota.

AUTH_ENDPOINT_PER_CALLER_MAX <-
  per_caller_throttle_env_int("AUTH_ENDPOINT_PER_CALLER_MAX", 5L, 1L, max_value = 1000L)
AUTH_ENDPOINT_WINDOW_SECONDS <-
  per_caller_throttle_env_int("AUTH_ENDPOINT_WINDOW_SECONDS", 60L, 5L, max_value = 86400L)
AUTH_ENDPOINT_MAX_ENTRIES <- 2000000L
AUTH_ENDPOINT_MAX_TRACKED <- min(
  per_caller_throttle_env_int("AUTH_ENDPOINT_MAX_TRACKED", 20000L, 100L, max_value = 200000L),
  as.integer(AUTH_ENDPOINT_MAX_ENTRIES %/% AUTH_ENDPOINT_PER_CALLER_MAX)
)
AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS <- per_caller_throttle_parse_trusted_cidrs(
  Sys.getenv("AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS", ""),
  "AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS"
)

.auth_endpoint_throttle_history <- new.env(parent = emptyenv())

auth_endpoint_rate_limit <- function(fingerprint, now = as.numeric(Sys.time()),
                                     max_n = AUTH_ENDPOINT_PER_CALLER_MAX,
                                     window_s = AUTH_ENDPOINT_WINDOW_SECONDS,
                                     store = .auth_endpoint_throttle_history,
                                     max_tracked = AUTH_ENDPOINT_MAX_TRACKED) {
  per_caller_rate_limit(fingerprint, now, max_n, window_s, store, max_tracked)
}

#' Admit a public auth request before body parsing, DB access, password work, or email.
#'
#' The response is deliberately generic: it contains no credentials, email address,
#' raw body, query string, or client fingerprint.
auth_endpoint_admission_guard <- function(req, res) {
  per_caller_admission_guard(
    req = req,
    res = res,
    rate_limit = function(fingerprint) auth_endpoint_rate_limit(fingerprint),
    fingerprint = function(request) {
      per_caller_throttle_fingerprint(
        request,
        trusted_cidrs = AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS
      )
    },
    rate_limit_message = "Too many authentication requests from your client. Please retry shortly.",
    unavailable_message = "Authentication throttling is temporarily unavailable. Please retry shortly.",
    on_error = function(error) {
      per_caller_throttle_warn("Authentication throttle failed; request denied with 503.")
    }
  )
}

auth_endpoint_rate_limit_reset <- function(store = .auth_endpoint_throttle_history) {
  per_caller_rate_limit_reset(store)
}
