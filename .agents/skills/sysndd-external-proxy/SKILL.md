---
name: sysndd-external-proxy
description: Use when adding or changing an external HTTP provider call in SysNDD (gnomAD, Ensembl, UniProt, AlphaFold, MGI, RGD, PubMed, PubTator, MONDO, JAX/HPO) or touching external-call timeouts, retries, caching, or per-request time budgets
---

# SysNDD External Proxy Budgets

Use this skill before adding or editing any outbound HTTP call to a gene/literature/ontology provider. The rules exist so one slow upstream cannot occupy a worker for tens of seconds or poison a long-lived cache. All helpers live in `api/functions/external-proxy-functions.R`.

## Every External Call Has a Budget

Derive the timeout/retry window from `external_proxy_budget(api_name, default_timeout =, default_max =, default_tries =)` **or** route the whole call through `make_external_request(url, api_name, throttle_config, ...)`. **Never a hardcoded `req_timeout(<n>)` / `max_seconds = <n>` literal** — this is enforced by `test-unit-external-budget-guard.R` (a bypass was reintroduced once via GeneReviews in #389, which is why the guard exists).

## Cache Only Successes

Wrap fetchers in `memoise_external_success_only(f, cache, source = "<provider>")`, **not** raw `memoise::memoise()`. It caches successful and true not-found responses but **not** transient `list(error = TRUE, ...)` failures, so a blip does not poison the 7/14/30-day caches. Passing `source =` also emits one structured timing log per call:

```
[external-proxy] ... event=complete status=... elapsed_ms=... cache=hit|miss
```

`gnomad`/`ensembl`/`uniprot`/`alphafold` use the memoise `source`; `mgi`/`rgd` instead log via the inline `external_proxy_with_timing()` wrapper and **omit** `source` to avoid double-logging.

## Request-Scoped Time Ceiling

`EXTERNAL_PROXY_REQUEST_MAX_SECONDS` (default 15s) is wired into both universal wrappers. Once a request's accumulated external time crosses it, further external calls **short-circuit to a degraded 503** (`request_budget_exceeded = TRUE`) without contacting the upstream. The accumulator is reset **per request** in the `preroute` hook (`bootstrap/mount_endpoints.R`) and **per job** at job start (`external_proxy_request_reset()`, `async-job-worker.R`).

- **Batch jobs** that make many independent provider calls must additionally reset the accumulator **per call** (see `.pubtatornidd_reset_external_budget()` in `pubtator-enrichment-collector.R`), or the ceiling — designed for public request paths — caps the back half of the batch.
- The `postroute` hook emits `[request-timing] method=… path=… status=… duration_ms=… external_ms=… slow=…` (`slow` over `API_SLOW_REQUEST_MS`, default 2000), so a slow request can be attributed to external time.

## Cheap Routes Stay External-Free

`/health`, `/auth`, `/statistics` must never call an external fetcher — enforced by `test-unit-cheap-route-isolation.R`.

## Known Exceptions

Batch jobs with their own pacing (e.g. `publication_date_backfill`) intentionally keep raw `httr2` retry (429 handling, Retry-After) and are **outside** the guard scan set — do not "fix" them into `external_proxy_budget()`. Per-provider budgets are tunable via env (`EXTERNAL_PROXY_MONDO_*`, etc.).

## Verify

`test-unit-external-budget-guard.R`, `test-unit-external-proxy-budgets.R`, `test-unit-external-slow-provider.R`, `test-unit-cheap-route-isolation.R`, and the router-level `test-integration-slow-provider-isolation.R`.
