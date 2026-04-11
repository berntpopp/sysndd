# v11.0 Phase C — Tier B Safety Net (Tests Only)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to orchestrate this phase session; it will call `superpowers:dispatching-parallel-agents` and `superpowers:using-git-worktrees`. Each worktree executes as its own subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase C.

**Phase goal:** Land the Tier B safety net — six functional view tests (C1–C6), three R endpoint test batches covering ten previously-untested files (C7, C8, C9), and two composable test worktrees (C10, C11) — all consuming the MSW handlers, fixtures, and wait-helpers from Phase B. Every unit is **tests only**; no source under test is modified.

**Phase architecture:** 11 fully parallel worktrees off Phase-B-merged `master`. This is the largest wave in the milestone. Every unit writes new test files that do not exist on `master`, so ownership is trivially disjoint. Exit criterion #5 is the defining acceptance rule: **per HTTP method per route** test coverage in C7/C8/C9 — **this scope is locked in Appendix C and must not be re-widened or re-narrowed.**

**Tech stack:** `@vue/test-utils` + `vitest-environment-jsdom` + MSW for views/composables; `testthat` + `with_test_db_transaction()` for R endpoints.

**Locked decisions from spec Appendix C (do not re-open):**
- **B1 handler table** is authoritative for every C1–C6 spec. View tests reference handlers from that table, not new ones. If a view needs a handler not in the table, STOP and flag — do not add it in Phase C.
- **Exit criterion #5** is locked at "per HTTP method per route declared in the endpoint file." Writing plans must not re-scope this to "per file" or "per route (any method)." The sizing note is also locked: `review_endpoints.R` and `status_endpoints.R` are the largest files and their test files carry the bulk of Phase C's backend test volume.
- **E7 auth consolidation** is Phase E — C1–C6 do not precede with auth composable assumptions.

---

## 1 — Prerequisites check

Before opening this phase, confirm:

- [ ] Phase B is **done** per its own gate (§2.3):
  ```bash
  git branch --list 'v11.0/phase-b/*' | wc -l              # must be 0
  git ls-remote --heads origin 'v11.0/phase-b/*' | wc -l   # must be 0
  ```
- [ ] `make ci-local` green on clean `master`.
- [ ] B1's MSW handlers cover every entry in the locked handler table. Verify with `scripts/verify-msw-against-openapi.sh`.
- [ ] B1's `onUnhandledRequest: 'error'` is active — grep `app/vitest.setup.ts`.
- [ ] B2's fixtures exist and are non-empty — `find api/tests/testthat/fixtures/pubmed api/tests/testthat/fixtures/pubtator -type f | grep -v .gitkeep | wc -l` returns non-zero.
- [ ] B3's `skip_if_not_slow_tests` is wired — `grep -r "skip_if_not_slow_tests" api/tests/testthat/ | wc -l` is non-zero.
- [ ] B4's `smoke-test` CI job ran green on at least one recent `master` push.
- [ ] B4's real `scripts/verify-test-gate.sh` is in place and rejects synthetic Phase D/E violations.
- [ ] B5: `grep -rn "Sys\.sleep" api/tests/testthat/` returns zero.
- [ ] No `v11.0/phase-c/*` branches exist locally or remotely.

If any check fails, stop and escalate.

---

## 2 — Worktree manifest

All 11 worktrees branch off current `master` via `make worktree-setup NAME=phase-c/<unit>`. Every worktree owns only new files — no pre-existing-file conflicts are possible across C1–C11.

### C.1 — View functional tests (6 worktrees)

