# Re-review publication removal (#635) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a publication removed in the re-review Edit-Review modal actually be removed, by deleting the union merge in `useReviewForm.submitForm()` that silently re-adds it.

**Architecture:** One composable stops widening the submitted set. `submitForm()` sanitises and submits `formData.publications` / `formData.genereviews` verbatim, matching the two sibling surfaces (`useEntityInfo`, `useReviewApprovalActions`) that never had the bug. No API change: `publication_replace_for_review()` is a faithful DELETE-then-INSERT and already honours a shrunken set. Coverage is added at both levels — a unit matrix on the composable, and an E2E spec that drives the real modal and asserts the DB effect through the API.

**Tech Stack:** Vue 3 + TypeScript, Vitest, Playwright, R/Plumber (read-only in this change), MySQL fixtures.

**Spec:** `.planning/superpowers/specs/2026-08-25-re-review-publication-removal-635-design.md`

## Global Constraints

- Handwritten source files stay under **600 lines** (AGENTS.md). `useReviewForm.ts` is 564 and this change only removes lines. `useReviewForm.spec.ts` is 538 — the #635 matrix must not push it over; extract the read-mock helpers if it approaches the ceiling.
- Frontend API access goes through the typed clients in `app/src/api/*`. No raw `axios` in views/components.
- Ontology/PMID tags are parsed with `splitOntologyTag()` only — never `split('-')[1]`.
- The E2E stack is **local-only**; there is no Playwright CI lane. Run `make playwright-stack`, then tear it down with `make playwright-stack-down` — leaving it up swaps `config.yml` and crash-loops the dev API.
- Verification gates before handoff: `make code-quality-audit`, `cd app && npm run type-check && npm run lint && npx vitest run`, then `make ci-local`.
- Release bump touches **four** surfaces: `app/package.json`, both root `version` fields in `app/package-lock.json`, `api/version_spec.json`, `CHANGELOG.md`.

---

## File Structure

| File | Responsibility after this change |
|---|---|
| `app/src/views/curate/composables/useReviewForm.ts` | Review-form state + submission. **Submits the live selection**; no snapshot of the loaded publication set. |
| `app/src/views/curate/composables/__tests__/useReviewForm.spec.ts` | Unit matrix pinning "submitted set == current selection" in both directions (add and remove). |
| `app/tests/e2e/review.publication-removal.spec.ts` | **New.** Browser-level #635 regression: remove a chip, save, assert gone via API and via a reopen. |
| `db/fixtures/playwright_e2e_baseline.sql` | Seeds a publication row shaped like production (`PMID:<n>` / `additional_references`) so the chip actually renders. |
| `app/tests/e2e/curate.variation-provenance.spec.ts` | Docblock corrected — its `reviewSaveWorks` note describes the old fixture shape. |
| `app/src/composables/__tests__/useMarkdownRenderer.spec.ts` | **New.** Pins the markdown-it 15 rendering + sanitiser contract. |
| `AGENTS.md`, `CHANGELOG.md`, version files | Durable docs + release bump. |

---

### Task 1: Make removal work (TDD, red first)

**Files:**
- Modify: `app/src/views/curate/composables/useReviewForm.ts:201-204, 330-334, 393-400, 485-488`
- Test: `app/src/views/curate/composables/__tests__/useReviewForm.spec.ts:87-253`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `useReviewForm()` keeps its exact public shape — `{ formData, submitForm(isUpdate: boolean, reReview: boolean): Promise<void>, loadReviewData, resetForm, ... }`. Only `originalPublications` / `originalGenereviews` (private, never exported) disappear. Task 2's E2E spec depends on the runtime behaviour, not on any new export.

- [ ] **Step 1: Write the failing tests**

Replace the `BUG-05: Publication preservation during re-review` describe block's third test
(`'handles scenario where form publications array is empty but originals exist'`,
currently at `useReviewForm.spec.ts:145-172`) and add the rest of the matrix. Rename the
block to `#635: submitted publications are exactly the current selection`.

Add a small helper next to `primeReadMocks` so each test reads one assertion, not ten
lines of cast:

