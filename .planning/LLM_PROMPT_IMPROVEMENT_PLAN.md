# LLM Prompt Improvement Plan

**Date:** 2026-02-01
**Priority:** CRITICAL - Current phenotype summaries are 100% hallucinated

---

## Implementation Tasks

### Phase 1: Immediate Fixes (Do Now)

#### Task 1.1: Migrate to Gemini 3 Pro
**Files:** `llm-service.R`, `llm-judge.R`
**Changes:**
- Update default model from `gemini-2.0-flash` to `gemini-3-pro-preview`
- Update `list_gemini_models()` with current models

#### Task 1.2: Create Phenotype-Specific Prompt Builder
**File:** `llm-service.R`
**New function:** `build_phenotype_cluster_prompt()`
**Key features:**
- Pass `quali_inp_var` data with v.test scores
- Explain v.test interpretation (positive = overrepresented, negative = underrepresented)
- Explicitly forbid hallucination of terms not in data
- Focus on phenotype patterns, not gene functions

#### Task 1.3: Create Phenotype-Specific Type Specification
**File:** `llm-service.R`
**Changes:**
- Modify `phenotype_cluster_summary_type` to remove gene-centric fields
- Add phenotype-centric fields:
  - `enriched_phenotypes`: Array of phenotypes with positive v.test
  - `depleted_phenotypes`: Array of phenotypes with negative v.test
  - `clinical_pattern`: Description of clinical syndrome category

#### Task 1.4: Update Judge for Phenotype Validation
**File:** `llm-judge.R`
**New function:** `build_phenotype_judge_prompt()`
**Key features:**
- Validate against phenotype data, not enrichment terms
- Check that mentioned phenotypes exist in input
- Verify v.test interpretation is correct

### Phase 2: Anti-Hallucination Measures

#### Task 2.1: Add Temperature Control
Set temperature to 0.2 for more deterministic outputs

#### Task 2.2: Add Uncertainty Constraints
Add to prompts:
- "If you cannot determine something from the provided data, explicitly state 'Unable to determine from provided data'"
- "Do NOT invent or guess phenotypes not listed above"

#### Task 2.3: Add Grounding Instructions
- "ONLY reference phenotypes from the data provided"
- "Every claim must be traceable to a specific data point"

#### Task 2.4: Add Chain-of-Verification
After generation, add verification step:
- Extract all phenotypes mentioned in summary
- Check each against input data
- Reject if any invented phenotypes found

### Phase 3: Regenerate All Phenotype Summaries

#### Task 3.1: Clear Phenotype Cache
Delete all phenotype cluster summaries from cache

#### Task 3.2: Trigger Regeneration
Trigger batch generation for all phenotype clusters

#### Task 3.3: Validate Results
Manual review of regenerated summaries

---

## Detailed Implementation

### New `build_phenotype_cluster_prompt()` Function

```r
#' Build prompt for phenotype cluster summary generation
#'
#' Creates a prompt optimized for phenotype clustering data with v.test scores.
#' Focuses on clinical phenotype patterns, not gene functions.
#'
#' @param cluster_data List containing quali_inp_var with phenotype variables
#' @param top_n_phenotypes Integer, number of phenotypes to include (default: 25)
#'
#' @return Character string, the formatted prompt
#' @export
build_phenotype_cluster_prompt <- function(cluster_data, top_n_phenotypes = 25) {
  # Extract and format phenotype variables
  if (!"quali_inp_var" %in% names(cluster_data) || length(cluster_data$quali_inp_var) == 0) {
    # Fallback if no phenotype data
    return(build_cluster_prompt(cluster_data))
  }

  phenotypes_df <- if (is.data.frame(cluster_data$quali_inp_var)) {
    cluster_data$quali_inp_var
  } else if (is.list(cluster_data$quali_inp_var)) {
    dplyr::bind_rows(cluster_data$quali_inp_var)
  } else {
    return(build_cluster_prompt(cluster_data))
  }

  # Sort by absolute v.test and take top N
  phenotypes_sorted <- phenotypes_df %>%
    dplyr::arrange(desc(abs(`v.test`))) %>%
    dplyr::slice_head(n = top_n_phenotypes)

  # Format with clear interpretation
  phenotype_lines <- phenotypes_sorted %>%
    dplyr::mutate(
      direction = dplyr::case_when(
        `v.test` > 5 ~ "STRONGLY ENRICHED",
        `v.test` > 2 ~ "enriched",
        `v.test` < -5 ~ "STRONGLY DEPLETED",
        `v.test` < -2 ~ "depleted",
        TRUE ~ "neutral"
      ),
      line = glue::glue("- {variable}: v.test = {round(`v.test`, 2)} [{direction}] (p = {signif(`p.value`, 2)})")
    ) %>%
    dplyr::pull(line) %>%
    paste(collapse = "\n")

  # Get entity count
  entity_count <- if ("identifiers" %in% names(cluster_data)) {
    nrow(cluster_data$identifiers)
  } else {
    cluster_data$cluster_size %||% "unknown"
  }

  prompt <- glue::glue("
You are an expert in clinical genetics and phenotype-based syndrome recognition.
Analyze this phenotype cluster and describe its clinical characteristics.

## CRITICAL INSTRUCTIONS - READ CAREFULLY

1. This cluster contains DISEASE ENTITIES (gene-disease associations), NOT individual genes
2. The v.test score indicates enrichment:
   - POSITIVE v.test = phenotype is MORE COMMON in this cluster than average
   - NEGATIVE v.test = phenotype is LESS COMMON in this cluster than average
   - Larger absolute values = stronger association
3. You MUST describe BOTH enriched AND depleted phenotypes - both are clinically meaningful
4. DO NOT guess at gene functions or molecular mechanisms
5. DO NOT invent phenotypes not in the list below
6. If unsure, state 'Unable to determine from the provided data'

## Cluster Information
- **Number of disease entities:** {entity_count}

## Phenotype Enrichment Analysis
The following phenotypes characterize this cluster (sorted by effect size):

{phenotype_lines}

## Your Task
Based ONLY on the phenotype data above:

1. **Summary (2-3 sentences):** Describe the clinical phenotype pattern that defines this cluster. What type of conditions are grouped here?

2. **Key phenotype themes (3-5):** List the main phenotypic categories that are enriched (positive v.test)

3. **Depleted phenotypes (if notable):** What phenotypes are notably ABSENT or rare in this cluster? (negative v.test)

4. **Clinical pattern:** What syndrome category or disease class does this pattern suggest? (e.g., 'syndromic malformations', 'progressive metabolic', 'overgrowth syndromes')

5. **Tags (3-7):** Short searchable terms from the phenotype data (NOT gene function terms)

REMEMBER: Only reference phenotypes from the data above. Any invented terms will cause rejection.
")

  return(prompt)
}
```

