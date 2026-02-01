# LLM Prompt Analysis Report

**Date:** 2026-02-01
**Purpose:** Analyze LLM prompts, understand "Pending review" status, and recommend model upgrades

---

## Executive Summary

Several clusters show "Pending review" status because the LLM-as-judge gives `low_confidence` verdicts when clusters lack enrichment data. Phenotype clusters don't have `term_enrichment` data (they have phenotype variables instead), so the prompt builder passes empty data, leading to inconsistent judge decisions.

**Key Issues:**
1. Phenotype clusters use different data structure (`quali_inp_var`) than functional clusters (`term_enrichment`)
2. Prompt builder only supports `term_enrichment`, not phenotype variables
3. LLM judge is inconsistent when no enrichment data provided
4. Current model (`gemini-2.0-flash`) is being deprecated March 31, 2026

---

## Current Validation Status

| Cluster Type | Total | Validated | Pending | Rejected |
|--------------|-------|-----------|---------|----------|
| Functional | 6 | 4 | 2 | 0 |
| Phenotype | 5 | 2 | 3 | 0 |

### Detailed Status

```
cache_id  cluster_type  cluster_number  validation_status
1         functional    1               validated
2         functional    2               validated
3         functional    3               validated
4         functional    4               validated
5         functional    5               pending
6         functional    6               pending
33        phenotype     1               validated
34        phenotype     2               pending
32        phenotype     3               pending
31        phenotype     4               validated
35        phenotype     5               pending
```

---

## Available Gemini Models

### Recommended Models (Early 2026)

| Model ID | Description | Best For | Status |
|----------|-------------|----------|--------|
| `gemini-3-pro-preview` | Best multimodal understanding | Complex reasoning, accuracy | **Recommended** |
| `gemini-3-flash-preview` | Balanced speed + intelligence | High-volume, low-latency | Good alternative |
| `gemini-2.5-pro` | State-of-the-art thinking | Complex reasoning | Stable |
| `gemini-2.5-flash` | Best price-performance | Large-scale processing | Stable |
| `gemini-2.5-flash-lite` | Fastest, cost-efficient | High throughput | Stable |

### Deprecated (To Be Removed March 31, 2026)

| Model ID | Status |
|----------|--------|
| `gemini-2.0-flash` | **Currently in use - DEPRECATING** |
| `gemini-2.0-flash-lite` | Deprecating |

**Action Required:** Update default model from `gemini-2.0-flash` to `gemini-2.5-flash` or `gemini-3-flash-preview`.