```ts
/** The literature block of the single review write recorded by the mocks. */
function submittedLiterature(): { additional_references: string[]; gene_review: string[] } {
  expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);
  const call = reviewApiMocks.updateReview.mock.calls[0];
  return (
    call[0] as {
      review_json: { literature: { additional_references: string[]; gene_review: string[] } };
    }
  ).review_json.literature;
}
```

Then the tests:

```ts
it('removing one publication submits the remaining ones without it (#635)', async () => {
  primeReadMocks({
    publications: [
      { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
    ],
  });

  const { formData, loadReviewData, submitForm } = useReviewForm();
  await loadReviewData(1);
  await flushPromises();

  // What BFormTags does on @remove: reassign the array without that tag.
  formData.publications = formData.publications.filter((p) => p !== 'PMID:12345678');

  await submitForm(true, true);
  await flushPromises();

  expect(submittedLiterature().additional_references).toEqual(['PMID:87654321']);
});

it('removing every publication submits an empty set (#635)', async () => {
  primeReadMocks({
    publications: [
      { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
    ],
  });

  const { formData, loadReviewData, submitForm } = useReviewForm();
  await loadReviewData(1);
  await flushPromises();

  formData.publications = [];

  await submitForm(true, true);
  await flushPromises();

  expect(submittedLiterature().additional_references).toEqual([]);
});

it('removing a genereview does not disturb the additional references (#635)', async () => {
  primeReadMocks({
    publications: [
      { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      { publication_id: 'PMID:11111111', publication_type: 'gene_review' },
    ],
  });

  const { formData, loadReviewData, submitForm } = useReviewForm();
  await loadReviewData(1);
  await flushPromises();

  formData.genereviews = [];

  await submitForm(true, true);
  await flushPromises();

  const literature = submittedLiterature();
  expect(literature.gene_review).toEqual([]);
  expect(literature.additional_references).toEqual(['PMID:12345678']);
});

it('an add and a remove in the same save both take effect (#635)', async () => {
  primeReadMocks({
    publications: [
      { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
    ],
  });

  const { formData, loadReviewData, submitForm } = useReviewForm();
  await loadReviewData(1);
  await flushPromises();

  formData.publications = ['PMID:87654321', 'PMID:99999999'];

  await submitForm(true, true);
  await flushPromises();

  expect(submittedLiterature().additional_references).toEqual([
    'PMID:87654321',
    'PMID:99999999',
  ]);
});
```

Keep unchanged, because they still describe correct behaviour: `'stores original
publications when loading review data'`, `'merges original publications with new
additions on submit'` (rename its title to `'adding a publication keeps the existing
ones'` — the word "merges" is now a lie), `'deduplicates publications when same PMID
exists in both original and form'`, and `'clears original publications on form reset'`
(rename to `'a second load does not resurrect the first review's publications'`).

- [ ] **Step 2: Run the tests and confirm the four new ones FAIL**

```bash
cd app && npx vitest run src/views/curate/composables/__tests__/useReviewForm.spec.ts
```

Expected: 4 failures. The diagnostic shape must be *extra* entries, e.g.
`expected [ 'PMID:87654321' ] to deeply equal ... received [ 'PMID:12345678', 'PMID:87654321' ]`.
If a test fails for any other reason, the test is wrong — fix the test before touching
the source.

- [ ] **Step 3: Delete the union**

In `useReviewForm.ts`, remove the two refs and their two comment lines (`:201-204`):

```ts
  // BUG-05 fix: Store originally loaded publications to ensure they're never accidentally deleted
  // When submitting, we merge original publications with any user additions
  const originalPublications = ref<string[]>([]);
  const originalGenereviews = ref<string[]>([]);
```

Remove the snapshot in `loadReviewData` (`:330-334`):

```ts
      // BUG-05 fix: Store original publications to preserve them during submission
      // This ensures existing publications are never accidentally deleted even if
      // there are reactivity issues with the form bindings
      originalPublications.value = [...formData.publications];
      originalGenereviews.value = [...formData.genereviews];
```

Remove the reset in `resetForm` (`:485-488`):

```ts
    // BUG-05 fix: Clear original publications on form reset
    originalPublications.value = [];
    originalGenereviews.value = [];
```

