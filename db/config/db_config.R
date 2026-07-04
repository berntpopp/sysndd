# db/config/db_config.R
#
# Shared configuration + path helpers for the out-of-band SysNDD data-prep /
# database-creation scripts (the numbered `NN_Rcommands_*.R` files plus the
# `A/B/C_Rcommands_*.R` finalizers).
#
# These scripts historically did three fragile things in every header:
#   1. `config::get(file = Sys.getenv("CONFIG_FILE"), config = "sysndd")`
#   2. `setwd(paste0(config_vars_proj$projectsdir, project_name))`
#   3. inlined every external download URL as a hardcoded literal
#
# That made them depend on (a) an undocumented `CONFIG_FILE` env var, (b) the
# caller's working directory, and (c) source URLs that could only be changed by
# editing each script. This module centralizes all three concerns so the
# scripts can be sourced from anywhere and so external sources / paths live in
# one config file.
#
# IMPORTANT: this is the OUT-OF-BAND data-prep tooling. It is distinct from the
# runtime migration runner under `db/migrations/*.sql`. Do not confuse the two.
#
# Pure helpers in this file are unit-tested in `db/tests/testthat/`. Functions
# that touch the network or a live database are intentionally NOT auto-run here.

# Avoid noisy scientific notation in every script that sources this helper.
options(scipen = 999)

# ---------------------------------------------------------------------------
# Repo-root / path resolution (working-directory independent)
# ---------------------------------------------------------------------------

#' Resolve the absolute path to this `db/` directory.
#'
#' Resolution order (first hit wins):
#'   1. `SYSNDD_DB_DIR` environment variable, if set and existing.
#'   2. The directory containing this script, derived from the call stack
#'      (`sys.frame`) when sourced, or from `commandArgs()` when run via
#'      `Rscript`.
#'   3. The `db/` directory under `here::here()` if the `here` package is
#'      available (anchors on the repo root via `.git` / project markers).
#'   4. The current working directory as a last resort.
#'
#' @return Absolute, normalized path to the `db/` directory.
db_dir <- function() {
  env_dir <- Sys.getenv("SYSNDD_DB_DIR", unset = "")
  if (nzchar(env_dir) && dir.exists(env_dir)) {
    return(normalizePath(env_dir, mustWork = FALSE))
  }

  script_path <- db_this_script_path()
  if (!is.null(script_path)) {
    candidate <- dirname(dirname(script_path)) # config/ -> db/
    if (basename(dirname(script_path)) == "config" && dir.exists(candidate)) {
      return(normalizePath(candidate, mustWork = FALSE))
    }
  }

  if (requireNamespace("here", quietly = TRUE)) {
    candidate <- file.path(here::here(), "db")
    if (dir.exists(candidate)) {
      return(normalizePath(candidate, mustWork = FALSE))
    }
  }

  normalizePath(getwd(), mustWork = FALSE)
}

#' Resolve the absolute path to the repository root (parent of `db/`).
#'
#' @return Absolute, normalized path to the repo root.
db_repo_root <- function() {
  normalizePath(dirname(db_dir()), mustWork = FALSE)
}

#' Best-effort path of the currently executing/sourcing script.
#'
#' Works for both `source()` (reads `sys.frames()` `ofile`) and
#' `Rscript file.R` (reads the `--file=` command argument). Returns `NULL` when
#' neither is available (e.g. an interactive paste).
#'
#' @return Absolute path string, or `NULL`.
db_this_script_path <- function() {
  # Case 1: sourced file — walk the frame stack for an `ofile`.
  for (frame in rev(sys.frames())) {
    ofile <- frame$ofile
    if (!is.null(ofile)) {
      return(normalizePath(ofile, mustWork = FALSE))
    }
  }

  # Case 2: Rscript — parse the `--file=` command argument.
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) == 1) {
    return(normalizePath(sub("^--file=", "", file_arg), mustWork = FALSE))
  }

  NULL
}

#' Build an absolute path under the `db/` directory.
#'
#' Replaces working-directory-relative literals such as `"data/foo.txt"` and
#' `"results/bar.csv"` so scripts resolve the same paths regardless of `getwd()`.
#'
#' @param ... Path components passed to `file.path()`, relative to `db/`.
#' @param create_dir Whether to create the parent directory if missing.
#' @return Absolute, normalized path string.
db_path <- function(..., create_dir = FALSE) {
  path <- file.path(db_dir(), ...)
  if (create_dir) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  }
  normalizePath(path, mustWork = FALSE)
}

