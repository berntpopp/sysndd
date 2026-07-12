## BLOCKER

None.

## HIGH

- The new job-type “single-flight” is a non-atomic check followed by a separate insert. `async_job_service_duplicate_by_type()` only performs a read at `api/functions/async-job-service.R:449-454`; submissions occur later at `api/functions/async-job-service.R:210-268`. The database uniqueness constraint remains payload-hash based at `db/migrations/020_add_async_job_schema.sql:31-46`. Two concurrent OMIM submissions with different payload hashes—or old/new deployments racing between check and insert—can both enqueue destructive jobs. The unit tests only stub the lookup and do not exercise concurrency at `api/tests/testthat/test-unit-async-job-service.R:138-168`. **Fix:** enforce resource-group single-flight atomically in MySQL, such as a generated active conflict key with a unique index, or acquire a transaction/advisory lock covering lookup plus insert; add a two-connection concurrency test.

- Destructive conflict families remain outside the new mutex. Both `omim_update` and `force_apply_ontology` replace `disease_ontology_set` through `refresh_disease_ontology_set()` at `api/functions/async-job-provider-handlers.R:333-337` and `api/functions/async-job-provider-handlers.R:353-391`, whose implementation deletes the full table at `api/functions/metadata-refresh.R:90-107`. Yet force-apply still uses the broken payload-hash pre-check at `api/endpoints/admin_endpoints.R:126-139`, and a job-type-only OMIM lock would not conflict with a different job type. Likewise, standalone `pubtator_enrichment_refresh` and `pubtatornidd_nightly` both invoke the full enrichment replacement at `api/functions/pubtator-enrichment-collector.R:321-372` and `api/functions/pubtatornidd-nightly.R:200-205`, but only nightly holds its own lock at `api/functions/pubtatornidd-nightly.R:151-158`. **Fix:** define shared conflict groups—at least `disease_ontology_set` and `pubtator_enrichment`—and enforce them atomically at worker execution and/or submission.

## MEDIUM

- The credential guard remains heuristic and its positive checks are file-wide, not handler-scoped. `.expect_resolves_creds()` passes when any function in a file contains the resolver at `api/tests/testthat/test-unit-job-payload-credential-guard.R:43-50`; the negative check only recognizes literal `(payload|params)$db_config` at `api/tests/testthat/test-unit-job-payload-credential-guard.R:93-106`. New leaks such as `cfg <- dw; params = list(config = cfg)`, `password = Sys.getenv(...)`, bracket access, or a renamed payload key evade all checks. The publication regression test has the same whole-file weakness at `api/tests/testthat/test-publication-refresh.R:198-213`. **Fix:** inspect each registered handler body individually, reject direct `DBI::dbConnect`, require the resolver for handlers needing a fresh connection, and parse submission expressions to reject credential-like keys/sources rather than relying on line regexes.

## LOW

- Several comments still describe the removed mirai execution model. Comparisons is documented as a mirai/create-job executor at `api/functions/comparisons-functions.R:16-22` and `api/functions/comparisons-functions.R:239-255`; PubTator claims it is designed for a mirai daemon at `api/functions/pubtator-functions.R:282-299`; the LLM executor says the same at `api/functions/llm-batch-generator.R:207-216`. These functions now depend on `.GlobalEnv$dw` through the durable-worker resolver. **Fix:** document them as durable-worker handlers and remove obsolete mirai-loader entries if no real mirai caller remains.

- Credential removal left unused compatibility formals: `dw` is unused in `svc_admin_ontology_update_async()` at `api/services/admin-ontology-endpoint-service.R:24-26`, `svc_admin_force_apply_ontology_prepare()` at `api/services/admin-ontology-endpoint-service.R:84-85`, and `svc_admin_publication_refresh_submit()` at `api/services/admin-publication-refresh-endpoint-service.R:117-120`. **Fix:** remove these formals and update endpoint/test callers, or explicitly mark them deprecated compatibility arguments.

