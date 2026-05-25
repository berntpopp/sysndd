# SysNDD Codebase Review

**Date:** 2026-05-24
**Repository:** `/home/bernt-popp/development/sysndd`
**Branch:** `master`
**HEAD:** `c8c189e3ab90782d12fcb714039873abc4a22173`
**Last updated:** 2026-05-25 after first-wave hardening merge
**Prior review:** `.planning/reviews/2026-04-23-codebase-review.md`

## Executive Summary

SysNDD is healthier than the April review baseline in several core areas: auth/query-string transport has largely been corrected, durable MySQL-backed async jobs exist, the frontend has a real typed API layer, and the code-quality ratchet is active. The first-wave hardening merge on 2026-05-25 closed the highest-risk issues from this review: PubTator admin mutation authorization, API image runtime-config packaging, legacy `deployment.sh`, About/CMS response normalization, strict migration manifest checks, and MCP phenotype cache-hit-only behavior.

The most urgent remaining work is now the second-wave operational/security backlog:

1. Replace rollback-unsafe MySQL `TRUNCATE` refresh paths with transaction-safe or staging-table patterns.
2. Add JWT token-purpose enforcement so password-reset tokens cannot act as access tokens.
3. Redact query strings from error logging.
4. Harden backup/restore credential handling and restore exit-code propagation.
5. Bind dev MySQL ports to loopback by default.
6. Move broad production bind-mount cleanup into an explicit deployment-hardening pass.

The next implementation plan should start with rollback-safe metadata refreshes. That item has the clearest data-loss blast radius and should be fixed before frontend cleanup, strict-TypeScript expansion, or large-file decomposition work.

## Method

- Reviewed the April report and its update blocks through the 2026-04-29 status.
- Used the existing `.understand-anything` graph for architecture orientation:
  - Generated: `2026-05-24T19:02:00Z`
  - Graph commit: `e7dc489c97ae8750a133b335a79bcaf4023bb486`
  - Current `HEAD` differs only by `.gitignore` ignoring graph artifacts, so the graph is effectively current for source review.
  - Graph scope: 843 analyzed files, 2,077 nodes, 2,177 edges, 14 layers.
  - Limitation: `.understandignore` excludes tests, planning artifacts, and durable docs, so direct source inspection was still required.
- Ran four parallel read-only review passes:
  - Frontend app/API-boundary review
  - R/Plumber API/auth/MCP review
  - DB/Compose/CI/deployment review
  - Prior-review/Understand graph/docs review
- Ran deterministic checks and scans:
  - `make code-quality-audit` -> passed
  - `git diff --check` -> passed
  - `cd app && npm run type-check:strict` -> passed
  - File-size, raw Axios/API-boundary, `localStorage`, `unsafe-*`, TODO/todo-test, console logging, secret/default, migration, and route scans with `rg`.
- Web/docs checks used primary/current sources where relevant:
  - OWASP ASVS query-string sensitive data guidance: https://owasp-aasvs4.readthedocs.io/en/latest/8.3.1.html
  - OWASP Logging Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
  - OWASP CSP Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html
  - OWASP SQL Injection Prevention / Query Parameterization Cheat Sheets: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
  - DBI `dbBind()` docs: https://dbi.r-dbi.org/reference/dbBind.html
  - Vue TypeScript docs: https://vuejs.org/guide/typescript/overview
  - Vue composables docs: https://vuejs.org/guide/reusability/composables
  - Pinia core concepts: https://pinia.vuejs.org/core-concepts/
  - GitHub action release pages for `actions/checkout`, `actions/setup-node`, `actions/upload-artifact`, and Docker build actions.

## First-Wave Hardening Update

Merged PR #363 as `c8c189e3` on 2026-05-25.

Implemented:

