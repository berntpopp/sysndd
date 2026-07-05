# Cluster-analysis statistical soundness & reproducibility (#508–#512)

**Date:** 2026-07-05
**Branch:** `feat/cluster-soundness-508-512`
**Status:** Approved (design signed off; implement + test end-to-end)
**Builds on:** `.planning/superpowers/specs/2026-06-30-analysis-cluster-validation-design.md`

> Repo rule: no manuscript references in any repository artifact. This spec is framed
> around the analysis pipeline and the **served cross-axis interpretation** ("function
> is modular, phenotype is a continuum"), not any external document.

## 1. Problem

SysNDD serves two derived cluster analyses and contrasts their separation directly:

- **Phenotype axis** — `FactoMineR::MCA` → `HCPC` on entities × HPO organ-system terms,
  summarized by **mean silhouette** (live: 0.194, k=3, N=1932).
- **Functional axis** — STRING PPI → weighted Leiden, summarized by **modularity**
  (live: 0.536, 9 clusters, 7 dropped).

Five defects (external reproducibility review, #508–#512) make this comparison and its
inputs unsound:

- **#508** MCA uses the HPO subtree root `HP:0000118` + near-universal terms as *active*
  variables with no near-constant filtering → dilutes inertia, mechanically depresses
  silhouette.
- **#509** the published `k_selection_curve` is a **plain full-data Ward cut**, a different
  partition than the reported labels; the two k=3 silhouettes disagree (curve 0.191 vs
  reported 0.194). **Verified live:** FactoMineR 2.13 `HCPC` sets `consol <- FALSE` when
  `kk != Inf`, so `HCPC(kk=50, consol=TRUE)` silently runs **without consolidation** — the
  comment at `analysis-phenotype-functions.R:60` is false.
- **#510** functional weights use STRING `combined_score` (includes text-mining/co-mention),
  with **no null model** (though Leiden maximizes Q) and **no giant-component handling**.
- **#511** silhouette vs modularity are incommensurable (different domain, range, null
  behavior); nothing computes a metric on both axes on a common footing.
- **#512** snapshots ship validation *numbers* but not the *inputs* (full edge list,
  complete membership, MCA coordinates) needed to independently recompute them.

## 2. Goals / Non-goals

**Goals**
- Replace the two incommensurable raw indices with **one unit-free, null-calibrated
  separation z-score reported identically on both axes**, plus a representation-agnostic
  continuum-vs-modular test.
- Make each axis's inputs statistically sound (feature hygiene; consistent, honestly-labeled
  k-selection; text-mining-free, null-benchmarked, giant-component-correct modularity).
- Make every served validation metric **independently reproducible** from published artifacts.
- Keep it state-of-the-art and cited; document the method.

**Non-goals (v1)**
- Matched non-NDD **control gene set** (deferred; needs degree/study-bias matching — later phase).
- Changing the *scientific conclusion*. The weak-phenotype-separation / strong-functional
  contrast is expected to survive; this is about correctness and defensibility, not spin.
- CPM/OSLOM/consensus alternatives (mention as reported cross-checks only, not primary).

## 3. Key architectural constraints (verified)

- `analysis_snapshot_payload_hash` **excludes** `partition_validation`
  (`analysis-snapshot-builder.R:493-494`). ⇒ additive validation fields **do not** change
  `cluster_hash`, so no LLM-summary-cache invalidation. Only **membership** changes do.
- Cluster-validation code is **worker/heavy-path only**, never on a public request. Nulls,
  dip tests, and repro-bundle builds run there. Public read paths stay DB-only.
- Single module loader `api/bootstrap/load_modules.R` covers API **and** durable worker;
  register every new file there. **Restart the worker** after changing worker-executed code.
- FactoMineR 2.13: `HCPC(consol=TRUE)` requires `kk=Inf`; N=1932 makes `kk=Inf` cheap.
- STRING per-channel scores are **not local**; only combined-score files exist in `api/data/`.
- File-size rule (< 600 lines) applies to **every** touched file. `analysis-snapshot-builder.R`
  is already 577 lines ⇒ new logic goes in new files; extract if any file approaches the ceiling.
