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
  it('documents the credential-free public MCP transport and shared fair-use behavior', () => {
    const wrapper = mount(McpInfoView, {
      global: {
        stubs: bootstrapStubs,
      },
    });

    const text = wrapper.text().replace(/\s+/g, ' ');
    expect(wrapper.find('.public-page').exists()).toBe(true);
    expect(wrapper.find('.public-shell').exists()).toBe(true);
    expect(wrapper.find('.public-hero').exists()).toBe(true);
    expect(wrapper.find('.public-panel').exists()).toBe(true);
    expect(text).toContain('SysNDD MCP');
    expect(text).toContain('Read-only');
    expect(text).toContain(`${window.location.origin}/mcp`);
    expect(text).toContain('No SysNDD account, API key, or access token is required');
    expect(text).toContain('leave authentication unset');
    expect(text).toContain('shared capacity');
    expect(text).toContain('HTTP 429');
    expect(text).toContain('retry with backoff');
    expect(text).toContain('cache stable results');
    expect(text).toContain('Standalone SSE listening is not currently offered');
    expect(text).toContain('operational probes negotiate MCP 2025-11-25');
    expect(text).toContain('newer 2026-07-28 revision');
    expect(text).toContain('one client can temporarily exhaust it for everyone');
    expect(text).toContain('HTTP 403');
    expect(
      wrapper
        .find(
          'a[href="https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http"]'
        )
        .exists()
    ).toBe(true);
    expect(text).not.toMatch(
      /access-protected|protected URL|token-protected|Authorization:\s*Bearer|Bearer\s*<token>|access token your operator|then authenticate|pick the auth method/i
    );
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
