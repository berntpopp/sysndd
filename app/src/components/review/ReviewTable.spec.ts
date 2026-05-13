import { mount } from '@vue/test-utils';
import { h } from 'vue';
import { describe, expect, it } from 'vitest';
import ReviewTable from './ReviewTable.vue';

const passthrough = {
  template: '<div><slot /></div>',
};

describe('ReviewTable', () => {
  it('passes filtered, sorted, paginated rows to mobile row slot', () => {
    const wrapper = mount(ReviewTable, {
      props: {
        title: 'Approve Reviews',
        items: [
          { entity_id: 1, symbol: 'ZZZ', disease: 'other' },
          { entity_id: 2, symbol: 'AAA', disease: 'match' },
          { entity_id: 3, symbol: 'CCC', disease: 'match' },
        ],
        fields: [{ key: 'symbol', label: 'Gene' }],
        totalRows: 2,
        currentPage: 1,
        perPage: 1,
        pageOptions: [1, 10],
        sortBy: [{ key: 'symbol', order: 'desc' }],
        filterText: 'match',
        categoryOptions: [{ value: null, text: 'All Categories' }],
        userOptions: [{ value: null, text: 'All Users' }],
        legendItems: [],
      },
      slots: {
        'mobile-rows': ({ items }) =>
          h(
            'div',
            { 'data-testid': 'mobile-symbols' },
            items.map((item) => (item as { symbol: string }).symbol).join(',')
          ),
      },
      global: {
        stubs: {
          BBadge: passthrough,
          BButton: passthrough,
          BCol: passthrough,
          BFormInput: passthrough,
          BFormSelect: passthrough,
          BInputGroup: passthrough,
          BInputGroupText: passthrough,
          BPagination: passthrough,
          BRow: passthrough,
          BSpinner: passthrough,
          BTable: passthrough,
          IconLegend: passthrough,
        },
      },
    });

    expect(wrapper.get('[data-testid="mobile-symbols"]').text()).toBe('CCC');
  });
});