- Latest migration `040`; next is `041`; update `EXPECTED_LATEST_MIGRATION`
  (`migration-manifest.R:5`) + the 3 asserting tests + the runner min-count test.

## 4. Locked decisions (override any before/during implementation)

| # | Decision | Value |
|---|---|---|
| 1 | #508 default = filtered active set + `{absent,present}` encoding + λ>1/Q ncp | **Yes** (regenerates phenotype hashes + LLM summaries) |
| 2 | #509 enable true consolidation (`kk=Inf, consol=TRUE`) | **Yes** |
| 3 | #510 text-mining-free scope | **Whole functional pipeline** (clustering, modularity, displayed edges) |
| 4 | #511 matched control gene set | **Defer** to a later optional phase |
| 5 | #512 delivery | **Sibling read-only endpoints + new snapshot child storage** |
| 6 | Rollout | **Wave 1 additive (no regen) → Wave 2 method-change (coordinated refresh + LLM regen)** |

## 5. Design — components

### C1. MCA feature hygiene (#508) — *membership change*

New helper module `api/functions/analysis-phenotype-mca-prep.R`:

- `phenotype_mca_active_filter(matrix, prevalence_min=0.05, prevalence_max=0.95, drop_terms=c("HP:0000118"))`
  → returns `{ active_matrix, kept_terms, excluded }` where `excluded` is a tibble
  `(term, hpo_id, prevalence, reason ∈ {root, near_universal, near_rare})`.
  - Prevalence = fraction of entities with the term **present** (non-NA / "yes").
  - Always drop the ontology root `HP:0000118`; drop terms with prevalence ∉ `[min,max]`.
  - Column identity: the matrix columns are `HPO_term` **names**; map to HPO ids via
    `phenotype_list` for the `hpo_id` + provenance. Keep the id-count/inheritance
    supplementary columns untouched.
- `phenotype_mca_encode_presence(matrix)` → recode each HPO presence column from `{"yes",NA}`
  to a 2-level factor `{"absent","present"}` so MCA treats absence as a real category
  (Le Roux & Rouanet; Greenacre). Supplementary columns (inheritance, counts) unchanged.
- `phenotype_mca_ncp(mca_or_eig, q_active)` → Greenacre `1/Q` rule: `ncp = max(2, sum(λ > 1/Q))`,
  with a documented floor/ceiling; also compute Greenacre-adjusted inertia percentages
  `pct_adj = (Q/(Q-1))^2 (λ-1/Q)^2 / greenacre_denom` for the retained axes.

`gen_mca_clust_obj` (`analysis-phenotype-functions.R`) changes:
- Apply `phenotype_mca_active_filter` + `phenotype_mca_encode_presence` to build the active set
  before `MCA`.
- Two-pass ncp: run `MCA(ncp = generous)` once to get eigenvalues, choose `ncp` by `1/Q`, re-run
  (or subset dims for HCPC). Keep deterministic `set.seed(42)`.
- Return provenance (kept/excluded terms, band, ncp, adjusted inertia) so the builder can put it
  in the validation block. Do **not** change the tibble's existing columns (downstream unnest).
- Keep `cluster_signature` semantics; membership will change, hashes will regenerate (expected).

### C2. k-selection consistency + honest reporting (#509) — *method change (consolidation)*

In `gen_mca_clust_obj`: switch to `HCPC(..., kk = Inf, consol = TRUE, nb.clust = cutpoint)` so
consolidation actually runs (textbook HCPC; cheap at N=1932). Fix/remove the false
`analysis-phenotype-functions.R:60` comment.

In `validate_phenotype_clusters` (`analysis-cluster-validation.R`), replace the Ward-cut curve:
- `k_selection_curve[k]` = mean silhouette of the **actual HCPC procedure re-run at each k**
  (`HCPC(res.mca, nb.clust=k, kk=Inf, consol=TRUE)`, silhouette on `dist(MCA coords[,1:ncp])` of
  `res$data.clust$clust`). By construction `curve[k_selected] == mean_silhouette`.
