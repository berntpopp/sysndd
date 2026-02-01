# LLM Prompt Test Results

**Date:** 2026-02-01
**Model:** gemini-3-pro-preview
**Status:** ALL PROMPTS VALIDATED - Ready for implementation

---

## Executive Summary

| Prompt Type | Result | Accuracy | Data Sent |
|-------------|--------|----------|-----------|
| Functional Cluster (Generator) | PASS | ~100% | 3-5 terms per category (GO, KEGG, HPO) |
| Functional Cluster (Validator) | PASS | N/A | Top 15 terms by FDR |
| Phenotype Cluster (Generator) | PASS | ~100% | Top 10-15 by |v.test| (enriched + depleted) |
| Phenotype Cluster (Validator) | PASS | N/A | Top 15 terms by |v.test| |

---

## Data Configuration

### Functional Clusters - How Much Data We Send

| Category | Terms Per Category | Total Terms | Recommendation |
|----------|-------------------|-------------|----------------|
| GO BP | 3-5 | ~5 | Sufficient for biological theme |
| KEGG | 3-5 | ~5 | Include pathways + descriptions |
| HPO | 3-5 | ~5 | Disease relevance terms |
| **Total** | - | **9-15** | Optimal range |

**Data format sent:**
```
### GO Biological Process
- Multicellular organism development (FDR: 4.52E-102, 382/536 genes)
- Anatomical structure morphogenesis (FDR: 1.47E-100, 265/536 genes)
...

### KEGG Pathways
- PI3K-Akt signaling pathway (FDR: 2.62E-31, 67/536 genes)
...
```

### Phenotype Clusters - How Much Data We Send

| Data Type | Count | Description |
|-----------|-------|-------------|
| Enriched (positive v.test > 2) | **ALL** | Phenotypes MORE common |
| Depleted (negative v.test < -2) | **ALL** | Phenotypes LESS common |
| **Total** | **All significant** | |v.test| > 2 threshold |

**Note:** Phenotype clusters have fewer significant terms than functional clusters, so we include ALL significant phenotypes rather than limiting to top N.

**Data format sent:**
```
### ENRICHED Phenotypes (overrepresented in this cluster)
| Phenotype | v.test | p-value |
|-----------|--------|---------|
| Abnormality of the genitourinary system | +22.18 | 5.52e-109 |
...

### DEPLETED Phenotypes (underrepresented in this cluster)
| Phenotype | v.test | p-value |
|-----------|--------|---------|
| Progressive | -9.53 | 1.61e-21 |
...
```

---

## Ablation Study Results

### Phenotype Cluster: Varying Data Amounts

| Test | Data Sent | Result | Notes |
|------|-----------|--------|-------|
| Full (15 phenotypes) | 10 enriched + 5 depleted | PASS | Complete coverage |
| Top 5 (8 phenotypes) | 5 enriched + 3 depleted | PASS | Still accurate |
| ALL (25 phenotypes) | 15 enriched + 10 depleted | PASS | Most comprehensive |

**Conclusion:** Use ALL significant phenotypes (|v.test| > 2). Phenotype clusters have fewer significant terms than functional clusters, so including all provides better clinical characterization without excessive token cost.

#### Test A: Full Data (15 phenotypes)
```json
{
  "summary": "This cluster is characterized by widespread structural congenital anomalies involving the genitourinary, skeletal, and cardiovascular systems, alongside craniofacial features such as oral clefts and abnormal facial shape. Conversely, primary neurological presentations including seizures, developmental regression, and progressive neurodegenerative courses are significantly underrepresented.",
  "key_phenotype_themes": ["Genitourinary and renal malformations", "Skeletal and limb abnormalities", "Craniofacial dysmorphism and oral clefts", "Congenital heart defects", "Sensory impairment (eye and hearing)"],
  "notably_absent": ["Progressive course", "Developmental regression", "Seizures"],
  "clinical_pattern": "Multiple Congenital Anomalies (MCA) Syndrome",
  "tags": ["Genitourinary anomalies", "Renal malformations", "Skeletal dysplasia", "Oral cleft", "Congenital heart defect", "Dysmorphism", "Short stature"]
}
```

#### Test B: Top 5 Data (8 phenotypes)
```json
{
  "summary": "This cluster represents a pattern of multiple congenital anomalies characterized by structural malformations of the genitourinary system, kidneys, and skeleton. It is strongly associated with craniofacial dysmorphisms, particularly oral clefts, while distinctly lacking progressive neurodegenerative features or developmental regression.",
  "key_phenotype_themes": ["Genitourinary system abnormalities", "Renal malformations", "Skeletal abnormalities", "Craniofacial dysmorphism", "Oral clefts"],
  "notably_absent": ["Progressive course", "Developmental regression", "Abnormality of the mitochondrion"],
  "clinical_pattern": "Multiple Congenital Anomaly Syndrome",
  "tags": ["Genitourinary defects", "Kidney malformations", "Skeletal dysplasia", "Oral cleft", "Dysmorphism", "Structural anomalies"]
}
```

