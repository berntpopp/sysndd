// app/src/views/curate/components/CombinedStatusReviewWorkflow.spec.ts
/**
 * Component spec for the combined Status & Review inline workflow
 * (issues #36, #37).
 *
 * Asserts:
 *   - both the status (category select) and review (synopsis) surfaces render
 *     in one panel
 *   - the direct-approval toggle is visible ONLY when `canDirectApprove` is
 *     true (Curator+ gating, frontend half of issue #37)
 *   - toggling it emits `update:direct-approval`
 *   - submitting emits `submit`
 */

import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import CombinedStatusReviewWorkflow from './CombinedStatusReviewWorkflow.vue';

const baseProps = {
  loading: false,
  submitting: null,
  review: { synopsis: 'Existing synopsis', comment: '' },
  selectPhenotype: [],
  selectVariation: [],
  selectAdditionalReferences: [],
  selectGeneReviews: [],
  phenotypeOptions: [],
  variationOptions: [],
  statusOptions: [{ id: 2, label: 'Definitive' }],
  statusOptionsLoading: false,
  formData: { category_id: 2, comment: '', problematic: false },
  directApproval: false,
  canDirectApprove: false,
};

const stubs = {
  BButton: { template: '<button type="button"><slot /></button>' },
  BForm: { template: '<form><slot /></form>' },
  BOverlay: { template: '<div><slot /></div>' },
  BSpinner: { template: '<span role="status" />' },
  BAlert: { template: '<div role="alert"><slot /></div>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BFormInput: { props: ['modelValue'], template: '<input :value="modelValue" />' },
  BFormSelect: {
    props: ['modelValue', 'options'],
    emits: ['update:model-value'],
    template:
      '<select class="status-select" :value="modelValue" @change="$emit(\'update:model-value\', Number($event.target.value))"><slot name="first" /><option value="2">Definitive</option></select>',
  },
  BFormSelectOption: { template: '<option><slot /></option>' },
  BFormTextarea: { props: ['modelValue'], template: '<textarea :value="modelValue" />' },
  BFormTags: { template: '<div><slot /></div>' },
  BFormTag: { template: '<span><slot /></span>' },
  BFormCheckbox: {
    props: ['modelValue', 'id'],
    emits: ['update:model-value'],
    template:
      '<label :data-id="id"><input type="checkbox" :checked="modelValue" @change="$emit(\'update:model-value\', !modelValue)" /><slot /></label>',
  },
  TreeMultiSelect: { template: '<div class="tree-multi-select" />' },
};

const mountWorkflow = (props = {}) =>
  mount(CombinedStatusReviewWorkflow, {
    props: { ...baseProps, ...props },
    global: { stubs },
  });

describe('CombinedStatusReviewWorkflow', () => {
  it('renders both the status and review surfaces in one panel', () => {
    const wrapper = mountWorkflow();
    expect(wrapper.find('.status-select').exists()).toBe(true);
    expect(wrapper.find('#combined-review-synopsis').exists()).toBe(true);
    expect(wrapper.text()).toContain('Status');
    expect(wrapper.text()).toContain('Review');
  });

  it('HIDES the direct-approval toggle for non-Curator roles', () => {
    const wrapper = mountWorkflow({ canDirectApprove: false });
    expect(wrapper.find('[data-id="combined-direct-approval"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Direct approval');
  });

  it('SHOWS the direct-approval toggle for Curator+', () => {
    const wrapper = mountWorkflow({ canDirectApprove: true });
    expect(wrapper.find('[data-id="combined-direct-approval"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('Direct approval');
  });

  it('emits update:direct-approval when the toggle is flipped', async () => {
    const wrapper = mountWorkflow({ canDirectApprove: true, directApproval: false });
    const toggle = wrapper.find('[data-id="combined-direct-approval"] input');
    await toggle.trigger('change');
    expect(wrapper.emitted('update:direct-approval')?.[0]).toEqual([true]);
  });

  it('emits submit when the form is submitted', async () => {
    const wrapper = mountWorkflow();
    await wrapper.find('form').trigger('submit');
    expect(wrapper.emitted('submit')).toBeTruthy();
  });

  it('emits update:form-data with the new category when the status select changes', async () => {
    const wrapper = mountWorkflow({ formData: { category_id: null, comment: '', problematic: false } });
    const select = wrapper.find('.status-select');
    await select.setValue('2');
    const emitted = wrapper.emitted('update:form-data');
    expect(emitted).toBeTruthy();
    expect(emitted?.[0][0]).toMatchObject({ category_id: 2 });
  });
});
