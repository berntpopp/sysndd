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
# - llm-client.R: generate_cluster_summary(), is_gemini_configured(), etc.
# - llm-types.R: type specs, prompt builders, prompt template CRUD
# - llm-rate-limiter.R: GEMINI_RATE_LIMIT, calculate_derived_confidence()
# - llm-cache-repository.R: generate_cluster_hash(), get_cached_summary(), save_summary_to_cache()
# - llm-validation.R: validate_summary_entities()
#
# Split from the original monolithic llm-service.R as part of v11.0 Phase D (D1).

require(logger)
require(jsonlite)

log_threshold(INFO)

# Load cache repository functions (if not already loaded)
if (!exists("generate_cluster_hash", mode = "function")) {
  if (file.exists("functions/llm-cache-repository.R")) {
    source("functions/llm-cache-repository.R", local = TRUE)
  }
}

# Load validation functions (if not already loaded)
if (!exists("validate_summary_entities", mode = "function")) {
  if (file.exists("functions/llm-validation.R")) {
    source("functions/llm-validation.R", local = TRUE)
  }
}

# Load split modules (if not already loaded)
if (!exists("get_default_gemini_model", mode = "function")) {
  if (file.exists("functions/llm-rate-limiter.R")) {
    source("functions/llm-rate-limiter.R", local = TRUE)
  }
  if (file.exists("functions/llm-types.R")) {
    source("functions/llm-types.R", local = TRUE)
  }
  if (file.exists("functions/llm-client.R")) {
    source("functions/llm-client.R", local = TRUE)
  }
}


