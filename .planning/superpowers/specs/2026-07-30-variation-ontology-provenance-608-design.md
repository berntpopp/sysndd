## Context

An audit of the February 2026 VariO enrichment imports found two distinct problems:

1. **8,111 variation-ontology annotations were written directly into the curated table** (`ndd_review_variation_ontology_connect`) by automated scripts, with no marker distinguishing them from curator-authored terms.
2. **Machine-derived terms are silently promoted to curator-authored on every re-review.** The curation forms prefill their term picker from the entity's existing terms (`app/src/views/curate/composables/useEntityInfo.ts:171-176`, and independently `useReviewForm.ts:251-274`). A curator editing one sentence of synopsis re-saves every pre-checked term onto a new, curator-attributed review. No user action distinguishes "I read the papers and agree" from "I did not notice the checkbox."

Concrete case: entity 2097 (PCDH12) asserts `VariO:0017` *nonsynonymous variation* — a missense mechanism — on the strength of exactly two ClinVar records, both Likely pathogenic at **1 star, single submitter**. The gene's established mechanism is truncating-only; supporting missense evidence first appeared in a preprint five months after the import. On 2026-07-29 that term was carried into a fresh curator review.

Of the ClinVar batch, **1,981 of 5,763 annotations (34.4%)** rest on 1-star evidence alone, 1,139 of them on a single variant.

The design below has been externally reviewed (`gpt-5.6-sol`, high reasoning) against this codebase; this is revision 2, incorporating that review. The implementation plan for **this repo** is in the first comment. The companion backfill plan lives in the administration repo.

**Related:** #607 (frontend ClinVar classification bug — separate defect, same audit).

---

# Variation Ontology Provenance & Curator Suggestions — Design

**Status:** Draft for review — revision 2
**Date:** 2026-07-30
**Scope:** SysNDD application repo (`berntpopp/sysndd`) — DB migration, API, curation UI, public UI
**Spec home:** this repo (`sysndd-administration`), deliberately kept out of the application repo until approved

**Revision 2** incorporates an external review (`2026-07-30-provenance-codex-review.md`). Changes from
revision 1: the identity key now includes `modifier_id`; assertion state and evidence are split into two
tables; the write path targets the service that is actually called; backfill coverage becomes a release
gate; stored evidence is limited to what the manifests genuinely contain.

---

## 1. Problem

SysNDD presents itself as an expert-curated resource. Today, a curated-looking variation-ontology
annotation can have three very different origins, and nothing in the schema, the API or the UI
distinguishes them:

1. A curator asserted it from literature they read.
2. A machine-derived batch inserted it from an external database.
3. A machine-derived annotation was inserted once, then **silently promoted to curator-authored**
   on the next review edit.

Mechanism for (3): the curation forms prefill their term picker from the entity's current terms
(`app/src/views/curate/composables/useEntityInfo.ts:171-176`, and independently
`app/src/views/curate/composables/useReviewForm.ts:251-274`). A curator opening an entity to change
one sentence of synopsis gets every existing term pre-checked. Saving rewrites all of them onto the
new review. No user action distinguishes "I read the papers and agree" from "I did not notice the
pre-checked box."

Worked example — entity 2097 (PCDH12, Diencephalic-mesencephalic junction dysplasia syndrome 1):

| Term | Name | Origin |
|---|---|---|
| VariO:0001 | variation | pre-existing |
| VariO:0015 | protein truncation | external-database import, 2026-02-15 |
| VariO:0017 | nonsynonymous variation | external-database import, 2026-02-15 |
| VariO:0031 | out-of-frame indel | external-database import, 2026-02-15 |
| VariO:0043 | protein loss of function | external-database import, 2026-02-15 |

`VariO:0017` rests on exactly two ClinVar records (VCV1343191, VCV1804020), both *Likely pathogenic*,
both **1-star, single submitter**. The gene's established mechanism is truncating-only; supporting
missense evidence first appeared in a preprint five months after the import. The claim was live and
indistinguishable from curated content for that entire period.

Scale of the affected set:

