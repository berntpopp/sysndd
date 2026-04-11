// ApproveStatus.spec.ts
/**
 * Functional test for the ApproveStatus view.
 *
 * Phase C unit C3 — .plans/v11.0/phase-c.md §3 Phase C.C3. Exercises the
 * approval flow end-to-end against the unchanged 1,432-LoC `ApproveStatus.vue`,
 * routing through the real `@/plugins/axios` instance (so the 401 response
 * interceptor in `src/plugins/axios.ts` fires) and MSW for HTTP mocking.
 *
 * Scope locks (from the phase-c dispatch brief):
 *   - Zero source modifications. The view is read-only.
 *   - Zero new handlers in `src/test-utils/mocks/handlers.ts`. The B1 locked
 *     table already exposes `GET /api/status/:id` and `PUT /api/status/approve/:id`
 *     (the endpoints the plan names). For list-loading paths that the B1
 *     table does not cover (`GET /api/list/status?tree=true` and the bare
 *     `GET /api/status` used by `loadStatusTableData`), this spec installs
 *     **per-test** overrides via `server.use(...)` — allowed because the
 *     overrides live in the spec file, not in the shared handler table. The
 *     401 test follows the same pattern on `PUT /api/status/approve/:id`,
 *     keeping the `authenticateUnauthorized` fixture shape from B1.
 *   - `it.todo` is the locked handshake for Phase E6 (`converge-approve-status`).
 *
 * Assertions:
 *   - Happy path: approve a pending status row; the row is removed from
 *     `items_StatusTable` after the automatic table reload.
 *   - Error path: the PUT returns 401; the axios interceptor clears auth
 *     state and redirects to `/Login` via `router.push(...)`.
 *   - `it.todo`: E6 handshake.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { statusByIdOk } from '@/test-utils/mocks/data/statuses';
import { authenticateUnauthorized } from '@/test-utils/mocks/data/auth';

// ---------------------------------------------------------------------------
// Composable mocks (mirrors the stub set used by ApproveStatus.a11y.spec.ts)
// ---------------------------------------------------------------------------
// `useToast`, `useColorAndSymbols`, `useText`, and `useAriaLive` are pulled
// from `@/composables`; the real `useToast` wraps bootstrap-vue-next's
// `useBootstrapToast`, which requires a BApp provider we don't mount here.
// Hoisted via `vi.mock`.
vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
  useColorAndSymbols: () => ({
    stoplights_style: {},
    user_style: {},
    user_icon: {},
  }),
  useText: () => ({
    truncate: (s: string) => s,
    inheritance_short_text: {},
    problematic_text: {},
  }),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: vi.fn(),
  }),
}));

// ---------------------------------------------------------------------------
// Router mock
// ---------------------------------------------------------------------------
// `src/plugins/axios.ts` does `import router from '@/router'` at module load,
// so we must mock `@/router` BEFORE importing the axios plugin or the view.
// `vi.mock` is hoisted above the other imports, so the factory can't close
// over a later-declared const (that throws "Cannot access X before
// initialization"). Instead we stash the push spy on `globalThis` inside the
// factory and pull it back out below.
vi.mock('@/router', () => {
  const push = vi.fn();
  (globalThis as unknown as { __routerPushMock: ReturnType<typeof vi.fn> }).__routerPushMock =
    push;
  return {
    default: {
      push,
      currentRoute: { value: { fullPath: '/curate/approve-status' } },
    },
  };
});

const routerPushMock = (
  globalThis as unknown as { __routerPushMock: ReturnType<typeof vi.fn> }
).__routerPushMock;

// Importing the real axios plugin attaches its 401 response interceptor to
// the shared axios default instance. The plugin also reads `VITE_BASE_URL`
// at module load; it's unset in the vitest env so `baseURL` ends up empty,
// which is exactly what we want for path-only MSW matching.
import axios from '@/plugins/axios';
import ApproveStatus from '@/views/curate/ApproveStatus.vue';

// ---------------------------------------------------------------------------
// Fixture rows for GET /api/status (the bare list endpoint consumed by
// `loadStatusTableData`). Two pending rows is the smallest fixture that lets
// us assert "row removed after approve".
// ---------------------------------------------------------------------------
interface StatusTableRow {
  status_id: number;
  entity_id: number;
  symbol: string;
  hgnc_id: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term_name: string;
  hpo_mode_of_inheritance_term: string;
  category: string;
  category_id: number;
  comment: string | null;
  problematic: number;
  status_date: string;
  status_user_name: string;
  status_user_role: string;
  status_approved: number;
  is_active: boolean;
  duplicate: string;
  review_change: boolean;
}

const pendingRows: StatusTableRow[] = [
  {
    status_id: 201,
    entity_id: 501,
    symbol: 'TEST1',
    hgnc_id: 'HGNC:12345',
    disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
    disease_ontology_name: 'Test Disease',
    hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
    hpo_mode_of_inheritance_term: 'HP:0000006',
    category: 'Definitive',
    category_id: 1,
    comment: null,
    problematic: 0,
    status_date: '2025-06-01 12:00:00',
    status_user_name: 'alice_admin',
    status_user_role: 'Administrator',
    status_approved: 0,
    is_active: true,
    duplicate: 'no',
    review_change: false,
  },
  {
    status_id: 202,
    entity_id: 502,
    symbol: 'TEST2',
    hgnc_id: 'HGNC:67890',
    disease_ontology_id_version: 'MONDO:0000456_2025-01-01',
    disease_ontology_name: 'Other Disease',
    hpo_mode_of_inheritance_term_name: 'Autosomal recessive inheritance',
    hpo_mode_of_inheritance_term: 'HP:0000007',
    category: 'Moderate',
    category_id: 2,
    comment: 'A comment',
    problematic: 0,
    status_date: '2025-06-02 09:30:00',
    status_user_name: 'bob_curator',
    status_user_role: 'Curator',
    status_approved: 0,
    is_active: true,
    duplicate: 'no',
    review_change: false,
  },
];

const listStatusTreeOk = [
  { category_id: 1, category: 'Definitive', label: 'Definitive', id: 1 },
  { category_id: 2, category: 'Moderate', label: 'Moderate', id: 2 },
];

// The component reads `import.meta.env.VITE_API_URL` at call time (not at
// module load) and builds URLs as `${VITE_API_URL}/api/status`. Vitest loads
// no `.env.test` for this app, so the var is undefined and the template
// literal collapses to `undefined/api/status` — which MSW can't match
// against the relative `/api/status` handler pattern. We normalise by
// writing an empty string onto `import.meta.env` directly; `vi.stubEnv`
// didn't propagate to `import.meta.env` in practice under Vitest 4 here.
const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

beforeEach(() => {
  setActivePinia(createPinia());
  envBag.VITE_API_URL = '';
  window.localStorage.setItem('token', 'test-token');
  axios.defaults.headers.common.Authorization = 'Bearer test-token';
  routerPushMock.mockClear();
});

afterEach(() => {
  if (originalViteApiUrl === undefined) {
    delete envBag.VITE_API_URL;
  } else {
    envBag.VITE_API_URL = originalViteApiUrl;
  }
  window.localStorage.clear();
  delete axios.defaults.headers.common.Authorization;
});

// ---------------------------------------------------------------------------
// Mount helper
// ---------------------------------------------------------------------------
// Bootstrap-Vue-Next components don't need to actually render for this
// functional test — we exercise the flow via component methods, not the
// modal UI — so we stub them to minimal templates that preserve slots.
const mountApproveStatus = async (): Promise<VueWrapper> => {
  const wrapper = mount(ApproveStatus, {
    global: {
      mocks: {
        // Supply the real axios plugin instance (with the 401 interceptor
        // already attached) as `this.axios` — matches how `main.ts` wires it
        // onto `app.config.globalProperties.axios`.
        axios,
      },
      // `main.ts` registers `v-b-tooltip` / `v-b-toggle` globally; provide
      // no-op versions here so Vue doesn't warn about unresolved directives
      // when the template contains `v-b-tooltip.hover.bottom`.
      directives: {
        'b-tooltip': {},
        'b-toggle': {},
      },
      stubs: {
        // Bootstrap-Vue-Next structural stubs: render slot children so data
        // binds propagate through but the heavy components don't mount.
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: {
          template:
            '<div><slot name="header" /><slot /></div>',
        },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BLink: { template: '<a><slot /></a>' },
        BSpinner: { template: '<div role="status" />' },
        BTable: {
          name: 'BTable',
          props: ['items'],
          template:
            '<table><tbody><tr v-for="it in items" :key="it.status_id" :data-status-id="it.status_id"><td>{{ it.entity_id }}</td></tr></tbody></table>',
        },
        BPagination: { template: '<nav />' },
        BFormInput: {
          props: ['modelValue', 'type', 'placeholder', 'id', 'debounce', 'size'],
          template: '<input />',
        },
        BFormSelect: {
          // Absorb `options`/`modelValue`/etc. so Vue does not fall through
          // the array-typed `options` onto the underlying DOM `<select>`
          // element (which only accepts an HTMLOptionsCollection).
          props: ['modelValue', 'options', 'size', 'id', 'ariaLabel'],
          template: '<select><slot /></select>',
        },
        BFormSelectOption: {
          props: ['value'],
          template: '<option><slot /></option>',
        },
        BFormTextarea: {
          props: ['modelValue', 'rows', 'size', 'id', 'placeholder'],
          template: '<textarea />',
        },
        BFormCheckbox: {
          props: ['modelValue', 'switch', 'size', 'id'],
          template: '<input type="checkbox" />',
        },
        BFormGroup: { template: '<div><slot /></div>' },
        BForm: { template: '<form><slot /></form>' },
        BOverlay: { template: '<div><slot /></div>' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BPopover: { template: '' },
        // BModal exposes `show()`/`hide()` imperatively — the view calls
        // `this.$refs[modal.id].show()`. Our stub mirrors that contract so
        // `infoApproveStatus` doesn't crash; the spec drives the OK path
        // by calling `handleStatusOk` directly (below).
        BModal: {
          name: 'BModal',
          props: ['id'],
          template: '<div><slot /></div>',
          methods: {
            show() {
              /* no-op: spec drives the OK handler directly */
            },
            hide() {
              /* no-op */
            },
          },
        },
        // Custom components — stubbed because they're not under test here.
        EntityBadge: { template: '<span />' },
        GeneBadge: { template: '<span />' },
        DiseaseBadge: { template: '<span />' },
        InheritanceBadge: { template: '<span />' },
        CategoryIcon: { template: '<span />' },
        AriaLiveRegion: { template: '<div />' },
        IconLegend: { template: '<div />' },
        ConfirmDiscardDialog: {
          template: '<div />',
          methods: { show() {} },
        },
      },
    },
  });

  // Let `mounted()` run `loadStatusList` → `loadStatusTableData`.
  await flushPromises();
  return wrapper;
};

