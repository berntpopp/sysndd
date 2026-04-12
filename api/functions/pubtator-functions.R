# functions/pubtator-functions.R
#### PubTator DB update orchestrators (sync + async pipelines)
#### Client functions in pubtator-client.R, parser/transform in pubtator-parser.R
#### Split as part of D3 refactor

require(tidyverse)
require(jsonlite)
require(logger)
require(DBI)
log_threshold(INFO)

# Load split modules if not already sourced (standalone loading, e.g. from tests).
# Use get_api_dir() (from test helper-paths.R) when available; fall back to
# relative "functions/" (works when wd is api/, i.e. normal API startup).
.funcs_dir <- tryCatch(file.path(get_api_dir(), "functions"), error = function(e) "functions")
if (!exists("pubtator_rate_limited_call", mode = "function")) {
  .p <- file.path(.funcs_dir, "pubtator-client.R")
  if (file.exists(.p)) source(.p, local = FALSE)
}
if (!exists("pubtator_parse_biocjson", mode = "function")) {
  .p <- file.path(.funcs_dir, "pubtator-parser.R")
  if (file.exists(.p)) source(.p, local = FALSE)
}
rm(.funcs_dir, .p)

# Load database helper functions for repository layer access (if not already loaded)
if (!exists("db_execute_query", mode = "function")) {
  if (file.exists("functions/db-helpers.R")) {
    source("functions/db-helpers.R", local = TRUE)
  }
}

