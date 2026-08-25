# Variation-ontology provenance — remaining application-repo work (#612)

Date: 2026-08-25
Issue: https://github.com/berntpopp/sysndd/issues/612
Predecessor: `.planning/superpowers/specs/2026-07-30-variation-ontology-provenance-608-design.md`
Adversarial review: Codex `gpt-5.6-terra`, 13 findings, all folded in (see §8).

## 0. What is already true

#608 shipped the assertion + evidence tables (migration `047`), the read surface, server-side
write reconciliation, rename carry-forward, the public entity card, and the three-zone curation
picker. #616 added the evidence import date. #638 closed the migration-test and rename-coverage
gaps and fixed two production defects found by actually running the integration file.

**External operational facts** (not verifiable from this repository; captured reproducibly, see
§3.1): the backfill ran on 2026-08-05 (`sysndd-administration`, admin#16, script
`005-variation-provenance-backfill`) writing 8,083 assertion + evidence rows across three February
batches with `source_version` NULL. Provenance is live in production and is no longer inert.

The load-bearing invariant is unchanged and governs everything below:

> **Absence of an assertion row means curator-authored.**
> Identity is `(entity_id, vario_id, modifier_id)` — never `(entity_id, vario_id)`.
> `ndd_review_variation_ontology_connect` is written only by `functions/ontology-repository.R`.
> Correctness is server-side; a client-sent field is never trusted.

## 1. Two findings that change the plan

### 1.1 A queue over `state = 'suggested'` would render an empty page

`provenance_builder.py:186` (administration repo) writes `"state": "active_unconfirmed"` for every
record; the 28 `removed` annotations were deliberately skipped rather than written `rejected`.
Production therefore holds **zero** `suggested` rows.

The existing entity-scoped route filters `a.state = 'suggested'`
(`entity-variation-provenance-service.R:444`), which is correct for what it serves — candidate
terms that are *not* in the curated set. But the #608 design spec's §6.4 cross-entity queue was
written before the backfill's state choice was settled and reads the same state, so it would show
nothing.

The ~1,981-item backlog the queue exists to make tractable is the ClinVar 1-star subset (#608 spec
§1, §3): assertions that are **served today** and have **never been confirmed** — i.e.
`active_unconfirmed`. The queue is therefore over `state IN ('suggested','active_unconfirmed')`,
with `state` as a facet.

### 1.2 "Dismiss" on a served term would fabricate curator authorship

`provenance_for_entity()` filters to `state %in% c("active_unconfirmed","confirmed")`
(`functions/variation-provenance-repository.R:29`). Writing `rejected` onto an
`active_unconfirmed` assertion drops it out of that filter, `attach_provenance()` yields NULL for
the unmatched term (`:187`), `svc_variation_attach_provenance()` preserves the NULL
(`entity-variation-provenance-service.R:315`), and the public read reaches that path
(`entity-read-endpoint-service.R:342`). The card then renders `provenance: null` —
**curator-authored** — while the term is still in the connect rows and still served.

So an assertion-only `rejected` write is safe **only** for an assertion that is not part of the
served set. This is the same principle the write path already encodes as
`review_write_save_determines_served_set()`.

| Assertion state | Served? | Safe assertion-only action from a queue |
|---|---|---|
| `active_unconfirmed` | yes | **Confirm** |
| `suggested` | no | **Dismiss** |

`Confirm` on a `suggested` row would have to ADD the term to the curated set; `Dismiss` on an
`active_unconfirmed` row would have to REMOVE it. Both are review writes and must go through
`review_write_mutate()`. The queue links out to the entity for those; it never writes the connect
table.

## 2. Scope

1. **`evidence_json` contract + rendering** — pin the three record shapes the backfill emits and
   render all three.
2. **Approval-path rejection hook** — reconcile rejections when a review is approved, not only
   when it is written.
3. **Phase 6** — the cross-entity suggestion queue, plus the three-zone picker on the two
   curation surfaces that still lack it.