// ---------------------------------------------------------------------------
// View-model shape for TypeScript access via `wrapper.vm`
// ---------------------------------------------------------------------------
// `ApproveStatus.vue` uses the Options API with `data()`/`methods`, so
// vue-tsc can't infer the instance shape when we reach into it through
// `wrapper.vm`. We declare the subset we actually touch and cast once per
// test via the `vm(wrapper)` helper below.
interface ApproveStatusVm {
  items_StatusTable: StatusTableRow[];
  totalRows: number;
  approveModal: { title: string; hasDuplicates: boolean };
  status_info: { status_id: number };
  infoApproveStatus: (item: StatusTableRow, index: number, button: unknown) => void;
  handleStatusOk: (event: unknown) => Promise<void>;
}

const vm = (wrapper: VueWrapper): ApproveStatusVm =>
  wrapper.vm as unknown as ApproveStatusVm;

// ---------------------------------------------------------------------------
// Per-test MSW overrides
// ---------------------------------------------------------------------------
// GET /api/list/status and GET /api/status are NOT in the Phase B.B1 locked
// handler table; we install them per-test via `server.use(...)` instead of
// adding them to `handlers.ts`. The scope lock in the dispatch brief
// explicitly permits per-test overrides but forbids expanding `handlers.ts`.
//
// GET /api/status/:id IS in the B1 table, but that handler returns a plain
// object (`statusByIdOk`) — whereas `ApproveStatus.vue`'s `loadStatusInfo`
// reads `response.data[0]`, matching R/Plumber's one-row-wrapped-in-array
// convention. Overriding the handler with a 1-element array keeps the
// fixture values (and the `authenticateUnauthorized` shape used by the 401
// test) intact while aligning with the shape the view actually consumes.
const installListLoadingStubs = (listRows: StatusTableRow[]): void => {
  server.use(
    // GET /api/list/status?tree=true — categories dropdown for the edit modal.
    http.get('/api/list/status', () => HttpResponse.json(listStatusTreeOk)),
    // GET /api/status — the main pending-status list. Always returns the
    // current `listRows` snapshot so sequential calls (initial load +
    // post-approve reload) see the caller's latest mutation.
    http.get('/api/status', () => HttpResponse.json(listRows)),
    // GET /api/status/:id — override to the R/Plumber 1-element-array shape
    // that `loadStatusInfo` expects (`response.data[0].category_id`).
    http.get('/api/status/:id', () => HttpResponse.json([statusByIdOk]))
  );
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('ApproveStatus — functional flow (Phase C3)', () => {
  it('approves a pending status row and removes it from the list', async () => {
    // Track the current list state so the post-approve reload returns the
    // filtered set. Using a shared ref is simpler than MSW's one-time
    // handlers and more robust against flushPromises ordering.
    const listState: { rows: StatusTableRow[] } = { rows: [...pendingRows] };
    server.use(
      http.get('/api/list/status', () => HttpResponse.json(listStatusTreeOk)),
      http.get('/api/status', () => HttpResponse.json(listState.rows)),
      // Override GET /api/status/:id (B1 table) to return the R/Plumber
      // 1-element-array shape `loadStatusInfo` expects.
      http.get('/api/status/:id', () => HttpResponse.json([statusByIdOk]))
    );

    const wrapper = await mountApproveStatus();
    const vmHappy = vm(wrapper);

    // Initial load should have populated both rows.
    expect(vmHappy.items_StatusTable).toHaveLength(2);
    expect(vmHappy.items_StatusTable.map((r) => r.status_id)).toEqual([201, 202]);
    expect(vmHappy.totalRows).toBe(2);

    // Open the approve flow for the first row. `infoApproveStatus` populates
    // `approveModal.title`, calls `loadStatusInfo` (GET /api/status/:id from
    // the B1 locked table), and then shows the modal. We call it directly
    // to skip click-synthesis on a stubbed button.
    vmHappy.infoApproveStatus(pendingRows[0], 0, null);
    await flushPromises();

    // The modal should now be wired to the first pending row. The GET
    // /api/status/:id handler in B1 returns status_id=201 for any non-999
    // id, which matches our first row.
    expect(vmHappy.approveModal.title).toBe('sysndd:501');
    expect(vmHappy.status_info.status_id).toBe(statusByIdOk.status_id);

    // Simulate the post-approval state: the API will have moved this row
    // out of the pending queue, so the reload should yield only the second
    // row. Mutating `listState` here is analogous to a real backend.
    listState.rows = listState.rows.filter((r) => r.status_id !== 201);

    // Fire the modal OK handler. This hits PUT /api/status/approve/:id
    // (default B1 200-OK shape) and then re-runs `loadStatusTableData`.
    await vmHappy.handleStatusOk(null);
    await flushPromises();

    // The approved row should be gone; only status_id=202 remains.
    expect(vmHappy.items_StatusTable).toHaveLength(1);
    expect(vmHappy.items_StatusTable[0].status_id).toBe(202);
    expect(vmHappy.items_StatusTable.some((r) => r.status_id === 201)).toBe(false);
    expect(vmHappy.totalRows).toBe(1);

    // No 401, so the axios interceptor must not have redirected.
    expect(routerPushMock).not.toHaveBeenCalled();
  });

  it('redirects to /Login when approve returns 401 (interceptor fires)', async () => {
    installListLoadingStubs(pendingRows);

    const wrapper = await mountApproveStatus();
    const vmErr = vm(wrapper);
    expect(vmErr.items_StatusTable).toHaveLength(2);

    vmErr.infoApproveStatus(pendingRows[0], 0, null);
    await flushPromises();
    expect(vmErr.status_info.status_id).toBe(statusByIdOk.status_id);

    // Override PUT /api/status/approve/:id to return the stale-token shape
    // from B1's auth fixture. The path+method pair is in the B1 locked
    // table, so this is a per-test override (not a new handler).
    server.use(
      http.put('/api/status/approve/:id', () =>
        HttpResponse.text(authenticateUnauthorized, { status: 401 })
      )
    );

    // Fire the modal OK handler; the real axios plugin's response
    // interceptor should catch the 401 and call `router.push`.
    await vmErr.handleStatusOk(null);
    await flushPromises();

    // Interceptor contract from `src/plugins/axios.ts`:
    //   - calls `router.push({ path: '/Login', query: { redirect: ... } })`
    //   - clears the Authorization default header
    //   - wipes `localStorage.token`
    expect(routerPushMock).toHaveBeenCalledTimes(1);
    const pushArg = routerPushMock.mock.calls[0][0] as {
      path: string;
      query?: Record<string, unknown>;
    };
    expect(pushArg.path).toBe('/Login');
    // The mocked router's currentRoute is '/curate/approve-status', so the
    // interceptor must include it as the `redirect` query.
    expect(pushArg.query).toEqual({ redirect: '/curate/approve-status' });

    expect(axios.defaults.headers.common.Authorization).toBeUndefined();
    expect(window.localStorage.getItem('token')).toBeNull();
  });

  // E6 handshake (locked string — do not edit without coordinating with
  // Phase E6 `converge-approve-status`). The Phase E6 agent unpins this
  // `it.todo` after replacing `ApproveStatus.vue` with a mount of the new
  // `ApprovalTableView.vue` component.
  it.todo('TODO: verify the combined status/review handling — hook for E6 convergence');
});
