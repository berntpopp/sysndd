# functions/pubtator-gene-summary.R
#
# Precomputed per-gene summary for the PubtatorNDD gene-prioritization endpoint.
#
# `GET /api/publication/pubtator/genes` used to collect the whole
# pubtator_human_gene_entity_view and nest it in R (tidyr::nest + per-gene
# purrr::map_int) on every request. The raw view query is ~50-100ms but the
# endpoint was ~800ms: the cost is the R nesting, not SQL. The frontend never
# consumes the nested publications/entities (it requests flat fields and lazy-
# fetches per-gene publications via /pubtator/table on row expand), so the
# nesting was pure overhead.
#
# A second, latent bug: the view has one row per (gene x publication x entity),
# so the old R nrow()-based counts double-counted. A gene with 43 distinct PMIDs
# and 2 SysNDD entities reported publication_count=86 (and an inflated
# entities_count) yet listed only 43 pmids. The SQL aggregation here uses
# COUNT(DISTINCT ...), so publication_count == number of distinct PMIDs (matches
# the pmids list) and entities_count == distinct SysNDD entities.
#
# pubtator_gene_summary_refresh() materializes the flat per-gene aggregates into
# the pubtator_gene_summary table (migration 035). pubtator_genes_summary_base()
# reads that table directly and, when it is empty (cold start before the first
# refresh), computes the SAME aggregation live via a read-only SELECT (identical
# semantics, no R nesting).

# Flat per-gene columns the gene listing needs (no nested publications/entities).
PUBTATOR_GENE_SUMMARY_COLS <- c(
  "gene_symbol", "gene_name", "hgnc_id", "gene_normalized_id",
  "publication_count", "entities_count", "is_novel", "oldest_pub_date", "pmids"
)

#' The single per-gene aggregation SELECT (shared by refresh + cold-start read)
#'
#' One row per gene from pubtator_human_gene_entity_view. COUNT(DISTINCT ...)
#' avoids the (publication x entity) fan-out double-count. `refreshed_at` is only
#' meaningful for the INSERT path but is harmless in a plain SELECT.
#' @keywords internal
.pubtator_gene_summary_select_sql <- function() {
  paste(
    "SELECT",
    "  gene_symbol,",
    "  MAX(gene_name)            AS gene_name,",
    "  MAX(hgnc_id)              AS hgnc_id,",
    "  MAX(gene_normalized_id)   AS gene_normalized_id,",
    "  COUNT(DISTINCT pmid)      AS publication_count,",
    "  COUNT(DISTINCT entity_id) AS entities_count,",
    "  CASE WHEN COUNT(DISTINCT entity_id) = 0 THEN 1 ELSE 0 END AS is_novel,",
    # Only consider publication rows (pmid not null), consistent with
    # publication_count / pmids, since pubtator_search_cache.pmid is nullable.
    "  MIN(CASE WHEN pmid IS NOT NULL THEN `date` END) AS oldest_pub_date,",
    "  GROUP_CONCAT(DISTINCT pmid ORDER BY pmid SEPARATOR ',') AS pmids",
    "FROM pubtator_human_gene_entity_view",
    "GROUP BY gene_symbol",
    sep = "\n"
  )
}

#' Refresh the precomputed pubtator_gene_summary table
#'
#' Atomically replaces the table contents from the per-gene aggregation SELECT.
#' The DELETE + INSERT...SELECT runs in one transaction so readers see either the
#' old or the new full set, never a partial one. `group_concat_max_len` is
#' widened so the PMID list is not truncated for heavily-published genes.
#'
#' @param conn A DBI connection.
#' @return `list(success = TRUE, genes = <int>)` on success.
#' @export
pubtator_gene_summary_refresh <- function(conn) {
  # Without this, GROUP_CONCAT silently truncates the pmids list at 1024 bytes.
  DBI::dbExecute(conn, "SET SESSION group_concat_max_len = 4194304")

  insert_select <- paste0(
    "INSERT INTO pubtator_gene_summary\n",
    "  (gene_symbol, gene_name, hgnc_id, gene_normalized_id,\n",
    "   publication_count, entities_count, is_novel, oldest_pub_date, pmids)\n",
    .pubtator_gene_summary_select_sql()
  )

  # dbWithTransaction gives atomic visibility of the swap.
  DBI::dbWithTransaction(conn, {
    DBI::dbExecute(conn, "DELETE FROM pubtator_gene_summary")
    DBI::dbExecute(conn, insert_select)
  })

  n <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM pubtator_gene_summary")
  list(success = TRUE, genes = as.integer(n$n[[1]]))
}

#' Read the flat per-gene base tibble for the gene listing
#'
#' Fast path: read the precomputed pubtator_gene_summary table (one indexed
#' scan, no R nesting). Cold-start fallback: when the summary table is missing or
#' empty, run the identical aggregation SELECT live (read-only) so the endpoint
#' is always correct and consistent with the materialized table.
#'
#' @param pool_obj A dbplyr-capable pool/connection.
#' @return `list(data = <tibble of flat per-gene rows>, source =
#'   "summary"|"live")`.
#' @export
pubtator_genes_summary_base <- function(pool_obj) {
  summary <- tryCatch(
    pool_obj %>%
      dplyr::tbl("pubtator_gene_summary") %>%
      dplyr::select(dplyr::any_of(PUBTATOR_GENE_SUMMARY_COLS)) %>%
      dplyr::collect(),
    error = function(e) NULL
  )

  if (!is.null(summary) && nrow(summary) > 0) {
    summary$oldest_pub_date <- as.character(summary$oldest_pub_date)
    return(list(data = summary, source = "summary"))
  }

  # Cold-start fallback: identical aggregation, computed live (read-only).
  # Accept either a pool (checkout/return) or a bare DBI connection, mirroring
  # the inherits(x, "Pool") pattern used elsewhere (e.g. migration-runner.R).
  is_pool <- inherits(pool_obj, "Pool")
  conn <- if (is_pool) pool::poolCheckout(pool_obj) else pool_obj
  if (is_pool) on.exit(pool::poolReturn(conn), add = TRUE)
  tryCatch(
    DBI::dbExecute(conn, "SET SESSION group_concat_max_len = 4194304"),
    error = function(e) NULL
  )
  df <- DBI::dbGetQuery(conn, .pubtator_gene_summary_select_sql())
  df$oldest_pub_date <- as.character(df$oldest_pub_date)
  list(data = tibble::as_tibble(df), source = "live")
}
