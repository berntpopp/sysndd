import { expect, test } from '@playwright/test';

const landmarkRoutes = [
  { path: '/', name: 'Home' },
  { path: '/DataReleases', name: 'Data Releases' },
  { path: '/GeneNetworks', name: 'Gene Networks' },
];

const viewports = [
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
];

for (const viewport of viewports) {
  test.describe(`public route landmarks — ${viewport.name}`, () => {
    test.beforeEach(async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
    });

    for (const route of landmarkRoutes) {
      test(`${route.name} has one main and distinguishable navigation landmarks`, async ({
        page,
      }) => {
        await page.goto(route.path);

        await expect(page.getByRole('main')).toHaveCount(1);
        await expect(page.getByRole('navigation', { name: 'Primary navigation' })).toBeVisible();
        await expect(page.getByRole('navigation', { name: 'Footer navigation' })).toBeVisible();
      });
    }

    test('MCP code regions are named and keyboard focusable', async ({ page }) => {
      await page.goto('/mcp');

      const codeRegions = page.locator('.mcp-code');
      await expect(codeRegions).toHaveCount(3);

      for (let index = 0; index < 3; index += 1) {
        const region = codeRegions.nth(index);
        await region.focus();
        await expect(region).toBeFocused();
        await expect(region).toHaveAttribute('aria-label', /.+/);
      }
    });

    test('Gene Networks exposes a keyboard-operable splitter', async ({ page }) => {
      await page.goto('/GeneNetworks');

      const separator = page.getByRole('separator', {
        name: 'Resize gene network and cluster table',
      });
      await expect(separator).toBeVisible();
      await expect(separator).toHaveAttribute('aria-orientation', 'vertical');
      await expect(separator).toHaveAttribute('aria-valuemin', '25');
      await expect(separator).toHaveAttribute('aria-valuemax', '75');

      await separator.focus();
      const initialValue = Number(await separator.getAttribute('aria-valuenow'));
      await page.keyboard.press('ArrowRight');
      await expect(separator).toHaveAttribute('aria-valuenow', String(initialValue + 2));
      await page.keyboard.press('Home');
      await expect(separator).toHaveAttribute('aria-valuenow', '25');
      await page.keyboard.press('End');
      await expect(separator).toHaveAttribute('aria-valuenow', '75');
    });
  });
}
