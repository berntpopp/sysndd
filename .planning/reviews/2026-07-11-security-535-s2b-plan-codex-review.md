## BLOCKER

None.

## HIGH

- Task 7 misses a guaranteed failing PubTator test. The plan removes the inline `executor_fn` from `svc_publication_pubtator_update_submit()` at `api/services/publication-admin-endpoint-service.R:321-360`, but `api/tests/testthat/test-unit-publication-endpoint-services.R:414-415` requires and evaluates that argument, while `:427-431` explicitly asserts it remains a function. That test file is absent from Task 7, and its contents do not match Task 7’s grep terms, so the generic grep will not discover it.  
  **Fix:** add `test-unit-publication-endpoint-services.R` explicitly; make the fake accept `executor_fn = NULL` or `...`, assert the executor is absent/NULL, and assert `params` contains no `db_config`.

- Task 8’s existing scrub test will fail after the proposed SQL rewrite. `api/tests/testthat/test-unit-async-job-payload-scrub.R:14` requires the backup-only `job_type` predicate, and `:20` requires that `db_password` not occur. The proposed statement intentionally violates both assertions, yet the plan only says to extend the tests and claims the pre-existing tests will pass.  
  **Fix:** replace/rename the statement-shape test at `:11-21`, removing both obsolete assertions and positively checking job-type independence and both paths.

- The frozen guard currently does not parse, invalidating every intermediate RED/GREEN step in Tasks 1–5. Commas are missing after the strings at `api/tests/testthat/test-unit-job-payload-credential-guard.R:67`, `:68`, and `:70`. The plan removes those entries only in Tasks 5–6, so the prescribed per-family green commits cannot occur.  
  **Fix:** repair the commas before Task 1, or replace the whole expected vector atomically and stop claiming intermediate green commits.

- The plan overlooks an active-job hash transition that can permit concurrent destructive maintenance jobs during deployment. `request_hash` is derived from the serialized payload at `api/functions/async-job-service.R:232-245`, and uniqueness applies to `(job_type, active_request_hash)` at `db/migrations/020_add_async_job_schema.sql:31-46`. Changing HGNC/comparisons from credential-bearing payloads (`api/services/job-maintenance-submission-service.R:150-152`, `:339-341`) to `list()` changes their hashes; an active pre-deploy job therefore does not dedupe against a post-deploy submission. The HGNC pre-check hashes `list(operation = "hgnc_update")` at `api/services/job-maintenance-submission-service.R:133-136`, so it does not close this gap. Concurrent HGNC jobs both replace `non_alt_loci_set` through the write path beginning at `api/functions/async-job-provider-handlers.R:22-31`.  
  **Fix:** add a deploy drain/single-flight step before accepting new submissions, or make maintenance-family dedupe job-type-based across payload-schema versions. Run the scrub after old jobs become terminal.

## MEDIUM

- The proposed “positive guarantee” is too weak to cover the two-level consume sites. A file-level `grepl("async_job_db_connect\\(")` passes if any handler in the file uses the resolver. `async-job-maintenance-handlers.R` already contains such a call at `api/functions/async-job-maintenance-handlers.R:110`, so it cannot prove the publication connects at `:141-148` and `:224-231` were migrated. Likewise, one migrated handler in `async-job-provider-handlers.R` could mask an unchanged force-apply connect at `api/functions/async-job-provider-handlers.R:389-397`.  
  **Fix:** assert against each handler body, require `async_job_db_connect(` there, and forbid `payload$db_config`, `params$db_config`, and direct `DBI::dbConnect` in that body.

- Task 8 does not behavior-test its new scope. The existing DB test exercises only a `backup_create` row with `$.db_config.password` at `api/tests/testthat/test-unit-async-job-payload-scrub.R:23-50`. The proposed new test merely searches the SQL string, so it would not demonstrate that a non-backup `$.db_config.db_password` row is actually redacted and hashed correctly.  
  **Fix:** add an integration test using, for example, terminal `llm_generation` and `pubtator_update` rows with `db_password`; verify redaction, hash recomputation, idempotency, and that queued/retryable rows remain untouched.

- Task 7’s resolver-mocking guidance is technically wrong. `async_job_worker_db_config()` looks only in `.GlobalEnv` with `inherits = FALSE` at `api/functions/async-job-db-config.R:26-30`; assigning `dw` “in a local env” will not satisfy it. This can turn handler unit tests into unexpected “runtime config unavailable” failures.  
  **Fix:** either temporarily assign/restore `dw` in `.GlobalEnv`, or source handlers into an isolated environment and replace `async_job_db_connect` in that exact lexical environment.

- Several touched source comments will become materially false even though the top-level docs are updated. Examples include the payload-credential contract in `api/services/job-maintenance-submission-service.R:13-26`, comparisons’ `db_config` parameter documentation at `api/functions/comparisons-functions.R:242-254`, the mirai/`db_config` contract at `api/functions/pubtator-functions.R:283-303`, and the publication handler’s `payload$db_config` description at `api/functions/async-job-maintenance-handlers.R:213-216`.  
  **Fix:** include these comments/roxygen blocks in the corresponding family tasks.

## LOW

- The HGNC dead-closure line range is misleading. The credential-bearing closure starts at `api/services/job-maintenance-submission-service.R:154` and ends at `:282`; `:187-193` is only its connection block. An implementer following the cited range literally could leave a syntactically or semantically broken closure.  
  **Fix:** state explicitly that lines `154-282` are removed as one argument expression.