Out of scope, unchanged: Phase 7 item 1 (shared importer write helper — administration repo) and
item 3 (restricted importer DB grant — operator action).

## 3. Item 1 — `evidence_json` contract and rendering

### 3.1 The contract, as it actually is

Derived from `provenance_builder.py` and captured from live production
(`GET /api/entity/<id>/variation/<vario_id>/<modifier_id>/evidence`, public and DB-only). The
captured payloads are committed as the fixture in §3.3, so the evidence is reproducible in-repo
rather than a claim about a system this repository cannot see.

| Batch | `source_key` | `source_type` | Containers | Record keys |
|---|---|---|---|---|
| `clinvar-2026-02` (5,763) | `clinvar` | `external_database` | `records`, `matched` | `id`, `classification`, `stars`, `consequence`, `url` |
| `extdb2-2026-02` (2,166) | `extdb2` | `external_database` | `records` | `confidence`, `mechanism`, `categorisation`, `consequence`, `support`, `disease`, `allelic_requirement`, `layer` |
| `synopsis-2026-02` (182) | `synopsis` | `literature` | `records` | `matched_text`, `negated`, `pattern`, `context` |

Captured specimens: entity 2097 `VariO:0015` (ClinVar, 10 records, `matched` present), entity 2900
`VariO:0039` (extdb2 with all eight keys including `categorisation`), entity 991 `VariO:0043`
(synopsis, two records — one negated, one not).

Four properties of the writer the reader must honour:

* **Optional keys are DROPPED, not written null.** `_clean()` returns `None` for an empty field
  and the external/synopsis builders assign a key only when the value is non-empty. A record
  legitimately carries a subset of its shape's keys; an absent key means "not recorded". Only
  `matched_text` and `negated` are guaranteed on a synopsis record; `id`/`classification`/`stars`/
  `consequence`/`url` are always assigned on a ClinVar record (`classification` may be `""`,
  `stars` and `consequence` may be `null`); an extdb2 record has no guaranteed key beyond being
  non-empty.
* **`matched` holds STRINGS, not records.** `build_clinvar_evidence` collects OMIM CURIEs; the
  captured payload is `"matched": [["OMIM:251280"]]` (each string plumber-wrapped). The existing
  `normalizeMatched()` (`variationProvenance.ts:303`) already handles that correctly. It must stay
  a separate text list and must never be folded into the record-container probe — `String(object)`
  on a record would render `"[object Object]"`.
* **`negated` is a BOOLEAN**, and it is the only field whose *false* value is meaningful. It
  reaches the client as `[false]`; today's `asText()` would render that as the string `"false"`.
* **Container keys already agree** with `RECORD_LIST_KEYS[0]` / `MATCHED_KEYS[0]`
  (`variationProvenance.ts:242,246`). The mismatch is **per record**, not per payload, and it is
  silent by design.

### 3.2 Today's behaviour

`normalizeRecordRows()` probes one shape and filters out any row carrying none of
`VARIATION_ID_KEYS` / `CONSEQUENCE_KEYS` / `CLASSIFICATION_KEYS`.

* ClinVar → id + classification + consequence. `stars` is in the payload and **never displayed**,
  even though the summary line ("max 2 stars") refers to it.
* extdb2 → `consequence` only. mechanism, confidence, categorisation, support, disease, allelic
  requirement and layer are all dropped.
* synopsis → **nothing**. Every row is filtered out, so the dialog shows a summary line above an
  empty body.

### 3.3 The fixture

`api/tests/testthat/fixtures/variation-evidence-record-shapes.json`, following the
`clinvar-significance-vocabulary.json` pattern: one file, both suites, two-direction assertions.

```
{ "shapes": {
    "<shape>": { "source_key", "source_type",
                 "container_keys":        [...],
                 "record_keys":           [...],   # every key the shape may carry
                 "required_record_keys":  [...],   # keys always present
                 "matched_item_type": "string" | null,
                 "sample": { ...verbatim captured payload, already plumber-wrapped... } } } }
```

