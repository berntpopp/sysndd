## -------------------------------------------------------------------##
# api/bootstrap/setup_workers.R
#
# Part of the Phase D.D6 extract-bootstrap refactor.
#
# Initialises the mirai daemon pool and pre-loads every package /
# source file that background jobs (HGNC/PubTator/ontology/LLM)
# need to execute standalone.
#
# IMPORTANT (from CLAUDE.md): mirai workers have no access to the
# main process's application context. Each daemon sources the
# files listed here ONCE at daemon start-up. If code run inside a
# daemon changes, the api container must be restarted so the
# daemon re-sources the updated file from disk.
#
# IMPORTANT (package order): Load packages that mask dplyr::select
# FIRST (STRINGdb, biomaRt → AnnotationDbi), then dplyr/tidyverse
# LAST so their functions win. Do NOT reorder the everywhere({...})
# block — the ordering is a deliberate workaround for a long-
# standing namespace-shadowing bug documented in CLAUDE.md.
## -------------------------------------------------------------------##

#' Start the mirai daemon pool and pre-source worker dependencies.
#'
#' `MIRAI_WORKERS` governs daemon count (default 2, clamped 1–8).
#' Tune for host RAM — see CLAUDE.md "Memory / Worker Tuning".
#'
#' @return A list describing the worker configuration (for
#'   logging / diagnostics): `count` (daemon count) and
#'   `dispatcher` (TRUE when dispatcher mode is enabled).
#' @export
bootstrap_setup_workers <- function() {
  worker_count <- as.integer(Sys.getenv("MIRAI_WORKERS", "2"))

  # Handle NA from invalid input (e.g., "abc")
  if (is.na(worker_count)) worker_count <- 2L

  # Validate bounds (minimum 1, maximum 8)
  worker_count <- max(1L, min(worker_count, 8L))

  mirai::daemons(
    n = worker_count,
    dispatcher = TRUE, # Enable for variable-length jobs
    autoexit = tools::SIGINT
  )
  message(sprintf(
    "[%s] Started mirai daemon pool with %d workers",
    Sys.time(), worker_count
  ))

  # Export required packages and functions to all daemons.
  # NOTE: Load packages that mask dplyr::select FIRST (STRINGdb, biomaRt
  # load AnnotationDbi), then load dplyr/tidyverse LAST so their
  # functions win. Do not reorder — see module header.
  mirai::everywhere({
    library(DBI)
    library(RMariaDB)
    library(STRINGdb)
    library(biomaRt)
    library(FactoMineR)
    library(factoextra)
    library(cluster)
    library(igraph)
    library(digest)
    library(jsonlite)
    library(openssl)
    library(httr2)
    library(memoise)
    library(cachem)
    library(dplyr)
    library(tidyr)
    library(tibble)
    library(stringr)
    library(purrr)
    library(readr)
    library(logger)
    # Load ellmer for LLM functionality (optional - graceful degradation if not available)
    if (requireNamespace("ellmer", quietly = TRUE)) {
      library(ellmer)
    }
    # Load pdftools for PDF parsing in comparisons update (optional)
    if (requireNamespace("pdftools", quietly = TRUE)) {
      library(pdftools)
    }
    # Source data-helpers (generate_panel_hash, generate_json_hash, generate_function_hash, etc.)
    source("/app/functions/data-helpers.R", local = FALSE)
    # Source entity-helpers (nest_gene_tibble, nest_pubtator_gene_tibble, etc.)
    source("/app/functions/entity-helpers.R", local = FALSE)
    # Source file functions (check_file_age, get_newest_file)
    source("/app/functions/file-functions.R", local = FALSE)
    # Source the analysis functions (gen_string_clust_obj, gen_mca_clust_obj)
    source("/app/functions/analyses-functions.R", local = FALSE)
    # Source shared external proxy infrastructure (validate_gene_symbol, cache backends, throttle)
    source("/app/functions/external-proxy-functions.R", local = FALSE)
    # Source gnomAD proxy functions (fetch_gnomad_constraints + memoised wrapper)
    source("/app/functions/external-proxy-gnomad.R", local = FALSE)
    # Source gnomAD/AlphaFold enrichment functions for HGNC update pipeline
    source("/app/functions/hgnc-enrichment-gnomad.R", local = FALSE)
    # Source HGNC functions (update_process_hgnc_data)
    source("/app/functions/hgnc-functions.R", local = FALSE)
    # Source Ensembl functions (gene_coordinates_from_ensembl, gene_coordinates_from_symbol)
    source("/app/functions/ensembl-functions.R", local = FALSE)
    # Source file-based job progress reporting
    source("/app/functions/job-progress.R", local = FALSE)
    # Source db-helpers for parameterized queries
    source("/app/functions/db-helpers.R", local = FALSE)
    # Source PubTator functions for async update jobs (client + parser before orchestrator)
    source("/app/functions/pubtator-client.R", local = FALSE)
    source("/app/functions/pubtator-parser.R", local = FALSE)
    source("/app/functions/pubtator-functions.R", local = FALSE)
    # Source OMIM functions (download_genemap2, parse_genemap2, download_hpoa) for comparisons
    source("/app/functions/omim-functions.R", local = FALSE)
    # Source comparisons functions for async comparisons update jobs
    source("/app/functions/comparisons-sources.R", local = FALSE)
    source("/app/functions/comparisons-functions.R", local = FALSE)
    # Source LLM-related functions for async LLM batch generation jobs
    source("/app/functions/llm-cache-repository.R", local = FALSE)
    source("/app/functions/llm-validation.R", local = FALSE)
    source("/app/functions/llm-rate-limiter.R", local = FALSE)
    source("/app/functions/llm-types.R", local = FALSE)
    source("/app/functions/llm-client.R", local = FALSE)
    source("/app/functions/llm-service.R", local = FALSE)
    source("/app/functions/llm-judge.R", local = FALSE)
    source("/app/functions/llm-batch-generator.R", local = FALSE)
  })
  message(sprintf(
    "[%s] Exported packages and functions to mirai daemons",
    Sys.time()
  ))

  list(count = worker_count, dispatcher = TRUE)
}
