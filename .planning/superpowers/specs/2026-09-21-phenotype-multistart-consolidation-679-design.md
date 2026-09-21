# Phenotype clustering: multi-start consolidation, application-owned k (#679)

Status: implemented (see "Findings during implementation")
Issue: berntpopp/sysndd#679
Date: 2026-09-21

## Problem

The phenotype axis (`gen_mca_clust_obj`, `api/functions/analysis-phenotype-functions.R`)
runs MCA, then `FactoMineR::HCPC(nb.clust = -1, kk = Inf, consol = TRUE)`. HCPC cuts a
Ward tree at a data-driven k and then "consolidates" with **one** k-means run started
from the Ward-cut centroids. k-means finds a local optimum; which one is decided
entirely by that single deterministic start. `set.seed(42)` is a no-op for it.

Every claim below was re-verified for this design against the live public
reproducibility bundle of snapshot 196 (`GET /api/analysis/phenotype_clustering/reproducibility`,
2,017 entities x 8 MCA dimensions, coordinates rounded to 4 decimals), in the
`sysndd-api:latest` image (R 4.6.1, FactoMineR 2.13).

**1. The served partition is the worse of two optima of its own objective.**

| | Ward-cut start (served) | best of 100 seeded random starts |
|---|---|---|
| sizes | 992 / 695 / 330 | 1121 / 555 / 341 |
| within-cluster inertia W/n | 0.3603 | **0.3530** |
| mean silhouette | 0.145 | **0.183** |
| random starts reaching this basin | 19-20 of 100 | 80-81 of 100 |

ARI between the two: 0.35. The Ward-start reproduces the served membership at ARI 1.00,
so this is a property of the procedure, not of a faulty replica.

**2. `iter.max` is not the cause here.** The Ward-start run converges in 3 iterations
(`ifault = 0`) and lands on 0.3603 with `iter.max = 10` and with `iter.max = 1000`
alike. Raising `iter.max` is still correct hygiene (issue item 2) but does not fix the
defect; only additional starts do.

**3. The single-start procedure is unstable under a one-entity change.** Deleting
1, 5, or 20 random entities from the snapshot-196 coordinates and re-running:

- single start: the partition flips basin in 17 of 20 trials (ARI ~0.35 against the
  full-data single-start result), including trials that removed **one** entity;
- multi-start (100 seeded starts, lowest inertia wins): ARI >= 0.95 in 20 of 20
  trials, k = 3 in all.

That is the mechanism behind the re-split between two snapshots taken weeks apart on
near-identical input.

**4. Inside the better basin there are micro-optima.** Hartigan-Wong stops at several
near-tied solutions (W/n 0.353006 ... 0.353030) that differ in 1-5% of boundary
entities (ARI 0.94-0.99 against the best). "Number of distinct optima" therefore needs
a definition that separates *basins* from *micro-variants* (see Landscape).

**5. The pinned FactoMineR version is the only thing holding k in place.**
`api/renv.lock` pins 2.13, whose `HCPC` auto-cut is

```r
quot <- intra[min:max] / intra[(min - 1):(max - 1)]; nb.clust <- which.min(quot) + min - 1
```

FactoMineR 2.17 (current CRAN, 2026-09-08) replaced it with a dimension-scaled
second-difference index (`intra_norm <- k^(2/p) * intra`, maximise
`|d(k-1,k) / d(k,k+1)|`). Diffing the two `HCPC` bodies shows this is the only
algorithmic change. On a synthetic three-block matrix 2.13 picks k = 3 and 2.17 picks
k = 8 with MCA coordinates identical to 6.6e-15 and identical partitions at a fixed k.
A routine `renv` refresh would silently change the released partition.

**6. 2.17 has two further behaviour changes that touch this code** (found while
testing the bump, not in the issue):

- `svd.triplet` now uses `irlba` (truncated SVD) when `ncp < 0.5 * min(dim)` — the
  production case (`ncp = 8`, ~60 indicator columns). Coordinates agree to 1e-14, but
  `mca$eig` is truncated to `ncp` rows. `validate_phenotype_clusters` feeds
  `mca$eig[, "eigenvalue"]` to `phenotype_mca_ncp()` (Greenacre 1/Q rule + adjusted
  inertia), which needs **all** eigenvalues above 1/Q. Under 2.17 that diagnostic would
  silently be computed from 8 eigenvalues.
