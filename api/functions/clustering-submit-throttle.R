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
# limiter, which `as.integer("abc")` -> NA would do). `max_value` clamps the accepted
# value so an operator typo (e.g. MAX=1000000000) cannot make a per-caller timestamp
# vector grow without bound; a value above the ceiling is clamped, not rejected.
.async_job_submit_env_int <- function(name, default, min_value, max_value = NULL) {
  raw <- trimws(Sys.getenv(name, ""))
  if (!nzchar(raw) || !grepl("^-?[0-9]+$", raw)) {
    return(as.integer(default))
  }
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value) || value < min_value) {
    return(as.integer(default))
  }
  if (!is.null(max_value) && value > max_value) {
    return(as.integer(max_value))
  }
  value
}

# Max submissions per caller per window, and the window length (seconds). Read once
# at source/startup; changing the env var requires an API restart. MAX floors at 1 so
# a stray `=0` (or any invalid value) falls back to the default rather than SILENTLY
# disabling the control; it is clamped to a sane ceiling. WINDOW must be >= 1.
CLUSTERING_SUBMIT_PER_CALLER_MAX <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_PER_CALLER_MAX", 5L, 1L, max_value = 10000L)
CLUSTERING_SUBMIT_WINDOW_SECONDS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_WINDOW_SECONDS", 60L, 1L, max_value = 86400L)
# Number of trusted reverse-proxy hops in front of the API (Traefik = 1). Clamped to
# a small ceiling so a misconfiguration cannot index far into client-supplied XFF.
CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS", 1L, 1L, max_value = 8L)
# Hard cap on distinct tracked fingerprints — bounds memory against X-Forwarded-For
# rotation (each spoofed value would otherwise create a permanent 1-entry bucket).
CLUSTERING_SUBMIT_MAX_TRACKED <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_MAX_TRACKED", 20000L, 100L, max_value = 1000000L)

# fingerprint -> numeric vector of recent submit epoch-seconds.
.clustering_submit_history <- new.env(parent = emptyenv())

#' Validate + canonicalize a candidate client identifier into a bounded throttle
#' key, or return NA when it is not a plausible IP.
#'
#' Rejecting non-IP tokens (e.g. an attacker-injected `X_Forwarded_For` header-alias
#' value colliding with the proxy's `X-Forwarded-For`) stops arbitrary strings from
#' becoming rotating throttle keys that would both evade the limit and exhaust the
#' store. IPv4 is kept verbatim (a `:port` suffix is dropped); IPv6 is grouped to its
#' `/64` network prefix so a single ISP allocation is ONE caller, not 2^64 buckets.
#' The result is always short (bounded key length regardless of input).
#'
#' @param token Candidate identifier (an XFF hop or REMOTE_ADDR).
#' @return Normalized IP/subnet string, or NA_character_ if not a valid IP.
.async_job_submit_normalize_ip <- function(token) {
  if (is.null(token) || length(token) != 1L || is.na(token)) {
    return(NA_character_)
  }
  token <- trimws(as.character(token))
  token <- sub("^\\[(.*)\\]$", "\\1", token) # [::1]:port already portless -> ::1
  if (!nzchar(token) || nchar(token) > 64L) {
    return(NA_character_)
  }
  # IPv4, optionally with a :port we drop: four 0-255 octets.
  ipv4 <- sub(":[0-9]+$", "", token)
  if (grepl("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", ipv4)) {
    octets <- suppressWarnings(as.integer(strsplit(ipv4, ".", fixed = TRUE)[[1]]))
    if (!anyNA(octets) && all(octets >= 0L & octets <= 255L)) {
      return(ipv4)
    }
    return(NA_character_)
  }
  # IPv6 (hex + colons only): group to the /64 network prefix (the first 4 hextets)
  # so a whole ISP allocation is one bucket. The /64 prefix lives in the part BEFORE
  # any "::" compression (real client addresses compress the low interface bits), so
  # padding a short left part with zeros only ever OVER-groups (stricter throttle),
  # never under-groups (which would be the bypass).
  if (grepl(":", token, fixed = TRUE) && grepl("^[0-9a-fA-F:]+$", token)) {
    low <- tolower(token)
    compressed <- grepl("::", low, fixed = TRUE)
    left <- if (compressed) sub("::.*$", "", low) else low
    groups <- strsplit(left, ":", fixed = TRUE)[[1]]
    groups <- groups[nzchar(groups)]
    if (length(groups) >= 4L) {
      prefix <- groups[1:4]
    } else if (compressed) {
      prefix <- c(groups, rep("0", 4L - length(groups)))
    } else {
      return(low) # uncompressed but < 4 hextets -> malformed; keep bounded value.
    }
    return(paste0(paste(prefix, collapse = ":"), "::/64"))
  }
  NA_character_
}

