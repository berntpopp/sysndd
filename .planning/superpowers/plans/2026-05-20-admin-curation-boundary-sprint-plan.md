# Admin Curation Boundary Sprint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move high-risk admin/curation request construction out of oversized Vue components and into typed API helpers plus focused local orchestration helpers.

**Architecture:** Keep Vue pages responsible for presentation, modal state, toasts, aria-live announcements, and URL updates. Put endpoint paths, query parameter names, and response envelope types in `app/src/api/*`. Put local duplicate-request/cache coordination for the logs table in a colocated helper.

**Tech Stack:** Vue 3, TypeScript, Vitest, MSW, Vite type-checking, SysNDD `apiClient`, `make code-quality-audit`.

---

## Completion Status

- Completed and merged via PR #359: https://github.com/berntpopp/sysndd/pull/359
- Merge commit: `aaea7f66ce7feb87f34de31784f7b8671806995b`
- Final branch head before merge: `9968901d6421f306ad2ac34102ab15a823713142`
- Version bumped to `0.20.8` in `api/version_spec.json`, `app/package.json`, and `app/package-lock.json`.
- Follow-up issue for noisy-but-passing local CI output: https://github.com/berntpopp/sysndd/issues/360

Final verification completed before merge:

```bash
git diff --check
cd app && npx vitest run src/api/re_review.spec.ts src/api/logging.spec.ts src/api/user.spec.ts src/api/list.spec.ts
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts src/components/tables/TablesLogs.spec.ts src/components/tables/logTableRequests.spec.ts
cd app && npm run type-check
make code-quality-audit
make pre-commit
make ci-local
```

GitHub CI passed on the final commit, including `CI Success`, `Build Frontend`, `Check Frontend`, `Lint R API`, `Smoke Test (prod stack)`, `Test R API (fast PR gate)`, and `make doctor (ubuntu-latest)`.

## Guardrails

- Work on a normal branch, for example `plan/admin-curation-boundary-sprint`.
- Do not create git worktrees unless the user explicitly asks.
- Do not change public routes, route guards, UI copy, table columns, or API endpoint paths.
- Add or strengthen focused tests before touching each production component.
- Prefer typed clients from `app/src/api/*`; do not add new raw axios calls.
- Do not broaden scope to unrelated `VITE_API_URL` call sites.
- After each cohesive extraction, run targeted tests, `cd app && npm run type-check`, and `make code-quality-audit`.
- Update `scripts/code-quality-file-size-baseline.tsv` downward only.
- Commit after each cohesive extraction.

## File Map

- Modify: `app/src/api/re_review.ts`
  - Own re-review endpoint paths, query params, and consumed response shapes.
- Modify: `app/src/api/re_review.spec.ts`
  - Pin new re-review typed client helpers.
- Modify: `app/src/api/logging.ts`
  - Keep logs list/export/delete helpers returning component-useful values.
- Modify: `app/src/api/logging.spec.ts`
  - Pin log helper query params and binary export behavior.
- Inspect: `app/src/api/user.ts`
  - Reuse existing `listUsersByRole()` from components.
- Modify: `app/src/views/curate/ManageReReview.vue`
  - Replace inline URL construction with typed clients and small response-mapping helpers.
- Modify: `app/src/views/curate/ManageReReview.spec.ts`
  - Update tests to assert relative API paths and behavior after client migration.
- Modify: `app/src/components/tables/TablesLogs.vue`
  - Replace inline URL construction with typed clients and extracted request/cache helper.
- Create: `app/src/components/tables/logTableRequests.ts`
  - Own duplicate-call detection and logs API call coordination.
- Create: `app/src/components/tables/logTableRequests.spec.ts`
  - Pin duplicate-request/cache behavior without mounting the full component.
- Inspect/run: `app/src/components/tables/TablesLogs.spec.ts`
  - No planned edit. Existing Bearer-header tests should still pass through the typed clients and `apiClient` interceptor; edit only if the migration changes component-observable behavior.
- Modify: `scripts/code-quality-file-size-baseline.tsv`
  - Lower only changed oversized file entries after shrink.

---

