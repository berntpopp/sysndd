# functions/llm-service.R
#
# Thin orchestrator composing llm-client, llm-types, and llm-rate-limiter
# into a cohesive pipeline for cluster summary generation and retrieval.
#
# This file provides:
# - get_or_generate_summary(): Main entry point (cache check -> generate -> save)
# - fetch_cluster_data_for_generation(): Dispatch to functional/phenotype fetchers
# - fetch_functional_cluster_data(): Retrieve functional cluster data from DB
# - fetch_phenotype_cluster_data(): Retrieve phenotype cluster data from DB
#
# Dependencies (sourced before this file):
# - llm-model-config.R: Gemini model catalog and default resolution
# - llm-client.R: generate_cluster_summary(), is_gemini_configured(), etc.
# - llm-types.R: type specs and prompt builders
# - llm-rate-limiter.R: GEMINI_RATE_LIMIT, calculate_derived_confidence()
# - llm-cache-repository.R: generate_cluster_hash(), get_cached_summary(), save_summary_to_cache()
# - llm-validation.R: validate_summary_entities()
#
# Split from the original monolithic llm-service.R as part of v11.0 Phase D (D1).
#
# Prompt-template persistence (get_prompt_template(), get_default_prompt_template(),
# save_prompt_template(), get_all_prompt_templates()) moved out to the new
# functions/llm-prompt-template-repository.R as part of the #346 refactor
# (Wave 4, Task 7). This file's own functions never call them; consumers such
# as services/llm-admin-endpoint-service.R depend on bootstrap/load_modules.R
# sourcing the repository file (before llm-service.R, matching the existing
# functions/* before services/* order) rather than a self-load guard here.

require(logger)
require(jsonlite)

log_threshold(INFO)

# Resolve function directory: use get_api_dir() (test helper) if available,
# otherwise fall back to relative "functions/" (API startup with wd = api/).
.funcs_dir <- tryCatch(file.path(get_api_dir(), "functions"), error = function(e) "functions")

# Load cache repository functions (if not already loaded)
if (!exists("generate_cluster_hash", mode = "function")) {
  .p <- file.path(.funcs_dir, "llm-cache-repository.R")
  if (file.exists(.p)) source(.p, local = FALSE)
}

# Load validation functions (if not already loaded)
if (!exists("validate_summary_entities", mode = "function")) {
  .p <- file.path(.funcs_dir, "llm-validation.R")
  if (file.exists(.p)) source(.p, local = FALSE)
}

# Load split modules (if not already loaded)
if (!exists("get_default_gemini_model", mode = "function")) {
  for (.f in c("llm-model-config.R", "llm-rate-limiter.R", "llm-types.R", "llm-client.R")) {
    .p <- file.path(.funcs_dir, .f)
    if (file.exists(.p)) source(.p, local = FALSE)
  }
}
rm(list = intersect(c(".funcs_dir", ".p", ".f"), ls()), envir = environment())


