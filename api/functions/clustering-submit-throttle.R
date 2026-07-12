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
  .async_job_submit_env_int("CLUSTERING_SUBMIT_PER_CALLER_MAX", 5L, 1L, max_value = 1000L)
# WINDOW floors at 5s (a 1s window would let a tiny MAX sustain a high rate) and caps
# at a day.
CLUSTERING_SUBMIT_WINDOW_SECONDS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_WINDOW_SECONDS", 60L, 5L, max_value = 86400L)
# Trusted reverse-proxy source CIDRs (comma-separated; IPv4 CIDR or exact IP). The
# fingerprint walks X-Forwarded-For right-to-left and selects the first address NOT in
# this set — the address our nearest proxy appended, which is non-spoofable. Empty
# (the default, single-Traefik direct-edge topology) trusts nothing upstream, so the
# rightmost (Traefik-appended) hop is used. Set it to the front-proxy CIDR(s) only when
# an additional trusted proxy sits in front of Traefik.
CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS <- local({
  raw <- trimws(Sys.getenv("CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS", ""))
  if (!nzchar(raw)) {
    character(0)
  } else {
    parts <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
    parts[nzchar(parts)]
  }
})
# Hard cap on distinct tracked fingerprints — bounds memory against X-Forwarded-For
# rotation (each spoofed value would otherwise create a permanent 1-entry bucket).
CLUSTERING_SUBMIT_MAX_TRACKED <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_MAX_TRACKED", 20000L, 100L, max_value = 200000L)

# fingerprint -> numeric vector of recent submit epoch-seconds.
.clustering_submit_history <- new.env(parent = emptyenv())

# Dotted IPv4 -> numeric (0..2^32-1), or NA for anything else (incl. IPv6).
.async_job_submit_ipv4_num <- function(ip) {
  m <- regmatches(ip, regexec("^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$", ip))[[1]]
  if (length(m) != 5L) {
    return(NA_real_)
  }
  o <- as.numeric(m[2:5])
  if (any(o < 0 | o > 255)) {
    return(NA_real_)
  }
  o[[1]] * 16777216 + o[[2]] * 65536 + o[[3]] * 256 + o[[4]]
}

# Expand an IPv6 string to its eight integer hextets (0..65535), or NULL when invalid
# (bad hextet, wrong group count, >1 or malformed "::"). Fully expands "::" to the
# exact zero run so the SAME address in any compression yields identical hextets.
.async_job_submit_ipv6_hextets <- function(token) {
  low <- tolower(token)
  if (!grepl(":", low, fixed = TRUE) || !grepl("^[0-9a-f:]+$", low) ||
        grepl(":::", low, fixed = TRUE)) {
    return(NULL)
  }
  dbl <- gregexpr("::", low, fixed = TRUE)[[1]]
  if (length(dbl) == 1L && dbl[[1]] != -1L) {
    left <- sub("::.*$", "", low)
    right <- sub("^.*::", "", low)
    lg <- if (nzchar(left)) strsplit(left, ":", fixed = TRUE)[[1]] else character(0)
    rg <- if (nzchar(right)) strsplit(right, ":", fixed = TRUE)[[1]] else character(0)
    zeros <- 8L - length(lg) - length(rg)
    if (zeros < 1L) {
      return(NULL)
    }
    groups <- c(lg, rep("0", zeros), rg)
  } else if (length(dbl) == 1L && dbl[[1]] == -1L) {
    groups <- strsplit(low, ":", fixed = TRUE)[[1]]
  } else {
    return(NULL)
  }
  if (length(groups) != 8L || !all(grepl("^[0-9a-f]{1,4}$", groups))) {
    return(NULL)
  }
  strtoi(groups, base = 16L)
}

