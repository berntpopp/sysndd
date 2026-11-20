import { describe, expect, it } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import ReviewQueueTable from './ReviewQueueTable.vue';

function mountTable(props: Record<string, unknown> = {}) {
  return shallowMount(ReviewQueueTable, {
    props: {
      filteredItems: [],
      fields: [],
      totalRows: 0,
      legendItems: [],
      user: {},
      dateYearAge: () => '',
      ...props,
    },
    global: {
      stubs: {
        TableShell: {
          props: ['meta'],
          template: '<div><span class="meta">{{ meta }}</span><slot name="toolbar" /></div>',
        },
        BBadge: { template: '<span class="badge"><slot /></span>' },
      },
    },
  });
}

const newBatchShown = (props: Record<string, unknown>) =>
  mountTable(props).text().includes('New batch');

describe('ReviewQueueTable', () => {
  it('pluralises the row count (B17)', () => {
    expect(mountTable({ totalRows: 1 }).find('.meta').text()).toBe('1 entity');
    expect(mountTable({ totalRows: 2 }).find('.meta').text()).toBe('2 entities');
  });

  it('offers a new batch only when an empty queue is not caused by a filter (B16)', () => {
    expect(newBatchShown({})).toBe(true);
    expect(newBatchShown({ categoryFilter: 'Definitive' })).toBe(false);
    expect(newBatchShown({ userFilter: 'alice' })).toBe(false);
    expect(newBatchShown({ activeQuickFilters: ['pending'] })).toBe(false);
  });
});
