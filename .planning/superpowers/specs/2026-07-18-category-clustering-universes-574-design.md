# Category-Selected Gene Universes for Functional Clustering (#574) — Design

Date: 2026-07-18
Issue: **#574** — `feat(api): support category-selected gene universes for functional clustering jobs`
Related program: `.planning/superpowers/specs/2026-07-18-analysis-snapshot-releases-573-design.md` (this is the companion slice; here it gets its own focused, adversarial design review).

---

## 1. Summary

Extend the **async** functional-clustering submit endpoint `POST /api/jobs/clustering/submit` with a server-side `category_filter` that derives the clustering gene universe from curated SysNDD confidence categories (e.g. `["Definitive"]`), instead of requiring the client to assemble and submit an explicit HGNC `genes` list. This enables a transparent, reproducible **Definitive-only functional-clustering sensitivity run** whose exact gene universe and analysis fingerprint are recorded for independent audit.

The fixed public snapshot GET (`GET /api/analysis/functional_clustering`) is **unchanged** and remains a fixed snapshot; category-specific results are user-initiated durable jobs, never activated as public-ready snapshots.

## 2. Current behavior (grounded in `api/services/job-functional-submission-service.R`)

`svc_job_submit_functional_clustering(req, res)` — public (no role gate), body params `genes` (optional HGNC list) and `algorithm` (default `leiden`; only `leiden`/`walktrap` accepted, else coerced to `leiden`):

