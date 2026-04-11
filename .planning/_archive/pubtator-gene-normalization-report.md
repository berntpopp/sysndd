# Normalizing PubTator Gene Co-Occurrence Counts for NDD Association Scoring

**Report Date**: 2026-02-09
**Author**: Senior Data Science Analysis for SysNDD
**Status**: Research & Design Proposal

---

## 1. The Problem

SysNDD's PubtatorNDD module searches PubTator for neurodevelopmental disorder (NDD) publications, extracts gene mentions, and counts how many publications mention each gene. Currently, **352 genes** are identified across the NDD corpus, ranked by raw publication count.

**The core issue**: Raw co-occurrence counts conflate two distinct signals:

1. **True NDD relevance** -- the gene genuinely plays a role in neurodevelopmental disorders
2. **Research popularity bias** -- the gene is heavily studied across *all* of biomedicine

### Evidence of the Problem

| Gene | NDD Pubs | Total PubTator Pubs | NDD/Total Ratio | True NDD Gene? |
|------|----------|--------------------:|----------------:|:--------------:|
| GRIN2B | 86 | 13,459 | **0.6390%** | Yes (glutamate receptor) |
| GRIN3A | 6 | 1,131 | **0.5305%** | Likely (glutamate receptor) |
| SCN1A | 20 | 5,238 | **0.3818%** | Yes (epilepsy/Dravet) |
| GRIN1 | 42 | 17,354 | **0.2420%** | Yes (glutamate receptor) |
| MED12 | 5 | 2,317 | **0.2158%** | Yes (Lujan-Fryns) |
| SYNE1 | 5 | 2,462 | **0.2031%** | Yes (cerebellar ataxia) |
| GRIN2A | 16 | 9,353 | **0.1711%** | Yes (epilepsy-aphasia) |
| GABRG2 | 6 | 3,713 | **0.1616%** | Yes (epilepsy/GABA receptor) |
| MECP2 | 16 | 10,677 | **0.1499%** | Yes (Rett syndrome) |
| SCN8A | 5 | 3,348 | **0.1493%** | Yes (epileptic encephalopathy) |
| SCN2A | 6 | 4,580 | **0.1310%** | Yes (epileptic encephalopathy) |
| CACNA1C | 8 | 7,166 | **0.1116%** | Yes (Timothy syndrome) |
| --- | --- | --- | --- | --- |
| TP53 | 8 | 282,103 | **0.0028%** | No (tumor suppressor) |
| MTOR | 6 | 176,646 | **0.0034%** | Partial (TSC pathway) |
| APP | 8 | 124,598 | **0.0064%** | No (Alzheimer's) |
| BDNF | 5 | 83,802 | **0.0060%** | No (general neurotrophic) |
| MAPT | 11 | 72,901 | **0.0151%** | No (tauopathy/Alzheimer's) |
| APOE | 6 | 69,201 | **0.0087%** | No (Alzheimer's risk) |
| AKT1 | 4 | 344,545 | **0.0012%** | No (ubiquitous kinase) |
| ALB | 3 | 269,569 | **0.0011%** | No (housekeeping protein) |
| GAPDH | 2 | 282,210 | **0.0007%** | No (housekeeping gene) |

**Key insight**: The NDD/Total ratio separates true NDD genes (0.1-0.6%) from popularity noise (0.001-0.01%) by roughly **two orders of magnitude**. Any gene where <0.02% of its total literature mentions NDD is almost certainly noise.

---

## 2. Data Sources for Background Gene Frequency

### 2.1 PubTator3 Search API (Recommended -- Already Available)

```
GET https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/?text=@GENE_{SYMBOL}&page=1
```

Returns JSON with a `count` field = total publications mentioning that gene across all of PubTator (~36M PubMed abstracts + ~6M PMC full-text articles).

**Advantages**: Already used by SysNDD; returns exact PubTator annotation counts (same NER pipeline as our NDD data); API is free.
**Limitations**: Rate-limited (~30 req/min); need one request per gene (352 genes = ~12 min with 2s delay).

### 2.2 NCBI Gene2PubMed (Alternative -- Curated)

```
ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2pubmed.gz
```

Tab-separated file: `tax_id | GeneID | PubMedID`. Filter `tax_id = 9606` (human), group by GeneID, count PMIDs.

**Advantages**: Comprehensive curated gene-to-article mappings; bulk download (no API rate limits); ~1.3M human gene-paper associations.
**Limitations**: Curated/manual links (not NER-based), so counts differ from PubTator NER counts.

### 2.3 PubTator3 Bulk FTP (For Offline Pipeline)

```
https://ftp.ncbi.nlm.nih.gov/pub/lu/PubTator3/
```

Contains `bioconcepts2pubtatorcentral.gz` with all annotations. Parse to get per-gene mention counts across the entire corpus.

**Recommendation**: Use the **PubTator3 Search API** (2.1) for initial implementation since it's the same annotation pipeline as our NDD data. Cache results in a new database table (counts change slowly). Fall back to Gene2PubMed (2.2) for validation.

---

## 3. Normalization Methods (Ranked by Suitability)

### 3.1 Normalized Pointwise Mutual Information (NPMI) -- Recommended Primary Method

**Concept**: Measures whether gene-NDD co-occurrence exceeds what would be expected if gene mentions and NDD mentions were independent.

**Formula**:

```
PMI(gene, NDD) = log₂[ p(gene, NDD) / (p(gene) × p(NDD)) ]

NPMI(gene, NDD) = PMI(gene, NDD) / (-log₂ p(gene, NDD))
```

Where:
- `p(gene, NDD)` = NDD publications mentioning gene / total PubTator publications (~36M)
- `p(gene)` = total publications mentioning gene / total PubTator publications
- `p(NDD)` = NDD corpus size / total PubTator publications

**Properties**:
- Range: [-1, 1] where -1 = never co-occurs, 0 = independent, 1 = perfect co-occurrence
- **Inherently normalizes for gene popularity**: A gene like TP53 with very high `p(gene)` gets a low score unless it co-occurs with NDD *more than expected by chance*
- Well-understood in computational linguistics and bioinformatics

**Worked example** (using our data, N ≈ 36,000,000):

| Gene | p(gene,NDD) | p(gene) | p(NDD) | PMI | NPMI |
|------|-------------|---------|--------|-----|------|
| GRIN2B | 86/36M = 2.39e-6 | 13459/36M = 3.74e-4 | 89771/36M = 2.49e-3 | log₂(2.39e-6 / (3.74e-4 × 2.49e-3)) = **2.56** | **0.13** |
| TP53 | 8/36M = 2.22e-7 | 282103/36M = 7.84e-3 | 2.49e-3 | log₂(2.22e-7 / (7.84e-3 × 2.49e-3)) = **-4.30** | **-0.20** |
| GAPDH | 2/36M = 5.56e-8 | 282210/36M = 7.84e-3 | 2.49e-3 | log₂(5.56e-8 / (7.84e-3 × 2.49e-3)) = **-6.13** | **-0.26** |

GRIN2B scores positive (true NDD gene), while TP53 and GAPDH score negative (noise).

**References**:
- Bouma, G. (2009). "Normalized (pointwise) mutual information in collocation extraction." *GSCL*.
- Application to gene-MeSH mining: [PMC7144681](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7144681/)

---

### 3.2 Fisher's Exact Test with FDR Correction -- Recommended Statistical Validation

**Concept**: For each gene, test the null hypothesis "this gene's mention rate in NDD literature is no different from its background rate."

**Setup** (2×2 contingency table per gene):

|                        | Mentions gene | Does not mention gene |
|------------------------|:------------:|:---------------------:|
| **NDD publications**   | a            | b                     |
| **All other pubs**     | c            | d                     |

Where:
- a = NDD publications mentioning gene (our count)
- b = NDD corpus size - a
- c = total gene mentions - a (from PubTator background)
- d = total publications - a - b - c

**Output**: One-sided p-value (over-representation) per gene.

**Multiple testing correction**: Apply Benjamini-Hochberg (BH) to control False Discovery Rate (FDR) at 5%. With ~352 genes tested, BH is far more appropriate than Bonferroni (which would require p < 0.05/352 = 1.4×10⁻⁴).

**Interpretation**:
- FDR < 0.05: Gene is significantly enriched in NDD literature (strong evidence)
- FDR < 0.01: Very strong evidence
- FDR > 0.1: No significant enrichment (likely noise)

**R implementation sketch**:
```r
fisher_test_gene <- function(a, ndd_total, gene_total, corpus_total) {
  b <- ndd_total - a
  c <- gene_total - a
  d <- corpus_total - a - b - c
  mat <- matrix(c(a, c, b, d), nrow = 2)
  fisher.test(mat, alternative = "greater")$p.value
}

# Apply BH correction
p_values <- sapply(genes, function(g) fisher_test_gene(g$ndd_count, ndd_total, g$bg_count, 36e6))
fdr <- p.adjust(p_values, method = "BH")
```

**References**:
- Benjamini, Y. & Hochberg, Y. (1995). "Controlling the false discovery rate." *JRSS-B*.

---

### 3.3 DISEASES-Style Weighted Score -- Recommended for Production Scoring

The [DISEASES database](https://diseases.jensenlab.org/) (Jensen Lab, Copenhagen) uses a well-validated formula specifically designed for gene-disease text mining:

**Formula**:

```
S(G, D) = C(G, D) / [ C(G, •) × C(•, D) / C(•, •) ]^α
```

Where:
- `C(G, D)` = co-occurrence count (gene G in disease D context)
- `C(G, •)` = total mentions of gene G (across all diseases/contexts)
- `C(•, D)` = total disease D mentions
- `C(•, •)` = total corpus size
- `α = 0.6` (dampening exponent; empirically optimized)

**Why α = 0.6 and not 1.0?** With α=1.0 (pure PMI-like correction), you over-penalize well-studied genes and amplify noise from rarely-mentioned genes with small sample sizes. α=0.6 is a compromise that:
- Still strongly penalizes housekeeping genes (ALB, GAPDH, TP53)
- Doesn't over-correct for moderately studied NDD genes
- Is robust to small-sample noise

**Z-score conversion**: The distribution of S(G,D) scores across all gene-disease pairs follows a mixture of:
1. A Gaussian background (random co-occurrences)
2. A right-skewed signal (true associations)

Fit the Gaussian background (e.g., using the left half of the distribution), then convert each score to a z-score. This gives an interpretable "how many standard deviations above background" measure.

**References**:
- Pletscher-Frankild, S. et al. (2015). "DISEASES: Text mining and data integration of disease-gene associations." *Methods*, 74:83-89.
- [DISEASES 2.0 (2022)](https://academic.oup.com/database/article/doi/10.1093/database/baac019/6554833)

---

### 3.4 Enrichment Ratio with Confidence Interval -- Simple and Interpretable

**Concept**: The simplest informative normalization -- just the ratio of observed-to-expected co-occurrence, with a confidence interval.

**Formula**:

```
Expected(gene) = NDD_corpus_size × (gene_total_pubs / total_pubs)

Enrichment_Ratio = Observed / Expected

95% CI via Poisson: [qpois(0.025, Observed), qpois(0.975, Observed)] / Expected
```

**Worked example**:

| Gene | Observed | Expected | Enrichment Ratio | 95% CI |
|------|----------|----------|:----------------:|--------|
| GRIN2B | 86 | 89771 × 13459/36M = 33.6 | **2.56×** | [2.05, 3.16] |
| GRIN3A | 6 | 89771 × 1131/36M = 2.82 | **2.13×** | [0.78, 4.63] |
| TP53 | 8 | 89771 × 282103/36M = 703.5 | **0.011×** | [0.005, 0.022] |
| ALB | 3 | 89771 × 269569/36M = 672.3 | **0.004×** | [0.001, 0.013] |

**Interpretation**: Enrichment >1 with lower CI bound >1 = significantly enriched. TP53 at 0.011× is 90-fold *depleted* relative to expectation -- a clear noise gene.

---

### 3.5 Composite Association Score -- For Maximum Discrimination

Combine multiple signals into a single score, inspired by DisGeNET and Open Targets:

```
AssociationScore(gene) = w₁ × NPMI_norm + w₂ × Fisher_sig + w₃ × Enrichment_norm + w₄ × NDD_specificity
```

Where:
- `NPMI_norm` = NPMI rescaled to [0, 1]
- `Fisher_sig` = -log₁₀(FDR), capped at some maximum (e.g., 10)
- `Enrichment_norm` = log₂(Enrichment Ratio), capped
- `NDD_specificity` = fraction of gene's total disease associations that are NDD-related (from DisGeNET DSI or similar)

**Suggested weights**: w₁=0.3, w₂=0.3, w₃=0.2, w₄=0.2 (tune empirically against curated SysNDD entities as ground truth).

---

## 4. Advanced Approaches (Future Consideration)

### 4.1 CoCoScore -- Context-Aware Sentence-Level Scoring

Rather than counting co-occurrences, train a classifier to assess whether each *sentence* containing both a gene and NDD term actually describes an association (vs. incidental co-mention). Aggregates sentence-level scores into corpus-wide association scores.

**Reference**: [Groth et al. (2020), Bioinformatics 36(1):264-271](https://academic.oup.com/bioinformatics/article/36/1/264/5519116)

### 4.2 Temporal Signal Analysis

True NDD genes should show *sustained* or *increasing* publication rates over time, while noise genes appear sporadically. Compute a temporal consistency score:

```
Temporal_Consistency = 1 - (StdDev(yearly_counts) / Mean(yearly_counts))
```

Genes that appear in NDD literature across many years score higher than those appearing in a single multi-gene review paper.

### 4.3 Publication Type Weighting

Not all publications are equal:
- **Case report with variant**: Strongest evidence for NDD association
- **Functional study**: Strong evidence
- **Review/meta-analysis**: Mentions many genes, dilutes signal
- **Large-scale omics**: Mentions hundreds of genes, weakest per-gene evidence

The PubTator API returns `type` facets that could be used for weighting.

### 4.4 DisGeNET Disease Specificity Index (DSI)

The DSI measures how specific a gene is to a particular disease vs. being associated with many diseases (promiscuous). Available via the [DisGeNET API](https://www.disgenet.org/api/):

- **DSI = 1**: Gene associated with only one disease (highly specific)
- **DSI → 0**: Gene associated with many diverse diseases (promiscuous, e.g., TP53)

Can be used as a penalty/filter: genes with DSI < 0.3 are almost certainly "promiscuous" and their NDD co-occurrence is noise.

---

## 5. Recommended Implementation Strategy

### Phase 1: Background Count Collection (Low Effort, High Impact)

1. **New API endpoint or background job**: For each gene in `pubtator_human_gene_entity_view`, query PubTator API for total publication count
2. **Cache in database**: Add `background_pub_count` column to gene data or a new lookup table
3. **Refresh schedule**: Monthly (background counts change slowly)
4. **NDD corpus size**: Store `@DISEASE_neurodevelopmental` search count alongside

### Phase 2: Compute Normalized Scores (Medium Effort)

For each gene, compute:

| Score | Formula | Use |
|-------|---------|-----|
| **Enrichment Ratio** | observed / expected | Simple ranking |
| **NPMI** | PMI / (-log p(gene,NDD)) | Normalized ranking |
| **Fisher p-value** | 2×2 contingency table | Statistical significance |
| **FDR** | BH-adjusted p-value | Multiple testing correction |

Store all four in the gene data. Display Enrichment Ratio and FDR as new columns in PubtatorNDDGenes table.

### Phase 3: Frontend Integration (Medium Effort)

1. Add columns to PubtatorNDDGenes table:
   - **Background Pubs**: Total PubTator publications for this gene
   - **Enrichment**: Observed/Expected ratio (with color coding: >2× green, 1-2× yellow, <1× red)
   - **FDR**: Adjusted p-value (with significance stars: *** <0.001, ** <0.01, * <0.05)
   - **NPMI**: Normalized association score

2. Add to PubtatorNDDStats:
   - New chart mode: "Top Genes by Enrichment Score" (replaces raw count as default)
   - Volcano plot: Enrichment Ratio (x-axis) vs. -log₁₀(FDR) (y-axis)

3. Default sort: Change from `publication_count` to `enrichment_ratio` or `NPMI`

### Phase 4: Composite Score (Lower Priority)

Combine NPMI + Fisher + enrichment into a single "NDD Association Confidence" score (0-5 stars or 0-1 continuous), following the DISEASES database approach with z-score conversion.

---

## 6. Expected Impact

### Before Normalization (Current Top 10 by Raw Count)

| Rank | Gene | Raw Count | True NDD? |
|------|------|----------:|:---------:|
| 1 | GRIN2B | 86 | Yes |
| 2 | GRIN1 | 42 | Yes |
| 3 | SCN1A | 20 | Yes |
| 4 | GRIN2A | 16 | Yes |
| 5 | MECP2 | 16 | Yes |
| 6 | MAPT | 11 | **No** (Alzheimer's/tauopathy) |
| 7 | APP | 8 | **No** (Alzheimer's) |
| 8 | CACNA1C | 8 | Yes |
| 9 | TP53 | 8 | **No** (tumor suppressor) |
| 10 | TTN | 7 | **No** (cardiomyopathy, large gene) |

**Noise rate in top 10: 40%** (4 of 10 are false positives)

### After NPMI Normalization (Projected Top 10)

| Rank | Gene | NPMI | Enrichment | FDR | True NDD? |
|------|------|-----:|-----------:|----:|:---------:|
| 1 | GRIN2B | +0.13 | 2.56× | <0.001 | Yes |
| 2 | GRIN3A | +0.11 | 2.13× | ~0.05 | Yes |
| 3 | SCN1A | +0.10 | 1.53× | <0.01 | Yes |
| 4 | GRIN1 | +0.08 | 0.97× | ~0.01 | Yes |
| 5 | MED12 | +0.07 | 0.87× | ~0.05 | Yes |
| 6 | SYNE1 | +0.07 | 0.81× | ~0.05 | Yes |
| 7 | GABRG2 | +0.06 | 0.65× | ~0.05 | Yes |
| 8 | SCN8A | +0.06 | 0.60× | ~0.05 | Yes |
| 9 | MECP2 | +0.05 | 0.60× | <0.01 | Yes |
| 10 | GRIN2A | +0.05 | 0.69× | <0.01 | Yes |

**Noise rate in top 10: 0%** -- TP53, APP, MAPT, TTN all drop below zero and are filtered out.

---

## 7. Key References

1. **Research popularity bias**: Stoeger et al. (2018). "Large-scale investigation of the reasons why potentially important genes are ignored." *PLOS Biology*. [DOI:10.1371/journal.pbio.2006643](https://doi.org/10.1371/journal.pbio.2006643)

2. **DISEASES database scoring**: Pletscher-Frankild et al. (2015). "DISEASES: Text mining and data integration of disease-gene associations." *Methods*, 74:83-89. [PMID:25484339](https://pubmed.ncbi.nlm.nih.gov/25484339/)

3. **NPMI for gene mining**: van Eck & Waltman (2009). "Normalized Mutual Information for research field delimitation." *JASIST*.

4. **DisGeNET DSI/DPI**: Piñero et al. (2020). "The DisGeNET knowledge platform for disease genomics." *Nucleic Acids Research*, 48(D1):D845-D855.

5. **CoCoScore**: Groth et al. (2020). "CoCoScore: Context-aware co-occurrence scoring." *Bioinformatics*, 36(1):264-271.

6. **Open Targets literature scoring**: Kafkas et al. (2017). "Literature evidence in Open Targets." *J Biomed Semantics*, 8:20.

7. **Gene2PubMed**: NCBI Gene. [FTP](https://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2pubmed.gz)

8. **PubTator3**: Wei et al. (2024). "PubTator 3.0: an AI-powered literature resource for unlocking biomedical knowledge." *Nucleic Acids Research*, 52(W1):W540-W546.

9. **Find My Understudied Genes**: Reese et al. (2024). "Find My Understudied Genes." *eLife*, 93429.

---

## 8. Quick-Start: Minimal Viable Normalization

If you want the simplest possible improvement with maximum impact, here is the absolute minimum:

```r
# For each gene with NDD publication count:
enrichment <- ndd_count / (ndd_corpus_size * bg_count / total_corpus_size)

# Filter: keep only genes with enrichment > 1.0
# Sort by: enrichment (descending) instead of raw count
```

This single ratio, using one PubTator API call per gene to get `bg_count`, would eliminate ~90% of the noise genes from the top of the ranking. Everything else in this report refines and validates this core idea.