- Add `k_decision_curve[k]` = HCPC's **relative inertia loss / Krzanowski–Lai** value per k
  (the metric HCPC actually uses), with `k_selected` marked — makes explicit that k was **not**
  chosen by silhouette.
- Add `silhouette_interpretation` band (Kaufman–Rousseeuw: ≤0.25 "no substantial structure /
  continuum", 0.26–0.5 "weak", …).
- `consolidation = TRUE`, `kk = "Inf"` recorded.

### C3. Functional modularity rigor (#510) — *membership change (channel)*

New module `api/functions/analysis-string-channels.R`:
- One-time data: fetch `9606.protein.links.detailed.v11.5.txt.gz` into `api/data/` (via db-prep
  download helper; documented, checksum-logged). Do **not** bake into image layers.
- `string_recompute_score(escore, dscore, prior=0.041)` → STRING OR combine of
  experimental+database only: `strip → 1-∏(1-·) → add prior`. Unit-tested against known values.
- `string_textmining_free_graph(subgraph_or_ids, score_threshold=400)` → igraph weighted by the
  recomputed `exp_db_score`, thresholded on the recomputed score; edges lacking exp/db evidence
  are dropped. Env `STRING_WEIGHT_CHANNELS` (default `"experimental,database"`) selects channels.

`build_string_subgraph` / `gen_string_clust_obj` (`analyses-functions.R`):
- Build the subgraph on text-mining-free weights (primary). Restrict to
  `igraph::largest_component()`. Weight Leiden + modularity by `exp_db_score`.
- Record `giant_component = { n_nodes, n_edges, n_isolates, n_components, node_retention,
  edge_retention }`.
- Displayed network (`analysis-network-functions.R`) uses the same text-mining-free weighted
  graph so display and partition agree.

New module `api/functions/analysis-null-models.R` (shared by both axes; < 600 lines):
- `modularity_null_zscore(graph, membership, weights, n_null=200, seed=42)` → degree-preserving
  `rewire(keeping_degseq(niter = 10*ecount))`, **permute weight vector**, **re-restrict to LCC**,
  re-run identical Leiden, return `{ z, p_empirical, q_obs, q_null_mean, q_null_sd, n_null, null_model }`.
  Env `ANALYSIS_MODULARITY_NULL_N` (default 200; document 1000 ideal).
- `silhouette_null_zscore(coords, membership, n_null=1000, seed=42)` → label-permutation null
  (preserve cluster sizes), return `{ z, p_empirical, sil_obs, sil_null_mean, sil_null_sd, n_null }`.
  Env `ANALYSIS_SILHOUETTE_NULL_N` (default 1000; cheap).
- `dip_unimodality(dist_vector)` → `diptest::dip.test` on a pairwise-distance vector →
  `{ dip_statistic, p_value, interpretation }`. (Add `diptest` dependency via `renv`.)
- `knn_similarity_graph(coords, k, kernel="gaussian_local")` → mutual-kNN + local-bandwidth
  Gaussian weights, for the phenotype shared index. Env `ANALYSIS_PHENOTYPE_KNN_K` (default e.g. 15).

`validate_functional_clusters` gains: `modularity` (text-mining-free, LCC primary),
`modularity_combined_score` (full-combined sensitivity), `modularity_z`, `modularity_p_empirical`,
`null_model`, `n_null`, `giant_component`, `weight_channel`, `dip_statistic`, `dip_p`
(graph distance = `1 - normalized weight` or shortest-path), `separation_z = modularity_z`.

### C4. Common cross-axis separation framework (#511) — *additive*

The **shared, unit-free footing**: both axes report `separation_z` (function = modularity-z;
phenotype = silhouette-z) + `dip_p`. Additionally, the **same index** on both axes:

- `validate_phenotype_clusters` gains `silhouette_z`, `silhouette_p_empirical`, `dip_statistic`,
  `dip_p` (Euclidean MCA-coord distances), and `modularity_z_knn` — phenotype **modularity-z on
  the kNN graph** of MCA coords (`knn_similarity_graph` + `modularity_null_zscore`), so modularity-z
  is reported on *both* axes.
- `separation_z` (the headline comparable) = silhouette-z for phenotype, modularity-z for function;
  `shared_modularity_z` present on both (function native; phenotype via kNN graph).
- Cross-axis interpretation is expressed as z-scores + dip p-values, never raw 0.19 vs 0.54.

### C5. Reproducibility bundle (#512) — *additive*

Storage: migration `041_add_analysis_reproducibility.sql` → new table
`analysis_snapshot_reproducibility (snapshot_id FK, kind, bundle_gzip_json LONGBLOB,
reproducibility_hash CHAR(64), byte_size, created_at)`. One row per clustering snapshot.

Bundle contents (built in `analysis-snapshot-builder.R`, gzipped):
- **functional**: full edge list `(source_hgnc_id, target_hgnc_id, combined_score, exp_db_score)`
  for the clustered (LCC) subgraph; **complete** membership vector (all communities incl.
  `< min_size`, keyed by original split position); params (`score_threshold`, channels, resolution,
  seed, giant-component counts).
- **phenotype**: MCA coordinate matrix (entity × ncp) + cluster assignment; the active/excluded
  term set + prevalence band; params (`ncp`, `kk=Inf`, `consol=TRUE`, seed). Optionally the exact
  input presence matrix.
- `reproducibility_hash` = SHA-256 over the canonical bundle; stored on the manifest so the served
  validation metrics are verifiably tied to the inputs.

Delivery: `api/endpoints/analysis_reproducibility_endpoints.R` (mounted via `mount_endpoint`):
- `GET /api/analysis/functional_clustering/reproducibility`
- `GET /api/analysis/phenotype_clustering/reproducibility`
DB-only, approved-public gated (entities/genes resolved through the public surface), returns the
bundle + `reproducibility_hash`. Large payloads streamed/gzip; documented size.

### C6. Surfacing (frontend + MCP) — *additive*

- `app/src/api/analysis.ts` `ClusterValidation` interface: add `separation_z`, `*_p_empirical`,
  `modularity_z`, `modularity_combined_score`, `shared_modularity_z`, `dip_statistic`, `dip_p`,
  `giant_component`, `silhouette_interpretation`, `k_decision_curve`, `active_feature_set`,
  `excluded_terms`, `reproducibility_hash`.
- `clusterValidation.ts` `summarizeValidation`: show z-score (+ p) as the headline separation
  metric on both axes; keep raw silhouette/modularity as secondary; add component counts,
  excluded-terms note, interpretation band. `ClusterValidationCard.vue` renders them.
- MCP (`mcp-analysis-service.R`): expose new validation fields as `operational_metadata`
  (read-only, current/validated only); never compute nulls/dip on MCP. Reproducibility bundle is
  **not** an MCP tool in v1 (large; approved-public HTTP endpoint only).

## 6. Validation schema & versioning

Bump `validation_schema_version` "1.0" → **"2.0"**; bump `ANALYSIS_SNAPSHOT_SCHEMA_VERSION`
"1.1" → **"1.2"** (new repro child rows + validation fields). Frontend/MCP read the new fields
defensively (absent ⇒ hide), so a pre-refresh snapshot still renders.

## 7. Rollout (blast radius)

- **Wave 1 (additive; no `cluster_hash` change; no LLM regen):** C4 (z/dip/shared-index computed
  on the *current* combined-score partition), C3's null-model + giant-component + z reporting
  (computed on current graph), C2 curve/comment fix, C5 repro bundle + endpoints, C6 surfacing.
  Ship + verify without touching served clusters.
- **Wave 2 (method change; `cluster_hash` regen + coordinated LLM regen):** C1 MCA filter/encoding/
  ncp, C2 consolidation, C3 text-mining-free primary channel. Then: worker restart →
  `POST /api/admin/analysis/snapshots/refresh?force=true` (both cluster types) →
  `POST /api/llm/regenerate?...&force=true` for phenotype + functional. Wave-1 metrics recompute
  on the new partitions automatically.

## 8. Config / env (all optional, documented defaults)

`STRING_WEIGHT_CHANNELS=experimental,database` · `ANALYSIS_MODULARITY_NULL_N=200` ·
`ANALYSIS_SILHOUETTE_NULL_N=1000` · `PHENOTYPE_MCA_PREVALENCE_MIN=0.05` ·
`PHENOTYPE_MCA_PREVALENCE_MAX=0.95` · `PHENOTYPE_MCA_NCP_RULE=greenacre_1_over_q` ·
`ANALYSIS_PHENOTYPE_KNN_K=15` · reuse `ANALYSIS_CLUSTER_VALIDATION_RESAMPLES`.

## 9. Testing (deterministic; TDD)

R (`api/tests/testthat/`):
- `test-unit-phenotype-mca-prep.R` — prevalence filter drops `HP:0000118` + band edges;
  `{absent,present}` encoding; λ>1/Q ncp; adjusted inertia formula.
- extend `test-unit-phenotype-hcpc-k.R` — consolidation on (`kk=Inf`); k-curve consistency
  (`curve[k_selected] == mean_silhouette` to tolerance); decision curve present.
- `test-unit-analysis-string-channels.R` — STRING OR recompute vs hand-computed known values;
  text-mining-free graph drops text-mining-only edges.
- `test-unit-analysis-null-models.R` — seeded modularity-z & silhouette-z determinism, sign,
  p-value bounds; degree preserved by rewire; dip test on known unimodal/bimodal vectors;
  kNN graph shape.
- extend `test-unit-functional-leiden-weights.R` — LCC restriction; giant-component counts;
  weights = exp_db_score.
- `test-unit-analysis-reproducibility.R` — **round-trip**: recompute modularity & silhouette from
  the bundle == served metrics (the core #512 guarantee); `reproducibility_hash` stable.
- extend `test-unit-analysis-snapshot-validation-build.R` — new validation fields persisted;
  schema 2.0.
- endpoint test for the two reproducibility routes (problem+json error handler; approved-public gate).
- static guard: public/cheap routes never invoke null-model/dip/repro build.
- migration tests: update the 3 `EXPECTED_LATEST_MIGRATION` assertions + runner min-count.

Frontend (`app/src/`): extend `clusterValidation.spec.ts`, `ClusterValidationCard.spec.ts`,
`analysis.spec.ts` for new fields; hide-when-absent.

End-to-end: `make code-quality-audit` (file-size ratchet), `make lint-api`, `make test-api-fast`
then targeted container test files; `cd app && npm run type-check && npm run test:unit`; live
verification via the container API + a forced Wave-2 refresh; confirm reproducibility endpoint
returns a bundle whose recomputed metrics match the served validation.

## 10. Docs (same change)

- `AGENTS.md` — extend the analysis-snapshot / cluster-validation architecture invariant with the
  null-calibrated z framework, text-mining-free channel, consolidation fact, and reproducibility bundle.
- `documentation/08-development.qmd` (method + how to refresh/verify), `documentation/09-deployment.qmd`
  (Wave-2 coordinated refresh + LLM regen runbook), `db/migrations/README.md` (041).
- A concise methods note (cited) under `.planning/` capturing the statistical rationale.

## 11. Open items / risks

- STRING detailed file size (~ hundreds of MB compressed) + load time in worker; verify budget.
- Null N vs worker lease time (heavy path already staggered); start at 200, make env-tunable.
- `analysis-snapshot-builder.R` at 577 lines — extract repro-bundle build into a helper file.
- kNN-graph k / kernel sensitivity for the phenotype shared index — report, keep env-tunable.
- Bundle storage size (~2 MB functional edge list) — LONGBLOB gzip; endpoint streams.
