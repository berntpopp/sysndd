# functions/clustering-submit-throttle.R
#### Per-caller submit throttle for the public clustering job routes (#535 S6).
#### Extracted from async-job-service.R to keep both files < 600 lines. Loaded
#### right after async-job-service.R in bootstrap/load_modules.R.

# ---------------------------------------------------------------------------
# Per-caller submit throttle (#535 S6 — clustering admission controls)
#
# async_job_capacity_exceeded() bounds the TOTAL in-flight public jobs but lets a
# single caller consume every slot. This adds a per-caller sliding-window submit
# rate limit as a SECOND admission dimension layered on the global cap (it does not
# replace it). It is process-local (in-memory) defense-in-depth: a fresh window per
# API process, so with multiple API replicas each enforces independently while the
# DB-backed global cap remains the cross-process backstop.
# ---------------------------------------------------------------------------

# Parse a positive-ish integer env var, falling back to a safe default on any
# invalid/empty/non-integer value (rather than silently disabling or corrupting the
# limiter, which `as.integer("abc")` -> NA would do).
.async_job_submit_env_int <- function(name, default, min_value) {
  raw <- trimws(Sys.getenv(name, ""))
  if (!nzchar(raw) || !grepl("^-?[0-9]+$", raw)) {
    return(as.integer(default))
  }
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value) || value < min_value) {
    return(as.integer(default))
  }
  value
}

# Max submissions per caller per window, and the window length (seconds). Read once
# at source/startup; changing the env var requires an API restart. MAX accepts an
# explicit 0 (disable); WINDOW must be >= 1.
CLUSTERING_SUBMIT_PER_CALLER_MAX <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_PER_CALLER_MAX", 5L, 0L)
CLUSTERING_SUBMIT_WINDOW_SECONDS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_WINDOW_SECONDS", 60L, 1L)
# Number of trusted reverse-proxy hops in front of the API (Traefik = 1).
CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS", 1L, 1L)
# Hard cap on distinct tracked fingerprints — bounds memory against X-Forwarded-For
# rotation (each spoofed value would otherwise create a permanent 1-entry bucket).
CLUSTERING_SUBMIT_MAX_TRACKED <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_MAX_TRACKED", 20000L, 100L)

# fingerprint -> numeric vector of recent submit epoch-seconds.
.clustering_submit_history <- new.env(parent = emptyenv())

#' Resolve the client fingerprint for submit throttling.
#'
#' Returns the client IP the TRUSTED reverse proxy appended to `X-Forwarded-For`:
#' the entry `trusted_hops` positions from the RIGHT. The proxy appends the address
#' of the peer it actually saw, so that hop is not spoofable; the leftmost XFF
#' entries are client-supplied and an attacker could rotate them to evade the limit
#' (or exhaust memory), so they are never trusted. Falls back to `REMOTE_ADDR` (the
#' proxy's own address in the Compose topology — coarse but unspoofable), then a
#' constant. Assumes exactly `trusted_hops` proxies front the API.
#'
#' @param req Plumber request object.
#' @param trusted_hops Number of trusted proxies in front of the API (default env).
#' @return Character fingerprint (never empty).
#' @export
async_job_submit_fingerprint <- function(req,
                                         trusted_hops = CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS) {
  xff <- req$HTTP_X_FORWARDED_FOR
  if (!is.null(xff) && length(xff) == 1L && nzchar(xff)) {
    parts <- trimws(strsplit(as.character(xff), ",", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    idx <- length(parts) - as.integer(trusted_hops) + 1L
    if (length(parts) > 0L && !is.na(idx) && idx >= 1L && idx <= length(parts)) {
      return(parts[[idx]])
    }
  }
  addr <- req$REMOTE_ADDR
  if (!is.null(addr) && length(addr) == 1L && nzchar(addr)) {
    return(as.character(addr))
  }
  "unknown"
}

#' Bound the throttle store: drop fully-idle fingerprints (all timestamps aged out),
#' then, if still at/over the cap, evict the least-recently-active until under it.
#' Keeps memory O(max_tracked) regardless of X-Forwarded-For rotation.
.async_job_submit_sweep <- function(store, cutoff, max_tracked) {
  keys <- ls(envir = store)
  if (length(keys) < max_tracked) {
    return(invisible(NULL))
  }
  last_seen <- vapply(keys, function(k) {
    ts <- get(k, envir = store, inherits = FALSE)
    if (length(ts) == 0L) -Inf else max(ts)
  }, numeric(1))
  expired <- keys[last_seen <= cutoff]
  if (length(expired) > 0L) {
    rm(list = expired, envir = store)
  }
  remaining <- setdiff(keys, expired)
  if (length(remaining) >= max_tracked) {
    n_evict <- length(remaining) - max_tracked + 1L
    victims <- names(sort(last_seen[remaining]))[seq_len(n_evict)]
    rm(list = victims, envir = store)
  }
  invisible(NULL)
}

#' Sliding-window per-caller submit rate limit.
#'
#' Pure except for the module-level `store`; the clock is injected so tests are
#' deterministic. Records the attempt when allowed. Bounds memory via the sweep.
#'
#' @param fingerprint Caller fingerprint (see async_job_submit_fingerprint()).
#' @param now Current epoch-seconds (injected for tests).
#' @param max_n Max allowed submissions in the window.
#' @param window_s Window length in seconds.
#' @param store Environment mapping fingerprint -> recent timestamps.
#' @param max_tracked Hard cap on distinct tracked fingerprints.
#' @return list(allowed, retry_after, count).
#' @export
async_job_submit_rate_limit <- function(fingerprint,
                                        now = as.numeric(Sys.time()),
                                        max_n = CLUSTERING_SUBMIT_PER_CALLER_MAX,
                                        window_s = CLUSTERING_SUBMIT_WINDOW_SECONDS,
                                        store = .clustering_submit_history,
                                        max_tracked = CLUSTERING_SUBMIT_MAX_TRACKED) {
  if (is.null(fingerprint) || length(fingerprint) != 1L || is.na(fingerprint) || !nzchar(fingerprint)) {
    fingerprint <- "unknown"
  }
  # A non-positive/invalid cap or window disables the limiter (always allow).
  if (is.na(max_n) || max_n <= 0L || is.na(window_s) || window_s <= 0L) {
    return(list(allowed = TRUE, retry_after = 0L, count = 0L))
  }
  cutoff <- now - window_s
  prev <- if (exists(fingerprint, envir = store, inherits = FALSE)) {
    get(fingerprint, envir = store, inherits = FALSE)
  } else {
    numeric(0)
  }
  recent <- prev[prev > cutoff]
  if (length(recent) >= max_n) {
    # The oldest in-window submission ages out at recent[1] + window_s.
    retry_after <- max(1L, as.integer(ceiling((recent[[1]] + window_s) - now)))
    assign(fingerprint, recent, envir = store) # persist the prune
    return(list(allowed = FALSE, retry_after = retry_after, count = length(recent)))
  }
  # Bound memory before recording a (possibly brand-new) allowed fingerprint.
  if (!exists(fingerprint, envir = store, inherits = FALSE)) {
    .async_job_submit_sweep(store, cutoff, max_tracked)
  }
  assign(fingerprint, c(recent, now), envir = store)
  list(allowed = TRUE, retry_after = 0L, count = length(recent) + 1L)
}

#' Reset the in-memory submit-throttle store (tests only).
#' @export
async_job_submit_rate_limit_reset <- function(store = .clustering_submit_history) {
  rm(list = ls(envir = store), envir = store)
  invisible(NULL)
}
