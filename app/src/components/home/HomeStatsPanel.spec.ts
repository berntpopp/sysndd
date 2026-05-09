import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import HomeStatsPanel from './HomeStatsPanel.vue';

const entityStatistics = {
  data: [
    {
      category: 'Definitive',
      inheritance: 'Any',
      n: 1997,
      groups: [{ category: 'Definitive', inheritance: 'Autosomal dominant', n: 1200 }],
    },
  ],
};

const geneStatistics = {
  data: [
    {
      category: 'Limited',
      inheritance: 'Any',
      n: 1252,
      groups: [{ category: 'Limited', inheritance: 'Autosomal recessive', n: 530 }],
    },
  ],
};

function mountPanel() {
  return mount(HomeStatsPanel, {
    props: {
      entityStatistics,
      geneStatistics,
      lastUpdate: '11/12/2025',
      inheritanceOverviewText: {
        'Autosomal dominant': 'AD',
        'Autosomal recessive': 'AR',
      },
      inheritanceLink: {
        'Autosomal dominant': ['HP:0000006'],
        'Autosomal recessive': ['HP:0000007'],
      },
    },
    global: {
      stubs: {
        CategoryIcon: {
          props: ['category'],
          template: '<span class="category-stub">{{ category }}</span>',
        },
        BLink: {
          props: ['to'],
          template: '<a :href="to"><slot /></a>',
        },
        BButton: {
          emits: ['click'],
          template:
            '<button type="button" v-bind="$attrs" @click="$emit(\'click\', $event)"><slot /></button>',
        },
      },
    },
  });
}

describe('HomeStatsPanel', () => {
  it('renders compact entity and gene statistics with count links', () => {
    const wrapper = mountPanel();

    expect(wrapper.text()).toContain('Database statistics');
    expect(wrapper.text()).toContain('Updated 11/12/2025');
    expect(wrapper.get('a[href="/Entities?filter=any(category,Definitive)"]').text()).toBe('1,997');
    expect(wrapper.get('a[href="/Panels/Limited/Any"]').text()).toBe('1,252');
  });

  it('expands inheritance breakdown chips without stacked mobile table markup', async () => {
    const wrapper = mountPanel();

    expect(wrapper.text()).not.toContain('AD');
    await wrapper
      .get('button[aria-label="Show Definitive entity inheritance details"]')
      .trigger('click');

    expect(wrapper.text()).toContain('AD');
    expect(
      wrapper
        .get(
          'a[href="/Entities?filter=any(category,Definitive),any(hpo_mode_of_inheritance_term_name,HP:0000006)"]'
        )
        .text()
    ).toContain('1,200');
  });
});
