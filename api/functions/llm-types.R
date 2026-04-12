# functions/llm-types.R
#
# Type/schema definitions and prompt builders for LLM cluster summaries.
# Contains ellmer type_object specifications for structured output and
# prompt construction functions for both functional and phenotype clusters.
#
# Prompt template database CRUD functions live in llm-service.R, not here.
#
# Split from llm-service.R as part of v11.0 Phase D (D1).

require(glue)
require(logger)

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
