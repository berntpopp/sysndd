# ClinVar Condition & Phenotype Association Filtering — Implementation Plan

- **Feature:** ClinVar Disease Association Display & Filtering in Genomic Visualizations
- **Date:** 2026-09-07
- **Spec:** `.planning/superpowers/specs/2026-09-07-clinvar-condition-filtering-design.md`

---

## Proposed Changes

### Backend (R / Plumber API)

#### 1. `api/functions/external-proxy-clinvar-traits.R` (New)
- Implement `enrich_variants_with_clinvar_traits(variants)`
- Extract `clinvar_variation_id` list
- Chunk into $\le 400$ IDs
- Call NCBI ClinVar E-utilities `esummary.fcgi` using `external_proxy_budget("ncbi_clinvar")`
- Parse `germline_classification.trait_set` and map back to variants:
  - `conditions`: character vector of trait names
  - `mondo_ids`: character vector of MONDO CURIEs
  - `omim_ids`: character vector of OMIM IDs
- Wrap in `tryCatch` fail-open: returns original variants if NCBI is unavailable.

#### 2. `api/bootstrap/load_modules.R`
- Register `functions/external-proxy-clinvar-traits.R` right after `functions/external-proxy-gnomad-clinvar.R`.

#### 3. `api/endpoints/external_endpoints.R`
- In `GET /api/external/gnomad/variants/<symbol>`:
  - Enrich variants list with traits prior to caching/returning.

#### 4. `api/tests/testthat/test-unit-clinvar-traits-enrichment.R` (New)
- Unit tests for parsing, chunking, and mock responses.

---

### Frontend (Vue 3 + TypeScript)

#### 5. `app/src/types/external.ts` & `app/src/types/protein.ts`
- Extend `ClinVarVariant` with `conditions?`, `mondo_ids?`, `omim_ids?`.
- Extend `ProcessedVariant` with `conditions`, `mondoIds`, `omimIds`.
- Extend `LollipopFilterState` with `selectedConditions?: string[] | null`.

#### 6. `app/src/components/gene/genomicVisualizationData.ts`
- Map `conditions`, `mondo_ids`, `omim_ids` from `ClinVarVariant` into `ProcessedVariant` and `GenomicVariant`.

#### 7. `app/src/components/gene/proteinLollipopControls.ts`
- Helpers for counting variants per condition (`countByCondition()`).
- Helper for checking condition visibility (`isConditionVisible()`).
- "Only" / "All" condition filter handlers.

#### 8. `app/src/components/gene/ProteinLollipopControlsPanel.vue`
- Add **Row 3: Condition Filter**:
  - Filter chips for top conditions with counts.
  - "only" / "all" condition actions.
  - Optional search or "Match Entity" button.

#### 9. `app/src/composables/d3-lollipop/lollipop-helpers.ts` & `lollipop-render.ts`
- Incorporate `isConditionVisible()` into variant marker visibility check.

#### 10. `app/src/components/gene/VariantTooltip.vue` & `VariantPanel.vue`
- Display associated condition(s) on variant hover and in the variant list.

---

## Verification Plan

### Automated Tests
```bash
# Frontend type check and unit tests
cd app && npm run type-check
cd app && npm run test:unit src/components/gene/

# Code quality audit
make code-quality-audit
```

### Manual Verification
1. Inspect *PTPN11* on the Gene page (`/Genes/PTPN11`):
   - Check that the lollipop plot renders with Row 3 condition filters.
   - Click "only" on "Noonan syndrome 1": verify LoF variants disappear and only Noonan missense variants remain.
   - Hover over a variant lollipop marker: verify condition names appear in the tooltip.
