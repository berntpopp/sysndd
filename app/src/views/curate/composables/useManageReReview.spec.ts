// useManageReReview.spec.ts
/**
 * Controller-composable spec for ManageReReview (#346 WP9 decomposition).
 *
 * Exercises `useManageReReview` directly (no mounted host) against MSW so the
 * behaviour that used to live in ManageReReview.vue is pinned at the source:
 *   - all four mount loaders start concurrently (a slow loader never blocks
 *     the others),
 *   - each of the nine authed endpoints carries the apiClient Bearer header,
 *   - the Plumber scalar-array `meta.total` is unwrapped,
 *   - selection validation short-circuits before any network call,
 *   - the fallback success copy is used when the server omits batch summaries,
 *   - the assign/reassign/recalculate refresh side effects match (reassign
 *     refreshes only the table; assign + recalculate also refresh entities),
 *   - recalculation omits incomplete date-range / null status fields.
 *
 * Refresh side effects are asserted via MSW request counters rather than
 * spying internal method calls — the composable's actions call the loaders as
 * closures, so counting the real refresh requests is both faithful and stable.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';

// Router mock — `src/plugins/axios.ts` imports `@/router` at module load.
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/curate/manage-re-review' } },
  },
}));

// Attach the real axios plugin (401 interceptor) + apiClient (Bearer request
// interceptor) so the typed clients the composable calls hit MSW with the
// injected Authorization header.
import '@/plugins/axios';
import '@/api/client';
import { useManageReReview, type UseManageReReviewDeps } from './useManageReReview';

// VITE_API_URL normalisation — see ManageReReview.spec.ts for the rationale.
const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

interface Harness {
  ctrl: ReturnType<typeof useManageReReview>;
  onToast: ReturnType<typeof vi.fn>;
  announce: ReturnType<typeof vi.fn>;
}

function makeController(): Harness {
  const onToast = vi.fn();
  const announce = vi.fn();
  const deps: UseManageReReviewDeps = { onToast, announce };
  const ctrl = useManageReReview(deps);
  return { ctrl, onToast, announce };
}

function installDefaultHandlers(): void {
  server.use(
    http.get('*/api/user/list', () => HttpResponse.json([])),
    http.get('*/api/re_review/assignment_table', () => HttpResponse.json([])),
    http.get('*/api/re_review/entities/available', () =>
      HttpResponse.json({ data: [], meta: { total: 0 } })
    ),
    http.get('*/api/list/status', () => HttpResponse.json({ data: [] })),
    http.put('*/api/re_review/batch/assign', () => HttpResponse.json({ message: 'ok' })),
    http.delete('*/api/re_review/batch/unassign', () => HttpResponse.json({ message: 'ok' })),
    http.put('*/api/re_review/entities/assign', () =>
      HttpResponse.json({ entry: { batch_id: 1, entity_count: 1 } })
    ),
    http.put('*/api/re_review/batch/reassign', () => HttpResponse.json({ message: 'ok' })),
    http.put('*/api/re_review/batch/recalculate', () =>
      HttpResponse.json({ entry: { batch_id: 1, entity_count: 1 } })
    )
  );
}

beforeEach(() => {
  setActivePinia(createPinia());
  envBag.VITE_API_URL = '';
  installDefaultHandlers();
});

afterEach(() => {
  useAuth().logout();
  if (originalViteApiUrl === undefined) {
    delete envBag.VITE_API_URL;
  } else {
    envBag.VITE_API_URL = originalViteApiUrl;
  }
});

