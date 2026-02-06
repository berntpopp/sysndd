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
# Based on Paid Tier 1: 60 RPM for gemini-2.0-flash
# Using conservative limit to avoid rate limiting issues
#------------------------------------------------------------------------------
GEMINI_RATE_LIMIT <- list(
  capacity = 30, # Conservative: 30 RPM (half of Paid Tier 1)
  fill_time_s = 60, # 1 minute window
  backoff_base = 2, # Exponential backoff base (seconds)
  max_retries = 3 # Maximum retry attempts
)

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
#' Defines structure for phenotype clusters which group disease entities
#' (gene-disease associations) by phenotype patterns, NOT by gene function.
#' Uses v.test scores to identify enriched/depleted phenotypes.
#'
#' @export
phenotype_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a phenotype cluster based on v.test enrichment",
  summary = ellmer::type_string(
    "2-3 sentence description of the clinical phenotype pattern.
     Focus on what phenotypes define this cluster (both enriched AND depleted).
     Target audience: clinical geneticists and syndrome researchers."
  ),
  key_phenotype_themes = ellmer::type_array(
    ellmer::type_string("Clinical phenotype category"),
    "3-5 main phenotypic themes that are ENRICHED in this cluster (positive v.test)"
  ),
  notably_absent = ellmer::type_array(
    ellmer::type_string("Phenotype that is rare in this cluster"),
    "2-3 phenotypes that are DEPLETED in this cluster (negative v.test)",
    required = FALSE
  ),
  clinical_pattern = ellmer::type_string(
    "Syndrome category suggested by the phenotype pattern (e.g., 'syndromic malformations',
     'progressive metabolic disorders', 'overgrowth syndromes', 'pure neurodevelopmental')"
  ),
  syndrome_hints = ellmer::type_array(
    ellmer::type_string("Recognized syndrome name or category"),
    "Known syndrome categories this phenotype pattern might represent",
    required = FALSE
  ),
  tags = ellmer::type_array(
    ellmer::type_string("Searchable clinical keyword"),
    "3-7 short tags derived from the phenotype data (e.g., 'cardiac', 'renal', 'skeletal')"
  ),
  inheritance_patterns = ellmer::type_array(
    ellmer::type_string("Inheritance mode abbreviation"),
    "1-3 inheritance patterns significantly associated with this cluster (e.g., 'AD', 'AR', 'XL').
     Derived from quali_sup_var data. Use standard abbreviations: AD=Autosomal dominant,
     AR=Autosomal recessive, XL=X-linked, MT=Mitochondrial, SP=Sporadic.",
    required = FALSE
  ),
  syndromicity = ellmer::type_enum(
    c("predominantly_syndromic", "predominantly_id", "mixed", "unknown"),
    "Overall syndromicity pattern based on phenotype counts:
     'predominantly_syndromic' = more non-ID phenotypes,
     'predominantly_id' = more ID phenotypes,
     'mixed' = balanced,
     'unknown' = insufficient data.
     Derived from quanti_sup_var (phenotype_id_count vs phenotype_non_id_count).",
    required = FALSE
  ),
  confidence = ellmer::type_enum(
    c("high", "medium", "low"),
    "Confidence based on phenotype data strength: high if many significant phenotypes,
     medium if moderate signal, low if sparse or conflicting data"
  ),
  data_quality_note = ellmer::type_string(
    "Note any data quality issues or caveats about the phenotype interpretation",
    required = FALSE
  )
)


