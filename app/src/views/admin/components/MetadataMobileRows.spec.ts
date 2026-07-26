import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import MetadataMobileRows from './MetadataMobileRows.vue';
import type { MetadataVocabulary } from '@/api/metadata';

const vocabulary: MetadataVocabulary = {
  slug: 'modifier',
  label: 'Modifiers',
  table: 'modifier_list',
  pk: 'modifier_id',
  pk_type: 'integer',
  editable: true,
  managed: 'sysndd',
  fields: ['modifier_name', 'allowed_phenotype', 'allowed_variation'],
  has_is_active: true,
  has_sort: true,
};

const row = {
  modifier_id: 7,
  modifier_name: 'present',
  allowed_phenotype: 1,
  allowed_variation: 0,
  is_active: 1,
  sort: 10,
};

describe('MetadataMobileRows', () => {
  it('exposes the term, status, and permitted named actions', async () => {
    const wrapper = mount(MetadataMobileRows, {
      props: {
        items: [row],
        vocabulary,
        canDeactivate: true,
      },
    });

    expect(wrapper.text()).toContain('present');
    expect(wrapper.text()).toContain('Active');
    expect(wrapper.text()).toContain('Phenotype: Yes');
    expect(wrapper.text()).toContain('Variation: No');

    await wrapper.get('[aria-label="Edit metadata entry present"]').trigger('click');
    await wrapper.get('[aria-label="Deactivate metadata entry present"]').trigger('click');

    expect(wrapper.emitted('edit')?.[0]).toEqual([row]);
    expect(wrapper.emitted('deactivate')?.[0]).toEqual([row]);
  });

  it('preserves the role-limited deactivate condition', () => {
    const wrapper = mount(MetadataMobileRows, {
      props: {
        items: [row],
        vocabulary: { ...vocabulary, editable: 'anchored' },
        canDeactivate: false,
      },
    });

    expect(wrapper.find('[aria-label="Edit metadata entry present"]').exists()).toBe(true);
    expect(wrapper.find('[aria-label="Deactivate metadata entry present"]').exists()).toBe(false);
  });
});
