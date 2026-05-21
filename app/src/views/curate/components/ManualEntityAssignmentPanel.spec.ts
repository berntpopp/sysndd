import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';

import ManualEntityAssignmentPanel from './ManualEntityAssignmentPanel.vue';

const baseProps = {
  userOptions: [
    { value: 3, text: 'Curator A' },
    { value: 4, text: 'Reviewer B' },
  ],
  entityAssignUserId: null,
  entityAssignBatchName: '',
  selectedEntityIds: [11],
  availableEntities: [
    {
      entity_id: 11,
      gene_symbol: 'ARID1B',
      disease_ontology_name: 'ARID1B disorder',
      review_date: '2026-01-01',
      status_name: 'Definitive',
    },
    {
      entity_id: 22,
      gene_symbol: 'SCN2A',
      disease_ontology_name: 'SCN2A disorder',
      review_date: '2026-02-01',
      status_name: 'Moderate',
    },
  ],
  availableEntityTotal: 7,
  entitySelectFields: [
    { key: 'selected', label: '' },
    { key: 'entity_id', label: 'ID' },
    { key: 'gene_symbol', label: 'Gene' },
    { key: 'disease_ontology_name', label: 'Disease' },
    { key: 'review_date', label: 'Last Review' },
    { key: 'status_name', label: 'Status' },
  ],
  manualEntityFilter: '',
  isLoadingEntities: false,
  isAssigningEntities: false,
  boundaryGeneAlertVisible: false,
  boundaryGeneAlertMessage: '',
};

function mountSubject(props = {}) {
  return mount(ManualEntityAssignmentPanel, {
    props: { ...baseProps, ...props },
    global: {
      stubs: {
        BFormGroup: {
          props: ['label'],
          template: '<div><label>{{ label }}</label><slot /></div>',
        },
        BFormSelect: {
          props: ['modelValue', 'options'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(`update:modelValue`, Number($event.target.value))"><slot name="first" /><option v-for="option in options" :key="option.value" :value="option.value">{{ option.text }}</option></select>',
        },
        BFormInput: {
          props: ['modelValue', 'id', 'size', 'placeholder', 'ariaLabel'],
          emits: ['update:modelValue'],
          template:
            '<input :value="modelValue" @input="$emit(`update:modelValue`, $event.target.value)" />',
        },
        BButton: {
          props: ['disabled'],
          emits: ['click'],
          template: '<button :disabled="disabled" @click="$emit(`click`)"><slot /></button>',
        },
        BSpinner: { template: '<span data-testid="spinner" />' },
        BAlert: {
          props: ['variant', 'show'],
          template: '<div :data-variant="variant"><slot /></div>',
        },
        TableSearchInput: {
          props: ['modelValue'],
          emits: ['update:modelValue', 'update', 'clear'],
          template:
            '<input aria-label="Search available entities" :value="modelValue" @input="$emit(`update:modelValue`, $event.target.value); $emit(`update`)" @keyup.esc="$emit(`clear`)" />',
        },
        BTable: {
          props: ['items', 'fields', 'tbodyTrClass', 'busy'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id" :class="tbodyTrClass(item)"><td><slot name="cell(selected)" :item="item" /></td><td><slot name="cell(entity_id)" :item="item" /></td><td>{{ item.gene_symbol }}</td><td><slot name="cell(disease_ontology_name)" :item="item" /></td><td>{{ item.review_date }}</td><td>{{ item.status_name }}</td></tr></tbody></table>',
        },
      },
    },
  });
}

describe('ManualEntityAssignmentPanel', () => {
  it('renders controls, selected count, entity rows, and available total', () => {
    const wrapper = mountSubject();

    expect(wrapper.text()).toContain('Assign to');
    expect(wrapper.text()).toContain('Batch name');
    expect(wrapper.text()).toContain('1');
    expect(wrapper.text()).toContain('selected');
    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('SCN2A disorder');
    expect(wrapper.text()).toContain('Showing 2 of 7 available entities.');
    expect(wrapper.find('tr').classes()).toContain('re-review-pick-table__row--selected');
  });

  it('disables assignment until a user and selected entity are present', async () => {
    const disabledWrapper = mountSubject({ selectedEntityIds: [], entityAssignUserId: null });
    expect(
      disabledWrapper
        .findAll('button')
        .some((button) => button.text().includes('Assign') && button.attributes('disabled') !== undefined)
    ).toBe(true);
    expect(
      disabledWrapper.findAll('button').find((button) => button.text().includes('Clear'))?.attributes('disabled')
    ).toBeDefined();

    const enabledWrapper = mountSubject({ selectedEntityIds: [11], entityAssignUserId: 3 });
    expect(
      enabledWrapper.findAll('button').find((button) => button.text().includes('Assign'))?.attributes('disabled')
    ).toBeUndefined();
    expect(
      enabledWrapper.findAll('button').find((button) => button.text().includes('Clear'))?.attributes('disabled')
    ).toBeUndefined();
  });

  it('emits model updates and manual assignment actions', async () => {
    const wrapper = mountSubject({ entityAssignUserId: 3 });

    await wrapper.find('select').setValue('4');
    await wrapper.find('input').setValue('named-batch');
    await wrapper.find('[aria-label="Search available entities"]').setValue('SCN2A');
    await wrapper.find('[aria-label="Select entity 22"]').trigger('change');
    await wrapper.findAll('button').find((button) => button.text().includes('Assign'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Refresh entities'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Clear'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Close setup'))!.trigger('click');

    expect(wrapper.emitted('update:entityAssignUserId')?.at(-1)).toEqual([4]);
    expect(wrapper.emitted('update:entityAssignBatchName')?.at(-1)).toEqual(['named-batch']);
    expect(wrapper.emitted('update:manualEntityFilter')?.at(-1)).toEqual(['SCN2A']);
    expect(wrapper.emitted('toggle-entity-selection')?.at(-1)).toEqual([22]);
    expect(wrapper.emitted('assign-entities')).toHaveLength(1);
    expect(wrapper.emitted('refresh-entities')).toBeTruthy();
    expect(wrapper.emitted('clear-selection')).toHaveLength(1);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('renders boundary-gene alert copy when requested', () => {
    const wrapper = mountSubject({
      boundaryGeneAlertVisible: true,
      boundaryGeneAlertMessage: 'Batch is gene-atomic for HGNC:4585.',
    });

    expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('HGNC:4585');
  });
});
