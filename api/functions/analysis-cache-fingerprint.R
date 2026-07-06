# functions/analysis-cache-fingerprint.R
#
# Self-invalidating memoise-key fingerprints for the analysis-logic-dependent
# clustering functions (#514).
#
# Background: the heavy clustering functions (gen_string_clust_obj,
# gen_network_edges, gen_mca_clust_obj) are memoised onto a disk-backed cache that
# lives on a named volume and survives container restarts/redeploys
# (api/bootstrap/init_cache.R). Historically the memoise key was just the call
# arguments (gene_ids, algorithm), so a change to the clustering *inputs* or
# *algorithm* — the STRING channel (#510 text-mining-free exp+db), the MCA feature
# hygiene (#508/#509), the Leiden parameters — did NOT change the key. A methodology
# deploy therefore served a STALE partition out of the disk cache while the (un-memoised)
# validator recomputed fresh, producing internally-incoherent snapshots (#514).
#
# Fix: fold a fingerprint into the memoise key. Each clustering function gains a
# trailing `.cache_fingerprint` formal whose default is one of these helpers; memoise
# hashes call-time default arguments, so the fingerprint enters the key with no
# call-site changes. The default is evaluated at CALL time (not at boot), so adding or
# rebuilding the exp+db artifact self-invalidates the relevant entries even without a
# restart — the exact production scenario in #514.
#
# Two mechanisms compose:
#   1. CLUSTER_LOGIC_VERSION — a code constant bumped on ANY clustering input/algorithm
#      change (graph construction, channel selection, Leiden/MCA/HCPC params). Bumping it
#      invalidates every clustering cache entry on the next call.
#   2. Data/config identity — the STRING channel + exp+db file (size:mtime) for the
#      functional axis, and the MCA prevalence band for the phenotype axis — so a data or
#      configuration change self-invalidates the relevant entries with no code change.

# Bump on ANY change to clustering inputs/algorithm. The token is opaque; only its
# equality across calls matters. Current value reflects the #510 exp+db methodology.
CLUSTER_LOGIC_VERSION <- "2026-07-06.510-expdb"

#' Fingerprint for the functional (STRING) clustering cache.
#'
#' Composite of CLUSTER_LOGIC_VERSION, the selected STRING channel, and the exp+db
#' edge file identity (present:size:mtime | absent). Returned as a readable,
#' pipe-delimited string; memoise hashes it into the cache key. Every component is
#' wrapped so a transient error degrades to a sentinel token rather than breaking the
#' clustering call.
#'
#' @return character(1) fingerprint token.
#' @export
analysis_string_cache_fingerprint <- function() {
  channels <- tryCatch(
    paste(string_weight_channels(), collapse = ","),
    error = function(e) "channels_NA"
  )
  expdb <- tryCatch(
    {
      f <- string_expdb_edges_file()
      if (isTRUE(file.exists(f))) {
        info <- file.info(f)
        paste0("present:", info$size, ":", as.integer(info$mtime))
      } else {
        "absent"
      }
    },
    error = function(e) "expdb_NA"
  )
  paste("string", CLUSTER_LOGIC_VERSION, channels, expdb, sep = "|")
}

#' Fingerprint for the phenotype (MCA/HCPC) clustering cache.
#'
#' Composite of CLUSTER_LOGIC_VERSION and the MCA prevalence band envs
#' (PHENOTYPE_MCA_PREVALENCE_MIN/MAX), so a band change self-invalidates the
#' phenotype cache without a code change. The STRING file identity is deliberately
#' excluded so a STRING-only change does not needlessly invalidate phenotype entries.
#'
#' @return character(1) fingerprint token.
#' @export
analysis_phenotype_cache_fingerprint <- function() {
  band <- paste(
    Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MIN", "0.05"),
    Sys.getenv("PHENOTYPE_MCA_PREVALENCE_MAX", "0.95"),
    sep = ","
  )
  paste("phenotype", CLUSTER_LOGIC_VERSION, band, sep = "|")
}

#' Resolve a fingerprint helper defensively (call-time default helper).
#'
#' Used as the `.cache_fingerprint` default in the clustering functions so that
#' test/minimal environments that source a clustering function without this module
#' degrade to a constant NULL key component instead of erroring on the default.
#'
#' @param kind "string" or "phenotype".
#' @return character(1) fingerprint, or NULL when the helper is unavailable.
#' @export
analysis_cache_fingerprint <- function(kind = c("string", "phenotype")) {
  kind <- match.arg(kind)
  # NB: do NOT use get()/exists() with a bare name here — the `config` package
  # (loaded for DB config) masks base::get with a signature that has no `mode`
  # argument, so `get(fn, mode = "function")` raises "unused argument". Dispatch
  # to the concrete helpers directly; base::exists is not masked.
  if (identical(kind, "string")) {
    if (exists("analysis_string_cache_fingerprint", mode = "function")) {
      analysis_string_cache_fingerprint()
    } else {
      NULL
    }
  } else {
    if (exists("analysis_phenotype_cache_fingerprint", mode = "function")) {
      analysis_phenotype_cache_fingerprint()
    } else {
      NULL
    }
  }
}