| # | Branch | Worktree path | Exclusive write ownership | Target (read-only) |
|---|---|---|---|---|
| C1 | `v11.0/phase-c/test-view-approve-review` | `worktrees/phase-c/test-view-approve-review` | `app/src/views/curate/ApproveReview.spec.ts` (new) | `app/src/views/curate/ApproveReview.vue` (2,138 LoC) |
| C2 | `v11.0/phase-c/test-view-review` | `worktrees/phase-c/test-view-review` | `app/src/views/review/Review.spec.ts` (new) | `app/src/views/review/Review.vue` (1,454 LoC) |
| C3 | `v11.0/phase-c/test-view-approve-status` | `worktrees/phase-c/test-view-approve-status` | `app/src/views/curate/ApproveStatus.spec.ts` (new) | `app/src/views/curate/ApproveStatus.vue` (1,432 LoC) |
| C4 | `v11.0/phase-c/test-view-modify-entity` | `worktrees/phase-c/test-view-modify-entity` | `app/src/views/curate/ModifyEntity.spec.ts` (new) | `app/src/views/curate/ModifyEntity.vue` (1,555 LoC) |
| C5 | `v11.0/phase-c/test-view-manage-annotations` | `worktrees/phase-c/test-view-manage-annotations` | `app/src/views/admin/ManageAnnotations.spec.ts` (new) | `app/src/views/admin/ManageAnnotations.vue` (2,159 LoC) |
| C6 | `v11.0/phase-c/test-view-manage-user` | `worktrees/phase-c/test-view-manage-user` | `app/src/views/admin/ManageUser.spec.ts` (new) | `app/src/views/admin/ManageUser.vue` (1,732 LoC) |

### C.2 — R endpoint test batches (3 worktrees)

| # | Branch | Worktree path | Exclusive write ownership (all new files) |
|---|---|---|---|
| C7 | `v11.0/phase-c/test-endpoint-read-batch` | `worktrees/phase-c/test-endpoint-read-batch` | `api/tests/testthat/test-endpoint-search.R` (new), `test-endpoint-list.R` (new), `test-endpoint-statistics.R` (new), `test-endpoint-ontology.R` (new) |
| C8 | `v11.0/phase-c/test-endpoint-write-batch` | `worktrees/phase-c/test-endpoint-write-batch` | `api/tests/testthat/test-endpoint-review.R` (new), `test-endpoint-status.R` (new), `test-endpoint-phenotype.R` (new), `test-endpoint-variant.R` (new) |
| C9 | `v11.0/phase-c/test-endpoint-admin-batch` | `worktrees/phase-c/test-endpoint-admin-batch` | `api/tests/testthat/test-endpoint-backup.R` (new), `test-endpoint-hash.R` (new) |

### C.3 — Composable tests (2 worktrees)

| # | Branch | Worktree path | Exclusive write ownership |
|---|---|---|---|
| C10 | `v11.0/phase-c/test-composables-async-form` | `worktrees/phase-c/test-composables-async-form` | `app/src/composables/useAsyncJob.spec.ts` (new), `app/src/composables/useEntityForm.spec.ts` (new) |
| C11 | `v11.0/phase-c/test-composables-table` | `worktrees/phase-c/test-composables-table` | `app/src/composables/useTableData.spec.ts` (new), `app/src/composables/useTableMethods.spec.ts` (new) |

**Intra-phase ownership rule (§2.4):** zero overlap. Every file in every ownership set is new. Two worktrees cannot hit the same file.

**Default-on transaction rollback (§3 Phase C.4, §4.5):** C7, C8, and C9 each audit sibling `test-integration-*.R` files in their subject area and wrap any not-yet-wrapped file in `with_test_db_transaction()`. This is the only Phase C allowance for modifying pre-existing test files — gated by B4's `verify-test-gate.sh` extended mode (§4.5), which requires every integration test file to open with either `with_test_db_transaction` or a documented `skip_if_no_test_db()` exemption.

---

## 3 — Per-worktree task spec

### C1 — `test-view-approve-review`

- [ ] **Target (read-only, do not modify):** `app/src/views/curate/ApproveReview.vue` (2,138 LoC).

