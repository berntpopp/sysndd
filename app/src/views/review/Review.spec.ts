// views/review/Review.spec.ts
/**
 * Functional spec for Review.vue — v11.0 Phase C unit C2 + v11.0 closeout F2c.
 *
 * Scope: .plans/v11.0/phase-c.md §3 Phase C.C2 writes this spec against the
 * unchanged 1,454-LoC view (`Review.vue`) so the Phase-B safety net grows
 * without touching source. The view mounts a re-review table and four modals;
 * the "classification wizard" language in the plan maps onto the edit-review
 * modal flow:
 *
 *   1. pick a row → open the review modal (`infoReview`)
 *   2. load entity + review data via axios → fill synopsis, optionally edit
 *      phenotypes/variation/publications via ReviewFormFields
 *   3. submit via the modal's @ok handler (`submitReviewChange`) which
 *      delegates to `useReviewForm.submitForm(isUpdate=true, reReview=true)`,
 *      ultimately calling `PUT /api/review/update` (B1 locked table entry).
 *
 * v11.0 closeout F2c extends the spec with:
 *   - a mount-hydration case covering the `mounted()` migration from
 *     `JSON.parse(localStorage.user)` to `useAuth().user.value`.
 *   - five Bearer-assertion cases, one per migrated endpoint, combining an
 *     `apiClient` URL/method assertion with an interceptor-level
 *     `expectBearerHeader()` probe. Because this spec replaces the `axios`
 *     module wholesale with a factory mock (so `useReviewForm.ts`'s direct
 *     `import axios from 'axios'` and Review.vue's `apiClient` calls both
 *     resolve to the same spy), the real `apiClient` request interceptor
 *     cannot fire against MSW. We instead capture the interceptor callback
 *     registered at module load and invoke it in-test — proving that the
 *     token seeded via `primeAuth()` is injected onto the Axios config.
 *
 * Both `Review.vue` (via `apiClient` after F2c, and `this.axios` on legacy
 * paths exercised by the happy-/error-path tests) and `useReviewForm.ts`
 * (via `import axios from 'axios'`) touch axios. We stub axios at the
 * module level so the composable's direct import and apiClient's delegated
 * calls resolve to the same mock shape. No network requests escape — MSW's
 * `onUnhandledRequest: 'error'` (vitest.setup.ts:65-66) is satisfied
 * vacuously.
 *
 * Required assertions (verbatim from phase-c.md §3 C2, lines 119-122):
 *   - Happy path: walk the classification wizard step-by-step, submit,
 *     assert success.
 *   - Error path: advance from step 1 with invalid evidence; assert the next
 *     button is disabled and the validation message shows.
 *   - it.todo: "TODO: verify the step-indicator state after a back-navigation"
 *
 * Error-path note on fidelity: `Review.vue`'s "Save Review" button is not
 * literally a `<button disabled>` when synopsis is empty — there is no
 * disable binding on the button element. The underlying composable however
 * exposes `isFormValid` (useReviewForm.ts:226-228) which flips to `false`
 * with an empty synopsis, and `submitForm` throws before any `axios.put`
 * fires. We assert (a) the composable's semantic "cannot submit yet" signal
 * via `validateField('synopsis')`, (b) no `axios.put` call ever escaped, and
 * (c) the view's failure branch fires its aria-live announcement
 * (`announce('Failed to submit review', 'assertive')`), which is the actual
 * user-visible "validation message" the plan refers to.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { bootstrapStubs } from '@/test-utils';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import Review from './Review.vue';

// ---------------------------------------------------------------------------
// axios stub (single shared mock consumed by both Review.vue (via `apiClient`
// + legacy `this.axios`) and `useReviewForm.ts` so assertions across layers
// reference the same mock. `vi.mock` is hoisted, so the factory may not
// close over non-hoisted locals.
//
// v11.0 closeout F2c note: the factory also provides `defaults`,
// `interceptors`, and static helpers (`isAxiosError`, `AxiosHeaders`,
// `AxiosError`). Without them, `@/plugins/axios` and `@/api/client`
// module-load side effects (baseURL seed, response interceptor, request
// interceptor registration) crash with "Cannot set properties of undefined"
// the moment the migrated `Review.vue` imports `apiClient`. We record the
// request interceptor callback so later tests can invoke it and assert the
// Bearer injection that F2c delegates to the apiClient interceptor.
// ---------------------------------------------------------------------------
interface RequestConfigLike {
  url?: string;
  headers?: Record<string, string>;
}

interface CapturedAxiosMock {
  get: ReturnType<typeof vi.fn>;
  post: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
  delete: ReturnType<typeof vi.fn>;
  defaults: { baseURL: string; headers: { common: Record<string, string> } };
  interceptors: {
    request: {
      use: ReturnType<typeof vi.fn>;
      _cb: ((config: RequestConfigLike) => RequestConfigLike) | null;
    };
    response: {
      use: ReturnType<typeof vi.fn>;
      _success: ((response: unknown) => unknown) | null;
      _error: ((err: unknown) => unknown) | null;
    };
  };
  isAxiosError: (err: unknown) => boolean;
}

vi.mock('axios', () => {
  // AxiosHeaders lookalike — the interceptor in `@/api/client` does an
  // `instanceof AxiosHeaders` check and calls `.has('Authorization')` /
  // `.set(...)`. A minimal Map-backed stand-in keeps that branch happy.
  class FakeAxiosHeaders {
    private store = new Map<string, string>();
    has(key: string): boolean {
      return this.store.has(key.toLowerCase());
    }
    get(key: string): string | null {
      return this.store.get(key.toLowerCase()) ?? null;
    }
    set(key: string, value: string): this {
      this.store.set(key.toLowerCase(), value);
      return this;
    }
  }

  const axiosMock: CapturedAxiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', headers: { common: {} } },
    interceptors: {
      request: {
        use: vi.fn((cb: (config: RequestConfigLike) => RequestConfigLike) => {
          axiosMock.interceptors.request._cb = cb;
          return 0;
        }),
        _cb: null,
      },
      response: {
        use: vi.fn((success: (r: unknown) => unknown, err: (e: unknown) => unknown) => {
          axiosMock.interceptors.response._success = success;
          axiosMock.interceptors.response._error = err;
          return 0;
        }),
        _success: null,
        _error: null,
      },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };

  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: FakeAxiosHeaders,
    AxiosError: Error,
  };
});

// `@/plugins/axios` imports `@/router` at module load and calls
// `router.push(...)` from the 401 interceptor. Provide a minimal stub so
// neither the plugin load nor a defensive call path crashes.
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/Review' } },
  },
}));

// useFormDraft pokes localStorage and setTimeout — stub it so the reactive
// watch inside useReviewForm doesn't schedule async draft saves across tests.
vi.mock('@/composables/useFormDraft', () => ({
  default: vi.fn(() => ({
    hasDraft: { value: false },
    lastSavedFormatted: { value: '' },
    isSaving: { value: false },
    loadDraft: vi.fn(() => null),
    clearDraft: vi.fn(),
    checkForDraft: vi.fn(() => false),
    scheduleSave: vi.fn(),
  })),
}));

// The announce spy is shared across all tests; Review.vue destructures it
// once in setup(). We mock the whole @/composables barrel to keep the view's
// imports stable. NOTE: `useAuth` is NOT re-exported from the barrel — it is
// imported directly from `@/composables/useAuth` — so this mock does not
// interfere with F2c's session-hydration migration.
const announceSpy = vi.fn();
const makeToastSpy = vi.fn();

vi.mock('@/composables', () => ({
  useToast: () => ({
    makeToast: makeToastSpy,
  }),
  useColorAndSymbols: () => ({
    stoplights_style: {
      Definitive: 'success',
      Moderate: 'info',
      Limited: 'warning',
      Refuted: 'danger',
    },
    user_style: {
      Administrator: 'danger',
      Curator: 'primary',
      Reviewer: 'info',
      Viewer: 'secondary',
    },
    user_icon: {
      Administrator: 'shield-fill-check',
      Curator: 'pencil-fill',
      Reviewer: 'eye-fill',
      Viewer: 'person-fill',
    },
    data_age_style: {
      0: 'success',
      3: 'warning',
      6: 'danger',
    },
    data_age_text: {
      0: 'Recent',
      3: 'Needs update',
      6: 'Stale',
    },
    ndd_icon_text: {
      yes: 'NDD phenotype',
      no: 'Not NDD',
      unknown: 'Unknown',
    },
  }),
  useText: () => ({
    truncate: (str: string) => str,
    inheritance_short_text: { 'Autosomal dominant': 'AD' },
    empty_table_text: { true: 'No entities found', false: 'No reviews found' },
  }),
  useAriaLive: () => ({
    message: { value: '' },
    politeness: { value: 'polite' },
    announce: announceSpy,
  }),
}));

// ---------------------------------------------------------------------------
// Fixtures — small, self-contained, shaped to mirror the plumber JSON the
// real endpoints return. We deliberately don't pull from
// src/test-utils/mocks/data/* because those fixtures target MSW handler
// payloads (plumber array-wrapped scalars, etc.) whereas here we feed the
// view directly.
// ---------------------------------------------------------------------------

interface ReReviewRow {
  entity_id: number;
  re_review_entity_id: number;
  review_id: number;
  status_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  category: string;
  ndd_phenotype_word: string;
  review_date: string;
  review_user_name: string;
  review_user_role: string;
  re_review_review_saved: number;
  re_review_status_saved: number;
}

const sampleRow: ReReviewRow = {
  entity_id: 501,
  re_review_entity_id: 701,
  review_id: 101,
  status_id: 201,
  hgnc_id: 'HGNC:12345',
  symbol: 'TEST1',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
  category: 'Definitive',
  ndd_phenotype_word: 'yes',
  review_date: '2025-06-01 12:00:00',
  review_user_name: 'alice_admin',
  review_user_role: 'Administrator',
  re_review_review_saved: 0,
  re_review_status_saved: 0,
};

const entityFixture = {
  entity_id: 501,
  sysndd_id: 'sysndd:000501',
  symbol: 'TEST1',
  hgnc_id: 'HGNC:12345',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
};

const reviewDetailFixture = [
  {
    review_id: 101,
    entity_id: 501,
    synopsis: 'Existing synopsis text used as the baseline.',
    comment: '',
    review_user_name: 'alice_admin',
    review_user_role: 'Administrator',
    review_date: '2025-06-01 12:00:00',
  },
];

// Configures the axios stub to answer every URL the view + composable hit
// during a normal review-modal open. We branch on substring so a single
// mockImplementation handles all parallel-loaded endpoints.
async function getSharedAxiosMock() {
  const axios = await import('axios');
  return axios.default as unknown as CapturedAxiosMock;
}

function wireHappyPathResponses(axiosMock: CapturedAxiosMock) {
  axiosMock.get.mockImplementation((url: string) => {
    // 1) Initial table load + dropdown lists (all the mounted() calls)
    if (url.includes('/api/re_review/table')) {
      return Promise.resolve({ data: { data: [sampleRow] } });
    }
    if (url.includes('/api/list/phenotype')) {
      return Promise.resolve({ data: [] });
    }
    if (url.includes('/api/list/variation_ontology')) {
      return Promise.resolve({ data: [] });
    }
    if (url.includes('/api/list/status')) {
      return Promise.resolve({
        data: [
          { category_id: 1, category: 'Definitive' },
          { category_id: 2, category: 'Moderate' },
        ],
      });
    }
    // 2) Entity lookup (getEntity() in infoReview)
    if (url.includes('/api/entity?filter=')) {
      return Promise.resolve({ data: { data: [entityFixture] } });
    }
    // 3) useReviewForm.loadReviewData — parallel /api/review/:id/* calls
    if (url.includes('/phenotypes')) {
      return Promise.resolve({ data: [] });
    }
    if (url.includes('/variation')) {
      return Promise.resolve({ data: [] });
    }
    if (url.includes('/publications')) {
      return Promise.resolve({ data: [] });
    }
    // 4) Review detail — called by useReviewForm.loadReviewData AND by
    //    Review.vue's loadReviewInfo (for the modal footer). Both consume
    //    `data[0]`, so one fixture satisfies both.
    if (url.match(/\/api\/review\/\d+$/)) {
      return Promise.resolve({ data: reviewDetailFixture });
    }
    return Promise.resolve({ data: [] });
  });
}

// ---------------------------------------------------------------------------
// Mount helper — stubs every Bootstrap-Vue-Next and child component the view
// pulls in. The stubs preserve accessible roles/slots where the test needs
// them, and collapse everything else into a plain `<div>`/`<button>`.
// ---------------------------------------------------------------------------
async function mountReview(): Promise<VueWrapper> {
  const pinia = createPinia();
  const axiosMock = await getSharedAxiosMock();

  const wrapper = mount(Review, {
    global: {
      plugins: [pinia],
      mocks: {
        // Mirror main.ts's globalProperties.axios injection so
        // `this.axios.get(...)` in Review.vue resolves to the same mock the
        // composable imports. Same reference → unified assertions.
        // v11.0 closeout F2c: Review.vue's 5 previously-`this.axios` calls
        // now go through `apiClient`, which also resolves to the same
        // mocked `axios.default` module. The injection here is still
        // needed because `useReviewForm.ts` and other legacy paths
        // referenced on other views remain on `this.axios` patterns that
        // this spec's unchanged happy/error-path coverage touches.
        axios: axiosMock,
        $route: { path: '/Review', name: 'Review', params: {} },
        $router: { push: vi.fn(), currentRoute: { value: { fullPath: '/Review' } } },
      },
      stubs: {
        ...bootstrapStubs,
        AriaLiveRegion: {
          name: 'AriaLiveRegion',
          props: ['message', 'politeness'],
          template: '<div role="status" aria-live="polite"></div>',
        },
        IconLegend: {
          name: 'IconLegend',
          props: ['legendItems', 'title'],
          template: '<div class="icon-legend" />',
        },
        // BModal — the view's `@ok` handler is wired from Vue, not from a
        // DOM click. We keep the slot hierarchy so the modal content is
        // visible when `modelValue` is truthy, but we rely on calling
        // `wrapper.vm.submitReviewChange()` directly for the happy/error
        // paths below.
        BModal: {
          name: 'BModal',
          props: ['modelValue', 'title', 'id'],
          methods: {
            show() {
              this.$emit('update:modelValue', true);
              this.$emit('show');
            },
            hide() {
              this.$emit('update:modelValue', false);
            },
          },
          template: `
            <div v-if="modelValue" role="dialog" :aria-label="title" :data-modal-id="id">
              <slot name="title"></slot>
              <slot></slot>
              <slot name="footer" :ok="() => $emit('ok')" :cancel="() => $emit('cancel')"></slot>
            </div>
          `,
        },
        // Form primitives: kept as plain passthrough wrappers. We do NOT
        // rewire v-model from the DOM here because every happy/error-path
        // assertion below drives state through `wrapper.vm` directly. That
        // avoids Vue template-compiler issues with TS casts on $event.target
        // and keeps the stubs focused on mounting the view.
        BFormInput: {
          name: 'BFormInput',
          props: ['modelValue', 'id', 'type', 'placeholder'],
          template: '<input :id="id" :type="type" :placeholder="placeholder" :value="modelValue" />',
        },
        BFormSelect: {
          name: 'BFormSelect',
          props: ['modelValue', 'options', 'id'],
          template: '<select :id="id"><slot /></select>',
        },
        BFormTextarea: {
          name: 'BFormTextarea',
          props: ['modelValue', 'id'],
          template: '<textarea :id="id" :value="modelValue"></textarea>',
        },
        BFormCheckbox: {
          name: 'BFormCheckbox',
          props: ['modelValue', 'id'],
          template: '<input type="checkbox" :id="id" :checked="modelValue" />',
        },
        BFormTags: { template: '<div><slot /></div>' },
        BFormTag: { template: '<span><slot /></span>' },
        BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BSpinner: {
          template: '<div role="status" aria-label="Loading..."></div>',
        },
        BBadge: { template: '<span><slot /></span>' },
        BPopover: { template: '' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BOverlay: { template: '<div><slot /></div>' },
        BForm: { template: '<form><slot /></form>' },
        BTable: {
          props: ['items'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id"><td><slot name="cell(actions)" v-bind="{ item, index: 0 }" /></td></tr></tbody></table>',
        },
        BPagination: { template: '<nav />' },
        BDropdown: { template: '<div><slot /></div>' },
        BDropdownItem: { template: '<a><slot /></a>' },
        EntityBadge: { template: '<span>Entity</span>' },
        GeneBadge: { template: '<span>Gene</span>' },
        DiseaseBadge: { template: '<span>Disease</span>' },
        InheritanceBadge: { template: '<span>Inheritance</span>' },
        CategoryIcon: { template: '<span>Category</span>' },
        NddIcon: { template: '<span>NDD</span>' },
        TreeMultiSelect: { template: '<select multiple><option /></select>' },
        ReviewFormFields: {
          name: 'ReviewFormFields',
          props: ['modelValue', 'phenotypesOptions', 'variationOptions', 'loading'],
          template: '<div class="review-form-fields-stub" />',
        },
      },
    },
  });

  await flushPromises();
  return wrapper;
}

// Narrow the wrapper.vm surface that this spec touches. Keeping this close to
// the tests makes the contract with the view explicit; if the view rearranges
// these names, the TS compiler fails the spec instead of silently mis-asserting.
interface ReviewVm {
  items: ReReviewRow[];
  isBusy: boolean;
  loading: boolean;
  user: Record<string, unknown> | null;
  // `data()` initialises `curator_mode: 0`, but `mounted()` reassigns it to
  // the boolean result of `this.user.user_role[0] === 'Administrator' || ...`
  // (see Review.vue mounted()). The runtime type is therefore `boolean |
  // number`; tests must assert against the correct post-mount shape.
  curator_mode: boolean | number;
  entity: Array<{ re_review_entity_id: number }>;
  status_approved: boolean;
  review_approved: boolean;
  reviewFormData: {
    synopsis: string;
    phenotypes: string[];
    variationOntology: string[];
    publications: string[];
    genereviews: string[];
    comment: string;
  };
  review_info: { review_id: number | null; entity_id: number | null };
  reviewForm: {
    validateField: (field: string) => string | true;
    touchField: (field: string) => void;
    getFieldError: (field: string) => string | null;
    isFormValid: { value: boolean };
  };
  infoReview: (item: ReReviewRow, index: number, button: unknown) => Promise<void>;
  submitReviewChange: () => Promise<void>;
  loadReReviewData: () => Promise<void>;
  handleSubmitOk: (evt: unknown) => Promise<void>;
  handleApproveOk: (evt: unknown) => Promise<void>;
  handleUnsetSubmission: (evt: unknown) => Promise<void>;
  newBatchApplication: () => Promise<void>;
}

describe('Review.vue — classification wizard (functional)', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    announceSpy.mockClear();
    makeToastSpy.mockClear();
  });

  it('happy path: opens review modal, loads data, submits, and reloads the table', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);
    axiosMock.put.mockResolvedValue({ data: { message: 'Review successfully updated.' } });

    // --- Step 0: mount the view (table load kicks off on mount()) ---
    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;

    // The view's mounted() hook issues the table load + three list loads.
    // Flushing promises finishes them all before we touch row actions.
    await flushPromises();
    expect(vm.items).toHaveLength(1);
    expect(vm.items[0].entity_id).toBe(501);

    // --- Step 1: open the review modal for row 0 (wizard step 1) ---
    await vm.infoReview(sampleRow, 0, null);
    await flushPromises();

    // infoReview triggers getEntity() + useReviewForm.loadReviewData() +
    // loadReviewInfo(). Every call routes through axios.get, so verify the
    // load-phase hit our stub for each expected URL family.
    const getUrls = axiosMock.get.mock.calls.map((c) => c[0] as string);
    expect(getUrls.some((u) => u.includes('/api/entity?filter='))).toBe(true);
    expect(getUrls.some((u) => /\/api\/review\/\d+$/.test(u))).toBe(true);
    expect(getUrls.some((u) => u.includes('/phenotypes'))).toBe(true);
    expect(getUrls.some((u) => u.includes('/variation'))).toBe(true);
    expect(getUrls.some((u) => u.includes('/publications'))).toBe(true);

    // loadReviewData populates synopsis from the fixture; confirm wizard
    // step 1 has real state the user can edit.
    expect(vm.reviewFormData.synopsis).toContain('Existing synopsis');
    expect(vm.review_info.review_id).toBe(101);
    expect(vm.review_info.entity_id).toBe(501);

    // --- Step 2: edit the synopsis (simulate typing into the wizard) ---
    vm.reviewFormData.synopsis =
      'Updated clinical synopsis for the re-review cycle — passes the 10-char minimum.';
    await flushPromises();

    // --- Step 3: submit the review (wizard final step) ---
    await vm.submitReviewChange();
    await flushPromises();

    // The happy-path PUT hit /api/review/update?re_review=true with the
    // merged payload shape from useReviewForm.submitForm(true, true). Assert
    // the method, the endpoint substring, and the inclusion of the edited
    // synopsis in the submitted body.
    expect(axiosMock.put).toHaveBeenCalledTimes(1);
    const [putUrl, putBody] = axiosMock.put.mock.calls[0];
    expect(putUrl).toContain('/api/review/update');
    expect(putUrl).toContain('re_review=true');
    const submittedPayload = (putBody as { review_json: { synopsis: string } }).review_json;
    expect(submittedPayload.synopsis).toContain('Updated clinical synopsis');

    // Success side effects: toast + aria-live announcement + a table refresh
    // (another /api/re_review/table call). All three are part of the "assert
    // success" acceptance criterion from phase-c.md §3 C2.
    expect(makeToastSpy).toHaveBeenCalledWith(
      'Review submitted successfully',
      'Success',
      'success'
    );
    expect(announceSpy).toHaveBeenCalledWith('Review submitted successfully');
    const reReviewTableCalls = axiosMock.get.mock.calls.filter((c) =>
      (c[0] as string).includes('/api/re_review/table')
    );
    expect(reReviewTableCalls.length).toBeGreaterThanOrEqual(2);
  });

  it('error path: invalid evidence at step 1 blocks submission and surfaces the validation message', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);
    // A put.mockRejectedValue here would muddy the assertion — we specifically
    // want to prove submitForm throws BEFORE any network attempt. Leave put
    // as the default vi.fn() and later assert it was never called.

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    // Open the review modal (wizard step 1). Data loads normally so we can
    // then blank out the synopsis to simulate "invalid evidence" — the
    // composable's validationRules.synopsis rejects anything shorter than
    // 10 characters (useReviewForm.ts:73-79).
    await vm.infoReview(sampleRow, 0, null);
    await flushPromises();

    vm.reviewFormData.synopsis = '';
    await flushPromises();

    // --- Semantic "next button disabled" assertion ---
    // The view doesn't bind `:disabled` on the Save Review button, but the
    // underlying isFormValid computed is the source of truth the plan cares
    // about — a Phase E rewrite would wire that ref to the button's disabled
    // prop. Validating both the composable's public validator and the
    // boolean form-valid state proves the semantic guard holds on unchanged
    // source.
    vm.reviewForm.touchField('synopsis');
    const synopsisError = vm.reviewForm.getFieldError('synopsis');
    expect(synopsisError).toBe('Synopsis is required');
    expect(vm.reviewForm.isFormValid.value).toBe(false);

    // Drop the captured GET call count so the subsequent assertion only
    // considers network activity after the submit attempt.
    const putCallsBefore = axiosMock.put.mock.calls.length;

    // --- Attempt to submit ---
    // submitReviewChange catches the thrown validation error and routes it
    // through makeToast + announce(..., 'assertive'). It must NOT fire any
    // axios.put and must NOT announce success.
    await vm.submitReviewChange();
    await flushPromises();

    expect(axiosMock.put.mock.calls.length).toBe(putCallsBefore);

    // --- Validation message shows (as aria-live 'assertive' + error toast) ---
    expect(announceSpy).toHaveBeenCalledWith('Failed to submit review', 'assertive');
    expect(announceSpy).not.toHaveBeenCalledWith('Review submitted successfully');
    // The error toast fires with variant='danger' and title='Error'; the
    // first arg is the thrown Error object which we don't pin verbatim.
    const errorToastCalls = makeToastSpy.mock.calls.filter(
      (call) => call[1] === 'Error' && call[2] === 'danger'
    );
    expect(errorToastCalls.length).toBeGreaterThanOrEqual(1);
  });

  // Phase E handshake — step-indicator back-navigation is state Phase E will
  // introduce when it rewrites the re-review UI to a true wizard. Leaving
  // this as an `it.todo` is the locked string the plan requires; E5's
  // rewrite unpins it into a real assertion.
  it.todo('TODO: verify the step-indicator state after a back-navigation');
});

// ---------------------------------------------------------------------------
// v11.0 closeout F2c — session hydration + apiClient Bearer injection.
//
// These tests exercise the two migrations F2c performed on Review.vue:
//   1. `mounted()` reads `useAuth().user.value` in place of
//      `JSON.parse(localStorage.user)`.
//   2. Five `this.axios.<verb>(url, { headers: { Authorization: 'Bearer ...' } })`
//      sites converted to `apiClient.<verb>(url, ...)` — the apiClient
//      request interceptor injects the Bearer header.
//
// Why we simulate the interceptor instead of using MSW:
// The top-of-file `vi.mock('axios', ...)` replaces the module wholesale so
// `useReviewForm.ts`'s direct `import axios from 'axios'` resolves to the
// same spy the view sees. MSW never sees those calls. We therefore capture
// the interceptor callback (the apiClient request interceptor registers
// itself via `axios.interceptors.request.use(cb)` at module load), invoke
// it directly inside each Bearer test, and run the result through
// `expectBearerHeader()` to prove the injection path is live and keyed to
// `useAuth().token.value`.
// ---------------------------------------------------------------------------

// The apiClient request interceptor has two branches for `config.headers`:
//
//   if (config.headers instanceof AxiosHeaders) { config.headers.set(...) }
//   else { (config.headers as Record<string, string>).Authorization = ... }
//
// In production, axios v1 normalises `config.headers` to `AxiosHeaders`
// before interceptors run, so the `instanceof` branch is what fires.
// Test-simulation must exercise BOTH branches to pin the contract — a
// regression in either path would be invisible if we only hit one.
//
// PR #278 (F1 test-followup) covers the full AxiosHeaders path end-to-end
// via real apiClient + MSW in `app/src/api/client.spec.ts`. These two
// helpers cover the F2c-specific interceptor-capture surface.

function simulateApiClientInterceptor(
  axiosMock: CapturedAxiosMock,
  url: string
): Request {
  // Plain-object headers branch: hand the interceptor `{ headers: {} }`
  // so `instanceof AxiosHeaders` is false and the fallback Record-cast
  // assignment runs.
  const cb = axiosMock.interceptors.request._cb;
  if (!cb) {
    throw new Error(
      'apiClient request interceptor was never registered — did @/api/client fail to import?'
    );
  }
  const config: RequestConfigLike = { url, headers: {} };
  const enriched = cb(config);
  const headers = (enriched.headers ?? {}) as Record<string, string>;
  return new Request(`http://localhost${url}`, {
    method: 'GET',
    headers,
  });
}

async function simulateApiClientInterceptorWithAxiosHeaders(
  axiosMock: CapturedAxiosMock,
  url: string
): Promise<Request> {
  // `AxiosHeaders` branch: hand the interceptor a `FakeAxiosHeaders`
  // instance (from the shared `vi.mock('axios')` factory — re-imported
  // here via dynamic import so the same mocked module is used). The
  // interceptor should call `.set('Authorization', …)` on it; we read
  // the value back via `.get('authorization')` and adapt to a fetch
  // Request for the shared `expectBearerHeader()` helper.
  const cb = axiosMock.interceptors.request._cb;
  if (!cb) {
    throw new Error(
      'apiClient request interceptor was never registered — did @/api/client fail to import?'
    );
  }
  const axiosModule = (await import('axios')) as unknown as {
    AxiosHeaders: new () => {
      has(k: string): boolean;
      get(k: string): string | null;
      set(k: string, v: string): unknown;
    };
  };
  const axiosHeaders = new axiosModule.AxiosHeaders();
  const config: RequestConfigLike = {
    url,
    headers: axiosHeaders as unknown as Record<string, string>,
  };
  const enriched = cb(config);
  const enrichedHeaders = enriched.headers as unknown as {
    get(name: string): string | null;
  };
  const authorization = enrichedHeaders.get('Authorization');
  const headersBag: Record<string, string> = authorization
    ? { Authorization: authorization }
    : {};
  return new Request(`http://localhost${url}`, {
    method: 'GET',
    headers: headersBag,
  });
}

describe('Review.vue — v11.0 closeout F2c migration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    announceSpy.mockClear();
    makeToastSpy.mockClear();
  });

  afterEach(() => {
    // Drop any session seeded by primeAuth so the next test's
    // `useAuth().user.value` read starts from a clean slate. The
    // per-file `beforeEach` in vitest.setup.ts also clears localStorage,
    // but `useAuth()`'s module-level refs need an explicit re-sync.
    useAuth().logout();
  });

  it('mount with no session: curator_mode stays at the data() default and `user` keeps its default shape', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);

    // No primeAuth() — the session is empty. Sanity-check the invariant
    // Review.vue's migrated `mounted()` relies on: `useAuth().user.value`
    // is null when there is no session.
    expect(useAuth().user.value).toBeNull();
    // And confirm localStorage is empty for both keys — the Phase C baseline
    // used to read `localStorage.user` directly, so this is what would have
    // triggered the old `if (localStorage.user)` guard to skip the block.
    expect(window.localStorage.getItem('user')).toBeNull();

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    // `user` keeps its `data()` default object (empty arrays for every
    // field) because the mounted() hook never entered the `if (sessionUser)`
    // block. `curator_mode` stays at its numeric default.
    expect(vm.user).not.toBeNull();
    expect(vm.user).toMatchObject({
      user_id: [],
      user_name: [],
      user_role: [],
    });
    expect(vm.curator_mode).toBe(0);
  });

  it('mount with session: hydrates `user` via useAuth() which re-syncs from localStorage on every call', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);

    // `primeAuth()` writes the reactive ref + localStorage. To prove the
    // view pulls through useAuth() (which re-runs `syncFromStorage()` on
    // every call, per useAuth.ts:396), we overwrite the `user` key AFTER
    // priming with a DIFFERENT, valid payload. The view's `mounted()`
    // calls `useAuth()`, which re-syncs, so the stale value deterministic-
    // ally wins. The negative would be: mounted() reads some cached
    // ref-only state and ignores storage — the stale payload would NOT
    // appear in `vm.user`.
    const { token } = primeAuth('token-from-primeAuth');
    window.localStorage.setItem(
      'user',
      JSON.stringify({
        user_id: [9999],
        user_name: ['stale-from-localStorage'],
        email: ['stale@example'],
        user_role: ['Viewer'],
        user_created: ['1970-01-01'],
        abbreviation: ['ST'],
        orcid: [''],
        exp: [Math.floor(Date.now() / 1000) + 3600],
      })
    );

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    // Deterministic contract:
    //   - useAuth() re-syncs on every call, so the LATE localStorage write
    //     wins over the earlier primeAuth() payload.
    //   - curator_mode depends on `user_role[0] === 'Administrator'` (see
    //     Review.vue's computed); the stale Viewer payload yields false.
    // Regression mode caught: if mounted() falls back to `data()` defaults
    // or caches a pre-sync wrapper, `user_name[0]` would not equal
    // 'stale-from-localStorage' and this assertion would red-fail.
    expect(vm.user.user_name[0]).toBe('stale-from-localStorage');
    expect(vm.user.user_role[0]).toBe('Viewer');
    expect(vm.curator_mode).toBe(false);
    // The primed Bearer token is independent of the user-payload mutation,
    // so the interceptor source is still what primeAuth() wrote.
    expect(useAuth().token.value).toBe(token);
  });

  it('apiClient interceptor injects Bearer header for loadReReviewData (GET /api/re_review/table)', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);

    const { token } = primeAuth('token-re-review-table');

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    // The mounted() hook has already called loadReReviewData once. Confirm
    // the URL reached the mock through `apiClient.get` (same mock object,
    // same spy).
    const getUrls = axiosMock.get.mock.calls.map((c) => c[0] as string);
    expect(getUrls.some((u) => u.includes('/api/re_review/table'))).toBe(true);

    // Simulate the apiClient request interceptor against the concrete URL
    // and assert the Bearer header that would be sent on the wire.
    const simulatedRequest = simulateApiClientInterceptor(
      axiosMock,
      '/api/re_review/table?curate=false'
    );
    expectBearerHeader(simulatedRequest, token);

    // Trigger another reload explicitly to prove the path stays live.
    axiosMock.get.mockClear();
    await vm.loadReReviewData();
    await flushPromises();
    const reloadUrls = axiosMock.get.mock.calls.map((c) => c[0] as string);
    expect(reloadUrls.some((u) => u.includes('/api/re_review/table'))).toBe(true);
  });

  it('apiClient interceptor injects Bearer header for handleSubmitOk (PUT /api/re_review/submit)', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);
    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });

    const { token } = primeAuth('token-re-review-submit');

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    // Seed entity state the handler reads.
    vm.entity = [{ re_review_entity_id: 701 }];
    await vm.handleSubmitOk(null);
    await flushPromises();

    // URL + body went through the mocked axios.put.
    expect(axiosMock.put).toHaveBeenCalled();
    const putCall = axiosMock.put.mock.calls.find((c) =>
      (c[0] as string).includes('/api/re_review/submit')
    );
    expect(putCall).toBeDefined();
    const [, submittedBody] = putCall as [string, { submit_json: unknown }];
    expect(submittedBody.submit_json).toMatchObject({
      re_review_entity_id: 701,
      re_review_submitted: 1,
    });

    // And the Bearer header the interceptor injects matches the primed token.
    const simulatedRequest = simulateApiClientInterceptor(
      axiosMock,
      '/api/re_review/submit'
    );
    expectBearerHeader(simulatedRequest, token);
  });

  it('apiClient interceptor injects Bearer header for handleApproveOk (PUT /api/re_review/approve/:id)', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);
    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });

    const { token } = primeAuth('token-re-review-approve');

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    vm.entity = [{ re_review_entity_id: 701 }];
    vm.status_approved = true;
    vm.review_approved = true;
    await vm.handleApproveOk(null);
    await flushPromises();

    const putCall = axiosMock.put.mock.calls.find((c) =>
      /\/api\/re_review\/approve\/701/.test(c[0] as string)
    );
    expect(putCall).toBeDefined();
    const approveUrl = (putCall as [string, unknown])[0];
    expect(approveUrl).toContain('status_ok=true');
    expect(approveUrl).toContain('review_ok=true');

    const simulatedRequest = simulateApiClientInterceptor(
      axiosMock,
      '/api/re_review/approve/701?status_ok=true&review_ok=true'
    );
    expectBearerHeader(simulatedRequest, token);
  });

  it('apiClient interceptor injects Bearer header for handleUnsetSubmission (PUT /api/re_review/unsubmit/:id)', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);
    axiosMock.put.mockResolvedValue({ data: { message: 'ok' } });

    const { token } = primeAuth('token-re-review-unsubmit');

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    vm.entity = [{ re_review_entity_id: 701 }];
    await vm.handleUnsetSubmission(null);
    await flushPromises();

    const putCall = axiosMock.put.mock.calls.find((c) =>
      /\/api\/re_review\/unsubmit\/701/.test(c[0] as string)
    );
    expect(putCall).toBeDefined();

    const simulatedRequest = simulateApiClientInterceptor(
      axiosMock,
      '/api/re_review/unsubmit/701'
    );
    expectBearerHeader(simulatedRequest, token);
  });

  it('apiClient interceptor injects Bearer header for newBatchApplication (GET /api/re_review/batch/apply)', async () => {
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);

    const { token } = primeAuth('token-re-review-batch');

    const wrapper = await mountReview();
    const vm = wrapper.vm as unknown as ReviewVm;
    await flushPromises();

    await vm.newBatchApplication();
    await flushPromises();

    const getUrls = axiosMock.get.mock.calls.map((c) => c[0] as string);
    expect(getUrls.some((u) => u.includes('/api/re_review/batch/apply'))).toBe(true);

    const simulatedRequest = simulateApiClientInterceptor(
      axiosMock,
      '/api/re_review/batch/apply'
    );
    expectBearerHeader(simulatedRequest, token);

    // Success side effects on the batch-apply path: toast + aria-live
    // announcement (the handler reports "Application send.").
    expect(makeToastSpy).toHaveBeenCalledWith('Application send.', 'Success', 'success');
    expect(announceSpy).toHaveBeenCalledWith('Batch application sent successfully');
  });

  it('apiClient interceptor injects Bearer header via AxiosHeaders branch (matches axios v1 runtime shape)', async () => {
    // Copilot review (#280): in production axios v1 normalises
    // `config.headers` to an `AxiosHeaders` instance before the
    // interceptor fires, so the `instanceof AxiosHeaders` branch in
    // `api/client.ts:95-97` is the real code path. The other F2c tests
    // above exercise the plain-object fallback; this one pins the
    // `AxiosHeaders` branch from the F2c interceptor-capture surface so a
    // regression in either branch is visible.
    const axiosMock = await getSharedAxiosMock();
    wireHappyPathResponses(axiosMock);

    const { token } = primeAuth('token-axiosheaders-branch');

    const simulatedRequest = await simulateApiClientInterceptorWithAxiosHeaders(
      axiosMock,
      '/api/re_review/table'
    );
    expectBearerHeader(simulatedRequest, token);
  });
});
