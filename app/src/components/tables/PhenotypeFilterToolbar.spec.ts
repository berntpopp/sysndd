import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';

import PhenotypeFilterToolbar from './PhenotypeFilterToolbar.vue';

const OPTIONS = [
  { phenotype_id: 'HP:0001249', HPO_term: 'Intellectual disability' },
  { phenotype_id: 'HP:0001250', HPO_term: 'Seizure' },
  { phenotype_id: 'HP:0000252', HPO_term: 'Microcephaly' },
];

function mountToolbar(props: Record<string, unknown> = {}) {
  return mount(PhenotypeFilterToolbar, {
    props: { phenotypeOptions: OPTIONS, selectedIds: [], ...props },
    global: {
      directives: { 'b-tooltip': {} },
      stubs: {
        BDropdown: {
          template: '<div><slot name="button-content" /><slot /></div>',
          methods: { show() {} },
        },
        BDropdownForm: { template: '<form><slot /></form>' },
        BDropdownDivider: { template: '<hr />' },
        BDropdownItemButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
        BDropdownText: { template: '<span><slot /></span>' },
        BFormInput: { props: ['modelValue'], template: '<input />' },
        BSpinner: { template: '<span />' },
      },
    },
  });
}

interface ToolbarVm {
  phenotypeSearch: string;
  filteredPhenotypeOptions: Array<{ phenotype_id: string; HPO_term: string }>;
  isPhenotypeSelected: (id: string) => boolean;
  getPhenotypeName: (id: string) => string;
}

describe('PhenotypeFilterToolbar', () => {
  it('returns all options (capped at 50) when no search term', () => {
    const vm = mountToolbar().vm as unknown as ToolbarVm;
    expect(vm.filteredPhenotypeOptions).toHaveLength(3);
  });

  it('filters options by HPO term or id, case-insensitively', () => {
    const wrapper = mountToolbar();
    const vm = wrapper.vm as unknown as ToolbarVm;
    vm.phenotypeSearch = 'seiz';
    expect(vm.filteredPhenotypeOptions.map((o) => o.phenotype_id)).toEqual(['HP:0001250']);
    vm.phenotypeSearch = 'hp:0000252';
    expect(vm.filteredPhenotypeOptions.map((o) => o.phenotype_id)).toEqual(['HP:0000252']);
  });

  it('resolves selection state and display names from ids', () => {
    const vm = mountToolbar({ selectedIds: ['HP:0001250'] }).vm as unknown as ToolbarVm;
    expect(vm.isPhenotypeSelected('HP:0001250')).toBe(true);
    expect(vm.isPhenotypeSelected('HP:0000252')).toBe(false);
    expect(vm.getPhenotypeName('HP:0001249')).toBe('Intellectual disability');
    // Unknown ids fall back to the raw id.
    expect(vm.getPhenotypeName('HP:9999999')).toBe('HP:9999999');
  });

  it('emits semantic events to the parent', async () => {
    const wrapper = mountToolbar({ selectedIds: ['HP:0001249'] });
    await wrapper.findAll('button')[0].trigger('click');
    expect(wrapper.emitted('toggle')?.[0]).toEqual(['HP:0001249']);
  });
});
