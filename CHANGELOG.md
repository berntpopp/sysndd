# Changelog

All notable changes to SysNDD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

## [Unreleased]

_Nothing yet. See `.plans/v11.0/` for work in progress._

## [0.11.5] — 2026-04-11

Phase B of the v11.0 test foundation initiative — Tier A test infrastructure that unblocks every Phase C / D / E unit. All 5 units (B1–B5) landed as one combined release. **No runtime code changed**; this is exclusively dev/test infrastructure (MSW handlers, httptest2 fixtures, CI jobs, test helpers, verify-test-gate logic). Patch bump per SemVer.

### Added

- **B1 — MSW handler expansion (app/src/test-utils/mocks/).** The vitest MSW layer now covers every handler in the locked Phase B.B1 table: 38 handlers across 6 view families (Auth, User admin, Review workflow, Status workflow, Entity curation, Annotation jobs). Every handler has a 2xx happy path and at least one 4xx branch distinguishable by request shape, and every handler carries an OpenAPI-path comment above it.
  - New fixture modules under `app/src/test-utils/mocks/data/`: `auth.ts`, `users.ts`, `reviews.ts`, `statuses.ts`, `entities.ts`, `jobs.ts` (split by response family, each under 300 LoC).
  - New smoke spec `app/src/test-utils/mocks/handlers.spec.ts` — 77 assertions, one 2xx and one 4xx case per handler, catches handler drift on first run.
  - New shell script `scripts/verify-msw-against-openapi.sh` — greps every handler path against the real `@get`/`@post`/`@put`/`@delete` annotations in `api/endpoints/*.R` and reports drift. Wired into `make lint-app`.
  - New `scripts/msw-openapi-exceptions.txt` — whitelists 4 entries where the locked spec table points at endpoints that don't exist (yet) on master. Each entry is a spec-bug flag for Phase C to resolve, not a handler bug: `PUT /api/user/delete` (real annotation is `@delete delete`), `PUT /api/review/approve/all` (no bulk route), `PUT /api/status/approve/all` (no bulk route), `GET /api/entity/:sysndd_id` (no bare getter — only sub-path routes). The verify script exits non-zero on any unlisted drift.
- **B2 — real PubMed/PubTator httptest2 fixtures.** Replaced the previously empty `api/tests/testthat/fixtures/{pubmed,pubtator}/` directories with 6 real captures (3 pubmed + 3 pubtator, 32.7 KB total), recorded via a new `make refresh-fixtures` target against the live NCBI eUtils and PubTator3 BioCJSON APIs on 2026-04-11. Captured via `httptest2::save_response(..., simplify = FALSE)` to preserve the full `httr2_response` object; not handcrafted JSON.
  - New helper `api/tests/testthat/helper-fixtures.R` — `skip_if_no_fixtures(subdir)` fails **loudly** on missing/empty fixture directories (both `testthat::fail()` and `stop()`, with an actionable message pointing at `make refresh-fixtures`). `.gitkeep`-only directories are treated as missing. Per spec §4.4 rule 1: the point is to make the silent-skip failure mode impossible to miss.
  - New `api/tests/testthat/fixtures/README.md` — documents every committed fixture with filename, recording date, API version, and exact capture command.
  - New `make refresh-fixtures` target (disjoint section from A7/A4/A6 Makefile edits) — invokes the capture commands against live APIs when explicitly run; **not** invoked from `make ci-local`.
  - `test-external-pubmed.R` and `test-external-pubtator.R` now call `skip_if_no_fixtures()` at the first `test_that()` of each file.
