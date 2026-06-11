// ModifyEntity.combined.spec.ts
/**
 * View-level spec for the combined Status & Review workflow in ModifyEntity
 * (issues #36, #37).
 *
 * The orchestration logic is unit-tested in
 * `composables/__tests__/useCombinedStatusReview.spec.ts` and the panel UI in
 * `components/CombinedStatusReviewWorkflow.spec.ts`. This spec covers the
 * wiring the view owns:
 *   - the "Status & Review" action opens the combined workflow and loads both
 *     the review and the status for the selected entity
 *   - the direct-approval toggle visibility (`can-direct-approve`) reflects the
 *     authenticated user's role (Curator+ shows, Reviewer hides) — the
 *     frontend half of issue #37's role gating
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { http, HttpResponse } from 'msw';
import { bootstrapStubs } from '@/test-utils';
import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { useAuth, type UserPayload } from '@/composables/useAuth';
import ModifyEntity from './ModifyEntity.vue';
import { entityByIdOk } from '@/test-utils/mocks/data/entities';

const makeToastSpy = vi.fn();
const announceSpy = vi.fn();

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: makeToastSpy }),
  useColorAndSymbols: () => ({
    stoplights_style: {},
    ndd_icon_style: {},
    ndd_icon: {},
  }),
  useText: () => ({
    truncate: (s: string) => s,
    inheritance_short_text: {},
    empty_table_text: { all: 'No entities found' },
  }),
  useAriaLive: () => ({ message: '', politeness: 'polite', announce: announceSpy }),
}));

// Capture the props passed to the combined workflow so we can assert the
// role-gated `can-direct-approve` value without depending on TreeMultiSelect /
// bootstrap internals.
let capturedCombinedProps: Record<string, unknown> | null = null;
const CombinedWorkflowStub = {
  name: 'CombinedStatusReviewWorkflow',
  props: ['canDirectApprove', 'directApproval', 'review', 'formData', 'loading'],
  setup(props: Record<string, unknown>) {
    capturedCombinedProps = props;
    return () => null;
  },
};

const REVIEWER: UserPayload = {
  user_id: [2],
  user_name: ['rev'],
  email: ['rev@sysndd.local'],
  user_role: ['Reviewer'],
  user_created: ['2024-01-01'],
  abbreviation: ['RV'],
  orcid: [''],
  exp: [Math.floor(Date.now() / 1000) + 3600],
};

const mountView = async (): Promise<VueWrapper> => {
  const wrapper = mount(ModifyEntity, {
    global: {
      plugins: [createPinia()],
      mocks: {
        $route: { path: '/curate/modify-entity', name: 'ModifyEntity', params: {} },
        $router: { push: vi.fn() },
      },
      stubs: {
        ...bootstrapStubs,
        AriaLiveRegion: { template: '<div />' },
        ConfirmDiscardDialog: { template: '<div />' },
        InlineEntityWorkflow: { template: '<div />' },
        CombinedStatusReviewWorkflow: CombinedWorkflowStub,
        EntitySearchPanel: { template: '<div />' },
        EntityInfoHeader: { template: '<div />' },
        BButton: {
          props: ['disabled'],
          template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
        },
        BContainer: { template: '<div><slot /></div>' },
        BSpinner: { template: '<span role="status" />' },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

const seedEntity = async (wrapper: VueWrapper) => {
  const vm = wrapper.vm as unknown as Record<string, unknown> & {
    entity_info: Record<string, unknown>;
    entity_loaded: boolean;
  };
  vm.entity_info = { ...entityByIdOk };
  vm.entity_loaded = true;
  await flushPromises();
};

beforeEach(() => {
  capturedCombinedProps = null;
  makeToastSpy.mockClear();
  announceSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
  // Lookups + per-entity loads used by showCombinedModify.
  server.use(
    http.get('/api/list/status', () => HttpResponse.json([])),
    http.get('/api/list/phenotype', () => HttpResponse.json([])),
    http.get('/api/list/variation_ontology', () => HttpResponse.json([])),
    http.get('/api/entity/:id/review', () =>
      HttpResponse.json([{ review_id: 1, entity_id: entityByIdOk.entity_id, synopsis: 's' }])
    ),
    http.get('/api/entity/:id/phenotypes', () => HttpResponse.json([])),
    http.get('/api/entity/:id/variation', () => HttpResponse.json([])),
    http.get('/api/entity/:id/publications', () => HttpResponse.json([])),
    http.get('/api/entity/:id/status', () =>
      HttpResponse.json([
        { status_id: 5, entity_id: entityByIdOk.entity_id, category_id: 2, comment: '' },
      ])
    )
  );
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('ModifyEntity — combined Status & Review workflow (#36/#37)', () => {
  it('opens the combined workflow and renders the combined panel', async () => {
    primeAuth('admin-token');
    const wrapper = await mountView();
    await seedEntity(wrapper);

    await (wrapper.vm as unknown as { showCombinedModify: () => Promise<void> }).showCombinedModify();
    await flushPromises();

    expect((wrapper.vm as unknown as { activeWorkflow: string }).activeWorkflow).toBe('combined');
    expect(wrapper.findComponent(CombinedWorkflowStub).exists()).toBe(true);
    expect(capturedCombinedProps).not.toBeNull();
  });

  it('SHOWS the direct-approval toggle for an Administrator (Curator+)', async () => {
    primeAuth('admin-token'); // primeAuth defaults to Administrator
    const wrapper = await mountView();
    await seedEntity(wrapper);

    await (wrapper.vm as unknown as { showCombinedModify: () => Promise<void> }).showCombinedModify();
    await flushPromises();

    expect(capturedCombinedProps?.canDirectApprove).toBe(true);
  });

  it('HIDES the direct-approval toggle for a Reviewer (below Curator)', async () => {
    primeAuth('reviewer-token', REVIEWER);
    const wrapper = await mountView();
    await seedEntity(wrapper);

    await (wrapper.vm as unknown as { showCombinedModify: () => Promise<void> }).showCombinedModify();
    await flushPromises();

    expect(capturedCombinedProps?.canDirectApprove).toBe(false);
  });
});
