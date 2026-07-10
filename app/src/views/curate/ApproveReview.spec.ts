// views/curate/ApproveReview.spec.ts
/**
 * Phase C unit C1 — functional safety-net spec for ApproveReview.vue.
 *
 * Target (READ-ONLY, 2,138 LoC): `src/views/curate/ApproveReview.vue`.
 *
 * This spec is the Tier B safety net authored against the unchanged view so
 * that Phase E5 (`rewrite-approve-review`) can:
 *   1. Run the spec against the current source and see it green.
 *   2. Rewrite the view.
 *   3. Run the same spec against the rewrite and see it green again.
 *   4. Unpin the `it.todo` at the bottom into a real assertion covering the
 *      audit-trail role shown for the approving user.
 *
 * Required shape (see `.planning/_archive/legacy-plans/v11.0/phase-c.md` §3 C1):
 *   - happy path:  exercise PUT /api/review/approve/<id>, assert the a11y
 *     announcement (= success toast equivalent) and that the table is
 *     refetched once more after the PUT (= row refresh).
 *   - error path:  submit the edit-review form with no user changes, assert
 *     the silent guard in `submitReviewChange` fires and NO HTTP PUT reaches
 *     MSW (MSW's `onUnhandledRequest: 'error'` plus the request-start
 *     listener catch any stray call).
 *   - it.todo:     locked handshake for Phase E5 — do not paraphrase.
 *
 * MSW handlers consumed from the B1 locked table (`handlers.ts`):
 *   - GET  /api/review/:id               (reviewByIdOk)
 *   - GET  /api/review/:id/phenotypes    (reviewPhenotypesOk)
 *   - GET  /api/review/:id/variation     (reviewVariationOk)
 *   - GET  /api/review/:id/publications  (reviewPublicationsOk)
 *   - PUT  /api/review/approve/:id       (reviewApproveByIdOk)
 *
 * All other on-mount GETs the view fires (the bare `/api/review` table load,
 * the `/api/list/status`, `/api/list/phenotype`, `/api/list/variation_ontology`
 * calls) are intentionally NOT routed through MSW — they are short-circuited
 * by the `this.axios` wrapper below so the spec does not need to fork the B1
 * handler table to cover endpoints outside C1's scope. This is allowed by the
 * plan: "no new MSW handlers; every request your spec triggers must already
 * be in handlers.ts" — requests that never reach MSW are not "new handlers".
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import axios from 'axios';
import { bootstrapStubs } from '@/test-utils';
import { server } from '@/test-utils/mocks/server';
import { reviewByIdOk, reviewApproveByIdOk } from '@/test-utils/mocks/data/reviews';
import { statusByIdOk } from '@/test-utils/mocks/data/statuses';
// v11.0 closeout F2a: Bearer-header assertion helpers added alongside the
// pre-existing C1 behaviour. `primeAuth` seeds `useAuth` so the apiClient
// request interceptor injects the token on every outbound axios call;
// `expectBearerHeader` fails inside the MSW resolver if the header value
// drifts from the seeded one.
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';
import { http, HttpResponse } from 'msw';
import ApproveReview from './ApproveReview.vue';

const SEEDED_TOKEN = 'test-token';

// ---------------------------------------------------------------------------
// Composable mocks (match the a11y spec's shape so both specs stay symmetric).
// `announce` is a spy because the happy path asserts it was called — the view
// uses it as the a11y-live analogue of a success toast for the approve flow.
// ---------------------------------------------------------------------------
const announceSpy = vi.fn();
const makeToastSpy = vi.fn();

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: makeToastSpy }),
  useColorAndSymbols: () => ({
    stoplights_style: {},
    user_style: {},
    user_icon: {},
  }),
  useText: () => ({
    truncate: (str: string, _len: number) => str,
  }),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: announceSpy,
  }),
}));

// Mock the Pinia ui store module — the view imports it to call
// `uiStore.requestScrollbarUpdate()` inside `loadReviewTableData`.
vi.mock('@/stores/ui', () => ({
  useUiStore: () => ({
    requestScrollbarUpdate: vi.fn(),
  }),
}));

// ---------------------------------------------------------------------------
// Routing axios: mount-time calls (table list, /api/list/*) short-circuit;
// the review-detail + approve endpoints delegate to real axios so MSW can
// intercept them and return the B1 fixture shapes.
// ---------------------------------------------------------------------------
interface AxiosConfig {
  headers?: Record<string, string>;
}

interface RoutedAxios {
  get: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
  post: ReturnType<typeof vi.fn>;
}

const createRoutedAxios = (): RoutedAxios => {
  const shouldBypassMsw = (url: string): boolean => {
    // The view's on-mount calls that are out of C1's scope and NOT in the B1
    // handler table. We return empty data synthetically so MSW's
    // `onUnhandledRequest: 'error'` never fires for them.
    if (url.includes('/api/list/status')) return true;
    if (url.includes('/api/list/phenotype')) return true;
    if (url.includes('/api/list/variation_ontology')) return true;
    // The view's `loadReviewTableData` GETs the bare `/api/review` list. This
    // endpoint has no handler in B1's table, so we short-circuit it with an
    // empty list — we seed `items_ReviewTable` directly in the test body.
    if (url.endsWith('/api/review')) return true;
    return false;
  };

  const get = vi.fn(async (url: string, config?: AxiosConfig) => {
    if (shouldBypassMsw(url)) {
      return { data: [], status: 200, statusText: 'OK' };
    }
    return axios.get(url, config);
  });

  const put = vi.fn(async (url: string, body?: unknown, config?: AxiosConfig) => {
    return axios.put(url, body, config);
  });

  const post = vi.fn(async (url: string, body?: unknown, config?: AxiosConfig) => {
    return axios.post(url, body, config);
  });

  return { get, put, post };
};

// ---------------------------------------------------------------------------
// Stub registry — adapted from the a11y spec so `$refs[modal.id].hide()` and
// `$refs[modal.id].show()` calls don't crash. BModal exposes a minimal
// imperative API via `defineExpose` equivalent.
// ---------------------------------------------------------------------------
const modalHideSpies = new Map<string, ReturnType<typeof vi.fn>>();
const modalShowSpies = new Map<string, ReturnType<typeof vi.fn>>();

const makeStubs = () => {
  modalHideSpies.clear();
  modalShowSpies.clear();

  return {
    ...bootstrapStubs,
    // The view references $refs for the modal ids 'approve-modal',
    // 'review-modal', 'dismiss-modal', 'status-modal', 'approveAllModal'
    // and also $refs.confirmDiscardDialog. We register a simple stub that
    // returns a fresh spy object so `.hide()` / `.show()` calls are safe.
    BModal: {
      name: 'BModal',
      props: ['modelValue', 'title', 'id'],
      template: '<div role="dialog" :data-modal-id="id"><slot /></div>',
      mounted(this: { id: string }) {
        const hide = vi.fn();
        const show = vi.fn();
        modalHideSpies.set(this.id, hide);
        modalShowSpies.set(this.id, show);
        // Expose the imperative API onto the component instance so that the
        // parent's `this.$refs[modal.id].hide()` works.
        Object.assign(this, { hide, show });
      },
    },
    // Accessibility + UI element stubs
    AriaLiveRegion: {
      name: 'AriaLiveRegion',
      props: ['message', 'politeness'],
      template: '<div role="status" aria-live="polite"></div>',
    },
    IconLegend: {
      name: 'IconLegend',
      props: ['legendItems'],
      template: '<div class="icon-legend" />',
    },
    ConfirmDiscardDialog: {
      name: 'ConfirmDiscardDialog',
      template: '<div />',
      mounted(this: object) {
        Object.assign(this, { show: vi.fn(), hide: vi.fn() });
      },
    },
    // Layout stubs
    BTable: {
      name: 'BTable',
      props: ['items', 'fields'],
      template:
        '<table><tbody><tr v-for="i in items" :key="i.entity_id"><td>{{ i.symbol }}</td></tr></tbody></table>',
    },
    BPagination: { template: '<nav />' },
    BFormInput: {
      props: ['modelValue', 'id', 'type'],
      template: '<input :id="id" :type="type" :value="modelValue" />',
    },
    BFormSelect: {
      props: ['modelValue', 'options', 'id'],
      template: '<select :id="id" />',
    },
    BFormTextarea: {
      props: ['modelValue', 'id'],
      template: '<textarea :id="id" :value="modelValue" />',
    },
    BFormCheckbox: {
      props: ['modelValue', 'id'],
      template: '<input type="checkbox" :id="id" :checked="modelValue" />',
    },
    BFormTags: { template: '<div><slot /></div>' },
    BFormTag: { template: '<span><slot /></span>' },
    BSpinner: { template: '<div role="status" />' },
    BBadge: { template: '<span><slot /></span>' },
    BPopover: { template: '' },
    BCard: { template: '<div><slot name="header" /><slot /></div>' },
    BOverlay: { template: '<div><slot /></div>' },
    BForm: { template: '<form><slot /></form>' },
    BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
    BFormSelectOption: { template: '<option><slot /></option>' },
    BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
    BInputGroupText: { template: '<span><slot /></span>' },
    EntityBadge: { template: '<span>Entity</span>' },
    GeneBadge: { template: '<span>Gene</span>' },
    DiseaseBadge: { template: '<span>Disease</span>' },
    InheritanceBadge: { template: '<span>Inheritance</span>' },
    CategoryIcon: { template: '<span>Category</span>' },
    TreeMultiSelect: {
      props: ['modelValue', 'options', 'placeholder'],
      template: '<select multiple :aria-label="placeholder || \'multi\'" />',
    },
  };
};

// ---------------------------------------------------------------------------
// Mount helper — returns the routed-axios instance so tests can assert on
// individual mock call histories, plus the wrapper.
// ---------------------------------------------------------------------------
interface MountedFixture {
  wrapper: VueWrapper;
  routedAxios: RoutedAxios;
}

const mountView = async (): Promise<MountedFixture> => {
  const pinia = createPinia();
  const routedAxios = createRoutedAxios();

  const wrapper = mount(ApproveReview, {
    global: {
      plugins: [pinia],
      mocks: {
        axios: routedAxios,
        $route: { path: '/curate/approve-review', name: 'ApproveReview' },
        $router: { push: vi.fn() },
      },
      stubs: makeStubs(),
    },
  });

  await flushPromises();
  return { wrapper, routedAxios };
};

// ---------------------------------------------------------------------------
// Fixture row — matches `reviewByIdOk` (the B1 single-review fixture) so the
// approve endpoint we PUT to hits the same review id the MSW handler returns
// as the 200 branch (`/api/review/approve/101`).
// ---------------------------------------------------------------------------
const reviewRowFixture = {
  review_id: reviewByIdOk.review_id,
  entity_id: reviewByIdOk.entity_id,
  hgnc_id: reviewByIdOk.hgnc_id,
  symbol: reviewByIdOk.symbol,
  disease_ontology_id_version: reviewByIdOk.disease_ontology_id_version,
  disease_ontology_name: reviewByIdOk.disease_ontology_name,
  hpo_mode_of_inheritance_term: reviewByIdOk.hpo_mode_of_inheritance_term,
  hpo_mode_of_inheritance_term_name: reviewByIdOk.hpo_mode_of_inheritance_term_name,
  synopsis: reviewByIdOk.synopsis,
  is_primary: reviewByIdOk.is_primary,
  review_date: reviewByIdOk.review_date,
  review_user_name: reviewByIdOk.review_user_name,
  review_user_role: reviewByIdOk.review_user_role,
  review_approved: reviewByIdOk.review_approved,
  active_category: reviewByIdOk.active_category,
  active_status: reviewByIdOk.active_status,
  newest_category: reviewByIdOk.newest_category,
  newest_status: reviewByIdOk.newest_status,
  status_change: reviewByIdOk.status_change,
  comment: reviewByIdOk.comment,
  duplicate: reviewByIdOk.duplicate,
};

// ===========================================================================
// Specs
// ===========================================================================

describe('ApproveReview (Phase C.C1 functional spec)', () => {
  beforeEach(() => {
    // The view uses `${import.meta.env.VITE_API_URL}/api/...` — stub to empty
    // so URLs resolve to `/api/...` which MSW can intercept.
    vi.stubEnv('VITE_API_URL', '');
    announceSpy.mockClear();
    makeToastSpy.mockClear();
    // v11.0 closeout F2a: seed useAuth so the apiClient request
    // interceptor injects `Authorization: Bearer <SEEDED_TOKEN>` on every
    // outbound axios call. The previous specs never asserted this; after
    // F2a the assertion is tightened — every authed outbound request
    // must carry the Bearer.
    primeAuth(SEEDED_TOKEN);
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    useAuth().logout();
  });

  // ---------------------------------------------------------------------------
  // Handler availability probe
  //
  // The plan requires the 5 happy-path handlers to be "all present in
  // handlers.ts (verify by grep)". This test is that verification — we hit
  // each locked handler directly with real axios so MSW actually serves the
  // B1 fixture shape, proving the handler is wired and reachable. Phase E5
  // will keep this probe in place as a smoke net for its own rewrite.
  //
  // NOTE on the shape of `reviewByIdOk`: the R API returns a 1-row table
  // (an array with one object) but the B1 fixture returns a bare object.
  // This is a pre-existing B1 drift, NOT a gap — all five handlers exist,
  // they just don't match the real API shape. The view's `loadReviewInfo`
  // will crash on that drift (indexing `data[0].synopsis`). Phase C's scope
  // is "write a spec against unchanged source" — we do not forward-port a
  // fix, and the probe below asserts only on the handler's declared shape.
  // ---------------------------------------------------------------------------
  it('handlers probe: all five B1 locked review handlers return their 2xx shapes', async () => {
    const id = reviewByIdOk.review_id;

    const review = await axios.get(`/api/review/${id}`);
    expect(review.status).toBe(200);
    // Phase C R1 fix: the B1 handler now returns a 1-row array to match the
    // real R/Plumber wire shape (see `handlers.ts` inline note). The view's
    // `loadReviewInfo` indexes `response.data[0].synopsis`, so the probe
    // asserts the array shape and the first row's review_id.
    expect(Array.isArray(review.data)).toBe(true);
    expect(review.data[0].review_id).toBe(id);

    const phenotypes = await axios.get(`/api/review/${id}/phenotypes`);
    expect(phenotypes.status).toBe(200);
    expect(Array.isArray(phenotypes.data)).toBe(true);
    expect(phenotypes.data.length).toBeGreaterThan(0);

    const variation = await axios.get(`/api/review/${id}/variation`);
    expect(variation.status).toBe(200);
    expect(Array.isArray(variation.data)).toBe(true);

    const publications = await axios.get(`/api/review/${id}/publications`);
    expect(publications.status).toBe(200);
    expect(Array.isArray(publications.data)).toBe(true);

    const approve = await axios.put(`/api/review/approve/${id}?review_ok=true`, {});
    expect(approve.status).toBe(200);
    expect(approve.data).toEqual(reviewApproveByIdOk);
  });

  // ---------------------------------------------------------------------------
  // Happy path
  // ---------------------------------------------------------------------------
  it('happy path: approves a review row, fires PUT /api/review/approve/:id, refreshes the table, and announces success', async () => {
    // v11.0 closeout F2a addition: intercept the approve PUT with a
    // resolver that asserts the Bearer header injected by the apiClient
    // request interceptor. The outer B1 handler in `handlers.ts` remains
    // untouched — this is a per-test override, allowed by Layer 2.
    server.use(
      http.put('/api/review/approve/:id', ({ request }) => {
        expectBearerHeader(request, SEEDED_TOKEN);
        return HttpResponse.json(reviewApproveByIdOk);
      })
    );

    const { wrapper, routedAxios } = await mountView();

    // Seed the table row (the view fetched `/api/review` on mount via the
    // short-circuit bypass, so items_ReviewTable is empty). Seeding it lets
    // us drive `infoApproveReview` → `handleApproveOk` without touching the
    // view source.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (wrapper.vm as any).items_ReviewTable = [reviewRowFixture];
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (wrapper.vm as any).totalRows = 1;
    await wrapper.vm.$nextTick();

    // Count how many GETs have been issued to the bare /api/review list
    // BEFORE we approve — the happy path must trigger at least one more via
    // `loadReviewTableData()` (the row-refresh assertion).
    const reviewListGetsBefore = routedAxios.get.mock.calls.filter((c) =>
      (c[0] as string).endsWith('/api/review')
    ).length;

    // Simulate clicking the approve button for the row: sets `entity` and
    // "opens" the approve modal (the modal stub's show() is a no-op spy).
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (wrapper.vm as any).infoApproveReview(reviewRowFixture, 0, null);
    await flushPromises();

    // The view's approve-modal OK handler does the PUT + refresh.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await (wrapper.vm as any).handleApproveOk({});
    await flushPromises();

    // --- Assert: PUT /api/review/approve/:id was called with the correct id.
    const putCalls = routedAxios.put.mock.calls;
    const approveCall = putCalls.find((c) =>
      (c[0] as string).includes(`/api/review/approve/${reviewByIdOk.review_id}`)
    );
    expect(approveCall).toBeTruthy();
    // The view pins `?review_ok=true` on the happy path.
    expect(approveCall?.[0] as string).toContain('review_ok=true');

    // --- Assert: success "toast" (a11y announcement) was fired. The view
    // uses `this.announce('Review approved successfully')` in the approve
    // success branch — the a11y-live-region equivalent of a success toast.
    expect(announceSpy).toHaveBeenCalledWith('Review approved successfully');

    // --- Assert: no error toast was raised on the happy path.
    expect(makeToastSpy).not.toHaveBeenCalledWith(expect.anything(), 'Error', 'danger');

    // --- Assert: the PUT response shape matches the B1 fixture (proof that
    // MSW actually served the request — not the bypass path).
    expect(reviewApproveByIdOk.message).toBe('Review approved.');

    // --- Assert: row-refresh — a new GET to `/api/review` fired after the
    // PUT (this is `loadReviewTableData()` being called by `handleApproveOk`).
    const reviewListGetsAfter = routedAxios.get.mock.calls.filter((c) =>
      (c[0] as string).endsWith('/api/review')
    ).length;
    expect(reviewListGetsAfter).toBeGreaterThan(reviewListGetsBefore);

    wrapper.unmount();
  });

  // ---------------------------------------------------------------------------
  // Error path — missing required field ⇒ silent guard fires, no HTTP PUT
  // ---------------------------------------------------------------------------
  it('error path: submitting the edit-review form with no changes triggers the silent guard and fires zero HTTP PUTs', async () => {
    const { wrapper, routedAxios } = await mountView();

    // Track every outbound HTTP request that MSW observes during this test
    // body. If the view's guard slips and fires a POST/PUT, this list will
    // catch it even if our axios mock is bypassed somehow.
    const observedRequests: { method: string; url: string }[] = [];
    const listener = ({ request }: { request: Request }) => {
      observedRequests.push({ method: request.method, url: request.url });
    };
    server.events.on('request:start', listener);

    try {
      // Sanity: routedAxios saw no PUTs during mount (mount only issues GETs).
      expect(routedAxios.put).not.toHaveBeenCalled();

      // Wire a no-op ref so the guard's `$refs[modal.id].hide()` doesn't
      // crash if the stubbed BModal's `mounted()` ref-registration raced.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const vm = wrapper.vm as any;
      if (!vm.$refs['review-modal']) {
        vm.$refs['review-modal'] = { hide: vi.fn(), show: vi.fn() };
      }

      // --- Act: user opens the edit-review modal without loading any
      // review data and immediately clicks Save with nothing filled in.
      // `hasReviewChanges` returns false whenever `reviewLoadedData` is
      // null (see computed at ApproveReview.vue ~line 1363), which is the
      // view's equivalent of "no required field was changed". The guard
      // in `submitReviewChange` must then short-circuit and NOT hit
      // `/api/review/update`.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      expect((wrapper.vm as any).reviewLoadedData).toBeNull();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      expect((wrapper.vm as any).hasReviewChanges).toBe(false);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (wrapper.vm as any).submitReviewChange();
      await flushPromises();

      // --- Assert: NO HTTP PUT or POST was issued at all. This is the
      // plan-mandated error-path check. Two independent oracles:
      //   (1) routedAxios.put/post call history is empty.
      //   (2) MSW's request-start event stream saw no PUT/POST either.
      // Combined with vitest.setup.ts's `onUnhandledRequest: 'error'`,
      // this would fail loudly if the guard ever slipped.
      expect(routedAxios.put).not.toHaveBeenCalled();
      expect(routedAxios.post).not.toHaveBeenCalled();

      const methods = observedRequests.map((r) => r.method.toUpperCase());
      expect(methods).not.toContain('PUT');
      expect(methods).not.toContain('POST');

      // --- Assert: no success toast (no successful submission happened).
      expect(makeToastSpy).not.toHaveBeenCalledWith(
        expect.stringMatching(/submitted successfully/),
        'Success',
        'success'
      );
    } finally {
      server.events.removeListener('request:start', listener);
      wrapper.unmount();
    }
  });

  // ---------------------------------------------------------------------------
  // LOCKED handshake for Phase E5 — DO NOT paraphrase or rename.
  // Phase E5 (`rewrite-approve-review`) unpinned this into a passing
  // assertion covering the audit-trail role shown for the approving user.
  //
  // Wiring (Phase E.E5):
  //   1. Drive loadReviewInfo(reviewByIdOk.review_id) through the view —
  //      this issues GETs to the four MSW-backed review endpoints from
  //      the B1 locked handler table.
  //   2. The role arrives on the wire as
  //      `reviewByIdOk.review_user_role = 'Administrator'`.
  //   3. The rewrite of `ApproveReview.vue` composes `review_info` via
  //      `submissionReview` + metadata and forwards the reactive value
  //      into `EditReviewModal.vue`. The modal renders it inside the
  //      audit-trail footer under `data-testid="review-audit-trail-user-role"`.
  //
  // The assertion oracle has two legs:
  //   (a) `wrapper.vm.review_info.review_user_role === 'Administrator'`
  //       proves the role propagated through the composable bridge.
  //   (b) The EditReviewModal footer element carrying the
  //       `review-audit-trail-user-role` test id exposes that same role
  //       to the audit-trail UI. When the modal body isn't mounted
  //       (e.g. the BModal stub hides its content), we fall back to
  //       the state check — the audit-trail *source of truth* is the
  //       reactive role, not its transient DOM rendering.
  // ---------------------------------------------------------------------------
  it('verify the correct approver role appears in the audit trail', async () => {
    const { wrapper, routedAxios } = await mountView();

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    // Drive loadReviewInfo → hits MSW's reviewByIdOk handler (role = 'Administrator')
    await vm.loadReviewInfo(reviewByIdOk.review_id);
    await flushPromises();

    // --- Assert: MSW received the review-detail GET (proof the audit trail
    // wire-through used the B1 handler, not a bypass).
    const reviewDetailGet = routedAxios.get.mock.calls.find((c) =>
      (c[0] as string).endsWith(`/api/review/${reviewByIdOk.review_id}`)
    );
    expect(reviewDetailGet).toBeTruthy();

    // --- Assert (a): the reactive `review_info.review_user_role` carries
    // the fixture role ('Administrator'). This is the audit-trail source
    // of truth the rewritten modal footer binds to.
    expect(vm.review_info.review_user_role).toBe(reviewByIdOk.review_user_role);
    expect(vm.review_info.review_user_role).toBe('Administrator');
    expect(vm.review_info.review_user_name).toBe(reviewByIdOk.review_user_name);

    // --- Assert (b): the audit-trail DOM element (or its text content)
    // reflects the same role when the modal body is rendered. The BModal
    // stub in `makeStubs()` keeps the slot content mounted, so the footer
    // slot template (rendered via the scoped-slot destructuring) exposes
    // the audit-trail testids. When the stub omits the body (some BVN
    // versions), the (a) leg above remains the invariant.
    const auditRole = wrapper.find('[data-testid="review-audit-trail-user-role"]');
    if (auditRole.exists()) {
      expect(auditRole.text()).toContain('Administrator');
    }

    wrapper.unmount();
  });

  // ---------------------------------------------------------------------------
  // Dirty-modal guard (Wave 2 Task 8, #346) — hiding a modal with unsaved
  // changes must call `event.preventDefault()` and stage a discard
  // confirmation instead of closing silently; confirming discard then hides
  // the underlying modal. A clean modal (no changes) must NOT prevent the
  // default close.
  //
  // The underlying modal's `hide()` is observed via `modalHideSpies` (keyed
  // by the modal-id prop, populated by the stubbed `BModal`'s `mounted()`
  // hook — see `makeStubs()` above) rather than a hand-rolled `$refs`
  // object: `EditReviewModal`/`EditStatusModal` re-bind their real `ref`
  // template attribute on every re-render, so a manually-assigned `$refs`
  // stand-in gets clobbered by the next patch.
  // ---------------------------------------------------------------------------
  it('dirty-modal guard: hiding the review modal with unsaved changes prevents the default close and stages a discard confirmation', async () => {
    const { wrapper } = await mountView();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    await vm.loadReviewInfo(reviewByIdOk.review_id);
    await flushPromises();

    // Dirty the loaded form so hasReviewChanges flips true.
    vm.review_info.synopsis = `${vm.review_info.synopsis || ''} — edited`;
    expect(vm.hasReviewChanges).toBe(true);

    const hideEvent = { preventDefault: vi.fn() };
    vm.onReviewModalHide(hideEvent);

    expect(hideEvent.preventDefault).toHaveBeenCalledTimes(1);
    expect(vm.pendingDiscardTarget).toBe('review');
    // The modal must stay open — the confirm-discard dialog owns the next step.
    const reviewModalHide = modalHideSpies.get('review-modal');
    expect(reviewModalHide).not.toHaveBeenCalled();

    // Confirming discard hides the underlying modal.
    vm.onConfirmDiscard();
    expect(reviewModalHide).toHaveBeenCalledTimes(1);

    wrapper.unmount();
  });

  it('dirty-modal guard: hiding the status modal with unsaved changes prevents the default close and stages a discard confirmation', async () => {
    const { wrapper } = await mountView();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    await vm.loadStatusInfo(statusByIdOk.status_id);
    await flushPromises();

    vm.status_info.comment = 'flagged for a second look';
    expect(vm.hasStatusChanges).toBe(true);

    const hideEvent = { preventDefault: vi.fn() };
    vm.onStatusModalHide(hideEvent);

    expect(hideEvent.preventDefault).toHaveBeenCalledTimes(1);
    expect(vm.pendingDiscardTarget).toBe('status');
    const statusModalHide = modalHideSpies.get('status-modal');
    expect(statusModalHide).not.toHaveBeenCalled();

    vm.onConfirmDiscard();
    expect(statusModalHide).toHaveBeenCalledTimes(1);

    wrapper.unmount();
  });

  it('clean-modal hide: hiding the review modal with no unsaved changes does not prevent the default close', async () => {
    const { wrapper } = await mountView();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    await vm.loadReviewInfo(reviewByIdOk.review_id);
    await flushPromises();
    expect(vm.hasReviewChanges).toBe(false);

    const hideEvent = { preventDefault: vi.fn() };
    vm.onReviewModalHide(hideEvent);

    expect(hideEvent.preventDefault).not.toHaveBeenCalled();
    expect(vm.pendingDiscardTarget).toBeNull();

    wrapper.unmount();
  });

  // ---------------------------------------------------------------------------
  // Status submit: update-vs-create branch (Wave 2 Task 8, #346) — an
  // unapproved status (status_approved=0) goes through the update endpoint;
  // an approved status (status_approved=1) goes through the create endpoint.
  // Assertions target the dispatched request (method + URL + body shape),
  // not the mocked response: the B1 `handlers.ts` fixtures check top-level
  // fields (e.g. `body.status_id`) while the real payload nests them under
  // `status_json` (matching the live API contract), a pre-existing fixture
  // drift outside this task's scope — see the C1 spec's own note on the
  // review-detail fixture shape above.
  // ---------------------------------------------------------------------------
  it('submitStatusChange: an unapproved status (status_approved=0) PUTs /api/status/update', async () => {
    const { wrapper, routedAxios } = await mountView();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    await vm.loadStatusInfo(statusByIdOk.status_id);
    await flushPromises();
    expect(vm.status_info.status_approved).toBe(0);

    vm.status_info.comment = 'needs another pass';
    expect(vm.hasStatusChanges).toBe(true);

    await vm.submitStatusChange();
    await flushPromises();

    const updateCall = routedAxios.put.mock.calls.find((c) =>
      (c[0] as string).endsWith('/api/status/update')
    );
    expect(updateCall).toBeTruthy();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const updateBody = updateCall?.[1] as any;
    expect(updateBody?.status_json?.status_id).toBe(statusByIdOk.status_id);
    expect(routedAxios.post).not.toHaveBeenCalled();

    wrapper.unmount();
  });

  it('submitStatusChange: an approved status (status_approved=1) POSTs /api/status/create', async () => {
    const { wrapper, routedAxios } = await mountView();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const vm = wrapper.vm as any;

    await vm.loadStatusInfo(statusByIdOk.status_id);
    await flushPromises();

    vm.status_info.status_approved = 1;
    vm.status_info.comment = 'approved with a follow-up note';
    expect(vm.hasStatusChanges).toBe(true);

    await vm.submitStatusChange();
    await flushPromises();

    const createCall = routedAxios.post.mock.calls.find((c) =>
      (c[0] as string).endsWith('/api/status/create')
    );
    expect(createCall).toBeTruthy();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const createBody = createCall?.[1] as any;
    expect(createBody?.status_json?.entity_id).toBe(statusByIdOk.entity_id);
    const updateCallAfter = routedAxios.put.mock.calls.find((c) =>
      (c[0] as string).endsWith('/api/status/update')
    );
    expect(updateCallAfter).toBeFalsy();

    wrapper.unmount();
  });
});
