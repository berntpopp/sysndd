# Admin Curation Boundary Sprint Design

## Goal

Reduce architectural risk in the authenticated admin/curation frontend by moving request construction and workflow orchestration out of oversized Vue components and into typed API helpers plus focused local composables.

This sprint is intentionally narrow enough for one LLM implementation session. It targets two high-risk surfaces:

- `app/src/views/curate/ManageReReview.vue`
- `app/src/components/tables/TablesLogs.vue`

## Why This Sprint

The merged top-10 refactor lowered file-size baselines and extracted pure helpers, but several large components still mix UI state, raw request URLs, response normalization, caching, error handling, and workflow side effects. That makes future changes risky for humans and LLM agents because editing one method requires understanding auth, API shape, table state, and user feedback at the same time.

`ManageReReview.vue` and `TablesLogs.vue` are the best next targets because they are authenticated operational pages and still contain direct `import.meta.env.VITE_API_URL` request construction. These call sites duplicate typed client behavior, create local-dev CSP risk when production API URLs leak into builds, and obscure which API contracts the component actually depends on.

## Scope

### In Scope

1. Complete the typed API-client boundary for the touched admin/curation calls.
2. Remove raw URL construction from the touched methods in `ManageReReview.vue` and `TablesLogs.vue`.
3. Extract one local orchestration boundary for each component:
   - re-review assignment workflow helpers or composable state for `ManageReReview.vue`
   - log table request/cache helpers for `TablesLogs.vue`
4. Preserve route names, URLs, visible UI behavior, emitted events, table columns, pagination behavior, and toast/aria-live copy.
5. Add or strengthen tests before each production extraction.
6. Ratchet `scripts/code-quality-file-size-baseline.tsv` downward only when a touched file shrinks.

### Out of Scope

1. Broad UI redesign of admin pages.
2. Backend endpoint changes.
3. Rewriting generic table infrastructure.
4. Replacing the existing module-level duplicate-request cache with a global store.
5. Refactoring unrelated raw `VITE_API_URL` call sites outside this sprint.
6. Playwright suite repair for pre-existing local stack data/CSP failures.

## Current Architecture

`app/src/api/re_review.ts` already exposes typed helpers for most re-review operations, including assignment table, batch assignment, unassignment, entity assignment, reassignment, archive, and recalculation. `app/src/api/logging.ts` already exposes typed helpers for listing logs, exporting logs as XLSX, and deleting logs. `app/src/api/user.ts` exposes `listUsersByRole`, and `app/src/api/list.ts` exposes status-list helpers.

Despite those clients, `ManageReReview.vue` still builds request URLs inline for:

- `GET /api/user/list?roles=Curator,Reviewer`
- `GET /api/re_review/assignment_table`
- `PUT /api/re_review/batch/assign`
- `DELETE /api/re_review/batch/unassign`
- `GET /api/re_review/entities/available`
- `PUT /api/re_review/entities/assign`
- `PUT /api/re_review/batch/reassign`
- `PUT /api/re_review/batch/recalculate`
- `GET /api/list/status`

`TablesLogs.vue` still builds request URLs inline for:

- `GET /api/user/list`
- `GET /api/logs/`
- `GET /api/logs/?format=xlsx`
- `DELETE /api/logs/`

## Target Architecture

### API Layer

The API layer owns endpoint paths, query parameter names, and raw envelope types. Components should call functions with typed parameter objects instead of string-building endpoint URLs.

Add or complete these helpers:

- `app/src/api/re_review.ts`
  - `listAvailableReReviewEntities(params)`
  - tighten response types for `getAssignmentTable`, `assignReReviewEntities`, and `recalculateReReviewBatch` where the component currently reads `entry.batch_id`, `entry.entity_count`, `data`, and `meta.total`.
- `app/src/api/logging.ts`
  - ensure `listLogs`, `listLogsXlsx`, and `deleteLogs` return component-useful data without exposing raw axios responses.
- `app/src/api/user.ts`
  - reuse `listUsersByRole({ roles: 'Curator,Reviewer' })` and `listUsersByRole()` instead of direct component calls.
- `app/src/api/list.ts`
  - reuse `listStatusCategories()` for `ManageReReview.vue` status options.

### Component Orchestration

The components remain the owners of presentation, modal state, selected rows, toast calls, aria-live announcements, and router/URL behavior. Extracted orchestration must not hide user-facing decisions in generic helpers.

For `ManageReReview.vue`, extract a small local helper module or composable only after typed clients are in place. The likely boundary is "re-review admin request normalization": converting API responses into component option rows and assignment table rows.

For `TablesLogs.vue`, extract request/cache coordination into `app/src/components/tables/logTableRequests.ts`. The helper should own duplicate-request detection and API calls, while the component owns applying returned data to Vue state and updating browser history after a successful fresh API load. Cache hits must apply cached response data without calling `updateBrowserUrl()`, preserving the current behavior where URL replacement happens only after a non-cached API success.

## Testing Strategy

Tests must be added or strengthened before touching production code in each slice.

### API Client Tests

Use existing MSW-based API client spec patterns:

- `app/src/api/re_review.spec.ts`
- `app/src/api/logging.spec.ts`
- `app/src/api/user.spec.ts`
- `app/src/api/list.spec.ts`

Pin exact paths and query parameters. These tests should fail if a future component or helper reintroduces absolute production URLs or wrong parameter names.

### Component Tests

Use existing component specs:

- `app/src/views/curate/ManageReReview.spec.ts`
- `app/src/components/tables/TablesLogs.spec.ts`

Keep the existing Bearer-header tests, but update expectations so they prove the component reaches the typed API clients through relative `/api/...` paths. Add focused tests for behavior that the extraction touches:

- user-list mapping to select options
- assignment-table response normalization
- available-entity response normalization
- successful assignment/reassignment/recalculation refresh behavior
- log list request caching and API response application
- log XLSX export receiving a `Blob`
- log delete request parameter normalization

## Verification

Each slice must run the smallest targeted tests first, then the stack checks relevant to the files touched.

Frontend slice commands:

```bash
cd app && npx vitest run src/api/re_review.spec.ts src/api/user.spec.ts src/api/list.spec.ts
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
cd app && npx vitest run src/api/logging.spec.ts
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Final session commands:

```bash
git diff --check
make pre-commit
```

Run `make ci-local` if the local environment is available and time permits. If blocked, document the exact command and blocker.

## Success Criteria

1. No touched `ManageReReview.vue` or `TablesLogs.vue` request method constructs URLs with `import.meta.env.VITE_API_URL`.
2. API paths and query names for the touched operations live in `app/src/api/*`.
3. The two large components shrink meaningfully without mechanical splitting.
4. No public routes, admin route guards, table columns, UI copy, or typed client boundaries regress.
5. Tests and `make code-quality-audit` pass.

## Risks

- Component tests currently stub broad Bootstrap and composable surfaces. Keep new tests narrow and method-level to avoid brittle DOM assertions.
- Some existing methods expect flexible API envelopes. Tighten types only around fields that are actually consumed by the component.
- `TablesLogs.vue` duplicate-request caching is module-level and intentional. Preserve that behavior until it is covered by focused tests.
- `ManageReReview.vue` currently sends `batch_name: null` when the optional manual assignment batch name is empty. Preserve that wire shape unless the R handler is verified to require a different representation.
- Do not convert all raw axios/VITE_API_URL call sites in the repo. That would turn this into a broad rewrite.
