# functions/llm-service.R
#
# Gemini API client using ellmer package for generating cluster summaries.
# Provides structured JSON output with type specifications.
#
# Key features:
# - Type specifications for guaranteed JSON structure
# - Exponential backoff with jitter for rate limit handling
# - Complete logging of all generation attempts
# - Cache integration for efficient summary retrieval

require(glue)
require(logger)
require(jsonlite)

# Make ellmer optional - LLM features require it but basic API functions don't
if (!requireNamespace("ellmer", quietly = TRUE)) {
  log_warn("ellmer package not available - LLM service disabled")
}

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

#------------------------------------------------------------------------------
# Rate limit configuration for Gemini API
# Based on Paid Tier 1: 60 RPM for gemini-3-pro-preview
# Using conservative limit to avoid rate limiting issues
#------------------------------------------------------------------------------
GEMINI_RATE_LIMIT <- list(
  capacity = 30,       # Conservative: 30 RPM (half of Paid Tier 1)
  fill_time_s = 60,    # 1 minute window
  backoff_base = 2,    # Exponential backoff base (seconds)
  max_retries = 3      # Maximum retry attempts
)

#------------------------------------------------------------------------------
# Type specifications for structured output
# Uses ellmer's type_object() for guaranteed JSON structure
#------------------------------------------------------------------------------

#' Type specification for functional cluster summary
#'
#' Defines the expected structure of LLM output for functional gene clusters.
#' Uses ellmer type specifications to guarantee valid JSON response.
#'
#' @export
functional_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a functional gene cluster",

  summary = ellmer::type_string(
    "2-3 sentence prose summary describing the cluster's biological function
     and relevance to neurodevelopmental disorders.
     Target audience: clinical researchers and database curators."
  ),

  key_themes = ellmer::type_array(
    ellmer::type_string("Biological theme or function"),
    "3-5 key biological themes that characterize this cluster"
  ),

  pathways = ellmer::type_array(
    ellmer::type_string("Pathway name from enrichment analysis"),
    "Top pathways from the enrichment data that define this cluster.
     Must be exact matches from the provided enrichment terms."
  ),

  tags = ellmer::type_array(
    ellmer::type_string("Searchable keyword for filtering"),
    "3-7 short, searchable tags (e.g., 'mitochondrial', 'synaptic', 'metabolism')"
  ),

  clinical_relevance = ellmer::type_string(
    "Brief note on clinical implications for NDD diagnosis or research",
    required = FALSE
  ),

  confidence = ellmer::type_enum(
    c("high", "medium", "low"),
    "Self-assessed confidence: high if enrichment data strongly supports themes,
     medium if moderate support, low if sparse data or ambiguous patterns"
  )
)

#' Type specification for phenotype cluster summary
#'
#' Extends functional cluster summary with phenotype-specific fields.
#'
#' @export
phenotype_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a phenotype cluster",

  summary = ellmer::type_string(
    "2-3 sentence prose summary describing the cluster's phenotype patterns
     and relevance to neurodevelopmental disorders.
     Target audience: clinical researchers and database curators."
  ),

  key_themes = ellmer::type_array(
    ellmer::type_string("Phenotype theme or pattern"),
    "3-5 key phenotypic themes that characterize this cluster"
  ),

  pathways = ellmer::type_array(
    ellmer::type_string("Pathway or term from enrichment analysis"),
    "Top pathways or terms from the enrichment data that define this cluster.
     Must be exact matches from the provided enrichment terms."
  ),

  tags = ellmer::type_array(
    ellmer::type_string("Searchable keyword for filtering"),
    "3-7 short, searchable tags (e.g., 'hypotonia', 'epilepsy', 'ataxia')"
  ),

  clinical_relevance = ellmer::type_string(
    "Brief note on clinical implications for NDD diagnosis or research",
    required = FALSE
  ),

  confidence = ellmer::type_enum(
    c("high", "medium", "low"),
    "Self-assessed confidence: high if enrichment data strongly supports themes,
     medium if moderate support, low if sparse data or ambiguous patterns"
  ),

  # Phenotype-specific fields
  syndrome_hints = ellmer::type_array(
    ellmer::type_string("Recognized syndrome name"),
    "Potential syndrome associations suggested by phenotype pattern",
    required = FALSE
  ),

  curation_notes = ellmer::type_string(
    "Notes for curators on phenotype patterns or potential gene associations",
    required = FALSE
  )
)


