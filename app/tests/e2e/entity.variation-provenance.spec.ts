// app/tests/e2e/entity.variation-provenance.spec.ts
//
// #608 — PUBLIC variation-ontology provenance surface, end to end against the
// real API. No login: this whole surface is unauthenticated.
//
// WHY THIS SPEC EXISTS
// --------------------
// The frontend was built against mocked responses and the API against R-level
// fixtures. Nothing had ever run one against the other, so the failure modes this
// file targets are exactly the ones a mock cannot reproduce:
//   * the serializer shape (plumber does NOT auto-unbox, so every scalar nested
//     inside `provenance` arrives as a LENGTH-1 ARRAY: `"state":["confirmed"]`,
//     `"strength":[1]`), while `provenance` itself is literally JSON `null` for a
//     curator-authored term,
//   * route shadowing between `/variation`, `/variation/suggestions` and
//     `/variation/<vario_id>/<modifier_id>/evidence`,
//   * a CURIE (`VariO:0017`) travelling through a URL path segment,
//   * the Curator gate on `/variation/suggestions` never leaking onto this page.
//
// Data comes from db/fixtures/playwright_e2e_baseline.sql, which
// `make playwright-stack` and global-setup.ts both seed. Entity 123 (CHD8) carries
// four curated-set-relevant terms:
//   VariO:0001 mod 1 — curated, NO assertion row  -> `provenance: null`
//   VariO:0015 mod 1 — assertion `confirmed`
//   VariO:0017 mod 1 — assertion `active_unconfirmed`  (the load-bearing case)
//   VariO:0508 mod 1 — assertion `suggested`, NOT in the curated set -> must be absent
import { test, expect, type Page, type Request } from '@playwright/test';
import { AxeBuilder } from '@axe-core/playwright';

const ENTITY_ID = 123;
const ENTITY_PATH = `/Entities/${ENTITY_ID}`;

const CURATOR_AUTHORED = { varioId: 'VariO:0001', modifier: 1 };
const CONFIRMED = { varioId: 'VariO:0015', modifier: 1 };
const UNCONFIRMED = { varioId: 'VariO:0017', modifier: 1 };
const SUGGESTED_ONLY = { varioId: 'VariO:0508', modifier: 1 };

/** The API path the evidence dialog fetches for one assertion. */
function evidencePathFragment(varioId: string, modifier: number): string {
  return `/api/entity/${ENTITY_ID}/variation/${varioId}/${modifier}/evidence`;
}

/**
 * Skips when the provenance fixture is absent, so this spec never false-fails
 * against a non-Playwright stack (same contract as entity.modify.spec.ts).
 * Deliberately checks for the ASSERTION, not just the entity: entity 123 exists
 * in the baseline fixture from before #608.
 */
async function provenanceFixturePresent(request: Page['request']): Promise<boolean> {
  try {
    const res = await request.get(`/api/entity/${ENTITY_ID}/variation`);
    if (!res.ok()) return false;
    const body: unknown = await res.json();
    if (!Array.isArray(body)) return false;
    return body.some(
      (row) =>
        (row as { vario_id?: string }).vario_id === UNCONFIRMED.varioId &&
        (row as { provenance?: unknown }).provenance != null
    );
  } catch {
    return false;
  }
}

/** Fails the test on any 5xx — the repo-wide guard idiom. */
function guardAgainstServerErrors(page: Page): string[] {
  const serverErrors: string[] = [];
  page.on('response', (r) => {
    if (r.status() >= 500) serverErrors.push(`${r.status()} ${r.request().method()} ${r.url()}`);
  });
  return serverErrors;
}

async function gotoEntity(page: Page): Promise<void> {
  await page.addInitScript(() => {
    localStorage.setItem(
      'sysndd-disclaimer',
      JSON.stringify({ isAcknowledged: true, acknowledgmentTimestamp: new Date().toISOString() })
    );
  });
  await page.goto(ENTITY_PATH);
  // The provenance affordances are gated on `hasProvenance`, so waiting for the
  // legend button is the precise "the provenance-aware card has rendered" signal.
  await expect(page.getByTestId('variation-provenance-legend')).toBeVisible({ timeout: 20_000 });
}

