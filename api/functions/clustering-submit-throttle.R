# Per-caller submit throttle for the public clustering job routes (#535 S6).
# Generic fingerprinting, bounded state, and response handling live in
# per-caller-throttle.R; this file owns only S6 policy and compatibility names.

.async_job_submit_env_int <- per_caller_throttle_env_int
.async_job_submit_valid_cidr <- per_caller_throttle_valid_cidr
.async_job_submit_size <- per_caller_rate_limit_size

CLUSTERING_SUBMIT_PER_CALLER_MAX <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_PER_CALLER_MAX", 5L, 1L, max_value = 1000L)
CLUSTERING_SUBMIT_WINDOW_SECONDS <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_WINDOW_SECONDS", 60L, 5L, max_value = 86400L)
CLUSTERING_SUBMIT_MAX_TRACKED <-
  .async_job_submit_env_int("CLUSTERING_SUBMIT_MAX_TRACKED", 20000L, 100L, max_value = 200000L)
CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS <- per_caller_throttle_parse_trusted_cidrs(
  Sys.getenv("CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS", ""),
  "CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS"
)

.clustering_submit_history <- new.env(parent = emptyenv())

async_job_submit_fingerprint <- function(req, trusted_cidrs = CLUSTERING_SUBMIT_TRUSTED_PROXY_CIDRS) {
  per_caller_throttle_fingerprint(req, trusted_cidrs)
}

async_job_submit_rate_limit <- function(fingerprint, now = as.numeric(Sys.time()),
                                        max_n = CLUSTERING_SUBMIT_PER_CALLER_MAX,
                                        window_s = CLUSTERING_SUBMIT_WINDOW_SECONDS,
                                        store = .clustering_submit_history,
                                        max_tracked = CLUSTERING_SUBMIT_MAX_TRACKED) {
  per_caller_rate_limit(fingerprint, now, max_n, window_s, store, max_tracked)
}

async_job_submit_admission_guard <- function(req, res) {
  per_caller_admission_guard(
    req = req,
    res = res,
    rate_limit = function(fingerprint) async_job_submit_rate_limit(fingerprint),
    fingerprint = async_job_submit_fingerprint,
    rate_limit_message = "Too many analysis submissions from your client. Please retry shortly."
  )
}

async_job_submit_rate_limit_reset <- function(store = .clustering_submit_history) {
  per_caller_rate_limit_reset(store)
}
