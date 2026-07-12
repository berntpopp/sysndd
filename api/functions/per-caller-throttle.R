# Reusable, in-memory per-caller admission throttle.
#
# Callers provide a separate store and policy. This module owns the security
# mechanics shared by public endpoints: validated client fingerprints, a bounded
# sliding-window store, and fail-closed response handling.

PER_CALLER_THROTTLE_MAX_XFF_BYTES <- 4096L
PER_CALLER_THROTTLE_MAX_XFF_HOPS <- 32L

# Parse a bounded positive integer env var. Bad values fall back to a secure
# default; callers use a minimum >= 1 for limits so configuration cannot disable
# admission controls.
per_caller_throttle_env_int <- function(name, default, min_value, max_value = NULL) {
  raw <- trimws(Sys.getenv(name, ""))
  if (!nzchar(raw) || !grepl("^-?[0-9]+$", raw)) return(as.integer(default))
  value <- suppressWarnings(as.integer(raw))
  if (is.na(value) || value < min_value) return(as.integer(default))
  if (!is.null(max_value) && value > max_value) return(as.integer(max_value))
  value
}

per_caller_throttle_ipv4_num <- function(ip) {
  match <- regmatches(ip, regexec("^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$", ip))[[1]]
  if (length(match) != 5L) return(NA_real_)
  octets <- as.numeric(match[2:5])
  if (any(octets < 0 | octets > 255)) return(NA_real_)
  octets[[1]] * 16777216 + octets[[2]] * 65536 + octets[[3]] * 256 + octets[[4]]
}

# Fully expand valid IPv6 text. Canonicalising before trust matching prevents a
# compressed spelling of the same proxy address from escaping its configured CIDR.
per_caller_throttle_ipv6_hextets <- function(token) {
  low <- tolower(token)
  if (!grepl(":", low, fixed = TRUE) || !grepl("^[0-9a-f:]+$", low) || grepl(":::", low, fixed = TRUE)) {
    return(NULL)
  }
  double_colon <- gregexpr("::", low, fixed = TRUE)[[1]]
  if (length(double_colon) == 1L && double_colon[[1]] != -1L) {
    left <- sub("::.*$", "", low)
    right <- sub("^.*::", "", low)
    left_groups <- if (nzchar(left)) strsplit(left, ":", fixed = TRUE)[[1]] else character(0)
    right_groups <- if (nzchar(right)) strsplit(right, ":", fixed = TRUE)[[1]] else character(0)
    zero_count <- 8L - length(left_groups) - length(right_groups)
    if (zero_count < 1L) return(NULL)
    groups <- c(left_groups, rep("0", zero_count), right_groups)
  } else if (length(double_colon) == 1L && double_colon[[1]] == -1L) {
    groups <- strsplit(low, ":", fixed = TRUE)[[1]]
  } else {
    return(NULL)
  }
  if (length(groups) != 8L || !all(grepl("^[0-9a-f]{1,4}$", groups))) return(NULL)
  strtoi(groups, base = 16L)
}

# Classify a header hop. IPv6 callers share a /64 bucket to prevent an allocation
# from bypassing a quota by rotating its interface identifier; trust checks use the
# full canonical address, not that bucket key.
per_caller_throttle_ip_classify <- function(token) {
  invalid <- list(family = NA_character_, canonical = NA_character_, key = NA_character_)
  if (is.null(token) || length(token) != 1L || is.na(token)) return(invalid)
  token <- trimws(as.character(token))
  token <- sub("^\\[(.*)\\]$", "\\1", token)
  if (!nzchar(token) || nchar(token) > 64L) return(invalid)
  ipv4 <- sub(":[0-9]+$", "", token)
  if (grepl("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", ipv4)) {
    octets <- suppressWarnings(as.integer(strsplit(ipv4, ".", fixed = TRUE)[[1]]))
    if (!anyNA(octets) && all(octets >= 0L & octets <= 255L)) {
      return(list(family = "v4", canonical = ipv4, key = ipv4))
    }
    return(invalid)
  }
  hex <- per_caller_throttle_ipv6_hextets(token)
  if (is.null(hex)) return(invalid)
  canonical <- sprintf("%x", hex)
  list(
    family = "v6",
    canonical = paste(canonical, collapse = ":"),
    key = paste0(paste(canonical[1:4], collapse = ":"), "::/64")
  )
}