Replace the merge in `submitForm` (`:393-400`) with:

```ts
    // #635: submit exactly what the curator selected. This deliberately does NOT
    // union in the set loaded from the server. The union it replaces ("BUG-05")
    // made removal impossible: dropping a chip cleared it from `formData` — which
    // is why the UI updated — and the union then restored it one line before
    // serialisation, so `publication_replace_for_review()` re-INSERTed the row the
    // curator had just deleted. The sibling surfaces (`useEntityInfo`,
    // `useReviewApprovalActions`) always submitted the live selection, which is why
    // removal only ever failed here. See #635.
    const cleanPublications = [...new Set(formData.publications)].map(sanitizePMID);
    const cleanGenereviews = [...new Set(formData.genereviews)].map(sanitizePMID);
```

The `new Set` stays: it is what keeps the dedupe test green, and BFormTags can hold a
duplicate when two inputs normalise to the same PMID (`PMID: 123` and `PMID:123`).

- [ ] **Step 4: Run the tests and confirm they all pass**

```bash
cd app && npx vitest run src/views/curate/composables/__tests__/useReviewForm.spec.ts
```

Expected: PASS, 0 failures. Then the whole unit suite and the static gates:

```bash
cd app && npx vitest run && npm run type-check && npm run lint
```

Expected: PASS. `type-check` is the one that catches an orphaned reference to a ref you
deleted — an unused `ref` import would only warn.

- [ ] **Step 5: Commit**

```bash
git add app/src/views/curate/composables/useReviewForm.ts \
        app/src/views/curate/composables/__tests__/useReviewForm.spec.ts
git commit -m "fix(review): submit the live publication selection so removals stick (#635)"
```

---

### Task 2: Fixture correction + E2E regression

**Files:**
- Modify: `db/fixtures/playwright_e2e_baseline.sql:245-278` (the `publication` insert) and `:608-628` (the `ndd_review_publication_join` insert)
- Modify: `app/tests/e2e/curate.variation-provenance.spec.ts:168-198` (stale docblock)
- Create: `app/tests/e2e/review.publication-removal.spec.ts`

**Interfaces:**
- Consumes: Task 1's behaviour. No new source exports.
- Produces: the fixture invariant that entity 123 / review 123 carries exactly one
  `additional_references` publication, `PMID:12345678`. Nothing else depends on it.

- [ ] **Step 1: Make the fixture production-shaped**

Production stores `publication_id` **with** the `PMID:` prefix and `publication_type` as
`additional_references` | `gene_review` — verified against the dev database
(`additional_references` 8148, `gene_review` 1099; zero rows of any other type). The
fixture uses `'12345678'` / `'PMID'`, so `useReviewForm.loadReviewData()` filters the row
out of both lists and the chip never renders. Change **both** inserts.

In the `publication` insert, `VALUES ('12345678', 'PMID', ...)` becomes
`VALUES ('PMID:12345678', 'additional_references', ...)`.

In the `ndd_review_publication_join` insert, `'12345678', 'PMID',` becomes
`'PMID:12345678', 'additional_references',`.

Replace the KNOWN LANDMINE comment block above the `publication` insert with:

```sql
-- PMID 12345678 is a real PubMed record whose only author is a 74-character
-- `CollectiveName` ("Ministerial Meeting on Population of the Non-Aligned Movement
-- (1993: Bali)"). That used to overflow `publication`.`Lastname` VARCHAR(50) and roll
-- back the whole review save as an opaque 500; migration 048 widened both author
-- columns to VARCHAR(255) (#614), so it no longer does. It stays as the fixture PMID
-- deliberately: it is the repo's only regression pressure on that path.
--
-- SHAPE MATTERS. `publication_id` carries the `PMID:` prefix and `publication_type` is
-- `additional_references` | `gene_review`, exactly as production stores them. A row
-- typed `'PMID'` (as this fixture held before #635) matches NEITHER of the filters in
-- `useReviewForm.loadReviewData()`, so it renders as no chip at all — which is why the
-- #635 removal bug had no end-to-end coverage. Seeding this row correctly is what lets
-- `review.publication-removal.spec.ts` exist.
--
-- Because the row is already in `publication`, `publication_write_prepare()` finds it by
-- id and skips the PubMed fetch entirely, so a save is offline and deterministic.
```

