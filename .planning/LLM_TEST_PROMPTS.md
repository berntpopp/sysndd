# LLM Test Prompts - For Manual Testing

**Date:** 2026-02-01
**Purpose:** Test prompts with real API data before implementing

---

## FUNCTIONAL CLUSTER PROMPT (for genes + enrichment)

### Test Data: Functional Cluster 1 (536 genes)

**Sample Genes:** CYP26B1, RALA, DVL2, PPP1R3F, NFE2L3, GNA11, PPP2R5B, NGFR, NTN1, EFNB1, LZTR1, MAPK1, SOS2, SIX4, PROKR2, TSC2, PIK3R2, FGFR2, NOTCH1, PTPN11...

**Enrichment Data:**
```
### GO Biological Process
- Multicellular organism development (FDR: 4.52E-102, 382 genes)
- Anatomical structure morphogenesis (FDR: 1.47E-100, 265 genes)
- Anatomical structure development (FDR: 2.67E-98, 389 genes)
- System development (FDR: 6.34E-98, 356 genes)
- Developmental process (FDR: 4.63E-90, 392 genes)

### GO Cellular Component
- Anchoring junction (FDR: 1.35E-28, 96 genes)
- Nuclear chromatin (FDR: 1.02E-26, 105 genes)
- Cell junction (FDR: 4.36E-26, 151 genes)

### GO Molecular Function
- Protein binding (FDR: 8.24E-47, 363 genes)
- DNA-binding transcription factor activity (FDR: 9.19E-39, 122 genes)

### KEGG Pathways
- Pathways in cancer (FDR: 6.63E-41, 92 genes)
- PI3K-Akt signaling pathway (FDR: 2.62E-31, 67 genes)
- Ras signaling pathway (FDR: 3.54E-29, 54 genes)
- Axon guidance (FDR: 4.62E-28, 51 genes)

### HPO (Human Phenotype Ontology)
- Abnormal nervous system physiology (FDR: 1.08E-89, 297 genes)
- Neurodevelopmental abnormality (FDR: 1.08E-89, 260 genes)
- Intellectual disability (FDR: 8.76E-87, 221 genes)
```

### Proposed FUNCTIONAL CLUSTER Prompt

```
You are a genomics expert analyzing gene clusters associated with neurodevelopmental disorders.

## Task
Analyze this functional gene cluster and summarize its biological significance.

## Cluster Data
- **Cluster size:** 536 genes
- **Sample genes:** CYP26B1, RALA, DVL2, NGFR, NTN1, EFNB1, MAPK1, TSC2, FGFR2, NOTCH1, PTPN11...

## Functional Enrichment Results
The following terms are statistically enriched in this gene cluster:

### GO Biological Process
- Multicellular organism development (FDR: 4.52E-102, 382/536 genes)
- Anatomical structure morphogenesis (FDR: 1.47E-100, 265/536 genes)
- System development (FDR: 6.34E-98, 356/536 genes)

### KEGG Pathways
- Pathways in cancer (FDR: 6.63E-41, 92/536 genes)
- PI3K-Akt signaling pathway (FDR: 2.62E-31, 67/536 genes)
- Ras signaling pathway (FDR: 3.54E-29, 54/536 genes)

### HPO Phenotypes (associated diseases)
- Neurodevelopmental abnormality (FDR: 1.08E-89, 260/536 genes)
- Intellectual disability (FDR: 8.76E-87, 221/536 genes)

## Instructions
Based on the enrichment data above:

1. **Summary (2-3 sentences):** What biological functions unite these genes? Focus on the GO terms and pathways.

2. **Key biological themes (3-5):** List the main functional categories from the enrichment data.

3. **Pathways:** List ONLY pathways that appear in the KEGG section above. Do NOT invent pathway names.

4. **Disease relevance:** Based on the HPO terms, what types of disorders involve these genes?

5. **Tags (3-7):** Short keywords derived from the enrichment terms (e.g., "development", "signaling")

6. **Confidence:** High if strong enrichment (FDR < 1E-50), Medium if moderate, Low if weak.

IMPORTANT: Only mention terms that appear in the data above. Do not invent or generalize.
```

---

## PHENOTYPE CLUSTER PROMPT (for entities + phenotype patterns)

### Test Data: Phenotype Cluster 4 (420 entities)

This cluster groups disease-gene associations (entities) that share similar phenotype annotations.

**Phenotype Enrichment (v.test > 0 = ENRICHED, v.test < 0 = DEPLETED):**
```
ENRICHED phenotypes (more common in this cluster):
- Abnormality of the genitourinary system: v.test=+22.18 (p=5.52e-109)
- Abnormality of the kidney: v.test=+16.27 (p=1.54e-59)
- Abnormality of the skeletal system: v.test=+14.27 (p=3.57e-46)
- Abnormal facial shape: v.test=+14.19 (p=1.00e-45)
- Oral cleft: v.test=+13.51 (p=1.43e-41)
- Abnormality of the eye: v.test=+13.09 (p=3.65e-39)
- Abnormal heart morphology: v.test=+12.96 (p=2.00e-38)
- Abnormality of limbs: v.test=+12.83 (p=1.09e-37)
- Short stature: v.test=+9.36 (p=8.13e-21)
- Hearing impairment: v.test=+8.35 (p=6.95e-17)

DEPLETED phenotypes (less common in this cluster):
- Progressive: v.test=-9.53 (p=1.61e-21)
- Developmental regression: v.test=-7.13 (p=9.93e-13)
- Abnormality of the mitochondrion: v.test=-6.92 (p=4.67e-12)
- Seizures: v.test=-5.85 (p=4.87e-09)
- Abnormality of the nervous system: v.test=-5.70 (p=1.18e-08)
```

