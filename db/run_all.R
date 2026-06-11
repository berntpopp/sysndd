#!/usr/bin/env Rscript
# db/run_all.R
#
# MASTER orchestration script for the out-of-band SysNDD data-prep /
# database-creation pipeline (GitHub issue #33).
#
# It runs the numbered table-builder scripts (01..17) followed by the database
# finalizers (A, B, C) in the correct order, each in its own fresh R subprocess,
# with timestamped logging and fail-fast behavior.
#
# WHY SUBPROCESSES: each step `library()`-loads heavy / mutually masking
# packages (tidyverse, biomaRt, STRINGdb, RMariaDB, ssh, ...) and manages its
# own DB connection lifecycle (e.g. `rm_con()`). Running each in a clean
# `Rscript` process avoids cross-step namespace masking and stale connections,
# and matches how the steps were historically run one-by-one.
#
# This script is OUT-OF-BAND tooling. It is NOT the runtime migration runner
# (`db/migrations/*.sql`, applied at API startup). Do not run this against a
# production database without understanding each step.
#
# Usage:
#   Rscript db/run_all.R                 # run the full pipeline
#   Rscript db/run_all.R --list          # list the ordered steps and exit
#   Rscript db/run_all.R --dry-run       # log what would run, do nothing
#   Rscript db/run_all.R --only 01,02    # run only matching step prefixes
#   Rscript db/run_all.R --from 04       # start at step 04 (resume)
#   Rscript db/run_all.R --skip-finalize # skip the A/B/C finalizers
#
# Prerequisites (see db/README.md):
#   * R with the packages each step needs (tidyverse, DBI, RMariaDB, sqlr, ...).
#   * db/config/sysndd_db.yml filled in (copy from .example).
#   * Authorized OMIM links in db/data/omim_links/omim_links.txt.
#   * A reachable SysNDD target DB and either a SysID SQLite snapshot or a live
#     SysID source (see db/README.md "Reproducible SysID import").

# The master script itself only needs base R; each step loads its own deps.

# Resolve this script's directory so the pipeline is working-directory
# independent (issue #33). We do NOT source db_config.R here to keep the
# orchestrator dependency-free, but we use the same --file= resolution trick.
.resolve_db_dir <- function() {
  env_dir <- Sys.getenv("SYSNDD_DB_DIR", unset = "")
  if (nzchar(env_dir) && dir.exists(env_dir)) {
    return(normalizePath(env_dir, mustWork = FALSE))
  }
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) == 1) {
    return(normalizePath(dirname(sub("^--file=", "", file_arg)), mustWork = FALSE))
  }
  normalizePath(getwd(), mustWork = FALSE)
}

DB_DIR <- .resolve_db_dir()

# Ordered pipeline. Numbered steps build/export individual tables; the A/B/C
# finalizers import the generated CSVs and set data types / keys / views.
TABLE_STEPS <- c(
  "01_Rcommands_sysndd_db_table_hgnc_non_alt_loci_set.R",
  "02_Rcommands_sysndd_db_table_disease_ontology_set.R",
  "03_Rcommands_sysndd_db_table_mode_of_inheritance_list.R",
  "04_Rcommands_sysndd_db_table_ndd_entity.R",
  "05_Rcommands_sysndd_db_table_ndd_entity_review.R",
  "06_Rcommands_sysndd_db_table_ndd_entity_status.R",
  "07_Rcommands_sysndd_db_table_ndd_review_phenotype_connect.R",
  "08_Rcommands_sysndd_db_table_publication.R",
  "09_Rcommands_sysndd_db_table_re_review.R",
  "10_Rcommands_sysndd_db_table_user.R",
  "11_Rcommands_sysndd_db_table_database_comparisons.R",
  "12_Rcommands_sysndd_db_table_variation_ontology_set.R",
  "13_Rcommands_sysndd_db_boolean_list.R",
  "14_Rcommands_sysndd_db_allowed_list.R",
  "15_Rcommands_sysndd_db_logging_table.R",
  "16_Rcommands_sysndd_db_pubtator_cache_table.R",
  "17_Rcommands_sysndd_db_json_storage_table.R"
)