- **B3 — skip-slow-wiring.** Wired `skip_if_not_slow_tests()` (previously defined in `helper-skip.R` but never called) into 22 `test_that()` blocks across 4 audited files that actually hit Mailpit or live external APIs: `test-integration-email.R` (5 blocks), `test-external-pubtator.R` (3), `test-e2e-user-lifecycle.R` (11), `test-external-pubmed.R` (3). The other 4 files flagged by the audit grep (`test-unit-publication-functions.R`, `test-unit-pubtator-parse.R`, `test-unit-genereviews-functions.R`, `test-unit-pubtator-functions.R`) were classified MOCK — they contain the search terms only in comments, string assertions, or mocked bindings — and left untouched.
  - New `slow-tests-nightly` CI job in `.github/workflows/ci.yml` — cron `0 3 * * *` plus `workflow_dispatch`, runs `RUN_SLOW_TESTS=true make test-api-full` with MySQL + Mailpit service containers. Correctly skipped on normal PR runs (verified: the pull_request run's `Slow Tests (nightly)` resolves to `skipping` while `Test R API` runs green in ~23 min without Mailpit). Bannered as `# ===== Phase B B3: slow-tests-nightly =====` to make the combined-merge with B4's `smoke-test` job trivial.
- **B4 — CI smoke test + real verify-test-gate.sh.** New `smoke-test` CI job in `.github/workflows/ci.yml` (triggered on `push` and `pull_request`) runs `scripts/ci-smoke.sh` which wraps `make preflight` plus a `curl -f` retry loop against `/api/health/ready`. Bannered as `# ===== Phase B B4: smoke-test =====` (disjoint from B3's nightly block). `ci-success` gates on `smoke-test` (but not `slow-tests-nightly`, which is schedule-only).
  - New `scripts/ci-smoke.sh` — boots the full prod stack via `make preflight` and verifies readiness.
  - Replaced the A6 `scripts/verify-test-gate.sh` stub (2-line echo) with 121 lines of real logic. Protects Phase D / Phase E PRs from silently mutating pre-existing test files to "pin" them to whatever the refactor produced. Rule summary: new `*.spec.ts` / `test-*.R` files are allowed; modifications to pre-existing spec/test files are rejected **unless** one of two branch-gated exemptions applies — (a) adding `skip_if_not_slow_tests()` on `v11.0/phase-b/*` only (for B3), or (b) replacing `Sys.sleep(N)` with `wait_for(..., timeout = N)` on `v11.0/phase-b/*` only (for B5). `--extended` mode also greps every `api/tests/testthat/test-integration-*.R` file and asserts it opens with `with_test_db_transaction` or a documented `skip_if_no_test_db()` exemption.
  - New bash unit-test harness `scripts/tests/test-verify-test-gate.sh` — 7 cases (new-spec-allowed, pre-existing-spec-rejected, phase-b skip exemption allowed, phase-b wait_for exemption allowed, phase-b exemption does NOT leak into phase-d, extended-mode rejects integration test missing rollback, extended-mode accepts well-formed repo). All 7 cases pass.
  - New `make verify-gate` target wires the harness into CI without an R dependency.
- **B5 — Sys.sleep eviction.** Evicted every real `Sys.sleep(N)` from the R test suite (4 call sites in `test-e2e-user-lifecycle.R` at lines 181/215/323/539, 1 in `helper-mailpit.R` at line 116 — the other `Sys.sleep` occurrences in `test-unit-*.R` are `mockery::stub` bindings or `test-publication-refresh.R` comments and were correctly left untouched).
  - New helper `api/tests/testthat/helper-wait.R` (297 lines) — defines `wait_for(condition, timeout, label)` (event-based polling, fails loudly on timeout with a diagnostic including last observed state) and a sibling `wait_stable(probe, duration, label)` for the negative-assertion case ("no change should occur for N seconds"; fails immediately on any change, strictly faster than a fixed sleep + single check on failure).
  - `helper-mailpit.R::mailpit_wait_for_message` refactored to delegate to `wait_for()` — no more internal `Sys.sleep` polling.
  - The 4 e2e call sites were all "no email should arrive" negative assertions, now using `wait_stable(mailpit_message_count, N)` with a baseline captured just before the action. The `wait_stable` approach fails immediately on any unexpected email rather than waiting the full sleep window.
  - 10-iteration flake check passed 10/10 in the prod sysndd-api Docker container (helper-wait self-tests: 10/10, 190/190 assertions; test-e2e-user-lifecycle.R load + dispatch: 10/10, all 11 `test_that` blocks reach `skip_if_no_mailpit()`/`skip_if_no_api()` cleanly).

### Changed

- `app/vitest.setup.ts` — MSW `onUnhandledRequest` flipped from `'warn'` to `'error'`. Every unmocked request now hard-fails the test, making any handler gap impossible to miss. Acceptance criterion: no pre-existing vitest was left failing because of this switch (full suite of 321 tests still green on the combined branch).
- `app/vitest.config.ts` — coverage thresholds pinned at the current measured floor (`lines: 6`, `functions: 4`, `branches: 4`, `statements: 6`). B1 originally "bumped 40 → 45" but the actual coverage is only 4–7% because `test-utils/` is excluded from the coverage denominator — the original 40 threshold was decorative since no CI job runs `npm run test:coverage`. Thresholds now form a ratchet that future phases must raise as specs land; see the inline comment in `app/vitest.config.ts` for the rule and rationale.

### Internal / dev tooling

- Bumped `app/package.json` and `api/version_spec.json` to `0.11.5`.
- Phase B work was developed across 5 parallel git worktrees (`v11.0/phase-b/*`) off Phase-A-merged master (`db18cb51`) and combined into a single PR for review, following the Phase A pattern. B5 merged first on the test-file conflicts (per the tiebreaker rule); B3 and B4's disjoint `ci.yml` job blocks merged cleanly with both banners intact; `ci-success.needs` correctly unions to include `smoke-test` (PR-gating) but not `slow-tests-nightly` (schedule-only).
- End-to-end verification on the combined branch was done via a Playwright monkey-walk against the full dev stack (traefik + api + app + mysql + mailpit) bound to the combined worktree. Walked 13 routes including unauth public views (Genes, Entities, Phenotypes, Panels, PublicationsNDD, Gene detail, About), the post-A1 `POST /api/auth/authenticate` login flow end-to-end against the live API (not a mock), and 4 authed views covering B1's mocked handler families (`/`, `/ManageUser`, `/ManageAnnotations`, `/ApproveReview`, `/ApproveStatus`). Zero Phase-B-introduced regressions; the only console errors encountered were (a) the expected 401 on `/api/auth/signin` for unauthenticated visitors and (b) two pre-existing 404s on `/api/external/{mgi,rgd}/phenotypes/A2ML1` that reflect a data gap in the upstream MGI/RGD records, unrelated to Phase B.
- Per-endpoint sanity-check (§7 of `.plans/v11.0/phase-b.md`): curled 4 handler-table endpoints against the live API on the combined worktree and confirmed B1's mock shapes are faithful — `GET /api/status/1` returns a full status record matching the mock shape; `POST /api/auth/authenticate` with bad creds returns HTTP 400 with the documented "Please provide valid username and password." body (matches B1's 4xx branch); `GET /api/user/role_list` and `GET /api/jobs/history` return 403 without a JWT (consistent with the `require_auth` middleware behaviour B1 assumes).

### Post-review fixes on PR #236

The first push of this PR surfaced six actionable items from the automated Copilot review plus one CI failure (smoke-test could not build) plus one misconfigured gate (vitest coverage thresholds). All are fixed in the final combined branch before merge — commit `chore(phase-b/combined): fix Copilot review + codecov + CI smoke-test`:

- **Copilot #1 — Makefile `.PHONY` gap.** `verify-gate` added to the `.PHONY` declaration so a stray file of that name cannot shadow the target.
- **Copilot #2 — `%||%` in `api/scripts/capture-external-fixtures.R`.** Replaced the rlang-only operator with a base-R fallback that resolves the script path via `sys.frame(1)$ofile`, then `commandArgs(trailingOnly = FALSE)` `--file=`, then `"."`. The script no longer has an implicit rlang dependency.
- **Copilot #3 — `helper-wait.R::is_truthy` was too permissive.** The old `is.atomic(v) -> TRUE` branch would return early on `0`, `NA`, `""`, `FALSE`, defeating the "wait until ready" semantics for any probe that uses a count-or-zero sentinel. Tightened to treat only `isTRUE()` logicals, non-empty lists, and non-empty data frames as truthy. A new 14-assertion test case (`wait_for does NOT treat atomic 0/NA/empty-string as truthy`) plus a 4-assertion test for non-empty list/data.frame pin the new semantics — verified 9/9 blocks / 35/35 assertions green in the sysndd-api prod container.
- **Copilot #4 — Bash 4+ in `verify-msw-against-openapi.sh`.** The associative array (`declare -A`) is replaced with a portable indexed array + `is_exception()` lookup so the script runs on Bash 3.2 — the version still shipped as `/bin/bash` on macOS. A defensive `BASH_VERSINFO` check surfaces a friendly error on anything older.
- **Copilot #5 — CI smoke-test failure.** The first PR-236 push made the smoke-test CI job fail at the Docker build step (`"/config.yml": not found`) because `api/config.yml` is gitignored on dev machines but the prod Dockerfile does `COPY config.yml config.yml`. Fix: committed `api/config.yml.example` with CI-safe dummy values (structurally identical to the real config, credentials aligned with `.env.example`'s placeholders so the dummy API container can actually reach the dummy MySQL user) and extended `scripts/ci-smoke.sh` with a `seed_from_template` step that copies `api/config.yml.example → api/config.yml` and `.env.example → .env` when either is missing. Idempotent — it does not overwrite real dev secrets.
- **Copilot #6 — `verify-test-gate.sh` Sys.sleep exemption was too permissive.** The old exemption accepted any diff on a `v11.0/phase-b/*` branch as long as it contained at least one removed `Sys.sleep(` line and one added `wait_for(...)` line — unrelated line changes could slip through. Tightened to a whitelist: every added/removed non-blank, non-comment line must match a narrow set of tokens (`wait_for(`, `wait_stable(`, named kwargs, closing paren, mailpit probe helpers, baseline assignments). A new harness case (`phase-b exemption rejects unrelated edits paired with Sys.sleep->wait_for`) pins the tightened behaviour; all 8 harness cases now pass.
- **Codecov / vitest coverage thresholds — pinned at realistic floor.** See `Changed` above.
- **Self-review S1 — `ERROR_SENTINELS` constants block.** Added a typed const export at the top of `app/src/test-utils/mocks/handlers.ts` documenting the path-param / query / header sentinels that trigger 4xx branches. Existing handlers and specs keep their literals for now; future handlers/specs should import from `ERROR_SENTINELS` so the contract is discoverable.

### Known limitations

- Same host-env constraint as 0.11.4: `make ci-local` still fails at the R lint/test steps on Ubuntu 25.10 "questing" hosts running Conda/miniforge R. Phase B's entire R test verification was done via the `sysndd-api` Docker container or deferred to CI on `ubuntu-latest`, which is the authoritative baseline. See the "Host-Env Workaround" section of `CLAUDE.md` for the details.
- `B1` flagged 4 drifts where the locked handler table points at endpoints that do not exist on master (whitelisted in `scripts/msw-openapi-exceptions.txt`). These are spec bugs for Phase C to resolve, not handler bugs — either the handler table needs updating or the missing endpoints need to be added in Phase C / D when the views actually consume them. See `scripts/msw-openapi-exceptions.txt` for the full list with rationale.

### References

- PR: [#230](https://github.com/berntpopp/sysndd/pull/230) — B3 skip-slow-wiring (individual, superseded by combined)
- PR: [#231](https://github.com/berntpopp/sysndd/pull/231) — B4 ci-smoke-test (individual, superseded by combined)
- PR: [#232](https://github.com/berntpopp/sysndd/pull/232) — B2 pubmed-pubtator-fixtures (individual, superseded by combined)
- PR: [#233](https://github.com/berntpopp/sysndd/pull/233) — B5 sys-sleep-eviction (individual, superseded by combined)
- PR: [#234](https://github.com/berntpopp/sysndd/pull/234) — B1 msw-handler-expansion (individual, superseded by combined)
- Plan: `.plans/v11.0/phase-b.md`
- Spec: `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase B

## [0.11.4] — 2026-04-11

Phase A of the v11.0 test foundation initiative. A1–A7 plus a focused follow-up, landed as one release.

### ⚠️ Upgrade notes — long-lived deployments must read this

On the **first API boot** after deploying this version against a database that was previously running `0.11.3` or earlier, the migration runner emits exactly one INFO log line:

```
[INFO] reconcile_schema_version_renames: rewriting schema_version.filename '008_hgnc_symbol_lookup.sql' -> '018_hgnc_symbol_lookup.sql'
```

This is the new `reconcile_schema_version_renames()` step in `api/functions/migration-runner.R` reconciling the filename rename introduced by **A4** (see _Changed_ below). It runs **before** the pending-migration diff, so the renamed migration is not re-executed.

- **No manual DML is required.** The reconciliation is idempotent: it is a no-op on every subsequent boot and on any fresh database where `008_hgnc_symbol_lookup.sql` was never recorded.
- **What would have happened without it:** `migration-runner.R`'s `setdiff(migration_files, applied)` would have seen `018_hgnc_symbol_lookup.sql` as pending and re-executed it. `CREATE TABLE IF NOT EXISTS` is safe, but the three `INSERT INTO hgnc_symbol_lookup` statements are **not** idempotent and would have duplicated rows.
- **Sanity check (optional but recommended):** `SELECT COUNT(*) FROM hgnc_symbol_lookup;` before and after the deploy — the counts should match exactly. A mismatch means the reconciliation failed and the migration was re-executed. Roll back and investigate.
- **Fail-fast behavior:** if the reconciliation hits a genuine DB error (broken connection, locked `schema_version`, etc.), API startup **aborts loudly** rather than silently proceeding into the main migration loop with an unreconciled state. This is the Risk 5 mitigation agreed during Copilot review — see the module-level doc comment on `MIGRATION_RENAMES` in `api/functions/migration-runner.R`.

_Context: Phase A.A4 resolves a duplicate `008_` migration prefix by renaming `008_hgnc_symbol_lookup.sql` → `018_hgnc_symbol_lookup.sql`. On any deployment that had the old file recorded in `schema_version`, the filename tracker is now stale. The reconciliation is what makes this deployment-safe. See `.plans/v11.0/phase-a.md` §3 A4 for the full rationale._

### Security

- **A1 (P0 hotfix):** Moved login and password-change credentials out of URL query strings. The previous `GET /api/auth/authenticate?user_name=…&password=…` and `PUT /api/user/password/update?…` shapes leaked secrets into access logs, Traefik logs, and browser history.
  - **New:** `POST /api/auth/authenticate` with `Content-Type: application/json` and body `{"user_name":"…","password":"…"}`.
  - **New:** `PUT /api/user/password/update` accepts a JSON body for the password fields. Handler is dual-mode: the legacy query-string form still works as a transitional fallback and will be removed in a later release (tracked as Phase E.E7 in the v11.0 plan).
  - **Deprecated (still functional in 0.11.4):** `GET /api/auth/authenticate`. Will be removed alongside the dual-mode password handler in Phase E.E7.
  - `app/src/views/LoginView.vue` and `app/src/views/UserView.vue` switched to the new POST/PUT shapes.
  - Middleware `AUTH_ALLOWLIST` updated to include `/api/auth/authenticate` so the new `@post` handler is reachable through the `require_auth` filter (the legacy `@get` only worked because unauthenticated `GET` requests are forwarded by default). This was caught by end-to-end Playwright testing after the subagent's host-side curl tests missed the interaction with the full Traefik + filter stack.

### Fixed

- **A2:** `/api/gene/:symbol` no longer corrupts the `gnomad_constraints` JSON blob by pipe-splitting it. The repository's `across(...)` call now excludes `gnomad_constraints` from `str_split_fn` using `-any_of("gnomad_constraints")` (schema-tolerant form). The frontend no longer carries the `[0]` dereference workaround in `GeneView.vue`; `app/src/types/gene.ts` now types the field as `string | null` with a JSDoc explanation of why this one field is the scalar exception.

### Added

- **A7 (already on master, merged in #220, released as part of 0.11.4):** One-command developer bootstrap.
  - `make install-dev` — idempotent aggregate bootstrap for R (via `renv::restore()`) and frontend (via `npm install`).
  - `make doctor` — environment verifier: Docker reachability (soft check), git ≥ 2.5, Node major matches `app/.nvmrc`, R callable, dev packages importable (`lintr`, `styler`, `testthat`, `covr`, `httptest2`, `callr`, `mockery`). Exit 0 on healthy; exit 1 with a specific diagnostic on any failure.
  - `make worktree-setup NAME=<scope>/<unit>` — parameterized worktree creation. Creates `worktrees/<scope>/<unit>` on branch `v11.0/<scope>/<unit>` from master, with `mkdir -p` for the parent directory so nested paths work on a clean clone.
  - `app/.nvmrc` pins the Node major to match `.github/workflows/ci.yml` (currently Node 24).
  - Human-facing `docs/DEVELOPMENT.md` (counterpart to the agent-facing `CLAUDE.md`): six sections covering requirements, quickstart, daily workflow, parallel worktree workflow, common gotchas, and getting help.
  - Root `CONTRIBUTING.md` with a minimal TL;DR and a link to `docs/DEVELOPMENT.md`.
  - `api/renv.lock` additions for the 7 declared dev packages (verified via a `rocker/r-ver:4.5` Docker sidecar because the development host runs Conda R on Ubuntu 25.10 "questing", which Posit PPM does not support yet).
  - New CI job `make doctor (ubuntu-latest)` on every PR that touches relevant paths. macOS was tried via colima + homebrew R but hit pre-existing Bioconductor lockfile rot and toolchain issues unrelated to A7 and was removed from the matrix; see the comment header on the `make-doctor` job in `.github/workflows/ci.yml` for the full rationale.
- **A3:** `db/migrations/README.md` rewritten to document the actual runner behavior — advisory lock with 30s timeout, fast-path skip, numbered-prefix convention, forward-only rollback policy, and a cross-reference to the Phase B.B4 CI smoke test.
- **A4:** `scripts/check-migration-prefixes.sh` — POSIX shell script that asserts unique `NNN_` migration prefixes across `db/migrations/*.sql`. Wired into `make lint-api`; fails CI on any future collision with a clear diagnostic listing the conflicting files.
- **A6:** `make worktree-prune` target — `git worktree prune -v` + `git worktree list`, safe as a no-op on clean master. `scripts/verify-test-gate.sh` stub (Phase B.B4 will fill in the real test-gate logic).
- **Follow-up:** `reconcile_schema_version_renames()` in `api/functions/migration-runner.R` with an internal `MIGRATION_RENAMES` map documenting historical renames (currently the A4 008→018 entry). Runs before the pending-migration diff in `run_migrations()`. Fail-fast on DB errors (no silent skip) per Copilot review. 7 `mockery::stub`-based unit tests in `api/tests/testthat/test-unit-migration-runner.R` lock in each state branch: rewrite, idempotent (new-already-present), dedup (both-present), fresh DB, premature-rename (new file not yet on disk), SELECT-error propagation, UPDATE-error propagation.
- **A1 (tests):** New `api/tests/testthat/test-endpoint-auth.R` — structural regex assertions and behavior tests for the new POST/PUT handlers. Uses `parse()` + source-ref extraction instead of `plumber::pr()` because plumber 1.3.2's internal route layout did not match the initial walker; the parse-based form is more portable and runs without plumber installed at test time.

### Changed

- **A4:** `db/migrations/008_hgnc_symbol_lookup.sql` renamed to `db/migrations/018_hgnc_symbol_lookup.sql`. File content unchanged; the rename resolves the duplicate-prefix issue flagged in the 2026-04-11 codebase review §2. **See Upgrade notes above** for deploy-time behavior on long-lived databases.

### Removed

- **A5:** Empty `api/repository/` directory (archaeological debris from an incomplete refactor; `api/functions/legacy-wrappers.R` already covers the repository-layer semantics). No live R code under `api/endpoints`, `api/functions`, `api/core`, `api/services`, or `api/start_sysndd_api.R` references this directory.
- **Follow-up:** Two `api/repository` references in `docker-compose.yml` — the volume bind-mount (line 144) and the `develop.watch` sync rule (line ~196). Without this removal, `docker compose up` and `docker compose watch` would have recreated the empty host-side directory on every invocation, reintroducing the exact state A5 was meant to eliminate.

### Internal / dev tooling

- Bumped `app/package.json` and `api/version_spec.json` to `0.11.4`.
- Tests for the new reconciliation function run entirely offline (`mockery::stub` covers all `DBI::dbGetQuery` / `DBI::dbExecute` call sites).
- The Phase A work was developed across 7 parallel git worktrees (`v11.0/phase-a/*`) and combined into a single PR (#228) for review. All historical branches have been deleted. The v11.0 plan files under `.plans/v11.0/` describe the parallel-worktree workflow and the intra-phase ownership rules.

### Known limitations

- `make ci-local` still fails at the lint step on Ubuntu 25.10 "questing" hosts running Conda/miniforge R because Posit Package Manager does not yet publish a `__linux__/questing/` binary repo and Conda R's `ld` cannot link zlib from source tarballs. Workarounds are documented in the agent-facing `CLAUDE.md` (gitignored, local memory). CI on `ubuntu-latest` is the authoritative baseline.
- The A1 POST handler returns HTTP 500 on a malformed JSON body (e.g. non-JSON text with `Content-Type: application/json`) instead of a clean 400. This is plumber's upstream JSON parser dying before the handler's own validation runs. Not a Phase A regression — the prior `@get` form simply never had this code path. Will be addressed in Phase E.E7 when the auth consolidation lands and the dual-mode handler is removed.
- The A4 prefix check script is wired into `make lint-api`, but GitHub Actions' `changes` filter skips the `lint-api` job on PRs that don't touch `api/**`. This means a PR that only touches `db/migrations/` might not exercise the prefix check in CI. Phase B.B4's verify-test-gate will close this gap; until then, the script runs locally on every `make lint-api` invocation.

### References

- PR: [#228](https://github.com/berntpopp/sysndd/pull/228) — combined Phase A (A1–A6 + follow-up + version bump, 22 commits)
- PR: [#220](https://github.com/berntpopp/sysndd/pull/220) — Phase A.A7 dev-environment bootstrap (merged first, 10 commits)
- Plan: `.plans/v11.0/phase-a.md`
- Spec: `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase A, §4.8 local developer environment
- Review: `docs/reviews/2026-04-11-codebase-review.md` §2 (duplicate prefix), §3 (empty repository)
- Follow-up todo: `.planning/todos/pending/refresh-stale-bioconductor-pins-in-renv-lock.md` (pre-existing lockfile rot surfaced by A7's CI matrix; deferred)

## [0.11.3] — 2026-04-09

- Dependency security updates (bulk bump of production-minor-patch group).
- Dev server fix: allow Docker proxy hosts in Vite 7 + Traefik routing.

## Earlier versions

Earlier history is available via `git log --grep="bump version"` on `master`. This CHANGELOG starts documenting the project at 0.11.3.

[Unreleased]: https://github.com/berntpopp/sysndd/compare/v0.11.5...HEAD
[0.11.5]: https://github.com/berntpopp/sysndd/compare/v0.11.4...v0.11.5
[0.11.4]: https://github.com/berntpopp/sysndd/compare/v0.11.3...v0.11.4
[0.11.3]: https://github.com/berntpopp/sysndd/releases/tag/v0.11.3
