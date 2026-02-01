# Phenotype Cluster LLM Summary Audit

**Date:** 2026-02-01
**Status:** CRITICAL - All summaries are hallucinated and useless

---

## Summary of Findings

**ALL 5 phenotype cluster summaries are fundamentally wrong.** The LLM:
1. Received NO phenotype data - only gene symbols
2. Hallucinated gene functions instead of describing phenotype patterns
3. Completely ignored the actual cluster characteristics
4. Doesn't understand v.test scores (positive = overrepresented, negative = underrepresented)

---

## Detailed Cluster-by-Cluster Audit

### Cluster 1: Congenital Malformation Syndrome Cluster

**ACTUAL DATA (Top Phenotypes):**
| Phenotype | v.test | Interpretation |
|-----------|--------|----------------|
| Abnormality of genitourinary system | +22.18 | STRONGLY overrepresented |
| Abnormality of kidney | +16.27 | STRONGLY overrepresented |
| Abnormality of skeletal system | +14.27 | STRONGLY overrepresented |
| Abnormal facial shape | +14.19 | STRONGLY overrepresented |
| Oral cleft | +13.51 | STRONGLY overrepresented |
| Eye abnormality | +13.09 | STRONGLY overrepresented |
| Heart morphology | +12.96 | STRONGLY overrepresented |
| Limb abnormality | +12.83 | STRONGLY overrepresented |

**CORRECT INTERPRETATION:** This cluster represents **syndromic/congenital malformation disorders** with multi-organ involvement (kidney, skeletal, facial, cardiac, limb defects). Classic pattern for ciliopathies, CHARGE syndrome, VACTERL association, etc.

**LLM HALLUCINATED:**
> "This gene cluster is strongly associated with mitochondrial dysfunction, inborn errors of metabolism, and lysosomal storage disorders... genes involved in mitochondrial respiratory chain function, fatty acid oxidation, peroxisomal biogenesis"

**ACCURACY: 0% - Completely wrong.** The summary talks about metabolic disorders but the data clearly shows congenital malformations!

---

### Cluster 2: Ectodermal/Hematological Cluster (NOT Neurological!)

**ACTUAL DATA (Top Phenotypes):**
| Phenotype | v.test | Interpretation |
|-----------|--------|----------------|
| Abnormality of integument (skin) | +13.42 | Overrepresented |
| Short stature | +13.16 | Overrepresented |
| **Abnormality of nervous system** | **-12.52** | **UNDERREPRESENTED!** |
| Blood abnormalities | +11.53 | Overrepresented |
| **Abnormality of brain morphology** | **-11.26** | **UNDERREPRESENTED!** |

**CORRECT INTERPRETATION:** This cluster is characterized by skin/integument issues, short stature, and blood abnormalities. Critically, it is **LESS** associated with nervous system and brain abnormalities (negative v.test). Think RASopathies, ectodermal dysplasias, bone marrow failure syndromes.

**LLM HALLUCINATED:**
> "This gene cluster is strongly associated with neurodevelopmental disorders, with a significant enrichment of genes involved in synaptic function, neuronal development, and intellectual disability."

**ACCURACY: 0% - OPPOSITE of reality!** The data shows this cluster is **negatively** associated with brain/nervous system issues, but the LLM claimed "strongly associated with neurodevelopmental disorders"!

---

### Cluster 3: Progressive Metabolic/Degenerative Cluster

**ACTUAL DATA (Top Phenotypes):**
| Phenotype | v.test | Interpretation |
|-----------|--------|----------------|
| Progressive | +21.95 | STRONGLY overrepresented |
| Age of death (early) | +20.29 | STRONGLY overrepresented |
| Abnormality of mitochondrion | +18.42 | STRONGLY overrepresented |
| Abnormality of metabolism/homeostasis | +18.03 | STRONGLY overrepresented |
| Developmental regression | +15.99 | STRONGLY overrepresented |