1. **Admission throttle first** (`async_job_submit_admission_guard`, #535 S6) — per-caller submit throttle before any DB/cache work.
2. **Default universe** (no `genes`): `pool %>% tbl("ndd_entity_view") %>% arrange(entity_id) %>% filter(ndd_phenotype == 1) %>% select(hgnc_id) %>% collect() %>% unique() %>% pull(hgnc_id)` — i.e. **distinct HGNC ids over NDD entities** (`ndd_entity_view` is one row per entity; `ndd_phenotype == 1` marks NDD entities). This is the key existing pattern the category resolver mirrors.
3. **STRING id prefetch**: `non_alt_loci_set` (symbol/hgnc_id/STRING_id) collected before the durable boundary (connections can't cross into the worker).
4. **Dedup**: `check_duplicate_job("clustering", list(genes = genes_list, algorithm = algorithm))` → `async_job_service_duplicate()` → hashes the passed params via `async_job_service_request_hash(job_type, payload_json) = sha256(job_type ":" payload_json)` and looks for an **active** job with that `request_hash` (`async_job_repository_find_active_duplicate`). On duplicate → **direct `res$status <- 409`** + `Location` header + a plain JSON body `{error:"DUPLICATE_JOB", ...}` (NOT a classed problem+json error). Note the resolved `genes_list` (not `NULL`) is what gets hashed — so the all-genes default already hashes the full resolved list.
5. **Cache-first**: `memoise::has_cache(gen_string_clust_obj_mem)(genes_list, algorithm)` → if warm, persist a completed job via `async_job_service_store_completed()` (queue `analysis`, priority 50) with payload `{genes, algorithm, category_links, string_id_table}` and result `{clusters, categories, meta:{algorithm, gene_count, cluster_count, cache_hit}}`; return 202.
6. **Capacity guard**: `async_job_capacity_exceeded(async_job_active_count("default"))` → 503 + `Retry-After: 60`.
7. **Submit**: `create_job(operation="clustering", params=list(genes, algorithm, category_links, string_id_table))` → 202.

**Consistency note (must be verified in implementation — see §12):** the dedup check hashes `list(genes, algorithm)` but the *stored* job is submitted via `create_job(... params = list(genes, algorithm, category_links, string_id_table))`. For dedup to ever match, `create_job`/`async_job_service_submit` must compute the stored `request_hash` over the **same identity object** the dup check hashes. The #574 change MUST keep the dup-check params and the stored identity in lock-step (else either dedup silently never matches, or two identical category runs both submit).

## 3. Requested change — request shape

```json
{ "category_filter": ["Definitive"], "algorithm": "leiden" }
```

- `category_filter`: optional array of curated status-category tokens.
- `genes`: existing optional explicit HGNC list (unchanged).
- `algorithm`: unchanged (`leiden` default).

## 4. Semantics (exact)

- **Mutual exclusion**: supplying **both** `genes` and a non-empty `category_filter` → **400** (`stop_for_bad_request`, problem+json). Supplying **neither** → the current all-NDD-genes default (preserved byte-for-byte).
- **Entity-level resolution (the correctness core)**: `["Definitive"]` selects **genes with ≥1 NDD entity whose status category is Definitive**. Because `ndd_entity_view` is **one row per entity**, this is achieved by filtering *entity rows* (`filter(category %in% cats, ndd_phenotype == 1)`) then `distinct(hgnc_id)`. A gene with a Definitive entity **and** a Limited entity **is included**; a gene with only a Limited entity **is excluded**. The resolver **must not** use any gene-level aggregated/display category (a per-gene "max category" label). Filtering entity rows makes the entity-level OR semantics automatic — do not group-to-gene before filtering.
- **Multi-value** `category_filter` = **union**: a gene qualifies if it has ≥1 NDD entity in **any** listed category (`category %in% cats`).
- **Validation**: every token must be an **active** curated status category (`ndd_entity_status_categories_list` where `is_active = 1`). The allowlist is read **live** from the DB, not hardcoded — so a vocabulary edit via `/ManageMetadata` is honored automatically and no code carries stale category strings. Any unknown/inactive token → 400 listing the offending token(s) and the allowed set.
- **Empty / contradictory**: an empty `category_filter` array (or one that normalizes to empty) → 400 (`empty selector`). A selector that validates but resolves to **zero** NDD genes, or fewer than the clustering minimum, → 400 (`empty_or_too_small_universe`) rather than submitting a job over an empty graph.
- **Normalization**: `selector_normalized = sort(unique(trimws(tokens)))`. Used for validation, dedup identity, and provenance.

## 5. Resolver design

New helper `clustering_resolve_category_universe(category_filter, conn = pool)` in a new focused file `api/functions/clustering-gene-universe.R` (registered in `bootstrap/load_modules.R`):

1. If `category_filter` is `NULL`/empty → **reuse the existing factored default** `generate_ndd_hgnc_ids()` (`analyses-functions.R:380-388` — the exact `tbl("ndd_entity_view") |> arrange(entity_id) |> filter(ndd_phenotype == 1) |> select(hgnc_id) |> collect() |> unique()` used by the snapshot path) and `pull(hgnc_id)`. This guarantees byte-identical ordering with today's default → the same `gen_string_clust_obj_mem(genes, algorithm)` cache key (cache parity).
2. Else normalize the selector (`sort(unique(trimws(...)))`); empty after normalization → `stop_for_bad_request("category_filter is empty")`.
3. Read the **active** allowlist: `tbl(conn, "ndd_entity_status_categories_list") |> filter(is_active == 1) |> pull(category)`. (`is_active` exists — added by migration `033`; the values are `Definitive`, `Moderate`, `Limited`, `Refuted`, `not applicable`.) Any token ∉ allowlist → `stop_for_bad_request` naming the offenders + the allowed set.
4. Resolve genes (approved-public surface only), **entity-level**: `tbl(conn, "ndd_entity_view") |> arrange(entity_id) |> filter(ndd_phenotype == 1, category %in% !!selector_normalized) |> select(hgnc_id) |> collect() |> unique() |> pull(hgnc_id)`. Because `ndd_entity_view` is one row per entity, a gene with ≥1 entity in a selected category qualifies even if it has other-category entities. **Do NOT** use `select_network_gene_category()` (`analyses-functions.R:126-135`) — that collapses a gene's entity categories to a single highest-priority *display label* (used only for node coloring in `gen_network_edges`) and would wrongly exclude a gene whose top label is not in the selector. `%in% !!selector_normalized` is dbplyr-parameterized; combined with the allowlist pre-validation, no category string is string-interpolated into SQL (defense in depth).
5. Empty/too-small result → `stop_for_bad_request("resolved universe is empty or too small for clustering")`.
6. Return `list(hgnc_ids = <char>, selector = selector_normalized, resolved_gene_count = length(...))`.

The endpoint refactors submit lines 67–76 to call `clustering_resolve_category_universe(NULL)` for the default too, so the two paths share one helper and can never diverge (mirrors the #508/#509 `phenotype_mca_prep_matrix` one-helper discipline). A test asserts the NULL-branch output is order-identical to the current inline query (cache-parity regression guard).

## 6. Provenance & result contract

Compute at submit time and thread into **both** the durable payload and the result `meta`:

- `selector`: `{ kind: "category" | "explicit" | "all_ndd", category_filter: selector_normalized|null }`
- `resolved_gene_count`: distinct HGNC count
- `gene_list_sha256`: `sha256(canonical(sort(unique(hgnc_ids))))` (sorted for order-independent identity; the issue's "sorted-HGNC-list SHA-256")
- `analysis_fingerprint`: `{ cluster_logic_version: CLUSTER_LOGIC_VERSION (currently "2026-07-06.510-expdb"), source_data_version: analysis_snapshot_source_data_version(), string_weight_channel: attr(clusters, "weight_channel") (exp+db per #510, or "combined_score" fallback), score_threshold: 400 (the fixed `build_string_subgraph` default), algorithm, seed: 42 (the hard-coded `set.seed(42)` in `gen_string_clust_obj`) }`. These are pulled from the existing constants/attrs — #574 does not change any of them; the seed/threshold/channel stay fixed unless explicitly versioned.

The interactive clustering job **currently records none** of these (only `{algorithm, gene_count, cluster_count}`; async-job-handlers.R:111-119) — the determinism lives only in the disk memoise key and the separate snapshot manifest. #574 adds them to the result `meta` **and** the durable payload so a category-scoped sensitivity run is self-describing and reproducible. The durable **payload already carries `genes = <resolved list>`**, so the exact gene universe is an immutable, retrievable job-input record (auditable even after curation changes). The result `meta` is extended from `{algorithm, gene_count, cluster_count, cache_hit}` to also carry `selector`, `resolved_gene_count`, `gene_list_sha256`, and `analysis_fingerprint`. **No credentials** enter the payload (#535). Results are **never** activated as `public_ready` snapshots (confirmed: neither submit service touches `analysis_snapshot_*`/`public_ready`; interactive results live in `async_jobs.result_json`, the public snapshot in `analysis_snapshot_manifest` — distinct tables/lifecycles).

## 7. Dedup identity (the crux — grounded in the actual two-hash mechanism)

There are **two** dedup hashes today, and they key on **different** inputs:

- **Preflight** (`check_duplicate_job("clustering", list(genes, algorithm))`, submit line 87) hashes `sha256("clustering:" + toJSON({genes, algorithm}))` and looks for an active job with that `request_hash`.
- **Stored / DB constraint** (`async_job_service_submit`, async-job-service.R:243) computes `request_hash` over the **FULL** `create_job` payload `{genes, algorithm, category_links, string_id_table}` and inserts it; the generated `active_request_hash` + `UNIQUE (job_type, active_request_hash)` (migration 020) is what actually blocks a concurrent duplicate (the race handler at async-job-repository.R:112-138 returns the existing job on violation).

**These two hashes can never be equal** (subset JSON ≠ full-payload JSON), so the preflight's `request_hash` lookup effectively never matches a stored full-payload hash — the **preflight 409 path is largely unreachable for clustering, and real dedup rides the DB `active_request_hash` unique constraint over the full payload.** (Because `category_links` is a constant and `string_id_table` changes only when `non_alt_loci_set` changes, the full-payload hash is in practice a function of `{genes, algorithm}` — so today two *identical* concurrent `{genes, algorithm}` submits dedup via the DB constraint, and the historical/inactive case is intentionally allowed to re-run.) This is a **pre-existing inconsistency**, flagged (§12), not introduced by #574.

**#574 fix (works with the authoritative DB-constraint mechanism):** add the normalized selector to the durable `create_job` payload as `category_filter = selector_normalized`. Then:
- Two **identical** selectors → identical full payload → identical `active_request_hash` → the second concurrent submit dedups (DB constraint). ✔
- `["Definitive"]` vs `["Definitive","Moderate"]` that resolve to the **same** genes → **different** `category_filter` in the payload → **different** hash → **two distinct jobs** with honest provenance (Codex MEDIUM finding). ✔
- A curation change (same selector, different resolved genes) → different `genes` in the payload → new job. ✔

Also pass `category_filter = selector_normalized` to the preflight `check_duplicate_job("clustering", list(genes, algorithm, category_filter))` for **consistency** (so if the preflight/stored-hash scopes are ever unified, the selector is already part of both). The **cache-first** path keeps keying `gen_string_clust_obj_mem(genes, algorithm)` (shared partition cache — identical genes reuse the computed clustering), so distinct-selector jobs over identical genes each get their own **job record + provenance** while sharing the **computed result** (efficient and honest).

**Regression tests** (integration, DB-backed): two identical `["Definitive"]` concurrent submits → one active job; `["Definitive"]` and a `["Definitive","Moderate"]` that resolves to the same genes → two jobs, each recording its own `category_filter`.

## 8. Edge cases (enumerated)

1. Gene with Definitive + Limited NDD entities, `["Definitive"]` → **included**. (test)
2. Gene with only Limited NDD entities, `["Definitive"]` → **excluded**. (test)
3. Gene whose only Definitive entity is **non-NDD** (`ndd_phenotype != 1`) → **excluded** (NDD-entities-only). (test)
4. `["Definitive","Moderate"]` → union of both. (test)
5. Unknown token `["Definative"]` (typo) → 400 with allowed set. (test)
6. Inactive category (soft-deleted in the vocabulary) → 400. (test)
7. `category_filter: []` → 400 empty. `category_filter` with duplicates/whitespace → normalized then validated. (test)
8. Valid category resolving to 0 genes → 400 empty-universe (no empty-graph job). (test)
9. Both `genes` and `category_filter` → 400 mutual exclusion. (test)
10. Neither → all NDD genes, byte-identical to today (same resolver, `NULL` selector). (test — backward compat)
11. Two identical `["Definitive"]` submits → second 409 (dedup). (test)
12. `["Definitive"]` and `["Definitive","Moderate"]` resolving to the same genes → **two** jobs, distinct provenance. (test)
13. Capacity exceeded → 503 (unchanged). Admission throttle → unchanged.
14. SQL-injection attempt in a token (`Definitive' OR 1=1`) → rejected by the allowlist (not in active vocabulary) → 400; never reaches SQL as a literal (dbplyr `%in%` parameterization is the second layer). (test)
15. `algorithm` invalid → coerced to `leiden` (unchanged); dedup identity uses the coerced value.

## 9. Error contract

- Category validation / mutual-exclusion / empty-universe → **400 problem+json** via `stop_for_bad_request` (routed through `mount_endpoint`'s RFC 9457 handler). This is the documented repo standard; the new validation path adopts it even though the pre-existing dup/capacity responses use direct `res$status` plain-JSON bodies (those are left as-is — not in scope to refactor).
- Duplicate → **409** direct-status (unchanged pattern).
- Capacity → **503** direct-status (unchanged).

## 10. Non-goals / out of scope

- `POST /api/jobs/phenotype_clustering/submit` category support (the issue is functional clustering; a symmetric extension is trivial later but not in scope).
- `GET /api/analysis/functional_clustering?category_filter=...` computing on demand — explicitly **out** (issue): the public GET stays a fixed snapshot; category-specific GET support would require an explicitly-built, validated public snapshot preset.
- Changing the deterministic functional-analysis settings (Leiden/seed/weighted STRING exp+db graph/threshold) — preserved unless explicitly versioned.
- Activating category runs as public-ready snapshots.

## 11. Testing

**Unit** (`api/tests/testthat/test-unit-clustering-gene-universe.R`): the resolver — entity-level inclusion/exclusion (cases 1–4), validation (5–8, 14), NULL→all-NDD (10), sorted sha256 stability, normalization.

**Endpoint/integration** (`test-integration-clustering-category-submit.R`, `with_test_db_transaction()`): mutual exclusion (9), 400 shapes, provenance fields present in payload + result meta, dedup identity (11–12), capacity/throttle preserved (13), backward compat for explicit-list and no-list (10), and that the resulting job's universe equals the resolved Definitive set with **no** client-side filter (the acceptance criterion). Seed a small fixture: gene A (Definitive + Limited NDD entities), gene B (Limited only), gene C (Definitive non-NDD entity), gene D (Moderate NDD).

**Static/guards**: no raw category interpolation into SQL (allowlist + dbplyr `%in%`); public route still cheap (no external fetcher). Extend `test-unit-job-endpoint-services.R` for the new branch.

## 12. Facts confirmed against the codebase (grounded)

1. **`ndd_entity_view.category` is per-entity** — migration `025_create_core_views.sql:70-96` joins each entity's approved status → `ndd_entity_status_categories_list`, exposing `category`/`category_id`/`ndd_phenotype` per entity row. Filtering entity rows gives the entity-level OR semantics for free.
2. **Vocabulary** `ndd_entity_status_categories_list` — values `Definitive`, `Moderate`, `Limited`, `Refuted`, `not applicable`; **`is_active` (+ `sort`) exist** (added by migration `033`, defaulting `is_active = 1`). Validate against `is_active = 1`.
3. **Dedup mechanism** — preflight hashes `{genes, algorithm}`, the stored `request_hash` covers the full payload; the DB `UNIQUE (job_type, active_request_hash)` is the real dedup. #574 adds `category_filter` to the durable payload (and the preflight params) so distinct selectors are distinct jobs (§7). **Flagged pre-existing inconsistency** (out of #574 scope): the preflight subset-hash cannot match the stored full-payload hash, so the preflight 409 path is largely unreachable and dedup relies on the DB constraint — worth a follow-up to unify the two hash scopes, but #574 only needs to be correct w.r.t. the authoritative DB constraint.
4. **No request-field validation exists on this endpoint today** (unknown `genes` silently dropped; invalid `algorithm` silently coerced). #574 introduces the first validated field + 400 path here, mirroring `validate_query_column` (`response-helpers.R:30-38`).

## 13. Acceptance-criteria mapping (#574)

| #574 AC | Design |
|---|---|
| Submitting `["Definitive"]` produces a fresh job over the resolved Definitive NDD universe | §4/§5 resolver; §11 integration test |
| Existing explicit-list and no-list submissions retain results/contracts | §5 shared resolver (NULL→all-NDD); §11 backward-compat tests |
| Duplicate-job identity includes the resolved selector/list + analysis fingerprint | §7 identity object |
| Unit tests: category→gene resolution, multi-entity genes, validation/mutual-exclusion, payload/provenance, backward compat | §8/§11 |
| Integration: resulting job uses expected universe without client-side filter | §11 |