#' Build prompt for cluster summary generation
#'
#' Constructs a prompt for the LLM using cluster data and enrichment terms.
#' Does NOT include JSON schema in prompt (ellmer handles via type spec).
#'
#' @param cluster_data List containing:
#'   - identifiers: tibble with symbol column (gene symbols)
#'   - term_enrichment: tibble with category, term, fdr columns
#' @param top_n_terms Integer, number of enrichment terms per category (default: 20)
#'
#' @return Character string, the formatted prompt
#'
#' @examples
#' \dontrun{
#' prompt <- build_cluster_prompt(cluster_data, top_n_terms = 20)
#' }
#'
#' @export
build_cluster_prompt <- function(cluster_data, top_n_terms = 20) {
  # Validate input
  if (!is.list(cluster_data)) {
    rlang::abort("cluster_data must be a list", class = "llm_service_error")
  }

  if (!"identifiers" %in% names(cluster_data)) {
    rlang::abort("cluster_data must contain 'identifiers' element", class = "llm_service_error")
  }

  # Extract gene symbols
  if ("symbol" %in% names(cluster_data$identifiers)) {
    genes <- paste(cluster_data$identifiers$symbol, collapse = ", ")
    gene_count <- nrow(cluster_data$identifiers)
  } else {
    genes <- "(gene symbols not provided)"
    gene_count <- nrow(cluster_data$identifiers)
  }

  # Extract and format enrichment terms by category
  enrichment_text <- ""
  if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    enrichment <- cluster_data$term_enrichment %>%
      dplyr::group_by(category) %>%
      dplyr::slice_head(n = top_n_terms) %>%
      dplyr::ungroup()

    enrichment_text <- enrichment %>%
      dplyr::mutate(term_line = glue::glue("- {term} (FDR: {signif(fdr, 3)})")) %>%
      dplyr::group_by(category) %>%
      dplyr::summarise(terms = paste(term_line, collapse = "\n"), .groups = "drop") %>%
      dplyr::mutate(section = glue::glue("### {category}\n{terms}")) %>%
      dplyr::pull(section) %>%
      paste(collapse = "\n\n")
  } else {
    enrichment_text <- "(No enrichment data provided)"
  }

  prompt <- glue::glue("
You are an expert in neurodevelopmental disorders and genomics.
Analyze this gene cluster and provide a summary.

## Cluster Information
- **Cluster Size:** {gene_count} genes
- **Genes:** {genes}

## Enrichment Analysis Results
{enrichment_text}

## Instructions
1. Summarize what biological functions unite these genes
2. Identify 3-5 key themes based on the enrichment data
3. List the most significant pathways (use exact names from enrichment above)
4. Suggest 3-7 searchable tags (lowercase, single words)
5. Note any clinical relevance for neurodevelopmental disorder research
6. Assess your confidence based on enrichment data strength
")

  return(prompt)
}


