import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import PhenotypesMobileRows from './PhenotypesMobileRows.vue';

const sample = {
  entity_id: 57,
  symbol: 'ARID1B',
  hgnc_id: 'HGNC:18040',
  disease_ontology_name: 'Coffin-Siris syndrome',
  disease_ontology_id_version: 'OMIM:135900_2025',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  category: 'Definitive',
  ndd_phenotype_word: 'Yes',
  modifier_phenotype_id: 'HP:0001249',
  entry_date: '2025-02-12',
  last_update: '2026-03-20',
};

describe('PhenotypesMobileRows', () => {
  it('renders compact linked phenotype-associated entity rows', async () => {
    const wrapper = mount(PhenotypesMobileRows, {
      props: {
        items: [sample],
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
    expect(wrapper.text()).toContain('HP:0001249');
    expect(wrapper.find('a[href="/Entities/57"]').exists()).toBe(true);
    expect(wrapper.find('a[href="/Genes/HGNC:18040"]').exists()).toBe(true);
    expect(wrapper.find('a[href="/Ontology/OMIM:135900"]').exists()).toBe(true);

    await wrapper.get('button[aria-expanded="false"]').trigger('click');

    expect(wrapper.get('button').attributes('aria-expanded')).toBe('true');
    expect(wrapper.text()).toContain('2025-02-12');
    expect(wrapper.text()).toContain('Last updated');
    expect(wrapper.text()).toContain('2026-03-20');
  });

  it('summarizes long phenotype id lists in the collapsed row', () => {
    const wrapper = mount(PhenotypesMobileRows, {
      props: {
        items: [
          {
            ...sample,
            modifier_phenotype_id: 'HP:0001249,HP:0001256,HP:0001871,HP:0003676',
          },
        ],
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

    expect(wrapper.text()).toContain('HP:0001249, HP:0001256 +2');
    expect(wrapper.get('[aria-label^="Phenotype:"]').attributes('title')).toBe(
      'HP:0001249,HP:0001256,HP:0001871,HP:0003676'
    );
  });
});