- [ ] **Goal (§3 Phase C.C1):** Author a `@vue/test-utils` + MSW functional test with one happy path, one error/edge path, and at least one pinned `it.todo` for Phase E's rewrite to unpin.

- [ ] **File ownership:** `app/src/views/curate/ApproveReview.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C1):**
  - **Happy path:** Open a review row, submit a classification, assert success toast and row-refresh. Uses handlers from the B1 locked table for `GET /api/review/<id>`, `GET /api/review/<id>/phenotypes`, `GET /api/review/<id>/variation`, `GET /api/review/<id>/publications`, `PUT /api/review/approve/<id>`.
  - **Error path:** Submit with a missing required field; assert the validation error is shown and **no** HTTP POST fires (MSW's `onUnhandledRequest: 'error'` catches any stray call).
  - **`it.todo` (locked handshake for E5):** `it.todo('TODO: verify the correct approver role appears in the audit trail')`.

- [ ] **Acceptance:**
  - `cd app && npx vitest run src/views/curate/ApproveReview.spec.ts` green against unchanged source.
  - No new MSW handlers added — every handler used is already in the B1 locked table. If a gap is discovered, STOP and flag (do not fork B1 in Phase C).
  - `make ci-local` green.

- [ ] **TDD loop reference (§4.2 variant):** Phase C writes new tests against unmodified source. The loop:
  1. Read `ApproveReview.vue` (do not modify) and enumerate the happy-path and error-path user actions.
  2. Author the spec file with the two `it` blocks and one `it.todo`.
  3. Run `npx vitest run src/views/curate/ApproveReview.spec.ts` — must be GREEN on unchanged source.
  4. If the spec fails on unchanged source, the test is wrong, not the source. Rewrite the spec; do not touch the view.
  5. `make ci-local`.
  6. Open PR.

- [ ] **Test-gate reference (§2.5):** Layer 1 — this worktree creates the test, so Phase E's `rewrite-approve-review` (E5) can structurally prove the test pre-exists. Layer 2 — C1's PR creates a new spec file; allowed by `verify-test-gate.sh`.

- [ ] **Downstream consumer:** E5 (`rewrite-approve-review`) runs this spec against unchanged source first (must be green), rewrites the view, then unpins the `it.todo` into a passing assertion. The handshake (§2.6) is locked.

### C2 — `test-view-review`

- [ ] **Target:** `app/src/views/review/Review.vue` (1,454 LoC).

- [ ] **Goal (§3 Phase C.C2):** Author functional test with happy, error, and `it.todo` coverage for the classification wizard.

- [ ] **File ownership:** `app/src/views/review/Review.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C2):**
  - **Happy path:** Walk the classification wizard step-by-step, submit, assert success. Uses `GET /api/entity/<sysndd_id>/review`, `POST /api/review/create`, `PUT /api/review/update` handlers from the B1 locked table.
  - **Error path:** Advance from step 1 with invalid evidence; assert the next button is disabled and the validation message shows.
  - **`it.todo`:** `it.todo('TODO: verify the step-indicator state after a back-navigation')`.

- [ ] **Acceptance:** green on unchanged source; no new MSW handlers; `make ci-local` green.

- [ ] **TDD loop reference:** same §4.2 Phase C variant as C1.

- [ ] **Test-gate reference (§2.5):** Layer 1 passes (new spec file); Layer 2 passes.

### C3 — `test-view-approve-status`

- [ ] **Target:** `app/src/views/curate/ApproveStatus.vue` (1,432 LoC).

- [ ] **Goal (§3 Phase C.C3):** Happy, error, and `it.todo` for status approval flow.

