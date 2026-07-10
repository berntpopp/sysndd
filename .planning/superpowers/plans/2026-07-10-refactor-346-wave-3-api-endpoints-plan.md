# Refactor #346 Wave 3 API Endpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce all nine oversized Plumber endpoint files below 600 lines while preserving every route, decorator, handler formal, authorization gate, response envelope, and mount position.

**Architecture:** Do not split or remount routers. Endpoint files remain thin authorization/delegation shells; cohesive request processing moves to `svc_`-prefixed services registered in the shared `bootstrap/load_modules.R`. The standalone worker also calls that shared loader, so these services may be sourced but remain unused there: they are never registered as job handlers, called by worker execution, or exposed through MCP.

**Tech Stack:** R, Plumber, testthat, DBI, httr2, SysNDD RFC 9457 helpers, Docker, OpenAPI verifier.

**Spec:** `.planning/superpowers/specs/2026-07-10-refactor-346-complete-closure-design.md`

---

Create each endpoint-domain branch only after its predecessor is merged, using freshly
updated master and the branch names below:

```bash
git switch master
git pull --ff-only origin master
git switch -c "$TASK_BRANCH"
```

```text
Task 1             refactor/346-w3-endpoint-contracts
Task 2             refactor/346-w3-publication-endpoints
Task 3             refactor/346-w3-user-endpoints
Task 4             refactor/346-w3-admin-endpoints
Task 5             refactor/346-w3-job-endpoints
Task 6             refactor/346-w3-rereview-endpoints
Task 7             refactor/346-w3-entity-endpoints
Task 8             refactor/346-w3-statistics-endpoints
Task 9 LLM         refactor/346-w3-llm-admin-endpoints
Task 9 backup      refactor/346-w3-backup-endpoints
```

Each is a separately reviewed/merged PR. Domain agents never edit shared registration,
pagination, or baseline files; the integration owner applies those changes inside the
same domain PR after receiving the agent's ordered requirements. Every domain PR runs
`--write-baseline` and lowers/removes its own endpoint entry before review.

### Task 1: Characterize the endpoint and bootstrap contracts

**Files:**
- Create: `api/tests/testthat/test-unit-oversized-endpoint-contract.R`
- Create: `api/tests/testthat/test-unit-endpoint-service-bootstrap.R`
- Verify: `api/bootstrap/load_modules.R`
- Modify: `api/tests/testthat/test-unit-endpoint-error-handler.R`
- Modify: `api/tests/testthat/test-pagination-contract.R`

- [ ] **Step 1: Build a hard-coded route manifest test**

For `publication`, `user`, `admin`, `jobs`, `re_review`, `entity`, `statistics`,
`llm_admin`, and `backup`, parse source in order and assert every HTTP method/path,
handler formal/default order, `@tag`, `@serializer`, and `@accept` block. Include both
ordered `GET <pmid>` declarations. Assert the current authorization matrix and that
every nontrivial final shell delegates exactly once to a `svc_` function.

- [ ] **Step 2: Characterize mount/error behavior**

Assert the complete ordered `pr_mount()` path/file vector, network-layout before jobs,
three nested admin routers before `/api/admin`, all nine files mounted through
`mount_endpoint()`, no bare `plumber::pr("endpoints/..."`) mount, and RFC 9457 400/404
envelopes containing `type`, `title`, `status`, `detail`, and `instance` with
`application/problem+json`.

- [ ] **Step 3: Characterize service registration**

Parse `service_files`; assert every currently registered service appears exactly once in
dependency order and all public bindings begin `svc_`/`service_` without repository
collisions. Each later domain PR first adds a failing assertion for its own new service
files, then adds the registration and makes that assertion green.

The integration owner also centralizes re-review and LLM-admin pagination envelope
assertions in `test-pagination-contract.R`. Domain agents treat that shared file as
verification-only, giving it one writer during parallel execution. In every Files list,
`Verify:` means read-only execution of the named test; the domain agent must not edit,
stage, or commit that file.

The same integration owner is the sole writer for `bootstrap/load_modules.R`. Each
domain task returns its new service filenames and required dependency order; the owner
applies those registrations after integrating the domain commit. `Verify:` on that file
likewise forbids domain-agent edits.