**TS assertions** (`variationProvenance.spec.ts`): per shape, the key set the normalizer
understands equals `record_keys` in **both** directions; each `sample` normalizes to a non-empty
record list of the expected `kind`; `matched` normalizes to strings for the ClinVar shape.

**R assertions** (`test-unit-variation-evidence-record-shapes.R`): R owns the wire shape the TS
normalizer is written against. Each `sample` is stored as it would be in the `evidence_json`
column, read back through `.svc_vp_parse_json()` (`simplifyVector = FALSE`) and
`.svc_vp_evidence_records()`, and the test asserts the resulting container and per-record key sets
equal the fixture's in both directions. A second assertion re-serializes with
`jsonlite::toJSON(auto_unbox = FALSE, na = "string", null = "null")` — the argument set the route
declares via `#* @serializer json list(na="string", null="null")` (`entity_endpoints.R:261`) — and
asserts a boolean `false` survives as `[false]` rather than being dropped or stringified. The test
says explicitly that it replicates plumber's serializer arguments rather than invoking the route.

### 3.4 Rendering

`normalizeRecordRows()` becomes shape-dispatched on `source_key`/`source_type`, returning a
discriminated union. The dispatch **falls back to the existing generic probe** for an unrecognised
source, so a future batch degrades to today's behaviour rather than to nothing.

```ts
type NormalizedEvidenceRecord =
  | { kind: 'clinvar';    variationId, classification, stars, consequence, url }
  | { kind: 'external';   fields: Array<{ label: string; value: string }> }
  | { kind: 'literature'; matchedText, negated: boolean | null, pattern, context }
  | { kind: 'generic';    variationId, consequence, classification, url }   // today's shape
```

* **ClinVar** — unchanged plus `stars`, rendered through the existing `strengthDisplay()` scale
  (0–4; `null` → "Not recorded", never zero stars for an unrecorded value).
* **External database** — a labelled field list in a fixed display order (`confidence`,
  `mechanism`, `categorisation`, `consequence`, `allelic_requirement`, `support`, `disease`,
  `layer`), each entry omitted when its key is absent. Labels come from a static map; an unknown
  key is rendered with its raw key as the label rather than dropped, because dropping is what
  caused this bug.
* **Literature (synopsis)** — matched text in quotes, sentence context, match pattern in small
  monospace, and a prominent **"negated context"** badge when `negated` is true. The badge is not
  decoration: a negated match is evidence *against* the term, which is why the builder scores it
  `strength = 1`. Rendering it indistinguishably from a positive match would overstate the machine
  evidence.
* A record carrying **no** renderable field is still dropped — the existing rule, now evaluated
  per shape.

`asBoolean()` joins `asText()`/`asStrength()`: unwrap the plumber array, accept only a real
boolean or the exact strings `"true"`/`"false"`, otherwise `null`. `null` renders as "not
recorded", never as "not negated".

### 3.5 Cross-repo agreement

`provenance_builder.py`'s header pins `records`/`matched` per admin#16. This spec pins the
per-record key names on this side. The fixture is the artifact both repos point at: a key rename
in the builder without a paired change here now fails a test instead of silently blanking a
section.

## 4. Item 2 — approval-path rejection hook

### 4.1 The gap

`variation_provenance_reconcile_for_review()` runs inside `review_write_mutate()` with its
rejection edges gated on `review_write_save_determines_served_set()`. A curator who removes a term
in a draft (`review_approved = 0`) and approves it later leaves the assertion
`active_unconfirmed`: the term stops being served, which is the safe direction, but the
suggestion-suppression signal is lost and the §5 queue keeps offering it.

`review_update()` unconditionally sets `review_approved = 0`
(`functions/review-repository.R:258-263`), so on a normal PUT the served-set branch never fires
and `direct_approval` is the only operative path today. Edit-then-approve-separately is the
ordinary Reviewer workflow, not an edge case.