#' Resolve the client fingerprint for submit throttling.
#'
#' Returns the client IP the TRUSTED reverse proxy appended to `X-Forwarded-For`:
#' the entry `trusted_hops` positions from the RIGHT. The proxy appends the address
#' of the peer it actually saw, so that hop is not spoofable; the leftmost XFF
#' entries are client-supplied and an attacker could rotate them to evade the limit
#' (or exhaust memory), so they are never trusted. The selected value must validate
#' as an IP (`.async_job_submit_normalize_ip()`); a non-IP token (header-alias
#' injection, junk) is discarded rather than trusted. Falls back to a validated
#' `REMOTE_ADDR` (the proxy's own address in the Compose topology — coarse but
#' unspoofable), then a constant. Never throws: crafted headers degrade to the
#' `"unknown"` bucket, they cannot fail the request. Assumes exactly `trusted_hops`
#' proxies front the API.
#'
#' @param req Plumber request object.
#' @param trusted_hops Number of trusted proxies in front of the API (default env).
#' @return Character fingerprint (never empty).
#' @export
async_job_submit_fingerprint <- function(req,
                                         trusted_hops = CLUSTERING_SUBMIT_TRUSTED_PROXY_HOPS) {
  candidate <- NA_character_
  xff <- tryCatch(req$HTTP_X_FORWARDED_FOR, error = function(e) NULL)
  if (!is.null(xff) && length(xff) == 1L && nzchar(xff)) {
    parts <- trimws(strsplit(as.character(xff), ",", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    idx <- length(parts) - as.integer(trusted_hops) + 1L
    if (length(parts) > 0L && !is.na(idx) && idx >= 1L && idx <= length(parts)) {
      candidate <- .async_job_submit_normalize_ip(parts[[idx]])
    }
  }
  if (!is.na(candidate)) {
    return(candidate)
  }
  addr <- .async_job_submit_normalize_ip(tryCatch(req$REMOTE_ADDR, error = function(e) NULL))
  if (!is.na(addr)) {
    return(addr)
  }
  "unknown"
}

# Reserved store keys (control-char prefix -> never a valid IP / "unknown", so they
# cannot collide with a real fingerprint). The overflow bucket collectively throttles
# brand-new callers once the store is saturated with ACTIVE callers; the sweep marker
# time-gates the reclaim scan.
.CLUSTERING_SUBMIT_OVERFLOW_KEY <- "\001overflow"
.CLUSTERING_SUBMIT_SWEEP_KEY <- "\001sweep_at"

# Number of tracked fingerprint buckets (excludes the sweep marker). Uses
# `length(env)` — O(bindings), with no name sort or character-vector allocation
# (unlike `ls()`), so it is cheap even under a rotation flood.
.async_job_submit_size <- function(store) {
  n <- length(store)
  if (base::exists(.CLUSTERING_SUBMIT_SWEEP_KEY, envir = store, inherits = FALSE)) n - 1L else n
}

#' Reclaim store space by dropping ONLY fully-idle fingerprints (every timestamp aged
#' out) — an active caller's window is never evicted. Sort-free (`names()`, not the
#' sorting `ls()`), and time-gated to at most once per window so a rotation flood
#' cannot force an O(n) scan on every request.
.async_job_submit_reclaim <- function(store, cutoff, now, window_s) {
  sweep_at <- if (base::exists(.CLUSTERING_SUBMIT_SWEEP_KEY, envir = store, inherits = FALSE)) {
    base::get(.CLUSTERING_SUBMIT_SWEEP_KEY, envir = store, inherits = FALSE)
  } else {
    -Inf
  }
  if ((now - sweep_at) < window_s) {
    return(invisible(NULL))
  }
  keys <- names(store)
  keys <- keys[keys != .CLUSTERING_SUBMIT_SWEEP_KEY]
  for (k in keys) {
    ts <- base::get(k, envir = store, inherits = FALSE)
    if (length(ts) == 0L || max(ts) <= cutoff) {
      rm(list = k, envir = store)
    }
  }
  assign(.CLUSTERING_SUBMIT_SWEEP_KEY, now, envir = store)
  invisible(NULL)
}

#' Sliding-window per-caller submit rate limit.
#'
#' Pure except for the module-level `store`; the clock is injected so tests are
#' deterministic. Records the attempt when allowed. Memory is bounded at `max_tracked`
#' fingerprints: once the store is saturated with ACTIVE callers, a brand-new
#' fingerprint is routed into a single shared overflow bucket (collectively throttled)
#' rather than evicting a legitimate caller's window — so an attacker rotating
#' X-Forwarded-For values can neither exhaust memory nor reset an innocent caller.
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
  # A non-positive/invalid cap or window disables the limiter (always allow). Not
  # reachable via env (the parser floors MAX at 1); only an explicit code caller.
  if (is.na(max_n) || max_n <= 0L || is.na(window_s) || window_s <= 0L) {
    return(list(allowed = TRUE, retry_after = 0L, count = 0L))
  }
  cutoff <- now - window_s
  # Bound the store BEFORE recording a brand-new fingerprint.
  if (!base::exists(fingerprint, envir = store, inherits = FALSE) &&
        .async_job_submit_size(store) >= max_tracked) {
    .async_job_submit_reclaim(store, cutoff, now, window_s)
    if (.async_job_submit_size(store) >= max_tracked) {
      fingerprint <- .CLUSTERING_SUBMIT_OVERFLOW_KEY # saturated -> shared bucket
    }
  }
  prev <- if (base::exists(fingerprint, envir = store, inherits = FALSE)) {
    base::get(fingerprint, envir = store, inherits = FALSE)
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
  assign(fingerprint, c(recent, now), envir = store)
  list(allowed = TRUE, retry_after = 0L, count = length(recent) + 1L)
}

#' Admission guard for the public clustering submit routes.
#'
#' The single entry point both submit services call FIRST (before any DB/cache/
#' duplicate work) so an abusive caller is rejected before it can do — or provoke —
#' any expensive work. Derives the caller fingerprint, applies the per-caller
#' throttle, and translates the decision to an HTTP response on `res`:
#'   * allowed  -> `list(admitted = TRUE)` (caller proceeds)
#'   * throttled-> `429` + `Retry-After`, `error = "RATE_LIMITED"`
#'   * internal error -> **fail CLOSED** `503` + `Retry-After`,
#'     `error = "THROTTLE_UNAVAILABLE"` (a throttle bug must neither 500 the
#'     endpoint nor silently admit an abusive caller).
#'
#' @param req Plumber request.
#' @param res Plumber response (mutated in place on a block).
#' @return list(admitted = TRUE) or list(admitted = FALSE, response = <payload>).
#' @export
# Emit the fail-closed 503 on a fresh `res`. Kept as one non-throwing helper so every
# error/malformed-decision path routes through exactly one place.
.async_job_submit_unavailable <- function(res) {
  res$status <- 503L
  res$setHeader("Retry-After", "5")
  list(admitted = FALSE, response = list(
    error = "THROTTLE_UNAVAILABLE",
    message = "Submission throttling is temporarily unavailable. Please retry shortly.",
    retry_after = 5L
  ))
}

async_job_submit_admission_guard <- function(req, res) {
  decision <- tryCatch(
    async_job_submit_rate_limit(async_job_submit_fingerprint(req)),
    error = function(e) {
      # Logging must never itself fail the request (log_warn may be absent in a
      # library-light env, or a glue interpolation could throw) -> swallow it.
      try(
        if (base::exists("log_warn", mode = "function")) {
          log_warn("clustering submit throttle failed (fail-closed 503): {conditionMessage(e)}")
        },
        silent = TRUE
      )
      NULL
    }
  )
  # Fail CLOSED on a NULL OR malformed decision (schema-validate before use, so a bad
  # shape can never reach setHeader() with an invalid value and 500 the endpoint).
  valid <- is.list(decision) &&
    length(decision$allowed) == 1L && is.logical(decision$allowed) && !is.na(decision$allowed)
  if (!valid) {
    return(.async_job_submit_unavailable(res))
  }
  if (!isTRUE(decision$allowed)) {
    retry_after <- suppressWarnings(as.integer(decision$retry_after))
    if (length(retry_after) != 1L || is.na(retry_after) || retry_after < 1L) {
      retry_after <- 1L
    }
    res$status <- 429L
    res$setHeader("Retry-After", as.character(retry_after))
    return(list(admitted = FALSE, response = list(
      error = "RATE_LIMITED",
      message = "Too many analysis submissions from your client. Please retry shortly.",
      retry_after = retry_after
    )))
  }
  list(admitted = TRUE)
}

#' Reset the in-memory submit-throttle store (tests only).
#' @export
async_job_submit_rate_limit_reset <- function(store = .clustering_submit_history) {
  rm(list = ls(envir = store, all.names = TRUE), envir = store)
  invisible(NULL)
}
