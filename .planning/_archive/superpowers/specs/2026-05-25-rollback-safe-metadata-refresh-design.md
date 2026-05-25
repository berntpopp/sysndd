# Rollback-Safe Metadata Refresh Design

## Goal

Replace the remaining rollback-unsafe metadata refresh paths that issue MySQL
`TRUNCATE` inside transaction code. This phase is limited to the five active
review locations from `.planning/reviews/2026-05-24-codebase-review.md`:

- `api/endpoints/admin_endpoints.R:230-238`
- `api/endpoints/admin_endpoints.R:493-513`
- `api/endpoints/admin_endpoints.R:611-632`
- `api/functions/async-job-handlers.R:504-510`
- `api/functions/async-job-handlers.R:694-706`

The implementation should preserve API contracts, response shapes, job result
fields, validation behavior, duplicate-job behavior, and re-review batch
creation semantics.

## Context Read

- `AGENTS.md`
- `.planning/reviews/2026-05-24-codebase-review.md`
- `db/migrations/README.md`
- `api/endpoints/admin_endpoints.R`
- `api/functions/async-job-handlers.R`
- `api/endpoints/jobs_endpoints.R`
- `api/tests/testthat/helper-db.R`
- Current schema definitions in `db/migrations/000_initialize_base_schema.sql`
- Existing transaction/static tests under `api/tests/testthat/`

The worktree was clean during planning, so checkpoint commits are suitable for
the implementation phase if it starts from the same state.

## Current Unsafe Paths

| Path | Runtime surface | Current behavior | Risk | Decision |
| --- | --- | --- | --- | --- |
| `api/endpoints/admin_endpoints.R:230-238` | Inline `executor_fn` body for `PUT /api/admin/update_ontology_async`; current `create_job()` ignores this function and submits a durable `omim_update` job. | Opens a direct MariaDB connection, starts `DBI::dbBegin()`, disables FK checks, truncates `disease_ontology_set`, appends the new ontology rows, reenables FK checks, then applies auto-fix updates to `ndd_entity`. | The code is unreachable today, but it still advertises a rollback-unsafe implementation and creates a second apparent ontology writer for future readers to reason about. | Delete the dead inline `executor_fn` argument from the `create_job()` call. The durable worker handler remains the single runtime ontology writer. |
| `api/endpoints/admin_endpoints.R:493-513` | Inline `executor_fn` body for `PUT /api/admin/force_apply_ontology`; current durable submission ignores this inline function and routes through the durable `force_apply_ontology` handler. | Opens a direct connection, begins a transaction, disables FK checks, truncates `disease_ontology_set`, appends pending ontology rows, appends inactive compatibility rows for critical old versions, reenables FK checks, then applies auto-fixes. Re-review batch creation remains outside the transaction. | Same unreachable-code problem: no runtime benefit from hardening it, and keeping it would preserve duplicate source for a critical refresh path. | Delete the dead inline `executor_fn` argument from the `create_job()` call. Keep endpoint validation, payload creation, duplicate-job behavior, and response shape unchanged. |
| `api/endpoints/admin_endpoints.R:611-632` | Synchronous admin HGNC endpoint `PUT /api/admin/update_hgnc_data`. | Calls `update_process_hgnc_data()`, then uses `db_with_transaction(function(txn_conn) { ... })`, disables FK checks, truncates `non_alt_loci_set`, inserts HGNC rows with dynamically quoted column names, and reenables FK checks. | `TRUNCATE` auto-commits, so the endpoint's error message claiming the transaction rolled back is false after a truncation. The pooled transaction connection also needs guaranteed FK restoration. | Use the same FK-safety helper around a transactional `DELETE FROM non_alt_loci_set` plus the existing insert loop. Do not change response shape or column handling in this endpoint. |
| `api/functions/async-job-handlers.R:504-510` | Durable worker handler `.async_job_omim_db_write()` used by `omim_update`. | Opens a direct MariaDB connection, begins a transaction, disables FK checks, truncates `disease_ontology_set`, appends new ontology rows, reenables FK checks, applies auto-fixes, and commits. | Active durable worker path can lose ontology rows if a failure occurs after truncation. FK checks are not protected by immediate cleanup. | Replace with the shared transaction-safe ontology helper and return the helper's `auto_fixes_applied` count. |
| `api/functions/async-job-handlers.R:694-706` | Durable worker handler `.async_job_run_force_apply_ontology()` used by `force_apply_ontology`. | Opens a direct connection, begins a transaction, disables FK checks, truncates `disease_ontology_set`, appends pending ontology rows, appends inactive compatibility rows, reenables FK checks, applies auto-fixes, commits, then creates a re-review batch and removes the pending CSV. | Active durable worker path can lose or partially refresh ontology rows despite rollback. FK checks lack immediate cleanup. | Replace the refresh block with the shared ontology helper. Preserve `compat_count`, `auto_fixes_applied`, re-review batch creation, CSV removal, and result fields. |

