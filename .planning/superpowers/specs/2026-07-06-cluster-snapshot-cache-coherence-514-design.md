# Cluster-snapshot cache coherence & self-healing analysis deploys (#514)

**Status:** design → implementation
**Issue:** #514 — *Cluster snapshots serve stale, incoherent partitions after a methodology deploy*
**Follow-up to:** #508–#512 (v0.29.0 cluster-analysis soundness)

## Problem (root causes, confirmed against code)

After the v0.29.0 methodology deploy, production served **stale + internally-incoherent**
functional-cluster snapshots: the displayed **partition** was the pre-#510 text-mining
clustering while the **validation metrics** in the *same* snapshot were the new
text-mining-free (exp+db) computation.

- **RC2 (primary) — memoise disk cache does not encode analysis logic/data.**
  `bootstrap_init_memoised` (`api/bootstrap/init_cache.R`) keys the clustering wrappers
  (`gen_string_clust_obj_mem`, `gen_mca_clust_obj_mem`, `gen_network_edges_mem`) only on
  their call args. The cache is disk-backed on a named volume (survives redeploys),
  invalidated only by a manual `CACHE_VERSION` bump or the 24 h `max_age`. #508–#512
  changed the graph/algorithm but did not bump `CACHE_VERSION`, so the snapshot builder
  (`analysis-snapshot-builder.R`) got **membership** from a stale disk-cache hit
  (`gen_string_clust_obj_mem`, line ~405) while **validation** recomputed fresh
  (`validate_functional_clusters`, line ~407, not memoised). The `left_join` on integer
  `cluster_id` then mismatched → real clusters got `n/a` stability.

- **RC1 — silent exp+db fallback.** `build_string_subgraph` (`analyses-functions.R`) falls
  back to the text-mining `combined_score` graph with only a `message()`, and the served
  **membership** provenance never exposed which channel it used — only `validate_*`
  reported `weight_channel`, so the two disagreeing channels were invisible.

## Fix (sustainable, no `cluster_hash` churn)

1. **Self-invalidating fingerprint (RC2).** New `api/functions/analysis-cache-fingerprint.R`
   defines `CLUSTER_LOGIC_VERSION` plus `analysis_string_cache_fingerprint()` (version +
   STRING channel + exp+db file identity `size:mtime`) and
   `analysis_phenotype_cache_fingerprint()` (version + MCA prevalence band). Each
   analysis-logic-dependent clustering function (`gen_string_clust_obj`,
   `gen_network_edges`, `gen_mca_clust_obj`) gains a trailing `.cache_fingerprint` formal
   whose **call-time** default is the relevant fingerprint. memoise 2.0.1 hashes call-time
   default args (verified), so the fingerprint enters the memoise key with **zero call-site
   changes**. Call-time (not boot) evaluation self-heals the exact prod scenario: adding the
   exp+db file changes the file identity → key changes → recompute, even without a restart.
   A code change is handled by bumping `CLUSTER_LOGIC_VERSION`; a data/channel/prevalence
   change self-invalidates automatically. Registered in `bootstrap/load_modules.R` (covers
   API, durable worker, and MCP sidecar) and `bootstrap/setup_workers.R` (mirai parity).

2. **Snapshot integrity gate (#4).** New `api/functions/analysis-snapshot-coherence.R`
   exposes `analysis_snapshot_assert_partition_coherent()`. The builder calls it for both
   clustering presets after the membership⋈validation join. It refuses to publish (throws →
   refresh fails → prior `public_ready` retained, new row `failed`) when the visible
   membership cluster set ≠ the validation cluster set, any visible cluster lacks a stability
   score, or membership-channel ≠ validation-channel. Gated by
   `ANALYSIS_SNAPSHOT_REQUIRE_COHERENCE` (default `true`; `false` downgrades to a warning as
   an operability escape hatch).

3. **Membership channel provenance + observable fallback (RC1/#5).** `gen_string_clust_obj`
   captures `attr(subgraph, "weight_channel")` and returns it as an attribute on the clusters
   tibble (survives the RDS cache round-trip). The builder stores it in the snapshot
   membership provenance and feeds it to the gate. `build_string_subgraph` emits a
   `warning()` (not just a `message()`) when an intended exp+db graph falls back to
   text-mining. `/api/health` surfaces `expdb_edges_file_present`.

4. **Docs/runbook (#1/#6).** AGENTS.md invariant + `documentation/09-deployment.qmd`
   runbook for methodology deploys (ensure exp+db artifact → bump `CLUSTER_LOGIC_VERSION`
   → full snapshot refresh → verify `weight_channel` + membership/metrics agreement).

## Deliberately deferred

- **Issue Fix #3 (single clustering pass).** Collapsing membership + validation onto one
  `communities` object is the most robust coherence guarantee but is invasive and would
  re-shape the `cluster_hash`-producing path (forcing LLM regeneration). Fixes 1+2+3 above
  both **prevent** (fingerprint) and **catch** (gate) the incoherence without that risk;
  the single-pass refactor is recorded as a future robustness improvement.

## Adversarial review (Codex, high reasoning) — dispositions

- **[Fixed] `config::get` masks `base::get` in the worker.** Found in live verification (not by Codex): the dispatcher's `get(fn, mode = "function")` raised `unused argument (mode = ...)` and **failed every snapshot refresh**. `analysis_cache_fingerprint()` now dispatches to the concrete helpers directly (no `get()`); regression-guarded by a masked-`get` test.
- **[Fixed] Gate proved only same *labels*, not same *partition* (Codex #1, High).** Strengthened: the validators now return `reference_members` (member ids per cluster_id) and the gate compares served vs validated member sets per shared cluster_id, so a stale membership whose cluster-id labels coincide with the fresh validation is still caught.
- **[Deferred, documented] Cache write/probe key divergence by gene-vector *order* (Codex #2, Medium).** Pre-existing and **non-correctness** (a false cache miss, never stale data): the snapshot write orders genes by `hgnc_id` while the interactive/MCP probes order by `entity_id`, so their memoise keys differ. Not introduced by #514 and orthogonal to the staleness fix; canonicalizing the gene order across all call sites is its own change with its own verification. Tracked as a follow-up.
- **[Deferred, documented] Phenotype job cache probe uses an unprepped matrix (Codex #3, Medium).** Pre-existing and non-correctness (the executor still preps via the shared `phenotype_mca_prep_matrix()`; only the cache-first fast-path misses). Tracked as a follow-up.

## Verification

- Host unit tests for the fingerprint (changes on version/channel/file identity; memoise
  miss on change), the coherence gate (pass / missing-score / orphan / channel-mismatch /
  escape hatch), and the fallback warning.
- Container: restart worker → forced snapshot refresh → assert served
  `functional_clustering` membership + metrics agree and `weight_channel` is exposed on both.
- `make code-quality-audit`, `make lint-api`, `make test-api-fast`.

## Compose note

The MCP sidecar (`docker-compose.yml` `mcp`) mounts `api_cache:ro` but not `./api/data`.
To keep MCP cache-probe **hit rate** (its fingerprint must match the writer's), add
`- ./api/data:/app/data:ro` to the `mcp` service. Correctness does not depend on it (a
mismatched fingerprint makes MCP **miss**, never serve stale), but the mount preserves hits.
