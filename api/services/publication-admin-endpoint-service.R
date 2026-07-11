# api/services/publication-admin-endpoint-service.R
#
# Wave 3 / Task 2 (#346): extracted mutation/status bodies for
# api/endpoints/publication_endpoints.R. Every route here is Administrator-
# (or Curator-, for cache-status) gated; `require_role()`, the shared
# `query == ""` 400 guard, and the `/pubtator/update/submit` duplicate-job 409
# short-circuit stay in the endpoint shell (auditable at the routing layer,
# required by the existing static endpoint-contract tests). This file owns
# the request-processing logic behind those guards. All bindings are
# svc_-prefixed (see publication-query-endpoint-service.R for the shadowing
# rationale). Deps already loaded by bootstrap_load_modules(): db-helpers.R,
# pubtator-parser.R, pubtator-functions.R, job-manager.R, job-progress.R,
# logging-functions.R; `pool`/`dw` globals from start_sysndd_api.R.

#' Fetch the rows `svc_publication_backfill_genes()` needs to backfill.
#'
#' Separated from the update loop so the loop's counting/messaging logic is
#' host-testable with a fixed pair of tibbles (no live database).
#'
#' @param pool_obj A dbplyr-capable pool/connection.
#' @return List with `null_ids` and `gene_symbols_df` (computed per search_id).
#' @export
svc_publication_backfill_genes_fetch <- function(pool_obj) {
  null_ids <- pool_obj %>%
    dplyr::tbl("pubtator_search_cache") %>%
    dplyr::filter(is.na(gene_symbols)) %>%
    dplyr::select(search_id) %>%
    dplyr::collect()

  if (nrow(null_ids) == 0) {
    return(list(null_ids = null_ids, gene_symbols_df = dplyr::tibble()))
  }

  gene_symbols_df <- pool_obj %>%
    dplyr::tbl("pubtator_annotation_cache") %>%
    dplyr::filter(type == "Gene") %>%
    dplyr::inner_join(
      pool_obj %>% dplyr::tbl("non_alt_loci_set") %>% dplyr::select(entrez_id, symbol),
      by = c("normalized_id" = "entrez_id")
    ) %>%
    dplyr::filter(search_id %in% !!null_ids$search_id) %>%
    dplyr::select(search_id, symbol) %>%
    dplyr::collect() %>%
    dplyr::group_by(search_id) %>%
    dplyr::summarise(
      gene_symbols = paste(sort(unique(na.omit(symbol))), collapse = ","),
      .groups = "drop"
    ) %>%
    dplyr::filter(gene_symbols != "")

  list(null_ids = null_ids, gene_symbols_df = gene_symbols_df)
}

#' Backfill `gene_symbols` for existing PubTator cache rows.
#'
#' Body of `POST /pubtator/backfill-genes` (Administrator).
#'
#' @param pool_obj A dbplyr-capable pool/connection (default global `pool`).
#' @param execute_fn Injectable statement executor (default [db_execute_statement()]).
#' @param fetch_fn Injectable row fetcher (default [svc_publication_backfill_genes_fetch()]).
#' @return List with `updated`, `total_null`, `execution_time`, `message`.
#' @export
svc_publication_backfill_genes <- function(pool_obj = pool,
                                            execute_fn = db_execute_statement,
                                            fetch_fn = svc_publication_backfill_genes_fetch) {
  start_time <- Sys.time()
  fetched <- fetch_fn(pool_obj)
  null_ids <- fetched$null_ids

  if (nrow(null_ids) == 0) {
    return(list(
      updated = 0,
      message = "No rows need backfilling - all gene_symbols already populated"
    ))
  }

  gene_symbols_df <- fetched$gene_symbols_df
  updated_count <- 0
  if (nrow(gene_symbols_df) > 0) {
    for (r in seq_len(nrow(gene_symbols_df))) {
      execute_fn(
        "UPDATE pubtator_search_cache
         SET gene_symbols = ?
         WHERE search_id = ?",
        list(gene_symbols_df$gene_symbols[r], gene_symbols_df$search_id[r])
      )
      updated_count <- updated_count + 1
    }
  }

  end_time <- Sys.time()
  execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

  list(
    updated = updated_count,
    total_null = nrow(null_ids),
    execution_time = paste0(execution_time, " secs"),
    message = paste0(
      "Updated ", updated_count, " rows with gene symbols. ",
      nrow(null_ids) - updated_count, " rows had no human genes."
    )
  )
}

