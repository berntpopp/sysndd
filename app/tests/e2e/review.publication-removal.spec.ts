// app/tests/e2e/review.publication-removal.spec.ts
//
// #635 — a publication removed in the re-review Edit-Review modal must actually be
// removed from the entity.
//
// WHY THE API ASSERTION IS THE LOAD-BEARING ONE
// ---------------------------------------------
// The bug was invisible to the UI. `useReviewForm.submitForm()` submitted the UNION of
// the set loaded from the server and the set currently in the form, so the chip vanished
// on click, the PUT returned 200 with "Review submitted successfully", and
// `publication_replace_for_review()` obediently re-INSERTed the row the curator had just
// deleted. A test that only asserted the chip was gone would have PASSED against the
// broken build. The `GET /api/review/<id>/publications` read after the save is what
// actually catches it; the reopen assertion catches the reporter's own repro path
// ("revisiting the tab ... reveals that the publication tag is still linked").
//
// ROUTING FACTS (documented in full in curate.variation-provenance.spec.ts)
// -------------------------------------------------------------------------
//  * The Edit-Review modal lives on /Review — `ReviewFormFields.vue`'s only consumer is
//    `ReviewEditModal.vue`, mounted by `Review.vue`. `ModifyEntity.vue` has its own
//    separate form and never had this bug.
//  * `GET /api/re_review/table` scopes the default queue to the requesting user's
//    `re_review_assignment` rows, so only an ASSIGNED user sees entity 123. The baseline
//    assigns batch 9001 to pw_curator as well as pw_reviewer — log in as `curator`.
//
// STATE IS MUTATED, SO THE BASELINE IS RE-SEEDED
// ----------------------------------------------
// This test deletes a join row. `global-setup.ts` only seeds once per `playwright test`
// invocation, so the baseline is re-seeded before and after every test, the same
// discipline as the #608 specs.
//
// IT ALSO SHARES entity/review 123 WITH curate.variation-provenance.spec.ts, which
// reseeds and writes the same rows. `playwright.config.ts` sets `fullyParallel`, so the
// two files must not run concurrently: use `--workers=1`, which is the repo's documented
// way to run this suite (AGENTS.md) and the configuration its known-good baseline is
// stated against. Playwright offers no cross-file lock, so this is a convention rather
// than a guarantee — a parallel run produces cross-talk, not a clean failure.
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';
import type { APIRequestContext, Page } from '@playwright/test';

const ENTITY_ID = 123;
const REVIEW_ID = 123;

/**
 * The baseline's seeded publication. Production stores `publication_id` WITH the `PMID:`
 * prefix and `publication_type` as `additional_references` (verified live: 8148 such
 * rows vs 1099 `gene_review`, and nothing else). #635 corrected the fixture to match —
 * before that it was `'12345678'` / `'PMID'`, which matches neither filter in
 * `useReviewForm.loadReviewData()` and so rendered as no chip at all. That mismatch is
 * why this regression had no end-to-end coverage.
 */
const FIXTURE_PMID = 'PMID:12345678';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

/** Re-seed the shared baseline fixture, reusing global-setup.ts's make target. */
function reseedBaseline(): void {
  execSync('make _playwright-seed-e2e-baseline', { cwd: REPO_ROOT, stdio: 'pipe' });
}

async function curatorToken(request: APIRequestContext): Promise<string> {
  const auth = await request.post('/api/auth/authenticate', {
    data: { user_name: testUsers.curator.username, password: testUsers.curator.password },
  });
  expect(auth.ok(), `curator login for the API assertion -> ${auth.status()}`).toBeTruthy();
  const parsed: unknown = JSON.parse((await auth.text()).trim());
  return Array.isArray(parsed) ? String(parsed[0]) : String(parsed);
}

/**
 * The review's publication ids straight from the API — the DB truth, not the DOM.
 * The route is Reviewer+ (#535 P0-1), so it must be called with a token.
 */
