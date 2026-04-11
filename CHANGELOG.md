# Changelog

All notable changes to SysNDD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

## [Unreleased]

_Nothing yet. See `.plans/v11.0/` for work in progress._

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

[Unreleased]: https://github.com/berntpopp/sysndd/compare/v0.11.4...HEAD
[0.11.4]: https://github.com/berntpopp/sysndd/compare/v0.11.3...v0.11.4
[0.11.3]: https://github.com/berntpopp/sysndd/releases/tag/v0.11.3
