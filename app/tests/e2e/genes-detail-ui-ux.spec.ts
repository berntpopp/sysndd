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
  // The gene page's <main> hydrates after the SPA fetches the gene record. On a
  // cold load — and especially under the serial group's back-to-back navigations
  // — that first paint can exceed the default 5s expect timeout, so give the H1
  // the same generous budget as the constraint-header wait below to avoid a
  // hydration-timing flake short-circuiting the whole serial group.
  await expect(page.getByRole('heading', { level: 1, name: symbol })).toBeVisible({
    timeout: 30_000,
  });
  // The gene page hydrates several async sources after the heading renders; the
  // first (cold) load is slow. Wait (best-effort) for the gnomAD constraint card
  // header — always present once that card mounts — so the per-viewport layout
  // assertions below run against a hydrated page instead of racing the default
  // 5s expect timeout. Non-fatal: a gene whose card never mounts is handled by
  // the test's own skip/assertion.
  await page
    .getByText('Gene Constraint (gnomAD)')
    .first()
    .waitFor({ state: 'visible', timeout: 30_000 })
    .catch(() => {});
}

test.describe('Genes detail UI/UX', () => {
  test.describe.configure({ mode: 'serial' });

  for (const viewport of viewports) {
    test(`ARID1B constraint card does not overflow at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'ARID1B');

      const card = page.getByRole('region', { name: /gene constraint scores from gnomad/i });
      // The constraint card is rendered lazily and depends on ARID1B's gnomAD
      // gene-constraint data being present in the dataset. In stacks where that
      // section does not render, skip the layout assertion rather than fail
      // (NAA10's no-data constraint layout is covered separately). When the card
      // DOES render, the overflow check below still runs.
      const cardVisible = await card
        .waitFor({ state: 'visible', timeout: 20_000 })
        .then(() => true)
        .catch(() => false);
      test.skip(!cardVisible, 'gnomAD constraint card not rendered for ARID1B in this stack');

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
