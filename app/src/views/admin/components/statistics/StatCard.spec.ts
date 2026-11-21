import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const source = readFileSync(
  resolve(process.cwd(), 'src/views/admin/components/statistics/StatCard.vue'),
  'utf8'
);

describe('StatCard visual contract', () => {
  it('uses the shared surface hierarchy without a decorative side accent', () => {
    expect(source).not.toMatch(/border-(?:left|right)\s*:/);
    expect(source).toContain('border: 1px solid var(--border-subtle);');
    expect(source).toContain('background: var(--surface-raised);');
  });
});

describe('StatCard rendering', () => {
  it('shows a fixed number of decimals and an icon delta with a text alternative', async () => {
    const { mount } = await import('@vue/test-utils');
    const { default: StatCard } = await import('./StatCard.vue');
    const wrapper = mount(StatCard, {
      props: { label: 'Avg Per Day', value: 0.004, decimals: 2, delta: -100 },
    });
    expect(wrapper.text()).toContain('0.00');
    expect(wrapper.find('.bi-arrow-down').exists()).toBe(true);
    expect(wrapper.text()).toContain('Down');
    expect(wrapper.text()).not.toContain('↓');
    // Darkened vermilion (>= 4.5:1), not the 3.9:1 #D55E00.
    expect(wrapper.find('.stat-card__delta').attributes('style')).toContain('rgb(169, 68, 0)');
  });
});