#' PubTator cache status for a query (`GET /pubtator/cache-status`, Curator).
#'
#' The `query == ""` 400 check and `require_role()` stay in the endpoint
#' shell; this covers the probe + cache lookup + response shaping.
#'
#' @param res Plumber response (`res$status` is set on a degraded upstream).
#' @param query The search query for PubTator.
#' @param total_pages_fn Injectable budget-bounded probe (default [pubtator_public_total_pages()]).
#' @param query_fn Injectable query function (default [db_execute_query()]).
#' @return List describing cache status, or the 503 error body.
#' @export
svc_publication_pubtator_cache_status <- function(res, query,
                                                   total_pages_fn = pubtator_public_total_pages,
                                                   query_fn = db_execute_query) {
  probe <- total_pages_fn(query)
  if (isTRUE(probe$error)) {
    res$status <- probe$status %||% 503L
    return(list(error = "PubTator is temporarily unavailable.", source = "pubtator"))
  }
  total_pages <- probe$total_pages

  q_hash <- generate_query_hash(query)
  cached <- query_fn(
    "SELECT query_id, queried_page_number, total_page_number, query_date
     FROM pubtator_query_cache WHERE query_hash = ?",
    list(q_hash)
  )

  if (nrow(cached) == 0) {
    return(list(
      query = query,
      cached = FALSE,
      pages_cached = 0,
      total_pages_available = total_pages,
      total_results_available = total_pages * 10,
      cache_date = NULL,
      estimated_fetch_time_minutes = round(total_pages * 2.5 / 60, 1),
      message = "No cache exists. Full fetch required."
    ))
  }

  pages_cached <- cached$queried_page_number[1]
  pages_remaining <- max(0, total_pages - pages_cached)

  pub_count <- query_fn(
    "SELECT COUNT(*) as cnt FROM pubtator_search_cache WHERE query_id = ?",
    list(cached$query_id[1])
  )$cnt[1]

  list(
    query = query,
    cached = TRUE,
    query_id = cached$query_id[1],
    pages_cached = pages_cached,
    publications_cached = pub_count,
    total_pages_available = total_pages,
    total_results_available = total_pages * 10,
    pages_remaining = pages_remaining,
    cache_date = as.character(cached$query_date[1]),
    estimated_fetch_time_minutes = round(pages_remaining * 2.5 / 60, 1),
    message = if (pages_remaining == 0) {
      "Cache is complete. Use clear_old=true to refresh."
    } else {
      paste0("Soft update will fetch ", pages_remaining, " new pages.")
    }
  )
}

#' Count publications/annotations captured by a PubTator update.
#'
#' Separated from [svc_publication_pubtator_update()] so the surrounding
#' response shaping is host-testable with a fixed count pair.
#'
#' @param query_id The `pubtator_query_cache` query_id to count for.
#' @param pool_obj A dbplyr-capable pool/connection.
#' @return List with `search_count` and `annotation_count`.
#' @export
svc_publication_pubtator_update_counts <- function(query_id, pool_obj = pool) {
  search_count <- pool_obj %>%
    dplyr::tbl("pubtator_search_cache") %>%
    dplyr::filter(query_id == !!query_id) %>%
    dplyr::count() %>%
    dplyr::collect() %>%
    dplyr::pull(n)

  search_ids_tbl <- pool_obj %>%
    dplyr::tbl("pubtator_search_cache") %>%
    dplyr::filter(query_id == !!query_id) %>%
    dplyr::select(search_id)

  annotation_count <- pool_obj %>%
    dplyr::tbl("pubtator_annotation_cache") %>%
    dplyr::inner_join(search_ids_tbl, by = "search_id") %>%
    dplyr::count() %>%
    dplyr::collect() %>%
    dplyr::pull(n)

  list(search_count = search_count, annotation_count = annotation_count)
}

