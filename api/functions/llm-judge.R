# functions/llm-judge.R
#
# LLM-as-judge validation for cluster summaries.
# Uses Gemini to evaluate summary accuracy and grounding.
#
# Key features:
# - Three-tier verdict: accept, low_confidence, reject
# - Same model as generation for consistency
# - Stores verdict and reasoning in summary metadata

require(logger)
require(glue)

# Make ellmer optional - LLM features require it but basic API functions don't
if (!requireNamespace("ellmer", quietly = TRUE)) {
  log_warn("ellmer package not available - LLM judge disabled")
}

log_threshold(INFO)

# Load LLM service functions (if not already loaded)
if (!exists("generate_cluster_summary", mode = "function")) {
  if (file.exists("functions/llm-service.R")) {
    source("functions/llm-service.R", local = TRUE)
  }
}

# Load cache repository functions (if not already loaded)
if (!exists("save_summary_to_cache", mode = "function")) {
  if (file.exists("functions/llm-cache-repository.R")) {
    source("functions/llm-cache-repository.R", local = TRUE)
  }
}


#' Type specification for LLM-as-judge validation verdict
#'
#' Defines the expected structure of judge validation response.
#' Uses ellmer type specifications to guarantee valid JSON.
#'
#' @export
llm_judge_verdict_type <- ellmer::type_object(
  "Validation verdict for a cluster summary",

  is_factually_accurate = ellmer::type_boolean(
    "Summary accurately describes biological function of the genes"
  ),

  is_grounded = ellmer::type_boolean(
    "All claims are supported by the enrichment data provided"
  ),

  pathways_valid = ellmer::type_boolean(
    "Listed pathways match the enrichment input (no invented pathways)"
  ),

  confidence_appropriate = ellmer::type_boolean(
    "Self-assessed confidence matches the evidence strength"
  ),

  reasoning = ellmer::type_string(
    "Brief explanation of assessment (2-3 sentences)"
  ),

  verdict = ellmer::type_enum(
    c("accept", "low_confidence", "reject"),
    "Final verdict: accept (cache as validated), low_confidence (cache but flag),
     reject (do not cache, trigger regeneration)"
  )
)