## MySQL Risk Model

MySQL treats `TRUNCATE TABLE` as DDL. It performs an implicit commit before and
after execution, so it does not participate in `DBI::dbBegin()`,
`DBI::dbWithTransaction()`, or `db_with_transaction()` rollback semantics.
Wrapping `TRUNCATE` in R transaction code therefore gives a false atomicity
signal: a later append, update, or validation failure cannot restore the table
to its pre-refresh state.

`DELETE FROM <table>` is DML for InnoDB tables and participates in the active
transaction. For these metadata tables, a full-table `DELETE` followed by insert
inside one transaction gives the desired all-or-nothing behavior.

`SET FOREIGN_KEY_CHECKS = 0` is session-scoped. Any path that disables it must
register restoration immediately after the disable succeeds:

1. Execute `SET FOREIGN_KEY_CHECKS = 0`.
2. Register `on.exit()` cleanup in the same helper or function frame.
3. Run the transaction work.
4. Explicitly execute `SET FOREIGN_KEY_CHECKS = 1` on success.
5. Let the `on.exit()` fallback restore FK checks on every error path.

This is especially important for pooled connections and long-lived workers.
Disconnecting a direct connection eventually clears session state, but the code
must not depend on disconnect for correctness.

## Strategy Decision

Three approaches were considered.

1. **Delete unreachable inline executor bodies, then use transaction-safe
   `DELETE` plus insert for live paths (recommended).** The current
   `create_job()` facade ignores its `executor_fn` argument, so hardening the
   inline admin executor bodies would spend review effort on dead code. The
   live durable worker handlers and synchronous HGNC endpoint should use the
   safer HGNC pattern from `api/endpoints/jobs_endpoints.R:731-751` and
   `api/functions/async-job-handlers.R:235-247`.

2. **Staging table plus swap.** This is useful for very large tables where a
   full delete would hold locks too long, but it requires DDL such as
   `CREATE TABLE`, `RENAME TABLE`, or `DROP TABLE`. Those statements also
   auto-commit in MySQL and become harder to make rollback-safe. The parent
   tables here are referenced by foreign keys from `ndd_entity` and
   `hgnc_symbol_lookup`, so a physical table swap would also need explicit
   foreign-key/index reconstruction and a maintenance lock design.

3. **Harden the dead inline endpoint executor functions.** This would remove
   the literal unsafe `TRUNCATE` statements, but it would leave two parallel
   ontology refresh implementations in source while only one can run. That is
   more confusing than deleting the unreachable bodies.

The chosen design is approach 1 for all five flagged locations. A staging/swap
pattern is not required for this phase.

## Proposed Design

Add a focused helper module:

- `api/functions/metadata-refresh.R`

Responsibilities:

