# Blocked OMIM update no longer freezes the disease dictionary (#470)

**Date:** 2026-06-29
**Issue:** https://github.com/berntpopp/sysndd/issues/470
**Branch:** `fix/omim-update-additive-autoapply-470`

## Problem

The `omim_update` async job is a stage-then-apply pipeline with a safeguard. When
`identify_critical_ontology_changes()` finds `truly_critical > 0`
entity-referenced changes, `.async_job_run_omim_update`
(`api/functions/async-job-handlers.R`) writes a pending CSV, returns
`list(status = "blocked", ...)`, and **`return()`s before the DB write** at the
`progress("write", ...)` step. The full freshly-built dictionary — including
brand-new, zero-risk OMIM terms that no entity references yet — is discarded
along with the genuinely conflicting changes.

Consequences observed in production (snapshot `sysndd_snapshot_20260629_1545`):

1. The live `disease_ontology_set` has been frozen at the 2026-02-08 snapshot for
   ~4 months (max applied id `OMIM:621495`). ~40+ newer terms (e.g.
   `OMIM:621533`, `OMIM:621608`) are unsearchable.
2. The rename-disease autocomplete reads the live view `search_disease_ontology_set`
   over the frozen base table, so curators searching a new OMIM term — by name or
   number — get a bare "No results found".
3. `async_jobs.status` has no `blocked` value, so a blocked run records as
   `completed`; monitoring and the admin UI both treat it as success. The existing
   blocked panel only renders *reactively* right after an admin runs an update
   (`useAnnotationJobReactions.ts`), so a page reload hides it. Nothing on load
   tells the admin the dictionary is frozen.
4. The same 5 critical entities re-block every cycle and overwrite the pending CSV,
   so the freeze is permanent until someone manually runs Force Apply.

## Goals

- New OMIM terms become searchable/assignable automatically, every cycle, with no
  manual step — even while unrelated critical changes are gated.
- A blocked/stale ontology update is visible to an administrator on page load, with
  a clear instruction and the Force Apply control.
- A curator who searches for a just-added OMIM term gets a helpful hint instead of
  a bare "No results found".
- The genuinely critical, entity-referenced changes continue to gate for manual
  Force Apply review — the safeguard is preserved, not removed.

## Non-goals (explicitly out of scope)

- **Fix 3 (persistent acknowledgement table).** Once additive auto-apply lands the
  dictionary no longer freezes, so re-blocking just correctly flags 5 entities that
  genuinely need a curator decision. A full ack table risks permanently hiding
  reviews that should happen. Deferred.
- **Changing the `async_jobs.status` enum.** The job genuinely completed; only its
  *result* is "blocked". Reclassifying the shared job lifecycle is invasive and
  risks the durable job state machine. We surface a derived signal instead.
- **Production Force-Apply remediation.** No production access from this change. The
  operator step is documented (see Operational remediation).
- **No DB migration.** All four fixes work within the existing schema.

## Design

### Fix 2 — Additive auto-apply (core, API)

Add two functions and wire one call:

1. `extract_additive_ontology_terms(disease_ontology_set_update, disease_ontology_set_current)`
   — pure helper in `api/functions/ontology-functions.R`. Returns the subset of
   update rows whose `disease_ontology_id_version` is **absent from the current
   set**. Such versions are brand-new and therefore entity-unreferenced (entities
   can only reference versions already present in the current set), so inserting
   them is zero-risk. Returns a 0-row tibble with the update's columns when there
   is nothing additive. No DB access — unit-testable with fixtures.

2. `apply_additive_ontology_terms(conn, additive_rows)` — in
   `api/functions/metadata-refresh.R`. Appends only `additive_rows` (no `DELETE`)
   inside the existing `metadata_with_foreign_key_checks_disabled()` +
   `DBI::dbWithTransaction()` wrapper, mirroring `refresh_disease_ontology_set`'s
   transaction discipline (no `TRUNCATE`, no manual begin/commit). Returns the
   number of rows inserted. A 0-row input is a no-op returning `0L`.

3. In `.async_job_run_omim_update` blocked branch (`api/functions/async-job-handlers.R`):
   after writing the pending CSV and before `return()`, compute the additive rows,
   insert them best-effort (`tryCatch`), chain the cross-ontology mapping refresh
   (reusing `.async_job_chain_ontology_mapping_refresh()`, exactly as the clean
   path does), and add `additive_applied` (and `additive_error` on failure) to the
   returned blocked result. The additive insert must never turn a blocked result
   into a job failure: on insert error we log, set `additive_applied = 0`, and still
   return `status = "blocked"`.

Idempotency: a re-run recomputes additive rows against the now-updated current set,
so previously inserted terms are excluded. A later Force Apply or clean run does a
full `DELETE` + reinsert from CSV, which includes the additive rows, so they are
cleanly superseded — never duplicated.

Column contract: `additive_rows` are rows of `disease_ontology_set_update`, which
carries the CSV column set (`disease_ontology_id_version`, `disease_ontology_id`,
`disease_ontology_name`, `disease_ontology_source`, `disease_ontology_date`,
`disease_ontology_is_specific`, `hgnc_id`, `hpo_mode_of_inheritance_term`, `DOID`,
`Orphanet`, `EFO`, `MONDO`, `is_active`, `update_date`). The migration-036
projection columns (`UMLS`, `MedGen`, `NCIT`, `GARD`, `ontology_mapping_release`)
are nullable and default to NULL on append, then are re-derived by the chained
mapping refresh — identical to how the clean `refresh_disease_ontology_set` path
behaves today.

