// ManageReReview.spec.ts
/**
 * v11.0 closeout F2d — Bearer-header migration spec for ManageReReview.vue.
 *
 * Scope: `.plans/v11.0/closeout.md` §3 F2d. The component has nine authed
 * endpoints today (pre-migration: inline `Authorization: Bearer ${
 * localStorage.getItem('token')}` headers at lines 767, 789, 825, 849, 889,
 * 931, 979, 1027, 1056). This spec authors a functional test for each one
 * using the F1-delivered helpers:
 *   - `primeAuth()` seeds `useAuth` with a deterministic session.
 *   - MSW intercepts the request and `expectBearerHeader(request, token)`
 *     asserts the apiClient interceptor injected the correct header from
 *     `useAuth().token.value` on every call.
 *
 * This is the largest test-authoring task in the closeout and the only F2
 * worktree that writes a genuinely new spec before migrating. The 9 tests
 * are intentionally narrow — each one exercises exactly the network call it
 * names so a future regression (a developer re-introducing a raw axios call
 * that skips the interceptor) flips exactly one red test.
 *
 * Scope locks:
 *   - No new handlers in `src/test-utils/mocks/handlers.ts`. Each test
 *     installs a per-test override via `server.use(...)`. Resetting between
 *     tests is handled by `vitest.setup.ts` (`server.resetHandlers()` in
 *     the global `afterEach`).
 *   - No `vi.mock('axios')` — the real axios plugin + apiClient interceptor
 *     must fire so we actually prove the Bearer header propagates.
 *   - `this.axios` is no longer injected; the post-migration component calls
 *     `apiClient.get(...)` directly, which goes through the same shared
 *     axios singleton and therefore still hits MSW.
 *
 * Endpoint catalog (matches the 9 migrated call sites):
 *   1. GET    /api/user/list?roles=Curator,Reviewer   (loadUserList)
 *   2. GET    /api/re_review/assignment_table         (loadReReviewTableData)
 *   3. PUT    /api/re_review/batch/assign             (handleNewBatchAssignment)
 *   4. DELETE /api/re_review/batch/unassign           (handleBatchUnAssignment)
 *   5. POST   /api/re_review/batch/preview            (loadAvailableEntities)
 *   6. PUT    /api/re_review/entities/assign          (handleEntityAssignment)
 *   7. PUT    /api/re_review/batch/reassign           (handleBatchReassignment)
 *   8. PUT    /api/re_review/batch/recalculate        (handleBatchRecalculation)
 *   9. GET    /api/list/status                        (loadStatusOptions)
 */

import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';

// ---------------------------------------------------------------------------
// Composable mocks — `useToast`/`useAriaLive` both require a BApp provider
// we don't mount. `vi.mock` is hoisted above the imports below.
// ---------------------------------------------------------------------------
vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
  useAriaLive: () => ({
    message: { value: '' },
    politeness: { value: 'polite' },
    announce: vi.fn(),
  }),
}));

// ---------------------------------------------------------------------------
// Router mock — `src/plugins/axios.ts` does `import router from '@/router'`
// at module load. Hoisted via `vi.mock` BEFORE the view import so the axios
// plugin sees our stub instead of the real router.
// ---------------------------------------------------------------------------
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/curate/manage-re-review' } },
  },
}));

// Importing the real axios plugin attaches its 401 response interceptor.
// Importing apiClient also attaches the request interceptor (Bearer header
// injection from `useAuth().token.value`).  The view-under-test must resolve
// to the same shared axios singleton these two plugins target, which it does
// post-migration via `import { apiClient } from '@/api/client'`.
import '@/plugins/axios';
import '@/api/client';
import ManageReReview from '@/views/curate/ManageReReview.vue';

// ---------------------------------------------------------------------------
// VITE_API_URL normalisation
// ---------------------------------------------------------------------------
// The component builds URLs as `${import.meta.env.VITE_API_URL}/api/...`.
// Vitest loads no `.env.test`, so the var is undefined and the template
// literal collapses to `undefined/api/...` — which MSW can't match against
// a path-only handler pattern. Normalise by writing an empty string directly
// onto `import.meta.env`; `vi.stubEnv` doesn't reliably propagate to
// `import.meta.env` under Vitest 4 for Vite env vars.
const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

