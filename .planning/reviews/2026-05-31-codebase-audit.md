# SysNDD Codebase Audit — Antipatterns, Bugs & Bottlenecks

- **Date:** 2026-05-31
- **Commit:** `6643a10930c11accaa0ac24f8285338d47810150`
- **Method:** 5 parallel specialist agents mined the `.understand-anything/` knowledge graph (2,128 nodes / 2,501 edges / 14 layers), then **verified every finding against real source** — no graph-only claims. The 3 highest-priority items were independently re-verified by hand.
- **Scoring:** `Priority = Leverage (1–5) × Fixability (1–5)`. Leverage = blast radius if fixed. Fixability = how small/safe the diff is. This produces the "high-leverage **and** easy-to-fix-first" ordering.
- **Confidence flags:** ⭐ = independently confirmed by two agents from different angles.

---

## Verdict

The architecture is **fundamentally sound**. The agents tried and largely *failed* to break the documented invariants (MCP read-only gate, durable async job atomicity, JWT alg-pinning, `unname(params)`, no `TRUNCATE`-in-transaction, `memoise_external_success_only`, config not baked into the image) — a good signal that `AGENTS.md` describes reality, not aspiration.

The real debt clusters in three veins:

1. **A dynamic-filter engine that parses user input as R code** (highest systemic risk).
2. **A public / unauthenticated attack surface** — path traversal in `/restore`, synchronous Gemini generation, uncapped clustering jobs, an over-permissive job-result read.
3. **Hot-path performance** — full-view `collect()` materialization on every list request, N+1 inserts, and a deep-watched full-SVG rebuild.

Most top items are well-scoped fixes, not rewrites.

---

## Resolution status (updated 2026-06-03)

The **Security & Data-Integrity Hardening Sprint** (plan:
`.planning/superpowers/plans/2026-05-31-security-data-integrity-sprint-plan.md`)
shipped as **PR #369** — merged to `master` (merge commit `a952a7bb`), released as
**v0.20.16**, with `make ci-local` green.

**Resolved by the sprint** (Tier 1 + cleanup batch):

| Audit # | Task | Resolution |
|---------|------|-----------|
| #1 | T6 | Filter/sort **column allowlist** (`validate_query_column` / `allowed_columns_for_view`); injected tokens 400 before `parse_exprs`. Guard: `test-unit-filter-column-allowlist.R`. |
| #2 | T7 | `db/migrations/025_create_core_views.sql` codifies `ndd_entity_view`/`users_view`/`search_*`; pristine boot fixed. |
| #3 | T1 | `/restore` path-traversal guard; shared `is_valid_backup_filename()` across `/restore`,`/download`,`/delete`. |
| #5 | T4 | Public LLM cluster-summary is cache-hit-only; generation requires Curator+. |
| #9 | T8 | `page_size` NA guard. |
| #10 | T8 | Dropped per-request `source()` on LLM hot path. |
| #17 | T5 | Public clustering-submit queue-depth cap (503 + `Retry-After`, `ASYNC_PUBLIC_JOB_CAP`). |
| #18 | T3 | `internet_archive` exact-host URL validation + auth. |
| #19 | T2 | `GET /jobs/<id>/status?result_mode=full` gated by `can_read_full_job_result`. Guard: `test-unit-job-result-access.R`. |
| #26 | T8 | Removed un-gated DB `message()`. |
| #27 | T8 | Dropped dead `type_suffix` param in `make_problem_response`. |
| #28 | T8 | `expires_in` driven by `config$token_expiry` (not `config$refresh`). |