- Task 7 says `test-unit-pubtator-functions.R` calls `pubtator_db_update_async`, but it only locates the function boundary textually at `api/tests/testthat/test-unit-pubtator-functions.R:129-130`. This is harmless but indicates the test inventory was not derived from actual calls.  
  **Fix:** distinguish direct callers from source-shape tests in the plan.

- `pubtatornidd_nightly_run()` retains an injected `dw_config` formal at `api/functions/pubtatornidd-nightly.R:135`, but after the proposed edit the argument becomes unused and the nested update resolves `.GlobalEnv$dw` instead. Production is safe because `pubtatornidd_nightly_job_run()` verifies and passes global `dw` at `:277-288`, but the injection seam becomes misleading.  
  **Fix:** either remove the formal and update its sole caller, or explicitly document that it remains compatibility-only.

## Confirmed correct

- All 14 actual scan offenders are classified correctly:

  - Ontology submit: `api/services/admin-ontology-endpoint-service.R:20-29`, consumed by OMIM at `api/functions/async-job-omim-apply.R:4-13`.
  - HGNC submit/consume: `api/services/job-maintenance-submission-service.R:125-152`; `api/functions/async-job-provider-handlers.R:22-30`.
  - Comparisons submit/consume: `api/services/job-maintenance-submission-service.R:314-341`; `api/functions/comparisons-functions.R:259-286`.
  - Publication refresh/backfill submits: `api/services/admin-publication-refresh-endpoint-service.R:110-119`, `:178-184`; `api/endpoints/admin_publications_endpoints.R:50-63`.
  - PubTator sync dead args, async submit, consume, and nightly in-process marshal: `api/services/publication-admin-endpoint-service.R:235-245`, `:308-360`; `api/functions/pubtator-functions.R:303-344`; `api/functions/pubtatornidd-nightly.R:189-203`.
  - LLM submit/consume: `api/functions/llm-batch-generator.R:176-218`, `:283-313`.

- The four non-frozen two-level consume sites are complete: `api/functions/async-job-omim-apply.R:46-54`, `api/functions/async-job-provider-handlers.R:389-397`, and `api/functions/async-job-maintenance-handlers.R:141-148`, `:224-231`. No additional `db_config` credential reader was found in `functions/`, `services/`, or `endpoints/`.

- Durable execution is in-process. `api/start_async_worker.R:1-16` loads the durable worker directly and never sources `setup_workers.R`; global `dw` is installed at `:18-34`. Dispatch calls `handler$run(...)` directly at `api/functions/async-job-worker.R:420-448`. The relevant types are explicitly registered at `api/functions/async-job-handlers.R:263-341`.

- The migrated direct connections use only the resolver’s supported five arguments. Ontology additionally supplies `server` at `api/functions/async-job-omim-apply.R:10` and `api/functions/async-job-provider-handlers.R:394`, but no site uses `bigint`, local-infile flags, timeouts, or other connection options. The resolver supplies the canonical five at `api/functions/async-job-db-config.R:70-76`.

- Signature-call mapping is complete:

  - `.async_job_omim_db_write()` has one live caller at `api/functions/async-job-provider-handlers.R:342-346`.
  - `.async_job_hgnc_write_db()` has one live caller at `api/functions/async-job-provider-handlers.R:95-99`.
  - `pubtator_db_update_async()` has two live named callers at `api/functions/async-job-provider-handlers.R:116-122` and `api/functions/pubtatornidd-nightly.R:197-203`, plus the dead closure at `api/services/publication-admin-endpoint-service.R:340-346`. No positional caller passes `db_config` first.

- Empty payloads are supported. `async_job_service_payload_json()` serializes arbitrary lists at `api/functions/async-job-service.R:146-159`; the resulting scalar JSON is hashed at `:162-171` and inserted at `:232-252`. Empty payloads therefore produce a stable per-job-type hash, and the generated active hash/unique index handles duplicate new submissions.

- The proposed scrub SQL is valid in structure: `JSON_REPLACE` is appropriate because absent paths must not be created; removing the job-type filter is safe for terminal rows because `active_request_hash IS NULL` excludes every row participating in the unique active-hash index defined at `db/migrations/020_add_async_job_schema.sql:31-46`.

- The persisted path split is accurate: canonical families store `$.db_config.password`; PubTator stores `db_password` at `api/services/publication-admin-endpoint-service.R:310-328`, and LLM stores it at `api/functions/llm-batch-generator.R:178-210`. The nightly `db_password` at `api/functions/pubtatornidd-nightly.R:189-203` is only in-process.

- After all planned offender removals, the credential scan should return `character(0)`; no additional one-level match exists outside the resolver/helper exclusions at `api/tests/testthat/test-unit-job-payload-credential-guard.R:27-40`. The current parse defect must still be fixed.

- Dead closure removal is behaviorally safe because `create_job()` ignores `executor_fn` and `timeout_ms`, forwarding only `operation` and `params` at `api/functions/job-manager.R:43-47`.

- All touched handwritten source files are currently below 600 lines; the largest are `comparisons-functions.R` at 563, `pubtator-functions.R` at 562, and `llm-batch-generator.R` at 549. The planned edits shrink them.

- The top-level documentation flip targets the correct locations: `AGENTS.md:92-96` and `documentation/09-deployment.qmd:35-65`.

## Ship readiness

**FIX-FIRST** — the migration design is sound, but the plan as written guarantees multiple test failures and lacks a safe transition for active jobs whose request hashes change.