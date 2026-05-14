# ClinVar Card Rich Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the `/Genes/:symbol` ClinVar summary card with dense ACMG chips and class-by-consequence popovers while preserving the lightweight `summary=true` data path.

**Architecture:** Add a pure R summary helper for gnomAD ClinVar variants and call it only from the existing `summary=true` branch. Extend the TypeScript summary shape and update `GeneClinVarCard.vue` to render compact button chips with Bootstrap Vue popovers. Keep `useGeneClinVar()` and the full ClinVar endpoint unchanged for genomic visualizations.

**Tech Stack:** R/Plumber API with `testthat`, Vue 3 `<script setup>` with TypeScript, Bootstrap Vue Next, Vitest, MSW.

---

### Task 1: API ClinVar Summary Helper

**Files:**
- Modify: `api/functions/external-proxy-gnomad.R`
- Create: `api/tests/testthat/test-unit-gnomad-clinvar-summary.R`

- [ ] **Step 1: Write failing API helper tests**

Create `api/tests/testthat/test-unit-gnomad-clinvar-summary.R` with tests for `summarise_gnomad_clinvar_variants()`. Fixture variants should include `Pathogenic`, `Pathogenic/Likely pathogenic`, `Benign/Likely benign`, `Conflicting classifications of pathogenicity`, missense, frameshift, stop-gained, splice, in-frame, intronic, and synonymous consequences. Assert existing five counts, normalized consequence counts, per-class breakdowns, `other_classifications`, and review-star/in-gnomAD counts.

- [ ] **Step 2: Run helper tests red**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"`

Expected: failure because `summarise_gnomad_clinvar_variants()` does not exist.

- [ ] **Step 3: Implement pure helper**

Add exported helper functions to `api/functions/external-proxy-gnomad.R`:

- `normalize_clinvar_classification()`
- `normalize_clinvar_consequence()`
- `summarise_gnomad_clinvar_variants(variants)`

The implementation must be linear over `variants`, return the old `counts` field plus `consequence_counts`, `class_breakdowns`, `quality_counts`, and `other_classifications`, and must not perform network or database work.

- [ ] **Step 4: Run helper tests green**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"`

Expected: all tests pass.

### Task 2: API Endpoint Summary Branch

**Files:**
- Modify: `api/endpoints/external_endpoints.R`

- [ ] **Step 1: Replace inline summary counting**

In the `summary=true` branch for `gnomad/variants/<symbol>`, replace the inline `classify()`/`vapply()` block with `summary_payload <- summarise_gnomad_clinvar_variants(variants)`, then return `source`, `gene_symbol`, `gene_id`, `variant_count`, `summary = TRUE`, and the helper fields.

- [ ] **Step 2: Run endpoint-adjacent tests**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-external-proxy-endpoints.R')"`

Expected: pass. This should verify external proxy path/auth invariants still load.

### Task 3: Frontend Types And Composable

**Files:**
- Modify: `app/src/composables/useGeneClinVarCounts.ts`
- Modify: `app/src/composables/__tests__/useGeneClinVarCounts.spec.ts`

- [ ] **Step 1: Write failing composable test**

Extend the existing MSW summary response in `useGeneClinVarCounts.spec.ts` with `consequence_counts`, `class_breakdowns`, and `quality_counts`. Assert the returned hook data exposes `class_breakdowns.pathogenic.consequences[0].key`.

- [ ] **Step 2: Run composable test red**

Run: `cd app && npx vitest run src/composables/__tests__/useGeneClinVarCounts.spec.ts`

Expected: TypeScript/Vitest failure because the richer fields are not typed yet.

- [ ] **Step 3: Add summary interfaces**

Extend `useGeneClinVarCounts.ts` with `ClinVarConsequenceCount`, `ClinVarClassBreakdown`, `ClinVarQualityCounts`, and optional `other_classifications`. Keep existing `counts` and `variant_count` fields unchanged.

- [ ] **Step 4: Run composable test green**

Run: `cd app && npx vitest run src/composables/__tests__/useGeneClinVarCounts.spec.ts`

Expected: pass.

### Task 4: Dense ClinVar Card UI

**Files:**
- Modify: `app/src/components/gene/GeneClinVarCard.vue`
- Modify: `app/src/components/gene/GeneClinVarCard.spec.ts`

- [ ] **Step 1: Write failing card tests**

Add tests that mount the card with rich summary props and assert:

- short chips `P 2`, `LP 1`, and `VUS 1` render;
- a chip has an accessible label containing the visible text and full class name;
- clicking a chip reveals consequence breakdown text such as `LoF` and `Missense`;
- count-only props still render the old class counts in compact chip form.

- [ ] **Step 2: Run card tests red**

Run: `cd app && npx vitest run src/components/gene/GeneClinVarCard.spec.ts`

Expected: fail because compact chips/popovers are not implemented.

- [ ] **Step 3: Implement card UI**

Update `GeneClinVarCard.vue` to:

- import and use `BPopover`;
- derive chip models from `counts` plus optional `class_breakdowns`;
- render dense button chips with short labels;
- open one manual popover at a time via click, Enter, or Space;
- render consequence rows with counts and percentages;
- keep loading, empty, error, retry, and ClinVar link behavior intact;
- preserve fallback behavior when only `counts` is available.

- [ ] **Step 4: Run card tests green**

Run: `cd app && npx vitest run src/components/gene/GeneClinVarCard.spec.ts`

Expected: pass.

### Task 5: Integration, Performance, And Browser Verification

**Files:**
- Modify only if verification finds a defect in files from Tasks 1-4.

- [ ] **Step 1: Run focused frontend tests**

Run:

```bash
cd app && npx vitest run src/components/gene/GeneClinVarCard.spec.ts src/composables/__tests__/useGeneClinVarCounts.spec.ts src/views/pages/__tests__/GeneView.spec.ts
```

Expected: pass.

- [ ] **Step 2: Run type-check and lint**

Run:

```bash
cd app && npm run type-check
cd app && npm run lint
```

Expected: type-check passes; lint exits 0. Existing unrelated warnings may remain.

- [ ] **Step 3: Run API helper test**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-clinvar-summary.R')"
```

Expected: pass.

- [ ] **Step 4: Check live summary payload size and page behavior**

If the local stack is running, run:

```bash
curl -sS 'http://localhost/api/external/gnomad/variants/ARID1B?summary=true' | wc -c
```

Expected: under `5000` bytes.

Use Playwright against `http://localhost/Genes/ARID1B` to confirm:

- ClinVar card does not horizontally overflow;
- the card remains comparable in height to Model Organisms;
- a ClinVar chip opens a visible breakdown popover.

- [ ] **Step 5: Commit implementation**

Commit all implementation and test files with message:

```bash
git commit -m "feat clinvar rich summary card"
```

## Plan Self-Review

- Spec coverage: covers API helper, endpoint branch, composable type, card UI, tests, performance, and browser verification.
- Placeholder scan: no unfinished implementation placeholders remain.
- Type consistency: summary field names match the committed spec: `consequence_counts`, `class_breakdowns`, `quality_counts`, `other_classifications`.