async function reviewPublicationIds(request: APIRequestContext): Promise<string[]> {
  const token = await curatorToken(request);
  const res = await request.get(`/api/review/${REVIEW_ID}/publications`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(
    res.ok(),
    `GET /api/review/${REVIEW_ID}/publications -> ${res.status()} ${(await res.text()).slice(0, 200)}`
  ).toBeTruthy();
  const rows = JSON.parse(await res.text()) as Array<{ publication_id: string }>;
  return rows.map((row) => row.publication_id);
}

/** /Review -> open entity 123's Edit-review modal. Mirrors the #608 spec's helper. */
async function openReviewModal(page: Page): Promise<void> {
  await page.goto('/Review');
  await expect(page.getByRole('heading', { name: /Re-review table/i })).toBeVisible({
    timeout: 20_000,
  });
  const edit = page.getByRole('button', { name: `Edit review for sysndd:${ENTITY_ID}` });
  await expect(edit).toBeVisible({ timeout: 20_000 });
  await edit.click();
  await expect(page.locator('.modal.show')).toBeVisible({ timeout: 20_000 });
}

/**
 * The Publications BFormTags, scoped by the id its inner input carries
 * (`input-id="review-literature-select"` in ReviewFormFields.vue). Scoping matters:
 * the modal renders a second, visually identical BFormTags for GeneReviews.
 */
function publicationTags(page: Page) {
  return page
    .locator('.modal.show .b-form-tags')
    .filter({ has: page.locator('#review-literature-select') });
}

/**
 * One publication chip, matched by its TEXT.
 *
 * Not by `[title="PMID:..."]`, which looks like the obvious selector and silently
 * matches nothing: BFormTag renders `title` from its own internal `tagText`, and
 * because `ReviewFormFields.vue` fills the tag's default slot with a `<BLink>` rather
 * than a bare string, the attribute comes out as the literal `"[object Object]"`.
 * Verified against the running dev stack, not assumed. The anchor's text is
 * `" PMID:12345678"` (a leading icon and space), so this matches on substring.
 */
function publicationChip(page: Page, pmid: string) {
  return publicationTags(page).locator('.b-form-tag').filter({ hasText: pmid });
}

/**
 * Save, and require the save to be an UPDATE.
 *
 * Deliberately narrower than the sibling specs' permissive matcher. Editing a queued
 * re-review is always an update, so a `create` here would mean `Review.vue`'s `isUpdate`
 * fell through and the save minted a duplicate review — the second defect this branch
 * fixes. A permissive assertion would let that pass, and the reseed's
 * `ON DUPLICATE KEY UPDATE` on review 123 would not clean the duplicate up either, so
 * the damage would leak into whatever ran next.
 */
async function saveReview(page: Page): Promise<void> {
  const save = page.locator('.modal.show').getByRole('button', { name: /Save Review/i });
  await expect(save).toBeEnabled();
  const response = page.waitForResponse(
    (r) => /\/api\/review\/(update|create)/.test(r.url()) && r.request().method() !== 'OPTIONS',
    { timeout: 30_000 }
  );
  await save.click();
  const res = await response;
  expect(res.status(), `review save failed: ${await res.text()}`).toBeLessThan(400);
  expect(res.url(), 'editing a queued re-review must PUT /update, never POST /create').toContain(
    '/api/review/update'
  );
  await expect(page.locator('.modal.show')).toHaveCount(0, { timeout: 20_000 });
}

test.describe('#635 re-review publication removal', () => {
  test.beforeEach(() => {
    reseedBaseline();
  });

  // afterEach, not afterAll: this test deletes a join row, so every test in the file
  // must hand the next one a clean fixture, not just the file's last test.
  test.afterEach(() => {
    reseedBaseline();
  });

  test('a publication removed in the modal is gone from the entity after save', async ({
    loggedInAs,
    request,
  }) => {
    // Precondition stated, not assumed: a fixture drift would otherwise make this test
    // pass vacuously by removing nothing.
    expect(
      await reviewPublicationIds(request),
      'baseline seeds the publication this test removes'
    ).toContain(FIXTURE_PMID);

    const page = await loggedInAs('curator');
    const server5xx: string[] = [];
    page.on('response', (r) => {
      if (r.status() >= 500) server5xx.push(`${r.status()} ${r.request().method()} ${r.url()}`);
    });

    await openReviewModal(page);

    const chip = publicationChip(page, FIXTURE_PMID);
    await expect(chip, 'the seeded publication renders as a chip').toBeVisible({
      timeout: 20_000,
    });

    await chip.locator('.b-form-tag-remove').click();
    await expect(chip, 'the chip disappears on click — this always worked').toHaveCount(0);

    await saveReview(page);
    expect(server5xx, 'no server error during the save').toEqual([]);

    // THE assertion. Before the fix this still returned [FIXTURE_PMID] despite the 200.
    expect(
      await reviewPublicationIds(request),
      'the removed publication must be gone from the entity'
    ).not.toContain(FIXTURE_PMID);

    // The reporter's own repro: revisit the tab and confirm it stayed removed.
    await openReviewModal(page);
    await expect(publicationChip(page, FIXTURE_PMID)).toHaveCount(0);
  });
});