#' Get or generate cluster summary
#'
#' Checks cache for existing summary; generates new one if not found or invalid.
#' This is the main entry point for cluster summary retrieval.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (defaults to get_default_gemini_model())
#' @param require_validated Logical, if TRUE only returns validated summaries (default: FALSE)
#'
#' @return List with:
#'   - success: Logical, TRUE if summary available
#'   - summary: List with structured summary
#'   - from_cache: Logical, TRUE if retrieved from cache
#'   - cache_id: Integer, cache ID (if cached)
#'   - validation_status: Character, validation status
#'   - error: Character, error message (if failed)
#'
#' @examples
#' \dontrun{
#' result <- get_or_generate_summary(
#'   cluster_data = list(
#'     identifiers = tibble(hgnc_id = 1:10, symbol = paste0("GENE", 1:10)),
#'     term_enrichment = tibble(category = "GO", term = "pathway", fdr = 0.001)
#'   ),
#'   cluster_type = "functional"
#' )
#'
#' if (result$success) {
#'   print(result$summary)
#' }
#' }
#'
#' @export
get_or_generate_summary <- function(
  cluster_data,
  cluster_type = "functional",
  model = NULL,
  require_validated = FALSE
) {
  if (is.null(model)) {
    model <- get_default_gemini_model()
  }

  # Validate cluster_type
  if (!cluster_type %in% c("functional", "phenotype")) {
    rlang::abort(
      paste("Invalid cluster_type:", cluster_type, "- must be 'functional' or 'phenotype'"),
      class = "llm_service_error"
    )
  }

  # Validate identifiers
  if (!"identifiers" %in% names(cluster_data)) {
    rlang::abort("cluster_data must contain 'identifiers' element", class = "llm_service_error")
  }

  id_col <- if (cluster_type == "functional") "hgnc_id" else "entity_id"
  if (!id_col %in% names(cluster_data$identifiers)) {
    rlang::abort(
      paste("cluster_data$identifiers must contain", id_col, "column for", cluster_type, "clusters"),
      class = "llm_service_error"
    )
  }

  # Generate cluster hash
  cluster_hash <- generate_cluster_hash(cluster_data$identifiers, cluster_type)

  log_debug("Checking cache for cluster hash: {substr(cluster_hash, 1, 16)}...")

  # Check cache
  cached <- get_cached_summary(cluster_hash, require_validated = require_validated)

  if (!is.null(cached) && nrow(cached) > 0) {
    # Parse JSON if needed
    summary_data <- if (is.character(cached$summary_json[1])) {
      jsonlite::fromJSON(cached$summary_json[1])
    } else {
      cached$summary_json[[1]]
    }

    log_info("Returning cached summary (cache_id={cached$cache_id[1]})")

    return(list(
      success = TRUE,
      summary = summary_data,
      from_cache = TRUE,
      cache_id = cached$cache_id[1],
      validation_status = cached$validation_status[1]
    ))
  }

  # Generate new summary
  log_info("No cached summary found, generating new...")

  result <- generate_cluster_summary(
    cluster_data = cluster_data,
    cluster_type = cluster_type,
    model = model
  )

  # Handle generation failure
  if (!result$success) {
    # If we have a last result that failed validation, save it as rejected
    if (!is.null(result$last_result) && !is.null(result$last_validation)) {
      cluster_number <- cluster_data$cluster_number %||% 0L

      # Add derived confidence even for rejected summaries
      summary_with_confidence <- result$last_result
      # Use appropriate data source for confidence calculation based on cluster type
      confidence_data <- if (cluster_type == "phenotype") {
        cluster_data$quali_inp_var
      } else {
        cluster_data$term_enrichment
      }
      summary_with_confidence$derived_confidence <- calculate_derived_confidence(confidence_data, cluster_type)

      # Persist the judge verdict + reasoning on the rejected row (#443). Unify
      # the blob keys (#490): write the SAME flat llm_judge_verdict /
      # llm_judge_reasoning keys the batch path uses, and keep the nested
      # `validation` block for backward compatibility.
      verdict_value <- result$last_validation$verdict %||% NA_character_
      reasoning_value <- result$last_validation$reasoning %||% NA_character_
      summary_with_confidence$llm_judge_verdict <- verdict_value
      summary_with_confidence$llm_judge_reasoning <- reasoning_value
      summary_with_confidence$validation <- list(verdict = verdict_value, reasoning = reasoning_value)

      cache_id <- save_summary_to_cache(
        cluster_type = cluster_type,
        cluster_number = as.integer(cluster_number),
        cluster_hash = cluster_hash,
        model_name = model,
        prompt_version = LLM_SUMMARY_PROMPT_VERSION,
        summary_json = summary_with_confidence,
        tags = result$last_result$tags,
        validation_status = "rejected"
      )

      log_warn("Saved rejected summary to cache (cache_id={cache_id}, verdict persisted)")

      return(list(
        success = FALSE,
        error = result$error,
        from_cache = FALSE,
        cache_id = cache_id,
        validation_status = "rejected",
        validation = result$last_validation
      ))
    }

    return(list(
      success = FALSE,
      error = result$error,
      from_cache = FALSE
    ))
  }

  # Calculate derived confidence from appropriate data source
  confidence_data <- if (cluster_type == "phenotype") {
    cluster_data$quali_inp_var
  } else {
    cluster_data$term_enrichment
  }
  derived_confidence <- calculate_derived_confidence(confidence_data, cluster_type)

  # Add derived_confidence to summary
  summary_with_confidence <- result$summary
  summary_with_confidence$derived_confidence <- derived_confidence

  # Save to cache with validation status
  cluster_number <- cluster_data$cluster_number %||% 0L
  tags <- result$summary$tags

  cache_id <- save_summary_to_cache(
    cluster_type = cluster_type,
    cluster_number = as.integer(cluster_number),
    cluster_hash = cluster_hash,
    model_name = model,
    prompt_version = LLM_SUMMARY_PROMPT_VERSION,
    summary_json = summary_with_confidence,
    tags = tags
  )

  log_info("Generated and cached summary (cache_id={cache_id})")

  return(list(
    success = TRUE,
    summary = summary_with_confidence,
    from_cache = FALSE,
    cache_id = cache_id,
    validation_status = "pending",
    validation = result$validation
  ))
}


