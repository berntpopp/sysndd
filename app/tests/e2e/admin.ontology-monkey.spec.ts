// app/tests/e2e/admin.ontology-monkey.spec.ts
// Randomised, seeded interaction storm on /ManageAnnotations.
// Asserts the page never crashes, throws uncaught JS errors, or leaves the
// heading unresponsive after ~60 deterministic monkey actions.  (#470)
import { test, expect } from './fixtures/auth';

// Deterministic PRNG so any failure reproduces identically.
function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

test('monkey: ManageAnnotations survives a randomized interaction storm (#470)', async ({
  loggedInAs,
}) => {
  // 60 randomised interactions, each with up to a 1s action timeout, exceed the
  // default 30s test budget.
  test.setTimeout(120_000);
  const page = await loggedInAs('admin');
  const errors: string[] = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });
  page.on('pageerror', (e) => errors.push(String(e)));
  const server5xx: string[] = [];
  page.on('response', (r) => {
    if (r.status() >= 500) server5xx.push(`${r.status()} ${r.request().method()} ${r.url()}`);
  });

  await page.goto('/ManageAnnotations');
  await expect(page.getByRole('heading', { name: /Manage Annotations/i })).toBeVisible({
    timeout: 15_000,
  });

  const rand = mulberry32(20260629);
  for (let i = 0; i < 60; i++) {
    // Scope the storm to the page's main content — fuzzing the global navbar
    // (Logout / nav links) would just navigate away, which is not a crash and
    // not what this resilience test is about.
    const clickable = await page
      .locator('main')
      .locator('button:visible, a:visible, input:visible, select:visible, [role="button"]:visible')
      .all();
    if (clickable.length === 0) continue;
    const el = clickable[Math.floor(rand() * clickable.length)];
    const action = rand();
    try {
      if (action < 0.6) {
        await el.click({ trial: false, timeout: 1000, force: true }).catch(() => {});
      } else if (action < 0.85) {
        await el.fill(String(Math.floor(rand() * 1_000_000)), { timeout: 1000 }).catch(() => {});
      } else {
        await el.hover({ timeout: 1000 }).catch(() => {});
      }
    } catch {
      // Ignore individual action failures; we assert global page health below.
    }
    // Never confirm destructive modals — dismiss any open cancel/close button.
    const cancel = page.getByRole('button', { name: /cancel|dismiss|close/i }).first();
    if (await cancel.isVisible().catch(() => false)) await cancel.click().catch(() => {});
  }

  // Assert the app never CRASHED — uncaught JS exceptions / Vue render errors
  // (captured via `pageerror`) must be zero. Filtered out as environment noise:
  //  - ResizeObserver/favicon — benign browser chatter
  //  - clipboard / "Failed to copy" — navigator.clipboard is unavailable headless
  //  - "Failed to load resource" / net::ERR — random input legitimately produces
  //    4xx responses that the app rejects gracefully (error toast), which is
  //    resilience, not a crash. Genuine 5xx are NOT swallowed here — they are
  //    asserted separately below via `server5xx`.
  const fatal = errors.filter(
    (e) =>
      !/ResizeObserver|favicon|net::ERR|clipboard|Failed to copy|Failed to load resource/i.test(e)
  );
  expect(fatal, `console/page errors:\n${fatal.join('\n')}`).toHaveLength(0);

  // No SERVER errors (5xx) during the storm. A 500 is a real backend defect, not
  // env noise — unlike a 4xx from random bad input, which the app rejects
  // gracefully. (This storm originally hit a cold-start 500 in
  // GET /api/publication/pubtator/genes when the pubtator view is absent; fixed
  // in api/functions/pubtator-gene-summary.R to degrade to an empty result.)
  const unique5xx = [...new Set(server5xx)];
  expect(unique5xx, `server 5xx responses during storm:\n${unique5xx.join('\n')}`).toHaveLength(0);

  // The app is still functional after the storm: re-navigating renders the page
  // (robust to any in-page navigation a random click may have triggered).
  await page.goto('/ManageAnnotations');
  await expect(page.getByRole('heading', { name: /Manage Annotations/i })).toBeVisible({
    timeout: 15_000,
  });
});