- `catdes` gained `html.table`, its quanti tables gained an `n` column, and category
  row names keep spaces (`HP term 5=...` vs `HP.term.5=...`). The served
  `quanti_sup_var` payload would grow a column; the `variable` strings are unaffected
  because the code already strips everything up to `=`.

## Goals

1. The released partition is the lowest-inertia solution among a fixed, seeded set of
   starts that always includes the Ward-cut start. Deterministic given the input.
2. k is computed in application code from the Ward tree by the documented rule, so no
   package update can change it silently.
3. The validation block reports how contested the solution is.
4. The per-k curve and the resampling reruns use the identical procedure, keeping the
   #509 invariant `k_selection_curve[k_selected] == mean_silhouette`.
5. The snapshot records everything needed to tie a partition to its procedure
   (procedure version, starts, seed, k rule, FactoMineR and R versions).
6. FactoMineR moves to the current CRAN release with a regression test that fails if
   k, the coordinates, or the consolidated partition drift across a package update.
7. Existing snapshots are untouched; the change applies from the next refresh.

## Non-goals

- Changing the MCA (active set, prevalence band, `ncp = 8`) or the k rule itself.
- Replacing k-means with a different consolidation objective, or choosing k by
  silhouette. The objective stays within-cluster inertia; only the optimiser improves.
- Frontend UI for the landscape. The block is served in `partition_validation` and
  typed in the client; rendering it is a follow-up.
- A general dependency refresh. Only FactoMineR and the four packages it newly
  imports move.

## Approaches considered

**A. Pass `nstart` through `HCPC(...)`.** `HCPC` forwards `...` to its internal
`kmeans(X, centers = <matrix>, iter.max, ...)`, and `stats::kmeans` honours `nstart`
with a centre matrix (first start = the matrix, the rest random). Smallest diff, but it
relies on undocumented `...` plumbing inside a third-party function — exactly the class
of coupling that produced the k drift — it yields no landscape, and k would still be
FactoMineR's. Rejected.

**B. Application computes k, then `HCPC(nb.clust = k)`, then re-consolidate outside.**
This is the issue's literal wording. But once the app owns the multi-start
consolidation, HCPC's own (single-start) consolidation result is discarded and its
`desc.var` describes the wrong partition, so `catdes` must be re-run anyway. HCPC would
contribute nothing but a second copy of the Ward cut. Rejected as redundant.

**C. Application owns tree -> k -> multi-start consolidation; FactoMineR supplies MCA
and `catdes` only. (Chosen.)** The clustering core becomes a small pure module over a
numeric coordinate matrix with base-R dependencies only (`stats::hclust`, `stats::kmeans`),
testable on the host and on a real-data fixture without FactoMineR. Verified:
`stats::hclust(method = "ward.D")` on `dist(X)^2 / (2n)` gives heights identical to
HCPC's `flashClust::hclust(method = "ward")` (max abs diff 0 over the top 30 merges)
and identical cuts for k = 2..10 on snapshot 196. Direct
`catdes(cbind(mca$call$X, clust), ncol, proba = 0.05, row.w = mca$call$row.w.init)`
is `all.equal` to `HCPC$desc.var` on both 2.13 and 2.17. With `n_starts = 0` the
module is a drop-in replica of FactoMineR 2.13 `HCPC(nb.clust = -1, kk = Inf,
consol = TRUE)`, which gives a parity test.

## Design

### New module `api/functions/analysis-phenotype-consolidation.R`

Pure functions, no DB, no FactoMineR, base R only. Registered in
`bootstrap/load_modules.R` and `bootstrap/setup_workers.R` **before**
`analysis-phenotype-functions.R`.

- `PHENOTYPE_PROCEDURE_VERSION <- "2.0-multistart"` — recorded in snapshot params.
- `phenotype_consolidation_config()` -> `list(n_starts, seed, iter_max, k_min, k_max,
  basin_ari)`. `n_starts` from env `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS` (default
  100, floor 0), `seed = 42L`, `iter_max = 100L`, `k_min = 3L`, `k_max = 25L`,
  `basin_ari = 0.90`.
- `phenotype_ward_tree(coords)` -> orders rows by the first coordinate (HCPC parity;
  row order changes nothing mathematically but fixes tie handling and the random-start
  row index space), builds `stats::hclust(dist(X)^2 / (2n), "ward.D")`, returns
  `list(X, tree, within)` where `within[k]` = W(k)/n from the tree heights.
