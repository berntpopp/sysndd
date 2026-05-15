import type { Page } from '@playwright/test';
import type { DocsScreenshot, DocsScreenshotAction } from './manifest';

type SetupContext = {
  page: Page;
  entry: DocsScreenshot;
};

type SetupHelper = (context: SetupContext) => Promise<void>;

export const setupHelpers: Record<string, SetupHelper> = {
  async reviewerReviewPage({ page }) {
    await page.getByRole('heading', { name: /Re-review table/i }).waitFor({ timeout: 30_000 });
  },

  async geneDetailPage({ page }) {
    await page.getByRole('heading', { name: /CHD8/i }).first().waitFor({ timeout: 30_000 });
    await page.waitForFunction(
      () =>
        document.querySelectorAll(
          '[data-testid="entities-skeleton"], [data-testid="section-card-skeleton"], .spinner-border',
        ).length === 0,
      undefined,
      { timeout: 30_000 },
    );
    await page.getByRole('table').first().waitFor({ timeout: 30_000 });
  },

  async swaggerAuthScreen({ page }) {
    await page.waitForSelector('#swagger-ui', { timeout: 30_000 });
    await page.waitForSelector('.swagger-ui', { timeout: 30_000 }).catch(() => undefined);
    const authorizeButton = page.getByRole('button', { name: /authorize/i }).first();
    if (await authorizeButton.isVisible().catch(() => false)) {
      await authorizeButton.click();
      await page.waitForSelector('.modal-ux, .dialog-ux, .modal.show', { timeout: 10_000 }).catch(
        () => undefined,
      );
    }
  },
};

export const actionHelpers: Record<string, (page: Page, args?: Record<string, unknown>) => Promise<void>> = {
  async openFirstReviewEditModal(page) {
    const editButton = page.getByRole('button', { name: /edit review for/i }).first();
    await editButton.waitFor({ timeout: 20_000 });
    await editButton.click();
    await page.waitForSelector('.modal.show', { timeout: 10_000 });
  },
};

export async function runAction(page: Page, action: DocsScreenshotAction): Promise<void> {
  if (action.type === 'click') {
    await page.locator(action.selector).click();
    return;
  }
  if (action.type === 'fill') {
    await page.locator(action.selector).fill(action.value);
    return;
  }
  if (action.type === 'press') {
    await page.keyboard.press(action.key);
    return;
  }
  if (action.type === 'hover') {
    await page.locator(action.selector).hover();
    return;
  }
  if (action.type === 'waitFor') {
    await page.waitForSelector(action.selector, { timeout: 30_000 });
    return;
  }
  const helper = actionHelpers[action.name];
  if (!helper) {
    throw new Error(`Unknown docs screenshot action helper: ${action.name}`);
  }
  await helper(page, action.args);
}

export function targetUrl(entry: DocsScreenshot, baseURL: string): string {
  const rawBase =
    entry.baseURL === 'api'
      ? process.env.PLAYWRIGHT_API_BASE_URL ?? 'http://localhost'
      : baseURL;
  const path = entry.url ?? entry.route ?? '/';
  return new URL(path, rawBase).toString();
}