### Proposed PHENOTYPE CLUSTER Prompt

```
You are a clinical geneticist analyzing phenotype clusters from a neurodevelopmental disorder database.

## Task
Analyze this phenotype cluster and describe its clinical pattern.

## Important Context
- This cluster contains 420 DISEASE ENTITIES (gene-disease associations), NOT individual genes
- Entities were clustered based on their phenotype (clinical feature) annotations
- v.test score indicates enrichment:
  - POSITIVE v.test = phenotype is MORE COMMON in this cluster than average
  - NEGATIVE v.test = phenotype is LESS COMMON in this cluster than average
  - Larger |v.test| = stronger association

## Phenotype Data

### ENRICHED Phenotypes (overrepresented in this cluster)
| Phenotype | v.test | p-value |
|-----------|--------|---------|
| Abnormality of the genitourinary system | +22.18 | 5.52e-109 |
| Abnormality of the kidney | +16.27 | 1.54e-59 |
| Abnormality of the skeletal system | +14.27 | 3.57e-46 |
| Abnormal facial shape | +14.19 | 1.00e-45 |
| Oral cleft | +13.51 | 1.43e-41 |
| Abnormality of the eye | +13.09 | 3.65e-39 |
| Abnormal heart morphology | +12.96 | 2.00e-38 |
| Abnormality of limbs | +12.83 | 1.09e-37 |
| Short stature | +9.36 | 8.13e-21 |
| Hearing impairment | +8.35 | 6.95e-17 |

### DEPLETED Phenotypes (underrepresented in this cluster)
| Phenotype | v.test | p-value |
|-----------|--------|---------|
| Progressive | -9.53 | 1.61e-21 |
| Developmental regression | -7.13 | 9.93e-13 |
| Abnormality of the mitochondrion | -6.92 | 4.67e-12 |
| Seizures | -5.85 | 4.87e-09 |
| Abnormality of the nervous system | -5.70 | 1.18e-08 |

## Instructions
Based ONLY on the phenotype data above:

1. **Summary (2-3 sentences):** Describe the clinical phenotype pattern. What types of conditions are in this cluster? Note both enriched AND depleted phenotypes.

2. **Key phenotype themes (3-5):** The main clinical feature categories that are ENRICHED.

3. **Notably absent (2-3):** What phenotypes are significantly DEPLETED? This is clinically meaningful.

4. **Clinical pattern:** What syndrome category does this suggest? (e.g., "syndromic malformation disorders", "pure neurodevelopmental", "metabolic/degenerative")

5. **Syndrome hints:** Based on the phenotype combination (kidney + heart + facial + skeletal + limb anomalies), what known syndrome categories might this represent?

6. **Tags (3-7):** Short clinical keywords from the phenotypes (e.g., "cardiac", "renal", "skeletal")

CRITICAL:
- Only describe phenotypes from the data above
- Do NOT mention genes or molecular pathways - this is purely phenotype-based
- Both enriched AND depleted phenotypes are important for characterization
```

---

## Expected Outputs

### Expected Functional Cluster 1 Output
```json
{
  "summary": "This gene cluster is enriched for developmental and morphogenesis processes, with strong involvement in PI3K-Akt and Ras signaling pathways. The genes are predominantly associated with neurodevelopmental disorders including intellectual disability.",
  "key_themes": ["developmental processes", "morphogenesis", "signaling pathways", "transcriptional regulation"],
  "pathways": ["PI3K-Akt signaling pathway", "Ras signaling pathway", "Pathways in cancer"],
  "disease_relevance": "Strongly associated with neurodevelopmental abnormalities and intellectual disability",
  "tags": ["development", "morphogenesis", "signaling", "transcription", "ndd"],
  "confidence": "high"
}
```

### Expected Phenotype Cluster 4 Output
```json
{
  "summary": "This cluster represents congenital malformation syndromes with multi-organ involvement. Entities are strongly enriched for structural anomalies of the genitourinary system, kidney, skeleton, face, heart, and limbs. Notably, progressive and degenerative features are depleted, indicating these are static/non-progressive conditions.",
  "key_phenotype_themes": ["congenital malformations", "multi-organ involvement", "structural anomalies", "craniofacial features"],
  "notably_absent": ["progressive course", "neurodegeneration", "seizures"],
  "clinical_pattern": "syndromic congenital malformation disorders",
  "syndrome_hints": ["ciliopathies", "cohesinopathies", "CHARGE-like syndromes", "VACTERL-like associations"],
  "tags": ["malformation", "renal", "cardiac", "skeletal", "facial", "congenital"]
}
```

---

## How to Test

1. Copy the prompt above
2. Go to Google AI Studio or Gemini API
3. Use model: `gemini-3-pro-preview`
4. Set temperature: 0.2 (for consistency)
5. Compare output with expected results
6. Iterate on prompt if needed

---

*Generated: 2026-02-01*
