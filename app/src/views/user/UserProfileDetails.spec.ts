import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import UserProfileDetails from './UserProfileDetails.vue';

describe('UserProfileDetails', () => {
  const user = {
    user_name: ['Testuser'],
    email: ['test@example.org'],
    orcid: [''],
    abbreviation: ['TU'],
  };

  it('renders profile details and emits edit action', async () => {
    const wrapper = mount(UserProfileDetails, {
      props: {
        user,
        isEditing: false,
        isSaving: false,
        email: '',
        orcid: '',
      },
      global: {
        stubs: {
          BButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
          BSpinner: { template: '<span />' },
          BBadge: { template: '<span><slot /></span>' },
          BTooltip: { template: '<span><slot /></span>' },
          BFormInput: { template: '<input />' },
          BFormInvalidFeedback: { template: '<div><slot /></div>' },
          BFormText: { template: '<small><slot /></small>' },
        },
      },
    });

    expect(wrapper.text()).toContain('Testuser');
    expect(wrapper.text()).toContain('test@example.org');
    await wrapper.get('button').trigger('click');
    expect(wrapper.emitted('edit')).toBeTruthy();
  });

  it('emits edited email and ORCID values', async () => {
    const wrapper = mount(UserProfileDetails, {
      props: {
        user,
        isEditing: true,
        isSaving: false,
        email: 'test@example.org',
        orcid: '',
      },
      global: {
        stubs: {
          BButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
          BSpinner: { template: '<span />' },
          BBadge: { template: '<span><slot /></span>' },
          BTooltip: { template: '<span><slot /></span>' },
          BFormInput: {
            props: ['modelValue'],
            template:
              '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
          },
          BFormInvalidFeedback: { template: '<div><slot /></div>' },
          BFormText: { template: '<small><slot /></small>' },
        },
      },
    });

    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('updated@example.org');
    await inputs[1].setValue('0000-0000-0000-000X');

    expect(wrapper.emitted('update:email')?.[0]).toEqual(['updated@example.org']);
    expect(wrapper.emitted('update:orcid')?.[0]).toEqual(['0000-0000-0000-000X']);
    expect(wrapper.text()).toContain('Leave empty to remove ORCID');
  });
});