#' Absolute path under the `db/data/` input directory.
#' @param ... Components relative to `db/data/`.
#' @param create_dir Whether to create the parent directory if missing.
db_data_path <- function(..., create_dir = FALSE) {
  db_path("data", ..., create_dir = create_dir)
}

#' Absolute path under the `db/results/` output directory.
#'
#' The `results/` directory is created on demand because it holds generated
#' CSVs that are not checked into the repo.
#'
#' @param ... Components relative to `db/results/`.
#' @param create_dir Whether to create the parent directory if missing.
db_results_path <- function(..., create_dir = TRUE) {
  db_path("results", ..., create_dir = create_dir)
}

#' One-call bootstrap for the data-prep scripts.
#'
#' Replaces the per-script header boilerplate. It:
#'   1. exports `SYSNDD_DB_DIR` so all path helpers (and any child processes)
#'      resolve `db/` deterministically;
#'   2. anchors the working directory to `db/` (so the scripts' existing
#'      `"data/..."` / `"results/..."` relative paths resolve);
#'   3. sources the SysID source abstraction (`db_sysid_source.R`);
#'   4. resolves the external-source URL registry into a `db_src` variable in the
#'      caller's environment (so URL-building scripts can use it);
#'   5. loads and returns the credentials config.
#'
#' Typical script header (after a tiny finder + `source(db_config.R)`):
#'   `config_vars_proj <- db_bootstrap()`
#'
#' @param config_file Optional explicit config path (see `db_load_config`).
#' @param config Config section name (default `"sysndd"`).
#' @param envir Environment to assign `db_src` into (default: caller).
#' @return The loaded config list.
db_bootstrap <- function(config_file = NULL, config = "sysndd",
                         envir = parent.frame()) {
  Sys.setenv(SYSNDD_DB_DIR = db_dir())
  db_setwd_to_db_dir()

  sysid_helper <- db_path("config", "db_sysid_source.R")
  if (file.exists(sysid_helper)) {
    sys.source(sysid_helper, envir = globalenv())
  }

  assign("db_src", db_sources(), envir = envir)
  db_load_config(config_file = config_file, config = config)
}

#' Anchor the working directory to the `db/` directory.
#'
#' The legacy scripts called `setwd(paste0(projectsdir, "R"))`, which depended
#' on an operator-specific config path. This anchors `getwd()` to the resolved
#' `db/` directory instead, so the many existing `"data/..."` / `"results/..."`
#' relative paths in the scripts resolve correctly no matter where the script
#' is launched from. Call this once in each script's header (after sourcing this
#' file). The `db/results/` directory is created if missing.
#'
#' @return The `db/` directory path (invisibly).
db_setwd_to_db_dir <- function() {
  target <- db_dir()
  dir.create(file.path(target, "results"), recursive = TRUE, showWarnings = FALSE)
  setwd(target)
  invisible(target)
}

# ---------------------------------------------------------------------------
# Config loading (database credentials + project dir)
# ---------------------------------------------------------------------------

#' Load the database/credentials config for the data-prep scripts.
#'
#' Mirrors the legacy
#' `config::get(file = Sys.getenv("CONFIG_FILE"), config = "sysndd")` call but
#' resolves a sensible default config file when `CONFIG_FILE` is unset, so the
#' env var is no longer mandatory.
#'
#' Resolution order for the config file:
#'   1. `config_file` argument, if provided.
#'   2. `CONFIG_FILE` environment variable, if set.
#'   3. `db/config/sysndd_db.yml` (gitignored real credentials).
#'
#' @param config_file Optional explicit path to a config YAML.
#' @param config Config section name (default `"sysndd"`).
#' @return Named list of config values.
db_load_config <- function(config_file = NULL, config = "sysndd") {
  if (is.null(config_file) || !nzchar(config_file)) {
    config_file <- Sys.getenv("CONFIG_FILE", unset = "")
  }
  if (!nzchar(config_file)) {
    config_file <- db_path("config", "sysndd_db.yml")
  }
  if (!file.exists(config_file)) {
    stop(
      "DB config file not found: ", config_file,
      "\nCopy db/config/sysndd_db.yml.example to db/config/sysndd_db.yml ",
      "and fill in real credentials, or set CONFIG_FILE.",
      call. = FALSE
    )
  }
  config::get(file = config_file, config = config)
}

# ---------------------------------------------------------------------------
# External data-source registry (config-ized URLs)
# ---------------------------------------------------------------------------