// ===========================================================================
// Concurrent mount loaders
// ===========================================================================
describe('useManageReReview — initialize()', () => {
  it('starts all four mount loaders concurrently (a hung loader does not block the rest)', async () => {
    primeAuth();
    let releaseUserList!: () => void;
    const userListGate = new Promise<void>((resolve) => {
      releaseUserList = resolve;
    });

    let userListCalled = false;
    let tableCalled = false;
    let entitiesCalled = false;
    let statusCalled = false;

    server.use(
      http.get('*/api/user/list', async () => {
        userListCalled = true;
        await userListGate; // hang until released
        return HttpResponse.json([{ user_id: 1, user_name: 'a', user_role: 'Curator' }]);
      }),
      http.get('*/api/re_review/assignment_table', () => {
        tableCalled = true;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/entities/available', () => {
        entitiesCalled = true;
        return HttpResponse.json({ data: [], meta: { total: 0 } });
      }),
      http.get('*/api/list/status', () => {
        statusCalled = true;
        return HttpResponse.json({ data: [{ category_id: 5, category: 'Definitive' }] });
      })
    );

    const { ctrl } = makeController();
    ctrl.initialize();
    await flushPromises();

    // The three fast loaders resolved even though loadUserList is still pending.
    expect(userListCalled).toBe(true);
    expect(tableCalled).toBe(true);
    expect(entitiesCalled).toBe(true);
    expect(statusCalled).toBe(true);
    expect(ctrl.status_options.value).toEqual([{ value: 5, text: 'Definitive' }]);
    expect(ctrl.loadingReReviewManagment.value).toBe(false);
    // loadUserList never completed, so its state is untouched.
    expect(ctrl.user_options.value).toEqual([]);

    releaseUserList();
    await flushPromises();
    expect(ctrl.user_options.value).toEqual([{ value: 1, text: 'a', role: 'Curator' }]);
  });
});

// ===========================================================================
// Nine authed endpoints — Bearer header + params
// ===========================================================================
describe('useManageReReview — apiClient Bearer header on every authed endpoint', () => {
  it('1/9 GET /api/user/list?roles=Curator,Reviewer carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/user/list', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        expect(new URL(request.url).searchParams.get('roles')).toBe('Curator,Reviewer');
        return HttpResponse.json([{ user_id: 3, user_name: 'alice', user_role: 'Curator' }]);
      })
    );
    const { ctrl } = makeController();
    await ctrl.loadUserList();
    expect(sawCall).toBe(true);
  });

  it('2/9 GET /api/re_review/assignment_table carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/re_review/assignment_table', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        return HttpResponse.json([]);
      })
    );
    const { ctrl } = makeController();
    await ctrl.loadReReviewTableData();
    expect(sawCall).toBe(true);
  });

  it('3/9 PUT /api/re_review/batch/assign carries Bearer + user_id', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/batch/assign', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        expect(new URL(request.url).searchParams.get('user_id')).toBe('7');
        return HttpResponse.json({ message: 'ok' });
      })
    );
    const { ctrl } = makeController();
    ctrl.user_id_assignment.value = 7;
    await ctrl.handleNewBatchAssignment();
    expect(sawCall).toBe(true);
  });

  it('4/9 DELETE /api/re_review/batch/unassign carries Bearer + re_review_batch', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.delete('*/api/re_review/batch/unassign', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        expect(new URL(request.url).searchParams.get('re_review_batch')).toBe('42');
        return HttpResponse.json({ message: 'ok' });
      })
    );
    const { ctrl } = makeController();
    await ctrl.handleBatchUnAssignment(42);
    expect(sawCall).toBe(true);
  });

  it('5/9 GET /api/re_review/entities/available carries Bearer and loads total', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/re_review/entities/available', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const url = new URL(request.url);
        expect(url.searchParams.get('page')).toBe('1');
        expect(url.searchParams.get('page_size')).toBe('100');
        return HttpResponse.json({
          data: [{ entity_id: 11, gene_symbol: 'GENE', disease_ontology_name: 'Disease' }],
          meta: { total: 312 },
        });
      })
    );
    const { ctrl } = makeController();
    await ctrl.loadAvailableEntities();
    expect(sawCall).toBe(true);
    expect(ctrl.availableEntityTotal.value).toBe(312);
  });

  it('6/9 PUT /api/re_review/entities/assign carries Bearer + body', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/entities/assign', async ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const body = (await request.json()) as {
          entity_ids: number[];
          user_id: number;
          batch_name: string | null;
        };
        expect(body.entity_ids).toEqual([11, 22]);
        expect(body.user_id).toBe(3);
        expect(body.batch_name).toBe('manual-batch');
        return HttpResponse.json({ entry: { batch_id: 77, entity_count: 2 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.selectedEntityIds.value = [11, 22];
    ctrl.entityAssignUserId.value = 3;
    ctrl.entityAssignBatchName.value = 'manual-batch';
    await ctrl.handleEntityAssignment();
    expect(sawCall).toBe(true);
  });

  it('7/9 PUT /api/re_review/batch/reassign carries Bearer + params', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/batch/reassign', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const url = new URL(request.url);
        expect(url.searchParams.get('re_review_batch')).toBe('42');
        expect(url.searchParams.get('user_id')).toBe('9');
        return HttpResponse.json({ message: 'ok' });
      })
    );
    const { ctrl } = makeController();
    ctrl.reassignBatchId.value = 42;
    ctrl.reassignNewUserId.value = 9;
    await ctrl.handleBatchReassignment();
    expect(sawCall).toBe(true);
  });

  it('8/9 PUT /api/re_review/batch/recalculate carries Bearer + body', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/batch/recalculate', async ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const body = (await request.json()) as { re_review_batch: number; batch_size: number };
        expect(body.re_review_batch).toBe(42);
        expect(body.batch_size).toBe(20);
        return HttpResponse.json({ entry: { batch_id: 42, entity_count: 20 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.recalculateBatchId.value = 42;
    ctrl.recalculateCriteria.value = {
      date_range: { start: null, end: null },
      gene_list: [],
      status_filter: null,
      batch_size: 20,
    };
    await ctrl.handleBatchRecalculation();
    expect(sawCall).toBe(true);
  });

  it('9/9 GET /api/list/status carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/list/status', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        return HttpResponse.json({
          data: [
            { category_id: 1, category: 'Definitive' },
            { category_id: 2, category: 'Moderate' },
          ],
        });
      })
    );
    const { ctrl } = makeController();
    await ctrl.loadStatusOptions();
    expect(sawCall).toBe(true);
    expect(ctrl.status_options.value).toEqual([
      { value: 1, text: 'Definitive' },
      { value: 2, text: 'Moderate' },
    ]);
  });
});

