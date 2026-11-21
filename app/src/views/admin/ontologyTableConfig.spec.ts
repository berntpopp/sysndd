import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import GenericTable from '@/components/small/GenericTable.vue';
import { ONTOLOGY_TABLE_FIELDS } from './ontologyTableConfig';

describe('ONTOLOGY_TABLE_FIELDS', () => {
  it('renders flags as Yes/No and dates in the long style, not raw 0/1 or ISO', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items: [
          {
            vario_id: 'VariO:0001',
            vario_name: 'variation',
            definition: 'A change',
            obsolete: 0,
            is_active: 1,
            sort: 3,
            update_date: '2026-11-21 12:10:50',
          },
        ],
        fields: ONTOLOGY_TABLE_FIELDS,
      },
      global: { directives: { 'b-tooltip': () => {} } },
    });
    const cells = wrapper.findAll('tbody td').map((td) => td.text());
    expect(cells).toContain('No');
    expect(cells).toContain('Yes');
    expect(cells).toContain('November 21, 2026');
    expect(wrapper.find('td[title="2026-11-21 12:10:50"]').exists()).toBe(true);
    expect(wrapper.findAll('thead th').map((th) => th.text())).toContain('Order');
  });
});
