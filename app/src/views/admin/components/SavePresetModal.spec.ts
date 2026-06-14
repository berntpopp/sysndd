/**
 * SavePresetModal contract tests.
 *
 * Replaces a native window.prompt() for naming a filter preset. Pins the
 * v-model:visible contract, the trimmed-name confirm emit, the empty-name
 * guard on the confirm button, and the @hidden reset of the input.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import SavePresetModal from './SavePresetModal.vue';

const stubs = {
  BModal: {
    name: 'BModal',
    template: '<div><slot /><slot name="footer" /></div>',
    props: ['modelValue', 'title'],
    emits: ['update:modelValue', 'hidden'],
  },
  BFormInput: {
    template:
      '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
    props: ['modelValue', 'state'],
    emits: ['update:modelValue'],
  },
  BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
};

function mountModal(props = {}) {
  return mount(SavePresetModal, {
    props: { visible: true, ...props },
    global: { stubs },
  });
}

describe('SavePresetModal', () => {
  it('keeps the confirm button disabled until a non-blank name is entered', async () => {
    const wrapper = mountModal();
    const confirm = wrapper.findAll('button')[1];
    expect(confirm.attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('   ');
    expect(confirm.attributes('disabled')).toBeDefined();

    await wrapper.find('input').setValue('Pending curators');
    expect(confirm.attributes('disabled')).toBeUndefined();
  });

  it('emits the trimmed name and closes on confirm', async () => {
    const wrapper = mountModal();
    await wrapper.find('input').setValue('  My preset  ');
    await wrapper.findAll('button')[1].trigger('click');

    expect(wrapper.emitted('confirm')).toEqual([['My preset']]);
    expect(wrapper.emitted('update:visible')).toEqual([[false]]);
  });

  it('emits cancel and closes without confirming', async () => {
    const wrapper = mountModal();
    await wrapper.find('input').setValue('discarded');
    await wrapper.findAll('button')[0].trigger('click');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
    expect(wrapper.emitted('confirm')).toBeUndefined();
    expect(wrapper.emitted('update:visible')).toEqual([[false]]);
  });

  it('resets the input when the modal hides', async () => {
    const wrapper = mountModal();
    await wrapper.find('input').setValue('typed name');
    wrapper.findComponent({ name: 'BModal' }).vm.$emit('hidden');
    await nextTick();
    expect((wrapper.find('input').element as HTMLInputElement).value).toBe('');
  });
});