### Task 1: Complete Re-Review Typed API Surface

**Files:**
- Modify: `app/src/api/re_review.spec.ts`
- Modify: `app/src/api/re_review.ts`

- [x] **Step 1: Add failing API-client tests for available entities and tighter batch entries**

`app/src/api/re_review.spec.ts` already has coverage for `assignReReviewEntities()` and `recalculateReReviewBatch()` request bodies. Keep those existing tests if they pin useful body fields; the tests below add the missing available-entities helper and tighten the returned `entry` shape consumed by `ManageReReview.vue`.

Add these imports to `app/src/api/re_review.spec.ts` if they are not already present:

```ts
import {
  listAvailableReReviewEntities,
  assignReReviewEntities,
  recalculateReReviewBatch,
} from './re_review';
```

Add these tests near the other re-review API helper tests:

```ts
it('GET /api/re_review/entities/available sends q/page/page_size params', async () => {
  let observedQuery: URLSearchParams | null = null;
  server.use(
    http.get('/api/re_review/entities/available', ({ request }) => {
      observedQuery = new URL(request.url).searchParams;
      return HttpResponse.json({
        data: [{ entity_id: 11, symbol: 'ARID1B' }],
        meta: { total: 1 },
      });
    })
  );

  const result = await listAvailableReReviewEntities({ q: 'ARI', page: 2, page_size: 50 });

  expect(observedQuery?.get('q')).toBe('ARI');
  expect(observedQuery?.get('page')).toBe('2');
  expect(observedQuery?.get('page_size')).toBe('50');
  expect(result.data).toEqual([{ entity_id: 11, symbol: 'ARID1B' }]);
  expect(result.meta?.total).toBe(1);
});

it('PUT /api/re_review/entities/assign returns the created batch entry', async () => {
  server.use(
    http.put('/api/re_review/entities/assign', async ({ request }) => {
      expect(await request.json()).toEqual({
        entity_ids: [11, 12],
        user_id: 7,
        batch_name: 'Manual ARID batch',
      });
      return HttpResponse.json({
        status: 200,
        entry: { batch_id: 4, entity_count: 2 },
      });
    })
  );

  const result = await assignReReviewEntities({
    entity_ids: [11, 12],
    user_id: 7,
    batch_name: 'Manual ARID batch',
  });

  expect(result.entry?.batch_id).toBe(4);
  expect(result.entry?.entity_count).toBe(2);
});

it('PUT /api/re_review/batch/recalculate sends criteria body and returns entry', async () => {
  server.use(
    http.put('/api/re_review/batch/recalculate', async ({ request }) => {
      expect(await request.json()).toEqual({
        re_review_batch: 9,
        batch_size: 20,
        status_filter: 3,
      });
      return HttpResponse.json({
        status: 200,
        entry: { batch_id: 9, entity_count: 17 },
      });
    })
  );

  const result = await recalculateReReviewBatch({
    re_review_batch: 9,
    batch_size: 20,
    status_filter: 3,
  });

  expect(result.entry?.batch_id).toBe(9);
  expect(result.entry?.entity_count).toBe(17);
});
```

- [x] **Step 2: Run the API-client tests and confirm the new helper test fails**

Run:

```bash
cd app && npx vitest run src/api/re_review.spec.ts
```

Expected: fail because `listAvailableReReviewEntities` is not exported yet.

- [x] **Step 3: Implement the typed helper and consumed response types**

In `app/src/api/re_review.ts`, add these interfaces near the batch-management types:

```ts
export interface AvailableReReviewEntitiesParams {
  q?: string;
  page?: number;
  page_size?: number;
}

export interface AvailableReReviewEntity {
  entity_id: number;
  symbol?: string | null;
  disease_ontology_name?: string | null;
  category?: string | null;
  [key: string]: unknown;
}

export interface AvailableReReviewEntitiesResponse {
  data: AvailableReReviewEntity[];
  meta?: {
    total?: number | number[];
    [key: string]: unknown;
  };
}

export interface BatchEntry {
  batch_id?: number;
  re_review_batch?: number;
  entity_count?: number;
  [key: string]: unknown;
}
```