- `phenotype_select_k(within, k_min, k_max)` -> `list(k, ratio_curve)`; `k_max` is
  capped at `n - 1`; `ratio_curve[k] = W(k)/W(k-1)`; `k = argmin` (first minimum on
  ties, matching `which.min`).
- `phenotype_consolidate_multistart(X, ward_cut, k, n_starts, seed, iter_max)`:
  start 0 = Ward-cut centroids; start i (1..n_starts) = `set.seed(seed + i)`, k rows
  drawn with `sample.int` from `unique(X)` (duplicate phenotype profiles are common —
  354 of 2,017 rows on snapshot 196 — and duplicate centres make `kmeans` error). All
  runs `stats::kmeans(algorithm = "Hartigan-Wong", iter.max = iter_max)` with warnings
  captured, `converged = (ifault == 0)`. If `unique(X)` has fewer than k rows the
  random starts are skipped (Ward start only).
  **Selection order:** converged before non-converged, then lowest `tot.withinss`
  (relative tolerance 1e-10 counts as a tie), then lowest start index — so the
  Ward-cut start wins exact ties, then seed order. Deterministic.
- `phenotype_consolidation_landscape(solutions, chosen, n, basin_ari)` -> the block
  under *Landscape*.
- `phenotype_cluster_coords(coords, k = NULL, config)` -> orchestrator. `k = NULL`
  selects by the rule; a positive k imposes it. Labels are renumbered by ascending
  first-coordinate centroid (HCPC's `order = TRUE` behaviour, retained so labels stay
  comparable to earlier snapshots). Returns `list(cluster = <named int, input row
  order>, k, k_selected_by, ratio_curve, centers, within_inertia, converged, landscape,
  config)`.

The landscape needs an adjusted Rand index. `adjusted_rand_index()` already exists in
`analysis-phenotype-missingness.R` with its own tests; the new module calls it rather
than defining a second copy. The call resolves at run time (both files are loaded by
`load_modules.R` / `setup_workers.R`), so source order is immaterial; the pure-module
tests source both files.

### `gen_mca_clust_obj` (same file, same signature, same return shape)

1. `set.seed(42)`; `FactoMineR::MCA(...)` unchanged.
2. `fit <- phenotype_cluster_coords(mca$ind$coord, k = if (cutpoint > 0) cutpoint else NULL)`.
3. `data_clust <- cbind.data.frame(mca$call$X, clust = factor(fit$cluster))`;
   `desc <- phenotype_catdes(data_clust, row_w = mca$call$row.w.init)` — a thin wrapper
   that passes `html.table = FALSE` only when the installed `catdes` has that formal,
   and returns `category` / `quanti` with the quanti table restricted to the six 2.13
   columns so the served `quanti_sup_var` shape does not depend on the package version.
4. The tibble assembly is unchanged except that it reads `data_clust` / `desc` instead
   of `mca_hcpc$data.clust` / `mca_hcpc$desc.var`.
5. Attributes: `data_driven_k` (unchanged) plus `consolidation` = `fit$landscape`
   augmented with `k_ward_ratio_curve`.

The HCPC call and its long `kk = Inf` comment go away; `kk` no longer exists as a
concept because there is no pre-partitioning path. `hcpc_kk = "Inf"` stays in the
validation block and bundle params as a frozen compatibility value meaning "full Ward
tree, consolidation ran".

### Validator (`validate_phenotype_clusters`)

- Per-k reruns and subsample reruns already call `gen_mca_clust_obj`, so they inherit
  the procedure by construction (issue item 4). No separate code path to keep in sync.
- New additive fields in `partition`: `procedure_version`, `k_rule =
  "ward_within_inertia_ratio_min"`, `k_ward_ratio_curve` (the *actual* selector curve,
  k = 3..min(25, n-1) — until now only the post-hoc `k_decision_curve` was served),
  `consolidation_landscape`, `factominer_version`.
  `k_selection_metric` keeps its value. `validation_schema_version` -> `"2.1"`.
- `ncp` diagnostic: eigenvalues come from a dedicated full-spectrum
  `FactoMineR::MCA(..., ncp = Inf)` (full SVD on every version, ~60 columns, negligible
  cost) instead of the clustering MCA's `eig`, so 2.17's truncation cannot degrade it.
