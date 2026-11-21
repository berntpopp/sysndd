import { flushPromises, mount } from '@vue/test-utils';
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

  it('wraps code blocks and gives each a named copy button', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.assign(navigator, { clipboard: { writeText } });
    const wrapper = mount(McpInfoView, { global: { stubs: bootstrapStubs } });

    // Long lines wrap, so blocks are not scroll regions and need no arrow-key hint.
    expect(wrapper.find('#mcp-code-scroll-guidance').exists()).toBe(false);
    const codeRegions = wrapper.findAll('pre.mcp-code');
    expect(codeRegions).toHaveLength(3);
    for (const region of codeRegions) expect(region.attributes('tabindex')).toBeUndefined();

    const buttons = wrapper.findAll('button.mcp-copy');
    expect(buttons).toHaveLength(3);
    expect(buttons[0].attributes('aria-label')).toBe('Copy Claude Code MCP command');
    await buttons[0].trigger('click');
    await flushPromises();
    expect(writeText).toHaveBeenCalledWith(codeRegions[0].text());
    expect(buttons[0].text()).toBe('Copied');
    wrapper.unmount();
  });
});