#------------------------------------------------------------------------------
# MASTER FUNCTION: pubtator_db_update
#   - wraps DB writes in a transaction
#   - stores total_page_number and queried_page_number
#   - does rollback on error
#------------------------------------------------------------------------------
#' Store PubTator search & annotation results in DB (transaction + rollback on errors)
#'
#' @param db_host,db_port,db_name,db_user,db_password  Connection params
#' @param query          The PubTator query string
#' @param max_pages      Max pages to actually fetch (queried_page_number)
#' @param do_full_update If TRUE, purge old data for that query_hash
#'
#' @return The `query_id` used in the DB, or NULL on error
#' @export
pubtator_db_update <- function(
  db_host,
  db_port,
  db_name,
  db_user,
  db_password,
  query,
  max_pages = 10,
  do_full_update = FALSE,
  progress_fn = NULL
) {
  # Helper to report progress (safe no-op if no function provided)
  report_progress <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(
        progress_fn(step, message, current = current, total = total),
        error = function(e) NULL  # Don't let progress errors break the fetch
      )
    }
  }
  # A) Retrieve total_pages BEFORE transaction (no DB write needed)
  report_progress("query", "Querying PubTator API for total pages...", current = 0, total = max_pages)

  total_pages <- pubtator_v3_total_pages_from_query(query)
  if (is.null(total_pages) || total_pages == 0) {
    log_warn("No pages found for query: {query}. Aborting.")
    return(NULL) # Early return - no DB operations started
  }

  if (max_pages > total_pages) {
    log_info("max_pages={max_pages} > total_pages={total_pages}, adjusting.")
    max_pages <- total_pages
  }

  report_progress("init", sprintf("Found %d total pages, fetching up to %d...", total_pages, max_pages),
                  current = 0, total = max_pages)

  # B) Query hash
  q_hash <- generate_query_hash(query)
  log_info("Query hash = {q_hash}")

  # C) Wrap ALL database operations in a single transaction
  result <- tryCatch(
    {
      db_with_transaction(function(txn_conn) {
        # Check if query exists
        existing_query <- db_execute_query(
          "SELECT query_id, queried_page_number, total_page_number, page_size
         FROM pubtator_query_cache WHERE query_hash = ?",
          list(q_hash),
          conn = txn_conn
        )

        query_id <- NA_integer_
        old_queried_number <- 0

        if (nrow(existing_query) == 0) {
          # Insert new row
          log_info("No record for query_hash={q_hash}, inserting new row.")
          db_execute_statement(
            "INSERT INTO pubtator_query_cache
            (query_text, query_hash, total_page_number, queried_page_number, page_size)
           VALUES (?, ?, ?, ?, ?)",
            list(query, q_hash, total_pages, max_pages, 10),
            conn = txn_conn
          )
          query_id <- db_execute_query("SELECT LAST_INSERT_ID() AS id", conn = txn_conn)$id[1]
        } else {
          # Found existing row
          query_id <- existing_query$query_id[1]
          old_queried_number <- existing_query$queried_page_number[1]
          old_total_number <- existing_query$total_page_number[1]

          log_info("Found existing query_id={query_id}, old_queried_number={old_queried_number}")

          if (do_full_update) {
            log_info("do_full_update=TRUE => removing old records.")
            db_execute_statement(
              "DELETE FROM pubtator_search_cache WHERE query_id = ?",
              list(query_id),
              conn = txn_conn
            )
            db_execute_statement(
              "DELETE a FROM pubtator_annotation_cache a
             JOIN pubtator_search_cache s ON a.search_id = s.search_id
             WHERE s.query_id = ?",
              list(query_id),
              conn = txn_conn
            )
            db_execute_statement(
              "UPDATE pubtator_query_cache
             SET total_page_number=?, queried_page_number=?, page_size=?
             WHERE query_id=?",
              list(total_pages, max_pages, 10, query_id),
              conn = txn_conn
            )
            old_queried_number <- 0
          } else {
            # Partial update check
            if (max_pages <= old_queried_number) {
              log_info("Already up to page={old_queried_number}, no new fetch needed.")
              # Return query_id - transaction will auto-commit
              return(query_id) # Early return WITH commit
            }
            log_info("Partial update: old_queried_number={old_queried_number}, new max_pages={max_pages}")
          }
        }

        # D) Fetch new pages
        start_page <- if (!do_full_update && nrow(existing_query) > 0) {
          existing_query$queried_page_number[1] + 1
        } else {
          1
        }

        if (start_page <= max_pages) {
          report_progress("fetch", sprintf("Fetching pages %d-%d from PubTator API...", start_page, max_pages),
                          current = start_page - 1, total = max_pages)

          df_results <- pubtator_v3_pmids_from_request(
            query = query, start_page = start_page,
            max_pages = (max_pages - start_page + 1),
            progress_fn = progress_fn  # Pass through for per-page updates
          )

          if (!is.null(df_results) && nrow(df_results) > 0) {
            log_info("Inserting {nrow(df_results)} rows => pubtator_search_cache")

            df_insert <- df_results %>%
              mutate(
                query_id = query_id,
                id = if (!"id" %in% names(.)) NA_character_ else id,
                date = if ("date" %in% names(.)) sub("T.*", "", date) else NA_character_
              ) %>%
              select(query_id, id, pmid, doi, title, journal, date, score, text_hl)

            for (r in seq_len(nrow(df_insert))) {
              db_execute_statement(
                "INSERT INTO pubtator_search_cache
                (query_id, id, pmid, doi, title, journal, date, score, text_hl)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                unname(as.list(df_insert[r, ])),
                conn = txn_conn
              )
            }

            db_execute_statement(
              "UPDATE pubtator_query_cache
             SET queried_page_number=?, total_page_number=? WHERE query_id=?",
              list(max_pages, total_pages, query_id),
              conn = txn_conn
            )
          }
        }

        # E) Gather PMIDs and fetch annotations
        pmid_rows <- db_execute_query(
          "SELECT DISTINCT s.pmid
           FROM pubtator_search_cache s
           LEFT JOIN pubtator_annotation_cache a ON s.pmid = a.pmid
           WHERE s.query_id = ? AND s.pmid IS NOT NULL
             AND a.annotation_id IS NULL",
          list(query_id),
          conn = txn_conn
        )

        if (nrow(pmid_rows) == 0) {
          log_info("No PMIDs in search_cache => skip annotation fetch.")
          return(query_id) # Early return WITH commit
        }

        pmid_vector <- pmid_rows$pmid
        log_info("Found {length(pmid_vector)} unannotated PMIDs => fetching annotations...")
        report_progress("annotations", sprintf("Fetching annotations for %d PMIDs...", length(pmid_vector)),
                        current = max_pages, total = max_pages + 2)  # +2 for annotations + gene symbols

        # F) Fetch and insert annotations
        doc_list <- pubtator_v3_data_from_pmids(pmid_vector)
        if (is.null(doc_list) || length(doc_list) == 0) {
          log_warn("No annotation data => skipping annotation_cache insert.")
          return(query_id) # Early return WITH commit
        }

        flat_df <- flatten_pubtator_passages(doc_list) %>%
          mutate(pmid = as.integer(pmid))

        srch_map <- db_execute_query(
          "SELECT search_id, pmid FROM pubtator_search_cache WHERE query_id=?",
          list(query_id),
          conn = txn_conn
        )

        flat_df_j <- flat_df %>%
          left_join(srch_map, by = "pmid", relationship = "many-to-many")

        log_info("Inserting {nrow(flat_df_j)} annotation rows")

        df_ann <- flat_df_j %>%
          mutate(valid = if_else(valid == "TRUE", 1, 0, missing = 0)) %>%
          select(
            search_id, pmid, id, text, identifier, type, ncbi_homologene,
            valid, normalized, `database`, normalized_id, biotype, name, accession
          )

        for (r in seq_len(nrow(df_ann))) {
          db_execute_statement(
            "INSERT IGNORE INTO pubtator_annotation_cache
            (search_id, pmid, id, text, identifier, type, ncbi_homologene, valid,
             normalized, `database`, normalized_id, biotype, name, accession)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            unname(as.list(df_ann[r, ])),
            conn = txn_conn
          )
        }

        # G) Compute and store human gene symbols per search_id
        report_progress("genes", "Computing human gene symbols...",
                        current = max_pages + 1, total = max_pages + 2)
        compute_pubtator_gene_symbols(query_id, conn = txn_conn)

        log_info("All done => returning query_id={query_id}")
        query_id # Return value - transaction auto-commits
      }, pool_obj = pool)
    },
    error = function(e) {
      # Transaction auto-rolled back by db_with_transaction
      log_error(skip_formatter(paste("pubtator_db_update: Error =>", e$message)))
      return(NULL)
    }
  )

  return(result)
}


