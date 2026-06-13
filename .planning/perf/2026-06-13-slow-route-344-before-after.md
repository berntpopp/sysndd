# Slow-route hardening (#344) — Gene detail page external-card baseline

Task 11 baseline measurement. READ + MEASURE only; no application source modified.

Goal: prove (later) that slow/failing external providers (MGI / RGD / gnomAD /
UniProt / AlphaFold / GeneReviews) do not block the gene detail page render.

## Before (baseline)

### Stack / environment notes (important caveat)

The task named `http://localhost:8088` as the "healthy, seeded full stack". In
this environment that is not accurate:

- **Port 8088** = the **Playwright isolated stack**
  (`sysndd_playwright_traefik` -> `sysndd_playwright_api` ->
  `sysndd_playwright_mysql`). The SPA serves cleanly (HTTP 200, `<title>SysNDD</title>`,
  `#app` present) and the API is up, but the DB is **schema/lookup only — 0 genes,
  0 entities** (`ndd_entity_view` = 0, `non_alt_loci_set` = 0; `/api/entity/`
  `totalItems = 0`). No gene detail page can fully render there; the SPA redirects
  any `/Genes/<symbol>` to `/PageNotFound` because the gene record hook resolves empty.
- **Port 80** = the **dev stack** (`sysndd_traefik` -> dev API `sysndd-api-1` ->
  `sysndd_mysql`). The DB **is seeded** (4200 entities; ARID1B/SCN2A/MECP2 resolve),
  but the SPA route `GET /Genes/<symbol>` **504s** through that traefik (frontend not
  reliably served on that path), and `sysndd-api-1` was observed flapping/restarting.

Net: no single stack offered *both* a seeded gene record *and* a cleanly served SPA
route. The external-provider endpoints, however, do **not** depend on entity seeding
(they proxy to live external providers keyed by gene symbol), so the API-side timing
evidence below is valid and is the primary baseline. The Lighthouse run is recorded
with a strong caveat.

### Gene page URL + symbol

- Frontend route: **`/Genes/:symbol`** — `app/src/router/routes.ts:500`
  (name `Gene`, component `@/views/pages/GeneView.vue`).
- URL used: **`http://localhost:8088/Genes/ARID1B`** (and the seeded API
  `http://localhost:80/api/gene/ARID1B?input_type=symbol` for data/timings).
- Symbol used: **ARID1B** (HGNC:18040). Verified seeded on port 80
  (`/api/gene/ARID1B` returns a full record). GRIN2B/ARID1B/SCN2A/MECP2 all 404/empty
  on the 8088 Playwright DB; ARID1B/SCN2A/MECP2 resolve on the port-80 seeded DB.

### External-card architecture — VERDICT: RESILIENT (non-blocking, per-card)

Each external provider is loaded by its own per-source SWR hook
(`app/src/composables/useResource.ts` + Pinia `cacheStore`) and rendered inside an
independent `<SectionCard>` (skeleton + error + hide-when-empty). The page shell does
**not** `await` any external response before rendering. Confirmed both statically and
dynamically.

Per-source hooks & endpoints:

| Provider     | Hook / file                                              | Endpoint                                              |
|--------------|----------------------------------------------------------|-------------------------------------------------------|
| Gene record  | `useGeneRecord.ts`                                       | `GET /api/gene/<input>?input_type=hgnc\|symbol` (60s) |
| gnomAD (ClinVar summary) | `useGeneClinVarCounts.ts`                    | `GET /api/external/gnomad/variants/<sym>?summary=true`|
| gnomAD (ClinVar list)    | `useGeneClinVar.ts`                          | `GET /api/external/gnomad/variants/<sym>`             |
| AlphaFold    | `useGeneAlphaFold.ts`                                    | `GET /api/external/alphafold/structure/<sym>`         |
| UniProt      | `useGeneUniProt.ts` -> `getUniprotDomains()`             | `GET /api/external/uniprot/domains/<sym>`             |
| MGI          | `useGeneMGI.ts`                                          | `GET /api/external/mgi/phenotypes/<sym>`              |
| RGD          | `useGeneRGD.ts`                                          | `GET /api/external/rgd/phenotypes/<sym>`              |

Cards: `GeneConstraintCard.vue` (gnomAD constraints from DB record),
`GeneClinVarCard.vue` (gnomAD/ClinVar), `ModelOrganismsCard.vue` (MGI + RGD),
plus UniProt/AlphaFold/Ensembl consumed by the lazy `GenomicVisualizationTabs`
panels (`ProteinDomainLollipopPlot`, `GeneStructurePlotWithVariants`,
`ProteinStructure3D`). API client: `app/src/api/external.ts`.

Load-bearing evidence (file:line):

