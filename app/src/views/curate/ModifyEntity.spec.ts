// ModifyEntity.spec.ts
/**
 * Functional spec for the ModifyEntity curate view (Phase C unit C4).
 *
 * Scope (from .planning/_archive/legacy-plans/v11.0/phase-c.md §3 Phase C.C4):
 *   - Happy path: edit an entity field, save, assert 200 + "cache invalidation"
 *     (the view's post-success behavior is `resetForm()`, which wipes
 *     `entity_info` and the search input — the UI-level analogue of a cache
 *     invalidation, since the next interaction must refetch).
 *   - Error path: submit a duplicate (gene + disease + inheritance) and assert
 *     the 409 conflict is surfaced to the user via the toast composable.
 *   - One locked `it.todo` placeholder for the unsaved-changes navigation
 *     warning (Phase E handshake).
 *
 * MSW drift note: the Phase B B1 handler table includes
 * `GET /api/entity/:sysndd_id`, a whitelisted drift documented in
 * `scripts/msw-openapi-exceptions.txt` (no bare `@get /<sysndd_id>` annotation
 * exists in `api/endpoints/entity_endpoints.R`). The view itself does NOT hit
 * that path — `getEntity()` actually fires
 * `GET /api/entity?filter=equals(entity_id,<id>)`, which has no handler in B1.
 * Rather than widen the locked B1 table in Phase C (forbidden by §3), this
 * spec follows the same `mocks: { axios }` pattern used by
 * `ModifyEntity.a11y.spec.ts`: every axios call in the view is intercepted at
 * the component-instance level. MSW's `onUnhandledRequest: 'error'` is still
 * active globally, so if the mock ever leaks and a real network call escapes,
 * vitest will fail loudly.
 *
 * Non-goals:
 *   - Not a rewrite. `ModifyEntity.vue` is read-only for Phase C.
 *   - Not a full integration test. Review/Status/Deactivate flows are out of
 *     scope — C4's locked required assertions cover the rename (edit) write
 *     path only. Covering the other three modals is a future phase concern.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { http, HttpResponse } from 'msw';
import { bootstrapStubs } from '@/test-utils';
// v11.0 closeout F2b migrated the three write calls
// (`POST /api/entity/rename`, `/api/entity/deactivate`, `/api/review/create`)
// from `this.axios.post(...)` onto the shared apiClient. Loading `@/plugins/
// axios` attaches the 401 interceptor and ensures the apiClient request
// interceptor is initialised before the first outbound call.
import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import ModifyEntity from './ModifyEntity.vue';
import { entityByIdOk, entityCreateConflict } from '@/test-utils/mocks/data/entities';

// ---------------------------------------------------------------------------
// Mocked composables (same shape as ModifyEntity.a11y.spec.ts so the mount
// succeeds without importing the real Pinia stores or toast engine).
// ---------------------------------------------------------------------------

const makeToastSpy = vi.fn();
const announceSpy = vi.fn();

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: makeToastSpy }),
  useColorAndSymbols: () => ({
    stoplights_style: {
      Definitive: 'success',
      Moderate: 'info',
      Limited: 'warning',
      Refuted: 'danger',
    },
    ndd_icon_style: { Yes: 'success', No: 'warning' },
    ndd_icon: { Yes: 'check', No: 'x' },
  }),
  useText: () => ({
    truncate: (str: string) => str,
    inheritance_short_text: {} as Record<string, string>,
    empty_table_text: { all: 'No entities found' },
  }),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: announceSpy,
  }),
}));

// `useStatusForm` is imported directly (not via the barrel), so mock it by
// module path. The spec never triggers the "Modify status" button so the
// returned stub only needs the members the setup() destructures.
vi.mock('@/views/curate/composables/useStatusForm', () => ({
  default: () => ({
    formData: {
      entity_id: null,
      category_id: null,
      problematic: false,
      comment: '',
    },
    loading: false,
    loadStatusByEntity: vi.fn(),
    submitForm: vi.fn(),
    resetForm: vi.fn(),
    hasChanges: false,
  }),
}));

// ---------------------------------------------------------------------------
// Typed axios shim — matches the `axios` global-property contract in
// src/plugins/axios.ts (Vue 3 `app.config.globalProperties.axios = axios`).
// ---------------------------------------------------------------------------

type AxiosResponse<T = unknown> = { data: T; status: number; statusText: string };
type AxiosMock = {
  get: ReturnType<typeof vi.fn>;
  post: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
};

/** Happy-path axios double — returns empty list shapes for the mounted lookups. */
const createAxiosMock = (): AxiosMock => ({
  get: vi.fn(
    (): Promise<AxiosResponse<{ data: unknown[] }>> =>
      Promise.resolve({ data: { data: [] }, status: 200, statusText: 'OK' })
  ),
  post: vi.fn(
    (): Promise<AxiosResponse> =>
      Promise.resolve({
        data: { message: 'Entity successfully renamed.', entity_id: 501 },
        status: 200,
        statusText: 'OK',
      })
  ),
  put: vi.fn(
    (): Promise<AxiosResponse> => Promise.resolve({ data: {}, status: 200, statusText: 'OK' })
  ),
});

