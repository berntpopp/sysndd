# PubTatorNDD — Performance, Stability & Automatic Updates

- **Date:** 2026-06-14
- **Status:** Approved (scope + delivery confirmed via decision gate)
- **Scope owner:** Bernt Popp
- **Surfaces:** `/PubtatorNDD` (publication table), `/PubtatorNDD/PubtatorNDDGenes` (gene prioritization), `/PubtatorNDD/Stats`

## 1. Problem statement

PubTatorNDD caches a fixed neurodevelopmental-disorder (NDD) PubTator3 query, derives a
per-gene prioritization with enrichment metrics, and serves three public pages. Today it is
**manually updated, partially broken, and slow on the gene path**:

| Layer | Finding | Evidence (verified live) |
|---|---|---|
| **DB** | `pubtator_annotation_cache` has **only** a PRIMARY key. The gene view joins on `a.search_id` and filters `a.type='Gene'` + `EXISTS(search_id,type,normalized_id='9606')`, forcing a full **10,660-row** scan per request. | `SHOW INDEX` → PRIMARY only. Migration `005` intended `idx_annotation_search_id`/`idx_annotation_type` but they never materialized in the live DB. |
| **Data** | `pubtator_gene_enrichment` and `pubtator_corpus_stats` are **empty**. The genes endpoint default sort is `-enrichment_ratio,-npmi,publication_count` → it sorts on all-NULL columns, so the ranking is effectively meaningless. | row counts = 0; `async_job_handler_registry` has `pubtator_enrichment_refresh` (async-job-handlers.R:838) but it has never been run. |
| **API speed** | `GET /api/publication/pubtator/genes` ≈ **800 ms**; `GET /api/publication/pubtator/table` ≈ **53 ms**. The genes cost is identical for `page_size=10` and `page_size=2000` because the full view is collected + nested in R *before* pagination. The Stats page reuses `/genes` (`page_size=2000`), so it also pays ~800 ms. | live `curl` timing through Traefik. |
| **Automation** | **No scheduler exists.** New NDD publications are never ingested unless an admin manually triggers an update. | no cron/sidecar/`later` timer found. |
| **Frontend** | `text_hl` is parsed **3×** per row in the table; `PubtatorNDDTable.vue` (948 lines) and `PubtatorNDDGenes.vue` (1141 lines) exceed the 600-line ceiling; D3 stats re-render on every keystroke (no debounce); publication cache is not cleared on filter/sort change (stale data); per-gene fetch errors are swallowed (infinite spinner); `AbortError` handling checks a non-standard `CanceledError`. | component review. |
| **Robustness** | `text_hl` is truncated at 5000 chars on insert (drops `@GENE_` tags past that offset → missed gene symbols); gene-symbol computation can double-count a gene present in both annotation + `text_hl`; some external PubTator calls lack an explicit timeout. | pubtator-functions.R / pubtator-parser.R. |

## 2. Goals / non-goals

**Goals**
1. Make the gene path fast (target: `/genes` p50 well under 200 ms at current scale; no per-request full-view R nesting).
2. Fix the broken enrichment ranking (populate the metrics; degrade gracefully when absent).
3. Make updates **automatic and constant** — a nightly job ingests new publications for the standing NDD query and refreshes enrichment, with no manual action.
4. Fix the identified correctness/robustness bugs.
5. Optimize the frontend (parsing, re-renders, stale cache, error states, component size).

**Non-goals (this milestone)**
- The 719 MB monthly FTP `gene2pubtator3.gz` background-count ETL. The current per-gene memoised PubTator-count path is adequate at ~350 genes; the FTP ETL is recorded as a *future* scale lever, not built now.
- Changing the curated NDD query semantics or the public/MCP data contracts.
- Re-architecting the durable async worker (reused as-is).

## 3. Architecture decisions (locked)