- [ ] **Step 2: Correct the now-stale docblock in the #608 spec**

`curate.variation-provenance.spec.ts`'s `reviewSaveWorks` docblock states the fixture is
seeded `publication_type = 'PMID'` and that the probe must avoid a resolvable PMID to
dodge "D2". Both premises are dead (Step 1; migration 048). Replace that paragraph with:

```ts
 * PROBE PAYLOAD: empty `literature`, which is what this spec's own flows submit — they
 * never touch the Publications field. The two defects this probe used to gate on are
 * both fixed (D1 mass-assignment, #613; D2 `publication.Lastname` VARCHAR(50) overflow,
 * #614/migration 048), so the probe is now expected to pass; it is kept because a
 * skip-with-reason is a better failure mode than eight tests failing on an unrelated
 * save-path outage. The baseline's publication row is seeded production-shaped since
 * #635 (`PMID:12345678` / `additional_references`), so it now renders as a chip in the
 * modal; these tests do not assert on it, but do not be surprised to see it.
```

- [ ] **Step 3: Write the E2E regression spec**

Create `app/tests/e2e/review.publication-removal.spec.ts`:

```ts
// app/tests/e2e/review.publication-removal.spec.ts
//
// #635 — a publication removed in the re-review Edit-Review modal must actually be
// removed from the entity.
//
// The bug this guards was invisible to the UI: `useReviewForm.submitForm()` submitted the
// UNION of the loaded set and the current selection, so the chip vanished, the save
// returned 200, and the row survived in `ndd_review_publication_join`. A UI-only
// assertion would therefore have PASSED against the broken build. The load-bearing
// assertion here is the API read after the save.
//
// Routing facts (same as curate.variation-provenance.spec.ts, which documents them in
// full): the Edit-Review modal lives on /Review, `GET /api/re_review/table` scopes the
// queue to the requesting user's assignments, and the baseline assigns batch 9001 to
// pw_curator as well as pw_reviewer — so log in as `curator`.
//
// This test MUTATES state (it deletes a join row), so it re-seeds the shared baseline
// both before and after.
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';
import type { APIRequestContext } from '@playwright/test';

const ENTITY_ID = 123;
const REVIEW_ID = 123;
const FIXTURE_PMID = 'PMID:12345678';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

function reseedBaseline(): void {
  execSync('make _playwright-seed-e2e-baseline', { cwd: REPO_ROOT, stdio: 'pipe' });
}

async function curatorToken(request: APIRequestContext): Promise<string> {
  const auth = await request.post('/api/auth/authenticate', {
    data: { user_name: testUsers.curator.username, password: testUsers.curator.password },
  });
  expect(auth.ok(), 'curator login for the API assertion').toBeTruthy();
  const parsed: unknown = JSON.parse((await auth.text()).trim());
  return Array.isArray(parsed) ? String(parsed[0]) : String(parsed);
}

/** The review's publication ids straight from the API — the DB truth, not the DOM. */
async function reviewPublicationIds(request: APIRequestContext): Promise<string[]> {
  const token = await curatorToken(request);
  const res = await request.get(`/api/review/${REVIEW_ID}/publications`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.ok(), `GET /api/review/${REVIEW_ID}/publications -> ${res.status()}`).toBeTruthy();
  const rows = JSON.parse(await res.text()) as Array<{ publication_id: string }>;
  return rows.map((r) => r.publication_id);
}

test.describe('#635 re-review publication removal', () => {
  test.beforeEach(() => {
    reseedBaseline();
  });

  test.afterAll(() => {
    reseedBaseline();
  });

  test('a publication removed in the modal is gone from the entity after save', async ({
    loggedInAs,
    request,
  }) => {
    // Precondition, stated rather than assumed: the fixture row is really there.
    expect(await reviewPublicationIds(request)).toContain(FIXTURE_PMID);

    const page = await loggedInAs('curator');
    const server5xx: string[] = [];
    page.on('response', (r) => {
      if (r.status() >= 500) server5xx.push(`${r.status()} ${r.request().method()} ${r.url()}`);
    });

    await page.goto('/Review');
    await page.getByRole('button', { name: /edit review/i }).first().click();

    const publicationTags = page
      .locator('.b-form-tags')
      .filter({ has: page.locator('#review-literature-select') });
    const chip = publicationTags.locator(`.b-form-tag[title="${FIXTURE_PMID}"]`);
    await expect(chip, 'the fixture publication renders as a chip').toBeVisible();

    await chip.locator('.b-form-tag-remove').click();
    await expect(chip, 'the chip disappears immediately (this always worked)').toHaveCount(0);

    await page.getByRole('button', { name: 'Save Review' }).click();
    await expect(page.getByText(/review submitted successfully/i)).toBeVisible();

    expect(server5xx, 'no server error during the save').toEqual([]);

    // THE assertion. Before the fix this returned [FIXTURE_PMID] despite the 200.
    expect(await reviewPublicationIds(request)).not.toContain(FIXTURE_PMID);

    // And the curator sees the removal persist on a fresh open.
    await page.reload();
    await page.getByRole('button', { name: /edit review/i }).first().click();
    await expect(publicationTags.locator(`.b-form-tag[title="${FIXTURE_PMID}"]`)).toHaveCount(0);
  });
});
```

