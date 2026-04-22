# v11.0 Phase D — Backend Structural Refactors

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to orchestrate this phase session; it will call `superpowers:dispatching-parallel-agents` and `superpowers:using-git-worktrees`. Each worktree executes as its own subagent and must follow `superpowers:test-driven-development` (rigid — do not adapt away discipline) for the §4.2 loop. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase D.

**Phase goal:** Backend structural refactors protected by Phase C's test net. Split three god-files, delete `legacy-wrappers.R`, enforce pagination on 9 previously-unpaginated list endpoints, and extract `start_sysndd_api.R` into an `api/bootstrap/` module set with zero new `<<-` globals.

**Phase architecture:** 6 worktrees. D1, D2, D3, D4, D5 run in parallel off Phase-C-merged `master`. **D6 (`extract-bootstrap`) merges last**, rebased against D1–D5's source-list edits — enforced by the execution session, not by branch protection (§2.4).

**Tech stack:** R + Plumber + `mirai` workers + `testthat` + `covr`.

**Locked decisions from spec Appendix C (do not re-open):**
- **B1 handler table** remains frozen — if a D-era refactor touches a route that changes shape, flag immediately instead of editing B1 handlers in Phase D.
- **Exit criterion #5** (per HTTP method per route) is the C7/C8/C9 scope — D4 and D5 consume those tests; they do not re-open the scope rule.
- **E7 auth consolidation** is Phase E — Phase D leaves the frontend untouched.

**Critical TDD rule (§2.5 Layer 1 + §4.2):** Every Phase D worktree is created off Phase-C-merged `master`. By definition, the Phase C test that protects the refactor is already on `master` at the moment the branch is cut. **A Phase D worktree that adds its own safety-net test is violating the plan** (§2.5 Layer 1). The only new-test work allowed in Phase D is D5's pagination contract test (net-new surface — no pre-existing test existed because the endpoints were unpaginated).

---

## 1 — Prerequisites check

Before opening this phase, confirm:

- [ ] Phase C is **done** per its own gate (§2.3):
  ```bash
  git branch --list 'v11.0/phase-c/*' | wc -l              # must be 0
  git ls-remote --heads origin 'v11.0/phase-c/*' | wc -l   # must be 0
  ```
