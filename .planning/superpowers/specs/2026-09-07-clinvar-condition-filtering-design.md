# ClinVar Condition & Phenotype Association Filtering — Design Spec

- **Feature:** ClinVar Disease Association Display & Filtering in Genomic Visualizations
- **Date:** 2026-09-07
- **Scope:** `api/functions/`, `api/endpoints/`, `app/src/types/`, `app/src/components/gene/`, `app/src/composables/d3-lollipop/`
- **Status:** Approved for Implementation

---

## 1. Problem & Clinical Context

In SysNDD, the genomic visualizations on gene and entity detail pages (`GenomicVisualizationTabs.vue`: Protein View lollipop, Gene Structure plot, and 3D Structure viewer) currently retrieve ClinVar variants via gnomAD's GraphQL proxy (`api/functions/external-proxy-gnomad.R`). 

gnomAD's `gene.clinvar_variants` projection is **strictly locus-based**: it returns every ClinVar variant intersecting the gene coordinates, regardless of phenotype, inheritance mode, or clinical indication.

### 1.1 The Pleiotropy Problem in Clinical Research
For genes with multiple allelic disorders, locus-level variant retrieval creates severe scientific distortion. 

Taking ***PTPN11* (SHP2)** as the prime example:
- **Noonan syndrome (NDD):** Caused by heterozygous gain-of-function (GOF) missense variants. Characterized by facial dysmorphism, congenital heart disease, short stature, and neurodevelopmental manifestations (developmental delay, executive dysfunction, learning disabilities, ASD).
- **LEOPARD syndrome (NSML):** Caused by catalytically impaired / dominant-negative missense variants.
- **Metachondromatosis (OMIM 156250, Non-NDD):** Caused by heterozygous loss-of-function (LoF) nonsense, frameshift, or splice variants. Characterized by enchondromas and osteochondromas with **completely normal cognitive development**.
- **Somatic hematologic malignancy (JMML):** Somatic GOF variants.

In SysNDD, 17 of the 195 Pathogenic/Likely Pathogenic variants in *PTPN11* belong exclusively to Metachondromatosis. When an NDD researcher examines *PTPN11* or downloads its variants from SysNDD, non-NDD skeletal variants and cancer-only submissions contaminate the dataset.

### 1.2 User Need
Users need:
1. **Visibility:** Display the associated condition(s) / phenotype(s) for each ClinVar variant (in tooltips, variant panels, and tables).
2. **Filtering:** An interactive UI control in the Protein View (and Gene Structure / 3D views) to filter variants by reported conditions (e.g. isolate "Noonan syndrome", or exclude "Metachondromatosis").
3. **Entity Match Shortcut:** A 1-click filter preset on Entity pages to automatically match the active disease entity.

---

## 2. Architectural Analysis & Data Source Strategy

### 2.1 Upstream Capabilities & Constraints

1. **Current Upstream (gnomAD GraphQL):**
   - Querying `gene(symbol).clinvar_variants` returns basic fields (`variant_id`, `pos`, `hgvsc`, `hgvsp`, `major_consequence`, `clinical_significance`, `review_status`, `gold_stars`).
   - The GraphQL schema on `ClinVarVariant` **does not include conditions**.
   - Querying single variants (`clinvar_variant(id)`) requires $N$ round-trips ($N=684$ for *PTPN11*), violating rate limits and the 15s request ceiling.
2. **NCBI ClinVar E-utilities (`esummary.fcgi?db=clinvar`):**
   - SysNDD already maintains an NCBI E-utilities infrastructure with `NCBI_API_KEY` in `api/functions/publication-functions.R`.
   - `esummary` supports comma-separated batching of up to **500 variation IDs** in a single request.
   - For 500 variants, execution time is ~1.0–1.5s.
   - Response includes `result[uid].germline_classification.trait_set` containing `trait_name` and ontology Xrefs (`MONDO`, `OMIM`, `MedGen`, `Orphanet`).
   - By enriching the variants list with NCBI ClinVar traits and caching with `memoise_external_success_only(..., cache = cache_dynamic)` (7-day TTL), subsequent requests are served in **0 ms**.
   - If NCBI E-utilities fails or times out, the enricher gracefully falls back to returning the un-enriched variants (fail-open, no 500/503 errors).

---

## 3. Detailed Technical Design

### 3.1 Backend API Layer

#### 3.1.1 Helper: `api/functions/external-proxy-clinvar-traits.R`
A dedicated, modular helper (kept under 600 lines) that:
1. Extracts unique numeric ClinVar variation IDs from `result$variants`.
2. Batches IDs into chunks of $\le 400$ to avoid URL length or server-side limits.
3. Queries NCBI E-utilities with `external_proxy_budget("ncbi_clinvar", default_timeout = 5, default_max = 8, default_tries = 2L)`.
4. Parses JSON `result[uid].germline_classification.trait_set` and extracts:
   - `conditions`: Array of distinct `trait_name` strings.
   - `mondo_ids`: Array of MONDO CURIEs (e.g. `MONDO:0008104`).
   - `omim_ids`: Array of OMIM numbers (e.g. `163950`).
