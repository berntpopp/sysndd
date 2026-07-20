# Enrichment-lane bulkhead (#344) — live two-lane isolation evidence

Companion to `2026-06-13-slow-route-344-before-after.md` (which measured the
per-request budgets/ceiling that PR #386/#413 shipped). This doc records the
**structural bulkhead** added to close the remaining #344 gap: a dedicated
`api-enrichment` process lane so a slow `/api/external/*` request can never
head-of-line-block cheap routes. It captures the live two-lane Docker
verification and the **counterfactual** (scale the lane away → the blocking
returns), i.e. proof the fix is load-bearing.

Date: 2026-07-20. Branch: `feat/enrichment-lane-344`.

## Stack under test

An **isolated** copy of the production compose (`docker-compose.yml`, no dev
override) brought up as its own compose project (`enr344`, Traefik on host
`:8099`, fresh project-scoped volumes/networks) so it does not disturb the
developer's running `sysndd` stack. Services: `traefik`, `mysql` (fresh),
`api` (core, **2 replicas** per the new `deploy.replicas: 2` floor),
`api-enrichment` (**1 replica**, `API_LANE=enrichment`). Requests use
`Host: sysndd.dbmr.unibe.ch`/`localhost` (both matched).

External endpoints do not depend on gene seeding — they proxy live upstreams
keyed by symbol — so an empty DB is sufficient for this isolation evidence
(same caveat noted in the 2026-06-13 doc). Cold symbols are used so each burst
does real upstream I/O; distinct symbols per phase avoid the shared success
cache short-circuiting the burst.

## 1. Routing is correct (application-log proof)

`GET /api/external/gene/SCN2A` (cold) and `GET /api/health/` were issued; the
`[request-timing]` lines from each container's `/app/logs/plumber_*.log`:

```
# api-enrichment container:
[request-timing] lane=enrichment method=GET path=/gene/SCN2A status=200 duration_ms=10523 external_ms=11515 slow=true
[request-timing] lane=enrichment method=GET path=/ready     status=200 duration_ms=3     external_ms=0     slow=false
# core api-1 / api-2 containers:
[request-timing] lane=core method=GET path=/ready status=200 duration_ms=4 external_ms=0 slow=false
[request-timing] lane=core method=GET path=/      status=200 duration_ms=1 external_ms=0 slow=false
```

`/api/external/*` (11.5s of upstream I/O) lands on `lane=enrichment`; core/cheap
routes land on `lane=core`. Traefik routers (from its own API): `api-enrichment`
`PathPrefix(/api/external)` @ priority 200; `api` `PathPrefix(/api)` @ 100.

## 2. `make smoke-lane-isolation` — PASS

24 concurrent cold `/api/external/gene/GRIN2B` saturating the enrichment lane,
while probing `/api/health/` on core:

```
[smoke] saturating the enrichment lane: 24 concurrent /api/external/gene/GRIN2B
[smoke] /api/health/ probe 1..8: 22 15 16 14 15 11 17 12 (ms)
[smoke] PASS: /api/health/ stayed under 1500ms (worst 22ms) under enrichment-lane saturation.
```

## 3. Counterfactual — the fix is load-bearing

Each phase bursts 24 concurrent cold `/api/external/gene/<symbol>` and probes
`/api/health/` 16× (0.5s apart). Lane topology changed with **targeted**
`docker stop/start` (not `compose up --scale`, which would reconcile the whole
project against the developer stack's fixed-name services).

| Phase | Topology | burst symbol | `/api/health/` min / median / **MAX** |
|---|---|---|---|
| **A** two-lane (isolated) | enrichment=1, core=2 | SCN8A | 9 / 15 / **17 ms** |
| **B** counterfactual | enrichment=**0**, core=2 | GRIN2A | 9 / 15 / **11,619 ms** |
| **B2** single-process | enrichment=**0**, core=**1** | CHD2 | 13 / 15 / **78,688 ms** |
| **C** restored | enrichment=1, core=2 | ADNP | 9 / 15 / **18 ms** |

- **A / C (bulkhead present):** `/api/health/` never exceeds ~18 ms while the
  enrichment lane is saturated with real upstream I/O. The core lane is
  structurally unoccupiable by external calls.
- **B (enrichment scaled to 0):** with the enrichment router gone, `/api/external`
  falls back onto the core `api`, and a `/api/health/` probe is blocked **11.6 s**
  behind an external request — the #344 head-of-line blocking returns.
- **B2 (also core scaled to 1):** the pre-#344 single-process reality — a
  `/api/health/` probe is blocked **78.7 s**. This reproduces the 2026-05-18
  production incident exactly.
- **C:** restoring the lane returns `/api/health/` to ~18 ms. Fix re-applied.

(The 2-replica core in B only *partially* masks the blocking — median stays
15 ms because the second replica sometimes serves the probe — but the MAX makes
the regression unambiguous; B2 removes the masking entirely.)

## 4. Per-request external ceiling is a true bound (MGI two-call fetcher)

Cold vs warm cache on the two-call MGI fetcher (`lane=enrichment`):

```
MGI CHD2 cold: http=200 time=0.355s   [request-timing] external_ms=673  (step1 phenotypes + step2 zygosity)
MGI CHD2 warm: http=200 time=0.059s   [request-timing] external_ms=0    (success cache)
```

The zygosity (step-2) call is now gated on the per-request ceiling. Proven in
the **deployed** enrichment container's R runtime (not just a host unit test) —
the bind-mounted `external-proxy-mgi.R` branches on the guard at line 120, and
the deployed helper behaves correctly:

```
# docker exec enr344-api-enrichment-1 Rscript … external-proxy-functions.R
accumulated=10s, ceiling=15s
  step1 took 2s  -> would_exceed(2000) = FALSE  (step2 zygosity RUNS)
  step1 took 6s  -> would_exceed(6000) = TRUE   (step2 zygosity SKIPPED)
```

So a single MGI request can no longer drive ~2× a provider budget (~32 s) past
the documented 15 s ceiling; step-1 phenotypes are still returned.

## 5. Static / unit coverage (host)

- `test-unit-api-lane.R`, `test-unit-external-proxy-request-bound.R`,
  `test-unit-external-fetcher-allowlist.R` — PASS (new guards).
- `test-unit-cheap-route-isolation.R`, `test-unit-external-budget-guard.R` — PASS
  (no regression).
- Full fast gate `make test-api-fast`: `[ FAIL 0 | WARN 97 | SKIP 142 | PASS 8285 ]`.
- `make lint-api` clean (196 files); `cd app && npm run type-check` exit 0.
- `docker compose -f docker-compose.yml config` parses; sticky labels = 0; core
  `api` `replicas: 2`; enrichment router `PathPrefix(/api/external)` @ 200.
  Dev merge (`docker compose config`) excludes `api-enrichment` and pins `api`
  `replicas: 1`.

## Notes / caveats

- The literal browser gene-page monkey test (open `/Genes/SCN2A` while hammering
  the lane) was not run in this isolated stack because it has no `app` container
  and an empty DB (an unseeded gene redirects to the SPA 404 — the same
  constraint documented on 2026-06-13). The HTTP-level saturation above exercises
  the identical server-side isolation the browser test would rely on; frontend
  resilience itself is locked separately by
  `app/tests/e2e/slow-provider-resilience.spec.ts`.
- Phase C initially showed transient spikes for ~1 probe after `docker start`
  (Traefik re-registering the enrichment router); the clean Phase C above was
  measured after confirming `/api/external` routed back to `lane=enrichment`.