### 4.2 The hook

**Principle, unchanged from the write path:** approval is when the served set becomes real.

* `variation_provenance_plan_reconciliation()` gains `apply_confirmations = TRUE`, symmetric with
  the existing `apply_rejections`, gating only the submitted branch (rows 1–5). Confirmation
  behaviour at every existing call site is unchanged, and a `confirmed` row is still never
  re-stamped because the `to_state != from_state` filter already drops it.
* `variation_provenance_reconcile_for_review()` passes the flag through, staying a pure
  passthrough.
* New `variation_provenance_served_terms_for_entity(entity_id, conn)` reads the entity's served
  term set — `ndd_review_variation_ontology_connect` where `is_active = 1` and the review is
  `is_primary = 1 AND review_approved = 1` — the same rule as `svc_entity_variation()`
  (`entity-read-endpoint-service.R:306-317`). Migrations `051`–`053` enforce `(review_id,
  entity_id)` agreement, so joining the connect row to its review by `review_id` alone is sound.
* New `variation_provenance_reconcile_on_approval(entity_id, review_user_id, conn)` reads that set
  and calls the planner with `apply_confirmations = FALSE, apply_rejections = TRUE`.

  Deriving `submitted` from the served set rather than from the approved review's own rows is what
  makes this correct when one approval covers several reviews of one entity: the question the hook
  answers is "what does this entity serve now", the same question the public read answers.

* `svc_approval_review_approve()` runs `review_approve()` and the per-entity reconciliation in
  **one** transaction, so a reconciliation failure rolls the approval back. It runs only when
  `approve = TRUE`; unapproving does not determine a served set.

**The served set is read AFTER `review_approve()`, and an empty set is meaningful.** Approval
itself creates the primary approved review (`review-repository.R:352,368`), so an entity with no
prior primary review legitimately ends with an empty served set when the approved review carries
no variation terms — and every assertion for it must then be rejected. There is deliberately **no
"skip when the served set is empty" guard**; such a guard would leave exactly the abandoned
assertions the queue exists to retire.

**Transaction mechanics.** `review_approve()` already skips its own transaction when handed a
`conn` (`review-repository.R:410`). The service must NOT wrap itself in a plain
`db_with_transaction()`, because that calls `DBI::dbWithTransaction()` even for a caller-owned
direct connection (`db-helpers.R:416`) and `with_test_db_transaction()` has already issued
`DBI::dbBegin()` (`helper-db.R:288`). It mirrors `review_write_run_mutation()`'s branch
(`review-write-service.R:532`): pool → `db_with_transaction`; direct `DBIConnection` → an explicit
`SAVEPOINT` / `RELEASE` / `ROLLBACK TO`.

**`"all"` detection is length-safe.** `if (as.character(review_id) == "all")`
(`approval-service.R:48`) errors with "the condition has length > 1" for a vector, so the
function's documented multi-id support has never worked. It becomes
`length(review_id) == 1L && identical(as.character(review_id), "all")`, and vectors then reach
`review_approve()` as documented. This is a prerequisite of the per-entity loop, not scope creep.

**Direct approval stays out of this hook, deliberately.** `review_write_mutate()` calls
`review_approve()` directly on its own transaction (`review-write-service.R:525`) after having
already reconciled with `apply_rejections = TRUE` in the same transaction (`:511`).
`review_apply_direct_approval()` has no call site. So the hook neither double-runs nor is needed
there. `svc_approval_review_approve()` has exactly one live caller,
`PUT /api/review/approve/<review_id_requested>` (`review_endpoints.R:481`).

### 4.3 What this deliberately does not do

It confirms nothing. Approving a review is an act on the review, not a per-term reading of machine
evidence; promoting `active_unconfirmed` → `confirmed` on approval would restore exactly the
silent promotion #608 exists to stop. Confirmation remains an explicit act, on the review form or
in the queue.

