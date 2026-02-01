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


#' Build judge prompt for FUNCTIONAL cluster validation
#'
#' Creates validation prompt for functional clusters which group genes by function.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data
#'
#' @return Character string, the formatted judge prompt
#'
#' @keywords internal
build_functional_judge_prompt <- function(summary, cluster_data) {
  # Extract context for judge
  genes <- if ("identifiers" %in% names(cluster_data) && "symbol" %in% names(cluster_data$identifiers)) {
    gene_list <- cluster_data$identifiers$symbol
    if (length(gene_list) > 20) {
      paste0(paste(head(gene_list, 15), collapse = ", "), "... (", length(gene_list), " total)")
    } else {
      paste(gene_list, collapse = ", ")
    }
  } else {
    "(genes not available)"
  }

  # Extract top 15 enrichment terms for validation
  enrichment_terms <- if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    cluster_data$term_enrichment %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = 15) %>%
      dplyr::mutate(
        display_name = dplyr::if_else(!is.na(description) & description != "", description, term),
        term_line = glue::glue("- {category}: {display_name} (FDR: {signif(fdr, 3)})")
      ) %>%
      dplyr::pull(term_line) %>%
      paste(collapse = "\n")
  } else {
    "(no enrichment data)"
  }

  # Extract summary components
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

  glue::glue("
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
1. **Factual accuracy:** Does the summary accurately describe biological functions of these genes?
2. **Grounding:** Are all claims supported by the enrichment data above? Are there invented terms?
3. **Pathway validity:** Are the listed pathways exact matches from the enrichment terms (no invented pathways)?
4. **Confidence appropriate:** Does the self-assessed confidence match the evidence strength?

## Instructions
Evaluate each criterion and provide a final verdict:
- **accept:** Summary is accurate and well-grounded in the enrichment data
- **low_confidence:** Summary is mostly accurate but has minor issues or unverifiable claims
- **reject:** Summary has significant errors, invented information, or hallucinated terms
")
}


#' Build judge prompt for PHENOTYPE cluster validation
#'
#' Creates validation prompt for phenotype clusters which group disease entities
#' by phenotype patterns using v.test scores.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data
#'
#' @return Character string, the formatted judge prompt
#'
#' @keywords internal
build_phenotype_judge_prompt <- function(summary, cluster_data) {
  # Extract phenotype data from quali_inp_var
  phenotype_terms <- if ("quali_inp_var" %in% names(cluster_data)) {
    phenotypes_df <- if (is.data.frame(cluster_data$quali_inp_var)) {
      cluster_data$quali_inp_var
    } else if (is.list(cluster_data$quali_inp_var)) {
      dplyr::bind_rows(cluster_data$quali_inp_var)
    } else {
      NULL
    }

    if (!is.null(phenotypes_df) && nrow(phenotypes_df) > 0 &&
        all(c("variable", "v.test") %in% names(phenotypes_df))) {
      phenotypes_df %>%
        dplyr::arrange(dplyr::desc(abs(`v.test`))) %>%
        dplyr::slice_head(n = 15) %>%
        dplyr::mutate(
          direction = dplyr::if_else(`v.test` > 0, "ENRICHED", "DEPLETED"),
          term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction}]")
        ) %>%
        dplyr::pull(term_line) %>%
        paste(collapse = "\n")
    } else {
      "(no phenotype data)"
    }
  } else {
    "(no phenotype data)"
  }

  # Get entity count
  entity_count <- if ("identifiers" %in% names(cluster_data)) {
    nrow(cluster_data$identifiers)
  } else {
    "unknown"
  }

  # Extract summary components (phenotype-specific fields)
  summary_text <- summary$summary %||% ""

  # Handle both old (key_themes) and new (key_phenotype_themes) field names
  key_themes <- if (!is.null(summary$key_phenotype_themes) && length(summary$key_phenotype_themes) > 0) {
    paste(summary$key_phenotype_themes, collapse = ", ")
  } else if (!is.null(summary$key_themes) && length(summary$key_themes) > 0) {
    paste(summary$key_themes, collapse = ", ")
  } else {
    "(none)"
  }

  notably_absent <- if (!is.null(summary$notably_absent) && length(summary$notably_absent) > 0) {
    paste(summary$notably_absent, collapse = ", ")
  } else {
    "(not specified)"
  }

  clinical_pattern <- summary$clinical_pattern %||% "(not specified)"
  self_confidence <- summary$confidence %||% "unknown"

  glue::glue("
You are validating an AI-generated phenotype cluster summary for accuracy.

## Important Context
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations), NOT genes
- Entities were clustered based on their phenotype annotations
- v.test interpretation: POSITIVE = phenotype ENRICHED, NEGATIVE = phenotype DEPLETED

## Original Phenotype Data
The cluster has these top phenotypes by effect size:
{phenotype_terms}

## Generated Summary to Validate
**Summary:** {summary_text}

**Key phenotype themes:** {key_themes}

**Notably absent phenotypes:** {notably_absent}

**Clinical pattern:** {clinical_pattern}

**Self-assessed confidence:** {self_confidence}

## Validation Criteria
1. **Phenotype accuracy:** Does the summary ONLY reference phenotypes from the input data?
2. **No hallucination:** Are there any invented phenotype terms not in the input?
3. **v.test interpretation:** Does it correctly identify enriched (positive) vs depleted (negative) phenotypes?
4. **No gene/pathway speculation:** Does the summary avoid inventing molecular mechanisms?
5. **Both directions:** Does the summary mention BOTH enriched AND depleted phenotypes where applicable?

## Instructions
Evaluate each criterion and provide a final verdict:
- **accept:** Summary accurately describes the phenotype pattern using only input data
- **low_confidence:** Minor issues but generally accurate
- **reject:** Contains hallucinated phenotypes, invents molecular mechanisms, or fundamentally misinterprets the data
")
}


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
validate_with_llm_judge <- function(summary, cluster_data, model = "gemini-3-pro-preview", cluster_type = "functional") {
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
  model = "gemini-3-pro-preview",
  cluster_hash = NULL
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
    model = model,
    cluster_type = cluster_type
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
