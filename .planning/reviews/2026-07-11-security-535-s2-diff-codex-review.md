Static review only; no tests or services run.

## BLOCKER

None.

## HIGH

1. Option-file write failures can leave a partial password on disk.  
   [.backup_write_option_file():212](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:212) registers no unlink inside the builder. If [writeLines():227](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:227) partially writes and throws (disk/full I/O error), the function never returns, so caller cleanup at [283-284](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:283) or [489-490](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:489) is never installed. H1 is therefore not fully fail-closed.  
   Fix: register `on.exit(unlink(path), add=TRUE)` immediately after successful `file.create()`, and cancel that cleanup only after `writeLines()` completes successfully.

2. Post-restore scrub failure is swallowed while the restore is reported completed.  
   [.async_job_run_backup_restore():91-102](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:91) catches every scrub error, logs a message, then returns `status="completed"`. A restored old dump can therefore reintroduce passwords, encounter a stale pool/schema/SQL failure, and still appear fully successful. H5’s ordering landed, but its security outcome is not enforced.  
   Fix: retry using a fresh runtime-config connection; if scrubbing still fails, propagate a classed error or return an explicit `restore_completed_scrub_failed` result that cannot be mistaken for full completion.

3. The documented operator scrub command cannot run in the API container as built.  
   The new script is invoked at [documentation/09-deployment.qmd:56](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/documentation/09-deployment.qmd:56), but the production image copies no `scripts/` directory at [api/Dockerfile:194-203](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/Dockerfile:194), and the API service mounts no scripts directory at [docker-compose.yml:143-160](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/docker-compose.yml:143). It will fail with “file not found.”  
   Additionally, [scrub-job-payload-credentials.R:16](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/scripts/scrub-job-payload-credentials.R:16) reads `API_CONFIG` without deriving it from `ENVIRONMENT`; Compose passes only `ENVIRONMENT` at [docker-compose.yml:161-166](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/docker-compose.yml:161).  
   Fix: copy/mount `api/scripts` into the API container and share the API/worker environment-selection helper rather than calling `config::get(Sys.getenv("API_CONFIG"))` directly.

4. H4’s claimed “new offender” guard is bypassable.  
   The regex at [test-unit-job-payload-credential-guard.R:13-20](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-job-payload-credential-guard.R:13) only recognizes assignments shaped like `password = x$password`. New leaks such as `params=list(db_config=dw)`, `password=dw[["password"]]`, `credentials=build_config(dw)`, or positional arguments pass undetected. File-level counts at [46-63](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-job-payload-credential-guard.R:46) also pass if one old match is removed while one new leak is added in the same file.  
   Fix: parse `create_job()`/`async_job_service_submit()` calls and freeze exact file + enclosing function + credential-expression tuples. Add explicit mutation fixtures proving each bypass form fails.

## MEDIUM

1. `failed` does not necessarily mean terminal, contrary to the scrub’s invariant.  
   The scrub includes every failed row at [async-job-payload-scrub.R:35-38](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-payload-scrub.R:35), but `active_request_hash` remains non-NULL for retryable failed rows at [020_add_async_job_schema.sql:31-39](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/db/migrations/020_add_async_job_schema.sql:31). Two historical retryable rows that differ only by password can converge to the same redacted hash, hit the unique index, and roll back the entire scrub.  
   Fix: retain B1’s status predicate but additionally require `active_request_hash IS NULL`, or explicitly drain/terminalize retries before scrubbing.

2. The real-client test proves acceptance, not correct password parsing.  
   [test-unit-backup-credential-safety.R:60-74](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-backup-credential-safety.R:60) passes if the client emits any `--password` option, even if quote/backslash decoding changes the value. It does not authenticate with the special-character password or compare the parsed value.  
   Fix: use a transaction-scoped temporary DB account and perform a real connection, or parse `--print-defaults` and assert the exact recovered password without printing it on failure.

3. Existing dump-write error handling can report a partial dump as successful.  
   The result of `tryCatch(writeLines(...))` at [backup-functions.R:333-340](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:333) is ignored. If writing partially succeeds and then throws, a nonempty partial file can pass later existence/size checks and be compressed as a valid backup.  
   Fix: make the write return a success flag or return the error from the enclosing function; remove partial output on failure.