## 5. Item 3 — Phase 6: cross-entity suggestion queue

### 5.1 Read endpoint

`GET /api/curate/variation/suggestions` — Curator-gated, DB-only, one query per request.
New endpoint file `api/endpoints/curate_variation_endpoints.R`, mounted at `/api/curate/variation`
through `mount_endpoint()` (which attaches the RFC 9457 error handler and the 404 handler). The
endpoint is thin: role gate, parameter forwarding, response status. All query construction lives
in `api/services/curate-variation-suggestion-service.R`, registered in
`api/bootstrap/load_modules.R` after the provenance modules.

A new `/api/curate` prefix is introduced rather than extending `/api/review`, because this is
entity-scoped curation triage, not review CRUD, and the #608 spec named the page
`/curate/variation-suggestions`.

**Query parameters** (all optional): `state` (`active_unconfirmed` | `suggested`), `source_key`,
`max_strength` (exact 0–4), `moved` (`true` restricts to laundered rows), `q` (gene symbol or
entity id), `sort` (`strength_desc` default, `strength_asc`, `entity_asc`), `page` (1-based),
`page_size` (default 25, capped 100). Every value is validated against a closed allowlist before
it reaches SQL, and every value is bound, never interpolated.

**Row shape** — one object per assertion:

```
{ entity_id, symbol, disease_ontology_name, vario_id, vario_name, modifier_id,
  state, served, moved, max_strength,
  evidence: [ { source_type, source_key, batch_id, strength, summary } ] }
```

`evidence_json` is deliberately not in the list payload. A page is ≤ 100 assertions; full records
stay one click away on the entity, which is where the decision needing them is made.

**`served`** is `EXISTS (an active connect row for this identity whose review is primary and
approved)`.

**`moved`** is defined exactly as: *the assertion has at least one evidence row whose
`origin_review_id` is non-null and is not currently a primary-approved review of that entity.*
Because `origin_review_id` deliberately carries no foreign key (migration `049`), a vanished
origin review also reads as moved, which is correct. Nothing more is claimed: with two
primary-approved reviews including the origin, `moved` is false, and that is the intended reading
— the import's review still serves. This is the first consumer of the column (95 rows in
production).

Entities are resolved through `ndd_entity_view`, so a non-public entity can never appear.

### 5.2 Write endpoints

Both Curator-gated, both assertion-only. Neither touches
`ndd_review_variation_ontology_connect`.

* `POST /api/curate/variation/suggestions/confirm` — body `{ items: [{entity_id, vario_id,
  modifier_id}, ...] }`, capped at 100. Per item the server requires state
  `active_unconfirmed` **and** served.
* `POST /api/curate/variation/suggestions/dismiss` — same shape and cap. Per item the server
  requires state `suggested` **and** not served. Dormant today; correct when `suggested` rows
  appear.

Both return `{ requested, applied, skipped: [{entity_id, vario_id, modifier_id, reason}] }`. A
skipped item is reported, never silently dropped: a silent partial success on a provenance surface
is the failure mode this feature exists to avoid.

**Concurrency (the P0).** The served/state gates are re-derived on the server, but a plain
read-then-write leaves a window: a dismiss could read `suggested + not served` while a concurrent
review write adds and approves that term, and then commit `rejected` onto a now-served
assertion — producing exactly the `provenance: null` fabrication of §1.2. Each batch therefore
runs in one transaction that:

1. `SELECT ... FOR UPDATE` the targeted `variation_ontology_assertion` rows, ordered by
   `assertion_id` so concurrent batches cannot deadlock on each other;
2. re-reads served membership **while holding those row locks**;
3. writes with a **state-conditional** `UPDATE ... WHERE assertion_id = ? AND state = ?`, and
   treats a 0-row result as `skipped` with reason `state_changed`.

This serializes against `review_write_mutate()`, whose reconciliation updates the very same
assertion row for any term it adds or removes, so one transaction blocks the other and the loser
observes the winner's state. The transaction uses the same pool/direct-connection branch as §4.2.

