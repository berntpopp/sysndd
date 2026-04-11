# Database Migrations

SQL migration files for the SysNDD MySQL schema. The API applies them
automatically at startup; this directory is the single source of truth.

## 1. What the runner does

On every API boot, `api/start_sysndd_api.R` (section 7.5, "Run database
migrations with double-checked locking") sources
`api/functions/migration-runner.R` and calls `run_migrations()` against the
shared `pool` connection. The runner:

1. Creates the `schema_version` tracking table if absent
   (`ensure_schema_version_table()`, `CREATE TABLE IF NOT EXISTS`).
2. Lists every `*.sql` file under `db/migrations/` via
   `list_migration_files()` and sorts them lexicographically (the numeric
   prefix guarantees the right order).
3. Diffs that list against `schema_version.filename WHERE success = TRUE`
   to compute pending migrations.
4. Executes each pending file in order via `execute_migration()`, splitting
   on `;` (and on `DELIMITER //` for stored-procedure files), running each
   statement with `DBI::dbExecute(immediate = TRUE)`, and inserting a
   `schema_version` row on success.

The runner is fail-fast by design: any SQL error stops execution, the
`tryCatch` at the startup call site converts it to
`stop("API startup aborted: migration failure - ...")`, and the API process
crashes. There is no "continue on error" mode, and there should not be one.
Fix the migration and redeploy.

This directory is bind-mounted **read-only** into the API container at
`/app/db/migrations`, so the runner can read but never write SQL files.

## 2. Advisory lock and fast-path

Production runs multiple API replicas behind Traefik, so startup uses
double-checked locking to coordinate them:

1. **Fast path (no lock).** `get_pending_migrations()` is called first with
   no lock held. If the pending set is empty the runner logs
   `"Fast path: schema up to date, no lock needed"` and returns. Most API
   restarts hit this path, so unchanged schemas incur one `SELECT` and zero
   lock contention.
2. **Acquire lock.** If pending migrations exist, the startup code checks
   out a dedicated connection, calls `acquire_migration_lock()` which runs
   `SELECT GET_LOCK('sysndd_migration', 30)`, and blocks for up to
   **30 seconds**. A timeout (`GET_LOCK` returned `0`) or DB error
   (returned `NULL`) is fatal — the startup `stop()`s and the container
   crash-loops until the lock becomes available.
3. **Re-check under lock.** Once the lock is held, `get_pending_migrations()`
   runs again. If another replica applied everything while we waited, the
   pending set is empty and we release the lock and continue without
   touching the schema.
4. **Apply.** Otherwise `run_migrations()` executes the pending files,
   records each in `schema_version`, and `release_migration_lock()` runs
   via `on.exit()` regardless of success or failure.

The lock is a MySQL named advisory lock (`GET_LOCK`/`RELEASE_LOCK`), not a
row or table lock. It is tied to the owning connection and MySQL releases
it automatically if the API dies mid-migration, so a crashed replica cannot
wedge the next boot.

## 3. Numbered-prefix convention

Filenames must match `<NNN>_<short_description>.sql`, e.g.

```
001_add_about_content.sql
002_add_genomic_annotations.sql
...
017_ensure_pubtator_gene_symbols.sql
```

- Three-digit zero-padded prefix so sort order matches apply order.
- Prefixes must be unique. A7's `scripts/check-migration-prefixes.sh`
  (enforced in `make lint-api`) fails CI if two files share a prefix.
- Lowercase snake_case after the prefix; no spaces.
- One logical change per file. Mixing unrelated DDL makes rollback
  (see §5) painful.

The only state the runner persists is the filename, so once a migration is
recorded in `schema_version` its **contents are frozen**. Editing an
already-applied file will not re-run it and will desync envs. Write a new
migration instead.

## 4. Adding a new migration

1. Pick the next unused prefix: `ls db/migrations/ | sort | tail -1`, add
   one.
2. Drop a new `NNN_short_name.sql` file in this directory. The migration
   should be idempotent where practical (`CREATE TABLE IF NOT EXISTS`,
   `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, guarded `INSERT IGNORE`,
   etc.) — it makes local recovery easier even though the runner itself
   uses `schema_version` for at-most-once semantics.
3. Restart the API (`docker compose restart api`, or redeploy). The new
   file is picked up automatically on the next start and applied under
   the advisory lock.
4. Verify in MySQL:

   ```sql
   SELECT filename, applied_at FROM schema_version ORDER BY filename;
   ```

   The new filename should appear with a recent `applied_at`.

No manual `mysql <` redirection is needed, and none is supported — there
is no out-of-band apply path.

## 5. Rollback guidance

Migrations are **forward-only**. The runner does not understand `down`
scripts and `schema_version` has no rollback column. To undo a change that
has already been applied in any environment:

1. Write a new, higher-numbered migration that reverses the DDL or data
   change (e.g. `020_drop_foo_column.sql`).
2. Commit it like any other migration.
3. Restart the API to apply it.

For an in-flight migration that crashed the API mid-file: MySQL DDL
auto-commits on each statement, so the schema may be partially applied and
the `schema_version` row **will not** have been inserted (the error short-
circuits `record_migration`). Inspect the actual schema, edit the failing
migration to be safe to re-run from its current state, and restart. Do
**not** hand-insert a `schema_version` row to "mark it applied" — that
hides the drift from the next environment.

For local dev resets, drop the dev DB container (`make docker-dev-db` +
recreate) and let the runner reapply everything from scratch.

## 6. CI smoke test

End-to-end coverage for the runner lives in Phase B4 of v11.0 (see
`.plans/v11.0/phase-b.md` §B4). B4 adds a CI job that spins up a fresh
MySQL container, boots the API image against it, and asserts that
`schema_version` contains every file in `db/migrations/`. That job is the
authoritative guard that this README and the runner stay in sync — if you
change the naming convention, the startup sequencing, or the table shape,
update B4's smoke test in the same PR.

Unit coverage for the individual runner helpers
(`list_migration_files`, `split_sql_statements`, `get_pending_migrations`,
etc.) lives in `api/tests/testthat/test-unit-migration-runner.R` and runs
as part of `make test-api`.
