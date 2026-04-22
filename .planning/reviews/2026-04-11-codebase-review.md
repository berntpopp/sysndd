# SysNDD Codebase Review — Consolidated

**Date:** 2026-04-11
**Branch:** `master` @ `6e0acab8`
**Scope:** api/ (~43k R LoC), app/ (~75k Vue/TS LoC), db/migrations/, docker-compose, CI, planning artifacts
**Method:** two independent review passes (one manual, one parallel-agent) merged and cross-verified. Where the two reviews disagreed, the claim that survived direct file-level verification is the one kept here — those reconciliations are called out inline.

---

## 1 · Executive summary

SysNDD is a mature, actively-maintained research/clinical database. Seventeen milestones have shipped, there is an explicit planned-work methodology (GSD), the R API has a real layered architecture with a migration runner, 68 testthat files, Argon2 password hashing, a sanitizing log layer, and a healthy `/api/health` endpoint. Most of the "obvious" debts from the January 2026 audit (Vue 2, `_old/` plumber files, no tests at all) have been paid off.

**What remains is a sharper, second-order set of problems** — and one of them is a live security bug that must be hotfixed before anything else:

1. **Credentials in URL query strings** on login and password-change — production-impacting.
2. **Frontend auth/session state is forked across five+ places** — drift is inevitable.
3. **TypeScript strictness is effectively off** (`strict: false`, `noImplicitAny: false`, `allowJs: true`) — the compiler isn't defending the risky parts of the SPA.
4. **Six Vue views over 1,400 LoC** each carry fetch + transform + UI state + submission flows in one file.
5. **Three backend files over 1,200 LoC** each mix several unrelated concerns, and `start_sysndd_api.R` is a 971-line global-state bootstrap.
6. **Async job state is in-process memory only**, propped up by a Traefik sticky-session cookie. Crash-lossy.
7. **`db/migrations/` catalog has governance holes**: a duplicate `008_*` prefix, and the README still claims migrations are manual even though the runner exists and ships.
8. **Operational blind spots**: no metrics endpoint, no error tracking, no request IDs, unclear TLS termination story (Traefik only listens on `:80`), no security-header middleware.
9. **The test pyramid is upside-down.** Coverage threshold is set to 40%. Zero functional unit tests for the six ≥1400 LoC views. Only 5 of ~130 API endpoints have MSW handlers. `httptest2` fixture directories are empty — tests either hit real APIs or silently skip. No contract tests, no E2E, no CI smoke test. **Testing is the single biggest multiplier for the rest of this plan** — see §6 for a dedicated strategy.

None of these is a rewrite candidate. All of them are addressable in the scope of one or two milestones.

### Scorecard

Both reviews agreed on the shape of the debt but not on the exact severity. The consolidated scorecard below leans on the harsher of the two where direct verification supported it (e.g. the credential-in-URL finding justifies a lower frontend-security score than the agent pass suggested).

| Area | Score | Notes |
|---|---:|---|
| Backend architecture | 5/10 | Layering is clean in principle; 971-line bootstrap + three 1200+ LoC files undermine it in practice |
| Backend maintainability | 5/10 | God-files, `legacy-wrappers.R` bridge never finished, empty `api/repository/` |
| Backend reliability | 5/10 | In-memory job state, `<<-` globals, mirai workers loaded once per container |
| Backend performance | 6/10 | Pool + mirai fine; 9/27 list endpoints lack pagination; HGNC pipeline redundancy |
| Frontend architecture | 4/10 | Six ≥1400 LoC views, duplicated auth, three search/autocomplete variants |
| Frontend maintainability | 4/10 | Good composable inventory, but views aren't using it |
| Frontend type-safety | 3/10 | `tsconfig.json` turns off `strict` *and* `noImplicitAny`; `allowJs: true` |
| Frontend security | 3/10 | Credentials in query strings (P0) + token in localStorage |
| Backend test coverage | 6/10 | 68 testthat files, DB isolation via `with_test_db_transaction`, 10/27 endpoint files untested — see §6 |
| Frontend test coverage | 3/10 | 22 vitest specs (13 composable/util, 3 component-shallow, 6 a11y-only). Coverage threshold = 40%. Zero functional tests on the six largest views — see §6 |
| Test infrastructure | 4/10 | MSW handlers for 5/~130 endpoints, `httptest2` fixture dirs empty, no contract tests, no E2E, no CI smoke test — see §6 |
| Database / migrations | 6/10 | Runner is solid; catalog has duplicate prefix and stale README |
| CI/CD & operability | 5/10 | `make ci-local` parity good; missing coverage upload, container scan, startup smoke test |
| Observability | 4/10 | Logs + health endpoint OK; no metrics, no traces, no error tracking |
| Documentation / backlog | 5/10 | `CLAUDE.md` is excellent; `db/migrations/README.md` and several todos are stale |
| **Overall** | **5.0 / 10** | Functional and improving, but structurally fragile and carrying one P0 |

Rating calibration: this scale is set for an *actively-maintained research/clinical database with a small core team*, not a FAANG-scale enterprise app. **5/10 means "it works, but each new feature is getting more expensive."** SysNDD is at a natural hardening inflection — the refactor momentum of v1-v10 should turn inward for v11.

### Corrected false positives

Three findings from the parallel agent audit were **wrong** and are called out so nobody acts on them:

- ❌ ~~"CRITICAL: committed secrets in `.env` and `api/config.yml`"~~ — both files are properly gitignored (`.env` via root `.gitignore`, `api/config.yml` via `api/.gitignore:2`). The agent read local files without running `git ls-files` / `git check-ignore`. **No emergency key rotation needed.**
- ❌ ~~"more `addEventListener` calls than `onUnmounted` hooks — cleanup gap"~~ — verification: **18 files with unmount hooks vs. 6 with listeners**. The opposite of the claim. Frontend lifecycle hygiene is actually fine.
- ❌ ~~"XSS risk — inconsistent `v-html`"~~ — there is exactly one `v-html` in the app (`TermSearch.vue:31`) and it has an explicit `eslint-disable-next-line` comment documenting that the input is internal. Visualization components deliberately use structured data props instead of `v-html`. This is *good* discipline, not a bug.

---

## 2 · Highest-priority findings

### P0 — Credentials are sent in URL query strings (HOTFIX)

This is the highest-severity finding in the review. Both login and password-change place secrets into the URL path/query, which is logged by browsers, proxies, nginx, Traefik, and any middleboxes — regardless of HTTPS.

- **`app/src/views/LoginView.vue:139`**
  ```
  const apiAuthenticateURL =
    `${import.meta.env.VITE_API_URL}/api/auth/authenticate?user_name=${this.user_name}&password=${this.password}`;
  ```
  A `GET` with the password as a query parameter.

- **`app/src/views/UserView.vue:640`**
  ```
  const apiChangePasswordURL =
    `${import.meta.env.VITE_API_URL}/api/user/password/update`
    + `?user_id_pass_change=${this.user.user_id[0]}&old_pass=${this.currentPassword}`
    + `&new_pass_1=${this.newPasswordEntry}&new_pass_2=${this.newPasswordRepeat}`;
  ```
  A `PUT`, but still with credentials in the URL path — the HTTP method does not keep query strings out of logs.

**Why this matters**

- Query strings leak into access logs, browser history, `Referer` headers on outbound navigation, reverse-proxy logs, Traefik access logs, and any error-reporting service.
- An attacker who compromises *any* logging backend downstream — not just the API server — gets plaintext credentials.
- `CLAUDE.md` even documents this as the intended auth flow: _"GET /api/auth/authenticate (user_name/password params) → JWT token"_. This is not a regression; it has always been wrong.

**Recommendation (hotfix, not refactor)**

1. Change the API side: add `@post` handlers on the affected endpoints that read body params (keep the `@get` as a deprecated thin wrapper for one release if needed).
2. Change both frontend call sites to `POST` / `PUT` with a JSON body.
3. Redact existing credentials from application, Traefik, and nginx logs.
4. Update `CLAUDE.md` and the API README to document the corrected flow.

This is an hour's work and should not wait for the next milestone.

### P1 — Frontend auth/session state is duplicated