State transitions are planned by `variation_provenance_plan_reconciliation()` — the queue and the
review form share one state machine — with `apply_rejections = FALSE` on confirm and
`apply_confirmations = FALSE` on dismiss, so neither endpoint can plan the other's edge.

The client's row state is a hint for rendering, never an input to the decision.

### 5.3 Page

`/curate/variation-suggestions`, Curator + Administrator, navbar entry under Curate
("Variation suggestions"). `views/curate/VariationSuggestions.vue` (shell) +
`composables/useVariationSuggestions.ts` (state, filters, paging, bulk selection) +
`components/VariationSuggestionsTable.vue` + a mobile-row component, following the existing
curate-page decomposition and `documentation/10-visual-design-guide.md`.

Row actions are exactly the safe ones from §1.2 — Confirm for a served `active_unconfirmed`,
Dismiss for a `suggested` — plus "Open entity" always. Multi-select drives bulk Confirm/Dismiss
over the selected rows of a single kind. `moved` is surfaced as both badge and filter, because
those 95 rows are where a curator review already displaced the import.

Typed client `app/src/api/curate_variation.ts`; no raw axios in the view.

### 5.4 Zone UI on the two remaining surfaces

The zone block currently lives inline in `views/curate/components/ReviewFormFields.vue`, whose only
consumer is `views/review/components/ReviewEditModal.vue`. Three other surfaces prefill and
resubmit variation terms with no deliberate-act affordance:

| Surface | Picker host | Submit path |
|---|---|---|
| ModifyEntity (inline) | `components/InlineEntityWorkflow.vue` | `useEntityMutations.ts:127` |
| ModifyEntity (combined) | `components/CombinedStatusReviewWorkflow.vue` | same |
| ApproveReview | `components/review/ReviewEditForm.vue` | `useReviewApprovalActions.ts:234` |

The zone block is extracted verbatim into `views/curate/components/VariationProvenanceZones.vue`
and mounted at all four points.

**State plumbing, in full.** `useVariationProvenanceZones()` requires **two** writable refs
(`useVariationProvenanceZones.ts:115`): `selectedTags` and `confirmedTags`. Binding only the
existing `select_variation` is not enough — each surface must also own a `confirmedTags` ref,
reset it when the entity/review selection changes, and thread `provenanceActionFor(tag)` into the
**third** argument of `new Variation(...)` on its submit path. The class already accepts it
(`submissionVariation.js:23`); the state is what is missing.

* ModifyEntity: the zones instance lives in `useModifyEntityWorkflows`, so `ModifyEntity.vue` only
  forwards a prop to its two workflow components. `confirmedTags` resets in `useEntityInfo.reset()`
  and after a successful review submit.
* ApproveReview: the zones instance lives in `useApproveReviewController`, loaded when the review
  modal opens and reset on `onReviewModalHide`.

**File-size budget.** `ModifyEntity.vue` is at 599 lines, so *any* addition trips the ratchet;
extracting from `ReviewFormFields.vue` cannot help it. Its 209-line `<style scoped>` block moves to
`./ModifyEntity.styles.css` via `<style scoped src="...">`, which is already used in this repo
(`components/nddscore/NddScoreGeneTable.vue:439`) and preserves scoping. That leaves ~390 lines
with ample headroom.

This is a **UX** change. It adds no correctness: reconciliation is server-side and these surfaces
are already protected. The value is that a curator on ModifyEntity sees "2 terms need
confirmation" instead of two silently pre-checked boxes.

## 6. Testing

Deterministic checks, red-tested where a test could otherwise pass while proving nothing.

**R**
* `test-unit-variation-evidence-record-shapes.R` — the fixture contract (§3.3).
* `test-unit-variation-provenance-reconcile.R` — extended for `apply_confirmations = FALSE`:
  rejections still fire, confirmations do not, a `confirmed` row is not re-stamped.