// ---------------------------------------------------------------------------
// Mount helper — stubs Bootstrap-Vue-Next and child components to minimal
// templates.  The spec drives behaviour via component methods rather than
// DOM events, so slot fidelity is intentionally low.
// ---------------------------------------------------------------------------
const mountManageReReview = async (): Promise<VueWrapper> => {
  const wrapper = mount(ManageReReview, {
    global: {
      directives: {
        'b-tooltip': {},
        'b-toggle': {},
      },
      stubs: {
        // Bootstrap-Vue-Next structural stubs
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: {
          template: '<div><slot name="header" /><slot /></div>',
        },
        BCollapse: {
          props: ['modelValue'],
          template: '<div><slot /></div>',
        },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BLink: { template: '<a><slot /></a>' },
        BSpinner: { template: '<div role="status" />' },
        BTable: {
          name: 'BTable',
          props: ['items', 'fields'],
          template: '<table><tbody><tr /></tbody></table>',
        },
        BPagination: { template: '<nav />' },
        BFormInput: {
          props: ['modelValue', 'type', 'placeholder', 'id', 'debounce', 'size', 'min', 'max'],
          template: '<input />',
        },
        BFormSelect: {
          props: ['modelValue', 'options', 'size', 'id', 'ariaLabel'],
          template: '<select><slot /></select>',
        },
        BFormSelectOption: {
          props: ['value'],
          template: '<option><slot /></option>',
        },
        BFormCheckbox: {
          props: ['modelValue', 'switch', 'size', 'id'],
          template: '<input type="checkbox" />',
        },
        BFormGroup: {
          template: '<div><slot name="label" /><slot /></div>',
        },
        BForm: { template: '<form><slot /></form>' },
        BOverlay: { template: '<div><slot /></div>' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BPopover: { template: '' },
        BModal: {
          name: 'BModal',
          props: ['modelValue', 'id', 'title'],
          template: '<div><slot /></div>',
          methods: {
            show() {},
            hide() {},
          },
        },
        // Child components stubbed — not under test.
        BatchCriteriaForm: { template: '<div />' },
        AriaLiveRegion: { template: '<div />' },
        IconLegend: { template: '<div />' },
      },
    },
  });

  // Let `mounted()` run its four parallel loaders before the spec proceeds.
  await flushPromises();
  return wrapper;
};

// ---------------------------------------------------------------------------
// View-model shape for TypeScript access via `wrapper.vm`.  `ManageReReview
// .vue` is Options API, so vue-tsc can't infer the instance shape.  We
// declare only the subset the tests touch.
// ---------------------------------------------------------------------------
interface ManageReReviewVm {
  user_id_assignment: number;
  selectedEntityIds: number[];
  entityAssignUserId: number | null;
  entityAssignBatchName: string;
  reassignBatchId: number | null;
  reassignNewUserId: number | null;
  recalculateBatchId: number | null;
  recalculateCriteria: {
    date_range: { start: string | null; end: string | null };
    gene_list: string[];
    status_filter: number | null;
    batch_size: number;
  };
  handleNewBatchAssignment: () => Promise<void>;
  handleBatchUnAssignment: (batchId: number) => Promise<void>;
  handleEntityAssignment: () => Promise<void>;
  handleBatchReassignment: () => Promise<void>;
  handleBatchRecalculation: () => Promise<void>;
}

const vm = (wrapper: VueWrapper): ManageReReviewVm =>
  wrapper.vm as unknown as ManageReReviewVm;

// ---------------------------------------------------------------------------
// A catch-all handler suite that answers every endpoint the view hits during
// `mounted()`.  Individual tests override the specific endpoint they assert
// on via `server.use(...)` BEFORE mounting.  Resetting between tests is
// handled globally in `vitest.setup.ts`.
//
// Responses are minimal shape: just enough to keep `mounted()` happy.  The
// per-test override installed first wins, so the catch-all is only hit by
// endpoints the test doesn't explicitly care about.
// ---------------------------------------------------------------------------
function installDefaultHandlers(): void {
  server.use(
    http.get('*/api/user/list', () => HttpResponse.json([])),
    http.get('*/api/re_review/assignment_table', () => HttpResponse.json([])),
    http.post('*/api/re_review/batch/preview', () =>
      HttpResponse.json({ data: [] }),
    ),
    http.get('*/api/list/status', () => HttpResponse.json([])),
  );
}

// ---------------------------------------------------------------------------
// Per-file setup: normalise VITE_API_URL, seed a Pinia instance, and
// pre-install the default handlers for the mounted() loaders.  Auth is
// seeded in each test via `primeAuth()` so the token value is explicit in
// the test body.
// ---------------------------------------------------------------------------
beforeEach(() => {
  setActivePinia(createPinia());
  envBag.VITE_API_URL = '';
  installDefaultHandlers();
});

afterEach(() => {
  // Clear the useAuth singleton between tests.  `vitest.setup.ts` clears
  // localStorage globally but does not reset the module-level refs inside
  // useAuth; `logout()` clears both layers.
  useAuth().logout();
  if (originalViteApiUrl === undefined) {
    delete envBag.VITE_API_URL;
  } else {
    envBag.VITE_API_URL = originalViteApiUrl;
  }
});

// ===========================================================================
// The 9 Bearer-header assertions — one per migrated call site.
// ===========================================================================
describe('ManageReReview.vue — apiClient Bearer header on every authed endpoint', () => {
  // -------------------------------------------------------------------------
  // 1/9 — GET /api/user/list?roles=Curator,Reviewer (loadUserList)
  //       Fires automatically from mounted() → loadUserList().
  // -------------------------------------------------------------------------
  it('1/9 GET /api/user/list?roles=Curator,Reviewer carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/user/list', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const url = new URL(request.url);
        expect(url.searchParams.get('roles')).toBe('Curator,Reviewer');
        return HttpResponse.json([
          { user_id: 3, user_name: 'alice', user_role: 'Curator' },
        ]);
      }),
    );

    await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 2/9 — GET /api/re_review/assignment_table (loadReReviewTableData)
  //       Fires automatically from mounted() → loadReReviewTableData().
  // -------------------------------------------------------------------------
  it('2/9 GET /api/re_review/assignment_table carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/re_review/assignment_table', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        return HttpResponse.json([]);
      }),
    );

    await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 3/9 — PUT /api/re_review/batch/assign?user_id=... (handleNewBatchAssignment)
  //       Driven by calling the method directly after mount.
  // -------------------------------------------------------------------------
  it('3/9 PUT /api/re_review/batch/assign carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/batch/assign', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const url = new URL(request.url);
        expect(url.searchParams.get('user_id')).toBe('7');
        return HttpResponse.json({ message: 'ok' });
      }),
    );

    const wrapper = await mountManageReReview();
    vm(wrapper).user_id_assignment = 7;
    await vm(wrapper).handleNewBatchAssignment();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 4/9 — DELETE /api/re_review/batch/unassign?re_review_batch=... (handleBatchUnAssignment)
  // -------------------------------------------------------------------------
  it('4/9 DELETE /api/re_review/batch/unassign carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.delete('*/api/re_review/batch/unassign', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const url = new URL(request.url);
        expect(url.searchParams.get('re_review_batch')).toBe('42');
        return HttpResponse.json({ message: 'ok' });
      }),
    );

    const wrapper = await mountManageReReview();
    await vm(wrapper).handleBatchUnAssignment(42);
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 5/9 — POST /api/re_review/batch/preview (loadAvailableEntities)
  //       Fires automatically from mounted() → loadAvailableEntities().
  // -------------------------------------------------------------------------
  it('5/9 POST /api/re_review/batch/preview carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.post('*/api/re_review/batch/preview', async ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const body = (await request.json()) as { batch_size: number };
        expect(body.batch_size).toBe(100);
        return HttpResponse.json({ data: [] });
      }),
    );

    await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 6/9 — PUT /api/re_review/entities/assign (handleEntityAssignment)
  // -------------------------------------------------------------------------
  it('6/9 PUT /api/re_review/entities/assign carries Bearer', async () => {
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
        return HttpResponse.json({
          entry: { batch_id: 77, entity_count: 2 },
        });
      }),
    );

    const wrapper = await mountManageReReview();
    vm(wrapper).selectedEntityIds = [11, 22];
    vm(wrapper).entityAssignUserId = 3;
    vm(wrapper).entityAssignBatchName = 'manual-batch';
    await vm(wrapper).handleEntityAssignment();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 7/9 — PUT /api/re_review/batch/reassign?re_review_batch=..&user_id=.. (handleBatchReassignment)
  // -------------------------------------------------------------------------
  it('7/9 PUT /api/re_review/batch/reassign carries Bearer', async () => {
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
      }),
    );

    const wrapper = await mountManageReReview();
    vm(wrapper).reassignBatchId = 42;
    vm(wrapper).reassignNewUserId = 9;
    await vm(wrapper).handleBatchReassignment();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 8/9 — PUT /api/re_review/batch/recalculate (handleBatchRecalculation)
  // -------------------------------------------------------------------------
  it('8/9 PUT /api/re_review/batch/recalculate carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.put('*/api/re_review/batch/recalculate', async ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        const body = (await request.json()) as {
          re_review_batch: number;
          batch_size: number;
        };
        expect(body.re_review_batch).toBe(42);
        expect(body.batch_size).toBe(20);
        return HttpResponse.json({
          entry: { batch_id: 42, entity_count: 20 },
        });
      }),
    );

    const wrapper = await mountManageReReview();
    vm(wrapper).recalculateBatchId = 42;
    vm(wrapper).recalculateCriteria = {
      date_range: { start: null, end: null },
      gene_list: [],
      status_filter: null,
      batch_size: 20,
    };
    await vm(wrapper).handleBatchRecalculation();
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 9/9 — GET /api/list/status (loadStatusOptions)
  //       Fires automatically from mounted() → loadStatusOptions().
  // -------------------------------------------------------------------------
  it('9/9 GET /api/list/status carries Bearer', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/list/status', ({ request }) => {
        expectBearerHeader(request, token);
        sawCall = true;
        return HttpResponse.json([
          { category_id: 1, category: 'Definitive' },
          { category_id: 2, category: 'Moderate' },
        ]);
      }),
    );

    await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
  });
});
