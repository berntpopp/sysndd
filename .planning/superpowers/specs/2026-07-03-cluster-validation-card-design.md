# Cluster Validation Card — design

**Date:** 2026-07-03
**Status:** Approved (design)
**Depends on:** the analysis-snapshot validation surface added in #457–459 / PR #482 (`meta.snapshot.validation`, `validation_hash`, `db_release`, and per-cluster `jaccard_mean` / `jaccard_n_resamples` / `silhouette_mean` in the `clusters[]` payload).

## Problem

The scientifically-corrected clustering work (#457–459) computes and persists per-partition and per-cluster validation metrics (weighted modularity, mean silhouette, data-driven k, bootstrap-Jaccard stability, DB release label). These are already served read-only by the public API but are **not surfaced in the SPA**, so a reader of the functional / phenotype cluster analyses has no way to tell how well-separated or reproducible a partition is, or which specific clusters to trust. This matters because the two analyses differ sharply in quality (functional: strong, balanced, mostly stable; phenotype: weak, one dominant mass, low stability), and only the metrics make that legible.

## Goal

Add an inline **Cluster Validation** card to the functional and phenotype cluster analysis pages that shows the partition-level validation summary plus a per-cluster stability breakdown, mirroring the spirit of the existing `/NDDScore/ModelCard` (metadata + quality metrics) but placed contextually next to the clusters it describes.

Non-goals: no API/DB change; no new route; no gene-networks/correlations card; no LLM/summary coupling; no methods essay (a compact "how it's computed" tooltip only).

## Data availability (verified against the running API)

No backend change is required — both endpoints already return everything:

- `GET /api/analysis/functional_clustering` → `meta.snapshot.validation` (partition), `meta.snapshot.db_release`, `meta.snapshot.validation_hash`, `meta.snapshot.generated_at`; each `clusters[]` row carries `cluster`, `cluster_size`, `jaccard_mean`, `jaccard_n_resamples`.
- `GET /api/analysis/phenotype_clustering` → same `meta.snapshot.*`; each `clusters[]` row additionally carries `silhouette_mean`.

Scalar fields arrive as Plumber scalar-arrays (e.g. `[0.8525]`, `["leiden"]`); the frontend unwraps them (same pattern as `NddScoreModelCard`'s `scalarString`/`scalarNumber`).

Partition `validation` fields observed:
- functional (`algorithm: "leiden"`): `weighted`, `modularity`, `modularity_scope`, `resolution_parameter`, `n_iterations`, `n_clusters`, `n_dropped_below_min_size`, `partition_scope`, `resampling_scheme`, `subsample_fraction`, `n_resamples`, `n_resamples_effective`, `validation_schema_version`.
- phenotype (`algorithm: "mca_hcpc"`): `k`, `k_selection_metric`, `k_selection_curve`, `mean_silhouette`, `silhouette_status`, `n_clusters`, `n_entities_assigned`, `n_entities_dropped`, `partition_scope`, `resampling_scheme`, `subsample_fraction`, `n_resamples`, `n_resamples_effective`, `validation_schema_version`.

## Approach (chosen: A — one shared, algorithm-aware component)

A single presentational `ClusterValidationCard.vue` adapts its headline metric to the algorithm and renders the shared per-cluster stability UI, backed by a pure `clusterValidation.ts` helper. Rejected: two separate cards (duplicates the per-cluster UI + band logic), and a stability column inside the existing tables (mixes the trust signal into the data table and gives no partition summary).

## Architecture

```
AnalyseGeneClusters.vue ─────┐
                             ├─▶ <ClusterValidationCard>  ◀── clusterValidation.ts (pure)
AnalysesPhenotypeClusters.vue ┘        (props only; no fetch)
```

### New: `app/src/components/analyses/clusterValidation.ts` (pure helpers, unit-tested)
- `toScalarNumber(v)` / `toScalarString(v)` — unwrap Plumber scalar-or-array values; return `null`/`NaN`-safe results.
- `jaccardBand(value): { key: 'stable' | 'doubtful' | 'weak' | 'dissolved' | 'na'; label: string; variant: string }`
  Thresholds from `api/functions/analysis-cluster-validation.R` Hennig bands: `>=0.85` highly stable, `>=0.75` stable, `0.60–0.75` doubtful ("pattern but membership doubtful"), `0.50–0.60` weak, `<0.50` dissolved; `NA`/missing → `na`. (Card collapses "highly stable" into the "stable" variant but keeps the label.)
- `summarizeValidation(analysisType, validation): Array<{ label: string; value: string; hint?: string }>` — algorithm-aware headline rows:
  - functional: modularity (`+ weighted, full partition`), `n_clusters`, `n_dropped_below_min_size`, `n_resamples_effective`.
  - phenotype: mean silhouette (`+ status`), `k` (data-driven), `n_entities_dropped`, `n_resamples_effective`.
- `perClusterStability(clusters, analysisType): Array<{ id: string; size: number; jaccard: number | null; jaccardN: number | null; silhouette: number | null; band }>` — maps + sorts by size desc.

### New: `app/src/components/analyses/ClusterValidationCard.vue` (presentational)
Props:
- `analysisType: 'functional_clusters' | 'phenotype_clusters'`
- `snapshotMeta: AnalysisSnapshotMeta | null` (source of `validation`, `db_release`, `validation_hash`, `generated_at`)
- `clusters: FunctionalCluster[] | PhenotypeCluster[]`

Renders (only when `snapshotMeta.validation` is non-empty; otherwise renders nothing):
- Header: title + `db_release.version` badge + built date (`generated_at`).
- Headline metric rows from `summarizeValidation()`.
- Per-cluster list from `perClusterStability()`: `cluster label · size · Jaccard bar (0–1) with band color AND text label`, plus `silhouette` for phenotype. Not color-only — the band **label** and numeric value are always shown.
- Footer: compact bands legend + a small "How is this computed?" tooltip (weighted Leiden run to convergence / MCA-HCPC data-driven k; per-cluster stability = bootstrap-Jaccard over N subsamples, Hennig bands). Short `validation_hash` for provenance.

### Edit: `app/src/api/analysis.ts` (types only)
- Add `interface ClusterValidation` covering the union of functional + phenotype partition fields (all optional, typed scalar-or-array).
- Extend `AnalysisSnapshotMeta` with `validation?: ClusterValidation`, `validation_hash?: string | string[]`, `db_release?: { version?: string | string[]; commit?: string | string[] }`, `generated_at?` already present.
- Add optional `jaccard_mean?`, `jaccard_n_resamples?`, `silhouette_mean?`, `cluster_size?` (scalar-or-array) to `FunctionalCluster` and `PhenotypeCluster`.

### Edit: `AnalyseGeneClusters.vue` and `AnalysesPhenotypeClusters.vue`
Mount `<ClusterValidationCard :analysis-type="…" :snapshot-meta="<meta.snapshot>" :clusters="<clusters>" />` after the existing cluster table/plot, wired to the already-loaded response (no new fetch).

## States
- No validation present (older/pre-rebuild snapshot with empty `validation`): the card renders nothing (hide-when-empty, matching the `SectionCard` convention).
- 503 "snapshot being prepared": already handled by each page's existing branch; the card is simply not rendered until clusters/validation exist.
- `NA`/missing per-cluster values: shown as "n/a" and excluded from the band summary.

## Visual & accessibility
Follows `documentation/10-visual-design-guide.md` and the `sysndd-visual-design` skill: BootstrapVueNext, design tokens, `SectionCard`-style container consistent with the surrounding analyses UI. Stability bands use semantic status variants but always pair color with a text label + numeric value, so the signal is never color-only (WCAG). Bars use `max-width: 100%`; the per-cluster list scrolls within its own container if long.

## Testing
- `clusterValidation.spec.ts`: band boundaries (0.50 / 0.60 / 0.75 / 0.85), scalar-array unwrapping, both algorithm summaries, per-cluster mapping + sort, NA handling.
- `ClusterValidationCard.spec.ts`: functional (modularity headline) vs phenotype (silhouette + k) rendering; per-cluster bars carry a text band label; card hides when `validation` is empty; unwraps scalar-arrays.
- Gates: `cd app && npm run type-check` and `npm run lint-app` clean; `npm run test:unit` for the two specs.

## Files
- Add: `app/src/components/analyses/ClusterValidationCard.vue`
- Add: `app/src/components/analyses/clusterValidation.ts`
- Add: `app/src/components/analyses/clusterValidation.spec.ts`
- Add: `app/src/components/analyses/ClusterValidationCard.spec.ts`
- Edit: `app/src/api/analysis.ts` (types only)
- Edit: `app/src/components/analyses/AnalyseGeneClusters.vue`
- Edit: `app/src/components/analyses/AnalysesPhenotypeClusters.vue`
