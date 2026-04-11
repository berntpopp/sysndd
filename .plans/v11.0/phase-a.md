# v11.0 Phase A — Hotfix, Dev Environment, and Fast Wins

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to orchestrate this phase session; it will in turn call `superpowers:dispatching-parallel-agents` and `superpowers:using-git-worktrees`. Each worktree executes as its own subagent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase A.

**Phase goal:** Land the P0 credential hotfix, establish a one-command dev-environment bootstrap so every downstream worktree agent can go from `git worktree add` to running tests in two commands, and land the small fast wins that don't fit anywhere else.

**Phase architecture:** 7 parallel worktrees off current `master`. A7 (`dev-environment-bootstrap`) merges first because its `make install-dev` / `make doctor` / `make worktree-setup` targets are consumed by every worktree in Phases B–E. A1–A6 run in parallel after A7 merges, since their ownership sets are disjoint.

**Tech stack:** R (Plumber) + Vue 3 + Vite + Docker Compose + GitHub Actions + Make.

**Locked decisions from spec Appendix C (do not re-open):** B1 handler table, exit-criterion #5 test scope, E7 auth consolidation — these are relevant to later phases but noted here so the Phase A session knows not to pre-work them.

---

## 1 — Prerequisites check

Before opening this phase, confirm on clean `master`:

- [ ] `git status` → clean working tree on `master`
- [ ] `git pull --ff-only` → up to date with `origin/master`
- [ ] `make ci-local` → green (establishes the "we're starting from a known-green baseline" baseline the phase gate will compare against)
- [ ] No `v11.0/phase-a/*` branches already exist locally or remotely:
  ```bash
  git branch --list 'v11.0/phase-a/*' | wc -l           # must be 0
  git ls-remote --heads origin 'v11.0/phase-a/*' | wc -l   # must be 0
  ```
- [ ] The consolidated review at `docs/reviews/2026-04-11-codebase-review.md` and the v11.0 spec at `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` are readable and match the expectations this plan is built on.

If any prerequisite fails, stop and escalate. Do not attempt to "fix master" from within this phase.

---

## 2 — Worktree manifest

All 7 worktrees branch off current `master` via `git worktree add` (§2.2). Until A7 merges, worktrees may be created manually via `git worktree add worktrees/phase-a/<unit> -b v11.0/phase-a/<unit>`; once A7 merges, subsequent worktrees use `make worktree-setup NAME=phase-a/<unit>`.

