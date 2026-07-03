import { beforeEach, describe, expect, it, vi } from 'vitest';
import { nextTick, reactive } from 'vue';
import { usePhenotypeClusterTable } from './usePhenotypeClusterTable';

const mocks = vi.hoisted(() => ({
  makeToast: vi.fn(),
  exportToExcel: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: mocks.makeToast }),
}));

vi.mock('@/composables', () => ({
  useExcelExport: () => ({ isExporting: false, exportToExcel: mocks.exportToExcel }),
}));

function makeProps(cluster: Record<string, unknown[]>) {
  return reactive({
    selectedCluster: {
      quali_inp_var: [],
      quali_sup_var: [],
      quanti_sup_var: [],
      ...cluster,
    },
    loading: false,
    activeCluster: '1',
  });
}

describe('usePhenotypeClusterTable', () => {
  beforeEach(() => {
    mocks.makeToast.mockClear();
    mocks.exportToExcel.mockClear();
  });

  it('exposes flat de-dotted field keys (variable / p_value / v_test)', () => {
    const { fields } = usePhenotypeClusterTable(makeProps({}));
    expect(fields.map((f) => f.key)).toEqual(['variable', 'p_value', 'v_test']);
  });

  it('paginates displayedItems by perPage and page', () => {
    const rows = Array.from({ length: 12 }, (_, i) => ({ variable: `HP:${i}`, p_value: i, v_test: i }));
    const t = usePhenotypeClusterTable(makeProps({ quali_inp_var: rows }));

    expect(t.displayedItems.value).toHaveLength(10);
    t.handlePageChange(2);
    expect(t.displayedItems.value).toHaveLength(2);
  });

  it('applies the global "any" filter to displayedItems', () => {
    const rows = [{ variable: 'HP:0001' }, { variable: 'HP:0002' }];
    const t = usePhenotypeClusterTable(makeProps({ quali_inp_var: rows }));

    t.filter.any.content = 'hp:0002';
    expect(t.displayedItems.value).toHaveLength(1);
    expect(t.displayedItems.value[0].variable).toBe('HP:0002');
  });

  it('toasts instead of exporting when there is no data', () => {
    const { downloadExcel } = usePhenotypeClusterTable(makeProps({}));
    downloadExcel();
    expect(mocks.makeToast).toHaveBeenCalledWith('No data to export', 'Warning', 'warning');
    expect(mocks.exportToExcel).not.toHaveBeenCalled();
  });

  it('exports rows with a contextual filename derived from the active cluster', () => {
    const rows = [{ variable: 'Age', p_value: 0.01, v_test: 3 }];
    const { downloadExcel } = usePhenotypeClusterTable(makeProps({ quali_inp_var: rows }));

    downloadExcel();
    expect(mocks.exportToExcel).toHaveBeenCalledTimes(1);
    const [data, opts] = mocks.exportToExcel.mock.calls[0];
    expect(data).toHaveLength(1);
    expect(opts.filename).toBe('sysndd_phenotype_cluster_1_quali_inp_var');
  });

  it('tracks the unfiltered row count and resets the page on a table-type change', async () => {
    const t = usePhenotypeClusterTable(
      makeProps({ quali_inp_var: [{ variable: 'a' }, { variable: 'b' }], quali_sup_var: [{ variable: 'x' }] })
    );
    t.handlePageChange(3);

    t.tableType.value = 'quali_sup_var';
    await nextTick();

    expect(t.totalRows.value).toBe(1);
    expect(t.currentPage.value).toBe(1);
  });
});