- Resample cost: each of the ~110 reruns now does `n_starts` extra k-means fits
  (~0.14 s per 100 starts at n = 2,017) — about 15 s added to a refresh that already
  takes minutes.

### Landscape block (`partition_validation$consolidation_landscape`)

```
n_starts_total, n_random_starts, seed, iter_max, algorithm = "Hartigan-Wong",
n_converged, basin_ari_threshold,
chosen      = { start = "ward_cut" | "random", start_index, within_inertia,
                n_starts_in_basin, share_of_starts },
ward_start  = { within_inertia, ari_vs_chosen, in_chosen_basin },
n_distinct_partitions,           # exact-label distinct solutions (micro-variants count)
n_basins,                        # after ARI >= basin_ari_threshold grouping
basins      = [ up to 5: { rank, best_within_inertia, n_starts, share_of_starts,
                           ari_vs_chosen, sizes } ],
runner_up   = { within_inertia, share_of_starts, ari_vs_chosen } | null,
inertia_gap_relative             # (runner_up - chosen) / chosen, null if one basin
```

Basins: solutions sorted by the selection order; each joins the first existing basin
whose representative it matches at ARI >= 0.90, else it opens a new basin. 0.90 sits
between the observed micro-variant range (0.94-0.99) and the cross-basin value (0.35).
Inertias are W/n, the scale used everywhere else in the block.

### Continuity against the previous snapshot

New `analysis_snapshot_phenotype_continuity(clusters, conn)` in
`analysis-snapshot-coherence.R` (the file that already owns partition provenance),
called by the builder before activation. It reads the current public-ready
`phenotype_clusters` snapshot's `analysis_snapshot_cluster_member` rows and reports
`{ status, previous_snapshot_id, n_common_entities, ari, per_cluster_best_jaccard }`
into `partition_validation$continuity`. Best-effort: any failure yields
`status = "unavailable"` with a message and never fails the refresh. Excluded from
`payload_hash` like the rest of `partition_validation`.

### Provenance

- `analysis_snapshot_phenotype_applied_params()` gains `procedure_version`, `k_rule`,
  `k_min`, `k_max`, `consolidation_method = "multistart_kmeans"`, `consolidation_n_starts`,
  `consolidation_seed`, `consolidation_iter_max`, `kmeans_algorithm`,
  `factominer_version`, `r_version`. (`library_versions` in the generator block already
  records FactoMineR and R; the issue asks for them *next to* ncp/kk/seed.)
- The reproducibility bundle `params` gains the same consolidation fields plus the
  chosen `within_inertia`, so a consumer can re-run and check the optimum from the
  bundle alone.
- `CLUSTER_LOGIC_VERSION` -> `"2026-09-21.679-multistart"`. The phenotype cache
  fingerprint additionally folds in `ANALYSIS_PHENOTYPE_CONSOLIDATION_STARTS`, because
  it changes membership.

### FactoMineR 2.13 -> 2.17

- `renv.lock`: FactoMineR 2.17 plus the newly imported `irlba`, `showtext`,
  `sysfonts`, `showtextdb`. 2.17 post-dates the pinned Posit snapshot (2026-05-08) that
  `RENV_CONFIG_REPOS_OVERRIDE` forces, and moving that date is a full dependency
  refresh (out of scope). FactoMineR is therefore locked as a URL remote to an
  immutable dated Posit source URL; the four new imports are ordinary records at their
  2026-05-08 versions. Gate: the API image must build and the phenotype tests must pass
  inside it. If the build cannot be made green without a general refresh, the bump is
  split into a follow-up PR and this PR keeps 2.13 with a call-site comment — the
  decoupling (goal 2) is what makes either order safe.
- Version-independence is enforced in code (`phenotype_catdes`, full-spectrum eig), not
  assumed.

### Deploy

Standard membership-change runbook (skill `sysndd-analysis-snapshots`): restart
`worker` + `worker-maintenance`, forced snapshot refresh, forced LLM regenerate.
Membership changes, so `cluster_hash` changes and summaries regenerate — expected.
PC labels may be renumbered relative to snapshot 196 but realign with snapshot 144.

## Error handling

- `kmeans` warnings (non-convergence, Quick-TRANSfer) are captured per start and
  surfaced as `converged = FALSE` / `n_converged`; they never abort clustering.
- A start that errors is recorded as failed and excluded; the Ward-cut start failing
  is a hard error (it is the legacy procedure and must always work).
