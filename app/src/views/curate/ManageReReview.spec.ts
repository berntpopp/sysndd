// ManageReReview.spec.ts
/**
 * v11.0 closeout F2d — Bearer-header migration spec for ManageReReview.vue.
 *
 * Scope: `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2d. The component has nine authed
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
 *   5. GET    /api/re_review/entities/available       (loadAvailableEntities)
 *   6. PUT    /api/re_review/entities/assign          (handleEntityAssignment)
 *   7. PUT    /api/re_review/batch/reassign           (handleBatchReassignment)
 *   8. PUT    /api/re_review/batch/recalculate        (handleBatchRecalculation)
 *   9. GET    /api/list/status                        (loadStatusOptions)
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
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
        BButtonGroup: { template: '<div><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BTooltip: { template: '' },
        BLink: { template: '<a><slot /></a>' },
        BSpinner: { template: '<div role="status" />' },
        BTable: {
          name: 'BTable',
          props: ['items', 'fields', 'tbodyTrClass', 'busy'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id" :class="tbodyTrClass ? tbodyTrClass(item) : undefined"><td><slot name="cell(selected)" :item="item" /></td><td><slot name="cell(entity_id)" :item="item" /></td><td>{{ item.gene_symbol }}</td><td><slot name="cell(disease_ontology_name)" :item="item" /></td><td>{{ item.review_date }}</td><td>{{ item.status_name }}</td></tr></tbody></table>',
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
        BAlert: {
          props: ['variant', 'show'],
          template: '<div :data-variant="variant"><slot /></div>',
        },
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
  user_options: Array<{ value: number; text: string; role: string }>;
  activeBatchMode: 'criteria' | 'manual' | null;
  user_id_assignment: number;
  availableEntities: Array<Record<string, unknown>>;
  availableEntityTotal: number;
  manualEntityFilter: string | null;
  selectedEntityIds: number[];
  entityAssignUserId: number | null;
  entityAssignBatchName: string;
  previewBoundaryGene: string | null;
  previewGeneCount: number;
  previewEntityCount: number;
  reassignModalShow: boolean;
  reassignBatchId: number | null;
  reassignNewUserId: number | null;
  recalculateModalShow: boolean;
  recalculateBatchId: number | null;
  recalculateCriteria: {
    date_range: { start: string | null; end: string | null };
    gene_list: string[];
    status_filter: number | null;
    batch_size: number;
  };
  status_options: Array<{ value: number; text: string }>;
  loadUserList: () => Promise<void>;
  loadReReviewTableData: () => Promise<void>;
  loadAvailableEntities: () => Promise<void>;
  loadStatusOptions: () => Promise<void>;
  handleNewBatchAssignment: () => Promise<void>;
  handleBatchUnAssignment: (batchId: number) => Promise<void>;
  handleEntityAssignment: () => Promise<void>;
  handleBatchReassignment: () => Promise<void>;
  handleBatchRecalculation: () => Promise<void>;
  makeToast: ReturnType<typeof vi.fn>;
  announce: ReturnType<typeof vi.fn>;
}

const vm = (wrapper: VueWrapper): ManageReReviewVm => wrapper.vm as unknown as ManageReReviewVm;

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
    http.get('*/api/re_review/entities/available', () =>
      HttpResponse.json({ data: [], meta: { total: 0 } })
    ),
    http.get('*/api/list/status', () => HttpResponse.json({ data: [] }))
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
        return HttpResponse.json([{ user_id: 3, user_name: 'alice', user_role: 'Curator' }]);
      })
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
      })
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
      })
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
      })
    );

    const wrapper = await mountManageReReview();
    await vm(wrapper).handleBatchUnAssignment(42);
    await flushPromises();

    expect(sawCall).toBe(true);
  });

  // -------------------------------------------------------------------------
  // 5/9 — GET /api/re_review/entities/available (loadAvailableEntities)
  //       Fires automatically from mounted() → loadAvailableEntities().
  // -------------------------------------------------------------------------
  it('5/9 GET /api/re_review/entities/available carries Bearer and loads total', async () => {
    const { token } = primeAuth();
    let sawCall = false;
    server.use(
      http.get('*/api/re_review/entities/available', async ({ request }) => {
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

    const wrapper = await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
    expect((wrapper.vm as unknown as { availableEntityTotal: number }).availableEntityTotal).toBe(
      312
    );
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
      })
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
      })
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
      })
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
        return HttpResponse.json({
          data: [
            { category_id: 1, category: 'Definitive' },
            { category_id: 2, category: 'Moderate' },
          ],
        });
      })
    );

    const wrapper = await mountManageReReview();
    await flushPromises();

    expect(sawCall).toBe(true);
    expect(vm(wrapper).status_options).toEqual([
      { value: 1, text: 'Definitive' },
      { value: 2, text: 'Moderate' },
    ]);
  });
});

