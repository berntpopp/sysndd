# Functional Cluster LLM Summary Audit

**Date:** 2026-02-01
**Status:** MAJOR BUGS FOUND - Prompt sends GO IDs instead of descriptions

---

## Critical Bug: Description Not Sent

### The Problem

The `build_cluster_prompt()` function sends **GO IDs** (e.g., "GO:0007275") instead of **human-readable descriptions** (e.g., "Multicellular organism development").

**Current code (line 198):**
```r
dplyr::mutate(term_line = glue::glue("- {term} (FDR: {signif(fdr, 3)})"))
```

**Data structure available:**
```json
{
  "category": "Process",
  "term": "GO:0007275",                              // ← SENT (opaque ID)
  "number_of_genes": 382,                            // ← NOT SENT
  "number_of_genes_in_background": 5023,             // ← NOT SENT
  "p_value": 3.52E-106,
  "fdr": 4.52E-102,                                  // ← SENT
  "description": "Multicellular organism development" // ← NOT SENT!
}
```

**What LLM receives:**
```
### Process
- GO:0007275 (FDR: 4.52e-102)
- GO:0009653 (FDR: 1.47e-100)
```

**What LLM SHOULD receive:**
```
### Process
- Multicellular organism development (FDR: 4.52e-102, 382 genes)
- Anatomical structure morphogenesis (FDR: 1.47e-100, 265 genes)
```

### Impact

The LLM must **infer** what GO:0007275 means from training data, which:
1. May be inaccurate or outdated
2. Loses the exact enrichment context
3. Forces hallucination of term meanings

---

## Cluster-by-Cluster Analysis

### Cluster 1: Developmental Processes

**Actual Top Enrichment Data:**
| Category | Description | FDR | Genes |
|----------|-------------|-----|-------|
| Process | Multicellular organism development | 4.52E-102 | 382 |
| Process | Anatomical structure morphogenesis | 1.47E-100 | 265 |
| Process | System development | 6.34E-98 | 356 |
| HPO | Abnormal nervous system physiology | 1.08E-89 | 297 |
| KEGG | Pathways in cancer | 6.63E-41 | - |
| KEGG | PI3K-Akt signaling pathway | 2.62E-31 | - |

**LLM Summary:**
> "This gene cluster is strongly associated with developmental processes, particularly those involving morphogenesis, cell differentiation, and signaling pathways crucial for embryonic development."

**Pathways mentioned:** Hippo, Wnt, ErbB, PI3K-Akt, TGF-beta

**ACCURACY: ~75%**
- ✅ "Developmental processes, morphogenesis" - CORRECT, matches top terms
- ✅ PI3K-Akt - CORRECT, in KEGG data
- ⚠️ Hippo, Wnt, ErbB, TGF-beta - NOT VERIFIED in top KEGG terms shown
- The summary captures the general theme but may invent specific pathways

---

### Cluster 2: Nuclear/Chromatin Processes

**Actual Top Enrichment Data:**
| Category | Description | FDR | Genes |
|----------|-------------|-----|-------|
| COMPARTMENTS | Nucleus | 4.39E-198 | 551 |
| Component | Nucleoplasm | 2.87E-177 | 500 |
| Keyword | Nucleus | 1.12E-172 | 549 |
| Component | Nuclear lumen | 2.82E-172 | 529 |

**LLM Summary:**
> "This gene cluster is strongly associated with fundamental cellular processes, particularly those related to gene expression, RNA processing, and DNA repair."

**Pathways mentioned:** Spliceosome, Base excision repair, Nucleotide excision repair, Fanconi anemia, RNA transport

**ACCURACY: ~60%**
- ✅ Nuclear localization is dominant - correctly inferred
- ⚠️ "RNA processing, DNA repair" - Reasonable inference from nuclear localization but NOT explicitly in top terms
- ⚠️ Specific pathways (Spliceosome, Base excision repair) - May not be in enrichment data

---

### Cluster 3: Metabolic/Mitochondrial

**Actual Top Enrichment Data:**
| Category | Top Term | Count |
|----------|----------|-------|
| HPO | Abnormal muscle physiology | 1352 terms total |
| COMPARTMENTS | Mitochondrion | 88 terms |
| Component | Mitochondrion | 75 terms |
| KEGG | Metabolic pathways | 59 terms |
| DISEASES | Inherited metabolic disorder | 91 terms |

**LLM Summary:**
> "This gene cluster is strongly associated with mitochondrial function, particularly oxidative phosphorylation and the electron transport chain."

**ACCURACY: ~70%**
- ✅ Mitochondrion IS in the data (COMPARTMENTS, Component, Keyword categories)
- ✅ Metabolic pathways IS in KEGG
- ⚠️ Top HPO terms (muscle physiology) are underemphasized
- ⚠️ "Oxidative phosphorylation, electron transport chain" - Reasonable inference but may not be exact terms

---

### Cluster 4: Glycosylation/Lysosomal

