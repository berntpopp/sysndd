/**
 * LogFilterToolbar contract tests.
 *
 * The toolbar is presentational: it binds the filter object's nested `.content`
 * fields and surfaces user actions as events. These pin the action emits
 * (show-delete, remove-filters, clear-filter, filtered, update:mobileSortValue)
 * and the active-filter pill rendering.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import LogFilterToolbar from './LogFilterToolbar.vue';
import { createEmptyLogFilter } from './useLogTable';

const stubs = {
  TableSearchInput: {
    template: '<input class="search" @input="$emit(\'update:modelValue\', $event.target.value)" />',
    emits: ['update:modelValue'],
  },
  TablePaginationControls: { template: '<div class="pagination-stub" />' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BContainer: { template: '<div><slot /></div>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BFormSelect: {
    template:
      '<select v-bind="$attrs" @change="$emit(\'update:modelValue\', $event.target.value)"><option v-for="o in (options || [])" :key="o.value" :value="o.value">{{ o.text }}</option><slot /></select>',
    props: ['modelValue', 'options'],
    emits: ['update:modelValue'],
  },
  BFormSelectOption: { template: '<option><slot /></option>' },
  BFormInput: {
    template: '<input class="mobile-filter" @input="$emit(\'update:modelValue\', $event.target.value)" />',
    emits: ['update:modelValue'],
  },
  BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
  BBadge: { template: '<span class="badge"><slot /></span>' },
};

function mountToolbar(props = {}) {
  return mount(LogFilterToolbar, {
    props: {
      filter: createEmptyLogFilter(),
      totalRows: 42,
      perPage: 10,
      showPaginationControls: true,
      pageOptions: [10, 25],
      currentPage: 1,
      methodOptions: [{ value: 'GET', text: 'GET' }],
      statusOptions: [{ value: '200', text: '200 OK' }],
      mobileSortOptions: [
        { value: '-id', text: 'Newest ID first' },
        { value: '-timestamp', text: 'Newest time first' },
      ],
      mobileSortValue: '-id',
      itemsLength: 5,
      hasActiveFilters: false,
      activeFilters: [],
      ...props,
    },
    global: { stubs, directives: { 'b-tooltip': {} } },
  });
}

describe('LogFilterToolbar', () => {
  it('emits show-delete when the delete button is clicked', async () => {
    const wrapper = mountToolbar();
    await wrapper.find('button[title="Delete all logs (requires confirmation)"]').trigger('click');
    expect(wrapper.emitted('show-delete')).toHaveLength(1);
  });

  it('renders active-filter pills and emits clear-filter / remove-filters', async () => {
    const wrapper = mountToolbar({
      hasActiveFilters: true,
      activeFilters: [{ key: 'status', label: 'Status', value: '200' }],
    });
    const badges = wrapper.findAll('.badge');
    expect(badges).toHaveLength(1);
    expect(wrapper.text()).toContain('Status: 200');

    // Pill clear button (inside the badge)
    await badges[0].find('button').trigger('click');
    expect(wrapper.emitted('clear-filter')).toEqual([['status']]);

    // "Clear all" button
    const clearAll = wrapper.findAll('button').find((b) => b.text().includes('Clear all'));
    await clearAll!.trigger('click');
    expect(wrapper.emitted('remove-filters')).toHaveLength(1);
  });

  it('emits update-filter (key, value) when a filter select changes', async () => {
    const wrapper = mountToolbar({ methodOptions: [{ value: 'GET', text: 'GET' }] });
    const methodSelect = wrapper.findAll('select')[0];
    await methodSelect.setValue('GET');
    expect(wrapper.emitted('update-filter')).toEqual([['request_method', 'GET']]);
  });

  it('emits update:mobileSortValue when the mobile sort select changes', async () => {
    const wrapper = mountToolbar();
    // The mobile sort select is the last select (method, status, path, mobile-sort)
    const selects = wrapper.findAll('select');
    await selects[selects.length - 1].setValue('-timestamp');
    expect(wrapper.emitted('update:mobileSortValue')).toEqual([['-timestamp']]);
  });
});