describe('ManageReReview.vue — typed client migration behavior', () => {
  it('renders manual entity assignment state from loaded entities', async () => {
    primeAuth('re-review-manual-panel-token');

    server.use(
      http.get('*/api/re_review/entities/available', ({ request }) => {
        const query = new URL(request.url).searchParams;
        expect(query.get('page')).toBe('1');
        expect(query.get('page_size')).toBe('100');
        return HttpResponse.json({
          data: [
            {
              entity_id: 11,
              gene_symbol: 'ARID1B',
              disease_ontology_name: 'ARID1B disorder',
              review_date: '2026-01-01',
              status_name: 'Definitive',
            },
          ],
          meta: { total: 4 },
        });
      })
    );

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    component.activeBatchMode = 'manual';
    component.selectedEntityIds = [11];
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Manual pick');
    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('ARID1B disorder');
    expect(wrapper.text()).toContain('Showing 1 of 4 available entities.');
    expect(wrapper.text()).toContain('Assign 1 selected');
  });

  it('renders the manual assignment boundary-gene alert in manual mode', async () => {
    primeAuth('re-review-boundary-panel-token');

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    component.activeBatchMode = 'manual';
    component.previewBoundaryGene = 'HGNC:4585';
    component.previewGeneCount = 2;
    component.previewEntityCount = 6;
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('HGNC:4585');
    expect(wrapper.text()).toContain('6 entities');
  });

  it('loadUserList maps Curator/Reviewer rows from the typed user client', async () => {
    primeAuth('re-review-users-token');
    let observedUrl = '';

    server.use(
      http.get('*/api/user/list', ({ request }) => {
        observedUrl = request.url;
        expectBearerHeader(request, 're-review-users-token');
        return HttpResponse.json([
          { user_id: 7, user_name: 'curator_a', user_role: 'Curator' },
          { user_id: 8, user_name: 'reviewer_b', user_role: 'Reviewer' },
        ]);
      })
    );

    const wrapper = await mountManageReReview();
    await flushPromises();

    expect(new URL(observedUrl).searchParams.get('roles')).toBe('Curator,Reviewer');
    expect(vm(wrapper).user_options).toEqual([
      { value: 7, text: 'curator_a', role: 'Curator' },
      { value: 8, text: 'reviewer_b', role: 'Reviewer' },
    ]);
  });

  it('loadAvailableEntities normalizes entity rows and scalar total', async () => {
    primeAuth('re-review-entities-token');

    server.use(
      http.get('*/api/re_review/entities/available', ({ request }) => {
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

  it('loadAvailableEntities unwraps Plumber scalar-array total values', async () => {
    primeAuth('re-review-entities-array-total-token');

    server.use(
      http.get('*/api/re_review/entities/available', () =>
        HttpResponse.json({
          data: [{ entity_id: 22, symbol: 'SCN2A' }],
          meta: { total: [1] },
        })
      )
    );

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);

    await component.loadAvailableEntities();
    await flushPromises();

    expect(component.availableEntities).toEqual([{ entity_id: 22, symbol: 'SCN2A' }]);
    expect(component.availableEntityTotal).toBe(1);
  });

  it('handleEntityAssignment preserves null batch name and success side effects', async () => {
    primeAuth('re-review-assign-token');
    let receivedBody: unknown = null;

    server.use(
      http.put('*/api/re_review/entities/assign', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({
          entry: { batch_id: 77, entity_count: 2 },
        });
      })
    );

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    const tableRefresh = vi.spyOn(component, 'loadReReviewTableData').mockResolvedValue();
    const entityRefresh = vi.spyOn(component, 'loadAvailableEntities').mockResolvedValue();

    component.selectedEntityIds = [11, 22];
    component.entityAssignUserId = 3;
    component.entityAssignBatchName = '';

    await component.handleEntityAssignment();
    await flushPromises();

    expect(receivedBody).toEqual({
      entity_ids: [11, 22],
      user_id: 3,
      batch_name: null,
    });
    expect(component.makeToast).toHaveBeenCalledWith(
      'Created batch 77 with 2 entities',
      'Success',
      'success'
    );
    expect(component.announce).toHaveBeenCalledWith('Created batch 77 with 2 entities');
    expect(component.selectedEntityIds).toEqual([]);
    expect(component.entityAssignUserId).toBeNull();
    expect(component.entityAssignBatchName).toBe('');
    expect(tableRefresh).toHaveBeenCalledTimes(1);
    expect(entityRefresh).toHaveBeenCalledTimes(1);
  });

  it('handleEntityAssignment validation avoids API calls for missing inputs', async () => {
    primeAuth('re-review-validation-token');
    let sawAssignCall = false;
    server.use(
      http.put('*/api/re_review/entities/assign', () => {
        sawAssignCall = true;
        return HttpResponse.json({});
      })
    );

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    component.selectedEntityIds = [];
    component.entityAssignUserId = 3;

    await component.handleEntityAssignment();

    expect(sawAssignCall).toBe(false);
    expect(component.makeToast).toHaveBeenCalledWith(
      'Please select at least one entity',
      'Validation',
      'warning'
    );
  });

  it('handleEntityAssignment uses fallback copy when the server omits batch summary fields', async () => {
    primeAuth('re-review-assign-empty-entry-token');

    server.use(
      http.put('*/api/re_review/entities/assign', () =>
        HttpResponse.json({
          entry: {},
        })
      )
    );

    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    vi.spyOn(component, 'loadReReviewTableData').mockResolvedValue();
    vi.spyOn(component, 'loadAvailableEntities').mockResolvedValue();

    component.selectedEntityIds = [11];
    component.entityAssignUserId = 3;

    await component.handleEntityAssignment();
    await flushPromises();

    expect(component.makeToast).toHaveBeenCalledWith(
      'Created assignment batch, but the batch summary was unavailable',
      'Success',
      'success'
    );
    expect(component.announce).toHaveBeenCalledWith(
      'Created assignment batch, but the batch summary was unavailable'
    );
  });

  it('handleBatchReassignment closes the modal and refreshes only the table', async () => {
    primeAuth('re-review-reassign-token');
    server.use(
      http.put('*/api/re_review/batch/reassign', () => HttpResponse.json({ status: 200 }))
    );
    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    const tableRefresh = vi.spyOn(component, 'loadReReviewTableData').mockResolvedValue();
    const entityRefresh = vi.spyOn(component, 'loadAvailableEntities').mockResolvedValue();

    component.reassignModalShow = true;
    component.reassignBatchId = 42;
    component.reassignNewUserId = 9;

    await component.handleBatchReassignment();
    await flushPromises();

    expect(component.reassignModalShow).toBe(false);
    expect(tableRefresh).toHaveBeenCalledTimes(1);
    expect(entityRefresh).not.toHaveBeenCalled();
  });

  it('handleBatchRecalculation closes the modal and refreshes table plus entities', async () => {
    primeAuth('re-review-recalculate-token');
    server.use(
      http.put('*/api/re_review/batch/recalculate', () =>
        HttpResponse.json({ entry: { batch_id: 42, entity_count: 20 } })
      )
    );
    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    const tableRefresh = vi.spyOn(component, 'loadReReviewTableData').mockResolvedValue();
    const entityRefresh = vi.spyOn(component, 'loadAvailableEntities').mockResolvedValue();

    component.recalculateModalShow = true;
    component.recalculateBatchId = 42;
    component.recalculateCriteria = {
      date_range: { start: null, end: null },
      gene_list: [],
      status_filter: null,
      batch_size: 20,
    };

    await component.handleBatchRecalculation();
    await flushPromises();

    expect(component.recalculateModalShow).toBe(false);
    expect(tableRefresh).toHaveBeenCalledTimes(1);
    expect(entityRefresh).toHaveBeenCalledTimes(1);
  });

  it('handleBatchRecalculation uses fallback copy when the server omits batch summary fields', async () => {
    primeAuth('re-review-recalculate-empty-entry-token');
    server.use(
      http.put('*/api/re_review/batch/recalculate', () => HttpResponse.json({ entry: {} }))
    );
    const wrapper = await mountManageReReview();
    const component = vm(wrapper);
    vi.spyOn(component, 'loadReReviewTableData').mockResolvedValue();
    vi.spyOn(component, 'loadAvailableEntities').mockResolvedValue();

    component.recalculateModalShow = true;
    component.recalculateBatchId = 42;

    await component.handleBatchRecalculation();
    await flushPromises();

    expect(component.makeToast).toHaveBeenCalledWith(
      'Batch recalculated, but the batch summary was unavailable',
      'Success',
      'success'
    );
    expect(component.announce).toHaveBeenCalledWith(
      'Batch recalculated, but the batch summary was unavailable'
    );
    expect(component.recalculateModalShow).toBe(false);
  });
});

// ===========================================================================
// Issue #29 — gene-atomic BAlert hint
// Verifies that ManageReReview.vue renders/hides the boundary-gene warning
// based on the previewBoundaryGene data property.
// ===========================================================================
describe('ManageReReview.vue — gene-atomic boundary-gene alert (issue #29)', () => {
  // -------------------------------------------------------------------------
  // Helper: mount with overridden data fields so we can drive the alert
  // without triggering real HTTP calls.
  // -------------------------------------------------------------------------
  const mountWithBoundaryData = async (overrides: Record<string, unknown>): Promise<VueWrapper> => {
    const wrapper = mount(ManageReReview, {
      global: {
        directives: {
          'b-tooltip': {},
          'b-toggle': {},
        },
        stubs: {
          BContainer: { template: '<div><slot /></div>' },
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BCollapse: { props: ['modelValue'], template: '<div><slot /></div>' },
          BButton: { template: '<button><slot /></button>' },
          BButtonGroup: { template: '<div><slot /></div>' },
          BBadge: { template: '<span><slot /></span>' },
          BTooltip: { template: '' },
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
          BFormSelectOption: { props: ['value'], template: '<option><slot /></option>' },
          BFormCheckbox: {
            props: ['modelValue', 'switch', 'size', 'id'],
            template: '<input type="checkbox" />',
          },
          BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
          BForm: { template: '<form><slot /></form>' },
          BOverlay: { template: '<div><slot /></div>' },
          BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
          BInputGroupText: { template: '<span><slot /></span>' },
          BPopover: { template: '' },
          BAlert: {
            // Render unconditionally — the outer v-if on the host controls
            // whether this stub is mounted at all. Pass-through attrs (including
            // data-testid) land on the root element via Vue's inheritAttrs.
            props: ['variant', 'show'],
            template: '<div :data-variant="variant"><slot /></div>',
          },
          BModal: {
            name: 'BModal',
            props: ['modelValue', 'id', 'title'],
            template: '<div><slot /></div>',
            methods: { show() {}, hide() {} },
          },
          BatchCriteriaForm: { template: '<div />' },
          AriaLiveRegion: { template: '<div />' },
          IconLegend: { template: '<div />' },
        },
      },
    });

    // Flush initial mount loaders before overriding data.
    await flushPromises();

    // Override the relevant data fields and trigger a re-render.
    Object.entries(overrides).forEach(([key, value]) => {
      (wrapper.vm as unknown as Record<string, unknown>)[key] = value;
    });

    // Wait for Vue reactivity to propagate the data changes to the DOM.
    await wrapper.vm.$nextTick();
    return wrapper;
  };

  it('alert is hidden when previewBoundaryGene is null', async () => {
    primeAuth();
    installDefaultHandlers();

    const wrapper = await mountWithBoundaryData({
      activeBatchMode: 'manual',
      previewBoundaryGene: null,
      previewGeneCount: 0,
      previewEntityCount: 0,
    });

    expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(false);
  });

  it('alert renders when previewBoundaryGene is non-null', async () => {
    primeAuth();
    installDefaultHandlers();

    const wrapper = await mountWithBoundaryData({
      activeBatchMode: 'manual',
      previewBoundaryGene: 'HGNC:4585',
      previewGeneCount: 2,
      previewEntityCount: 6,
    });

    const alert = wrapper.find('[data-testid="batch-boundary-gene-alert"]');
    expect(alert.exists()).toBe(true);
    expect(alert.text()).toContain('HGNC:4585');
    expect(alert.text()).toContain('6');
  });
});