#------------------------------------------------------------------------------
# Cluster Data Fetching Functions for On-Demand Summary Generation
# Used by LLM endpoint helpers to retrieve cluster data for generation
#------------------------------------------------------------------------------

#' Fetch Cluster Data for Summary Generation
#'
#' Retrieves cluster composition data needed to generate an LLM summary.
#' This function queries the database for cluster members and enrichment data.
#' Dispatches to appropriate fetch function based on cluster type.
#'
#' @param cluster_hash SHA256 hash of cluster composition
#' @param cluster_type Character, either "functional" or "phenotype"
#'
#' @return List with identifiers, term_enrichment/quali_inp_var, cluster_number
#'         or NULL if cluster not found
#'
#' @export
fetch_cluster_data_for_generation <- function(cluster_hash, cluster_type) {
  if (cluster_type == "functional") {
    fetch_functional_cluster_data(cluster_hash)
  } else if (cluster_type == "phenotype") {
    fetch_phenotype_cluster_data(cluster_hash)
  } else {
    log_error("Invalid cluster_type: {cluster_type}")
    NULL
  }
}

#' Fetch Functional Cluster Data
#'
#' Retrieves functional cluster data for summary generation including
#' gene identifiers and term enrichment results.
#'
#' Uses the memoized gen_string_clust_obj_mem function to compute clusters
#' dynamically and find the cluster matching the requested hash.
#'
#' @param cluster_hash SHA256 hash of cluster composition
#'
#' @return List with identifiers, term_enrichment, cluster_number or NULL
#'
#' @noRd
fetch_functional_cluster_data <- function(cluster_hash) {
  # Build the filter format to match against cluster data

  hash_filter <- paste0("equals(hash,", cluster_hash, ")")

  # Get genes from database (same query as functional_clustering endpoint)
  conn <- get_db_connection()
  genes_from_entity_table <- tryCatch(
    {
      DBI::dbGetQuery(
        conn,
        "SELECT DISTINCT hgnc_id FROM ndd_entity_view WHERE ndd_phenotype = 1"
      )
    },
    error = function(e) {
      log_error("Failed to fetch genes for functional clustering: {e$message}")
      return(NULL)
    }
  )

  if (is.null(genes_from_entity_table) || nrow(genes_from_entity_table) == 0) {
    log_warn("No genes found for functional clustering")
    return(NULL)
  }

  # Check if gen_string_clust_obj_mem is available (defined in start_sysndd_api.R)
  if (!exists("gen_string_clust_obj_mem", mode = "function")) {
    log_error("gen_string_clust_obj_mem not available - clustering functions not loaded")
    return(NULL)
  }

  # Generate clusters using memoized function
  functional_clusters <- tryCatch(
    gen_string_clust_obj_mem(genes_from_entity_table$hgnc_id, algorithm = "leiden"),
    error = function(e) {
      log_error("Failed to generate functional clusters: {e$message}")
      return(NULL)
    }
  )

  if (is.null(functional_clusters)) {
    return(NULL)
  }

  # Find cluster matching the requested hash
  matching_cluster <- functional_clusters %>%
    dplyr::filter(hash_filter == !!hash_filter)

  if (nrow(matching_cluster) == 0) {
    log_warn("Functional cluster not found for hash: {substr(cluster_hash, 1, 16)}...")
    return(NULL)
  }

  cluster_number <- matching_cluster$cluster[1]

  # Extract identifiers from the nested column
  identifiers <- matching_cluster$identifiers[[1]]
  if (nrow(identifiers) == 0) {
    log_warn("No identifiers found for functional cluster {cluster_number}")
    return(NULL)
  }

  # Extract term enrichment data (top 100 by FDR)
  term_enrichment <- matching_cluster$term_enrichment[[1]]
  if (!is.null(term_enrichment) && nrow(term_enrichment) > 0) {
    term_enrichment <- term_enrichment %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = 100) %>%
      dplyr::select(category, term = term_name, p_value, fdr)
  } else {
    term_enrichment <- tibble::tibble(category = character(), term = character(),
                                       p_value = numeric(), fdr = numeric())
  }

  list(
    identifiers = tibble::as_tibble(identifiers),
    term_enrichment = tibble::as_tibble(term_enrichment),
    cluster_number = as.integer(cluster_number)
  )
}

