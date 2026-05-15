import { test, expect, type Page } from './fixtures/auth';

function captureHardErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (error) => {
    errors.push(`pageerror: ${error.message}`);
  });
  return errors;
}

test('ManagePubtator exposes usable query, fetch, and danger controls', async ({ loggedInAs }) => {
  const page = await loggedInAs('admin');
  const errors = captureHardErrors(page);

  await page.goto('/ManagePubtator');
  await expect(page.getByTestId('authenticated-page-shell')).toBeVisible();

  const queryWorkspace = page.getByTestId('pubtator-query-workspace');
  await expect(queryWorkspace).toBeVisible();
  await queryWorkspace.locator('#query-input').fill('autism AND gene');

  const fetchWorkspace = page.getByTestId('pubtator-fetch-workspace');
  await expect(fetchWorkspace).toBeVisible();
  await fetchWorkspace.locator('#max-pages').fill('12');
  await fetchWorkspace.getByText('Hard update: clear existing cache first').click();
  await expect(fetchWorkspace.getByRole('button', { name: /submit fetch job/i })).toBeEnabled();

  const dangerZone = page.getByTestId('pubtator-danger-zone');
  await expect(dangerZone).toBeVisible();
  await dangerZone.getByRole('button', { name: /clear all cache/i }).click();
  await expect(page.getByRole('dialog', { name: /clear all pubtator cache/i })).toBeVisible();
  await page.getByRole('button', { name: /cancel/i }).click();
  await expect(page.getByRole('dialog', { name: /clear all pubtator cache/i })).toBeHidden();

  expect(errors.filter((error) => !/websocket|hmr|devtools/i.test(error))).toEqual([]);
});
