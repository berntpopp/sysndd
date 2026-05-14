import { test, expect } from './fixtures/auth';

test('ViewLogs shows an inline loader while logs are loading', async ({ loggedInAs }) => {
  const page = await loggedInAs('admin');

  await page.route('**/api/logs/?**', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 800));
    await route.continue();
  });

  await page.goto('/ViewLogs?sort=-id&page_size=10');

  await expect(page.getByTestId('logs-loading-state')).toBeVisible();
  await expect(page.getByTestId('logs-loading-state')).toBeHidden({ timeout: 15_000 });
  await expect(page.getByText(/Loaded 10\//)).toBeVisible();
});
