import { test, expect } from '@playwright/test';

// #344 follow-up: "Associated" (our own SysNDD DB data) must not load AFTER the
// external-provider enrichment cards. The API is single-threaded per process, so
// the entity request must be DISPATCHED before the external-provider requests —
// otherwise it queues behind up to 6 slow upstream calls and finishes last.
//
// Root cause this guards against: useResource()'s immediate watcher fires the
// external fetches synchronously in GeneView's parent setup(), before the child
// <TablesEntities> mounts and fires the entity fetch. On a SYMBOL URL the
// externals don't wait for the gene record, so they jump the queue ahead of our
// own data. The fix defers external activation to onMounted (after the entity
// request is dispatched).
//
// Local-only (no Playwright CI lane). Run against a seeded stack, e.g.:
//   cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 \
//     npx playwright test tests/e2e/gene-page-own-data-priority.spec.ts

test('entity (Associated) request is dispatched before external-provider requests on a symbol URL', async ({ page }) => {
  const dispatchOrder: string[] = [];
  page.on('request', (req) => {
    const u = req.url();
    if (u.includes('/api/entity/')) dispatchOrder.push('entity');
    else if (u.includes('/api/external/')) dispatchOrder.push('external');
  });

  await page.goto('/Genes/ARID1B', { waitUntil: 'domcontentloaded' });
  // Ensure the entity request has been issued, then let all initial requests settle.
  await page.waitForResponse((r) => r.url().includes('/api/entity/'), { timeout: 20_000 });
  await page.waitForTimeout(1500);

  const entityIdx = dispatchOrder.indexOf('entity');
  const firstExternalIdx = dispatchOrder.findIndex((o) => o === 'external');

  expect(entityIdx, 'entity request should have been issued').toBeGreaterThanOrEqual(0);
  expect(firstExternalIdx, 'an external request should have been issued').toBeGreaterThanOrEqual(0);
  // Own-data first: entity must be dispatched before any external-provider request.
  expect(entityIdx, 'entity must be dispatched before external-provider requests').toBeLessThan(
    firstExternalIdx
  );
});
