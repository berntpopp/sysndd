# #551 Dead `create_job()` Argument Removal Implementation Plan

**Goal:** Remove the unused `executor_fn` and `timeout_ms` API surface from the durable-job submit facade without changing durable-handler execution.

**Architecture:** `create_job()` only delegates `operation` and `params` to `async_job_service_submit()`. Registered handlers run claimed durable jobs, so every production caller will submit only those two fields. A source-level test will freeze the two-formal contract and reject either dead named argument in a direct production invocation.

## Steps

1. Add the static guard to `api/tests/testthat/test-unit-job-manager-durable.R` and run it while the obsolete formals and calls still exist; it must fail for that reason.
2. Contract `api/functions/job-manager.R` to `create_job(operation, params)`, including its roxygen/example.
3. Remove `executor_fn` closures/`NULL` placeholders and `timeout_ms` values from every direct production submission; preserve each operation and payload exactly.
4. Update test fakes and expectations to model the two-argument API, then rerun the targeted test green.
5. Run diff review, fold any findings with a regression test, and run the required API quality/test gates before committing.
