import { mount } from '@vue/test-utils';
import { afterEach, describe, expect, it, vi } from 'vitest';
import GenericTable from './GenericTable.vue';

const fields = [{ key: 'symbol', label: 'Gene', sortable: true }];
const items = [{ symbol: 'ARID1B' }];

const bTableStub = {
  name: 'BTable',
  props: ['items', 'stacked', 'fixed'],
  template:
    '<div data-testid="b-table" :data-stacked="String(stacked)" :data-fixed="String(fixed)"><slot /><slot name="row-expansion" :item="items?.[0]" /></div>',
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

  it('renders fallback row details as horizontal label-value rows', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items: [{ hgnc_id: 'HGNC:60', disease_ontology_name: 'Cardiomyopathy, dilated, 1O' }],
        fields,
        fieldDetails: [
          { key: 'hgnc_id', label: 'HGNC ID' },
          { key: 'disease_ontology_name', label: 'Disease ontology name' },
        ],
      },
      global: {
        stubs: {
          BTable: bTableStub,
          BCard: { template: '<div><slot /></div>' },
        },
      },
    });

    const rows = wrapper.findAll('.generic-table-detail__row');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('HGNC ID');
    expect(rows[0].text()).toContain('HGNC:60');
    expect(wrapper.findAll('[data-testid="b-table"]')).toHaveLength(1);
  });

  it('uses readable full-width rows for long narrative detail fields', () => {
    const synopsis =
      'A long clinical synopsis with multiple findings, inheritance context, and publication-derived evidence.';
    const wrapper = mount(GenericTable, {
      props: {
        items: [{ synopsis, hgnc_id: 'HGNC:9100' }],
        fields,
        fieldDetails: [
          { key: 'hgnc_id', label: 'HGNC ID' },
          { key: 'synopsis', label: 'Clinical Synopsis' },
        ],
      },
      global: {
        stubs: {
          BTable: bTableStub,
          BCard: { template: '<div><slot /></div>' },
        },
      },
    });

    const longTextRow = wrapper.get('.generic-table-detail__row--long-text');
    expect(longTextRow.text()).toContain('Clinical Synopsis');
    expect(longTextRow.text()).toContain(synopsis);
  });

  it('copies long narrative detail values to the clipboard', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    const synopsis = 'Copyable clinical synopsis.';
    const wrapper = mount(GenericTable, {
      props: {
        items: [{ entity_id: 3373, synopsis }],
        fields,
        fieldDetails: [{ key: 'synopsis', label: 'Clinical Synopsis' }],
      },
      global: {
        stubs: {
          BTable: bTableStub,
          BCard: { template: '<div><slot /></div>' },
        },
      },
    });

    const button = wrapper.get('.generic-table-detail__copy-button');
    await button.trigger('click');

    expect(writeText).toHaveBeenCalledWith(synopsis);
    expect(button.text()).toContain('Copied');
  });

  it('keeps the button in the copy state when the clipboard write fails', async () => {
    const writeText = vi.fn().mockRejectedValue(new Error('denied'));
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    const wrapper = mount(GenericTable, {
      props: {
        items: [{ entity_id: 7, synopsis: 'Un-copyable clinical synopsis.' }],
        fields,
        fieldDetails: [{ key: 'synopsis', label: 'Clinical Synopsis' }],
      },
      global: {
        stubs: {
          BTable: bTableStub,
          BCard: { template: '<div><slot /></div>' },
        },
      },
    });

    const button = wrapper.get('.generic-table-detail__copy-button');
    await button.trigger('click');
    await Promise.resolve();

    expect(writeText).toHaveBeenCalled();
    expect(button.text()).toContain('Copy');
    expect(button.text()).not.toContain('Copied');
  });

  it('resets the copied state after the timeout and clears the timer on unmount', async () => {
    vi.useFakeTimers();
    const clearSpy = vi.spyOn(window, 'clearTimeout');
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText },
    });

    const wrapper = mount(GenericTable, {
      props: {
        items: [{ entity_id: 9, synopsis: 'Timed clinical synopsis.' }],
        fields,
        fieldDetails: [{ key: 'synopsis', label: 'Clinical Synopsis' }],
      },
      global: {
        stubs: {
          BTable: bTableStub,
          BCard: { template: '<div><slot /></div>' },
        },
      },
    });

    const button = wrapper.get('.generic-table-detail__copy-button');
    await button.trigger('click');
    await Promise.resolve();
    expect(button.text()).toContain('Copied');

    // Timer resets the label back to Copy.
    vi.advanceTimersByTime(1600);
    await wrapper.vm.$nextTick();
    expect(button.text()).toContain('Copy');
    expect(button.text()).not.toContain('Copied');

    // Unmounting with a pending timer clears it (no leaked callback).
    await button.trigger('click');
    await Promise.resolve();
    clearSpy.mockClear();
    wrapper.unmount();
    expect(clearSpy).toHaveBeenCalled();
  });
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});