#' Classify a candidate client identifier into (family, canonical full IP, bucket key),
#' or family = NA when it is not a plausible IP.
#'
#' Rejecting non-IP tokens (an attacker-injected `X_Forwarded_For` header-alias value,
#' junk) stops arbitrary strings from becoming rotating throttle keys. `canonical` is
#' the FULL address (used for trusted-proxy matching); `key` is the bucket key: the bare
#' IPv4, or the IPv6 `/64` prefix so a whole allocation is ONE caller. `/64` grouping is
#' applied ONLY to the key, never to the trust check — so an IPv6 trusted proxy still
#' matches its configured CIDR/address.
#'
#' @param token Candidate identifier (an XFF hop or REMOTE_ADDR).
#' @return list(family = "v4"/"v6"/NA, canonical, key).
.async_job_submit_ip_classify <- function(token) {
  na <- list(family = NA_character_, canonical = NA_character_, key = NA_character_)
  if (is.null(token) || length(token) != 1L || is.na(token)) {
    return(na)
  }
  token <- trimws(as.character(token))
  token <- sub("^\\[(.*)\\]$", "\\1", token) # [::1]:port already portless -> ::1
  if (!nzchar(token) || nchar(token) > 64L) {
    return(na)
  }
  ipv4 <- sub(":[0-9]+$", "", token) # IPv4 may carry a :port we drop
  if (grepl("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", ipv4)) {
    octets <- suppressWarnings(as.integer(strsplit(ipv4, ".", fixed = TRUE)[[1]]))
    if (!anyNA(octets) && all(octets >= 0L & octets <= 255L)) {
      return(list(family = "v4", canonical = ipv4, key = ipv4))
    }
    return(na)
  }
  hex <- .async_job_submit_ipv6_hextets(token)
  if (!is.null(hex)) {
    hx <- sprintf("%x", hex) # canonical hextets, leading zeros stripped
    return(list(
      family = "v6",
      canonical = paste(hx, collapse = ":"),
      key = paste0(paste(hx[1:4], collapse = ":"), "::/64")
    ))
  }
  na
}

#' Bucket key for a candidate identifier (bare IPv4 / IPv6 `/64`), or NA if not an IP.
.async_job_submit_normalize_ip <- function(token) {
  .async_job_submit_ip_classify(token)$key
}

# TRUE when the IPv4 `ip` matches CIDR `c` (`a.b.c.d/n`) or an exact IPv4. Prefix compare
# uses integer division on the 32-bit value (no bitwAnd -> no 2^31 overflow).
.async_job_submit_v4_match <- function(ip, c) {
  ip_num <- .async_job_submit_ipv4_num(ip)
  if (is.na(ip_num)) {
    return(FALSE)
  }
  if (grepl("/", c, fixed = TRUE)) {
    seg <- strsplit(c, "/", fixed = TRUE)[[1]]
    if (length(seg) != 2L) {
      return(FALSE)
    }
    bits <- suppressWarnings(as.integer(seg[[2]]))
    net <- .async_job_submit_ipv4_num(seg[[1]])
    if (is.na(bits) || bits < 0L || bits > 32L || is.na(net)) {
      return(FALSE)
    }
    shift <- 2^(32 - bits)
    return(floor(ip_num / shift) == floor(net / shift))
  }
  identical(.async_job_submit_ipv4_num(c), ip_num)
}

# TRUE when the IPv6 `ip_canonical` matches CIDR `c` (`.../n`, 0..128) or an exact IPv6.
# Compares full hextets, then the boundary hextet under a mask (values <=65535, so no
# bitwAnd overflow).
.async_job_submit_v6_match <- function(ip_canonical, c) {
  ih <- .async_job_submit_ipv6_hextets(ip_canonical)
  if (is.null(ih)) {
    return(FALSE)
  }
  if (grepl("/", c, fixed = TRUE)) {
    seg <- strsplit(c, "/", fixed = TRUE)[[1]]
    if (length(seg) != 2L) {
      return(FALSE)
    }
    bits <- suppressWarnings(as.integer(seg[[2]]))
    nh <- .async_job_submit_ipv6_hextets(seg[[1]])
    if (is.na(bits) || bits < 0L || bits > 128L || is.null(nh)) {
      return(FALSE)
    }
    full <- bits %/% 16L
    rem <- bits %% 16L
    if (full > 0L && !all(ih[seq_len(full)] == nh[seq_len(full)])) {
      return(FALSE)
    }
    if (rem > 0L) {
      mask <- 65536L - as.integer(2^(16L - rem))
      if (bitwAnd(ih[[full + 1L]], mask) != bitwAnd(nh[[full + 1L]], mask)) {
        return(FALSE)
      }
    }
    return(TRUE)
  }
  nh <- .async_job_submit_ipv6_hextets(c)
  !is.null(nh) && all(ih == nh)
}

