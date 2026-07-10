// PubtatorNDDTable.spec.ts
//
// Characterization spec for the thin SFC shell. All request/cache
// orchestration now lives in usePubtatorPublicationTable.ts (see its own
// spec); this file mounts the real component through a slot-forwarding
// GenericTable stub and asserts the publication data cells, the pmid
// "action" cell, and the row-expansion "detail" slot all render with the
// expected row props.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import PubtatorNDDTable from './PubtatorNDDTable.vue';
import { server } from '@/test-utils/mocks/server';

const makeToastSpy = vi.fn();

// Real bootstrap-vue-next toast requires its plugin/BApp; stub it like the
// sibling PubTator/table specs (PubtatorNDDGenes.spec.ts, TablesLogs.spec.ts).
vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: makeToastSpy }),
  };
});

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/analyses/pubtator-table', component: { template: '<div />' } },
      { path: '/Genes/:symbol', component: { template: '<div />' } },
    ],
  });
}

const genericTableStub = {
  props: ['items', 'fields', 'fieldDetails', 'sortBy', 'sortDesc'],
  emits: ['update-sort'],
  template: `
    <table class="generic-table-stub">
      <tbody>
        <tr v-for="(row, idx) in items" :key="row.search_id ?? idx" class="pub-row">
          <td class="cell-search_id"><slot name="cell-search_id" :row="row" :index="idx" /></td>
          <td class="cell-pmid"><slot name="cell-pmid" :row="row" :index="idx" /></td>
          <td class="cell-doi"><slot name="cell-doi" :row="row" :index="idx" /></td>
          <td class="cell-title"><slot name="cell-title" :row="row" :index="idx" /></td>
          <td class="cell-journal"><slot name="cell-journal" :row="row" :index="idx" /></td>
          <td class="cell-date"><slot name="cell-date" :row="row" :index="idx" /></td>
          <td class="cell-score"><slot name="cell-score" :row="row" :index="idx" /></td>
          <td class="cell-gene_symbols"><slot name="cell-gene_symbols" :row="row" :index="idx" /></td>
          <td class="cell-text_hl"><slot name="cell-text_hl" :row="row" :index="idx" /></td>
          <td class="row-expansion"><slot name="row-expansion" :row="row" /></td>
        </tr>
      </tbody>
    </table>
  `,
};

const bButtonStub = {
  props: ['href', 'disabled', 'size', 'variant'],
  template:
    '<a v-if="href" :href="href"><slot /></a><button v-else :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
};