#' Trigger a synchronous PubTator search/store (`POST /pubtator/update`, Administrator).
#'
#' The `query == ""` 400 check and `require_role()` stay in the endpoint shell.
#'
#' @param req,res Plumber request/response.
#' @param query The search query for PubTator.
#' @param max_pages Maximum pages to fetch.
#' @param clear_old Hard update - clear existing cache first.
#' @param update_fn Injectable updater (default [pubtator_db_update()]).
#' @param query_fn Injectable query function (default [db_execute_query()]).
#' @param counts_fn Injectable post-update counter (default [svc_publication_pubtator_update_counts()]).
#' @return List with query_id, cache info, and statistics.
#' @export
svc_publication_pubtator_update <- function(req, res, query,
                                             max_pages = 10, clear_old = FALSE,
                                             update_fn = pubtator_db_update,
                                             query_fn = db_execute_query,
                                             counts_fn = svc_publication_pubtator_update_counts) {
  start_time <- Sys.time()
  max_pages <- as.integer(max_pages)
  clear_old <- as.logical(clear_old)
  log_info("PubTator update requested: query='{query}', max_pages={max_pages}, clear_old={clear_old}")

  q_hash <- generate_query_hash(query)
  cached_before <- query_fn(
    "SELECT query_id, queried_page_number FROM pubtator_query_cache WHERE query_hash = ?",
    list(q_hash)
  )
  pages_before <- if (nrow(cached_before) > 0) cached_before$queried_page_number[1] else 0

  tryCatch({
      query_id <- update_fn(
        db_host = dw$db_host,
        db_port = dw$db_port,
        db_name = dw$db_name,
        db_user = dw$db_user,
        db_password = dw$db_password,
        query = query,
        max_pages = max_pages,
        do_full_update = clear_old
      )
      end_time <- Sys.time()
      execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)
      if (is.null(query_id)) {
        return(list(
          success = FALSE,
          message = "No results found or error occurred",
          execution_time = paste0(execution_time, " secs")
        ))
      }

      cached_after <- query_fn(
        "SELECT queried_page_number, total_page_number FROM pubtator_query_cache WHERE query_id = ?",
        list(query_id)
      )
      pages_after <- cached_after$queried_page_number[1]
      total_pages <- cached_after$total_page_number[1]
      pages_fetched <- if (clear_old) pages_after else max(0, pages_after - pages_before)
      cache_hit <- pages_fetched == 0
      counts <- counts_fn(query_id)

      list(
        success = TRUE,
        query_id = query_id,
        query = query,
        update_type = if (clear_old) "hard" else "soft",
        cache_hit = cache_hit,
        pages_fetched = pages_fetched,
        pages_cached_total = pages_after,
        pages_available = total_pages,
        publications_count = counts$search_count,
        annotations_count = counts$annotation_count,
        execution_time = paste0(execution_time, " secs"),
        message = if (cache_hit) {
          paste0("Cache hit - already have ", pages_after, " pages. Use clear_old=true for hard refresh.")
        } else {
          paste0("Fetched ", pages_fetched, " new pages (", pages_fetched * 10, " publications). ",
                 "Total cached: ", pages_after, "/", total_pages, " pages.")
        }
      )
    },
    error = function(e) {
      log_error("PubTator update failed: {e$message}")
      res$status <- 500
      list(success = FALSE, error = e$message)
    }
  )
}

