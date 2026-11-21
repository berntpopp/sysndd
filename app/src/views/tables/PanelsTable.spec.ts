import { shallowMount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { describe, expect, it, vi } from 'vitest';
import { browsePanels, browsePanelsXlsx } from '@/api/panels';
import PanelsTable from './PanelsTable.vue';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables', () => ({
  useToast: () => ({
    makeToast: vi.fn(),
  }),
}));

vi.mock('@/api/panels', () => ({
  getPanelOptions: vi.fn(() => new Promise(() => {})),
  browsePanels: vi.fn(),
  browsePanelsXlsx: vi.fn(),
}));

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  return { promise, resolve, reject };
}

function responseFor(symbol: string) {
  return {
    data: [{ symbol }],
    fields: [{ key: 'symbol', label: 'Symbol' }],
    meta: [
      {
        totalItems: 1,
        currentPage: 1,
        totalPages: 1,
        prevItemID: null,
        currentItemID: 0,
        nextItemID: null,
        lastItemID: null,
        executionTime: '10 ms',
      },
    ],
  };
}

function mountPanelsTable() {
  return shallowMount(PanelsTable, {
    global: {
      plugins: [createPinia()],
      directives: {
        bTooltip: {},
      },
      mocks: {
        $route: {
          params: {
            category_input: 'All',
            inheritance_input: 'All',
          },
        },
      },
    },
  });
}

describe('PanelsTable', () => {
  it('ignores stale browse responses when panel controls change quickly', async () => {
    const first = deferred<ReturnType<typeof responseFor>>();
    const second = deferred<ReturnType<typeof responseFor>>();
    vi.mocked(browsePanels).mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);

    const wrapper = mountPanelsTable();
    Object.assign(wrapper.vm, {
      selected_category: 'All',
      selected_inheritance: 'All',
      selected_columns: ['symbol'],
      perPage: 10,
      currentItemID: 0,
    });

    const firstRequest = wrapper.vm.requestSelected();
    const secondRequest = wrapper.vm.requestSelected();

    second.resolve(responseFor('SECOND'));
    await secondRequest;

    expect(wrapper.vm.items).toEqual([{ symbol: 'SECOND' }]);

    first.resolve(responseFor('FIRST'));
    await firstRequest;

    expect(wrapper.vm.items).toEqual([{ symbol: 'SECOND' }]);
  });

  it('sends the chosen columns with the Excel export', async () => {
    vi.mocked(browsePanelsXlsx).mockRejectedValueOnce(new Error('stop before download'));
    const wrapper = mountPanelsTable();
    Object.assign(wrapper.vm, { selected_columns: ['symbol', 'category'] });

    await wrapper.vm.requestExcel();

    expect(vi.mocked(browsePanelsXlsx).mock.calls[0][0]).toMatchObject({
      fields: 'symbol,category',
    });
  });

  it('counts the rows on screen and labels columns with their acronyms', async () => {
    const response = {
      data: ['A', 'B', 'C', 'D'].map((symbol) => ({
        symbol,
        inheritance: 'Autosomal dominant inheritance',
      })),
      fields: ['symbol', 'inheritance', 'hgnc_id', 'ucsc_id', 'bed_hg19'].map((key) => ({
        key,
        label: key,
      })),
      meta: [{ ...responseFor('A').meta[0], totalItems: 4 }],
    };
    vi.mocked(browsePanels).mockResolvedValueOnce(response);
    const wrapper = mountPanelsTable();
    Object.assign(wrapper.vm, { selected_columns: ['symbol'], perPage: 10, currentPage: 1 });

    await wrapper.vm.requestSelected();
    await wrapper.vm.$nextTick();

    const shell = wrapper.findComponent({ name: 'TableShell' });
    // Known bug 2: the header printed the page size ("Loaded 10/4").
    expect(shell.props('description')).toBe('Showing 1–4 of 4');
    expect(wrapper.vm.tableFields.map((f: { label: string }) => f.label)).toEqual([
      'Symbol',
      'Inheritance',
      'HGNC ID',
      'UCSC ID',
      'BED (hg19)',
    ]);
  });
});