**Regressions found & fixed during execution** (also in PR #369 / follow-ups):

- **Modify Entity 500** — `useEntityInfo.loadEntity()` requested `is_active`/`replaced_by`/`details`, which `ndd_entity_view` does not expose, so `select_tibble_fields()` 500'd on every entity selection. Introduced by `a586078a` (v0.20.14), independent of this sprint. Fixed by trimming the field list to view-backed columns (+ vitest/Playwright guards).
- **Mounted sub-routers ignored the RFC 9457 `errorHandler`** (related to #27's area) — plumber does not propagate the root error/404 handler to `pr_mount`ed sub-routers, so classed throws (e.g. `stop_for_bad_request` → `error_400`) surfaced as opaque `{"error":"500 ..."}`. Fixed with a `mount_endpoint()` helper attaching `pr_set_error(errorHandler)` + `pr_set_404(notFoundHandler)` to every sub-router; `select_tibble_fields()` now raises `error_400`; duplicate `Content-Type` header removed. Guard: `test-unit-endpoint-error-handler.R`.

**Still open** (deferred per the sprint's out-of-scope list): Tier 1 frontend items #4,#6,#7,#8,#11,#12; Tier 2 #13,#14,#15,#16,#20,#21,#22,#23,#24,#25; Tier 3 #29–#35. The frontend raw-axios/typed-client migration (#4/#6/#8/#24) and the schema/collation work (#14/#21/#29) are the recommended next sprint.

---

## Master ranking (highest leverage × fixability first)

### 🔴 Tier 1 — Do first (Priority 15–20)

| # | Finding | Cat | Where | L | F | **P** |
|---|---------|-----|-------|---|---|-----|
| 1 | **User filter/sort tokens parsed as R code** (`paste0(column,…)` → `parse_exprs` on `collect()`ed data, no column allowlist) ⭐ | bug/sec | `api/functions/response-helpers.R:248` → `api/functions/endpoint-functions.R:108,235,460,801` | 5 | 3 | **15** |
| 2 | **Core views absent from migrations** — `ndd_entity_view`/`users_view`/`search_*` only in legacy R script → pristine boot is broken | bug | `db/migrations/*` (missing); `db/C_Rcommands_set-table-connections.R:347` | 5 | 4 | **20** |
| 3 | **`/restore` lacks the path-traversal guard `/download` & `/delete` have** (admin-gated, destructive) | sec | `api/endpoints/backup_endpoints.R:284` vs `:460,:560` | 4 | 5 | **20** |
| 4 | **Frontend raw `axios` bypasses typed client** in ~7 composables (hits internal admin/write routes, skips interceptor chain) | antipattern | `app/src/composables/annotations/useAnnotationsApi.ts`, `usePubtatorAdmin.ts`, `useGene{ClinVar,RGD,MGI,AlphaFold}.ts` | 5 | 4 | **20** |
| 5 | **Public unauth GET triggers synchronous Gemini/LLM generation** (cost/DoS; violates cache-only invariant) | sec/bug | `api/endpoints/analysis_endpoints.R:280-317` → `api/functions/llm-endpoint-helpers.R:96`; `api/core/middleware.R:94` | 5 | 3 | **15** |
| 6 | **Bearer header injection is an import side-effect** — raw-axios call sites may ship with no `Authorization` | bug | `app/src/api/client.ts:69` vs `app/src/main.ts:23`; `usePubtatorAdmin.ts:97` | 4 | 4 | **16** |
| 7 | **PubtatorNDDTable re-parses annotation text 2–3×/row/render** (regex parse inside `v-for`) | bottleneck | `app/src/components/analyses/PubtatorNDDTable.vue:167,172,219` | 4 | 4 | **16** |
| 8 | **13 views/components call `apiClient` directly** (endpoint knowledge leaks into presentational layer) | antipattern | `app/src/views/admin/ManageOntology.vue:716`, `app/src/components/small/IconPairDropdownMenu.vue:98`, +11 | 4 | 4 | **16** |
| 9 | **`page_size` coercion → `NA`** breaks pagination slicing (no `suppressWarnings`/guard) | bug | `api/endpoints/analysis_endpoints.R:151,88` | 3 | 5 | **15** |
| 10 | **LLM endpoints `source()` 3 files on every request** (redundant disk I/O + re-parse on hot path) | antipattern | `api/endpoints/analysis_endpoints.R:282-284,313-315`; `api/endpoints/admin_endpoints.R:977` | 3 | 5 | **15** |
| 11 | **`fetchPubtatorStats` = 3-request serial waterfall** (no data dep → `Promise.all`) | bottleneck | `app/src/composables/annotations/useAnnotationsApi.ts:104-115` | 3 | 5 | **15** |
| 12 | **Production `console.log` in hot fetch/render paths** (~17 files; ~10 lines per network fetch) | antipattern | `app/src/composables/useNetworkData.ts:200-279`, `useCytoscape.ts:498` | 3 | 5 | **15** |

### 🟠 Tier 2 — High value (Priority 8–12)

| # | Finding | Cat | Where | L | F | **P** |
|---|---------|-----|-------|---|---|-----|
| 13 | **Full `ndd_entity_view` `collect()` then filter-in-R** on every list request (no pushdown/pagination/cache) ⭐ | bottleneck | `api/functions/endpoint-functions.R:228-235,429-457,745`; `api/endpoints/gene_endpoints.R:106-117` | 4 | 3 | **12** |
| 14 | **Charset/collation fragmentation** (utf8mb3 vs utf8mb4_0900_ai_ci vs utf8mb4_unicode_ci) → cross-table joins kill index use | antipattern | `db/migrations/000_…sql:337,59`; `023_*.sql:56`; `024_*.sql:39` | 4 | 3 | **12** |
| 15 | **N+1 single-row INSERTs in PubTator cache writes** (thousands of round-trips per update) | bottleneck | `api/functions/pubtator-functions.R:252-261,184-192` | 3 | 4 | **12** |
| 16 | **GeneStructurePlot deep-watches whole variant array → full SVG teardown/rebuild on any filter tweak** | bottleneck | `app/src/components/gene/GeneStructurePlotWithVariants.vue:1164-1172,595` | 4 | 3 | **12** |
| 17 | **Public clustering-submit has no rate limit/capacity cap** (unauth queue flood + STRING-db quota abuse) | sec | `api/core/middleware.R:23`; `api/endpoints/jobs_endpoints.R:28,257`; `api/functions/job-manager.R:43` | 4 | 3 | **12** |
| 18 | **`internet_archive` endpoint: unanchored URL regex + IA credential abuse** (unauth GET) | sec | `api/endpoints/external_endpoints.R:36-54`; `api/functions/external-functions.R:30` | 3 | 4 | **12** |
| 19 | **Unauth `GET /jobs/<id>/status?result_mode=full`** returns any job's full result (UUID-gated only) | sec | `api/endpoints/jobs_endpoints.R:920-947`; `api/functions/job-manager.R:120` | 3 | 4 | **12** |
| 20 | **Plumber array-scalar unwrap done inline in templates** (4× ternary, bypasses `unwrapValue`) | antipattern | `app/src/components/analyses/AnalyseGeneClusters.vue:50-65` | 3 | 4 | **12** |
| 21 | **`DOUBLE` join keys vs `INT` parents** (`category_id`, `modifier_id`) → defeats index + float-equality risk | bug | `db/migrations/000_…sql:367,388` vs `:359,91` | 3 | 3 | **9** |
| 22 | **Naive migration SQL splitter** (`strsplit(…, ";\\s*(\n|$)")`) — latent mis-apply, still marks "applied" | bug | `api/functions/migration-runner.R:463` | 3 | 3 | **9** |
| 23 | **`import * as d3`** in 14 modules defeats tree-shaking (~250–280 KB) | bottleneck | `app/src/composables/useD3Lollipop.ts:19` +13 | 3 | 3 | **9** |
| 24 | **Frontend auth/router import cycle** (5-module SCC; infra `client.ts` imports app-layer `useAuth`) | bug(struct) | `app/src/api/client.ts:48-53,78` ⇄ `useAuth.ts`/`auth.ts`/`routes.ts` | 3 | 3 | **9** |
| 25 | **77 service functions lack `svc_`/`service_` prefix** — latent repository-shadowing (no live collision yet) | antipattern | `api/services/*` (`search_genes`, `user_get_list`, `batch_create`…) | 3 | 3 | **9** |

### 🟡 Tier 3 — Cheap wins & lower-leverage (Priority ≤ 10)

| # | Finding | Cat | Where | L | F | **P** |
|---|---------|-----|-------|---|---|-----|
| 26 | **Unconditional `message()` debug log on every DB query** (un-gated stderr I/O) ⭐ | antipattern | `api/functions/db-helpers.R:139` | 2 | 5 | **10** |
| 27 | **`make_problem_response` dead `type_suffix` param** (status passed twice) | antipattern | `api/core/filters.R:260-271` +5 callers | 2 | 5 | **10** |
| 28 | **`expires_in` reported from `config$refresh`, not `token_expiry`**; access == refresh token | bug | `api/services/auth-service.R:71,188,195` | 2 | 5 | **10** |
| 29 | **Missing standalone index on `ndd_review_phenotype_connect.entity_id`** (join key) | bottleneck | `db/migrations/000_…sql:393` | 2 | 4 | **8** |
| 30 | **MCP query/record service cycle** (leaky 2-file split, no real seam) | antipattern | `api/services/mcp-query-service.R` ⇄ `mcp-record-service.R` | 2 | 4 | **8** |
| 31 | **Password-reset invalidator = MD5(salt+password)** (weak primitive; plaintext `collect()`) | antipattern | `api/endpoints/user_endpoints.R:668,744` | 2 | 3 | **6** |
| 32 | **MCP legacy disk-cache scanner `readRDS()`s arbitrary files** (deserialization sink; `:ro`-mitigated) | sec | `api/functions/mcp-analysis-cache-repository.R:15-46` | 2 | 3 | **6** |
| 33 | **Shared `archive_secret_key` reused across all 4 env blocks** (dev compromise = prod) | sec | `api/config.yml:24,52,80,108` | 2 | 3 | **6** |
| 34 | **`useAuth` module-scope 1 Hz `setInterval` never cleared** (always-on timer) | bug | `app/src/composables/useAuth.ts:256-259` | 2 | 3 | **6** |
| 35 | **God files** — 65 source files > 600-line ceiling (`ManageReReview.vue` 1570, `AnalyseGeneClusters.vue` 1270 + fan-out 17) | antipattern | many | 2–4 | 2 | **4–8** |

---

## Tier 1 detail

### 1 ⭐ — User filter/sort tokens parsed as R code (bug / security)
`generate_filter_expressions()` builds expression strings via `paste0(column, " == '", filter_value, "'")`, then `endpoint-functions.R` does `filter(!!!rlang::parse_exprs(filter_exprs))`. On the fallback path the data is `collect()`ed **before** `filter()`, so `parse_exprs` evaluates attacker-influenced text **as R code in the API process** (not just SQL). Only quotes/parens are stripped from `filter_value`; the `column` token is never validated against real view columns.
**Fix:** whitelist every `column`/sort identifier against a per-view allowlist (unknown → 400); build predicates with `.data[[column]]` / `dplyr::sym()` + literals so user text is never parsed as code.

### 2 — Core views absent from migrations (bug)
`ndd_entity_view`, `users_view`, `search_non_alt_loci_view` — the most-queried objects in the codebase — exist only in the out-of-band `db/C_Rcommands_set-table-connections.R` (and a fixture), which `db/migrations/README.md` explicitly says is *not* a supported apply path. A from-scratch boot passes migrations, then 500s on the first entity/gene/user/search query.
**Fix:** add `025_create_core_views.sql` (`CREATE OR REPLACE VIEW …` copied verbatim, DB-name qualifier stripped); bump `EXPECTED_LATEST_MIGRATION` + `EXPECTED_MIGRATION_COUNT` in `api/functions/migration-manifest.R`.

### 3 — `/restore` path traversal (security)
`/download/<filename>` and `/delete/<filename>` both reject path separators (`grepl("[/\\\\]", filename)`) and enforce a `.sql`/`.sql.gz` extension. `/restore` does **neither** — it takes `req$argsBody$filename`, builds `file.path("/backup", filename)`, checks only `file.exists()`, then feeds it to `execute_restore()` into the live DB. Admin-gated, but a real traversal hole into a destructive op.
**Fix:** copy the two guards from download/delete, then `normalizePath()` and assert the result is under `/backup`.

### 4 — Frontend raw `axios` bypasses the typed client (antipattern)
~7 composables hand-build URLs and call `axios.get/post` directly against *internal* routes (admin, jobs, publication, comparisons), bypassing the `app/src/api/*` typed-client contract and the interceptor chain. `usePubtatorAdmin.ts` POSTs to write routes (`/update/submit`, `/clear-cache`, `/backfill-genes`) with bare `axios.post`.
**Fix:** add typed methods to `api/external.ts` / a new `api/pubtator.ts` / extend `api/admin.ts`; route composables through `apiClient`.

### 5 — Public unauth GET triggers synchronous Gemini generation (security / bug)
`require_auth` forwards every tokenless GET as "public read" (`middleware.R:94`); on cache miss the cluster-summary endpoints call `get_or_generate_summary()` inline. Any anonymous client can drive on-demand Gemini calls (cost, latency, rate-limit exhaustion, DoS) — contradicting the documented cache-only invariant.
**Fix:** make these endpoints cache-hit-only on the public path (404/202 + enqueue admin/worker job), or gate generation behind a Curator role.

### 6 — Bearer header injection is an import side-effect (bug)
`plugins/axios.ts` (loaded at startup) registers only `baseURL` + the response 401 interceptor. The **request** interceptor that adds `Authorization: Bearer <token>` lives in `api/client.ts` as a module side-effect — it runs only if some module imports `@/api/client`. Raw-axios composables that send `withCredentials: true` rely on that side-effect already being registered by an unrelated chunk.
**Fix:** move the request-interceptor registration into `plugins/axios.ts` (imported by `main.ts`) so Bearer injection is guaranteed app-wide.

### 7 — PubtatorNDDTable re-parses text 2–3× per row per render (bottleneck)
`parseAnnotations(row.text_hl)` (a regex parse) is called in the `v-for` and again in a sibling `v-if`, with a third re-parse in the expansion slot. No memoization → runs every re-render. Same pattern at `PublicationsNDDTable.vue:194`.
**Fix:** compute parsed segments once (memoized map keyed by row id, or precompute after fetch).

### 8 — 13 views/components call `apiClient` directly (antipattern)
Distinct from #4: these *use* the client but from the wrong layer, putting endpoint knowledge into presentational components (incl. `IconPairDropdownMenu.vue:98` calling `/api/auth/signin`, and `ManageOntology.vue` using the `apiClient.raw` escape hatch).
**Fix:** add typed methods to the relevant `api/*.ts` clients and route the 13 call sites through them.

### 9–12 — see "One cleanup PR" below.

---

## Tier 2 & 3 detail (condensed)

- **13 ⭐** — list endpoints `collect()` the full ~4.2k-row view per request then group/filter/sort in R; push aggregation to SQL + memoise the facet spec.
- **14** — unify to one `utf8mb4` collation; standardize join-key columns (`hgnc_id`, `phenotype_id`).
- **15** — replace the per-row INSERT loop with `DBI::dbAppendTable()` / one prepared statement over column vectors (runs in worker).
- **16** — split watchers (full re-render only on `geneData`/`variants` identity; enter/update/exit for filter changes; drop `deep:true` on the variant array).
- **17** — auth-gate or add a queue-depth/concurrency cap (re-introduce 503 + `Retry-After`) + per-IP token bucket for public submit routes.
- **18** — parse the URL with `httr2::url_parse`, require `host == "sysndd.dbmr.unibe.ch"`, use `stringr::fixed()`, require auth.
- **19** — require ≥Reviewer/Admin for `result_mode="full"` (keep `summary` public if needed).
- **20** — unwrap Plumber scalars at the API client / a `computed`, not inline in templates.
- **21** — migration to `MODIFY … INT` after `SELECT … WHERE col <> FLOOR(col)` confirms no fractional values.
- **22** — document "one statement per line" + add a `test-unit-migration-runner.R` case for a string containing `;`, or replace the splitter with a literal-aware tokenizer.
- **23** — switch to submodule d3 imports (`import { select, scaleLinear } from 'd3'`).
- **24** — inject a token getter into the client (`setTokenProvider()`) instead of `client.ts` importing `useAuth`; collapses the SCC.
- **25** — rename to `svc_`/`service_`, or add a CI static guard that fails on `services/*` ↔ `functions/*` name collisions.
- **26 ⭐** — delete the un-gated `message()`; the level-gated `log_debug` two lines below already covers it.
- **27** — drop the dead `type_suffix` param + update 5 callers.
- **28** — drive `exp` from a single documented `token_expiry`; implement a real refresh token or rename the field.
- **29** — `ALTER TABLE … ADD KEY idx_rpc_entity (entity_id)` (additive, cheap).
- **30** — merge the two MCP service files, or move the shared resolver into `mcp-service.R`.
- **31** — random hashed time-limited reset token (or HMAC-SHA256 over `user_id|password_reset_date`).
- **32** — prefer the snapshot/DB path exclusively; constrain the disk scanner to known filenames.
- **33** — distinct per-env IA credentials, prod secret via `.env`.
- **34** — start the ticker on login / clear on logout, or drive `isExpired` from an on-demand read.
- **35** — extract composables/sub-components when next touching these files; don't grow them further.

---

## The 4 to fix first (highest leverage that's genuinely fixable)

1. **Harden the dynamic-filter engine (#1)** — the single biggest systemic risk; column allowlist + literal-binding.
2. **Add the missing core-views migration (#2)** — restores the pristine-bootstrap guarantee.
3. **Patch `/restore` path traversal (#3)** — 5-minute fix, destructive blast radius.
4. **Make public LLM/cluster paths cache-only + capped (#5, #17)** — closes real cost/DoS vectors.

> These plus the small security items (#18, #19) and the cleanup batch are specced in
> `.planning/superpowers/plans/2026-05-31-security-data-integrity-sprint-plan.md` — **shipped in PR #369 (v0.20.16); see Resolution status above.**

## One cleanup PR (high-fixability batch — #9–12, #26–28)

All ≥ F4, low-risk, touch adjacent code — bundle them: NA-guard `page_size`; delete per-request `source()`; `Promise.all` the Pubtator-stats waterfall; gate/strip prod `console.log` (Vite `drop:['console']`); remove the un-gated DB `message()`; drop the dead `type_suffix` param; fix `expires_in`/`token_expiry`.

---

## What's actually solid

Verified-good (agents tried and could not break these): MCP read-only enforcement (parameterized SQL gated on `is_primary=1 AND review_approved=1`, snapshot-only with `unsupported_parameter` fast-fail, `:ro` cache mount, JSON error envelopes), durable async (`SELECT … FOR UPDATE SKIP LOCKED`, `claim_token` 1-row completion, advisory locks), JWT alg-pinning (`jose` 1.2.1), JSON-body-only auth + log redaction, `unname(params)` in `dbBind`, no `TRUNCATE`-in-transaction, `memoise_external_success_only`, config not baked into the image.

## Caveats

- **Dead-code analysis was inconclusive and deliberately omitted.** The R API sources by path-lists (≈0 `import` edges) and the graph's `calls` set is sparse (210 edges / 1,043 functions), producing false positives (e.g. `api/user.ts` flagged "orphan" despite 4 real importers). Don't trust any dead-code claim from this graph without manual confirmation.
- Severity ratings are engineering judgment; the security items (#3, #5, #17–19, #32, #33) deserve a focused security review before being treated as final triage.

## Appendix — graph metrics

- **Cycles:** 2 file-level dependency cycles (frontend auth/router 5-SCC; MCP query/record 2-SCC); 0 function-level call cycles.
- **Top fan-in hubs:** `app/src/api/client.ts` (41), `useResource.ts` (13), `api/entity.ts` (10).
- **Top fan-out:** `AnalyseGeneClusters.vue` (17), `ManageAnnotations.vue` (13).
- **Complex nodes by layer:** frontend-app 143, api-endpoints 54, api-repository 53.
- **Agents:** API backend, frontend, data-layer, architecture-scale graph, cross-cutting security — each returned 7–12 verified findings; 3 converged across agents (⭐).