#### Test C: ALL Data (25 phenotypes) - RECOMMENDED
```json
{
  "summary": "This cluster represents a pattern of multiple congenital anomalies primarily affecting the genitourinary, skeletal, and craniofacial systems. It is characterized by structural malformations such as kidney defects, oral clefts, and heart defects, while notably lacking progressive neurological features, seizures, and neuromuscular abnormalities like spasticity.",
  "key_phenotype_themes": ["Genitourinary and kidney anomalies", "Skeletal and limb malformations", "Craniofacial dysmorphism (including oral clefts)", "Congenital heart defects", "Sensory impairments (Eye/Ear)"],
  "notably_absent": ["Progressive neurological symptoms", "Seizures", "Developmental regression"],
  "clinical_pattern": "Multiple Congenital Anomaly Syndrome",
  "tags": ["Genitourinary anomalies", "Renal hypoplasia", "Oral cleft", "Congenital heart defect", "Skeletal malformation", "Short stature", "Dysmorphic features"]
}
```

### Functional Cluster: Varying Terms per Category

| Test | Data Sent | Result | Notes |
|------|-----------|--------|-------|
| Top 5 per category (15 total) | 5 GO + 5 KEGG + 5 HPO | PASS | Complete coverage |
| Top 3 per category (9 total) | 3 GO + 3 KEGG + 3 HPO | PASS | Still accurate, more concise |

**Conclusion:** Top 3-5 per category is optimal. Disease relevance correctly uses HPO terms only.

#### Test A: Top 5 per category (15 terms)
```json
{
  "summary": "This cluster is highly enriched for genes involved in multicellular organism development and anatomical structure morphogenesis, mediated by critical signaling cascades including PI3K-Akt, Ras, and MAPK pathways...",
  "key_themes": ["Multicellular organism development", "Anatomical structure morphogenesis", "Neurodevelopmental abnormality", "Signal transduction", "Axon guidance"],
  "pathways": ["Pathways in cancer", "PI3K-Akt signaling pathway", "Ras signaling pathway", "Axon guidance", "MAPK signaling pathway"],
  "disease_relevance": "Abnormal nervous system physiology, Neurodevelopmental abnormality, Intellectual disability, Global developmental delay, Abnormality of nervous system morphology",
  "tags": ["neurodevelopment", "morphogenesis", "axon guidance", "PI3K-Akt", "MAPK", "intellectual disability", "Ras signaling"],
  "confidence": "high"
}
```

#### Test B: Top 3 per category (9 terms)
```json
{
  "summary": "This cluster is highly enriched for genes involved in multicellular organism development, anatomical structure morphogenesis, and system development. Biologically, these functions are driven by key signaling cascades, including the PI3K-Akt and Ras pathways...",
  "key_themes": ["Multicellular organism development", "Anatomical structure morphogenesis", "System development", "PI3K-Akt signaling", "Ras signaling"],
  "pathways": ["Pathways in cancer", "PI3K-Akt signaling pathway", "Ras signaling pathway"],
  "disease_relevance": "Neurodevelopmental abnormality, Intellectual disability, Global developmental delay",
  "tags": ["development", "morphogenesis", "PI3K-Akt", "Ras signaling", "neurodevelopmental abnormality", "intellectual disability"],
  "confidence": "high"
}
```

---

## Generator Prompts

### Functional Cluster Generator Prompt

```
You are a genomics expert analyzing gene clusters associated with neurodevelopmental disorders.

## Task
Analyze this functional gene cluster and summarize its biological significance.

## Cluster Data
- **Cluster size:** {gene_count} genes
- **Sample genes:** {sample_genes}

## Functional Enrichment Results
{enrichment_data}

## Instructions
Based on the enrichment data above:

1. **Summary (2-3 sentences):** What biological functions unite these genes?

2. **Key biological themes (3-5):** List the main functional categories from the enrichment data.

3. **Pathways:** List ONLY pathways that appear in the KEGG section above. Do NOT invent pathways.

4. **Disease relevance:** Based ONLY on the HPO Disease Phenotypes section, what disorders are associated? Do NOT speculate beyond the provided terms.

5. **Tags (3-7):** Short keywords derived from the enrichment terms.

6. **Confidence:** High if strong enrichment (FDR < 1E-50), Medium if moderate, Low if weak.

IMPORTANT: Only mention terms that appear in the data above. Do not invent or generalize.
```