#' Validate cluster summary using LLM-as-judge
#'
#' Evaluates a generated summary for accuracy and grounding using Gemini.
#' Returns a structured verdict with reasoning.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data (identifiers and enrichment)
#' @param model Character, Gemini model name (default: "gemini-3-pro-preview")
#'
#' @return List with verdict structure:
#'   - is_factually_accurate: Logical
#'   - is_grounded: Logical
#'   - pathways_valid: Logical
#'   - confidence_appropriate: Logical
#'   - reasoning: Character
#'   - verdict: Character ("accept", "low_confidence", or "reject")
#'
#' @details
#' - Uses same model as generation for consistency
#' - Evaluates factual accuracy, grounding in data, pathway validity
#' - Returns low_confidence verdict if judge fails (graceful degradation)
#' - Logs all verdicts for calibration analysis
#'
#' @examples
#' \dontrun{
#' verdict <- validate_with_llm_judge(
#'   summary = generated_summary,
#'   cluster_data = cluster_data,
#'   model = "gemini-3-pro-preview"
#' )
#' }
#'
#' @export
validate_with_llm_judge <- function(summary, cluster_data, model = "gemini-2.0-flash") {
  # Handle NULL inputs
  if (is.null(summary)) {
    log_warn("Judge received NULL summary, returning reject verdict")
    return(list(
      is_factually_accurate = FALSE,
      is_grounded = FALSE,
      pathways_valid = FALSE,
      confidence_appropriate = FALSE,
      reasoning = "Summary is NULL",
      verdict = "reject"
    ))
  }

  if (is.null(cluster_data)) {
    log_warn("Judge received NULL cluster_data, returning low_confidence verdict")
    return(list(
      is_factually_accurate = NA,
      is_grounded = FALSE,
      pathways_valid = FALSE,
      confidence_appropriate = FALSE,
      reasoning = "Cluster data unavailable for validation",
      verdict = "low_confidence"
    ))
  }

  log_info("Validating summary with LLM-as-judge (model={model})")

  # Extract context for judge
  genes <- if ("identifiers" %in% names(cluster_data) && "symbol" %in% names(cluster_data$identifiers)) {
    paste(cluster_data$identifiers$symbol, collapse = ", ")
  } else {
    "(genes not available)"
  }

  # Extract top 15 enrichment terms for validation
  enrichment_terms <- if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    cluster_data$term_enrichment %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = 15) %>%
      dplyr::mutate(term_line = glue::glue("- {category}: {term} (FDR: {signif(fdr, 3)})")) %>%
      dplyr::pull(term_line) %>%
      paste(collapse = "\n")
  } else {
    "(no enrichment data)"
  }

  # Extract summary components for evaluation
  summary_text <- summary$summary %||% ""
  key_themes <- if (!is.null(summary$key_themes) && length(summary$key_themes) > 0) {
    paste(summary$key_themes, collapse = ", ")
  } else {
    "(none)"
  }
  pathways <- if (!is.null(summary$pathways) && length(summary$pathways) > 0) {
    paste(summary$pathways, collapse = ", ")
  } else {
    "(none)"
  }
  self_confidence <- summary$confidence %||% "unknown"

  # Build judge prompt
  judge_prompt <- glue::glue("
You are a scientific accuracy validator for AI-generated gene cluster summaries.
Evaluate the following summary for accuracy and grounding.

## Original Cluster Data
**Genes:** {genes}

**Top 15 Enrichment Terms:**
{enrichment_terms}

## Generated Summary to Validate
**Summary text:** {summary_text}

**Key themes:** {key_themes}

**Pathways listed:** {pathways}

**Self-assessed confidence:** {self_confidence}

## Validation Criteria
1. **Factual accuracy:** Does the summary accurately describe biological functions?
2. **Grounding:** Are all claims supported by the enrichment data above?
3. **Pathway validity:** Are the listed pathways exact matches from the enrichment terms (or reasonable generalizations)?
4. **Confidence appropriate:** Does the self-assessed confidence match the evidence strength?

## Instructions
Evaluate each criterion and provide a final verdict:
- **accept:** Summary is accurate and well-grounded, cache as validated
- **low_confidence:** Summary is mostly accurate but has minor issues, cache but flag for review
- **reject:** Summary has significant errors or invented information, trigger regeneration
")

  # Call judge LLM
  tryCatch(
    {
      # Create chat instance
      chat <- ellmer::chat_google_gemini(model = model)

      # Get structured verdict
      # Note: chat_structured expects prompt as unnamed argument (part of ...)
      verdict <- chat$chat_structured(judge_prompt, type = llm_judge_verdict_type)

      log_info("Judge verdict: {verdict$verdict} (reasoning: {substr(verdict$reasoning, 1, 80)}...)")

      return(verdict)
    },
    error = function(e) {
      log_warn("LLM-as-judge failed: {e$message}, returning low_confidence verdict")
      return(list(
        is_factually_accurate = NA,
        is_grounded = NA,
        pathways_valid = NA,
        confidence_appropriate = NA,
        reasoning = paste("Judge validation failed:", conditionMessage(e)),
        verdict = "low_confidence"
      ))
    }
  )
}


