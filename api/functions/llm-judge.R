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
You are a STRICT scientific accuracy validator for AI-generated gene cluster summaries.
Your task is to DETECT HALLUCINATIONS and verify the summary is accurately grounded in the provided data.

## Original Cluster Data
**Genes:** {genes}

**Top 15 Enrichment Terms (AUTHORITATIVE SOURCE):**
{enrichment_terms}

## Generated Summary to Validate
**Summary text:** {summary_text}

**Key themes:** {key_themes}

**Pathways listed:** {pathways}

**Self-assessed confidence:** {self_confidence}

---

## MANDATORY VERIFICATION CHECKLIST

Complete each verification step before rendering your verdict.

### Step 1: Pathway String Matching (CRITICAL)
For EACH pathway listed in the summary:
- Does it appear VERBATIM in the enrichment terms? (YES/NO)
- If NO, is it a reasonable synonym of an existing term? (YES/NO)
- If neither, mark as INVENTED

**Scoring:**
- All pathways appear verbatim = +2 points
- Minor generalizations only = +1 point
- Any completely invented pathway = 0 points

### Step 2: Theme Grounding Check
For EACH key theme, identify which enrichment terms support it.
- Theme with supporting term(s) = GROUNDED
- Theme with NO supporting terms = UNGROUNDED

**Scoring:**
- All themes grounded = +2 points
- 1-2 ungrounded but reasonable = +1 point
- 3+ ungrounded themes = 0 points

### Step 3: Invented Term Detection
List ANY terms, pathways, or mechanisms in the summary that:
- Do NOT appear in the enrichment terms AND
- Cannot be directly inferred from the enrichment data

**Scoring:**
- No invented terms = +2 points
- 1-2 minor invented terms = +1 point
- Any significant hallucination = 0 points

### Step 4: Confidence Calibration
Compare self-assessed confidence to evidence strength:
- High appropriate if: Multiple terms with FDR < 1E-50
- Medium appropriate if: Terms with FDR between 1E-10 and 1E-50
- Low appropriate if: Terms with FDR > 1E-10 or few terms

**Scoring:**
- Confidence matches evidence = +2 points
- Off by one level = +1 point
- Significantly mismatched = 0 points

---

## VERDICT CALCULATION

**Total your points from Steps 1-4 (maximum 8 points):**

| Points | Verdict | Action |
|--------|---------|--------|
| 7-8 | **accept** | Cache as 'validated' |
| 4-6 | **low_confidence** | Cache as 'pending' for review |
| 0-3 | **reject** | Do not cache, trigger regeneration |

---

## EXAMPLES

### Example: ACCEPT (8 points)
- 'PI3K-Akt signaling pathway' appears verbatim in KEGG terms (+2)
- All themes map to specific enrichment terms (+2)
- No invented terms found (+2)
- Medium confidence for FDR ~1E-30 terms (+2)

### Example: LOW_CONFIDENCE (5 points)
- 'Ras/MAPK cascade' but data shows 'Ras signaling pathway' separately (+1)
- Most themes grounded, one reasonable inference (+1)
- One term not in enrichment data (+1)
- Confidence matches evidence (+2)

### Example: REJECT (2 points)
- 'Wnt signaling pathway' NOT in enrichment data (+0)
- 'epigenetic regulation' but no epigenetic terms in data (+0)
- Multiple invented mechanisms (+0)
- High confidence despite weak enrichment (+2)

---

## YOUR RESPONSE
Complete the verification steps, calculate total points, then provide your verdict.
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
You are a STRICT validator for AI-generated phenotype cluster summaries.
Your job is to DETECT HALLUCINATIONS and REJECT inaccurate summaries.

## CRITICAL CONTEXT
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations)
- Entities were clustered by PHENOTYPE PATTERNS, NOT by gene function
- The summary MUST describe CLINICAL PHENOTYPES, not molecular mechanisms
- v.test interpretation: POSITIVE = phenotype ENRICHED, NEGATIVE = phenotype DEPLETED

