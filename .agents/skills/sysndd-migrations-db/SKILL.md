---
name: sysndd-migrations-db
description: Use when adding or changing a SysNDD DB migration, editing a SQL view (especially ndd_entity_view or the core read views), touching the migration runner or manifest, restoring a database, or diagnosing a startup failure related to migrations
---

# SysNDD Migrations & DB Views

Use this skill before adding a migration, editing a view, or touching the migration runner. `db/migrations/*.sql` are applied at API startup by the runner using a MySQL advisory lock (`GET_LOCK('sysndd_migration')`, `migration-runner.R`). See `db/migrations/README.md` for specifics.

## Core Rule — Failures Are Meant to Crash Startup

A failing migration is supposed to crash boot. **Do not weaken startup checks to work around it** — fix the migration or the mount. Missing, empty, or stale migration mounts are fatal by design and are a packaging/deployment problem, not something to patch in code.

## Adding a Migration

1. Name it `NNN_snake_case.sql`, contiguous with the current latest (currently `041_add_analysis_reproducibility.sql`). `make lint-api` checks the prefix.
2. **Bump the manifest** in `api/functions/migration-manifest.R`: `EXPECTED_LATEST_MIGRATION` must equal the new sorted-latest filename, and keep `EXPECTED_MIGRATION_COUNT` in sync. Startup validates the manifest *before* the fast path (`validate_migration_manifest`): the dir must exist, contain SQL files, have the expected latest, and meet the minimum count — all fatal if not.
3. Migrations are idempotent-friendly where they re-assert schema (e.g. `039` re-asserts columns/types after a drifted restore). Prefer `CREATE TABLE IF NOT EXISTS` / guarded `ALTER` for re-assertable DDL.

## Views Are Mirrored — Change Both Places

The core read views (`ndd_entity_view`, `users_view`, `search_non_alt_loci_view`, `search_disease_ontology_set`) are codified in `025_create_core_views.sql` with `SQL SECURITY INVOKER` so a pristine DB boots. `ndd_entity_view` is later rebuilt by `026_add_entity_last_update.sql` (adds the derived `last_update` column). **The latest `CREATE OR REPLACE VIEW ndd_entity_view` migration is the source of truth and must stay mirrored byte-for-byte** (modulo the `sysndd_db.` schema prefix and the migration's `ALGORITHM`/`SQL SECURITY INVOKER` clause) in `db/C_Rcommands_set-table-connections.R`. Edit a view definition → update both.

## Rollback & Restore Gotchas

- Metadata refreshes needing rollback must **not** use `TRUNCATE` (DDL auto-commits, breaking the transaction). Use `refresh_disease_ontology_set()` / `metadata_with_foreign_key_checks_disabled()` from `metadata-refresh.R`; enforced by `test-unit-metadata-refresh-patterns.R`.
- A `dbWriteTable`-style DB restore silently drifts schema (narrow auto-sized VARCHARs, `comparison_id` recreated as `DOUBLE` PK without `AUTO_INCREMENT`, dropped columns). Use `make db-restore-latest` then `make db-views-rebuild` to recreate the DEFINER views; the idempotent re-assert migrations (`039`) repair the drift.

## Related

- Never re-add `COPY config.yml` to `api/Dockerfile` — config is a runtime read-only mount only.
- New job-handler / function files register in `bootstrap/load_modules.R` and need a worker restart — see `sysndd-async-jobs`.

## Verify

Confirm the API starts cleanly (migration runner logs each applied migration), run `make lint-api` (prefix check), and consult `db/migrations/README.md`.