- [ ] **Step 4: Run it**

```bash
make playwright-stack
cd app && npx playwright test tests/e2e/review.publication-removal.spec.ts --workers=1
```

Expected: 1 passed. If a locator misses, open the trace
(`npx playwright show-trace`) and correct the selector against the real DOM — the
`.b-form-tag` / `.b-form-tag-remove` classes are read from
`bootstrap-vue-next/dist/BFormTag-*.js`, and the "Edit review" trigger's accessible name
must be confirmed against `Review.vue`'s queue table rather than assumed.

Then confirm the fixture change did not disturb the #608 specs, which share entity 123:

```bash
cd app && npx playwright test tests/e2e/curate.variation-provenance.spec.ts \
                              tests/e2e/entity.variation-provenance.spec.ts \
                              tests/e2e/review.approve.spec.ts --workers=1
```

Expected: no NEW failures versus the documented baseline (0 failed / 3 env-gated skips
across the full suite). Tear down when finished: `make playwright-stack-down`.

- [ ] **Step 5: Commit**

```bash
git add db/fixtures/playwright_e2e_baseline.sql \
        app/tests/e2e/review.publication-removal.spec.ts \
        app/tests/e2e/curate.variation-provenance.spec.ts
git commit -m "test(review): e2e regression for publication removal in re-review (#635)"
```

---

### Task 3: markdown-it 15 integration (#620)

**Files:**
- Modify: `app/package.json` (remove `@types/markdown-it`), `app/package-lock.json`
- Create: `app/src/composables/__tests__/useMarkdownRenderer.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new. `renderMarkdown(source: string): string` and
  `useMarkdownRenderer(debounceMs?: number)` keep their signatures.

Do this **before** Task 4 merges the dependabot branches, so the branch that raises
`markdown-it` lands together with the two things it needs.

- [ ] **Step 1: Write the contract test**

`useMarkdownRenderer.ts` has no test today, so nothing pins its behaviour across a major
bump. Create `app/src/composables/__tests__/useMarkdownRenderer.spec.ts`:

```ts
// app/src/composables/__tests__/useMarkdownRenderer.spec.ts
/**
 * Pins the rendering + sanitiser contract of useMarkdownRenderer across the
 * markdown-it 14 -> 15 major bump (#620).
 *
 * markdown-it 15 moves to linkify-it v6, which turns OFF fuzzy links by default. The
 * two linkify assertions below encode the POST-15 behaviour deliberately: a bare
 * `example.com` no longer auto-links, an explicit scheme still does. If a future bump
 * changes that again, this test is the thing that says so.
 */
import { describe, it, expect } from 'vitest';
import { renderMarkdown } from '../useMarkdownRenderer';

