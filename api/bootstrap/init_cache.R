## -------------------------------------------------------------------##
# api/bootstrap/init_cache.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Handles the disk-backed memoise cache used by the analytics /
# statistics endpoints:
#   1. Honour CACHE_VERSION — clear stale `.rds` files if the
#      stored marker differs from the current version.
#   2. Build the `cachem::cache_disk` used as the memoise backend.
#   3. Wrap the heavy report-generation functions with `memoise()`
#      and return them so the composer can bind each as a global.
#
# CACHE_VERSION semantics are documented in docs/DEPLOYMENT.md.
# Operators bump CACHE_VERSION whenever a code change alters the
# return structure of a memoised function.
## -------------------------------------------------------------------##

#' Clear the memoise disk cache when CACHE_VERSION changes.
#'
#' Writes a `.cache_version` marker file inside `cache_dir`. On
#' subsequent boots, if the marker's content matches the current
#' CACHE_VERSION env var the cache is kept; otherwise every `.rds`
#' file under `cache_dir` is removed and the marker is rewritten.
#'
#' @param cache_dir Directory path (default "/app/cache").
#' @return Invisibly, the current CACHE_VERSION value.
#' @export
bootstrap_init_cache_version <- function(cache_dir = "/app/cache") {
  cache_version <- Sys.getenv("CACHE_VERSION", "1")
  cache_version_file <- file.path(cache_dir, ".cache_version")

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  stored_version <- tryCatch(
    readLines(cache_version_file, n = 1, warn = FALSE),
    error = function(e) ""
  )
  if (length(stored_version) == 0) stored_version <- ""

  if (stored_version != cache_version) {
    message(sprintf(
      "[%s] Cache version mismatch (stored: '%s', current: '%s') - clearing cache",
      Sys.time(), stored_version, cache_version
    ))
    cache_files <- list.files(
      cache_dir, pattern = "\\.rds$", full.names = TRUE, recursive = TRUE
    )
    if (length(cache_files) > 0) {
      unlink(cache_files)
      message(sprintf(
        "[%s] Cleared %d cached files", Sys.time(), length(cache_files)
      ))
    }
    writeLines(cache_version, cache_version_file)
    message(sprintf(
      "[%s] Cache version set to '%s'", Sys.time(), cache_version
    ))
  } else {
    message(sprintf(
      "[%s] Cache version '%s' is current - no clearing needed",
      Sys.time(), cache_version
    ))
  }

  invisible(cache_version)
}

#' Build the memoise cache backend and wrap the heavy reports.
#'
#' The memoised wrappers replace the equivalent super-assignments
#' that used to sit in `start_sysndd_api.R`. They are returned as a
#' named list so the composer can bind each name at top level
#' (which is .GlobalEnv, so endpoints keep finding them by bare name).
#'
#' `get_string_db()` is an unrelated singleton defined in
#' analyses-functions.R and shared with mirai workers — it is not
#' memoised here.
#'
#' @param cache_dir Directory path (default "/app/cache").
#' @return Named list of memoised functions.
#' @export
bootstrap_init_memoised <- function(cache_dir = "/app/cache") {
  cm <- cachem::cache_disk(
    dir      = cache_dir,
    max_age  = 86400, # 24h safety net; CACHE_VERSION bump for immediate invalidation
    max_size = 500 * 1024^2 # 500 MB persistent on disk
  )

  list(
    generate_stat_tibble_mem       = memoise::memoise(generate_stat_tibble, cache = cm),
    generate_gene_news_tibble_mem  = memoise::memoise(generate_gene_news_tibble, cache = cm),
    nest_gene_tibble_mem           = memoise::memoise(nest_gene_tibble, cache = cm),
    generate_tibble_fspec_mem      = memoise::memoise(generate_tibble_fspec, cache = cm),
    gen_string_clust_obj_mem       = memoise::memoise(gen_string_clust_obj, cache = cm),
    gen_mca_clust_obj_mem          = memoise::memoise(gen_mca_clust_obj, cache = cm),
    gen_network_edges_mem          = memoise::memoise(gen_network_edges, cache = cm),
    read_log_files_mem             = memoise::memoise(read_log_files, cache = cm),
    nest_pubtator_gene_tibble_mem  = memoise::memoise(nest_pubtator_gene_tibble, cache = cm)
  )
}