- n < 4 or fewer than 2 distinct rows -> explicit `stop()` with a clear message (today
  HCPC fails opaquely).
- Continuity and landscape are additive diagnostics: failure degrades to a status
  field, mirroring `missingness_sensitivity`.

## Testing

Host-runnable (base R only):

1. `test-unit-phenotype-consolidation.R` — k rule on a hand-built inertia vector;
   selection order (converged first, tolerance ties -> Ward start, then seed order);
   duplicate-row inputs; label ordering by first-coordinate centroid; determinism
   (two calls identical); landscape basin grouping on a constructed two-basin input.
2. `test-unit-phenotype-consolidation-snapshot196.R` — regression fixture
   `fixtures/phenotype-snapshot196-coords.csv.gz` (public bundle coordinates + served
   membership): k = 3; Ward start W/n = 0.3603; chosen W/n = 0.3530 and <= every
   start; sizes within +-10 of 1121/555/341; ARI(chosen, served) < 0.5; two basins;
   `ward_start$in_chosen_basin` is FALSE; `n_starts = 0` reproduces the served
   membership at ARI 1.00; deletion-perturbation ARI >= 0.95.

Container-only (`skip_if_not_installed("FactoMineR")`):

3. HCPC parity: `n_starts = 0` equals `FactoMineR::HCPC(nb.clust = k)` partition and
   `desc.var` on the synthetic fixture — on whichever FactoMineR is installed.
4. Package-drift guard: fixed synthetic input -> asserted k, a coordinate checksum
   at 1e-8, asserted partition sizes and the 6-column quanti shape.
5. Existing `test-unit-phenotype-hcpc-k.R` (source-text assertions updated),
   `test-unit-phenotype-validation-crossaxis.R` (anchor invariant + new fields),
   provenance and reproducibility tests extended for the new params.
6. Continuity helper against a stubbed query function plus one real-schema integration
   test (`with_test_db_transaction`) because mocked tests cannot see SQL.

End-to-end: build the image, run the real `validate_phenotype_clusters` +
`gen_mca_clust_obj` on a production-shaped synthetic matrix under 2.13 and 2.17 and
confirm identical k, membership and curve anchor.

## Docs

`sysndd-analysis-snapshots` skill (`SKILL.md` + `references/cluster-soundness-508-512.md`),
`documentation/08-development.qmd` / `09-deployment.qmd` where the phenotype procedure
and the refresh runbook are described, `CHANGELOG.md`, and the file-size baseline if
any touched file crosses the ceiling.

## Findings during implementation

1. **The legacy k rule was numerically fragile on duplicated profiles.** When the input
   has few distinct phenotype profiles (the existing test fixtures: two or three crisp
   blocks), W(k) beyond the number of distinct rows is SVD noise at ~1e-33, and
   `W(k)/W(k-1)` on that noise picked an arbitrary k: FactoMineR 2.13 `HCPC` returned
   **seven** clusters (60/1/1/1/19/37/1) for a two-block input, masked only by the
   `min_size` drop. `phenotype_select_k()` therefore zeroes within-inertia below 1e-12 of
   the total (0/0 ratios are `NA` and ignored) and caps k at the number of rows that are
   distinct on a scale-relative 10-decimal grid; random starts draw from those rows. On
   real data (no zero W in 3..25) the rule is unchanged, which the HCPC parity test and
   the snapshot-196 regression both confirm.
2. **`consolidation_method`, not `consolidation`.** The reproducibility bundle already has
   a boolean `consolidation` key; the procedure params use `consolidation_method =
   "multistart_kmeans"` so no existing key changes type.
3. **`base::exists()` in the RNG guard.** The live runtime masks `exists()`/`get()` with S4
   generics that reject `inherits =`; the repository's static guard caught the bare call.
   The end-to-end check was then repeated with the full worker library set attached
   (51 packages, `get` masked by `config`) under FactoMineR 2.17.
4. **FactoMineR 2.17 verified end to end.** The image builds with the URL-remote record;
   MCA coordinates, k, membership, inertia, per-cluster Jaccard, the curve anchor and the
   1/Q ncp diagnostic are identical under 2.13 and 2.17 on a 2,000 x 30 synthetic matrix.
   Multi-start clustering costs ~0.2-0.6 s versus ~0.1 s single-start at that size.
5. **An external plan review could not be run** (the reviewing service was over its usage
   limit); the diff was reviewed by an independent agent instead.
