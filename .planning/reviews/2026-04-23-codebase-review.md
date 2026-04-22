# SysNDD Codebase Review

**Date:** 2026-04-23  
**Repository:** `berntpopp/sysndd`  
**Branch:** `master`  
**Baseline compared:** `.planning/reviews/2026-04-11-codebase-review.md`

## Executive Summary

The 2026-04-11 review is materially stale. Since then, SysNDD has improved in three important ways:

1. The API bootstrap was extracted into `api/bootstrap/*`; `api/start_sysndd_api.R` is now a thin composer.
2. Migration governance was tightened; `db/migrations/README.md` now documents the automatic runner and the historical duplicate `008_*` issue has been reconciled.
3. Test coverage and CI are materially stronger. The frontend now has 56 passing spec files, the API has a substantial `testthat` suite, slow nightly tests exist, and CI includes a production smoke test.

The current review is therefore not "the same review, updated a bit". It is a re-baselined assessment of the current codebase.

The codebase is in a much healthier state than it was on 2026-04-11, but it still carries four high-leverage risks:

1. Sensitive data still travels in URL query strings in some auth-related flows, and raw query strings are still logged.
2. The highest-severity open correctness issue is now data integrity, not architecture: issue `#167`.
3. Async job state is still in-process and non-durable.
4. The frontend architecture migration is only partially complete: the typed API layer exists, but most of the app still bypasses it.

## Method

- Direct inspection of current repo state in `app/`, `api/`, `db/`, `docs/`, `.github/workflows/`
- Comparison against `.planning/reviews/2026-04-11-codebase-review.md`
- Parallel independent review passes for frontend, backend, and testing/backlog
- Current-docs spot check against primary sources:
  - OWASP ASVS 8.3.1 on sensitive data in query strings: https://owasp-aasvs4.readthedocs.io/en/latest/8.3.1.html
  - Vue composables guidance: https://vuejs.org/guide/reusability/composables
  - Pinia introduction: https://pinia.vuejs.org/introduction.html
  - Vitest coverage thresholds: https://vitest.dev/config/coverage.html
  - OWASP CSP cheat sheet: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html
  - OWASP HSTS cheat sheet: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html
  - Traefik headers middleware docs: https://doc.traefik.io/traefik/v3.3/middlewares/http/headers/
  - `mirai` docs: https://mirai.r-lib.org/

## What Changed Since 2026-04-11

### Findings from the old review that are now stale or wrong

- The bootstrap is no longer a 971-line god-script. `api/start_sysndd_api.R` now composes `api/bootstrap/*`.
- Migration documentation is no longer stale. `db/migrations/README.md` now documents the startup runner and advisory locking.
- The duplicate `008_*` migration-prefix finding is no longer current; the tree now uses unique prefixes through `018_hgnc_symbol_lookup.sql`.
- Frontend auth state is no longer duplicated across five unrelated readers. `app/src/composables/useAuth.ts` is now the central owner, and router/navbar integrations exist.
- Login and password-change no longer send credentials in query strings from the frontend. Those frontend call sites were fixed.
- The "minimal frontend test coverage" conclusion is stale. The app now has broad Vitest coverage, MSW handlers, view specs, and a ratcheted coverage gate.

### Areas where the old review was directionally right but now need re-scoring

- TypeScript strictness is still off globally, but strict-scoped type-checking is now present and passing.
- Large Vue views still exist, but there are three remaining monoliths, not six 1400+ LoC views.
- Async jobs are still stored in memory, but this now stands out more clearly because other platform hardening work has already landed.

## Current Findings

### P0

#### 1. Open data-integrity issue `#167` is the top production risk

The strongest currently open production risk is issue `#167`, which documents active suffix-gene misalignments and other entity-integrity problems. This is a correctness issue against core domain data, not just code quality debt, and should outrank feature work.

Why this is P0:

- It affects persisted domain truth.
- It can surface incorrect disease/gene relationships in the product.
- It is already analyzed in depth and appears actionable.

Recommendation:

- Prioritize `#167` before new feature work.
- Split it into a short remediation milestone:
  - one-time data repair
  - validation queries
  - regression guard in the ontology update pipeline

### P1

#### 2. Registration still sends PII in a query string

The login and password-change frontend flows were fixed, but registration was not.

Current path:

