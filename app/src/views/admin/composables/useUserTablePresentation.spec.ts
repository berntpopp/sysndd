import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import GenericTable from '@/components/small/GenericTable.vue';
import { useUserTablePresentation } from './useUserTablePresentation';

describe('user table fields', () => {
  it('truncates e-mail with a title and shows the created date in the long style', () => {
    const { fields } = useUserTablePresentation();
    const wrapper = mount(GenericTable, {
      props: {
        items: [
          {
            user_id: 1,
            user_name: 'admin',
            email: 'admin.demo@example.org',
            created_at: '2026-11-21 12:10:50',
          },
        ],
        fields,
      },
      global: { directives: { 'b-tooltip': () => {} } },
    });
    const email = wrapper.get('td[title="admin.demo@example.org"]');
    expect(email.classes()).toContain('text-truncate');
    expect(wrapper.get('td[title="2026-11-21 12:10:50"]').text()).toBe('November 21, 2026');
  });
});
