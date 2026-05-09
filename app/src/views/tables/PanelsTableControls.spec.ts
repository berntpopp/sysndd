import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import PanelsTableControls from './PanelsTableControls.vue';

const columns = [{ value: 'symbol' }, { value: 'hgnc_id' }, { value: 'entrez_id' }];

function mountControls() {
  return mount(PanelsTableControls, {
    props: {
      categories: [{ value: 'All' }, { value: 'Definitive' }],
      inheritance: [{ value: 'All' }, { value: 'AD' }],
      columns,
      selectedCategory: 'All',
      selectedInheritance: 'All',
      selectedColumns: ['symbol', 'hgnc_id'],
      sortBy: [{ key: 'symbol', order: 'asc' }],
    },
    global: {
      stubs: {
        BFormSelect: {
          name: 'BFormSelect',
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(\'update:modelValue\', $event.target.value)" />',
        },
      },
    },
  });
}

describe('PanelsTableControls', () => {
  it('emits Bootstrap table sort shape from sort controls', async () => {
    const wrapper = mountControls();

    await wrapper
      .findAllComponents({ name: 'BFormSelect' })[2]
      .vm.$emit('update:modelValue', 'hgnc_id');
    await wrapper
      .findAllComponents({ name: 'BFormSelect' })[3]
      .vm.$emit('update:modelValue', 'desc');

    expect(wrapper.emitted('update:sort')?.[0]).toEqual([[{ key: 'hgnc_id', order: 'asc' }]]);
    expect(wrapper.emitted('update:sort')?.[1]).toEqual([[{ key: 'symbol', order: 'desc' }]]);
  });

  it('keeps the required symbol column when toggling columns', async () => {
    const wrapper = mountControls();
    await wrapper.get('button[aria-controls="panel-controls-columns"]').trigger('click');

    const symbolCheckbox = wrapper.find('input[value="symbol"]');
    const entrezCheckbox = wrapper.find('input[value="entrez_id"]');

    expect(symbolCheckbox.attributes('disabled')).toBeDefined();

    await entrezCheckbox.setValue(true);

    expect(wrapper.emitted('update:columns')?.[0]).toEqual([['symbol', 'hgnc_id', 'entrez_id']]);
  });

  it('keeps column controls collapsed by default', () => {
    const wrapper = mountControls();

    expect(wrapper.find('#panel-controls-columns').exists()).toBe(false);
    expect(wrapper.get('button[aria-controls="panel-controls-columns"]').text()).toContain(
      'Columns'
    );
  });
});