| Measure | Count |
|---|---|
| Annotations inserted by the Feb 2026 import batches | 8,111 |
| Of the ClinVar batch, resting on 1-star evidence only | 1,981 (34.4%) |
| Of those, supported by exactly one variant | 1,139 |
| Missense (`VariO:0017`) resting on 1-star only | 224 |
| Sampled imported annotations still present, unmodified | 157 / 157 |
| Sampled entities re-reviewed since the import | 0 / 60 |

The last two rows matter for sequencing: the imported rows are still **identifiable today**, and the
laundering has barely begun. Every future re-review makes one more entity permanently ambiguous.

## 2. Goals and non-goals

**Goals**

- Every variation-ontology annotation carries a truthful, queryable statement of where it came from.
- Machine-derived annotations can never again become curator-authored without an explicit act.
- Curators see the actual evidence at the moment of decision, not a bare source label.
- Machine-derived candidates reach curators as **suggestions** rather than as silent writes.
- Provenance is visible to the public, so a reader can tell confirmed from unconfirmed.

**Non-goals**

- No retroactive deletion or deactivation. All 8,111 existing annotations stay visible; they are
  marked, not removed.
- No change to the ontology vocabulary itself.
- Not a general audit-log for the whole database. Scope is variation ontology.
- Does not fix the separate frontend ClinVar classification bug (application repo issue #607).

## 3. Constraints that shape the architecture

### 3.1 The curated table is rewritten on every save

`variation_ontology_replace_for_review()` (`api/functions/ontology-repository.R:264-290`) handles every
review edit as `DELETE FROM ndd_review_variation_ontology_connect WHERE review_id = ?` followed by
re-`INSERT` of each submitted term. **A provenance column on that table would be destroyed on every
review save.** Provenance must live in its own table.

### 3.2 The annotation's identity includes the modifier

`ndd_review_variation_ontology_connect` is unique on
`(review_id, vario_id, modifier_id, entity_id, is_active)`
(`db/migrations/000_initialize_base_schema.sql:413-425`). `modifier_list` defines both `present` (1)
and `absent` (5) as valid for variation (`:486-493`), and the curation UI stores selections as
`"modifier_id-vario_id"` (`useEntityInfo.ts:171-176`).

`(entity_id, vario_id)` is therefore **not** an identity — it conflates "missense is present" with
"missense is absent". The stable identity is `(entity_id, vario_id, modifier_id)`.

### 3.3 The live write path is not the obvious one

`PUT/POST /api/review` calls `svc_review_write()` (`api/endpoints/review_endpoints.R:244-253`), whose
transactional mutation calls the ontology repository directly
(`api/services/review-write-service.R:195-232`). `svc_review_add_variation_ontology()` in
`review-service.R:279-310` is **bypassed**. Its normalizer also reduces each submitted term to
`(vario_id, modifier_id)` (`review-write-service.R:93-97`), so any extra field would be silently
dropped before mutation.

Provenance reconciliation must therefore land inside `review_write_prepare()` / `review_write_mutate()`,
on the **same `txn_conn`** as the connect-table write, or provenance and curated membership will not be
atomic.

### 3.4 More than one curation surface prefills

`useEntityInfo.ts` is not alone; `useReviewForm.ts:251-274` and `useReviewApprovalActions.ts:98-119`
also load, prefill and resubmit terms. A design that depends on one new UI to send the right signal
will leave the other surfaces laundering. **State correctness must be enforced server-side** by
reconciling the previous assertion set against the submitted set, not by trusting a client field.

## 4. Data model

Two tables: one **assertion** row per annotation identity, and one or more **evidence** rows attached
to it. Revision 1 conflated these, which made the public contract ambiguous whenever a term had two
sources.

### 4.1 `variation_ontology_assertion`

```sql
CREATE TABLE variation_ontology_assertion (
  assertion_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  entity_id       INT NOT NULL,
  vario_id        VARCHAR(10) NOT NULL,
  modifier_id     INT NOT NULL,
  state           ENUM('suggested','active_unconfirmed','confirmed','rejected') NOT NULL,
  confirmed_by    INT NULL,
  confirmed_at    DATETIME NULL,
  rejected_reason VARCHAR(255) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (assertion_id),
  UNIQUE KEY uq_assertion (entity_id, vario_id, modifier_id),
  KEY idx_state (state),
  CONSTRAINT chk_confirmed_attribution
    CHECK (state <> 'confirmed' OR (confirmed_by IS NOT NULL AND confirmed_at IS NOT NULL)),
  CONSTRAINT fk_assertion_entity   FOREIGN KEY (entity_id)   REFERENCES ndd_entity (entity_id),
  CONSTRAINT fk_assertion_vario    FOREIGN KEY (vario_id)    REFERENCES variation_ontology_list (vario_id),
  CONSTRAINT fk_assertion_modifier FOREIGN KEY (modifier_id) REFERENCES modifier_list (modifier_id),
  CONSTRAINT fk_assertion_user     FOREIGN KEY (confirmed_by) REFERENCES user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
```

Types and charset match the referenced legacy tables exactly (`vario_id VARCHAR(10)`, `utf8mb3`), which
is what makes the foreign keys possible at all.

### 4.2 `variation_ontology_evidence`

```sql
CREATE TABLE variation_ontology_evidence (
  evidence_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  assertion_id      INT UNSIGNED NOT NULL,
  source_type       ENUM('literature','external_database') NOT NULL,
  source_key        VARCHAR(64) NOT NULL,
  batch_id          VARCHAR(64) NOT NULL,
  source_version    VARCHAR(128) NULL,
  evidence_summary  VARCHAR(255) NOT NULL,
  evidence_strength TINYINT UNSIGNED NULL,
  evidence_json     JSON NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (evidence_id),
  UNIQUE KEY uq_evidence (assertion_id, source_key, batch_id),
  KEY idx_strength (evidence_strength),
  CONSTRAINT chk_strength_range
    CHECK (evidence_strength IS NULL OR evidence_strength BETWEEN 0 AND 4),
  CONSTRAINT fk_evidence_assertion FOREIGN KEY (assertion_id)
    REFERENCES variation_ontology_assertion (assertion_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
```

`source_key` and `batch_id` are `NOT NULL` deliberately: MySQL permits multiple `NULL`s in a unique
index, so a nullable component would silently defeat idempotent re-runs of the backfill.

`evidence_summary` is a column, not something recomputed from JSON on every read. Revision 1 parsed
every payload in R purely to regenerate a summary, which defeated the point of a small hot endpoint and
discarded the source's own wording.

There is no `curator` source type. Under §4.3 a curator-authored annotation has no assertion row at
all, so a curator evidence row could never exist.

### 4.3 State semantics

| State | In curated set? | Meaning |
|---|---|---|
| `suggested` | no | Machine-derived candidate awaiting a curator. Never written to the connect table. |
| `active_unconfirmed` | yes | Present in curated data but machine-derived and never explicitly confirmed. |
| `confirmed` | yes | A curator explicitly affirmed it, with attribution and timestamp. |
| `rejected` | no | A curator explicitly declined. Suppressed from future suggestion runs. |

**Absence of an assertion row means curator-authored** — but only once backfill coverage is complete.
See §7.1; this is a release gate, not an assumption.

## 5. API surface

### 5.1 Public reads

`GET /api/entity/<id>/variation` gains a `provenance` object per term, joined on
`(entity_id, vario_id, modifier_id)`:

```json
{ "entity_id": 2097, "vario_id": "VariO:0017", "vario_name": "nonsynonymous variation",
  "modifier_id": 1,
  "provenance": {
    "state": "active_unconfirmed",
    "max_strength": 1,
    "sources": [
      { "source_type": "external_database", "source_key": "clinvar",
        "strength": 1, "summary": "2 ClinVar records, max 1 star" }
    ] } }
```

`sources` is an **array**, ordered by `evidence_strength` descending then `source_key` ascending, so two
independent sources corroborating a term is representable and the rendering order is deterministic.
Revision 1 returned a singular object and selected a row by `match()`, which was nondeterministic
whenever more than one source existed.

`provenance` is `null` for curator-authored terms. The full `evidence_json` is not on this endpoint;
it is fetched on demand:

`GET /api/entity/<id>/variation/<vario_id>/<modifier_id>/evidence` → full payloads for that assertion.

### 5.2 Suggestions

- `GET /api/entity/<id>/variation/suggestions` — `state='suggested'` for one entity, used inline by the
  curation form.
- `GET /api/curate/variation/suggestions` — cross-entity queue, filterable by `source_key`,
  `evidence_strength`, `vario_id`, gene; paginated with the existing cursor helper. Curator role.

### 5.3 Writes — server-side reconciliation

Because several curation surfaces prefill and resubmit (§3.4), correctness cannot depend on a client
field. `review_write_mutate()` reconciles, inside the existing transaction:

1. Read the previous assertion set for the entity.
2. Compare against the submitted `(vario_id, modifier_id)` set.
3. Apply:

| Situation | Result |
|---|---|
| Term submitted, assertion `active_unconfirmed`, no explicit action | **stays `active_unconfirmed`** |
| Term submitted with `provenance_action: "confirm"` | → `confirmed` + `confirmed_by` + `confirmed_at` |
| Term omitted that was previously `active_unconfirmed` or `suggested` | → `rejected` |
| Term submitted that has no assertion row | no row created — curator-authored |

Row 1 is the whole fix. A curator who saves without engaging a pre-checked machine-derived term leaves
it unconfirmed. The annotation stays live; it is simply never silently upgraded. Confirmation becomes
an act, not a side effect.

Row 3 makes removal correct for every surface, including ones that send no provenance fields at all —
which is what revision 1 got wrong by trusting a `variation_ontology_rejected` array that existing
clients never send.

`review_write_prepare()` must be extended to carry `provenance_action` through its normalizer
(`review-write-service.R:93-97` currently drops everything except `vario_id` and `modifier_id`).

## 6. UI / UX

### 6.1 Design principle

Provenance is **information, not an error**. An unconfirmed annotation is not broken — it is
un-reviewed. Styling it in red would make thousands of entity pages look alarming and train curators to
ignore it. The visual language is quiet by default and detailed on demand. Reserve saturated color for
curator actions; carry state with weight, a small glyph, and a dotted underline.

### 6.2 Public entity page — Variation Ontology card

```
┌─ Variation Ontology ────────────── ⓘ provenance ─┐
│                                                   │
│  ✔ variation          ✔ protein truncation        │   ← curator: unchanged styling
│                                                   │
│  ⌁ nonsynonymous variation                        │   ← machine-derived, unconfirmed
│    ·······················                        │
│                                                   │
│  ⌁ out-of-frame indel   ⌁ protein loss of function │
└───────────────────────────────────────────────────┘
```

**Evidence popover** — click or keyboard-focus any chip:

```
┌──────────────────────────────────────────────┐
│  nonsynonymous variation          VariO:0017 │
│  ─────────────────────────────────────────── │
│  Source    ClinVar (external database)       │
│  Imported  15 Feb 2026 · batch clinvar-2026-02│
│  Strength  ★☆☆☆ 1 star — single submitter    │
│  Status    Not yet confirmed by a curator    │
│                                              │
│  Supporting records                          │
│   • VCV1343191  missense · Likely path.  ↗   │
│   • VCV1804020  missense · Likely path.  ↗   │
│                                              │
│  Matched via OMIM:251280                     │
└──────────────────────────────────────────────┘
```

Records are listed by ClinVar variation ID, consequence and classification — the fields the import
manifest actually captured. Protein/cDNA labels such as `p.Thr215Pro` are **not** stored: the importer
never recorded them (`clinvar_processor.py:324-337`). Where a nicer label is wanted, the existing
external proxy resolves it lazily at display time. Storing an HGVS string the backfill cannot prove
would be exactly the fabrication this whole design exists to prevent.

Evidence is fetched lazily on first open and cached per entity, so the card costs nothing extra on page
load. Chips are focusable, the popover is a labelled dialog reachable by keyboard, and state is exposed
in text (`aria-label="nonsynonymous variation, machine-derived, not confirmed"`) — never by glyph or
color alone.

### 6.3 Curation form — the load-bearing change

```
┌─ Variation Ontology ────────────────────────────────────────┐
│  CONFIRMED                                                  │
│   [✔ variation ×]  [✔ protein truncation ×]                 │
│                                                             │
│  NEEDS CONFIRMATION                          2 terms        │
│   ┌───────────────────────────────────────────────────────┐ │
│   │ ⌁ nonsynonymous variation   present   VariO:0017      │ │
│   │   ClinVar · ★☆☆☆ · 2 records, single submitter        │ │
│   │   VCV1343191 ↗   VCV1804020 ↗                         │ │
│   │                          [ Confirm ]  [ Remove ]      │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                             │
│  SUGGESTED — not in the entity                1 term        │
│   ┌───────────────────────────────────────────────────────┐ │
│   │ + splice variation          present   VariO:0508      │ │
│   │   ClinVar · ★★★☆ · 6 records, expert panel            │ │
│   │                          [ Accept ]   [ Dismiss ]     │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                             │
│  + add term…                                                │
└─────────────────────────────────────────────────────────────┘
```

Each card shows the **modifier** alongside the term, because *present* and *absent* are different
assertions with independent state.

- **Needs confirmation** holds `active_unconfirmed`. Terms remain selected and are still submitted —
  the annotation does not vanish. Only `Confirm` changes state. Saving without touching them is
  explicitly allowed. `Remove` drops the term and, via §5.3 row 3, records `rejected`.
- **Suggested** holds `state='suggested'`, unchecked by default. `Accept` moves it into Confirmed;
  `Dismiss` records `rejected` so it never resurfaces.
- The zone header count is the honest signal: "2 terms need confirmation" is actionable in a way a
  pre-checked box never was.

Evidence is inline here, not behind a popover. In the curation flow the evidence *is* the decision.

### 6.4 Suggestion queue (last phase)

A curator-role table at `/curate/variation-suggestions` reusing the re-review queue's patterns: gene,
entity, term, modifier, source, strength, evidence summary; filters on source and strength; row actions
Accept / Dismiss; multi-select for bulk dismissal. Default sort strongest-evidence-first. This is what
makes the 1,981 weak-evidence backlog tractable.

## 7. Backfill

One-off scripts in **this** repo under `scripts/data-corrections/`, dry-run by default.

### 7.1 Coverage is a release gate

Under §4.3, absence of an assertion row means curator-authored. That is only true once **every** import
batch is backfilled. Backfilling one batch and shipping public reads would positively present the other
batches' annotations as curator-authored — worse than the current state, and a direct inversion of the
primary goal.

**Gate:** all three February batches (182 + 5,763 + 2,166 = 8,111) must be backfilled and count-verified
before §5.1 ships. The plan enforces this by covering all three in one execution, and by a verification
step that asserts the total assertion count equals the sum of the three execution logs.

### 7.2 Identifying what is still current

Current terms are the ones on **primary, approved** reviews
(`entity-read-endpoint-service.R:293-310`; `review-repository.R:29-33`) — not simply `is_active = 1`.
Historical connect rows remain `is_active = 1` after another review becomes primary, so an
`is_active`-only query would mark annotations that are no longer publicly current, and could match an
obsolete imported *present* row against a current curator-authored *absent* row.

The backfill classifies each manifest row by joining on `(entity_id, vario_id, modifier_id)` against the
primary-approved set, and comparing the manifest's `review_id` against the current one:

| Case | Meaning | Action |
|---|---|---|
| present, same `review_id` | untouched since import | write `active_unconfirmed` |
| present, different `review_id` | carried into a later review (laundered) | write `active_unconfirmed`, count separately |
| absent | curator already removed it | skip, report |

### 7.3 What can honestly be recorded

- `evidence_json` carries only fields the manifests contain: ClinVar variation ID, classification,
  review stars, consequence, matched OMIM identifier. No HGVS.
- `source_version` is written **only** if the archived input can be identified and checksummed. The
  importer consumed a generic `clinvar.vcf.gz`, skipped re-download when the file existed, and printed
  but never persisted its MD5 (`clinvar_processor.py:45-69, 93-107`). If the archived file is not
  available, `source_version` is `NULL` and the execution log records why. A guessed release string
  would be a fabricated provenance record.
- Evidence items are deduplicated by variation ID. The original processor can append the same variant
  once per matching OMIM identifier (`clinvar_processor.py:291-337`), which would otherwise inflate
  record counts. Matched diseases are stored as a list, not just the first.

## 8. Future importers

> An automated process may write assertion rows with `state='suggested'`.
> It may **not** write to `ndd_review_variation_ontology_connect`.

Policy alone cannot hold this — existing scripts insert into the connect table directly
(`clinvar_processor.py:744-747`), and under §4.3 any future script repeating that pattern immediately
creates falsely curated-looking data. Enforcement, in increasing strength:

1. A single shared write helper in `scripts/data-corrections/_shared/` that is the only sanctioned path,
   writing suggestions only.
2. A CI guard that fails if any file under `scripts/data-corrections/` contains an `INSERT`/`UPDATE`/
   `DELETE` against `ndd_review_variation_ontology_connect`.
3. A dedicated DB account for importers with `INSERT` on the provenance tables and no write grant on the
   connect table.

(1) and (2) ship with this work; (3) is recommended and tracked separately.

## 9. Testing

| Layer | Test |
|---|---|
| Migration | Applies against the test DB via `split_sql_statements()`; both tables exist with FKs; CHECK rejects strength 5 and a `confirmed` row without `confirmed_by`. |
| Migration | Unique key rejects a duplicate `(entity_id, vario_id, modifier_id)` and a duplicate `(assertion_id, source_key, batch_id)`. |
| Identity | *present* and *absent* for the same term are independent assertions with independent state. |
| Backfill | Counts asserted, not printed: annotations, unique keys, evidence coverage, per-batch totals. Any mismatch aborts before commit. |
| Backfill | Idempotent on re-run; refuses to write when a manifest row is no longer on a primary-approved review. |
| API read | `provenance` is `null` for curator-authored terms; `sources` is a deterministically ordered array; `evidence_json` is absent from the hot endpoint. |
| API write | **Saving a review with no `provenance_action` leaves `active_unconfirmed` unchanged.** The regression test for the original bug. |
| API write | A term omitted by a client that sends no provenance fields transitions to `rejected`. |
| API write | Provenance and connect-table writes share one transaction; a forced failure rolls back both. |
| UI | Unconfirmed terms render in the Needs-confirmation zone with their modifier; saving without acting does not change state. |
| A11y | Chip state exposed in text; popover keyboard-reachable and labelled. |

Migrations are forward-only (`db/migrations/README.md:161-176`), so there is no rollback test.

## 10. Phasing

| Phase | Deliverable | Repo | Risk |
|---|---|---|---|
| 1 | Migration + assertion/evidence repositories | application | low, additive |
| 2 | Backfill, **all three batches** | administration | low, new tables only |
| 3 | API reads + public chips and evidence popover | application | low — gated on Phase 2 completing |
| 4 | Write reconciliation in `review_write_*` | application | **highest — behavioural, transactional** |
| 5 | Curation form three-zone picker | application | medium |
| 6 | Suggestion queue | application | low |
| 7 | Importer write helper + CI guard | both | low |

Phase 3 must not ship before Phase 2 completes (§7.1). Phase 4 is where behaviour changes and where the
transaction boundary matters; it deserves the most review attention.

## 11. Open questions

1. **Confirmation granularity.** Does confirming a term confirm it for the entity permanently, or per
   review? Proposed: per entity — re-confirming on every review is busywork.
2. **Suggestion staleness.** If an upstream record is reclassified, does the suggestion update or
   expire? Out of scope; a refresh job should compare `source_version` and flag drift — which is a
   further argument for recording a real version or none at all.
3. **`VariO:0001`.** Terms this generic carry little information. Worth deciding separately whether they
   should be suggestible at all.
4. **Strength comparability.** A 0–4 scale shared across literature and external databases implies a
   comparability that is not obviously real. It is retained because the queue needs a sort order, but
   the literature mapping should be revisited once the queue exists.

