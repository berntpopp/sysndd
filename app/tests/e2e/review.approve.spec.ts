// app/tests/e2e/review.approve.spec.ts
import { test, expect } from './fixtures/auth';

test.describe('review: review queue scaffolding', () => {
  test('reviewer can open the Review queue and see the page header', async ({ loggedInAs }) => {
    const page = await loggedInAs('reviewer');
    await page.goto('/Review');

    // Page header confirms the view loaded — Re-review table heading sits
    // in a BCard header.
    await expect(page.getByRole('heading', { name: /Re-review table/i })).toBeVisible({
      timeout: 15_000,
    });

    // Note: the deep flow (find a pending row → click Approve → confirm
    // modal → assert row removal) exercises a complex BTable + modal
    // pipeline plus seeded review data that is not provisioned by
    // db/fixtures/playwright_users.sql. Wave 0 captures the queue scaffold
    // only; Wave 1b workstream W6 (Review.vue migrate + decompose) is the
    // natural place to add the full approve flow once the typed clients
    // and decomposition are in place.
  });
});