Update `BatchServiceResponse` so `entry` is typed:

```ts
export interface BatchServiceResponse {
  status: number;
  message?: string;
  entry?: BatchEntry;
  error?: string;
  [key: string]: unknown;
}
```

Update `AssignEntitiesRequest` to preserve the current component wire shape for empty optional batch names:

```ts
export interface AssignEntitiesRequest {
  entity_ids: number[];
  user_id: number;
  batch_name?: string | null;
}
```

Add the helper after `getAssignmentTable()`:

```ts
/**
 * GET /api/re_review/entities/available
 * Mirrors api/endpoints/re_review_endpoints.R available-entities handler.
 *
 * Curator+ only. Returns entities currently available for manual batch
 * assignment.
 */
export async function listAvailableReReviewEntities(
  params: AvailableReReviewEntitiesParams = {},
  config?: AxiosRequestConfig
): Promise<AvailableReReviewEntitiesResponse> {
  return apiClient.get<AvailableReReviewEntitiesResponse>('/api/re_review/entities/available', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
```

- [x] **Step 4: Verify re-review API-client tests pass**

Run:

```bash
cd app && npx vitest run src/api/re_review.spec.ts
```

Expected: pass.

- [x] **Step 5: Commit the typed API helper**

Run:

```bash
git add app/src/api/re_review.ts app/src/api/re_review.spec.ts
git commit -m "refactor: complete re-review typed api helpers"
```

---

### Task 2: Migrate ManageReReview To Typed Clients

**Files:**
- Modify: `app/src/views/curate/ManageReReview.spec.ts`
- Modify: `app/src/views/curate/ManageReReview.vue`
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [x] **Step 1: Strengthen component tests before production changes**

In `app/src/views/curate/ManageReReview.spec.ts`, add a test that proves the user-list call uses the relative API path:

```ts
it('loadUserList maps Curator/Reviewer rows from the typed user client', async () => {
  primeAuth('re-review-users-token');
  let observedUrl = '';

  server.use(
    http.get('/api/user/list', ({ request }) => {
      observedUrl = request.url;
      expectBearerHeader(request, 're-review-users-token');
      return HttpResponse.json([
        { user_id: 7, user_name: 'curator_a', user_role: 'Curator' },
        { user_id: 8, user_name: 'reviewer_b', user_role: 'Reviewer' },
      ]);
    }),
    http.get('/api/re_review/assignment_table', () => HttpResponse.json([])),
    http.get('/api/re_review/entities/available', () =>
      HttpResponse.json({ data: [], meta: { total: 0 } })
    ),
    http.get('/api/list/status', () => HttpResponse.json({ data: [] }))
  );

  const wrapper = await mountManageReReview();
  await flushPromises();

  expect(new URL(observedUrl).searchParams.get('roles')).toBe('Curator,Reviewer');
  expect(vm(wrapper).user_options).toEqual([
    { value: 7, text: 'curator_a', role: 'Curator' },
    { value: 8, text: 'reviewer_b', role: 'Reviewer' },
  ]);
});
```

Add another test for available-entity normalization:

```ts
it('loadAvailableEntities normalizes entity rows and scalar total from the typed client', async () => {
  primeAuth('re-review-entities-token');

  server.use(
    http.get('/api/user/list', () => HttpResponse.json([])),
    http.get('/api/re_review/assignment_table', () => HttpResponse.json([])),
    http.get('/api/list/status', () => HttpResponse.json({ data: [] })),
    http.get('/api/re_review/entities/available', ({ request }) => {
      const query = new URL(request.url).searchParams;
      expect(query.get('q')).toBe('ARID');
      expect(query.get('page')).toBe('1');
      expect(query.get('page_size')).toBe('100');
      return HttpResponse.json({
        data: [{ entity_id: 11, symbol: 'ARID1B' }],
        meta: { total: 1 },
      });
    })
  );

  const wrapper = await mountManageReReview();
  const component = vm(wrapper);
  component.manualEntityFilter = 'ARID';

  await component.loadAvailableEntities();
  await flushPromises();

  expect(component.availableEntities).toEqual([{ entity_id: 11, symbol: 'ARID1B' }]);
  expect(component.availableEntityTotal).toBe(1);
});
```

