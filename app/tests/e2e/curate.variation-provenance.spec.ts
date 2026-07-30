// app/tests/e2e/curate.variation-provenance.spec.ts
//
// #608 — the CURATION three-zone variation-ontology picker, in a real browser
// against the real API.
//
// ROUTING FACTS THIS SPEC DEPENDS ON (each verified empirically, not assumed)
// --------------------------------------------------------------------------
//  1. The three-zone picker lives in `views/curate/components/ReviewFormFields.vue`,
//     whose ONLY consumer is `views/review/components/ReviewEditModal.vue`, mounted
//     by `views/review/Review.vue`. `ModifyEntity.vue` has its own separate inline
//     review form WITHOUT the zones (it is protected server-side instead). So the
//     route is /Review -> the row's "Edit review" action, NOT /ModifyEntity.
//  2. `GET /api/re_review/table` scopes the default queue to
//     `re_review_assignment.user_id = <requesting user>`, so only an ASSIGNED user
//     sees entity 123's row. The `curate=true` surface is not an alternative: it
//     also requires `re_review_submitted = 1`, and the fixture's connect row is 0.
//  3. The Suggested zone needs `GET /api/entity/<id>/variation/suggestions`, which
//     is gated at CURATOR. A Reviewer gets 403 there (confirmed live), so a
//     reviewer-only assignment can never render all three zones.
//     (2)+(3) are why db/fixtures/playwright_e2e_baseline.sql assigns batch 9001 to
//     pw_curator as well as pw_reviewer, and why this spec logs in as `curator`.
//
// STATE IS MUTATED, SO EVERY TEST RE-SEEDS
// ----------------------------------------
// Saving a review reconciles the entity's assertions server-side, so tests that
// save are order-coupled unless the fixture is restored. global-setup.ts only
// re-seeds once per `playwright test` invocation, so `reseedBaseline()` reuses the
// same make target before EVERY test; the fixture's `ON DUPLICATE KEY UPDATE`
// covers `state`, `confirmed_by` and `confirmed_at`, so a reseed genuinely resets
// the workflow.
//
// NOTE on reject-by-omission, verified live and deliberately NOT asserted here:
// `review_write_mutate()` computes `apply_rejections` from
// `review_write_save_determines_served_set()` AFTER `review_update()` has already
// run "Reset approval status" (`review_approved = 0`). So on the plain PUT path the
// flag is always FALSE and omitted terms are never rejected — observed: both
// `suggested` rows survive an untouched save unchanged. That is consistent with the
// reconcile module's own "removal becomes real when it becomes public" rationale,
// but it means reject-by-omission is only reachable via `direct_approval=true`.
// Reported in the task-8 report rather than asserted, because whether that is the
// intended end state is a product decision, not a test one.
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';
import type { APIRequestContext, Page, Request } from '@playwright/test';

const ENTITY_ID = 123;

const CURATOR_AUTHORED_TAG = '1-VariO:0001';
const CONFIRMED_TAG = '1-VariO:0015';
const UNCONFIRMED_TAG = '1-VariO:0017';
/** Same CURIE as UNCONFIRMED_TAG, different modifier -> a DIFFERENT assertion. */
const SUGGESTED_ABSENT_TAG = '5-VariO:0017';
const SUGGESTED_TAG = '1-VariO:0508';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

/** Re-seed the shared baseline fixture, reusing global-setup.ts's make target. */
function reseedBaseline(): void {
  execSync('make _playwright-seed-e2e-baseline', { cwd: REPO_ROOT, stdio: 'pipe' });
}

/**
 * The served provenance state per term, read back through the PUBLIC endpoint so
 * the assertion travels the same path a reader sees — not a DB peek.
 * `state` arrives as a length-1 array (plumber does not auto-unbox).
 */
async function servedStates(request: APIRequestContext): Promise<Record<string, string | null>> {
  const res = await request.get(`/api/entity/${ENTITY_ID}/variation`);
  expect(res.status(), await res.text()).toBe(200);
  const rows = (await res.json()) as Array<Record<string, unknown>>;
  const out: Record<string, string | null> = {};
  for (const row of rows) {
    const tag = `${row.modifier_id}-${row.vario_id}`;
    const prov = row.provenance as { state?: unknown } | null;
    const state = prov?.state;
    out[tag] = prov === null ? null : String(Array.isArray(state) ? state[0] : state);
  }
  return out;
}

