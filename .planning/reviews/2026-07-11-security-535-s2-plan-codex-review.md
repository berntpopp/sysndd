## BLOCKER

1. The historical scrub breaks deferred S2b jobs.

   The proposed scrub targets every row and all generic credential paths ([plan:441](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:441>)), while deferred handlers still require `payload$db_config$password`, including publication refresh ([async-job-maintenance-handlers.R:104](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:104>)), publication backfill ([async-job-maintenance-handlers.R:185](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:185>)), and provider handlers ([async-job-provider-handlers.R:393](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-provider-handlers.R:393>)). Any queued/retryable job scrubbed before S2b will fail.

   Fix: for S2, restrict scrub SQL to `job_type IN ('backup_create','backup_restore')`. Scrub other families only when their consumers migrate. Stop/drain both workers before deployment scrub.

2. The stated acceptance criterion is not met if P1-1 means all durable jobs.

   The plan explicitly admits remaining credential-bearing durable submissions ([plan:24-26](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:24>)), while its self-review claims coverage of “Remove database credentials from durable jobs” ([plan:595-597](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:595>)). Concrete remaining submitters include publication backfill ([admin_publications_endpoints.R:50](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/endpoints/admin_publications_endpoints.R:50>)), LLM generation ([llm-batch-generator.R:207](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/llm-batch-generator.R:207>)), HGNC/comparisons ([job-maintenance-submission-service.R:121](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/services/job-maintenance-submission-service.R:121>)), ontology ([admin-ontology-endpoint-service.R:71](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/services/admin-ontology-endpoint-service.R:71>)), and PubTator ([publication-admin-endpoint-service.R:308](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/services/publication-admin-endpoint-service.R:308>)).

   Fix: either include S2b in this implementation or obtain an explicitly backup-family-scoped acceptance criterion. Do not claim repository-wide durable-job compliance.

## HIGH

1. Mode 0600 is not fail-closed.

   `.backup_write_option_file()` ignores the return values of both `file.create()` and `Sys.chmod()` before writing the secret ([plan:114-119](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:114>)). `file.create()` initially uses permissions allowed by the process umask; ordinarily that is 0644. The file is empty during the create/chmod interval, so no secret is exposed if chmod succeeds, but a failed chmod followed by `writeLines()` can expose it.

   Fix: create under a temporary `Sys.umask("0077")`, restore the prior umask with `on.exit`, check every return value, verify `(mode & 077L) == 0`, then write. Abort and unlink on any failure. `Sys.chmod(..., use_umask = FALSE)` itself is a valid R call ([R documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/files2.html)).

2. The special-character option-file tests will fail and do not validate parsing.

   The fixture contains `"` and `\` ([plan:52-53](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:52>)), but the test expects the unescaped raw password to appear contiguously after escaping ([plan:76-87](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:76>)). It will not.

   Fix: assert the exact escaped body and add a real client integration check using a temporary DB user/password containing `#`, space, `"`, and `\`. MariaDB 10.11 is the actual Noble client behind `default-mysql-client` ([Dockerfile:21-24](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/Dockerfile:21>), [Ubuntu package](https://packages.ubuntu.com/noble/mariadb-client)); its documented escapes include `\"` and `\\` ([MariaDB option-file syntax](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/configuring-mariadb-with-option-files)). The proposed escaping is conceptually correct, but the test is not.

3. Removing closure tests drops the restore safety contract without replacing it.

   The current tests prove pre-backup-before-restore and abort-on-pre-backup-failure ([test-unit-backup-endpoint-service.R:334](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-backup-endpoint-service.R:334>), [test-unit-backup-endpoint-service.R:355](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-backup-endpoint-service.R:355>)). The replacement example tests only backup creation ([plan:365-377](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:365>)).

   It also omits a stub for `.async_job_progress_reporter`, so sourcing only the two listed files will fail at the handler’s first statement.

   Fix: sandbox the maintenance handler with resolver, progress reporter, dump, and restore stubs. Preserve both restore-ordering and pre-backup-failure tests against `.async_job_run_backup_restore()`.

4. The static guard does not enforce its stated invariant.

   It scans only `api/services`, so it misses the direct endpoint submission at [admin_publications_endpoints.R:50](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/endpoints/admin_publications_endpoints.R:50>) and function-based LLM submission at [llm-batch-generator.R:207](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/llm-batch-generator.R:207>). Entire-file allowlisting ([plan:549-558](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:549>)) also permits unlimited new leaks inside known files.

   Fix: scan `functions/`, `services/`, and `endpoints/`; allowlist exact file/function/credential-expression tuples and assert the exact offender set. Prefer parsing calls to `create_job()` and `async_job_service_submit()` over raw whole-file regex.

5. Restoring an old backup can reintroduce scrubbed credentials.

   Restore imports the whole SQL dump ([backup-functions.R:393-445](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:393>)). Old backups can contain credential-bearing `async_jobs` rows. The scrub runs only at API startup ([plan:499-503](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:499>)), not after restore.

   Fix: run the backup-scoped scrub immediately after successful restore, before reporting completion. Rotation remains mandatory because old backup files cannot safely be rewritten in place.

6. Redacting JSON leaves a password-derived verifier.

   `request_hash` is SHA-256 over job type plus the original payload JSON ([async-job-service.R:162-170](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-service.R:162>)); it remains after JSON redaction. For predictable payloads, it permits offline guessing of the former password.

   Fix: for scrubbed terminal backup jobs, recompute `request_hash` from the redacted payload. Handle `active_request_hash`/unique-index implications explicitly for active rows, preferably after draining workers.

## MEDIUM

