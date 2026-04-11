// views/review/Review.spec.ts
/**
 * Functional spec for Review.vue — v11.0 Phase C unit C2.
 *
 * Scope: .plans/v11.0/phase-c.md §3 Phase C.C2. Writes this spec against the
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
 * Both `Review.vue` (via `this.axios`) and `useReviewForm.ts` (via
 * `import axios from 'axios'`) touch axios. We stub axios at the module level
 * so the composable's direct import resolves to the same mock shape, and we
 * inject the same mock on `this.axios` via the test's `global.mocks` option.
 * Because every axios call is stubbed, no network requests escape — MSW's
 * `onUnhandledRequest: 'error'` (vitest.setup.ts:65-66) is satisfied
 * vacuously. No new MSW handlers are added and the B1 locked handler table
 * (src/test-utils/mocks/handlers.ts, phase-c.md §3 line 14) is not reopened.
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

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { bootstrapStubs } from '@/test-utils';
import Review from './Review.vue';

// ---------------------------------------------------------------------------
// axios stub (single shared mock consumed by both Review.vue and
// useReviewForm.ts so assertions across layers reference the same mock.
// `vi.mock` is hoisted, so `mockAxios` must be declared via a factory.
// ---------------------------------------------------------------------------
vi.mock('axios', () => {
  const axiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  };
  return {
    default: axiosMock,
    ...axiosMock,
  };
});

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
// imports stable.
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
  return axios.default as unknown as {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    put: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
}

function wireHappyPathResponses(
  axiosMock: Awaited<ReturnType<typeof getSharedAxiosMock>>
) {
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
  user: Record<string, unknown>;
  curator_mode: number;
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
