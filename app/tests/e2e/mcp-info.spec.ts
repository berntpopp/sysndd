import { expect, test } from '@playwright/test';

test.describe('MCP public information and protocol proxy', () => {
  test('renders the browser information page at /mcp', async ({ page }) => {
    await page.goto('/mcp');

    await expect(page.getByRole('heading', { name: 'SysNDD MCP' })).toBeVisible();
    await expect(
      page.getByText('No SysNDD account, API key, or access token is required')
    ).toBeVisible();
    await expect(
      page.locator('dl code').filter({ hasText: `${new URL(page.url()).origin}/mcp` })
    ).toBeVisible();
  });

  test('proxies MCP initialize requests through /mcp', async ({ request }) => {
    const response = await request.post('/mcp', {
      headers: {
        Accept: 'application/json, text/event-stream',
        'Content-Type': 'application/json',
        'MCP-Protocol-Version': '2025-11-25',
      },
      data: {
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2025-11-25',
          capabilities: {},
          clientInfo: { name: 'sysndd-playwright', version: '0.1' },
        },
      },
    });

    // The standard Playwright stack does not enable the opt-in `mcp` profile.
    // When MCP is absent, POST /mcp reaches the SPA service and this protocol-only
    // assertion is environment-gated. The browser test above always verifies the
    // public information contract; scripts/tests/test-mcp-traefik-edge.sh verifies
    // the production router labels against a disposable Traefik instance.
    if (!response.ok()) {
      test.skip(
        true,
        'MCP transport proxy is not enabled in this stack (/mcp serves the info page only)'
      );
    }
    const body = await response.json();
    expect(body.result.serverInfo.name).toBe('SysNDD read-only MCP');
    expect(body.result.instructions).toContain('read-only access');
  });
});
