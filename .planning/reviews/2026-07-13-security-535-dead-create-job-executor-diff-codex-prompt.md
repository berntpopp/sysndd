Review the current working-tree diff for issue #551 as an adversarial senior security/correctness reviewer. This contracts `create_job()` to a durable-submit facade by removing its ignored `executor_fn` and `timeout_ms` arguments, their closures/placeholders, and obsolete test fakes.

Inspect the entire diff plus every `create_job(...)` caller and its registered durable handler. Verify that each handler receives the unchanged payload it needs; no direct or injected alias caller still passes a removed argument; production docs/tests are truthful; the static guard is robust; and no R/Plumber, source-order, `config::get` masking, or file-size regression was introduced. Consider adjacent same-class stale executor/timeout paths. Do not modify files.

Report findings by severity with file/line and a final `Verdict:` line. BLOCKER/HIGH findings are merge blockers; identify cheap MED/LOW improvements separately.
