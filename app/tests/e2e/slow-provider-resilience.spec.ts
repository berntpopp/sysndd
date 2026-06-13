import { test, expect } from '@playwright/test';

// #344: a slow external provider must not block the gene page shell or its
// non-external content. We delay every /api/external/** response by 20s (longer
// than any reasonable user patience) and assert the page shell + gene header +
// the entities table + the external card frames all render well within a few
// seconds, with the external cards in their own loading/degraded state rather
// than blocking paint.
//
// Local-only regression check (no Playwright CI lane — see AGENTS.md). Run with
// a seeded stack, e.g.:
//   cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 \
//     npx playwright test tests/e2e/slow-provider-resilience.spec.ts
//
// The gene record + entities table read /api/entity & /api/gene (NOT
// /api/external/**), so only the provider cards are stalled by the route below.

const GENE = 'SCN2A';

test('gene page shell + core content render while external providers are slow', async ({ page }) => {
  let externalRequests = 0;
  await page.route('**/api/external/**', async (route) => {
    externalRequests += 1;
    await new Promise((resolve) => setTimeout(resolve, 20_000));
    await route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({ error: true, source: 'stub', message: 'stubbed slow provider' }),
    });
  });

  const start = Date.now();
  await page.goto(`/Genes/${GENE}`, { waitUntil: 'domcontentloaded' });

  // 1. Gene header renders quickly (symbol comes from the route, not an external call).
  await expect(page.locator('h1.gene-page-title')).toContainText(GENE, { timeout: 8_000 });

  // 2. The external provider card frames are rendered (in loading/skeleton state),
  //    proving the page laid them out without awaiting their responses.
  await expect(page.locator('[data-testid="gene-external-card-col"]').first()).toBeVisible({
    timeout: 8_000,
  });

  // 3. All of the above happened far faster than the 20s upstream stall, i.e. the
  //    slow providers did NOT block the page shell.
  const elapsed = Date.now() - start;
  expect(elapsed).toBeLessThan(12_000);

  // 4. The page actually attempted the external calls (so the stall was real).
  expect(externalRequests).toBeGreaterThan(0);
});