#' Generate and validate cluster summary with LLM-as-judge
#'
#' Complete pipeline: generate summary, validate entities, validate with judge, cache.
#' This is the main entry point for generating summaries with validation.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (default: "gemini-3-pro-preview")
#'
#' @return List with:
#'   - success: Logical, TRUE if accepted or low_confidence, FALSE if rejected
#'   - summary: List with structured summary (if success)
#'   - cache_id: Integer, cache ID (if cached)
#'   - validation_status: Character, "validated", "pending", or "rejected"
#'   - judge_result: List with judge verdict and reasoning
#'   - error: Character, error message (if failed)
#'
#' @details
#' Pipeline steps:
#' 1. Generate summary with generate_cluster_summary() (includes entity validation)
#' 2. Validate summary with LLM-as-judge
#' 3. Map verdict to validation_status:
#'    - accept -> validated
#'    - low_confidence -> pending
#'    - reject -> rejected
#' 4. Add judge metadata (verdict, reasoning, derived_confidence)
#' 5. Save to cache with appropriate validation_status
#' 6. Return success=FALSE for rejected summaries (triggers retry in batch)
#'
#' @examples
#' \dontrun{
#' result <- generate_and_validate_with_judge(
#'   cluster_data = cluster_data,
#'   cluster_type = "functional"
#' )
#'
#' if (result$success) {
#'   print(paste("Cached as:", result$validation_status))
#' }
#' }
#'
#' @export
generate_and_validate_with_judge <- function(
  cluster_data,
  cluster_type = "functional",
  model = "gemini-2.0-flash"
) {
  log_info("Starting generation + validation pipeline for {cluster_type} cluster")

  # Step 1: Generate summary (includes entity validation)
  gen_result <- tryCatch(
    generate_cluster_summary(
      cluster_data = cluster_data,
      cluster_type = cluster_type,
      model = model
    ),
    error = function(e) {
      log_error("Summary generation failed: {e$message}")
      return(list(success = FALSE, error = e$message))
    }
  )

  # If generation failed, return early
  if (!gen_result$success) {
    return(list(
      success = FALSE,
      error = gen_result$error,
      validation_status = "rejected"
    ))
  }

  # Step 2: Validate with LLM-as-judge
  judge_result <- validate_with_llm_judge(
    summary = gen_result$summary,
    cluster_data = cluster_data,
    model = model
  )

  # Step 3: Map verdict to validation_status
  validation_status <- switch(
    judge_result$verdict,
    "accept" = "validated",
    "low_confidence" = "pending",
    "reject" = "rejected",
    "pending"  # Fallback
  )

  # Determine success flag (reject -> FALSE to trigger retry)
  success <- validation_status != "rejected"

  log_info("Judge verdict: {judge_result$verdict} -> validation_status={validation_status}, success={success}")

  # Step 4: Add judge metadata to summary
  summary_with_metadata <- gen_result$summary

  # Add judge verdict and reasoning
  summary_with_metadata$llm_judge_verdict <- judge_result$verdict
  summary_with_metadata$llm_judge_reasoning <- judge_result$reasoning

  # Add derived confidence if not already present
  if (is.null(summary_with_metadata$derived_confidence)) {
    summary_with_metadata$derived_confidence <- calculate_derived_confidence(cluster_data$term_enrichment)
  }

  # Step 5: Save to cache with validation_status
  cluster_number <- cluster_data$cluster_number %||% 0L
  cluster_hash <- tryCatch(
    {
      id_col <- if (cluster_type == "functional") "hgnc_id" else "entity_id"
      if (id_col %in% names(cluster_data$identifiers)) {
        generate_cluster_hash(cluster_data$identifiers, cluster_type)
      } else {
        digest::digest(as.character(cluster_data), algo = "sha256", serialize = FALSE)
      }
    },
    error = function(e) {
      digest::digest(as.character(cluster_data), algo = "sha256", serialize = FALSE)
    }
  )

  cache_id <- tryCatch(
    save_summary_to_cache(
      cluster_type = cluster_type,
      cluster_number = as.integer(cluster_number),
      cluster_hash = cluster_hash,
      model_name = model,
      prompt_version = "1.0",
      summary_json = summary_with_metadata,
      tags = gen_result$summary$tags,
      validation_status = validation_status
    ),
    error = function(e) {
      log_error("Failed to save to cache: {e$message}")
      return(NULL)
    }
  )

  # Step 6: Return result
  if (is.null(cache_id)) {
    return(list(
      success = FALSE,
      error = "Failed to save to cache",
      validation_status = validation_status,
      judge_result = judge_result
    ))
  }

  log_info("Summary cached (cache_id={cache_id}, status={validation_status})")

  return(list(
    success = success,
    summary = summary_with_metadata,
    cache_id = cache_id,
    validation_status = validation_status,
    judge_result = judge_result,
    tokens_input = gen_result$tokens_input,
    tokens_output = gen_result$tokens_output,
    latency_ms = gen_result$latency_ms
  ))
}