1. PubTator mutation routes are no longer globally allowlisted, mutation handlers require administrator authorization, and unauthenticated integration coverage exists in `api/tests/testthat/test-integration-pubtator-auth.R`.
2. API Docker images no longer copy local runtime `api/config.yml`; `api/.dockerignore`, `api/config.yml.example`, `api/Dockerfile`, smoke checks, README, and deployment docs now reflect runtime config injection. The API image healthcheck also uses `/api/health/`.
3. `deployment.sh` was removed and replaced by a retirement regression in `scripts/tests/test-deployment-retirement.sh`.
4. About/CMS frontend loading now goes through `app/src/api/about.ts`, normalizes bare-array and envelope responses, and avoids default autosave overwrites. Coverage was added across `app/src/api/about.spec.ts`, `app/src/composables/useCmsContent.spec.ts`, and `app/src/views/admin/ManageAbout.spec.ts`.
5. Startup/readiness now enforce a strict migration manifest through `api/functions/migration-manifest.R`; missing/empty migrations and an out-of-date expected latest migration fail deterministically.
6. MCP phenotype analysis now reads cache hits only and returns structured unavailable responses on cache miss. The API and MCP sidecar bind the same memoised wrapper names, with regression coverage in MCP analysis/cache tests.
7. First-wave plan/spec artifacts were archived under `.planning/_archive/superpowers/`, and versions were bumped to API `0.20.11` and frontend `0.20.12`.

Verification performed for the first-wave merge included targeted API/frontend tests, live PubTator/auth and health integration checks, `make code-quality-audit`, `git diff --check`, `make pre-commit`, `make ci-local`, and passing GitHub Actions for PR #363.

## Remaining Findings After First Wave

The fixed first-wave findings are recorded above and removed from the active risk list. The remaining findings below are ordered by current implementation priority.

### P1: Destructive Metadata Refreshes Are Not Rollback-Safe

Several refresh paths wrap MySQL `TRUNCATE` inside transaction code:

- `api/endpoints/admin_endpoints.R:230-238`
- `api/endpoints/admin_endpoints.R:493-513`
- `api/endpoints/admin_endpoints.R:611-632`
- `api/functions/async-job-handlers.R:504-510`
- `api/functions/async-job-handlers.R:694-706`

MySQL `TRUNCATE` is DDL and auto-commits, so a failure after truncation cannot be rolled back. Some paths also disable foreign-key checks without an immediate `on.exit()` safety restore.

The newer HGNC async path already documents the safer pattern:

- `api/endpoints/jobs_endpoints.R:731-751`
- `api/functions/async-job-handlers.R:235-247`

**Recommendation:** replace these legacy `TRUNCATE` paths with transaction-safe `DELETE` plus insert, or a staging-table/swap design explicitly built for MySQL DDL auto-commit. Register `on.exit(SET FOREIGN_KEY_CHECKS = 1)` immediately after disabling FK checks.

### P1: Password Reset JWTs Are Accepted By General Auth Middleware

Password reset tokens are normal signed JWTs with `user_id`, `user_name`, `email`, `hash`, `iat`, and `exp`:

- `api/endpoints/user_endpoints.R:680-689`

The global middleware accepts any valid signed JWT and attaches `req$user_id` without checking token purpose:

- `api/core/middleware.R:115-128`

Self-service endpoints such as profile update require only `req$user_id`:

- `api/endpoints/user_endpoints.R:549-627`

The reset token may not have `user_role`, so role-gated admin routes fail, but self-service routes can still accept a password-reset token as an access token.

**Recommendation:** add `token_type` or `aud` claims. Require `token_type == "access"` in `require_auth()`, and validate `token_type == "password_reset"` only inside the reset-change endpoint.

### P2: Error Logging Keeps Raw Query Strings

Normal access logging was improved, but the error path still retains `QUERY_STRING`:

- `api/core/logging_sanitizer.R:78-83`
- `api/core/filters.R:238-246`

OWASP guidance treats query strings as high-risk for sensitive data because URLs leak through logs, history, and intermediaries. Even if current auth flows are body-based, accidental legacy query parameters can still persist on errors.

**Recommendation:** set `QUERY_STRING = "[redacted]"` in `sanitize_request()`, or parse and redact sensitive keys before logging.

### P2: Internet Archive Endpoint Is A Public GET With Weak URL Validation

The Internet Archive route is a public unauthenticated GET because the global middleware forwards unauthenticated GETs:

