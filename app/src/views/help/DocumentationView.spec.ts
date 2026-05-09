import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import DocumentationView from './DocumentationView.vue';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

const bootstrapStubs = {
  BSpinner: { template: '<div role="status" />' },
  BContainer: { template: '<div><slot /></div>' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BCard: { template: '<article><slot /></article>' },
  BAccordion: { template: '<div><slot /></div>' },
  BAccordionItem: { template: '<section><slot name="title" /><slot /></section>' },
  BLink: { template: '<a><slot /></a>' },
  BListGroup: { template: '<ul><slot /></ul>' },
  BListGroupItem: { template: '<li><slot /></li>' },
  BAlert: { template: '<div role="alert"><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
};

describe('DocumentationView', () => {
  it('renders documentation content inside the modern public content shell', () => {
    const wrapper = mount(DocumentationView, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    expect(wrapper.find('.public-page').exists()).toBe(true);
    expect(wrapper.find('.public-shell').exists()).toBe(true);
    expect(wrapper.find('.public-hero').exists()).toBe(true);
    expect(wrapper.find('.public-panel').exists()).toBe(true);
    expect(wrapper.findAll('.public-action-card')).toHaveLength(3);
  });
});