- [x] **Step 2: Run ManageReReview tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
```

Expected: pass or fail only where assertions expose current absolute URL construction. Do not edit production code until this is observed.

- [x] **Step 3: Replace inline request construction with typed clients**

In `app/src/views/curate/ManageReReview.vue`, replace the `apiClient` import with typed imports:

```ts
import {
  assignReReviewBatch,
  assignReReviewEntities,
  getAssignmentTable,
  listAvailableReReviewEntities,
  recalculateReReviewBatch,
  reassignReReviewBatch,
  unassignReReviewBatch,
} from '@/api/re_review';
import { listUsersByRole } from '@/api/user';
import { listStatusCategories } from '@/api/list';
```

Update methods as follows:

```ts
async loadUserList() {
  try {
    const data = await listUsersByRole({ roles: 'Curator,Reviewer' });
    this.user_options = Array.isArray(data)
      ? data.map((item) => ({
          value: item.user_id,
          text: item.user_name,
          role: item.user_role,
        }))
      : [];
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.user_options = [];
  }
},
async loadReReviewTableData() {
  this.loadingReReviewManagment = true;
  try {
    const data = await getAssignmentTable();
    this.items_ReReviewTable = Array.isArray(data) ? data : [];
    this.totalRows = this.items_ReReviewTable.length;
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.items_ReReviewTable = [];
    this.totalRows = 0;
  } finally {
    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
    this.loadingReReviewManagment = false;
  }
},
async handleNewBatchAssignment() {
  try {
    await assignReReviewBatch({ user_id: this.user_id_assignment });
    this.makeToast('New batch assigned successfully.', 'Success', 'success');
    this.announce('New batch assigned successfully');
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.announce('Failed to assign batch', 'assertive');
  }
  this.loadReReviewTableData();
},
async handleBatchUnAssignment(batch_id) {
  try {
    await unassignReReviewBatch({ re_review_batch: batch_id });
    this.makeToast('Batch unassigned successfully.', 'Success', 'success');
    this.announce('Batch unassigned successfully');
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
    this.announce('Failed to unassign batch', 'assertive');
  }
  this.loadReReviewTableData();
},
async loadAvailableEntities() {
  this.isLoadingEntities = true;
  try {
    const responseData = await listAvailableReReviewEntities({
      q: this.manualEntityFilter || '',
      page: 1,
      page_size: 100,
    });
    this.availableEntities = responseData.data || [];
    const total = responseData.meta?.total;
    this.availableEntityTotal = Array.isArray(total)
      ? (total[0] ?? this.availableEntities.length)
      : (total ?? this.availableEntities.length);
    this.previewBoundaryGene = null;
    this.previewGeneCount = 0;
    this.previewEntityCount = 0;
  } catch (_e) {
    this.makeToast('Failed to load available entities', 'Error', 'danger');
  } finally {
    this.isLoadingEntities = false;
  }
},
```

Update entity assignment, reassignment, recalculation, and status methods. Preserve the surrounding validation, payload-building, toast/announce messages, modal state updates, and table/entity refresh calls exactly as they are today; replace only the API invocation blocks.

```ts
const responseData = await assignReReviewEntities({
  entity_ids: this.selectedEntityIds,
  user_id: this.entityAssignUserId,
  batch_name: this.entityAssignBatchName || null,
});
```

`batch_name: null` intentionally preserves the current wire shape for an empty optional batch name.

```ts
await reassignReReviewBatch({
  re_review_batch: this.reassignBatchId,
  user_id: this.reassignNewUserId,
});
```

```ts
const responseData = await recalculateReReviewBatch(payload);
```

```ts
const responseData = await listStatusCategories();
const data = responseData?.data || [];
```

Also update any existing `ManageReReview.spec.ts` status-list MSW handlers that currently return a raw array for `/api/list/status` to return the typed-client envelope:

```ts
HttpResponse.json({ data: [{ category_id: 1, category: 'Definitive' }] })
```

This keeps status-option population aligned with `listStatusCategories()`. Tests that only assert the Bearer interceptor may still pass with a raw array, but the fixture should represent the typed-client contract.

- [x] **Step 4: Remove obsolete `apiClient` import**

Run:

```bash
rg -n "apiClient|VITE_API_URL" app/src/views/curate/ManageReReview.vue
```

Expected: no matches.

- [x] **Step 5: Verify ManageReReview migration**

Run:

```bash
cd app && npx vitest run src/api/re_review.spec.ts src/api/user.spec.ts src/api/list.spec.ts
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [x] **Step 6: Ratchet baseline and commit**

