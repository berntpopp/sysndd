// app/tests/e2e/toast.spec.ts
import { test, expect } from './fixtures/auth';
import type { Locator, Page } from '@playwright/test';

type ViewportCase = {
  name: string;
  width: number;
  height: number;
};

const viewports: ViewportCase[] = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'mobile', width: 390, height: 740 },
];

async function triggerBadLoginToast(page: Page) {
  await page.goto('/Login');
  await page.getByPlaceholder('User').fill('nopelogin');
  await page.getByPlaceholder('Password').fill('also-nope-pw');
  await page.getByRole('button', { name: /^Login$/ }).click();
}

async function visibleBox(locator: Locator) {
  await expect(locator).toBeVisible();
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  if (!box) {
    throw new Error('Expected visible element to have a bounding box');
  }
  return box;
}

test.describe('toast notifications', () => {
  for (const viewport of viewports) {
    test(`bad login renders a visible, chrome-aware toast on ${viewport.name}`, async ({
      page,
    }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await triggerBadLoginToast(page);

      const toast = page
        .locator('.toast')
        .filter({ hasText: /User or password wrong\.|Authentication failed\./ })
        .first();

      await expect(toast).toHaveClass(/show/);
      const toastBox = await visibleBox(toast);
      await expect(toast).toHaveAttribute('role', 'alert');

      const navbarBox = await visibleBox(page.locator('.app-navbar__bar').first());
      const footerBox = await visibleBox(page.locator('.app-footer__bar').first());

      expect(toastBox.y).toBeGreaterThanOrEqual(navbarBox.y + navbarBox.height + 4);
      expect(toastBox.y + toastBox.height).toBeLessThanOrEqual(footerBox.y - 4);
      expect(toastBox.x).toBeGreaterThanOrEqual(8);
      expect(toastBox.x + toastBox.width).toBeLessThanOrEqual(viewport.width - 8);
    });
  }
});