#' Build prompt for FUNCTIONAL cluster summary generation
#'
#' Constructs a prompt for the LLM using cluster data and enrichment terms.
#' Used for functional clusters which group GENES by functional similarity.
#' Does NOT include JSON schema in prompt (ellmer handles via type spec).
#'
#' @param cluster_data List containing:
#'   - identifiers: tibble with symbol column (gene symbols)
#'   - term_enrichment: tibble with category, term, description, fdr, number_of_genes columns
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

  # Extract gene symbols (show sample for large clusters)
  if ("symbol" %in% names(cluster_data$identifiers)) {
    gene_count <- nrow(cluster_data$identifiers)
    if (gene_count > 20) {
      sample_genes <- paste(head(cluster_data$identifiers$symbol, 15), collapse = ", ")
      genes <- paste0(sample_genes, "... (", gene_count, " total)")
    } else {
      genes <- paste(cluster_data$identifiers$symbol, collapse = ", ")
    }
  } else {
    genes <- "(gene symbols not provided)"
    gene_count <- nrow(cluster_data$identifiers)
  }

  # Extract and format enrichment terms by category
  # Now includes description (human-readable) and number_of_genes
  enrichment_text <- ""
  if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    enrichment <- cluster_data$term_enrichment %>%
      dplyr::group_by(category) %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = top_n_terms) %>%
      dplyr::ungroup()

    # Use description if available, otherwise fall back to term
    # Include gene count if available
    enrichment_text <- enrichment %>%
      dplyr::mutate(
        display_name = dplyr::if_else(
          !is.na(description) & description != "",
          description,
          term
        ),
        gene_info = dplyr::if_else(
          !is.na(number_of_genes) & number_of_genes > 0,
          glue::glue(", {number_of_genes}/{gene_count} genes"),
          ""
        ),
        term_line = glue::glue("- {display_name} (FDR: {signif(fdr, 3)}{gene_info})")
      ) %>%
      dplyr::group_by(category) %>%
      dplyr::summarise(terms = paste(term_line, collapse = "\n"), .groups = "drop") %>%
      dplyr::mutate(section = glue::glue("### {category}\n{terms}")) %>%
      dplyr::pull(section) %>%
      paste(collapse = "\n\n")
  } else {
    enrichment_text <- "(No enrichment data provided)"
  }

  prompt <- glue::glue("
You are a genomics expert analyzing gene clusters associated with neurodevelopmental disorders.

## Task
Analyze this functional gene cluster and summarize its biological significance
based STRICTLY on the enrichment data provided.

## Cluster Information
- **Cluster Size:** {gene_count} genes
- **Sample genes:** {genes}

## Functional Enrichment Results (YOUR ONLY SOURCE OF TRUTH)
The following terms are statistically enriched in this gene cluster. You may ONLY reference terms from this section.

{enrichment_text}

## Instructions
Based EXCLUSIVELY on the enrichment data above:

1. **Summary (2-3 sentences):** What biological functions unite these genes?
   - Every function you mention must be traceable to a specific term listed above
   - Do NOT introduce concepts not explicitly present in the enrichment data

2. **Key biological themes (3-5):** List the main functional categories.
   - Derive these directly from the enrichment term descriptions
   - Use wording that closely matches the source terms

3. **Pathways:** List pathways VERBATIM from the KEGG section above.
   - Copy exact pathway names as written (e.g., 'PI3K-Akt signaling pathway' not 'PI3K pathway')
   - Do NOT paraphrase, abbreviate, or generalize pathway names
   - If no KEGG pathways appear above, write 'No KEGG pathways in enrichment data'

4. **Disease relevance:** Based EXCLUSIVELY on the 'HPO' or disease phenotype section:
   - Only mention phenotypes that appear in that section
   - Do NOT infer additional disease associations
   - If no HPO terms are provided, write 'No HPO terms in enrichment data'

5. **Tags (3-7):** Short keywords derived ONLY from the enrichment terms above.
   - Each tag must correspond to a concept in the data
   - Avoid generic terms not grounded in the specific enrichment results

6. **Confidence:**
   - High: Many terms with FDR < 1E-50, strong consistent signal
   - Medium: Moderate enrichment, some strong terms
   - Low: Sparse data, weak enrichment, or ambiguous patterns

## Uncertainty Handling
- If a category has no enriched terms, state 'No significant [category] terms' rather than inferring
- If the data does not clearly support a theme, write 'Unable to determine from provided data'
- It is acceptable to omit optional fields rather than guess

## Self-Verification Checklist
Before finalizing, verify:
- [ ] Every pathway in your response appears EXACTLY in the KEGG section above
- [ ] Every theme can be traced to a specific enrichment term description
- [ ] Disease relevance only mentions terms from the HPO section
- [ ] No terms were invented, paraphrased beyond recognition, or generalized

CRITICAL: Only reference terms that appear in the enrichment data above.
Invented or generalized terms will cause rejection.
")

  return(prompt)
}


