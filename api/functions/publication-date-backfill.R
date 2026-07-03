## -------------------------------------------------------------------##
# api/functions/publication-date-backfill.R
#
# Shared verified-date backfill logic (#460). Re-fetches PubMed metadata for
# publications linked to a primary-approved review whose
# publication.publication_date_source is NULL/invalid, and corrects both
# publication.Publication_date and publication.publication_date_source using the
# fixed date parser (resolve_pubmed_date / info_from_pmid).
#
# One source of truth shared by:
#   - the operator CLI wrapper db/updates/backfill_publication_dates.R, and
#   - the durable `publication_date_backfill` async job (worker-executed).
#
# Framed generically: makes literature publication dates temporally/provenance
# queryable through the API/MCP once their source is verified. Unresolvable PMIDs
# stay NULL/`unknown` -> `unverified`. PubMed EUtils is the single source; the job
# carries its own chunking + NCBI rate-limit (it does not route through the public
# per-request external-time budget).
## -------------------------------------------------------------------##

#' Run the verified publication-date backfill against a connection.
#'
#' Single-flights via `GET_LOCK('sysndd_backfill_publication_dates', 0)`. Selects
#' primary-approved publications with a NULL/invalid `publication_date_source`,
#' chunk-fetches PubMed metadata (<=200/req, NCBI rate-limited, per-PMID fallback so
#' one bad PMID does not fail the chunk), and writes both `Publication_date` and
#' `publication_date_source` in a batched transaction.
#'
#' @param conn A live DBI connection (or pool-checked-out connection).
#' @param limit Optional integer cap on the number of targeted publications.
#' @param dry_run When TRUE, report the target count without fetching or writing.
#' @param progress Optional `function(step, message, current = NULL, total = NULL)`
#'   progress reporter (job-history visibility).
#' @param manage_transaction When TRUE (default; the worker handler and operator
#'   CLI, which both call with a fresh AUTOCOMMIT connection) each write batch owns
#'   its own `DBI::dbWithTransaction()`. When FALSE (the test harness, which already
#'   holds an open transaction via `with_test_db_transaction()`) the writes
#'   participate in the caller's transaction because MySQL forbids a nested
#'   `dbBegin`.
#' @param write_batch_size Integer number of rows committed per write batch, so
#'   partial progress persists across a mid-run failure/outage and a retry resumes.
#' @return list(targeted=, verified=, partial=, unresolved=, written=, dry_run=)
#'   and, on a benign single-flight skip, an additional `skipped = "lock_held"`.
#' @export
backfill_publication_dates_run <- function(conn, limit = NULL, dry_run = FALSE,
                                           progress = NULL,
                                           manage_transaction = TRUE,
                                           write_batch_size = 200L) {
  report <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress) && is.function(progress)) {
      tryCatch(progress(step, message, current = current, total = total),
               error = function(e) NULL)
    }
  }

  chunk_size <- 200L
  # NCBI rate-limit self-throttle. Key-aware (#494): ~3 req/s anonymous, faster
  # with an NCBI_API_KEY present. pubmed_min_request_interval() lives in
  # publication-functions.R (sourced by both the worker and the operator CLI).
  ncbi_delay <- if (exists("pubmed_min_request_interval", mode = "function")) {
    pubmed_min_request_interval()
  } else {
    0.34
  }

  # Single-flight lock (mirrors db/updates/backfill_publication_dates.R).
  lock_row <- DBI::dbGetQuery(
    conn, "SELECT GET_LOCK('sysndd_backfill_publication_dates', 0) AS acquired"
  )
  if (!identical(as.integer(lock_row$acquired[[1]]), 1L)) {
    # Benign skip: another backfill holds the lock. Completes successfully.
    return(list(
      targeted = 0L, verified = 0L, partial = 0L, unresolved = 0L,
      dry_run = isTRUE(dry_run), skipped = "lock_held"
    ))
  }
  on.exit({
    tryCatch(
      DBI::dbGetQuery(conn, "SELECT RELEASE_LOCK('sysndd_backfill_publication_dates')"),
      error = function(e) NULL
    )
  }, add = TRUE)

  # Target query (lifted verbatim from the standalone script): DISTINCT
  # publication_id of primary-approved publications with NULL/invalid source.
  report("select", "Selecting unverified primary-approved publications...")
  linked <- DBI::dbGetQuery(conn, "
    SELECT DISTINCT p.publication_id, p.Publication_date AS old_date,
           p.publication_date_source AS old_source
    FROM publication p
    JOIN ndd_review_publication_join rpj
      ON rpj.publication_id = p.publication_id AND rpj.is_reviewed = 1
    JOIN ndd_entity_review er
      ON er.review_id = rpj.review_id AND er.is_primary = 1 AND er.review_approved = 1
    WHERE p.publication_date_source IS NULL
       OR p.publication_date_source NOT IN ('pubmed', 'pubmed_partial', 'medline_date', 'unknown')")

  if (!is.null(limit) && !is.na(suppressWarnings(as.integer(limit)))) {
    linked <- utils::head(linked, as.integer(limit))
  }
  targeted <- nrow(linked)

  if (isTRUE(dry_run)) {
    return(list(
      targeted = targeted, verified = 0L, partial = 0L, unresolved = 0L,
      dry_run = TRUE
    ))
  }

  if (targeted == 0L) {
    return(list(
      targeted = 0L, verified = 0L, partial = 0L, unresolved = 0L, dry_run = FALSE
    ))
  }

  # Per-PMID fallback (lifted verbatim): a chunk error falls back to single-PMID
  # fetches so one bad PMID does not fail the whole chunk/job. Skips are split by
  # CAUSE (#500): a publication_fetch_error is a DATA condition (PMID fetched but
  # unresolvable / no parseable record, e.g. a withdrawn PMID) -> `unresolved`;
  # any other error is an INFRA condition (transport/HTTP/timeout) -> `failed`.
  # Only a wholesale infra outage (every targeted PMID failed) fails the job; a
  # batch that is entirely genuinely-unresolvable succeeds with unresolved counted.
  unresolved_ids <- character()
  unresolved_errors <- character()
  failed_ids <- character()
  failed_errors <- character()
  record_unresolved <- function(publication_id, e) {
    unresolved_ids <<- c(unresolved_ids, publication_id)
    unresolved_errors <<- c(unresolved_errors, conditionMessage(e))
    tibble::tibble()
  }
  record_failed <- function(publication_id, e) {
    failed_ids <<- c(failed_ids, publication_id)
    failed_errors <<- c(failed_errors, conditionMessage(e))
    tibble::tibble()
  }
  fetch_one <- function(publication_id) {
    on.exit(Sys.sleep(ncbi_delay), add = TRUE)
    tryCatch(
      {
        row <- info_from_pmid(publication_id)
        row$publication_id <- paste0("PMID:", sub("^PMID:", "", publication_id))
        row
      },
      publication_fetch_error = function(e) record_unresolved(publication_id, e),
      error = function(e) record_failed(publication_id, e)
    )
  }

  fetch_chunk <- function(publication_ids) {
    tryCatch(
      {
        rows <- info_from_pmid(publication_ids)
        rows$publication_id <- paste0("PMID:", sub("^PMID:", "", publication_ids))
        Sys.sleep(ncbi_delay)
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

  chunks <- split(
    linked$publication_id,
    ceiling(seq_along(linked$publication_id) / chunk_size)
  )
  total_chunks <- length(chunks)
  fetched <- purrr::map_dfr(seq_along(chunks), function(i) {
    report("fetch", sprintf("Fetching chunk %d/%d", i, total_chunks),
           current = i, total = total_chunks)
    fetch_chunk(chunks[[i]])
  })

  # On a total fetch outage every chunk returns an empty tibble, so `fetched`
  # has 0 columns and the select below would throw an opaque "column
  # publication_id doesn't exist" error before the systemic-failure check runs.
  # Normalize to the expected empty shape so the join yields all-NA (all
  # unresolved) and the observable classed failure fires instead.
  if (!("publication_id" %in% names(fetched))) {
    fetched <- tibble::tibble(
      publication_id = character(),
      Publication_date = as.Date(character()),
      publication_date_source = character()
    )
  }

  merged <- linked %>%
    dplyr::left_join(
      fetched %>% dplyr::select(publication_id, Publication_date, publication_date_source),
      by = "publication_id"
    ) %>%
    dplyr::filter(!is.na(Publication_date) | !is.na(publication_date_source)) %>%
    dplyr::mutate(changed = is.na(old_date) | as.character(old_date) != Publication_date |
                    is.na(old_source) | old_source != publication_date_source)

  to_update <- merged %>% dplyr::filter(changed)

  # Write the verified dates in committed batches (see backfill_write_updates).
  # Batched commits mean partial progress persists across a mid-run failure or
  # outage, and re-runs are idempotent because the target query above already
  # excludes rows whose publication_date_source is now valid. No SAVEPOINT probe:
  # the previous "am I in a transaction?" detection via a bare SAVEPOINT was
  # unreliable on a fresh AUTOCOMMIT connection and threw "SAVEPOINT ... does not
  # exist" at write time (#489).
  written <- 0L
  if (nrow(to_update) > 0L) {
    written <- backfill_write_updates(
      conn, to_update,
      manage_transaction = manage_transaction,
      write_batch_size = write_batch_size,
      report = report
    )
  }

  # Counters derive from the resolved publication_date_source over the targeted set
  # (pubmed -> verified; pubmed_partial/medline_date -> partial; NA/unknown/skipped
  # -> unresolved). verified + partial + unresolved == targeted.
  source_vec <- merged$publication_date_source
  verified <- sum(source_vec == "pubmed", na.rm = TRUE)
  partial <- sum(source_vec %in% c("pubmed_partial", "medline_date"), na.rm = TRUE)
  unresolved <- targeted - verified - partial

  all_skipped_ids <- unique(c(failed_ids, unresolved_ids))
  skipped_count <- length(all_skipped_ids)
  failed_count <- length(unique(failed_ids))
  unresolved_skip_count <- length(unique(unresolved_ids))

  # Fail observably only on a systemic TRANSPORT/INFRA outage: every targeted PMID
  # hit a non-classed error (NCBI down, worker egress broken, info_from_pmid
  # unavailable), nothing was written, and the run would otherwise report a false
  # "success". A batch that is entirely genuinely-unresolvable (parse-empty ->
  # publication_fetch_error, e.g. an all-GeneReviews/withdrawn target set) is a
  # DATA condition (#500): it completes as a success with 0 verified and N
  # unresolved, never a false systemic failure. Rows that resolved are persisted.
  if (targeted > 0L && failed_count >= targeted) {
    stop(structure(
      class = c("publication_backfill_systemic_failure", "error", "condition"),
      list(
        message = sprintf(
          paste0("verified publication-date backfill: all %d targeted PMIDs failed ",
                 "to fetch (systemic outage; no rows written). First error: %s"),
          targeted,
          if (length(failed_errors)) failed_errors[[1]] else "unknown"
        ),
        call = sys.call(-1)
      )
    ))
  }

  list(
    targeted = targeted,
    verified = as.integer(verified),
    partial = as.integer(partial),
    unresolved = as.integer(unresolved),
    written = as.integer(written),
    skipped_count = as.integer(skipped_count),
    failed_count = as.integer(failed_count),
    unresolved_skip_count = as.integer(unresolved_skip_count),
    skipped_pmids = utils::head(all_skipped_ids, 50L),
    failed_pmids = utils::head(unique(failed_ids), 50L),
    skipped_errors = utils::head(unique(c(failed_errors, unresolved_errors)), 5L),
    dry_run = FALSE
  )
}

#' Write verified publication-date updates to the DB in committed batches.
#'
#' Splits `to_update` into chunks of `write_batch_size` rows and applies each
#' chunk's `UPDATE publication ...` statements. When `manage_transaction` is TRUE
#' each batch is wrapped in its own `DBI::dbWithTransaction()`, so committed
#' progress persists across a mid-run failure/outage and a retry safely resumes
#' (the backfill target query already excludes rows whose `publication_date_source`
#' is now valid, so re-application is idempotent). When FALSE the UPDATEs run
#' directly on the caller's already-open transaction (MySQL forbids a nested
#' `dbBegin`; the test harness wraps the run in `with_test_db_transaction()`).
#'
#' Deliberately issues NO `SAVEPOINT` / `RELEASE SAVEPOINT` /
#' `ROLLBACK TO SAVEPOINT`: the previous transaction-probe via a bare SAVEPOINT was
#' unreliable on a fresh AUTOCOMMIT connection and produced
#' "SAVEPOINT ... does not exist" at write time (#489).
#'
#' @param conn A live DBI connection.
#' @param to_update Data frame with `Publication_date`, `publication_date_source`,
#'   and `publication_id` columns (one row per UPDATE).
#' @param manage_transaction When TRUE own one transaction per batch; when FALSE
#'   participate in the caller's open transaction.
#' @param write_batch_size Integer number of rows committed per batch.
#' @param report Optional `function(step, message, current = NULL, total = NULL)`
#'   progress reporter (per-batch progress).
#' @return Integer count of rows written.
#' @export
backfill_write_updates <- function(conn, to_update, manage_transaction = TRUE,
                                   write_batch_size = 200L, report = NULL) {
  total <- nrow(to_update)
  if (total == 0L) {
    return(0L)
  }

  reporter <- if (!is.null(report) && is.function(report)) {
    report
  } else {
    function(...) NULL
  }
  upd <- "UPDATE publication SET Publication_date = ?, publication_date_source = ? WHERE publication_id = ?"
  batch_size <- max(1L, as.integer(write_batch_size))
  batches <- split(seq_len(total), ceiling(seq_len(total) / batch_size))

  apply_rows <- function(row_indices) {
    for (i in row_indices) {
      r <- to_update[i, ]
      DBI::dbExecute(conn, upd, params = unname(list(
        r$Publication_date, r$publication_date_source, r$publication_id
      )))
    }
  }

  written <- 0L
  for (bi in seq_along(batches)) {
    row_indices <- batches[[bi]]
    if (isTRUE(manage_transaction)) {
      DBI::dbWithTransaction(conn, apply_rows(row_indices))
    } else {
      apply_rows(row_indices)
    }
    written <- written + length(row_indices)
    reporter("write",
             sprintf("Wrote %d/%d verified publication dates", written, total),
             current = written, total = total)
  }

  written
}
