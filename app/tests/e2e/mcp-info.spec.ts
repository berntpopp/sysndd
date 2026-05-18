import { expect, test } from '@playwright/test';

test.describe('MCP public information and protocol proxy', () => {
  test('renders the browser information page at /mcp', async ({ page }) => {
    await page.goto('/mcp');

    await expect(page.getByRole('heading', { name: 'SysNDD MCP' })).toBeVisible();
    await expect(page.getByText('not the public MCP transport endpoint')).toBeVisible();
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

    expect(response.ok()).toBe(true);
    const body = await response.json();
    expect(body.result.serverInfo.name).toBe('SysNDD read-only MCP');
    expect(body.result.instructions).toContain('read-only access');
  });
});
