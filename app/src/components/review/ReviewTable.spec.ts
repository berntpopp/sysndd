import { mount } from '@vue/test-utils';
import { h } from 'vue';
import { describe, expect, it } from 'vitest';
import ReviewTable from './ReviewTable.vue';

const passthrough = {
  template: '<div><slot /></div>',
};

const formInputStub = {
  props: ['modelValue', 'size'],
  template: '<input v-bind="$attrs" />',
};
const formSelectStub = {
  props: ['modelValue', 'options', 'size'],
  template: '<select v-bind="$attrs" />',
};
const paginationStub = {
  props: ['limit'],
  template: '<nav v-bind="$attrs" :data-limit="limit" />',
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
        pendingTotal: 2,
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

  it('names search, page-size, pagination, and filter controls', () => {
    const wrapper = mount(ReviewTable, {
      props: {
        title: 'Approve Reviews',
        items: [],
        fields: [{ key: 'symbol', label: 'Gene' }],
        totalRows: 0,
        pendingTotal: 0,
        currentPage: 1,
        perPage: 10,
        pageOptions: [10, 25],
        sortBy: [],
        categoryOptions: [{ value: null, text: 'All Categories' }],
        userOptions: [{ value: null, text: 'All Users' }],
        legendItems: [],
      },
      global: {
        stubs: {
          BBadge: passthrough,
          BButton: passthrough,
          BCol: passthrough,
          BFormInput: formInputStub,
          BFormSelect: formSelectStub,
          BInputGroup: passthrough,
          BInputGroupText: passthrough,
          BPagination: paginationStub,
          BRow: passthrough,
          BSpinner: passthrough,
          BTable: passthrough,
          IconLegend: passthrough,
        },
      },
    });

    expect(wrapper.get('input[aria-label="Search reviews"]')).toBeTruthy();
    expect(wrapper.get('select[aria-label="Rows per page"]')).toBeTruthy();
    expect(wrapper.get('nav[aria-label="Reviews pagination"]')).toBeTruthy();
    expect(wrapper.get('select[aria-label="Filter by category"]')).toBeTruthy();
    expect(wrapper.get('select[aria-label="Filter by user"]')).toBeTruthy();
    expect(wrapper.get('input[aria-label="Filter from date"]')).toBeTruthy();
    expect(wrapper.get('input[aria-label="Filter to date"]')).toBeTruthy();
  });

  // PUB-03: limit="2" hid the active page below sm; no page count anywhere.
  it('keeps the active page visible and states the page count', () => {
    const wrapper = mount(ReviewTable, {
      props: {
        title: 'Approve Reviews',
        items: [],
        fields: [{ key: 'symbol', label: 'Gene' }],
        totalRows: 42,
        pendingTotal: 42,
        currentPage: 2,
        perPage: 10,
        pageOptions: [10, 25],
        sortBy: [],
        categoryOptions: [{ value: null, text: 'All Categories' }],
        userOptions: [{ value: null, text: 'All Users' }],
        legendItems: [],
      },
      global: {
        stubs: {
          BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
          BFormInput: formInputStub,
          BFormSelect: formSelectStub,
          BInputGroup: passthrough,
          BInputGroupText: passthrough,
          BPagination: paginationStub,
          BSpinner: passthrough,
          IconLegend: passthrough,
          GenericTable: passthrough,
        },
      },
    });
    expect(wrapper.get('nav[aria-label="Reviews pagination"]').attributes('data-limit')).toBe('5');
    expect(wrapper.text()).toContain('Page 2 of 5');
    expect(wrapper.text()).toContain('Approve all 42');
  });

  // "Approve all" calls the server's approve/all, which ignores the table filters, so the
  // button must count every pending row, not the 3 left after filtering.
  it('counts every pending row on Approve all, not the filtered rows', () => {
    const wrapper = mount(ReviewTable, {
      props: {
        title: 'Approve Reviews',
        items: [],
        fields: [{ key: 'symbol', label: 'Gene' }],
        totalRows: 3,
        pendingTotal: 40,
        currentPage: 1,
        perPage: 10,
        pageOptions: [10, 25],
        sortBy: [],
        categoryOptions: [{ value: null, text: 'All Categories' }],
        userOptions: [{ value: null, text: 'All Users' }],
        legendItems: [],
      },
      global: {
        stubs: {
          BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
          BFormInput: formInputStub,
          BFormSelect: formSelectStub,
          BInputGroup: passthrough,
          BInputGroupText: passthrough,
          BPagination: paginationStub,
          BSpinner: passthrough,
          IconLegend: passthrough,
          GenericTable: passthrough,
        },
      },
    });
    expect(wrapper.text()).toContain('Approve all 40');
    expect(wrapper.text()).not.toContain('Approve all 3');
  });

  it('names the search box after the queue it filters', () => {
    const wrapper = mount(ReviewTable, {
      props: {
        title: 'Status Queue',
        totalRowsLabel: 'statuses',
        items: [],
        fields: [{ key: 'symbol', label: 'Gene' }],
        totalRows: 0,
        pendingTotal: 0,
        currentPage: 1,
        perPage: 10,
        pageOptions: [10],
        sortBy: [],
        categoryOptions: [{ value: null, text: 'All Categories' }],
        userOptions: [{ value: null, text: 'All Users' }],
        legendItems: [],
      },
      global: {
        stubs: {
          BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
          BFormInput: formInputStub,
          BFormSelect: formSelectStub,
          BInputGroup: passthrough,
          BInputGroupText: passthrough,
          BPagination: paginationStub,
          BSpinner: passthrough,
          IconLegend: passthrough,
          GenericTable: passthrough,
        },
      },
    });
    expect(wrapper.find('input[aria-label="Search statuses"]').exists()).toBe(true);
  });
});
