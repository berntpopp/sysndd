// app/tests/e2e/shell-layout.spec.ts
// Layout guards for the app shell and public detail pages (UI quality round 2026-11).
// Read-only: public pages only, no fixtures needed.
import { test, expect, type Page } from '@playwright/test';

async function open(page: Page, path: string): Promise<void> {
  await page.addInitScript(() =>
    localStorage.setItem(
      'sysndd-disclaimer',
      JSON.stringify({ isAcknowledged: true, acknowledgmentTimestamp: '2026-01-01T00:00:00Z' })
    )
  );
  await page.goto(path);
}

test.describe('app shell', () => {
  test('content is not centred by the shell and modals use the app font', async ({ page }) => {
    await open(page, '/About');
    await expect(page.locator('main h1').first()).toBeVisible();
    expect(await page.locator('#main').evaluate((el) => getComputedStyle(el).textAlign)).not.toBe(
      'center'
    );
    const bodyFont = await page.evaluate(() => getComputedStyle(document.body).fontFamily);
    expect(bodyFont).toContain('Avenir');
  });

  test('phones: skip link is off-screen until focused, and only the header has a hamburger', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await open(page, '/');
    const skip = page.locator('.skip-link');
    const box = await skip.boundingBox();
    expect(box && box.y + box.height).toBeLessThanOrEqual(0);
    await page.keyboard.press('Tab');
    await expect(skip).toBeFocused();
    // Slides in over 150 ms.
    await expect.poll(async () => (await skip.boundingBox())!.y).toBeGreaterThanOrEqual(0);

    const hamburgers = page.locator('.navbar-toggler-icon');
    await expect(hamburgers).toHaveCount(1);
    await expect(page.getByRole('button', { name: /^Partners/ })).toBeVisible();
  });

  test('phones: the API hero stacks instead of squeezing the title', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await open(page, '/API');
    const hero = page.locator('.public-hero');
    await expect(hero).toBeVisible();
    expect(await hero.evaluate((el) => getComputedStyle(el).flexDirection)).toBe('column');
  });

  test('404 links home', async ({ page }) => {
    await open(page, '/this-page-does-not-exist');
    await expect(page.getByRole('heading', { level: 1, name: 'Page not found' })).toBeVisible();
    await page.getByRole('link', { name: 'Go to home' }).click();
    await expect(page).toHaveURL(/\/$/);
  });
});

test.describe('entity page', () => {
  test('the disease chip stays inside its card at 1366 px', async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await open(page, '/Entities/1848');
    const chip = page.locator('.entity-unit-disease .disease-badge');
    await expect(chip).toBeVisible();
    const cell = await page.locator('.entity-unit-disease').boundingBox();
    const chipBox = await chip.boundingBox();
    expect(chipBox!.x + chipBox!.width).toBeLessThanOrEqual(cell!.x + cell!.width + 0.5);
  });
});