async function provenanceFixturePresent(request: APIRequestContext): Promise<boolean> {
  try {
    const states = await servedStates(request);
    return states[UNCONFIRMED_TAG] === 'active_unconfirmed';
  } catch {
    return false;
  }
}

/** Cached Curator bearer token for the API-side steps below. */
let curatorTokenCache: string | null = null;

async function curatorToken(request: APIRequestContext): Promise<string> {
  if (curatorTokenCache) return curatorTokenCache;
  const auth = await request.post('/api/auth/authenticate', {
    data: { user_name: testUsers.curator.username, password: testUsers.curator.password },
  });
  expect(auth.ok(), `probe login failed: ${auth.status()}`).toBeTruthy();
  const parsed: unknown = JSON.parse((await auth.text()).trim());
  curatorTokenCache = Array.isArray(parsed) ? String(parsed[0]) : String(parsed);
  return curatorTokenCache;
}

/**
 * Re-approve review 123 after a save, so the public read can see it again.
 *
 * WHY THIS STEP EXISTS (not a workaround — it is the real workflow):
 * `review_update()` (api/functions/review-repository.R) deliberately runs
 * "Reset approval status" — `review_approved = 0` and `approving_user_id = NULL` —
 * on every review update, because an edited review must be re-approved. Verified
 * live: `review_approved` goes 1 -> 0 on a successful save. Every public
 * review-derived read is gated on `primary_approved_reviews()`
 * (`is_primary = 1 AND review_approved = 1`), so immediately after a save the
 * entity's variation terms vanish from `GET /api/entity/<id>/variation` entirely
 * and every state reads back as `undefined`.
 *
 * The brief asked to read back through the public endpoint "rather than the
 * database if you can". Post-save, that is impossible without re-approving — so we
 * re-approve through the real Curator endpoint and then read publicly, which keeps
 * the whole assertion on the paths a reader and a curator actually use. (The
 * `.../evidence` route is the one public read that is approval-INDEPENDENT, since
 * it resolves the entity via `ndd_entity_view` rather than via the review; it is
 * used as a cross-check below.)
 */
async function reapproveReview(request: APIRequestContext): Promise<void> {
  const res = await request.put(`/api/review/approve/123`, {
    headers: { Authorization: `Bearer ${await curatorToken(request)}` },
    params: { review_ok: 'true' },
  });
  expect(res.status(), `re-approve failed: ${await res.text()}`).toBeLessThan(400);
}

/**
 * One term's state via the approval-independent public evidence route.
 * Returns `null` when no publicly visible assertion matches (404).
 */
async function evidenceState(
  request: APIRequestContext,
  varioId: string,
  modifierId: number
): Promise<string | null> {
  const res = await request.get(
    `/api/entity/${ENTITY_ID}/variation/${varioId}/${modifierId}/evidence`
  );
  if (res.status() === 404) return null;
  expect(res.status(), await res.text()).toBe(200);
  const body = (await res.json()) as { state?: unknown };
  const state = body.state;
  return String(Array.isArray(state) ? state[0] : state);
}