- `api/core/middleware.R:94-100`
- `api/endpoints/external_endpoints.R:35-54`

It validates by substring match against `dw$archive_base_url`:

- `api/endpoints/external_endpoints.R:38`
- `api/functions/external-functions.R:31-35`

A URL such as `https://attacker.example/?u=https://sysndd...` can satisfy a substring check while pointing at a non-SysNDD origin. The endpoint also performs an external side effect from GET.

**Recommendation:** require auth or convert to POST behind a role check, parse URLs with a real URL parser, require exact scheme/host allowlist, and reject userinfo/redirect-like forms.

### P2: Backup/Restore Credentials And Exit Handling Are Unsafe

Backup helpers pass DB passwords on process command lines:

- `api/functions/backup-functions.R:206-217`
- `api/functions/backup-functions.R:422-445`

Local restore targets filter MySQL output and append `|| true`, so failed restores can be reported as successful:

- `Makefile:420-423`
- `Makefile:436-438`

The Makefile also contains a real-looking literal DB password:

- `Makefile:233`
- `Makefile:262`

**Recommendation:** use `MYSQL_PWD` or a temporary MySQL defaults file inside the container instead of `-p...` command-line arguments, remove hard-coded credentials, and capture the `mysql` exit code before filtering expected warnings.

### P2: Dev DB Ports Bind All Interfaces With Weak Defaults

`docker-compose.dev.yml` publishes MySQL on all host interfaces with weak defaults:

- `docker-compose.dev.yml:37-42`
- `docker-compose.dev.yml:68-73`

This can expose dev/test MySQL on a LAN.

**Recommendation:** bind `127.0.0.1:7654:3306` and `127.0.0.1:7655:3306`, and require explicit local credentials for any non-ephemeral data.

### P2: Production Compose Still Bind-Mounts Source And Config

Base `docker-compose.yml` mounts mutable API and worker source/config into containers:

- `docker-compose.yml:143-150`
- `docker-compose.yml:251-260`

This weakens image immutability and lets a compromised container alter host code/config.

**Recommendation:** move live source mounts to dev overrides. In production, run image contents, mount only config/secrets read-only, and keep cache/results/backup volumes as the writable surface.

### P2: Raw Axios And Typed API Boundary Leaks Remain

AGENTS.md requires frontend API access through `app/src/api/*`. The About/CMS first-wave fix removed one direct bypass by routing draft load/save through `app/src/api/about.ts`, but production code still has direct HTTP access in composables, views, and legacy services.

Examples:

- `app/src/assets/js/services/apiService.ts:12`
- `app/src/composables/useAsyncJob.ts:4`
- `app/src/composables/usePubtatorAdmin.ts:12`
- `app/src/composables/annotations/useAnnotationsApi.ts:10`
- `app/src/composables/useGeneAlphaFold.ts:2`
- `app/src/views/admin/composables/useUserData.ts:106`
- `app/src/views/curate/composables/useEntityMutations.ts:50`

Typed helpers already exist for several bypassed areas, including PubTator routes in `app/src/api/publication.ts`, About routes in `app/src/api/about.ts`, and search routes in `app/src/api/search.ts`.

**Recommendation:** move remaining composable-owned HTTP wrappers into typed clients. Start with `usePubtatorAdmin`, `useAnnotationsApi`, external gene hooks, `useAsyncJob`, `useBatchForm`, user admin composables, and entity mutation composables. After migration, extend the lint boundary to `app/src/composables`.

### P2: Search Suggestions Interpolate User Input Into The Path

Legacy `apiService.ts` builds a search URL from raw user input:

- `app/src/assets/js/services/apiService.ts:59-61`
- `app/src/composables/useSearchSuggestions.ts:45`
- `app/src/components/small/SearchBar.vue:62`

Inputs containing `/`, `?`, `#`, `&`, or `%` can alter the path/query or fail unexpectedly. `app/src/api/search.ts` already has a typed helper that encodes path segments.

**Recommendation:** retire the legacy `assets/js/services/apiService.ts` search path and use `searchEntities()` from `app/src/api/search.ts`.