- [ ] **File ownership:** `app/src/views/curate/ApproveStatus.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C3):**
  - **Happy path:** Approve a status row; assert the row is removed from the list. Uses `GET /api/status/<id>`, `PUT /api/status/approve/<id>`.
  - **Error path:** Approve with a stale/expired token; assert the 401 interceptor redirects to login. The 401 response shape comes from B1's auth handler.
  - **`it.todo`:** `it.todo('TODO: verify the combined status/review handling — hook for E6 convergence')`. This todo is the handshake for E6 (`converge-approve-status`).

- [ ] **Acceptance:** green on unchanged source; `make ci-local` green.

- [ ] **Downstream consumer:** E6 unpins the `it.todo` after replacing `ApproveStatus.vue` with a mount of the new `ApprovalTableView.vue`.

### C4 — `test-view-modify-entity`

- [ ] **Target:** `app/src/views/curate/ModifyEntity.vue` (1,555 LoC).

- [ ] **Goal (§3 Phase C.C4):** Happy, error, `it.todo`.

- [ ] **File ownership:** `app/src/views/curate/ModifyEntity.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C4):**
  - **Happy path:** Edit an entity field, save, assert 200 and cache invalidation. Uses `GET /api/entity/<sysndd_id>`, `POST /api/entity/rename` (or the appropriate write route from the B1 table).
  - **Error path:** Submit a duplicate entity (same gene+disease+inheritance); assert 409 is surfaced with the conflict description. `POST /api/entity/create` 409 branch per B1.
  - **`it.todo`:** `it.todo('TODO: verify unsaved-changes warning on navigation')`.

- [ ] **Acceptance:** green on unchanged source; `make ci-local` green.

### C5 — `test-view-manage-annotations`

- [ ] **Target:** `app/src/views/admin/ManageAnnotations.vue` (2,159 LoC).

- [ ] **Goal (§3 Phase C.C5):** Happy, error (using the **real** `status = "blocked"` Phase 76 pattern — NOT a job-cancel endpoint, which does not exist), and `it.todo`.

