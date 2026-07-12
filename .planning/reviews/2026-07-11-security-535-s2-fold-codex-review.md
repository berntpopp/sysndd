## BLOCKER

- [api/Dockerfile:201](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/Dockerfile:201) attempts `COPY scripts/ scripts/`, but [api/.dockerignore:33](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/.dockerignore:33) excludes the entire directory. The API image build fails because the COPY source is absent from the build context. The Compose bind mount can make the operator command work against an existing image, but does not fix the build or standalone image. Fix: remove the exclusion or re-include the directory/script explicitly.

## HIGH

- [async-job-maintenance-handlers.R:122](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:122) returns `post_restore_scrub`, but it is not reliably observable. The dump covers the entire database, including `async_jobs`; restoring an older dump normally removes the currently running restore-job row. The worker then attempts an UPDATE at [async-job-worker.R:450](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-worker.R:450), gets zero affected rows, and fails at [async-job-worker.R:456](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-worker.R:456). Thus `result_json.post_restore_scrub` is lost after a normal restore. Fix: preserve/recreate the active restore-job record after restoring, or exclude operational job tables from backups/restores with a legacy-dump strategy.

## MEDIUM

- The credential guard remains trivially bypassable. Its pattern at [test-unit-job-payload-credential-guard.R:19](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-job-payload-credential-guard.R:19) recognizes `$password` and only double-quoted `[["password"]]`; `dw[['password']]`, `password = cfg$secret`, or `cfg <- dw; db_config = cfg` evade it. The tripwire at [line 86](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-job-payload-credential-guard.R:86) catches only a literal `dw`. Fix: cover both bracket quote forms and scan payload/config propagation rather than specific variable names, preferably using parsed R expressions.

## LOW

- `setup_workers.R` sources the resolver at [line 122](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/bootstrap/setup_workers.R:122) and the restore handler at [line 134](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/bootstrap/setup_workers.R:134), but not `async-job-payload-scrub.R`; its daemon environment also does not provision global `dw`. If that registered handler is invoked in a mirai daemon, credential resolution or both scrub attempts fail. The current durable-worker entrypoint is correctly sourced through `load_modules`, so this is latent. Fix: remove unreachable durable-handler sourcing from mirai, or source all dependencies and provision runtime config.

- The fresh connection is registered for cleanup immediately at [async-job-maintenance-handlers.R:105](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:105), but an exception from `dbDisconnect()` during `on.exit` can escape the outer error handler and fail an otherwise successful restore. Fix: make disconnect itself best-effort with `tryCatch`.

## Ship readiness

**FIX-FIRST.** The Docker build is blocked, and H2’s result-level observability does not survive the database restore.

## Confirmed fixed

- **H1:** Correct fail-closed unlink and rethrow at [backup-functions.R:230](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:230).
- **H2:** Retry mechanics, fresh connection, WARN, and returned field exist at [async-job-maintenance-handlers.R:97](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:97), but end-to-end observability is not fixed.
- **H3:** Compose mounts, ENVIRONMENT mapping, and runbook are correct; Docker image inclusion is not fixed because of `.dockerignore`.
- **H4:** The frozen 14-line direct-offender multiset matches current direct matches, including the duplicate lines. The regex is valid R, and `trimws()` tolerates reindent/outer whitespace; internal whitespace/comments intentionally break the snapshot. Bypass resistance remains insufficient.
- **M1:** `active_request_hash IS NULL` at [async-job-payload-scrub.R:40](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-payload-scrub.R:40) correctly excludes retryable-failed rows and avoids the unique-index collision.
- **M2:** Real-auth test is DB/client/privilege skip-guarded and cleanup uses deferred `DROP USER` at [test-unit-backup-credential-safety.R:79](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-backup-credential-safety.R:79).
- **M3:** `write_ok` correctly aborts with `success=FALSE` and removes the partial output at [backup-functions.R:345](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:345). Success behavior is unchanged.
- **L1/L2:** Fractional/out-of-range ports are rejected at [async-job-db-config.R:51](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-db-config.R:51); the connector validates through the resolver and does not explicitly echo passwords. Stale mirai comments were corrected. `backup-functions.R` is 573 lines, below the 600-line ceiling.

No tests or services were run. The optional knowledge graph was absent, so the review used the source and diffs directly.