import { shallowMount } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { describe, expect, it, vi } from 'vitest';
import { browsePanels } from '@/api/panels';
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
});