---

## AUTOMATIC REJECTION TRIGGERS
ANY of these errors = immediate verdict of 'reject':

1. **MOLECULAR HALLUCINATION**: Summary mentions genes, proteins, pathways, molecular mechanisms,
   chromatin, transcription, signaling, enzymes, or any biological mechanism terms
   - REJECT if: 'genes involved in synaptic function'
   - REJECT if: 'chromatin remodeling and transcriptional regulation'
   - REJECT if: 'mitochondrial respiratory chain', 'DNA repair pathways'

2. **FABRICATED PHENOTYPES**: Summary references phenotypes NOT in the input data
   - REJECT if: summary says 'autism' but input only has 'intellectual disability'
   - REJECT if: summary says 'epilepsy' but no seizure term in input
   - REJECT if: summary says 'cardiac defects' but no heart-related term in input

3. **DIRECTION INVERSION**: Summary describes enriched phenotypes as depleted or vice versa
   - REJECT if: v.test is NEGATIVE but summary says 'strongly associated with' or 'enriched'
   - REJECT if: v.test is POSITIVE but summary says 'absent' or 'depleted'

4. **SCOPE ERROR**: Summary discusses gene functions when data is about disease phenotypes
   - REJECT if: mentions what genes 'do' or their 'functions'
   - ACCEPT if: describes what clinical features patients present with

---

## FORBIDDEN TERMS (if present = automatic reject)
gene, protein, pathway, signaling, transcription, chromatin, histone, methylation,
enzyme, receptor, kinase, mTOR, MAPK, DNA repair, RNA processing, cell cycle,
'plays a role in', 'involved in', 'functions in', 'regulates', 'modulates'

---

## INPUT PHENOTYPE DATA (Ground Truth)
{phenotype_terms}

## SUMMARY TO VALIDATE
**Summary text:** {summary_text}

**Key phenotype themes:** {key_themes}

**Notably absent phenotypes:** {notably_absent}

**Clinical pattern:** {clinical_pattern}

**Self-assessed confidence:** {self_confidence}

---

## STEP-BY-STEP VERIFICATION (Complete ALL steps before verdict)

**Step 1 - Forbidden Term Scan (FIRST!):**
Check for ANY molecular/gene/pathway terms in the summary.
If found: Mark as MOLECULAR_HALLUCINATION = automatic reject

**Step 2 - Extract Claims:**
List every phenotype or clinical term mentioned in the summary.

**Step 3 - Ground Each Claim:**
For EACH term from Step 2, verify it exists in the input phenotype data (exact or semantically equivalent).
Mark ungrounded terms as FABRICATED.

**Step 4 - Direction Check:**
For phenotypes described as enriched, verify v.test > 0.
For phenotypes described as depleted, verify v.test < 0.
Mark mismatches as DIRECTION_ERROR.

**Step 5 - Calculate Grounding Score:**
Grounding % = (number of grounded claims / total claims) x 100

---

## VERDICT CRITERIA

**REJECT (any of these):**
- ANY molecular/gene term found (Step 1)
- ANY fabricated phenotype (Step 3)
- ANY direction inversion (Step 4)
- Grounding score < 70%

**LOW_CONFIDENCE (moderate issues):**
- Grounding score 70-89%
- Uses overly broad syndrome terms
- Missing significant phenotypes from top 5 by |v.test|
- Minor semantic drift but no fabrication

**ACCEPT (all must be true):**
- Grounding score >= 90%
- No molecular/gene content
- No fabricated phenotypes
- Direction interpretation correct
- Mentions both enriched AND depleted phenotypes where applicable

---

## YOUR RESPONSE
Complete the verification steps, then provide your verdict.
REMEMBER: If ANY forbidden molecular terms appear, verdict MUST be 'reject'.
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
