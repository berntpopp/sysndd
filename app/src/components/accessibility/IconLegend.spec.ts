import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import IconLegend from './IconLegend.vue';

describe('IconLegend', () => {
  // CUR-10: an undeclared `title` fell through to BCard and rendered as a card-title <h4>.
  it('renders a caller title as the inline label, not a heading', () => {
    const wrapper = mount(IconLegend, {
      props: { legendItems: [{ icon: 'bi bi-eye', label: 'Toggle details' }], title: 'Status' },
    });
    expect(wrapper.find('h4').exists()).toBe(false);
    expect(wrapper.get('strong').text()).toBe('Status');
  });
});
