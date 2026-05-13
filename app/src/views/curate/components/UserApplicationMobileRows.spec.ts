import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import UserApplicationMobileRows from './UserApplicationMobileRows.vue';

const user = {
  user_id: 7,
  user_name: 'jane_curator',
  first_name: 'Jane',
  family_name: 'Curator',
  email: 'jane@example.org',
  user_role: 'Curator',
  created_at: '2026-04-28T09:00:00Z',
  comment: 'Works on NDD submissions.',
};

describe('UserApplicationMobileRows', () => {
  it('renders pending application rows and emits review actions', async () => {
    const wrapper = mount(UserApplicationMobileRows, {
      props: { items: [user] },
    });

    expect(wrapper.text()).toContain('jane_curator');
    expect(wrapper.text()).toContain('Jane Curator');
    expect(wrapper.text()).toContain('jane@example.org');
    expect(wrapper.text()).toContain('Curator');
    expect(wrapper.text()).toContain('2026-04-28');

    const buttons = wrapper.findAll('button');
    await buttons
      .find((button) => button.attributes('aria-label') === 'Review user jane_curator')!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label') === 'Approve user jane_curator')!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label') === 'Reject user jane_curator')!
      .trigger('click');

    expect(wrapper.emitted('review')?.[0]).toEqual([user]);
    expect(wrapper.emitted('approve')?.[0]).toEqual([user]);
    expect(wrapper.emitted('reject')?.[0]).toEqual([user]);
  });
});