#' Build prompt for PHENOTYPE cluster summary generation
#'
#' Constructs a prompt for phenotype clusters which group DISEASE ENTITIES
#' (gene-disease associations) by phenotype similarity, NOT by gene function.
#' Uses v.test scores to identify enriched/depleted phenotypes.
#'
#' Unlike functional clusters which have many categories, phenotype clusters
#' typically have fewer significant terms, so we include ALL significant
#' phenotypes (|v.test| > 2) rather than limiting to top N.
#'
#' @param cluster_data List containing:
#'   - identifiers: tibble with entity_id column
#'   - quali_inp_var: tibble with variable, p.value, v.test columns
#' @param vtest_threshold Numeric, minimum |v.test| to include (default: 2)
#'
#' @return Character string, the formatted prompt
#'
#' @examples
#' \dontrun{
#' prompt <- build_phenotype_cluster_prompt(cluster_data, vtest_threshold = 2)
#' }
#'
#' @export
build_phenotype_cluster_prompt <- function(cluster_data, vtest_threshold = 2) {
  # Validate input
  if (!is.list(cluster_data)) {
    rlang::abort("cluster_data must be a list", class = "llm_service_error")
  }

  # Check for phenotype data (quali_inp_var)
  if (!"quali_inp_var" %in% names(cluster_data) || length(cluster_data$quali_inp_var) == 0) {
    log_warn("No phenotype data (quali_inp_var) found, falling back to generic prompt")
    return(build_cluster_prompt(cluster_data))
  }

  # Convert to data frame if needed
  phenotypes_df <- if (is.data.frame(cluster_data$quali_inp_var)) {
    cluster_data$quali_inp_var
  } else if (is.list(cluster_data$quali_inp_var)) {
    dplyr::bind_rows(cluster_data$quali_inp_var)
  } else {
    log_warn("Unable to process quali_inp_var, falling back to generic prompt")
    return(build_cluster_prompt(cluster_data))
  }

  # Validate required columns
  if (!all(c("variable", "v.test", "p.value") %in% names(phenotypes_df))) {
    log_warn("quali_inp_var missing required columns, falling back to generic prompt")
    return(build_cluster_prompt(cluster_data))
  }

  # Get entity count
  entity_count <- if ("identifiers" %in% names(cluster_data)) {
    nrow(cluster_data$identifiers)
  } else {
    cluster_data$cluster_size %||% "unknown"
  }

  # Include ALL significant phenotypes (|v.test| > threshold)
  # For phenotype clusters, we want comprehensive data rather than top N
  phenotypes_significant <- phenotypes_df %>%
    dplyr::filter(abs(`v.test`) > vtest_threshold)

  # Separate enriched (positive v.test) and depleted (negative v.test)
  enriched <- phenotypes_significant %>%
    dplyr::filter(`v.test` > 0) %>%
    dplyr::arrange(dplyr::desc(`v.test`))

  depleted <- phenotypes_significant %>%
    dplyr::filter(`v.test` < 0) %>%
    dplyr::arrange(`v.test`)

  # Format enriched phenotypes as table
  enriched_text <- if (nrow(enriched) > 0) {
    enriched_lines <- enriched %>%
      dplyr::mutate(
        line = glue::glue("| {variable} | +{round(`v.test`, 2)} | {signif(`p.value`, 2)} |")
      ) %>%
      dplyr::pull(line) %>%
      paste(collapse = "\n")
    paste0(
      "| Phenotype | v.test | p-value |\n",
      "|-----------|--------|--------|\n",
      enriched_lines
    )
  } else {
    "(No significantly enriched phenotypes)"
  }

  # Format depleted phenotypes as table
  depleted_text <- if (nrow(depleted) > 0) {
    depleted_lines <- depleted %>%
      dplyr::mutate(
        line = glue::glue("| {variable} | {round(`v.test`, 2)} | {signif(`p.value`, 2)} |")
      ) %>%
      dplyr::pull(line) %>%
      paste(collapse = "\n")
    paste0(
      "| Phenotype | v.test | p-value |\n",
      "|-----------|--------|--------|\n",
      depleted_lines
    )
  } else {
    "(No significantly depleted phenotypes)"
  }

  # ============================================================================
  # SUPPLEMENTARY VARIABLES (don't affect clustering, but describe cluster characteristics)
  # ============================================================================

  # Process qualitative supplementary variables (inheritance patterns from HPO)
  inheritance_text <- "(No inheritance data available)"
  if ("quali_sup_var" %in% names(cluster_data) && length(cluster_data$quali_sup_var) > 0) {
    inheritance_df <- if (is.data.frame(cluster_data$quali_sup_var)) {
      cluster_data$quali_sup_var
    } else if (is.list(cluster_data$quali_sup_var)) {
      dplyr::bind_rows(cluster_data$quali_sup_var)
    } else {
      NULL
    }

    if (!is.null(inheritance_df) && nrow(inheritance_df) > 0 &&
      all(c("variable", "v.test", "p.value") %in% names(inheritance_df))) {
      # Filter to significant associations
      inheritance_sig <- inheritance_df %>%
        dplyr::filter(abs(`v.test`) > vtest_threshold) %>%
        dplyr::arrange(dplyr::desc(`v.test`))

      if (nrow(inheritance_sig) > 0) {
        inheritance_lines <- inheritance_sig %>%
          dplyr::mutate(
            sign = ifelse(`v.test` > 0, "+", ""),
            line = glue::glue("| {variable} | {sign}{round(`v.test`, 2)} | {signif(`p.value`, 2)} |")
          ) %>%
          dplyr::pull(line) %>%
          paste(collapse = "\n")
        inheritance_text <- paste0(
          "| Inheritance Pattern | v.test | p-value |\n",
          "|---------------------|--------|--------|\n",
          inheritance_lines
        )
      }
    }
  }

  # Process quantitative supplementary variables (phenotype counts)
  syndromicity_text <- "(No syndromicity data available)"
  if ("quanti_sup_var" %in% names(cluster_data) && length(cluster_data$quanti_sup_var) > 0) {
    quanti_df <- if (is.data.frame(cluster_data$quanti_sup_var)) {
      cluster_data$quanti_sup_var
    } else if (is.list(cluster_data$quanti_sup_var)) {
      dplyr::bind_rows(cluster_data$quanti_sup_var)
    } else {
      NULL
    }

    if (!is.null(quanti_df) && nrow(quanti_df) > 0 &&
      all(c("variable", "v.test", "p.value") %in% names(quanti_df))) {
      # Filter to significant associations
      quanti_sig <- quanti_df %>%
        dplyr::filter(abs(`v.test`) > vtest_threshold) %>%
        dplyr::arrange(dplyr::desc(abs(`v.test`)))

      if (nrow(quanti_sig) > 0) {
        quanti_lines <- quanti_sig %>%
          dplyr::mutate(
            sign = ifelse(`v.test` > 0, "+", ""),
            # Add interpretation hint for each variable
            interpretation = dplyr::case_when(
              grepl("phenotype_id_count", variable) & `v.test` > 0 ~
                "(more ID phenotypes than average)",
              grepl("phenotype_id_count", variable) & `v.test` < 0 ~
                "(fewer ID phenotypes than average)",
              grepl("phenotype_non_id_count", variable) & `v.test` > 0 ~
                "(more syndromic features than average)",
              grepl("phenotype_non_id_count", variable) & `v.test` < 0 ~
                "(fewer syndromic features than average)",
              grepl("gene_entity_count", variable) & `v.test` > 0 ~
                "(genes with more disease associations)",
              grepl("gene_entity_count", variable) & `v.test` < 0 ~
                "(genes with fewer disease associations)",
              TRUE ~ ""
            ),
            line = glue::glue(
              "| {variable} | {sign}{round(`v.test`, 2)} | {signif(`p.value`, 2)} | {interpretation} |"
            )
          ) %>%
          dplyr::pull(line) %>%
          paste(collapse = "\n")
        syndromicity_text <- paste0(
          "| Variable | v.test | p-value | Interpretation |\n",
          "|----------|--------|---------|----------------|\n",
          quanti_lines
        )
      }
    }
  }

  prompt <- glue::glue("
You are a clinical geneticist analyzing phenotype clusters from a neurodevelopmental disorder database.

## Task
Analyze this phenotype cluster and describe its clinical pattern using ONLY the data listed below.

## Important Context
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations), NOT individual genes
- Entities were clustered based on their phenotype (clinical feature) annotations
  using Multiple Correspondence Analysis (MCA)
- v.test score indicates statistical enrichment/depletion:
  - POSITIVE v.test = MORE COMMON in this cluster than database average
  - NEGATIVE v.test = LESS COMMON in this cluster than database average
  - |v.test| > 2 = significant, > 5 = strong, > 10 = very strong

## SOURCE DATA (Your Only Source of Truth)

### SECTION 1: PRIMARY PHENOTYPES (Used for clustering)
These phenotype terms directly determined cluster membership.

#### ENRICHED Phenotypes (overrepresented in this cluster)
{enriched_text}

#### DEPLETED Phenotypes (underrepresented in this cluster)
{depleted_text}

### SECTION 2: SUPPLEMENTARY DATA (Describes cluster characteristics)
These variables did NOT affect clustering but are statistically associated with this cluster.
Positive v.test = over-represented; Negative v.test = under-represented.

#### Inheritance Patterns (from HPO)
{inheritance_text}

#### Syndromicity Metrics
(phenotype_id_count = intellectual disability phenotypes; phenotype_non_id_count = other syndromic features)
{syndromicity_text}

---

## CRITICAL CONSTRAINTS

### FORBIDDEN - You MUST NOT:
- Mention ANY phenotype not explicitly listed in the tables above
- Infer related phenotypes (e.g., do NOT add 'seizures' if only 'Abnormal nervous system physiology' is listed)
- Use clinical synonyms not in the data (e.g., do NOT say 'ataxia' if only 'Movement disorder' is listed)
- Mention genes, proteins, or molecular pathways - this is PURELY phenotype-based
- Generalize beyond the specific phenotype names (e.g., do NOT say
  'neurological features' when specific phenotypes are listed)
- Use terms like: gene, protein, pathway, signaling, transcription, chromatin, enzyme, receptor, kinase, DNA, RNA

### ALLOWED:
- Grouping phenotypes into categories (e.g., 'genitourinary and renal phenotypes')
- Describing the clinical significance of specific phenotypes
- Using inheritance pattern data to characterize the cluster
- Stating uncertainty with phrases like 'The data suggests...'
- Leaving optional fields empty if the data doesn't support them

---

## Instructions
Based ONLY on the data above:

1. **Summary (2-3 sentences):** Describe the clinical phenotype pattern.
   Reference specific phenotype names from the data.
   - If uncertain, say 'The data suggests...' rather than stating definitively
   - May mention inheritance patterns if significantly associated

2. **Key phenotype themes (3-5):** Group the ENRICHED phenotypes into clinical categories.
   - Each theme MUST be derived directly from one or more phenotypes in the ENRICHED table
   - Use wording that closely matches the source phenotypes

3. **Notably absent (2-3):** Copy the exact phenotype names from the DEPLETED table.
   - Do NOT paraphrase or interpret - use the exact names

4. **Clinical pattern:** What syndrome category does this suggest?
   - Choose from: 'syndromic malformation', 'pure neurodevelopmental',
     'progressive metabolic/degenerative', 'overgrowth syndrome', 'other'

5. **Syndrome hints (optional):** If the phenotype pattern strongly suggests known syndrome categories, list them.
   - If uncertain, state 'No specific syndrome pattern identified' rather than guessing

6. **Tags (3-7):** Short keywords EXTRACTED DIRECTLY from the phenotype names above.
   - Example: if 'Abnormality of the kidney' is enriched, use 'renal' or 'kidney'

7. **Inheritance patterns (1-3):** Based on the inheritance data in SECTION 2:
   - Use standard abbreviations: AD (Autosomal dominant), AR (Autosomal recessive),
     XL (X-linked), MT (Mitochondrial), SP (Sporadic)
   - Only include patterns with significant v.test (>2)
   - Leave empty if no significant inheritance associations

8. **Syndromicity:** Based on the syndromicity metrics in SECTION 2:
   - 'predominantly_syndromic' = positive v.test for phenotype_non_id_count
   - 'predominantly_id' = positive v.test for phenotype_id_count
   - 'mixed' = both or neither significant
   - 'unknown' = no syndromicity data

## Self-Verification Checklist
Before finalizing, verify that:
- [ ] Every phenotype mentioned appears EXACTLY in the tables above
- [ ] No clinical terms were added that aren't in the source data
- [ ] The 'notably absent' section uses exact names from DEPLETED table
- [ ] Tags are derived from actual phenotype names, not inferred categories
- [ ] Inheritance patterns match the data in SECTION 2
- [ ] NO molecular/gene terms appear anywhere in your response

CRITICAL: Mentioning genes, pathways, or molecular mechanisms will cause IMMEDIATE REJECTION.
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
  message("[LLM-Service] generate_cluster_summary called for ", cluster_type, " cluster")

  # Check for API key
  api_key <- Sys.getenv("GEMINI_API_KEY")
  message("[LLM-Service] GEMINI_API_KEY present: ", nchar(api_key) > 0, " (length=", nchar(api_key), ")")

  if (api_key == "" || is.na(api_key)) {
    message("[LLM-Service] ERROR: GEMINI_API_KEY not set!")
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


#' Calculate derived confidence from cluster data
#'
#' Computes a confidence score based on data strength.
#' Provides an objective measure independent of LLM self-assessment.
#' Handles both functional (enrichment/FDR) and phenotype (v.test/p.value) clusters.
#'
#' @param data Tibble with either:
#'   - term_enrichment: containing 'fdr' column (for functional clusters)
#'   - quali_inp_var: containing 'p.value' and 'v.test' columns (for phenotype clusters)
#' @param cluster_type Character, "functional" or "phenotype" (default: auto-detect)
#'
#' @return List with:
#'   - avg_fdr: Average FDR/p-value across top terms (numeric)
#'   - term_count: Number of significant terms (integer)
#'   - score: Derived confidence score ("high", "medium", or "low")
#'
#' @details
#' For functional clusters (FDR-based):
#' - high: avg_fdr < 1e-10 AND term_count > 20
#' - medium: avg_fdr < 1e-5 AND term_count > 10
#' - low: otherwise
#'
#' For phenotype clusters (v.test-based):
#' - high: many terms with |v.test| > 5 AND p.value < 1e-10
#' - medium: some terms with |v.test| > 3 AND p.value < 1e-5
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
calculate_derived_confidence <- function(data, cluster_type = NULL) {
  # Handle NULL or empty data
  if (is.null(data)) {
    return(list(
      avg_fdr = NA_real_,
      term_count = 0L,
      score = "low"
    ))
  }

  # Convert list to data frame if needed
  if (is.list(data) && !is.data.frame(data)) {
    data <- tryCatch(
      dplyr::bind_rows(data),
      error = function(e) NULL
    )
  }

  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(list(
      avg_fdr = NA_real_,
      term_count = 0L,
      score = "low"
    ))
  }

  # Auto-detect cluster type based on column presence
  if (is.null(cluster_type)) {
    cluster_type <- if ("fdr" %in% names(data)) {
      "functional"
    } else if (all(c("p.value", "v.test") %in% names(data))) {
      "phenotype"
    } else {
      "unknown"
    }
  }

  if (cluster_type == "phenotype") {
    # Phenotype cluster: use p.value and v.test
    if (!all(c("p.value", "v.test") %in% names(data))) {
      log_warn("Phenotype data missing required columns, returning low confidence")
      return(list(
        avg_fdr = NA_real_,
        term_count = nrow(data),
        score = "low"
      ))
    }

    # Count significant terms (p.value < 0.05 AND |v.test| > 2)
    significant_terms <- data %>%
      dplyr::filter(`p.value` < 0.05 & abs(`v.test`) > 2)

    term_count <- nrow(significant_terms)

    # Use p.value as the equivalent of FDR for display
    avg_pvalue <- if (term_count > 0) {
      mean(significant_terms$`p.value`, na.rm = TRUE)
    } else {
      NA_real_
    }

    # Count strong effects
    strong_effects <- sum(abs(significant_terms$`v.test`) > 5, na.rm = TRUE)
    very_strong <- sum(abs(significant_terms$`v.test`) > 10, na.rm = TRUE)

    # Determine confidence score based on v.test magnitudes and p-values
    score <- if (!is.na(avg_pvalue) && avg_pvalue < 1e-10 && strong_effects > 10) {
      "high"
    } else if (!is.na(avg_pvalue) && avg_pvalue < 1e-5 && term_count > 5) {
      "medium"
    } else {
      "low"
    }

    log_debug(
      "Derived confidence (phenotype): avg_pvalue={signif(avg_pvalue, 3)}, ",
      "term_count={term_count}, strong_effects={strong_effects}, score={score}"
    )

    return(list(
      avg_fdr = avg_pvalue, # Use p.value for consistency with frontend
      term_count = as.integer(term_count),
      score = score
    ))
  } else {
    # Functional cluster: use FDR
    if (!"fdr" %in% names(data)) {
      log_warn("Enrichment data missing 'fdr' column, returning low confidence")
      return(list(
        avg_fdr = NA_real_,
        term_count = nrow(data),
        score = "low"
      ))
    }

    # Count significant terms (FDR < 0.05)
    significant_terms <- data %>%
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

    log_debug("Derived confidence (functional): avg_fdr={signif(avg_fdr, 3)}, term_count={term_count}, score={score}")

    return(list(
      avg_fdr = avg_fdr,
      term_count = as.integer(term_count),
      score = score
    ))
  }
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

  result <- db_with_transaction({
    if (deactivate_previous) {
      db_execute_statement(
        "UPDATE llm_prompt_templates SET is_active = FALSE WHERE prompt_type = ?",
        list(prompt_type)
      )
    }

    db_execute_statement(
      "INSERT INTO llm_prompt_templates
       (prompt_type, version, template_text, description, is_active, created_by)
       VALUES (?, ?, ?, ?, TRUE, ?)",
      list(prompt_type, version, template_text, description_val, created_by_val)
    )

    id_result <- db_execute_query("SELECT LAST_INSERT_ID() AS id")
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
