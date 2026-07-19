You are an adversarial senior R/Plumber reviewer. Review ONLY the diff of the current branch vs master for correctness, security, and contract-compliance bugs. Run `git diff origin/master...HEAD -- ':(exclude).planning/**'` to see the change set (feature #574: category-selected gene universes for functional clustering). Read the touched files in full where needed. Be skeptical and specific; find bugs, not style nits.

## What #574 does
`POST /api/jobs/clustering/submit` gains an optional `category_filter` JSON body array (e.g. `["Definitive"]`) that resolves the clustering gene universe from curated SysNDD confidence categories instead of an explicit `genes` array. New file `api/functions/clustering-gene-universe.R` holds the resolver + provenance helpers; the submit service `api/services/job-functional-submission-service.R` wires it in; the durable handler `.async_job_run_clustering` (`api/functions/async-job-handlers.R`) echoes provenance into the worker-run result meta.

## LOCKED design decisions — a violation of any of these is a BUG (report it):
1. **Entity-level resolution**: the universe = distinct `hgnc_id` from `ndd_entity_view` filtered `ndd_phenotype == 1` AND `category %in% selector`. A gene with ≥1 entity in a selected category qualifies even if it has other-category entities. It must NEVER use `select_network_gene_category()`.
2. **NULL/absent selector → the pre-#574 default** (all NDD genes via `generate_ndd_hgnc_ids()`), byte-identical for cache parity. `clustering_normalize_category_filter` returns NULL ONLY for a NULL arg; `character(0)` for supplied-but-empty (`[]`/`[""]`/`["  "]`) which must 400 (NOT fall through to default).
3. **Validation is live** against `ndd_entity_status_categories_list WHERE is_active = 1`. No hardcoded category strings; no category string interpolated into SQL (must use dbplyr `%in%` + an allowlist pre-check). The allowed active set must appear in the error MESSAGE (conditionMessage), not only a `detail` field.
4. **Guards**: unknown/inactive category → 400; supplied-empty → 400; resolved universe < 2 genes → 400; `genes` + non-empty `category_filter` → 400 (mutual exclusion).
5. **Selector-aware dedup, additively**: the normalized `category_filter` enters the durable payload AND the preflight dedup key ONLY for category selectors. Explicit-`genes` and no-arg submits must keep a BYTE-IDENTICAL payload/`request_hash` to pre-#574 (no `category_filter` key) — though ALL three kinds now additively gain a `provenance` key. No HTTP-409 was added; active-only dedup semantics unchanged.
6. **Provenance** persisted in payload: `selector {kind: explicit|category|all_ndd, category_filter}`, `resolved_gene_count`, `gene_list_sha256` (sha256 of sorted-unique hgnc ids, sort-order independent), an INTENDED `intended_fingerprint` (string cache fingerprint + score_threshold=400 + algorithm + seed=42), and a CACHED, FAIL-CLOSED `source_data_version` (on fetch error → HTTP 503 `PROVENANCE_UNAVAILABLE`, NEVER records NA). The result `meta` additionally carries an EFFECTIVE `effective_fingerprint = {weight_channel = attr(clusters,"weight_channel")}`, on BOTH the cache-hit response and the worker-run handler.
7. **Results are NEVER `public_ready`** (ephemeral job results). The fixed public snapshot GET is untouched (category GET stays `unsupported_parameter`).

## Focus your adversarial search on:
- Any path where a supplied-but-empty or whitespace-only `category_filter` silently becomes the all-NDD default (would be a serious bug).
- Any asymmetry between the cache-hit payload/meta path and the cache-miss (`create_job`) payload path (a field added to one but not the other).
- The fail-closed `source_data_version` / TTL cache (`clustering_cached_source_data_version`): can it ever cache or return an error/NA? Can a stale cached value be served past its TTL? Is the 503 short-circuit before any payload is built?
- The `.async_job_run_clustering` meta echo: does it match the cache-hit meta shape? Backward compatible for a legacy payload with no `provenance`?
- SQL injection / expression injection via category tokens (must be dbplyr-parametrized + allowlisted).
- `resolved_gene_count` vs `gene_list_sha256` consistency; dedup identity collisions between different selectors that resolve to the same current genes.
- The new integration test: does it genuinely assert (not vacuously), skip cleanly on an empty DB, and correctly bind `pool` for the NULL-branch assertion (the NULL branch calls `generate_ndd_hgnc_ids()` which uses the global `pool`, not the passed conn)?
- Anything worker-executed that would only fail at runtime (masked base functions: `config::get` masks `base::get`; `biomaRt::select` masks `dplyr::select` — verify `dplyr::` namespacing).
- Whether explicit/no-arg payloads are truly byte-identical (the `provenance` addition is expected; anything ELSE differing is a bug).

## Output
For each finding: severity (BLOCKER / HIGH / MEDIUM / LOW), file:line, the concrete failure scenario (inputs → wrong behavior), and the fix. Then a final line: **VERDICT: SHIP** or **VERDICT: NO-SHIP** with the blocker count. Only give SHIP if there are zero BLOCKER/HIGH findings.
