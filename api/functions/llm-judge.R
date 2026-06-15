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

# Load judge prompt builders (extracted to functions/llm-judge-prompts.R, #448).
# Bootstrap sources that file first; this guard makes llm-judge.R self-sufficient
# when sourced standalone (e.g. in tests).
if (!exists("build_phenotype_judge_prompt", mode = "function")) {
  if (file.exists("functions/llm-judge-prompts.R")) {
    source("functions/llm-judge-prompts.R", local = TRUE)
  }
}


#' Type specification for LLM-as-judge validation verdict
#'
#' Defines the expected structure of judge validation response.
#' Uses ellmer type specifications to guarantee valid JSON.
#'
#' @export
llm_judge_verdict_type <- ellmer::type_object(
  "Validation verdict for a cluster summary with optional corrections",

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

  corrections_needed = ellmer::type_boolean(
    "TRUE if minor corrections were made to the summary"
  ),

  corrections_made = ellmer::type_array(
    ellmer::type_string("Description of each correction made"),
    "List of corrections applied (empty if none needed)"
  ),

  corrected_tags = ellmer::type_array(
    ellmer::type_string("Corrected tag"),
    "Tags after removing any that don't appear in source data (only if corrections needed)"
  ),

  corrected_notably_absent = ellmer::type_array(
    ellmer::type_string("Phenotype that IS in source data as depleted"),
    "Notably absent list after removing items not in source data (only if corrections needed).
     Only applicable for phenotype clusters.",
    required = FALSE
  ),

  corrected_inheritance_patterns = ellmer::type_array(
    ellmer::type_string("Inheritance mode abbreviation from source data"),
    "Inheritance patterns after correction (only include patterns from quali_sup_var with |v.test| > 2).
     Only applicable for phenotype clusters - leave empty for functional clusters.",
    required = FALSE
  ),

  corrected_syndromicity = ellmer::type_enum(
    c("predominantly_syndromic", "predominantly_id", "mixed", "unknown"),
    "Syndromicity corrected based on quanti_sup_var data.
     Only applicable for phenotype clusters - leave NULL for functional clusters.",
    required = FALSE
  ),

  corrected_summary = ellmer::type_string(
    "Corrected main summary text. Provide ONLY when verdict is
     accept_with_corrections AND the main summary needed wording fixes (e.g. an
     isolated molecular phrase rewritten as a clinical phenotype description, or
     an over-reaching label trimmed). The corrected text must stay grounded in
     the input data and contain no molecular/gene/pathway mechanism language.
     Leave empty when the main summary text needs no change.",
    required = FALSE
  ),

  reasoning = ellmer::type_string(
    "Brief explanation of assessment including any corrections (2-3 sentences)"
  ),

  verdict = ellmer::type_enum(
    c("accept", "accept_with_corrections", "low_confidence", "reject"),
    "Final verdict: accept (perfect), accept_with_corrections (minor fixes applied),
     low_confidence (concerns but usable), reject (severe hallucinations only)"
  )
)