- All external hooks are declared side-by-side with **no `await`** —
  `app/src/views/pages/GeneView.vue:216` (`useGeneRecord`), and
  `:238-243` (`useGeneClinVarCounts`, `useGeneClinVar`, `useGeneAlphaFold`,
  `useGeneUniProt`, `useGeneMGI`, `useGeneRGD`). The only `await` in the script is
  inside the user-triggered `retryAllExternalData()` (`:262`).
- `useResource` returns its refs synchronously and fires the fetch **non-awaited** in
  the background: `app/src/composables/useResource.ts:178` (`void activate(next)`)
  under `{ immediate: true }` (`:180`); returns `{ data, error, loading, ... }` at `:187`.
- Each card is wrapped in `<SectionCard>` with per-card `loading` / `empty` / `error`
  bound to that card's own hook: `GeneView.vue:85-89` (Constraint, `:loading="geneRecord.loading.value"`),
  `:100-104` (ClinVar, `:error="clinvarCounts.error..."`),
  `:121-129` (Model Organisms, `:loading="mgi.loading.value && rgd.loading.value"`).
- Partial-failure tolerance: `modelOrgError` is non-null **only when BOTH** MGI and RGD
  fail (`GeneView.vue:259-263`), so one slow/failing provider does not break the card.
- Dynamic confirmation (headless Chrome / Playwright against 8088): on mount the page
  fired **all** external hooks in parallel — observed requests included
  `/api/gene/ARID1B`, `gnomad/variants?summary=true`, `gnomad/variants`,
  `alphafold/structure`, `uniprot/domains`, `mgi/phenotypes`, `rgd/phenotypes`. The
  shell did not block on them. (Note: the 8088 build sent the gnomad/alphafold/mgi/rgd
  calls to the prod host `https://sysndd.dbmr.unibe.ch` while gene/uniprot used the
  relative local path — a build-config detail, not a blocking-architecture concern.)

Conclusion: the gene page is **already resilient** by design — there is no component
that blocks the page shell or sibling cards on an external response. The remaining
risk surface for #344 is therefore API-side latency/timeouts of the individual
external endpoints (below), not front-end render blocking.

### External endpoint API timings (curl, ARID1B)

Run against the running stacks. Cold = first hit (no cache), Warm = immediate 2nd hit.

Port 80 (seeded dev API):

| Endpoint                       | Cold HTTP / time     | Warm HTTP / time     |
|--------------------------------|----------------------|----------------------|
| `external/uniprot/domains`     | 200 / 1.507 s        | 200 / 0.043 s        |
| `external/alphafold/structure` | 200 / 0.071 s        | 200 / 0.725 s        |
| `external/mgi/phenotypes`      | 200 / 1.092 s        | 200 / 0.059 s        |
| `external/rgd/phenotypes`      | 200 / 1.418 s        | 200 / 0.093 s        |
| `external/gnomad/constraints`  | **503 / 6.091 s**    | 503 / 0.278 s        |

Port 8088 (Playwright API, same endpoints — DB-independent external proxies):

| Endpoint                       | Cold HTTP / time     | Warm HTTP / time     |
|--------------------------------|----------------------|----------------------|
| `external/uniprot/domains`     | 200 / 0.037 s        | 200 / 0.011 s        |
| `external/alphafold/structure` | 200 / 0.730 s        | 200 / 0.292 s        |
| `external/mgi/phenotypes`      | 200 / 1.151 s        | 200 / 0.061 s        |
| `external/rgd/phenotypes`      | 404 / 0.067 s        | 404 / 0.087 s        |
| `external/gnomad/constraints`  | **503 / 6.086 s**    | 503 / 0.242 s        |

Key observations:

- **gnomAD constraints is the slow/failing provider**: cold request hung ~6.0 s before
  returning **503** (`gnomAD API returned HTTP 502`, problem+json
  `https://sysndd.org/problems/external-api-failure`, `source:"gnomad"`). This ~6 s is
  the per-request external budget fast-failing a bad upstream — exactly the
  worst-case the #344 hardening targets. On the warm hit it fast-failed at ~0.25 s.
- UniProt / MGI / RGD cold times are ~1.1-1.5 s and drop to <0.1 s warm (7/14/30-day
  external success caches working as designed).
- The slow gnomAD call is isolated to its own card; per the architecture above it does
  not delay the gene record, the page shell, or sibling cards.

### Lighthouse (performance, desktop)

Lighthouse **ran** (`npx --yes lighthouse`, v13.4.0, system `google-chrome` at
`/usr/bin/google-chrome`, `--headless=new`). Report saved to
`.planning/perf/lh-genes-before.json`.

**Caveat — these numbers are NOT a valid gene-page baseline.** Because the 8088 DB has
no ARID1B record, the SPA redirected `/Genes/ARID1B` to **`/PageNotFound`**
(`finalDisplayedUrl: http://localhost:8088/PageNotFound`). The score below therefore
reflects the lightweight 404 page, not a populated gene detail page with mounted
external cards. It is recorded only for completeness; the curl timings are the
authoritative external-latency evidence for #344.

