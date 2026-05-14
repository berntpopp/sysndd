import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import OntologyMobileRows from './OntologyMobileRows.vue';

describe('OntologyMobileRows', () => {
  it('renders compact ontology rows and emits edit for the selected term', async () => {
    const item = {
      vario_id: 'VariO:0001',
      vario_name: 'Example term',
      definition: 'A concise definition',
      obsolete: 0,
      is_active: 1,
      sort: 10,
      update_date: '2026-05-01T10:00:00Z',
    };

    const wrapper = mount(OntologyMobileRows, {
      props: { items: [item] },
    });

    expect(wrapper.text()).toContain('VariO:0001');
    expect(wrapper.text()).toContain('Example term');
    expect(wrapper.text()).toContain('Active');
    expect(wrapper.text()).toContain('Current');

    await wrapper.get('button[aria-label="Edit ontology VariO:0001"]').trigger('click');

    expect(wrapper.emitted('edit')).toEqual([[item]]);
  });
});
