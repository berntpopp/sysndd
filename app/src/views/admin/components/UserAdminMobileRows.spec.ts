import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import UserAdminMobileRows from './UserAdminMobileRows.vue';

const user = {
  user_id: 9,
  user_name: 'admin_user',
  email: 'admin@example.org',
  user_role: 'Administrator',
  approved: 1,
  abbreviation: 'ADM',
  created_at: '2026-03-14T10:00:00Z',
};

describe('UserAdminMobileRows', () => {
  it('renders admin user rows and emits selection/edit/delete actions', async () => {
    const wrapper = mount(UserAdminMobileRows, {
      props: {
        items: [user],
        selectedIds: [],
      },
    });

    expect(wrapper.text()).toContain('admin_user');
    expect(wrapper.text()).toContain('admin@example.org');
    expect(wrapper.text()).toContain('Administrator');
    expect(wrapper.text()).toContain('Approved');
    expect(wrapper.text()).toContain('ADM');
    expect(wrapper.text()).toContain('2026-03-14');

    await wrapper.get('input[type="checkbox"]').setValue(true);
    await wrapper.get('button[aria-label="Edit user admin_user"]').trigger('click');
    await wrapper.get('button[aria-label="Delete user admin_user"]').trigger('click');

    expect(wrapper.emitted('toggle-select')?.[0]).toEqual([9]);
    expect(wrapper.emitted('edit')?.[0]).toEqual([user]);
    expect(wrapper.emitted('delete')?.[0]).toEqual([user]);
  });
});