### Fix 1 — Visibility: derived status endpoint + persistent banner (API + UI)

**API:** `GET /api/admin/ontology/status` (Administrator-gated, DB-only, cheap).
Logic:

- Read `disease_ontology_set` for `MAX(update_date)` (last applied) and
  `MAX(disease_ontology_id)` for OMIM rows (informational `max_omim_id`).
- Find the most recent `omim_update` job from job history and read its
  `result_json`. If its result status is `"blocked"` and the pending CSV still
  exists and is fresh (≤ the same 48h staleness window Force Apply enforces),
  set `blocked = TRUE` and surface `blocked_job_id`, `critical_count`,
  `auto_fixable_count`, `additive_applied`, `pending_csv_path`.
- `stale = blocked || last-applied older than a threshold` (reuse a sensible
  default, e.g. 30 days, env-overridable; the headline signal is `blocked`).

Returns a flat JSON object:
`{ blocked, blocked_job_id, disease_ontology_last_applied, max_omim_id,
   critical_count, auto_fixable_count, additive_applied, stale,
   last_omim_update_status, last_omim_update_at }`.

**Frontend:** `ManageAnnotations.vue` calls the status endpoint `onMounted` (via a
new typed helper in `useAnnotationsApi.ts`). When `blocked` and a `blocked_job_id`
is present, it reuses the existing `fetchOntologyJobResult(blocked_job_id)` to
hydrate `ontologyBlocked`, so the existing `OntologyAnnotationsCard` blocked panel
renders **persistently on page load** (today it only appears reactively right after
running an update). The panel already renders the critical-entity table, auto-fix
list, user-assignment select, and Force Apply button. Copy additions:

- A staleness line: "Disease dictionary last applied {date} — {N} new term(s) were
  auto-applied; {critical_count} entity-referenced change(s) need review."
- Clearer instruction directing the admin to review the listed entities and Force
  Apply to flush the remaining staged changes.

This reuses the existing card and force-apply flow — minimal new frontend surface.

### Fix 4 — Curator-facing hint (UI only)

In the rename-disease autocomplete path
(`app/src/views/curate/composables/useEntityAutocomplete.ts` and the component that
renders the disease treeselect), when `searchOntology` returns an empty array **and**
the trimmed query is OMIM-shaped (`/^(omim:?\s*)?\d{6}$/i`) **and** not loading,
expose an `ontologyEmptyHint` message:

> "No matching disease found. If you recently added this OMIM ID, the disease
> dictionary may need an administrator refresh."

For non-OMIM-shaped empty queries the behavior is unchanged (standard "No results").
Frontend-only; always-correct guidance regardless of pending state.

## Data flow

```
omim_update job (worker)
  process_combine_ontology() -> full new dictionary (CSV columns)
  validate_omim_data()
  identify_critical_ontology_changes() -> {auto_fixes, critical, summary}
    truly_critical == 0 ──> .async_job_omim_db_write (full refresh)         [unchanged]
    truly_critical  > 0 ──> write pending CSV
                            extract_additive_ontology_terms(update, current)
                            apply_additive_ontology_terms(conn, additive)   [NEW, pure INSERT]
                            chain mapping refresh (best-effort)
                            return status="blocked" + additive_applied      [NEW field]

ManageAnnotations.vue onMounted
  GET /api/admin/ontology/status -> { blocked, blocked_job_id, ... }        [NEW endpoint]
    if blocked: fetchOntologyJobResult(blocked_job_id) -> hydrate banner    [reuses existing]

Rename-disease autocomplete
  searchOntology(q) -> [] && OMIM-shaped(q) -> ontologyEmptyHint            [NEW hint]
```

## Error handling

- Additive insert failure → logged, `additive_applied = 0`, job still returns
  `blocked` (never fails the job over a best-effort enhancement).
- Mapping-refresh chain failure → already best-effort in
  `.async_job_chain_ontology_mapping_refresh()` (logs, never throws).
- Status endpoint: job-history / DB errors fall back to a safe
  `blocked = FALSE, stale = FALSE` payload (never 500s the admin page); a missing
  pending CSV downgrades `blocked` to FALSE just like Force Apply's 410 guard.
- Curator hint is presentation-only and cannot error.

## Testing

- **R unit:** `extract_additive_ontology_terms` (additive subset correctness,
  empty-input, no-additive cases) in `test-unit-ontology-functions.R`;
  `apply_additive_ontology_terms` transaction-pattern static guard +
  blocked-branch wiring static guard in `test-unit-async-job-handlers.R`;
  status-endpoint blocked/stale derivation logic test.
- **Frontend unit:** status→banner hydration in `ManageAnnotations.spec.ts`;
  OMIM-shaped empty-state hint in `useEntityAutocomplete.spec.ts`.
- **Playwright (local-only):** load the production snapshot into the dev DB; assert
  the admin sees the persistent blocked banner on `/ManageAnnotations` load, and
  that the previously-missing OMIM term resolves in disease search after the
  additive path / Force Apply.

## Operational remediation (documented, not executed here)

To flush the currently-staged 2026-06-29 dictionary in production: review the 5
critical entities, then `PUT /api/admin/force_apply_ontology?blocked_job_id=<id>`
(or Admin → Manage Annotations → Force Apply). The code fixes prevent recurrence;
once deployed, additive auto-apply makes new terms assignable without this step.

## Documentation contract

Update `AGENTS.md` (Background jobs / ontology safeguard section) to record the
additive-auto-apply-on-block behavior and the new `/api/admin/ontology/status`
endpoint. Note the operator remediation in `documentation/09-deployment.qmd` if the
ontology-refresh operations section warrants it.