- **Delivery:** one feature branch + PR per sprint; each runs `make pre-commit` / targeted tests; merged via the repo's `gh pr merge --merge` convention with a release bump where appropriate.
- **Scheduler:** a **cron sidecar** compose service (alpine + crond) whose *only* responsibility is to enqueue a durable async job nightly. All heavy logic, retries, partial-failure recovery, and history stay in the existing MySQL-backed worker (already attached to the egress-capable `proxy` network). No in-API timer, no host crontab.
- **Single-flight:** the nightly job acquires a MySQL advisory lock (`GET_LOCK('pubtatornidd_nightly', 0)`); if not acquired, it exits cleanly (mirrors the existing `nddscore_import` serialization pattern).
- **Incremental sync:** PubTator3 has **no date-range search param**, so we use a **PMID set-diff watermark** against `pubtator_search_cache` — fetch the standing query's pages, diff PMIDs, only export annotations for the delta, paced to ≤3 req/s.
- **Server speed:** a **precomputed `pubtator_gene_summary` table** populated by the nightly/enrichment job replaces the per-request `collect()+nest()` path. Atomic refresh via the existing snapshot `is_current`-style activation (or in-txn replace), keyed on a data-aware version. The genes endpoint reads the summary + joins enrichment.
- **Enrichment method:** unchanged (per-gene memoised PubTator background counts via `memoise_external_success_only`), just *actually run* and *scheduled*.

## 4. Sprint plan (parallelizable)

Dependency graph: `A ⟂ E` (fully parallel). `D` depends on `A`. `C` depends on `B`. `B ⟂ A ⟂ E`.

### Sprint A — DB indexing & query speed *(S, low risk; independent)*
- New migration `db/migrations/0XX_add_pubtator_annotation_indexes.sql`:
  - `ADD INDEX idx_annotation_search_type (search_id, type)` on `pubtator_annotation_cache`
  - `ADD INDEX idx_annotation_type_norm (type, normalized_id)` (species existence + `non_alt_loci_set.entrez_id` join)
  - `ADD INDEX idx_search_query (query_id)`, `ADD INDEX idx_search_date (date)` on `pubtator_search_cache`
  - Idempotent: guarded `CREATE INDEX` inside a stored procedure that checks `INFORMATION_SCHEMA` (MySQL 8 has no `CREATE INDEX IF NOT EXISTS`; this is the same working pattern as migration `027`, and the runner handles `DELIMITER`). 005's indexes are missing **not** because its procedure failed but because the out-of-band `db/16_Rcommands` bootstrap recreates the cache tables without indexes — so that script is fixed inline in the same change.
- Update `db/16_Rcommands_sysndd_db_pubtator_cache_table.R` so a pristine bootstrap also gets the indexes.
- Verify `EXPLAIN` no longer shows a full annotation scan; re-time `/genes`.
- Bump `EXPLAIN`/manifest expectations (`EXPECTED_LATEST_MIGRATION`).

### Sprint B — Fix enrichment + graceful degradation *(M; independent)*
- Run `pubtator_enrichment_refresh` to populate `pubtator_corpus_stats` + `pubtator_gene_enrichment` (verify worker egress + advisory lock + atomic `is_current` activation).
- Genes endpoint: when no `is_current` enrichment snapshot exists, **degrade deterministically** (sort fallback to `publication_count` desc) and expose an `enrichment_status` flag (`current` / `stale` / `missing`) + `enrichment_refreshed_at` in the response `meta`, so the frontend can show a "ranking not yet computed / last refreshed …" notice instead of a silent NULL sort.
- Add/extend a unit test asserting the fallback ordering + status flag when enrichment is empty.

### Sprint C — Nightly auto-update *(M; depends on B)*
- New durable async job type `pubtatornidd_nightly` (registered in `async_job_handler_registry`) that, single-flighted via `GET_LOCK`:
  1. fetches new pages of the standing NDD query, set-diffs PMIDs vs. `pubtator_search_cache`, exports annotations only for the delta (≤3 req/s, per-request budget), `INSERT … ON DUPLICATE KEY UPDATE`;
  2. recomputes gene symbols for affected rows;
  3. refreshes enrichment;
  4. refreshes the `pubtator_gene_summary` table (Sprint D);
  5. records a run summary (counts, watermark, status) for observability.