- [ ] **Human Checkpoint #2 (§2.7) signed off.** Without this, Phase D does not open.
- [ ] `make ci-local` green on clean `master`.
- [ ] Frontend coverage threshold at 55 in `app/vitest.config.ts` (Phase C gate).
- [ ] Backend coverage printed by `make test-api` (advisory, ≥70% target).
- [ ] B4's real `scripts/verify-test-gate.sh` is live and rejects synthetic `v11.0/phase-d/*` violations (modifying pre-existing spec files outside of `it.todo` unpinning — and Phase D has **no** `it.todo` unpinning; that's Phase E).
- [ ] C8's endpoint write-batch tests (`test-endpoint-review.R`, `test-endpoint-status.R`) are green on `master` — D4 depends on them.
- [ ] C7's `test-endpoint-statistics.R`, `test-endpoint-list.R`, `test-endpoint-search.R`, `test-endpoint-ontology.R` green — D5's pagination sweep touches all nine list endpoints and the sibling integration tests must stay green.
- [ ] The "source order: repositories before services" test from §5.2 Risk 3 mitigation is green (create one if absent as part of D1/D2/D3's worktree setup — but see §2.4 rule: this test creation is allowed because it is protecting the Phase D refactor, and no Phase C test covered it).
- [ ] No `v11.0/phase-d/*` branches exist locally or remotely.

If any check fails, stop and escalate.

---

## 2 — Worktree manifest

All 6 worktrees branch off current `master` via `make worktree-setup NAME=phase-d/<unit>`.

| # | Branch | Worktree path | Exclusive write ownership (§2.4, §3) | Merge order |
|---|---|---|---|---|
| D1 | `v11.0/phase-d/split-llm-service` | `worktrees/phase-d/split-llm-service` | `api/functions/llm-service.R` (split), `api/functions/llm-client.R` (new), `api/functions/llm-types.R` (new), `api/functions/llm-rate-limiter.R` (new). **Source-list edits to `api/start_sysndd_api.R` only inside the magic-commented region.** | Parallel |
| D2 | `v11.0/phase-d/split-helper-functions` | `worktrees/phase-d/split-helper-functions` | `api/functions/helper-functions.R` (delete once empty), `api/functions/account-helpers.R` (new), `api/functions/entity-helpers.R` (new), `api/functions/response-helpers.R` (new), `api/functions/data-helpers.R` (new). Source-list edits same rule as D1. | Parallel |
| D3 | `v11.0/phase-d/split-pubtator-functions` | `worktrees/phase-d/split-pubtator-functions` | `api/functions/pubtator-functions.R` (split), `api/functions/pubtator-client.R` (new), `api/functions/pubtator-parser.R` (new). Source-list edits same rule as D1. | Parallel |
| D4 | `v11.0/phase-d/delete-legacy-wrappers` | `worktrees/phase-d/delete-legacy-wrappers` | `api/functions/legacy-wrappers.R` (delete), `api/endpoints/entity_endpoints.R` (update call sites), any other file found via the wrapper-function grep below. | Parallel |
| D5 | `v11.0/phase-d/pagination-sweep` | `worktrees/phase-d/pagination-sweep` | `api/endpoints/about_endpoints.R`, `backup_endpoints.R`, `hash_endpoints.R`, `llm_admin_endpoints.R`, `re_review_endpoints.R`, `search_endpoints.R`, `variant_endpoints.R`, `panels_endpoints.R`, `comparisons_endpoints.R` (all modified to use `api/functions/pagination-helpers.R`), `api/tests/testthat/test-pagination-contract.R` (new — the only net-new Phase D test, allowed because no pre-existing test covered the pagination contract). | Parallel |
| D6 | `v11.0/phase-d/extract-bootstrap` | `worktrees/phase-d/extract-bootstrap` | `api/start_sysndd_api.R` (major rewrite, ≤200 LoC), `api/bootstrap/load_modules.R` (new), `api/bootstrap/create_pool.R` (new), `api/bootstrap/run_migrations.R` (new), `api/bootstrap/setup_workers.R` (new), `api/bootstrap/core/filters.R` (new, if absent in `api/core/`), `api/bootstrap/mount_endpoints.R` (new). **Merges last.** | **Merges last** |

**Intra-phase ownership rule (§2.4, Risk 3 mitigation):**

D1, D2, D3, D4 all need to edit the source list block in `api/start_sysndd_api.R`. The rule:

> Those edits are made only inside a magic-commented region:
>
> ```r
> # --- function source list (v11.0) ---
> source("functions/...")
> # --- end source list ---
> ```
>
> Merge conflicts inside this block are trivially resolvable by alphabetizing, because source order matters only between layers (repositories before services — enforced by a test), not between files in the same layer.

**Open question from §6.4 (writing-plans deferral):** the magic-comment format is locked here as `# --- function source list (v11.0) ---` / `# --- end source list ---` per §2.4. D1 (the first worktree to edit the source list) is responsible for introducing the magic-comment markers around the existing source block in the same commit that adds its first `source()` line. D2, D3, D4 edit inside the markers after D1 has established them. If D2/D3/D4 start before D1 merges, they still add the markers defensively and resolve conflicts by merge-time alphabetization.

**D6 merge-last enforcement:** D6 (`extract-bootstrap`) rewrites `api/start_sysndd_api.R` in bulk, including the source list region. It merges last. The execution session tracks this — D6's worktree is not dispatched until D1–D5 have all opened PRs, and D6's PR is not merged until D1–D5 are on `master`. D6 then rebases against current `master` and resolves the source list into the new `api/bootstrap/load_modules.R` module.

---

## 3 — Per-worktree task spec

### D1 — `split-llm-service`

- [ ] **Protecting Phase C test (Layer 1):** none specific, but the existing `test-llm-*.R` suite is on `master` and must remain green. Pre-existing failures in `test-llm-benchmark.R` and `test-llm-judge.R` (unused `info` arg) are allowed to remain red per `CLAUDE.md` and §1.3.

- [ ] **Goal (§3 Phase D.D1):** Split `api/functions/llm-service.R` (1,747 LoC) into:
  - `llm-client.R` — HTTP / SDK calls to LLM providers.
  - `llm-types.R` — type/schema definitions and coercion.
  - `llm-rate-limiter.R` — throttling and quota management.
  - `llm-service.R` — thin orchestrator that composes the above into the public surface.

- [ ] **File ownership:**
  - Modify: `api/functions/llm-service.R` (reduce to thin pipeline).
  - Create: `api/functions/llm-client.R`, `llm-types.R`, `llm-rate-limiter.R`.
  - Modify: `api/start_sysndd_api.R` ONLY inside the magic-commented source list region.

- [ ] **Acceptance (§3 Phase D.D1):**
  - Each new file ≤600 LoC. `wc -l api/functions/llm-*.R` confirms.
  - Existing `test-llm-*.R` suite passes (pre-existing failures in `test-llm-benchmark.R` / `test-llm-judge.R` remain — not this PR's problem).
  - `make ci-local` green.
  - Container restart after merge — mirai workers re-source the split files via `everywhere()`; confirm no `could not find function` errors in `docker logs sysndd-api-1`.

- [ ] **TDD loop (§4.2 — rigid, do not adapt):**
  ```
  1. make worktree-setup NAME=phase-d/split-llm-service
  2. cd worktrees/phase-d/split-llm-service
  3. make install-dev
  4. make doctor
  5. Run the protecting test against unchanged source:
       make test-api | grep -A 2 "test-llm"
     Must be GREEN on unchanged source (modulo the pre-existing failures documented above).
  6. Begin the split. The test WILL break at some point — that's the red phase.
     Expected red points: when a function is moved to a new file but not yet sourced
     in the magic-comment region, any caller breaks.
  7. Finish the split; re-run the test. GREEN again.
  8. No it.todo to unpin in Phase D (that's Phase E's handshake).
  9. make ci-local                       # must be green before opening the PR
  10. Restart dev container (make dev down && make dev up) and verify mirai workers healthy.
  11. Open PR via superpowers:requesting-code-review
  ```

- [ ] **Test-gate reference (§2.5):**
  - Layer 1: the protecting test is `test-llm-*.R`, already on `master`. D1 did not create it.
  - Layer 2: `scripts/verify-test-gate.sh` runs on D1's PR. D1 must NOT modify any pre-existing spec file. No `.spec.ts` edits, no `test-*.R` edits. If the gate rejects D1, check the diff for accidental test edits.
  - Layer 3: Checkpoint #2 was the check that `test-llm-*.R` is a meaningful safety net — already passed.

### D2 — `split-helper-functions`

- [ ] **Protecting Phase C tests:** C7, C8, C9 integration test batches (every endpoint currently using any helper from `helper-functions.R` must stay green).

- [ ] **Goal (§3 Phase D.D2):** Split `api/functions/helper-functions.R` (1,440 LoC) into:
  - `account-helpers.R`
  - `entity-helpers.R`
  - `response-helpers.R`
  - `data-helpers.R`

  Delete the original orchestrator once empty.

- [ ] **File ownership:**
  - Delete: `api/functions/helper-functions.R` (after contents are redistributed).
  - Create: the four new helper files.
  - Modify: `api/start_sysndd_api.R` ONLY inside the magic-commented source list region.

- [ ] **Acceptance (§3 Phase D.D2):**
  - Each new file ≤500 LoC. `wc -l api/functions/{account,entity,response,data}-helpers.R`.
  - `make test-api` green.
  - Full Phase C endpoint test batches from C7/C8/C9 still green against the refactored call sites.
  - `make ci-local` green.
  - Container restart: no `could not find function` errors.

- [ ] **TDD loop (§4.2):** same as D1. Protecting test set: `test-endpoint-*.R` from C7/C8/C9 + any pre-existing integration tests that cover helpers used by the rest of the API.

- [ ] **Test-gate reference:** Layer 1 passes (C7/C8/C9 tests pre-exist). Layer 2 — no spec-file edits allowed.

### D3 — `split-pubtator-functions`

- [ ] **Protecting Phase C tests:** B2's recorded PubMed/PubTator fixtures back any integration test that touches `pubtator-functions.R`; specifically `test-integration-pubtator*.R`.

- [ ] **Goal (§3 Phase D.D3):** Split `api/functions/pubtator-functions.R` (1,269 LoC) into:
  - `pubtator-client.R` — BioCJSON API calls, URL construction.
  - `pubtator-parser.R` — `fromJSON()` parsing, `bind_rows()` accumulation, gene-symbol computation (see project memory: `pubtator_parse_biocjson`, three-approach gene-symbol matching).
  - `pubtator-functions.R` — thin pipeline orchestrator.

- [ ] **File ownership:**
  - Modify: `api/functions/pubtator-functions.R` (thin).
  - Create: `pubtator-client.R`, `pubtator-parser.R`.
  - Modify: `api/start_sysndd_api.R` ONLY inside the magic-commented source list region.

- [ ] **Acceptance (§3 Phase D.D3):**
  - Each new file ≤600 LoC.
  - `test-integration-pubtator*.R` green using the new B2 fixtures.
  - `make ci-local` green.
  - Container restart: mirai workers pick up the new files (per project memory: mirai workers source files once via `everywhere()`, so container restart is required).

- [ ] **TDD loop (§4.2):** same as D1. Both `pubtator_db_update()` (sync) AND `pubtator_db_update_async()` must continue to work (project memory note).

- [ ] **Test-gate reference:** Layer 1 passes (B2 + pre-existing integration tests). Layer 2 — no spec-file edits allowed.

### D4 — `delete-legacy-wrappers`

- [ ] **Protecting Phase C tests:** **C8's write-endpoint batch is the critical safety net.** `test-endpoint-review.R` and `test-endpoint-status.R` exercise every write endpoint that currently routes through `legacy-wrappers.R` per §5.5 ("legacy-wrappers.R deletion breaking a caller we missed — covered by C7/C8/C9's endpoint test batches").

- [ ] **Goal (§3 Phase D.D4, exit criterion #9):** Migrate every caller of the legacy wrappers to call `svc_entity_*` / repository functions directly; delete `api/functions/legacy-wrappers.R` (630 LoC).

- [ ] **Caller discovery command (§3 Phase D.D4):**
  ```bash
  grep -rn "post_db_entity\|put_db_entity_deactivation\|put_post_db_review\|put_post_db_pub_con\|put_post_db_phen_con\|put_post_db_var_ont_con\|put_post_db_status\|put_db_review_approve\|put_db_status_approve" api/
  ```
  Every hit is a caller that must be migrated. `api/endpoints/entity_endpoints.R` is the known primary caller.

- [ ] **File ownership:**
  - Delete: `api/functions/legacy-wrappers.R`.
  - Modify: `api/endpoints/entity_endpoints.R` — replace wrapper calls with direct `svc_entity_*` / repository function calls. Reference project memory for the entity creation flow (svc_entity_create_with_review_status, repository functions accept `conn = NULL` for transaction participation).
  - Modify: any other file surfaced by the grep above.
  - **No new tests.** D4's protecting tests are C7/C8/C9 — authoring new tests here would violate Layer 1.

- [ ] **Acceptance (§3 Phase D.D4, exit criterion #9):**
  - `test -f api/functions/legacy-wrappers.R` fails.
  - `grep -r "legacy-wrappers" api/` returns only historical references (none in live code).
  - C8's write-endpoint test batch (especially `test-endpoint-review.R` and `test-endpoint-status.R`) green against the refactored call sites.
  - `make ci-local` green.
  - Container restart: no `could not find function` errors.

- [ ] **TDD loop (§4.2):**
  ```
  5. Run the protecting test against unchanged source:
       docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"
       docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"
     Both GREEN on unchanged source.
  6. Begin the migration. For each caller: replace wrapper call → direct service/repository call → run C8 tests incrementally.
     If C8 tests go red, the migration broke a contract Phase C did not catch — STOP and escalate.
     If the escalation reveals a tautology, open a reinforcing Phase C worktree to cover the gap BEFORE D4 proceeds.
  7. Delete legacy-wrappers.R once every caller is migrated.
  8. Re-run C8 batch — GREEN.
  9. make ci-local
  10. Open PR.
  ```

- [ ] **Test-gate reference (§2.5):** Layer 1 — C7/C8/C9 pre-exist. Layer 2 — no spec-file edits allowed; verify-test-gate.sh rejects any accidental edit. Layer 3 — Checkpoint #2 asked explicitly whether C8 is a meaningful safety net for the wrapper deletion; already signed off.

### D5 — `pagination-sweep`

- [ ] **Protecting Phase C tests:** C7 read-batch (search, list, statistics, ontology) — but only four of the nine list endpoints in D5's scope are in C7. The other five (`about`, `backup`, `hash`, `llm_admin`, `re_review`, `variant`, `panels`, `comparisons` — noting `search` is in C7 but also in D5's list) are covered by C9 (`backup`, `hash`) and fall outside Phase C test batches for the remaining five.

  **This is a scope exception:** D5's net-new `test-pagination-contract.R` is allowed because no pre-existing test covered the pagination contract. It is a contract-level test, not a per-endpoint refactor protector, and it is authored in D5's own PR because the contract did not exist on `master` before.

- [ ] **Goal (§3 Phase D.D5, exit criterion #16):** Enforce `limit`/`offset` (or cursor) on the 9 previously-unpaginated list endpoints.

- [ ] **File ownership:**
  - Modify: `api/endpoints/about_endpoints.R`, `backup_endpoints.R`, `hash_endpoints.R`, `llm_admin_endpoints.R`, `re_review_endpoints.R`, `search_endpoints.R`, `variant_endpoints.R`, `panels_endpoints.R`, `comparisons_endpoints.R` — each updated to use `api/functions/pagination-helpers.R`.
  - Create: `api/tests/testthat/test-pagination-contract.R` — asserts `links.next` presence on every `GET /api/<resource>`.

- [ ] **Acceptance (§3 Phase D.D5, exit criterion #16):**
  - Every endpoint accepts `limit` and `offset` query params.
  - Default `limit` is a sane cap (50).
  - Paginated responses include `links.next`.
  - `test-pagination-contract.R` passes.
  - `make ci-local` green.

- [ ] **TDD loop (§4.2 variant — contract test is new surface):**
  ```
  5. Author test-pagination-contract.R with one assertion per target endpoint. Run it — RED for every endpoint not yet paginated.
  6. Update each endpoint file to use pagination-helpers. Re-run the contract test incrementally. Green accumulates.
  7. Run sibling C7 tests to ensure the read-batch doesn't regress:
       docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-search.R')"
       docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-list.R')"
  8. make ci-local
  9. Open PR.
  ```

- [ ] **Test-gate reference (§2.5):** Layer 1 — D5 creates `test-pagination-contract.R` as a new test file, which `scripts/verify-test-gate.sh` allows (new unit/contract test creation). Layer 2 — D5 must NOT modify any pre-existing `test-*.R` file.

### D6 — `extract-bootstrap` (merges last)

- [ ] **Protecting Phase C tests:** every backend test. D6 rewrites the startup path; any startup regression red-lights the entire suite.

- [ ] **Goal (§3 Phase D.D6, exit criterion #11):** Extract `api/start_sysndd_api.R` (971 LoC) into explicit init modules under `api/bootstrap/` returning values. Compose them in a ≤200-LoC top-level script. Remove `<<-` globals by threading an application-context object.

- [ ] **File ownership:**
  - Major rewrite: `api/start_sysndd_api.R` (target ≤200 LoC).
  - Create: `api/bootstrap/load_modules.R` — consumes the magic-commented source list from D1/D2/D3/D4 and encapsulates it as a function returning a loaded-modules context.
  - Create: `api/bootstrap/create_pool.R` — returns the DB pool object.
  - Create: `api/bootstrap/run_migrations.R` — returns migration status.
  - Create: `api/bootstrap/setup_workers.R` — runs `everywhere({...})` with the same function set in the same order (no worker-init regression); returns the worker context.
  - Create: `api/bootstrap/mount_endpoints.R` — mounts every `pr_mount()` call; returns the mounted plumber router.
  - Create: `api/bootstrap/core/filters.R` only if `api/core/filters.R` does not already exist.

- [ ] **Acceptance (§3 Phase D.D6, exit criterion #11):**
  - `wc -l api/start_sysndd_api.R` ≤ 200.
  - `grep -c "<<-" api/start_sysndd_api.R` returns 0 (no new globals).
  - `grep -rn "<<-" api/start_sysndd_api.R api/bootstrap/` returns 0 (same check extended across the bootstrap set — exit criterion #11 + Phase D gate).
  - `make test-api` green.
  - B4 smoke test green.
  - Mirai workers sourced via `everywhere()` still load the same function set in the same order — no worker-init regression. Verified by diffing the pre-D6 and post-D6 `everywhere({...})` blocks and confirming functional equivalence.

- [ ] **Merge-last sequencing rule (§2.4):**
  - D6 is not dispatched until D1, D2, D3, D4, D5 have all opened PRs.
  - D6 is not merged until D1, D2, D3, D4, D5 are on `master`.
  - D6 then rebases against `master` and integrates the magic-commented source list edits from D1–D4 into `api/bootstrap/load_modules.R`.

- [ ] **TDD loop (§4.2):**
  ```
  1. make worktree-setup NAME=phase-d/extract-bootstrap  (AFTER D1–D5 PRs are open)
  2–4. setup + env
  5. Run the protecting tests against unchanged source:
       make test-api
     All green (minus the documented pre-existing failures).
  6. Iteratively extract each init module. After each extraction:
       - make test-api              # unit/integration
       - scripts/ci-smoke.sh        # B4's smoke test locally (or equivalent manual boot)
     RED is expected during the extraction.
  7. Final pass: drop every <<- and thread the application context explicitly through each init module return value.
  8. make ci-local
  9. REBASE against master (D1–D5 are now on master): git pull --rebase origin master
  10. Resolve the source-list magic-comment region into api/bootstrap/load_modules.R.
  11. make ci-local again after rebase.
  12. Restart dev container and confirm no errors.
  13. Open PR.
  ```

- [ ] **Test-gate reference (§2.5):** Layer 1 — the protecting tests are every backend test, all pre-existing. Layer 2 — D6 must not modify pre-existing spec files. Layer 3 — Checkpoint #2 implicitly covered the backend test suite as a safety net for startup refactors.

---

## 4 — Parallel dispatch block

Merge order (§2.4): D1, D2, D3, D4, D5 parallel → D6 last.

```
SEQUENCE 1 (5-way parallel from Phase-C-merged master):
  D1 — split-llm-service
  D2 — split-helper-functions
  D3 — split-pubtator-functions
  D4 — delete-legacy-wrappers
  D5 — pagination-sweep

(wait until all 5 PRs open; Human Checkpoint is at Phase end, not here)

SEQUENCE 2 (sequential, D6 alone, merges after D1–D5 are on master):
  D6 — extract-bootstrap
```

**Dispatch mechanics:**

- [ ] Step 1 — rebase local `master`:
  ```bash
  git checkout master && git pull --ff-only
  ```

- [ ] Step 2 — create D1–D5 worktrees:
  ```bash
  make worktree-setup NAME=phase-d/split-llm-service
  make worktree-setup NAME=phase-d/split-helper-functions
  make worktree-setup NAME=phase-d/split-pubtator-functions
  make worktree-setup NAME=phase-d/delete-legacy-wrappers
  make worktree-setup NAME=phase-d/pagination-sweep
  ```

- [ ] Step 3 — dispatch D1–D5 agents in one parallel batch via `superpowers:dispatching-parallel-agents`. Each agent runs the §4.2 TDD loop rigidly and gates its PR on a green `make ci-local`.

- [ ] Step 4 — watch for D1–D4 source-list conflicts at merge time. Resolve by alphabetization inside the magic-commented region per §2.4 Risk 3 mitigation. Confirm the "source order: repositories before services" test remains green after each resolution.

- [ ] Step 5 — after D1–D5 merge, create D6 worktree:
  ```bash
  git checkout master && git pull --ff-only
  make worktree-setup NAME=phase-d/extract-bootstrap
  ```

- [ ] Step 6 — dispatch the D6 agent alone. It follows the §4.2 loop and ends with a rebase against the latest `master` that includes D1–D5's source list edits. D6's agent is responsible for integrating the magic-commented region's contents into `api/bootstrap/load_modules.R`.

- [ ] Step 7 — if Phase D doesn't converge within 2 weeks (§5.4 Risk 3 exit ramp), convert D1/D2/D3 to strict sequential order and rerun. D4, D5 are not affected by the ramp.

---

## 5 — TDD loop (from §4.2, rigid)

Phase D is the first phase where the §4.2 loop applies **literally**, as written:

```
1. make worktree-setup NAME=phase-d/<unit>
2. cd worktrees/phase-d/<unit>
3. make install-dev                                         # idempotent on clean or pre-installed worktree
4. make doctor                                              # verify env
5. Run the protecting test against unchanged source — must be GREEN.
     D1: make test-api | grep test-llm
     D2: make test-api (C7/C8/C9 + pre-existing integration tests)
     D3: docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-integration-pubtator.R')"
     D4: docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"
     D5: (new contract test — starts red; see D5 variant above)
     D6: make test-api (full suite)
6. Begin the refactor/rewrite. The test WILL break at some point — that's the red phase.
7. Finish the rewrite; the test is GREEN again.
8. No it.todo to unpin in Phase D (that's Phase E's handshake).
9. make ci-local                                            # must be green before opening the PR
10. Restart dev container (make dev down && make dev up) and verify mirai workers healthy.
11. Open PR via superpowers:requesting-code-review
```

**Rules that apply rigidly:**
- **A Phase D worktree may not merge a PR where the protecting Phase C test was modified to make it pass.** The only legal change to a pre-existing spec file is unpinning an `it.todo` — and Phase D has no `it.todo` unpinning (that is Phase E's handshake).
- **D5 is the only worktree that authors a new test in Phase D.** It creates `test-pagination-contract.R`, which is net-new contract surface that did not exist on `master`. B4's `verify-test-gate.sh` allows new test file creation.

---

## 6 — Test-gate reference (from §2.5)

- **Layer 1 (structural):** Phase D worktrees are created off Phase-C-merged `master`. By definition, the Phase C test protecting each refactor is already on `master`. A Phase D worktree that adds its own safety-net test violates the plan — enforced by the writing-plans rule and verified by `verify-test-gate.sh`.
- **Layer 2 (CI-enforced):** `scripts/verify-test-gate.sh` (B4) runs on every Phase D PR. It allows:
  - D5's new `test-pagination-contract.R` (new file creation).
  - D6's new `api/bootstrap/*.R` files (not test files — not subject to the gate).
  And rejects:
  - Any modification to pre-existing `*.spec.ts` or `test-*.R` file in D1–D6 (Phase D has no `it.todo` unpinning).
- **Layer 3 (human):** Checkpoint #2 signed off that Phase C tests are a meaningful safety net for Phase D. Layer 3 is the precondition, not a per-PR check.

---

## 7 — Human checkpoint

**No dedicated human checkpoint for Phase D in §2.7.** The critical checkpoint for Phase D (Checkpoint #2) happened **before** Phase D opened. Phase D's output is validated at Phase D's gate and Checkpoint #3 (end of Phase E).

Phase D merges PR-by-PR with standard review. No batch review.

---

## 8 — Phase gate commands (from §2.3)

Run on clean `master` after every Phase D PR merges:

```bash
# Mechanical "phase done" detection (§2.3)
git branch --list 'v11.0/phase-d/*' | wc -l               # must be 0
git ls-remote --heads origin 'v11.0/phase-d/*' | wc -l    # must be 0
make ci-local                                             # must be green on master
```

Plus the Phase D-specific gate additions (§3 Phase D gate, exit criteria #9/#10/#11/#16):

```bash
# D4: legacy-wrappers.R deleted; no live call sites remain
test ! -f api/functions/legacy-wrappers.R
grep -r "legacy-wrappers" api/ --include="*.R" | grep -v "# " | wc -l   # historical doc references only

# D1/D2/D3: file size targets
for f in api/functions/llm-client.R api/functions/llm-types.R api/functions/llm-rate-limiter.R api/functions/llm-service.R; do
  wc -l "$f" | awk '{ if ($1 > 600) exit 1 }'
done
for f in api/functions/account-helpers.R api/functions/entity-helpers.R api/functions/response-helpers.R api/functions/data-helpers.R; do
  wc -l "$f" | awk '{ if ($1 > 500) exit 1 }'
done
test ! -f api/functions/helper-functions.R   # D2 deletes the orchestrator
for f in api/functions/pubtator-client.R api/functions/pubtator-parser.R api/functions/pubtator-functions.R; do
  wc -l "$f" | awk '{ if ($1 > 600) exit 1 }'
done

# D6: start_sysndd_api.R ≤200 LoC, zero new <<- globals
wc -l api/start_sysndd_api.R | awk '{ if ($1 > 200) exit 1 }'
grep -rn '<<-' api/start_sysndd_api.R api/bootstrap/ | wc -l    # must be 0

# D5: every target endpoint paginated
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-pagination-contract.R')"

# B4 smoke test green on the Phase-D-merged master
gh run list --workflow ci.yml --branch master --limit 5 | grep -q "smoke-test.*success"

# Container restart smoke — mirai workers load the refactored function set
docker compose restart api && sleep 5 && curl -f http://localhost/api/health/ready
```

**Phase D is done only when all checks pass.** At that point, Phase E opens off the new `master` SHA.