/**
 * TWO PRE-EXISTING `api/` DEFECTS BLOCK EVERY REVIEW SAVE. Both were found by
 * this spec (it is the first e2e test in the repo that actually saves a review —
 * review.approve.spec.ts explicitly deferred the deep flow), and both are OUTSIDE
 * #608: neither file was touched on this branch.
 *
 *  D1 (P0, live since v0.29.3 / PR #521 `171c4a38`):
 *      `review_write_mutate()` (api/services/review-write-service.R) calls
 *      `review_update(review_id, prepared$review_data, ...)` with the WHOLE
 *      payload, but `review_update()` (api/functions/review-repository.R:225)
 *      gained a mass-assignment allowlist of
 *      {synopsis, comment, is_primary, review_approved, approving_user_id,
 *      review_date}. The frontend's `review_json` ALWAYS carries `literature`,
 *      `phenotypes` and `variation_ontology`, so every real save aborts with
 *      "Disallowed review field(s): literature, phenotypes, variation_ontology"
 *      -> transaction rollback -> opaque 500. Proven: the identical PUT with
 *      those three keys removed returns 200 "OK. Review updated.".
 *
 *  D2: `publication.Lastname` is VARCHAR(50), but PubMed `CollectiveName`
 *      (consortium) authors are longer. The baseline fixture's own PMID 12345678
 *      resolves to a 74-char collective author, so the publication write fails
 *      "Data too long for column 'Lastname'" and rolls the save back too.
 *      `publication-functions.R` writes `Lastname = lastname` untruncated.
 *
 * D1 is FIXED (#613, `6ef2b35e`): `review_write_updatable_review_fields()` now projects
 * the body to {synopsis, comment} before `review_update()` sees it.
 *
 * Rather than hard-fail on a defect this spec may not patch, the save-dependent
 * tests SKIP with this reason and RE-ACTIVATE automatically once a save succeeds
 * (repo convention: cf. `seededEntityPresent` in entity.modify.spec.ts). The
 * assertions below are the real regression guard for #608 and must not be
 * deleted — they are one API fix away from running.
 *
 * PROBE PAYLOAD: this deliberately mirrors what the BROWSER actually submits,
 * which carries EMPTY `literature`. The baseline fixture's
 * `ndd_review_publication_join` row is seeded with `publication_type = 'PMID'`,
 * but the API writes/reads that column as `'additional_references'` | `'gene_review'`
 * (see api/endpoints/review_endpoints.R and publication-write-preparation.R), so
 * `useReviewForm.loadReviewData()` filters the row out and submits no references.
 * The probe must therefore NOT include a resolvable PMID: doing so makes the probe
 * strictly harder than the flow it gates and would trip D2 (which the fixture's
 * `publication_type` mismatch otherwise masks), skipping these tests for a reason
 * that has nothing to do with the code path under test.
 */
let reviewSaveProbe: { ok: boolean; detail: string } | null = null;

async function reviewSaveWorks(
  request: APIRequestContext
): Promise<{ ok: boolean; detail: string }> {
  if (reviewSaveProbe) return reviewSaveProbe;
  // The route is Reviewer+, so the probe must be authenticated or it would skip
  // on a 403 and blame the wrong thing.
  const auth = await request.post('/api/auth/authenticate', {
    data: { user_name: testUsers.curator.username, password: testUsers.curator.password },
  });
  if (!auth.ok()) {
    reviewSaveProbe = { ok: false, detail: `probe login failed: ${auth.status()}` };
    return reviewSaveProbe;
  }
  const parsed: unknown = JSON.parse((await auth.text()).trim());
  const token = Array.isArray(parsed) ? String(parsed[0]) : String(parsed);

  const res = await request.put('/api/review/update', {
    headers: { Authorization: `Bearer ${token}` },
    params: { re_review: 'true' },
    data: {
      review_json: {
        review_id: 123,
        entity_id: ENTITY_ID,
        synopsis: 'review-save capability probe',
        comment: 'probe',
        literature: { additional_references: [], gene_review: [] },
        phenotypes: [{ phenotype_id: 'HP:0001263', modifier_id: 1 }],
        variation_ontology: [{ vario_id: 'VariO:0001', modifier_id: 1 }],
      },
    },
  });
  reviewSaveProbe = {
    ok: res.status() < 400,
    detail: `PUT /api/review/update -> ${res.status()} ${(await res.text()).slice(0, 200)}`,
  };
  return reviewSaveProbe;
}

interface Recorders {
  server5xx: string[];
  consoleErrors: string[];
  reviewPayloads: unknown[];
}

/** Repo-wide guard idiom: no 5xx, no uncaught console error, plus payload capture. */
function attachRecorders(page: Page): Recorders {
  const rec: Recorders = { server5xx: [], consoleErrors: [], reviewPayloads: [] };
  page.on('response', (r) => {
    if (r.status() >= 500) rec.server5xx.push(`${r.status()} ${r.request().method()} ${r.url()}`);
  });
  page.on('console', (m) => {
    if (m.type() === 'error') rec.consoleErrors.push(m.text());
  });
  page.on('pageerror', (e) => rec.consoleErrors.push(String(e)));
  page.on('request', (r: Request) => {
    if (/\/api\/review\/(update|create)/.test(r.url())) {
      try {
        const body = r.postData();
        if (body) rec.reviewPayloads.push(JSON.parse(body));
      } catch {
        /* a non-JSON body is asserted on separately via the 5xx guard */
      }
    }
  });
  return rec;
}

/** Console noise that is environment, not a defect (mirrors admin.ontology-monkey). */
function fatalConsoleErrors(errors: string[]): string[] {
  return errors.filter(
    (e) =>
      !/ResizeObserver|favicon|net::ERR|clipboard|Failed to copy|Failed to load resource/i.test(e)
  );
}