function trigger(page: Page, term: { varioId: string; modifier: number }) {
  return page.getByTestId(`variation-provenance-trigger-${term.varioId}-${term.modifier}`);
}

test.describe('#608 public entity page: variation ontology provenance', () => {
  test.beforeEach(async ({ request }) => {
    test.skip(
      !(await provenanceFixturePresent(request)),
      `requires the #608 provenance rows on entity ${ENTITY_ID}; run \`make _playwright-seed-e2e-baseline\``
    );
  });

  test('API contract: the public read serves provenance in the documented wire shape', async ({
    request,
  }) => {
    // This is the mock-proof assertion. It pins the exact serializer shape the
    // frontend normalizer (variationProvenance.ts) was written against, so a
    // change to the `null="null"` / non-unboxing serializer arguments is caught
    // here rather than as a silently blank card.
    const res = await request.get(`/api/entity/${ENTITY_ID}/variation`);
    expect(res.status(), await res.text()).toBe(200);
    const rows = (await res.json()) as Array<Record<string, unknown>>;
    expect(Array.isArray(rows)).toBeTruthy();

    const byId = new Map(rows.map((r) => [String(r.vario_id), r]));

    // The curated set is exactly the three connect rows. A `suggested` assertion
    // must NEVER surface on the public read.
    expect([...byId.keys()].sort()).toEqual([
      CURATOR_AUTHORED.varioId,
      CONFIRMED.varioId,
      UNCONFIRMED.varioId,
    ]);
    expect(byId.has(SUGGESTED_ONLY.varioId)).toBe(false);

    // Data-frame columns arrive as scalars...
    const unconfirmed = byId.get(UNCONFIRMED.varioId)!;
    expect(unconfirmed.vario_id).toBe(UNCONFIRMED.varioId);
    expect(unconfirmed.modifier_id).toBe(UNCONFIRMED.modifier);

    // ...but a curator-authored term's `provenance` is literally JSON null.
    expect(byId.get(CURATOR_AUTHORED.varioId)!.provenance).toBeNull();

    // ...and every scalar NESTED in `provenance` is a length-1 array.
    const prov = unconfirmed.provenance as Record<string, unknown>;
    expect(prov).not.toBeNull();
    expect(prov.state).toEqual(['active_unconfirmed']);
    expect(prov.max_strength).toEqual([1]);
    expect(Array.isArray(prov.sources)).toBeTruthy();
    const sources = prov.sources as Array<Record<string, unknown>>;
    expect(sources).toHaveLength(1);
    expect(sources[0].source_key).toEqual(['clinvar']);
    expect(sources[0].strength).toEqual([1]);
    expect(sources[0].summary).toEqual(['2 ClinVar records, max 1 star']);

    expect((byId.get(CONFIRMED.varioId)!.provenance as Record<string, unknown>).state).toEqual([
      'confirmed',
    ]);
  });

  test('API contract: the evidence route resolves a CURIE in the path and stays state-gated', async ({
    request,
  }) => {
    // A colon inside one path segment, both raw and percent-encoded. Plumber does
    // not percent-decode path params, so the service decodes them — both spellings
    // must resolve to the same assertion.
    for (const spelling of [UNCONFIRMED.varioId, encodeURIComponent(UNCONFIRMED.varioId)]) {
      const res = await request.get(
        `/api/entity/${ENTITY_ID}/variation/${spelling}/${UNCONFIRMED.modifier}/evidence`
      );
      expect(res.status(), `${spelling}: ${await res.text()}`).toBe(200);
      const body = (await res.json()) as Record<string, unknown>;
      expect(body.state).toEqual(['active_unconfirmed']);
      const evidence = body.evidence as Array<Record<string, unknown>>;
      expect(evidence).toHaveLength(1);
      expect(evidence[0].evidence_summary).toEqual(['2 ClinVar records, max 1 star']);
    }

    // `suggested` is curation state and must not be reachable on this PUBLIC
    // route, even though the assertion exists.
    const suggested = await request.get(
      evidencePathFragment(SUGGESTED_ONLY.varioId, SUGGESTED_ONLY.modifier)
    );
    expect(suggested.status()).toBe(404);

    // The literal `suggestions` route must not be captured as a `vario_id` by the
    // dynamic sibling, and must stay Curator-gated for an anonymous caller.
    const suggestions = await request.get(`/api/entity/${ENTITY_ID}/variation/suggestions`);
    expect(suggestions.status(), await suggestions.text()).toBe(403);
  });

  test('card shows all three curated terms and only the machine-derived ones carry an affordance', async ({
    page,
  }) => {
    const serverErrors = guardAgainstServerErrors(page);
    await gotoEntity(page);

    // All three curated terms render as chips (the pre-#608 chip is unchanged).
    for (const term of [CURATOR_AUTHORED, CONFIRMED, UNCONFIRMED]) {
      await expect(page.getByTestId(`variation-chip-${term.varioId}`)).toBeVisible();
    }
    // The suggested-only term is not part of the curated set.
    await expect(page.getByTestId(`variation-chip-${SUGGESTED_ONLY.varioId}`)).toHaveCount(0);

    // THE MOST IMPORTANT ASSERTION IN THIS FILE: the visible difference between a
    // curated annotation and a machine-derived one.
    await expect(trigger(page, UNCONFIRMED)).toBeVisible();
    await expect(trigger(page, CONFIRMED)).toBeVisible();
    await expect(trigger(page, CURATOR_AUTHORED)).toHaveCount(0);
    await expect(
      page.getByTestId(
        `variation-provenance-group-${CURATOR_AUTHORED.varioId}-${CURATOR_AUTHORED.modifier}`
      )
    ).toHaveCount(0);

    // State is in WORDS on the accessible name, not colour or glyph alone.
    await expect(trigger(page, UNCONFIRMED)).toHaveAttribute(
      'aria-label',
      /nonsynonymous variation, machine-derived, not confirmed\. Show evidence/i
    );
    await expect(trigger(page, CONFIRMED)).toHaveAttribute(
      'aria-label',
      /machine-derived, confirmed by a curator\. Show evidence/i
    );

    // The legend explains the marking, and is collapsed until asked for.
    await expect(page.getByTestId('variation-provenance-legend-text')).toHaveCount(0);
    await page.getByTestId('variation-provenance-legend').click();
    await expect(page.getByTestId('variation-provenance-legend-text')).toContainText(
      /machine-derived/i
    );

    expect(serverErrors, serverErrors.join('\n')).toHaveLength(0);
  });

  test('the term chip keeps its own external ontology outlink', async ({ page }) => {
    await gotoEntity(page);

    // The provenance trigger is a SEPARATE control, so the chip's href must be
    // untouched for both a curator-authored and a machine-derived term.
    for (const term of [CURATOR_AUTHORED, UNCONFIRMED]) {
      const chip = page.getByTestId(`variation-chip-${term.varioId}`);
      await expect(chip).toHaveAttribute('href', /^https?:\/\/.+/);
      await expect(chip).toHaveAttribute('target', '_blank');
    }
  });

  test('evidence is fetched on first open only, never on page load', async ({ page }) => {
    const evidenceRequests: string[] = [];
    const onRequest = (r: Request) => {
      if (r.url().includes('/variation/') && r.url().includes('/evidence')) {
        evidenceRequests.push(r.url());
      }
    };
    page.on('request', onRequest);

    await gotoEntity(page);
    // Let the page settle so a stray eager fetch would have landed.
    await page.waitForTimeout(1_000);
    expect(evidenceRequests, `fetched on page load: ${evidenceRequests.join(', ')}`).toHaveLength(
      0
    );

    await trigger(page, UNCONFIRMED).click();
    await expect(page.getByTestId('variation-provenance-dialog')).toBeVisible();
    await expect.poll(() => evidenceRequests.length, { timeout: 10_000 }).toBeGreaterThanOrEqual(1);
    expect(evidenceRequests[0]).toContain(
      evidencePathFragment(UNCONFIRMED.varioId, UNCONFIRMED.modifier)
    );

    const afterFirstOpen = evidenceRequests.length;

    // Reopening must hit the shared resource cache, not the network again.
    await page.getByTestId('variation-provenance-dialog-close').click();
    await expect(page.getByTestId('variation-provenance-dialog')).toHaveCount(0);
    await trigger(page, UNCONFIRMED).click();
    await expect(page.getByTestId('variation-provenance-dialog')).toBeVisible();
    await page.waitForTimeout(1_000);
    expect(evidenceRequests.length, `reopen refetched: ${evidenceRequests.join(', ')}`).toBe(
      afterFirstOpen
    );
  });

  test('the dialog shows the ClinVar records and the 1-star strength, and no HGVS label', async ({
    page,
  }) => {
    await gotoEntity(page);
    await trigger(page, UNCONFIRMED).click();

    const dialog = page.getByTestId('variation-provenance-dialog');
    await expect(dialog).toBeVisible();
    await expect(page.getByTestId('variation-provenance-dialog-title')).toHaveText(
      'nonsynonymous variation'
    );
    await expect(page.getByTestId('variation-provenance-dialog-status')).toContainText(
      /Not yet confirmed by a curator/i
    );
    await expect(page.getByTestId('variation-provenance-dialog-error')).toHaveCount(0);
    await expect(page.getByTestId('variation-provenance-empty')).toHaveCount(0);

    const source = page.getByTestId('variation-provenance-source-0');
    await expect(source).toContainText('ClinVar');
    await expect(source).toContainText('external database');
    await expect(source).toContainText('2 ClinVar records, max 1 star');

    // Strength is carried in TEXT, not by stars alone.
    await expect(page.getByTestId('variation-provenance-strength-0')).toContainText('1 of 4');

    // Both real ClinVar accessions from the issue's worked example, each a link.
    const records = page.getByTestId('variation-provenance-records-0');
    await expect(records.getByRole('listitem')).toHaveCount(2);
    await expect(page.getByTestId('variation-provenance-record-0-0')).toContainText('VCV1343191');
    await expect(page.getByTestId('variation-provenance-record-0-1')).toContainText('VCV1804020');
    await expect(records).toContainText('Likely pathogenic');
    await expect(
      page.getByTestId('variation-provenance-record-0-0').getByRole('link')
    ).toHaveAttribute('href', /ncbi\.nlm\.nih\.gov\/clinvar\/variation\/1343191/);
    await expect(page.getByTestId('variation-provenance-matched-0')).toContainText('OMIM:615032');

    // NEVER SYNTHESISE: the importer records no protein/cDNA label, so none may
    // appear. This is the anti-fabrication guard the whole feature exists for.
    const dialogText = (await dialog.innerText()).toLowerCase();
    expect(dialogText).not.toMatch(/\bp\.[a-z]{3}\d/i);
    expect(dialogText).not.toMatch(/\bc\.\d+[acgt]>/i);
    expect(dialogText).not.toContain('hgvs');
  });

  test('an unrecorded strength reads "Not recorded" and sorts after a scored source', async ({
    page,
  }) => {
    // The confirmed term carries TWO sources: clinvar (strength 2) and pubtator
    // (strength NULL). The API orders `(strength IS NULL) ASC, strength DESC`, so
    // the scored source is first — and a NULL must never render as zero stars.
    await gotoEntity(page);
    await trigger(page, CONFIRMED).click();

    await expect(page.getByTestId('variation-provenance-dialog-status')).toContainText(
      /Confirmed by a curator/i
    );
    await expect(page.getByTestId('variation-provenance-source-0')).toContainText('ClinVar');
    await expect(page.getByTestId('variation-provenance-strength-0')).toContainText('2 of 4');

    const unscored = page.getByTestId('variation-provenance-source-1');
    // An unknown source key is shown verbatim, not prettified into a guess.
    await expect(unscored).toContainText('pubtator');
    const unscoredStrength = page.getByTestId('variation-provenance-strength-1');
    await expect(unscoredStrength).toContainText('Not recorded');
    await expect(unscoredStrength).not.toContainText('0 of 4');
    await expect(unscoredStrength.locator('.vp-stars')).toHaveCount(0);
  });

  test('the dialog is keyboard operable: Tab reaches it, Enter opens, Escape restores focus', async ({
    page,
  }) => {
    await gotoEntity(page);

    const target = trigger(page, UNCONFIRMED);
    // Reachable by Tab from the chip that precedes it — a real tab order check,
    // not a programmatic .focus().
    await page.getByTestId(`variation-chip-${UNCONFIRMED.varioId}`).focus();
    await page.keyboard.press('Tab');
    await expect(target).toBeFocused();
    await expect(target).toHaveAttribute('aria-haspopup', 'dialog');
    await expect(target).toHaveAttribute('aria-expanded', 'false');

    await page.keyboard.press('Enter');
    const dialog = page.getByTestId('variation-provenance-dialog');
    await expect(dialog).toBeVisible();
    await expect(target).toHaveAttribute('aria-expanded', 'true');
    await expect(dialog).toHaveAttribute('aria-modal', 'true');
    // Focus moved INTO the dialog (the container itself, so its accessible name
    // is announced before its controls).
    await expect(dialog).toBeFocused();

    // Tab stays trapped inside the dialog.
    await page.keyboard.press('Tab');
    const trappedInside = await page.evaluate(() => {
      const root = document.querySelector('[data-testid="variation-provenance-dialog"]');
      return Boolean(root && document.activeElement && root.contains(document.activeElement));
    });
    expect(trappedInside).toBe(true);

    await page.keyboard.press('Escape');
    await expect(dialog).toHaveCount(0);
    // Focus RETURNS to the trigger it came from.
    await expect(target).toBeFocused();
    await expect(target).toHaveAttribute('aria-expanded', 'false');
  });

  test('the scrim dismisses the dialog', async ({ page }) => {
    await gotoEntity(page);
    await trigger(page, UNCONFIRMED).click();
    await expect(page.getByTestId('variation-provenance-dialog')).toBeVisible();
    // The scrim is full-viewport (`inset: 0`) and the dialog is centred inside
    // it, so a default centre-click is legitimately intercepted by the dialog.
    // Click near the corner, which is where a real user clicks to dismiss.
    await page.getByTestId('variation-provenance-scrim').click({ position: { x: 8, y: 8 } });
    await expect(page.getByTestId('variation-provenance-dialog')).toHaveCount(0);
  });

  for (const viewport of [
    { name: 'mobile-390', width: 390, height: 844 },
    { name: 'desktop-1440', width: 1440, height: 900 },
  ]) {
    test(`no horizontal overflow with the dialog open at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoEntity(page);
      await trigger(page, UNCONFIRMED).click();
      await expect(page.getByTestId('variation-provenance-dialog')).toBeVisible();

      const bodyOverflows = await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1
      );
      expect(bodyOverflows, 'page body scrolls horizontally').toBe(false);

      const dialogOverflows = await page
        .getByTestId('variation-provenance-dialog')
        .evaluate((el) => el.scrollWidth > el.clientWidth + 1);
      expect(dialogOverflows, 'dialog scrolls horizontally').toBe(false);
    });
  }

  test('axe: the provenance card and the open dialog have no target-rule violations', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await gotoEntity(page);
    await page.getByTestId('variation-provenance-legend').click();

    // SCOPED to the provenance card, not to all of `main`. Verified empirically:
    // an unscoped `main` run reports four PRE-EXISTING `color-contrast`
    // violations from `entity-unit-label` (EntityUnitHeader) and
    // `clinical-panel-meta`, neither of which #608 touches. Asserting on `main`
    // would make this spec a proxy for the app's whole a11y backlog and it would
    // fail for reasons unrelated to provenance.
    const targetIds = new Set([
      'aria-prohibited-attr',
      'aria-required-attr',
      'aria-valid-attr-value',
      'button-name',
      'color-contrast',
      'heading-order',
      'label-content-name-mismatch',
      'link-name',
      'list',
      'listitem',
    ]);

    const cardResult = await new AxeBuilder({ page })
      .include('.card:has([data-testid="variation-provenance-legend"])')
      .analyze();
    expect(
      cardResult.violations.filter((v) => targetIds.has(v.id)).map((v) => `${v.id}: ${v.help}`)
    ).toEqual([]);

    await trigger(page, UNCONFIRMED).click();
    await expect(page.getByTestId('variation-provenance-dialog')).toBeVisible();
    // Wait for the evidence body so axe analyses the fully populated dialog.
    await expect(page.getByTestId('variation-provenance-source-0')).toBeVisible();

    const dialogResult = await new AxeBuilder({ page })
      .include('[data-testid="variation-provenance-dialog"]')
      .analyze();
    expect(
      dialogResult.violations.filter((v) => targetIds.has(v.id)).map((v) => `${v.id}: ${v.help}`)
    ).toEqual([]);
  });
});
