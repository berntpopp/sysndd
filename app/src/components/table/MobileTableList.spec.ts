import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import MobileTableList from './MobileTableList.vue';

describe('MobileTableList', () => {
  it('renders records as a named native list', () => {
    const wrapper = mount(MobileTableList, {
      props: {
        items: [{ id: 1 }, { id: 2 }],
        label: 'Genes',
        itemKey: 'id',
      },
      slots: { default: '<div class="record" role="listitem">Gene record</div>' },
    });

    const list = wrapper.get('[role="list"][aria-label="Genes"]');
    expect(list.findAll(':scope > [role="listitem"].record')).toHaveLength(2);
  });

  it('uses a status message instead of an empty list', () => {
    const wrapper = mount(MobileTableList, {
      props: {
        items: [],
        label: 'Genes',
        emptyText: 'No genes found.',
      },
    });

    expect(wrapper.find('[role="list"]').exists()).toBe(false);
    expect(wrapper.get('[role="status"]').text()).toBe('No genes found.');
  });
});
