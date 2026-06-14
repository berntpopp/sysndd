import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import PubtatorNDDGenes from './PubtatorNDDGenes.vue';
import { server } from '@/test-utils/mocks/server';

const makeToastSpy = vi.fn();
const exportToExcelSpy = vi.fn().mockResolvedValue(undefined);

vi.mock('@/composables/useExcelExport', async () => {
  const { ref } = await import('vue');
  return {
    useExcelExport: () => ({
      isExporting: ref(false),
      exportToExcel: exportToExcelSpy,
    }),
  };
});

vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  const { ref, computed } = await import('vue');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
    useTableData: (opts: { pageSizeInput: number; sortInput: string; pageAfterInput: string }) => ({
      items: ref([]),
      totalRows: ref(0),
      perPage: ref(opts.pageSizeInput),
      currentPage: ref(1),
      sortBy: ref([]),
      sort: ref(opts.sortInput),
      loading: ref(false),
      isBusy: ref(false),
      downloading: ref(false),
      currentItemID: ref(Number(opts.pageAfterInput) || 0),
      prevItemID: ref(null),
      nextItemID: ref(null),
      lastItemID: ref(null),
      filter_string: ref(''),
      pageOptions: ref([10, 25, 50]),
      removeFiltersButtonTitle: computed(() => 'Remove filters'),
      removeFiltersButtonVariant: computed(() => 'outline-secondary'),
    }),
  };
});

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/analyses/pubtator-genes', component: { template: '<div />' } }],
  });
}