// ===========================================================================
// Loader normalisation
// ===========================================================================
describe('useManageReReview — loader normalisation', () => {
  it('loadUserList maps Curator/Reviewer rows', async () => {
    primeAuth('users-token');
    server.use(
      http.get('*/api/user/list', () =>
        HttpResponse.json([
          { user_id: 7, user_name: 'curator_a', user_role: 'Curator' },
          { user_id: 8, user_name: 'reviewer_b', user_role: 'Reviewer' },
        ])
      )
    );
    const { ctrl } = makeController();
    await ctrl.loadUserList();
    expect(ctrl.user_options.value).toEqual([
      { value: 7, text: 'curator_a', role: 'Curator' },
      { value: 8, text: 'reviewer_b', role: 'Reviewer' },
    ]);
  });

  it('loadAvailableEntities normalizes entity rows and scalar total (q passthrough)', async () => {
    primeAuth('entities-token');
    server.use(
      http.get('*/api/re_review/entities/available', ({ request }) => {
        expect(new URL(request.url).searchParams.get('q')).toBe('ARID');
        return HttpResponse.json({ data: [{ entity_id: 11, symbol: 'ARID1B' }], meta: { total: 1 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.manualEntityFilter.value = 'ARID';
    await ctrl.loadAvailableEntities();
    expect(ctrl.availableEntities.value).toEqual([{ entity_id: 11, symbol: 'ARID1B' }]);
    expect(ctrl.availableEntityTotal.value).toBe(1);
  });

  it('loadAvailableEntities unwraps Plumber scalar-array total values', async () => {
    primeAuth('entities-array-total-token');
    server.use(
      http.get('*/api/re_review/entities/available', () =>
        HttpResponse.json({ data: [{ entity_id: 22, symbol: 'SCN2A' }], meta: { total: [1] } })
      )
    );
    const { ctrl } = makeController();
    await ctrl.loadAvailableEntities();
    expect(ctrl.availableEntities.value).toEqual([{ entity_id: 22, symbol: 'SCN2A' }]);
    expect(ctrl.availableEntityTotal.value).toBe(1);
  });
});

// ===========================================================================
// Entity assignment — validation, fallback copy, refresh side effects
// ===========================================================================
describe('useManageReReview — handleEntityAssignment', () => {
  it('validation avoids the API call for missing inputs', async () => {
    primeAuth('validation-token');
    let sawAssignCall = false;
    server.use(
      http.put('*/api/re_review/entities/assign', () => {
        sawAssignCall = true;
        return HttpResponse.json({});
      })
    );
    const { ctrl, onToast } = makeController();
    ctrl.selectedEntityIds.value = [];
    ctrl.entityAssignUserId.value = 3;
    await ctrl.handleEntityAssignment();
    expect(sawAssignCall).toBe(false);
    expect(onToast).toHaveBeenCalledWith(
      'Please select at least one entity',
      'Validation',
      'warning'
    );
  });

  it('preserves null batch name and refreshes table + entities on success', async () => {
    primeAuth('assign-token');
    let receivedBody: unknown = null;
    let tableCalls = 0;
    let entityCalls = 0;
    server.use(
      http.put('*/api/re_review/entities/assign', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ entry: { batch_id: 77, entity_count: 2 } });
      }),
      http.get('*/api/re_review/assignment_table', () => {
        tableCalls += 1;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/entities/available', () => {
        entityCalls += 1;
        return HttpResponse.json({ data: [], meta: { total: 0 } });
      })
    );
    const { ctrl, onToast, announce } = makeController();
    ctrl.selectedEntityIds.value = [11, 22];
    ctrl.entityAssignUserId.value = 3;
    ctrl.entityAssignBatchName.value = '';
    await ctrl.handleEntityAssignment();
    await flushPromises();

    expect(receivedBody).toEqual({ entity_ids: [11, 22], user_id: 3, batch_name: null });
    expect(onToast).toHaveBeenCalledWith('Created batch 77 with 2 entities', 'Success', 'success');
    expect(announce).toHaveBeenCalledWith('Created batch 77 with 2 entities');
    expect(ctrl.selectedEntityIds.value).toEqual([]);
    expect(ctrl.entityAssignUserId.value).toBeNull();
    expect(ctrl.entityAssignBatchName.value).toBe('');
    expect(tableCalls).toBe(1);
    expect(entityCalls).toBe(1);
  });

  it('uses fallback copy when the server omits batch summary fields', async () => {
    primeAuth('assign-empty-entry-token');
    server.use(
      http.put('*/api/re_review/entities/assign', () => HttpResponse.json({ entry: {} }))
    );
    const { ctrl, onToast, announce } = makeController();
    ctrl.selectedEntityIds.value = [11];
    ctrl.entityAssignUserId.value = 3;
    await ctrl.handleEntityAssignment();
    await flushPromises();
    expect(onToast).toHaveBeenCalledWith(
      'Created assignment batch, but the batch summary was unavailable',
      'Success',
      'success'
    );
    expect(announce).toHaveBeenCalledWith(
      'Created assignment batch, but the batch summary was unavailable'
    );
  });
});

// ===========================================================================
// Reassignment + recalculation — refresh side effects, fallback, field omission
// ===========================================================================
describe('useManageReReview — reassign & recalculate', () => {
  it('handleBatchReassignment closes the modal and refreshes only the table', async () => {
    primeAuth('reassign-token');
    let tableCalls = 0;
    let entityCalls = 0;
    server.use(
      http.put('*/api/re_review/batch/reassign', () => HttpResponse.json({ status: 200 })),
      http.get('*/api/re_review/assignment_table', () => {
        tableCalls += 1;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/entities/available', () => {
        entityCalls += 1;
        return HttpResponse.json({ data: [], meta: { total: 0 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.reassignModalShow.value = true;
    ctrl.reassignBatchId.value = 42;
    ctrl.reassignNewUserId.value = 9;
    await ctrl.handleBatchReassignment();
    await flushPromises();
    expect(ctrl.reassignModalShow.value).toBe(false);
    expect(tableCalls).toBe(1);
    expect(entityCalls).toBe(0);
  });

  it('handleBatchRecalculation closes the modal and refreshes table + entities', async () => {
    primeAuth('recalculate-token');
    let tableCalls = 0;
    let entityCalls = 0;
    server.use(
      http.put('*/api/re_review/batch/recalculate', () =>
        HttpResponse.json({ entry: { batch_id: 42, entity_count: 20 } })
      ),
      http.get('*/api/re_review/assignment_table', () => {
        tableCalls += 1;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/entities/available', () => {
        entityCalls += 1;
        return HttpResponse.json({ data: [], meta: { total: 0 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.recalculateModalShow.value = true;
    ctrl.recalculateBatchId.value = 42;
    ctrl.recalculateCriteria.value = {
      date_range: { start: null, end: null },
      gene_list: [],
      status_filter: null,
      batch_size: 20,
    };
    await ctrl.handleBatchRecalculation();
    await flushPromises();
    expect(ctrl.recalculateModalShow.value).toBe(false);
    expect(tableCalls).toBe(1);
    expect(entityCalls).toBe(1);
  });

  it('handleBatchRecalculation uses fallback copy when the server omits batch summary fields', async () => {
    primeAuth('recalculate-empty-entry-token');
    server.use(
      http.put('*/api/re_review/batch/recalculate', () => HttpResponse.json({ entry: {} }))
    );
    const { ctrl, onToast, announce } = makeController();
    ctrl.recalculateModalShow.value = true;
    ctrl.recalculateBatchId.value = 42;
    await ctrl.handleBatchRecalculation();
    await flushPromises();
    expect(onToast).toHaveBeenCalledWith(
      'Batch recalculated, but the batch summary was unavailable',
      'Success',
      'success'
    );
    expect(announce).toHaveBeenCalledWith('Batch recalculated, but the batch summary was unavailable');
    expect(ctrl.recalculateModalShow.value).toBe(false);
  });

  it('recalculation omits incomplete date-range and null status fields', async () => {
    primeAuth('recalculate-omit-token');
    let receivedBody: Record<string, unknown> | null = null;
    server.use(
      http.put('*/api/re_review/batch/recalculate', async ({ request }) => {
        receivedBody = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ entry: { batch_id: 42, entity_count: 5 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.recalculateBatchId.value = 42;
    ctrl.recalculateCriteria.value = {
      date_range: { start: '2026-01-01', end: null }, // incomplete → dropped
      gene_list: [],
      status_filter: null, // null → dropped
      batch_size: 15,
    };
    await ctrl.handleBatchRecalculation();
    await flushPromises();

    expect(receivedBody).toEqual({ re_review_batch: 42, batch_size: 15 });
    expect(receivedBody).not.toHaveProperty('date_range');
    expect(receivedBody).not.toHaveProperty('status_filter');
  });

  it('recalculation includes complete date-range and non-null status fields', async () => {
    primeAuth('recalculate-include-token');
    let receivedBody: Record<string, unknown> | null = null;
    server.use(
      http.put('*/api/re_review/batch/recalculate', async ({ request }) => {
        receivedBody = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ entry: { batch_id: 42, entity_count: 5 } });
      })
    );
    const { ctrl } = makeController();
    ctrl.recalculateBatchId.value = 42;
    ctrl.recalculateCriteria.value = {
      date_range: { start: '2026-01-01', end: '2026-02-01' },
      gene_list: [],
      status_filter: 3,
      batch_size: 30,
    };
    await ctrl.handleBatchRecalculation();
    await flushPromises();

    expect(receivedBody).toEqual({
      re_review_batch: 42,
      batch_size: 30,
      date_range: { start: '2026-01-01', end: '2026-02-01' },
      status_filter: 3,
    });
  });
});