describe('renderMarkdown', () => {
  it('renders basic markdown', () => {
    expect(renderMarkdown('**bold** and *em*')).toContain('<strong>bold</strong>');
    expect(renderMarkdown('**bold** and *em*')).toContain('<em>em</em>');
  });

  it('renders lists, headings and code', () => {
    const html = renderMarkdown('# Title\n\n- one\n- two\n\n`code`');
    expect(html).toContain('<h1>Title</h1>');
    expect(html).toContain('<li>one</li>');
    expect(html).toContain('<code>code</code>');
  });

  it('strips raw HTML from the source (html: false)', () => {
    const html = renderMarkdown('<script>alert(1)</script>\n\nplain');
    expect(html).not.toContain('<script');
    expect(html).not.toContain('alert(1)');
  });

  it('drops tags outside the DOMPurify allowlist', () => {
    // `img` is not in ALLOWED_TAGS, so the sanitiser must remove it even though
    // markdown-it happily emits it.
    expect(renderMarkdown('![x](https://example.com/x.png)')).not.toContain('<img');
  });

  it('auto-links an explicit scheme', () => {
    expect(renderMarkdown('see https://example.com now')).toContain(
      '<a href="https://example.com"'
    );
  });

  it('does not auto-link a bare domain (linkify-it v6 default, markdown-it 15)', () => {
    expect(renderMarkdown('see example.com now')).not.toContain('<a href');
  });
});
```

- [ ] **Step 2: Run it on the CURRENT (14.x) tree to see where it stands**

```bash
cd app && npx vitest run src/composables/__tests__/useMarkdownRenderer.spec.ts
```

Expected on markdown-it 14: the last test **FAILS** (14 fuzzy-links `example.com`), the
other five pass. That failure is the proof the bump is a real behaviour change and that
this test is measuring it. Do not "fix" it here.

- [ ] **Step 3: Take the bump and drop the stale types package**

markdown-it 15 ships its own declarations and its changelog says to remove
`@types/markdown-it`; leaving both installed gives one module two declaration sources.

```bash
cd app && npm uninstall @types/markdown-it && npm install markdown-it@^15.0.0
```

- [ ] **Step 4: Verify the whole gate**

```bash
cd app && npx vitest run src/composables/__tests__/useMarkdownRenderer.spec.ts \
       && npm run type-check && npm run lint && npm run build
```

Expected: all six tests PASS (the fuzzy-link test now passes because 15 disabled it),
`type-check` clean (this is where a leftover `@types/markdown-it` would surface), lint
clean, build succeeds.

- [ ] **Step 5: Commit**

```bash
git add app/package.json app/package-lock.json \
        app/src/composables/__tests__/useMarkdownRenderer.spec.ts
git commit -m "chore(deps): bump markdown-it to 15, drop @types/markdown-it, pin renderer contract (#620)"
```

---

### Task 4: Fold in the remaining dependabot bumps

**Files:**
- Modify: `app/package.json`, `app/package-lock.json`, `docker-compose.dev.yml`, `docker-compose.playwright.yml`

**Interfaces:** none.

- [ ] **Step 1: Merge the three remaining branches**

All three are `mergeable_state: clean` against `master`. Merge the compose-only one
first, then the two npm ones (which touch the same lockfile Task 3 just rewrote, so
expect and resolve lockfile conflicts).

```bash
git fetch origin \
  dependabot/docker_compose/compose-images-de579208ff \
  dependabot/npm_and_yarn/app/production-minor-patch-e61cb27959 \
  dependabot/npm_and_yarn/app/dev-dependencies-e434320d04