per_caller_throttle_normalize_ip <- function(token) per_caller_throttle_ip_classify(token)$key

per_caller_throttle_v4_match <- function(ip, cidr) {
  ip_num <- per_caller_throttle_ipv4_num(ip)
  if (is.na(ip_num)) return(FALSE)
  if (!grepl("/", cidr, fixed = TRUE)) return(identical(per_caller_throttle_ipv4_num(cidr), ip_num))
  parts <- strsplit(cidr, "/", fixed = TRUE)[[1]]
  bits <- if (length(parts) == 2L) suppressWarnings(as.integer(parts[[2]])) else NA_integer_
  network <- if (length(parts) == 2L) per_caller_throttle_ipv4_num(parts[[1]]) else NA_real_
  if (is.na(bits) || bits < 0L || bits > 32L || is.na(network)) return(FALSE)
  unit <- 2^(32L - bits)
  floor(ip_num / unit) == floor(network / unit)
}

per_caller_throttle_v6_match <- function(ip_canonical, cidr) {
  ip_hex <- per_caller_throttle_ipv6_hextets(ip_canonical)
  if (is.null(ip_hex)) return(FALSE)
  if (!grepl("/", cidr, fixed = TRUE)) {
    network_hex <- per_caller_throttle_ipv6_hextets(cidr)
    return(!is.null(network_hex) && all(ip_hex == network_hex))
  }
  parts <- strsplit(cidr, "/", fixed = TRUE)[[1]]
  bits <- if (length(parts) == 2L) suppressWarnings(as.integer(parts[[2]])) else NA_integer_
  network_hex <- if (length(parts) == 2L) per_caller_throttle_ipv6_hextets(parts[[1]]) else NULL
  if (is.na(bits) || bits < 0L || bits > 128L || is.null(network_hex)) return(FALSE)
  full_groups <- bits %/% 16L
  remaining_bits <- bits %% 16L
  if (full_groups > 0L && !all(ip_hex[seq_len(full_groups)] == network_hex[seq_len(full_groups)])) return(FALSE)
  if (remaining_bits > 0L) {
    mask <- 65536L - as.integer(2^(16L - remaining_bits))
    return(bitwAnd(ip_hex[[full_groups + 1L]], mask) == bitwAnd(network_hex[[full_groups + 1L]], mask))
  }
  TRUE
}

per_caller_throttle_valid_cidr <- function(cidr) {
  cidr <- trimws(cidr)
  if (grepl(":", cidr, fixed = TRUE)) {
    if (!grepl("/", cidr, fixed = TRUE)) return(!is.null(per_caller_throttle_ipv6_hextets(cidr)))
    parts <- strsplit(cidr, "/", fixed = TRUE)[[1]]
    bits <- if (length(parts) == 2L) suppressWarnings(as.integer(parts[[2]])) else NA_integer_
    return(!is.na(bits) && bits >= 0L && bits <= 128L && !is.null(per_caller_throttle_ipv6_hextets(parts[[1]])))
  }
  if (!grepl("/", cidr, fixed = TRUE)) return(!is.na(per_caller_throttle_ipv4_num(cidr)))
  parts <- strsplit(cidr, "/", fixed = TRUE)[[1]]
  bits <- if (length(parts) == 2L) suppressWarnings(as.integer(parts[[2]])) else NA_integer_
  !is.na(bits) && bits >= 0L && bits <= 32L && !is.na(per_caller_throttle_ipv4_num(parts[[1]]))
}

# Parse a comma-separated proxy trust list and fail closed on malformed entries:
# invalid text is observable but is never retained as a trusted source.
per_caller_throttle_parse_trusted_cidrs <- function(raw, config_name) {
  raw <- trimws(raw)
  if (!nzchar(raw)) return(character(0))
  cidrs <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
  cidrs <- cidrs[nzchar(cidrs)]
  valid <- vapply(cidrs, per_caller_throttle_valid_cidr, logical(1))
  invalid <- cidrs[!valid]
  if (length(invalid) > 0L && base::exists("log_warn", mode = "function")) {
    logger <- base::get("log_warn", mode = "function")
    try(logger(paste0(
      config_name, " has invalid entries (ignored): ",
      paste(invalid, collapse = ", ")
    )), silent = TRUE)
  }
  cidrs[valid]
}

