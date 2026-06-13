# Slow-Route Hardening (#344) — Comprehensive Design

- **Issue:** [#344](https://github.com/berntpopp/sysndd/issues/344) — *api: prevent slow external/analysis endpoints from blocking cheap routes*
- **Date:** 2026-06-13
- **Status:** Approved (brainstorming) → ready for implementation plan
- **Related:** #154 (heavy/light worker-pool isolation, **out of scope here**), #325 (closed, external 503/error caching), PR #386 (`52a1717a` — original slow-route isolation that delivered ~85% of #344), PR #389 (`cc3eb368` — GeneReviews, which re-introduced a budget bypass)

---

## 1. Problem & Current State

Production showed API head-of-line blocking (2026-05-18): a single-threaded R/Plumber worker was occupied for tens of seconds (up to ~85s) by slow synchronous external-provider and analysis requests, starving cheap routes (`/api/health/`, `/api/auth/*`, `/api/statistics/*`, simple entity lookups). The operational mitigation (1→2 replicas, sticky-off) reduced visible impact but did not remove the blocking.

**~85% of #344 already shipped in PR #386 and is verified on master:**

| Acceptance criterion | Status | Evidence (file:line) |
|---|---|---|
| Per-provider timeout budgets | ✅ | `external_proxy_budget()` → 6s timeout / 10s max / 2 tries, env-tunable — `api/functions/external-proxy-functions.R:192` |
| Aggregate fast-fail + degraded response | ✅ | `external_proxy_aggregate_budget()` 12s, short-circuits remaining sources, returns `partial=TRUE` + `skipped_sources` — `external-proxy-functions.R:260,422` |
| Structured per-provider timing logs | ✅ | `[external-proxy] source=… event=… status=… elapsed_ms=… cache=…` — `external-proxy-functions.R` |
| Heavy analysis isolated from cheap routes | ✅ | `network_edges` reads precomputed snapshots; heavy clustering is async/worker-only; `/health/` does no DB I/O — `endpoints/analysis_endpoints.R:243`, `endpoints/health_endpoints.R:40` |
| Async job queue-depth cap | ✅ | `async_job_capacity_exceeded()` (ASYNC_PUBLIC_JOB_CAP=8 → 503 + Retry-After) — `functions/async-job-service.R:8` |
| Unit tests for fast-fail + cheap-route isolation | ✅ | `tests/testthat/test-unit-external-proxy-budgets.R`, `test-unit-external-slow-provider.R` |

### Verified remaining gaps

1. **Three external calls bypass the central budget** — the exact pattern #344 was meant to eliminate:
   - `api/functions/external-proxy-uniprot.R:119-131` — step-2 EBI Proteins features fetch uses `max_tries=5, max_seconds=120, req_timeout(30)`. **Worst case ~120s holding a worker.** UniProt is also AlphaFold's step-1 accession lookup; both PRR12 entries in the issue log were ~67s, making this the most likely production culprit.
   - `api/functions/genereviews-lookup.R:78-90` — E-utilities XML fetch uses `max_tries=3, req_timeout(30)`. ~30s+. **Introduced by PR #389 *after* #386's fix** — proof that bypasses creep back in without a guard.
   - `api/functions/external-proxy-gnomad-batch.R:173-176` — `req_timeout(30), max_tries=3, max_seconds=30`. ~30s. No public endpoint caller found (worker/job path), so lower head-of-line priority, but still bounded for correctness.

2. **The single explicitly-unfulfilled AC**: no *full-stack* slow-provider integration/smoke test that runs a slow provider concurrently with a cheap route and asserts the cheap route stays bounded. Only in-process unit simulation exists.

3. **Frontend dimension unmeasured**: does a slow external-provider card on a gene detail page block paint/TTI, or do cards degrade independently? This is the user-facing half of the issue.

### Boundary (NOT in scope)

True heavy/light worker-pool isolation + Redis queue remains **#154**. Plumber stays single-threaded-per-process. Our contract is **bounded single-request time**, not in-process parallelism. The "small step toward #154" here is a global per-request external-time ceiling + categorical cheap-route isolation guard, nothing more.

---

## 2. Goals & Success Criteria

**Goal:** Make it structurally impossible for any single request to occupy a worker for tens of seconds, prove it end-to-end (backend + frontend), and prevent bypass-creep.

Success =
1. Every external HTTP call in the codebase derives its timeout/retry window from `external_proxy_budget()` (or an equivalent bounded, env-tunable budget). No hardcoded `req_timeout(30)` / `max_seconds=120` literals on external paths.
2. A static guard test fails CI if a new external fetcher hardcodes a timeout instead of using a budget.
3. A global per-request external-time ceiling fast-fails further external work once exceeded; cheap routes are categorically guarded against calling external fetchers.
4. Per-request observability attributes slow requests to external time (`duration_ms` + `external_ms` + `slow` flag).
5. A backend integration test asserts: a slow provider fast-fails with a degraded 503 envelope **and** a cheap route stays bounded.
6. Playwright + Lighthouse evidence (before/after) shows the gene page renders within budget and external cards degrade independently under injected upstream latency.
7. Docs updated (AGENTS.md, 08-development.qmd, 09-deployment.qmd).

---

## 3. Architecture & Components

### Component 1 — Uniform external-timeout budget (close the 3 bypasses)

Route the three bypassing calls through the existing budget machinery:
- **UniProt step-2** (`external-proxy-uniprot.R`): replace the inline `req_retry(max_tries=5, max_seconds=120)` + `req_timeout(30)` with `make_external_request()` or an explicit `budget <- external_proxy_budget("uniprot")` block, identical to step-1 and the gnomad/mgi/rgd/ensembl/alphafold fetchers.
- **GeneReviews** (`genereviews-lookup.R`): `genereviews_eutils_xml()` takes a `budget <- external_proxy_budget("genereviews")`; default ≤10s, env `EXTERNAL_PROXY_GENEREVIEWS_*`.
- **gnomAD-batch** (`external-proxy-gnomad-batch.R`): `budget <- external_proxy_budget("gnomad_batch")`. Because it is worker-only and batches many genes, allow a higher *env-overridable* default (e.g. 30s) but never the implicit 120s class; keep it explicitly bounded and named.

All three keep success-only caching (`memoise_external_success_only`) and emit the structured `[external-proxy]` log (memoise `source=` for gnomad-batch/uniprot; the genereviews path adds a `source="genereviews"` label or inline `external_proxy_with_timing`).

### Component 2 — Static budget guard (regression prevention)

`api/tests/testthat/test-unit-external-budget-guard.R`:
- Enumerate external fetcher files (`functions/external-proxy-*.R`, `functions/genereviews-lookup.R`, and the NCBI E-utilities helpers).
- Fail if any `req_timeout(...)` / `req_retry(... max_seconds = ...)` argument is a numeric literal rather than a `budget$timeout_seconds` / `budget$max_seconds` reference (allowlist the budget *definition* in `external-proxy-functions.R`).
- Mirrors the established static-guard pattern (`test-unit-llm-model-default-guard.R`, `test-unit-filter-column-allowlist.R`, `test-unit-metadata-refresh-patterns.R`).

### Component 3 — Global per-request external-time ceiling + cheap-route isolation guard

- **Request-scoped accumulator:** because Plumber handles one request at a time *per process*, no request-id keying is needed. Use a single module-level environment (`external_proxy_request_state <- new.env(parent = emptyenv())`) holding `external_ms` and `ceiling_tripped`, reset in the `preroute` hook; every `external_proxy_*` call increments `external_ms` by its `elapsed_ms`. A small accessor pair (`external_proxy_request_reset()` / `external_proxy_request_add(ms)` / `external_proxy_request_total()`) keeps it testable and avoids leaking state between requests.
- **Hard ceiling:** `EXTERNAL_PROXY_REQUEST_MAX_SECONDS` (default ~15s). Once the accumulator exceeds it, subsequent external calls in the same request short-circuit to a degraded 503 envelope without performing the upstream request. This covers single-endpoint paths the *aggregate* budget (which only governs the multi-source `/api/external/gene/<symbol>` aggregator) does not.
- **Cheap-route static guard:** `test-unit-cheap-route-isolation.R` asserts the handlers for `/health/*`, `/auth/*`, `/statistics/*` never reference an `external_proxy_*` / `fetch_*` external fetcher (static source scan).

### Component 4 — Request-level SLO observability (chosen: Option A)

Enhance the existing `preroute`/`postroute` hook in `api/bootstrap/mount_endpoints.R`:
- Reset the external-time accumulator in `preroute`.
- In `postroute`, emit a structured, parseable line including `route`, `method`, `status`, `duration_ms`, `external_ms` (from the accumulator), and `slow=true` when `duration_ms` exceeds an SLO threshold (`API_SLOW_REQUEST_MS`, default ~2000). Keep the existing DB log write; add the structured stdout line so slow requests are greppable and attributable to external time.
- No new metrics endpoint (Option C deferred).

### Component 5 — Backend slow-provider integration test (unfulfilled AC)

`api/tests/testthat/test-integration-slow-provider-isolation.R`:
- Against the mounted Plumber router (or a focused harness), stub an external fetcher to sleep > budget.
- Assert the external route returns a 503 degraded envelope within ~(budget + margin), **and** that a cheap route (`/api/health/`) called immediately after returns < a small bound.
- Optionally extend `scripts/ci-smoke.sh` with a slow-provider scenario (stub via env or a test-only route) — decided during planning to keep CI runtime sane.

### Component 6 — Frontend resilience validation + optimization (Playwright + Lighthouse)

- **Baseline (before):** capture Lighthouse (perf score, LCP, TBT/TTI) + Playwright network timings for a gene detail page against the Playwright stack (`http://localhost:8088`), under normal and injected-latency conditions.
- **Playwright spec** `app/tests/e2e/slow-provider-resilience.spec.ts` (or under `tests/perf/`): use `page.route('**/api/external/**', …)` to delay external responses (e.g. 20s), assert the page shell + core SWR/`SectionCard` cards render within budget while external cards show skeleton/degraded states; assert no external card blocks first contentful paint.
- **Optimize laggards:** the v11.3 genes/entities page already uses SWR composables + per-card `SectionCard` skeletons + hide-when-empty, so isolation likely holds; verify and patch any external-provider card that awaits a slow endpoint and blocks render. Frontend API access stays through typed `app/src/api/*` clients.
- **After:** re-capture Lighthouse + Playwright; record before/after in `.planning/perf/`.

### Component 7 — Documentation

- `AGENTS.md`: external-proxy gotcha updated with the budget guard, the new env knobs (`EXTERNAL_PROXY_GENEREVIEWS_*`, `EXTERNAL_PROXY_GNOMAD_BATCH_*`, `EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, `API_SLOW_REQUEST_MS`), the request-time accumulator, and the explicit #154 boundary.
- `documentation/08-development.qmd`: how to run the slow-provider integration test + Playwright resilience spec.
- `documentation/09-deployment.qmd`: operator knobs, the structured slow-request log format, degraded-response semantics.

### Dev-environment side-fix (enabling, not #344 feature)

`sysndd-api-1` crash-loops on `Error: dw$secret must be a non-empty string`: `config::get(API_CONFIG)` resolves a config block without a non-empty `secret` for the dev container (config.yml's secret currently lives under the playwright block). `sysndd-worker-1` fails on stale `playwright` DB creds. Fix dev config/env so `make dev` boots, without baking real secrets into image layers (per AGENTS.md). Isolated from the #344 changes.

---

## 4. Data Flow (external request, after hardening)

```
request → preroute hook: reset external-time accumulator, tic()
  → endpoint handler → external_proxy_* fetcher
       → check request-ceiling accumulator; if exceeded → degraded 503 (no upstream call)
       → else: httr2 request bounded by external_proxy_budget(provider)
            (timeout_seconds, max_seconds, max_tries — all env-tunable)
       → memoise_external_success_only: cache success/true-404, drop transient errors
       → add elapsed_ms to accumulator; emit [external-proxy] log
  → postroute hook: toc(); log route/status/duration_ms/external_ms/slow; DB log write
```

Aggregator (`/api/external/gene/<symbol>`) additionally short-circuits remaining sources past `external_proxy_aggregate_budget()` (12s) and returns `partial=TRUE` + `skipped_sources` (unchanged).

---

## 5. Testing Strategy

| Layer | Test | Asserts |
|---|---|---|
| Unit | `test-unit-external-budget-guard.R` (new) | No hardcoded timeout literals on external paths |
| Unit | `test-unit-cheap-route-isolation.R` (new) | Cheap-route handlers never call external fetchers |
| Unit | extend `test-unit-external-proxy-budgets.R` | `genereviews`/`gnomad_batch` budgets bounded; request-ceiling helper behaves |
| Integration | `test-integration-slow-provider-isolation.R` (new) | Slow provider fast-fails 503 + cheap route bounded (router-level) |
| Frontend E2E | `slow-provider-resilience.spec.ts` (new, local) | Page renders under injected `/api/external/**` latency; cards degrade independently |
| Perf | Lighthouse before/after on gene page | Perf score / LCP / TBT not regressed; ideally improved |
| Gate | `make test-api-fast`, `make lint-api`, `cd app && npm run type-check`, `make ci-local` before handoff | Full local CI parity |

---

## 6. Risks & Mitigations

- **Behavior change (UniProt):** genes that *currently* return full domains after 30-120s will return degraded/partial faster. Intended per the issue ("prefer fast-fail/degraded responses"); mitigated by env-tunable budgets and a docs note.
- **Scope creep toward #154:** strictly limit component 3 to a per-request ceiling + isolation guard; no Redis/worker-pool split.
- **Static guard false positives:** allowlist the budget definition and any legitimate non-external `req_timeout` (e.g. internal health probes); scope the scan to external fetcher files only.
- **Frontend over-degradation:** external cards may show empty states more often; acceptable and consistent with existing hide-when-empty `SectionCard` behavior.
- **gnomAD-batch worker path:** confirm during planning whether tightening its budget affects batch annotation jobs; keep its default higher and env-overridable.

---

## 7. Execution Notes (parallelism)

Independent workstreams suitable for parallel subagents once the plan exists:
- **WS-A (backend budgets+guards):** components 1, 2, 3, unit tests.
- **WS-B (observability):** component 4 (postroute hook + accumulator).
- **WS-C (backend integration test):** component 5.
- **WS-D (frontend + measurement):** component 6 (Playwright/Lighthouse, baseline first).
- **WS-E (dev-stack fix + docs):** dev-config side-fix, component 7.

WS-A/B touch overlapping files (`external-proxy-functions.R`, `mount_endpoints.R`) — sequence or coordinate to avoid conflicts. WS-C depends on WS-A’s degraded-envelope shape. WS-D is fully independent (frontend + measurement). Baseline measurement (WS-D "before") should run first to capture pre-fix evidence.
