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

  it('disables Submit until the entity review is saved, and its tooltip follows (#708)', async () => {
    const tooltips: unknown[] = [];
    // Only the Submit wrapper is a <span>; the other tooltips sit on buttons.
    const record = (el: Element, binding: { value: unknown }) =>
      el.tagName === 'SPAN' && tooltips.push(binding.value);
    const props = (saved: number) => ({
      filteredItems: [{ entity_id: 1, re_review_review_saved: saved }],
      fields: [],
      totalRows: 1,
      legendItems: [],
      user: {},
      dateYearAge: () => '',
    });
    const wrapper = shallowMount(ReviewQueueTable, {
      props: props(0),
      global: {
        directives: { bTooltip: { mounted: record, updated: record } },
        stubs: {
          TableShell: { template: '<div><slot /></div>' },
          BTable: {
            props: ['items'],
            template:
              '<div><template v-for="(item, index) in items" :key="index">' +
              '<slot name="cell(actions)" :item="item" :index="index" /></template></div>',
          },
          BButton: { template: '<button><slot /></button>' },
        },
      },
    });
    const submitButton = () => wrapper.find('[aria-label="Submit review for sysndd:1"]');

    expect(submitButton().attributes('disabled')).toBeDefined();
    expect(tooltips).toContain('Save the entity review first (unchanged is fine), then submit');

    // The row is reused when the table reloads after a save: tooltip text must update too.
    await wrapper.setProps(props(1));
    expect(submitButton().attributes('disabled')).toBeUndefined();
    expect(tooltips.at(-1)).toBe('Submit entity review');
  });

  // S-12/S-13/CUR-10/CUR-24: unnamed per-page select, filtered-empty text with no
  // filter, and a legend title that fell through to BCard as an <h4>.
  it('names the per-page select, treats an empty search as no filter, and titles the legend', () => {
    const TableStub = { props: ['filter', 'emptyFilteredText'], template: '<div />' };
    const LegendStub = { props: ['title', 'legendItems'], template: '<div />' };
    const wrapper = shallowMount(ReviewQueueTable, {
      props: {
        filteredItems: [],
        fields: [],
        totalRows: 0,
        legendItems: [],
        user: {},
        dateYearAge: () => '',
        filter: '',
      },
      global: {
        stubs: {
          TableShell: { template: '<div><slot name="toolbar" /><slot /></div>' },
          BTable: TableStub,
          IconLegend: LegendStub,
          BFormSelect: { inheritAttrs: false, template: '<select v-bind="$attrs" />' },
        },
      },
    });
    const perPage = wrapper.get('#review-queue-per-page-select');
    expect(perPage.attributes('aria-label')).toBe('Rows per page');
    const table = wrapper.findComponent(TableStub);
    expect(table.props('filter')).toBeUndefined();
    expect(table.props('emptyFilteredText')).toBe('No entities match the current filters.');
    expect(wrapper.findComponent(LegendStub).props('title')).toBe('Category and review status');
  });
});
