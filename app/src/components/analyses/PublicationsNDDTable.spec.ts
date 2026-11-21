import { describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';

const journal = vi.hoisted(
  () => 'American journal of human genetics and related neurodevelopmental fields'
);

vi.mock('@/api/publication', () => ({
  listPublicationsXlsx: vi.fn(),
  listPublications: vi.fn().mockResolvedValue({
    meta: [{ totalItems: 4690, currentPage: 1, totalPages: 469, executionTime: 0.27, fspec: [] }],
    data: [{ publication_id: 'PMID:1', Title: 'A title', Journal: journal }],
  }),
}));

import PublicationsNDDTable from './PublicationsNDDTable.vue';

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return { ...actual, useToast: () => ({ makeToast: vi.fn() }) };
});

async function mountTable() {
  setActivePinia(createPinia());
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/PublicationsNDD', component: { template: '<div />' } }],
  });
  await router.push('/PublicationsNDD');
  await router.isReady();
  const wrapper = mount(PublicationsNDDTable, {
    global: {
      plugins: [router],
      directives: { 'b-tooltip': {} },
      stubs: {
        AnalysisPanel: {
          props: ['title', 'description'],
          template: '<section><p class="desc">{{ description }}</p><slot /></section>',
        },
        TablePaginationControls: { template: '<nav />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        GenericTable: {
          props: ['items'],
          template:
            '<table><tr v-for="row in items" :key="row.publication_id"><td class="cell-Journal"><slot name="cell-Journal" :row="row" /></td></tr></table>',
        },
      },
    },
  });
  await flushPromises();
  await new Promise((r) => setTimeout(r, 50));
  await flushPromises();
  (wrapper.vm as unknown as { loading: boolean }).loading = false;
  await flushPromises();
  return wrapper;
}

describe('PublicationsNDDTable', () => {
  it('summarises the page as "Showing x–y of N" instead of developer timing text', async () => {
    const wrapper = await mountTable();
    expect(wrapper.get('.desc').text()).toBe('Showing 1–1 of 4,690');
  });

  it('shows the full journal name (CSS ellipsis) and keeps it reachable in a title', async () => {
    const wrapper = await mountTable();
    const badge = wrapper.get('.cell-Journal .journal-badge');
    expect(badge.attributes('title')).toBe(journal);
    expect(badge.text()).toBe(journal);
  });
});