#------------------------------------------------------------------------------
# ASYNC VERSION: pubtator_db_update_async
#   - Designed for mirai daemons (no pool dependency)
#   - Creates its own database connection
#   - Transaction handling via DBI directly
#------------------------------------------------------------------------------
#' Store PubTator results in DB (async/daemon version with direct connection)
#'
#' This version is designed for use in mirai daemons where the global pool
#' is not available. It creates its own database connection and uses direct
#' DBI operations instead of pool-based helpers.
#'
#' @param db_config List with db_host, db_port, db_name, db_user, db_password
#' @param query The PubTator query string
#' @param max_pages Max pages to fetch
#' @param do_full_update If TRUE, clear existing cache first
#' @param progress_fn Optional progress reporting function
#'
#' @return List with success status, query_id, and message
#' @export
pubtator_db_update_async <- function(db_config, query, max_pages = 10,
                                      do_full_update = FALSE, progress_fn = NULL) {
  # Helper to report progress
  report_progress <- function(step, message, current = NULL, total = NULL) {
    if (!is.null(progress_fn) && is.function(progress_fn)) {
      tryCatch(progress_fn(step, message, current = current, total = total), error = function(e) NULL)
    }
  }

  report_progress("init", "Querying PubTator API...", current = 0, total = max_pages)

  # A) Get total pages from API (no DB needed)
  total_pages <- pubtator_v3_total_pages_from_query(query)
  if (is.null(total_pages) || total_pages == 0) {
    log_warn("No pages found for query: {query}")
    return(list(success = FALSE, query_id = NULL, message = "No results found from PubTator API"))
  }

  if (max_pages > total_pages) {
    max_pages <- total_pages
  }

  q_hash <- generate_query_hash(query)
  log_info("Query hash = {q_hash}, total_pages = {total_pages}, max_pages = {max_pages}")

  report_progress("connect", "Connecting to database...", current = 0, total = max_pages)

  # B) Create direct database connection
  conn <- tryCatch(
    DBI::dbConnect(
      RMariaDB::MariaDB(),
      dbname = db_config$db_name,
      host = db_config$db_host,
      user = db_config$db_user,
      password = db_config$db_password,
      port = db_config$db_port
    ),
    error = function(e) {
      log_error(skip_formatter(paste("Failed to connect to database:", e$message)))
      return(NULL)
    }
  )

  if (is.null(conn)) {
    return(list(success = FALSE, query_id = NULL, message = "Database connection failed"))
  }

  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  # C) Begin transaction
  tryCatch({
    DBI::dbBegin(conn)

    # Check if query exists
    existing <- db_execute_query(
      "SELECT query_id, queried_page_number FROM pubtator_query_cache WHERE query_hash = ?",
      list(q_hash), conn = conn
    )

    query_id <- NA_integer_
    old_queried <- 0

    if (nrow(existing) == 0) {
      # Insert new query
      log_info("Inserting new query record for hash: {q_hash}")
      db_execute_statement(
        "INSERT INTO pubtator_query_cache
         (query_text, query_hash, total_page_number, queried_page_number, page_size)
         VALUES (?, ?, ?, ?, 10)",
        list(query, q_hash, total_pages, max_pages), conn = conn
      )
      query_id <- db_execute_query(
        "SELECT LAST_INSERT_ID() AS id", list(), conn = conn
      )$id[1]
    } else {
      query_id <- existing$query_id[1]
      old_queried <- existing$queried_page_number[1]
      log_info("Found existing query_id={query_id}, old_queried={old_queried}")

      if (do_full_update) {
        log_info("Hard update: clearing existing data")
        # Delete old data (annotations first due to FK-like relationship)
        db_execute_statement(
          "DELETE a FROM pubtator_annotation_cache a
           JOIN pubtator_search_cache s ON a.search_id = s.search_id
           WHERE s.query_id = ?",
          list(query_id), conn = conn
        )
        db_execute_statement(
          "DELETE FROM pubtator_search_cache WHERE query_id = ?",
          list(query_id), conn = conn
        )
        db_execute_statement(
          "UPDATE pubtator_query_cache
           SET total_page_number = ?, queried_page_number = ? WHERE query_id = ?",
          list(total_pages, max_pages, query_id), conn = conn
        )
        old_queried <- 0
      } else if (max_pages <= old_queried) {
        log_info("Cache hit: already have {old_queried} pages")
        DBI::dbCommit(conn)
        return(list(success = TRUE, query_id = query_id,
                    message = sprintf("Cache hit - already have %d pages", old_queried)))
      }
    }

    # D) Fetch new pages
    start_page <- if (!do_full_update && nrow(existing) > 0) old_queried + 1 else 1

    if (start_page <= max_pages) {
      report_progress("fetch", sprintf("Fetching pages %d-%d...", start_page, max_pages),
                      current = start_page - 1, total = max_pages)

      df_results <- pubtator_v3_pmids_from_request(
        query = query, start_page = start_page,
        max_pages = (max_pages - start_page + 1),
        progress_fn = progress_fn
      )

      if (!is.null(df_results) && nrow(df_results) > 0) {
        log_info("Inserting {nrow(df_results)} publications")

        df_insert <- df_results %>%
          mutate(
            query_id = query_id,
            id = if (!"id" %in% names(.)) NA_character_ else id,
            date = if ("date" %in% names(.)) sub("T.*", "", date) else NA_character_
          ) %>%
          dplyr::select(query_id, id, pmid, doi, title, journal, date, score, text_hl)

        # Insert search results row by row (parameterized queries for security)
        for (r in seq_len(nrow(df_insert))) {
          row <- df_insert[r, ]
          db_execute_statement(
            "INSERT INTO pubtator_search_cache
             (query_id, id, pmid, doi, title, journal, date, score, text_hl)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            list(
              row$query_id,
              if (is.na(row$id)) NA else row$id,
              if (is.na(row$pmid)) NA else row$pmid,
              if (is.na(row$doi)) NA else row$doi,
              if (is.na(row$title)) NA else substr(row$title, 1, 500),
              if (is.na(row$journal)) NA else substr(row$journal, 1, 255),
              if (is.na(row$date)) NA else row$date,
              if (is.na(row$score)) NA else row$score,
              if (is.na(row$text_hl)) NA else substr(row$text_hl, 1, 5000)
            ),
            conn = conn
          )
        }

        db_execute_statement(
          "UPDATE pubtator_query_cache
           SET queried_page_number = ?, total_page_number = ? WHERE query_id = ?",
          list(max_pages, total_pages, query_id), conn = conn
        )
      }
    }

    # E) Fetch annotations for PMIDs
    report_progress("annotations", "Fetching annotations...", current = max_pages, total = max_pages + 1)

    pmid_rows <- db_execute_query(
      "SELECT DISTINCT s.pmid
       FROM pubtator_search_cache s
       LEFT JOIN pubtator_annotation_cache a ON s.pmid = a.pmid
       WHERE s.query_id = ? AND s.pmid IS NOT NULL
         AND a.annotation_id IS NULL",
      list(query_id), conn = conn
    )

    if (nrow(pmid_rows) > 0) {
      pmid_vector <- pmid_rows$pmid
      log_info("Fetching annotations for {length(pmid_vector)} unannotated PMIDs")

      doc_list <- pubtator_v3_data_from_pmids(pmid_vector)

      if (!is.null(doc_list) && length(doc_list) > 0) {
        flat_df <- flatten_pubtator_passages(doc_list) %>% mutate(pmid = as.integer(pmid))

        srch_map <- db_execute_query(
          "SELECT search_id, pmid FROM pubtator_search_cache WHERE query_id = ?",
          list(query_id), conn = conn
        )

        flat_df_j <- flat_df %>% left_join(srch_map, by = "pmid", relationship = "many-to-many")
        log_info("Inserting {nrow(flat_df_j)} annotations")

        df_ann <- flat_df_j %>%
          mutate(valid = if_else(valid == "TRUE", 1, 0, missing = 0)) %>%
          dplyr::select(search_id, pmid, id, text, identifier, type, ncbi_homologene,
                 valid, normalized, `database`, normalized_id, biotype, name, accession)

        for (r in seq_len(nrow(df_ann))) {
          row <- df_ann[r, ]
          db_execute_statement(
            "INSERT IGNORE INTO pubtator_annotation_cache
             (search_id, pmid, id, text, identifier, type, ncbi_homologene, valid,
              normalized, `database`, normalized_id, biotype, name, accession)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            list(
              if (is.na(row$search_id)) NA else row$search_id,
              if (is.na(row$pmid)) NA else row$pmid,
              if (is.na(row$id)) NA else substr(as.character(row$id), 1, 100),
              if (is.na(row$text)) NA else substr(as.character(row$text), 1, 500),
              if (is.na(row$identifier)) NA else substr(as.character(row$identifier), 1, 255),
              if (is.na(row$type)) NA else row$type,
              if (is.na(row$ncbi_homologene)) NA else row$ncbi_homologene,
              if (is.na(row$valid)) 0L else as.integer(row$valid),
              if (is.na(row$normalized)) NA else substr(as.character(row$normalized), 1, 100),
              if (is.na(row$`database`)) NA else substr(as.character(row$`database`), 1, 100),
              if (is.na(row$normalized_id)) NA else substr(as.character(row$normalized_id), 1, 100),
              if (is.na(row$biotype)) NA else substr(as.character(row$biotype), 1, 100),
              if (is.na(row$name)) NA else substr(as.character(row$name), 1, 255),
              if (is.na(row$accession)) NA else substr(as.character(row$accession), 1, 100)
            ),
            conn = conn
          )
        }
      }
    }

    # F) Compute gene symbols
    report_progress("genes", "Computing gene symbols...", current = max_pages + 1, total = max_pages + 1)
    compute_pubtator_gene_symbols(query_id, conn = conn)

    DBI::dbCommit(conn)
    log_info("PubTator update complete for query_id={query_id}")

    # Get final stats
    final_stats <- db_execute_query(
      "SELECT queried_page_number, total_page_number FROM pubtator_query_cache WHERE query_id = ?",
      list(query_id), conn = conn
    )

    pub_count <- db_execute_query(
      "SELECT COUNT(*) as cnt FROM pubtator_search_cache WHERE query_id = ?",
      list(query_id), conn = conn
    )$cnt[1]

    return(list(
      success = TRUE,
      query_id = query_id,
      pages_cached = final_stats$queried_page_number[1],
      pages_total = final_stats$total_page_number[1],
      publications_count = pub_count,
      message = sprintf(
        "Fetched %d pages (%d publications)",
        as.integer(final_stats$queried_page_number[1]),
        as.integer(pub_count)
      )
    ))

  }, error = function(e) {
    tryCatch(DBI::dbRollback(conn), error = function(e2) NULL)
    log_error(skip_formatter(paste("PubTator async update failed:", e$message)))
    return(list(success = FALSE, query_id = NULL, message = paste("Error:", e$message)))
  })
}