#' Get or generate cluster summary
#'
#' Checks cache for existing summary; generates new one if not found or invalid.
#' This is the main entry point for cluster summary retrieval.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (default: "gemini-3-pro-preview")
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
  model = "gemini-3-pro-preview",
  require_validated = FALSE
) {
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

      cache_id <- save_summary_to_cache(
        cluster_type = cluster_type,
        cluster_number = as.integer(cluster_number),
        cluster_hash = cluster_hash,
        model_name = model,
        prompt_version = "1.0",
        summary_json = summary_with_confidence,
        tags = result$last_result$tags,
        validation_status = "rejected"
      )

      log_warn("Saved rejected summary to cache (cache_id={cache_id})")

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
    prompt_version = "1.0",
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
      pool::dbGetQuery(
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
  # Build the filter format to match against cluster data
  hash_filter <- paste0("equals(hash,", cluster_hash, ")")

  # ID phenotype IDs for filtering (same as phenotype_clustering endpoint)
  id_phenotype_ids <- c(
    "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )
  categories <- c("Definitive")

  # Get data from database (replicating phenotype_clustering endpoint logic)
  conn <- get_db_connection()

  ndd_entity_view_tbl <- tryCatch(
    pool::dbGetQuery(conn, "SELECT * FROM ndd_entity_view"),
    error = function(e) {
      log_error("Failed to fetch ndd_entity_view: {e$message}")
      return(NULL)
    }
  )
  if (is.null(ndd_entity_view_tbl)) return(NULL)

  ndd_entity_review_tbl <- tryCatch(
    pool::dbGetQuery(conn, "SELECT review_id FROM ndd_entity_review WHERE is_primary = 1"),
    error = function(e) {
      log_error("Failed to fetch ndd_entity_review: {e$message}")
      return(NULL)
    }
  )
  if (is.null(ndd_entity_review_tbl)) return(NULL)

  ndd_review_phenotype_connect_tbl <- tryCatch(
    pool::dbGetQuery(conn, "SELECT * FROM ndd_review_phenotype_connect"),
    error = function(e) {
      log_error("Failed to fetch ndd_review_phenotype_connect: {e$message}")
      return(NULL)
    }
  )
  if (is.null(ndd_review_phenotype_connect_tbl)) return(NULL)

  modifier_list_tbl <- tryCatch(
    pool::dbGetQuery(conn, "SELECT * FROM modifier_list"),
    error = function(e) {
      log_error("Failed to fetch modifier_list: {e$message}")
      return(NULL)
    }
  )
  if (is.null(modifier_list_tbl)) return(NULL)

  phenotype_list_tbl <- tryCatch(
    pool::dbGetQuery(conn, "SELECT * FROM phenotype_list"),
    error = function(e) {
      log_error("Failed to fetch phenotype_list: {e$message}")
      return(NULL)
    }
  )
  if (is.null(phenotype_list_tbl)) return(NULL)

  # Convert to tibbles for dplyr operations
  ndd_entity_view_tbl <- tibble::as_tibble(ndd_entity_view_tbl)
  ndd_entity_review_tbl <- tibble::as_tibble(ndd_entity_review_tbl)
  ndd_review_phenotype_connect_tbl <- tibble::as_tibble(ndd_review_phenotype_connect_tbl)
  modifier_list_tbl <- tibble::as_tibble(modifier_list_tbl)
  phenotype_list_tbl <- tibble::as_tibble(phenotype_list_tbl)

  # Join and filter (replicating phenotype_clustering endpoint logic)
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    dplyr::left_join(ndd_review_phenotype_connect_tbl, by = c("entity_id")) %>%
    dplyr::left_join(modifier_list_tbl, by = c("modifier_id")) %>%
    dplyr::left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    dplyr::mutate(
      ndd_phenotype = dplyr::case_when(
        ndd_phenotype == 1 ~ "Yes",
        ndd_phenotype == 0 ~ "No",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::filter(ndd_phenotype == "Yes") %>%
    dplyr::filter(category %in% categories) %>%
    dplyr::filter(modifier_name == "present") %>%
    dplyr::filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    dplyr::select(entity_id, hpo_mode_of_inheritance_term_name, phenotype_id, HPO_term, hgnc_id) %>%
    dplyr::group_by(entity_id) %>%
    dplyr::mutate(
      phenotype_non_id_count = sum(!(phenotype_id %in% id_phenotype_ids)),
      phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)
    ) %>%
    dplyr::ungroup() %>%
    unique()

  if (nrow(sysndd_db_phenotypes) == 0) {
    log_warn("No phenotype data found for clustering")
    return(NULL)
  }

  # Convert to wide format
  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    dplyr::mutate(present = "yes") %>%
    dplyr::select(-phenotype_id) %>%
    tidyr::pivot_wider(names_from = HPO_term, values_from = present) %>%
    dplyr::group_by(hgnc_id) %>%
    dplyr::mutate(gene_entity_count = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::relocate(gene_entity_count, .after = phenotype_id_count) %>%
    dplyr::select(-hgnc_id)

  # Convert to data frame for MCA
  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    dplyr::select(-entity_id) %>%
    as.data.frame()
  row.names(sysndd_db_phenotypes_wider_df) <- sysndd_db_phenotypes_wider$entity_id

  # Check if gen_mca_clust_obj_mem is available
  if (!exists("gen_mca_clust_obj_mem", mode = "function")) {
    log_error("gen_mca_clust_obj_mem not available - clustering functions not loaded")
    return(NULL)
  }

  # Perform cluster analysis using memoized function
  phenotype_clusters <- tryCatch(
    gen_mca_clust_obj_mem(sysndd_db_phenotypes_wider_df),
    error = function(e) {
      log_error("Failed to generate phenotype clusters: {e$message}")
      return(NULL)
    }
  )

  if (is.null(phenotype_clusters)) {
    return(NULL)
  }

  # Find cluster matching the requested hash
  matching_cluster <- phenotype_clusters %>%
    dplyr::filter(hash_filter == !!hash_filter)

  if (nrow(matching_cluster) == 0) {
    log_warn("Phenotype cluster not found for hash: {substr(cluster_hash, 1, 16)}...")
    return(NULL)
  }

  cluster_number <- matching_cluster$cluster[1]

  # Extract identifiers and add symbols from entity view
  identifiers <- matching_cluster$identifiers[[1]]
  if (nrow(identifiers) == 0) {
    log_warn("No identifiers found for phenotype cluster {cluster_number}")
    return(NULL)
  }

  # Add symbol from entity view
  ndd_entity_view_sub <- ndd_entity_view_tbl %>%
    dplyr::select(entity_id, symbol) %>%
    dplyr::distinct()
  identifiers <- identifiers %>%
    dplyr::mutate(entity_id = as.integer(entity_id)) %>%
    dplyr::left_join(ndd_entity_view_sub, by = "entity_id")

  # Extract qualitative input variables
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


#------------------------------------------------------------------------------
# Prompt Template Database Functions
# Functions for managing admin-editable LLM prompt templates stored in database
#------------------------------------------------------------------------------

#' Get active prompt template from database
#'
#' Returns the active prompt template for the specified type.
#' Falls back to hardcoded default if no database entry exists.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#'
#' @return List with template_id, prompt_type, version, template_text, description
#'
#' @export
get_prompt_template <- function(prompt_type) {
  valid_types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )
  if (!prompt_type %in% valid_types) {
    log_error("Invalid prompt_type: {prompt_type}")
    rlang::abort(paste("Invalid prompt_type:", prompt_type))
  }

  # Try database first
  result <- tryCatch(
    {
      db_execute_query(
        "SELECT template_id, prompt_type, version, template_text, description
       FROM llm_prompt_templates
       WHERE prompt_type = ? AND is_active = TRUE
       ORDER BY created_at DESC
       LIMIT 1",
        list(prompt_type)
      )
    },
    error = function(e) {
      log_warn("Failed to query prompt templates: {e$message}")
      tibble::tibble()
    }
  )

  if (nrow(result) > 0) {
    return(list(
      template_id = result$template_id[1],
      prompt_type = result$prompt_type[1],
      version = result$version[1],
      template_text = result$template_text[1],
      description = result$description[1]
    ))
  }

  # Fallback to hardcoded defaults
  log_debug("Using hardcoded default for prompt_type: {prompt_type}")
  get_default_prompt_template(prompt_type)
}


#' Get hardcoded default prompt template
#'
#' Returns the original hardcoded prompt for backward compatibility.
#' Used when database table doesn't exist or has no entry for type.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#'
#' @return List with template_id, prompt_type, version, template_text, description
#'
#' @export
get_default_prompt_template <- function(prompt_type) {
  # Hardcoded fallbacks matching the original prompts in build_*_prompt functions
  templates <- list(
    functional_generation = paste0(
      "You are a genomics expert analyzing gene clusters associated with ",
      "neurodevelopmental disorders. Analyze this functional gene cluster and ",
      "summarize its biological significance based STRICTLY on the enrichment ",
      "data provided."
    ),
    functional_judge = paste0(
      "You are a STRICT scientific accuracy validator. Review the following ",
      "AI-generated summary and evaluate whether it accurately represents the ",
      "gene cluster data."
    ),
    phenotype_generation = paste0(
      "You are a clinical geneticist analyzing phenotype clusters from a ",
      "neurodevelopmental disorder database. Analyze this phenotype cluster ",
      "and describe its clinical pattern using ONLY the data listed."
    ),
    phenotype_judge = paste0(
      "You are a STRICT validator for AI-generated phenotype cluster summaries. ",
      "Review the following summary and evaluate scientific accuracy."
    )
  )

  list(
    template_id = NA_integer_,
    prompt_type = prompt_type,
    version = "1.0",
    template_text = templates[[prompt_type]],
    description = "Default hardcoded template"
  )
}


#' Save prompt template to database
#'
#' Creates a new version of a prompt template. Optionally deactivates
#' previous versions of the same type.
#'
#' @param prompt_type Character, one of "functional_generation", "functional_judge",
#'   "phenotype_generation", "phenotype_judge"
#' @param template_text Character, the prompt text
#' @param version Character, version string (e.g., "1.1")
#' @param description Character or NULL, description of changes
#' @param created_by Integer or NULL, user_id of creator
#' @param deactivate_previous Logical, if TRUE marks previous versions as inactive
#'
#' @return Integer, the template_id of the new entry
#'
#' @export
save_prompt_template <- function(prompt_type,
                                 template_text,
                                 version,
                                 description = NULL,
                                 created_by = NULL,
                                 deactivate_previous = TRUE) {
  valid_types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )
  if (!prompt_type %in% valid_types) {
    rlang::abort(paste("Invalid prompt_type:", prompt_type))
  }

  # Convert NULLs to NA for DBI binding (DBI requires length 1)
  description_val <- if (is.null(description)) NA_character_ else description
  created_by_val <- if (is.null(created_by)) NA_integer_ else as.integer(created_by)

  result <- db_with_transaction(function(txn_conn) {
    if (deactivate_previous) {
      db_execute_statement(
        "UPDATE llm_prompt_templates SET is_active = FALSE WHERE prompt_type = ?",
        list(prompt_type),
        conn = txn_conn
      )
    }

    db_execute_statement(
      "INSERT INTO llm_prompt_templates
       (prompt_type, version, template_text, description, is_active, created_by)
       VALUES (?, ?, ?, ?, TRUE, ?)",
      list(prompt_type, version, template_text, description_val, created_by_val),
      conn = txn_conn
    )

    id_result <- db_execute_query("SELECT LAST_INSERT_ID() AS id", conn = txn_conn)
    id_result$id[1]
  })

  log_info("Saved prompt template: type={prompt_type}, version={version}, id={result}")
  result
}


#' Get all prompt templates for admin display
#'
#' Returns the active template for each prompt type.
#'
#' @return Named list with template data for each type
#'
#' @export
get_all_prompt_templates <- function() {
  types <- c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )

  templates <- lapply(types, get_prompt_template)
  names(templates) <- types
  templates
}