## LOW

1. Port validation silently truncates fractional numeric values.  
   [async-job-db-config.R:51-55](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-db-config.R:51) accepts `3306.9` as `3306`, despite claiming to validate an integer.  
   Fix: reject values whose numeric representation is not exactly integer-valued and within `1:65535`.

2. Backup service documentation still describes deleted mirai closures.  
   [backup-endpoint-service.R:15-17](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/services/backup-endpoint-service.R:15) and [126-127](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/services/backup-endpoint-service.R:126) contradict the durable-handler implementation.  
   Fix: update comments to describe durable submission and worker dispatch.

## Corrections to apply

1. Make `.backup_write_option_file()` internally clean up every post-create failure.
2. Do not report restore completion when credential scrubbing failed.
3. Package/mount the operator script and resolve its config exactly like API startup.
4. Replace the regex/count guard with parsed submit-call assertions and adversarial fixtures.
5. Exclude retryable `failed` rows from the scrub or handle active hashes explicitly.
6. Strengthen the real-client test to prove exact password semantics.
7. Correct dump-output write error propagation.
8. Tighten port validation and remove stale mirai documentation.

## Confirmed correct

- B1’s requested job-type and status predicates are present at [async-job-payload-scrub.R:35-38](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-payload-scrub.R:35), subject to the retryable-failed caveat above.
- B2 is explicitly backup-scoped and S2b is deferred at [documentation/09-deployment.qmd:65-67](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/documentation/09-deployment.qmd:65).
- Pre-secret permission handling uses umask `0077`, checks creation, and verifies group/other bits before writing at [backup-functions.R:212-227](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:212).
- Quote and backslash escaping is exact for double-quoted MySQL option values at [backup-functions.R:194-205](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:194). Backticks, `$`, brackets, `=` and spaces require no additional escaping there.
- `--defaults-extra-file` is first for both clients at [backup-functions.R:231-260](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:231).
- Passwords are absent from mysqldump argv and restore shell text. Captured stderr can expose authentication failure text or the option-file path, but not its contents.
- Once the option-file builder returns, caller `on.exit()` cleanup covers normal returns and R errors; stacking with stderr cleanup is sound.
- H3 landed: durable-handler tests cover pre-backup ordering, abort-before-restore, and stub progress at [test-unit-async-job-maintenance-handlers.R:16-87](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/tests/testthat/test-unit-async-job-maintenance-handlers.R:16).
- H5’s scrub call is positioned before completion reporting at [async-job-maintenance-handlers.R:91-105](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-maintenance-handlers.R:91).
- H6 landed in the same UPDATE at [async-job-payload-scrub.R:31-38](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-payload-scrub.R:31). JSON canonicalization differences do not affect terminal-row execution semantics.
- M1 landed: resolver sourcing is present in both loaders at [load_modules.R:64-67](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/bootstrap/load_modules.R:64) and [setup_workers.R:118-134](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/bootstrap/setup_workers.R:118); lookup uses qualified `base::exists/get` at [async-job-db-config.R:23-31](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-db-config.R:23). The durable worker assigns `dw` before entering its run loop. Mirai daemons do not receive `dw`, but no current backup execution path dispatches there.
- M2 landed: restore host/user/database are `shQuote()`d and port is coerced at [backup-functions.R:248-260](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/backup-functions.R:248).
- M5 landed: one UPDATE produces a distinct affected-row count at [async-job-payload-scrub.R:44-48](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-payload-scrub.R:44).
- `create_job()` still requires `executor_fn`, but `NULL` is valid because it is unused at [job-manager.R:43-47](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/job-manager.R:43).
- Backup registry dispatch remains intact at [async-job-handlers.R:313-321](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/functions/async-job-handlers.R:313).
- Startup scrub runs after pool creation at [start_sysndd_api.R:89-97](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/start_sysndd_api.R:89) and [154-159](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s2-secrets-out-of-jobs/api/start_sysndd_api.R:154).
- All changed handwritten source files remain below the 600-line soft ceiling; the largest is `backup-functions.R` at 555 lines.