- [ ] **File ownership:** `app/src/views/admin/ManageAnnotations.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C5, Appendix C locked):**
  - **Happy path:** Submit an HGNC-update annotation job via `POST /api/jobs/hgnc_update/submit`; poll `GET /api/jobs/<job_id>/status`; assert status transitions (queued → running → complete) and the result is rendered in the history table.
  - **Error path:** Poll returns `status = "blocked"` (the Phase 76 ontology-update safeguard — already in production); assert the blocked-entities table renders with the block reason and the user sees the force-apply UI affordance. **There is no job-cancel endpoint in the current API. Do not mock or assert cancellation.**
  - **`it.todo`:** `it.todo('TODO: verify the force-apply flow fires PUT /api/admin/force_apply_ontology with the correct blocked_job_id')`.

- [ ] **Acceptance:** green on unchanged source; no new MSW handlers added (B1's table covers `/api/jobs/*`). `make ci-local` green.

- [ ] **Downstream consumer:** E4 (`rewrite-manage-annotations`) unpins the force-apply `it.todo` after rewriting the view with `useAsyncJob` + `useTableData`.

### C6 — `test-view-manage-user`

- [ ] **Target:** `app/src/views/admin/ManageUser.vue` (1,732 LoC).

- [ ] **Goal (§3 Phase C.C6):** Happy, error (demote-last-admin permission-denied), `it.todo`.

- [ ] **File ownership:** `app/src/views/admin/ManageUser.spec.ts` (new).

- [ ] **Required assertions (§3 Phase C.C6):**
  - **Happy path:** Change a user's role via `PUT /api/user/update` (confirmed by reading `ManageUser.vue` around line 1558 — do not invent a different route); assert the permission matrix re-renders.
  - **Error path:** Backend returns permission-denied for attempting to demote the last admin; assert the UI surfaces the error banner and does not remove the role locally.
  - **`it.todo`:** `it.todo('TODO: verify the search-and-filter state persists across role edits and user_role bulk assignments via POST /api/user/bulk_assign_role')`.

- [ ] **Acceptance:** green on unchanged source; `make ci-local` green.

### C7 — `test-endpoint-read-batch`

- [ ] **Goal (§3 Phase C.C7, exit criterion #5 locked):** One happy path and one 404/empty-result path per endpoint file, per HTTP method per route. Read-only endpoints.

- [ ] **File ownership (all new):**
  - `api/tests/testthat/test-endpoint-search.R`
  - `api/tests/testthat/test-endpoint-list.R`
  - `api/tests/testthat/test-endpoint-statistics.R`
  - `api/tests/testthat/test-endpoint-ontology.R`

- [ ] **Scope rule (§3 Phase C.2 sizing guidance, locked):** **per HTTP method per route** declared in the endpoint file. For each route in `search_endpoints.R`, if it exposes both a `@get` and a `@post`, the test file must include at least one `test_that()` block per method. Minimum per block: happy path. Where applicable: 404/empty-result path. Response-shape assertion: matches OpenAPI spec; pagination fields present where applicable.

- [ ] **Test harness rule (§4.5):** Every `test_that()` block runs inside `with_test_db_transaction()` unless the test exercises DDL, in which case an inline comment documents the exemption.

- [ ] **Default-on transaction rollback audit (§3 Phase C.4, §4.5):** C7 also audits sibling `test-integration-*.R` files in its subject area (search/list/statistics/ontology) and wraps any not-yet-wrapped file in `with_test_db_transaction()`. This is the **only** allowed modification to pre-existing test files in Phase C. Each such edit is documented in the commit message so B4's `verify-test-gate.sh` does not flag it.

- [ ] **Acceptance:**
  - Each of the 4 new test files exists and covers every route × method per the scope rule.
  - `make test-api` passes with the new files.
  - `grep -L "with_test_db_transaction" api/tests/testthat/test-integration-search*.R` etc. returns empty for the audited set (or has a documented `skip_if_no_test_db()` exemption with a reason).
  - `make ci-local` green.

- [ ] **TDD loop reference (§4.2 variant):**
  1. Read the target endpoint file (e.g. `api/endpoints/search_endpoints.R`) and enumerate every `@get`/`@post`/`@put`/`@delete` route.
  2. For each (route, method) pair, author one `test_that()` block with a happy path and (where applicable) a 404/empty path. Wrap each in `with_test_db_transaction()`.
  3. Run `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-search.R')"` (or the host-side equivalent once `make install-dev` has staged the helper). First run — RED (file didn't exist).
  4. Iterate until each block passes. Do NOT modify the endpoint files.
  5. Run the rollback audit: ensure every sibling integration test opens with `with_test_db_transaction` or a documented exemption.
  6. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous (Phase C creates new tests); Layer 2 — the rollback-audit edits to pre-existing integration tests are the allowed exception and must be documented.

### C8 — `test-endpoint-write-batch`

- [ ] **Goal (§3 Phase C.C8, exit criterion #5 locked):** Per HTTP method per route: one happy path, one validation-error path, one permission-denied path. These are write endpoints; sizing is the bulk of Phase C's backend test volume per the locked sizing guidance — `review_endpoints.R` and `status_endpoints.R` are the two largest files (8+ routes each).

- [ ] **File ownership (all new):**
  - `api/tests/testthat/test-endpoint-review.R`
  - `api/tests/testthat/test-endpoint-status.R`
  - `api/tests/testthat/test-endpoint-phenotype.R`
  - `api/tests/testthat/test-endpoint-variant.R`

- [ ] **Scope rule (exit criterion #5 locked):** per HTTP method per route, with minimum three blocks per method (happy / validation / permission). Every block runs inside `with_test_db_transaction()`.

- [ ] **Default-on transaction rollback audit:** same as C7, scoped to review/status/phenotype/variant integration tests.

- [ ] **Acceptance:**
  - Every route × method in the 4 target endpoint files has happy + validation + permission blocks. `review_endpoints.R` and `status_endpoints.R` produce the bulk of blocks per the locked sizing note.
  - `make test-api` passes.
  - Rollback audit green for sibling integration tests.
  - `make ci-local` green.

- [ ] **TDD loop reference:** same as C7.

- [ ] **Downstream consumer:** D4 (`delete-legacy-wrappers`) depends on C8's test-endpoint-review.R and test-endpoint-status.R being green before D4's rewrite. Exit criterion #9 is checked against C8's suite after D4 lands.

### C9 — `test-endpoint-admin-batch`

- [ ] **Goal (§3 Phase C.C9, exit criterion #5 locked):** One happy path per endpoint, per HTTP method per route. Admin endpoints.

- [ ] **File ownership (all new):**
  - `api/tests/testthat/test-endpoint-backup.R`
  - `api/tests/testthat/test-endpoint-hash.R`

- [ ] **Scope rule:** per HTTP method per route, happy path required; validation/permission where applicable. `backup_endpoints.R` may need a mock filesystem — document the mock setup in the test file.

- [ ] **Default-on transaction rollback audit:** scoped to backup/hash integration tests.

- [ ] **Acceptance:**
  - Each new test file covers every route × method.
  - Backup tests use a mock filesystem or a tmpdir; don't touch real backup paths.
  - `make test-api` passes.
  - Rollback audit green for the scoped integration tests.
  - `make ci-local` green.

### C10 — `test-composables-async-form`

- [ ] **Goal (§3 Phase C.C10):** Pin behavior of `useAsyncJob` and `useEntityForm` before E4 / E5 rewrites consume them.

- [ ] **File ownership (all new):**
  - `app/src/composables/useAsyncJob.spec.ts`
  - `app/src/composables/useEntityForm.spec.ts`

- [ ] **Required coverage (§3 Phase C.C10):**
  - `useAsyncJob.spec.ts`: job lifecycle transitions (submit → poll → complete, submit → poll → blocked, submit → poll → error). Uses MSW handlers from B1 (`POST /api/jobs/*/submit`, `GET /api/jobs/<job_id>/status`).
  - `useEntityForm.spec.ts`: form validation and submission. Uses MSW handlers for the entity write routes from B1.

- [ ] **Acceptance:**
  - `cd app && npx vitest run src/composables/useAsyncJob.spec.ts src/composables/useEntityForm.spec.ts` green against unchanged source.
  - No new MSW handlers added.
  - `make ci-local` green.

- [ ] **Downstream consumer:** E4 (`rewrite-manage-annotations`) consumes `useAsyncJob`; E-era rewrites consume `useEntityForm` if they touch the entity-form surface.

### C11 — `test-composables-table`

- [ ] **Goal (§3 Phase C.C11):** Pin behavior of `useTableData` and `useTableMethods`.

- [ ] **File ownership (all new):**
  - `app/src/composables/useTableData.spec.ts`
  - `app/src/composables/useTableMethods.spec.ts`

- [ ] **Required coverage:** sort, filter, pagination state transitions. Uses MSW handlers for whichever list route the composable calls (per B1 table).

- [ ] **Acceptance:** green on unchanged source; `make ci-local` green.

- [ ] **Downstream consumer:** E4 and E5 both consume `useTableData`.

---

## 4 — Parallel dispatch block

All 11 worktrees run concurrently (§3 Phase C: "all parallel").

```
SEQUENCE 1 (11-way parallel from Phase-B-merged master):
  C1  — test-view-approve-review
  C2  — test-view-review
  C3  — test-view-approve-status
  C4  — test-view-modify-entity
  C5  — test-view-manage-annotations
  C6  — test-view-manage-user
  C7  — test-endpoint-read-batch
  C8  — test-endpoint-write-batch
  C9  — test-endpoint-admin-batch
  C10 — test-composables-async-form
  C11 — test-composables-table