- [ ] **Step 4: Run the tests before production changes**

```bash
cd api
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-oversized-endpoint-contract.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-endpoint-service-bootstrap.R')"
Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-endpoint-error-handler.R')"
```

Expected: all assertions for the current tree pass. No assertion for a future module is
merged red; each domain extends the manifest in its own red→green cycle.

- [ ] **Step 5: Commit the guards**

```bash
git add api/tests/testthat/test-unit-oversized-endpoint-contract.R \
  api/tests/testthat/test-unit-endpoint-service-bootstrap.R \
  api/tests/testthat/test-unit-endpoint-error-handler.R
git commit -m "test(api): characterize oversized endpoint contracts (#346)"
```

### Task 2: Thin publication_endpoints.R

**Files:**
- Create: `api/services/publication-query-endpoint-service.R` (target ≤430)
- Create: `api/services/publication-admin-endpoint-service.R` (target ≤450)
- Create: `api/tests/testthat/test-unit-publication-endpoint-services.R`
- Modify: `api/endpoints/publication_endpoints.R` (target ≤410)
- Modify: `api/tests/testthat/test-endpoint-publication.R`
- Modify: `api/tests/testthat/test-unit-pubtator-public-route-guard.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Add service tests for PMID normalization, degraded 503, cursor/meta/data and XLSX,
  enrichment fallback sort echo, missing query 400, duplicate 409 + `Location`, capacity
  503 + `Retry-After`, accepted 202 headers, and cache deletion order.
- [ ] Move read handlers to `svc_publication_get_by_pmid`,
  `svc_publication_validate_pmid`, `svc_publication_pubtator_search`,
  `svc_publication_list`, `svc_publication_pubtator_table`, and
  `svc_publication_pubtator_genes`. Move mutations/status to `svc_publication_*` admin
  functions. Keep Curator/Administrator `require_role()` in endpoint shells.
- [ ] Preserve both `GET <pmid>` declarations, all decorators/formals, public budgets,
  202/409/503 headers, and response shapes. Expand the budget guard to scan services.
- [ ] Run contract/bootstrap/publication/PubTator guard tests, `make lint-api`, and
  `wc -l`; require all three production files below their targets. Commit as
  `refactor(api): extract publication endpoint services (#346)`.

### Task 3: Thin user_endpoints.R

**Files:**
- Create: `api/services/user-read-endpoint-service.R` (≤250)
- Create: `api/services/user-account-endpoint-service.R` (≤360)
- Create: `api/services/user-password-profile-endpoint-service.R` (≤360)
- Create: `api/services/user-bulk-endpoint-service.R` (≤220)
- Create: `api/tests/testthat/test-unit-user-endpoint-services.R`
- Modify: `api/endpoints/user_endpoints.R` (≤285)
- Modify: `api/tests/testthat/test-endpoint-auth.R`
- Modify: `api/tests/testthat/test-unit-role-admin-target-guard.R`
- Modify: `api/tests/testthat/test-unit-user-approval.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test scalar JSON rejection, own/other contributions, admin-target shields, approval
  mail failure, reset anti-enumeration/JWT expiry/hash mismatch/success, profile email and
  ORCID validation, bulk cap 20, and exact role matrix.
- [ ] Move table/contributions/role/list to read service; approval/change-role/delete/
  update to account service; password/profile/reset to password-profile service; bulk
  operations to bulk service. Keep all role gates and request-user attribution in shells.
- [ ] Preserve sensitive JSON-body-only values and all response/status behavior. Update
  source guards to check gate+delegation in endpoint and behavior in service.
- [ ] Run contract/bootstrap/user/auth/approval/password tests, lint, and line counts.
  Commit as `refactor(api): extract user endpoint services (#346)`.

### Task 4: Thin admin_endpoints.R

**Files:**
- Create: `api/services/admin-ontology-endpoint-service.R` (≤430)
- Create: `api/services/admin-diagnostics-endpoint-service.R` (≤320)
- Create: `api/services/admin-nddscore-endpoint-service.R` (≤200)
- Create: `api/services/admin-publication-refresh-endpoint-service.R` (≤260)
- Create: `api/tests/testthat/test-unit-admin-endpoint-services.R`
- Modify: `api/endpoints/admin_endpoints.R` (≤350)
- Modify: `api/tests/testthat/test-endpoint-admin.R`
- Modify: `api/tests/testthat/test-unit-metadata-refresh-patterns.R`
- Modify: `api/tests/testthat/test-publication-refresh.R`
- Modify: `api/tests/testthat/test-unit-publication-refresh-source.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test OpenAPI single enhancement, validation-before-submit, full result mode,
  404/409/410, stale CSV, async 202, HGNC transactional/FK behavior, NDDScore 409/202,
  publication refresh invalid/empty/no-match/duplicate/capacity/success, and 350 ms
  rate-limit guard.
- [ ] Move ontology/HGNC/deprecated, diagnostics/version/dates/SMTP, NDDScore, and
  publication-refresh families to their services. Keep the public removed 410 route and
  public version/dates/OpenAPI routes unchanged; keep all existing Administrator gates.
- [ ] Run contract/bootstrap/admin/refresh/NDDScore tests, lint, and line counts. Commit
  as `refactor(api): extract admin endpoint services (#346)`.

### Task 5: Thin jobs_endpoints.R

**Files:**
- Create: `api/services/job-functional-submission-service.R` (≤330)
- Create: `api/services/job-phenotype-submission-service.R` (≤350)
- Create: `api/services/job-maintenance-submission-service.R` (≤450)
- Create: `api/services/job-query-endpoint-service.R` (≤180)
- Create: `api/tests/testthat/test-unit-job-endpoint-services.R`
- Modify: `api/endpoints/jobs_endpoints.R` (≤180)
- Modify: `api/tests/testthat/test-unit-job-status-result-mode.R`
- Modify: `api/tests/testthat/test-unit-phenotype-clustering-approved-guard.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test scalar algorithm/default genes, duplicate/cache-hit/capacity/new submit,
  approved-only phenotype inputs, credential-free hashes, maintenance headers, history
  clamp, result-mode 400/403/503/404/running behavior, and public summaries.
- [ ] Move functional, phenotype, maintenance, history, and status handler bodies to the
  named services. Preserve anonymous executor closures inside submission services and
  keep `async_job_handler_registry` unchanged. Keep public vs Administrator gates in
  shells. The codebase has no `ASYNC_JOB_HANDLERS` binding; do not introduce or search
  for that obsolete/nonexistent name.
- [ ] Do not add endpoint services to worker-specific source lists or handler
  registration. They may still be sourced by the shared loader; no worker handler or
  execution path may call them. Run contract/bootstrap/job/approved-input tests, lint,
  and line counts. Commit as
  `refactor(api): extract job endpoint services (#346)`.

### Task 6: Thin re_review_endpoints.R

**Files:**
- Create: `api/services/re-review-query-endpoint-service.R` (≤300)
- Create: `api/services/re-review-workflow-endpoint-service.R` (≤380)
- Create: `api/tests/testthat/test-unit-re-review-endpoint-services.R`
- Modify: `api/endpoints/re_review_endpoints.R` (≤390)
- Verify: `api/tests/testthat/test-pagination-contract.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test submit allowlisting/unnamed DB params, refusal errors, query predicates,
  assignment scoping, cursor envelope, legacy assignment array, email/insert behavior,
  criteria mapping, status propagation, and entity-assignment validation.
- [ ] Move read/assignment-table handlers to query service and all lifecycle/batch/
  assignment/recalculation handlers to workflow service over existing domain services.
  Keep Reviewer/Curator gates exactly route-local.
- [ ] Run contract/bootstrap/re-review/pagination tests, lint, and line counts. Commit as
  `refactor(api): extract re-review endpoint services (#346)`.

### Task 7: Thin entity_endpoints.R

**Files:**
- Create: `api/services/entity-read-endpoint-service.R` (≤440)
- Create: `api/services/entity-submission-endpoint-service.R` (≤330)
- Create: `api/tests/testthat/test-unit-entity-endpoint-services.R`
- Modify: `api/endpoints/entity_endpoints.R` (≤335)
- Modify: `api/tests/testthat/test-unit-public-approved-review-guard.R`
- Modify: `api/tests/testthat/test-integration-entity-rename.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test compact/global query behavior, cursor/XLSX, publication preparation before
  transaction, no-write failure, normalization, server attribution, direct approval,
  201/cache invalidation, mutation-only deactivate, and detail columns.
- [ ] Move list/detail reads to read service and create/deactivate request orchestration
  to submission service; retain `svc_entity_rename_full`. Keep Curator gates in shells.
- [ ] Expand approved-review guard to services; every `is_primary` includes
  `review_approved`, and all three historical branches use approved-primary IDs.
- [ ] Run contract/bootstrap/entity/security/integration tests, lint, and counts. Commit
  as `refactor(api): extract entity endpoint services (#346)`.

### Task 8: Thin statistics_endpoints.R

**Files:**
- Create: `api/services/statistics-public-endpoint-service.R` (≤430)
- Create: `api/services/statistics-admin-endpoint-service.R` (≤400)
- Create: `api/tests/testthat/test-unit-statistics-endpoint-services.R`
- Modify: `api/endpoints/statistics_endpoints.R` (≤305)
- Modify: `api/tests/testthat/test-endpoint-statistics.R`
- Modify: `api/tests/testthat/test-unit-cheap-route-isolation.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] Test invalid aggregate/group 400, time-series shapes/counts, publication filters,
  leaderboard fields/meta, empty states, and exact role matrix.
- [ ] Move four public routes to public service and six privileged routes to admin
  service; retain Administrator gates in shells. Expand cheap-route scan to both services
  so extraction cannot hide external calls.
- [ ] Run contract/bootstrap/statistics/cheap-route tests, lint, and counts. Commit as
  `refactor(api): extract statistics endpoint services (#346)`.

### Task 9: Thin LLM-admin and backup endpoints

**Files:**
- Create: `api/services/llm-admin-endpoint-service.R` (≤450)
- Create: `api/tests/testthat/test-unit-llm-admin-endpoint-service.R`
- Modify: `api/endpoints/llm_admin_endpoints.R` (≤350)
- Modify: `api/tests/testthat/test-unit-llm-regenerate.R`
- Create: `api/services/backup-endpoint-service.R` (≤450)
- Modify: `api/endpoints/backup_endpoints.R` (≤215)
- Modify: `api/tests/testthat/test-endpoint-backup.R`
- Verify: `api/tests/testthat/test-pagination-contract.R`
- Verify: `api/bootstrap/load_modules.R`

- [ ] LLM tests cover model/pagination/cache/prompt validation, Gemini 503, snapshot 409,
  regeneration 202 + force forwarding, no clustering recomputation, and attribution.
- [ ] Backup tests cover role gate, sort/pagination, duplicate/capacity, traversal and
  extension guards, 404, serializer/header switching, safety backup, latest-link refusal,
  typed confirmation, and filesystem failures.
- [ ] Move each handler family to its `svc_` service and keep Administrator checks in
  all shells. Preserve exact serializers, headers, job types, and response envelopes.
- [ ] Run contract/bootstrap/LLM/backup/pagination tests, lint, and line counts. Commit
  each domain separately.

### Task 10: Verify merged Wave 3 integration

After all endpoint-domain PRs merge, pull fresh master.

- [ ] Integration owner merges service registrations in dependency order and reruns all
  three shared guards plus `./scripts/verify-msw-against-openapi.sh`.
- [ ] Run `--write-baseline` and require a clean `git diff --exit-code`; all nine
  endpoint rows were removed by their domain PRs and no value increased.

```bash
bash scripts/code-quality-audit.sh --write-baseline
git diff --exit-code -- scripts/code-quality-file-size-baseline.tsv
```
- [ ] Run:

```bash
make lint-api
make test-api-fast
make code-quality-audit
make pre-commit
git diff --check
wc -l api/endpoints/{publication,user,admin,jobs,re_review,entity,statistics,llm_admin,backup}_endpoints.R
```

- [ ] Run `make test-api` and `make ci-local`; DB tests must show real passes, not
  environment skips used as evidence.
- [ ] Record the merged-state results; no extra ratchet PR is necessary.
