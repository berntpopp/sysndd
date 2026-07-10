# Refactor #346 Wave 4 API Services and Workers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce every remaining oversized API service/function/worker source file below 600 lines while preserving transactions, source order, handler registration, queue semantics, external budgets, and public behavior.

**Architecture:** Split only cohesive function families. Runtime bootstrap explicitly loads each extracted module before its consumer; direct-source tests receive corresponding fixtures rather than relying on accidental globals. Service functions retain `svc_`/`service_` prefixes, and worker registry ownership remains centralized.

**Tech Stack:** R, Plumber services, DBI/MySQL transactions, durable async jobs, testthat, Docker workers, SysNDD bootstrap.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

Create each service-domain branch only after its predecessor is merged, using fresh
master and the branch names below:

```bash
git switch master
git pull --ff-only origin master
git switch -c "$TASK_BRANCH"
```

```text
Task 1   refactor/346-w4-module-guards
Task 2   refactor/346-w4-entity-services
Task 3   refactor/346-w4-rereview-services
Task 4   refactor/346-w4-async-handlers
Task 5   refactor/346-w4-async-repository
Task 6   refactor/346-w4-endpoint-functions
Task 7   refactor/346-w4-llm-prompts
Task 8   refactor/346-w4-migration-state
Task 9   refactor/346-w4-nddscore-import
Task 10  refactor/346-w4-omim-functions
```

Each task is its own reviewed/merged PR. Domain agents return runtime-registration
requirements; the integration owner alone edits the four shared source lists inside the
same domain PR. Domain PRs do not edit the size baseline.

### Task 1: Add module/source-order characterization

**Files:**
- Create: `api/tests/testthat/test-unit-api-module-registration.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/bootstrap/setup_workers.R`
- Modify: `api/start_async_worker.R`
- Modify: `api/functions/async-job-worker.R`
- Modify: `api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R`

The integration owner executing Task 1 is the sole writer for these four runtime source
lists. Domain agents return ordered registration requirements and treat every `Verify:`
entry as read-only: they must not edit, stage, or commit it.

- [ ] Parse `bootstrap/load_modules.R` and assert exact-once, dependency-ordered entries
  for every module named in this plan. Assert service bindings remain prefixed and do
  not collide with repository bindings.
- [ ] Parse `start_async_worker.R`, `functions/async-job-worker.R`, and
  `bootstrap/setup_workers.R`; assert extracted handler files appear before
  `async-job-handlers.R`, async repository helpers appear before the repository,
  NDDScore source before import, and OMIM download/parser before the OMIM shell in every
  runtime that uses them.
- [ ] Run both tests before adding modules; expected new-registration assertions fail.
- [ ] Commit as `test(api): characterize module and worker source order (#346)`.

### Task 2: Split entity creation and rename services

