# v11.0 Phase B — Tier A Test Infrastructure (Unblock Everything)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to orchestrate this phase session; it will call `superpowers:dispatching-parallel-agents` and `superpowers:using-git-worktrees`. Each worktree executes as its own subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase B.

**Phase goal:** Land the test infrastructure that unblocks every Phase C / D / E unit — MSW handler expansion with `onUnhandledRequest: 'error'`, real `httptest2` fixtures, `skip_if_not_slow_tests` wiring, a CI smoke test + real `scripts/verify-test-gate.sh`, and eviction of every `Sys.sleep` from the R test suite.

**Phase architecture:** 5 fully parallel worktrees off Phase-A-merged `master`. Nothing in Phase B is a structural refactor; everything is infrastructure. All 5 can run concurrently — §3 says "all parallel" in the wave summary and §2.4's ownership table shows no intersections.

**Tech stack:** MSW + vitest + `@vue/test-utils`, R `httptest2`, GitHub Actions, Docker Compose, Bash.

**Locked decisions from spec Appendix C (do not re-open):**
- **B1 handler count and paths are fully enumerated.** The table in §3 Phase B.B1 is authoritative — do not widen, narrow, or rewrite it. The handlers listed must be implemented as-is.
- **Exit criterion #5** (per HTTP method per route) is Phase C scope, not Phase B — do not pre-work it here.
- **E7 auth consolidation** is Phase E scope — B1 mocks the new POST/PUT shapes from A1, but does not touch auth composables.

---

## 1 — Prerequisites check

Before opening this phase, confirm:

- [ ] Phase A is **done** per its own gate (§2.3):
  ```bash
  git branch --list 'v11.0/phase-a/*' | wc -l              # must be 0
  git ls-remote --heads origin 'v11.0/phase-a/*' | wc -l   # must be 0
  ```