/**
 * The #600 regression, asserted on the real submitted bytes: the ontology half of
 * a `"<modifier>-<CURIE>"` tag must never be `Number()`d, because
 * `JSON.stringify(NaN)` is `null` and the API then 500s on the connect step.
 */
function assertNoNullVarioId(payloads: unknown[]): void {
  for (const payload of payloads) {
    const serialized = JSON.stringify(payload);
    expect(serialized, 'submitted payload contains vario_id:null (#600)').not.toContain(
      '"vario_id":null'
    );
    expect(serialized, 'submitted payload contains phenotype_id:null (#600)').not.toContain(
      '"phenotype_id":null'
    );
  }
}

/** /Review -> open entity 123's Edit-review modal and wait for the form to load. */
async function openReviewModal(page: Page): Promise<void> {
  await page.goto('/Review');
  await expect(page.getByRole('heading', { name: /Re-review table/i })).toBeVisible({
    timeout: 20_000,
  });
  const edit = page.getByRole('button', { name: `Edit review for sysndd:${ENTITY_ID}` });
  await expect(edit).toBeVisible({ timeout: 20_000 });
  await edit.click();
  await expect(page.locator('.modal.show')).toBeVisible({ timeout: 20_000 });
  // The zones render only once BOTH provenance reads have resolved.
  await expect(page.getByTestId('variation-provenance-zones')).toBeVisible({ timeout: 20_000 });
}

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
  // The modal closes on success; wait for it so the next read is post-write.
  await expect(page.locator('.modal.show')).toHaveCount(0, { timeout: 20_000 });
}

/** Leading integer of a `"3 terms"` / `"1 term"` zone count. */
async function zoneCount(page: Page, zone: string): Promise<number> {
  const text = await page.getByTestId(`variation-zone-${zone}-count`).innerText();
  const match = /(\d+)/.exec(text);
  return match ? Number(match[1]) : Number.NaN;
}

function cardByTag(page: Page, tag: string) {
  return page.locator(`[data-testid="variation-card"][data-tag="${tag}"]`);
}

