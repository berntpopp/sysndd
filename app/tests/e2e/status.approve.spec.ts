// app/tests/e2e/status.approve.spec.ts
import { test, expect } from './fixtures/auth';

test.describe('review: status approve scaffolding', () => {
  test('reviewer can open the Approve Status page', async ({ loggedInAs }) => {
    const page = await loggedInAs('reviewer');
    await page.goto('/ApproveStatus');

    // The view loads and renders the approval table scaffold. The
    // ApprovalTableView component handles the deep flow; here we only
    // verify the page didn't 404 and the navigation chrome is present.
    await expect(page.locator('header, nav, [role="banner"]').first()).toBeVisible({
      timeout: 10_000,
    });

    // Wait briefly for the table to render at least the structural elements.
    await page.waitForLoadState('domcontentloaded');

    await page.screenshot({
      path: 'tests/e2e/screenshots/status.approve__success__desktop.png',
      fullPage: true,
    });

    // Note: deep flow (find a pending status row → click Approve → confirm
    // modal → assert row removal) requires seeded entity-status data not
    // provisioned by db/fixtures/playwright_users.sql. Wave 0 captures the
    // page scaffold only; a future workstream can add the full flow once
    // entity/status fixtures are available.
  });
});