#' Validate cluster summary using LLM-as-judge
#'
#' Evaluates a generated summary for accuracy and grounding using Gemini.
#' Returns a structured verdict with reasoning.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data (identifiers and enrichment)
#' @param model Character, Gemini model name (defaults to get_default_gemini_model())
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
#'   model = "gemini-3.5-flash"
#' )
#' }
#'
#' @export
validate_with_llm_judge <- function(summary, cluster_data, model = NULL, cluster_type = "functional") {
  # Use default model if not specified
  if (is.null(model)) {
    model <- get_default_gemini_model()
  }
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

  log_info("Validating summary with LLM-as-judge (model={model}, type={cluster_type})")

  # Build appropriate judge prompt based on cluster type
  judge_prompt <- if (cluster_type == "phenotype") {
    build_phenotype_judge_prompt(summary, cluster_data)
  } else {
    build_functional_judge_prompt(summary, cluster_data)
  }

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


#' Apply judge corrections to a generated summary.
#'
#' When the judge returns `corrections_needed = TRUE`, copy any corrected fields
#' onto the summary. Beyond the supporting fields (tags / notably_absent /
#' inheritance_patterns / syndromicity), this also applies `corrected_summary`
#' to the main summary text (#448) so an otherwise-grounded clinical summary with
#' an isolated molecular phrase or over-reaching label can be salvaged via
#' `accept_with_corrections` instead of being permanently rejected. A no-op when
#' `corrections_needed` is not TRUE.
#'
#' @param summary List, the generated summary.
#' @param judge_result List, the judge verdict (with optional corrected_* fields).
#' @return The summary list with corrections applied (and corrections metadata).
#' @export
apply_judge_corrections <- function(summary, judge_result) {
  if (!isTRUE(judge_result$corrections_needed)) {
    return(summary)
  }
  log_info("Applying judge corrections to summary")

  # Corrected main summary text (#448): salvage isolated molecular phrasing /
  # over-reach rather than hard-rejecting an otherwise-grounded summary.
  cs <- judge_result$corrected_summary
  if (!is.null(cs) && length(cs) > 0 && nzchar(trimws(as.character(cs[[1]])))) {
    summary$summary <- as.character(cs[[1]])
    log_debug("Applied corrected_summary")
  }

  # Corrected tags
  if (!is.null(judge_result$corrected_tags) && length(judge_result$corrected_tags) > 0) {
    summary$tags <- judge_result$corrected_tags
    log_debug("Applied corrected tags: {paste(judge_result$corrected_tags, collapse=', ')}")
  }

  # Corrected notably_absent
  if (!is.null(judge_result$corrected_notably_absent)) {
    summary$notably_absent <- judge_result$corrected_notably_absent
    log_debug("Applied corrected notably_absent")
  }

  # Corrected inheritance_patterns
  corrected_inh <- judge_result$corrected_inheritance_patterns
  if (!is.null(corrected_inh) && length(corrected_inh) > 0) {
    summary$inheritance_patterns <- corrected_inh
    log_debug("Applied corrected inheritance_patterns")
  }

  # Corrected syndromicity
  if (!is.null(judge_result$corrected_syndromicity) &&
        nzchar(judge_result$corrected_syndromicity)) {
    summary$syndromicity <- judge_result$corrected_syndromicity
    log_debug("Applied corrected syndromicity: {judge_result$corrected_syndromicity}")
  }

  summary$corrections_applied <- TRUE
  summary$corrections_made <- judge_result$corrections_made
  summary
}


#' Generate and validate cluster summary with LLM-as-judge
#'
#' Complete pipeline: generate summary, validate entities, validate with judge, cache.
#' This is the main entry point for generating summaries with validation.
#'
#' @param cluster_data List containing identifiers and term_enrichment
#' @param cluster_type Character, "functional" or "phenotype"
#' @param model Character, Gemini model name (defaults to get_default_gemini_model())
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
  model = NULL,
  cluster_hash = NULL
) {
  # Use default model if not specified
  if (is.null(model)) {
    model <- get_default_gemini_model()
  }
  log_info("Starting generation + validation pipeline for {cluster_type} cluster with model={model}")

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
    model = model,
    cluster_type = cluster_type
  )

  # Step 3: Map verdict to validation_status
  validation_status <- switch(
    judge_result$verdict,
    "accept" = "validated",
    "accept_with_corrections" = "validated",  # Corrected summaries are validated
    "low_confidence" = "pending",
    "reject" = "rejected",
    "pending"  # Fallback
  )

  # Determine success flag (reject -> FALSE to trigger retry)
  success <- validation_status != "rejected"

  log_info("Judge verdict: {judge_result$verdict} -> validation_status={validation_status}, success={success}")

  # Step 4: Add judge metadata to summary
  summary_with_metadata <- apply_judge_corrections(gen_result$summary, judge_result)

  # Add judge verdict and reasoning
  summary_with_metadata$llm_judge_verdict <- judge_result$verdict
  summary_with_metadata$llm_judge_reasoning <- judge_result$reasoning

  # Add derived confidence if not already present
  if (is.null(summary_with_metadata$derived_confidence)) {
    # Use appropriate data source for confidence calculation based on cluster type
    confidence_data <- if (cluster_type == "phenotype") {
      cluster_data$quali_inp_var
    } else {
      cluster_data$term_enrichment
    }
    summary_with_metadata$derived_confidence <- calculate_derived_confidence(confidence_data, cluster_type)
  }

  # Step 5: Save to cache with validation_status
  cluster_number <- cluster_data$cluster_number %||% 0L

  # Use passed-in cluster_hash if provided (from batch generator extracting hash_filter),
  # otherwise fallback to generating from identifiers
  final_hash <- if (!is.null(cluster_hash) && nzchar(cluster_hash)) {
    message("[llm-judge] Using passed cluster_hash: ", substr(cluster_hash, 1, 16), "...")
    cluster_hash
  } else {
    message("[llm-judge] No cluster_hash passed, generating from identifiers")
    tryCatch(
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
  }

  cache_id <- tryCatch(
    save_summary_to_cache(
      cluster_type = cluster_type,
      cluster_number = as.integer(cluster_number),
      cluster_hash = final_hash,
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