FINALIZE_STEPS <- c(
  "A_Rcommands_create-database-tables.R",
  "B_Rcommands_set-table-data-types.R",
  "C_Rcommands_set-table-connections.R"
)

# ---- arg parsing ---------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

arg_flag <- function(name) name %in% args

arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) == 1) {
    return(sub(paste0("^", name, "="), "", hit))
  }
  idx <- which(args == name)
  if (length(idx) == 1 && idx < length(args)) {
    return(args[idx + 1])
  }
  NULL
}

opt_list <- arg_flag("--list")
opt_dry_run <- arg_flag("--dry-run")
opt_skip_finalize <- arg_flag("--skip-finalize")
opt_only <- arg_value("--only")
opt_from <- arg_value("--from")

# ---- logging -------------------------------------------------------------

log_msg <- function(...) {
  ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s\n", ts, paste0(...)))
}

# ---- build the step list -------------------------------------------------

steps <- TABLE_STEPS
if (!opt_skip_finalize) {
  steps <- c(steps, FINALIZE_STEPS)
}

if (!is.null(opt_only)) {
  prefixes <- trimws(strsplit(opt_only, ",")[[1]])
  steps <- steps[vapply(steps, function(s) {
    any(startsWith(s, prefixes))
  }, logical(1))]
}

if (!is.null(opt_from)) {
  start_idx <- which(startsWith(steps, opt_from))
  if (length(start_idx) >= 1) {
    steps <- steps[seq(min(start_idx), length(steps))]
  } else {
    log_msg("WARNING: --from '", opt_from, "' matched no step; running all.")
  }
}

# ---- list / validate -----------------------------------------------------

if (opt_list) {
  log_msg("Ordered pipeline steps (db dir: ", DB_DIR, "):")
  for (i in seq_along(steps)) {
    cat(sprintf("  %2d. %s\n", i, steps[i]))
  }
  quit(status = 0)
}

if (length(steps) == 0) {
  log_msg("No steps selected. Nothing to do.")
  quit(status = 0)
}

missing <- steps[!file.exists(file.path(DB_DIR, steps))]
if (length(missing) > 0) {
  log_msg("ERROR: missing step scripts: ", paste(missing, collapse = ", "))
  quit(status = 1)
}

# ---- run -----------------------------------------------------------------

r_bin <- file.path(R.home("bin"), "Rscript")

log_msg("Starting SysNDD data-prep pipeline (", length(steps), " steps).")
log_msg("DB dir: ", DB_DIR)
if (opt_dry_run) log_msg("DRY RUN: no scripts will be executed.")

pipeline_start <- Sys.time()

for (i in seq_along(steps)) {
  step <- steps[i]
  step_path <- file.path(DB_DIR, step)
  log_msg(sprintf("[%d/%d] >>> %s", i, length(steps), step))

  if (opt_dry_run) {
    next
  }

  step_start <- Sys.time()
  # Propagate SYSNDD_DB_DIR so each subprocess resolves paths identically.
  status <- system2(
    r_bin,
    args = c("--no-init-file", shQuote(step_path)),
    env = paste0("SYSNDD_DB_DIR=", DB_DIR)
  )
  elapsed <- round(as.numeric(difftime(Sys.time(), step_start, units = "secs")), 1)

  if (!identical(status, 0L)) {
    log_msg(sprintf("FAILED (exit %s) after %ss: %s", status, elapsed, step))
    log_msg("Pipeline aborted. Fix the step above and resume with: ",
            "Rscript db/run_all.R --from ", substr(step, 1, 2))
    quit(status = 1)
  }
  log_msg(sprintf("[%d/%d] <<< OK in %ss: %s", i, length(steps), elapsed, step))
}

total <- round(as.numeric(difftime(Sys.time(), pipeline_start, units = "secs")), 1)
log_msg("Pipeline completed successfully in ", total, "s.")