```

**Dispatch mechanics:**

- [ ] Step 1 — rebase local `master`:
  ```bash
  git checkout master && git pull --ff-only
  ```

- [ ] Step 2 — create all 11 worktrees via `make worktree-setup`:
  ```bash
  make worktree-setup NAME=phase-c/test-view-approve-review
  make worktree-setup NAME=phase-c/test-view-review
  make worktree-setup NAME=phase-c/test-view-approve-status
  make worktree-setup NAME=phase-c/test-view-modify-entity
  make worktree-setup NAME=phase-c/test-view-manage-annotations
  make worktree-setup NAME=phase-c/test-view-manage-user
  make worktree-setup NAME=phase-c/test-endpoint-read-batch
  make worktree-setup NAME=phase-c/test-endpoint-write-batch
  make worktree-setup NAME=phase-c/test-endpoint-admin-batch
  make worktree-setup NAME=phase-c/test-composables-async-form
  make worktree-setup NAME=phase-c/test-composables-table
  ```

- [ ] Step 3 — dispatch all 11 agents in one parallel batch via `superpowers:dispatching-parallel-agents`. The review bandwidth risk (Risk 10) is mitigated by **batch review** per §2.3 and §5.2:

  > For Phase C, reviews are batch-reviewed (all 11 PRs reviewed in one focused session via `superpowers:requesting-code-review`) to compress human bandwidth.

  Each agent opens its PR via `superpowers:verification-before-completion` gating on a green `make ci-local`. PRs accumulate; the reviewer runs one batch session answering the Checkpoint #2 question across all 11.

- [ ] Step 4 — **last-merging Phase C PR** (at the reviewer's choice) bumps `app/vitest.config.ts` coverage threshold from 45 → 55 (§4.6). The threshold-bump commit lands with the tests that make it pass — never as a separate PR.

- [ ] Step 5 — Risk 6 mitigation: if 9 of 11 worktrees merge on schedule but 2 straggle, Phase D may start on the merged-9 subset **only if the stragglers are for endpoints/composables that D does not touch**. If the stragglers are view tests (C1–C6), Phase D waits. The orchestrator verifies the D-unblocking condition before opening Phase D.

---

## 5 — TDD loop (from §4.2)

Phase C writes new tests against unmodified source. The §4.2 loop adapts:

```
1. make worktree-setup NAME=phase-c/<unit>
2. cd worktrees/phase-c/<unit>
3. make install-dev
4. make doctor
5. Read the target file(s) read-only. Do not modify them.
6. Author the new spec/test file with the required blocks (view: happy + error + it.todo;
   endpoint: per HTTP method per route per exit criterion #5).
7. Run the new test:
     - C1–C6: cd app && npx vitest run src/views/<path>.spec.ts
     - C7–C9: docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-<name>.R')"
     - C10, C11: cd app && npx vitest run src/composables/<path>.spec.ts
   The new test MUST be GREEN on unchanged source. If it is red on unchanged source, the test is wrong — not the source.
8. For C7/C8/C9 only: run the rollback audit on sibling test-integration-*.R files.
9. make ci-local                                            # must be green before opening the PR
10. Open PR via superpowers:requesting-code-review
```

**Rules that still apply:**
- No view (`.vue`), endpoint (`.R`), service, or composable source file may be modified in Phase C. The only allowed edits to pre-existing files are C7/C8/C9's rollback-audit wrappers on `test-integration-*.R`.
- No new MSW handlers may be added. If a handler is needed, STOP — the gap must be closed by a reinforcing Phase B worktree, not by forking B1 in Phase C.

---

## 6 — Test-gate reference (from §2.5)

Layer 1 (structural): Phase C worktrees are created off Phase-B-merged `master`. All 11 worktrees create new test files. By definition, no protecting test exists yet and the Layer 1 rule passes trivially.

Layer 2 (CI-enforced): B4's real `verify-test-gate.sh` runs on every Phase C PR. It allows:
- New `*.spec.ts` files under `app/src/views/**`, `app/src/composables/**` (all C1–C6, C10, C11).
- New `test-endpoint-*.R` files (C7, C8, C9).
- Rollback-audit wrappers on pre-existing `test-integration-*.R` files (C7/C8/C9 exemption, documented in commit message).

It rejects: any modification to pre-existing `.vue`, endpoint `.R`, service, composable, or `.spec.ts` source files.

Layer 3 (human): **Checkpoint #2 below** is the Layer 3 for Phase D / Phase E. Phase C itself has no Layer 3 check on its inputs.

---

## 7 — Human checkpoint

**Checkpoint #2 of 3 (§2.7, the most important checkpoint in the milestone):**

> After Phase B+C, before Phase D opens — the most important checkpoint. Human reads every view spec file and answers: *"Are these tests a meaningful safety net for the refactor that's about to happen?"* This is where tautological tests get caught.

The reviewer runs this checkpoint as a **batch review** (Risk 10 mitigation, §5.2) across all 11 Phase C PRs in one focused session via `superpowers:requesting-code-review`. Questions:

1. **Tautology check (Risk 1, §5.2 Layer 2):** For each of C1–C6's spec files, answer: *"If I rewrote this view to do something subtly different, would this test catch it?"* If the answer is no for any view, open a reinforcing Phase C worktree (`v11.0/phase-c/<reinforcement-name>`) before Phase D is unblocked.

2. **Handshake check (§2.6):** For each of C1, C3, C4, C5, C6, and (optionally) C2, confirm the `it.todo` is concrete enough that Phase E's rewriting agent can turn it into a passing assertion. A vague `it.todo('improve this later')` fails the handshake check.

3. **MSW shape sanity (§4.3, residual Risk 2):** For 3 random B1 handlers consumed by Phase C tests, `curl` the real dev API and diff the real response body against the MSW fixture body. ~5 minutes. Catches drift before Phase D/E consumes the handlers.

4. **Scope locked per exit criterion #5:** confirm C7/C8/C9 tests are structured per HTTP method per route, not per file. Randomly spot-check `test-endpoint-review.R` (the largest) against `api/endpoints/review_endpoints.R` to verify every `@get`/`@post`/`@put`/`@delete` route has a matching `test_that()` block per method.

5. **Default-on rollback:** confirm every `test-integration-*.R` file opens with `with_test_db_transaction` or a documented exemption. Run `scripts/verify-test-gate.sh --extended` if the script's extended mode exposes this.

**If any of the five checks fails, Phase D does not open.** Open a reinforcing worktree and re-run the checkpoint.

---

## 8 — Phase gate commands (from §2.3)

Run on clean `master` after every Phase C PR merges:

```bash
# Mechanical "phase done" detection (§2.3)
git branch --list 'v11.0/phase-c/*' | wc -l               # must be 0
git ls-remote --heads origin 'v11.0/phase-c/*' | wc -l    # must be 0
make ci-local                                             # must be green on master
```

Plus the Phase C-specific gate additions (§3 Phase C gate):

```bash
# Frontend coverage threshold bumped 45 → 55
grep -q '"lines": 55' app/vitest.config.ts
grep -q '"functions": 55' app/vitest.config.ts
grep -q '"branches": 55' app/vitest.config.ts
grep -q '"statements": 55' app/vitest.config.ts

# Backend coverage printed by make test-api (advisory only in v11.0)
make test-api 2>&1 | grep -Eq "coverage.*[0-9]+\.[0-9]+%"

# Default-on transaction rollback applied across all integration tests
# (B4's extended-mode grep from scripts/verify-test-gate.sh)
bash scripts/verify-test-gate.sh --extended

# Human Checkpoint #2 sign-off (tracked in the v11.0 milestone doc or PR description)
```

**Phase C is done only when all checks pass and Checkpoint #2 has been signed off.** At that point, Phase D opens off the new `master` SHA.
