import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import McpInfoView from './McpInfoView.vue';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

const bootstrapStubs = {
  BAlert: { template: '<div role="alert"><slot /></div>' },
  BLink: { template: '<a><slot /></a>' },
};

describe('McpInfoView', () => {
  it('explains that /mcp is an information page, not the public tool endpoint', () => {
    const wrapper = mount(McpInfoView, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    expect(wrapper.find('.public-page').exists()).toBe(true);
    expect(wrapper.find('.public-shell').exists()).toBe(true);
    expect(wrapper.find('.public-hero').exists()).toBe(true);
    expect(wrapper.find('.public-panel').exists()).toBe(true);
    expect(wrapper.text()).toContain('SysNDD MCP');
    expect(wrapper.text()).toContain('Read-only');
    expect(wrapper.text()).toContain('not the public MCP transport endpoint');
    expect(wrapper.text()).toContain(`${window.location.origin}/mcp`);
    expect(wrapper.text()).toContain('protected');
  });
});