- `app/src/views/RegisterView.vue` still calls `GET /api/auth/signup?signup_data=...`
- `api/endpoints/authentication_endpoints.R` still exposes signup as `@get signup`
- `api/tests/testthat/test-e2e-user-lifecycle.R` still exercises signup through query params

Impact:

- Names, email, ORCID, and free-text comment fields can land in browser history, reverse-proxy logs, server access logs, and monitoring systems.
- OWASP ASVS 8.3.1 explicitly says sensitive data should not be carried in query string parameters.

Recommendation:

- Add `POST /api/auth/signup` with JSON body.
- Migrate the frontend and tests to the body-based path.
- Remove or rapidly deprecate the query-string path.

#### 3. Legacy URL-based auth/password compatibility remains on the backend, and raw query strings are still logged

Even though the frontend no longer uses URL-based login/password updates, the API still keeps those legacy forms alive:

- `api/endpoints/authentication_endpoints.R` still contains `@get authenticate`
- `api/endpoints/user_endpoints.R` still accepts the transitional password-update shape
- `api/bootstrap/mount_endpoints.R` logs `req$QUERY_STRING` verbatim into both the application log entry and DB logging path

Impact:

- The remaining legacy paths preserve the original security bug in backend behavior.
- Because query strings are logged raw, any legacy caller still leaks secrets into logs.

Recommendation:

- Remove the legacy GET auth path and legacy query-param password-update support.
- Redact or drop raw query-string logging by default.
- Add a regression test proving auth/password flows cannot be reconstructed from logs.

#### 4. Async job state is still in-memory and tied to sticky sessions

`api/functions/job-manager.R` still stores job state in `jobs_env`, which means restarts or replica changes lose state. Sticky sessions mitigate routing drift, but they do not provide durability.

This aligns directly with open issue `#154`.

Why it matters now:

- The rest of the platform is more disciplined now, so this stands out as the main backend reliability gap.
- The frontend already has explicit sticky-session handling in `useAsyncJob.ts`, which is a sign the implementation detail is leaking into application behavior.

Recommendation:

- Move job metadata and state to durable storage.
- Minimum viable fix: persist jobs in MySQL and treat memory as a cache.
- Better long-term fix: land `#154` and move to a queue-backed worker model.

#### 5. Frontend architecture migration is incomplete

The app now has a good direction:

- `app/src/api/client.ts`
- `app/src/api/auth.ts`
- `app/src/api/genes.ts`
- `app/src/composables/useAuth.ts`

But the migration is far from complete:

- `app/src/api/*.ts` contains many stub modules
- many production call sites still use raw `axios.get/post/put/...`
- a large part of auth, table, and view logic still lives in Options API monoliths

This conflicts with current Vue guidance around extracting reusable logic into small composables and isolated units.

Recommendation:

- Treat the architecture debt as a migration-completion problem, not a redesign problem.
- Prioritize moving active, high-change views first.
- Make new work consume `app/src/api/*` instead of adding more raw `axios` call sites.

### P2

#### 6. Type safety is improving, but still not strong enough globally

`app/tsconfig.json` still has:

- `strict: false`
- `noImplicitAny: false`
- `allowJs: true`

That said, this area is improved relative to April:

- strict-scoped configs exist
- `npm run type-check:strict` currently passes for the scoped targets

Risk:

- The app still relies on runtime checking and local escape hatches in complex views.
- The typed API layer cannot pay off fully while most call sites bypass it.

Recommendation:

- Keep the incremental strategy.
- Expand strict-scoped coverage around `src/api/`, `src/router/`, `useAuth`, and the highest-churn table/view boundaries.
- Do not flip full-project strict mode until the raw-axios migration is further along.

#### 7. Three large frontend monoliths remain

The remaining large views are still:

- `app/src/views/admin/ManageUser.vue`
- `app/src/views/curate/ModifyEntity.vue`
- `app/src/views/review/Review.vue`

This is no longer the sweeping "six giant views" problem from April, but these files are still too large and still mix fetch, transform, workflow, and UI concerns. Vue's composables guidance favors composing complex logic from small isolated units, and these three views remain the clearest place where the codebase is not following that direction.

Recommendation:

- Continue the successful extraction pattern already used elsewhere.
- Leave the view as orchestration shell.
- Move data loading, filters, modal state, and mutation workflows into composables/components.

#### 8. Auth-state cleanup still has a reactive drift edge case

