import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import GeneReviewsCoverage from './GeneReviewsCoverage.vue';
import type { GeneReviewCoverageResponse } from '@/api/genereviews';

// Bootstrap-Vue-Next components are registered globally by the app, not by the
// test harness. Stub the ones this view uses as simple passthroughs so the spec
// focuses on the view's data/behaviour rather than Bootstrap's table internals.
const passthrough = (tag = 'div') => ({ template: `<${tag}><slot /></${tag}>` });
const bootstrapStubs = {
  BContainer: passthrough(),
  BTable: {
    props: ['items', 'perPage', 'currentPage', 'stacked'],
    template: '<div class="b-table-stub"><slot /></div>',
  },
  BAlert: { template: '<div role="alert"><slot /></div>' },
  TablePaginationControls: {
    props: ['totalRows', 'currentPage', 'initialPerPage'],
    template: '<nav class="pager-stub" />',
  },
  BModal: passthrough(),
  BButton: { template: '<button><slot /></button>' },
  BBadge: passthrough('span'),
  BLink: { props: ['to', 'href'], template: '<a :href="href"><slot /></a>' },
  BFormCheckbox: { template: '<label><slot /></label>' },
  BFormInput: { props: ['debounce'], template: '<input />' },
  BFormSelect: { template: '<select><slot /></select>' },
  BFormGroup: passthrough(),
  GeneBadge: { props: ['symbol', 'hgncId'], template: '<span>{{ symbol }}</span>' },
  EntityBadge: { props: ['entityId'], template: '<span>{{ entityId }}</span>' },
};

function mountView() {
  return mount(GeneReviewsCoverage, {
    global: { stubs: bootstrapStubs },
  });
}

const sampleResponse: GeneReviewCoverageResponse = {
  meta: { include_live: false, total: 2, already_linked: 1, needs_attention: null },
  data: [
    {
      entity_id: 1,
      hgnc_id: 'HGNC:4586',
      symbol: 'GRIN2B',
      disease_ontology_name: 'GRIN2B disorder',
      already_linked: true,
      linked_pmid: 'PMID:20301494',
      linked_nbk_id: 'NBK1116',
      genereview_available: null,
      available_nbk_id: null,
      available_url: null,
      available_title: null,
      lookup_error: false,
      needs_attention: null,
    },
    {
      entity_id: 2,
      hgnc_id: 'HGNC:11122',
      symbol: 'SCN1A',
      disease_ontology_name: 'SCN1A disorder',
      already_linked: false,
      linked_pmid: null,
      linked_nbk_id: null,
      genereview_available: null,
      available_nbk_id: null,
      available_url: null,
      available_title: null,
      lookup_error: false,
      needs_attention: null,
    },
  ],
};

const mocks = vi.hoisted(() => ({
  getGeneReviewsCoverage: vi.fn(),
  exportGeneReviewsCoverageCsv: vi.fn(),
  attachGeneReview: vi.fn(),
  makeToast: vi.fn(),
}));

vi.mock('@/api/genereviews', () => ({
  getGeneReviewsCoverage: mocks.getGeneReviewsCoverage,
  exportGeneReviewsCoverageCsv: mocks.exportGeneReviewsCoverageCsv,
  attachGeneReview: mocks.attachGeneReview,
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: mocks.makeToast }),
}));

