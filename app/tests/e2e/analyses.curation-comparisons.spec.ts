// app/tests/e2e/analyses.curation-comparisons.spec.ts
import { test, expect } from './fixtures/auth';

test.describe('analyses: curation comparisons', () => {
  test('curator can open the Curation Comparisons page and see all three tabs', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');
    await page.goto('/CurationComparisons');

    // The three nav tabs (Overlap, Similarity, Table) inside the card
    // header are the stable landmark — the card "title" attribute used
    // for "Curation comparisons" is not a text node we can match.
    await expect(page.getByRole('link', { name: /^Overlap$/ })).toBeVisible({
      timeout: 15_000,
    });
    await expect(page.getByRole('link', { name: /^Similarity$/ })).toBeVisible();
    await expect(page.getByRole('link', { name: /^Table$/ })).toBeVisible();

    // Note: deep flow (apply a filter → assert row count narrows) requires
    // seeded comparison data that is not provisioned by the playwright
    // user fixture. Wave 0 captures the page scaffold + tabs only.
  });
});
