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

  reasoning = ellmer::type_string(
    "Brief explanation of assessment including any corrections (2-3 sentences)"
  ),

  verdict = ellmer::type_enum(
    c("accept", "accept_with_corrections", "low_confidence", "reject"),
    "Final verdict: accept (perfect), accept_with_corrections (minor fixes applied),
     low_confidence (concerns but usable), reject (severe hallucinations only)"
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

  # Extract top 20 enrichment terms PER CATEGORY for validation

  # CRITICAL: Must match the generation prompt which uses top_n_terms = 20 per category
  # Previous bug: used slice_head(n=15) globally, so judge only saw 15 terms total
  # while generator showed 20 per category (potentially 80+ terms)
  enrichment_terms <- if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    cluster_data$term_enrichment %>%
      dplyr::group_by(category) %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = 20) %>%
      dplyr::ungroup() %>%
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

**Top 20 Enrichment Terms per Category (AUTHORITATIVE SOURCE):**
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

## VERDICT CALCULATION (with Corrections)

**Total your points from Steps 1-4 (maximum 8 points):**

| Points | Verdict | Action |
|--------|---------|--------|
| 7-8 | **accept** | Cache as 'validated' |
| 5-6 | **accept_with_corrections** | Apply corrections, cache as 'validated' |
| 3-4 | **low_confidence** | Cache as 'pending' for review |
| 0-2 | **reject** | Do not cache, trigger regeneration |

**IMPORTANT: Prefer accept_with_corrections over reject when possible**

---

## CORRECTION INSTRUCTIONS

For scores 5-6, if issues are correctable:
1. Set corrections_needed = true
2. List corrections in corrections_made array
3. Provide corrected_tags with ONLY valid pathway/functional terms from input
4. Use verdict = 'accept_with_corrections'

Only REJECT (score 0-2) if:
- Summary fundamentally misrepresents the cluster
- Multiple severe hallucinations that can't be corrected
- Core summary text is inaccurate (not just tags/metadata)

---

## EXAMPLES

### Example: ACCEPT (8 points)
- 'PI3K-Akt signaling pathway' appears verbatim in KEGG terms (+2)
- All themes map to specific enrichment terms (+2)
- No invented terms found (+2)
- Medium confidence for FDR ~1E-30 terms (+2)

### Example: ACCEPT_WITH_CORRECTIONS (6 points)
- Pathway name slightly paraphrased but correct meaning (+1)
- Most themes grounded, one tag not in data - CORRECT IT (+2)
- One invented term in tags - REMOVE IT (+1)
- Confidence matches evidence (+2)
- corrections_made: ['Removed \"axon guidance\" from tags - not in KEGG data']

### Example: LOW_CONFIDENCE (4 points)
- 'Ras/MAPK cascade' but data shows 'Ras signaling pathway' separately (+1)
- Most themes grounded, one reasonable inference (+1)
- One term not in enrichment data (+0)
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

  # Extract inheritance patterns from quali_sup_var
  inheritance_terms <- "(no inheritance data)"
  if ("quali_sup_var" %in% names(cluster_data) && length(cluster_data$quali_sup_var) > 0) {
    inheritance_df <- if (is.data.frame(cluster_data$quali_sup_var)) {
      cluster_data$quali_sup_var
    } else if (is.list(cluster_data$quali_sup_var)) {
      dplyr::bind_rows(cluster_data$quali_sup_var)
    } else {
      NULL
    }

    if (!is.null(inheritance_df) && nrow(inheritance_df) > 0 &&
        all(c("variable", "v.test") %in% names(inheritance_df))) {
      sig_inheritance <- inheritance_df %>%
        dplyr::filter(abs(`v.test`) > 2) %>%
        dplyr::arrange(dplyr::desc(`v.test`))

      if (nrow(sig_inheritance) > 0) {
        inheritance_terms <- sig_inheritance %>%
          dplyr::mutate(
            direction = dplyr::if_else(`v.test` > 0, "ENRICHED", "DEPLETED"),
            term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction}]")
          ) %>%
          dplyr::pull(term_line) %>%
          paste(collapse = "\n")
      }
    }
  }

  # Extract syndromicity metrics from quanti_sup_var
  syndromicity_terms <- "(no syndromicity data)"
  if ("quanti_sup_var" %in% names(cluster_data) && length(cluster_data$quanti_sup_var) > 0) {
    quanti_df <- if (is.data.frame(cluster_data$quanti_sup_var)) {
      cluster_data$quanti_sup_var
    } else if (is.list(cluster_data$quanti_sup_var)) {
      dplyr::bind_rows(cluster_data$quanti_sup_var)
    } else {
      NULL
    }

    if (!is.null(quanti_df) && nrow(quanti_df) > 0 &&
        all(c("variable", "v.test") %in% names(quanti_df))) {
      sig_quanti <- quanti_df %>%
        dplyr::filter(abs(`v.test`) > 2) %>%
        dplyr::arrange(dplyr::desc(abs(`v.test`)))

      if (nrow(sig_quanti) > 0) {
        syndromicity_terms <- sig_quanti %>%
          dplyr::mutate(
            direction = dplyr::if_else(`v.test` > 0, "HIGHER", "LOWER"),
            term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction} than average]")
          ) %>%
          dplyr::pull(term_line) %>%
          paste(collapse = "\n")
      }
    }
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

  # Extract new supplementary fields
  inheritance_patterns <- if (!is.null(summary$inheritance_patterns) && length(summary$inheritance_patterns) > 0) {
    paste(summary$inheritance_patterns, collapse = ", ")
  } else {
    "(not specified)"
  }

  syndromicity <- summary$syndromicity %||% "(not specified)"

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

