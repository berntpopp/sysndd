import { expect, test } from './fixtures/auth';

const routes = [
  {
    name: 'curation comparisons',
    path: '/CurationComparisons/Table',
    maxMobileRowHeight: 155,
  },
  {
    name: 'entities',
    path: '/Entities?sort=%2Bentity_id&page_size=10',
    maxMobileRowHeight: 155,
  },
  {
    name: 'genes',
    path: '/Genes?sort=%2Bsymbol&page_after=0&page_size=10',
    maxMobileRowHeight: 145,
  },
  {
    name: 'phenotypes',
    path: '/Phenotypes?sort=entity_id&filter=all%28modifier_phenotype_id%2CHP%3A0001249%29&page_size=10',
    maxMobileRowHeight: 175,
  },
  {
    name: 'panels',
    path: '/Panels/All/All',
    maxMobileRowHeight: 155,
  },
];

test.describe.configure({ mode: 'serial' });

async function waitForTableRoute(page: import('@playwright/test').Page, path: string) {
  await page.goto(path);
  await page.waitForLoadState('networkidle');
  await expect(page.locator('.table-shell').first()).toBeVisible({ timeout: 15_000 });
}

for (const route of routes) {
  test(`${route.name} has no horizontal overflow on mobile`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    await waitForTableRoute(page, route.path);

    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });

  test(`${route.name} renders compact mobile records`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    await waitForTableRoute(page, route.path);

    const rows = page.locator('[role="listitem"]');
    const rowCount = await rows.count();

    if (rowCount === 0) {
      await expect(page.locator('.mobile-table-list__empty')).toBeVisible();
      return;
    }

    await expect(rows.first()).toBeVisible();
    const firstFive = await rows.evaluateAll((elements) =>
      elements.slice(0, 5).map((element) => element.getBoundingClientRect().height)
    );
    const average = firstFive.reduce((sum, height) => sum + height, 0) / firstFive.length;
    expect(average).toBeLessThanOrEqual(route.maxMobileRowHeight);
  });

  test(`${route.name} keeps desktop table semantics`, async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 900 });
    await waitForTableRoute(page, route.path);

    await expect(page.locator('table').first()).toBeVisible();
    await expect(page.locator('thead').first()).toBeVisible();
  });
}