1. The resolver is absent from the mirai source list.

   Durable execution does run in the same process where `dw` is assigned: `dw` is global at [start_async_worker.R:28](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/start_async_worker.R:28>), and the worker invokes `handler$run()` directly at [async-job-worker.R:443](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-worker.R:443>). However, mirai also sources maintenance handlers ([setup_workers.R:128-133](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/bootstrap/setup_workers.R:128>)), and the plan does not source the resolver there.

   Also, the claim to place it “before async-job-maintenance-handlers.R” in `load_modules.R` is inaccurate: that loader does not contain the maintenance handler; `start_async_worker.R` sources it separately at line 14.

   Fix: source the resolver immediately before maintenance handlers in both `start_async_worker.R`/shared loader flow and `setup_workers.R`, or remove durable-handler loading from mirai if it is intentionally unsupported. Use `base::exists/base::get(..., envir=.GlobalEnv)` for deterministic lookup.

2. The restore shell still interpolates unquoted runtime fields.

   The proposed builder quotes paths but not host, user, or database ([plan:135-145](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:135>)). These are operator-controlled rather than request-controlled, but retaining unquoted shell interpolation is unnecessary.

   Fix: `shQuote()` every shell token, validate port as an integer, or replace the shell composition with a process API/pipeline.

3. The scrub test’s idempotency assertion is tautological.

   Every statement contains `REDACTED` in `JSON_SET`, so the right side of the `|` makes the assertion pass even without the `<> sentinel` guard ([plan:412-422](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:412>)).

   Fix: assert the exact `WHERE` predicate per path and add a transaction-isolated MySQL test that proves first run changes one row and second run changes zero.

4. The proposed live scrub check is invalid SQL for this schema.

   It omits required `request_hash` and refers to nonexistent `created_at` ([plan:509-515](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:509>)). The schema requires `request_hash` and uses `submitted_at` ([020_add_async_job_schema.sql:10-13](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/db/migrations/020_add_async_job_schema.sql:10>)).

   Fix: insert all required columns or use `async_job_service_submit()` inside `with_test_db_transaction()`.

5. The reported scrub count is not distinct rows.

   `db_execute_statement()` correctly returns affected rows ([db-helpers.R:308-313](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/db-helpers.R:308>)), but summing three UPDATE results counts a row once per matching path. The log’s “payload row(s)” claim is therefore false.

   Fix: use one `UPDATE` with nested `JSON_SET`, or report “credential fields redacted”; if distinct rows are required, identify targets once.

## LOW

1. Option files can survive abnormal worker termination.

   `on.exit(unlink())` handles normal returns and R errors, but not SIGKILL/container crash. The residual file remains 0600, limiting exposure.

   Fix: place files under a dedicated private directory and remove stale `mysql_opt_*.cnf` files on worker startup.

2. The resolver does not validate required fields.

   Null/empty password, host, or port values will fail later with less useful CLI errors ([plan:243-258](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md:243>)).

   Fix: validate five scalar fields and integer port in the resolver without including credential values in errors.

3. Existing `latest.*` symlinks remain accepted by download and restore.

   Listing excludes symlinks ([backup-functions.R:48-55](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:48>)), but filename validation only rejects separators/extensions ([backup-functions.R:469-476](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:469>)). This is not a password leak by itself, but preserves a symlink-following surface.

   Fix: resolve and verify the canonical target remains under `/backup`, or consistently reject symlinks for restore/download.

## Confirmed points

- `--defaults-extra-file` is supported by the installed MariaDB client family and must be the first argument. The proposed argument ordering is correct ([MariaDB documentation](https://mariadb.com/docs/server/clients-and-utilities/mariadb-client/mariadb-command-line-client), [MySQL documentation](https://dev.mysql.com/doc/refman/8.4/en/option-file-options.html)).
- Quoted option-file values correctly protect spaces and `#`; escaping `"` and `\` is required and supported.
- `create_job()` syntactically requires `executor_fn` and defaults only `timeout_ms` ([job-manager.R:43](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/job-manager.R:43>)). Passing `executor_fn = NULL` works because both arguments are ignored; only `operation` and `params` are submitted ([job-manager.R:44-47](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/job-manager.R:44>)).
- Backup jobs are durable-dispatched registry entries ([async-job-handlers.R:313-321](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-handlers.R:313>)); deleting the endpoint closures does not remove live execution.
- The native JSON column claim is correct ([020_add_async_job_schema.sql:11](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/db/migrations/020_add_async_job_schema.sql:11>)). `JSON_SET` plus `JSON_UNQUOTE(JSON_EXTRACT(...)) <> sentinel` is idempotent for scalar paths.
- The startup wrapper’s `tryCatch` prevents scrub failure from crashing boot. Placement after migrations/pool creation is appropriate ([start_sysndd_api.R:89-98](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/start_sysndd_api.R:89>)).
- No new numbered migration is needed; current manifest latest is 042 ([migration-manifest.R:5](</home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/migration-manifest.R:5>)).
- `source_api_file()` and `../../services` are established test-harness patterns. `testthat` 3.3.2 provides `local_mocked_bindings`.
- Projected touched-file sizes remain below 600 lines if the executor block is removed. The closest existing files are the backup service test at 570 and worker at 573; the plan does not enlarge the worker.

## Corrections to apply before implementation

1. Restrict S2 scrubbing to backup job types and add post-restore scrubbing.
2. Resolve whether P1-1 requires all durable families; otherwise narrow the acceptance wording explicitly.
3. Make option-file creation fail-closed under umask 0077 and test actual client parsing.
4. Preserve restore-order/failure tests against the durable handler and stub progress correctly.
5. Replace the broad allowlist with an exact repository-wide offender-set guard.
6. Address password-derived `request_hash` values during historical cleanup.
7. Source the resolver consistently in durable and mirai environments.
8. Fix the invalid live scrub fixture and test idempotency against MySQL.