## INPUT DATA (Ground Truth)

### Primary Phenotypes (used for clustering)
{phenotype_terms}

### Supplementary Data (describes cluster characteristics)
**Inheritance patterns (from HPO):**
{inheritance_terms}

**Syndromicity metrics:**
{syndromicity_terms}

---

## SUMMARY TO VALIDATE
**Summary text:** {summary_text}

**Key phenotype themes:** {key_themes}

**Notably absent phenotypes:** {notably_absent}

**Clinical pattern:** {clinical_pattern}

**Inheritance patterns:** {inheritance_patterns}

**Syndromicity:** {syndromicity}

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

**Step 6 - Inheritance Pattern Check:**
For each inheritance pattern in the summary:
- Verify it appears in the inheritance data (quali_sup_var) with |v.test| > 2
- Standard abbreviations: AD=Autosomal dominant, AR=Autosomal recessive, XL=X-linked, MT=Mitochondrial
- Mark as INVALID if pattern not in source data

**Step 7 - Syndromicity Check:**
Compare summary's syndromicity claim against quanti_sup_var data:
- 'predominantly_syndromic' should match positive v.test for phenotype_non_id_count
- 'predominantly_id' should match positive v.test for phenotype_id_count
- 'mixed' is valid if both or neither significant
- 'unknown' is valid if no syndromicity data
- Mark as INVALID if mismatch

---

## VERDICT CRITERIA (with Corrections)

**IMPORTANT: Prefer CORRECTING minor issues over REJECTING**

**REJECT (only for SEVERE issues):**
- ANY molecular/gene/pathway term found in main summary text (Step 1)
- Direction inversion in main summary description (Step 4)
- Grounding score < 50% in main summary
- Multiple fabricated claims that fundamentally misrepresent the cluster

**ACCEPT_WITH_CORRECTIONS (correctable issues):**
- Tags array contains items not in input data → Remove them, list in corrections_made
- Notably_absent array contains items not in input data → Remove them, list in corrections_made
- One or two phenotype terms need adjustment → Provide corrected list
- Main summary is accurate but supporting fields have minor issues

**LOW_CONFIDENCE (moderate issues, no correction possible):**
- Grounding score 50-79%
- Uses overly broad syndrome terms that can't be corrected
- Missing significant phenotypes from top 5 by |v.test|

**ACCEPT (all must be true):**
- Grounding score >= 80%
- No molecular/gene content
- No fabricated phenotypes in main summary
- Direction interpretation correct
- All tags and notably_absent items verified in input data

---

## CORRECTION INSTRUCTIONS

If issues are correctable:
1. Set corrections_needed = true
2. List each correction in corrections_made array
3. Provide corrected_tags with ONLY items that appear in the input phenotype data
4. Provide corrected_notably_absent with ONLY depleted phenotypes (v.test < 0) from input
5. Provide corrected_inheritance_patterns with ONLY patterns from quali_sup_var with |v.test| > 2
   - Use standard abbreviations: AD, AR, XL, XLR, XLD, MT, SP
6. Provide corrected_syndromicity based on quanti_sup_var data
7. Use verdict = 'accept_with_corrections'

Example correction:
- corrections_made: ['Removed \"Seizures\" from notably_absent - not in input data', 'Corrected inheritance from XL to AR based on source data']
- corrected_notably_absent: ['Progressive', 'Developmental regression'] (only items with v.test < 0)
- corrected_inheritance_patterns: ['AR', 'AD'] (only from source data)
- corrected_syndromicity: 'predominantly_id' (based on positive v.test for phenotype_id_count)

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
  summary_with_metadata <- gen_result$summary

  # Apply corrections if judge provided them
  if (isTRUE(judge_result$corrections_needed)) {
    log_info("Applying judge corrections to summary")

    # Apply corrected tags if provided
    if (!is.null(judge_result$corrected_tags) && length(judge_result$corrected_tags) > 0) {
      summary_with_metadata$tags <- judge_result$corrected_tags
      log_debug("Applied corrected tags: {paste(judge_result$corrected_tags, collapse=', ')}")
    }

    # Apply corrected notably_absent if provided
    if (!is.null(judge_result$corrected_notably_absent)) {
      summary_with_metadata$notably_absent <- judge_result$corrected_notably_absent
      log_debug("Applied corrected notably_absent: {paste(judge_result$corrected_notably_absent, collapse=', ')}")
    }

    # Apply corrected inheritance_patterns if provided
    if (!is.null(judge_result$corrected_inheritance_patterns) && length(judge_result$corrected_inheritance_patterns) > 0) {
      summary_with_metadata$inheritance_patterns <- judge_result$corrected_inheritance_patterns
      log_debug("Applied corrected inheritance_patterns: {paste(judge_result$corrected_inheritance_patterns, collapse=', ')}")
    }

    # Apply corrected syndromicity if provided
    if (!is.null(judge_result$corrected_syndromicity) && nzchar(judge_result$corrected_syndromicity)) {
      summary_with_metadata$syndromicity <- judge_result$corrected_syndromicity
      log_debug("Applied corrected syndromicity: {judge_result$corrected_syndromicity}")
    }

    # Add corrections metadata
    summary_with_metadata$corrections_applied <- TRUE
    summary_with_metadata$corrections_made <- judge_result$corrections_made
  }

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
