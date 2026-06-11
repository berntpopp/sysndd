# Design: "Last updated" date for entities

**Date:** 2026-06-11
**Branch:** `feat/entity-last-updated-date`
**Origin:** User feature request — alongside the existing *Entry date*, show a *last edited / last updated* date so a visitor can judge how current an entity is and whether SysNDD's record is fresh enough or warrants looking elsewhere.

## Problem

Entities currently expose only `entry_date` (the date the gene–disease–inheritance record was first created). That date never changes, so a 2014 entry that was re-reviewed and re-classified in 2026 still reads as "2014". Users cannot tell, at a glance, whether a record reflects recent curation.

## Definition of "last updated"

SysNDD's curation model is append-only/versioned across three tables:

- `ndd_entity.entry_date` — when the entity was first created.
- `ndd_entity_status.status_date` — each (re)classification; the active+approved one is exposed by `ndd_entity_status_approved_view`.
- `ndd_entity_review.review_date` — each synopsis/phenotype/publication/variation review; the curated record is the **primary approved** review (`is_primary = 1 AND review_approved = 1`).

The most recent meaningful curation touch is therefore:

```
last_update = GREATEST(
  entry_date,
  approved status_date,
  COALESCE(latest primary-approved review_date, entry_date)
)
```

Validated against the live dev DB: 2254 / 4200 active entities have `last_update > entry_date`, confirming this is a genuinely informative freshness signal (not a near-duplicate of entry date).

`GREATEST` is well-defined: `entry_date` and the approved `status_date` are both `NOT NULL` (the approved-status view is an inner join), and the review term is coalesced to `entry_date` when an entity has no primary-approved review.

## Approach (chosen)

**Single derived column in `ndd_entity_view`.** All three consuming surfaces — the Entities table, the Phenotypes table, and the Entity detail page — read `ndd_entity_view`. Adding one `last_update` column there surfaces the value everywhere through existing data paths:

- `GET /api/entity/` returns it automatically (no endpoint change; `fields=""` returns all view columns).
- Sort/filter allowlist is derived from the view's live columns via `allowed_columns_for_view()`, so `sort=-last_update` becomes valid after an API restart refreshes the memoised allowlist.
- fspec marks high-cardinality date columns non-selectable (verified with `entry_date`), so there is no filter-dropdown bloat.

Rejected alternative: compute it per-request in the entity endpoint(s). That would duplicate the GREATEST logic across the entity and phenotype code paths and skip the table surface where Entry date is most visible.

## Changes

### Database
- `db/migrations/026_add_entity_last_update.sql`: `CREATE OR REPLACE VIEW ndd_entity_view` with the new `last_update` column (LEFT JOIN to a primary-approved-review subquery + `GREATEST`).
- `db/C_Rcommands_set-table-connections.R`: mirror the view definition (kept in sync per AGENTS.md core-views invariant).

### API
- `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION = "026_add_entity_last_update.sql"`, `EXPECTED_MIGRATION_COUNT = 27`.
- Update manifest unit tests (`test-unit-analysis-snapshot-migration.R`, `test-unit-core-views-manifest.R`).
- Restart the API container so the migration applies and the memoised allowlist picks up the new column.

### Frontend
- `app/src/types/models.ts`: add `last_update: string` to `Entity`.
- `app/src/views/pages/EntityView.vue`: hero metadata pills for **Entry date** and **Last updated** (date-only display).
- `app/src/components/tables/TablesEntities.vue`: add **Last updated** to the expandable detail row (next to Entry date).
- `app/src/components/tables/TablesPhenotypes.vue`: same, next to its Entry date.
- `app/src/components/tables/EntitiesMobileRows.vue` + `PhenotypesMobileRows.vue`: add a Last updated detail row.

### Tests
- Frontend: extend existing vitest specs (mobile rows, entity view) for the new field.
- Backend: assert the migration defines `last_update` and the manifest is consistent.

## Out of scope
- Changing how `entry_date` itself is displayed.
- Per-source/external "last checked" freshness (this is SysNDD-internal curation freshness only).
- A dedicated top-level sortable column in the main Entities grid (kept in the detail row alongside Entry date to match the existing layout; sorting via `?sort=-last_update` still works).

## Display note
The view returns `last_update` as a timestamp (full fidelity, correct sort). The Entity hero renders it date-only (`YYYY-MM-DD`) for a clean freshness signal; table/mobile detail rows render the raw value, matching the existing `entry_date` presentation.