async function mountSubject(props = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/analyses/pubtator-genes');
  await router.isReady();

  const wrapper = mount(PubtatorNDDGenes, {
    props,
    global: {
      plugins: [router],
      directives: { 'b-tooltip': {} },
      stubs: {
        AnalysisPanel: {
          template:
            '<section><h2>{{ title }}</h2><p>{{ description }}</p><slot name="actions" /><slot /></section>',
          props: ['title', 'description'],
        },
        InlineHelpBadge: { template: '<button />' },
        BPopover: { template: '<div><slot name="title" /><slot /></div>' },
        BSpinner: { template: '<div data-testid="spinner" />' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BContainer: { template: '<div><slot /></div>' },
        BInputGroup: { template: '<label><slot /></label>' },
        BFormSelect: {
          inheritAttrs: false,
          props: ['options', 'modelValue'],
          template: '<select @change="$emit(\'change\')"><slot /></select>',
        },
        TableSearchInput: {
          template:
            '<input aria-label="table-search" @input="$emit(\'input\', $event.target.value)" />',
        },
        TablePaginationControls: {
          template:
            '<nav><button data-testid="next-page" @click="$emit(\'page-change\', 2)">next</button><button data-testid="per-page" @click="$emit(\'per-page-change\', 25)">25</button></nav>',
        },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        GeneBadge: { template: '<a :href="linkTo">{{ symbol }}</a>', props: ['symbol', 'linkTo'] },
        BBadge: { template: '<span><slot /></span>' },
        BAlert: { template: '<div class="b-alert"><slot /></div>' },
        BButton: {
          template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
          props: ['disabled'],
        },
        BFormInput: { template: '<input />' },
        BTable: {
          props: ['items'],
          emits: ['update:sort-by'],
          template:
            '<table><tbody><template v-for="item in items" :key="item.gene_symbol"><tr><td>{{ item.gene_symbol }}</td><td>{{ item.gene_name }}</td><td>{{ item.publication_count }}</td><td><slot name="cell(background_count)" :item="item" /></td><td><slot name="cell(enrichment_ratio)" :item="item" /></td><td><slot name="cell(fdr_bh)" :item="item" /></td><td>{{ item.oldest_pub_date }}</td><td>{{ item.is_novel === 1 ? "Literature Only" : "Curated" }}</td><td>{{ item.pmids }}</td><td><slot name="cell(actions)" :item="item" :expansion-showing="false" :toggle-expansion="() => {}" /></td></tr><tr><td colspan="10"><slot name="row-expansion" :item="item" /></td></tr></template></tbody></table>',
        },
      },
    },
  });
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  exportToExcelSpy.mockClear();
  vi.stubEnv('VITE_URL', 'https://sysndd.test');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('PubtatorNDDGenes', () => {
  it('loads gene rows with cursor params and emits the novel count', async () => {
    let observed: URLSearchParams | null = null;
    server.use(
      http.get('/api/publication/pubtator/genes', ({ request }) => {
        observed = new URL(request.url).searchParams;
        return HttpResponse.json({
          meta: [{ totalItems: 2, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            {
              gene_symbol: 'MECP2',
              gene_name: 'methyl CpG binding protein 2',
              publication_count: 4,
              oldest_pub_date: '2001-01-01',
              is_novel: 1,
              pmids: '123,456',
            },
            {
              gene_symbol: 'SCN2A',
              gene_name: 'sodium channel',
              publication_count: 9,
              oldest_pub_date: '1999-01-01',
              is_novel: 0,
              pmids: '789',
            },
          ],
        });
      })
    );

    const wrapper = await mountSubject();

    expect(wrapper.text()).toContain('MECP2');
    expect(wrapper.text()).toContain('Literature Only');
    expect(wrapper.emitted('novel-count')?.at(-1)).toEqual([1]);
    // issue #175: default ranking is enrichment-based, not raw count.
    expect((observed as URLSearchParams).get('sort')).toBe(
      '-enrichment_ratio,-npmi,publication_count'
    );
    expect((observed as URLSearchParams).get('page_size')).toBe('10');
    expect((observed as URLSearchParams).get('format')).toBe('json');
  });

  it('renders normalized enrichment metrics and separates true NDD genes from noise', async () => {
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 2, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            {
              gene_symbol: 'GRIN2B',
              gene_name: 'glutamate receptor',
              publication_count: 86,
              background_count: 13459,
              enrichment_ratio: 17.6,
              npmi: 0.32,
              fisher_p: 1e-40,
              fdr_bh: 1e-38,
              is_novel: 0,
              pmids: '1,2',
            },
            {
              gene_symbol: 'TP53',
              gene_name: 'tumor protein p53',
              publication_count: 8,
              background_count: 282103,
              enrichment_ratio: 0.08,
              npmi: -0.2,
              fisher_p: 0.9,
              fdr_bh: 0.95,
              is_novel: 1,
              pmids: '3',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    const text = wrapper.text();
    // Background count is compacted (e.g. 13459 -> "13.5k", 282103 -> "282.1k").
    expect(text).toContain('13.5k');
    expect(text).toContain('282.1k');
    // Enrichment ratio rendered with the multiplication marker.
    expect(text).toContain('18×'); // 17.6 rounds to 18 for display
    // FDR significance: GRIN2B significant (stars), TP53 not significant (ns).
    expect(text).toContain('***');
    expect(text).toContain('ns');
  });

  it('loads expanded publication details through the PubTator table endpoint', async () => {
    let observed: URLSearchParams | null = null;
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            {
              gene_symbol: 'MECP2',
              gene_name: 'methyl CpG binding protein 2',
              publication_count: 2,
              oldest_pub_date: '2001-01-01',
              is_novel: 1,
              pmids: '123,456',
            },
          ],
        })
      ),
      http.get('/api/publication/pubtator/table', ({ request }) => {
        observed = new URL(request.url).searchParams;
        return HttpResponse.json({
          data: [
            {
              search_id: 1,
              pmid: 123,
              title: 'MECP2 paper',
              journal: 'Journal',
              date: '2001-01-01',
              score: 8,
              gene_symbols: 'MECP2',
              text_hl: 'MECP2 is linked to NDD.',
            },
          ],
        });
      })
    );

    const wrapper = await mountSubject();
    await wrapper
      .findAll('button')
      .find((button) => button.text().includes('Show'))!
      .trigger('click');
    await flushPromises();

    expect((observed as URLSearchParams).get('filter')).toBe('any(pmid,123,456)');
    expect((observed as URLSearchParams).get('page_size')).toBe('2');
    expect((observed as URLSearchParams).get('format')).toBe('json');
    expect(wrapper.text()).toContain('MECP2 paper');
  });

  it('exports visible rows with stable headers and toast behavior', async () => {
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            {
              gene_symbol: 'MECP2',
              gene_name: 'methyl CpG binding protein 2',
              publication_count: 2,
              oldest_pub_date: '2001-01-01',
              is_novel: 1,
              pmids: '123,456',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    await wrapper
      .findAll('button')
      .find((button) => button.text().includes('Export'))!
      .trigger('click');
    await flushPromises();

    expect(exportToExcelSpy).toHaveBeenCalledWith(
      [
        expect.objectContaining({
          gene_symbol: 'MECP2',
          gene_name: 'methyl CpG binding protein 2',
          publication_count: 2,
          oldest_pub_date: '2001-01-01',
          source: 'Literature Only',
          pmids: '123,456',
        }),
      ],
      expect.objectContaining({
        sheetName: 'Gene Prioritization',
        headers: expect.objectContaining({
          gene_symbol: 'Gene Symbol',
          pmids: 'PMIDs',
          enrichment_ratio: 'Enrichment Ratio',
          fdr_bh: 'FDR (BH q-value)',
        }),
      })
    );
    expect(makeToastSpy).toHaveBeenCalledWith('Excel file downloaded', 'Success', 'success');
  });

  it('shows a freshness notice when the API reports a stale/missing ranking', async () => {
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [
            {
              totalItems: 1,
              totalPages: 1,
              currentPage: 1,
              currentItemID: 0,
              fspec: [],
              enrichmentStatus: 'missing',
            },
          ],
          data: [
            {
              gene_symbol: 'MECP2',
              gene_name: 'methyl CpG binding protein 2',
              publication_count: 2,
              is_novel: 1,
              pmids: '123',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    expect(wrapper.find('.b-alert').exists()).toBe(true);
    expect(wrapper.text()).toContain('Gene ranking not yet computed');
  });

  it('renders no freshness notice when the meta fields are absent (defensive)', async () => {
    server.use(
      http.get('/api/publication/pubtator/genes', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, totalPages: 1, currentPage: 1, currentItemID: 0, fspec: [] }],
          data: [
            {
              gene_symbol: 'MECP2',
              gene_name: 'methyl CpG binding protein 2',
              publication_count: 2,
              is_novel: 1,
              pmids: '123',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    expect(wrapper.find('.b-alert').exists()).toBe(false);
  });
});