#' Generate cluster summary using Gemini API
#'
#' Calls Gemini API via ellmer to generate a structured summary.
#' Implements retry with exponential backoff and complete logging.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (default: "gemini-2.0-flash")
#' @param max_retries Integer, maximum retry attempts (default: 3)
#' @param top_n_terms Integer, number of enrichment terms per category (default: 20)
#'
#' @return List with:
#'   - success: Logical, TRUE if generation succeeded
#'   - summary: List with structured summary (if success)
#'   - tokens_input: Integer, input token count
#'   - tokens_output: Integer, output token count
#'   - latency_ms: Integer, API call latency
#'   - error: Character, error message (if failed)
#'   - attempts: Integer, number of attempts made
#'
#' @details
#' - Checks GEMINI_API_KEY environment variable
#' - Uses ellmer::chat_google_gemini() for API calls
#' - Uses chat$chat_structured() with type specifications
#' - Implements exponential backoff with jitter for retries
#' - Logs all attempts via log_generation_attempt()
#'
#' @examples
#' \dontrun{
#' result <- generate_cluster_summary(
#'   cluster_data = list(
#'     identifiers = tibble(hgnc_id = 1:10, symbol = paste0("GENE", 1:10)),
#'     term_enrichment = tibble(category = "GO", term = "pathway", fdr = 0.001)
#'   ),
#'   cluster_type = "functional",
#'   model = "gemini-2.0-flash"
#' )
#' }
#'
#' @export
generate_cluster_summary <- function(
  cluster_data,
  cluster_type = "functional",
  model = "gemini-2.0-flash",
  max_retries = 3,
  top_n_terms = 20
) {
  # Check for API key
  api_key <- Sys.getenv("GEMINI_API_KEY")
  if (api_key == "" || is.na(api_key)) {
    rlang::abort(
      "GEMINI_API_KEY environment variable is not set. Please set it to your Gemini API key.",
      class = "llm_service_error"
    )
  }

  # Validate cluster_type
  if (!cluster_type %in% c("functional", "phenotype")) {
    rlang::abort(
      paste("Invalid cluster_type:", cluster_type, "- must be 'functional' or 'phenotype'"),
      class = "llm_service_error"
    )
  }

  # Generate cluster hash for logging
  cluster_hash <- if ("identifiers" %in% names(cluster_data)) {
    id_col <- if (cluster_type == "functional") "hgnc_id" else "entity_id"
    if (id_col %in% names(cluster_data$identifiers)) {
      generate_cluster_hash(cluster_data$identifiers, cluster_type)
    } else {
      digest::digest(as.character(cluster_data), algo = "sha256", serialize = FALSE)
    }
  } else {
    digest::digest(as.character(cluster_data), algo = "sha256", serialize = FALSE)
  }

  # Get cluster number if available
  cluster_number <- cluster_data$cluster_number %||% 0L

  # Select type specification based on cluster type
  type_spec <- if (cluster_type == "functional") {
    functional_cluster_summary_type
  } else {
    phenotype_cluster_summary_type
  }

  # Build prompt
  prompt <- build_cluster_prompt(cluster_data, top_n_terms = top_n_terms)

  log_info("Generating {cluster_type} cluster summary with model={model}")

  retries <- 0
  last_error <- NULL
  last_result <- NULL
  last_validation <- NULL

  while (retries < max_retries) {
    start_time <- Sys.time()

    tryCatch(
      {
        # Apply exponential backoff with jitter for retries
        if (retries > 0) {
          backoff_time <- (GEMINI_RATE_LIMIT$backoff_base^retries) + runif(1, 0, 1)
          log_info("Retry {retries}/{max_retries}, backing off {round(backoff_time, 1)}s...")
          Sys.sleep(backoff_time)
        }

        # Create chat instance
        chat <- ellmer::chat_google_gemini(model = model)

        # Generate structured response
        result <- chat$chat_structured(
          prompt = prompt,
          type = type_spec
        )

        # Calculate latency
        end_time <- Sys.time()
        latency_ms <- as.integer(difftime(end_time, start_time, units = "secs") * 1000)

        # Get token usage (if available from chat object)
        # Note: ellmer may not expose token counts directly; use NULL if unavailable
        tokens_input <- NULL
        tokens_output <- NULL

        # Store for potential retry tracking
        last_result <- result

        # Validate entities in the generated summary
        validation <- validate_summary_entities(result, cluster_data)
        last_validation <- validation

        if (validation$is_valid) {
          # Log successful generation with validation pass
          log_generation_attempt(
            cluster_type = cluster_type,
            cluster_number = as.integer(cluster_number),
            cluster_hash = cluster_hash,
            model_name = model,
            status = "success",
            prompt_text = prompt,
            response_json = result,
            tokens_input = tokens_input,
            tokens_output = tokens_output,
            latency_ms = latency_ms
          )

          log_info("Successfully generated and validated {cluster_type} cluster summary in {latency_ms}ms")

          return(list(
            success = TRUE,
            summary = result,
            tokens_input = tokens_input,
            tokens_output = tokens_output,
            latency_ms = latency_ms,
            validation = validation
          ))
        } else {
          # Validation failed - log and retry
          validation_errors <- paste(validation$errors, collapse = "; ")
          log_generation_attempt(
            cluster_type = cluster_type,
            cluster_number = as.integer(cluster_number),
            cluster_hash = cluster_hash,
            model_name = model,
            status = "validation_failed",
            prompt_text = prompt,
            response_json = result,
            validation_errors = validation_errors,
            tokens_input = tokens_input,
            tokens_output = tokens_output,
            latency_ms = latency_ms
          )

          retries <- retries + 1
          last_error <- paste("Validation failed:", validation_errors)
          log_warn("Validation failed (attempt {retries}): {validation_errors}")
        }
      },
      error = function(e) {
        retries <<- retries + 1
        last_error <<- conditionMessage(e)

        # Calculate latency even for failed attempts
        end_time <- Sys.time()
        latency_ms <- as.integer(difftime(end_time, start_time, units = "secs") * 1000)

        # Determine error status
        error_status <- if (grepl("429|rate.?limit|quota", tolower(last_error))) {
          "api_error"
        } else if (grepl("timeout|timed.?out", tolower(last_error))) {
          "timeout"
        } else {
          "api_error"
        }

        # Log failed attempt
        log_generation_attempt(
          cluster_type = cluster_type,
          cluster_number = as.integer(cluster_number),
          cluster_hash = cluster_hash,
          model_name = model,
          status = error_status,
          prompt_text = prompt,
          response_json = NULL,
          latency_ms = latency_ms,
          error_message = last_error
        )

        log_warn("LLM call failed (attempt {retries}): {last_error}")
      }
    )
  }

  # All retries exhausted
  log_error("LLM generation failed after {max_retries} attempts: {last_error}")

  return(list(
    success = FALSE,
    error = last_error,
    attempts = retries,
    last_result = last_result,
    last_validation = last_validation
  ))
}


