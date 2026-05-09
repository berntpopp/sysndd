import { mount, flushPromises } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { describe, expect, it, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/api/comparisons', () => ({
  getComparisonsMetadata: vi.fn().mockResolvedValue({
    last_full_refresh: '2026-02-07T22:20:22Z',
    last_refresh_status: 'success',
    last_refresh_error: null,
    sources_count: 7,
    rows_imported: 18132,
  }),
}));

import CurationComparisons from './CurationComparisons.vue';

function makeRouter() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/CurationComparisons',
        component: CurationComparisons,
        children: [
          {
            path: '',
            component: { template: '<div data-testid="route-child">Overlap child</div>' },
          },
          {
            path: 'Similarity',
            component: { template: '<div data-testid="route-child">Similarity child</div>' },
          },
          {
            path: 'Table',
            component: { template: '<div data-testid="route-child">Table child</div>' },
          },
        ],
      },
    ],
  });
  router.push('/CurationComparisons');
  return router;
}

describe('CurationComparisons shell', () => {
  it('uses one compact analysis frame with accessible tabs and metadata', async () => {
    const router = makeRouter();
    await router.isReady();

    const wrapper = mount(CurationComparisons, {
      global: {
        plugins: [router],
        stubs: {
          RouterView: { template: '<div data-testid="route-child">Overlap child</div>' },
        },
      },
    });
    await flushPromises();

    const frame = wrapper.get('[data-testid="curation-comparisons-frame"]');
    expect(frame.classes()).toContain('analysis-frame');
    expect(wrapper.findAll('.card')).toHaveLength(0);

    const tabs = wrapper.get('[aria-label="Curation comparison views"]');
    expect(tabs.text()).toContain('Overlap');
    expect(tabs.text()).toContain('Similarity');
    expect(tabs.text()).toContain('Table');

    const metadata = wrapper.get('[data-testid="comparisons-refresh-badge"]');
    expect(metadata.attributes('aria-label')).toContain('Last comparisons refresh');
    expect(metadata.classes()).toContain('analysis-meta-badge');
  });
});
