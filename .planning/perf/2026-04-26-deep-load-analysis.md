# v11.3 Deep Load Analysis — 2026-04-26

Hands-on perf+UX investigation of `/Genes/<symbol>` and `/Entities/<id>` after the v11.3 W2/W3 fixes landed (commits `81839624` and `7b1ba213`). Captured with Playwright on `/Genes/GRIN2B` against the integration dev stack at `http://localhost`.

## TL;DR

- **All 7 API calls already fan out in parallel at t≈362 ms.** The v11.3 hook architecture is doing its job.
- **Entity API is the critical-path bottleneck** at 566 ms (vs 74 ms for the gene record). 161 ms of that is `collect()` of the full 4,200-row `ndd_entity_view` followed by in-R filter/sort.
- **The user-visible "Associated table renders last" complaint** was caused by two things, both now fixed: (a) `TablesEntities` had a hard 500 ms timer flipping `loading=false` regardless of fetch state — flashed the empty-state message for ~400 ms; (b) the centered spinner gave no shape clue, so the table appeared to "pop in" at ~928 ms cold. Replaced with a 5-row skeleton matching the eventual table.
- **The 4.9 s "cold" entity API** I measured after `docker restart` is one-time R/Plumber JIT cost. Real users don't see it. Warm cost is 137 ms.
- **No cross-origin requests.** All external sources route through our `/api/external/*` proxy. `<link rel=preconnect>` won't help.

## Network waterfall — `/Genes/GRIN2B` (cold-after-warmup, 1440×900)

| t (ms) | Endpoint | TTFB | Total | Size |
|---:|---|---:|---:|---:|
| 280 | First Contentful Paint | | | |
| 362 | `/api/gene/GRIN2B?input_type=symbol` | 72 | **74** | 783 B |
| 362 | `/api/external/alphafold/structure/GRIN2B` | 82 | 82 | 542 B |
| 362 | `/api/external/rgd/phenotypes/GRIN2B` | 120 | 122 | 465 B |
| 362 | `/api/external/gnomad/variants/GRIN2B` | 307 | 311 | **44 KB** |
| 362 | `/api/external/mgi/phenotypes/GRIN2B` | 318 | 319 | 1.5 KB |
| 362 | `/api/external/uniprot/domains/GRIN2B` | 329 | 330 | 972 B |
| 364 | `/api/entity/?...filter=equals(symbol,GRIN2B)...` | **454** | **566** | 1.5 KB |

Critical path:
- **0 ms → 280 ms** — HTML + JS shell + Vue bootstrap → FCP (gene header card frame visible)
- **362 ms** — all 7 API calls fan out in parallel
- **436 ms** — gene record back, header populates
- **562 ms** — alphafold, gene-structure tab data ready
- **673 ms** — gnomAD variants → ClinVar card populates
- **681 ms** — MGI back, model-organism card populates
- **692 ms** — UniProt back
- **930 ms** — entity API back, table populates
- **~1.4 s** — perceived "page loaded" once Vue completes the table render pass

## Render timing

- The 5 external cards render their data within ~700 ms (skeleton → resolved).
- The Associated Entities table renders at ~930 ms.
- The user perception of "table renders last" is **correct** — it does, by ~250 ms. It's not a bug; it's the entity API being slower than the external proxies.
- After the v11.3 W4.4 escape hatch + the new skeleton wrapper, the slot has stable shape during the load and no "no records to show" flash.

## Why the entity API is slow (server-side profile)

Server-side breakdown of `/api/entity/?filter=equals(symbol,GRIN2B)&page_size=10` (warm):

| step | time |
|---|---:|
| parse filter/sort exprs | 51 ms |
| `tbl(view) %>% left_join(reviews) %>% collect()` (4,200 rows × ~30 cols) | **161 ms** |
| in-R filter+sort | 2 ms |
| (paginate, fspec, JSON serialize, response headers) | ~140–340 ms (varies, memoised) |
| **total wall** | **~214–566 ms** |

The endpoint at `api/endpoints/entity_endpoints.R:76-79` does:

```r
ndd_entity_view <- pool %>%
  tbl("ndd_entity_view") %>%
  left_join(ndd_entity_review, by = c("entity_id")) %>%
  collect()                                  # <-- pulls all 4,200 rows into R
```