| # | Branch | Worktree path | Exclusive write ownership (§2.4, §3) | Merge order |
|---|---|---|---|---|
| A7 | `v11.0/phase-a/dev-environment-bootstrap` | `worktrees/phase-a/dev-environment-bootstrap` | `Makefile` (new targets `install-dev`, `doctor`, `worktree-setup` only), `app/.nvmrc` (new), `docs/DEVELOPMENT.md` (new), `CONTRIBUTING.md` (new), `api/renv.lock` (verify dev packages present) | **Merges first** |
| A1 | `v11.0/phase-a/hotfix-credentials` | `worktrees/phase-a/hotfix-credentials` | `app/src/views/LoginView.vue`, `app/src/views/UserView.vue`, `api/endpoints/auth_endpoints.R`, `api/endpoints/user_endpoints.R`, `logs/*` (redaction sweep), `CLAUDE.md` auth-flow section | After A7 |
| A2 | `v11.0/phase-a/json-pipe-split` | `worktrees/phase-a/json-pipe-split` | `api/endpoints/gene_endpoints.R` (line 219), `app/src/views/pages/GeneView.vue` (line 193), `app/src/types/gene.ts`, `.planning/todos/pending/fix-pipe-split-on-json-column.md` (delete) | After A7 |
| A3 | `v11.0/phase-a/migrations-readme` | `worktrees/phase-a/migrations-readme` | `db/migrations/README.md`, `.planning/todos/pending/make-migration-002-idempotent.md` (delete) | After A7 |
| A4 | `v11.0/phase-a/dup-008-rename` | `worktrees/phase-a/dup-008-rename` | `db/migrations/008_hgnc_symbol_lookup.sql` (rename → `018_hgnc_symbol_lookup.sql`), `scripts/check-migration-prefixes.sh` (new), `Makefile` `lint-api` target (add prefix check — distinct section from A7's new targets) | After A7 |
| A5 | `v11.0/phase-a/delete-empty-repository` | `worktrees/phase-a/delete-empty-repository` | `api/repository/` (delete) | After A7 |
| A6 | `v11.0/phase-a/fast-wins` | `worktrees/phase-a/fast-wins` | `.gitignore` (add `/worktrees/`), `scripts/verify-test-gate.sh` (stub; B4 fills in), `Makefile` `worktree-prune` target (distinct section from A7) | After A7 |

**Intra-phase ownership rule (§2.4):** Two worktrees in the same phase never appear in each other's ownership set. Above, A7, A4, and A6 all touch `Makefile`; they are disjoint by adding new, non-overlapping target sections. If any agent sees a `<<<<<<< HEAD` conflict in `Makefile` at merge time, the resolution is always "keep both blocks, alphabetize top-level targets" — never drop a block.

---

## 3 — Per-worktree task spec

The per-worktree detail is the acceptance criterion the executor verifies before opening the PR. Every worktree follows the TDD loop variant in §5. The test-gate reference in §6 is the structural rule every PR CI run is checked against.

### A7 — `dev-environment-bootstrap` (merges first)

- [ ] **Goal (§3 Phase A.A7):** One-command developer bootstrap and environment verification. Every subsequent worktree agent must be able to go from `git worktree add` to running tests in two commands.

- [ ] **File ownership (exclusive writes):**
  - Create: `app/.nvmrc` — pins to the Node major used in `.github/workflows/ci.yml`.
  - Create: `docs/DEVELOPMENT.md` — sections: requirements, quickstart, daily workflow, parallel worktree workflow, common gotchas (cross-reference `CLAUDE.md`), getting help.
  - Create: `CONTRIBUTING.md` — minimal root contributor policy, points at `docs/DEVELOPMENT.md`.
  - Modify: `Makefile` — add exactly three new targets: `install-dev`, `doctor`, `worktree-setup`. Do not modify existing targets.
  - Verify (may update): `api/renv.lock` — confirm dev packages `testthat`, `covr`, `lintr`, `styler`, `httptest2`, `callr`, `mockery` are present; add the missing ones in this worktree via `renv::install()` + `renv::snapshot()` in the same commit that introduces them.

- [ ] **Acceptance (§3 Phase A.A7):**
  - `make install-dev` succeeds on a clean clone (verified on Ubuntu + macOS via a GitHub Actions matrix added to this PR, per Risk 9 mitigation).
  - `make doctor` exits 0 and prints `Environment healthy`.
  - `make doctor` includes a `renv::status() | grep -q "synchronized"` assertion (Risk 5 mitigation).
  - `app/.nvmrc` matches the Node major currently used by CI.
  - `docs/DEVELOPMENT.md` covers the six sections listed above; `CONTRIBUTING.md` exists and links to `docs/DEVELOPMENT.md`.
  - `renv::status()` returns "synchronized".

- [ ] **TDD loop reference:** §4.2 variant — this worktree is an infrastructure worktree, not a refactor. Its "test" is the GitHub Actions matrix job running `make doctor` on `ubuntu-latest` and `macos-latest`. That matrix job is the acceptance evidence.

- [ ] **Test-gate reference (§2.5):** Layer 1 (structural) — A7 is in Phase A, which has no protecting Phase C tests yet, so the Layer 2 `scripts/verify-test-gate.sh` check is vacuous here; the stub from A6 is what runs. No pre-existing spec files exist for A7 to modify, so Layer 2 trivially passes.

### A1 — `hotfix-credentials` (P0)

- [ ] **Goal (§3 Phase A.A1, exit criterion #1):** Move login and password-change secrets out of URL query strings.

- [ ] **File ownership:**
  - Modify: `api/endpoints/auth_endpoints.R` — add `@post` handler on the existing authenticate route with JSON body params (`user_name`, `password`). Preserve the existing `@get` handler only long enough for the frontend to switch (same PR).
  - Modify: `api/endpoints/user_endpoints.R` — add `@put` handler for password change with JSON body.
  - Modify: `app/src/views/LoginView.vue` (around line 139) — switch to `POST` with JSON body.
  - Modify: `app/src/views/UserView.vue` (around line 640) — switch to `PUT` with JSON body.
  - Modify: `logs/*` — sweep existing log lines containing `password=` or token values and redact.
  - Modify: `CLAUDE.md` — update the "Auth flow" section to describe the new POST-body flow. The current text (`GET /api/auth/authenticate` with `user_name`/`password` params → JWT) is wrong as of this PR.

- [ ] **Acceptance (§3 Phase A.A1):**
  - Unit tests on the new handlers pass (added in the same PR inside `api/tests/testthat/test-endpoint-auth.R` — this is a new test file; A1 is allowed to author it because no Phase C endpoint test has been written for auth yet).
  - Live smoke: `curl -X POST -H 'Content-Type: application/json' -d '{"user_name":"...","password":"..."}' http://localhost:7777/api/auth/authenticate` succeeds end-to-end against the dev stack (`make dev`).
  - `grep -r "password=" logs/` returns nothing.
  - `CLAUDE.md` auth-flow section reflects the new shape.

- [ ] **TDD loop reference (§4.2 variant):** A1 authors the first auth endpoint test in the same PR. The test is red without the handler, green with it. Because no pre-existing test protects the current `@get` shape, this worktree is allowed to both write the test and make it pass — the "test precedes refactor" rule (§2.5) applies to D/E, not A.

- [ ] **Test-gate reference (§2.5):** Layer 1 structural — no pre-existing spec is being modified; Layer 2 vacuous for Phase A.

- [ ] **Downstream coupling note:** B1 acceptance (§3 Phase B.B1) says "after the A1 hotfix merges, the authentication and password-update handlers mock the new POST/PUT shapes; until then, they mock the current @get shapes." B1 reads the final shape of A1 and mirrors it. E7 (Phase E auth consolidation) edits `LoginView.vue` and `UserView.vue` after A1 is merged; the two never touch those files concurrently.

### A2 — `json-pipe-split`

- [ ] **Goal (§3 Phase A.A2):** Fix the JSON pipe-split issue flagged in `.planning/todos/pending/fix-pipe-split-on-json-column.md`.

- [ ] **File ownership:**
  - Modify: `api/endpoints/gene_endpoints.R` line ~219 — change the `across(...)` call to `across(-c(gnomad_constraints), str_split_fn)`.
  - Modify: `app/src/views/pages/GeneView.vue` line ~193 — remove the `[0]` dereference on `gnomad_constraints`.
  - Modify: `app/src/types/gene.ts` — update the type to reflect the real shape of `gnomad_constraints`.
  - Delete: `.planning/todos/pending/fix-pipe-split-on-json-column.md`.

- [ ] **Acceptance (§3 Phase A.A2):**
  - Manual smoke test: Gene view page renders `gnomad_constraints` correctly in `make dev`.
  - `cd app && npx vue-tsc --noEmit` reports no errors for `GeneView.vue` or `types/gene.ts`.
  - The pending todo file is deleted.

- [ ] **TDD loop reference:** §4.2 variant — no Phase C test yet exists for `GeneView.vue`. A2 may optionally add a `types/gene.spec.ts` type-level test; if it does, the test is authored in the same PR. This is allowed in Phase A (see A1 note above).

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous; no pre-existing spec is modified.

- [ ] **Downstream coupling note:** E3 (`first-client-migration`) migrates `GeneView.vue` off raw `axios.get`. E3 is in Phase E and branches off master after A2 has merged; no concurrent edit.

### A3 — `migrations-readme`

- [ ] **Goal (§3 Phase A.A3):** Rewrite `db/migrations/README.md` to document the actual runner behavior.

- [ ] **File ownership:**
  - Rewrite: `db/migrations/README.md` — describe the runner truthfully (advisory lock, fast-path check, numbered-prefix convention, rollback guidance, CI smoke test reference).
  - Delete: `.planning/todos/pending/make-migration-002-idempotent.md` — per review §4, already idempotent.

- [ ] **Acceptance (§3 Phase A.A3):**
  - `grep "Manual execution required" db/migrations/README.md` returns nothing.
  - The README references `functions/migration-runner.R` accurately (advisory lock, 30s timeout, fast-path check) and cross-references the B4 CI smoke test as the end-to-end guard.

- [ ] **TDD loop reference:** §4.2 variant — doc-only worktree; the "test" is the spec-to-reality match the reviewer verifies.

- [ ] **Test-gate reference (§2.5):** vacuous.

### A4 — `dup-008-rename`

- [ ] **Goal (§3 Phase A.A4):** Resolve the duplicate `008_*` migration prefix flagged in review §2.

- [ ] **File ownership:**
  - Rename: `db/migrations/008_hgnc_symbol_lookup.sql` → `db/migrations/018_hgnc_symbol_lookup.sql` (use `git mv`).
  - Create: `scripts/check-migration-prefixes.sh` — asserts `ls db/migrations/ | awk -F_ '{print $1}' | sort | uniq -d` returns empty; exits non-zero if a duplicate is introduced.
  - Modify: `Makefile` — the existing `lint-api` target calls `scripts/check-migration-prefixes.sh` as an additional step. This Makefile edit is inside the `lint-api` target block, disjoint from A7's new top-level targets and A6's `worktree-prune` target.

- [ ] **Acceptance (§3 Phase A.A4):**
  - `ls db/migrations/ | awk -F_ '{print $1}' | sort | uniq -d` returns empty.
  - `make lint-api` runs the new prefix-check script and is green.
  - `schema_version` ordering is still monotonic after the rename. Verified by booting the dev DB (`make docker-dev-db`) and checking `SELECT version FROM schema_version ORDER BY version` — no regression.

- [ ] **TDD loop reference:** §4.2 variant — the test is `scripts/check-migration-prefixes.sh` itself, authored in this PR. It must fail on a synthetic duplicate (verified by a temp file) and pass on the cleaned tree.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous.

### A5 — `delete-empty-repository`

- [ ] **Goal (§3 Phase A.A5):** Delete the empty `api/repository/` directory flagged in review §3.

- [ ] **File ownership:** `api/repository/` (delete).

- [ ] **Acceptance (§3 Phase A.A5):**
  - `test -d api/repository` fails.
  - `grep -r "api/repository" . --exclude-dir=.git` returns only historical doc references (none in live code).

- [ ] **TDD loop reference:** §4.2 variant — this is a deletion; the "test" is `make ci-local` remaining green.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous.

### A6 — `phase-a-fast-wins`

- [ ] **Goal (§3 Phase A.A6):** Small edits that don't fit anywhere else and don't conflict with A1–A5.

- [ ] **File ownership:**
  - Modify: `.gitignore` — add `/worktrees/`.
  - Create: `scripts/verify-test-gate.sh` — stub body only: `#!/bin/bash; echo "stub — B4 will fill"; exit 0`. **Do not implement the real logic here; B4 owns it.**
  - Modify: `Makefile` — add `worktree-prune` target. This is in a distinct Makefile section from A7's three new targets and A4's `lint-api` edit.

- [ ] **Acceptance (§3 Phase A.A6):**
  - `make worktree-prune` runs as a no-op on clean `master`.
  - `scripts/verify-test-gate.sh` exists with the stub body exactly as specified above.
  - `.gitignore` contains `/worktrees/`.

- [ ] **TDD loop reference:** §4.2 variant — structural, no tests to author.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous.

---

## 4 — Parallel dispatch block

Dispatch sequence (§2.4 merge-order rule: "A7 first, A1–A6 parallel after"):

```
SEQUENCE 1 (sequential, blocks everything else):
  A7 — dev-environment-bootstrap

SEQUENCE 2 (6-way parallel after A7 is merged to master):
  A1 — hotfix-credentials
  A2 — json-pipe-split
  A3 — migrations-readme
  A4 — dup-008-rename
  A5 — delete-empty-repository
  A6 — phase-a-fast-wins
```

**Dispatch mechanics:**

- [ ] Step 1 — create the A7 worktree only (manual `git worktree add`, since A7 has not yet landed `make worktree-setup`):
  ```bash
  git worktree add worktrees/phase-a/dev-environment-bootstrap -b v11.0/phase-a/dev-environment-bootstrap master
  ```

- [ ] Step 2 — dispatch one agent into A7's worktree via `superpowers:dispatching-parallel-agents`. Wait for A7 to merge to `master` before proceeding. The check:
  ```bash
  git fetch origin
  git ls-remote --heads origin 'v11.0/phase-a/dev-environment-bootstrap' | wc -l   # must be 0 after merge
  ```

- [ ] Step 3 — once A7 is on `master`, rebase local `master` and create the remaining six worktrees via `make worktree-setup`:
  ```bash
  git checkout master && git pull --ff-only
  make worktree-setup NAME=phase-a/hotfix-credentials
  make worktree-setup NAME=phase-a/json-pipe-split
  make worktree-setup NAME=phase-a/migrations-readme
  make worktree-setup NAME=phase-a/dup-008-rename
  make worktree-setup NAME=phase-a/delete-empty-repository
  make worktree-setup NAME=phase-a/fast-wins
  ```

- [ ] Step 4 — dispatch all 6 agents in one parallel batch via `superpowers:dispatching-parallel-agents`. Each agent runs `make install-dev` (now idempotent) and `make doctor` inside its worktree before beginning work.

- [ ] Step 5 — each agent opens its own PR using `superpowers:verification-before-completion` to gate the PR on a green `make ci-local`. PR reviews happen per-unit (no batch review in Phase A).

---

## 5 — TDD loop (from §4.2)

Phase A is not a refactor phase, so the §4.2 loop as literally written ("run the protecting test against unchanged source — must be GREEN") does not apply to most A worktrees. The loop for Phase A is its simplified variant:

```
1. make worktree-setup NAME=phase-a/<unit>                  (A7 first; remaining after A7 merges)
2. cd worktrees/phase-a/<unit>
3. make install-dev                                         # idempotent
4. make doctor                                              # verify env
5. Read the spec §3 Phase A.<unit> acceptance criteria.
6. Make the edits listed under "File ownership" above.
7. If the worktree authors a new test (A1 auth handler test, A4 prefix-check script), run it and verify it passes.
8. make ci-local                                            # must be green before opening the PR
9. Open PR via superpowers:requesting-code-review
```

**Rule that still applies:** no Phase A worktree touches a pre-existing spec file. A1 authors a new `test-endpoint-auth.R`; that is the only new test expected in Phase A.

---

## 6 — Test-gate reference (from §2.5)

The three-layer test gate:

- **Layer 1 (structural):** worktree is created off `master`; no protecting test exists yet; Layer 1 passes vacuously for Phase A.
- **Layer 2 (CI-enforced `scripts/verify-test-gate.sh`):** A6 ships the stub (`echo "stub — B4 will fill"; exit 0`), so every Phase A PR passes the gate trivially. B4 replaces the stub with real logic during Phase B.
- **Layer 3 (human checkpoint):** no Phase A worktree is a refactor protected by a Phase C test, so the Layer 3 question ("would this test catch a subtle rewrite?") doesn't apply here.

Phase A's test-gate is effectively "don't modify pre-existing spec files" — followed by convention, not enforced by the stub.

---

## 7 — Human checkpoint

**Checkpoint #1 of 3 (§2.7):** "After Phase A — quick scan that the hotfix and fast wins landed without surprises. ~15 minutes."

Questions the reviewer answers at this checkpoint:

1. Did A1's POST/PUT shape match what B1 will mock in Phase B? (cross-check against the B1 handler table in spec §3 Phase B.B1)
2. Does `make install-dev` succeed on a fresh clone of `master`? Run it yourself.
3. Does `make doctor` exit 0 on your laptop?
4. Is the `Makefile` readable after three worktrees (A7, A4, A6) each added non-overlapping sections?
5. Are there any surprise entries in `grep -r "password=" logs/`?

If any answer is "no," the phase is not done. Open a reinforcing worktree under `v11.0/phase-a/<fix-name>` and re-run the phase gate.

---

## 8 — Phase gate commands (from §2.3)

Run these on clean `master` after every Phase A PR merges:

```bash
# Mechanical "phase done" detection (§2.3)
git branch --list 'v11.0/phase-a/*' | wc -l           # must be 0
git ls-remote --heads origin 'v11.0/phase-a/*' | wc -l   # must be 0
make ci-local                                         # must be green on master
```

Plus the Phase A-specific gate additions (§3 Phase A gate):

```bash
make install-dev    # must succeed from a fresh `git clone`; verified by reviewer
make doctor         # must exit 0 with "Environment healthy"
make ci-local       # redundant with above but the canonical Phase gate command
```

**Phase A is done only when all four checks pass and Human Checkpoint #1 has been signed off.** At that point, Phase B opens off the new `master` SHA.