### P2: `TermSearch` Uses `v-html` On Unsanitized Highlight Strings

`TermSearch.vue` renders `highlightMatch()` output via `v-html`:

- `app/src/components/filters/TermSearch.vue:31`
- `app/src/components/filters/TermSearch.vue:115`

Current call sites may use controlled symbols/terms, but the component type accepts arbitrary `suggestions: string[]`, so reuse can become an XSS footgun.

**Recommendation:** render highlighted fragments as text nodes plus a `<strong>` element, or sanitize the generated HTML before binding.

### P2: SWR Stale Revalidation Does Not Dedupe Concurrent Refreshes

`useResource()` dedupes cold pending fetches, but stale background revalidation uses `force = true`:

- `app/src/composables/useResource.ts:72`
- `app/src/composables/useResource.ts:142`

Multiple consumers mounting against the same stale key can launch duplicate requests and overwrite the cache's single pending entry. Existing tests cover cold dedupe, not stale revalidation.

**Recommendation:** let background stale revalidation join existing pending fetches; reserve bypass for explicit `refresh()`. Add a two-consumer stale-cache test.

### P2: Sticky Cookie Conflicts With Public Privacy Copy

Durable async jobs make sticky sessions optional for correctness:

- `documentation/09-deployment.qmd:110-112`

Compose still enables a Traefik sticky cookie:

- `docker-compose.yml:216-220`

Public user-facing copy says regular users get a cookieless/stateless site:

- `app/src/components/small/AppBanner.vue:25-33`
- `app/src/components/disclaimer/DisclaimerDialog.vue:56-69`

**Recommendation:** remove the sticky-cookie labels unless still operationally required. If retained, update privacy copy and deployment docs to disclose it precisely.

### P2: Temporary Password Generation Uses Non-Cryptographic Randomness

Temporary account passwords are generated with base R `sample()`:

- `api/functions/account-helpers.R:37-45`

R's default RNG is not intended for credential generation. These passwords are emailed and become account credentials until changed.

**Recommendation:** use cryptographic randomness, for example `openssl::rand_bytes()` or `sodium`, encode with a password-safe alphabet, and enforce complexity after generation.

### P3: Large Source Files Remain A Maintenance Hotspot

`make code-quality-audit` passes, so the file-size ratchet is working. The current baseline still contains many oversized handwritten files. Largest current examples:

- `app/src/views/curate/ManageReReview.vue` — 1,570 lines
- `api/endpoints/admin_endpoints.R` — 1,368 lines
- `app/src/components/gene/GeneStructurePlotWithVariants.vue` — 1,306 lines
- `app/src/components/analyses/AnalyseGeneClusters.vue` — 1,292 lines
- `app/src/components/analyses/NetworkVisualization.vue` — 1,235 lines
- `app/src/components/tables/TablesLogs.vue` — 1,221 lines
- `api/endpoints/publication_endpoints.R` — 1,174 lines

The Understand graph marks the same API endpoint and analysis/visualization surfaces as complex.

**Recommendation:** do not do broad mechanical splits. Schedule focused decompositions around active change surfaces:

1. `ManageReReview.vue`: table/query state, preview/create/assign workflows, and modal state.
2. `AnalyseGeneClusters.vue` / `NetworkVisualization.vue`: visualization config, data loading, export/download, and interaction handlers.
3. `GeneStructurePlotWithVariants.vue` / `useD3Lollipop.ts`: D3 scales/rendering, brush/zoom, and export logic.
4. API endpoints: move endpoint-local business logic into `services/` or repository helpers while preserving `svc_` / `service_` prefixes.

### P3: Strict TypeScript Coverage Is Still Ratcheted, Not Global

`type-check:strict` passes, but `app/scripts/type-check-strict.js` still excludes strict cohorts:

- D3 and Cytoscape typing gaps
- file-saver typing
- Bootstrap-Vue-Next overload/null issues
- null narrowing
- API response narrowing
- toast shim typing

**Recommendation:** keep the ratchet. Retire exclusions by cohort, not file-by-file churn. Start with API response narrowing and toast shim typing because those unblock admin/curation composables.

