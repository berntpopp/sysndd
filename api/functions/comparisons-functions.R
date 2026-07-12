# api/functions/comparisons-functions.R
#
# Core import logic for comparisons data refresh.
# Refactored from db/11_Rcommands_sysndd_db_table_database_comparisons.R
#
# This module handles:
# - Downloading data from 7+ external NDD databases
# - Resolving gene symbols to HGNC IDs via local database lookup
# - Resilient per-list database update: each source refreshes independently
#   (per-list replace); a failed source keeps its previous rows, and the refresh
#   only aborts when every source fails (see comparisons_refresh_outcome()).
#
# The per-source parsers + standardize_comparison_data live in the sibling
# functions/comparisons-parsers.R (extracted to keep both files < 600 lines).
#
# Key functions:
#   - comparisons_update_async(params): Main entry point for the durable worker
#   - download_source_data(source_config, temp_dir): Download single source
#   - resolve_hgnc_symbols(symbols, conn): Batch lookup HGNC IDs
#
# Usage:
#   Submitted via jobs_endpoints.R -> create_job(); run by the durable worker

library(DBI)
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(jsonlite)
library(tibble)

# Conditionally load pdftools (may not be installed in all environments)
if (requireNamespace("pdftools", quietly = TRUE)) {
  library(pdftools)
}

# Ensure the extracted per-source parsers are available. setup_workers.R sources
# comparisons-parsers.R before this file, but guard-source it too so any
# entrypoint that sources this file directly (unit tests, a future durable-worker
# path) still gets parse_* / standardize_comparison_data.
if (!exists("standardize_comparison_data", mode = "function")) {
  for (.cmp_parsers_path in c("functions/comparisons-parsers.R",
                              "/app/functions/comparisons-parsers.R")) {
    if (file.exists(.cmp_parsers_path)) {
      source(.cmp_parsers_path, local = FALSE)
      break
    }
  }
}

#' Download Source Data
#'
#' Downloads data from a single source URL to a temporary file.
#' Handles different file formats appropriately.
#'
#' @param source_config A single-row tibble with source_name, source_url, file_format
#' @param temp_dir Directory to save downloaded files
#' @param timeout_seconds Download timeout in seconds (default: 300)
#'
#' @return Path to downloaded file, or NULL on failure
#'
#' @export
download_source_data <- function(source_config, temp_dir, timeout_seconds = 300) {
  source_name <- source_config$source_name
  url <- source_config$source_url
  format <- source_config$file_format

  # Determine file extension
  ext <- switch(format,
    "pdf" = ".pdf",
    "csv.gz" = ".csv.gz",
    "csv" = ".csv",
    "tsv" = ".tsv",
    "json" = ".json",
    "txt" = ".txt",
    ".dat"  # fallback

)

  output_file <- file.path(temp_dir, paste0(source_name, ext))

  tryCatch({
    # Download with timeout
    old_timeout <- getOption("timeout")
    options(timeout = timeout_seconds)
    on.exit(options(timeout = old_timeout), add = TRUE)

    download.file(url, output_file, mode = "wb", quiet = TRUE)

    if (file.exists(output_file) && file.size(output_file) > 0) {
      return(output_file)
    } else {
      warning(sprintf("[%s] Downloaded file is empty or missing", source_name))
      return(NULL)
    }
  }, error = function(e) {
    warning(sprintf("[%s] Download failed: %s", source_name, e$message))
    return(NULL)
  })
}

