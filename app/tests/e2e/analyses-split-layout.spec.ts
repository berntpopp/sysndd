import { expect, test } from '@playwright/test';

// The resizable network/table splitter stacks its panes below 992 px, so a phone
// gets full-width panes instead of two ~180 px columns with per-character wrapping.
const pages = ['/PhenotypeCorrelations/PhenotypeClusters', '/GeneNetworks', '/Analysis'];

async function paneBoxes(page: import('@playwright/test').Page) {
  const panes = page.locator('.accessible-splitter > .splitpanes__pane');
  await expect(panes).toHaveCount(2, { timeout: 15_000 });
  return Promise.all([panes.nth(0).boundingBox(), panes.nth(1).boundingBox()]);
}

for (const path of pages) {
  test(`${path} stacks the split panes on a phone`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(path);
    const [first, second] = await paneBoxes(page);
    expect(first!.width).toBeGreaterThan(300);
    expect(second!.width).toBeGreaterThan(300);
    expect(second!.y).toBeGreaterThanOrEqual(first!.y + first!.height - 1);
    await expect(page.locator('.accessible-splitter > .splitpanes__splitter')).toBeHidden();
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });

  test(`${path} keeps the resizable side-by-side panes on a laptop`, async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.goto(path);
    const [first, second] = await paneBoxes(page);
    expect(Math.abs(first!.y - second!.y)).toBeLessThanOrEqual(1);
    await expect(page.locator('.accessible-splitter > .splitpanes__splitter')).toBeVisible();
  });
}
