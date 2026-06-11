import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import EntitiesMobileRows from './EntitiesMobileRows.vue';

const bLinkStub = {
  props: ['to', 'href'],
  template: '<a :href="to || href"><slot /></a>',
};

describe('EntitiesMobileRows', () => {
  it('renders linked entity, gene, disease, inheritance, statuses, and toggleable details', async () => {
    const wrapper = mount(EntitiesMobileRows, {
      props: {
        items: [
          {
            entity_id: 57,
            symbol: 'ARID1B',
            hgnc_id: 'HGNC:18040',
            disease_ontology_name: 'Coffin-Siris syndrome 1',
            disease_ontology_id_version: 'OMIM:135900_2024-01-01',
            hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
            hpo_mode_of_inheritance_term: 'HP:0000006',
            category: 'Definitive',
            ndd_phenotype_word: 'Yes',
            entry_date: '2024-02-10',
            last_update: '2026-02-10',
            synopsis: 'Developmental delay with speech involvement.',
          },
        ],
      },
      global: {
        stubs: {
          BLink: bLinkStub,
        },
      },
    });

    expect(wrapper.text()).toContain('sysndd:57');
    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('Coffin-Siris syndrome 1');
    expect(wrapper.text()).toContain('AD');
    expect(wrapper.text()).toContain('Definitive');
    expect(wrapper.text()).toContain('NDD Yes');
    expect(wrapper.find('[aria-label="Associated with NDD"]').exists()).toBe(true);

    expect(wrapper.get('a[href="/Entities/57"]').text()).toContain('sysndd:57');
    expect(wrapper.get('a[href="/Genes/HGNC:18040"]').text()).toContain('ARID1B');
    expect(wrapper.get('a[href="/Ontology/OMIM:135900"]').text()).toContain(
      'Coffin-Siris syndrome 1'
    );

    const detailsButton = wrapper.get('button');
    expect(detailsButton.attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('dl').exists()).toBe(false);

    await detailsButton.trigger('click');

    expect(detailsButton.attributes('aria-expanded')).toBe('true');
    expect(wrapper.find('dl').exists()).toBe(true);
    expect(wrapper.text()).toContain('HGNC:18040');
    expect(wrapper.text()).toContain('OMIM:135900_2024-01-01');
    expect(wrapper.text()).toContain('2024-02-10');
    expect(wrapper.text()).toContain('Last updated');
    expect(wrapper.text()).toContain('2026-02-10');
    expect(wrapper.text()).toContain('Developmental delay with speech involvement.');
  });
});