| Metric                       | Value (PageNotFound, NOT gene page) |
|------------------------------|-------------------------------------|
| Performance score            | 97                                  |
| First Contentful Paint (FCP) | 0.9 s                               |
| Largest Contentful Paint (LCP)| 1.2 s                              |
| Total Blocking Time (TBT)    | 0 ms                                |
| Cumulative Layout Shift (CLS)| 0                                   |
| Speed Index                  | 0.9 s                               |
| Time to Interactive          | 1.2 s                               |

To get a representative gene-page Lighthouse number, a stack is needed that serves the
SPA **and** has a seeded gene record on the same origin (neither port 8088 nor port 80
satisfied both during this measurement).

## After (hardening applied)

The #344 hardening is **backend latency/timeout work**, so the meaningful "after"
evidence is (a) bounded worst-case external latency, (b) per-request external-time
attribution in the logs, and (c) an empirical proof that the gene page renders while
external providers are stalled. Lighthouse measures *normal-path* render performance,
which this change does not alter (it changes *degraded-mode* timeout behavior), so a
Lighthouse delta is not the right instrument here — the Playwright resilience spec is.

### 1. Bounded worst-case external latency (the actual fix)

Three calls that previously bypassed `external_proxy_budget()` are now bounded:

| Call (before → after)            | Before (worst case) | After (default budget)            |
|----------------------------------|---------------------|-----------------------------------|
| UniProt step-2 features fetch    | `req_timeout(30)` + `max_seconds=120`, 5 tries → **~120 s** | `external_proxy_budget("uniprot")` → 6 s timeout / 10 s window |
| GeneReviews E-utilities          | `req_timeout(30)`, 3 tries → **~30 s+** | `external_proxy_budget("genereviews")` → 6 s / 10 s |
| gnomAD-batch chunk request       | `req_timeout(30)`, `max_seconds=30` | `external_proxy_budget("gnomad_batch")` → 20 s / 30 s (tunable; worker-only) |

Plus a **global per-request external-time ceiling** (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`,
default 15 s) short-circuits any further external work in a request once the ceiling is
crossed — covering single-endpoint paths the 12 s aggregate budget never governed.
A static guard (`test-unit-external-budget-guard.R`) now fails CI if any external
fetcher reintroduces a hardcoded timeout literal (this exact regression happened once
already via GeneReviews / PR #389).

### 2. Per-request external-time attribution (live, dev stack)

The postroute hook now emits a structured, greppable line (to `/app/logs/plumber_*.log`):

```
[request-timing] method=GET path=/                       status=200 duration_ms=1   external_ms=0   slow=false
[request-timing] method=GET path=/uniprot/domains/SCN2A  status=200 duration_ms=928 external_ms=926 slow=false
[request-timing] method=GET path=/ready                  status=200 duration_ms=3   external_ms=0   slow=false
```

Cheap routes show `external_ms=0`; the external route's 928 ms is 926 ms external —
slowness is now directly attributable to external time, with a `slow` flag over
`API_SLOW_REQUEST_MS` (default 2000).

### 3. Empirical frontend resilience proof (Playwright)

`app/tests/e2e/slow-provider-resilience.spec.ts` delays **every** `/api/external/**`
response by 20 s, then loads `/Genes/SCN2A`:

- **Result: PASS in 3.1 s** (against the seeded Vite stack, `PLAYWRIGHT_BASE_URL=http://localhost:5173`).
- The gene header (`h1.gene-page-title` = SCN2A) and the external card frames rendered
  in ~3 s while all providers were stalled for 20 s → the slow providers did **not**
  block the page shell. This confirms the "already resilient" architecture verdict above
  and locks it in as a regression check.

### Measurement-environment notes

- `sysndd-api-1` / `sysndd-worker-1` had been crash-looping because `api/config.yml` was
  clobbered by the playwright CI config (real dev config restored from
  `api/config.yml.devbackup`). Both healthy after restore.
- A plain `docker restart sysndd-api-1` changes the container IP and leaves
  `sysndd_traefik` routing to the stale backend (504 on `:80/api/*`); restart Traefik
  (or use `docker compose ... up`) to force backend re-discovery. The Vite dev server on
  `:5173` (seeded SPA + working `/api` proxy) is the reliable local measurement target.
- A representative *production-build* gene-page Lighthouse number still requires a stack
  that serves the built SPA **and** a seeded gene record on one origin (8088 is
  schema-only; the `:80` Traefik→app route 504s; `:5173` is an unoptimized dev build).
  Not chased here because it does not measure the degraded-mode behavior #344 changes.
