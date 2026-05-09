import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TableShell from './TableShell.vue';

describe('TableShell', () => {
  it('renders title, description, meta, actions, toolbar, and body slots', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Entities',
        description: 'Gene-inheritance-disease records',
        meta: '2,605 records',
      },
      slots: {
        actions: '<button type="button">Export</button>',
        toolbar: '<label>Search<input aria-label="Search entities" /></label>',
        default: '<table><tbody><tr><td>ARID1B</td></tr></tbody></table>',
      },
    });

    expect(wrapper.text()).toContain('Entities');
    expect(wrapper.text()).toContain('Gene-inheritance-disease records');
    expect(wrapper.text()).toContain('2,605 records');
    expect(wrapper.find('button').text()).toBe('Export');
    expect(wrapper.find('input[aria-label="Search entities"]').exists()).toBe(true);
    expect(wrapper.find('td').text()).toBe('ARID1B');
  });

  it('uses the loading slot when loading is true', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Genes',
        loading: true,
      },
      slots: {
        loading: '<div data-testid="loading">Loading genes</div>',
        default: '<div data-testid="body">Loaded</div>',
      },
    });

    expect(wrapper.find('[data-testid="loading"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="body"]').exists()).toBe(false);
  });

  it('renders the default loading state when no loading slot is provided', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Genes',
        loading: true,
      },
      slots: {
        default: '<div data-testid="body">Loaded</div>',
      },
    });

    expect(wrapper.find('[role="status"]').attributes('aria-label')).toBe('Loading table data');
    expect(wrapper.find('[data-testid="body"]').exists()).toBe(false);
  });
});
