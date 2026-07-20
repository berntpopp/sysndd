# Slow-Route Isolation via a Synchronous Enrichment Lane (#344 closure) — Design

- **Issue:** [#344](https://github.com/berntpopp/sysndd/issues/344) — *api: prevent slow external/analysis endpoints from blocking cheap routes*
- **Date:** 2026-07-20
- **Status:** Approved (brainstorming, research-grounded) → ready for implementation plan
- **Predecessor:** `.planning/superpowers/specs/2026-06-13-slow-route-hardening-344-design.md` (PRs #386, #413 — shipped ~85% of #344: budgets, per-request ceiling, guards, observability, resilience tests). This design closes the **remaining structural gap** that predecessor explicitly deferred to #154.
- **Related:** #154 (Redis heavy/light worker pool) — **closed `not_planned`**, superseded by the MySQL durable-job system, which isolates *async* work only. #486 (async `worker`/`worker-maintenance` two-lane split — the async-tier precedent this design mirrors on the synchronous tier).

---

## 1. Problem & Current State

Production head-of-line blocking (2026-05-18): a single-threaded R/Plumber worker was occupied for tens of seconds by a slow synchronous request, starving cheap routes (`/api/health/`, `/api/auth/*`, `/api/statistics/*`, simple entity lookups). Plumber's own docs confirm this is structural: *"R is a single-threaded programming language… it can only do one task at a time"* and *"if you have a single endpoint that takes two seconds… your R process will be unable to respond to any additional incoming requests for those two seconds."* The framework's remedy is to *"run multiple R processes… and load-balance incoming requests."*

The predecessor work bounded and observed the problem but, per its own boundary note, delivered **"bounded single-request time, not in-process parallelism"** and deferred true isolation to **#154**. #154 is now **closed** — so the deferral target is gone and the structural root cause is unaddressed.

### What is already solved (do not re-tread)

- Per-provider `external_proxy_budget()` (6s timeout / 10s window / 2 tries, env-tunable); aggregate budget (12s) for `/api/external/gene/<symbol>`; success-only caching; `[external-proxy]` and `[request-timing]` structured logs. (`api/functions/external-proxy-functions.R`, `api/bootstrap/mount_endpoints.R:159-219`.)
- All heavy analysis is **off the request path**: `/api/analysis/network_edges` and every clustering/correlation read are pure `analysis_snapshot_*` DB reads that fast-fail **503 + `Retry-After`** on a miss and **never compute inline** (`api/endpoints/analysis_endpoints.R`, `api/services/analysis-snapshot-service.R:26-91`). Heavy STRING/MCA/fCoSE work is worker/durable-job only.
- Static guards (`test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`), a router-level integration test, and a Playwright resilience spec. The frontend is already resilient: all six external cards are non-core, degrade independently via SWR + hide-when-empty, and analysis pages have a first-class "being prepared" 503 state.

### Verified remaining gaps (this design's scope)

1. **No structural isolation of the one remaining slow synchronous surface.** After the analysis migration, the *only* public request-path work that makes live upstream calls is `/api/external/*` (gnomAD / UniProt / Ensembl / AlphaFold / MGI / RGD + the `gene/<symbol>` aggregator). On the single-threaded process these still occupy the worker while awaiting upstreams, blocking cheap routes when the API runs thin.
2. **The 15s per-request ceiling is a pre-call gate, not a real bound.** It is checked once at each fetcher's entry. `fetch_mgi_phenotypes` / `fetch_rgd_phenotypes` each issue **two sequential** `httr2` calls inside **one** wrapper, so a slow provider can occupy the worker ~2 × (`max_seconds` + `timeout_seconds`) ≈ **~32s** — well past the nominal 15s the docs/AGENTS.md advertise.
3. **Sticky sessions are still ON** (`docker-compose.yml:258-261`, `sysndd_api_sticky`), contradicting both the documented stopgap and #344's acceptance criterion. Durable MySQL jobs mean no request needs to land on a specific instance.
4. **No declared replica floor** — the `api` service has no `deploy.replicas`; at rest it may be a single container, so even non-sticky routing yields zero isolation.

### Boundary (NOT in scope)

- **No in-process async** (`promises`/`future`). Against the codebase grain (the entire runtime is sourced into `.GlobalEnv`; `future` workers would each re-source it, and disk-memoise/DB-pool state does not cross process boundaries cleanly). Plumber's own guidance favours multiple processes over in-process async, and does not document the async route.
- **No Redis / rrq** (the closed #154 approach). MySQL durable jobs already cover async; the synchronous tier only needs **process partitioning**.
- **No cache-first external decoupling in v1** — documented as an optional **Phase 2** (§8) that layers on top, not instead.

---

## 2. Goal & Success Criteria

**Goal:** Make it *structurally impossible* for a slow `/api/external/*` request to occupy a process that serves cheap routes — a hard guarantee, not a statistical one — and close the remaining acceptance criteria (sticky-off, replica floor, real per-request bound), with the smallest possible blast radius.

Success =

1. **Bulkhead:** `/api/external/*` is served by a dedicated `api-enrichment` process pool (same image, all routes mounted). Cheap/core routes run on a separate `api` pool that no slow upstream call can ever occupy. Verified by a two-lane smoke: inject upstream latency into an external provider and assert `/api/health/` stays fast while `/api/external/*` is slow.
2. **Sticky retired:** the `api` load-balancer sticky-cookie labels are removed; the deployment runs stateless across replicas (job state lives in `async_jobs`). Closes the "no sticky sessions once job state is externalised" AC.
3. **Replica floor:** the core `api` declares a ≥2 replica floor in prod; `api-enrichment` is independently scalable.
4. **Real per-request bound:** the request-external-time ceiling is re-checked *between* the sequential internal calls of the multi-call fetchers (MGI/RGD), so a single external request cannot exceed ~one provider budget (~16s) instead of ~32s — the reality now matches the documented 15s contract.
5. **Boundary stays honest:** a static guard asserts the set of files invoking external fetchers on public request paths is a known allowlist (`external_endpoints.R` + the documented Curator-gated entity-create residual), so a *new* external-calling public route cannot silently land on the core lane.
6. **Dev unchanged in spirit:** local `make dev` still runs a single API container (enrichment lane profile-gated out, exactly like `worker-maintenance`); the two-lane stack is prod-only and locally reproducible on demand.
7. **Docs updated:** AGENTS.md, `09-deployment.qmd`, `08-development.qmd`; the "deferred to #154" notes are replaced with the enrichment-lane resolution.

---

## 3. Architecture & Components

### Component 1 — The enrichment lane (the bulkhead)

A new Compose service `api-enrichment`, a deliberate near-clone of `api` (the same relationship `worker-maintenance` has to `worker`):

- **Image/entrypoint:** `${SYSNDD_API_IMAGE:-sysndd-api:latest}`, `CMD ["Rscript", "start_sysndd_api.R"]` — the full router (every endpoint mounted). Traefik decides what reaches it; the process is not specialised in R.
- **Networks:** `proxy` + `backend` (needs egress for upstreams **and** DB for external cache reads/writes, e.g. the RGD DB lookup and cache persistence).
- **Volumes/env:** mirror `api` (config.yml, `functions`/`core`/`services`/`bootstrap`, `db/migrations`, `data`, `layout`, **shared `api_cache` named volume** so external success caches are warm and fingerprint-consistent across lanes).
- **Startup is subordinate, not authoritative:** `depends_on: api: { condition: service_healthy }`, and it **skips every startup bootstrap** using the *existing* env flags — `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP=false`, `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP=false`, and the pubtatornidd bootstrap flag `=false` (confirm exact name in the plan). The migration runner is advisory-locked and idempotent, so it no-ops after the core `api` has applied migrations; the cheap manifest **validation** still runs (catches a broken `db/migrations` mount). **Net: zero R code needed to make the lane subordinate.**
- **Resource limits:** modest (e.g. `MIRAI_WORKERS=1`, `DB_POOL_SIZE` small); it serves I/O-bound proxy calls, not heavy compute.
- **Healthcheck:** same as `api` (`curl -sf http://localhost:7777/api/health/ready`).

### Component 2 — Traefik routing (path-prefix bulkhead)

Add one router; change nothing the frontend sees (the SPA still calls `/api/...`; Traefik dispatches):

| Router | Rule | Priority | Service |
|---|---|---|---|
| `api-enrichment` (new) | `Host(...) && PathPrefix(`/api/external`)` | **200** | `api-enrichment` |
| `api` (existing) | `Host(...) && PathPrefix(`/api`)` | 100 | `api` (core) |
| `app` (existing) | `Host(...) && PathPrefix(`/`)` | 1 | `app` (SPA) |

More-specific/higher-priority wins, so `/api/external/**` → enrichment, all other `/api/**` → core. The `api-strip-xff-alias` middleware **must** be attached to the enrichment router too (XFF hygiene, #535 S6). The enrichment service defines its own `loadbalancer.server.port=7777`; it carries **no** sticky-cookie labels.

### Component 3 — Retire sticky sessions on the core `api`

Remove the four `traefik.http.services.api.loadbalancer.sticky.cookie*` labels (`docker-compose.yml:258-261`). Rationale: job state is durable in `async_jobs`; per Plumber's hosting guidance sticky sessions are only for *local* state and cost even load distribution. **Accepted residual:** the per-caller in-memory admission throttles (clustering/auth) and the external-time accumulator are per-process; without stickiness a caller's throttle budget is effectively per-replica (already a documented multi-replica caveat). A globally-shared limiter is explicitly out of scope (separate concern). Document this trade-off; do not add stickiness back to paper over it.

### Component 4 — Declared replica floor + independent scaling

- Prod `docker-compose.yml`: `api` → `deploy.replicas: 2` (core floor); `api-enrichment` → `deploy.replicas: 1` (scale via `--scale api-enrichment=N`). `--scale` still overrides for load tests. No `container_name` on either (incompatible with replicas; both already auto-named).
- **The floor is prod-only.** Because the base file is shared, the dev override (`docker-compose.override.yml`) must **pin `api` back to `deploy.replicas: 1`** so `make dev` does not spin two API containers (both re-running startup work) on a memory-constrained laptop.
- Dev keeps one lane: **profile-gate `api-enrichment` out of dev** (`profiles: [prod-enrichment-lane]`, never activated) — identical mechanism to `worker-maintenance`. With the enrichment service absent in dev, its Traefik router is gone too, so `/api/external` falls through to the single dev `api` via the `/api` router. Dev stays one lane; prod is two.

### Component 5 — Make the per-request ceiling a true bound

Fix the pre-call-gate weakness (gap #2) surgically, in `api/functions/external-proxy-*.R`:

- Introduce a small helper so each **individual** internal `httr2` call in a multi-call fetcher is wrapped (ceiling-checked, timed, accumulator-updated) rather than the whole two-call body sharing one wrapper. `fetch_mgi_phenotypes` / `fetch_rgd_phenotypes` re-check `external_proxy_request_ceiling_exceeded()` before their **second** upstream call and short-circuit to the degraded envelope if the first already spent the budget.
- Outcome: a single external request is bounded to ~one provider budget, aligning behaviour with the documented `EXTERNAL_PROXY_REQUEST_MAX_SECONDS`. Single-call fetchers are unaffected. This is defense-in-depth for the *enrichment lane's own* responsiveness (one card request cannot monopolise the lane for ~32s); cheap-route protection is already guaranteed by Components 1–2.

### Component 6 — Boundary-completeness static guard + lane observability

- **Guard:** extend the static-scan family with a test asserting that the set of source files invoking `external_proxy_*` / `fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)` **on a public request path** equals a known allowlist (`endpoints/external_endpoints.R`, plus the explicitly-noted Curator-gated `entity_endpoints.R` create-path GeneReviews residual and worker/job files). A new external-calling public endpoint fails CI until it is either mounted under `/api/external` (enrichment lane) or added to the allowlist with justification. This is the R-side enforcement that the Traefik bulkhead boundary is complete.
- **Observability:** add an optional `API_LANE` env (`core` default, `enrichment` on the new service) and include `lane=` in the `[request-timing]` log line (and optionally in `/api/health`). The only R change beyond Component 5; additive and cosmetic.

### Component 7 — Documentation

- **AGENTS.md:** new "Synchronous API lanes (core vs enrichment)" note mirroring the `worker`/`worker-maintenance` section — the bulkhead, the `/api/external` boundary + allowlist guard, sticky-off rationale, the replica floor, `API_LANE`, and the now-real per-request ceiling. Replace "deferred to #154" references.
- **09-deployment.qmd:** operator guide — the two API services, scaling each, sticky removed, healthcheck, the routing table, the two-lane smoke; update the existing "#154 stopgap: ≥1 replica non-sticky" note to the resolved state.
- **08-development.qmd:** dev runs single-lane; how to bring up the two-lane stack locally to test isolation.

---

## 4. Data Flow (after)

```
Browser → Traefik
  PathPrefix('/api/external')  [prio 200] → api-enrichment pool   (egress + DB; startup bootstraps OFF; sticky-free)
  PathPrefix('/api')           [prio 100] → api (core) pool       (health/auth/statistics/entity/gene/analysis/jobs)
  PathPrefix('/')              [prio 1]   → app (SPA)

Core pool:       no live upstream I/O can ever occupy it (bulkhead).  ≥2 replicas, stateless, no sticky.
Enrichment pool: per-request external time now truly bounded (~1 provider budget); scale replicas independently.
Both pools:      stateless (durable MySQL jobs) → sticky sessions removed.
```

---

## 5. Testing Strategy

| Layer | Test | Asserts |
|---|---|---|
| Unit | extend `test-unit-external-proxy-budgets.R` / new | ceiling re-checked between MGI/RGD's two internal calls → single-request bound holds |
| Unit | new `test-unit-external-fetcher-allowlist.R` | external-fetcher callers on public paths ⊆ known allowlist (boundary completeness) |
| Unit | keep `test-unit-cheap-route-isolation.R`, `test-unit-external-budget-guard.R` | unchanged guarantees still pass |
| Integration | keep/extend `test-integration-slow-provider-isolation.R` | slow provider fast-fails 503 + cheap route bounded (in-process) |
| Compose smoke | new `scripts/` smoke (or `make` target) | two-lane stack: injected upstream latency on `/api/external/*` leaves `/api/health/` fast (the cross-container bulkhead proof that a unit test cannot give) |
| Frontend E2E | keep `slow-provider-resilience.spec.ts` | gene page renders while providers stall (regression) |
| Gate | `make test-api-fast`, `make lint-api`, `cd app && npm run type-check`, `make ci-local` | local CI parity before handoff |

The cross-container isolation guarantee is inherently an infrastructure property; the compose smoke is its authoritative proof, the unit/integration tests protect the in-process pieces (ceiling bound, boundary allowlist).

---

## 6. Risks & Mitigations

- **Second container double-runs startup work.** Mitigated by `depends_on: api healthy` + disabling all three startup bootstraps via existing env flags; the migration runner is advisory-locked/idempotent. Verify no third bootstrap path lacks a flag during planning.
- **Sticky removal breaks a hidden per-instance assumption.** Audited: durable jobs are DB-backed; the only per-process state is best-effort throttles/accumulator (documented caveat). Mitigation: call it out in docs; keep the throttle behaviour per-replica for now.
- **`deploy.replicas` vs the repo's `--scale` habit / dev fixed-ports.** Floor set only in prod compose; dev keeps single instances and profile-gates the enrichment lane out. `--scale` still overrides.
- **Operational cost (+1 service class).** Accepted and intentional — it is the bulkhead. Enrichment is low-resource (I/O-bound); it can even share a host with core.
- **Boundary drift.** The Component 6 allowlist guard fails CI on a new un-laned external caller, preventing silent regressions.
- **Entity-create residual on core.** `POST /api/entity/create` (Curator-gated write) still calls GeneReviews on core; low-frequency and budget-bounded, documented as an accepted residual rather than routed (routing a write sub-path would overcomplicate the boundary). Revisit only if it ever shows in `[request-timing]` as a core-lane offender.

---

## 7. Execution Notes (parallelism)

Independent workstreams once the plan exists:

- **WS-A (infra):** Components 1–4 — `api-enrichment` service, Traefik router, sticky removal, replica floor, dev profile-gate. Touches `docker-compose.yml` + `docker-compose.override.yml`.
- **WS-B (bound fix):** Component 5 — MGI/RGD intra-fetcher ceiling re-check + unit test. Touches `external-proxy-*.R`.
- **WS-C (guard + observability):** Component 6 — allowlist static guard, `API_LANE` in the timing log. Touches `mount_endpoints.R` + a new test.
- **WS-D (smoke + docs):** compose smoke target + Component 7 docs.

WS-A and WS-D coordinate on the compose file; WS-B and WS-C are independent of each other and of WS-A. The compose smoke (WS-D) depends on WS-A landing first.

---

## 8. Optional Phase 2 (future, not in this scope) — cache-first external decoupling

Make `/api/external/*` return cache-hit-or-fast-`202/503` and enqueue a durable `external_refresh` job on a miss; the worker fetches upstream and writes the cache; the frontend's existing SWR skeleton/hide-when-empty already tolerates the "fills on next visit" behaviour. This removes upstream I/O from the request path entirely, making even the enrichment lane cheap. It changes the endpoint contract and cold-cache UX (fewer cards on first visit), so it is deliberately **layered on top of** the bulkhead as a later phase rather than bundled here.
