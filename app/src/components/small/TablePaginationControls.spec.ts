import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TablePaginationControls from './TablePaginationControls.vue';

const stubs = {
  BInputGroup: { template: '<div><slot /></div>' },
  BFormSelect: {
    props: ['modelValue', 'options'],
    template:
      '<select v-bind="$attrs" @change="$emit(\'update:modelValue\', Number($event.target.value))"><option v-for="option in options" :key="option" :value="option">{{ option }}</option></select>',
    emits: ['update:modelValue'],
  },
  BPagination: {
    props: ['modelValue', 'limit'],
    template:
      '<nav v-bind="$attrs" :data-limit="limit" @click="$emit(\'update:modelValue\', 2)"><button>Next</button></nav>',
    emits: ['update:modelValue'],
  },
};

describe('TablePaginationControls', () => {
  it('uses the supplied descriptive labels for page size and pagination', () => {
    const wrapper = mount(TablePaginationControls, {
      props: {
        totalRows: 30,
        label: 'Manage users pagination',
        perPageLabel: 'Users per page',
      },
      global: { stubs },
    });

    expect(wrapper.get('[role="group"]').attributes('aria-label')).toBe('Manage users pagination');
    expect(wrapper.get('select').attributes('aria-label')).toBe('Users per page');
    expect(wrapper.get('nav').attributes('aria-label')).toBe('Manage users pagination');
  });

  it('preserves numeric per-page and page-change payloads', async () => {
    const wrapper = mount(TablePaginationControls, {
      props: { totalRows: 30 },
      global: { stubs },
    });

    await wrapper.get('select').setValue('25');
    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('per-page-change')).toEqual([[25]]);
    expect(wrapper.emitted('page-change')).toEqual([[2]]);
  });

  it('keeps the active page visible on phones and states the page count', () => {
    const wrapper = mount(TablePaginationControls, {
      props: { totalRows: 5150, currentPage: 3 },
      global: { stubs },
    });

    // limit 2 let bootstrap-vue-next hide the active page below sm (PUB-03 / ADM-10)
    expect(Number(wrapper.get('nav').attributes('data-limit'))).toBeGreaterThanOrEqual(3);
    expect(wrapper.text()).toContain('Page 3 of 515');
  });

  it('omits the pager buttons and count when everything fits on one page', () => {
    const wrapper = mount(TablePaginationControls, {
      props: { totalRows: 4 },
      global: { stubs },
    });
    expect(wrapper.text()).not.toContain('Page 1 of');
    // no "« ‹ › »" row of disabled buttons for a single page; its height stays reserved
    expect(wrapper.find('.table-pager--single nav').exists()).toBe(true);
  });
});
