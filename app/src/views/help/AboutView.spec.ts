import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AboutView from './AboutView.vue';

const source = readFileSync(resolve(process.cwd(), 'src/views/help/AboutView.vue'), 'utf8');

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/api/about', () => ({
  getPublishedAbout: vi.fn().mockRejectedValue(new Error('CMS unavailable')),
}));

vi.mock('@/api/version', () => ({
  getVersion: vi.fn().mockResolvedValue({
    version: '0.20.18',
    commit: 'abcdef1',
    title: 'SysNDD API',
    description: 'desc',
    database: { version: '1.0.0', commit: '7532ab5', available: true },
  }),
}));

vi.mock('@/composables', () => ({
  renderMarkdown: (value: string) => value,
}));

const bootstrapStubs = {
  BSpinner: { template: '<div role="status" />' },
  BContainer: { template: '<div><slot /></div>' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BAccordion: { template: '<div><slot /></div>' },
  BAccordionItem: { template: '<section><slot name="title" /><slot /></section>' },
  BLink: { template: '<a><slot /></a>' },
  BListGroup: { template: '<ul><slot /></ul>' },
  BListGroupItem: { template: '<li><slot /></li>' },
  BCard: { template: '<article><slot /></article>' },
  BAlert: { template: '<div role="alert"><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
};

describe('AboutView', () => {
  it('renders fallback content inside the modern public content shell', async () => {
    const wrapper = mount(AboutView, {
      global: {
        stubs: bootstrapStubs,
        directives: {
          dompurifyHtml: {
            mounted: () => undefined,
          },
        },
      },
    });

    await flushPromises();

    expect(wrapper.find('.public-page').exists()).toBe(true);
    expect(wrapper.find('.public-shell').exists()).toBe(true);
    expect(wrapper.find('.public-hero').exists()).toBe(true);
    expect(wrapper.find('.public-panel').exists()).toBe(true);
  });

  it('uses shared bounded surfaces without decorative side accents', () => {
    expect(source).not.toMatch(/border-(?:left|right)\s*:/);
    expect(source).toContain('border: 1px solid var(--border-subtle');
    expect(source).toContain('background: var(--surface-subtle);');
  });
});