# TRUE when the classified candidate (family + canonical full IP) is inside one of the
# trusted-proxy `cidrs`. IPv4 candidates match only IPv4 CIDRs/addresses and IPv6 only
# IPv6 — evaluated on the CANONICAL address, never the /64 bucket key.
.async_job_submit_ip_trusted <- function(family, canonical, cidrs) {
  if (length(cidrs) == 0L || is.null(family) || is.na(family)) {
    return(FALSE)
  }
  for (c in cidrs) {
    c <- trimws(c)
    cidr_is_v6 <- grepl(":", c, fixed = TRUE)
    if (family == "v4" && !cidr_is_v6 && .async_job_submit_v4_match(canonical, c)) {
      return(TRUE)
    }
    if (family == "v6" && cidr_is_v6 && .async_job_submit_v6_match(canonical, c)) {
      return(TRUE)
    }
  }
  FALSE
}

# TRUE when `c` is a syntactically valid IPv4/IPv6 CIDR or exact address.
.async_job_submit_valid_cidr <- function(c) {
  c <- trimws(c)
  if (grepl(":", c, fixed = TRUE)) {
    if (grepl("/", c, fixed = TRUE)) {
      seg <- strsplit(c, "/", fixed = TRUE)[[1]]
      bits <- if (length(seg) == 2L) suppressWarnings(as.integer(seg[[2]])) else NA_integer_
      return(!is.na(bits) && bits >= 0L && bits <= 128L &&
               !is.null(.async_job_submit_ipv6_hextets(seg[[1]])))
    }
    return(!is.null(.async_job_submit_ipv6_hextets(c)))
  }
  if (grepl("/", c, fixed = TRUE)) {
    seg <- strsplit(c, "/", fixed = TRUE)[[1]]
    bits <- if (length(seg) == 2L) suppressWarnings(as.integer(seg[[2]])) else NA_integer_
    return(!is.na(bits) && bits >= 0L && bits <= 32L && !is.na(.async_job_submit_ipv4_num(seg[[1]])))
  }
  !is.na(.async_job_submit_ipv4_num(c))
}

# Surface (but do not fail boot on) malformed trusted-proxy CIDRs: an invalid entry
# simply never matches (safe — it trusts nothing), so log it for visibility.
local({
  bad <- Filter(function(c) !.async_job_submit_valid_cidr(c), CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS)
  if (length(bad) > 0L && base::exists("log_warn", mode = "function")) {
    log_warn(paste0(
      "CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS has invalid entries (ignored): ",
      paste(bad, collapse = ", ")
    ))
  }
})

