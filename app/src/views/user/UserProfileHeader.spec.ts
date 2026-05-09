import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import UserProfileHeader from './UserProfileHeader.vue';

describe('UserProfileHeader', () => {
  it('renders identity, role, member date, and session state', () => {
    const wrapper = mount(UserProfileHeader, {
      props: {
        user: {
          abbreviation: ['TU'],
          user_name: ['Testuser'],
          user_role: ['Reviewer'],
        },
        roleVariant: 'info',
        roleIcon: 'eye-fill',
        memberSince: 'Jun 9, 2022',
        sessionStatusClass: 'bg-success-subtle text-success',
        sessionStatusText: 'Active',
      },
    });

    expect(wrapper.text()).toContain('TU');
    expect(wrapper.text()).toContain('Testuser');
    expect(wrapper.text()).toContain('Reviewer');
    expect(wrapper.text()).toContain('Member since Jun 9, 2022');
    expect(wrapper.text()).toContain('Active');
  });
});