git merge --no-edit FETCH_HEAD  # run once per branch, in the order above
```

- [ ] **Step 2: Resolve lockfile conflicts by regenerating, never by hand-merging**

If `app/package-lock.json` conflicts, take **`package.json`** as the source of truth,
resolve that file's conflict manually (the version lines are independent), then:

```bash
cd app && rm -f package-lock.json && npm install
```

Confirm the result carries every intended bump and nothing else:

```bash
cd app && npm ls vue pinia dompurify markdown-it eslint vue-tsc typescript-eslint --depth=0
```

Expected: `vue@3.5.41`, `pinia@4.0.3`, `dompurify@3.4.14`, `markdown-it@15.x`,
`eslint@10.9.x`, `vue-tsc@3.3.11`, `typescript-eslint@8.67.x`, and **no**
`@types/markdown-it`.

- [ ] **Step 3: Run the gates the tooling bumps can break**

`eslint` 10.8→10.9 and `typescript-eslint` 8.65→8.67 can surface new rule violations;
`vue-tsc` 3.3.8→3.3.11 can surface new type errors; `sass` 1.102→1.103 can surface new
deprecations at build time. Run all four:

```bash
cd app && npm run lint && npm run type-check && npm run type-check:strict && npm run build
cd app && npx vitest run
```

Expected: clean. Fix any new finding **in the code**, not by pinning the tool back.

- [ ] **Step 4: Verify the compose bump did not break the stacks**

```bash
grep -rn "axllent/mailpit" docker-compose*.yml
```

Expected: `v1.30.7` in both `docker-compose.dev.yml` and `docker-compose.playwright.yml`.

- [ ] **Step 5: Commit**

The merges commit themselves. Commit only the lockfile regeneration:

```bash
git add app/package.json app/package-lock.json
git commit -m "chore(deps): regenerate lockfile after folding in #633, #634, #628"
```

---

### Task 5: Docs and release bump

**Files:**
- Modify: `AGENTS.md` (Stack-Specific Gotchas), `CHANGELOG.md`, `app/package.json`,
  `app/package-lock.json` (both root `version` fields), `api/version_spec.json`

**Interfaces:** none.

- [ ] **Step 1: Record the trap in AGENTS.md**

Add to the **Stack-Specific Gotchas** list, after the review-tag bullet:

```markdown
- A review-form composable must submit the curator's **live** selection, never a union
  with the set it loaded. `useReviewForm.submitForm()` merged
  `originalPublications ∪ formData.publications` as a "never accidentally delete"
  guard; because `publication_replace_for_review()` (`api/functions/publication-repository.R`)
  is an honest DELETE-then-INSERT of exactly what it is sent, that union made removal
  impossible on the one surface that had it — the chip vanished, the PUT returned 200,
  and the row came straight back (#635). The two sibling surfaces
  (`views/curate/composables/useEntityInfo.ts`, `composables/review/useReviewApprovalActions.ts`)
  never had it, which is why removal worked from Modify Entity and nowhere else. A guard
  that cannot distinguish "the curator cleared the field" from "a hypothetical reactivity
  failure" is not a guard; if a desync is ever observed, fix the binding.
- The Playwright baseline's publication row must stay **production-shaped**:
  `publication_id` carries the `PMID:` prefix and `publication_type` is
  `additional_references` | `gene_review`. It was seeded `'12345678'` / `'PMID'`, which
  matches neither filter in `useReviewForm.loadReviewData()` — so the row rendered as no
  chip at all and #635 shipped without end-to-end coverage. Production holds only those
  two types (8148 / 1099; zero others).
```

- [ ] **Step 2: Write the CHANGELOG entry**

Under `## [Unreleased]` → `### Fixed`, above the #607 entry:

```markdown
- **Publications removed in the re-review tab are actually removed** (#635).
  `useReviewForm.submitForm()` did not submit the curator's selection; it submitted the
  union of that selection and the set loaded from the server. Removing a PMID cleared it
  from the reactive form — which is why the chip disappeared — and the union restored it
  one line before serialisation, so the save returned "Review submitted successfully" and
  `publication_replace_for_review()` dutifully re-INSERTed the row that had just been
  deleted. Reopening the tab, or approving the entity, showed the publication still
  attached.

  The union was added as a "never accidentally delete an existing publication" guard
  against reactivity issues the current bindings cannot produce: `ReviewFormFields.vue`
  binds `v-model` straight onto the composable's own reactive object, `loadReviewData()`
  is atomic so a partial load cannot open the modal, and the draft is cleared before the
  load. It was also the reason removal worked from Modify Entity but not from re-review —
  the two sibling surfaces never had it. It is gone; the live selection is submitted, as
  everywhere else. No API change: the server was always correct.

  Covered by a unit matrix asserting the submitted set equals the current selection in
  both directions, and by a new Playwright regression that removes a chip, saves, and
  asserts the row is gone **through the API** — the check a UI-only assertion would have
  passed while the bug was live.
```

Under `### Changed`, add:

```markdown
- `markdown-it` 14.3.0 → 15.0.0 (#620), with `@types/markdown-it` removed (15 bundles its
  own declarations). markdown-it 15 uses linkify-it v6, which disables fuzzy links by
  default: bare `example.com` text in a markdown field no longer auto-links, while
  `https://example.com` still does. `useMarkdownRenderer` gains its first unit test,
  pinning that behaviour plus the `html: false` and DOMPurify-allowlist contracts.
- Dependency bumps folded in: production minor/patch group (#633, incl. `vue` 3.5.41,
  `pinia` 4.0.3, `dompurify` 3.4.14), dev-dependency group (#634, incl. `eslint` 10.9,
  `typescript-eslint` 8.67, `vue-tsc` 3.3.11), and `axllent/mailpit` v1.30.7 (#628).
```

- [ ] **Step 3: Bump the four version surfaces to 0.31.2**

```bash
cd app && npm version 0.31.2 --no-git-tag-version
```

That rewrites `app/package.json` and **both** root `version` fields in
`app/package-lock.json`. Then edit `api/version_spec.json`'s `"version"` to `"0.31.2"`,
and change `## [Unreleased]` to `## [0.31.2] - 2026-08-25` in `CHANGELOG.md`, adding a
fresh empty `## [Unreleased]` above it.

Verify all four moved:

```bash
grep -n '"version": "0.31.2"' app/package.json api/version_spec.json
grep -c '"version": "0.31.2"' app/package-lock.json   # expect 2
grep -n '0.31.2' CHANGELOG.md | head -1
```

- [ ] **Step 4: Run the full local gate**

```bash
make code-quality-audit
make ci-local
```

Expected: both green. `code-quality-audit` is the file-size ratchet — this change only
removes lines from `useReviewForm.ts`, but the new spec files count, so if the audit
flags a baseline drift, update `scripts/code-quality-file-size-baseline.tsv` **in this
PR** rather than after merge.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md CHANGELOG.md app/package.json app/package-lock.json api/version_spec.json
git commit -m "chore(release): v0.31.2"
```

---

## Self-Review

**Spec coverage.** §2 root cause → Task 1 Step 3. §4 "no confirmation prompt / no server
change / no compensating snapshot" → honoured by Task 1 touching one file and no R code.
§5 unit matrix → Task 1 Step 1 (all seven rows present). §5 E2E → Task 2 Step 3. §5
fixture correction → Task 2 Step 1. §6 file table → Tasks 1, 2, 5. §8 dependency bumps →
Tasks 3 and 4, with both markdown-it integration steps. §7 risks → the E2E test (desync),
the server-side `log_warn` (accidental clearing, no code needed), `reseedBaseline()`
(destructive test).

One spec item is **deliberately widened** by the plan: §5 changes only
`ndd_review_publication_join.publication_type`, but the plan also changes
`publication.publication_id` to carry the `PMID:` prefix and `publication.publication_type`
to `additional_references`. Verifying against the live database showed production stores
the prefixed form, and a bare `12345678` chip would fail the form's own
`tagValidatorPMID`, so a fixture that only fixed the join row would still not be the shape
the code expects. Recorded here rather than left as a silent divergence.

**Placeholder scan.** No TBD/TODO. Every code step carries the literal code. Every command
carries its expected output. The one judgement call — an E2E locator that misses — has an
explicit procedure (Task 2 Step 4) rather than "adjust as needed".

**Type consistency.** `submittedLiterature()` returns
`{ additional_references: string[]; gene_review: string[] }` and every Task 1 assertion
reads one of those two fields. `reviewPublicationIds()` returns `string[]` and both call
sites `toContain`/`not.toContain` a string. `renderMarkdown(source: string): string` is
used only as a string in Task 3. `FIXTURE_PMID` is the same literal in the fixture, the
E2E spec, and the AGENTS.md note.