Run:

```bash
wc -l app/src/views/curate/ManageReReview.vue
```

If the current line count is lower than the existing `scripts/code-quality-file-size-baseline.tsv` entry, lower that entry to the current count.

Then commit:

```bash
git add app/src/api/re_review.ts app/src/api/re_review.spec.ts app/src/views/curate/ManageReReview.vue app/src/views/curate/ManageReReview.spec.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: route re-review admin calls through typed clients"
```

---

### Task 3: Extract Logs Request Cache Helper

**Files:**
- Create: `app/src/components/tables/logTableRequests.ts`
- Create: `app/src/components/tables/logTableRequests.spec.ts`

- [x] **Step 1: Add helper tests first**

Create `app/src/components/tables/logTableRequests.spec.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createLogTableRequestCache, logRequestKey } from './logTableRequests';

describe('logTableRequests', () => {
  beforeEach(() => {
    vi.useRealTimers();
  });

  it('builds a stable request key from table params', () => {
    expect(
      logRequestKey({
        sort: '-timestamp',
        filter: 'status==500',
        page_after: 10,
        page_size: 25,
      })
    ).toBe('sort=-timestamp&filter=status==500&page_after=10&page_size=25');
  });

  it('reuses a fresh cached response for duplicate requests', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    const fetcher = vi.fn().mockResolvedValue({ data: [], meta: [{ totalItems: 0 }] });

    const first = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );
    const second = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );

    expect(first?.fromCache).toBe(false);
    expect(second?.fromCache).toBe(true);
    expect(first?.response).toBe(second?.response);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('does not reuse stale cached responses after the duplicate window', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ data: [{ id: 1 }], meta: [{ totalItems: 1 }] })
      .mockResolvedValueOnce({ data: [{ id: 2 }], meta: [{ totalItems: 1 }] });

    await cache.load({ sort: '-id', filter: '', page_after: 0, page_size: 10 }, fetcher);
    vi.setSystemTime(new Date('2026-05-20T00:00:01Z'));
    const result = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );

    expect(result).not.toBeNull();
    expect(result!.response.data).toEqual([{ id: 2 }]);
    expect(result!.fromCache).toBe(false);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
});
```

- [x] **Step 2: Run helper tests and confirm failure**

Run:

```bash
cd app && npx vitest run src/components/tables/logTableRequests.spec.ts
```

Expected: fail because `logTableRequests.ts` does not exist.

- [x] **Step 3: Implement the helper**

Create `app/src/components/tables/logTableRequests.ts`:

```ts
import type { LogListResponse, ListLogsParams } from '@/api/logging';

export type LogTableRequestParams = Required<
  Pick<ListLogsParams, 'sort' | 'filter' | 'page_after' | 'page_size'>
>;

export function logRequestKey(params: LogTableRequestParams): string {
  return `sort=${params.sort}&filter=${params.filter}&page_after=${params.page_after}&page_size=${params.page_size}`;
}

export interface LogTableRequestResult {
  response: LogListResponse;
  fromCache: boolean;
}

export function createLogTableRequestCache(windowMs = 500) {
  let lastKey = '';
  let lastCallTime = 0;
  let lastResponse: LogListResponse | null = null;
  let inProgressKey: string | null = null;
  let inProgressPromise: Promise<LogListResponse> | null = null;

  return {
    async load(
      params: LogTableRequestParams,
      fetcher: () => Promise<LogListResponse>
    ): Promise<LogTableRequestResult | null> {
      const key = logRequestKey(params);
      const now = Date.now();

      if (lastKey === key && lastResponse && now - lastCallTime < windowMs) {
        return { response: lastResponse, fromCache: true };
      }

      if (inProgressKey === key && inProgressPromise) {
        return null;
      }

      lastKey = key;
      lastCallTime = now;
      inProgressKey = key;
      inProgressPromise = fetcher();

      try {
        lastResponse = await inProgressPromise;
        return { response: lastResponse, fromCache: false };
      } finally {
        inProgressKey = null;
        inProgressPromise = null;
      }
    },
  };
}
```