* `test-unit-approval-service-provenance.R` — the hook rejects an omitted term, leaves a served
  term alone, does nothing on `approve = FALSE`, reconciles when the post-approval served set is
  **empty**, and handles a vector `review_id` (the `"all"` length fix).
* `test-unit-curate-variation-suggestions.R` — parameter validation and allowlists; the `served`
  and `moved` derivations; the two refusals (`confirm` on a `suggested` row, `dismiss` on a served
  row); `skipped` reporting; and that the SQL text carries `FOR UPDATE` and a state-conditional
  `WHERE`.
* `test-integration-variation-suggestions.R` — against a real schema-loaded MySQL: the queue query
  over seeded assertions, a confirm round-trip, and a dismiss refused on a served term.
* Existing static guards stay green unchanged — in particular
  `test-unit-variation-connect-write-guard.R` and `test-unit-endpoint-error-handler.R` (the new
  endpoint file must be mounted through `mount_endpoint()`).

  Scope note: that write guard scans `api/functions`, `api/services` and `api/endpoints` only — it
  deliberately excludes `scripts/`, `db/` and tests. It is sufficient to protect the new
  request-path code, which is what is claimed here; it is not a repo-wide proof.

**Frontend**
* `variationProvenance.spec.ts` — the fixture contract and all three renderers, including the
  boolean-`false` unwrap and `matched`-as-strings.
* `VariationProvenanceDialog.spec.ts` — a synopsis payload renders a negated badge and context; an
  extdb2 payload renders mechanism and confidence; a ClinVar payload renders stars.
* `EntityEvidenceGridProvenance.spec.ts` — the golden-HTML inertness assertion unchanged.
* `VariationProvenanceZones.spec.ts` plus per-surface specs asserting `provenance_action` reaches
  the submitted payload from ModifyEntity and ApproveReview.
* `useVariationSuggestions.spec.ts` and a shell spec for the page; a routes spec for the new
  Curator-gated route.

**Verification before handoff** — `make code-quality-audit`, `make test-api-fast`, `make lint-api`,
`npm run type-check`, `npm run test:unit`, and the integration files actually **run** against a
throwaway `mysql:8.4.11` with all 51 migrations applied (CI provisions an empty MySQL, so an
unrun integration file proves nothing; #638 found two production defects this way).

## 7. Risks

* **A queue write reaching the wrong state.** Mitigated by locking reads, state-conditional
  updates, server-side re-derivation, one shared planner, and the two explicit refusal tests.
* **Transaction scope on approval.** Wrapping `review_approve()` changes a shared path with one
  live caller. Existing approval tests must pass unchanged, and the savepoint branch must nest
  correctly under `with_test_db_transaction()`.
* **The approval hook rejecting broadly.** By design an empty post-approval served set rejects
  every assertion for that entity. That is correct — the entity serves no variation terms — but it
  is the highest-consequence behaviour here and is asserted directly.
* **File-size ratchet.** `ModifyEntity.vue` (599), `InlineEntityWorkflow.vue` (546) and
  `ReviewFormFields.vue` (498) are all close to the ceiling. `make code-quality-audit` is the gate.

## 8. Review disposition

Codex `gpt-5.6-terra` adversarial review, 2026-08-25. All findings accepted and folded in:
P0 race → §5.2 locking; P1 empty-served-set guard → §4.2; P1 transaction nesting → §4.2; P1 `"all"`
length bug → §4.2; P1 direct-approval path → §4.2; P1 `moved` definition → §5.1; P1 `confirmedTags`
plumbing → §5.4; P1 `matched` container → §3.1; P2 serializer wording → §3.3; P2 `ModifyEntity.vue`
budget → §5.4; P2 service module + loader → §5.1; P2 guard scope → §6; P3 external evidence → §0,
§3.1. Findings 14–16 confirmed the read-path conclusion, the `suggested` filter, and the
route-order / `mount_endpoint()` requirements.