Even though `app/src/plugins/axios.ts` is the centralized axios setup, session state is read and interpreted directly in at least five places:

- `app/src/router/routes.ts:334`
- `app/src/components/AppNavbar.vue:135`
- `app/src/components/small/LogoutCountdownBadge.vue:36`
- `app/src/views/LoginView.vue:126`
- `app/src/views/UserView.vue:549`

`LogoutCountdownBadge.vue:60,75,91` still has a `TODO: move to a mixin` from the Vue 2 era that was never followed up on — the JWT refresh logic lives in the badge component today.

**Consequences**

- Role parsing + expiry checks drift as endpoints evolve.
- Corrupted `localStorage.user` payloads break navigation instead of being caught once.
- Bug fixes have to be replicated to every reader.

**Fix:** one typed `useAuth` composable (or pinia store) that owns reads, writes, refresh, and 401 handling. Router guards, navbar state, badge, login, user view all consume it. No other place reads `localStorage.token` / `localStorage.user` directly.

### P1 — TypeScript strictness is effectively off

**`app/tsconfig.json:4-7`**
```json
{
  "strict": false,
  "noImplicitAny": false,
  "allowJs": true
}
```

And **`app/vitest.config.ts:8`** excludes router from coverage and sets thresholds to 40%.

Combined with the 141 direct `axios.get` calls scattered through components (no typed client wrapper), this means the compiler is not defending the highest-risk parts of the SPA — auth, router, and API response handling. The `as any` casts called out below are the *visible* surface:

- `app/src/composables/use3DStructure.ts:87`
- `app/src/composables/useCytoscape.ts:64`
- `app/src/composables/useModalControls.ts:25`

The invisible surface is larger — anywhere an axios response is destructured without an interface.

**Fix (incremental):**
1. Do not flip global `strict: true` yet — it will flood the queue.
2. Turn on per-directory strictness for `src/router/`, `src/composables/useAuth*`, `src/api/` (once it exists), and `src/types/`.
3. Introduce `src/api/client.ts` — a thin typed wrapper over the shared axios instance — and migrate components off the raw `axios.get('/api/...')` pattern one feature at a time.
4. Add focused tests for route guards, corrupted `localStorage.user` payloads, login/logout, and token refresh — these are the paths the compiler currently isn't watching.

### P1 — Backend bootstrap is a 971-line global-state script

**`api/start_sysndd_api.R`** does, all in order, in one file:

- library loading
- environment selection
- config loading
- script sourcing (55 files from `functions/`, plus `core/`, `services/`, `endpoints/`)
- pool creation → `pool <<-` (line 199)
- migration runner → `migration_status <<-` (line 232)
- memoize / cache setup
- mirai daemon pool construction
- CORS filter definition
- auth filter definition
- serializer registration → `serializers <<-` (line 328)
- endpoint mounting → `root <<-` (line 819)
- shutdown handling

The `<<-` global assignments are not just stylistic — they create implicit dependencies between sourced files that are only knowable by reading the bootstrap end to end. Three distinct problems stack on each other:

