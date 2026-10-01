import { expect, test } from '@playwright/test';

const DOI = '10.64898/2026.09.29.755401';
const STORAGE_KEY = 'sysndd.publicationBanner.dismissedDoi';

test.describe('Home preprint announcement', () => {
  // A first visit shows the disclaimer dialog, which intercepts pointer events.
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() => {
      localStorage.setItem(
        'sysndd-disclaimer',
        JSON.stringify({ isAcknowledged: true, acknowledgmentTimestamp: new Date().toISOString() })
      );
    });
  });

  test('announces the preprint above the hero and links to it', async ({ page }) => {
    await page.goto('/');

    const banner = page.getByRole('complementary', { name: 'SysNDD preprint announcement' });
    await expect(banner).toBeVisible();
    await expect(banner).toContainText(`doi:${DOI}`);

    const link = banner.getByTestId('preprint-banner-link');
    await expect(link).toHaveAttribute('href', `https://www.biorxiv.org/content/${DOI}`);
    await expect(link).toHaveAttribute('target', '_blank');
    await expect(link).toHaveAttribute('rel', /noopener/);

    // The announcement precedes the hero and never causes horizontal overflow.
    const bannerBox = await banner.boundingBox();
    const heroBox = await page.locator('.home-hero').boundingBox();
    expect(bannerBox!.y + bannerBox!.height).toBeLessThanOrEqual(heroBox!.y);
    const overflows = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth
    );
    expect(overflows).toBe(false);
  });

  test('copies the citation', async ({ page, context, browserName }) => {
    test.skip(browserName !== 'chromium', 'clipboard permissions are Chromium-only');
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    await page.goto('/');

    const copy = page.getByTestId('preprint-banner-copy');
    await copy.click();
    await expect(copy).toContainText('Copied');

    const clipboard = await page.evaluate(() => navigator.clipboard.readText());
    expect(clipboard).toContain('SysNDD: A Systematic Database for Neurodevelopmental Disorders');
    expect(clipboard).toContain(`doi: ${DOI}`);
  });

  test('stays dismissed across reloads', async ({ page }) => {
    await page.goto('/');

    await page.getByRole('button', { name: 'Dismiss preprint announcement' }).click();
    await expect(page.getByTestId('preprint-banner')).toHaveCount(0);
    expect(await page.evaluate((key) => localStorage.getItem(key), STORAGE_KEY)).toBe(DOI);

    await page.reload();
    await expect(page.getByRole('heading', { level: 1, name: 'SysNDD' })).toBeVisible();
    await expect(page.getByTestId('preprint-banner')).toHaveCount(0);
  });
});