#' Resolve HGNC Symbols to HGNC IDs
#'
#' Batch lookup of gene symbols to HGNC IDs using the normalized hgnc_symbol_lookup table.
#' Handles current symbols, previous symbols, and alias symbols with priority ordering.
#'
#' PERFORMANCE: Uses indexed temp table JOIN instead of O(n*m) nested loops.
#' Requires migration 008_hgnc_symbol_lookup to create the lookup table.
#'
#' @param symbols Character vector of gene symbols to resolve
#' @param conn Database connection
#'
#' @return Tibble with columns: symbol, hgnc_id
#'
#' @export
resolve_hgnc_symbols <- function(symbols, conn) {
  if (length(symbols) == 0) {
    return(tibble(symbol = character(), hgnc_id = character()))
  }

  # Ensure unique uppercase symbols

  unique_symbols <- unique(toupper(symbols))
  n_symbols <- length(unique_symbols)

  message(sprintf("[HGNC Resolution] Resolving %d unique symbols...", n_symbols))
  start_time <- Sys.time()

  # Check if optimized lookup table exists
  lookup_exists <- tryCatch({
    DBI::dbGetQuery(conn, "SELECT 1 FROM hgnc_symbol_lookup LIMIT 1")
    TRUE
  }, error = function(e) FALSE)

  if (lookup_exists) {
    # OPTIMIZED PATH: Use normalized lookup table with temp table JOIN
    # This is O(n) with indexed lookups instead of O(n*m) nested loops

    # Create temp table for batch lookup (avoids massive IN clause)
    temp_table <- sprintf("temp_symbols_%d", as.integer(Sys.time()) %% 100000)

    tryCatch({
      # Create temp table
      DBI::dbExecute(conn, sprintf("
        CREATE TEMPORARY TABLE %s (
          symbol VARCHAR(50) NOT NULL,
          INDEX idx_temp_symbol (symbol)
        )
      ", temp_table))

      # Batch insert symbols (chunk to avoid packet size limits)
      chunk_size <- 1000
      for (i in seq(1, n_symbols, by = chunk_size)) {
        chunk_end <- min(i + chunk_size - 1, n_symbols)
        chunk_symbols <- unique_symbols[i:chunk_end]

        # Build VALUES clause
        values <- paste(sprintf("('%s')", gsub("'", "''", chunk_symbols)), collapse = ",")
        DBI::dbExecute(conn, sprintf("INSERT INTO %s (symbol) VALUES %s", temp_table, values))
      }

      # Optimized query using JOIN with GROUP BY for priority
      # Priority: current (1) > previous (2) > alias (3)
      # First, get all matches with priority scores
      query <- sprintf("
        SELECT t.symbol, l.hgnc_id,
               CASE l.symbol_type
                 WHEN 'current' THEN 1
                 WHEN 'previous' THEN 2
                 WHEN 'alias' THEN 3
               END AS priority
        FROM %s t
        INNER JOIN hgnc_symbol_lookup l ON l.lookup_symbol = t.symbol
      ", temp_table)

      all_matches <- DBI::dbGetQuery(conn, query)

      # In R, select best match per symbol (faster than SQL GROUP BY with ORDER)
      if (nrow(all_matches) > 0) {
        matches <- as_tibble(all_matches) %>%
          group_by(symbol) %>%
          slice_min(priority, n = 1, with_ties = FALSE) %>%
          ungroup() %>%
          dplyr::select(symbol, hgnc_id)
      } else {
        matches <- tibble(symbol = character(), hgnc_id = character())
      }

      # Add unmatched symbols
      all_symbols <- DBI::dbGetQuery(conn, sprintf("SELECT symbol FROM %s", temp_table))
      matches <- tibble(symbol = all_symbols$symbol) %>%
        left_join(matches, by = "symbol")

      # Clean up temp table
      DBI::dbExecute(conn, sprintf("DROP TEMPORARY TABLE IF EXISTS %s", temp_table))

    }, error = function(e) {
      # Clean up on error
      tryCatch(
        DBI::dbExecute(conn, sprintf("DROP TEMPORARY TABLE IF EXISTS %s", temp_table)),
        error = function(e2) NULL
      )
      stop(e)
    })

  } else {
    # FALLBACK PATH: Direct lookup without normalized table (slower but works)
    # This path is used if migration 008 hasn't been run
    message("[HGNC Resolution] Warning: hgnc_symbol_lookup table not found, using slower fallback")

    # Direct symbol lookup using indexed column
    placeholders <- paste(rep("?", n_symbols), collapse = ",")
    query <- sprintf("
      SELECT UPPER(symbol) as symbol, hgnc_id
      FROM non_alt_loci_set
      WHERE UPPER(symbol) IN (%s)
    ", placeholders)

    stmt <- DBI::dbSendQuery(conn, query)
    DBI::dbBind(stmt, as.list(unique_symbols))
    matches <- DBI::dbFetch(stmt)
    DBI::dbClearResult(stmt)
  }

  matches <- as_tibble(matches)

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  matched_count <- sum(!is.na(matches$hgnc_id))
  message(sprintf("[HGNC Resolution] Resolved %d/%d symbols in %.2f seconds",
                  matched_count, n_symbols, elapsed))

  # Join back to original symbols (preserving order and including unmatched)
  result <- tibble(symbol = toupper(symbols)) %>%
    left_join(matches, by = "symbol")

  return(result)
}

#' Comparisons Update Async
#'
#' Main async entry point for the comparisons data refresh job.
#' Submitted via create_job(); executed by the durable async worker.
#'
#' Downloads all active sources, parses, standardizes, resolves HGNC IDs,
#' merges, and atomically updates the database.
#'
#' Resilient per-list refresh: each source is downloaded/parsed independently;
#' a source that fails keeps its previously-imported rows (per-list replace), and
#' the refresh only aborts when every source fails. Status is "success" (all ok)
#' or "partial" (some failed), recorded in comparisons_metadata.
#'
#' @param params List containing:
#'   - .__job_id__: Job ID for progress reporting (injected by create_job)
#'   DB creds are resolved at run time via `async_job_db_connect()` (#535 S2b);
#'   the payload no longer carries `db_config`.
#'
#' @return List with status, sources_updated, rows_written
#'
#' @export
comparisons_update_async <- function(params) {
  job_id <- params$.__job_id__

  # Create progress reporter
  progress <- create_progress_reporter(job_id)

  # Initialize tracking variables
  temp_dir <- NULL
  conn <- NULL

  tryCatch({
    progress("init", "Initializing comparisons update...", current = 0, total = 10)

    # Create temp directory for downloads
    temp_dir <- tempfile(pattern = "comparisons_")
    dir.create(temp_dir, recursive = TRUE)

    # Create database connection — creds resolved at run time (#535 S2b).
    progress("connect", "Connecting to database...", current = 1, total = 10)
    conn <- async_job_db_connect()

    # Get active sources
    progress("config", "Loading source configuration...", current = 2, total = 10)
    sources <- get_active_sources(conn)

    if (nrow(sources) == 0) {
      stop("No active sources configured in comparisons_config table")
    }

    message(sprintf("[%s] [job:%s] Found %d active sources", Sys.time(), job_id, nrow(sources)))

    # Track downloaded files
    downloaded_files <- list()
    all_parsed_data <- list()
    # Sources that failed download or parse this run. They are NOT aborted on;
    # they keep their previously-imported rows via the per-list replace below.
    failed_sources <- character(0)
    import_date <- format(Sys.Date(), "%Y-%m-%d")

    # Download all sources
    for (i in seq_len(nrow(sources))) {
      source <- sources[i, ]
      source_name <- source$source_name
      progress_current <- 2 + i
      progress_total <- 2 + nrow(sources) + 3

      progress("download", sprintf("Downloading %s...", source_name),
               current = progress_current, total = progress_total)

      file_path <- download_source_data(source, temp_dir)

      if (is.null(file_path)) {
        # Resilient refresh: record the failure and keep going. This source
        # retains its previously-imported rows (per-list replace below) instead
        # of freezing every comparator because one upstream is down.
        failed_sources <- c(failed_sources, source_name)
        message(sprintf("[%s] [job:%s] Download FAILED for %s; keeping its previous data",
                        Sys.time(), job_id, source_name))
        next
      }

      downloaded_files[[source_name]] <- file_path
      message(sprintf("[%s] [job:%s] Downloaded %s to %s", Sys.time(), job_id, source_name, file_path))
    }

    # Parse and standardize each source
    progress("parse", "Parsing downloaded files...",
             current = 2 + nrow(sources) + 1, total = 2 + nrow(sources) + 3)

    for (i in seq_len(nrow(sources))) {
      source <- sources[i, ]
      source_name <- source$source_name
      file_path <- downloaded_files[[source_name]]

      # Skip deprecated sources that may remain if migrations haven't run
      deprecated_sources <- c("phenotype_hpoa", "omim_genemap2",
                              "hpo_phenotype_to_genes")
      if (source_name %in% deprecated_sources) {
        message(sprintf("[%s] [job:%s] Skipping deprecated source: %s",
                        Sys.time(), job_id, source_name))
        next
      }

      # Skip sources whose download failed above (already recorded as failed).
      if (is.null(file_path)) {
        next
      }

      message(sprintf("[%s] [job:%s] Parsing %s...", Sys.time(), job_id, source_name))

      parsed_data <- tryCatch({
        switch(source_name,
          "radboudumc_ID" = parse_radboudumc_pdf(file_path),
          "gene2phenotype" = parse_gene2phenotype_csv(file_path),
          "panelapp" = parse_panelapp_tsv(file_path),
          "sfari" = parse_sfari_csv(file_path),
          "ndd_genehub" = parse_ndd_genehub_csv(file_path),
          "orphanet_id" = parse_orphanet_json(file_path),
          stop(sprintf("Unknown source: %s", source_name))
        )
      }, error = function(e) {
        # Resilient refresh: record the parse failure and keep going.
        message(sprintf("[%s] [job:%s] Parse FAILED for %s: %s; keeping its previous data",
                        Sys.time(), job_id, source_name, e$message))
        NULL
      })

      if (is.null(parsed_data)) {
        failed_sources <- c(failed_sources, source_name)
      } else if (nrow(parsed_data) > 0) {
        # Standardize the data
        standardized <- standardize_comparison_data(parsed_data, source_name, import_date)
        all_parsed_data[[source_name]] <- standardized
        message(sprintf("[%s] [job:%s] Parsed %d rows from %s", Sys.time(), job_id, nrow(standardized), source_name))
      }
    }

    # Parse OMIM via shared infrastructure (not in comparisons_config anymore)
    progress("parse_omim", "Parsing OMIM via shared infrastructure...",
             current = 2 + nrow(sources) + 1, total = 2 + nrow(sources) + 4)
    message(sprintf("[%s] [job:%s] Parsing omim_genemap2 via shared infrastructure...", Sys.time(), job_id))
    omim_parsed <- tryCatch({
      genemap2_path <- download_genemap2(output_path = "data/", force = FALSE)
      genemap2_data <- parse_genemap2(genemap2_path)
      ptg_path <- download_phenotype_to_genes(output_path = "data/", force = FALSE)
      # Honor the configured seed (OMIM_NDD_SEED_TERM) so the refresh matches
      # the db-prep script and the /comparisons/sources provenance (#502).
      parsed <- adapt_genemap2_for_comparisons(genemap2_data, ptg_path,
                                               seed_term = omim_ndd_seed_term())
      standardize_comparison_data(parsed, "omim_genemap2", import_date)
    }, error = function(e) {
      # Resilient refresh: OMIM needs OMIM_DOWNLOAD_KEY + external egress. If it
      # is unavailable, keep the previous omim_ndd rows instead of aborting the
      # whole refresh.
      message(sprintf("[%s] [job:%s] OMIM parse FAILED: %s; keeping previous omim_ndd data",
                      Sys.time(), job_id, e$message))
      NULL
    })
    if (is.null(omim_parsed)) {
      failed_sources <- c(failed_sources, "omim_genemap2")
    } else {
      all_parsed_data[["omim_genemap2"]] <- omim_parsed
      message(sprintf("[%s] [job:%s] Parsed %d rows from omim_genemap2", Sys.time(), job_id, nrow(omim_parsed)))
    }

    # Decide commit vs abort from which sources produced data. Never wipe the
    # table on a total outage; commit succeeded sources otherwise.
    outcome <- comparisons_refresh_outcome(names(all_parsed_data), unique(failed_sources))
    if (!isTRUE(outcome$commit)) {
      update_comparisons_metadata(conn, "failed", 0, 0, outcome$error)
      stop(outcome$error)
    }

    # Merge all data
    progress("merge", "Merging and resolving HGNC IDs...",
             current = 2 + nrow(sources) + 2, total = 2 + nrow(sources) + 4)

    merged_data <- bind_rows(all_parsed_data)

    if (nrow(merged_data) == 0) {
      update_comparisons_metadata(conn, "failed", 0, 0, "No rows parsed from any source")
      stop("No data parsed from any source")
    }

    message(sprintf(
      "[%s] [job:%s] Merged %d rows from %d source(s); %d failed (%s)",
      Sys.time(), job_id, nrow(merged_data), length(all_parsed_data),
      length(unique(failed_sources)),
      if (length(failed_sources)) paste(unique(failed_sources), collapse = ", ") else "none"
    ))

    # Resolve HGNC symbols - use unique symbols only to avoid duplication
    symbols_to_resolve <- unique(toupper(merged_data$symbol[!is.na(merged_data$symbol)]))
    resolved <- resolve_hgnc_symbols(symbols_to_resolve, conn)

    # Create unique lookup table (one hgnc_id per symbol)
    resolved_unique <- resolved %>%
      dplyr::select(symbol, resolved_hgnc = hgnc_id) %>%
      dplyr::distinct(symbol, .keep_all = TRUE)

    # Join resolved HGNC IDs back to data
    # Note: resolved$hgnc_id and non_alt_loci_set.hgnc_id already have "HGNC:" prefix
    merged_data <- merged_data %>%
      mutate(symbol = toupper(symbol)) %>%
      left_join(resolved_unique, by = "symbol") %>%
      mutate(
        hgnc_id = case_when(
          !is.na(resolved_hgnc) ~ resolved_hgnc,  # Already has "HGNC:" prefix
          TRUE ~ hgnc_id
        )
      ) %>%
      dplyr::select(-resolved_hgnc) %>%
      # Get symbol from HGNC table for resolved genes
      left_join(
        DBI::dbGetQuery(conn, "SELECT hgnc_id, symbol AS resolved_symbol FROM non_alt_loci_set"),
        by = "hgnc_id"  # Both already have "HGNC:" prefix
      ) %>%
      mutate(symbol = coalesce(resolved_symbol, symbol)) %>%
      dplyr::select(-resolved_symbol) %>%
      # Filter out rows without HGNC ID. (comparison_id is AUTO_INCREMENT and is
      # intentionally NOT assigned here so the per-list replace below never
      # collides with rows retained from sources that were not refreshed.)
      filter(!is.na(hgnc_id) & hgnc_id != "HGNC:NA")

    message(sprintf("[%s] [job:%s] Final dataset: %d rows with HGNC IDs", Sys.time(), job_id, nrow(merged_data)))

    # Only replace the lists we successfully refreshed; failed sources keep their
    # existing rows.
    refreshed_lists <- unique(merged_data$list[!is.na(merged_data$list)])

    # Write to database atomically
    progress("write", "Writing to database...",
             current = 2 + nrow(sources) + 3, total = 2 + nrow(sources) + 4)

    # Per-list atomic replacement: DELETE(refreshed lists) + INSERT in a txn
    tryCatch({
      DBI::dbBegin(conn)

      # Delete only the successfully-refreshed lists (never a blanket wipe).
      if (length(refreshed_lists) > 0) {
        placeholders <- paste(rep("?", length(refreshed_lists)), collapse = ", ")
        del_stmt <- DBI::dbSendStatement(
          conn,
          sprintf("DELETE FROM ndd_database_comparison WHERE list IN (%s)", placeholders)
        )
        DBI::dbBind(del_stmt, unname(as.list(refreshed_lists)))
        DBI::dbClearResult(del_stmt)
      }

      # Insert new data (let the DB assign comparison_id via AUTO_INCREMENT).
      if (nrow(merged_data) > 0) {
        table_cols <- DBI::dbListFields(conn, "ndd_database_comparison")
        insert_data <- merged_data %>%
          dplyr::select(any_of(setdiff(table_cols, "comparison_id")))

        DBI::dbAppendTable(conn, "ndd_database_comparison", insert_data)
      }

      # Update metadata (success or partial, with the failed-source warning)
      update_comparisons_metadata(conn, outcome$status, length(all_parsed_data),
                                  nrow(merged_data), outcome$error)

      # Update source timestamps for the sources that refreshed
      for (source_name in names(all_parsed_data)) {
        # Skip omim_genemap2 (not in comparisons_config table anymore)
        if (source_name == "omim_genemap2") {
          next
        }
        update_source_last_updated(conn, source_name)
      }

      DBI::dbCommit(conn)

    }, error = function(e) {
      DBI::dbRollback(conn)
      update_comparisons_metadata(conn, "failed", length(all_parsed_data), 0,
                                  sprintf("Database write failed: %s", e$message))
      stop(sprintf("Database write failed: %s", e$message))
    })

    message(sprintf("[%s] [job:%s] Comparisons update %s: %d rows from %d source(s), %d failed",
                    Sys.time(), job_id, outcome$status, nrow(merged_data),
                    length(all_parsed_data), length(unique(failed_sources))))

    # Return result (status is "success" or "partial")
    list(
      status = "completed",
      refresh_status = outcome$status,
      sources_updated = length(all_parsed_data),
      sources_failed = length(unique(failed_sources)),
      failed_sources = unique(failed_sources),
      rows_written = nrow(merged_data),
      message = if (identical(outcome$status, "partial")) {
        sprintf("Updated %d rows from %d source(s); %s",
                nrow(merged_data), length(all_parsed_data), outcome$error)
      } else {
        sprintf("Successfully updated %d rows from %d sources",
                nrow(merged_data), length(all_parsed_data))
      }
    )

  }, error = function(e) {
    message(sprintf("[%s] [job:%s] Comparisons update failed: %s", Sys.time(), job_id, e$message))
    stop(e)

  }, finally = {
    # Cleanup temp directory
    if (!is.null(temp_dir) && dir.exists(temp_dir)) {
      unlink(temp_dir, recursive = TRUE)
    }

    # Close database connection
    if (!is.null(conn) && DBI::dbIsValid(conn)) {
      DBI::dbDisconnect(conn)
    }
  })
}