### P3: Playwright Security Header Coverage Is Documented As CI But Is Local-Only

Deployment docs say CI's Playwright spec catches security-header drift:

- `documentation/09-deployment.qmd:180`
- `documentation/09-deployment.qmd:193`

But AGENTS.md and the current workflows state Playwright is local-only:

- `AGENTS.md:39`
- `.github/workflows/ci.yml` has no Playwright lane.

**Recommendation:** either add a manual `workflow_dispatch` Playwright security-header lane, or update deployment docs to say this is a local pre-release check.

### P3: README And April Review Are Now Stale

The April report is now a historical artifact, not a current review. It reports older version/test-count context. Current metadata:

- `app/package.json` version: `0.20.12`
- `api/version_spec.json` version: `0.20.11`
- `app/package.json` has `bootstrap-vue-next` `^0.45.4`
- `README.md:87-90` still says Bootstrap-Vue-Next `0.42`
- Current scan counted 187 frontend spec/test files and 130 API test files.

**Recommendation:** leave the April report as history, point new readers to this report, and update README tech-stack versions from package metadata.

## April Review Status Map

Resolved or materially improved:

- First-wave hardening resolved PubTator mutation authorization, API image runtime-config packaging, `deployment.sh`, About/CMS draft normalization, strict migration manifest checks, and MCP phenotype cache-hit-only behavior.
- Registration/authenticate now use POST JSON body.
- Durable async jobs are implemented with MySQL-backed state and a worker service.
- Original largest frontend view monoliths were decomposed, although new hotspots remain.
- Query logging was improved on the normal access path.
- Typed API clients exist and cover many areas.
- Node/GitHub Actions versions are current; official release pages show the current `checkout@v6`, `setup-node@v6`, `upload-artifact@v7`, `docker/setup-buildx-action@v4`, and `docker/build-push-action@v7` lines exist.

Still current or newly resurfaced:

- Rollback-unsafe `TRUNCATE` refreshes remain the highest-priority active finding.
- JWT token-purpose enforcement is still missing.
- Typed API adoption is incomplete.
- Component/view/API endpoint file sizes remain a maintenance risk.
- Browser E2E/Playwright remains local-only.
- CSP still intentionally retains `script-src 'unsafe-eval'` and `style-src 'unsafe-inline'`; this is documented but remains residual risk.
- Some documentation is stale relative to current code and workflow behavior.

## Recommended Sequence

### Immediate

1. Replace transaction-wrapped `TRUNCATE` refresh paths with rollback-safe patterns. This should be the next implementation plan.
2. Add JWT token purpose enforcement.
3. Redact query strings in error logging.
4. Harden backup/restore credentials and restore exit handling.
5. Bind dev MySQL ports to loopback only.
6. Remove production source bind mounts or make config/code mounts read-only and intentional.

### Next

1. Harden the public Internet Archive endpoint's auth/method/URL validation.
2. Generate temporary account passwords with cryptographic randomness.
3. Finish typed-client migration for composables and expand lint enforcement.
4. Fix search URL encoding and remove legacy `apiService.ts` search usage.
5. Replace `TermSearch` `v-html` highlighting.
6. Add stale-cache dedupe test/fix for `useResource`.

### After That

1. Decompose the largest active monoliths around active change surfaces.
2. Fix sticky-cookie/privacy copy mismatch.
3. Expand strict TypeScript coverage by cohort.
4. Update README tech-stack metadata and deployment docs.
5. Decide whether Playwright security-header coverage should become a manual CI lane or remain documented as local-only.

## Bottom Line

The April review's broad platform-hardening story is mostly complete, and the first-wave hardening issues from this review are now closed. The current risk profile is narrower: rollback-unsafe refreshes, token-purpose confusion, error-log query strings, backup/restore safety, local DB exposure, production bind mounts, and a few frontend/API boundary hazards. Fix rollback-safe metadata refreshes next, then continue the remaining hardening backlog before returning to broad typed-client, strict-TypeScript, and monolith-decomposition work.