- [x] **Step 4: Verify helper tests pass**

Run:

```bash
cd app && npx vitest run src/components/tables/logTableRequests.spec.ts
```

Expected: pass.

- [x] **Step 5: Commit helper extraction**

Run:

```bash
git add app/src/components/tables/logTableRequests.ts app/src/components/tables/logTableRequests.spec.ts
git commit -m "refactor: extract log table request cache"
```

---

### Task 4: Migrate TablesLogs To Typed Clients

**Files:**
- Modify: `app/src/api/logging.spec.ts`
- Modify: `app/src/components/tables/TablesLogs.vue`
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [x] **Step 1: Strengthen logs API-client tests**

In `app/src/api/logging.spec.ts`, ensure these behaviors are covered:

```ts
it('listLogs forces format=json and preserves table params', async () => {
  let observedQuery: URLSearchParams | null = null;
  server.use(
    http.get('/api/logs/', ({ request }) => {
      observedQuery = new URL(request.url).searchParams;
      return HttpResponse.json({ data: [], meta: [{ totalItems: 0 }] });
    })
  );

  await listLogs({
    sort: '-timestamp',
    filter: 'status==500',
    page_after: 10,
    page_size: 25,
  });

  expect(observedQuery?.get('format')).toBe('json');
  expect(observedQuery?.get('sort')).toBe('-timestamp');
  expect(observedQuery?.get('filter')).toBe('status==500');
  expect(observedQuery?.get('page_after')).toBe('10');
  expect(observedQuery?.get('page_size')).toBe('25');
});

it('listLogsXlsx returns a Blob from the xlsx export path', async () => {
  server.use(
    http.get('/api/logs/', ({ request }) => {
      expect(new URL(request.url).searchParams.get('format')).toBe('xlsx');
      return new HttpResponse(new Blob(['xlsx-bytes']), {
        headers: {
          'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
      });
    })
  );

  const result = await listLogsXlsx({ page_after: 0, page_size: 'all' });

  expect(result).toBeInstanceOf(Blob);
});

it('deleteLogs sends older_than_days as a query param', async () => {
  let observedQuery: URLSearchParams | null = null;
  server.use(
    http.delete('/api/logs/', ({ request }) => {
      observedQuery = new URL(request.url).searchParams;
      return HttpResponse.json({ message: 'deleted', deleted_count: 12 });
    })
  );

  const result = await deleteLogs({ older_than_days: 30 });

  expect(observedQuery?.get('older_than_days')).toBe('30');
  expect(result.deleted_count).toBe(12);
});
```

- [x] **Step 2: Run logging API tests on unchanged production code**

Run:

```bash
cd app && npx vitest run src/api/logging.spec.ts
```

Expected: pass. If a duplicate test already exists, keep the existing equivalent and do not add redundant assertions.

- [x] **Step 3: Replace TablesLogs inline API calls**

In `app/src/components/tables/TablesLogs.vue`, import typed clients and cache helper:

```ts
import { listLogs, listLogsXlsx, deleteLogs as deleteLogsApi } from '@/api/logging';
import { listUsersByRole } from '@/api/user';
import { createLogTableRequestCache } from './logTableRequests';
```

Create module cache near the existing module-level cache variables:

```ts
const moduleLogRequestCache = createLogTableRequestCache();
```

Update `loadUserList()`:

```ts
async loadUserList() {
  try {
    const data = await listUsersByRole();
    this.user_options = data.map((item) => ({
      value: item.user_name,
      text: `${item.user_name} (${item.user_role})`,
    }));
  } catch (_e) {
    this.makeToast('Failed to load user list', 'Error', 'danger');
  }
},
```

