import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import PanelsMobileRows from './PanelsMobileRows.vue';

describe('PanelsMobileRows', () => {
  it('renders compact panel gene rows with gene links and selected details', async () => {
    const wrapper = mount(PanelsMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            category: 'Definitive',
            inheritance: 'AD',
            hgnc_id: 'HGNC:18040',
            entrez_id: '57492',
          },
        ],
        selectedFieldKeys: ['hgnc_id', 'entrez_id'],
      },
      global: {
        directives: {
          bTooltip: {},
        },
        stubs: {
          BLink: {
            props: ['to'],
            template: '<a :href="to"><slot /></a>',
          },
        },
      },
    });

    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('Definitive');
    expect(wrapper.text()).toContain('AD');
    expect(wrapper.find('a[href="/Genes/HGNC:18040"]').exists()).toBe(true);

    await wrapper.get('button[aria-expanded="false"]').trigger('click');

    const detailsButton = wrapper.get('button');
    const detailsId = detailsButton.attributes('aria-controls');

    expect(detailsButton.attributes('aria-expanded')).toBe('true');
    expect(detailsId).toBeTruthy();
    expect(wrapper.find(`#${detailsId}`).exists()).toBe(true);
    expect(wrapper.text()).toContain('HGNC:18040');
    expect(wrapper.text()).toContain('57492');
  });

  it('falls back to symbol gene links when hgnc id is not selected', () => {
    const wrapper = mount(PanelsMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            category: 'Definitive',
            inheritance: 'AD',
          },
        ],
        selectedFieldKeys: ['symbol', 'category', 'inheritance'],
      },
      global: {
        directives: {
          bTooltip: {},
        },
        stubs: {
          BLink: {
            props: ['to'],
            template: '<a :href="to"><slot /></a>',
          },
        },
      },
    });

    expect(wrapper.find('a[href="/Genes/ARID1B"]').exists()).toBe(true);
  });
});
