// app/tests/e2e/analyses.data-releases.spec.ts
// E2E smoke for the #573 analysis-snapshot release UI (Slice B): the public
// /DataReleases page and the Administrator /ManageAnalysisReleases page.
//
// The Playwright fixture stack runs no async worker, so analysis snapshots
// never reach `available` and no release can be built. These specs therefore
// assert the empty/gated states render cleanly end-to-end — the real value the
// bare-DB build session could not verify in a browser. Data-dependent flows
// (download + checksum, build/publish/DOI) are covered by unit/vitest + the API
// contract; a live populated run needs a prod-restored DB.

import { test, expect, type Page } from './fixtures/auth';

function captureConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (e) => {
    errors.push(`pageerror: ${e.message}`);
  });
  return errors;
}

// Mirror views.smoke.spec.ts: the empty-DB fixture stack legitimately 404s the
// release-detail fetch (no releases exist) and CSP dev noise is known-pending.
// Those are not what this spec checks — a real render fault is a pageerror or a
// non-network console error.
function filterBenignErrors(errors: string[]): string[] {
  return errors.filter(
    (e) =>
      !/devtools|hot module|HMR/i.test(e) &&
      !/Content Security Policy/i.test(e) &&
      !/Refused to (load|apply|connect|execute)/i.test(e) &&
      !/Failed to load resource.*status of (4\d{2}|5\d{2})/i.test(e) &&
      !/the server responded with a status of (4\d{2}|5\d{2})/i.test(e) &&
      !/AxiosError: Request failed with status code (4\d{2}|5\d{2})/i.test(e),
  );
}

test.describe('analysis-snapshot releases UI (#573 Slice B)', () => {
  test('public /DataReleases renders with the empty state', async ({ page }) => {
    const errors = captureConsoleErrors(page);

    const response = await page.goto('/DataReleases');
    expect(response?.status() ?? 0, 'HTTP status on /DataReleases').toBeLessThan(500);

    await expect(
      page.getByRole('heading', { name: 'Analysis-snapshot releases', level: 1 }),
    ).toBeVisible({ timeout: 15_000 });

    // No releases exist in the fixture stack → the EmptyState is shown.
    await expect(page.getByText('No releases published yet')).toBeVisible({ timeout: 15_000 });

    const hardErrors = filterBenignErrors(errors);
    expect(hardErrors, `console errors: ${hardErrors.join(' | ')}`).toEqual([]);
  });

  test('admin /ManageAnalysisReleases renders with Build gated', async ({ loggedInAs }) => {
    const page = await loggedInAs('admin');
    const errors = captureConsoleErrors(page);

    const response = await page.goto('/ManageAnalysisReleases');
    expect(response?.status() ?? 0, 'HTTP status on /ManageAnalysisReleases').toBeLessThan(500);

    await expect(
      page.getByRole('heading', { name: 'Manage analysis-snapshot releases', level: 1 }),
    ).toBeVisible({ timeout: 15_000 });

    // Readiness panel renders the per-layer states.
    await expect(page.getByText('Snapshot readiness')).toBeVisible();

    // No worker in the fixture stack → snapshots never reach `available` →
    // Build is disabled and the gating hint is shown.
    const buildButton = page.getByRole('button', { name: 'Build release' });
    await expect(buildButton).toBeVisible();
    await expect(buildButton).toBeDisabled();
    await expect(page.getByText(/Build is disabled until every release layer/i)).toBeVisible();

    const hardErrors = filterBenignErrors(errors);
    expect(hardErrors, `console errors: ${hardErrors.join(' | ')}`).toEqual([]);
  });
});