**CORRECT INTERPRETATION:** This is clearly a **progressive/degenerative metabolic cluster** - conditions that worsen over time, often with early death, mitochondrial involvement, and regression. Classic pattern for mitochondrial disorders, lysosomal storage diseases, neurodegeneration.

**LLM SAID:**
> "This gene cluster exhibits a diverse set of functions... including DNA repair, RNA processing, signal transduction"

**ACCURACY: ~20%** - The LLM completely missed the clear progressive/metabolic signature visible in the data! The data SCREAMS "mitochondrial/metabolic degenerative conditions" but LLM talked about "DNA repair, RNA processing."

---

### Cluster 4: "Typical NDD" Cluster (Negative for Syndromic Features)

**ACTUAL DATA (Top Phenotypes - ALL NEGATIVE!):**
| Phenotype | v.test | Interpretation |
|-----------|--------|----------------|
| Abnormality of genitourinary system | **-15.36** | UNDERREPRESENTED |
| Abnormal heart morphology | **-13.91** | UNDERREPRESENTED |
| Abnormality of skeletal system | **-12.38** | UNDERREPRESENTED |
| Age of death | **-12.29** | UNDERREPRESENTED |
| Short stature | **-12.07** | UNDERREPRESENTED |

**CORRECT INTERPRETATION:** This cluster is defined by what it **LACKS** - no congenital malformations, no early death, no syndromic features. These are likely **"pure" neurodevelopmental disorders** without multi-organ involvement (autism, isolated ID, etc.).

**LLM HALLUCINATED:**
> "This gene cluster is strongly implicated in neurodevelopmental disorders, encompassing... chromatin remodeling, transcriptional regulation, and signal transduction pathways"

**ACCURACY: ~30%** - Yes it's NDD-related, but the LLM completely missed the KEY insight: this cluster is characterized by ABSENCE of syndromic features. The negative v.tests are crucial information that was ignored!

---

### Cluster 5: Overgrowth Syndrome Cluster

**ACTUAL DATA (Top Phenotypes):**
| Phenotype | v.test | Interpretation |
|-----------|--------|----------------|
| Overgrowth | +12.20 | STRONGLY overrepresented |
| Tall stature | +11.78 | STRONGLY overrepresented |
| Macrocephaly | +9.59 | Overrepresented |
| Obesity | +4.75 | Moderately overrepresented |
| Intellectual disability, mild | +4.03 | Moderately overrepresented |

**CORRECT INTERPRETATION:** This is clearly an **overgrowth syndrome cluster** - conditions with excessive growth, large head, tall stature. Think PTEN hamartoma syndrome, Sotos syndrome, Weaver syndrome, PIK3CA-related overgrowth, etc.

**LLM HALLUCINATED:**
> "This gene cluster is strongly implicated in chromatin modification and regulation of gene expression... histone modification, and transcriptional control"

**ACCURACY: ~10%** - While some overgrowth syndromes DO involve chromatin (e.g., NSD1 in Sotos), the LLM should have described the PHENOTYPE PATTERN (overgrowth, macrocephaly, tall stature) not guessed at molecular mechanisms. The summary tells users nothing useful about what phenotypes characterize this cluster!

---

## Root Cause Analysis

### Problem 1: No Phenotype Data Sent to LLM

The prompt builder (`build_cluster_prompt()`) only handles `term_enrichment` data:

```r
# Current code - only checks for term_enrichment
if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
  # ... format enrichment data
} else {
  enrichment_text <- "(No enrichment data provided)"
}
```

Phenotype clusters have `quali_inp_var`, `quali_sup_var`, `quanti_sup_var` - **none of this is passed to the LLM!**

### Problem 2: Wrong Prompt for Phenotype Analysis

The generation prompt says:
> "You are an expert in neurodevelopmental disorders and genomics. Analyze this gene cluster..."

But phenotype clusters are about **entity grouping by phenotype patterns**, not gene function!

