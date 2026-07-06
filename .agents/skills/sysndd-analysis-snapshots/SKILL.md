---
name: sysndd-analysis-snapshots
description: Use when changing gene clustering (STRING/Leiden functional axis or phenotype MCA/HCPC), the analysis snapshot builder or validator, the memoised clustering cache, cache coherence, or LLM cluster summaries — or deploying a clustering change so public endpoints and summaries reflect it
---

# SysNDD Analysis Snapshots & Cache Coherence

Use this skill before touching clustering, the snapshot builder/validator, the clustering cache, or LLM cluster summaries. This subsystem (#508–#514) is coherence-sensitive: a subtle mistake serves a stale, internally-incoherent snapshot that still activates as public-ready.

## Architecture

- Public endpoints (`/api/analysis/functional_clustering`, `.../phenotype_clustering`) read **activated `analysis_snapshot_*` rows** — not live compute. Nothing public changes until a **snapshot refresh job** (worker) rebuilds and activates a new row.
- Heavy clustering (`gen_string_clust_obj`, `gen_mca_clust_obj`, `gen_network_edges`) is **memoised to a disk cache on a named volume that SURVIVES redeploys** (`bootstrap/init_cache.R`).
- The builder reads **membership** from the memoised function; the **validator** (`validate_functional_clusters`, not memoised) recomputes fresh. They are coherent only when both clustered the identical graph with the identical seed.

## The Additivity Lever

`analysis_snapshot_payload_hash` **excludes** `partition_validation` and `reproducibility` (`analysis-snapshot-builder.R`). So new validation metrics are **additive** — they never change `cluster_hash` and never invalidate LLM summaries. Only changes to cluster **membership** (graph construction, STRING channel, MCA hygiene, Leiden/HCPC params) change `cluster_hash`.

## Cache Invalidation — Two Mechanisms

The memoise key is call-args **plus a call-time `.cache_fingerprint`** (`analysis-cache-fingerprint.R`).

- **Code change to clustering inputs/algorithm → bump `CLUSTER_LOGIC_VERSION`.** This is the only thing that changes the key for a code-only change; the data-identity components (STRING channel, exp+db file `size:mtime`, MCA prevalence band) won't. This **supersedes** the manual `CACHE_VERSION` bump for clustering caches (`CACHE_VERSION` nukes *all* memoised `.rds` and still governs other return-shape changes).
- **Data/channel/prevalence change → self-invalidates** via the fingerprint at call time, no restart needed.

## The Coherence Gate — Do Not Bypass

The builder joins validation onto membership **only** through `analysis_snapshot_join_validated_clusters()` → `analysis_snapshot_assert_partition_coherent()` (`analysis-snapshot-coherence.R`). It refuses to publish (throws → refresh fails → prior public-ready retained) when the visible membership cluster set ≠ the validation set, a visible cluster lacks a stability score, or the membership channel ≠ the validation channel. **Never reintroduce a bare `left_join(clusters, val$per_cluster)`.** `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` defaults `true`; setting it `false` to "get a refresh through" re-opens the incoherent-publish hole — bump `CLUSTER_LOGIC_VERSION` instead.

## LLM Summaries

Keyed by per-cluster `cluster_hash` **plus `LLM_SUMMARY_PROMPT_VERSION`** (`llm-summary-config.R`). A membership change changes `cluster_hash`, so old summaries retire and regenerate. **Bump `LLM_SUMMARY_PROMPT_VERSION` only when the prompt or generation/judge logic changes** — not for a clustering change (the hash already handles that; bumping would gratuitously blank untouched clusters).

## Membership-Change Deploy Runbook

1. Ensure the exp+db artifact exists (`api/data/9606.protein.links.expdb.v11.5.min400.txt.gz`) if the functional axis needs it — else clustering silently falls back to the text-mining graph (loud via `warning()` + health flag).
2. Bump `CLUSTER_LOGIC_VERSION` (only for a code change).
3. Restart `worker` **and** `worker-maintenance` (worker-executed code; the refresh runs on the worker).
4. `POST /api/admin/analysis/snapshots/refresh?analysis_type=functional_clusters&force=true` (and `…phenotype_clusters`). **`force` is required** — a non-forced refresh skips a preset whose current snapshot is still `available`.
5. `POST /api/llm/regenerate?cluster_type=functional&force=true` (and `…phenotype`). **`force` required here too**, else it short-circuits on existing `is_current` rows.

## Verify

- Health endpoint (`health_endpoints.R`): `analysis.cluster_logic_version` == new value, `analysis.expdb_edges_file_present == true`.
- `GET /api/admin/analysis/snapshots/status`: preset `available`, fresh timestamps.
- Snapshot refresh job in history is **succeeded, not failed** (a coherence throw shows here — the tell you forgot the version bump).
- Public endpoint: every visible cluster has a **non-null stability score** (the #514 symptom was `n/a`), metrics agree, and `weight_channel`/`membership_weight_channel == experimental_database`.
- LLM: summaries map to a **new** `cluster_hash`. In the batch-generation log, "all cached / 0 generated" means membership did **not** change — the change was additive and a forced regen is wasteful.