#' Submit an async PubTator update job (`POST /pubtator/update/submit`, Administrator).
#'
#' `require_role()`, the `query == ""` 400 check, and the duplicate-job 409
#' short-circuit (`check_duplicate_job()`) all stay in the endpoint shell;
#' this covers job creation and the capacity-503 / accepted-202 response.
#'
#' @param req,res Plumber request/response.
#' @param query The search query for PubTator.
#' @param max_pages Maximum pages to fetch (already coerced to integer).
#' @param clear_old Hard update flag (already coerced to logical).
#' @param q_hash Precomputed query hash (from the shell's duplicate check).
#' @param submit_fn Injectable job submitter (default [create_job()]).
#' @return List with job_id/status/etc (202), or the capacity error body (503).
#' @export
svc_publication_pubtator_update_submit <- function(req, res, query, max_pages, clear_old, q_hash,
                                                     submit_fn = create_job) {
  db_config <- list(
    db_host = dw$host,
    db_port = dw$port,
    db_name = dw$dbname,
    db_user = dw$user,
    db_password = dw$password
  )
  # Each page ~6s (350ms rate limit + 2s fetch + 3s DB), plus a 2-minute
  # buffer for gene-symbol computation at the end.
  timeout_ms <- max(120000, (max_pages * 6000) + 120000)

  result <- submit_fn(
    operation = "pubtator_update",
    params = list(
      query = query,
      max_pages = max_pages,
      clear_old = clear_old,
      query_hash = q_hash,
      db_config = db_config
    ),
    timeout_ms = timeout_ms,
    executor_fn = function(params) {
      # Runs in the durable async worker.
      progress <- create_progress_reporter(params$.__job_id__)
      job_id <- params$.__job_id__
      message(sprintf(
        "[%s] [job:%s] PubTator update starting: query='%s', max_pages=%d, clear_old=%s",
        Sys.time(), job_id, params$query, params$max_pages, params$clear_old
      ))
      progress("init", "Initializing PubTator fetch...", current = 0, total = params$max_pages)
      result <- pubtator_db_update_async(
        db_config = params$db_config,
        query = params$query,
        max_pages = params$max_pages,
        do_full_update = params$clear_old,
        progress_fn = progress
      )
      progress("complete", "PubTator fetch complete", current = params$max_pages, total = params$max_pages)

      list(
        status = "completed",
        success = result$success,
        query_id = result$query_id,
        query = params$query,
        pages_cached = result$pages_cached,
        pages_total = result$pages_total,
        publications_count = result$publications_count,
        message = result$message
      )
    }
  )

  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", as.character(result$retry_after))
    return(result)
  }

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")
  estimated_seconds <- round(max_pages * 2.5)

  list(
    job_id = result$job_id,
    status = result$status,
    query = query,
    max_pages = max_pages,
    estimated_seconds = estimated_seconds,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

#' Clear all PubTator cache tables (`POST /pubtator/clear-cache`, Administrator).
#'
#' Deletion order matters (annotations reference search rows, which reference
#' query rows): annotation_cache, then search_cache, then query_cache.
#'
#' @param res Plumber response (`res$status` is set to 500 on error).
#' @param checkout_fn Injectable pool checkout (default `pool::poolCheckout(pool)`).
#' @param return_fn Injectable pool return (default `pool::poolReturn`).
#' @param query_fn Injectable `(conn, sql) -> data.frame` reader (default `DBI::dbGetQuery`).
#' @param execute_fn Injectable `(conn, sql) -> ...` statement runner (default `DBI::dbExecute`).
#' @return List with `success`, `deleted` counts, `execution_time`, `message`.
#' @export
svc_publication_pubtator_clear_cache <- function(
  res,
  checkout_fn = function() pool::poolCheckout(pool),
  return_fn = pool::poolReturn,
  query_fn = function(conn, sql) DBI::dbGetQuery(conn, sql),
  execute_fn = function(conn, sql) DBI::dbExecute(conn, sql)
) {
  start_time <- Sys.time()

  tryCatch({
      log_info("Starting pubtator cache clear...")
      conn <- checkout_fn()
      on.exit(return_fn(conn), add = TRUE)

      search_count <- query_fn(conn, "SELECT COUNT(*) as cnt FROM pubtator_search_cache")$cnt[1]
      annotation_count <- query_fn(conn, "SELECT COUNT(*) as cnt FROM pubtator_annotation_cache")$cnt[1]
      query_count <- query_fn(conn, "SELECT COUNT(*) as cnt FROM pubtator_query_cache")$cnt[1]
      log_info("Counts: queries={query_count}, publications={search_count}, annotations={annotation_count}")

      # Order matters: annotations first, then search rows, then query rows.
      execute_fn(conn, "DELETE FROM pubtator_annotation_cache")
      execute_fn(conn, "DELETE FROM pubtator_search_cache")
      execute_fn(conn, "DELETE FROM pubtator_query_cache")
      end_time <- Sys.time()
      execution_time <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

      list(
        success = TRUE,
        deleted = list(
          queries = query_count,
          publications = search_count,
          annotations = annotation_count
        ),
        execution_time = paste0(execution_time, " secs"),
        message = paste0(
          "Cleared ", query_count, " queries, ",
          search_count, " publications, ",
          annotation_count, " annotations"
        )
      )
    },
    error = function(e) {
      log_error("PubTator cache clear failed: {conditionMessage(e)}")
      res$status <- 500
      list(success = FALSE, error = conditionMessage(e))
    }
  )
}
