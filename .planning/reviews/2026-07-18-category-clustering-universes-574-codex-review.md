# Codex adversarial review — #574 findings (gpt-5.6-terra, high reasoning)

Reconciliation: `…-category-clustering-universes-574-codex-reconciliation.md`. (Raw streamed log discarded; findings verbatim below.)

## BLOCKER

- [Plan D1 fixture and `< 2` guard](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md:65) cannot both pass. The fixture resolves `["Definitive"]` to only `HGNC:1`, while the proposed resolver rejects every universe with fewer than two genes. D3 reuses that fixture for a “fresh job.” Fix: seed at least two Definitive NDD genes in both unit and integration fixtures.

## HIGH

- [Plan D1 normalization](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md:103) collapses absent and supplied-empty selectors to `NULL`; the resolver then treats `NULL` as the all-NDD default. `{"category_filter":[]}` or `["   "]` therefore submits an all-NDD clustering job instead of the specified 400. Preserve a distinct “supplied but empty” value and reject it before the default branch.

- [Plan D2 provenance](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-18-category-clustering-universes-574-plan.md:207) omits `string_weight_channel` from `analysis_fingerprint`, despite the spec requiring it. It is only appended as a separate result-meta field after clustering. The actual channel is determined during `gen_string_clust_obj()` from `build_string_subgraph()` ([analyses-functions.R](/home/bernt-popp/development/sysndd/api/functions/analyses-functions.R:197)); it can fall back from exp+db to `combined_score`. Thus the immutable payload/hash cannot identify the effective method. Fix: persist a submit-time input fingerprint such as `analysis_string_cache_fingerprint()` in the identity payload, then persist a separate effective fingerprint containing the observed `attr(clusters, "weight_channel")`; fail closed rather than recording `NA` when source-version lookup fails.

- Calling `analysis_snapshot_source_data_version()` on this unauthenticated submit path is not cheap. Its backing view performs multiple global counts and joins, including `ndd_entity_view` and `ndd_review_phenotype_connect` ([migration 044](/home/bernt-popp/development/sysndd/db/migrations/044_mcp_public_read_projections.sql:149)), and D2 invokes it before duplicate/capacity handling. Distributed callers can force these aggregate scans even while the queue is full. Fix: use a maintained/versioned source token or a bounded cache, and perform capacity/duplicate admission before any new expensive provenance query.

## MEDIUM

- The promised “allowed set” will not reach clients. D1 passes it as `detail` to `stop_for_bad_request`, but the mounted error handler serializes only `conditionMessage(err)` ([filters.R](/home/bernt-popp/development/sysndd/api/core/filters.R:272)). An unknown category returns 400 problem+json, but omits the allowed categories required by the spec. Put the allowed set in the error message or teach the handler to honor `err$http_problem`.

- The spec’s “second identical submit returns 409” claim is false under the actual durable flow. The preflight hash still cannot match the full stored payload; on a cache miss the DB race handler returns the existing row, but `create_job()` discards `submitted$duplicate` and the endpoint returns 202 ([job-manager.R](/home/bernt-popp/development/sysndd/api/functions/job-manager.R:36)). On a warm cache, `store_completed()` inserts completed rows, whose `active_request_hash` is `NULL` ([migration 020](/home/bernt-popp/development/sysndd/db/migrations/020_add_async_job_schema.sql:31)), so repeated submits each create a job. Active-only dedup is acceptable if intentional, but the 409 requirement/test must be removed; otherwise propagate the duplicate result and use one full identity object for preflight and insertion.

- The specified selector contract is not implementable from D2 as written. The spec requires `{kind: category|explicit|all_ndd, category_filter}`, but the plan persists only a character vector or `NULL`. An explicit list equal to the all-NDD universe and a no-argument request become indistinguishable in provenance. Define and persist the selector object, while explicitly deciding whether that distinction should also change existing explicit-vs-default dedup behavior.