- Provide `metadata_with_foreign_key_checks_disabled(conn, work)` to disable FK
  checks, immediately register restoration, run a callback, explicitly restore
  FK checks on success, and restore on errors. Restoration failure must be
  visible: log a warning on cleanup failure, and treat success-path restoration
  failure as fatal so pooled connections are not silently returned with
  `FOREIGN_KEY_CHECKS = 0`.
- Provide `refresh_disease_ontology_set(conn, disease_ontology_set_update,
  auto_fixes, compatibility_rows)` to:
  - Disable FK checks through the helper.
  - Run `DBI::dbWithTransaction(conn, { ... })`.
  - `DELETE FROM disease_ontology_set`.
  - Append the new ontology rows when present.
  - Append compatibility rows when present.
  - Apply existing auto-fix updates to `ndd_entity`.
  - Return `list(auto_fixes_applied = <int>, compatibility_rows = <int>)`.

Source the helper through:

- `api/bootstrap/load_modules.R` before endpoints and durable worker handlers
  can use it.
- `api/bootstrap/setup_workers.R` because mirai daemon workers source a
  hand-picked set of files once at startup.

The durable async worker entrypoint already calls `bootstrap_load_modules()`,
so the explicit `start_async_worker.R` path will receive the helper through the
normal function source list before `async-job-handlers.R` is sourced.

Use the helper from:

- `.async_job_omim_db_write()` in `api/functions/async-job-handlers.R`.
- `.async_job_run_force_apply_ontology()` in
  `api/functions/async-job-handlers.R`.

Delete the dead inline `executor_fn` bodies from the admin OMIM and force-apply
job submission routes. Do not replace them with a second helper-backed
implementation; the durable handler registry owns execution.

For the synchronous HGNC endpoint in `api/endpoints/admin_endpoints.R`, keep the
existing `db_with_transaction(function(txn_conn) { ... })` and dynamic insert
loop, but replace `TRUNCATE TABLE non_alt_loci_set` with
`DELETE FROM non_alt_loci_set`. Wrap the delete and insert work in
`metadata_with_foreign_key_checks_disabled(txn_conn, function() { ... })` so FK
checks are restored even if an insert fails.

The existing durable HGNC update path in `api/endpoints/jobs_endpoints.R` and
`api/functions/async-job-handlers.R:235-247` is the safer reference pattern and
does not need production changes in this phase.

## Rollback Expectations

For ontology refreshes:

- If appending the new ontology rows fails, the transaction rolls back and the
  previous `disease_ontology_set` rows remain.
- If compatibility-row append fails, both the new rows and the delete roll back.
- If an auto-fix update fails, ontology rows and `ndd_entity` updates roll back
  together.
- FK checks are restored before the connection is returned, disconnected, or
  reused.
- If FK restoration fails while unwinding a primary error, the primary error is
  preserved and the FK-restore failure is logged as a warning.
- In `.async_job_run_force_apply_ontology()`, remove the outer
  `DBI::dbRollback(sysndd_db)` call after switching to the helper. The helper
  owns the transaction; a rollback with no active transaction can mask the real
  error.

For the synchronous HGNC refresh:

- If any row insert fails after the delete, the `db_with_transaction()` rollback
  restores the previous `non_alt_loci_set` rows.
- The endpoint's existing success and error response shape remains unchanged.
- FK checks are restored before the pooled transaction callback exits.

For force-apply flows:

- The metadata refresh and auto-fixes are atomic.
- Re-review batch creation remains outside the metadata refresh transaction and
  remains non-fatal, matching current behavior.
- Pending CSV removal remains after successful metadata refresh handling.

## Test Strategy

Use TDD in the implementation phase.

1. Add failing helper tests in
   `api/tests/testthat/test-unit-metadata-refresh.R`.
   - Verify FK checks are restored when the callback errors.
   - Verify the ontology helper executes `DELETE FROM disease_ontology_set`,
     appends update and compatibility rows, applies auto-fixes, and never emits
     `TRUNCATE`.
   - Use mocked DBI calls for helper order and error paths, so these tests do
     not write database state.