`app/src/plugins/axios.ts` clears `localStorage` directly on 401. `useAuth.ts` documents the drift problem and contains `handle401()`, but that path is not yet the single owner of logout cleanup.

Impact:

- Reactive UI state can temporarily drift from persisted auth state until the next `useAuth()` read or route transition.

Recommendation:

- Route 401 cleanup through `useAuth.handle401()`.
- Add a focused regression test around logout propagation across navbar, route guard, and redirected page state.

#### 9. Security headers improved, but deployment policy is not yet settled

This is an area where the code improved but governance is incomplete:

- `app/docker/nginx/security-headers.conf` now emits HSTS, CSP, and related headers.
- Open issues `#299` and `#300` correctly capture the unresolved decisions:
  - CSP still allows `'unsafe-inline'` and `'unsafe-eval'`
  - HSTS `preload` + `includeSubDomains` is a one-way policy decision

The current implementation is better than the April snapshot, but the repo still needs a documented operating policy tied to those issues.

Recommendation:

- Resolve `#299` and `#300` as deployment-policy issues, not just code cleanup.
- Document the final stance in `docs/DEPLOYMENT.md`.

### P3

#### 10. Test coverage is much better, but browser-level workflow regression coverage is still missing

Current state is solid relative to April:

- Frontend unit/spec suite passes
- API test suite is broad
- nightly slow tests exist
- smoke test exists in CI

Verification run on this review:

- `npm run type-check:strict` -> passed
- `npm run test:unit` -> passed
  - 56 test files
  - 601 tests passed
  - 3 `todo`

Remaining gap:

- The curation flows still do not have a true browser-level regression layer.
- `Review.spec.ts` still contains a locked `it.todo` for a back-navigation case.

Recommendation:

- Add a thin browser-level regression suite for the highest-value curator/reviewer flows.
- Keep the current Vitest/MSW foundation as the fast inner loop.

## Open Issues: Prioritized and Grouped

This section covers the **currently open GitHub issues**, grouped by operational priority rather than age.

### P0: correctness / data trust

- `#167` Entity data integrity audit: 13 suffix-gene misalignments and other pre-existing issues

### P1: security posture / production correctness

- `#299` CSP tightening
- `#300` HSTS preload decision
- `#29` inconsistent entity-batch grouping
- `#98` replace VariO ontology with alternative

### P2: platform and workflow improvements

- `#154` durable job queue / heavy-light workers
- `#175` normalize PubTator gene counts
- `#105` automated log cleanup
- `#89` links to curation/correlation matrix
- `#55` removal option in approve review/status workflow
- `#54` refusal button for re-reviews
- `#48` PubTator query and gene-list generation endpoint
- `#46` GeneReviews update enhancement
- `#37` direct approval option in create/modify entity pages
- `#33` database creation scripts enhancement
- `#32` admin view for phenotype-related data
- `#25` CSR/certificate automation
- `#22` DB database version
- `#15` variant annotation search/filter/download
- `#14` search for new GeneReview articles

### P3: docs / polish / cleanup

- `#83` curation comparisons input style inconsistency
- `#56` documentation for view functions
- `#52` explain the "not applicable" category
- `#51` describe variant ontology curation
- `#50` explain how to find a PMID for GeneReviews
- `#49` bug-reporting documentation
- `#5` rename `entity_quadruple` constraint

## Recommended Next Sequence

### Immediate

1. Fix or at least open a tracked issue for registration PII in query strings.
2. Remove legacy URL-based auth/password compatibility and raw query-string logging.
3. Triage and execute `#167`.

### Next milestone

1. Land durable async job state work from `#154` or a smaller MySQL-backed intermediate.
2. Finish the auth cleanup path so 401 handling has a single owner.
3. Continue migrating active views onto `app/src/api/*` and away from raw `axios`.

### After that

1. Resolve `#299` and `#300` with documented deployment policy.
2. Add browser-level workflow regression coverage.
3. Expand strict-scoped TypeScript coverage as the API migration advances.

## Bottom Line

SysNDD is no longer in the state described by the 2026-04-11 review. The platform has already done meaningful hardening work. The right strategy now is not a broad "modernization" push; it is a focused finish-the-hardening sequence:

- fix the remaining sensitive-data transport/logging paths
- repair the known data-integrity issue
- make async jobs durable
- complete the frontend API/composable migration already underway

That is a much narrower and more actionable backlog than the April review suggested.
