# Variation Ontology Provenance (#608) — Application-Repo Execution Plan

**Issue:** [#608](https://github.com/berntpopp/sysndd/issues/608)
**Spec:** `.planning/superpowers/specs/2026-07-30-variation-ontology-provenance-608-design.md` (revision 2, externally reviewed by `gpt-5.6-sol`)
**Branch:** `feat/variation-ontology-provenance-608`
**Repo:** `berntpopp/sysndd` (application repo). The backfill is **Plan B** in `sysndd-administration`.

## What this plan delivers, and why this scope

The issue's phasing table has seven phases across two repos. This plan executes every
application-repo phase that is **correct to ship before the backfill runs**, plus the
frontend surfaces, and explicitly defers the two pieces that are not.

| Phase | Deliverable | This plan |
|---|---|---|
| 1 | Migration + assertion/evidence repositories | **T1–T3** |
| 2 | Backfill, all three batches | administration repo (Plan B) — not here |
| 3 | API reads + public chips and evidence popover | **T5, T6** (inert until Plan B — see gate below) |
| 4 | Write reconciliation in `review_write_*` | **T4** — the load-bearing fix |
| 5 | Curation form three-zone picker | **T7** |
| 6 | Suggestion queue (cross-entity) | **deferred** — see below |
| 7 | Importer write helper + CI guard | **T9 (partial)** — the application-repo half |

### Honoring the §7.1 release gate without withholding the code

Spec §7.1 makes backfill coverage a release gate: absence of an assertion row means
curator-authored, so shipping public provenance reads while batches are un-backfilled would
*positively present* machine-derived annotations as curator-authored.

The gate's concern is a **positive claim**, not the presence of the code. This plan therefore
ships the read path and the UI with a hard **inertness property**:

> With zero assertion rows, `GET /api/entity/<id>/variation` returns `provenance: null` for
> every term, and the public Variation Ontology card renders **byte-identically to today** —
> no legend, no glyph, no affordance, no claim. The provenance affordance appears only when
> the entity has at least one assertion row.

So pre-backfill the public surface makes no claim at all, which is strictly safer than the
partial-coverage scenario §7.1 forbids. This property is locked by a test in T5 and T6, not
left to inspection. **Plan B is still required before provenance means anything**; that is a
deployment note, recorded in `documentation/09-deployment.qmd` (T9).

Phase 4 is **ungated and the highest-value piece**: with zero assertion rows it is a no-op, and
the moment Plan B lands it stops the silent promotion permanently. Every review saved without
it makes one more entity permanently ambiguous, so it ships now.

### Deferrals, stated

- **Phase 6 (cross-entity suggestion queue page + endpoint).** Its purpose is to make the
  1,981-item weak-evidence backlog tractable. That backlog does not exist until Plan B runs, so
  the page would ship with nothing to show and the endpoint would ship with no consumer (dead
  code). Deferred to a follow-up issue once Plan B has run. The **entity-scoped** suggestions
  read ships in T5 because T7's curation form consumes it.
- **Phase 7 enforcement items (1) and (3).** Item (1), the shared importer write helper under
  `scripts/data-corrections/_shared/`, has no home in this repo — `scripts/data-corrections/`
  does not exist here; it is administration-repo work. Item (3), a restricted DB account for
  importers, is an operator action tracked separately by the spec itself. The application-repo
  analogue of item (2) — a static guard that no new code writes the curated connect table
  outside the sanctioned review-write path — **does** ship, in T9.

## Global Constraints

Binding on every task. Copied from the spec and verified against this checkout.

1. **`ndd_review_variation_ontology_connect` is never altered, and never written outside the
   existing sanctioned path** (`variation_ontology_connect_to_review` /
   `variation_ontology_replace_for_review` in `api/functions/ontology-repository.R`). Provenance
   lives in its own tables because that table is `DELETE`d and re-`INSERT`ed wholesale on every
   review save (`ontology-repository.R:233-307`).
2. **The annotation identity is `(entity_id, vario_id, modifier_id)`.** Never key on
   `(entity_id, vario_id)` — `modifier_list` defines both `present` (1) and `absent` (5) as
   valid for variation, so those are two different claims with independent state.
3. **State correctness is enforced server-side.** Three independent frontend surfaces prefill
   and resubmit terms (`useEntityInfo.ts:171-176`, `useReviewForm.ts:272-275`,
   `useReviewApprovalActions.ts:104-106`). Never trust a client field to carry state; reconcile
   the previous assertion set against the submitted set.
4. **Provenance writes share the connect-table write's transaction.** Reconciliation runs inside
   `review_write_mutate()` on the same `txn_conn`, or provenance and curated membership are not
   atomic.
5. **Migrations** match `<NNN>_<short_description>.sql`, are idempotent and restore-drift safe,
   and are **forward-only** (no rollback tests). They auto-apply at API startup.
6. **FK-compatible types.** `vario_id VARCHAR(10)`, `ENGINE=InnoDB DEFAULT CHARSET=utf8mb3` —
   the referenced legacy tables (`variation_ontology_list`, `modifier_list`, `ndd_entity`,
   `user`) are all `utf8mb3`, and a string FK requires matching charset.
7. **New R files must be registered in `api/bootstrap/load_modules.R`.** Files are not
   autodiscovered. This covers both the API and the durable worker.
8. **Every endpoint file is mounted via `mount_endpoint()`** so the RFC 9457 error handler is
   attached; a bare `pr_mount` turns a 400 into an opaque 500.
9. **Frontend API access goes through typed clients in `app/src/api/*`.** No raw axios in
   views/components.
10. **Chips use the token-based `.sysndd-chip--<tone>` classes** in
    `app/src/assets/scss/partials/_chips.scss`, not a new per-component pastel palette
    (`documentation/10-visual-design-guide.md:219-225`).
11. **`BTable`/`GenericTable` cannot render a dotted field key**, and `v-b-tooltip` is reactive
    to its binding *value*, not a bound `:title`.
12. **Files stay under the 600-line soft ceiling.** `useReviewForm.ts` is already 493 lines and
    `EntityEvidenceGrid.vue` 352 — extract cohesive composables/components rather than growing
    them.
13. **`dplyr::select()` etc. are namespaced explicitly**, and `base::get()` is used explicitly
    where `get()` is needed (the `config` package masks `base::get` with a signature that has no
    `mode` argument).

## Tasks

Each task is TDD: failing test first, then implementation, then the test passes, then commit.

- **T1 — Migration 047: assertion + evidence tables.**
  `db/migrations/047_add_variation_ontology_provenance.sql`, manifest bump to
  `047_...`/`45L`, `test-unit-variation-provenance-migration.R`. The test must create the FK
  target tables it needs before applying (the test DB is a partial schema; `ensure_test_user_table()`
  exists for exactly this reason), and must assert: both tables exist; the migration text never
  mentions the connect table; `present`/`absent` are independent rows; the identity unique key
  rejects a duplicate; `chk_strength_range` rejects 5; `chk_confirmed_attribution` rejects a
  `confirmed` row with no `confirmed_by`.

- **T2 — Evidence strength normalizer.** `api/functions/variation-provenance-evidence.R` +
  registration + `test-unit-variation-provenance-evidence.R`. `normalize_evidence_strength()`
  returns `NA` rather than guessing on out-of-range, fractional, non-digit-string, or unknown
  source input. There is no `summarise_evidence()` — the summary is a stored column.

- **T3 — Provenance read repository.** `api/functions/variation-provenance-repository.R` +
  registration + `test-unit-variation-provenance-repository.R`. `provenance_for_entity()` (one
  row per evidence record, `evidence_json` excluded) and `attach_provenance()` (pure join on the
  full identity, `sources` ordered strength-desc then key-asc, `NULL` for curator-authored,
  never drops or reorders terms).

- **T4 — Write reconciliation (highest risk).** Assertion write repository +
  `provenance_action` carried through `review_write_normalize_ontology()` +
  `review_write_reconcile_provenance()` called from `review_write_mutate()` on `txn_conn`.
  Reconciliation table from spec §5.3: submitted + `active_unconfirmed` + no action → **stays
  `active_unconfirmed`** (the whole fix); submitted with `provenance_action: "confirm"` →
  `confirmed` + `confirmed_by` + `confirmed_at`; omitted and previously `active_unconfirmed` or
  `suggested` → `rejected`; submitted with no assertion row → no row created. Tests: the
  regression test for the original bug (save with no action leaves state unchanged); a client
  that sends no provenance fields still transitions an omitted term to `rejected`; provenance
  and connect-table writes roll back together under forced failure.

- **T5 — Read API.** `provenance` on `GET /api/entity/<id>/variation`; evidence detail route;
  entity-scoped suggestions route. Includes the **inertness test**: with zero assertion rows the
  response is identical to the pre-change response.

- **T6 — Public frontend.** Provenance state on the Variation Ontology card + lazily-fetched,
  keyboard-reachable, labelled evidence dialog. Quiet by default; state carried in text, never
  by glyph or color alone. Inert with no assertions.

- **T7 — Curation frontend.** Three-zone picker (Confirmed / Needs confirmation / Suggested)
  with the modifier shown per card, inline evidence, and `provenance_action` on submit. Extract
  a composable so `useReviewForm.ts` stays under the ceiling.

- **T8 — E2E + design.** Seed provenance fixtures into `db/fixtures/playwright_e2e_baseline.sql`
  so the specs and the design review have real data; Playwright monkey-testing specs for the
  public card and the curation form; a11y assertions; design review against
  `documentation/10-visual-design-guide.md`.

- **T9 — Guard + docs + release.** Static guard that no new code writes the curated connect
  table outside the sanctioned path; `AGENTS.md`, `documentation/08-development.qmd`,
  `documentation/09-deployment.qmd` (including the Plan B deployment note), `CHANGELOG.md`, and
  the four-surface version bump.

## Verification

`make code-quality-audit`, `make lint-api`, `make lint-app`, `cd app && npm run type-check`,
`cd app && npm run test:unit`, `make test-api-fast`, then the full `make ci-local`. Playwright
locally via `make playwright-stack` at `--workers=1` (known-good baseline: 0 failures, 3
env-gated skips).