- [ ] `make ci-local` green on clean `master`.
- [ ] `make doctor` exits 0 (A7's deliverable is live).
- [ ] `make install-dev` succeeds from a fresh clone (A7's deliverable).
- [ ] Human Checkpoint #1 (§2.7) was signed off after Phase A.
- [ ] A1's new POST/PUT auth shapes are on `master` — B1 handlers will mirror them.
- [ ] A6's `scripts/verify-test-gate.sh` stub exists at `scripts/verify-test-gate.sh`. B4 will replace it in-place.
- [ ] No `v11.0/phase-b/*` branches exist locally or remotely.

If any check fails, stop and escalate. Do not re-open Phase A from within Phase B.

---

## 2 — Worktree manifest

All 5 worktrees branch off current `master` via `make worktree-setup NAME=phase-b/<unit>` (A7 deliverable).

| # | Branch | Worktree path | Exclusive write ownership (§2.4, §3) | Merge order |
|---|---|---|---|---|
| B1 | `v11.0/phase-b/msw-handler-expansion` | `worktrees/phase-b/msw-handler-expansion` | `app/src/test-utils/mocks/handlers.ts`, `app/src/test-utils/mocks/data/*` (new static JSON fixtures mirroring OpenAPI shapes from `api/config/openapi/`), `app/vitest.setup.ts` (flip `onUnhandledRequest: 'warn'` → `'error'`), `app/vitest.config.ts` (coverage threshold 40 → 45), `app/src/test-utils/mocks/handlers.spec.ts` (new), `scripts/verify-msw-against-openapi.sh` (new) | Parallel |
| B2 | `v11.0/phase-b/pubmed-pubtator-fixtures` | `worktrees/phase-b/pubmed-pubtator-fixtures` | `api/tests/testthat/fixtures/pubmed/*` (new captures), `api/tests/testthat/fixtures/pubtator/*` (new captures), `api/tests/testthat/helper-fixtures.R` (new), `api/tests/testthat/fixtures/README.md` (new), `Makefile` `refresh-fixtures` target (new, disjoint section from A7/A4/A6 Makefile edits) | Parallel |
| B3 | `v11.0/phase-b/skip-slow-wiring` | `worktrees/phase-b/skip-slow-wiring` | `.github/workflows/ci.yml` (add new `slow-tests-nightly` job via `schedule:` trigger — disjoint section from B4's `smoke-test` job), the audited list of `api/tests/testthat/test-*.R` files that hit Mailpit or live external APIs | Parallel |
| B4 | `v11.0/phase-b/ci-smoke-test` | `worktrees/phase-b/ci-smoke-test` | `.github/workflows/ci.yml` (add new `smoke-test` job — disjoint section from B3's `slow-tests-nightly` job), `scripts/ci-smoke.sh` (new), `scripts/verify-test-gate.sh` (replace A6's stub in-place with real logic) | Parallel |
| B5 | `v11.0/phase-b/sys-sleep-eviction` | `worktrees/phase-b/sys-sleep-eviction` | `api/tests/testthat/helper-wait.R` (new), the audited list of test files currently containing `Sys.sleep` — per review: 3 in `test-e2e-user-lifecycle.R`, 1 in `helper-mailpit.R` | Parallel |

**Intra-phase ownership rule (§2.4):** B3 and B4 both edit `.github/workflows/ci.yml`. They own distinct job blocks: B3 adds `slow-tests-nightly` (`schedule:` trigger), B4 adds `smoke-test` (`push`/`pull_request` triggers). If the two merge close in time and produce a trivial conflict inside `jobs:`, the resolution is "keep both job blocks" — never drop a job.

B3 and B5 both modify `test-e2e-user-lifecycle.R` and `helper-mailpit.R`: B3 wraps Mailpit-dependent `test_that()` blocks in `skip_if_not_slow_tests()`, B5 replaces `Sys.sleep(N)` with `wait_for(condition, timeout = N)`. **Resolution rule:** B5 merges first when there is a conflict, because `wait_for` replaces the `Sys.sleep` line entirely and B3's skip wrapper is trivially re-applicable on top. If B3 lands first, B5 must rebase and resolve the skip wrapper around the new `wait_for` call. Either order is safe; the B5-first rule exists only as the default tiebreaker.

---

## 3 — Per-worktree task spec

### B1 — `msw-handler-expansion`

- [ ] **Goal (§3 Phase B.B1):** Add MSW handlers for every real axios call site in the six top views, cross-referenced against real `@get`/`@post`/`@put`/`@delete` annotations in `api/endpoints/*.R`.

- [ ] **File ownership (exclusive writes):**
  - Modify: `app/src/test-utils/mocks/handlers.ts` — add handlers per the **locked table** below.
  - Create: `app/src/test-utils/mocks/data/*.ts` — static JSON fixtures mirroring the OpenAPI response shapes under `api/config/openapi/`. One file per response family is fine (e.g. `reviews.ts`, `users.ts`); the split is a judgment call, but no file exceeds 300 LoC.
  - Modify: `app/vitest.setup.ts` — flip `onUnhandledRequest: 'warn'` → `'error'`.
  - Modify: `app/vitest.config.ts` — bump coverage threshold from 40 → 45 (lines / functions / branches / statements).
  - Create: `app/src/test-utils/mocks/handlers.spec.ts` — a smoke test that each handler returns its declared 2xx and 4xx shape.
  - Create: `scripts/verify-msw-against-openapi.sh` — greps every handler path in `handlers.ts` and asserts the underlying `@get`/`@post`/`@put`/`@delete` annotation exists in the corresponding `api/endpoints/*.R` file. Runs as part of `make lint-app`.

- [ ] **Locked handler table (§3 Phase B.B1, Appendix C — DO NOT REOPEN):**

  | View / flow | Handlers |
  |---|---|
  | Auth (post-A1) | `POST /api/auth/authenticate` (new body shape), `GET /api/auth/refresh`, `GET /api/auth/signin` |
  | User admin (`ManageUser.vue`) | `GET /api/user/table`, `GET /api/user/role_list`, `GET /api/user/list`, `PUT /api/user/update`, `PUT /api/user/delete`, `POST /api/user/bulk_approve`, `POST /api/user/bulk_assign_role`, `POST /api/user/bulk_delete`, `PUT /api/user/password/update` (post-A1 body shape) |
  | Review workflow (`ApproveReview.vue`) | `GET /api/review/<id>`, `GET /api/review/<id>/phenotypes`, `GET /api/review/<id>/variation`, `GET /api/review/<id>/publications`, `POST /api/review/create`, `PUT /api/review/update`, `PUT /api/review/approve/<id>`, `PUT /api/review/approve/all` |
  | Status workflow (`ApproveStatus.vue`, `ApproveReview.vue`) | `GET /api/status/<id>`, `POST /api/status/create`, `PUT /api/status/update`, `PUT /api/status/approve/<id>`, `PUT /api/status/approve/all` |
  | Entity curation (`ModifyEntity.vue`) | `GET /api/entity/<sysndd_id>`, `POST /api/entity/create`, `POST /api/entity/rename`, `POST /api/entity/deactivate`, `GET /api/entity/<sysndd_id>/review`, `GET /api/entity/<sysndd_id>/status` |
  | Review wizard (`Review.vue`) | `GET /api/entity/<sysndd_id>/review`, `POST /api/review/create`, `PUT /api/review/update` |
  | Annotation jobs (`ManageAnnotations.vue`) | `GET /api/jobs/history`, `GET /api/jobs/<job_id>/status`, `POST /api/jobs/hgnc_update/submit`, `POST /api/jobs/ontology_update/submit`, `POST /api/jobs/comparisons_update/submit`, `POST /api/jobs/clustering/submit`, `POST /api/jobs/phenotype_clustering/submit` |

  **There is no job-cancel endpoint in the current API.** Do not mock one. C5's error path (Phase C) uses the `status = "blocked"` pattern instead.

- [ ] **Acceptance (§3 Phase B.B1):**
  - Every handler in the table above has a 2xx happy path and at least one 4xx branch reachable via a distinguishable request shape.
  - Every handler has the OpenAPI path as a code comment above the handler (§4.3).
  - `handlers.spec.ts` smoke-tests each handler.
  - `scripts/verify-msw-against-openapi.sh` runs green and fails on a synthetic fake path (test it with a temporary fake handler before committing).
  - Coverage threshold in `vitest.config.ts` bumped to 45.
  - Full existing vitest suite green with `onUnhandledRequest: 'error'` (B1's own acceptance — no pre-existing test may be left failing because of the switch).
  - `cd app && npm run test:unit` green.
  - `cd app && npm run type-check` green.
  - Handler paths for Auth and User password change mirror the post-A1 POST/PUT shapes landed in Phase A — confirmed by grep against `api/endpoints/auth_endpoints.R` and `api/endpoints/user_endpoints.R` on current `master`.

- [ ] **TDD loop reference (§4.2 variant):** B1 is an infrastructure worktree. The loop is:
  1. Write `handlers.spec.ts` assertions for each handler before wiring the handler.
  2. Run `npm run test:unit` — specs fail with "handler not found."
  3. Add each handler with its 2xx + 4xx branches.
  4. Run `npm run test:unit` — specs pass.
  5. Flip `onUnhandledRequest: 'error'` and re-run the full vitest suite. Fix any handler gap exposed by the flip in the same PR.
  6. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous (Phase B); Layer 2 — B1 creates new spec files (`handlers.spec.ts`), which is allowed by `scripts/verify-test-gate.sh` ("allowed only for new unit/composable specs"). No pre-existing spec files may be modified.

### B2 — `pubmed-pubtator-fixtures`

- [ ] **Goal (§3 Phase B.B2):** Replace the empty `.gitkeep`-only `httptest2` fixture directories with real captures; add a fail-loud helper.

- [ ] **File ownership:**
  - Create: `api/tests/testthat/fixtures/pubmed/*` — real captures from live PubMed API.
  - Create: `api/tests/testthat/fixtures/pubtator/*` — real captures from live PubTator API.
  - Create: `api/tests/testthat/helper-fixtures.R` — defines `skip_if_no_fixtures(subdir)`. Must fail the test loudly (not silent skip) if fixtures are missing; per §4.4 rule 1, an empty or `.gitkeep`-only directory is treated as "missing."
  - Create: `api/tests/testthat/fixtures/README.md` — lists every fixture, when it was recorded, what API version it corresponds to, and the capture command.
  - Modify: `Makefile` — add `refresh-fixtures` target that invokes the capture commands against real APIs when explicitly run by a developer. Do not run this from CI. Disjoint Makefile section from A7/A4/A6's targets.

- [ ] **Acceptance (§3 Phase B.B2, §4.4):**
  - Fixture files committed and non-empty (neither directory contains only `.gitkeep`).
  - `skip_if_no_fixtures("pubmed")` called with a missing fixture file errors loudly with a clear message, not a silent `skip()`.
  - `fixtures/README.md` lists every fixture with date, API version, and capture command.
  - `make refresh-fixtures` exists and works when explicitly invoked. Do not add it to `make ci-local`.
  - Existing `test-integration-pubtator*` tests pass using the new fixtures.
  - Risk 5 mitigation: the commit that adds any new R package for B2 also commits the `api/renv.lock` update, and the worktree runs `renv::status()` locally before opening the PR.

- [ ] **TDD loop reference (§4.2 variant):**
  1. Confirm a test that currently passes silently because fixtures are missing — `test-integration-pubtator.R` is the canonical example.
  2. Wire `skip_if_no_fixtures()` into that test. Run it — it errors loudly.
  3. Record the fixture via `make refresh-fixtures`.
  4. Re-run the test — it passes.
  5. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 2 — B2 creates a new `helper-fixtures.R` and new fixture files, both allowed. B2 may modify `test-integration-pubtator.R` to add the `skip_if_no_fixtures` call; this is not a non-`it.todo` change in the spec-refactor sense, and Phase B is not D/E, so the gate applies trivially — but the agent must document the edit in the commit message so B4's real `verify-test-gate.sh` (once landed) doesn't flag it.

### B3 — `skip-slow-wiring`

- [ ] **Goal (§3 Phase B.B3):** Wire `skip_if_not_slow_tests()` (currently defined in `helper-skip.R` but uncalled) into Mailpit-dependent and live-API tests. Add the `slow-tests-nightly` CI job.

- [ ] **File ownership:**
  - Modify: `.github/workflows/ci.yml` — add the `slow-tests-nightly` job under `jobs:`, triggered by `schedule:` (e.g. `cron: '0 3 * * *'`). Runs `RUN_SLOW_TESTS=true make test-api-full`. **Do not touch B4's `smoke-test` job.**
  - Modify: the audited list of `api/tests/testthat/test-*.R` files that currently hit Mailpit or a live external API. The audit is produced by:
    ```bash
    grep -rln "mailpit\|pubmed\|pubtator" api/tests/testthat/ | grep -v helper-
    ```
    Each hit receives a `skip_if_not_slow_tests()` call at the top of its `test_that()` block.

- [ ] **Acceptance (§3 Phase B.B3):**
  - `grep -r "skip_if_not_slow_tests" api/tests/testthat/ | wc -l` returns non-zero (currently zero).
  - Normal CI run (without `RUN_SLOW_TESTS=true`) completes without needing Mailpit.
  - Nightly `slow-tests-nightly` job runs the slow suite and is green on at least one scheduled run before Phase B's gate is signed off. If the nightly run hasn't fired yet by the gate check, a manual workflow dispatch to `slow-tests-nightly` is acceptable evidence.

- [ ] **TDD loop reference (§4.2 variant):**
  1. Run `make test-api` on a fresh `master` without `RUN_SLOW_TESTS=true`. Any test that needs Mailpit but is not guarded will red-light.
  2. Add `skip_if_not_slow_tests()` to each red test.
  3. Re-run `make test-api` — all Mailpit-dependent tests are now skipped cleanly.
  4. Run `RUN_SLOW_TESTS=true make test-api` locally (Mailpit up) — they execute and pass.
  5. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 2 — B3 modifies pre-existing `test-*.R` files, but only to add a skip wrapper. Once B4's real `verify-test-gate.sh` is live, `skip_if_not_slow_tests()` additions must be in the list of allowed edits. **B4 must add this exemption when writing `verify-test-gate.sh`; see B4 spec below.**

### B4 — `ci-smoke-test`

- [ ] **Goal (§3 Phase B.B4, §2.5 Layer 2):** Add a CI job that boots the full docker stack and hits `/api/health/ready`; fill in the real `scripts/verify-test-gate.sh` logic.

- [ ] **File ownership:**
  - Modify: `.github/workflows/ci.yml` — add the `smoke-test` job under `jobs:`, triggered by `push` and `pull_request`. Runs `scripts/ci-smoke.sh`. **Do not touch B3's `slow-tests-nightly` job.**
  - Create: `scripts/ci-smoke.sh` — wraps `make preflight` + a `curl -f` against `/api/health/ready` with a reasonable retry loop.
  - Replace in place: `scripts/verify-test-gate.sh` — replace A6's stub with real logic:
    ```bash
    # For every *.spec.ts or test-*.R file modified in this PR:
    #   - was the file created in this PR? (allowed for new unit/composable specs)
    #   - if pre-existing, does the diff touch anything other than an `it.todo` unpinning?
    # If a pre-existing test file has non-.todo changes in a D/E PR: FAIL.
    ```
    Expected size: ~40 lines of bash (`git merge-base` + `git log --follow` + `git diff`).
    **Allowed edit exemption:** the script must recognise that a `skip_if_not_slow_tests()` addition (introduced by B3) is a legal change on pre-existing files in Phase B only. Gate the exemption on branch prefix (`v11.0/phase-b/*`) so it does not leak into Phase D/E.
    **Extended mode (§4.5):** the script also greps every `api/tests/testthat/test-integration-*.R` file and asserts it opens with either `with_test_db_transaction` or a documented `skip_if_no_test_db()` exemption explaining why rollback isn't usable.

- [ ] **Acceptance (§3 Phase B.B4):**
  - The `smoke-test` CI job passes on a PR that boots the stack.
  - The same job fails on a synthetic PR that corrupts `api/start_sysndd_api.R` to break startup. Verify this by temporarily introducing `stop("simulated boot failure")` in a local branch and confirming the CI job fails; revert before merging.
  - `scripts/verify-test-gate.sh` returns non-zero for a synthetic Phase D/E violation (modify a pre-existing spec file in a branch named `v11.0/phase-d/test-synthetic` and confirm the script rejects it).
  - `scripts/verify-test-gate.sh` returns zero for a legal Phase C unit-spec creation.
  - Extended-mode grep catches a synthetic integration test that opens without `with_test_db_transaction`.

- [ ] **TDD loop reference (§4.2 variant):**
  1. Write a bash unit test harness for `scripts/verify-test-gate.sh` under `scripts/tests/` (lightweight — a small test fixture directory and an assert helper).
  2. Write each case (new spec allowed, pre-existing spec non-`.todo` change rejected, `skip_if_not_slow_tests` exemption allowed on phase-b branch only, extended-mode rollback grep).
  3. Run the harness — initial failures.
  4. Implement the script logic incrementally, retesting after each case.
  5. Harness green.
  6. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 2 — B4 creates new files (`scripts/ci-smoke.sh`, `scripts/tests/*`) and replaces a stub file (`scripts/verify-test-gate.sh`). The stub replacement is not a spec file, so the verify-test-gate rule does not apply to it.

### B5 — `sys-sleep-eviction`

- [ ] **Goal (§3 Phase B.B5):** Replace every `Sys.sleep(N)` in `api/tests/testthat/**/*.R` with an event-based wait helper.

- [ ] **File ownership:**
  - Create: `api/tests/testthat/helper-wait.R` — defines `wait_for(condition, timeout = 10)`. Returns the condition's value on success; fails the test loudly on timeout with a clear message.
  - Modify: the audited list of test files currently containing `Sys.sleep`. Per the review, there are 3 call sites in `test-e2e-user-lifecycle.R` and 1 in `helper-mailpit.R`. Verify with:
    ```bash
    grep -rn "Sys\.sleep" api/tests/testthat/
    ```

- [ ] **Acceptance (§3 Phase B.B5):**
  - `grep -rn "Sys\.sleep" api/tests/testthat/` returns zero.
  - `wait_for(...)` is called at each replaced site.
  - 10 consecutive CI runs of the test suite complete without flake from any converted test. The 10-run count is satisfied via a tight loop re-running the affected tests, e.g.:
    ```bash
    for i in $(seq 1 10); do
      docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-e2e-user-lifecycle.R')" || exit 1
    done
    ```
    Evidence: paste the 10-run output into the PR description.

- [ ] **TDD loop reference (§4.2 variant):**
  1. Audit the `Sys.sleep` call sites and for each, identify the condition the sleep is masking.
  2. Write `helper-wait.R::wait_for()` with a failing unit test.
  3. Implement `wait_for()` until the unit test passes.
  4. Replace each `Sys.sleep(N)` with `wait_for(<condition>, timeout = N)`.
  5. Run the 10-iteration loop above.
  6. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 2 — B5 modifies pre-existing `test-e2e-user-lifecycle.R` and `helper-mailpit.R` to replace `Sys.sleep`. This is a non-`it.todo` change, but Phase B is not D/E, so the gate does not apply. B4's `verify-test-gate.sh` must not flag Phase B edits — confirmed by the phase-prefix gating in B4's script.

---

## 4 — Parallel dispatch block

All 5 worktrees run concurrently (§3 Phase B: "all parallel").

```
SEQUENCE 1 (5-way parallel from Phase-A-merged master):
  B1 — msw-handler-expansion
  B2 — pubmed-pubtator-fixtures
  B3 — skip-slow-wiring
  B4 — ci-smoke-test
  B5 — sys-sleep-eviction
```

**Dispatch mechanics:**

- [ ] Step 1 — rebase local `master`:
  ```bash
  git checkout master && git pull --ff-only
  ```

- [ ] Step 2 — create all 5 worktrees:
  ```bash
  make worktree-setup NAME=phase-b/msw-handler-expansion
  make worktree-setup NAME=phase-b/pubmed-pubtator-fixtures
  make worktree-setup NAME=phase-b/skip-slow-wiring
  make worktree-setup NAME=phase-b/ci-smoke-test
  make worktree-setup NAME=phase-b/sys-sleep-eviction
  ```

- [ ] Step 3 — dispatch all 5 agents in one parallel batch via `superpowers:dispatching-parallel-agents`. Each agent runs `make install-dev` and `make doctor` inside its worktree before beginning work.

- [ ] Step 4 — each agent opens its own PR using `superpowers:verification-before-completion` to gate the PR on a green `make ci-local`. PR reviews happen per-unit (no batch review in Phase B).

- [ ] Step 5 — merge order: no strict order required, but if B3 and B4 conflict on `ci.yml`, resolve by keeping both job blocks. If B3 and B5 conflict on the Mailpit test file, B5 merges first (see §2).

---

## 5 — TDD loop (from §4.2)

Phase B is infrastructure, not refactor. The §4.2 loop adapts to the "test the tool before shipping the tool" pattern:

```
1. make worktree-setup NAME=phase-b/<unit>
2. cd worktrees/phase-b/<unit>
3. make install-dev                                         # idempotent
4. make doctor                                              # verify env
5. Author the new helper/handler/script with a failing smoke test in the same commit.
6. Run the smoke test locally. First run must be RED.
7. Implement until the smoke test is GREEN.
8. Run the full relevant test suite:
     - B1, B2, B5: make ci-local
     - B3:         make ci-local + manual workflow_dispatch of slow-tests-nightly
     - B4:         make ci-local + the synthetic violation test described in B4 acceptance
9. Open PR via superpowers:requesting-code-review
```

**Rule that still applies:** no Phase B worktree modifies a pre-existing `*.spec.ts` file. B3 and B5 may modify pre-existing `test-*.R` files for the specific exempted patterns (skip wrappers, `Sys.sleep` replacement); B4's `verify-test-gate.sh` explicitly allows this on `v11.0/phase-b/*` branches.

---

## 6 — Test-gate reference (from §2.5)

Layer 1 (structural): the `scripts/verify-test-gate.sh` that runs on every Phase B PR is either A6's stub (until B4 merges) or B4's real implementation (after B4 merges). Either way, Phase B PRs pass trivially.

Layer 2 (CI-enforced): B4 **replaces** the stub with the real implementation. The real implementation is what protects Phase D/E from test-gate violations. Its acceptance criteria (§3 above) include:
- Allowing new unit/composable spec file creation.
- Rejecting non-`it.todo` edits to pre-existing spec files on `v11.0/phase-d/*` and `v11.0/phase-e/*` branches.
- Allowing `skip_if_not_slow_tests()` additions on `v11.0/phase-b/*` branches only.
- Extended-mode rollback grep on `test-integration-*.R` files.

Layer 3 (human): Phase B has no refactors to protect, so Layer 3 doesn't apply until Phase D opens.

---

## 7 — Human checkpoint

**No dedicated human checkpoint for Phase B in §2.7.** Phase B's output is consumed by Phase C (which has Checkpoint #2 after it). Phase B merges without a ceremony; its value is validated at Checkpoint #2 when the view specs (Phase C) actually consume the B1 handlers and fail loudly on any gap.

However, before closing Phase B, the executor should still sanity-check:

- [ ] B1: manually `curl` 3 random endpoints from the locked handler table against the dev stack (`make dev`) and diff the real response body against the MSW fixture body. This is the §4.3 "5-minute sanity check" but performed at Phase B close, not Checkpoint #2. It is cheaper to catch an MSW shape drift here than at Checkpoint #2.
- [ ] B4: confirm the `smoke-test` CI job is green on `master` on at least one real push. The smoke test run must be visible in `gh run list --workflow ci.yml`.

---

## 8 — Phase gate commands (from §2.3)

Run on clean `master` after every Phase B PR merges:

```bash
# Mechanical "phase done" detection (§2.3)
git branch --list 'v11.0/phase-b/*' | wc -l               # must be 0
git ls-remote --heads origin 'v11.0/phase-b/*' | wc -l    # must be 0
make ci-local                                             # must be green on master
```

Plus the Phase B-specific gate additions (§3 Phase B gate):

```bash
# B4's CI smoke test has run successfully on at least one real PR
gh run list --workflow ci.yml --branch master --limit 5 | grep -q "smoke-test.*success"

# onUnhandledRequest: 'error' is active (no pre-existing vitest failing because of the switch)
grep -q "onUnhandledRequest: 'error'" app/vitest.setup.ts
cd app && npm run test:unit                               # must be green
```

**Phase B is done only when all checks pass.** At that point, Phase C opens off the new `master` SHA.