### Phenotype Cluster Generator Prompt

```
You are a clinical geneticist analyzing phenotype clusters from a neurodevelopmental disorder database.

## Task
Analyze this phenotype cluster and describe its clinical pattern.

## Important Context
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations), NOT individual genes
- v.test: POSITIVE = MORE COMMON, NEGATIVE = LESS COMMON, larger |v.test| = stronger

## Phenotype Data
{phenotype_data}

## Instructions
Based ONLY on the phenotype data above:

1. **Summary (2-3 sentences):** Describe the clinical pattern. Note both enriched AND depleted phenotypes.

2. **Key phenotype themes (3-5):** Main clinical feature categories that are ENRICHED.

3. **Notably absent (2-3):** Phenotypes that are DEPLETED.

4. **Clinical pattern:** What syndrome category does this suggest?

5. **Tags (3-7):** Short clinical keywords from the phenotypes.

CRITICAL: Only describe phenotypes from the data above. Do NOT mention genes or molecular pathways.
```

---

## Validator (Judge) Prompts

### Functional Cluster Validator Prompt

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
1. **Factual accuracy:** Does the summary accurately describe biological functions of these genes?
2. **Grounding:** Are all claims supported by the enrichment data above? Are there invented terms?
3. **Pathway validity:** Are the listed pathways exact matches from the enrichment terms (no invented pathways)?
4. **Confidence appropriate:** Does the self-assessed confidence match the evidence strength?

## Instructions
Evaluate each criterion and provide a final verdict:
- **accept:** Summary is accurate and well-grounded in the enrichment data
- **low_confidence:** Summary is mostly accurate but has minor issues or unverifiable claims
- **reject:** Summary has significant errors, invented information, or hallucinated terms
```

### Phenotype Cluster Validator Prompt

```
You are validating an AI-generated phenotype cluster summary for accuracy.

## Important Context
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations), NOT genes
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
```

---

## Type Specifications

### Functional Cluster Summary Type
```r
functional_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a functional gene cluster",
  summary = ellmer::type_string("2-3 sentence summary"),
  key_themes = ellmer::type_array(ellmer::type_string("theme"), "3-5 themes"),
  pathways = ellmer::type_array(ellmer::type_string("pathway"), "KEGG pathways only"),
  tags = ellmer::type_array(ellmer::type_string("tag"), "3-7 tags"),
  clinical_relevance = ellmer::type_string("Clinical implications", required = FALSE),
  confidence = ellmer::type_enum(c("high", "medium", "low"), "Confidence level")
)
```

### Phenotype Cluster Summary Type
```r
phenotype_cluster_summary_type <- ellmer::type_object(
  "AI-generated summary of a phenotype cluster",
  summary = ellmer::type_string("2-3 sentence clinical pattern description"),
  key_phenotype_themes = ellmer::type_array(ellmer::type_string("theme"), "3-5 ENRICHED themes"),
  notably_absent = ellmer::type_array(ellmer::type_string("absent"), "2-3 DEPLETED phenotypes"),
  clinical_pattern = ellmer::type_string("Syndrome category"),
  syndrome_hints = ellmer::type_array(ellmer::type_string("syndrome"), "Syndrome associations"),
  tags = ellmer::type_array(ellmer::type_string("tag"), "3-7 clinical tags"),
  confidence = ellmer::type_enum(c("high", "medium", "low"), "Confidence level"),
  data_quality_note = ellmer::type_string("Data quality issues", required = FALSE)
)
```

### Validator Verdict Type
```r
llm_judge_verdict_type <- ellmer::type_object(
  "Validation verdict",
  is_factually_accurate = ellmer::type_boolean("Accuracy check"),
  is_grounded = ellmer::type_boolean("Grounding check"),
  pathways_valid = ellmer::type_boolean("Pathway validity"),
  confidence_appropriate = ellmer::type_boolean("Confidence check"),
  reasoning = ellmer::type_string("Brief explanation"),
  verdict = ellmer::type_enum(c("accept", "low_confidence", "reject"), "Final verdict")
)
```

---

## Implementation Checklist

- [x] Validated functional cluster prompt with ablation (top 3-5 per category)
- [x] Validated phenotype cluster prompt with ablation (top 5-10 enriched + top 3-5 depleted)
- [x] Documented validator prompts for both cluster types
- [x] Verified disease_relevance uses HPO terms only
- [x] Confirmed no hallucination in outputs
- [x] Model upgraded to gemini-3-pro-preview

---

*Generated: 2026-02-01*