#' Get or generate cluster summary
#'
#' Checks cache for existing summary; generates new one if not found or invalid.
#' This is the main entry point for cluster summary retrieval.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (default: "gemini-2.0-flash")
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
  model = "gemini-2.0-flash",
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
      summary_with_confidence$derived_confidence <- calculate_derived_confidence(cluster_data$term_enrichment)

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

  # Calculate derived confidence from enrichment data
  derived_confidence <- calculate_derived_confidence(cluster_data$term_enrichment)

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


#' Check if Gemini API is configured
#'
#' Utility function to verify API key is set before attempting operations.
#'
#' @return Logical, TRUE if GEMINI_API_KEY is set
#'
#' @export
is_gemini_configured <- function() {
  api_key <- Sys.getenv("GEMINI_API_KEY")
  return(api_key != "" && !is.na(api_key))
}


#' Calculate derived confidence from enrichment data
#'
#' Computes a confidence score based on enrichment data strength.
#' Provides an objective measure independent of LLM self-assessment.
#'
#' @param enrichment_data Tibble with term enrichment data containing 'fdr' column
#'
#' @return List with:
#'   - avg_fdr: Average FDR across top terms
#'   - term_count: Number of significant terms (FDR < 0.05)
#'   - score: Derived confidence score ("high", "medium", or "low")
#'
#' @details
#' Confidence scoring:
#' - high: avg_fdr < 1e-10 AND term_count > 20
#' - medium: avg_fdr < 1e-5 AND term_count > 10
#' - low: otherwise
#'
#' @examples
#' \dontrun{
#' enrichment <- tibble(term = c("GO:001", "GO:002"), fdr = c(1e-12, 1e-15))
#' conf <- calculate_derived_confidence(enrichment)
#' # conf$score = "high"
#' }
#'
#' @export
calculate_derived_confidence <- function(enrichment_data) {
  # Handle NULL or empty enrichment data
  if (is.null(enrichment_data) || nrow(enrichment_data) == 0) {
    return(list(
      avg_fdr = NA_real_,
      term_count = 0L,
      score = "low"
    ))
  }

  # Ensure fdr column exists
  if (!"fdr" %in% names(enrichment_data)) {
    log_warn("Enrichment data missing 'fdr' column, returning low confidence")
    return(list(
      avg_fdr = NA_real_,
      term_count = nrow(enrichment_data),
      score = "low"
    ))
  }

  # Count significant terms (FDR < 0.05)
  significant_terms <- enrichment_data %>%
    dplyr::filter(fdr < 0.05)

  term_count <- nrow(significant_terms)

  # Calculate average FDR across significant terms
  avg_fdr <- if (term_count > 0) {
    mean(significant_terms$fdr, na.rm = TRUE)
  } else {
    NA_real_
  }

  # Determine confidence score
  score <- if (!is.na(avg_fdr) && avg_fdr < 1e-10 && term_count > 20) {
    "high"
  } else if (!is.na(avg_fdr) && avg_fdr < 1e-5 && term_count > 10) {
    "medium"
  } else {
    "low"
  }

  log_debug("Derived confidence: avg_fdr={signif(avg_fdr, 3)}, term_count={term_count}, score={score}")

  list(
    avg_fdr = avg_fdr,
    term_count = as.integer(term_count),
    score = score
  )
}


#' List available Gemini models
#'
#' Returns a list of commonly used Gemini models for cluster summary generation.
#'
#' @return Character vector of model names
#'
#' @export
list_gemini_models <- function() {
  c(
    "gemini-2.0-flash",       # Fast, cost-effective
    "gemini-2.5-flash",       # Newer flash model
    "gemini-3-pro-preview"    # Best quality (preview)
  )
}
