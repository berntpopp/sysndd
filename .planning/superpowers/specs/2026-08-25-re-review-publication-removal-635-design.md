# Publication tags cannot be removed in the re-review tab (#635)

- **Issue:** [#635](https://github.com/berntpopp/sysndd/issues/635) (`bug`)
- **Date:** 2026-08-25
- **Surface:** frontend only (`app/src/views/curate/composables/useReviewForm.ts`)
- **Also folded into the same PR:** dependabot bumps #634, #633, #628, #620 (see §8)

## 1. Reported behaviour

> Publication tags are not actually removed from the entity if they are removed in the
> re-review tab. PMID tags disappear when removing them in the tab and after "Save Review"
> the message "Review submitted successfully" appears. However, revisiting the tab in the
> re-review section (or after approving the reviewed entity) reveals that the publication
> tag is still linked to the entity.
>
> In contrast, there is no issue with removing publication tags when using the
> "Modify entity" function.

Three facts in that report pin the defect precisely, and each is load-bearing:

1. **The tag disappears from the UI.** So the `v-model` binding works and the reactive
   form state really does lose the tag. The defect is downstream of the widget.
2. **The save succeeds** (`Review submitted successfully`, HTTP 2xx). So the request is
   well-formed and the server accepted it. The defect is not an error path.
3. **Modify Entity is unaffected.** So it is not in the shared server write path — it is
   in whatever the re-review Edit-Review modal does *differently*.

## 2. Root cause

`useReviewForm.submitForm()` does not submit the current selection. It submits the
**union** of the current selection and the set that was loaded from the server:

```ts
// app/src/views/curate/composables/useReviewForm.ts:393-400
// BUG-05 fix: Merge original publications with current form data
// This ensures existing publications are preserved even if there are reactivity issues
const mergedPublications = [
  ...new Set([...originalPublications.value, ...formData.publications]),
];
const mergedGenereviews = [...new Set([...originalGenereviews.value, ...formData.genereviews])];
```

`originalPublications` / `originalGenereviews` are snapshotted at load
(`useReviewForm.ts:333-334`) and are never narrowed by anything the curator does. A
removal therefore mutates `formData.publications` — which is why the chip vanishes — and
is then silently undone one line before serialisation. The PUT body carries the full
pre-edit set.

The server is not complicit; it is obedient.
`publication_replace_for_review()` (`api/functions/publication-repository.R:224`)
`DELETE`s every `ndd_review_publication_join` row for the review and re-`INSERT`s exactly
what it was handed. Handed the union, it faithfully restores the removed row. The
endpoint's empty-literature branch is also correct: `purrr::compact()` on an all-empty
`literature` yields a zero-row tibble (`api/endpoints/review_endpoints.R:225-242`) and
`review_write_mutate()` routes a zero-row PUT to `publication_replace_for_review()` with
an empty tibble (`api/services/review-write-service.R:474-479`), i.e. "delete them all".
**No API change is required or wanted.**

The union exists in exactly one composable. Verified by
`grep -rn "originalPublications\|originalGenereviews" app/src` — one file. The two sibling
surfaces that also prefill-and-resubmit publications submit the live selection verbatim:

| Surface | Composable | Union? |
|---|---|---|
| Re-review Edit-Review modal | `views/curate/composables/useReviewForm.ts` | **yes — the bug** |
| Modify Entity | `views/curate/composables/useEntityInfo.ts` | no |
| Approve Review | `composables/review/useReviewApprovalActions.ts` | no |

That table is the report's third fact, explained.

## 3. Why the union was added, and why removing it is safe

The comment claims the union guards against "reactivity issues with the form bindings",
and a unit test enshrines that claim
(`__tests__/useReviewForm.spec.ts:145`, *"Simulate form reactivity issue - formData.publications
gets cleared"*). The guard is defending against a failure mode the current code cannot
produce, and the test now asserts the bug:

- **The binding cannot desync.** `ReviewFormFields.vue:206` binds
  `v-model="localFormData.publications"`, where `localFormData` is a `computed` whose
  getter returns `props.modelValue` *itself* (`ReviewFormFields.vue:373-376`) — the
  composable's `reactive` object, passed down unchanged through
  `ReviewEditModal.vue:99`. A nested `v-model` write mutates that object in place. There
  is no copy, so there is nothing to fall out of sync.
- **A partial load cannot open the modal.** `loadReviewData()` awaits a single
  `Promise.all` over the four read helpers (`useReviewForm.ts:296-301`); any rejection
  propagates out of `infoReview()` (`Review.vue:405`) *before* `$refs.reviewModalRef.show()`
  at line 415. A modal that opened has a complete load behind it.
- **A stale draft cannot bleed in.** `Review.vue` never calls `restoreFromDraft()` or
  `checkForDraft()` — the draft this modal writes is never read back. `infoReview()` also
  calls `clearDraft()` before the load and `loadReviewData()` overwrites every
  publication field from the response, but the operative reason is non-use, not the
  clear. (Stated precisely after review: `clearDraft()` does not cancel an already
  queued debounce, so resting the argument on it would have been wrong.)

So after the fix, `formData.publications` being empty means one thing only: the curator
emptied it. That is the case the issue asks us to honour.

Note the asymmetry the guard created. Phenotypes and variation-ontology terms are already
submitted verbatim from `formData` — only publications got the union. A curator could
always remove a phenotype in this same modal; only publications were sticky.

## 4. Fix

Delete the union and the two snapshot refs. `submitForm()` sanitises and submits
`formData.publications` / `formData.genereviews` directly, exactly as the two sibling
surfaces do.

Deliberately **not** doing:

- **No confirmation prompt on removal.** Removal becomes symmetric with Modify Entity,
  which has never prompted. Adding a modal would be new UX the issue did not ask for, on
  the one surface that already has the most modal chrome.

  > Corrected after review: this originally cited `publication_replace_for_review()`'s
  > `log_warn` on a decreasing count as the compensating audit trail. That was **false**.
  > The warning sat inside the function's `is.null(conn)` branch, and the review write
  > path always passes `txn_conn` (`review-write-service.R`), so it never fired on the
  > only path that matters. Rather than drop the claim, the logging was moved into the
  > shared write path and is read on the write connection, making it transaction-local.
  > Verified live: a browser removal now emits
  > `WARN Publication count decreasing for review 3155: 2 -> 1.`
- **No server change.** The server is correct (§2). A "don't shrink the set" guard there
  would re-implement this bug one layer down, and would break Modify Entity too.
- **No compensating snapshot kept "just in case".** A guard that cannot distinguish
  "the curator removed everything" from "a hypothetical reactivity failure" is not a
  guard; it is this bug. If a real desync is ever observed, the fix is to fix the
  binding.

## 5. Test plan

**Unit — `__tests__/useReviewForm.spec.ts`.** The `BUG-05` block is rewritten around the
true invariant: *the submitted set is the current selection*. Preservation-on-add is kept
(it is still correct, and it is the behaviour the original BUG-05 wanted); the
preservation-on-clear test is inverted into the #635 regression.

| Test | Asserts |
|---|---|
| adding a PMID keeps the existing ones | `[a, b]` + push `c` → submits `a, b, c` (unchanged) |
| **removing one publication submits without it** | `[a, b]` − `a` → submits `[b]` |
| **removing every publication submits an empty set** | `[a]` − `a` → submits `[]` |
| **removing a genereview submits without it** | independent of the additional-references list |
| **add and remove in one save** | `[a, b]` − `a` + `c` → submits `[b, c]` |
| no duplicates when re-adding an existing PMID | dedupe still holds |
| a second load does not resurrect the first review's set | cross-review isolation |

**E2E — `app/tests/e2e/review.publication-removal.spec.ts`.** Drives the real modal as a
curator: open the re-review Edit-Review modal for the baseline entity, remove the PMID
chip, Save, then assert the row is gone **both** by reopening the modal and by reading
`GET /api/review/<id>/publications` — the API assertion is what the issue actually
reports, and a UI-only assertion would have passed while the bug was live. Gated by the
existing `reviewSaveWorks` probe pattern so an unrelated save-path outage skips rather
than false-fails. Re-seeds the baseline afterwards, since the test is destructive.

**Fixture correction — `db/fixtures/playwright_e2e_baseline.sql`.** The seeded
`ndd_review_publication_join` row carries `publication_type = 'PMID'`. The form partitions
publications on `publication_type === 'gene_review'` / `'additional_references'`
(`useReviewForm.ts:315-322`), so a `'PMID'` row matches neither filter and never renders —
the E2E test would have nothing to remove. Production holds only the two real values
(verified against the dev database: `additional_references` 8148, `gene_review` 1099), so
`'PMID'` is a fixture error, not a shape the app must tolerate. Corrected to
`additional_references`.

> Worth stating plainly, because it is the uncomfortable part: a `'PMID'`-typed row would
> be *deleted* by any save from this modal, since it renders in neither list and so is
> absent from the submitted union. That is pre-existing, is not what #635 reports, and no
> such row exists in production. It is recorded here rather than fixed, because a
> speculative tolerance for a value the schema permits but the data never contains is
> scope this issue does not carry.

## 6. Files

| File | Change |
|---|---|
| `app/src/views/curate/composables/useReviewForm.ts` | remove union + both snapshot refs + their reset |
| `app/src/views/curate/composables/__tests__/useReviewForm.spec.ts` | invert the enshrined test; add the removal matrix |
| `app/tests/e2e/review.publication-removal.spec.ts` | new E2E regression |
| `db/fixtures/playwright_e2e_baseline.sql` | `publication_type` `'PMID'` → `'additional_references'` |
| `CHANGELOG.md`, `app/package.json`, `app/package-lock.json`, `api/version_spec.json` | release bump |

## 7. Risks

| Risk | Mitigation |
|---|---|
| A real reactivity desync exists that the union was masking | §3 traces all three candidate paths (binding, partial load, stale draft) to closed. The E2E test drives the real widget, so a desync would fail it loudly instead of silently eating an edit. |
| A curator empties the list by accident | Symmetric with Modify Entity, which has always behaved this way. Server-side `log_warn` on a decreasing count keeps the audit trail. |
| The E2E test is destructive to the shared baseline | Re-seeds via the existing `reseedBaseline()` helper, as the #608 provenance specs already do. |

## 8. Dependency bumps folded in

Four open dependabot PRs, all `mergeable_state: clean` against `master`, merged into this
branch rather than landed separately so one CI run and one release bump covers them.

| PR | Bump | Note |
|---|---|---|
| #628 | `axllent/mailpit` v1.30.6 → v1.30.7 | compose only (`docker-compose.dev.yml`, `docker-compose.playwright.yml`) |
| #633 | production-minor-patch ×8 (`vue` 3.5.40→3.5.41, `pinia`, `dompurify`, `cytoscape`, `swagger-ui`, `@unhead/vue`, `@vueuse/core`) | patch/minor |
| #634 | dev-dependencies ×15 (`eslint` 10.8→10.9, `typescript-eslint` 8.65→8.67, `vue-tsc` 3.3.8→3.3.11, `sass`, `axios`, `@playwright/test`, …) | lint/type-check/build tooling — verified by `make ci-local`, which runs all three |
| #620 | `markdown-it` 14.3.0 → **15.0.0** | **major; not a drop-in — see below** |

`markdown-it` 15 requires two things dependabot did not do:

1. It **bundles its own TypeScript declarations** and its changelog says to remove
   `@types/markdown-it`. `app/package.json` still pins `@types/markdown-it: ^14.1.2`; two
   competing declaration sources for one module is exactly the setup that produces a
   confusing `vue-tsc` failure. The stale `@types` package is removed here.
2. It moves to **linkify-it v6, which disables fuzzy links by default**. `useMarkdownRenderer.ts`
   sets `linkify: true`, so bare `example.com` text stops auto-linking while
   `https://example.com` continues to. That composable has **no test at all** today, so
   nothing in the repo pins its contract. A unit test is added covering the
   sanitiser allowlist, the `html: false` XSS path, and both linkify behaviours — pinning
   the post-15 contract rather than asserting the pre-15 one.

Both are in scope precisely because folding #620 in without them would be the sloppy
version of "fold it in".


## 9. Adversarial review outcomes (Codex `gpt-5.6-sol`, high)

The spec was reviewed before any code was written. Eleven findings; the verdict was
DO-NOT-SHIP-as-written. Each was checked against the code rather than accepted, and the
review's own two factual errors are recorded here as well — a review is evidence, not
an oracle.

**Accepted and implemented**

| # | Finding | Action |
|---|---|---|
| 1 | `submitReviewChange()` derived create-vs-update from `review_info.review_id`, populated by an error-swallowing `loadReviewInfo()`; a failed metadata fetch POSTed and minted a **duplicate review** | Derive from `useReviewForm`'s own `reviewId` (atomic load). Red-green in `Review.submitMode.spec.ts`. A genuine latent bug on the same save path. |
| 3 | The `bind_rows(.id = )` positional contract was unproven | Parse extracted to `functions/review-literature-parsing.R`; 23 assertions across all four populated/empty combinations |
| 6 | The `log_warn` audit-trail claim was false on the real path | Logging moved into the shared write path; verified live |
| 8 | markdown-it 15 disables fuzzy links; `make ci-local` runs neither Vitest nor the bundle build | `md.linkify.set({ fuzzyLink: true })` + a renderer test; verification extended to `npm run test:unit` and `build:bundle-budget` |
| 9 | No durable-docs update | `AGENTS.md` gotchas added |
| 5 | Reseed only at the successful end | Moved to `afterEach` |
| 10, 11 | Draft-safety reasoning imprecise; stale line anchors | Corrected above |

**Rejected, with evidence**

- **Finding 4's sub-claim, "Keep `publication.publication_type='PMID'`; only the join's
  relation type is wrong."** Wrong. Production's `publication` table holds
  `additional_references` (4304) and `gene_review` (386) and **zero** `'PMID'` rows —
  queried live. Both tables are corrected, which is also what makes the seeded id
  `PMID:12345678` consistent with the `validatePMID` the form applies.
- **Finding 2, "fail closed on unknown relation types."** The concern is real in
  principle — an unrecognised type is filtered out of both lists and then deleted by the
  replace — but the counts above are exhaustive in both tables, so there is no such row
  to fail closed on. Adding a 400 path for data that does not exist would be speculative.
  Recorded as a residual in §5 instead.
- **Findings 5 and 7's implementability objections** (file-local helpers, `getByLabel`,
  missing bearer, dedupe conflict) describe the spec's prose, not the implementation:
  the E2E spec carries its own helpers, scopes by `#review-literature-select`, attaches
  the token explicitly, and `submitForm()` de-duplicates the current selection only.
- **Finding 8's "preferably keep the four Dependabot updates separate."** The bundling
  was explicitly requested.

**Found by neither the spec nor the review — only by driving the real stack**

`BFormTag` renders `title` from its internal `tagText`, and `ReviewFormFields.vue` fills
the tag's default slot with a `<BLink>`, so the attribute is the literal
`"[object Object]"`. The planned `.b-form-tag[title="PMID:…"]` selector matches nothing
and would have made the E2E pass vacuously. Chips are matched by text instead.