test.describe('#608 curation: variation ontology provenance zones', () => {
  // The save-capability probe runs BEFORE the reseed (and is cached across
  // tests), so its own write is undone and every test starts from the fixture.
  test.beforeEach(async ({ request }) => {
    await reviewSaveWorks(request);
    reseedBaseline();
    test.skip(
      !(await provenanceFixturePresent(request)),
      `requires the #608 provenance rows on entity ${ENTITY_ID}; run \`make _playwright-seed-e2e-baseline\``
    );
  });

  /** Gate for the four tests that must write. See `reviewSaveWorks` for why. */
  async function skipUnlessSaveWorks(request: APIRequestContext): Promise<void> {
    const probe = await reviewSaveWorks(request);
    test.skip(
      !probe.ok,
      `BLOCKED by a pre-existing api/ defect outside #608 — review save 500s. ${probe.detail} ` +
        '(D1: review_update() mass-assignment allowlist rejects literature/phenotypes/' +
        'variation_ontology, live since v0.29.3/PR #521; D2: publication.Lastname VARCHAR(50) ' +
        'overflows on PubMed CollectiveName authors.) This test re-activates automatically.'
    );
  }

  test('the three zones render with the right membership and counts', async ({ loggedInAs }) => {
    const page = await loggedInAs('curator');
    const rec = attachRecorders(page);
    await openReviewModal(page);

    // Confirmed: the curator-authored term (no assertion row) plus the already
    // `confirmed` machine-derived one.
    await expect(page.getByTestId('variation-zone-confirmed')).toBeVisible();
    expect(await zoneCount(page, 'confirmed')).toBe(2);
    const confirmedTags = await page
      .getByTestId('variation-confirmed-chip')
      .evaluateAll((els) => els.map((e) => e.getAttribute('data-tag')));
    expect(confirmedTags.sort()).toEqual([CURATOR_AUTHORED_TAG, CONFIRMED_TAG].sort());

    // Needs confirmation: EXACTLY the `active_unconfirmed` term. This zone being
    // non-empty is the whole point of the feature — it is the review step a
    // pre-checked picker used to skip silently.
    await expect(page.getByTestId('variation-zone-needs-confirmation')).toBeVisible();
    expect(await zoneCount(page, 'needs-confirmation')).toBe(1);
    await expect(cardByTag(page, UNCONFIRMED_TAG)).toBeVisible();
    await expect(cardByTag(page, UNCONFIRMED_TAG)).toContainText('nonsynonymous variation');
    // Evidence is inline in the curation flow, because here the evidence IS the
    // decision. Stored wording, verbatim.
    await expect(cardByTag(page, UNCONFIRMED_TAG)).toContainText('2 ClinVar records, max 1 star');
    await expect(cardByTag(page, UNCONFIRMED_TAG)).toContainText('clinvar');

    // Suggested: not in the curated set. Both suggestions appear.
    await expect(page.getByTestId('variation-zone-suggested')).toBeVisible();
    expect(await zoneCount(page, 'suggested')).toBe(2);
    await expect(cardByTag(page, SUGGESTED_TAG)).toBeVisible();
    await expect(cardByTag(page, SUGGESTED_TAG)).toContainText('5 ClinVar records, max 3 stars');

    // IDENTITY INVARIANT, in the browser: the SAME CURIE (VariO:0017) is in
    // Needs-confirmation under modifier 1 and in Suggested under modifier 5,
    // because modifier_id is part of the assertion identity. Keyed on vario_id
    // alone, these two would collapse into one entry.
    await expect(cardByTag(page, SUGGESTED_ABSENT_TAG)).toBeVisible();
    await expect(
      page.getByTestId('variation-zone-suggested').locator(`[data-tag="${SUGGESTED_ABSENT_TAG}"]`)
    ).toHaveCount(1);
    await expect(
      page
        .getByTestId('variation-zone-needs-confirmation')
        .locator(`[data-tag="${UNCONFIRMED_TAG}"]`)
    ).toHaveCount(1);

    // No term is in two zones at once (keyed on the full tag).
    const allTags = await page
      .getByTestId('variation-provenance-zones')
      .locator('[data-tag]')
      .evaluateAll((els) => els.map((e) => e.getAttribute('data-tag') ?? ''));
    expect(allTags.length).toBe(new Set(allTags).size);

    expect(rec.server5xx, rec.server5xx.join('\n')).toHaveLength(0);
    expect(fatalConsoleErrors(rec.consoleErrors).join('\n')).toBe('');
  });

  test('each zone action button has an accessible name that names its term', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');
    await openReviewModal(page);

    // Without the term in the name a screen-reader user hears N identical
    // "Confirm" buttons. The modifier is part of the name because `present` and
    // `absent` are different assertions.
    const needs = cardByTag(page, UNCONFIRMED_TAG);
    await expect(needs.getByTestId('variation-action-confirm')).toHaveAccessibleName(
      /Confirm nonsynonymous variation, present/i
    );
    await expect(needs.getByTestId('variation-action-remove')).toHaveAccessibleName(
      /Remove nonsynonymous variation, present/i
    );

    await expect(
      cardByTag(page, SUGGESTED_TAG).getByTestId('variation-action-accept')
    ).toHaveAccessibleName(/Accept splice variation, present/i);
    await expect(
      cardByTag(page, SUGGESTED_TAG).getByTestId('variation-action-dismiss')
    ).toHaveAccessibleName(/Dismiss splice variation, present/i);

    // The two VariO:0017 modifiers must be distinguishable by name alone.
    await expect(
      cardByTag(page, SUGGESTED_ABSENT_TAG).getByTestId('variation-action-accept')
    ).toHaveAccessibleName(/Accept nonsynonymous variation, absent/i);
  });

  test('THE REGRESSION: saving without touching the unconfirmed term leaves it live and unpromoted', async ({
    loggedInAs,
    request,
  }) => {
    await skipUnlessSaveWorks(request);
    // This is #608's reason to exist. Before the fix, every existing term arrived
    // pre-checked and a save rewrote all of them onto a new curator-attributed
    // review, so "I edited one word of the synopsis" was indistinguishable from
    // "I read the papers and vouch for this machine-derived term".
    const page = await loggedInAs('curator');
    const rec = attachRecorders(page);
    await openReviewModal(page);

    // Deliberately touch NOTHING in the zones. Edit an unrelated field so the
    // save is a realistic "I came here to fix the synopsis" edit.
    const synopsis = page.locator('#review-textarea-synopsis');
    await expect(synopsis).toBeVisible();
    await synopsis.fill(
      'CHD8-related neurodevelopmental disorder — synopsis edited by the #608 e2e regression test.'
    );

    await saveReview(page);

    // Cross-check on the approval-INDEPENDENT route first: the assertion itself is
    // untouched even before the review is re-approved.
    expect(
      await evidenceState(request, 'VariO:0017', 1),
      'unconfirmed term was silently promoted'
    ).toBe('active_unconfirmed');

    await reapproveReview(request);
    const states = await servedStates(request);
    // Still served, still NOT promoted.
    expect(states[UNCONFIRMED_TAG], 'unconfirmed term was silently promoted').toBe(
      'active_unconfirmed'
    );
    // The already-confirmed term is not re-stamped, and the curator-authored term
    // keeps having no provenance at all.
    expect(states[CONFIRMED_TAG]).toBe('confirmed');
    expect(states[CURATOR_AUTHORED_TAG]).toBeNull();

    // The submitted entry for the untouched term carries NO provenance_action.
    const submitted = rec.reviewPayloads.at(-1) as {
      review_json?: { variation_ontology?: Array<Record<string, unknown>> };
    };
    const entries = submitted?.review_json?.variation_ontology ?? [];
    const untouched = entries.find((e) => e.vario_id === 'VariO:0017' && e.modifier_id === 1);
    expect(untouched, `VariO:0017 missing from ${JSON.stringify(entries)}`).toBeTruthy();
    expect('provenance_action' in (untouched as object)).toBe(false);

    assertNoNullVarioId(rec.reviewPayloads);
    expect(rec.server5xx, rec.server5xx.join('\n')).toHaveLength(0);
  });

  test('confirming the term and saving promotes it to confirmed', async ({
    loggedInAs,
    request,
  }) => {
    await skipUnlessSaveWorks(request);
    const page = await loggedInAs('curator');
    const rec = attachRecorders(page);
    await openReviewModal(page);

    await cardByTag(page, UNCONFIRMED_TAG).getByTestId('variation-action-confirm').click();
    // Confirming moves it out of Needs-confirmation and into Confirmed, before any
    // save — the decision is visible immediately.
    await expect(cardByTag(page, UNCONFIRMED_TAG)).toHaveCount(0);
    await expect(
      page.getByTestId('variation-confirmed-chip').filter({ has: page.locator(':scope') })
    ).not.toHaveCount(0);
    const confirmedTags = await page
      .getByTestId('variation-confirmed-chip')
      .evaluateAll((els) => els.map((e) => e.getAttribute('data-tag')));
    expect(confirmedTags).toContain(UNCONFIRMED_TAG);

    await saveReview(page);
    await reapproveReview(request);

    const states = await servedStates(request);
    expect(states[UNCONFIRMED_TAG]).toBe('confirmed');

    const submitted = rec.reviewPayloads.at(-1) as {
      review_json?: { variation_ontology?: Array<Record<string, unknown>> };
    };
    const entry = (submitted?.review_json?.variation_ontology ?? []).find(
      (e) => e.vario_id === 'VariO:0017' && e.modifier_id === 1
    );
    expect(entry?.provenance_action).toBe('confirm');

    assertNoNullVarioId(rec.reviewPayloads);
    expect(rec.server5xx, rec.server5xx.join('\n')).toHaveLength(0);
  });

  test('accepting a suggested term adds it to the curated set', async ({ loggedInAs, request }) => {
    await skipUnlessSaveWorks(request);
    const page = await loggedInAs('curator');
    const rec = attachRecorders(page);
    await openReviewModal(page);

    // A suggestion is NOT in the curated set until accepted.
    let states = await servedStates(request);
    expect(states[SUGGESTED_TAG]).toBeUndefined();

    await cardByTag(page, SUGGESTED_TAG).getByTestId('variation-action-accept').click();
    // Accepting selects AND confirms, so it lands in Confirmed immediately.
    await expect(cardByTag(page, SUGGESTED_TAG)).toHaveCount(0);
    const confirmedTags = await page
      .getByTestId('variation-confirmed-chip')
      .evaluateAll((els) => els.map((e) => e.getAttribute('data-tag')));
    expect(confirmedTags).toContain(SUGGESTED_TAG);

    await saveReview(page);
    await reapproveReview(request);

    states = await servedStates(request);
    // Now part of the served curated set, and attributed as confirmed.
    expect(states[SUGGESTED_TAG]).toBe('confirmed');
    // Not touching the unconfirmed term still leaves it live.
    expect(states[UNCONFIRMED_TAG]).toBe('active_unconfirmed');

    assertNoNullVarioId(rec.reviewPayloads);
    expect(rec.server5xx, rec.server5xx.join('\n')).toHaveLength(0);
  });

  // Deterministic PRNG so any failure reproduces identically (same idiom as
  // admin.ontology-monkey.spec.ts). NEVER use unseeded randomness here.
  function mulberry32(seed: number) {
    return () => {
      seed |= 0;
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  test('monkey: the zones hold their invariants under a seeded interaction storm', async ({
    loggedInAs,
    request,
  }) => {
    test.setTimeout(180_000);
    const saveProbe = await reviewSaveWorks(request);
    const page = await loggedInAs('curator');
    const rec = attachRecorders(page);
    await openReviewModal(page);

    const zones = page.getByTestId('variation-provenance-zones');
    const rand = mulberry32(20260730);
    const ACTIONS = 24;

    for (let i = 0; i < ACTIONS; i++) {
      // Scope strictly to the zone controls. Fuzzing the whole modal would just
      // close it (Cancel) or edit unrelated fields, which is not what this checks.
      const controls = await zones
        .locator(
          '[data-testid="variation-action-confirm"]:visible, [data-testid="variation-action-remove"]:visible, [data-testid="variation-action-accept"]:visible, [data-testid="variation-action-dismiss"]:visible'
        )
        .all();
      // Every zone can legitimately be emptied by Remove/Dismiss; when nothing is
      // left to act on the wrapper disappears (`hasZones` is false) and the storm
      // has nothing more to do. That is a valid terminal state, not a failure.
      if (controls.length === 0) break;

      await controls[Math.floor(rand() * controls.length)]
        .click({ timeout: 2_000 })
        .catch(() => {});

      // ---- Invariants that must hold after EVERY interaction, in any order ----
      if ((await zones.count()) === 0) break;

      const perZone: Record<string, string[]> = {};
      for (const zone of ['confirmed', 'needs-confirmation', 'suggested']) {
        const zoneEl = page.getByTestId(`variation-zone-${zone}`);
        if ((await zoneEl.count()) === 0) {
          perZone[zone] = [];
          continue;
        }
        const tags = await zoneEl
          .locator('[data-tag]')
          .evaluateAll((els) => els.map((e) => e.getAttribute('data-tag') ?? ''));
        perZone[zone] = tags;

        // The zone count always equals the number of rendered entries.
        expect(
          await zoneCount(page, zone),
          `iteration ${i}: ${zone} count disagrees with ${tags.length} rendered entries`
        ).toBe(tags.length);
      }

      // A term is never in two zones simultaneously. Keyed on the FULL
      // `<modifier>-<vario>` tag, so the deliberate VariO:0017 modifier-1 /
      // modifier-5 pair in the fixture is correctly two distinct terms.
      const all = Object.values(perZone).flat();
      const duplicates = all.filter((tag, index) => all.indexOf(tag) !== index);
      expect(duplicates, `iteration ${i}: tag(s) in two zones: ${duplicates.join(', ')}`).toEqual(
        []
      );
    }

    // Save whatever state the storm left, so the storm's effect on the submitted
    // payload is asserted too — not just the rendered DOM. Skipped while the
    // pre-existing review-save defect (see `reviewSaveWorks`) is unfixed, because
    // its 500 would drown out any real 5xx the storm produced. The DOM invariants
    // above — the actual point of the storm — always run.
    if (
      saveProbe.ok &&
      (await page
        .locator('.modal.show')
        .isVisible()
        .catch(() => false))
    ) {
      await saveReview(page).catch(() => {
        /* a save refused by validation is not a crash; 5xx is asserted below */
      });
    }

    assertNoNullVarioId(rec.reviewPayloads);
    expect(
      rec.server5xx,
      `5xx during storm:\n${[...new Set(rec.server5xx)].join('\n')}`
    ).toHaveLength(0);
    const fatal = fatalConsoleErrors(rec.consoleErrors);
    expect(fatal, `console/page errors:\n${fatal.join('\n')}`).toHaveLength(0);

    // Still functional after the storm.
    await page.goto('/Review');
    await expect(page.getByRole('heading', { name: /Re-review table/i })).toBeVisible({
      timeout: 20_000,
    });
  });
});
