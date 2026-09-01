# API integration tests: CI schema + the traps that woke up with it

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for this subsystem.

**Integration tests need a schema, and CI now gives them one.** Every
`test-integration-*.R` file guards itself with a `skip_if_missing_*_schema()`
helper that calls `DBI::dbExistsTable()`. CI provisions a real MySQL service
container but an EMPTY one, so all 28 files used to SKIP — silently and
permanently, which is how the entity-rename suite stayed dormant long enough to
hide two production defects (#638). `api/scripts/ci-load-test-schema.R` now
applies the project's own migrations before the test step in all three R jobs.
It is not a mock: the same 51 migrations the API runs at startup, on the same
`mysql:8.4.8` image, verified as the unprivileged service user under MySQL 8.4's
**default** `sql_mode` — a GitHub Actions service container cannot override the
server command line. It is idempotent and fails loudly rather than letting a
half-loaded database report a wall of skips as success.

Locally, `make test-db-schema` runs the same script against `config.yml`'s
`sysndd_db_test`. If it reports far fewer tables than expected, `schema_version`
records migrations whose tables do not exist (a database built ad hoc rather than
by the runner) — drop and recreate that database and re-run.

**Waking those tests up broke them in ways unrelated to the code under test**,
and the errors do not name their causes. `.agents/skills/sysndd-api-testing/SKILL.md`
carries the full list with each trap's tell; the two that reach beyond tests:

- **A destructive teardown must register its restore BEFORE the destructive
  step**, never after the assertions — an expectation failure aborts the block,
  and a teardown registered later simply never runs. A migration test that
  drops its tables to re-apply its migration and then leaves them dropped
  destroys shared schema for **every later file in the run and every subsequent
  run**, because nothing puts it back. Restore through the real migration runner
  (clear exactly those `schema_version` rows, re-apply, then VERIFY and fail
  loudly naming the gap): the migration under test is usually not the whole
  current shape, e.g. `047` creates `variation_ontology_evidence` but `049` adds
  its `origin_review_id`.
- **`db_with_savepoint_or_transaction()` is NOT the fix for
  "Nested transactions not supported" in a test.** It is correct only where the
  caller genuinely owns an open transaction. `refresh_disease_ontology_set()`
  and `analysis_snapshot_refresh()` are handed a raw, autocommit connection in
  production (`async_job_db_connect()`, or a pool checkout), and a `SAVEPOINT`
  on such a connection silently buys **no atomicity at all** — swapping it in to
  make a test pass would quietly remove the rollback that a half-rebuilt
  `disease_ontology_set` depends on. Fix the test instead: drop the outer
  `with_test_db_transaction()` and clean up explicitly (documenting why), or
  stub the thin BEGIN/COMMIT seam when the transaction is not what is under
  test.

A test must also never depend on another test's residue: `test-integration-mondo-index.R`
skipped unless some *other* file had leaked an `OMIM:618524` row into
`disease_ontology_set`, so it passed for the wrong reason and went silent the
moment that leak was fixed. Seed what you need inside your own rollback.