2. Add failing static guard tests in
   `api/tests/testthat/test-unit-metadata-refresh-patterns.R`.
   - Scan runtime R files for executable `TRUNCATE TABLE disease_ontology_set`
     or `TRUNCATE TABLE non_alt_loci_set` statements.
   - Allow optional backticks around table names.
   - Ignore comments so explanatory text about the risk remains allowed.
   - Assert the admin OMIM and force-apply submission routes no longer keep
     dead inline `executor_fn = function(...)` bodies.

3. Add a real-DB rollback test for the ontology refresh boundary.
   - Seed a minimal set of `disease_ontology_set` and related rows.
   - Trigger a failure after `DELETE FROM disease_ontology_set`, for example by
     making the auto-fix update attempt to store an overlong
     `disease_ontology_id_version`.
   - Assert that the original ontology rows remain after the helper returns an
     error.
   - Assert that `@@FOREIGN_KEY_CHECKS` is `1` after the failure.
   - Use `with_test_db_transaction()` when it works with the helper's internal
     transaction. If nested transaction behavior makes that invalid for
     RMariaDB, document the exception in the test because the test itself must
     verify the production rollback boundary.

4. Add durable async-handler structural tests in
   `api/tests/testthat/test-unit-async-job-handlers.R`.
   - Assert `.async_job_omim_db_write()` delegates to
     `refresh_disease_ontology_set()` and no longer contains manual
     `DBI::dbBegin()`, `DBI::dbCommit()`, or `DBI::dbRollback()`.
   - Assert `.async_job_run_force_apply_ontology()` delegates to
     `refresh_disease_ontology_set()` and no longer calls
     `DBI::dbRollback(sysndd_db)` from the outer error handler.

5. Do not add broad live-network HGNC or OMIM tests. Existing update pipelines
   depend on external providers. This phase should test the database refresh
   boundary, not provider behavior.

Any API integration test that writes application DB state must use
`with_test_db_transaction()` unless the test is explicitly verifying the
production transaction boundary and documents why an outer rollback wrapper
would invalidate that assertion.

## Documentation Requirements

Update durable agent guidance in `AGENTS.md` to say metadata refreshes must not
use `TRUNCATE` inside transaction paths and should name
`refresh_disease_ontology_set()`,
`metadata_with_foreign_key_checks_disabled()`, and the static guard test
`api/tests/testthat/test-unit-metadata-refresh-patterns.R`.

No public frontend docs, SEO docs, API contract docs, or deployment docs are
required because the API surface and operator workflow do not change. If the
implementation discovers an operator-visible behavior change, update
`documentation/08-development.qmd` or `documentation/09-deployment.qmd` in the
same implementation change.

## Verification Requirements

Targeted implementation verification:

- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh-patterns.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-async-job-handlers.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"`
- `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-enrichment-fallback.R')"`

Repository verification:

- `make code-quality-audit`
- `git diff --check`
- `make pre-commit` if host R and Docker prerequisites are available.
- `make ci-local` if the local environment permits the full check. If it does
  not, record the exact missing prerequisite or failing environment condition.

Because worker-executed code is sourced once at worker startup, manual
verification of a running stack must restart the durable worker after changing
`api/functions/async-job-handlers.R` or the new helper.

## Non-Goals

- JWT token-purpose enforcement.
- Query-string error logging redaction.
- Backup/restore credential and exit-code hardening.
- Dev DB port binding changes.
- Production bind-mount cleanup.
- Internet Archive endpoint hardening.
- Temporary password generation changes.
- Frontend typed-client cleanup or UI work.
- Broad refactoring of `api/endpoints/admin_endpoints.R` or
  `api/functions/async-job-handlers.R` beyond the touched refresh paths.
- Rebuilding HGNC symbol lookup semantics or changing current metadata refresh
  provider behavior.
- Introducing a staging/swap refresh architecture for these two metadata
  tables.
