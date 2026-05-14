import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import GenericTable from './GenericTable.vue';

const fields = [{ key: 'symbol', label: 'Gene', sortable: true }];
const items = [{ symbol: 'ARID1B' }];

const bTableStub = {
  name: 'BTable',
  props: ['stacked', 'fixed'],
  template:
    '<div data-testid="b-table" :data-stacked="String(stacked)" :data-fixed="String(fixed)"><slot /></div>',
};

describe('GenericTable responsive mode', () => {
  it('keeps the existing stacked md mode by default', () => {
    const wrapper = mount(GenericTable, {
      props: { items, fields, sortBy: 'symbol', sortDesc: false, isBusy: false },
      global: { stubs: { BTable: bTableStub } },
    });

    expect(wrapper.find('[data-testid="b-table"]').attributes('data-stacked')).toBe('md');
  });

  it('can disable Bootstrap stacked output for hybrid mobile layouts', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items,
        fields,
        sortBy: 'symbol',
        sortDesc: false,
        isBusy: false,
        stackedMode: false,
      },
      global: { stubs: { BTable: bTableStub } },
    });

    expect(wrapper.find('[data-testid="b-table"]').attributes('data-stacked')).toBe('false');
  });

  it('can opt out of fixed table layout for content-heavy public tables', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items,
        fields,
        sortBy: 'symbol',
        sortDesc: false,
        isBusy: false,
        fixedLayout: false,
      },
      global: { stubs: { BTable: bTableStub } },
    });

    expect(wrapper.find('[data-testid="b-table"]').attributes('data-fixed')).toBe('false');
  });
});