async function mountSubject(props: Record<string, unknown> = {}) {
  setActivePinia(createPinia());
  const router = makeRouter();
  await router.push('/analyses/pubtator-table');
  await router.isReady();

  const wrapper = mount(PubtatorNDDTable, {
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
        BSpinner: { template: '<div data-testid="spinner" />' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BContainer: { template: '<div><slot /></div>' },
        TableSearchInput: {
          template: '<input aria-label="table-search" @input="$emit(\'input\')" />',
        },
        TablePaginationControls: { template: '<nav />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        BButton: bButtonStub,
        GenericTable: genericTableStub,
      },
    },
  });
  await flushPromises();
  // The composable clears the min-spinner-visible `loading` flag via a 500ms
  // setTimeout (independent of the data load); flip it directly rather than
  // pulling in fake timers for every test.
  (wrapper.vm as unknown as { loading: boolean }).loading = false;
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  vi.stubEnv('VITE_URL', 'https://sysndd.test');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('PubtatorNDDTable', () => {
  it('loads rows with the configured sort/fields cursor query parameters', async () => {
    let observed: URLSearchParams | null = null;
    server.use(
      http.get('/api/publication/pubtator/table', ({ request }) => {
        observed = new URL(request.url).searchParams;
        return HttpResponse.json({
          meta: [{ totalItems: 0, currentPage: 1, totalPages: 0, fspec: [] }],
          data: [],
        });
      })
    );

    await mountSubject();

    expect((observed as unknown as URLSearchParams).get('sort')).toBe('-search_id');
    expect((observed as unknown as URLSearchParams).get('page_size')).toBe('10');
    expect((observed as unknown as URLSearchParams).get('format')).toBe('json');
  });

  it('renders the publication data cells (title truncated, journal, date, score, doi, search_id) with the expected row props', async () => {
    const title = 'A very long publication title that certainly exceeds sixty characters in length';
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [
            {
              search_id: 42,
              pmid: 123456,
              doi: '10.1000/abcde',
              title,
              journal: 'Journal of Testing',
              date: '2020-01-01',
              score: 8.12345,
              gene_symbols: 'MECP2',
              text_hl: null,
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    const row = wrapper.get('.pub-row');

    expect(row.get('.cell-search_id').text()).toBe('42');
    // Utils.truncate(str, 60) -> first 57 chars + '...'
    expect(row.get('.cell-title').text()).toBe(`${title.substr(0, 57)}...`);
    expect(row.get('.cell-journal').text()).toBe('Journal of Testing');
    expect(row.get('.cell-date').text()).toBe('2020-01-01');
    // row.score.toFixed(3)
    expect(row.get('.cell-score').text()).toBe('8.123');
    const doiLink = row.get('.cell-doi a');
    expect(doiLink.attributes('href')).toBe('https://doi.org/10.1000/abcde');
    expect(doiLink.text()).toBe('10.1000/abcde');
  });

  it('renders the pmid action cell as a PubMed link with the expected row props', async () => {
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [{ search_id: 1, pmid: 987654, title: 'T', journal: 'J', date: '2021-01-01' }],
        })
      )
    );

    const wrapper = await mountSubject();
    const pmidLink = wrapper.get('.cell-pmid a');

    expect(pmidLink.attributes('href')).toBe('https://pubmed.ncbi.nlm.nih.gov/987654');
    expect(pmidLink.text()).toBe('987654');
  });

  it('renders up to 3 gene chips plus an overflow indicator for the gene_symbols cell', async () => {
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [
            {
              search_id: 1,
              pmid: 1,
              title: 'T',
              gene_symbols: 'MECP2, SCN2A, ARID1B, GRIN2B',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    const cell = wrapper.get('.cell-gene_symbols');
    const chips = cell.findAll('a.gene-chip');

    expect(chips.map((c) => c.text())).toEqual(['MECP2', 'SCN2A', 'ARID1B']);
    expect(chips[0].attributes('href')).toBe('/Genes/MECP2');
    expect(cell.get('.gene-chip-more').text()).toBe('+1');
  });

  it('shows a muted fallback when text_hl is absent', async () => {
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [{ search_id: 1, pmid: 1, title: 'T', text_hl: null }],
        })
      )
    );

    const wrapper = await mountSubject();
    expect(wrapper.get('.cell-text_hl').text()).toBe('No highlight text');
  });

  it('renders the row-expansion detail slot with PMID/date/journal and the annotated text', async () => {
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [
            {
              search_id: 1,
              pmid: 555,
              title: 'Detail title',
              journal: 'Detail journal',
              date: '2022-06-15',
              text_hl: '@GENE_1 @GENE_MECP2 @@@MECP2@@@ variants cause disease.',
            },
          ],
        })
      )
    );

    const wrapper = await mountSubject();
    const detail = wrapper.get('.row-expansion');

    expect(detail.text()).toContain('Detail title');
    expect(detail.text()).toContain('PMID:555');
    expect(detail.text()).toContain('2022-06-15');
    expect(detail.text()).toContain('Detail journal');
    // PubtatorAnnotatedText renders the parsed gene segment text.
    expect(detail.text()).toContain('MECP2');
    expect(detail.find('.pubtator-gene').exists()).toBe(true);
  });

  it('shows the "no annotated text" fallback in the detail slot when text_hl is absent', async () => {
    server.use(
      http.get('/api/publication/pubtator/table', () =>
        HttpResponse.json({
          meta: [{ totalItems: 1, currentPage: 1, totalPages: 1, fspec: [] }],
          data: [{ search_id: 1, pmid: 1, title: 'T', text_hl: null }],
        })
      )
    );

    const wrapper = await mountSubject();
    expect(wrapper.get('.row-expansion').text()).toContain('No annotated text available.');
  });
});