Sources:
- [Gemini models documentation](https://ai.google.dev/gemini-api/docs/models)
- [Release notes](https://ai.google.dev/gemini-api/docs/changelog)

---

## Generation Prompt Analysis

### File: `api/functions/llm-service.R`

#### Prompt Template (lines 208-226)

```
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
```

#### Data Sent to LLM

**For Functional Clusters:**
- Gene symbols (comma-separated list)
- Gene count
- Term enrichment data (top 20 per category):
  - Category (GO, KEGG, HPO, etc.)
  - Term name
  - FDR value

**Example enrichment text:**
```
### GO:BP
- nervous system development (FDR: 1.23e-15)
- neurogenesis (FDR: 3.45e-12)
...

### KEGG
- Hippo signaling pathway (FDR: 2.34e-08)
...
```

**For Phenotype Clusters (PROBLEM):**
- Gene symbols (comma-separated list)
- Gene count
- **EMPTY enrichment data** - `(No enrichment data provided)`

The prompt builder (`build_cluster_prompt()`) only handles `term_enrichment`. Phenotype clusters have different data:
- `quali_inp_var` - Phenotype input variables (p-value, v-test)
- `quali_sup_var` - Supplementary variables (inheritance)
- `quanti_sup_var` - Quantitative variables (phenotype counts)

---

## Judge/Validator Prompt Analysis

### File: `api/functions/llm-judge.R`

#### Judge Prompt Template (lines 168-198)

```
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
```

#### Verdict Mapping

| Judge Verdict | Validation Status | UI Display |
|---------------|-------------------|------------|
| `accept` | `validated` | "Validated" |
| `low_confidence` | `pending` | "Pending review" |
| `reject` | `rejected` | (hidden, triggers retry) |

---

## Why Phenotype Cluster 2 Shows "Pending Review"

### Root Cause

The LLM judge gave `low_confidence` verdict because:

1. **No enrichment data provided:** The phenotype cluster has `quali_inp_var` data, but the prompt builder only passes `term_enrichment` (which is empty)

2. **Judge reasoning (from database):**
   > "since no enrichment data was provided, the summary is not grounded in the 'enrichment data above' as the instructions require"

3. **Derived confidence also low:** `"term_count": 0, "avg_fdr": "NA"`

### Comparison: Phenotype Cluster 1 (Validated) vs Cluster 2 (Pending)

Both have identical data structure issues (no enrichment data), but the judge was inconsistent:

**Cluster 1 (validated):**
> "Although no enrichment data is provided, the connections made are logical and supported by the gene list. Low confidence seems appropriate given lack of direct evidence."

**Cluster 2 (pending):**
> "since no enrichment data was provided, the summary is not grounded in the 'enrichment data above' as the instructions require"

This inconsistency is due to LLM non-determinism - the same input can produce different judgments.

---

## Recommendations

### 1. Upgrade Model (URGENT - Before March 31, 2026)

Update default model in these files:

**`api/functions/llm-service.R` line 275:**
```r
# Change from:
model = "gemini-2.0-flash"

# To:
model = "gemini-2.5-flash"  # or "gemini-3-flash-preview"
```

**`api/functions/llm-judge.R` line 106:**
```r
# Change from:
model = "gemini-2.0-flash"

# To:
model = "gemini-2.5-flash"  # or "gemini-3-flash-preview"
```

### 2. Fix Phenotype Cluster Data (HIGH PRIORITY)

Modify `build_cluster_prompt()` to handle phenotype data:

```r
# If no term_enrichment, use quali_inp_var for phenotype clusters
if (is.null(enrichment_text) || enrichment_text == "(No enrichment data provided)") {
  if ("quali_inp_var" %in% names(cluster_data)) {
    # Format phenotype variables as enrichment-like data
    phenotype_text <- cluster_data$quali_inp_var %>%
      dplyr::arrange(`p.value`) %>%
      dplyr::slice_head(n = 20) %>%
      dplyr::mutate(term_line = glue::glue("- {variable} (p-value: {signif(`p.value`, 3)})")) %>%
      dplyr::pull(term_line) %>%
      paste(collapse = "\n")

    enrichment_text <- glue::glue("### Phenotype Variables\n{phenotype_text}")
  }
}
```

### 3. Improve Judge Prompt Consistency (MEDIUM)

Add guidance for handling missing enrichment data:

```
## Special Instructions
- If no enrichment data is provided, evaluate based on gene list relevance only
- Do NOT mark as low_confidence solely due to missing enrichment data
- Focus on biological accuracy of the summary given the genes present
```

### 4. Update Model List (LOW)

Update `list_gemini_models()` in `llm-service.R`:

```r
list_gemini_models <- function() {
  c(
    "gemini-3-pro-preview",     # Best quality (newest)
    "gemini-3-flash-preview",   # Fast + capable (newest)
    "gemini-2.5-flash",         # Best price-performance
    "gemini-2.5-pro",           # Complex reasoning
    "gemini-2.5-flash-lite"     # Budget option
  )
}
```

---

## Data Structure Comparison

### Functional Cluster
```json
{
  "cluster": 1,
  "cluster_size": 150,
  "hash_filter": "equals(hash,abc123...)",
  "identifiers": [{"hgnc_id": 1, "symbol": "BRCA1"}, ...],
  "term_enrichment": [
    {"category": "GO:BP", "term": "DNA repair", "fdr": 1e-15},
    {"category": "KEGG", "term": "Cell cycle", "fdr": 1e-10}
  ]
}
```

### Phenotype Cluster
```json
{
  "cluster": 1,
  "cluster_size": 325,
  "hash_filter": "equals(hash,def456...)",
  "identifiers": [{"entity_id": "abc", "symbol": "GENE1"}, ...],
  "quali_inp_var": [
    {"variable": "Intellectual disability", "p.value": 1e-50, "v.test": 15.2},
    {"variable": "Seizures", "p.value": 1e-30, "v.test": 12.1}
  ],
  "quali_sup_var": [...],
  "quanti_sup_var": [...]
}
```

---

## Implementation Priority

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| **1 - URGENT** | Upgrade to gemini-2.5-flash | Low | Avoid deprecation breakage |
| **2 - HIGH** | Support quali_inp_var in prompts | Medium | Fix phenotype summaries |
| **3 - MEDIUM** | Improve judge consistency | Low | Reduce pending rate |
| **4 - LOW** | Update model list | Low | Better documentation |

---

*Generated: 2026-02-01*
