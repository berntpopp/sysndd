import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import TableShell from './TableShell.vue';

const shellSource = readFileSync(
  resolve(process.cwd(), 'src/components/table/TableShell.vue'),
  'utf8'
);

describe('TableShell', () => {
  it('renders title, description, meta, actions, toolbar, and body slots', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Entities',
        description: 'Gene-inheritance-disease records',
        meta: '2,605 records',
      },
      slots: {
        'title-actions': '<button type="button" aria-label="Explain table">?</button>',
        actions: '<button type="button">Export</button>',
        toolbar: '<label>Search<input aria-label="Search entities" /></label>',
        default: '<table><tbody><tr><td>ARID1B</td></tr></tbody></table>',
      },
    });

    expect(wrapper.text()).toContain('Entities');
    expect(wrapper.text()).toContain('Gene-inheritance-disease records');
    expect(wrapper.text()).toContain('2,605 records');
    expect(wrapper.get('button[aria-label="Explain table"]').text()).toBe('?');
    expect(wrapper.findAll('button').at(1)?.text()).toBe('Export');
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

  it('keeps heading-level behavior while using semantic shell tokens', () => {
    const defaultHeading = mount(TableShell, {
      props: { title: 'Default heading' },
    });
    const routeHeading = mount(TableShell, {
      props: { title: 'Route heading', headingLevel: 1 },
    });
    const scopedStyle = shellSource.match(/<style scoped>([\s\S]*?)<\/style>/)?.[1] ?? '';

    expect(defaultHeading.get('h2').text()).toBe('Default heading');
    expect(routeHeading.get('h1').text()).toBe('Route heading');
    expect(scopedStyle).toContain('background: var(--surface-raised);');
    expect(scopedStyle).toContain('background: var(--surface-subtle);');
    expect(scopedStyle).toContain('color: var(--text-primary);');
    expect(scopedStyle).toContain('color: var(--text-secondary);');
    expect(scopedStyle).toContain('color: var(--text-muted);');
    expect(scopedStyle).toContain('border: 1px solid var(--border-subtle);');
    expect(scopedStyle).not.toMatch(/#[\da-f]{3,8}\b|rgba?\(/i);
  });
});
