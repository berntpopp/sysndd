# Missingness-aware positive-only sensitivity validation for phenotype clustering (#582)

- **Issue:** berntpopp/sysndd#582
- **Date:** 2026-07-19
- **Type:** Additive validation metric (no membership / `cluster_hash` change)
- **Subsystem:** Analysis snapshots — phenotype MCA/HCPC axis (#508–#514 family)

## 1. Problem

The phenotype-clustering input collapses **unrecorded / unknown** HPO annotations into
an explicit **absent** category:

- `generate_phenotype_cluster_input()` keeps only `modifier_name == "present"` rows and
  pivots them to a wide `{"yes", NA}` matrix
  (`api/functions/analysis-phenotype-functions.R`).
- `phenotype_mca_prep_matrix()` recodes `"yes" -> present` and every `NA -> absent`
  (`api/functions/analysis-phenotype-mca-prep.R`), then MCA/HCPC/silhouette/dip/resampling
  all operate on that complete present/absent representation.

In the curation data, the absence of a recorded `present` annotation generally means
**not recorded / unknown**, not confirmed clinical absence. The served partition is
therefore a partition of *recorded annotation profiles*, not a direct partition of
clinical phenotype presence/absence. Shared non-recording can contribute to entity
similarity as if it were shared negative evidence, which can inflate similarity between
sparsely annotated entities and make annotation completeness a latent clustering axis.

This is an **interpretation limit**, not a proof the partition is wrong. We add a
**sensitivity analysis** that uses only positive annotations and never rewards a pair for
shared unrecorded terms, and we report how well the served partition survives that
stricter, evidence-only representation.

## 2. Goals / Non-goals

**Goals**
- Add an additive **positive-only Jaccard sensitivity** to `validate_phenotype_clusters()`,
  stored under `partition_validation$missingness_sensitivity`.
- Keep the served MCA/HCPC partition byte-identical (no membership, `cluster_hash`, or LLM
  summary change).
- Ship a tested, deterministic, self-contained helper.
- Correct the provenance/documentation language: unrecorded cells are **not recorded /
  unknown**, not confirmed absent.

**Non-goals**
- Replacing the primary MCA/HCPC partition.
- Treating unrecorded annotations as confirmed clinical absence (the primary MCA encoding
  is unchanged; only its *documented semantics* are clarified).
- Touching the functional axis, phenotype-functional correlation, or the reproducibility
  bundle (`reproducibility_hash` stays unchanged, so #573 releases are unaffected).
- Any manuscript text.

## 3. Key design insight — reuse the matrix the validator already has

`validate_phenotype_clusters(wide_phenotypes_df, ...)` already receives the **encoded active
matrix** produced by `phenotype_mca_prep_matrix()`:

- Columns `c(quali_sup_var, quanti_sup_var)` (default `1` and `2:4`) are the supplementary
  columns (inheritance name + 3 count columns).
- Every other column is an **active HPO term** coded as a factor with levels
  `c("absent", "present")` — i.e. after the same Definitive-entity, active-review,
  HPO-root, and prevalence filters used by the primary analysis.

So the **positive-term set** of an entity is exactly the active columns whose cell is
`present`:

```
A(entity) = { active_term : matrix[entity, active_term] %in% c("present", "yes") }
```

(`"yes"` is accepted as a defensive fallback so the helper also works if handed a raw,
pre-encoding matrix in a test.) This gives us, **for free and by construction**:

- the same eligible entities as the served analysis (AC5),
- the same active phenotype-term set as the served analysis (AC5),
- no shared-unrecorded contribution — `absent` cells simply never enter any set.

No new DB query, no re-plumbing of the raw `{yes, NA}` matrix.

## 4. Algorithm

Computed over the **assigned entities of the served visible partition** — the entities
that appear in `ref_members` (`unlist(ref_members)`), i.e. the same entity set the served
silhouette and ARI are defined on. Sub-`min_size` unassigned entities are excluded exactly
as they already are from the served silhouette.

### 4.1 Positive sets and Jaccard dissimilarity

For eligible entities with positive sets `A`, `B`:

```
J(A, B) = |A ∩ B| / |A ∪ B|
d(A, B) = 1 - J(A, B)
```

Efficient, vectorized construction (no O(n²) R loop):

1. Build a binary incidence matrix `X` (assigned entities × active terms; `1` = present),
   rows sorted by `entity_id` for a stable, reproducible order.
2. `inter = X %*% t(X)` (pairwise intersection sizes); `sizes = rowSums(X)`.
3. `union[i,j] = sizes[i] + sizes[j] - inter[i,j]`.
4. `J = inter / union`; **`union == 0 → J = 0 → d = 1`**.

### 4.2 Empty-set semantics (explicit — AC4)

- `d(A, A) = 0` on the diagonal (a `dist` diagonal is always 0).
- `d(∅, B≠∅) = 1` naturally (`|∩| = 0`).
- **`d(∅, ∅) = 1`** for two *different* entities that both carry zero positive evidence —
  they are treated as maximally dissimilar, **never** as a zero-distance (identical) pair.
  This is the `union == 0 → d = 1` rule above.
- `n_empty_positive_sets` (count of assigned entities with an empty active positive set) is
  recorded in provenance. Empty positive sets can genuinely occur — an entity all of whose
  recorded terms fell outside the prevalence band still gets an MCA position and an HCPC
  cluster.

### 4.3 Sensitivity clustering (deterministic — AC6)

- `hc = stats::hclust(stats::as.dist(D), method = "average")` — average-linkage
  hierarchical clustering; accepts a non-Euclidean dissimilarity; deterministic (no RNG).
- `sens_labels = stats::cutree(hc, k = n_clusters)` where `n_clusters` = the **served
  visible phenotype-cluster count** (`length(ref_members)`). Fixing `k` tests representation
  sensitivity, not cluster-number re-selection (AC per issue step 4).

### 4.4 Comparison metrics vs the served partition (AC7)

Let `served_labels` be the served visible cluster assignment for the same assigned
entities, aligned to the incidence-matrix row order.

1. **Adjusted Rand Index** — hand-rolled `adjusted_rand_index(served_labels, sens_labels)`
   (Hubert & Arabie 1985; contingency table + `choose(·, 2)` sums). Degenerate case (either
   side a single cluster) → `NA_real_` with a documented reason. No new dependency.
2. **Per-served-cluster maximum Jaccard recovery** — reuse the existing
   `cluster_max_jaccard(reference_members = served ref_members,
   bootstrap_clusters = split(assigned_entities, sens_labels), present_ids = assigned_entities)`.
   Keyed by `cluster_id`, matching the served cluster labels.
3. **Jaccard-space mean silhouette** — `cluster::silhouette(labels_int, as.dist(D))`:
   - `silhouette_served_partition` (headline): silhouette of the **served** partition in
     positive-only Jaccard space — does the served partition stay internally cohesive under
     evidence-only distances?
   - `silhouette_sensitivity_partition` (secondary, cheap): silhouette of the sensitivity
     partition in the same space, for context.

### 4.5 Result shape (`partition_validation$missingness_sensitivity`)

```r
list(
  status = "ok",                                   # "ok" | "skipped" | "error" | "undefined_lt2_clusters"
  data_class = "curated_derived_analysis",
  method = "positive_only_jaccard",
  linkage = "average",
  distance = "one_minus_jaccard",
  encoding_semantics = "present/not_recorded",     # absent MCA level == not recorded, NOT confirmed absent
  empty_union_distance = 1,                         # explicit ∅,∅ handling
  k = <n_clusters>,                                 # fixed to served visible cluster count
  n_entities = <n_assigned>,
  n_active_terms = <#active columns>,
  n_empty_positive_sets = <count>,
  adjusted_rand_index = <double | NA>,
  per_cluster_max_jaccard = list("<cluster_id>" = <double|NA>, ...),
  silhouette_served_partition = <double | NA>,
  silhouette_sensitivity_partition = <double | NA>,
  interpretation = "<band>"                         # ARI band: e.g. ari>=0.75 strong agreement, etc.
)
```

`status = "undefined_lt2_clusters"` when `n_clusters < 2` (ARI/silhouette undefined) —
mirrors the served silhouette's own guard. `status = "skipped"` when env-disabled.

## 5. Placement, wiring, and additivity

### 5.1 New file (single responsibility, < 600 lines)

`api/functions/analysis-phenotype-missingness.R` — self-contained, testable in isolation:

- `phenotype_positive_sets_from_matrix(matrix, active_cols)` → named list entity → char vec.
- `positive_jaccard_dissimilarity(positive_sets, entity_order)` → symmetric matrix `D`
  (attaches `n_empty_positive_sets`).
- `adjusted_rand_index(a, b)` → double.
- `phenotype_missingness_sensitivity(wide_phenotypes_df, ref_members, quali_sup_var,
  quanti_sup_var)` → the result list in §4.5 (the orchestrator).

Registered in `api/bootstrap/load_modules.R` **before** `functions/analysis-cluster-validation.R`
(the validator calls it), and in `api/bootstrap/setup_workers.R`'s `everywhere()` block
(also before `analysis-cluster-validation.R`, ~line 98) for mirai parity — both entrypoints
already source the sibling `analysis-*` files.

### 5.2 Validator integration (`analysis-cluster-validation.R`)

Inside `validate_phenotype_clusters()`, after `ref_members` / `ent_to_cluster` /
`entity_ids` are established, add a best-effort block (mirroring the `ncp_diag` / `kg`
patterns):

```r
missingness <- if (identical(tolower(Sys.getenv(
      "ANALYSIS_PHENOTYPE_MISSINGNESS_SENSITIVITY", "true")), "true") &&
    exists("phenotype_missingness_sensitivity", mode = "function")) {
  tryCatch(
    phenotype_missingness_sensitivity(wide_phenotypes_df, ref_members,
                                      quali_sup_var, quanti_sup_var),
    error = function(e) list(status = "error", message = conditionMessage(e))
  )
} else {
  list(status = "skipped")
}
```

Then add `missingness_sensitivity = missingness` to the `partition = list(...)` return.
A failure degrades to a diagnostic field; it **never** fails the snapshot refresh.

### 5.3 Why this is additive (no `cluster_hash` churn)

- The field lives in `val$partition` → `partition_validation` →
  `analysis_snapshot_build_payload` excludes `partition_validation` (and `reproducibility`)
  from `payload_hash` (builder ~line 503). So `payload_hash` / `cluster_hash` are unchanged.
- The **coherence gate** reads `val$per_cluster` (cluster-id set, stability scores,
  `reference_members`), never `val$partition`. We touch none of those. Gate unaffected.
- `analysis_snapshot_attach_partition_provenance()` mutates `partition$membership_weight_channel`
  and `partition$reference_members` only — it preserves `missingness_sensitivity`.
- The service read path returns the whole `validation_json` blob as
  `meta.snapshot.validation`, so `missingness_sensitivity` surfaces at
  `meta.snapshot.validation.missingness_sensitivity` with **zero endpoint changes** (AC7).
  `validation_hash` (already served) changes when validation changes — the intended signal.
- `reproducibility` bundle untouched → `reproducibility_hash` unchanged → #573 releases
  unaffected.

## 6. Documentation & provenance language (AC10)

- New file header + orchestrator roxygen state: `absent` in the primary MCA encoding means
  **not recorded / unknown**, not confirmed clinical absence; the sensitivity uses positive
  evidence only.
- `missingness_sensitivity$encoding_semantics = "present/not_recorded"`.
- Update `AGENTS.md` (the #508–#514 cluster-soundness section) with a short paragraph on the
  additive missingness sensitivity, its additivity guarantees, and the deploy note.
- Update `documentation/` analysis/snapshot docs where the phenotype validation block is
  described, to say unrecorded cells are unknown/not recorded.

## 7. Tests

New `api/tests/testthat/test-unit-phenotype-missingness.R` (unit, host-runnable, no DB):

- **Jaccard core**
  - identical positive sets → `d = 0` (AC2).
  - disjoint positive sets → `d = 1` **regardless of how many terms are jointly unrecorded**
    (two entities, one distinct active term each, out of many active columns) (AC3).
  - `d(∅, ∅) = 1` and `d(∅, B) = 1`; no artificial zero-distance pair (AC4).
  - partial overlap → exact `1 - |∩|/|∪|`.
- **`adjusted_rand_index`**: identical labelings → 1; independent labelings ≈ 0; degenerate
  single-cluster → `NA`.
- **Orchestrator** on a small synthetic encoded matrix with a known 2-cluster positive-set
  structure: `status == "ok"`, `k` == served cluster count, ARI/per-cluster-Jaccard/both
  silhouettes present, `n_active_terms` / `n_entities` / `n_empty_positive_sets` correct
  (AC5, AC6, AC7).
- **Determinism** (AC6): two runs on the same input return identical results.
- **Positive-set extraction ignores supplementary columns** and unrecorded (`absent`/`NA`)
  cells (AC1).

Extend `api/tests/testthat/test-unit-analysis-cluster-validation.R` (or a small focused
guard) to assert:
- `validate_phenotype_clusters(...)$partition$missingness_sensitivity` exists and carries
  `adjusted_rand_index`, `per_cluster_max_jaccard`, `silhouette_served_partition`.
- **Additivity regression (AC8/AC9):** `missingness_sensitivity` is nested under
  `partition` (the `partition_validation` block), which the builder excludes from
  `payload_hash`; a guard asserts the field name is in the excluded set so it can never
  enter `payload_hash` / `cluster_hash`. Coherence continues to run through
  `analysis_snapshot_join_validated_clusters()` unchanged.

The existing heavy validator test uses `FactoMineR::MCA`/`gen_mca_clust_obj`; keep the new
orchestrator test decoupled from FactoMineR by testing `phenotype_missingness_sensitivity`
with a hand-built `ref_members` + matrix so it runs fast on the host.

## 8. Deployment (additive — AC per issue "Deployment notes")

Primary membership is unchanged, so:

- **Do not** bump `CLUSTER_LOGIC_VERSION`.
- Restart `worker` **and** `worker-maintenance` (worker-executed validator/new file).
- `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true`
  to persist the new validation fields (`force` required — a non-forced refresh skips an
  `available` snapshot).
- **Do not** regenerate LLM summaries (cluster hashes are unchanged; a forced regen is
  wasteful — the batch log will show "all cached").

If — contrary to plan — the primary matrix/membership ends up changing, treat it as a
clustering-logic change: bump `CLUSTER_LOGIC_VERSION`, restart workers, force-refresh, pass
the coherence gate, and regenerate summaries. (This spec is designed so that never happens.)

## 9. Acceptance-criteria traceability

| # | Acceptance criterion | Covered by |
|---|----------------------|------------|
| 1 | Tested positive-only Jaccard helper, no double-unrecorded counting | §4.1, §7 Jaccard core + extraction test |
| 2 | Identical positive sets → distance 0 | §4.2, §7 |
| 3 | Disjoint sets → distance 1 regardless of joint unrecorded | §4.1 `union==0→d=1` + non-shared terms never counted; §7 |
| 4 | Empty / one-empty explicit, no artificial zero | §4.2, §7 |
| 5 | Same eligible entities + active term set as served | §3 (reuses served matrix + `ref_members`) |
| 6 | Deterministic; records algorithm, fixed k, entity/term counts, exclusions | §4.3, §4.5, §7 determinism |
| 7 | Exposes ARI, per-cluster max Jaccard, Jaccard-space mean silhouette | §4.4, §4.5, §5.3 (auto-surfaced) |
| 8 | Coherence still enforced via `analysis_snapshot_join_validated_clusters()` | §5.3 |
| 9 | Regression: sensitivity does not change primary membership / cluster hash | §5.3, §7 additivity guard |
| 10 | Docs say unrecorded cells are unknown/not recorded, not confirmed absent | §6 |

## 10. Files

- **New:** `api/functions/analysis-phenotype-missingness.R`
- **New:** `api/tests/testthat/test-unit-phenotype-missingness.R`
- **Edit:** `api/functions/analysis-cluster-validation.R` (call + attach field)
- **Edit:** `api/bootstrap/load_modules.R` (+ `setup_workers.R` if parity needed)
- **Edit:** `api/tests/testthat/test-unit-analysis-cluster-validation.R` (additivity guard)
- **Edit:** `AGENTS.md`, `documentation/` analysis/snapshot docs

## 11. Open question flagged for review

- **§4.4 silhouette definition.** The issue lists "mean silhouette calculated on the
  positive-only Jaccard dissimilarity" as one comparison. A silhouette needs a labeling; the
  chosen headline is the **served** partition's silhouette in Jaccard space (measures whether
  the served partition survives evidence-only distances), with the sensitivity partition's
  silhouette reported secondarily. Confirm this is the intended semantics, or whether only
  one of the two should be the headline.