describe('GeneReviewsCoverage', () => {
  beforeEach(() => {
    mocks.getGeneReviewsCoverage.mockReset();
    mocks.exportGeneReviewsCoverageCsv.mockReset();
    mocks.attachGeneReview.mockReset();
    mocks.makeToast.mockReset();
    mocks.getGeneReviewsCoverage.mockResolvedValue(sampleResponse);
  });

  it('loads coverage on mount and exposes the gene rows', async () => {
    const wrapper = mountView();
    await flushPromises();

    expect(mocks.getGeneReviewsCoverage).toHaveBeenCalledWith({ include_live: false });
    expect(wrapper.vm.rows.map((r) => r.symbol)).toEqual(['GRIN2B', 'SCN1A']);
    // The shell renders the page heading regardless of the table body engine.
    expect(wrapper.text()).toContain('GeneReviews coverage');
  });

  it('filters rows by the not_linked status filter', async () => {
    const wrapper = mountView();
    await flushPromises();

    wrapper.vm.statusFilter = 'not_linked';
    await flushPromises();

    expect(wrapper.vm.filteredRows.map((r) => r.symbol)).toEqual(['SCN1A']);
  });

  it('re-requests coverage with include_live when toggled', async () => {
    const wrapper = mountView();
    await flushPromises();

    wrapper.vm.includeLive = true;
    await wrapper.vm.reload();
    await flushPromises();

    expect(mocks.getGeneReviewsCoverage).toHaveBeenLastCalledWith({ include_live: true });
  });

  it('exports the coverage CSV via the typed client', async () => {
    const blob = new Blob(['symbol,already_linked\n'], { type: 'text/csv' });
    mocks.exportGeneReviewsCoverageCsv.mockResolvedValue(blob);
    // jsdom lacks createObjectURL/revokeObjectURL — stub them.
    const createSpy = vi
      .spyOn(window.URL, 'createObjectURL')
      .mockReturnValue('blob:mock');
    const revokeSpy = vi.spyOn(window.URL, 'revokeObjectURL').mockImplementation(() => {});

    const wrapper = mountView();
    await flushPromises();

    await wrapper.vm.onExportCsv();
    await flushPromises();

    expect(mocks.exportGeneReviewsCoverageCsv).toHaveBeenCalledWith({ include_live: false });
    createSpy.mockRestore();
    revokeSpy.mockRestore();
  });

  it('attaches a GeneReviews reference and reloads coverage', async () => {
    mocks.attachGeneReview.mockResolvedValue({
      status: 200,
      message: 'OK. GeneReviews reference attached to entity.',
      entity_id: 2,
      review_id: 9,
      publication_id: 'PMID:20301494',
    });

    const wrapper = mountView();
    await flushPromises();

    wrapper.vm.openAttach(sampleResponse.data[1]);
    wrapper.vm.attachPmid = '20301494';
    await wrapper.vm.confirmAttach();
    await flushPromises();

    expect(mocks.attachGeneReview).toHaveBeenCalledWith({ entity_id: 2, pmid: '20301494' });
    // Initial mount + reload after attach = 2 coverage calls.
    expect(mocks.getGeneReviewsCoverage).toHaveBeenCalledTimes(2);
  });

  // CUR-01: all 4,200 rows rendered and every keystroke re-rendered them (7 s).
  it('pages the table 25 rows at a time and debounces the filter by 300 ms', async () => {
    const many = Array.from({ length: 60 }, (_, i) => ({
      ...sampleResponse.data[1],
      entity_id: i + 1,
      symbol: `G${i}`,
    }));
    mocks.getGeneReviewsCoverage.mockResolvedValue({ ...sampleResponse, data: many });
    const wrapper = mountView();
    await flushPromises();

    const table = wrapper.findComponent(bootstrapStubs.BTable);
    expect(table.props('perPage')).toBe(25);
    expect(table.props('currentPage')).toBe(1);
    expect(table.props('stacked')).toBe('md');
    expect(wrapper.findComponent(bootstrapStubs.TablePaginationControls).props('totalRows')).toBe(60);
    expect(Number(wrapper.findComponent(bootstrapStubs.BFormInput).props('debounce'))).toBe(300);
  });

  // CUR-15: a stale "8 of 4200" during the 19 s live check, and one warning per row.
  it('says it is checking NCBI while loading and summarises lookup failures once', async () => {
    let finish!: (v: GeneReviewCoverageResponse) => void;
    const wrapper = mountView();
    await flushPromises();
    mocks.getGeneReviewsCoverage.mockReturnValue(new Promise((r) => (finish = r)));
    wrapper.vm.includeLive = true;
    const pending = wrapper.vm.reload();
    await flushPromises();
    expect(wrapper.text()).toContain('Checking NCBI');

    const failed = sampleResponse.data.map((row) => ({ ...row, lookup_error: true }));
    finish({ ...sampleResponse, data: failed });
    await pending;
    await flushPromises();
    const alerts = wrapper.findAll('[role="alert"]');
    expect(alerts).toHaveLength(1);
    expect(alerts[0].text()).toContain('2 of 2');
  });
});