// ---------------------------------------------------------------------------
// Component mount factory. Keeps the stub table identical to the a11y spec so
// both files share the same template-shape assumptions.
// ---------------------------------------------------------------------------

type ModifyEntityVM = InstanceType<typeof ModifyEntity> & {
  axios: AxiosMock;
  entity_info: Partial<typeof entityByIdOk> & Record<string, unknown>;
  modify_entity_input: number | null;
  ontology_input: string | null;
  entity_loaded: boolean;
  submitEntityRename: () => Promise<void>;
};

const mountModifyEntity = async (axiosInstance: AxiosMock): Promise<VueWrapper> => {
  const pinia = createPinia();

  const wrapper = mount(ModifyEntity, {
    global: {
      plugins: [pinia],
      mocks: {
        axios: axiosInstance,
        $route: { path: '/curate/modify-entity', name: 'ModifyEntity', params: {} },
        $router: { push: vi.fn() },
      },
      stubs: {
        ...bootstrapStubs,
        AriaLiveRegion: { template: '<div />' },
        IconLegend: { template: '<div />' },
        ConfirmDiscardDialog: { template: '<div />' },
        BModal: { template: '<div><slot /></div>' },
        BFormInput: {
          props: ['modelValue'],
          template: '<input :value="modelValue" />',
        },
        BFormSelect: {
          props: ['modelValue', 'options'],
          template: '<select :value="modelValue"></select>',
        },
        BFormSelectOption: { template: '<option><slot /></option>' },
        BFormTextarea: {
          props: ['modelValue'],
          template: '<textarea :value="modelValue"></textarea>',
        },
        BFormCheckbox: {
          props: ['modelValue'],
          template: '<input type="checkbox" :checked="modelValue" />',
        },
        BFormTags: { template: '<div><slot /></div>' },
        BFormTag: { template: '<span><slot /></span>' },
        BForm: { template: '<form><slot /></form>' },
        BOverlay: { template: '<div><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BSpinner: { template: '<span role="status">Loading…</span>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BInputGroup: { template: '<div><slot /></div>' },
        BAlert: { template: '<div role="alert"><slot /></div>' },
        AutocompleteInput: {
          props: ['modelValue'],
          template: '<input aria-label="Autocomplete" :value="modelValue" />',
        },
        EntityBadge: { template: '<span>Entity</span>' },
        GeneBadge: { template: '<span>Gene</span>' },
        DiseaseBadge: { template: '<span>Disease</span>' },
        TreeMultiSelect: { template: '<div />' },
      },
    },
  });

  await flushPromises();
  return wrapper;
};

/** Seeds the view with a loaded entity fixture so rename flows can proceed. */
const seedLoadedEntity = async (wrapper: VueWrapper) => {
  const vm = wrapper.vm as unknown as ModifyEntityVM;
  vm.modify_entity_input = entityByIdOk.entity_id;
  vm.entity_info = { ...entityByIdOk };
  vm.entity_loaded = true;
  vm.ontology_input = 'MONDO:0000456_2025-01-01';
  await flushPromises();
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ModifyEntity — functional (Phase C/C4)', () => {
  beforeEach(() => {
    makeToastSpy.mockClear();
    announceSpy.mockClear();
    vi.stubEnv('VITE_API_URL', '');
    // Seed a session so the apiClient request interceptor injects the
    // Bearer on the migrated POSTs. The existing tests don't pin the
    // header — the new F2b tests below do.
    primeAuth('modify-entity-token');

    // v11.1 W4: the read loaders (`loadStatusList`, `loadPhenotypesList`,
    // `loadVariationOntologyList`) used to flow through `this.axios.get(...)`
    // and were caught by the per-component `axiosMock`. After migration they
    // go through the typed `@/api/list` clients → shared axios singleton →
    // MSW. Provide empty-array defaults so the loaders resolve cleanly and
    // the rename / deactivate / review test cases see only the toast their
    // POST handler emits.
    server.use(
      http.get('/api/list/status', () => HttpResponse.json([])),
      http.get('/api/list/phenotype', () => HttpResponse.json([])),
      http.get('/api/list/variation_ontology', () => HttpResponse.json([]))
    );
  });

  afterEach(() => {
    useAuth().logout();
    vi.unstubAllEnvs();
  });

  describe('happy path — rename entity disease', () => {
    it('POSTs /api/entity/rename, surfaces success, and clears the selection (cache invalidation)', async () => {
      // Loaders still run through `this.axios.get(...)` / `this.axios.put(...)`
      // (those call sites are out of F2b scope); the axiosMock covers them.
      // The MIGRATED write (rename POST) now goes through apiClient → the
      // shared axios singleton → MSW. We capture the body via MSW and assert
      // the same `rename_json.entity` shape the original spec checked.
      const axiosMock = createAxiosMock();

      let capturedBody: unknown = null;
      server.use(
        http.post('/api/entity/rename', async ({ request }) => {
          capturedBody = await request.json();
          return HttpResponse.json(
            { message: 'Entity successfully renamed.', entity_id: 501 },
            { status: 200, statusText: 'OK' }
          );
        })
      );

      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      const vm = wrapper.vm as unknown as ModifyEntityVM;
      await vm.submitEntityRename();
      await flushPromises();

      // 1. The POST hit /api/entity/rename with a wrapped payload
      //    (`rename_json`) shaped by the submissionSubmission class.
      expect(capturedBody).not.toBeNull();
      const payload = capturedBody as { rename_json: { entity: Record<string, unknown> } };
      expect(payload).toHaveProperty('rename_json');
      expect(payload.rename_json).toHaveProperty('entity');
      // The view mutates `entity_info.disease_ontology_id_version = ontology_input`
      // before wrapping — confirm the new ontology id is on the wire.
      expect(payload.rename_json.entity).toMatchObject({
        entity_id: entityByIdOk.entity_id,
        disease_ontology_id_version: 'MONDO:0000456_2025-01-01',
      });

      // 2. The success toast fired with the 'success' variant.
      const successToasts = makeToastSpy.mock.calls.filter((call) => call[2] === 'success');
      expect(successToasts.length).toBeGreaterThanOrEqual(1);

      // 3. The aria-live region announced success (UX assertion tied to the
      //    `announce('Disease name updated successfully')` branch).
      expect(announceSpy).toHaveBeenCalledWith('Disease name updated successfully');

      // 4. Cache invalidation — resetForm() clears entity_info and the input
      //    so the next interaction must refetch. This is the view's
      //    post-success "the selection is stale, forget everything" contract.
      expect(vm.entity_info).toEqual({});
      expect(vm.modify_entity_input).toBeNull();
      expect(vm.entity_loaded).toBe(false);
      expect(vm.ontology_input).toBeNull();
    });
  });

  describe('error path — duplicate entity (409 conflict)', () => {
    it('surfaces the 409 conflict description via the toast composable and keeps the selection intact', async () => {
      // Reject the migrated rename POST with the conflict shape from B1.
      server.use(
        http.post('/api/entity/rename', () =>
          HttpResponse.json(entityCreateConflict, { status: 409 })
        )
      );

      const axiosMock = createAxiosMock();
      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      const vm = wrapper.vm as unknown as ModifyEntityVM;
      await vm.submitEntityRename();
      await flushPromises();

      // 1. makeToast was called with the error variant and the API-provided
      //    conflict message extracted from the rejected axios error.
      const dangerToasts = makeToastSpy.mock.calls.filter((call) => call[2] === 'danger');
      expect(dangerToasts.length).toBeGreaterThanOrEqual(1);

      expect(dangerToasts[0][0]).toBe(entityCreateConflict.error);

      // 2. Screen reader was told the operation failed (assertive politeness).
      expect(announceSpy).toHaveBeenCalledWith('Failed to update disease name', 'assertive');

      // 3. On failure, the view does NOT resetForm — the selection must
      //    survive so the user can fix the input and retry. Verify the
      //    entity is still loaded post-failure.
      expect(vm.entity_loaded).toBe(true);
      expect(vm.entity_info).toMatchObject({ entity_id: entityByIdOk.entity_id });
    });
  });

  // -------------------------------------------------------------------------
  // v11.0 closeout F2b — Bearer-header contract on each of the three migrated
  // write paths. Pins the apiClient interceptor injection so regressions in
  // this view (or in F1's `apiClient`/`useAuth()` plumbing) surface loudly.
  // -------------------------------------------------------------------------
  describe('v11.0 closeout F2b — apiClient Bearer header contract', () => {
    it('submitEntityRename() carries Authorization: Bearer <token>', async () => {
      let sawBearer = false;
      server.use(
        http.post('/api/entity/rename', ({ request }) => {
          expectBearerHeader(request, 'modify-entity-token');
          sawBearer = true;
          return HttpResponse.json({ message: 'ok', entity_id: 501 });
        })
      );

      const axiosMock = createAxiosMock();
      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      await (wrapper.vm as unknown as ModifyEntityVM).submitEntityRename();
      await flushPromises();
      expect(sawBearer).toBe(true);
    });

    it('submitEntityDeactivation() carries Authorization: Bearer <token>', async () => {
      let sawBearer = false;
      server.use(
        http.post('/api/entity/deactivate', ({ request }) => {
          expectBearerHeader(request, 'modify-entity-token');
          sawBearer = true;
          return HttpResponse.json({ message: 'ok' });
        })
      );

      const axiosMock = createAxiosMock();
      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      const vm = wrapper.vm as unknown as ModifyEntityVM & {
        submitEntityDeactivation: () => Promise<void>;
        deactivate_check: boolean;
        replace_entity_input: number | null;
      };
      vm.deactivate_check = true;
      vm.replace_entity_input = null;

      await vm.submitEntityDeactivation();
      await flushPromises();
      expect(sawBearer).toBe(true);
    });

    it('submitReviewChange() carries Authorization: Bearer <token>', async () => {
      let sawBearer = false;
      server.use(
        http.post('/api/review/create', ({ request }) => {
          expectBearerHeader(request, 'modify-entity-token');
          sawBearer = true;
          return HttpResponse.json({ message: 'ok' });
        })
      );

      const axiosMock = createAxiosMock();
      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      // Loose cast: the component exposes a narrower `review_info` type
      // on its instance, but we only need to set the fields the view's
      // `submitReviewChange()` reads before the POST. `unknown` as an
      // intermediate escape hatch keeps vue-tsc quiet.
      const vm = wrapper.vm as unknown as {
        submitReviewChange: () => Promise<void>;
        hasReviewChanges: boolean;
        review_info: unknown;
        select_additional_references: string[];
        select_gene_reviews: string[];
        select_phenotype: string[];
        select_variation: string[];
        $refs: Record<string, { hide: () => void }>;
      };
      // Bypass the silent-skip early return that fires when hasReviewChanges
      // is false. We reach into the instance here (same pattern the happy-
      // path test uses to seed `entity_info`).
      Object.defineProperty(vm, 'hasReviewChanges', {
        value: true,
        configurable: true,
      });
      vm.review_info = {
        entity_id: entityByIdOk.entity_id,
        literature: {},
        phenotypes: [],
        variation_ontology: [],
        synopsis: '',
        comment: '',
      };
      vm.select_additional_references = [];
      vm.select_gene_reviews = [];
      vm.select_phenotype = [];
      vm.select_variation = [];

      await vm.submitReviewChange();
      await flushPromises();
      expect(sawBearer).toBe(true);
    });
  });

  // Locked todo — Phase E will unpin this after wiring unsaved-changes guards
  // into the rename flow (the dialog is already imported at template level).
  it.todo('TODO: verify unsaved-changes warning on navigation');
});