5. Injects `conditions`, `mondo_ids`, and `omim_ids` into each variant object in `variants`.
6. Enclosed in `tryCatch`: on any upstream error, logs a warning and returns the original variants list with empty condition arrays.

#### 3.1.2 Endpoint Integration: `api/endpoints/external_endpoints.R`
In `GET /api/external/gnomad/variants/<symbol>`:
- When `summary == FALSE`, calls `enrich_variants_with_clinvar_traits(result$variants)` before returning.
- When `summary == TRUE`, incorporates top reported conditions into `summary_payload$condition_counts`.

---

### 3.2 Frontend Data Model & Types

#### 3.2.1 Wire Types (`app/src/types/external.ts`)
```typescript
export interface ClinVarVariant {
  clinical_significance: string;
  clinvar_variation_id: string;
  gold_stars: number;
  hgvsc: string | null;
  hgvsp: string | null;
  in_gnomad: boolean;
  major_consequence: string;
  pos: number;
  review_status: string;
  variant_id: string;
  conditions?: string[];
  mondo_ids?: string[];
  omim_ids?: string[];
}
```

#### 3.2.2 Protein Types (`app/src/types/protein.ts`)
```typescript
export interface ProcessedVariant {
  proteinPosition: number;
  proteinHGVS: string;
  codingHGVS: string;
  classification: PathogenicityClass;
  goldStars: number;
  reviewStatus: string;
  clinvarId: string;
  variantId: string;
  majorConsequence: string;
  isSpliceVariant: boolean;
  inGnomad: boolean;
  conditions: string[];
  mondoIds: string[];
  omimIds: string[];
}

export interface LollipopFilterState {
  pathogenic: boolean;
  likelyPathogenic: boolean;
  vus: boolean;
  likelyBenign: boolean;
  benign: boolean;
  conflicting?: boolean;
  other?: boolean;
  coloringMode: ColoringMode;
  effectFilters?: Record<EffectType, boolean>;
  /** Selected condition names to display (empty or null = show all) */
  selectedConditions?: string[] | null;
}
```

#### 3.2.3 Data Transformer (`app/src/components/gene/genomicVisualizationData.ts`)
Update `buildProteinPlotData()` and `buildGenomicVariants()` to map `conditions`, `mondo_ids`, and `omim_ids`.

---

### 3.3 UI / UX Design (Impeccable & Visual Guide Aligned)

#### 3.3.1 Visual Hierarchy in `ProteinLollipopControlsPanel.vue`
Following `documentation/10-visual-design-guide.md`:
- **Controls Row:** Coloring toggle, Domain legend, SVG/PNG export buttons.
- **Row 1 (ACMG Pathogenicity):** P, LP, CONF, VUS, LB, B, Other filter chips with "only" / "all".
- **Row 2 (Variant Effect):** Missense, LoF, Splice, In-frame, Synonymous filter chips with "only" / "all".
- **Row 3 (Associated Conditions):**
  - **Quick Preset Bar:**
    - `[All conditions]`
    - `[★ Match Entity Disease]` (when mounted inside an Entity view, or matching top NDD term)
  - **Condition Chips:**
    - Top conditions by variant count (e.g. `Noonan syndrome 1 (412)`, `LEOPARD syndrome 1 (54)`, `Metachondromatosis (14)`).
    - Compact toggles with count badge, "only" shortcut button, and smooth hover state.
    - If $>6$ conditions exist, an expandable/scrollable drawer with a search box `Search conditions...`.

#### 3.3.2 Tooltip in `VariantTooltip.vue`
Add a row showing the associated condition(s):
```html
<div v-if="data.conditions && data.conditions.length > 0" class="tooltip-row condition-row">
  <span class="condition-label">Condition:</span>
  <span class="condition-text">{{ data.conditions.join(', ') }}</span>
</div>
```

#### 3.3.3 Variant Sidebar in `VariantPanel.vue`
Display condition chips on list items and allow searching by condition name.

---

## 4. Verification & Testing Plan

1. **R Backend Unit Tests:**
   - `api/tests/testthat/test-unit-clinvar-traits-enrichment.R`: Test batching, mock NCBI E-utilities responses, test missing/empty traits, test error fallback.
2. **Frontend Unit Tests:**
   - `app/src/components/gene/proteinLollipopControls.spec.ts`: Test condition filtering logic, "only"/"all" condition actions.
   - `app/src/components/gene/ProteinLollipopControlsPanel.spec.ts`: Test rendering of condition chips and event emits.
   - `app/src/components/gene/VariantTooltip.spec.ts`: Verify condition display in tooltips.
3. **Full System Verification:**
   - `make code-quality-audit` (ratchet & line limit check)
   - `cd app && npm run type-check && npm run test:unit`
