# Analysis clustering: scientific correctness + persisted validation metrics (#457, #458, #459)

**Date:** 2026-06-30
**Issues:** https://github.com/berntpopp/sysndd/issues/457 · /458 · /459
**Implementation branch (proposed):** `fix/analysis-cluster-validation-457-459`

> Scope note: this is an **analysis-layer correctness + reproducibility** change. All
> framing is internal to the API/snapshot/MCP surface and generic downstream
> consumers (frontend, MCP, external reproducibility reporting). No external
> publication artifacts are referenced anywhere in this repo.

## Problem

The two clustering algorithms behind the public analysis snapshots have concrete
scientific defects, the snapshots persist **no** stability metric, and they carry no
human-facing DB release label. Verified against the code (igraph 2.3.1, FactoMineR
2.13, cluster 2.1.8.2; `fpc` is **not** in `renv.lock`):

### Functional clustering — `#457` (`api/functions/analyses-functions.R::gen_string_clust_obj`)

1. **Unweighted optimization.** `igraph::cluster_leiden()` (`:148`) is called with **no
   `weights=`**. The STRING induced subgraph carries its confidence as edge attribute
   **`combined_score`** (read explicitly at `analysis-network-functions.R:241`, `:308`),
   not `weight`, so igraph's auto-weight default does not pick it up. The objective runs
   unweighted: post the ≥400 confidence filter, a 401-confidence and a 999-confidence
   edge contribute identically. The partition is driven by degree topology (which on
   STRING tracks annotation/study bias), discarding exactly the signal the ≥400 filter
   exists to preserve.
2. **Non-converged.** `n_iterations = 2` (`:153`). Leiden's guarantees are asymptotic in
   iteration count (Traag, Waltman & van Eck 2019, *Sci Rep* 9:5233 report a median of
   ~6 iterations to a stable partition); two passes is a non-stationary point, so the
   result is sensitive to small input perturbations. `set.seed(42)` (`:132`) gives
   *determinism for a fixed graph*, not *stability under input change*.
3. **`resolution_parameter = 1.0` is an unexamined, hardcoded free parameter** (`:151`;
   no `resolution` argument exists). γ=1 is a reasonable default but is treated as
   canonical with no justification.
4. **No stability/modularity metric is computed anywhere** (grep-verified: zero hits for
   modularity-value, jaccard, clusterboot, bootstrap-resampling across `api/`).

### Phenotype clustering — `#458` (`api/functions/analysis-phenotype-functions.R::gen_mca_clust_obj`)

1. **k is hard-forced, not data-determined.** `HCPC(..., nb.clust = cutpoint, ...)` with
   `cutpoint = 5` (`:19`, `:48`). In FactoMineR, a positive `nb.clust` **imposes** that
   many clusters; only `nb.clust = -1` auto-selects via relative within-inertia loss.
2. **`min_size` is dead.** Declared (`:16`, default 10), documented in roxygen, and
   `cluster_size = nrow(identifiers)` is computed (`:74`) — but there is **no
   `filter(cluster_size >= min_size)`** anywhere (the functional path filters at `:192`;
   the phenotype path does not). The parameter is accepted and ignored.
3. **Speed approximations asserted but unmeasured.** `MCA(ncp = 8)` (was 15) and
   `HCPC(kk = 50)` (was Inf) carry inline comments claiming "validated stable
   clustering" with **no stored metric**. `ncp` truncation changes the metric space in
   which Ward inertia is computed; `kk` introduces seed-dependent k-means pre-clustering.
4. **MCA coordinates are discarded.** `mca_phenotypes$ind$coord` is computed internally
   but never extracted or returned, so a silhouette cannot be scored from the function
   output as-is.
5. **Cluster identity is positional.** Returned clusters are keyed by integer index; any
   change to k or ordering silently relabels downstream consumers.

### Persistence — `#459` (`api/functions/analysis-snapshot-*.R`)

1. No cluster-validation metric is computed or stored, so the snapshot read path and the
   MCP `*_context` tools cannot report any stability statistic.
