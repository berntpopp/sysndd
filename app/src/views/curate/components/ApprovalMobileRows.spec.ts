import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import ApprovalMobileRows from './ApprovalMobileRows.vue';

const item = {
  entity_id: 42,
  symbol: 'MECP2',
  hgnc_id: 'HGNC:6990',
  disease_ontology_name: 'Rett syndrome',
  disease_ontology_id_version: 'OMIM:312750_2024-01-01',
  hpo_mode_of_inheritance_term_name: 'X-linked inheritance',
  hpo_mode_of_inheritance_term: 'HP:0001417',
  category: 'Definitive',
  review_user_name: 'curator_one',
  review_user_role: 'Curator',
  review_date: '2026-05-01T12:30:00Z',
  comment: 'Needs confirmation.',
};

describe('ApprovalMobileRows', () => {
  it('renders compact approval rows and emits row actions', async () => {
    const wrapper = mount(ApprovalMobileRows, {
      props: {
        items: [item],
        userField: 'review_user_name',
        roleField: 'review_user_role',
        dateField: 'review_date',
        showStatusEdit: true,
      },
      global: {
        stubs: {
          BLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
          CategoryIcon: { props: ['category'], template: '<span>{{ category }}</span>' },
          DiseaseBadge: { props: ['name'], template: '<span>{{ name }}</span>' },
          EntityBadge: { props: ['entityId'], template: '<span>sysndd:{{ entityId }}</span>' },
          GeneBadge: { props: ['symbol'], template: '<span>{{ symbol }}</span>' },
          InheritanceBadge: { props: ['fullName'], template: '<span>{{ fullName }}</span>' },
        },
      },
    });

    expect(wrapper.text()).toContain('sysndd:42');
    expect(wrapper.text()).toContain('MECP2');
    expect(wrapper.text()).toContain('Rett syndrome');
    expect(wrapper.text()).toContain('Definitive');
    expect(wrapper.text()).toContain('Curator');
    expect(wrapper.text()).toContain('curator_one');
    expect(wrapper.text()).toContain('2026-05-01');

    const buttons = wrapper.findAll('button');
    await buttons
      .find((button) => button.attributes('aria-label')?.startsWith('Show details'))!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label')?.startsWith('Edit'))!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label')?.startsWith('Edit status'))!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label')?.startsWith('Approve'))!
      .trigger('click');
    await buttons
      .find((button) => button.attributes('aria-label')?.startsWith('Dismiss'))!
      .trigger('click');

    expect(wrapper.text()).toContain('Needs confirmation.');
    expect(wrapper.emitted('edit')?.[0]).toEqual([item]);
    expect(wrapper.emitted('edit-status')?.[0]).toEqual([item]);
    expect(wrapper.emitted('approve')?.[0]).toEqual([item]);
    expect(wrapper.emitted('dismiss')?.[0]).toEqual([item]);
  });
});