- New compose service `pubtatornidd-cron` (alpine + crond, pinned `TZ`) that nightly enqueues this job via the same mechanism the web API uses. Documented in `09-deployment.qmd`.
- Idempotent + partial-failure safe: re-running re-processes only the delta; enrichment/summary recompute are pure functions of the cache tables.

### Sprint D — Server-side response speed *(M; depends on A)*
- New `pubtator_gene_summary` table (one row per gene: `gene_symbol, hgnc_id, publication_count, entities_count, is_novel, oldest_pub_date, pmids, summary_version, refreshed_at`), populated by the nightly/enrichment job from the view via SQL `GROUP BY` (not R nesting).
- Genes endpoint reads `pubtator_gene_summary` + LEFT JOIN enrichment, filter/sort/paginate (ideally push to SQL); keep the nested `publications`/`entities` payload behind `expand=`/`response_mode=compact` so the default response is lean.
- Cache invalidation keyed on `summary_version`; bump it in the refresh job (don't rely on TTL).
- Enable gzip for these JSON endpoints at Traefik if not already on.

### Sprint E — Frontend perf & UX *(M; fully independent)*
- Pre-parse `text_hl` **once** on data arrival (store `text_hl_parsed`), eliminating 3×/row parsing in the table and per-render parsing in genes.
- Debounce the Stats `minCount`/`topN` watcher (≈300 ms) before D3 re-render; reuse a single SVG root.
- Clear/scope the per-gene publication cache on filter/sort change (fix stale data).
- Fix `AbortError` handling (drop the bogus `CanceledError` branch); add error toasts + exit loading state on per-gene fetch failure.
- Surface the Sprint-B `enrichment_status` ("ranking pending / last refreshed …") in the Genes UI.
- Split `PubtatorNDDTable.vue` / `PubtatorNDDGenes.vue` below the 600-line ceiling by extracting cell renderers / filter bar / pagination into focused components/composables.
- Keep the existing perf/axe bench green.

### Sprint F — Stability/bug fixes *(S; woven into A–E, not a separate PR)*
- `text_hl` truncation: raise/remove the 5000-char cap or parse genes before truncation so late `@GENE_` tags aren't lost.
- Gene-symbol dedup across annotation + `text_hl` sources before `GROUP_CONCAT`.
- Ensure every external PubTator call derives its timeout from `external_proxy_budget(...)` (no hardcoded literals; matches the repo guard).

## 5. Verification

- **DB:** `EXPLAIN` shows index usage, no full annotation scan; re-timed `/genes`.
- **API:** `make test-api-fast` (PR gate) + targeted `testthat` for the genes fallback/status and the summary-table path; live `curl` timing before/after.
- **Automation:** dry-run the nightly job manually (enqueue → worker runs → counts/watermark recorded); confirm `GET_LOCK` single-flight; confirm the cron sidecar enqueues.
- **Frontend:** `npm run type-check`, `npm run test:unit`, lint; the genes/stats perf bench stays green.
- **Repo gates:** `make pre-commit` per sprint; `make ci-local` before the final handoff. Update `AGENTS.md` (new job type, cron sidecar, summary table, enrichment-status contract), `08-development.qmd`, `09-deployment.qmd`.

## 6. Risks & mitigations

- **Indexes dropped by a later table recreation (the real 005 cause):** add the indexes inline in `db/16_Rcommands` so a pristine bootstrap has them too, verify presence via EXPLAIN, and bump the manifest.
- **Worker egress for PubTator at night:** confirm the worker stays on both `backend` + `proxy` networks (already required for Gemini/PubMed/PubTator).
- **Stale precomputed summary:** the refresh job is the sole writer of `summary_version`; endpoints read it; activation is atomic.
- **PubTator search relevance shuffling pages:** walk enough pages to cover the query's full count; nightly re-scan gives eventual consistency.
- **Public-path safety:** no synchronous external/Gemini calls on public routes; nightly work is worker-only; respect the existing public job-capacity cap.