per_caller_throttle_ip_trusted <- function(family, canonical, trusted_cidrs) {
  if (length(trusted_cidrs) == 0L || is.null(family) || is.na(family)) return(FALSE)
  for (cidr in trusted_cidrs) {
    cidr <- trimws(cidr)
    is_v6 <- grepl(":", cidr, fixed = TRUE)
    if (family == "v4" && !is_v6 && per_caller_throttle_v4_match(canonical, cidr)) return(TRUE)
    if (family == "v6" && is_v6 && per_caller_throttle_v6_match(canonical, cidr)) return(TRUE)
  }
  FALSE
}

#' Derive a stable caller key from a proxy-owned XFF chain.
#'
#' Traefik appends the peer it actually observed on the right. Walking right to
#' left and skipping only configured trusted proxy sources means an attacker can
#' forge leftmost values but cannot choose the selected rightmost-untrusted hop.
#' Invalid header values are never accepted as keys; they fall back to REMOTE_ADDR
#' and finally one shared unknown bucket.
per_caller_throttle_fingerprint <- function(req, trusted_cidrs = character(0)) {
  remote <- per_caller_throttle_normalize_ip(tryCatch(req$REMOTE_ADDR, error = function(e) NULL))
  xff <- tryCatch(req$HTTP_X_FORWARDED_FOR, error = function(e) NULL)
  xff_valid <- !is.null(xff) && length(xff) == 1L && !is.na(xff) && nzchar(xff) &&
    nchar(as.character(xff), type = "bytes") <= PER_CALLER_THROTTLE_MAX_XFF_BYTES
  if (isTRUE(xff_valid)) {
    hops <- trimws(strsplit(as.character(xff), ",", fixed = TRUE)[[1]])
    hops <- hops[nzchar(hops)]
    if (length(hops) <= PER_CALLER_THROTTLE_MAX_XFF_HOPS) {
      for (i in rev(seq_along(hops))) {
        candidate <- per_caller_throttle_ip_classify(hops[[i]])
        if (is.na(candidate$family)) next
        if (per_caller_throttle_ip_trusted(candidate$family, candidate$canonical, trusted_cidrs)) next
        return(candidate$key)
      }
    }
  }
  if (!is.na(remote)) return(remote)
  "unknown"
}

.PER_CALLER_THROTTLE_OVERFLOW_KEY <- "\001overflow"
.PER_CALLER_THROTTLE_SWEEP_KEY <- "\001sweep_at"
.PER_CALLER_THROTTLE_COUNT_KEY <- "\001count"

per_caller_rate_limit_size <- function(store) {
  if (!base::exists(.PER_CALLER_THROTTLE_COUNT_KEY, envir = store, inherits = FALSE)) return(0L)
  base::get(.PER_CALLER_THROTTLE_COUNT_KEY, envir = store, inherits = FALSE)
}

.per_caller_rate_limit_size_add <- function(store, delta) {
  assign(.PER_CALLER_THROTTLE_COUNT_KEY, per_caller_rate_limit_size(store) + as.integer(delta), envir = store)
}

.per_caller_rate_limit_reclaim <- function(store, cutoff, now, window_s) {
  sweep_at <- if (base::exists(.PER_CALLER_THROTTLE_SWEEP_KEY, envir = store, inherits = FALSE)) {
    base::get(.PER_CALLER_THROTTLE_SWEEP_KEY, envir = store, inherits = FALSE)
  } else {
    -Inf
  }
  if ((now - sweep_at) < window_s) return(invisible(NULL))
  keys <- setdiff(names(store), c(.PER_CALLER_THROTTLE_SWEEP_KEY, .PER_CALLER_THROTTLE_COUNT_KEY))
  removed <- 0L
  for (key in keys) {
    timestamps <- base::get(key, envir = store, inherits = FALSE)
    if (length(timestamps) == 0L || max(timestamps) <= cutoff) {
      rm(list = key, envir = store)
      if (!identical(key, .PER_CALLER_THROTTLE_OVERFLOW_KEY)) removed <- removed + 1L
    }
  }
  assign(.PER_CALLER_THROTTLE_SWEEP_KEY, now, envir = store)
  if (removed > 0L) .per_caller_rate_limit_size_add(store, -removed)
  invisible(NULL)
}

