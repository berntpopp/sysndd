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
- Touching the functional axis code, phenotype-functional correlation **logic**, or the
  reproducibility bundle. `reproducibility_hash`, `payload_hash`, and cluster hashes stay
  unchanged. **Caveat (Codex #1):** the deploy still force-refreshes the correlation
  snapshot to re-pin its phenotype dependency lineage (§8), because *any* phenotype refresh
  mints a new integer phenotype `snapshot_id` and supersedes the old row
  (`analysis_snapshot_activate`), and the correlation layer's #571/#572 dependency gate
  pins the phenotype `snapshot_id` **and** `payload_hash`
  (`analysis-snapshot-dependencies.R:215-225`) — so an unchanged `payload_hash` is not
  enough. Existing **published** #573 releases stay immutable; a *new* release built after
  this deploy may receive a different `content_digest` because the pinned dependency
  `snapshot_id`s changed.
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

Note the naming: because `d(∅, ∅) = 1` breaks the Jaccard identity axiom, provenance
labels this a **modified positive-only Jaccard dissimilarity**
(`distance = "one_minus_jaccard_modified"`), not the standard metric (Codex non-blocking
#10).

### 4.3 Non-informative distance guard (Codex BLOCKING #2)

Before clustering, inspect the strict lower triangle of `D`. If it contains **only one
unique finite value** (all-empty positive sets → all `1`; all-identical sets → all `0`;
all pairwise-disjoint sets → all `1`), the dissimilarity carries **no evidence-defined
merge order**: `hclust` still returns a deterministic tree, but the cut — and therefore
ARI and per-cluster recovery — is an artifact of entity-ID tie order, not phenotype
structure. In that case:

- return `status = "undefined_no_distance_structure"` with the diagnostic counts,
- do **not** report `adjusted_rand_index` or `per_cluster_max_jaccard` (they would be
  misleading; leave `NA` / empty),
- optionally still report `silhouette_served_partition` (well-defined on `D` regardless),
  labeled with the status.

### 4.4 Sensitivity clustering (deterministic — AC6)

- `hc = stats::hclust(stats::as.dist(D), method = "average")` — average-linkage
  hierarchical clustering; accepts a non-Euclidean dissimilarity; deterministic (no RNG).
- `sens_labels = stats::cutree(hc, k = n_clusters)` where `n_clusters` = the **served
  visible phenotype-cluster count** (`length(ref_members)`). Fixing `k` tests representation
  sensitivity, not cluster-number re-selection (AC per issue step 4).
- Determinism is **conditional on the explicit entity sort** (§4.1 step 1): the same input
  under a row permutation yields the same result. This is asserted by a test.

### 4.5 Comparison metrics vs the served partition (AC7)

Let `served_labels` be the served visible cluster assignment for the same assigned
entities, aligned to the incidence-matrix row order.

1. **Adjusted Rand Index** — hand-rolled `adjusted_rand_index(served_labels, sens_labels)`
   (Hubert & Arabie 1985; contingency table + `choose(·, 2)` sums). The degeneracy rule is
   **denominator-based, not single-cluster-based** (Codex non-blocking #5):
   `ari = (index - expected) / (max_index - expected)`, and return `NA_real_` **iff**
   `max_index == expected` (the adjustment denominator is zero — e.g. both labelings are a
   single cluster, or otherwise non-adjustable). Validate equal label lengths. No new
   dependency.
2. **Per-served-cluster maximum Jaccard recovery** — reuse the existing
   `cluster_max_jaccard(reference_members = served ref_members,
   bootstrap_clusters = split(assigned_entities, sens_labels), present_ids = assigned_entities)`.
   Keyed by `cluster_id`, matching the served cluster labels.
3. **Jaccard-space mean silhouette** — `cluster::silhouette(labels_int, as.dist(D))`:
   - `silhouette_served_partition` (headline): silhouette of the **served** partition in
     positive-only Jaccard space — does the served partition stay internally cohesive under
     evidence-only distances?
   - `silhouette_sensitivity_partition` (secondary, cheap): silhouette of the sensitivity
     partition in the same space, for context (average linkage did not optimize silhouette,
     so it is descriptive only).

   **Headline decision (resolves §11):** `silhouette_served_partition` is the headline —
   it directly answers the scientific question (does the *served* partition stay cohesive
   under positive-only evidence?). Confirmed by Codex.

### 4.6 Result shape (`partition_validation$missingness_sensitivity`)

```r
list(
  status = "ok",           # "ok" | "skipped" | "error" |
                           # "undefined_lt2_clusters" | "undefined_no_distance_structure"
  data_class = "curated_derived_analysis",
  method = "positive_only_jaccard",
  linkage = "average",
  distance = "one_minus_jaccard_modified",         # d(∅,∅)=1 breaks Jaccard identity axiom
  encoding_semantics = "present/not_recorded",     # absent MCA level == not recorded, NOT confirmed absent
  empty_union_distance = 1,                         # explicit ∅,∅ handling
  k = <n_clusters>,                                 # fixed to served visible cluster count
  n_entities_input = <matrix row count>,           # eligibility accounting (Codex #3)
  n_entities_assigned = <n_assigned>,              # == entities scored (in a served cluster)
  n_entities_excluded_unassigned = <input - assigned>,  # sub-min_size, exclusion reason recorded
  n_active_terms = <#active columns>,
  n_empty_positive_sets = <count>,
  adjusted_rand_index = <double | NA>,
  per_cluster_max_jaccard = list("<cluster_id>" = <double|NA>, ...),
  silhouette_served_partition = <double | NA>,
  silhouette_sensitivity_partition = <double | NA>,
  interpretation = "<band>"                         # ARI band: e.g. ari>=0.75 strong agreement, etc.
)
```

Status semantics:
- `"undefined_lt2_clusters"` — `n_clusters < 2` (ARI/silhouette undefined); mirrors the
  served silhouette's own guard.
- `"undefined_no_distance_structure"` — §4.3 non-informative distance guard tripped.
- `"skipped"` — env-disabled.
- `"error"` — `tryCatch` caught a failure (carries a `message`); never fails the refresh.

## 5. Placement, wiring, and additivity

### 5.1 New file (single responsibility, < 600 lines)

`api/functions/analysis-phenotype-missingness.R` — self-contained, testable in isolation:

- `phenotype_active_terms(matrix, quali_sup_var, quanti_sup_var)` → the active-term column
  names. **Authoritative source is `attr(matrix, "mca_provenance")$kept_terms`** (Codex
  non-blocking #2 — the validator already reads this attribute at
  `analysis-cluster-validation.R:242`); the positional complement
  `setdiff(names(matrix), names(matrix)[c(quali_sup_var, quanti_sup_var)])` is a **validated
  fallback** for test matrices lacking the attribute. Both must intersect the actual columns.
- `phenotype_positive_sets_from_matrix(matrix, active_cols)` → named list entity → char vec
  (cells `%in% c("present", "yes")`); ignores supplementary and `absent`/`NA` cells.
- `positive_jaccard_dissimilarity(positive_sets, entity_order)` → symmetric matrix `D`
  (attaches `n_empty_positive_sets`).
- `adjusted_rand_index(a, b)` → double (denominator-based degeneracy rule, §4.5).
- `phenotype_missingness_sensitivity(wide_phenotypes_df, ref_members, quali_sup_var,
  quanti_sup_var)` → the result list in §4.6 (the orchestrator). Before scoring it asserts
  **alignment invariants** (Codex non-blocking #4): unique matrix row names, unique
  membership ids across `ref_members`, no entity in two clusters, and every `ref_members`
  id present as a matrix row. A violated invariant → `status = "error"` (never a silent
  mislabeling).

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
- The **coherence gate** decides on `val$per_cluster` (cluster-id set, stability scores) and
  `val$reference_members`. It does read one field of `val$partition` —
  `val$partition$weight_channel` (`analysis-snapshot-coherence.R:243`), which is `NULL` on
  the phenotype axis so the channel check is skipped — but it never reads or is affected by
  `missingness_sensitivity`. We touch none of the gate's inputs. Gate unaffected. (Codex
  corrected my earlier "never reads val$partition" wording; the correction is harmless.)
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

New `api/tests/testthat/test-unit-phenotype-missingness.R` (unit, host-runnable, no DB;
decoupled from FactoMineR — hand-built `ref_members` + encoded matrix so it runs fast):

- **Jaccard core**
  - identical positive sets → `d = 0` (AC2).
  - disjoint positive sets → `d = 1` **regardless of how many terms are jointly unrecorded**
    (two entities, one distinct active term each, out of many active columns) (AC3).
  - `d(∅, ∅) = 1` and `d(∅, B) = 1`; no artificial zero-distance pair (AC4).
  - partial overlap → exact `1 - |∩|/|∪|`.
- **Non-informative distance guard (Codex BLOCKING #2):** all-empty, all-identical, and
  all-disjoint positive-set universes each → `status == "undefined_no_distance_structure"`,
  `adjusted_rand_index`/`per_cluster_max_jaccard` **not** reported (NA/empty), no error.
- **`adjusted_rand_index`**: identical labelings → 1; independent labelings ≈ 0; denominator
  -zero degeneracy (both single-cluster) → `NA`; unequal label lengths → error/guard (Codex
  non-blocking #5).
- **Orchestrator** on a small synthetic encoded matrix with a known 2-cluster positive-set
  structure: `status == "ok"`, `k` == served cluster count, ARI/per-cluster-Jaccard/both
  silhouettes present, `n_active_terms` / `n_entities_*` / `n_empty_positive_sets` correct
  (AC5, AC6, AC7). `per_cluster_max_jaccard` keyed by the served `cluster_id`s.
- **Eligibility accounting (Codex #3):** a fixture with sub-`min_size` unassigned entities →
  `n_entities_input > n_entities_assigned`, `n_entities_excluded_unassigned` correct.
- **Alignment invariants (Codex #4):** duplicate row name / entity in two `ref_members`
  clusters / `ref_members` id absent from matrix → `status == "error"`.
- **Determinism (AC6):** two runs identical; **row-permuted** input yields identical results
  (permutation-invariance from the explicit sort); tie-heavy duplicated profiles and
  numeric-string entity IDs are stable.
- **Positive-set extraction (AC1):** ignores the four supplementary columns and unrecorded
  (`absent`/`NA`) cells; uses `mca_provenance$kept_terms` when present, positional fallback
  otherwise.
- **Production-shape extraction (Codex #8):** a raw `{yes, NA}` frame with the real four
  supplementary columns → `phenotype_mca_prep_matrix()` → extract sets, proving the
  end-to-end column-layout claim (not just a hand-built encoded fixture).

Extend `api/tests/testthat/test-unit-analysis-cluster-validation.R` (or a small focused
guard):
- `validate_phenotype_clusters(...)$partition$missingness_sensitivity` exists and carries
  `adjusted_rand_index`, `per_cluster_max_jaccard`, `silhouette_served_partition`; coherence
  still runs through `analysis_snapshot_join_validated_clusters()` unchanged.
- **Additivity regression, corrected (AC8/AC9 — Codex #1 non-blocking):** the earlier
  "assert the field name is in the excluded set" was wrong — only the **top-level**
  `partition_validation` key is excluded, not nested field names. Instead build two payloads
  that differ **only inside** `partition_validation$missingness_sensitivity` and assert the
  hash-relevant payload subset (`setdiff(names(payload), c("raw", "partition_validation",
  "reproducibility"))`) — hence `payload_hash` and the per-cluster `cluster_hash`es — are
  **identical**.

Public serialization coverage (Codex #7), in a focused service test:
- Round-trip a validation object carrying `missingness_sensitivity` through the snapshot
  service meta builder; assert it appears at `meta.snapshot.validation.missingness_sensitivity`,
  that `per_cluster_max_jaccard` serializes as a **keyed JSON object**, and that
  `validation_hash` changes while `payload_hash` does not.

## 8. Deployment (additive — AC per issue "Deployment notes")

Primary membership is unchanged, so:

- **Do not** bump `CLUSTER_LOGIC_VERSION`.
- Restart `worker` **and** `worker-maintenance` (worker-executed validator/new file).
- `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true`
  to persist the new validation fields (`force` required — a non-forced refresh skips an
  `available` snapshot).
- **Then** `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_functional_correlations&force=true`
  (Codex BLOCKING #1). The phenotype refresh minted a **new** phenotype `snapshot_id` and
  superseded the old one, so the correlation layer's pinned dependency lineage
  (`snapshot_id` + `payload_hash`, `analysis-snapshot-dependencies.R:215-225`) no longer
  matches and public correlation reads return `dependency_snapshot_mismatch` until the
  correlation snapshot is rebuilt against the new phenotype `snapshot_id`. (Functional is
  untouched, but the correlation preset re-pins both dependencies on rebuild.)
- **Do not** regenerate LLM summaries (cluster hashes are unchanged; a forced regen is
  wasteful — the batch log will show "all cached").
- Existing **published** #573 releases remain immutable; a *new* release built after this
  deploy may get a different `content_digest` because the pinned dependency `snapshot_id`s
  changed.

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
| 6 | Deterministic; records algorithm, fixed k, entity/term counts, exclusions | §4.4, §4.6, §7 determinism |
| 7 | Exposes ARI, per-cluster max Jaccard, Jaccard-space mean silhouette | §4.5, §4.6, §5.3 (auto-surfaced) |
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

## 11. Performance bound (Codex non-blocking #9)

At the Definitive-category scale (~1,900 assigned entities) a dense `n×n` double matrix is
~29 MiB; the vectorized Jaccard and one `hclust` are well within a worker job that already
reclusters 100× on 80% subsamples. **Guardrail:** do not hold `inter`, `union`, `J`, and `D`
alive simultaneously — transform in place (`inter → J → D`) so peak memory is ~1 matrix, not
4. This keeps headroom if the eligible set grows (at 5,000 entities a single matrix is
~190 MiB). The incidence matrix `X` is entities × active terms (~1,900 × ~40), negligible.

## 12. Codex 5.6-sol review — resolution log

Reviewed at `--effort high`, read-only, verified against code. Verdict was **REVISE**; both
blocking findings were confirmed against the source and are now incorporated:

- **BLOCKING #1 (correlation lineage):** §2 caveat, §5.3, §8 runbook step, §7 note.
- **BLOCKING #2 (non-informative distance):** §4.3 guard + `undefined_no_distance_structure`
  status + §7 tests.
- Non-blocking accepted: `mca_provenance$kept_terms` source (§5.1), denominator-based ARI
  rule (§4.5), corrected AC8/AC9 test design (§7), eligibility counts (§4.6), alignment
  invariants (§5.1/§7), determinism/permutation + production-shape + public-serialization
  tests (§7), modified-Jaccard naming (§4.2), performance bound (§11), coherence-gate wording
  correction (§5.3).
- **§4.5 silhouette headline** resolved: `silhouette_served_partition` (Codex-confirmed).
