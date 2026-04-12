# functions/llm-client.R
#
# HTTP / SDK calls to LLM providers (Gemini via ellmer).
# Contains the core API interaction layer: model selection, chat calls,
# retry logic with exponential backoff, and configuration checks.
#
# Split from llm-service.R as part of v11.0 Phase D (D1).

require(glue)
require(logger)
require(jsonlite)

# Make ellmer optional - LLM features require it but basic API functions don't
if (!requireNamespace("ellmer", quietly = TRUE)) {
  log_warn("ellmer package not available - LLM client disabled")
}

#------------------------------------------------------------------------------
# Default Gemini model configuration
# Can be overridden via GEMINI_MODEL environment variable
# Options:
#   - gemini-3-flash-preview: Fast, high quality, good balance (default)
#   - gemini-3-pro-preview: Best quality, 250 RPD limit
#   - gemini-2.0-flash: Fast, unlimited RPD, good for high-volume
#------------------------------------------------------------------------------
get_default_gemini_model <- function() {
  model <- Sys.getenv("GEMINI_MODEL", "gemini-3-flash-preview")
  log_info("Using Gemini model: {model}")
  return(model)
}


#' Generate cluster summary using Gemini API
#'
#' Calls Gemini API via ellmer to generate a structured summary.
#' Implements retry with exponential backoff and complete logging.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (default: "gemini-3-pro-preview")
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
#'   model = "gemini-3-pro-preview"
#' )
#' }
#'
#' @export
generate_cluster_summary <- function(
  cluster_data,
  cluster_type = "functional",
  model = NULL,
  max_retries = 3,
  top_n_terms = 20
) {
  # Use default model if not specified
  if (is.null(model)) {
    model <- get_default_gemini_model()
  }
  # Debug logging for daemon execution
  logger::log_debug("generate_cluster_summary called for {cluster_type} cluster")

  # Check for API key (presence only — never log length or value).
  api_key <- Sys.getenv("GEMINI_API_KEY")
  logger::log_debug("GEMINI_API_KEY present: {nzchar(api_key)}")

  if (api_key == "" || is.na(api_key)) {
    logger::log_error("GEMINI_API_KEY not set")
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

  # Validate identifiers are non-empty
  if (!"identifiers" %in% names(cluster_data) || nrow(cluster_data$identifiers) == 0) {
    rlang::abort(
      "cluster_data must contain non-empty identifiers",
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

  # Build prompt using the appropriate builder for cluster type
  # For phenotype clusters: include all significant phenotypes (|v.test| > 2)
  # For functional clusters: use top N terms per category
  prompt <- if (cluster_type == "phenotype") {
    build_phenotype_cluster_prompt(cluster_data, vtest_threshold = 2)
  } else {
    build_cluster_prompt(cluster_data, top_n_terms = top_n_terms)
  }

  message("[LLM-Service] Generating ", cluster_type, " cluster summary with model=", model)
  log_info("Generating {cluster_type} cluster summary with model={model}")

  retries <- 0
  last_error <- NULL
  last_result <- NULL
  last_validation <- NULL

  while (retries < max_retries) {
    start_time <- Sys.time()
    message("[LLM-Service] Attempt ", retries + 1, "/", max_retries)

    tryCatch(
      {
        # Apply exponential backoff with jitter for retries
        if (retries > 0) {
          backoff_time <- (GEMINI_RATE_LIMIT$backoff_base^retries) + runif(1, 0, 1)
          message("[LLM-Service] Retry backoff: ", round(backoff_time, 1), "s")
          log_info("Retry {retries}/{max_retries}, backing off {round(backoff_time, 1)}s...")
          Sys.sleep(backoff_time)
        }

        # Create chat instance
        message("[LLM-Service] Creating chat instance with model: ", model)
        chat <- ellmer::chat_google_gemini(model = model)
        message("[LLM-Service] Chat instance created, calling chat_structured...")

        # Generate structured response
        # Note: chat_structured expects prompt as unnamed argument (part of ...)
        result <- chat$chat_structured(prompt, type = type_spec)
        message("[LLM-Service] chat_structured returned successfully")

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


#' List available Gemini models
#'
#' Returns a list of recommended Gemini models for cluster summary generation.
#' Updated February 2026 - gemini-2.0-flash deprecated March 31, 2026.
#'
#' @return Character vector of model names
#'
#' @export
list_gemini_models <- function() {
  c(
    "gemini-3-pro-preview", # Best quality, complex reasoning (default)
    "gemini-3-flash-preview", # Fast + capable
    "gemini-2.5-flash", # Best price-performance
    "gemini-2.5-pro", # Complex reasoning (stable)
    "gemini-2.5-flash-lite" # Budget option
  )
}
