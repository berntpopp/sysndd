import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import GenesMobileRows from './GenesMobileRows.vue';

const bLinkStub = {
  props: ['to', 'href'],
  template: '<a :href="to || href"><slot /></a>',
};

describe('GenesMobileRows', () => {
  it('renders linked gene, unique aggregated statuses, and linked expanded entities', async () => {
    const wrapper = mount(GenesMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            hgnc_id: 'HGNC:18040',
            entities_count: 2,
            entities: [
              {
                entity_id: 57,
                disease_ontology_name: 'Coffin-Siris syndrome 1',
                disease_ontology_id_version: 'OMIM:135900_2024-01-01',
                hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
                hpo_mode_of_inheritance_term: 'HP:0000006',
                category: 'Definitive',
                ndd_phenotype_word: 'Yes',
              },
              {
                entity_id: 58,
                disease_ontology_name: 'Developmental delay, ARID1B-related',
                disease_ontology_id_version: 'MONDO:0013342_2024-01-01',
                hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
                hpo_mode_of_inheritance_term: 'HP:0000006',
                category: 'Definitive',
                ndd_phenotype_word: 'Yes',
              },
            ],
          },
        ],
      },
      global: {
        stubs: {
          BLink: bLinkStub,
        },
      },
    });

    expect(wrapper.get('a[href="/Genes/HGNC:18040"]').text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('2 entities');
    expect(wrapper.findAll('[data-testid="inheritance-status"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-testid="category-status"]')).toHaveLength(1);
    expect(wrapper.findAll('[data-testid="ndd-status"]')).toHaveLength(1);
    expect(wrapper.text()).toContain('NDD Yes');
    expect(wrapper.find('[aria-label="Associated with NDD"]').exists()).toBe(true);

    const detailsButton = wrapper.get('button');
    expect(detailsButton.attributes('aria-expanded')).toBe('false');
    expect(wrapper.find('dl').exists()).toBe(false);

    await detailsButton.trigger('click');

    expect(detailsButton.attributes('aria-expanded')).toBe('true');
    expect(wrapper.text()).toContain('Coffin-Siris syndrome 1');
    expect(wrapper.text()).toContain('Developmental delay, ARID1B-related');
    expect(wrapper.get('a[href="/Entities/57"]').text()).toContain('sysndd:57');
    expect(wrapper.get('a[href="/Entities/58"]').text()).toContain('sysndd:58');
    expect(wrapper.get('a[href="/Ontology/OMIM:135900"]').text()).toContain(
      'Coffin-Siris syndrome 1'
    );
    expect(wrapper.get('a[href="/Ontology/MONDO:0013342"]').text()).toContain(
      'Developmental delay, ARID1B-related'
    );
  });
});
