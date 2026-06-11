/**
 * LogDeleteModal contract tests.
 *
 * The parent (TablesLogs) keeps this component mounted and relies on the
 * modal's hidden lifecycle to reset state for every close path (cancel,
 * dismiss, successful delete). These tests pin that contract plus the
 * DELETE-confirmation gate on the confirm button.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import LogDeleteModal from './LogDeleteModal.vue';

const stubs = {
  BModal: {
    name: 'BModal',
    template: '<div><slot /><slot name="footer" /></div>',
    props: ['modelValue'],
    emits: ['update:modelValue', 'hidden'],
  },
  BFormSelect: { template: '<select />', props: ['modelValue'] },
  BFormInput: {
    template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
    props: ['modelValue', 'state'],
    emits: ['update:modelValue'],
  },
  BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
  BSpinner: { template: '<span />' },
};

function mountModal(props = {}) {
  return mount(LogDeleteModal, {
    props: { modelValue: true, deleteMode: 'all', totalRows: 42, isDeleting: false, ...props },
    global: { stubs },
  });
}

describe('LogDeleteModal', () => {
  it('resets confirm text and emits deleteMode reset when the modal hides', async () => {
    const wrapper = mountModal({ deleteMode: '7' });
    await wrapper.find('input').setValue('DELETE');
    expect(wrapper.vm.deleteConfirmText).toBe('DELETE');

    wrapper.findComponent({ name: 'BModal' }).vm.$emit('hidden');
    await nextTick();

    expect(wrapper.vm.deleteConfirmText).toBe('');
    expect(wrapper.emitted('update:deleteMode')).toEqual([['all']]);
  });

  it('keeps confirm disabled until DELETE is typed, then emits confirm on click', async () => {
    const wrapper = mountModal();
    const confirmButton = wrapper.findAll('button')[1];
    expect(confirmButton.attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('DELETE');
    expect(confirmButton.attributes('disabled')).toBeUndefined();

    await confirmButton.trigger('click');
    expect(wrapper.emitted('confirm')).toHaveLength(1);
  });

  it('keeps confirm disabled while deleting even with DELETE typed', async () => {
    const wrapper = mountModal({ isDeleting: true });
    await wrapper.find('input').setValue('DELETE');
    expect(wrapper.findAll('button')[1].attributes('disabled')).toBeDefined();
  });
});