**Actual Top Enrichment Data:**
| Category | Description | FDR |
|----------|-------------|-----|
| HPO | Neurodevelopmental abnormality | 1.57E-128 |
| HPO | Abnormal muscle tone | 1.88E-127 |
| KEGG | Lysosome | 4.58E-41 |
| KEGG | N-Glycan biosynthesis | 1.67E-23 |
| Process | Glycosylation | 1.6E-44 |

**LLM Summary:**
> "This gene cluster is strongly associated with protein glycosylation and the synthesis of various glycans... linked to congenital disorders of glycosylation (CDGs) and lysosomal storage disorders."

**ACCURACY: ~80%**
- ✅ Glycosylation IS in Process and KEGG terms
- ✅ Lysosome IS in KEGG
- ✅ CDGs/lysosomal storage is reasonable clinical inference
- ⚠️ HPO terms (NDD, muscle tone) are underemphasized in summary

---

### Cluster 5: Synaptic/Neuronal

**Actual Top Enrichment Data:**
| Category | Description | FDR | Genes |
|----------|-------------|-----|-------|
| Component | Synapse | 4.27E-142 | 251 |
| Component | Cell junction | 1.13E-122 | 272 |
| Component | Neuron projection | 1.08E-115 | 226 |
| Component | Postsynapse | 4.32E-98 | 158 |

**LLM Summary:**
> "This gene cluster... is strongly enriched for genes involved in neuronal function, particularly synaptic transmission and ion transport across neuronal membranes."

**ACCURACY: ~90%**
- ✅ Synapse, Neuron projection - EXACTLY matches top terms
- ✅ "Synaptic transmission" - Correct inference
- ⚠️ "Ion transport" - May or may not be in data (not shown in top terms)

---

### Cluster 6: Cilium/Microtubule

**Actual Top Enrichment Data:**
| Category | Description | FDR | Genes |
|----------|-------------|-----|-------|
| Keyword | Cytoskeleton | 1.32E-111 | 135 |
| Component | Microtubule cytoskeleton | 1.73E-106 | 132 |
| Process | Cilium organization | 2E-87 | 86 |
| Component | Microtubule organizing center | 9.7E-87 | 103 |

**LLM Summary:**
> "This gene cluster is strongly associated with cilia function, microtubule organization, and cell division, processes that are critical for neurodevelopment."

**ACCURACY: ~95%**
- ✅ Cilium, Microtubule - EXACTLY matches top terms
- ✅ "Ciliopathies, microcephaly syndromes" - Correct clinical inference
- This is the most accurate summary

---

## Summary: Functional Cluster Accuracy

| Cluster | Theme | Accuracy | Main Issue |
|---------|-------|----------|------------|
| 1 | Developmental | ~75% | Some pathways may be invented |
| 2 | Nuclear | ~60% | Inferred mechanisms not in data |
| 3 | Mitochondrial | ~70% | HPO terms underemphasized |
| 4 | Glycosylation | ~80% | HPO terms underemphasized |
| 5 | Synaptic | ~90% | Minor - "ion transport" unverified |
| 6 | Cilium | ~95% | Excellent match |

**Overall: Functional clusters are ~75% accurate** - much better than phenotype clusters (0%) but still have issues.

---

## Root Causes

### 1. GO IDs Instead of Descriptions (CRITICAL)
The LLM receives "GO:0007275" not "Multicellular organism development"

### 2. Missing Gene Counts
The LLM doesn't see `number_of_genes` which indicates strength of evidence

### 3. Category Imbalance
HPO terms are numerous but often underemphasized in summaries relative to KEGG pathways

### 4. No Grounding Instructions
Prompt doesn't explicitly forbid inventing pathway names

---

## Recommended Fixes

### Fix 1: Include Description and Gene Count

```r
# Change from:
dplyr::mutate(term_line = glue::glue("- {term} (FDR: {signif(fdr, 3)})"))

# To:
dplyr::mutate(term_line = glue::glue("- {description} [{term}] (FDR: {signif(fdr, 3)}, {number_of_genes} genes)"))
```

### Fix 2: Add Anti-Hallucination Instructions

Add to prompt:
```
IMPORTANT: Only use pathway names that appear EXACTLY in the enrichment data above.
Do NOT invent or generalize pathway names.
If a pathway is not listed above, do not mention it.
```

### Fix 3: Prioritize by Significance

Sort all terms by FDR regardless of category, then show top 50-100 most significant:

```r
enrichment <- cluster_data$term_enrichment %>%
  dplyr::arrange(fdr) %>%
  dplyr::slice_head(n = 100)
```

### Fix 4: Structured Category Summary

Instead of showing all categories equally, show:
1. **Most significant overall** (top 20 by FDR regardless of category)
2. **By category** (top 5-10 per category)

---

## Comparison: Functional vs Phenotype Clusters

| Aspect | Functional Clusters | Phenotype Clusters |
|--------|--------------------|--------------------|
| Data sent | GO IDs (missing descriptions) | NO DATA AT ALL |
| Accuracy | ~75% | ~0% |
| Main issue | Missing descriptions, some hallucination | Complete hallucination |
| Fix complexity | Medium - add fields | High - new prompt needed |

---

*Generated: 2026-02-01*