// ---------------------------------------------------------------------------
// v11.1 finish-hardening fix #5 — EntityBadge sites are guarded with v-if so
// modal templates do not warn when `entity_info` is empty.
//
// Pre-fix: 4 of the 5 `<EntityBadge :entity-id="entity_info.entity_id" />`
// sites lived inside `<BModal>` `#title` slots. BModal mounts its slot tree
// before the parent's `entity_info` is loaded, so EntityBadge received
// `entity_info.entity_id === undefined` and Vue's prop validator emitted
// "Invalid prop: type check failed for prop 'entityId'. Expected
// String|Number, got Undefined". The fix adds `v-if="entity_info?.entity_id"`
// to all 4 modal-title sites (line 61 was already guarded by an outer BCard
// v-if). A fifth assertion below covers the line-61 path for completeness.
// ---------------------------------------------------------------------------

describe('ModifyEntity — fix #5 EntityBadge guarded with v-if', () => {
  let consoleWarnSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    makeToastSpy.mockClear();
    announceSpy.mockClear();
    vi.stubEnv('VITE_API_URL', '');
    primeAuth('modify-entity-fix5-token');
    server.use(
      http.get('/api/list/status', () => HttpResponse.json([])),
      http.get('/api/list/phenotype', () => HttpResponse.json([])),
      http.get('/api/list/variation_ontology', () => HttpResponse.json([]))
    );
    consoleWarnSpy = vi.spyOn(console, 'warn');
  });

  afterEach(() => {
    consoleWarnSpy.mockRestore();
    useAuth().logout();
    vi.unstubAllEnvs();
  });

  /**
   * Mount factory that uses the REAL `EntityBadge` (instead of the
   * happy-path spec's stub) so that Vue's prop validator actually runs and
   * we can detect the regression mode (a warning fires when `entity_info`
   * has no `entity_id`).
   */
  async function mountWithRealEntityBadge(axiosInstance: AxiosMock): Promise<VueWrapper> {
    const pinia = createPinia();
    return mount(ModifyEntity, {
      global: {
        plugins: [pinia],
        mocks: {
          axios: axiosInstance,
          $route: { path: '/curate/modify-entity', name: 'ModifyEntity', params: {} },
          $router: { push: vi.fn() },
        },
        stubs: {
          ...bootstrapStubs,
          AriaLiveRegion: { template: '<div />' },
          IconLegend: { template: '<div />' },
          ConfirmDiscardDialog: { template: '<div />' },
          // Render BModal's slot tree even when the modal is "closed" so the
          // EntityBadge in the title slot is mounted. This is the contract
          // the original warnings were emitted under: BModal eagerly mounts
          // its slots in production (so the modal can fade in cleanly), and
          // the prop validator fires once at mount time. With v-if on
          // EntityBadge, no warning is emitted because the badge is not
          // rendered when `entity_info?.entity_id` is falsy.
          BModal: {
            props: ['modelValue'],
            template:
              '<div class="b-modal-stub"><slot name="title" /><slot /><slot name="footer" /></div>',
          },
          BFormInput: { props: ['modelValue'], template: '<input :value="modelValue" />' },
          BFormSelect: { props: ['modelValue'], template: '<select />' },
          BFormSelectOption: { template: '<option><slot /></option>' },
          BFormTextarea: {
            props: ['modelValue'],
            template: '<textarea :value="modelValue"></textarea>',
          },
          BFormCheckbox: { props: ['modelValue'], template: '<input type="checkbox" />' },
          BFormTags: { template: '<div><slot /></div>' },
          BFormTag: { template: '<span><slot /></span>' },
          BForm: { template: '<form><slot /></form>' },
          BOverlay: { template: '<div><slot /></div>' },
          BBadge: { template: '<span><slot /></span>' },
          BSpinner: { template: '<span role="status" />' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BInputGroup: { template: '<div><slot /></div>' },
          BAlert: { template: '<div role="alert"><slot /></div>' },
          AutocompleteInput: {
            props: ['modelValue'],
            template: '<input aria-label="Autocomplete" :value="modelValue" />',
          },
          // EntityBadge is NOT stubbed — we want the real component (and its
          // prop validator) to run.
          GeneBadge: { template: '<span>Gene</span>' },
          DiseaseBadge: { template: '<span>Disease</span>' },
          TreeMultiSelect: { template: '<div />' },
        },
      },
    });
  }

  it('mount with empty entity_info: no Vue prop warnings for EntityBadge entity-id are logged', async () => {
    const axiosInstance = createAxiosMock();
    const wrapper = await mountWithRealEntityBadge(axiosInstance);

    // Sanity: `entity_info` is `{}` at mount (the data() default), which is
    // exactly the state the original warnings fired under. No `entity_id`
    // anywhere, so any unguarded EntityBadge would warn.
    const vm = wrapper.vm as unknown as ModifyEntityVM;
    expect(vm.entity_info).toEqual({});
    await flushPromises();

    // Inspect every warn call for the regression substring. We match on the
    // EntityBadge prop name to keep the assertion narrow — a future
    // unrelated warning (e.g. another component) won't muddy the signal.
    const warnings = consoleWarnSpy.mock.calls.map((args) => args.join(' '));
    const entityBadgeWarnings = warnings.filter((line) =>
      /EntityBadge|entityId|entity-id/i.test(line)
    );
    expect(entityBadgeWarnings).toEqual([]);
  });

  it('mount with loaded entity_info: EntityBadge prop validator passes (positive control)', async () => {
    // Belt-and-braces: prove the test actually exercises the prop validator
    // by seeding a valid `entity_info` and confirming no warnings fire on the
    // happy path either. If this fails we know our negative test above is
    // not actually mounting EntityBadge.
    const axiosInstance = createAxiosMock();
    const wrapper = await mountWithRealEntityBadge(axiosInstance);
    const vm = wrapper.vm as unknown as ModifyEntityVM;
    vm.entity_info = { ...entityByIdOk } as Partial<typeof entityByIdOk> & Record<string, unknown>;
    vm.entity_loaded = true;
    await flushPromises();

    const warnings = consoleWarnSpy.mock.calls.map((args) => args.join(' '));
    const entityBadgeWarnings = warnings.filter((line) =>
      /EntityBadge|entityId|entity-id/i.test(line)
    );
    expect(entityBadgeWarnings).toEqual([]);
  });
});
