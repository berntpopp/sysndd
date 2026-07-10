// ManageReReview.spec.ts
/**
 * Shell-level spec for ManageReReview.vue (#346 WP9 decomposition).
 *
 * After WP9 the view is a thin orchestration shell: the workflow state, loaders,
 * and actions live in `useManageReReview` (covered exhaustively by
 * `composables/useManageReReview.spec.ts` — nine endpoint calls, scalar-array
 * unwrap, selection validation, fallback copy, refresh side effects, and the
 * recalculation field-omission), the table/toolbar lives in
 * `ReReviewAssignmentTable`, and the reassign/recalculate modals live in
 * `ReReviewBatchDialogs`.
 *
 * This spec therefore covers only what the shell itself owns:
 *   - the `onMounted` wiring fires all four loaders,
 *   - the (unchanged) manual entity-assignment panel renders loaded state,
 *   - the gene-atomic boundary-gene alert renders/hides (issue #29).
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import useAuth from '@/composables/useAuth';

// Composable mocks — `useToast`/`useAriaLive` both require a BApp provider we
// don't mount. `vi.mock` is hoisted above the imports below.
vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
  useAriaLive: () => ({
    message: { value: '' },
    politeness: { value: 'polite' },
    announce: vi.fn(),
  }),
}));

// Router mock — `src/plugins/axios.ts` imports `@/router` at module load.
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/curate/manage-re-review' } },
  },
}));

import '@/plugins/axios';
import '@/api/client';
import ManageReReview from '@/views/curate/ManageReReview.vue';

const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

// ---------------------------------------------------------------------------
// Mount helper — stubs Bootstrap-Vue-Next and the two extracted child
// components (table + dialogs), but keeps the (unchanged) manual assignment
// panel rendering so its loaded-state output can be asserted.
// ---------------------------------------------------------------------------
const mountManageReReview = async (): Promise<VueWrapper> => {
  const wrapper = mount(ManageReReview, {
    global: {
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BButtonGroup: { template: '<div><slot /></div>' },
        BBadge: { template: '<span><slot /></span>' },
        BTooltip: { template: '' },
        BSpinner: { template: '<div role="status" />' },
        BTable: {
          name: 'BTable',
          props: ['items', 'fields', 'tbodyTrClass', 'busy'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id"><td><slot name="cell(selected)" :item="item" /></td><td><slot name="cell(entity_id)" :item="item" /></td><td>{{ item.gene_symbol }}</td><td><slot name="cell(disease_ontology_name)" :item="item" /></td></tr></tbody></table>',
        },
        BFormInput: {
          props: ['modelValue', 'type', 'placeholder', 'id', 'size', 'min', 'max'],
          template: '<input />',
        },
        BFormSelect: {
          props: ['modelValue', 'options', 'size', 'id', 'ariaLabel'],
          template: '<select><slot /></select>',
        },
        BFormSelectOption: { props: ['value'], template: '<option><slot /></option>' },
        BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
        BAlert: {
          props: ['variant', 'show'],
          template: '<div :data-variant="variant"><slot /></div>',
        },
        // Child components stubbed — covered by their own specs.
        BatchCriteriaForm: { template: '<div />' },
        AriaLiveRegion: { template: '<div />' },
        IconLegend: { template: '<div />' },
        RefusedReReviewPanel: { template: '<div data-testid="refused-panel" />' },
        ReReviewAssignmentTable: { template: '<div data-testid="assignment-table" />' },
        ReReviewBatchDialogs: { template: '<div data-testid="batch-dialogs" />' },
      },
    },
  });
  await flushPromises();
  return wrapper;
};

interface ManageReReviewVm {
  activeBatchMode: 'criteria' | 'manual' | null;
  selectedEntityIds: number[];
  previewBoundaryGene: string | null;
  previewGeneCount: number;
  previewEntityCount: number;
}
const vm = (wrapper: VueWrapper): ManageReReviewVm => wrapper.vm as unknown as ManageReReviewVm;

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

describe('ManageReReview.vue — shell mount wiring', () => {
  it('fires all four mount loaders via the controller initialize()', async () => {
    primeAuth();
    let userList = false;
    let table = false;
    let entities = false;
    let status = false;
    server.use(
      http.get('*/api/user/list', () => {
        userList = true;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/assignment_table', () => {
        table = true;
        return HttpResponse.json([]);
      }),
      http.get('*/api/re_review/entities/available', () => {
        entities = true;
        return HttpResponse.json({ data: [], meta: { total: 0 } });
      }),
      http.get('*/api/list/status', () => {
        status = true;
        return HttpResponse.json({ data: [] });
      })
    );

    await mountManageReReview();
    await flushPromises();

    expect(userList).toBe(true);
    expect(table).toBe(true);
    expect(entities).toBe(true);
    expect(status).toBe(true);
  });
});

describe('ManageReReview.vue — manual entity assignment panel', () => {
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
    vm(wrapper).activeBatchMode = 'manual';
    vm(wrapper).selectedEntityIds = [11];
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Manual pick');
    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('ARID1B disorder');
    expect(wrapper.text()).toContain('Showing 1 of 4 available entities.');
    expect(wrapper.text()).toContain('Assign 1 selected');
  });
});

describe('ManageReReview.vue — gene-atomic boundary-gene alert (issue #29)', () => {
  it('hides the alert when previewBoundaryGene is null', async () => {
    primeAuth();
    const wrapper = await mountManageReReview();
    vm(wrapper).activeBatchMode = 'manual';
    vm(wrapper).previewBoundaryGene = null;
    vm(wrapper).previewGeneCount = 0;
    vm(wrapper).previewEntityCount = 0;
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(false);
  });

  it('renders the alert when previewBoundaryGene is non-null', async () => {
    primeAuth();
    const wrapper = await mountManageReReview();
    vm(wrapper).activeBatchMode = 'manual';
    vm(wrapper).previewBoundaryGene = 'HGNC:4585';
    vm(wrapper).previewGeneCount = 2;
    vm(wrapper).previewEntityCount = 6;
    await wrapper.vm.$nextTick();

    const alert = wrapper.find('[data-testid="batch-boundary-gene-alert"]');
    expect(alert.exists()).toBe(true);
    expect(alert.text()).toContain('HGNC:4585');
    expect(alert.text()).toContain('6 entities');
  });
});