#' Apply one bounded sliding-window decision for a caller fingerprint.
per_caller_rate_limit <- function(fingerprint, now = as.numeric(Sys.time()), max_n,
                                  window_s, store, max_tracked) {
  if (is.null(fingerprint) || length(fingerprint) != 1L || is.na(fingerprint) || !nzchar(fingerprint)) {
    fingerprint <- "unknown"
  }
  if (length(max_n) != 1L || !is.finite(max_n) || max_n < 1L ||
      length(window_s) != 1L || !is.finite(window_s) || window_s < 1L ||
      length(max_tracked) != 1L || !is.finite(max_tracked) || max_tracked < 1L) {
    stop("per-caller throttle misconfigured")
  }
  cutoff <- now - window_s
  is_new <- !base::exists(fingerprint, envir = store, inherits = FALSE)
  if (is_new && per_caller_rate_limit_size(store) >= max_tracked) {
    .per_caller_rate_limit_reclaim(store, cutoff, now, window_s)
    if (per_caller_rate_limit_size(store) >= max_tracked) {
      fingerprint <- .PER_CALLER_THROTTLE_OVERFLOW_KEY
      is_new <- !base::exists(fingerprint, envir = store, inherits = FALSE)
    }
  }
  previous <- if (is_new) numeric(0) else base::get(fingerprint, envir = store, inherits = FALSE)
  recent <- previous[previous > cutoff]
  if (length(recent) >= max_n) {
    retry_after <- max(1L, as.integer(ceiling((recent[[1]] + window_s) - now)))
    assign(fingerprint, recent, envir = store)
    return(list(allowed = FALSE, retry_after = retry_after, count = length(recent)))
  }
  assign(fingerprint, c(recent, now), envir = store)
  if (is_new && !identical(fingerprint, .PER_CALLER_THROTTLE_OVERFLOW_KEY)) {
    .per_caller_rate_limit_size_add(store, 1L)
  }
  list(allowed = TRUE, retry_after = 0L, count = length(recent) + 1L)
}

per_caller_rate_limit_reset <- function(store) {
  rm(list = ls(envir = store, all.names = TRUE), envir = store)
  invisible(NULL)
}

.per_caller_throttle_unavailable <- function(res, retry_after, message) {
  res$status <- 503L
  res$setHeader("Retry-After", as.character(retry_after))
  list(admitted = FALSE, response = list(
    error = "THROTTLE_UNAVAILABLE", message = message, retry_after = retry_after
  ))
}

per_caller_throttle_warn <- function(message) {
  try({
    if (base::exists("log_warn", mode = "function")) {
      logger <- base::get("log_warn", mode = "function")
      logger(message)
    }
  }, silent = TRUE)
  invisible(NULL)
}

#' Translate a limiter decision to a safe Plumber response.
#'
#' The limiter closure is injected so route-specific policies retain separate
#' stores and configs. Its exceptions and malformed values are denied, never
#' treated as a reason to silently bypass the control.
per_caller_admission_guard <- function(
    req,
    res,
    rate_limit,
    fingerprint = per_caller_throttle_fingerprint,
    rate_limit_message,
    unavailable_message = "Submission throttling is temporarily unavailable. Please retry shortly.",
    unavailable_retry_after = 5L,
    on_error = NULL) {
  decision <- tryCatch(rate_limit(fingerprint(req)), error = function(e) {
    if (is.function(on_error)) try(on_error(e), silent = TRUE)
    NULL
  })
  valid <- is.list(decision) && length(decision$allowed) == 1L &&
    is.logical(decision$allowed) && !is.na(decision$allowed)
  if (!valid) return(.per_caller_throttle_unavailable(res, unavailable_retry_after, unavailable_message))
  if (!isTRUE(decision$allowed)) {
    retry_after <- suppressWarnings(as.integer(decision$retry_after))
    if (length(retry_after) != 1L || is.na(retry_after) || retry_after < 1L) retry_after <- 1L
    res$status <- 429L
    res$setHeader("Retry-After", as.character(retry_after))
    return(list(admitted = FALSE, response = list(
      error = "RATE_LIMITED", message = rate_limit_message, retry_after = retry_after
    )))
  }
  list(admitted = TRUE)
}