#' Fetch Phenotype Cluster Data
#'
#' Retrieves phenotype cluster data for summary generation including
#' entity identifiers and qualitative input variables.
#'
#' Uses the memoized gen_mca_clust_obj_mem function to compute clusters
#' dynamically and find the cluster matching the requested hash.
#'
#' @param cluster_hash SHA256 hash of cluster composition
#'
#' @return List with identifiers, quali_inp_var, cluster_number or NULL
#'
#' @noRd
fetch_phenotype_cluster_data <- function(cluster_hash) {
  hash_filter <- paste0("equals(hash,", cluster_hash, ")")

  if (!exists("generate_phenotype_clusters", mode = "function")) {
    log_error("generate_phenotype_clusters not available - phenotype analysis functions not loaded")
    return(NULL)
  }

  phenotype_clusters <- tryCatch(
    generate_phenotype_clusters(),
    error = function(e) {
      log_error("Failed to generate phenotype clusters: {e$message}")
      return(NULL)
    }
  )

  if (is.null(phenotype_clusters) || nrow(phenotype_clusters) == 0) {
    log_warn("No phenotype clusters available for summary generation")
    return(NULL)
  }

  matching_cluster <- phenotype_clusters %>%
    dplyr::filter(hash_filter == !!hash_filter)

  if (nrow(matching_cluster) == 0) {
    log_warn("Phenotype cluster not found for hash: {substr(cluster_hash, 1, 16)}...")
    return(NULL)
  }

  cluster_number <- matching_cluster$cluster[1]

  identifiers <- matching_cluster$identifiers[[1]]
  if (nrow(identifiers) == 0) {
    log_warn("No identifiers found for phenotype cluster {cluster_number}")
    return(NULL)
  }

  identifiers <- identifiers %>%
    dplyr::mutate(entity_id = as.integer(entity_id))

  quali_inp_var <- matching_cluster$quali_inp_var[[1]]
  if (is.null(quali_inp_var) || nrow(quali_inp_var) == 0) {
    quali_inp_var <- tibble::tibble(variable = character(), p.value = numeric(), v.test = numeric())
  }

  list(
    identifiers = tibble::as_tibble(identifiers),
    quali_inp_var = tibble::as_tibble(quali_inp_var),
    cluster_number = as.integer(cluster_number)
  )
}