- The scrub test header still says the scrub is backup-only and single-path at `api/tests/testthat/test-unit-async-job-payload-scrub.R:1-5`, contradicting the test and implementation. **Fix:** update the header to describe family-agnostic, dual-path terminal scrubbing.

- `git diff --check` fails because the added review artifact has trailing whitespace, beginning at `.planning/reviews/2026-07-11-security-535-s2b-plan-codex-review.md:7`. **Fix:** remove the trailing spaces or exclude the review artifact from the commit.

## Confirmed correct

- Repository-wide post-diff searches found no live caller passing removed arguments to `.async_job_omim_db_write`, `.async_job_hgnc_write_db`, `pubtator_db_update_async`, `pubtatornidd_nightly_run`, or synchronous `pubtator_db_update`. Their live calls are updated at `api/functions/async-job-provider-handlers.R:89-92`, `api/functions/async-job-provider-handlers.R:109-114`, `api/functions/async-job-provider-handlers.R:334-337`, `api/functions/pubtatornidd-nightly.R:190-198`, and `api/services/publication-admin-endpoint-service.R:235-240`.

- No production handler still reads `payload$db_config`, `params$db_config`, `db_config$db_password`, or `db_cfg$...`. The migrated connection sites use the resolver, including publication handlers at `api/functions/async-job-maintenance-handlers.R:135-143` and `api/functions/async-job-maintenance-handlers.R:215-223`, force-apply at `api/functions/async-job-provider-handlers.R:380-382`, and comparisons at `api/functions/comparisons-functions.R:277-280`.

- Durable-worker availability is correct: the resolver is loaded before handlers at `api/bootstrap/load_modules.R:64-67`, handler files are sourced before the registry at `api/start_async_worker.R:10-16`, and global `dw` is installed before the worker loop at `api/start_async_worker.R:28-37`. Missing `dw` fails closed without exposing values at `api/functions/async-job-db-config.R:23-58`.

- Empty payloads are supported: `list()` is serialized without payload validation at `api/functions/async-job-service.R:146-160` and hashed/submitted at `api/functions/async-job-service.R:210-268`. `create_job()` ignores `executor_fn` at `api/functions/job-manager.R:43-56`; explicit `NULL` is accepted. In R, an omitted formal also does not error when its promise is never evaluated.

- The active-status extraction preserves the old predicate exactly: queued, running, cancel-requested, and retryable failed rows at `api/functions/async-job-repository.R:169-184`. The new type query is correctly job-type scoped and has no hash predicate at `api/functions/async-job-repository.R:187-208`.

- Existing HGNC/comparisons duplicate responses remain HTTP 409 with `DUPLICATE_JOB` at `api/services/job-maintenance-submission-service.R:126-135` and `api/services/job-maintenance-submission-service.R:177-186`. OMIM preserves its pre-existing `already_running` body at `api/services/admin-ontology-endpoint-service.R:49-55`.

- The scrub SQL uses valid multi-path `JSON_REPLACE`, retains `active_request_hash IS NULL`, and recomputes SHA-256 from the redacted payload at `api/functions/async-job-payload-scrub.R:37-54`. DB tests cover non-backup `db_password` redaction and absent-key behavior at `api/tests/testthat/test-unit-async-job-payload-scrub.R:108-163`.

- The inverted executor/payload assertions check observable captured arguments rather than passing vacuously at `api/tests/testthat/test-unit-job-endpoint-services.R:393-420` and `api/tests/testthat/test-unit-publication-endpoint-services.R:409-433`.

- No touched handwritten source exceeds 600 lines; the largest is `api/functions/async-job-repository.R:596`. The dead synchronous PubTator connection formals were genuinely unused; the function uses the global transaction helper, documented at `api/functions/pubtator-functions.R:39-56`.

- No tests were executed: both the code-quality audit and R startup failed because this environment cannot create temporary files. The new DB scrub and concurrency behavior therefore still require the CI DB lane; no DB PASS is claimed.

## Ship readiness

**FIX-FIRST** — credential removal and caller migration are sound, but the advertised destructive-job single-flight is not atomic and omits conflicting job families.