1. **Init order is brittle.** Sourcing `services/` before `functions/*-repository.R` would silently shadow repository functions (this is documented in `CLAUDE.md` as a landmine — that it is documented tells you it's been stepped on).
2. **Tests can't isolate.** Any test that needs the pool has to either construct the global or source the whole bootstrap.
3. **Runtime behavior depends on sourced side effects, not explicit arguments.** Hard to reason about, hard to change.

**Fix:** split the bootstrap into small init modules that each return a value, and have `start_sysndd_api.R` compose them into an application-context object. Target size of the top-level script: ~150 LoC.

- `load_modules.R` — sources `functions/`, `core/`, `services/`, `endpoints/` in the correct order, returns nothing (kept as side-effecting but at least isolated)
- `create_pool.R` — returns the pool object
- `run_migrations.R` — returns a migration-status record
- `setup_workers.R` — returns the mirai daemon handle
- `core/filters.R` — already exists in spirit; move CORS + auth filter definitions here
- `mount_endpoints.R` — takes a router + context, returns the mounted router

### P1 — Six Vue views over 1,400 LoC each

| View | LoC | Dominant concerns |
|---|---:|---|
| `app/src/views/admin/ManageAnnotations.vue` | **2159** | job polling + annotation sections + blocked-entities table |
| `app/src/views/curate/ApproveReview.vue` | **2138** | review modal + table + status modal + filters |
| `app/src/views/admin/ManageUser.vue` | **1732** | user filters + permission matrix |
| `app/src/views/curate/ModifyEntity.vue` | **1555** | entity form + search + preview |
| `app/src/views/review/Review.vue` | **1454** | classification wizard + evidence form |
| `app/src/views/curate/ApproveStatus.vue` | **1432** | same shape as ApproveReview |

The extraction targets already exist and are underused: `useAsyncJob`, `useEntityForm`, `useReviewForm`, `useModalControls`, `useTableData`. For each view the recipe is the same: lift job polling into `useAsyncJob`, lift table state into `useTableData`, split modals into their own components, split form sections into wizard steps (the `Review.vue` wizard — `StepEvidence`, `StepClassification`, `StepCoreEntity` — is the right template already used elsewhere).

Note: `ApproveReview.vue` and `ApproveStatus.vue` are effectively the same page twice. Target a single parameterized `ApprovalTableView` component.

**Critical prerequisite: add at least one functional test per view before refactoring.** There are `.a11y.spec.ts` files for four of these views, which is good, but axe-only — they don't test behavior. The curation workflow is the business core of the app; refactoring it without a safety net is how regressions land in production.

### P1 — Backend god-files

Three files in `api/functions/` each pack several unrelated concerns into one ~1,500-line module:

- **`api/functions/llm-service.R`** — **1,747 LoC.** Gemini client + type-spec declarations + rate limiter + cache coordination. Split into `llm-client.R`, `llm-types.R`, `llm-rate-limiter.R`; leave `llm-service.R` as the orchestrator.
- **`api/functions/helper-functions.R`** — **1,440 LoC.** The "misc" file: password/email helpers, gene/panel hashing, tibble nesting, response shaping. Split into `account-helpers.R`, `entity-helpers.R`, `response-helpers.R`, `data-helpers.R`.
- **`api/functions/pubtator-functions.R`** — **1,269 LoC.** HTTP + retry + parsing + entity resolution. Split into `pubtator-client.R` (HTTP), `pubtator-parser.R` (JSON → tibble); keep `pubtator-functions.R` as the pipeline.

None of this is a behavior change — it's a file-boundary change that makes the files small enough to hold in one head.

### P1 — `legacy-wrappers.R` is a bridge nobody finished

**`api/functions/legacy-wrappers.R`** is 630 LoC and opens with this comment:

> _"Background: The original database-functions.R was removed in a refactoring, but the endpoints still call these wrapper functions. This file bridges the gap until the endpoints can be updated to use the service layer directly."_

Every entity-write function the API exposes goes through this shim: `post_db_entity`, `put_db_entity_deactivation`, `put_post_db_review`, `put_post_db_pub_con`, `put_post_db_phen_con`, `put_post_db_var_ont_con`, `put_post_db_status`, `put_db_review_approve`, `put_db_status_approve`. Because the file is sourced after `functions/*-repository.R` in the bootstrap order, these bare names sit in the global env and can shadow repository functions with the same name.

**Fix:** update `entity_endpoints.R` (and any other caller) to call the `svc_entity_*` / repository functions directly, then delete `legacy-wrappers.R`. Expected delta: −630 LoC, zero feature change. This deletes a whole layer without rewriting it.

### P1 — Async job state is in-process memory

**`api/functions/job-manager.R:31`** stores job state in an in-process environment. When the api container restarts, in-flight jobs are orphaned and the frontend keeps polling job IDs that no longer exist. The deployment papers over horizontal-scaling issues with a sticky-session cookie at **`docker-compose.yml:171`** (`sysndd_api_sticky`), but that only pins which container handles polling — it does not make job state durable.

This finding lines up with open issue **#154** (Redis job queue with heavy/light workers).

**Minimum fix:** persist job metadata and status to the existing MySQL database (a `job` table) so restart-survival works. Keep the in-memory map as a read-through cache. The frontend keeps its polling contract unchanged.

**Bigger fix (matches #154):** replace the in-process queue with Redis + heavy/light worker pools. More work, real scalability payoff.

### P1 — Migration catalog governance

Two issues in `db/migrations/`:

1. **Duplicate `008_` prefix.** Both **`db/migrations/008_add_llm_prompt_templates.sql`** and **`db/migrations/008_hgnc_symbol_lookup.sql`** exist. Ordering between them is filename-alphabetical (`add` before `hgnc`) — good luck, but not guaranteed, and auditability is lost.
2. **`db/migrations/README.md:12`** still says _"Manual execution required - No automated migration runner yet"_ even though `api/functions/migration-runner.R` runs migrations at startup (`api/start_sysndd_api.R:216`) and `schema_version` tracks them.

**Fix:**
- Rename one of the two `008_*` files to `018_*` (or renumber conservatively). Verify the schema-version table records the new number correctly.
- Rewrite `db/migrations/README.md` to describe the actual runner, document the naming convention, rollback guidance, and a CI smoke test that applies all migrations against a fresh DB.
- Add a CI check that asserts migration prefixes are unique.

### P2 — Traefik TLS and security headers

- **`docker-compose.yml:24`** and **`docker-compose.override.yml:35`** both define `--entryPoints.web.address=:80`. No `websecure`, no `443`, no certresolver in either file.
- Neither prod nor override sets HSTS, CSP, X-Frame-Options, X-Content-Type-Options, or Referrer-Policy at Traefik.

One of two things is true: either an external reverse proxy in front of the Docker stack at `sysndd.dbmr.unibe.ch` handles TLS and security headers (in which case `docs/DEPLOYMENT.md` does not document it, which is a gap), or the stack serves plain HTTP and unhardened headers directly.

**Fix (whichever applies):**
- If external: document the deployment topology in `docs/DEPLOYMENT.md`, including who owns TLS cert renewal.
- If internal: add a `websecure` entrypoint with a Let's Encrypt resolver, a security-headers middleware file, and attach it to all routers.

### P2 — 9 of 27 list endpoints lack pagination

Backend audit flagged: `about`, `backup`, `hash`, `llm_admin`, `re_review`, `search`, `variant`, `panels`, and `comparisons` endpoints. `api/functions/pagination-helpers.R` exists but is inconsistently adopted. Current dataset sizes are tolerable; the frame-drop cliff is near. **Fix:** enforce `limit`/`offset` (or cursor) on every list endpoint; add a CI test that asserts every `GET /api/<resource>` returns a `links.next` field.

---

## 3 · DRY / KISS / SOLID / anti-pattern summary

### DRY violations (verified)

- Token and role handling duplicated across five+ frontend call sites (see P1: auth duplication)
- Auth header construction repeated at every `axios.get` site instead of at a single client boundary (141 direct axios call sites)
- `ApproveReview.vue` and `ApproveStatus.vue` — same page twice
- Three search/autocomplete components with overlapping logic: `TermSearch.vue`, `AutocompleteInput.vue`, `SearchCombobox.vue`
- `PubtatorNDDGenes.vue` (1221 LoC) and `PublicationsNDDTable.vue` (1077 LoC) — parallel table implementations with ~80% overlap
- `useTableData.ts` + `useTableMethods.ts` — split unnecessarily; methods mostly wrap computed properties of data
- Pagination/filter/sort expression generation is reused on the backend, but request-validation boilerplate recurs across endpoints

### KISS violations

- **`api/start_sysndd_api.R`** at 971 LoC doing 12+ distinct startup responsibilities
- Large Vue views handling fetch, transform, UI state, and submission flows together (see P1)
- Planning artifacts that describe old architecture increase cognitive load — `db/migrations/README.md`, `optimize-ensembl-biomart-connections.md`, `make-migration-002-idempotent.md` (see §4)

### SOLID and modularity violations

- **Single Responsibility:** the six Vue views and three backend god-files each have many reasons to change
- **Open/Closed:** inline auth/session reads across components means any auth policy change touches many call sites
- **Dependency Inversion:** backend depends on global `pool <<-`, `migration_status <<-`, `serializers <<-`, `root <<-`, and on functions sourced into the global env — not on explicit injection. Tests inherit this coupling.

### Anti-patterns

- **Credentials in query strings** (P0)
- **Global mutable runtime state** (`<<-` assignments in `start_sysndd_api.R`)
- **Process-local async state hidden behind sticky sessions**
- **Docs and backlog items that no longer reflect actual code**
- **Duplicate migration version prefix**
- **Bridge layer (`legacy-wrappers.R`) that nobody finished crossing**
- **Empty `api/repository/` directory** — archaeological debris from a partial refactor. Delete or populate.

---

## 4 · Pending todos — triage (reconciled)

Both reviews triaged the four pending todos in `.planning/todos/pending/`. Reconciled with direct file-level verification:

| Todo | Disposition | Reason (verified) |
|---|---|---|
| **`database-migration-system.md`** | **Close as partially implemented** | `api/functions/migration-runner.R` exists and is wired into `api/start_sysndd_api.R:216`. Replace with a smaller follow-up: unique numeric prefixes (see duplicate `008_*`), CI startup/migration smoke test, docs cleanup, rollback runbook. |
| **`fix-pipe-split-on-json-column.md`** | **Keep, high-value next milestone** | Verified: `api/endpoints/gene_endpoints.R:219` still applies `str_split()` across every selected field, and `app/src/views/pages/GeneView.vue:193` still dereferences `gnomad_constraints?.[0]`. Small change, cross-stack payoff. |
| **`make-migration-002-idempotent.md`** | **Close as stale** | Verified: `db/migrations/002_add_genomic_annotations.sql` is **already** idempotent via `INFORMATION_SCHEMA` checks inside `CREATE PROCEDURE IF NOT EXISTS migrate_002_genomic_annotations`. (My initial review said "keep as LOW priority — 20 minutes of work"; that was wrong — the work is done.) |
| **`optimize-ensembl-biomart-connections.md`** | **Keep but rewrite** | Verified: the original "creates both marts in every helper" critique is outdated — `create_ensembl_mart()` now exists at `api/functions/ensembl-functions.R:75` and is the sole creation point. But `api/functions/hgnc-functions.R:316-340` still triggers four coordinate lookups (`gene_coordinates_from_ensembl` hg19 + hg38, `gene_coordinates_from_symbol` hg19 + hg38), each calling `create_ensembl_mart()` again. Real remaining issue: reuse the mart across the HGNC pipeline rather than recreating it. Rewrite the todo around this. |

---

## 5 · Open GitHub issues — prioritized

29 open issues. Grouped by leverage:

### P0 — Stability and data correctness

Highest leverage because they affect trust in the system and production behavior.

- **[#167](https://github.com/berntpopp/sysndd/issues/167)** — Entity data integrity audit (13 suffix-gene misalignments)
- **[#154](https://github.com/berntpopp/sysndd/issues/154)** — Redis job queue / durable async architecture *(matches the P1 finding above on in-memory job state)*
- **[#22](https://github.com/berntpopp/sysndd/issues/22)** — DB database version visibility *(partially delivered by `schema_version`; consider closing or rescoping)*
- **[#5](https://github.com/berntpopp/sysndd/issues/5)** — Rename `entity_quadruple` → `entity_triple` constraint
- **[#105](https://github.com/berntpopp/sysndd/issues/105)** — Automated log cleanup

### P1 — Workflow and maintainability improvements

Curator productivity and developer throughput. **Schedule the approval/removal cluster together** — they are one feature from the user's point of view.

- **[#29](https://github.com/berntpopp/sysndd/issues/29)** — Inconsistent entity-batch grouping *(cluster with #167)*
- **[#32](https://github.com/berntpopp/sysndd/issues/32)** — Admin view for phenotype/inheritance management
- **[#34](https://github.com/berntpopp/sysndd/issues/34)** — Removal button in status modal
- **[#36](https://github.com/berntpopp/sysndd/issues/36)** — Combined status/review modal *(schedule alongside the `ApproveReview`/`ApproveStatus` convergence in P1)*
- **[#37](https://github.com/berntpopp/sysndd/issues/37)** — Direct approval in create/modify flows
- **[#54](https://github.com/berntpopp/sysndd/issues/54)** — Refusal handling for re-reviews
- **[#55](https://github.com/berntpopp/sysndd/issues/55)** — Removal option in approval workflow
- ~~**[#58](https://github.com/berntpopp/sysndd/issues/58)** — Editable static content via UI~~ — **closed 2026-04-11 as delivered** (`ManageAbout.vue` admin editor + `about_endpoints.R` draft/publish workflow)

### P2 — Product expansion and analysis quality

- **[#14](https://github.com/berntpopp/sysndd/issues/14)** — Search for new GeneReviews articles
- **[#15](https://github.com/berntpopp/sysndd/issues/15)** — Search/filter/download variant annotations
- **[#46](https://github.com/berntpopp/sysndd/issues/46)** — GeneReviews update enhancement *(cluster with #14)*
- **[#48](https://github.com/berntpopp/sysndd/issues/48)** — Pubtator query and gene list generation
- **[#89](https://github.com/berntpopp/sysndd/issues/89)** — Links to curation/correlation matrices
- **[#98](https://github.com/berntpopp/sysndd/issues/98)** — Replace VariO ontology
- **[#175](https://github.com/berntpopp/sysndd/issues/175)** — Normalize PubtatorNDD counts

### P3 — Documentation and polish

Batch into a documentation sprint.

- **[#49](https://github.com/berntpopp/sysndd/issues/49)** — Bug reporting docs
- **[#50](https://github.com/berntpopp/sysndd/issues/50)** — PMID docs
- **[#51](https://github.com/berntpopp/sysndd/issues/51)** — Variant ontology curation docs
- **[#52](https://github.com/berntpopp/sysndd/issues/52)** — "Not applicable" docs
- **[#56](https://github.com/berntpopp/sysndd/issues/56)** — JSDoc/docs for view functions
- **[#83](https://github.com/berntpopp/sysndd/issues/83)** — Input style inconsistency in CurationComparisons
- **[#140](https://github.com/berntpopp/sysndd/issues/140)** — Automated docs screenshot generation with Playwright *(would also provide the E2E testing foundation that's currently missing)*

### Candidates to close as delivered

- **[#22](https://github.com/berntpopp/sysndd/issues/22)** — Backend `/api/version` + `schema_version` table exist; frontend still doesn't display version. Rescope as a small "show version in footer" follow-up rather than closing outright.
- **[#33](https://github.com/berntpopp/sysndd/issues/33)** — Migrations system delivers the catalog/master-script part, but the original asks (SQLite SysID import, removing hardcoded OMIM links from `db/*.R`) are unmet. Leave open or rescope.
- ~~**[#58](https://github.com/berntpopp/sysndd/issues/58)**~~ — **closed 2026-04-11 as delivered** by `ManageAbout.vue` + `about_endpoints.R`.

---

## 6 · Testing strategy

Testing gets its own section because it is the **single biggest velocity multiplier for the rest of this plan**. The §7 Action Plan rewrites views, splits god-files, and deletes `legacy-wrappers.R` — none of those are safe without tests first. This section captures (a) the current state quantitatively, (b) the gaps, (c) what the 2026 state of the art looks like for this stack, and (d) a concrete tiered plan that drops into the action plan.

### 6.1 · Current state — quantitative

**R backend (`api/tests/testthat/`, 68 files, ~610 assertions):**

| Category | Count | Notes |
|---|---:|---|
| Unit tests | ~40 | Cover repositories, services, helpers, parsers |
| Integration tests | ~22 | `skip_if_no_test_db()`-gated, hit real test DB |
| E2E / user-lifecycle | ~4 | Mailpit-dependent — **not run in CI** (no Mailpit service in `.github/workflows/ci.yml`) |
| Perf / benchmark | ~2 | `test-llm-benchmark.R` (accuracy), `test-llm-judge.R` — both known-failing per CLAUDE.md |
| **Endpoints with dedicated tests** | **17/27** | 10 endpoint files have no test file at all |
| **Endpoints without tests** | 10 | `backup`, `hash`, `list`, `ontology`, `phenotype`, `review`, `search`, `statistics`, `status`, `variant` |
| **Pre-existing failures (left alone)** | 4+ | `test-llm-benchmark.R`, `test-llm-judge.R`, 4 in `test-unit-entity-creation.R` |

**Frontend (`app/src/**/*.spec.ts`, 22 files):**

| Category | Count | Notes |
|---|---:|---|
| Utility tests (`utils/__tests__/`) | 3 | `apiUtils`, `dateUtils`, `timeSeriesUtils` |
| Composable tests | 10 | `useText`, `useToast`, `useColorAndSymbols`, `useModalControls`, `useUrlParsing`, `useStatusForm`, `useReviewForm`, + 3 more |
| Component tests (shallow-mount) | 3 | `AppFooter`, `AppBanner`, `FooterNavItem` |
| A11y-only specs | 6 | `ApproveReview.a11y`, `ApproveStatus.a11y`, `ApproveUser.a11y`, `ManageReReview.a11y`, `Review.a11y`, `AppFooter.a11y` — use `vitest-axe`, check for axe violations only, **do not exercise behavior** |
| **Components ≥500 LoC with zero functional tests** | 20+ | Includes all six ≥1400 LoC views plus `AnalyseGeneClusters`, `GeneStructurePlotWithVariants`, `NetworkVisualization`, `PubtatorNDDGenes`, `TablesPhenotypes`, `TablesLogs`, and 8 more 700-1100 LoC components |
| **Composables with zero tests** | ~30/44 | Notable gaps: `useAsyncJob`, `useGeneExternalData`, `useTableData`, `useTableMethods`, `useEntityForm`, `useD3Lollipop`, `use3DStructure`, `useAriaLive`, `useLlmAdmin`, `useHierarchyPath` |

**Test-runner configuration (`app/vitest.config.ts`):**
- Coverage thresholds: **lines 40% / functions 40% / branches 40% / statements 40%** — this encodes the expectation, and the expectation is low
- Coverage excludes: router, `main.ts`, `*.d.ts`, `test-utils/`, `types/`
- Environment: jsdom (not happy-dom, not Vitest Browser Mode)
- `vitest.setup.ts` mocks `matchMedia` and `localStorage` in-memory; starts MSW with `onUnhandledRequest: 'warn'`

**MSW handlers (`app/src/test-utils/mocks/handlers.ts`, 89 lines):**
- Only 5 endpoints mocked, all `GET`: `/api/auth/signin`, `/api/genes/:symbol`, `/api/entity/:id`, `/api/search`, `/api/external/internet_archive`
- **Zero POST / PUT / DELETE handlers** — any test that exercises form submission or mutations falls through to the `/api/*` catch-all, which warns and returns 500
- This is why nobody writes component tests for the curation workflow: the first `submitReview()` call hits a stubbed 500

**`httptest2` fixtures (`api/tests/testthat/fixtures/`):**
- `pubmed/.gitkeep` — empty
- `pubtator/.gitkeep` — empty
- `llm-benchmark-ground-truth.json` — real fixture
- `genemap2_test.txt`, `phenotype_hpoa_test.txt`, `phenotype_to_genes_test.txt` — real fixtures
- PubMed and PubTator tests will either record from live APIs on first run or silently skip — **staleness risk is high, fixture provenance is undocumented**

**CI (`.github/workflows/ci.yml`):**
- R lint + R test-with-MySQL-8.4.8 + app lint + app type-check + app vitest + app build
- **No coverage upload** to Codecov, Coveralls, or equivalent — coverage is generated locally and discarded
- **No container scan** (Trivy / Syft)
- **No startup smoke test** — `api` container is never actually booted in CI; the preflight target exists in the Makefile but isn't wired into GitHub Actions
- **Mailpit service not present** → all email tests are silently skipped in CI
- **No concurrency optimization** — jobs run sequentially within each path-filter bucket

### 6.2 · Diagnostic themes

These are the patterns behind the numbers, not more numbers.

**1. The test pyramid is upside-down.** Industry guidance in 2026 ([Vue.js testing docs](https://vuejs.org/guide/scaling-up/testing), [alexop.dev Vue 3 testing pyramid](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)) is to lean on **integration tests** of components with their real collaborators because "they test what users actually experience." SysNDD has it backwards: plenty of utility tests, a few composable tests, then a cliff drop to zero functional tests on the components users actually touch. A11y-only specs are giving a false signal that these views are "tested."

**2. 40% is the expectation, not the floor.** Coverage thresholds encode intent. When the threshold is 40%, nobody is going to write the 50th test that would push it to 41% — it's already green. Raising the threshold by 5% per milestone is the standard way to turn this around without flag-day pain.

**3. Untested production code drives untestable production code.** `ManageAnnotations.vue` is 2159 lines because nobody has ever had to write a test for it. The six ≥1400 LoC views are simultaneously the biggest refactor targets (§7.4) *and* the biggest test gaps. Tests must be written **before** the refactor, not after, or the refactor has no safety net.

**4. MSW handler gap is the blocker.** The reason zero functional tests exist for the curation workflow is that the first form submission hits an un-mocked POST and returns 500. Fixing this unblocks literally all of §7.4.

**5. `httptest2` empty-fixture pattern is a trap.** A fixture file that doesn't exist looks identical to a recorded fixture that's silently returning stale data. Either the fixtures must be checked in and version-controlled, or the tests must fail loudly when the fixture is missing. Neither is currently the case.

**6. There's no bridge between the OpenAPI spec and either end.** `api/config/openapi/` has 162 documented paths. The frontend generates no types from it. The backend enforces no contract against it. Drift is invisible until production.

**7. The R side is actually in better shape than the app side.** 68 files × 610 assertions is genuinely solid coverage for an R research project. The DB transaction-rollback pattern in `helper-db.R` is the right answer. The gaps (10 untested endpoints, Mailpit in CI, empty PubMed fixtures) are specific and fixable.

### 6.3 · 2026 best practices for this stack

Synthesized from web research. Citations at the end of the section.

**R / Plumber:**

- **Two-layer testing.** Keep business logic in pure R functions (under `api/services/` and `api/functions/*-repository.R`) and test them with plain `testthat` — no HTTP, no plumber routing. Test API contracts separately by booting the API as a background process. This is the pattern recommended by the Plumber team ([R-bloggers 2025](https://www.r-bloggers.com/2025/07/testing-your-plumber-apis-from-r/), [Jumping Rivers — API as a package](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)).
- **Use `callr` or `callthat` to run the API in tests.** [`callr::r_bg()`](https://jafaraziz.com/blog/rest-api-with-r-part-4/) boots the API in a background R process; teardown kills it. [`callthat`](https://github.com/edgararuiz/callthat) wraps this pattern and lets you test plumber endpoints inside `testthat` without a running server — it constructs a plumber router object and invokes it directly. Either is a better fit than SysNDD's current pattern of hitting the API via `httr2` against a running container.
- **Transaction rollback for DB tests is correct but fragile.** ([XUnit Patterns](http://xunitpatterns.com/Transaction%20Rollback%20Teardown.html)) MySQL's transactional rollback does not undo DDL statements and does not undo nested `REQUIRES_NEW` blocks. SysNDD's `helper-db.R:70-99` (`with_test_db_transaction`) is the right approach for DML-only tests; for tests that exercise migration-runner.R or any DDL path, use **Testcontainers**-style fresh-container isolation instead.

**Vue 3 / Vitest / MSW:**

- **Test behavior, not implementation.** Test descriptions should read "shows error message when email format is invalid," not "calls validateEmail function." ([Vitest guide](https://vitest.dev/guide/browser/component-testing))
- **Mock only external boundaries.** MSW is the 2026 standard for mocking HTTP at the network layer. Never mock internal modules to make tests pass — if a test needs internal mocks, the architecture is the problem. ([Vue.js testing guide](https://vuejs.org/guide/scaling-up/testing))
- **JSDOM vs. Vitest Browser Mode.** ([pkgpulse comparison](https://www.pkgpulse.com/blog/happy-dom-vs-jsdom-2026), [InfoQ](https://www.infoq.com/news/2025/06/vitest-browser-mode-jsdom/)) JSDOM stays correct for pure logic, composables, and shallow-mounted components. **Vitest Browser Mode** (via Playwright provider) is the 2026 recommendation for tests that touch real browser APIs — CSS custom properties, ResizeObserver, Shadow DOM, Canvas/SVG sizing, focus/scroll behavior. SysNDD's D3 and Cytoscape visualizations are in this category. **Migration path:** leave the 22 existing specs on jsdom; add Vitest Browser Mode as a second runner for new visualization tests and any test that needs real layout.
- **Integration over unit for components.** Prefer tests that render the component with its real children and assert user-visible behavior over tests that mock everything away. "Test what the user experiences." ([alexop.dev](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/))

**OpenAPI contract testing:**

- **`openapi-typescript` on the frontend.** Generates TypeScript types from `api/config/openapi/` zero-runtime-cost. The compiler then refuses to build if the frontend reads a field that isn't in the spec. ([Alex O'Callaghan — contract testing with OpenAPI & TypeScript](https://alexocallaghan.com/openapi-typescript-contract-testing))
- **`Schemathesis` for property-based API testing.** Python-based but language-agnostic — point it at the spec, it generates thousands of test cases (fuzzing, multi-step flows via OpenAPI `links`) and finds the edge cases that hand-written tests miss. Run in CI against a booted API. ([Schemathesis docs](https://schemathesis.io/), [David Mello on automated API testing](https://www.davidmello.com/software-testing/test-automation/automated-api-testing-with-schemathesis))
- This is a **much higher-leverage intervention** than hand-writing more endpoint tests. The OpenAPI spec already exists; all that's missing is the wire.

**Playwright (E2E + visual regression + screenshots):**

- **One tool for three jobs.** Playwright covers E2E testing, visual regression via `toHaveScreenshot()`, and programmatic screenshot capture. This means issue #140 (documentation screenshots) and the E2E gap and the visual regression gap all get solved by the same installation. ([Playwright docs](https://playwright.dev/docs/test-components), [BrowserStack Vue+Playwright guide](https://www.browserstack.com/guide/playwright-vue), [Bug0 visual regression guide](https://bug0.com/knowledge-base/playwright-visual-regression-testing))
- **Component testing with Playwright is still experimental.** Don't use `@playwright/experimental-ct-vue` yet for unit-like tests; use **Vitest Browser Mode with the Playwright provider** for in-browser component tests and save Playwright itself for real E2E.
- **Visual regression in 2026 is a SaaS-adjacent decision.** Keep baselines in git for now (cheap, no extra infra), migrate to a visual-diff SaaS (Percy, Chromatic, Argos) if the baseline review workflow becomes painful.

**Test isolation and speed:**

- **Transaction rollback is the default.** Every DB test should be inside a rolled-back transaction. ([Los Techies: isolating DB data in integration tests](https://lostechies.com/jimmybogard/2012/10/18/isolating-database-data-in-integration-tests/)) SysNDD already has `with_test_db_transaction` in `helper-db.R` — it's just not the default.
- **Testcontainers for migration-runner tests.** ([Testcontainers MySQL module](https://testcontainers.com/modules/mysql/)) A fresh MySQL container per test for anything that exercises DDL is faster than it sounds — ~2-5s startup if the image is cached — and removes all the rollback-with-DDL fragility. Alternative: a single session-scoped container with snapshot/restore.
- **No `Sys.sleep` in tests.** Replace polling sleeps with event-based waits (`wait_for(condition, timeout)` helpers). Every `Sys.sleep` is a race condition waiting to happen.

### 6.4 · Testing plan — tiered, maps to action plan

This plan stands alongside §7 — items are cross-referenced back so you can see which tests unlock which refactor.

#### Tier A — Unblock everything else (≤1 week, runs in parallel with the P0 hotfix)

1. **Expand MSW handlers to cover all POST/PUT/DELETE endpoints that appear in the six top views.** Without this, no functional test for any view in §7.4 is possible. Start with: `POST /api/auth/authenticate` (hotfix target), `PUT /api/user/password/update` (hotfix target), `POST /api/review/approve`, `POST /api/status/approve`, `POST /api/entity`, `PUT /api/entity/:id`, `DELETE /api/entity/:id`, plus the async job endpoints under `/api/jobs/`. Goal: any test that mounts a real view can run to completion without hitting the catch-all 500.
2. **Record `httptest2` fixtures for PubMed and PubTator.** Run the external tests once against real APIs to populate `tests/testthat/fixtures/pubmed/` and `tests/testthat/fixtures/pubtator/`, commit them, document refresh cadence in the testthat helpers. Add a `skip_if_no_fixtures()` helper that fails loudly instead of silently when fixtures are missing.
3. **Wire `skip_if_not_slow_tests()` into the integration tests that need Mailpit or external APIs.** `helper-skip.R` already defines the function; grep shows zero callers. Gate the slow ones behind `RUN_SLOW_TESTS=true`, and run that variant once nightly in CI rather than on every push.
4. **Add a CI matrix job that boots the full stack and hits `/api/health`.** This is the missing smoke test. ~30 lines of YAML. Catches migration-apply failures, renv drift, config.yml shape breaks, and Docker-layer bugs that the unit suite cannot see.
5. **Raise the vitest coverage threshold from 40% → 45%.** Not yet — do this *after* Tier B step 1 bumps it naturally. Setting the target now creates the pressure.

#### Tier B — Safety net for the v11.0 refactor (1-2 weeks, must precede §7.4)

1. **Write one `@vue/test-utils` + MSW functional test per ≥1400 LoC view.** Six tests, covering the happy path and one edge case each. Order by risk: `ApproveReview` → `Review` → `ApproveStatus` → `ModifyEntity` → `ManageAnnotations` → `ManageUser`. Target: coverage threshold 45% → 55% falls out of this.
2. **Add tests for the 10 untested endpoint files on the R side.** Prioritize `search_endpoints.R`, `variant_endpoints.R`, `review_endpoints.R` (public read paths) over `backup_endpoints.R` and `hash_endpoints.R` (admin-only, low-traffic).
3. **Test the high-risk composables that the views will be refactored into.** `useAsyncJob`, `useEntityForm`, `useTableData`, `useTableMethods` — these are the targets of the extractions in §7.4, and the extractions need tests to prove behavior preservation. Already have `useStatusForm.spec.ts` and `useReviewForm.spec.ts` as templates.
4. **Replace the three `Sys.sleep` lines in `test-e2e-user-lifecycle.R` and the one in `helper-mailpit.R`.** Event-based waits with a 10s timeout. Mark this done when a CI run survives 10 consecutive executions without flaking.
5. **Add `with_test_db_transaction` as the default for all integration tests that don't need DDL.** Most of `test-integration-*.R` should be inside it; audit the ~22 integration files and add where missing.

#### Tier C — Contract enforcement and E2E (2-4 weeks, v11.1 / v11.2)

1. **Introduce `openapi-typescript` in the app build.** Run it in `make ci-local` and CI. Generate `app/src/api/generated/` from `api/config/openapi/` on every build. Integrate into the new `app/src/api/client.ts` wrapper (§7.4 step 7). First build will surface the existing drift — fix iteratively.
2. **Wire `Schemathesis` as a CI job.** Add a Python step that boots the api container via docker compose, points Schemathesis at `/api/config/openapi/`, runs `--workers 4 --hypothesis-max-examples 30`, and fails the build on any spec violation. Start in "advisory" mode (allowed to fail) for one week to surface the existing violations, then flip to blocking.
3. **Install Playwright for E2E + visual regression + documentation screenshots.** This is the single installation that closes issue #140, fills the E2E gap, and establishes the visual regression baseline. Ten scenarios to start: login, view an entity, run a review, approve a review, approve a status, create a new entity, change password, view the admin panel, run an annotation job, view the about page. Keep baselines in git.
4. **Vitest Browser Mode as a second runner for visualization tests.** Keep jsdom as the default. Add a `test:browser` script that runs `@vitest/browser-playwright` against `useD3Lollipop`, `useCytoscape`, `NetworkVisualization`, `GeneStructurePlotWithVariants`. Catches the layout bugs that jsdom can't see.
5. **Raise coverage threshold from 55% → 65%** as Tier B and C fill in.

#### Tier D — Longer-term investments (v11.3+, optional)

1. **Testcontainers migration-runner tests.** A fresh MySQL container per test for anything that touches DDL. Replaces the current "apply migrations to the shared test DB" pattern for migration-specific tests.
2. **Mutation testing** via `stryker` (JS) and/or `mutants` (R) on the core services — only once functional tests exist. Will be loud at first.
3. **Load testing** — replace the accuracy-focused `test-llm-benchmark.R` with a real latency harness. `k6` is the standard 2026 pick. Useful once the Redis job queue lands (§7.5 / #154) — before then, the MIRAI worker ceiling bounds throughput anyway.
4. **Visual regression in a SaaS** (Percy / Chromatic / Argos) if the git-hosted baseline review becomes painful. Not before.

### 6.5 · Tool recommendations

**Keep:** `testthat`, `httptest2`, `vitest`, `@vue/test-utils`, `MSW`, `vitest-axe`. All solid choices for their respective jobs.

**Add (in priority order):**

| Tool | Job | Why now |
|---|---|---|
| **MSW handler expansion** (no new tool) | Unblock Vue functional tests | Zero-cost, enables everything downstream |
| **`openapi-typescript`** | Compile-time contract enforcement | The spec already exists; generating types is one npm script |
| **`Schemathesis`** | Property-based API contract tests | Kills the entire "what if the frontend and backend drift" class of bug |
| **Playwright** | E2E + visual regression + screenshots | Three gaps closed by one install |
| **`callthat`** or `callr::r_bg()` | Plumber endpoint tests without a running container | Cleaner than the current HTTP-against-container pattern |
| **Vitest Browser Mode** | Visualization component tests | Only where jsdom actually fails |
| **Testcontainers MySQL** | Migration-runner test isolation | Only for tests that touch DDL |

**Retire or rework:**

- **`Sys.sleep` in test code** — every occurrence becomes an event-based wait
- **Empty `httptest2` fixture dirs** — record or fail loud, no middle ground
- **a11y-only `.spec.ts` files as the sole test for a view** — keep the a11y tests, but add functional companions
- **`ci.yml` test-api job without Mailpit** — either add the service or mark Mailpit-dependent tests as `skip_if_not_slow_tests()`

### 6.6 · Coverage targets

A realistic progression over the next three milestones. Coverage-threshold changes should land with the tests that make them pass, not as separate PRs.

| Milestone | Frontend target | Backend target | Delivery |
|---|---:|---:|---|
| v11.0 (Tier A + B) | **55%** | **70%** | MSW expansion, 6 view tests, 10 endpoint tests, composable backfill, CI smoke test |
| v11.1 (Tier C) | **65%** | **80%** | `openapi-typescript`, `Schemathesis`, Playwright E2E (10 scenarios) |
| v11.2 (Tier C finish) | **70%** | **80%** | Vitest Browser Mode for visualizations, remaining composables |
| v11.3 (Tier D optional) | **75%** | **85%** | Testcontainers for DDL tests, mutation testing pass |

### 6.7 · Developer-loop impact

Today's feedback loop per code change:

| Change type | Current | After Tier A | After Tier B |
|---|---|---|---|
| Vue view template | <1s (HMR) | <1s (HMR) | <1s (HMR) |
| Vue view logic | manual re-test | `vitest --watch` < 2s | `vitest --watch` < 2s |
| R endpoint body | bind-mount + manual test | bind-mount + targeted `testthat::test_file` | bind-mount + `testthat::auto_test_package` |
| R migration | manual `make docker-dev-db` | CI smoke test catches breaks | CI smoke test + Testcontainers local |
| OpenAPI spec change | silent drift | silent drift | compile error via `openapi-typescript` |

The "silent drift" row is the one that costs the most today. Contract tests kill that.

### 6.8 · Sources (testing research)

- **R / Plumber:** [Testing your Plumber APIs from R (R-bloggers, 2025-07)](https://www.r-bloggers.com/2025/07/testing-your-plumber-apis-from-r/) · [API as a package: Testing (Jumping Rivers)](https://www.jumpingrivers.com/blog/api-as-a-package-testing/) · [callthat package](https://github.com/edgararuiz/callthat) · [Plumber: REST API with R Part 4 (Jafar Aziz)](https://jafaraziz.com/blog/rest-api-with-r-part-4/) · [Plumber package (CRAN, 2026-01)](https://cran.r-project.org/web/packages/plumber/plumber.pdf)
- **Vue 3 / Vitest / MSW:** [Vue.js Testing Guide](https://vuejs.org/guide/scaling-up/testing) · [Vue 3 Testing Pyramid with Vitest Browser Mode (alexop.dev)](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/) · [Vitest Component Testing Guide](https://vitest.dev/guide/browser/component-testing) · [happy-dom vs jsdom 2026 (PkgPulse)](https://www.pkgpulse.com/blog/happy-dom-vs-jsdom-2026) · [Vitest Browser Mode vs Playwright Component Testing (PkgPulse 2026)](https://www.pkgpulse.com/blog/vitest-browser-mode-vs-playwright-component-testing-vs-2026)
- **OpenAPI contract testing:** [Contract testing with OpenAPI & TypeScript (Alex O'Callaghan)](https://alexocallaghan.com/openapi-typescript-contract-testing) · [Schemathesis](https://schemathesis.io/) · [Stop Writing API Tests Manually — Schemathesis (David Mello)](https://www.davidmello.com/software-testing/test-automation/automated-api-testing-with-schemathesis) · [OpenAPI Testing: Contract, Fuzz, and Integration (Apideck)](https://www.apideck.com/blog/openapi-testing)
- **Playwright & visual regression:** [Playwright Component Testing (experimental)](https://playwright.dev/docs/test-components) · [Playwright Visual Regression Testing Guide 2026 (Bug0)](https://bug0.com/knowledge-base/playwright-visual-regression-testing) · [Playwright for Vue applications (BrowserStack)](https://www.browserstack.com/guide/playwright-vue) · [Visual Regression: Vitest vs Playwright (mayashavin.com)](https://mayashavin.com/articles/visual-testing-vitest-playwright)
- **Test isolation & databases:** [Transaction Rollback Teardown (XUnit Patterns)](http://xunitpatterns.com/Transaction%20Rollback%20Teardown.html) · [Isolating DB data in integration tests (Los Techies)](https://lostechies.com/jimmybogard/2012/10/18/isolating-database-data-in-integration-tests/) · [Testcontainers MySQL Module](https://testcontainers.com/modules/mysql/) · [Why Traditional Rollbacks Failed My Integration Tests (Medium)](https://medium.com/@dewiroberts_19249/why-traditional-rollbacks-failed-my-integration-tests-and-how-i-fixed-it-with-testcontainers-772af53051a1)

---

## 7 · Action plan

**Cross-reference:** each milestone below has a `Tests:` line pointing at the §6 testing tier that must precede (or land alongside) it. **No view refactor or god-file split ships without the corresponding tests.**

### Next 2 weeks — hotfix and fast wins

1. **P0 fix:** move login and password-change credentials out of query strings. Use `POST`/`PUT` body. Redact existing logs.
2. **Centralize frontend auth/session** behind one typed `useAuth` composable. Remove direct `localStorage.token` / `localStorage.user` reads from all call sites.
3. **Fix stale docs:** rewrite `db/migrations/README.md` to describe the actual runner. Delete or replace `make-migration-002-idempotent.md`. Rewrite `optimize-ensembl-biomart-connections.md` around mart reuse in the HGNC pipeline.
4. **Close the duplicate `008_*` migration prefix.** Rename one file (with a matching `schema_version` update), add a CI check for unique prefixes.
5. **Fix the JSON pipe-split issue** (pending todo + F8 cross-stack): one-line `across(-c(gnomad_constraints), ...)` in `api/endpoints/gene_endpoints.R:219`, remove `[0]` dereference in `GeneView.vue:193`, fix type in `types/gene.ts`.
6. **Delete `api/repository/`** (empty, root-owned) or populate it.

> **Tests (Tier A, §6.4):** expand MSW handlers (all verbs), record PubMed/PubTator fixtures, wire `skip_if_not_slow_tests`, add CI smoke test that boots the stack and hits `/api/health`, replace `Sys.sleep` calls.

### Next 4 to 8 weeks — v11.0 Code modernization

**Goal:** close the structural debt without adding features. Drives backend and frontend scores up by ~1.5 each.

1. **Delete `legacy-wrappers.R`** by migrating `entity_endpoints.R` to the service layer. Target: −630 LoC.
2. **Split backend god-files** (`llm-service.R`, `helper-functions.R`, `pubtator-functions.R`) into focused modules.
3. **Extract `start_sysndd_api.R`** into init modules returning an application-context object. Top-level script target: ~150 LoC.
4. **Rewrite the top two Vue views** (`ManageAnnotations.vue`, `ApproveReview.vue`) — lift logic into composables, split modals into their own components. **Write tests first** (see Tier B).
5. **Converge `ApproveReview` and `ApproveStatus`** into one parameterized `ApprovalTableView`.
6. **Introduce `src/api/client.ts`** — typed wrapper over the central axios instance. Migrate components off direct `axios.get` one feature at a time.
7. **Enable stricter TypeScript incrementally** for `src/router/`, `src/composables/useAuth*`, `src/api/`, `src/types/` — not global `strict: true` yet.
8. **Enforce pagination on the 9 remaining list endpoints.** Add a CI test asserting `links.next`.

> **Tests (Tier B, §6.4) — this tier MUST precede steps 1-5 above:** one `@vue/test-utils` + MSW functional test per ≥1400 LoC view (six tests), tests for the 10 untested R endpoints, tests for `useAsyncJob`/`useEntityForm`/`useTableData`/`useTableMethods`, default-on `with_test_db_transaction`. Coverage threshold: frontend 40% → 55%, backend 70%.

### Next milestone — v11.1 Security & operations hardening

1. **Document or implement TLS termination.** Either add Traefik `websecure` + Let's Encrypt, or document the external reverse proxy topology.
2. **Add Traefik security-header middleware** (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy).
3. **Durable async job state.** Persist job metadata to MySQL; keep the in-memory map as a read-through cache. Matches [#154](https://github.com/berntpopp/sysndd/issues/154).
4. **Observability primitives.** Request IDs in log lines, a JSON `/api/metrics` endpoint, optional Sentry integration.
5. **CI improvements.** Coverage upload (Codecov or similar), container scan (Trivy), upgrade the smoke test from Tier A to full migration-applied-to-fresh-DB.

> **Tests (Tier C, §6.4):** introduce `openapi-typescript` in the app build, wire `Schemathesis` as a CI job against the booted API, install Playwright for E2E + visual regression + #140 screenshots (ten scenarios), add Vitest Browser Mode as a second runner for D3/Cytoscape visualizations. Coverage threshold: frontend 65%, backend 80%.

### Next milestone — v11.2 Data quality & curation UX

1. **Entity data integrity audit** ([#167](https://github.com/berntpopp/sysndd/issues/167), [#29](https://github.com/berntpopp/sysndd/issues/29)) — investigate root cause of the 13 suffix-gene misalignments, fix, backfill.
2. **Optimize Ensembl BioMart reuse** in `update_process_hgnc_data` (pending todo, rewritten).
3. **Curation workflow UX cluster** ([#34](https://github.com/berntpopp/sysndd/issues/34), [#36](https://github.com/berntpopp/sysndd/issues/36), [#37](https://github.com/berntpopp/sysndd/issues/37), [#54](https://github.com/berntpopp/sysndd/issues/54), [#55](https://github.com/berntpopp/sysndd/issues/55)) — one feature from the user's POV. Rides on the v11.0 view rewrite so features don't bolt onto 2138-line components.
4. **Normalize PubtatorNDD gene counts** ([#175](https://github.com/berntpopp/sysndd/issues/175)).
5. **Fix CurationComparisons input styles** ([#83](https://github.com/berntpopp/sysndd/issues/83)).

> **Tests (Tier C finish):** Playwright scenarios for the curation workflow features, remaining composable backfill, coverage threshold frontend 70%, backend 80%. Data-integrity audit should produce property-based Schemathesis cases that prevent regression.

### v11.3 — Documentation, E2E testing finish, legacy closeout

1. **Operations runbook** (`docs/OPERATIONS.md`): restart API, rotate secrets, apply migration, recover failed job, scale API. Closes docs issues #49, #50, #51, #52, #56.
2. **Expand Playwright E2E scenarios** to cover every curation role (viewer, curator, reviewer, admin) end-to-end. Baseline visual regression for every top-level view.
3. **Database ERD / data dictionary** — Mermaid or PlantUML.
4. **Close delivered issues** from v11.0–v11.2. Rescope #22 and #33.

> **Tests (Tier D, §6.4, optional):** Testcontainers MySQL for DDL-touching tests, mutation testing pass via `stryker` (JS) and `mutants` (R), replace `test-llm-benchmark.R` with a real `k6` load-test harness. Coverage threshold stretch: frontend 75%, backend 85%.

---

## 8 · What's already good

Both reviews agreed on this, and it's worth naming so the v11 work doesn't throw it away.

**Backend**

- Argon2 password hashing in `api/core/security.R:47-51` with a graceful plaintext-migration path.
- `api/core/logging_sanitizer.R` redacts passwords, tokens, API keys, and auth headers before logging — most R projects don't do this at all.
- `api/functions/db-helpers.R` enforces the `?` placeholder convention across the codebase.
- `db_with_transaction()` is used consistently in services, and `test-unit-transaction-patterns.R` verifies it.
- `/api/health` is rich: migration status, pool stats, worker count, DB ping.
- CORS strictness in production is explicit and correct (no `*`).
- 68 testthat files with `helper-db.R` that works in both CI and local dev, plus httptest2 fixtures for external APIs.
- Sticky-session cookie for horizontally-scalable async workers is the right call (even though the state underneath still needs to become durable).

**Frontend**

- All 57 routes lazy-loaded via `() => import(...)`.
- `plugins/axios.ts` has a central 401 interceptor with a re-entrancy guard.
- XSS discipline — only one `v-html` exists, explicitly justified; visualization components use structured props.
- `SkipLink.vue` wired in `App.vue:4`; 149 aria-label instances; four a11y spec files with `vitest-axe`.
- TypeScript generics (`PaginatedResponse<T>`, `ApiResponse<T>`) are used, not ornamental.
- D3/Cytoscape components clean up selections in `onUnmounted` — the usual memory-leak trap is avoided.
- `vee-validate` 4 properly integrated; `Review.vue` wizard step components are a template worth replicating.

**Infrastructure**

- `api/Dockerfile` is genuinely good: multi-stage, rocker base, P3M binaries, ccache, stripped symbols, non-root `apiuser`, `HEALTHCHECK`. ~3-5 min build.
- Compose file layering (base / override / dev-db-only) is the textbook pattern and well-documented in `CLAUDE.md`.
- `make ci-local` actually matches CI. Most projects claim this and it's false; this one is true.
- `api/functions/migration-runner.R` uses a MySQL advisory lock with a 30s timeout + fast-path short-circuit when schema is current. More thought than most projects put into migrations.
- Dependabot PRs visible in the log — security updates are being merged.
- `CLAUDE.md` as onboarding documentation is well above average.

---

## 9 · Where the two reviews agreed, where they disagreed

| Finding | Manual review | Agent review | Verified |
|---|---|---|---|
| Credentials in URL query strings | ✅ found | ❌ missed | **Confirmed P0** at LoginView.vue:139 + UserView.vue:640 |
| `tsconfig.json` strictness off | ✅ found | ❌ undersold (just flagged 3 `as any`) | **Confirmed** — `strict: false`, `noImplicitAny: false`, `allowJs: true` |
| Duplicate `008_*` migration prefix | ✅ found | ❌ missed | **Confirmed** — both files exist |
| Migration 002 idempotent | ✅ "already done, close" | ❌ "keep LOW" | **Confirmed done** — close as stale |
| `legacy-wrappers.R` 630 LoC bridge | ❌ missed | ✅ found | **Confirmed** — real and actionable |
| Empty `api/repository/` directory | ❌ missed | ✅ found | **Confirmed** — delete or populate |
| Backend god-file LoC numbers | ❌ no specifics | ✅ measured | **Confirmed** — 1747/1440/1269 |
| Six ≥1400 LoC Vue views listed | ✅ named subset | ✅ full list with LoC | **Confirmed** |
| In-memory job state + sticky sessions | ✅ found | ✅ found | Same finding both sides |
| `start_sysndd_api.R` bootstrap bloat | ✅ found w/ `<<-` line numbers | ✅ found | Same finding both sides; manual review added the `<<-` detail |
| Traefik `:80` only, no security headers | ❌ missed | ✅ found (but framed wrong as "no HTTPS") | **Confirmed** — real, but external proxy may handle it |
| Committed secrets in `.env` / config.yml | ❌ didn't claim | ⚠️ false positive | **False positive** — both gitignored |
| `onUnmounted` cleanup gap | ❌ didn't claim | ⚠️ false positive | **False positive** — 18 unmount files vs 6 listener files |
| `v-html` XSS inconsistency | ❌ didn't claim | ⚠️ false positive | **False positive** — single justified usage |

**Calibration note:** the manual review's scores (Frontend 4/10, Backend 4/10, Overall 4.2/10) were harsher than the agent review's (Frontend 5.5, Backend 7, Overall 6.5). Direct verification put the consolidated number at **5.0/10** — closer to the manual pass because it caught the P0 credential leak, but the agent review was right to credit the concrete strengths (Argon2, logging sanitizer, health endpoint richness, migration runner design) that a purely defect-focused read would understate.

---

## 10 · Verification notes

**Directly verified during this review pass:**

- `.env` and `api/config.yml` are gitignored — `git ls-files` returns nothing, `git check-ignore` returns a match
- Credentials-in-URL at LoginView.vue:139 and UserView.vue:640 — read the files
- `tsconfig.json:4-7` — `strict: false`, `noImplicitAny: false`, `allowJs: true`
- Migration 002 idempotent — read `db/migrations/002_add_genomic_annotations.sql`, confirmed `CREATE PROCEDURE IF NOT EXISTS migrate_002_genomic_annotations` with `INFORMATION_SCHEMA` checks
- `create_ensembl_mart()` exists at `api/functions/ensembl-functions.R:75`
- Duplicate `008_*` in `db/migrations/` — `ls` confirmed
- `db/migrations/README.md:12` still says manual — read the file
- `legacy-wrappers.R` is 630 LoC and opens with the self-documented "bridges the gap" comment
- `api/repository/` is empty (root-owned)
- Traefik `:80` only — grepped both compose files
- Large-file LoC counts — `wc -l`
- `onUnmounted` / `addEventListener` file counts — `grep -rc`
- `v-html` usage — `grep -rn`
- Testing audit numbers for §6 (68 testthat files, 22 vitest specs, 5 MSW handlers, 40% coverage threshold, 10 untested R endpoints, empty `httptest2` fixture dirs, no `skip_if_not_slow_tests` callers, 6 a11y-only view specs) — collected by a dedicated testing-audit agent pass and cross-checked against `app/vitest.config.ts`, `app/src/test-utils/mocks/handlers.ts`, `api/tests/testthat/helper-*.R`, and `.github/workflows/ci.yml`
- §6 best-practices recommendations — sourced from 2026 public testing guidance (Plumber, Vitest, MSW, OpenAPI contract testing, Playwright visual regression, testcontainers) cited inline in §6.8

**Not verified this pass:**

- Full Docker startup or database-backed end-to-end run
- SQL EXPLAIN on the largest queries (would need a warm DB)
- `renv::status()` for drift between `renv.lock` and installed packages
- CI workflow behavior on a real push
- Swagger UI publication (mentioned as present, not checked)

**Known to leave alone (per `CLAUDE.md`):**

- Pre-existing test failures in `test-llm-benchmark.R`, `test-llm-judge.R`, and 4 status-aggregation failures in `test-unit-entity-creation.R`

---

*Consolidated 2026-04-11 from one manual review pass and one parallel-agent audit pass, with direct file-level verification on all findings that survived into this document.*