### Problem 3: LLM Only Receives Gene Symbols

Without phenotype data, the LLM just sees gene symbols and hallucinates based on what it "knows" about those genes from training data - which has nothing to do with the actual cluster characteristics.

### Problem 4: Judge Can't Validate

The judge prompt asks about "enrichment terms" which don't exist for phenotype clusters. So even clearly hallucinated summaries get `accept` or `low_confidence` instead of `reject`.

---

## What a Correct Summary Should Look Like

### Cluster 1 - CORRECT Summary:
> "This phenotype cluster is characterized by congenital malformation syndromes with multi-organ involvement. Entities show strong enrichment for structural abnormalities of the genitourinary system (v.test: 22.2), kidney (16.3), skeletal system (14.3), face (14.2), and heart (13.0). This pattern suggests ciliopathies, cohesinopathies, or syndromes like CHARGE or VACTERL association."

### Cluster 3 - CORRECT Summary:
> "This phenotype cluster represents progressive and degenerative conditions with significant metabolic involvement. Entities are strongly enriched for progressive course (v.test: 22.0), early mortality (20.3), mitochondrial abnormalities (18.4), and metabolic dysfunction (18.0). Developmental regression (16.0) is prominent. This pattern is typical of mitochondrial disorders, lysosomal storage diseases, and neurometabolic conditions."

### Cluster 5 - CORRECT Summary:
> "This phenotype cluster is characterized by overgrowth syndromes. Entities show strong enrichment for overgrowth (v.test: 12.2), tall stature (11.8), and macrocephaly (9.6). Obesity and mild intellectual disability are moderately associated. This pattern suggests conditions like Sotos syndrome, PTEN hamartoma syndrome, or PIK3CA-related overgrowth spectrum."

---

## Recommendations

### 1. Create Phenotype-Specific Prompt (CRITICAL)

```r
build_phenotype_cluster_prompt <- function(cluster_data) {
  # Extract phenotype variables with v.test
  phenotypes <- cluster_data$quali_inp_var %>%
    dplyr::arrange(desc(abs(`v.test`))) %>%
    dplyr::slice_head(n = 20) %>%
    dplyr::mutate(
      direction = ifelse(`v.test` > 0, "OVERREPRESENTED", "UNDERREPRESENTED"),
      term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} ({direction}, p={signif(`p.value`, 3)})")
    ) %>%
    dplyr::pull(term_line) %>%
    paste(collapse = "\n")

  prompt <- glue::glue("
You are an expert in clinical genetics and syndrome recognition.
Analyze this phenotype cluster and describe its clinical pattern.

## Important: Understanding the Data
- This is a cluster of DISEASE ENTITIES (gene-disease associations), NOT genes
- Positive v.test = phenotype is OVERREPRESENTED in this cluster
- Negative v.test = phenotype is UNDERREPRESENTED in this cluster
- The v.test magnitude indicates strength of association

## Phenotype Enrichment Data
{phenotypes}

## Instructions
1. Describe the PHENOTYPE PATTERN (do NOT guess at gene functions)
2. Identify what syndrome categories this cluster might represent
3. Note both enriched AND depleted phenotypes - both are informative
4. Suggest clinical syndrome associations based on phenotype pattern
5. Be specific about the phenotypes - do not hallucinate terms not in the data

CRITICAL: Only describe phenotypes from the data above. Do NOT invent or guess!
")
  return(prompt)
}
```

### 2. Create Phenotype-Specific Judge Prompt

The judge must validate against the phenotype data, not enrichment terms.

### 3. Immediate Model Migration

Change from `gemini-2.0-flash` to `gemini-3-pro-preview` for better reasoning.

### 4. Add Hallucination Guards

- Set temperature to 0.1-0.2 for consistency
- Add explicit instruction: "If unsure, say 'unclear from data'"
- Post-process to verify mentioned phenotypes exist in input

---

*Generated: 2026-02-01*