### Updated `phenotype_cluster_summary_type`

```r
phenotype_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a phenotype cluster",

  summary = ellmer::type_string(
    "2-3 sentence description of the clinical phenotype pattern.
     Focus on what phenotypes define this cluster, not gene functions.
     ONLY reference phenotypes from the provided data."
  ),

  key_phenotype_themes = ellmer::type_array(
    ellmer::type_string("Clinical phenotype category"),
    "3-5 main phenotypic themes that are ENRICHED in this cluster (positive v.test)"
  ),

  depleted_phenotypes = ellmer::type_array(
    ellmer::type_string("Phenotype that is rare in this cluster"),
    "Notable phenotypes that are DEPLETED in this cluster (negative v.test)",
    required = FALSE
  ),

  clinical_pattern = ellmer::type_string(
    "Syndrome category suggested by the phenotype pattern (e.g., 'congenital malformations',
     'progressive metabolic disorders', 'overgrowth syndromes', 'pure neurodevelopmental')"
  ),

  tags = ellmer::type_array(
    ellmer::type_string("Searchable keyword"),
    "3-7 short tags derived from the phenotype data (e.g., 'macrocephaly', 'cardiac', 'skeletal')"
  ),

  confidence = ellmer::type_enum(
    c("high", "medium", "low"),
    "Confidence based on phenotype data strength: high if many significant phenotypes,
     medium if moderate signal, low if sparse or conflicting data"
  ),

  data_quality_note = ellmer::type_string(
    "Note any data quality issues or caveats",
    required = FALSE
  )
)
```

### Updated Judge Prompt for Phenotypes

```r
build_phenotype_judge_prompt <- function(summary, cluster_data) {
  # Extract phenotypes from input data
  input_phenotypes <- cluster_data$quali_inp_var %>%
    dplyr::pull(variable) %>%
    paste(collapse = ", ")

  # Extract phenotypes mentioned in summary
  summary_text <- summary$summary %||% ""
  themes <- paste(summary$key_phenotype_themes %||% character(0), collapse = ", ")

  judge_prompt <- glue::glue("
You are validating an AI-generated phenotype cluster summary for accuracy.

## Original Phenotype Data
The cluster had these phenotypes in its input data:
{input_phenotypes}

## Generated Summary to Validate
**Summary:** {summary_text}
**Key themes:** {themes}
**Clinical pattern:** {summary$clinical_pattern %||% 'not specified'}

## Validation Criteria

1. **Phenotype accuracy:** Does the summary ONLY reference phenotypes from the input data?
2. **No hallucination:** Are there any invented terms not in the input?
3. **v.test interpretation:** Does it correctly distinguish enriched (positive) from depleted (negative)?
4. **Clinical relevance:** Is the clinical pattern suggestion reasonable given the phenotypes?

## Verdicts
- **accept:** Summary accurately describes the phenotype pattern using only input data
- **low_confidence:** Minor issues but generally accurate
- **reject:** Contains hallucinated phenotypes or fundamentally misinterprets the data
")

  return(judge_prompt)
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `api/functions/llm-service.R` | Add `build_phenotype_cluster_prompt()`, update type spec, change default model |
| `api/functions/llm-judge.R` | Add `build_phenotype_judge_prompt()`, change default model |
| `api/functions/llm-batch-generator.R` | Use phenotype prompt for cluster_type="phenotype" |

---

## Testing Plan

1. Clear phenotype cache
2. Regenerate Cluster 1 with new prompt
3. Verify summary mentions: genitourinary, kidney, skeletal, facial, heart abnormalities
4. Verify summary does NOT mention: mitochondrial, metabolic, lysosomal
5. Repeat for all 5 clusters

---

## Success Criteria

| Cluster | Must Mention | Must NOT Mention |
|---------|--------------|------------------|
| 1 | genitourinary, kidney, skeletal, facial, cardiac malformations | mitochondrial, metabolic, lysosomal |
| 2 | integument/skin, short stature, blood | synaptic, neuronal development |
| 3 | progressive, mitochondrial, metabolic, regression | DNA repair, RNA processing |
| 4 | "lack of" syndromic features, pure NDD | chromatin, transcription |
| 5 | overgrowth, tall stature, macrocephaly | chromatin, histone |

---

## References

- [PromptHub: Three Prompt Engineering Methods to Reduce Hallucinations](https://www.prompthub.us/blog/three-prompt-engineering-methods-to-reduce-hallucinations)
- [Gemini models documentation](https://ai.google.dev/gemini-api/docs/models)
- [Microsoft: Best Practices for Mitigating Hallucinations](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/best-practices-for-mitigating-hallucinations-in-large-language-models-llms/4403129)

---

*Generated: 2026-02-01*
