/**
 * ConfirmActionModal contract tests.
 *
 * Generic yes/no confirmation modal used in place of native window.confirm().
 * These pin the v-model visibility contract, the confirm/cancel emits, the
 * busy-disables-both-buttons behaviour, and the message/slot fallback.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import ConfirmActionModal from './ConfirmActionModal.vue';

const stubs = {
  BModal: {
    name: 'BModal',
    template: '<div><slot /><slot name="footer" /></div>',
    props: ['modelValue', 'title'],
    emits: ['update:modelValue', 'hidden'],
  },
  BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
  BSpinner: { template: '<span class="spinner" />' },
};

function mountModal(props = {}) {
  return mount(ConfirmActionModal, {
    props: { modelValue: true, title: 'Do the thing?', message: 'Are you sure?', ...props },
    global: { stubs },
  });
}

describe('ConfirmActionModal', () => {
  it('renders the message prop when no default slot is provided', () => {
    const wrapper = mountModal({ message: 'This cannot be undone.' });
    expect(wrapper.text()).toContain('This cannot be undone.');
  });

  it('emits confirm when the confirm button is clicked', async () => {
    const wrapper = mountModal();
    // Footer order: [Cancel, Confirm]
    await wrapper.findAll('button')[1].trigger('click');
    expect(wrapper.emitted('confirm')).toHaveLength(1);
  });

  it('emits cancel and closes when the cancel button is clicked', async () => {
    const wrapper = mountModal();
    await wrapper.findAll('button')[0].trigger('click');
    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('update:modelValue')).toEqual([[false]]);
  });

  it('disables both buttons while busy', () => {
    const wrapper = mountModal({ busy: true });
    expect(wrapper.findAll('button')[0].attributes('disabled')).toBeDefined();
    expect(wrapper.findAll('button')[1].attributes('disabled')).toBeDefined();
  });

  it('forwards the hidden lifecycle so the parent can reset state', () => {
    const wrapper = mountModal();
    wrapper.findComponent({ name: 'BModal' }).vm.$emit('hidden');
    expect(wrapper.emitted('hidden')).toHaveLength(1);
  });
});