2. `db_version_get()` (`api/functions/db-version.R:32-68`, issue #22) returns a
   human-facing `{version, commit, …}` but is **not joined** into the snapshot manifest
   (grep-verified: only `version_endpoints.R` calls it). The stored `source_data_version`
   is a SHA2-256 content **hash**, not a human-facing release label.

## Goals

- Functional Leiden optimizes **weighted** modularity (STRING `combined_score`) and runs
  **to convergence** (`n_iterations = -1`); `resolution` is an explicit argument.
- Phenotype HCPC selects k **from the data** (`nb.clust = -1`) and reports the emergent
  k; `min_size` is **enforced** with a documented tiny-cluster policy.
- A dedicated, lightweight, **membership-only** validation layer computes per-cluster
  bootstrap-Jaccard for both partitions, weighted modularity (functional), and mean
  silhouette (phenotype), scoped explicitly to the **stored visible top-level clusters**.
- Snapshots **persist** those metrics + a human-facing **DB release label**, and the API
  + MCP read paths **expose** them (read-only, correctly data-classed).
- A **stable, signature-based cluster identity** so downstream consumers map clusters by
  reproducible content, not positional index.
- Speed approximations (`ncp`, `kk`) and the resolution operating point are **quantified
  once** and archived as reproducible diagnostics.

## Non-goals

- **No synchronous compute on public request paths.** All clustering + validation runs in
  the worker / heavy snapshot build path only (verified: public `/clustering/submit` and
  `/jobs/phenotype_clustering/submit` are cache-hit-or-enqueue).
- **No new heavyweight dependency.** `fpc` is absent from `renv.lock`; bootstrap-Jaccard
  is hand-rolled in base R + `cluster`/`igraph` (already present). `cluster::silhouette`
  is used for the phenotype path. (If the user later prefers `fpc::clusterboot`, that is a
  separate dependency decision; the hand-rolled path also fits #457's fixed-graph,
  resample-genes-not-edges requirement that `clusterboot` does not model directly.)
- **No layout change.** fCoSE/FR layouts and the `gene_network_edges` snapshot geometry
  are untouched; only the community-detection objective and validation change.
- **No silhouette for graph clusters.** The functional community graph provides no metric
  embedding; silhouette would require an arbitrary node embedding and is omitted by
  design. Silhouette is computed only for the phenotype MCA clusters (Euclidean embedding).

## Design

### A. Functional Leiden correctness (`#457`, production)

In `gen_string_clust_obj` (`api/functions/analyses-functions.R`):

1. Add `resolution = 1.0` to the signature (after `min_size`, before `subcluster`, to
   avoid disturbing positional callers — all current callers use named or the leading
   positional `hgnc_list` only; verify each call site).
2. Change the `cluster_leiden` call (`:148-154`) to:
   ```r
   cluster_result <- igraph::cluster_leiden(
     subgraph,
     objective_function   = "modularity",
     weights              = igraph::E(subgraph)$combined_score,
     resolution_parameter = resolution,
     beta                 = 0.01,
     n_iterations         = -1
   )
   ```
   - With `objective_function = "modularity"`, igraph's default `vertex_weights` is the
     weighted degree — the correct configuration-model null term — so no further argument
     is needed. The weight scale is immaterial to modularity up to a constant; raw
     `combined_score` is used.
   - `n_iterations = -1` is "iterate until the partition is stable" (supported in igraph
     2.3.1, confirmed in `renv.lock`).
3. `set.seed(42)` stays (deterministic cluster hashes / LLM cache matching).
4. The single-level recursive sub-cluster call (`:220`) passes the same `resolution`
   through (defaults to 1.0) and keeps `subcluster = FALSE`.

**`partition_scope` definition (carried through to #459):** metrics describe the
**stored visible top-level clusters** = top-level (`subcluster = FALSE`) Leiden clusters
surviving the `cluster_size >= min_size` filter (`:192`). This is the set persisted to
snapshots and rendered downstream — **not** the raw full partition and **not** the
recursive subclusters. Constant: `partition_scope = "visible_top_level"`.

### B. Phenotype data-driven k + `min_size` + identity (`#458`, production)

In `gen_mca_clust_obj` (`api/functions/analysis-phenotype-functions.R`):

1. **Data-driven k.** Default `cutpoint = -1` → `HCPC(..., nb.clust = -1, ...)`. HCPC then
   cuts the Ward tree where the **relative loss of within-cluster inertia** is largest
   (its automatic criterion). Capture the emergent k as
   `k <- nlevels(mca_hcpc$data.clust$clust)` and surface it.
2. **Enforce `min_size`.** After computing `cluster_size`, add
   `filter(cluster_size >= min_size)` mirroring the functional path. **Tiny-cluster
   policy = drop** (entities in a sub-`min_size` HCPC cluster become unassigned; they are
   not merged, to avoid manufacturing a non-data-driven cluster). Documented in roxygen.
3. **Surface MCA coordinates.** Return `mca_ind_coord` (the `mca_phenotypes$ind$coord`
   matrix, `ncp` dims, row-named by `entity_id`) as a sibling element of the result so the
   validation helper can score silhouette without recomputing MCA. (Builder ignores it for
   row persistence; it is consumed only by validation.)
4. **Stable cluster signature.** Add `cluster_signature` per cluster = the deterministically
   ordered top-N enriched HPO term identifiers already in `quali_inp_var` (sort by
   ascending `p.value`, tie-break by HPO id; N=5), plus a short SHA2 of that ordered list.
   This rides into per-row `metadata_json` (builder serializes non-excluded columns).
   Downstream consumers key cluster identity on `cluster_signature`, not integer index.

> The functional path gets the analogous treatment: `gen_string_clust_obj` adds a
> `cluster_signature` = ordered top-N highest-degree member genes (deterministic from the
> fixed graph) + short hash, so both partitions have reproducible content identity.

### C. Membership-only validation helpers (`#457` requirement; consumed by `#459`)

New file `api/functions/analysis-cluster-validation.R` (registered in
`api/bootstrap/load_modules.R`). Two helpers, **worker/heavy-path only**, deterministic,
hand-rolled (no `fpc`):

**`validate_functional_clusters(hgnc_list, score_threshold = 400, resolution = 1.0, n_resamples = 100, min_size = 10, seed = 42)`**

- Build the STRING subgraph **once** (fixed graph) via the existing `get_string_db` path
  with `enrichment = FALSE, subcluster = FALSE`.
- Reference partition: weighted + converged Leiden, then `cluster_size >= min_size`
  (`partition_scope = "visible_top_level"`). Clusters `C_1..C_K` over node set `V`.
- **Weighted modularity** of the reference partition:
  `Q = igraph::modularity(subgraph, membership, weights = E(subgraph)$combined_score)`.
- **Per-cluster bootstrap-Jaccard (Hennig 2007 / `clusterboot` "boot" semantics):**
  for `b = 1..B`: draw a nonparametric bootstrap sample of the node set (sample `|V|`
  nodes with replacement), collapse to the distinct sampled set `S_b`, induce the
  subgraph `G[S_b]`, recluster with identical settings → `D_1..D_{L_b}`. For each
  reference cluster `C_k`, compute the recovery
  `γ_{k,b} = max_l Jaccard(C_k ∩ S_b, D_l)`; cluster stability `s_k = mean_b γ_{k,b}`.
  Per-resample seed is `seed + b` (reproducible). `resampling_scheme = "bootstrap_nodes"`
  is recorded; subsampling without replacement is a documented alternative parameter.
- **Optional conductance** per cluster (cheap; cut-weight / min(vol(C), vol(V∖C))).
- Returns: per-cluster `{cluster_id, jaccard_mean, jaccard_n_resamples, bootstrap_seed,
  conductance?}` and partition-level `{algorithm="leiden", weighted=TRUE, n_iterations=-1,
  resolution_parameter, modularity, n_clusters, partition_scope, resampling_scheme}`.

**`validate_phenotype_clusters(wide_phenotypes_df, quali_sup_var, quanti_sup_var, min_size, n_resamples = 100, seed = 42)`**

- Recompute MCA+HCPC deterministically (data-driven k, `min_size` enforced).
- **Mean silhouette** (valid — MCA is a Euclidean embedding):
  `cluster::silhouette(membership_int, dist(mca_ind_coord))`; report overall mean +
  per-cluster mean. Coordinates come from `mca_ind_coord` (helper input, not recomputed).
- **k-selection diagnostic:** the HCPC relative-inertia-loss value at the chosen k
  (`k_selection_metric = "hcpc_relative_inertia_loss"`), plus a corroborating mean
  silhouette computed over `k ∈ {2..10}` (stored as a small curve).
- **Per-cluster bootstrap-Jaccard:** resample **entities** (rows) with replacement,
  recompute MCA+HCPC, per-cluster `max`-Jaccard against the reference, mean over `B`.
- Returns: per-cluster `{cluster_id, jaccard_mean, jaccard_n_resamples, bootstrap_seed,
  silhouette_mean}` and partition-level `{algorithm="mca_hcpc", k, k_selection_metric,
  k_selection_curve[], mean_silhouette, partition_scope, resampling_scheme="bootstrap_entities"}`.

**Hennig interpretation bands** (carried as metric documentation, not as gates): mean
Jaccard ≤0.5 "dissolved"; 0.6–0.75 "pattern but membership doubtful"; ≥0.75
"valid/stable"; ≥0.85 "highly stable".

**Performance.** Bootstrap Leiden ×100 on a few-hundred-to-~2k-node graph is seconds
(Leiden is ~ms/run). Bootstrap MCA+HCPC ×100 is the heavier path (~1–3 min). Both run in
the worker heavy preset; `n_resamples` is configurable
(`ANALYSIS_CLUSTER_VALIDATION_RESAMPLES`, default 100) so a constrained refresh can lower
it. Adding validation makes `phenotype_clusters` effectively heavy → reweight it (see E).

### D. Persist + expose (`#459`)

**Migration `037_add_analysis_snapshot_validation.sql`** — `ALTER TABLE
analysis_snapshot_manifest` add: `validation_json JSON DEFAULT NULL`,
`db_release_version VARCHAR(64) DEFAULT NULL`, `db_release_commit VARCHAR(64) DEFAULT
NULL`. Bump `EXPECTED_LATEST_MIGRATION` → `"037_add_analysis_snapshot_validation.sql"` and
`EXPECTED_MIGRATION_COUNT` 34→35 in `api/functions/migration-manifest.R`; update the two
asserting guard tests (`test-unit-core-views-manifest.R`,
`test-unit-analysis-snapshot-migration.R`).

**Builder** (`api/functions/analysis-snapshot-builder.R`):
- Per-cluster validation fields (`jaccard_mean`, `jaccard_n_resamples`, `bootstrap_seed`,
  `silhouette_mean` [phenotype], `cluster_signature`) are merged onto the cluster tibble
  before `analysis_snapshot_build_cluster_rows`; they flow into per-row `metadata_json`
  automatically (they are not in the excluded-key set) and already round-trip on read.
- For the two clustering presets, call the matching validation helper in the heavy build
  path and assemble a partition-level `validation` list; thread it + the DB release label
  into the manifest create.
- **DB release label:** call `db_version_get(conn)` at build; store `version`/`commit`
  into the new manifest columns **and** into `source_versions_json`
  (`{db_release_version, db_release_commit}`). Policy: when `available == FALSE`, store the
  literal `"unknown"` (never omit).

**Repository** (`api/functions/analysis-snapshot-repository.R`):
- `analysis_snapshot_create_manifest()` gains `validation`, `db_release_version`,
  `db_release_commit` params; bind them in the INSERT (`:112`). Read path is `SELECT *`,
  so the new columns surface automatically.

**Service** (`api/services/analysis-snapshot-service.R`):
- `service_analysis_snapshot_meta()` (`:316-350`) exposes a `validation` object and a
  `db_release` object (`{version, commit}`) in the meta block.

**MCP** (`api/services/mcp-analysis-service.R`, `api/functions/mcp-analysis-repository.R`):
- `get_phenotype_analysis_context` (`:390`) and `get_gene_network_context` (`:500`)
  surface `validation` (data-class `curated_derived_analysis`) and `db_release` +
  `partition_scope` (data-class `operational_metadata`), read-only. Document new fields in
  `get_sysndd_capabilities`.

### E. Snapshot preset weighting + schema version

- `analysis_snapshot_preset_weight()` (`api/functions/analysis-snapshot-presets.R`):
  reclassify `phenotype_clusters` as `"heavy"` now that it runs bootstrap validation, so
  the startup bootstrap staggers it (mirrors `functional_clusters`).
- Bump `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` `"1.0"` → `"1.1"` (new persisted fields).

### F. Reproducible diagnostics (archived, operator-run — not endpoints)

Standalone scripts under `api/scripts/analysis-validation/` writing committed JSON/markdown
reports (no production wiring, no public surface):

1. **`functional-resolution-sweep.R`** — for a fixed approved-gene input: γ ∈
   {0.5,0.7,1.0,1.4,2.0} → `{n_clusters, weighted_modularity, ARI_vs_gamma1}` (ARI via
   `igraph::compare(method="adjusted.rand")`), plus a factorial decomposition
   {unweighted,weighted} × {n_iterations 2, converged} × γ-grid reporting cluster count +
   pairwise ARI. Justifies the default γ on a stability plateau and quantifies how much the
   unweighted/non-converged settings changed the partition.
2. **`phenotype-approximation-ari.R`** — ARI(partition(ncp=8) vs partition(ncp=15)) and
   ARI across ≥5 `kk` k-means seeds. Keep the fast settings only if ARI ≳ 0.9; otherwise
   flag for review.

## Data model summary

| Field | Where stored | Scope |
|---|---|---|
| `jaccard_mean`, `jaccard_n_resamples`, `bootstrap_seed` | `analysis_snapshot_cluster.metadata_json` | per cluster, both presets |
| `silhouette_mean` | `analysis_snapshot_cluster.metadata_json` | per cluster, phenotype only |
| `cluster_signature` (+ hash) | `analysis_snapshot_cluster.metadata_json` | per cluster, both presets |
| `validation_json` | `analysis_snapshot_manifest` (migration 037) | partition-level |
| `db_release_version`, `db_release_commit` | `analysis_snapshot_manifest` (037) + `source_versions_json` | snapshot |

`validation_json` shape — functional: `{algorithm, weighted, n_iterations,
resolution_parameter, modularity, n_clusters, partition_scope, resampling_scheme,
resolution_sweep?}`; phenotype: `{algorithm, k, k_selection_metric, k_selection_curve,
mean_silhouette, n_clusters, partition_scope, resampling_scheme}`.

## Testing

- **Static guards** (repo convention): `gen_string_clust_obj` source contains
  `weights = igraph::E(subgraph)$combined_score` and `n_iterations = -1`;
  `gen_mca_clust_obj` source contains `nb.clust = -1` and `filter(cluster_size >= min_size)`.
- **Unit — validation math** (no DB): synthetic weighted graph with two planted
  well-separated communities → `validate_functional_clusters` returns Jaccard ≈ 1 and
  higher weighted modularity than an unweighted control; synthetic phenotype matrix with
  planted structure → positive mean silhouette + high Jaccard; degenerate/empty inputs
  return typed empty results (mirrors `test-unit-clustering-empty-tibble.R`).
- **Unit — builder/manifest**: both clustering presets produce non-null per-cluster
  Jaccard, a partition-level metric, an explicit `partition_scope`, and a non-null DB
  release label (real or `"unknown"`); a `cluster_signature` is present and stable across
  two runs on the same input.
- **Migration guards** updated (count 35, latest `037…`).
- **MCP**: `get_phenotype_analysis_context` / `get_gene_network_context` surface
  `validation` + `db_release` with correct data-class labels (extend
  `test-mcp-analysis-service.R`).
- **Playwright (local-only)**: Gene Networks view still renders after a re-partitioned
  snapshot (sanity, no behavioral assertion on cluster count).
- **Adversarial math review** (`/code-review`-style pass) of the Jaccard/modularity/
  silhouette helper before merge.

## Acceptance criteria

- [ ] Leiden uses `combined_score` weights + `n_iterations = -1`; `resolution` is an
      argument; static guard asserts the weighted, converged call.
- [ ] HCPC uses `nb.clust = -1` (data-driven k); `min_size` is enforced; tiny-cluster
      policy documented.
- [ ] Membership-only validation helpers exist (`enrichment=FALSE`, `subcluster=FALSE`,
      fixed graph, per-resample seed) and compute per-cluster bootstrap-Jaccard (≥100
      resamples) over the **visible top-level** clusters.
- [ ] A fresh functional snapshot carries weighted modularity + per-cluster Jaccard with
      `partition_scope="visible_top_level"`; a phenotype snapshot carries mean silhouette
      + per-cluster Jaccard + the data-driven k.
- [ ] Every snapshot carries a DB release label (real or explicit `"unknown"`).
- [ ] A reproducible `cluster_signature` exists per cluster (both presets) and is stable
      across reruns on identical input.
- [ ] MCP analysis-context tools expose the metrics + label read-only, correctly
      data-classed; documented in `get_sysndd_capabilities`.
- [ ] Resolution-sweep + ncp/kk-ARI diagnostics archived; settings justified.

## Operational notes

- **Memoise cache invalidation (required).** The snapshot builder calls the memoised
  wrappers `gen_string_clust_obj_mem` / `gen_mca_clust_obj_mem` / `gen_network_edges_mem`,
  whose `api_cache` keys are derived from arguments only — they will **not** auto-invalidate
  when the underlying function changes. The derived-analysis cache version must be bumped so
  the corrected (weighted/converged/data-driven) functions do not serve pre-fix partitions
  from a warm cache. (MCP mounts `api_cache` read-only and must not initialize/clear it; the
  bump + reprime happens on the API/worker side.)
- Re-partitioning shifts `hash_filter` → LLM-summary cache keys; affected functional and
  phenotype clusters need regeneration (existing admin/worker path). Plan a post-deploy
  snapshot refresh + LLM regeneration.
- Validation adds build time; `n_resamples` is env-tunable, and both clustering presets
  stagger on startup as heavy presets.

## Files touched (anticipated)

- `api/functions/analyses-functions.R` (weighted/converged Leiden, `resolution`, signature)
- `api/functions/analysis-phenotype-functions.R` (`nb.clust=-1`, `min_size`, coords, signature)
- `api/functions/analysis-cluster-validation.R` (**new**)
- `api/functions/analysis-snapshot-builder.R` (call validation, assemble `validation_json`, DB label)
- `api/functions/analysis-snapshot-repository.R` (manifest INSERT columns)
- `api/services/analysis-snapshot-service.R` (meta exposure)
- `api/services/mcp-analysis-service.R`, `api/functions/mcp-analysis-repository.R` (+ capabilities)
- `api/functions/analysis-snapshot-presets.R` (weight + schema version)
- `api/functions/migration-manifest.R` (manifest constants)
- `api/bootstrap/load_modules.R` (register new module)
- `db/migrations/037_add_analysis_snapshot_validation.sql` (**new**)
- `api/scripts/analysis-validation/*.R` (**new**, diagnostics)
- tests: new `test-unit-analysis-cluster-validation.R`; updates to snapshot/MCP/migration guards

## Sequencing

1. **#457 + #458 production correctness** (independent, parallel) → 2. **validation helpers**
(depend on 1) → 3. **#459 persistence + exposure** (depends on 2) → 4. **diagnostics scripts +
post-deploy refresh/regeneration**. Migration 037 lands with step 3.
