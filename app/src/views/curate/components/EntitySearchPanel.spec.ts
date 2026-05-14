import { describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';

import EntitySearchPanel from './EntitySearchPanel.vue';

const mountPanel = (props = {}) =>
  mount(EntitySearchPanel, {
    props: {
      modelValue: null,
      displayValue: '',
      searchResults: [],
      loading: false,
      ...props,
    },
    global: {
      stubs: {
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        AutocompleteInput: {
          props: ['modelValue', 'displayValue', 'loading'],
          emits: ['search', 'update:model-value', 'update:display-value'],
          template: `
            <input
              aria-label="Entity"
              :value="displayValue"
              @input="$emit('update:display-value', $event.target.value)"
              @change="$emit('search', $event.target.value)"
            />
          `,
        },
      },
    },
  });

describe('EntitySearchPanel', () => {
  it('renders a compact search state without a bordered card wrapper', () => {
    const wrapper = mountPanel();

    expect(wrapper.find('.entity-search-panel').exists()).toBe(true);
    expect(wrapper.findComponent({ name: 'BCard' }).exists()).toBe(false);
    expect(wrapper.text()).toContain('Search by sysndd ID');
    expect(wrapper.text()).toContain('No entity selected');
  });

  it('surfaces loading and selected states while preserving emitted search updates', async () => {
    const wrapper = mountPanel({ modelValue: 501, loading: true, displayValue: 'MECP2' });
    const input = wrapper.get('input');

    expect(wrapper.text()).toContain('Searching');
    expect(wrapper.text()).toContain('Selected entity 501');

    await input.setValue('SCN2A');
    await input.trigger('change');

    expect(wrapper.emitted('update:display-value')?.[0]).toEqual(['SCN2A']);
    expect(wrapper.emitted('search')?.[0]).toEqual(['SCN2A']);
  });
});