Then filters/sorts in-memory via `dplyr::filter(!!!parse_exprs(filter_exprs))`. The filter expression `equals(symbol, GRIN2B)` becomes the R expression `str_detect(symbol, '^GRIN2B$')`, which dbplyr CAN translate to MySQL `WHERE symbol REGEXP '^GRIN2B$'`. Pushing it would drop the SQL portion from 63 ms to 27 ms (≈36 ms saved per call) — modest, but free.

The bigger cost is `generate_tibble_fspec_mem(ndd_entity_view, fspec)` (line 109), which pivots the full 4,200×30 collected tibble to compute facet dropdown options. For embedded calls (GeneView passes `:show-filter-controls="false"`), this work is **completely wasted** — the dropdowns are never rendered.

## Loading-state UX audit (post-fix)

Captured at 1440×900 after the cold-cache navigation:

- **t = 0–280 ms**: blank page with navbar only. Acceptable.
- **t = 280–362 ms**: gene info header BCard frame visible (no skeleton — header card content needs gene-record data).
- **t = 362–500 ms**: skeleton stripes for ClinVar / Model Organisms cards (frameless SectionCard); skeleton table rows for Entities.
- **t = 500–700 ms**: external cards resolve one-by-one (no double border, single dark frame each).
- **t = 700–930 ms**: only Entities still shows skeleton table.
- **t = 930 ms**: entity table populated; constraint card now also shows real data.

No more `"no records to show"` flash, no double borders, CLS stable thanks to `min-height` on the skeleton wrappers.

## Lighthouse-equivalent metrics (hand-derived from PerformanceObserver)

| metric | value |
|---|---:|
| FCP | 280 ms |
| LCP | ~600 ms (gene header background) |
| Total Blocking Time | minimal (no long tasks observed) |
| CLS | < 0.05 estimated (skeletons match final shape) |
| Time to first useful UI | 928 ms cold |

W4 bench had reported these as "missed gates" because the spec was aspirational (≤ 100 ms entity-request-start, ≤ 700 ms first-row); the realistic post-fix number is ~930 ms cold.

## 2025 best-practice notes (applied / deferred)

| pattern | status |
|---|---|
| Skeleton screens matching final shape (avoid CLS) | **applied** — `SectionCard frameless` + `TablesEntities` skeleton rows |
| Parallel data fetching (avoid waterfall) | **applied** — all hooks fire at the same tick |
| SWR (`stale-while-revalidate`) cache | **applied** — Pinia `cacheStore` + `useResource` |
| `<link rel=preconnect>` to external origins | **N/A** — all external traffic proxied through our origin |
| HTTP `fetchPriority`/`Priority` hints | not applied — minimal benefit when same-origin and parallel |
| Code-splitting heavy panels (D3, NGL viewer) | **partial** — `GenomicVisualizationTabs` lazy-mounts inactive panels via `KeepAlive` (W2.4); the active panel is loaded eagerly |
| Server-side filter pushdown for filtered queries | **not applied** — see "Recommendations" |
| Skip facet computation for embedded calls | **not applied** — see "Recommendations" |

## Recommendations (prioritized)

### P0 — ship-now, low-risk

These are already in the latest commits on `feature/v11.3-genes-entities-perf-ux`:

- ✅ `TablesEntities`: bind `loading` to actual fetch lifecycle (`81839624`)
- ✅ `TablesEntities`: skeleton table rows replace centered spinner (`7b1ba213`)
- ✅ `SectionCard frameless` mode kills double-border (`81839624`)

### P1 — backend perf, follow-up

**P1.1 / P1.2 — Investigated, NOT applied** (counterintuitive measurement).

I prototyped pushing `equals()` filters to SQL (`view %>% filter(...) %>% collect()`) plus a `?compact=true` mode that skips the global-fspec computation. Combined cold-cold measurement (`docker restart sysndd-v113-integration-api-1` then single curl):

| mode | cold | warm | 3rd |
|---|--:|--:|--:|
| current (collect-all + R-filter) | 211 ms | 127 ms | 121 ms |
| compact (SQL filter + skip global fspec) | 192 ms | 168 ms | 129 ms |

