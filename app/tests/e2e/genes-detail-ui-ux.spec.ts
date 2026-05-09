import type { Page } from '@playwright/test';
import { test, expect } from '@playwright/test';
import { AxeBuilder } from '@axe-core/playwright';

const viewports = [
  { name: 'mobile-390', width: 390, height: 844 },
  { name: 'tablet-768', width: 768, height: 1024 },
  { name: 'laptop-1024', width: 1024, height: 768 },
  { name: 'mid-1280', width: 1280, height: 800 },
  { name: 'mid-1366', width: 1366, height: 768 },
  { name: 'desktop-1440', width: 1440, height: 900 },
  { name: 'wide-1920', width: 1920, height: 1080 },
];

async function gotoGene(page: Page, symbol: string) {
  await page.goto(`/Genes/${symbol}`);
  await expect(page.getByRole('heading', { level: 1, name: symbol })).toBeVisible();
}

test.describe('Genes detail UI/UX', () => {
  test.describe.configure({ mode: 'serial' });

  for (const viewport of viewports) {
    test(`ARID1B constraint card does not overflow at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'ARID1B');

      const card = page.getByRole('region', { name: /gene constraint scores from gnomad/i });
      await expect(card).toBeVisible();

      const overflow = await card.evaluate((el) => {
        const cardEl = el as HTMLElement;
        const descendants = Array.from(cardEl.querySelectorAll<HTMLElement>('*'));
        return [cardEl, ...descendants].some((node) => node.scrollWidth > node.clientWidth + 1);
      });

      expect(overflow).toBe(false);
    });

    test(`NAA10 keeps gnomAD no-data card and link visible at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'NAA10');

      await expect(page.getByText('Gene Constraint (gnomAD)').first()).toBeVisible();
      await expect(page.getByText('No gnomAD constraint data available for this gene.')).toBeVisible();
      await expect(page.getByRole('link', { name: /view gene on gnomad/i })).toBeVisible();
    });
  }

  test('ARID1B page-scoped axe target rules pass at 1280', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await gotoGene(page, 'ARID1B');

    const result = await new AxeBuilder({ page })
      .include('main')
      .exclude('header, nav, footer')
      .analyze();

    const targetIds = new Set([
      'aria-prohibited-attr',
      'color-contrast',
      'heading-order',
      'page-has-heading-one',
      'label-content-name-mismatch',
    ]);
    const targetViolations = result.violations.filter((violation) => targetIds.has(violation.id));
    expect(targetViolations).toEqual([]);
  });

  for (const viewport of [
    { name: 'mobile-390', width: 390, height: 844 },
    { name: 'tablet-768', width: 768, height: 1024 },
    { name: 'desktop-1440', width: 1440, height: 900 },
  ]) {
    test(`ARID1B protein view does not create an internal scrollbar at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'ARID1B');

      const panel = page.locator('.visualization-panel--protein');
      await expect(panel).toBeVisible();

      const scrollState = await panel.evaluate((el) => {
        const panelEl = el as HTMLElement;
        const style = window.getComputedStyle(panelEl);
        return {
          overflowY: style.overflowY,
          maxHeight: style.maxHeight,
          hasVerticalScroll: panelEl.scrollHeight > panelEl.clientHeight + 1,
        };
      });

      expect(scrollState).toEqual({
        overflowY: 'visible',
        maxHeight: 'none',
        hasVerticalScroll: false,
      });
    });
  }

  test('navbar search is rendered with valid list semantics', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await gotoGene(page, 'ARID1B');

    const navbarLists = page.locator('ul.navbar-nav');
    await expect(navbarLists.first()).toBeVisible();
    await expect(navbarLists).not.toHaveCount(0);

    const invalidDirectChildren = await navbarLists.evaluateAll((lists) =>
      lists.flatMap((list) =>
        Array.from(list.children)
          .filter((child) => child.tagName.toLowerCase() !== 'li')
          .map((child) => child.outerHTML),
      ),
    );
    expect(invalidDirectChildren).toEqual([]);
  });
});