# Built-in defaults for every external source URL the scripts touch. These are
# public, non-secret base URLs; they live in code as a fallback so a fresh
# checkout works without an extra config file. Operators can override any of
# them via `db/config/db_sources.yml`.
.db_source_defaults <- list(
  # HGNC complete gene set (TSV) downloaded by script 01.
  hgnc_non_alt_loci_set = "http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/non_alt_loci_set.txt",
  # genenames.org REST search endpoints (scripts 02, 04, 11).
  genenames_rest_base   = "http://rest.genenames.org/search",
  # Human Phenotype Ontology term API (scripts 02, 03, 04, 11).
  # The legacy hpo.jax.org term API was retired; JAX serves it from the Monarch
  # ontology API now. Term detail: "<base>/<id>"; children/descendants:
  # "<base>/<id>/children" and "<base>/<id>/descendants".
  hpo_term_api_base     = "https://ontology.jax.org/api/hp/terms",
  # EBI OxO cross-ontology mapping API (scripts 02, 04).
  oxo_mappings_api      = "https://www.ebi.ac.uk/spot/oxo/api/mappings",
  # NCBI E-utilities efetch endpoint (script 08).
  ncbi_eutils_efetch    = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
  # NCBI Bookshelf / GeneReviews base (script 08).
  ncbi_books_base       = "https://www.ncbi.nlm.nih.gov/books",
  # Variation Ontology OBO download (script 12).
  vario_obo             = "http://www.variationontology.org/vario_download/vario.obo"
)

#' Resolve the external-source registry (defaults overlaid with config file).
#'
#' Reads `db/config/db_sources.yml` (if present) and overlays any keys it
#' defines on top of `.db_source_defaults`. The config file is optional; the
#' built-in defaults are valid public URLs.
#'
#' @param sources_file Optional explicit path to a sources YAML.
#' @return Named list of source URLs.
db_sources <- function(sources_file = NULL) {
  if (is.null(sources_file) || !nzchar(sources_file)) {
    sources_file <- Sys.getenv("DB_SOURCES_FILE", unset = "")
  }
  if (!nzchar(sources_file)) {
    sources_file <- db_path("config", "db_sources.yml")
  }

  merged <- .db_source_defaults
  if (file.exists(sources_file) && requireNamespace("yaml", quietly = TRUE)) {
    overrides <- yaml::read_yaml(sources_file)
    sources <- overrides[["sources"]]
    if (is.null(sources)) {
      sources <- overrides
    }
    for (key in names(sources)) {
      if (nzchar(key) && !is.null(sources[[key]])) {
        merged[[key]] <- sources[[key]]
      }
    }
  }
  merged
}

#' Look up a single external-source URL by key.
#'
#' @param key Source key (see names of `.db_source_defaults`).
#' @param sources Optional pre-resolved source list (avoids re-reading config).
#' @return URL string.
db_source_url <- function(key, sources = db_sources()) {
  if (!key %in% names(sources)) {
    stop("Unknown data source key: ", key, call. = FALSE)
  }
  sources[[key]]
}

#' Build a genenames.org REST search URL.
#'
#' Example: `db_genenames_search_url("prev_symbol", "FOO")` ->
#'   "http://rest.genenames.org/search/prev_symbol/FOO"
#'
#' @param field Search field (e.g. "prev_symbol", "alias_symbol", "symbol",
#'   "hgnc_id").
#' @param value Search value (caller is responsible for any escaping).
#' @param sources Optional pre-resolved source list.
#' @return URL string.
db_genenames_search_url <- function(field, value = "", sources = db_sources()) {
  base <- db_source_url("genenames_rest_base", sources)
  paste0(base, "/", field, "/", value)
}

#' Build an HPO term API URL for a single term id.
#'
#' Reserved characters in the term id (e.g. the `:` in "HP:0000005") are
#' URL-encoded, matching the legacy `URLencode(term, reserved = TRUE)` calls.
#'
#' @param term_id HPO term id (e.g. "HP:0000005").
#' @param sources Optional pre-resolved source list.
#' @return URL string.
db_hpo_term_url <- function(term_id, sources = db_sources()) {
  base <- db_source_url("hpo_term_api_base", sources)
  paste0(base, "/", utils::URLencode(term_id, reserved = TRUE))
}

#' Build an EBI OxO mappings API URL for a `fromId`.
#'
#' @param from_id Source ontology id to map from.
#' @param sources Optional pre-resolved source list.
#' @return URL string.
db_oxo_mappings_url <- function(from_id, sources = db_sources()) {
  base <- db_source_url("oxo_mappings_api", sources)
  paste0(base, "?fromId=", from_id)
}
