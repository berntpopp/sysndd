#!/usr/bin/env Rscript
# backfill_publication_dates.R
#
# One-off operator CLI wrapper. Re-fetches PubMed metadata for every publication
# linked to a primary-approved review and corrects publication.Publication_date
# and publication.publication_date_source using the fixed date parser
# (resolve_pubmed_date / info_from_pmid).
#
# The selection / fetch / write logic lives in the shared function
# backfill_publication_dates_run() (api/functions/publication-date-backfill.R),
# which is also executed by the durable `publication_date_backfill` async job, so
# the operator CLI and the worker share one source of truth.
#
# Requires: db/migrations/021_add_publication_date_source.sql applied,
#           outbound network egress to NCBI E-utilities.
#
# Usage:
#   Rscript db/updates/backfill_publication_dates.R --dry-run --limit=25
#   Rscript db/updates/backfill_publication_dates.R --dry-run
#   Rscript db/updates/backfill_publication_dates.R --apply
#
# Run from the repo root or inside the API container.

suppressWarnings(suppressMessages({
  library(DBI)
  library(RMariaDB)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(tibble)
  library(tidyr)
  library(xml2)
}))

args <- commandArgs(trailingOnly = TRUE)
if ("--help" %in% args) {
  cat("Usage: Rscript db/updates/backfill_publication_dates.R [--dry-run] [--apply] [--limit=N]\n")
  quit(status = 0)
}
dry_run <- !("--apply" %in% args)
limit_arg <- grep("^--limit=", args, value = TRUE)
row_limit <- if (length(limit_arg) > 0L) {
  suppressWarnings(as.integer(sub("^--limit=", "", limit_arg[[1]])))
} else {
  NULL
}
if (!is.null(row_limit) && (is.na(row_limit) || row_limit < 1L)) {
  stop("--limit must be a positive integer")
}

api_dir <- Sys.getenv("SYSNDD_API_DIR", "api")
if (!dir.exists(api_dir) && dir.exists("/app")) api_dir <- "/app"
source(file.path(api_dir, "functions", "publication-functions.R"))
source(file.path(api_dir, "functions", "publication-date-backfill.R"))

con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  host = Sys.getenv("MYSQL_HOST", "mysql"),
  port = as.integer(Sys.getenv("MYSQL_PORT", "3306")),
  dbname = Sys.getenv("MYSQL_DATABASE", "sysndd_db"),
  user = Sys.getenv("MYSQL_USER", "bernt"),
  password = Sys.getenv("MYSQL_PASSWORD", "changeme")
)
on.exit(suppressWarnings(DBI::dbDisconnect(con)), add = TRUE)

has_column <- DBI::dbGetQuery(con, "
  SELECT COUNT(*) n
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'publication_date_source'")$n[[1]]
if (!identical(as.integer(has_column), 1L)) {
  stop("publication.publication_date_source column is missing; apply migration 021 first")
}

message(sprintf("[backfill] starting (dry_run=%s, limit=%s)",
                dry_run, if (is.null(row_limit)) "none" else row_limit))

summary <- backfill_publication_dates_run(
  con,
  limit = row_limit,
  dry_run = dry_run,
  progress = function(step, message, current = NULL, total = NULL) {
    base::message(sprintf("[backfill] %s: %s", step, message))
  }
)

if (!is.null(summary$skipped)) {
  message(sprintf("[backfill] skipped: %s (another backfill is running)", summary$skipped))
} else if (isTRUE(summary$dry_run)) {
  message(sprintf("[backfill] dry-run: %d publications would be re-checked. Re-run with --apply to write.",
                  summary$targeted))
} else {
  message(sprintf(
    "[backfill] done: targeted=%d verified=%d partial=%d unresolved=%d",
    summary$targeted, summary$verified, summary$partial, summary$unresolved
  ))
}
