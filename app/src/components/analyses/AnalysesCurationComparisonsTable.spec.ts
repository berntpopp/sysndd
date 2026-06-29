import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';

import AnalysesCurationComparisonsTable from './AnalysesCurationComparisonsTable.vue';

// Keep the real composables (notably useUrlParsing, which serialises the filter
// object the coordinator keys on) but stub useToast — bootstrap-vue-next's toast
// registry is not installed in this lightweight mount.
vi.mock('@/composables', async () => {
  const actual = await vi.importActual<typeof import('@/composables')>('@/composables');
  return {
    ...actual,
    useToast: () => ({ makeToast: vi.fn() }),
  };
});

// Controllable mock of the comparisons API client so we can resolve overlapping
// requests in a chosen order and assert the stale one is discarded.
const browseComparisons = vi.fn();
vi.mock('@/api/comparisons', () => ({
  browseComparisons: (...args: unknown[]) => browseComparisons(...args),
  browseComparisonsXlsx: vi.fn(),
}));

interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void;
  args: { filter?: string };
}

let pending: Deferred<unknown>[] = [];

function makeResponse(symbols: string[]) {
  return {
    data: symbols.map((symbol, index) => ({ symbol, hgnc_id: index + 1, SysNDD: 'Definitive' })),
    meta: [
      {
        totalItems: symbols.length,
        currentPage: 1,
        totalPages: 1,
        prevItemID: 0,
        currentItemID: 0,
        nextItemID: 0,
        lastItemID: 0,
        executionTime: 1,
        fspec: [],
      },
    ],
  };
}

const mountedWrappers: VueWrapper[] = [];

async function mountSubject() {
  setActivePinia(createPinia());
  const wrapper = mount(AnalysesCurationComparisonsTable, {
    global: {
      directives: { 'b-tooltip': {}, 'b-popover': {} },
      stubs: {
        TableShell: { template: '<section><slot name="toolbar" /><slot /></section>' },
        TableLoadingState: { template: '<div />' },
        TablePaginationControls: { template: '<nav />' },
        TableDownloadLinkCopyButtons: { template: '<div />' },
        InlineHelpBadge: { template: '<span />' },
        CurationComparisonMobileRows: { template: '<div />' },
        CategoryIcon: { template: '<span />' },
        GeneBadge: { template: '<a>{{ symbol }}</a>', props: ['symbol'] },
        GenericTable: {
          props: ['items'],
          template:
            '<table><tbody><tr v-for="row in items" :key="row.symbol"><td>{{ row.symbol }}</td></tr></tbody></table>',
        },
        BPopover: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormCheckbox: { template: '<label><slot /></label>' },
        BFormInput: { inheritAttrs: false, props: ['modelValue'], template: '<input />' },
        BFormSelect: {
          inheritAttrs: false,
          props: ['modelValue', 'options'],
          template: '<select />',
        },
        BFormSelectOption: { template: '<option><slot /></option>' },
      },
    },
  });
  mountedWrappers.push(wrapper);
  await flushPromises();
  // Drain any initial-load requests with empty data.
  for (let i = 0; i < 10 && pending.length > 0; i += 1) {
    const batch = pending;
    pending = [];
    batch.forEach((d) => d.resolve(makeResponse([])));
    await flushPromises();
  }
  pending = [];
  return wrapper;
}

beforeEach(() => {
  pending = [];
  browseComparisons.mockReset();
  browseComparisons.mockImplementation((args: { filter?: string }) => {
    let resolve!: (value: unknown) => void;
    const promise = new Promise<unknown>((res) => {
      resolve = res;
    });
    pending.push({ promise, resolve, args });
    return promise;
  });
});

afterEach(() => {
  mountedWrappers.splice(0).forEach((wrapper) => wrapper.unmount());
  vi.restoreAllMocks();
});

describe('AnalysesCurationComparisonsTable', () => {
  it('discards a stale earlier response so it cannot overwrite the current filtered result', async () => {
    // Regression: with no request coordination, an earlier request could
    // resolve AFTER a newer one and clobber the table — the reported
    // "filter to a gene, then it reverts to something else" behaviour.
    const wrapper = await mountSubject();
    const vm = wrapper.vm as unknown as {
      filter: Record<string, { content: string | string[] | null }>;
      items: Array<{ symbol: string }>;
    };

    // Fire an earlier request (STALE), then a newer one (CURRENT).
    vm.filter.any.content = 'STALE';
    await flushPromises();
    vm.filter.any.content = 'CURRENT';
    await flushPromises();

    const staleReq = pending.find((d) => (d.args.filter || '').includes('STALE'));
    const currentReq = pending.find((d) => (d.args.filter || '').includes('CURRENT'));
    expect(staleReq).toBeTruthy();
    expect(currentReq).toBeTruthy();

    // The current (newer) request resolves first -> table shows the filtered row.
    currentReq!.resolve(makeResponse(['CURRENT_GENE']));
    await flushPromises();
    expect(vm.items.map((row) => row.symbol)).toEqual(['CURRENT_GENE']);

    // The stale (earlier) request resolves later -> must be dropped, not applied.
    staleReq!.resolve(makeResponse(['STALE_GENE_A', 'STALE_GENE_B']));
    await flushPromises();
    expect(vm.items.map((row) => row.symbol)).toEqual(['CURRENT_GENE']);
  });
});
