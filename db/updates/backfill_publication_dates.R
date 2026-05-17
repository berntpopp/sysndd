#!/usr/bin/env Rscript
# backfill_publication_dates.R
#
# One-off operator script. Re-fetches PubMed metadata for every publication
# linked to a primary-approved review and corrects publication.Publication_date
# and publication.publication_date_source using the fixed date parser
# (resolve_pubmed_date / info_from_pmid).
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
  NA_integer_
}
if (!is.na(row_limit) && row_limit < 1L) {
  stop("--limit must be a positive integer")
}
chunk_size <- as.integer(Sys.getenv("BACKFILL_FETCH_CHUNK_SIZE", "200"))
if (is.na(chunk_size) || chunk_size < 1L || chunk_size > 200L) {
  stop("BACKFILL_FETCH_CHUNK_SIZE must be between 1 and 200")
}
update_batch_size <- as.integer(Sys.getenv("BACKFILL_UPDATE_BATCH_SIZE", "250"))
if (is.na(update_batch_size) || update_batch_size < 1L) {
  stop("BACKFILL_UPDATE_BATCH_SIZE must be a positive integer")
}
single_request_delay <- as.numeric(Sys.getenv("NCBI_REQUEST_DELAY_SECONDS", "0.34"))
chunk_request_delay <- as.numeric(Sys.getenv("NCBI_CHUNK_DELAY_SECONDS", "0.34"))

api_dir <- Sys.getenv("SYSNDD_API_DIR", "api")
if (!dir.exists(api_dir) && dir.exists("/app")) api_dir <- "/app"
source(file.path(api_dir, "functions", "publication-functions.R"))

con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  host = Sys.getenv("MYSQL_HOST", "mysql"),
  port = as.integer(Sys.getenv("MYSQL_PORT", "3306")),
  dbname = Sys.getenv("MYSQL_DATABASE", "sysndd_db"),
  user = Sys.getenv("MYSQL_USER", "bernt"),
  password = Sys.getenv("MYSQL_PASSWORD", "changeme")
)
lock_acquired <- FALSE
disconnected <- FALSE
cleanup <- function() {
  if (isTRUE(disconnected)) return(invisible(NULL))
  if (isTRUE(lock_acquired)) {
    suppressWarnings(try({
      res <- DBI::dbSendQuery(con, "SELECT RELEASE_LOCK('sysndd_backfill_publication_dates')")
      on.exit(try(DBI::dbClearResult(res), silent = TRUE), add = TRUE)
      DBI::dbFetch(res)
      lock_acquired <<- FALSE
    }, silent = TRUE))
  }
  suppressWarnings(DBI::dbDisconnect(con))
  disconnected <<- TRUE
  invisible(NULL)
}
on.exit(cleanup(), add = TRUE)

has_column <- DBI::dbGetQuery(con, "
  SELECT COUNT(*) n
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'publication_date_source'")$n[[1]]
if (!identical(as.integer(has_column), 1L)) {
  stop("publication.publication_date_source column is missing; apply migration 021 first")
}

lock_row <- DBI::dbGetQuery(con, "SELECT GET_LOCK('sysndd_backfill_publication_dates', 0) AS acquired")
if (!identical(as.integer(lock_row$acquired[[1]]), 1L)) {
  stop("another publication-date backfill appears to be running")
}
lock_acquired <- TRUE

linked <- DBI::dbGetQuery(con, "
  SELECT DISTINCT p.publication_id, p.Publication_date AS old_date,
         p.publication_date_source AS old_source
  FROM publication p
  JOIN ndd_review_publication_join rpj
    ON rpj.publication_id = p.publication_id AND rpj.is_reviewed = 1
  JOIN ndd_entity_review er
    ON er.review_id = rpj.review_id AND er.is_primary = 1 AND er.review_approved = 1
  WHERE p.publication_date_source IS NULL
     OR p.publication_date_source NOT IN ('pubmed', 'pubmed_partial', 'medline_date', 'unknown')")
if (!is.na(row_limit)) {
  linked <- utils::head(linked, row_limit)
}

message(sprintf("[backfill] %d linked publications to re-check (dry_run=%s, chunk_size=%d)",
                nrow(linked), dry_run, chunk_size))

skipped <- character()
fetch_one <- function(publication_id) {
  on.exit(Sys.sleep(single_request_delay), add = TRUE)
  tryCatch(
    {
      row <- info_from_pmid(publication_id)
      row$publication_id <- paste0("PMID:", sub("^PMID:", "", publication_id))
      row
    },
    publication_fetch_error = function(e) {
      skipped <<- c(skipped, publication_id)
      message(sprintf("[backfill] skipped %s: %s", publication_id, e$message))
      tibble::tibble()
    },
    error = function(e) {
      skipped <<- c(skipped, publication_id)
      message(sprintf("[backfill] skipped %s: %s", publication_id, conditionMessage(e)))
      tibble::tibble()
    }
  )
}

fetch_chunk <- function(publication_ids) {
  tryCatch(
    {
      rows <- info_from_pmid(publication_ids)
      rows$publication_id <- paste0("PMID:", sub("^PMID:", "", publication_ids))
      Sys.sleep(chunk_request_delay)
      rows
    },
    publication_fetch_error = function(e) {
      purrr::map_dfr(publication_ids, fetch_one)
    },
    error = function(e) {
      purrr::map_dfr(publication_ids, fetch_one)
    }
  )
}

chunks <- split(linked$publication_id, ceiling(seq_along(linked$publication_id) / chunk_size))
fetched <- if (nrow(linked) == 0L) tibble::tibble() else purrr::map_dfr(chunks, fetch_chunk)

merged <- linked %>%
  dplyr::left_join(
    fetched %>% dplyr::select(publication_id, Publication_date, publication_date_source),
    by = "publication_id"
  ) %>%
  dplyr::filter(!is.na(Publication_date) | !is.na(publication_date_source)) %>%
  dplyr::mutate(changed = is.na(old_date) | as.character(old_date) != Publication_date |
                  is.na(old_source) | old_source != publication_date_source)

to_update <- merged %>% dplyr::filter(changed)
message(sprintf("[backfill] %d rows fetched; %d rows skipped",
                nrow(fetched), length(unique(skipped))))
message(sprintf("[backfill] %d rows would change", nrow(to_update)))
for (i in seq_len(min(nrow(to_update), 20L))) {
  r <- to_update[i, ]
  message(sprintf("  %s: %s -> %s (%s)", r$publication_id,
                  r$old_date, r$Publication_date, r$publication_date_source))
}

if (dry_run) {
  message("[backfill] dry-run: no rows written. Re-run with --apply to write.")
} else {
  upd <- "UPDATE publication SET Publication_date = ?, publication_date_source = ? WHERE publication_id = ?"
  update_chunks <- split(seq_len(nrow(to_update)),
                         ceiling(seq_len(nrow(to_update)) / update_batch_size))
  for (chunk_idx in seq_along(update_chunks)) {
    rows <- update_chunks[[chunk_idx]]
    DBI::dbWithTransaction(con, {
      for (i in rows) {
        r <- to_update[i, ]
        DBI::dbExecute(con, upd, params = unname(list(
          r$Publication_date, r$publication_date_source, r$publication_id
        )))
      }
    })
    message(sprintf("[backfill] committed update batch %d/%d (%d rows)",
                    chunk_idx, length(update_chunks), length(rows)))
  }
  message(sprintf("[backfill] applied %d updates", nrow(to_update)))
}

cleanup()