Update `doLoadData()` to call the cache helper:

```ts
async doLoadData() {
  const params = {
    sort: this.sort,
    filter: this.filter_string,
    page_after: this.currentItemID,
    page_size: this.perPage,
  };

  this.isBusy = true;

  try {
    const result = await moduleLogRequestCache.load(params, () => listLogs(params));
    if (result) {
      this.applyApiResponse(result.response);
      if (!result.fromCache) {
        this.updateBrowserUrl();
      }
    }
    this.isBusy = false;
  } catch (error) {
    this.makeToast(`Error: ${error.message}`, 'Error loading logs', 'danger');
    this.isBusy = false;
  }
},
```

Update `requestExcel()`:

```ts
const blob = await listLogsXlsx({
  page_after: 0,
  page_size: 'all',
  filter: this.filter_string,
  sort: this.sort,
});

const fileURL = window.URL.createObjectURL(new Blob([blob]));
```

Update `deleteLogs()`:

```ts
const response = await deleteLogsApi({ older_than_days: olderThanDays });
const deletedCount = response.deleted_count || 0;
```

- [x] **Step 4: Remove obsolete raw URL state**

Run:

```bash
rg -n "VITE_API_URL|apiClient|moduleLastApi|moduleApiCallInProgress" app/src/components/tables/TablesLogs.vue
```

Expected: no matches for `VITE_API_URL`, `apiClient`, `moduleLastApi`, or `moduleApiCallInProgress`.

- [x] **Step 5: Verify TablesLogs migration**

Run:

```bash
cd app && npx vitest run src/api/logging.spec.ts src/api/user.spec.ts
cd app && npx vitest run src/components/tables/logTableRequests.spec.ts
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
cd app && npm run type-check
make code-quality-audit
```

Expected: all commands exit 0.

- [x] **Step 6: Ratchet baseline and commit**

Run:

```bash
wc -l app/src/components/tables/TablesLogs.vue
```

If the current line count is lower than the existing `scripts/code-quality-file-size-baseline.tsv` entry, lower that entry to the current count.

Then commit:

```bash
git add app/src/api/logging.spec.ts app/src/components/tables/TablesLogs.vue app/src/components/tables/logTableRequests.ts app/src/components/tables/logTableRequests.spec.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: route log table calls through typed clients"
```

---

### Task 5: Final Audit And Handoff

**Files:**
- Inspect all changed files.

- [x] **Step 1: Confirm no touched component uses raw request URL construction**

Run:

```bash
rg -n "VITE_API_URL|apiClient|getAxios|inject\\('axios'\\)|inject<Axios" app/src/views/curate/ManageReReview.vue app/src/components/tables/TablesLogs.vue
```

Expected: no matches, unless a remaining match is unrelated to request construction and documented in the handoff.

- [x] **Step 2: Run final deterministic checks**

Run:

```bash
git diff --check
cd app && npx vitest run src/api/re_review.spec.ts src/api/logging.spec.ts src/api/user.spec.ts src/api/list.spec.ts
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts src/components/tables/TablesLogs.spec.ts src/components/tables/logTableRequests.spec.ts
cd app && npm run type-check
make code-quality-audit
make pre-commit
```

Expected: all commands exit 0.

- [x] **Step 3: Run local CI parity if practical**

Run:

```bash
make ci-local
```

Expected: exits 0. If the environment blocks it, record the exact blocker and the last passing command.

- [x] **Step 4: Review code-quality risks**

Use `.agents/skills/sysndd-code-quality/SKILL.md` and check:

- `ManageReReview.vue` and `TablesLogs.vue` shrank or did not grow.
- No new oversized handwritten source files were created.
- API helpers use relative paths.
- Component tests still cover Bearer-header behavior through `apiClient`.
- No public route, UI, table-column, or backend endpoint behavior changed.

- [x] **Step 5: Final commit if any verification-only edits were made**

If verification required follow-up edits, commit them:

```bash
git status --short
git add <changed-files>
git commit -m "test: cover admin curation typed client boundaries"
```

Expected: working tree clean after the final commit.
