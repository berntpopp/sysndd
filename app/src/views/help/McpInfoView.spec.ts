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

  it('names every code region and makes long commands keyboard-scrollable', async () => {
    const wrapper = mount(McpInfoView, {
      attachTo: document.body,
      global: {
        stubs: bootstrapStubs,
      },
    });

    const guidance = wrapper.get('#mcp-code-scroll-guidance');
    expect(guidance.text()).toContain('arrow keys');

    const codeRegions = wrapper.findAll('.mcp-code');
    expect(codeRegions).toHaveLength(3);
    expect(new Set(codeRegions.map((region) => region.attributes('aria-label'))).size).toBe(3);

    for (const region of codeRegions) {
      expect(region.attributes('tabindex')).toBe('0');
      expect(region.attributes('aria-describedby')).toBe('mcp-code-scroll-guidance');
      (region.element as HTMLElement).focus();
      expect(document.activeElement).toBe(region.element);
    }

    wrapper.unmount();
  });
});