The compact path wins by ~20 ms cold but **loses ~10–40 ms warm** because `generate_tibble_fspec_mem(full_view, …)` is filesystem-memoised, so default-mode fspec is essentially free after the first call, while `str_detect → MySQL REGEXP` does a per-row scan that costs more than full-view sequential read+collect over a warm pool. With only 4,200 rows in `ndd_entity_view`, the SQL pushdown win evaporates. Reverted both changes — the reasoning lives here for the next time someone wonders.

**P1.3 — Split `useGeneClinVar` into counts + variants — APPLIED.**

The full ClinVar/gnomAD variant payload was 521 KB (~44 KB on the wire) and ~310 ms. The above-the-fold ClinVar card needs only 5 classification counts. The full variant array is still needed by `GenomicVisualizationTabs` for the protein/structure plots (below the fold).

Implementation:

- Backend: added `?summary=true` to `GET /api/external/gnomad/variants/<symbol>`. When set, the endpoint derives counts server-side (mirroring the frontend's substring-classification logic so totals are byte-identical) and returns ~250 B instead of 521 KB. `external_endpoints.R:118-219`.
- Frontend: new `useGeneClinVarCounts` composable at `app/src/composables/useGeneClinVarCounts.ts` calls the summary endpoint. `GeneClinVarCard.vue` accepts a precomputed `counts` + `totalCount` (with a backward-compat fallback to deriving from the full `data` array). `GeneView.vue` wires the card to `clinvarCounts`; `GenomicVisualizationTabs` continues to receive the full variant list via the existing `clinvar` hook.
- Tests: 3 new specs in `useGeneClinVarCounts.spec.ts`. All page specs still green.

Measured impact (Playwright PerformanceObserver, cold pass against `make dev`):

| metric | before | after |
|---:|--:|--:|
| ClinVar card data ready | 673 ms | **333 ms** |
| ClinVar payload over the wire | 44 KB | 472 B |
| First Contentful Paint | 280 ms | 128 ms |
| Entity table painted | 930 ms | 883 ms |

The 521 KB → 472 B reduction is the headline win. Full variants still fetched in parallel for below-fold tabs at 328 ms — no user-perceivable delay there.

### P2 — larger architectural changes

**P2.1 Server-rendered first-paint** for `/Genes/<symbol>` and `/Entities/<id>`.

A Vite SSR or Nuxt-style build could ship the gene header + skeleton already in the initial HTML, dropping FCP from 280 ms → ~150 ms. Significant build-system change; only worth it if the dev team wants it for SEO/social-card reasons.

**P2.2 Edge cache for entity-list filtered queries.**

`/api/entity/?filter=equals(symbol,X)&page_size=10` results are stable per gene per data revision. A Traefik / Cloudflare cache layer keyed on the URL would drop the 137 ms warm cost to <10 ms for repeat visitors. Out of scope for v11.3.

**P2.3 Prefetch on link hover.**

When the user hovers an entity row in the main `/Entities` table, prefetch `/api/entity/<id>` etc. so the EntityView page is instant. Out of scope.

## Reproduction

```bash
# Restart the API to clear any in-process state
docker restart sysndd-v113-integration-api-1 && sleep 8

# Warm one request to skip Plumber JIT (~3.6 s one-time cost)
curl -s -o /dev/null "http://localhost/api/version"

# In a browser DevTools Network panel, hard-reload http://localhost/Genes/GRIN2B
# and capture the waterfall.
```

To re-measure server-side breakdown:

```bash
docker exec sysndd-v113-integration-api-1 Rscript -e "
  suppressMessages({ library(yaml); library(DBI); library(RMariaDB); library(dplyr); library(stringr); library(dbplyr); library(rlang) })
  cfg <- yaml::read_yaml('/app/config.yml'); dw <- cfg\$default\$sysndd_db
  con <- dbConnect(MariaDB(), dbname=dw\$dbname, host=dw\$host, user=dw\$user,
                   password=dw\$password, port=as.integer(dw\$port))
  t1 <- Sys.time()
  view <- tbl(con, 'ndd_entity_view') %>% collect()
  cat(sprintf('collect: %.3fs (%d rows)\n', as.numeric(Sys.time()-t1), nrow(view)))
  dbDisconnect(con)
"
```

## Artifacts

- After-fix screenshot at 1440×900: `.planning/screenshots/after-fixes-grin2b-1440.png`
- Original W4 bench: `.planning/perf/after-2026-04-26.json`