#' Resolve the client fingerprint for submit throttling.
#'
#' Walks `X-Forwarded-For` RIGHT-TO-LEFT and returns the first address that is NOT a
#' known trusted proxy (`CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS`). Our nearest proxy
#' appends the address of the peer it actually saw at the RIGHT, so the first untrusted
#' address from the right is the real client and is NOT spoofable: an attacker can put
#' anything in the leftmost entries, but the rightmost hop it cannot forge is the peer
#' our proxy observed. With the default empty trust set (single-Traefik direct edge)
#' this is simply the rightmost hop. Each candidate must validate as an IP
#' (`.async_job_submit_normalize_ip()`); non-IP tokens (header-alias injection, junk)
#' are skipped. Falls back to a validated `REMOTE_ADDR`, then a constant. Never throws:
#' crafted headers degrade to the `"unknown"` bucket, they cannot fail the request.
#'
#' @param req Plumber request object.
#' @param trusted_cidrs Trusted reverse-proxy source CIDRs (default env).
#' @return Character fingerprint (never empty).
#' @export
async_job_submit_fingerprint <- function(req,
                                         trusted_cidrs = CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS) {
  xff <- tryCatch(req$HTTP_X_FORWARDED_FOR, error = function(e) NULL)
  if (!is.null(xff) && length(xff) == 1L && nzchar(xff)) {
    parts <- trimws(strsplit(as.character(xff), ",", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    for (i in rev(seq_along(parts))) {
      p <- .async_job_submit_ip_classify(parts[[i]])
      if (is.na(p$family)) next                                        # non-IP -> ignore
      if (.async_job_submit_ip_trusted(p$family, p$canonical, trusted_cidrs)) next # our proxy
      return(p$key)                                                    # first untrusted from right
    }
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
# time-gates the reclaim scan; the count marker holds the O(1) tracked-bucket count.
.CLUSTERING_SUBMIT_OVERFLOW_KEY <- "\001overflow"
.CLUSTERING_SUBMIT_SWEEP_KEY <- "\001sweep_at"
.CLUSTERING_SUBMIT_COUNT_KEY <- "\001count"

# O(1) tracked-caller count (real fingerprints, EXCLUDING the shared overflow and the
# reserved markers). Maintained on insert/reclaim so the hot path never scans the env.
.async_job_submit_size <- function(store) {
  if (base::exists(.CLUSTERING_SUBMIT_COUNT_KEY, envir = store, inherits = FALSE)) {
    base::get(.CLUSTERING_SUBMIT_COUNT_KEY, envir = store, inherits = FALSE)
  } else {
    0L
  }
}

.async_job_submit_size_add <- function(store, delta) {
  assign(.CLUSTERING_SUBMIT_COUNT_KEY, .async_job_submit_size(store) + as.integer(delta), envir = store)
}

#' Reclaim store space by dropping ONLY fully-idle fingerprints (every timestamp aged
#' out) — an active caller's window is never evicted. Sort-free (`names()`, not the
#' sorting `ls()`), and time-gated to at most once per window so a rotation flood
#' cannot force an O(n) scan on every request. Keeps the O(1) counter in sync.
.async_job_submit_reclaim <- function(store, cutoff, now, window_s) {
  sweep_at <- if (base::exists(.CLUSTERING_SUBMIT_SWEEP_KEY, envir = store, inherits = FALSE)) {
    base::get(.CLUSTERING_SUBMIT_SWEEP_KEY, envir = store, inherits = FALSE)
  } else {
    -Inf
  }
  if ((now - sweep_at) < window_s) {
    return(invisible(NULL))
  }
  reserved <- c(.CLUSTERING_SUBMIT_SWEEP_KEY, .CLUSTERING_SUBMIT_COUNT_KEY)
  keys <- setdiff(names(store), reserved)
  removed_real <- 0L
  for (k in keys) {
    ts <- base::get(k, envir = store, inherits = FALSE)
    if (length(ts) == 0L || max(ts) <= cutoff) {
      rm(list = k, envir = store)
      if (!identical(k, .CLUSTERING_SUBMIT_OVERFLOW_KEY)) {
        removed_real <- removed_real + 1L
      }
    }
  }
  assign(.CLUSTERING_SUBMIT_SWEEP_KEY, now, envir = store)
  if (removed_real > 0L) {
    .async_job_submit_size_add(store, -removed_real)
  }
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
#' Invalid `max_n`/`window_s` FAIL CLOSED (`stop()`): the admission guard maps the
#' error to a 503, so an internal misconfiguration can never silently admit.
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
  # Invalid limiter parameters are an internal error, not a disable switch: fail CLOSED
  # so the admission guard returns 503 THROTTLE_UNAVAILABLE rather than silently admit.
  if (length(max_n) != 1L || !is.finite(max_n) || max_n < 1L ||
        length(window_s) != 1L || !is.finite(window_s) || window_s < 1L) {
    stop("clustering submit throttle misconfigured: max_n and window_s must be finite and >= 1")
  }
  cutoff <- now - window_s
  is_new <- !base::exists(fingerprint, envir = store, inherits = FALSE)
  # Bound the store BEFORE recording a brand-new fingerprint.
  if (is_new && .async_job_submit_size(store) >= max_tracked) {
    .async_job_submit_reclaim(store, cutoff, now, window_s)
    if (.async_job_submit_size(store) >= max_tracked) {
      fingerprint <- .CLUSTERING_SUBMIT_OVERFLOW_KEY # saturated -> shared bucket
      is_new <- !base::exists(fingerprint, envir = store, inherits = FALSE)
    }
  }
  prev <- if (!is_new) {
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
  # Count only real distinct callers (never the shared overflow) toward the bound.
  if (is_new && !identical(fingerprint, .CLUSTERING_SUBMIT_OVERFLOW_KEY)) {
    .async_job_submit_size_add(store, 1L)
  }
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