**Files:**
- Create: `api/services/entity-creation-service.R` (target ≤380)
- Create: `api/services/entity-rename-service.R` (target ≤310)
- Modify: `api/services/entity-service.R` (target ≤460)
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-unit-entity-service.R`
- Modify: `api/tests/testthat/test-unit-entity-creation.R`
- Modify: `api/tests/testthat/test-integration-entity-rename.R`

- [ ] Add a create-full operation-order assertion covering publication preparation,
  transaction begin, entity/review/status writes, commit, and rollback on each failure.
- [ ] Move `svc_entity_create_with_review_status` and `svc_entity_create_full` together
  to creation service. Move `svc_entity_rename_full` to rename service. Keep validation,
  basic CRUD/read/duplicate functions and legacy wrappers in entity service.
- [ ] Register entity-service → creation → rename → endpoint orchestration. Update direct
  source fixtures to load all three explicitly; do not guard-source in production.
- [ ] Run unit creation/service and integration rename tests with real transaction
  rollback; lint and require all modules below 600. Commit as
  `refactor(api): split entity orchestration services (#346)`.

### Task 3: Split re-review selection from lifecycle

**Files:**
- Create: `api/services/re-review-selection-service.R` (≤420)
- Modify: `api/services/re-review-service.R` (≤590)
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-re-review-service.R`
- Modify: `api/tests/testthat/test-unit-re-review-submit-allowlist.R`

- [ ] Add tests for criteria normalization, gene-atomic soft limit, preview/available
  parity, invalid criteria rejection, and unchanged transaction rollback.
- [ ] Move allowlists, criteria/parameter builders, matching selection, preview, and
  available-entity functions to selection service. Keep create/assign/reassign/archive/
  entity-assign/recalculate lifecycle in the original service.
- [ ] Register selection before lifecycle and update direct-source tests. Run both
  re-review suites, lint, and counts. Commit as
  `refactor(api): split re-review selection service (#346)`.

### Task 4: Split async job handlers by execution family

**Files:**
- Create: `api/functions/async-job-provider-handlers.R` (≤460)
- Create: `api/functions/async-job-maintenance-handlers.R` (≤260)
- Modify: `api/functions/async-job-handlers.R` (≤380)
- Verify: `api/functions/async-job-worker.R`
- Verify: `api/start_async_worker.R`
- Verify: `api/bootstrap/setup_workers.R`
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-unit-async-job-handlers.R`
- Modify: `api/tests/testthat/test-unit-async-job-worker.R`
- Modify: `api/tests/testthat/test-unit-analysis-snapshot-worker-preload.R`

- [ ] Extend registry tests to assert the exact job-type set, handler function,
  `cancel_mode`, and `after_success`; extend preload tests to exact-once/order in both
  worker entrypoints.
- [ ] Move HGNC, PubTator, NDDScore, mapping, OMIM, and force-apply handlers to provider
  module. Move backup create/restore and publication refresh/backfill to maintenance
  module. Keep common payload/progress/clustering helpers, passthrough factory, registry,
  and lookup in the shell.
- [ ] Explicitly source extracted handlers before registry in API, standalone worker,
  `async-job-worker.R`'s guarded fallback chain, and mirai bootstrap. The guarded path
  must source provider and maintenance modules before `async-job-handlers.R`, because
  the registry binds handler functions eagerly. Do not change job names, lane/priority
  helpers, handler payloads,
  cancellation, success hooks, or external budget resets.
- [ ] Run handler/worker/preload/publication/NDDScore/PubTator/ontology tests, lint, and
  counts. Restart `worker` and `worker-maintenance`, submit one default-lane clustering
  and one maintenance job, and verify both complete on expected queues. Commit as
  `refactor(api): split durable async handler families (#346)`.

### Task 5: Extract async repository primitives

**Files:**
- Create: `api/functions/async-job-repository-helpers.R` (≤140)
- Modify: `api/functions/async-job-repository.R` (≤560)
- Verify: `api/bootstrap/load_modules.R`
- Verify: `api/bootstrap/setup_workers.R`
- Modify: `api/tests/testthat/test-unit-async-job-repository.R`

- [ ] Add helper tests for base-get capture, selected columns, scalar/empty validation,
  queue validation, and named/unnamed parameter normalization.
- [ ] Move libraries/DB fallback, captured `base::get`, base columns, select/validation/
  scalar/empty helpers to helper file. Preserve CRUD/claim/lifecycle/history in repository.
- [ ] Load immediately after DB helpers and before repository in API and worker setup.
  Preserve `priority ASC`, queue filters, claim tokens, and unname binds.
- [ ] Run repository/service/worker suites, lint, and counts. Commit as
  `refactor(api): extract async repository primitives (#346)`.

### Task 6: Split endpoint-functions by phenotype and panel domains

**Files:**
- Create: `api/functions/phenotype-endpoint-functions.R` (≤190)
- Create: `api/functions/panels-endpoint-functions.R` (≤285)
- Modify: `api/functions/endpoint-functions.R` (≤320)
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-unit-endpoint-functions.R`
- Modify: `api/tests/testthat/test-unit-panels-endpoint.R`

- [ ] Add direct behavior tests for phenotype/panel filter/sort validation, approved
  views, empty/meta/XLSX behavior, and injection-rejecting identifiers.
- [ ] Move `generate_phenotype_entities_list` to phenotype module and
  `generate_panels_list` to panels module. Keep statistics/news/variant functions in
  shell. Load both before shell and update direct sources.
- [ ] Run endpoint/panel/static security tests, lint, and counts. Commit as
  `refactor(api): split endpoint function domains (#346)`.

### Task 7: Extract LLM prompt-template persistence

**Files:**
- Create: `api/functions/llm-prompt-template-repository.R` (≤210)
- Modify: `api/functions/llm-service.R` (≤490)
- Verify: `api/bootstrap/load_modules.R`
- Create: `api/tests/testthat/test-unit-llm-prompt-template-repository.R`
- Modify: `api/tests/testthat/test-unit-llm-service-db-access.R`
- Modify: `api/tests/testthat/test-unit-llm-service-model-resolution.R`

- [ ] Test default fallback, invalid prompt type, current-template lookup, transactional
  save/current-row retirement, and complete listing.
- [ ] Move `get_prompt_template`, `get_default_prompt_template`,
  `save_prompt_template`, and `get_all_prompt_templates` to repository file. Keep LLM
  generation/fetch orchestration in service; do not change prompt content or
  `LLM_SUMMARY_PROMPT_VERSION`.
- [ ] Load repository before service; update direct-source fixtures. Run prompt/service/
  LLM-admin tests, lint, and counts. Commit as
  `refactor(api): extract LLM prompt template repository (#346)`.

### Task 8: Split migration state persistence from execution

**Files:**
- Create: `api/functions/migration-state-repository.R` (≤350)
- Modify: `api/functions/migration-runner.R` (≤450)
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-unit-migration-runner.R`

- [ ] Add exact source-order and state-repository tests for schema table creation,
  manifest file listing, applied rows, rename reconciliation, and record insertion.
- [ ] Move those five state functions to repository; keep advisory lock, SQL splitter,
  delimiter/execution, pending calculation, and runner in original module.
- [ ] Load migration manifest → state repository → runner. Update DB helpers that source
  runner directly. Preserve strict manifest failures and lock release on every path.
- [ ] Run migration runner tests, startup migration smoke, lint, and counts. No migration,
  manifest, schema, or view changes are allowed. Commit as
  `refactor(api): split migration state repository (#346)`.

### Task 9: Split NDDScore release acquisition from import transaction

**Files:**
- Create: `api/functions/nddscore-release-source.R` (≤470)
- Modify: `api/functions/nddscore-import.R` (≤450)
- Verify: `api/bootstrap/load_modules.R`
- Verify: `api/bootstrap/setup_workers.R`
- Modify: `api/tests/testthat/test-nddscore-import.R`
- Modify: `api/tests/testthat/test-nddscore-job.R`

- [ ] Test config resolution, Zenodo metadata/download/checksum/extract, JSON/TSV parsing,
  schema validation, and unchanged failure classification independently of DB writes.
- [ ] Move acquisition/parser/validation functions to release source; keep advisory lock,
  DB upserts/inserts/counts/activation/failure and import orchestration in import module.
- [ ] Load release source before import in API and worker paths. Preserve outbound timeout/
  retry, checksum, lock, transaction, and activation behavior verbatim.
- [ ] Run import/job/repository/endpoint tests, lint, and counts. Commit as
  `refactor(api): split NDDScore release source (#346)`.

### Task 10: Split OMIM download and parser modules

**Files:**
- Create: `api/functions/omim-download-functions.R` (≤400)
- Create: `api/functions/omim-parser-functions.R` (≤250)
- Modify: `api/functions/omim-functions.R` (≤430)
- Verify: `api/bootstrap/load_modules.R`
- Verify: `api/bootstrap/setup_workers.R`
- Modify: `api/tests/testthat/test-unit-omim-functions.R`

- [ ] Add focused tests for credential redaction, TTL cache paths, download error classes,
  genemap/mim2gene parser headers/versions/edge cases, and downstream validation/build
  equivalence.
- [ ] Move credentials and mim2gene/genemap/HPO acquisition to download module. Move
  `parse_genemap2` and `parse_mim2gene` to parser module. Keep validation, deprecation,
  and dataset build functions in OMIM shell.
- [ ] Load download → parser → OMIM before comparisons in API and worker. Preserve
  `OMIM_DOWNLOAD_KEY` secrecy, TTL, retry/timeout, parsing semantics, and MONDO source.
- [ ] Run full OMIM/comparisons/ontology tests, lint, and counts. Commit as
  `refactor(api): split OMIM acquisition and parsing (#346)`.

### Task 11: Ratchet and publish Wave 4 integration

After Tasks 1-10 merge, create `refactor/346-w4-ratchet` from fresh master.

- [ ] Merge source-registration edits in the exact dependency order asserted by Task 1.
  Restart API, worker, and worker-maintenance before runtime smoke.
- [ ] Regenerate baseline once; every Wave 4 row disappears and no value increases.
- [ ] Run targeted files named above plus:

```bash
make lint-api
make test-api-fast
make test-api
make code-quality-audit
make pre-commit
make ci-local
git diff --check
```

- [ ] Independently inventory all API production files and require no non-exempt file
  above 600. Verify default and maintenance job smoke results and queue names.
- [ ] Push `refactor/346-w4-ratchet`, open the focused ratchet PR, obtain Claude and
  Codex security/correctness/code-quality reviews, fix and re-review all findings, wait
  for green checks, and squash-merge.
