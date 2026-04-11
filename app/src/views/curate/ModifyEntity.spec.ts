// ModifyEntity.spec.ts
/**
 * Functional spec for the ModifyEntity curate view (Phase C unit C4).
 *
 * Scope (from .plans/v11.0/phase-c.md §3 Phase C.C4):
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

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { bootstrapStubs } from '@/test-utils';
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
    (): Promise<AxiosResponse> =>
      Promise.resolve({ data: {}, status: 200, statusText: 'OK' })
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
  });

  describe('happy path — rename entity disease', () => {
    it('POSTs /api/entity/rename, surfaces success, and clears the selection (cache invalidation)', async () => {
      const axiosMock = createAxiosMock();
      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      const vm = wrapper.vm as unknown as ModifyEntityVM;
      await vm.submitEntityRename();
      await flushPromises();

      // 1. Exactly one POST went to /api/entity/rename with a wrapped payload
      //    (`rename_json`) shaped by the submissionSubmission class.
      const renameCalls = axiosMock.post.mock.calls.filter((call) =>
        String(call[0]).endsWith('/api/entity/rename')
      );
      expect(renameCalls).toHaveLength(1);

      const [, payload] = renameCalls[0];
      expect(payload).toHaveProperty('rename_json');
      const renameJson = (payload as { rename_json: { entity: Record<string, unknown> } })
        .rename_json;
      expect(renameJson).toHaveProperty('entity');
      // The view mutates `entity_info.disease_ontology_id_version = ontology_input`
      // before wrapping — confirm the new ontology id is on the wire.
      expect(renameJson.entity).toMatchObject({
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
      const axiosMock = createAxiosMock();
      // Reject the rename POST with an axios-shaped 409 carrying the
      // conflict description from the B1 entity fixtures.
      const conflictError = Object.assign(new Error('Request failed with status code 409'), {
        isAxiosError: true,
        response: {
          status: 409,
          statusText: 'Conflict',
          data: entityCreateConflict,
        },
      });
      axiosMock.post.mockRejectedValueOnce(conflictError);

      const wrapper = await mountModifyEntity(axiosMock);
      await seedLoadedEntity(wrapper);

      const vm = wrapper.vm as unknown as ModifyEntityVM;
      await vm.submitEntityRename();
      await flushPromises();

      // 1. The rename POST was still attempted (otherwise the 409 never fires).
      const renameCalls = axiosMock.post.mock.calls.filter((call) =>
        String(call[0]).endsWith('/api/entity/rename')
      );
      expect(renameCalls).toHaveLength(1);

      // 2. makeToast was called with the error variant and the rejected
      //    axios error object (the view forwards `e` through to the toast
      //    composable, which typically renders `e.response.data.error`).
      const dangerToasts = makeToastSpy.mock.calls.filter((call) => call[2] === 'danger');
      expect(dangerToasts.length).toBeGreaterThanOrEqual(1);

      const dangerArg = dangerToasts[0][0] as {
        response?: { status?: number; data?: { error?: string } };
      };
      expect(dangerArg).toBeDefined();
      expect(dangerArg.response?.status).toBe(409);
      expect(dangerArg.response?.data?.error).toBe(entityCreateConflict.error);

      // 3. Screen reader was told the operation failed (assertive politeness).
      expect(announceSpy).toHaveBeenCalledWith('Failed to update disease name', 'assertive');

      // 4. On failure, the view does NOT resetForm — the selection must
      //    survive so the user can fix the input and retry. Verify the
      //    entity is still loaded post-failure.
      expect(vm.entity_loaded).toBe(true);
      expect(vm.entity_info).toMatchObject({ entity_id: entityByIdOk.entity_id });
    });
  });

  // Locked todo — Phase E will unpin this after wiring unsaved-changes guards
  // into the rename flow (the dialog is already imported at template level).
  it.todo('TODO: verify unsaved-changes warning on navigation');
});
