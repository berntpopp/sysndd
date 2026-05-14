import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';

import EntityInfoHeader from './EntityInfoHeader.vue';

const entity = {
  entity_id: 501,
  symbol: 'MECP2',
  hgnc_id: 'HGNC:6990',
  disease_ontology_name: 'Rett syndrome',
  disease_ontology_id_version: 'MONDO:0010726_2025-01-01',
  hpo_mode_of_inheritance_term_name: 'X-linked dominant inheritance',
  category: 'Definitive',
  ndd_phenotype_word: 'Yes',
};

describe('EntityInfoHeader', () => {
  it('renders selected entity details as an inline summary instead of a card', () => {
    const wrapper = mount(EntityInfoHeader, {
      props: {
        entity,
        legendItems: [],
        stoplightsStyle: { Definitive: 'success' },
        nddIconStyle: { Yes: 'success' },
        nddIcon: { Yes: 'check' },
      },
      global: {
        stubs: {
          BRow: { template: '<div><slot /></div>' },
          BCol: { template: '<div><slot /></div>' },
          BBadge: { template: '<span><slot /></span>' },
          EntityBadge: { props: ['entityId'], template: '<span>sysndd:{{ entityId }}</span>' },
          GeneBadge: { props: ['symbol'], template: '<span>{{ symbol }}</span>' },
          DiseaseBadge: { props: ['name'], template: '<span>{{ name }}</span>' },
          IconLegend: { template: '<div />' },
        },
      },
    });

    expect(wrapper.find('.entity-info-header__summary').exists()).toBe(true);
    expect(wrapper.findComponent({ name: 'BCard' }).exists()).toBe(false);
    expect(wrapper.find('[aria-label="Selected entity summary"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('MECP2');
    expect(wrapper.text()).toContain('Rett syndrome');
    expect(wrapper.text()).toContain('Definitive');
  });
});
