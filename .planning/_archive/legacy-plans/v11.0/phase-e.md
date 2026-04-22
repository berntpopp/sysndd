# v11.0 Phase E — Frontend Structural Refactors

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to orchestrate this phase session; it will call `superpowers:dispatching-parallel-agents` and `superpowers:using-git-worktrees`. Each worktree executes as its own subagent and must follow `superpowers:test-driven-development` (rigid — do not adapt away discipline) for the §4.2 loop. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec reference:** `docs/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase E.

**Phase goal:** Frontend structural refactors protected by Phase C's view specs. Introduce `api/client.ts` and stub per-resource modules, enable per-directory TypeScript strictness on specific scopes, migrate one feature as a template, rewrite the two 2,000+ LoC views (`ManageAnnotations.vue`, `ApproveReview.vue`) as `<script lang="ts">`, consolidate `useAuth`, and converge `ApproveStatus.vue` into a parameterized `ApprovalTableView.vue`.

**Phase architecture:** 7 worktrees. E1 merges **first** (everything consumes `api/client.ts`). E2, E3, E4, E5, E7 run in parallel in the middle. E6 merges **last** (depends on E5's established pattern). Merge order enforced by the execution session (§2.4).

**Tech stack:** Vue 3 Composition API + `<script setup lang="ts">` + Vite + Pinia + Vitest + `@vue/test-utils` + MSW.

**Locked decisions from spec Appendix C (do not re-open):**
- **B1 handler table** remains frozen — Phase E consumes handlers from the table; does not modify them.
- **Exit criterion #5** is Phase C scope — Phase E consumes view specs (C1, C3, C5), not endpoint tests.
- **E7 auth consolidation** is **explicitly locked** — the finding, scope, call sites, dependency on A1, and new-file exception to the "tests precede refactor" rule are all spelled out inline in spec §3 Phase E.E7 and repeated in this plan below. **Do not re-scope.**

**Critical TDD rule (§2.5 Layer 1 + §4.2):** Every Phase E worktree is created off Phase-D-merged `master`. The Phase C specs protecting the rewrites are already on `master`. A Phase E worktree that adds its own safety-net test is violating the plan — **except E7**, which is the one documented exception because `useAuth.ts` is a new file with no pre-existing source to protect (§3 Phase E.E7).

---

## 1 — Prerequisites check

Before opening this phase, confirm:

- [ ] Phase D is **done** per its own gate:
  ```bash
  git branch --list 'v11.0/phase-d/*' | wc -l              # must be 0
  git ls-remote --heads origin 'v11.0/phase-d/*' | wc -l   # must be 0
  ```
- [ ] `make ci-local` green on clean `master`.
- [ ] Exit criteria #9 (legacy-wrappers deleted), #10 (god-files split), #11 (`start_sysndd_api.R` ≤200 LoC, zero new `<<-`), #16 (pagination on 9 endpoints) all confirmed.
- [ ] B4's smoke test green on Phase-D-merged `master`.
- [ ] A1's POST/PUT auth shapes are on `master` (Phase A landed) — E7 depends on this.
- [ ] A2's JSON pipe-split fix is on `master` (Phase A landed) — E3 depends on this because it migrates `GeneView.vue`.
- [ ] C1's `ApproveReview.spec.ts` exists and is green on `master` — E5 depends on it.
- [ ] C3's `ApproveStatus.spec.ts` exists and is green on `master` — E6 depends on it.
- [ ] C5's `ManageAnnotations.spec.ts` exists and is green on `master` — E4 depends on it.
- [ ] C10's `useAsyncJob.spec.ts` and `useEntityForm.spec.ts` exist and are green on `master` — E4 depends on `useAsyncJob`.
- [ ] C11's `useTableData.spec.ts` and `useTableMethods.spec.ts` exist and are green on `master` — E4 and E5 depend on `useTableData`.
- [ ] B1's handler table fully covers every axios path touched by the views being rewritten. `scripts/verify-msw-against-openapi.sh` green.
- [ ] B4's real `scripts/verify-test-gate.sh` rejects synthetic `v11.0/phase-e/*` violations except for `it.todo` unpinning.
- [ ] No `v11.0/phase-e/*` branches exist locally or remotely.

If any check fails, stop and escalate.

---

## 2 — Worktree manifest

All 7 worktrees branch off current `master` via `make worktree-setup NAME=phase-e/<unit>`.

| # | Branch | Worktree path | Exclusive write ownership (§2.4, §3) | Merge order |
|---|---|---|---|---|
| E1 | `v11.0/phase-e/api-client-introduction` | `worktrees/phase-e/api-client-introduction` | `app/src/api/client.ts` (new), `app/src/api/*.ts` (new stubs for all 27 resource families, with `genes.ts` and `auth.ts` fully implemented), `app/src/api/client.spec.ts` (new — this is a new unit-spec file, allowed) | **Merges first** |
| E2 | `v11.0/phase-e/ts-strictness-scopes` | `worktrees/phase-e/ts-strictness-scopes` | `app/tsconfig.strict.json` (new), `app/tsconfig.router.json` (new), `app/tsconfig.api.json` (new), `app/tsconfig.types.json` (new), `app/tsconfig.composables-auth.json` (new), `app/package.json` (update `type-check` script, add `type-check:strict` script). Any implicit-any fixes inside the newly strict scopes. | Parallel after E1 |
| E3 | `v11.0/phase-e/first-client-migration` | `worktrees/phase-e/first-client-migration` | `app/src/views/pages/GeneView.vue` (switch to `api/genes.ts`), `app/src/api/genes.ts` (add missing helpers), `app/src/api/genes.spec.ts` (new — allowed as new unit spec) | Parallel after E1 |
| E4 | `v11.0/phase-e/rewrite-manage-annotations` | `worktrees/phase-e/rewrite-manage-annotations` | `app/src/views/admin/ManageAnnotations.vue` (full rewrite, `<script setup lang="ts">`, ≤700 LoC), `app/src/components/annotations/*` (new modal/subsection components, each ≤300 LoC), optionally new composables under `app/src/composables/annotations/`. **`app/src/views/admin/ManageAnnotations.spec.ts` (Phase C file) may be touched ONLY to unpin the `it.todo`.** | Parallel after E1 |
| E5 | `v11.0/phase-e/rewrite-approve-review` | `worktrees/phase-e/rewrite-approve-review` | `app/src/views/curate/ApproveReview.vue` (full rewrite, `<script setup lang="ts">`, ≤700 LoC), `app/src/components/review/*` (new components), optionally new composables. **`app/src/views/curate/ApproveReview.spec.ts` may be touched ONLY to unpin the `it.todo`.** | Parallel after E1 |
| E7 | `v11.0/phase-e/consolidate-auth-session` | `worktrees/phase-e/consolidate-auth-session` | `app/src/composables/useAuth.ts` (new, `.ts`), `app/src/composables/useAuth.spec.ts` (new), `app/src/router/routes.ts` (remove direct localStorage reads ~line 334), `app/src/components/AppNavbar.vue` (consume useAuth ~line 135), `app/src/components/small/LogoutCountdownBadge.vue` (consume useAuth ~line 36; delete stale comments at lines 60/75/91), `app/src/views/LoginView.vue` (consume useAuth, remove direct localStorage write ~line 126), `app/src/views/UserView.vue` (consume useAuth ~line 549) | Parallel after E1 |
| E6 | `v11.0/phase-e/converge-approve-status` | `worktrees/phase-e/converge-approve-status` | `app/src/components/ApprovalTableView.vue` (new, `<script setup lang="ts">`, ≤700 LoC), `app/src/views/curate/ApproveStatus.vue` (rewritten as thin wrapper ≤100 LoC mounting `ApprovalTableView`). **`app/src/views/curate/ApproveStatus.spec.ts` may be touched ONLY to unpin the `it.todo`.** | **Merges last** |

**Intra-phase ownership rule (§2.4):**

- **E1 merges first** — E3, E4, E5 all consume `api/client.ts`. E2 also consumes the api directory (strict scope requires the directory to exist). E6 consumes the pattern established by E5.
- **E4, E5 both create `.ts` files under `app/src/composables/`** but in different sub-scopes (E4's `composables/annotations/`, E5's `composables/review/`). No overlap.
- **E5, E6 both touch the `ApproveReview.vue` / `ApproveStatus.vue` code surface conceptually** — this is why E6 merges last. E6 rebases against E5's merged state and copies the pattern. **E6 is not dispatched until E5's PR is open.**
- **E7 depends on A1** (both touch `LoginView.vue` and `UserView.vue`). A1 is on `master` as of Phase A, so E7's branch carries A1 already. E7 and A1 never touch those files concurrently.
- **E7 touches `LoginView.vue` and `UserView.vue` — so does E3? No, E3 owns `GeneView.vue` only.** E7 and E3 are disjoint.
- **No overlap between E2, E3, E4, E5, E7 in ownership sets.** Verified by inspection of the per-unit File ownership rows above.

---

## 3 — Per-worktree task spec

### E1 — `api-client-introduction` (merges first)

- [ ] **Protecting Phase C test:** none specific — E1 creates new surface. The existing vitest suite must stay green.

- [ ] **Goal (§3 Phase E.E1, exit criterion #14):** New `app/src/api/client.ts` — typed wrapper over the central axios instance. Stub `app/src/api/<resource>.ts` modules for all 27 resource families (at minimum exported empty modules). Implement `genes.ts` and `auth.ts` as templates.

- [ ] **File ownership:**
  - Create: `app/src/api/client.ts` — typed request/response interceptors threading through the existing `app/src/plugins/axios.ts` instance. **Does not replace `plugins/axios.ts`; wraps it.**
  - Create: `app/src/api/genes.ts` — full template implementation.
  - Create: `app/src/api/auth.ts` — full template implementation matching A1's POST/PUT shapes.
  - Create: `app/src/api/*.ts` for the remaining 25 resource families — stubs with a comment pointing at v11.1 for fill-out.
  - Create: `app/src/api/client.spec.ts` — smoke-tests the wrapper with MSW (using B1's handlers).

- [ ] **Acceptance (§3 Phase E.E1, exit criterion #14):**
  - `client.ts` exports a typed wrapper; `genes.ts` and `auth.ts` fully implemented.
  - Other resource modules are stub-exported (each file exists, even if empty besides the v11.1 comment).
  - `client.spec.ts` smoke-tests pass using MSW handlers.
  - `cd app && npm run type-check` green (global permissive config; E2 adds strict variants).
  - `make ci-local` green.
  - No existing axios call site was replaced in E1 — that is E3's job. E1 only introduces the surface.

- [ ] **TDD loop (§4.2 variant — new surface):**
  1. Author `client.spec.ts` with smoke tests for the typed wrapper.
  2. Run it — RED.
  3. Implement `client.ts` until tests pass.
  4. Author `genes.ts` and `auth.ts` template implementations using `client.ts`.
  5. Stub the remaining 25 resource modules.
  6. `cd app && npm run test:unit` green.
  7. `make ci-local` green.

- [ ] **Test-gate reference (§2.5):** Layer 1 vacuous (E1 is new surface). Layer 2 — `client.spec.ts` is a new file; allowed.

### E2 — `ts-strictness-scopes`

- [ ] **Goal (§3 Phase E.E2, exit criterion #15):** Per-directory `tsconfig.*.json` overrides enabling `strict: true` on specific scopes without flipping the global config. Global `tsconfig.json` remains permissive so the 129 unmigrated JS SFCs continue to build.

- [ ] **File ownership:**
  - Create: `app/tsconfig.strict.json` — base for strict scopes; `extends` the existing root `tsconfig.json`, overrides `strict: true` and related flags.
  - Create: `app/tsconfig.router.json` — strict scope for `src/router/`.
  - Create: `app/tsconfig.api.json` — strict scope for `src/api/` (depends on E1 existing).
  - Create: `app/tsconfig.types.json` — strict scope for `src/types/`.
  - Create: `app/tsconfig.composables-auth.json` — strict scope for `src/composables/useAuth*` (E7 consumes this).
  - Modify: `app/package.json` — `type-check` script stays global/permissive; add a new `type-check:strict` script that runs each scoped config.

- [ ] **Acceptance (§3 Phase E.E2, exit criterion #15):**
  - `cd app && npm run type-check` green (global permissive, unchanged scope).
  - `cd app && npm run type-check:strict` green.
  - If strict checks surface implicit-any in the named scopes (auth composables and router almost certainly have 1–3 violations per the spec's estimate), they are fixed in the same PR.
  - Global `tsconfig.json` remains permissive.
  - `make ci-local` green.

- [ ] **TDD loop (§4.2 variant):**
  1. Create the strict base and per-scope tsconfigs.
  2. Run `npm run type-check:strict` — expect red for 1–3 implicit-any violations.
  3. Add explicit types inline until green.
  4. Confirm `npm run type-check` is still green (non-strict).
  5. `make ci-local`.

- [ ] **Test-gate reference (§2.5):** Layer 2 — E2 doesn't touch test files. The implicit-any fixes modify source files, but those source files are not in any Phase C spec's ownership set, so there's no protecting test to violate.

### E3 — `first-client-migration`

- [ ] **Protecting Phase C test:** none exists yet for `GeneView.vue` — this is a known gap (it is not in the top 6 views C1–C6 cover). **E3 carries its own safety net at the api-module level, not the view level**, via the new `genes.spec.ts`. The gene view itself is left to manual smoke-testing.

- [ ] **Goal (§3 Phase E.E3, exit criterion #14):** Migrate one feature off raw `axios.get` onto the new `api/client.ts` + `api/genes.ts`. Recommended: `GeneView.vue` since A2 already touched it.

- [ ] **File ownership:**
  - Modify: `app/src/views/pages/GeneView.vue` — replace every `axios.get('/api/...')` with an `api/genes.ts` call.
  - Modify: `app/src/api/genes.ts` — add any missing helpers E1 didn't fully stub.
  - Create: `app/src/api/genes.spec.ts` — unit test each helper using B1's handlers.

- [ ] **Acceptance (§3 Phase E.E3):**
  - `grep -n "axios\\.get" app/src/views/pages/GeneView.vue` returns 0 direct API-path matches.
  - Existing Gene view manual smoke test still passes (`make dev` + browse to a gene page).
  - `genes.ts` exports typed helpers for every call the view makes.
  - `genes.spec.ts` unit tests cover each helper.
  - `cd app && npm run type-check` green.
  - `cd app && npm run type-check:strict` green (`src/api/` is under the strict scope from E2).
  - `make ci-local` green.

- [ ] **TDD loop (§4.2 variant — new surface on the api side, existing view on the view side):**
  1. Author `genes.spec.ts` helper tests. RED.
  2. Implement the helpers in `genes.ts`. GREEN.
  3. Refactor `GeneView.vue` to use the helpers.
  4. Manual smoke: `make dev`, visit a gene page.
  5. `make ci-local` green.

- [ ] **Test-gate reference (§2.5):** Layer 1 — new `genes.spec.ts` file is allowed by `verify-test-gate.sh`. No pre-existing spec covers `GeneView.vue`, so there is no protecting test to violate.

### E4 — `rewrite-manage-annotations`

- [ ] **Protecting Phase C test:** C5's `app/src/views/admin/ManageAnnotations.spec.ts` is on `master`.

- [ ] **Goal (§3 Phase E.E4, exit criterion #12):** Rewrite `app/src/views/admin/ManageAnnotations.vue` (2,159 LoC) as `<script setup lang="ts">` using `useAsyncJob` + `useTableData`. Split the annotation modals into their own components.

- [ ] **File ownership:**
  - Rewrite: `app/src/views/admin/ManageAnnotations.vue` (≤700 LoC, `<script setup lang="ts">` with explicit types on every prop and emit).
  - Create: `app/src/components/annotations/*` — new components for modals/subsections (each ≤300 LoC).
  - Create (optional): `app/src/composables/annotations/*` — any new composables needed.
  - Modify: `app/src/views/admin/ManageAnnotations.spec.ts` **ONLY to unpin the `it.todo`.** No other edits.

- [ ] **Acceptance (§3 Phase E.E4, exit criterion #12):**
  - Rewritten file ≤ 700 LoC. `wc -l app/src/views/admin/ManageAnnotations.vue`.
  - Modal subcomponents each ≤ 300 LoC.
  - C5's `ManageAnnotations.spec.ts` green against the rewritten source.
  - C5's `it.todo('TODO: verify the force-apply flow fires PUT /api/admin/force_apply_ontology with the correct blocked_job_id')` is **unpinned** as a passing assertion in the rewrite commit.
  - `<script setup lang="ts">` with explicit types on every prop and emit.
  - Risk 7 mitigation — before/after screenshots of the happy path attached to the PR.
  - Manual smoke test: annotation job start → poll → result rendered.
  - `make ci-local` green.

- [ ] **TDD loop (§4.2 — rigid, per spec):**
  ```
  1. make worktree-setup NAME=phase-e/rewrite-manage-annotations
  2. cd worktrees/phase-e/rewrite-manage-annotations
  3. make install-dev
  4. make doctor
  5. Run the protecting test against unchanged source:
       cd app && npx vitest run src/views/admin/ManageAnnotations.spec.ts
     Must be GREEN against the pre-rewrite ManageAnnotations.vue.
  6. Begin the rewrite. The test WILL break at some point — that's the red phase.
  7. Finish the rewrite; the test is GREEN again.
  8. Unpin the it.todo and turn it into a passing assertion for the force-apply flow.
     Use the B1 handlers (GET /api/jobs/<job_id>/status with status="blocked" branch).
  9. make ci-local                       # must be green before opening the PR
  10. Capture happy-path screenshots before and after for Risk 7 mitigation.
  11. Open PR via superpowers:requesting-code-review
  ```

- [ ] **Test-gate reference (§2.5):**
  - Layer 1: C5's spec file exists on `master` before E4's branch is cut — confirmed by Phase C gate.
  - Layer 2: `scripts/verify-test-gate.sh` allows the `it.todo` unpinning as the single legal edit to a pre-existing spec file in Phase D/E PRs. E4's PR diff on `ManageAnnotations.spec.ts` must contain only that one edit.
  - Layer 3: Checkpoint #2 confirmed C5 is a meaningful safety net. **If the rewriting agent cannot turn the `it.todo` into a passing assertion, the rewrite is incomplete and the PR is rejected** (§2.6).

### E5 — `rewrite-approve-review`

- [ ] **Protecting Phase C test:** C1's `app/src/views/curate/ApproveReview.spec.ts` is on `master`.

- [ ] **Goal (§3 Phase E.E5, exit criterion #12):** Rewrite `app/src/views/curate/ApproveReview.vue` (2,138 LoC) as `<script setup lang="ts">` using `useReviewForm` + `useTableData` + `useModalControls`. Split the review modal and the status modal into separate components. **This rewrite establishes the pattern E6 will reuse.**

- [ ] **File ownership:**
  - Rewrite: `app/src/views/curate/ApproveReview.vue` (≤700 LoC).
  - Create: `app/src/components/review/*` — new review and status modal components.
  - Create (optional): new composables under `app/src/composables/review/`.
  - Modify: `app/src/views/curate/ApproveReview.spec.ts` **ONLY to unpin the `it.todo`.**

- [ ] **Acceptance (§3 Phase E.E5, exit criterion #12):**
  - Rewritten file ≤ 700 LoC.
  - C1's `ApproveReview.spec.ts` green; `it.todo('TODO: verify the correct approver role appears in the audit trail')` unpinned.
  - Before/after screenshots attached (Risk 7).
  - Manual smoke test: open a review, submit, observe status.
  - `make ci-local` green.

- [ ] **TDD loop (§4.2):** same as E4, with C1 as the protecting spec.

- [ ] **Test-gate reference:** Layer 2 — allows only the `it.todo` unpinning on `ApproveReview.spec.ts`. Any other diff on that file rejected by `verify-test-gate.sh`.

- [ ] **Downstream coupling note:** E5's components and composables are the pattern E6 reuses to build `ApprovalTableView.vue`. E6 is not dispatched until E5's PR is open and reviewed.

### E7 — `consolidate-auth-session` (locked — do not re-scope)

- [ ] **Locked spec reference (§3 Phase E.E7, Appendix C):** E7 is the closure of the P1 "Frontend auth/session state is duplicated" finding from the review. Scope, call sites, dependency on A1, and the new-file exception to the test-before-refactor rule are **locked inline** in the spec and must not be re-opened.

- [ ] **Goal:** Close the P1 finding. Create a typed `useAuth()` composable as the single owner of read/write/refresh/401-handling for auth state. Remove direct `localStorage.token` / `localStorage.user` reads from every call site named in the review.

- [ ] **File ownership (locked call sites from §3 Phase E.E7):**
  - Create: `app/src/composables/useAuth.ts` — new `.ts` file.
  - Create: `app/src/composables/useAuth.spec.ts` — new spec; authored first (see rule below).
  - Modify: `app/src/router/routes.ts` — remove direct localStorage reads around **line 334**.
  - Modify: `app/src/components/AppNavbar.vue` — consume useAuth instead of localStorage around **line 135**.
  - Modify: `app/src/components/small/LogoutCountdownBadge.vue` — consume useAuth around **line 36**; **also delete the stale "TODO: move to a mixin" comment at lines 60 / 75 / 91**.
  - Modify: `app/src/views/LoginView.vue` — post-A1: consume useAuth, remove the direct `localStorage` write at **line 126**.
  - Modify: `app/src/views/UserView.vue` — post-A1: consume useAuth at **line 549**.

- [ ] **Dependency on A1 (locked):** E7 depends on A1 (`hotfix-credentials`) having merged, because both touch `LoginView.vue` and `UserView.vue`. Since Phase E follows Phase A, this is automatically satisfied — E7 branches off `master` after A1 is on it. Confirmed at prerequisite check above.

- [ ] **Locked exception to the test-before-refactor rule (§3 Phase E.E7):**
  > This worktree is the one exception to the "tests precede refactor" rule at the worktree level, because `useAuth.ts` is a **new file** with no pre-existing source to protect. The worktree follows an internal red-green-refactor loop: `useAuth.spec.ts` is authored first (failing against nothing), `useAuth.ts` is written until it passes, then the call sites are migrated one at a time.

- [ ] **Required test coverage (§3 Phase E.E7):** `useAuth.spec.ts` covers:
  - Login stores token + user.
  - Logout clears both.
  - Expired token triggers refresh or redirects.
  - Corrupted `localStorage.user` payload does not crash navigation.
  - 401 interceptor coordinates with useAuth state.

- [ ] **Acceptance (§3 Phase E.E7):**
  - `grep -rn "localStorage\\.token\\|localStorage\\.user" app/src/` returns only `useAuth.ts` hits.
  - All five call sites named in the locked list consume `useAuth()`.
  - Stale "TODO: move to a mixin" comments in `LogoutCountdownBadge.vue` removed.
  - `useAuth.spec.ts` passes.
  - `cd app && npm run type-check:strict` green (`useAuth.ts` lives under the strict scope `tsconfig.composables-auth.json` from E2).
  - `make ci-local` green.

- [ ] **TDD loop (§4.2 — E7 variant with documented exception):**
  ```
  1. make worktree-setup NAME=phase-e/consolidate-auth-session
  2. cd worktrees/phase-e/consolidate-auth-session
  3. make install-dev
  4. make doctor
  5. Author useAuth.spec.ts covering the 5 required cases. RED — there is no useAuth.ts yet.
  6. Implement useAuth.ts until the spec is GREEN. This is the new-file red-green-refactor
     loop that is the E7 exception to the Phase D/E test-before-refactor rule.
  7. Migrate each of the 5 call sites ONE AT A TIME. After each migration:
       cd app && npm run test:unit
       cd app && npm run type-check:strict
       grep -rn "localStorage\\.token\\|localStorage\\.user" app/src/
     Confirm the hit count decreases by one each migration until it matches useAuth.ts-only.
  8. No it.todo unpinning (E7 has no Phase C precursor spec).
  9. make ci-local
  10. Open PR.
  ```

- [ ] **Test-gate reference (§2.5):** Layer 1 — the E7 exception is **explicitly documented in the spec**. `scripts/verify-test-gate.sh` must recognize E7 as an allowed new-spec-and-new-source-in-same-PR pattern. B4's script handled this as "file created in this PR is allowed only for new unit/composable specs" — `useAuth.spec.ts` is a new composable spec, so the allow rule fires naturally. No script update required. Layer 2 — verify E7 does not accidentally modify a pre-existing spec file.

- [ ] **Coupling notes:**
  - E7 touches `LoginView.vue` and `UserView.vue`. A1 also touched these files — but A1 merged in Phase A, and the files are already on `master` with A1's POST/PUT changes.
  - E7's strict-type check depends on E2 having landed `tsconfig.composables-auth.json`. If E7 and E2 are dispatched in parallel, E7 must wait on E2's PR to merge before running `type-check:strict`. If E7 finishes earlier, it can still open its PR; CI's `type-check:strict` runs on the full merged set and will only exercise the composables-auth scope once E2 is on `master`.

### E6 — `converge-approve-status` (merges last)

- [ ] **Protecting Phase C test:** C3's `app/src/views/curate/ApproveStatus.spec.ts` is on `master`.

- [ ] **Goal (§3 Phase E.E6, exit criterion #13):** Create a parameterized `app/src/components/ApprovalTableView.vue` (from the E5 pattern), then replace `ApproveStatus.vue`'s standalone implementation with a mount of that component.

- [ ] **File ownership:**
  - Create: `app/src/components/ApprovalTableView.vue` — new `<script setup lang="ts">`, ≤700 LoC.
  - Rewrite: `app/src/views/curate/ApproveStatus.vue` — now a thin wrapper (≤100 LoC) that passes props and mounts `ApprovalTableView`.
  - Modify: `app/src/views/curate/ApproveStatus.spec.ts` **ONLY to unpin the `it.todo`.**

- [ ] **Acceptance (§3 Phase E.E6, exit criterion #13):**
  - `ApproveStatus.vue` ≤ 100 LoC.
  - `ApprovalTableView.vue` ≤ 700 LoC.
  - C3's `ApproveStatus.spec.ts` green; `it.todo('TODO: verify the combined status/review handling — hook for E6 convergence')` unpinned.
  - Before/after screenshots attached (Risk 7).
  - `make ci-local` green.

- [ ] **Merge-last sequencing rule (§2.4):** E6 is dispatched after E5's PR is open (so its agent can read E5's pattern). E6's PR is merged after E5's is on `master`. E6 then rebases against `master` and confirms the pattern from E5 is usable in `ApprovalTableView.vue`.

- [ ] **TDD loop (§4.2):** same as E4/E5, with C3 as the protecting spec and E5's pattern as the implementation template.

- [ ] **Test-gate reference:** Layer 2 — only `it.todo` unpinning allowed on `ApproveStatus.spec.ts`.

---

## 4 — Parallel dispatch block

Merge order (§2.4): E1 first → E2, E3, E4, E5, E7 parallel → E6 last.

```
SEQUENCE 1 (sequential, blocks everything else):
  E1 — api-client-introduction

SEQUENCE 2 (5-way parallel after E1 is merged to master):
  E2 — ts-strictness-scopes
  E3 — first-client-migration
  E4 — rewrite-manage-annotations
  E5 — rewrite-approve-review
  E7 — consolidate-auth-session

(wait until E5's PR is open; at that point, dispatch E6)

SEQUENCE 3 (sequential, E6 alone, merges after E5 is on master):
  E6 — converge-approve-status
```

**Dispatch mechanics:**

- [ ] Step 1 — rebase local `master`:
  ```bash
  git checkout master && git pull --ff-only
  ```

- [ ] Step 2 — create E1 worktree and dispatch its agent alone:
  ```bash
  make worktree-setup NAME=phase-e/api-client-introduction
  ```
  Wait for E1 to merge to `master`. Check:
  ```bash
  git fetch origin
  git ls-remote --heads origin 'v11.0/phase-e/api-client-introduction' | wc -l   # must be 0 after merge
  ```

- [ ] Step 3 — rebase local `master` and create the 5 parallel worktrees:
  ```bash
  git checkout master && git pull --ff-only
  make worktree-setup NAME=phase-e/ts-strictness-scopes
  make worktree-setup NAME=phase-e/first-client-migration
  make worktree-setup NAME=phase-e/rewrite-manage-annotations
  make worktree-setup NAME=phase-e/rewrite-approve-review
  make worktree-setup NAME=phase-e/consolidate-auth-session
  ```

- [ ] Step 4 — dispatch E2, E3, E4, E5, E7 in one parallel batch. Each agent runs the §4.2 TDD loop rigidly.

- [ ] Step 5 — when E5's PR is **open** (not yet merged), create E6's worktree and dispatch it:
  ```bash
  make worktree-setup NAME=phase-e/converge-approve-status
  ```
  E6's agent reads E5's open PR for the pattern, then authors `ApprovalTableView.vue`.

- [ ] Step 6 — merge order enforcement: E6's PR is held until E5 is on `master`. E6 then rebases against current `master` (which now includes E2/E3/E4/E5/E7) and opens for review.

- [ ] Step 7 — Risk 7 mitigation: every view-rewrite PR (E4, E5, E6) attaches before/after happy-path screenshots to the PR. Manually captured — **no automated screenshot helper in v11.0** per the writing-plans resolution of open question §6.4.2 in the spec (helper script is deferred to v11.1 as too much tooling investment for one milestone).

- [ ] Step 8 — Risk 10 mitigation: Phase E's 7 PRs do not get batch review (unlike Phase C). Each PR gets its own focused review, because the rewrites are substantial and deserve individual attention.

- [ ] Step 9 — Risk 9 note (cross-platform) is carried by A7's matrix job, not re-checked in Phase E.

- [ ] Step 10 — if Phase E doesn't converge in the §5.4 exit ramp window, defer E4/E5 to v11.0.5 and close v11.0 on what landed. Coverage-threshold bumps still stand.

---

## 5 — TDD loop (from §4.2, rigid)

Phase E is the second phase where the §4.2 loop applies literally. Every E worktree except E7 follows:

```
1. make worktree-setup NAME=phase-e/<unit>
2. cd worktrees/phase-e/<unit>
3. make install-dev                                         # idempotent on clean or pre-installed worktree
4. make doctor                                              # verify env
5. Run the protecting test against unchanged source — must be GREEN.
     E4: cd app && npx vitest run src/views/admin/ManageAnnotations.spec.ts
     E5: cd app && npx vitest run src/views/curate/ApproveReview.spec.ts
     E6: cd app && npx vitest run src/views/curate/ApproveStatus.spec.ts
     E1, E2, E3: new surface; the loop variants are in each unit's spec above.
6. Begin the refactor/rewrite. The test WILL break at some point — that's the red phase.
7. Finish the rewrite; the test is GREEN again.
8. Unpin the it.todo and turn it into a passing assertion.
   E4: force-apply flow PUT /api/admin/force_apply_ontology with blocked_job_id
   E5: correct approver role appears in the audit trail
   E6: combined status/review handling
9. make ci-local                                            # must be green before opening the PR
10. Capture before/after screenshots for E4/E5/E6.
11. Open PR via superpowers:requesting-code-review
```

**E7 follows the variant loop documented in its unit spec above — the documented exception.**

**Rules that apply rigidly:**
- **A Phase E worktree may not merge a PR where the protecting Phase C test was modified to make it pass.** The only legal change to a pre-existing spec file is unpinning the specific `it.todo` that was pinned in Phase C for that worktree.
- If the rewriting agent cannot turn the `it.todo` into a passing assertion, the rewrite is incomplete and the PR is rejected (§2.6).

---

## 6 — Test-gate reference (from §2.5)

- **Layer 1 (structural):** Phase E worktrees are created off Phase-D-merged `master`. Every protecting Phase C spec is already on `master`. E7 is the documented exception because `useAuth.ts` is a new file.
- **Layer 2 (CI-enforced):** `scripts/verify-test-gate.sh` (B4) runs on every Phase E PR. It allows:
  - `it.todo` unpinning on pre-existing `*.spec.ts` files (E4, E5, E6).
  - New `*.spec.ts` files (E1's `client.spec.ts`, E3's `genes.spec.ts`, E7's `useAuth.spec.ts`).
  And rejects: any other modification to pre-existing `*.spec.ts` or `test-*.R` files.
- **Layer 3 (human):** Checkpoint #2 confirmed C1, C3, C5 are meaningful safety nets. Checkpoint #3 at Phase E close is the final walkthrough.

---

## 7 — Human checkpoint

**Checkpoint #3 of 3 (§2.7):**

> After Phase D+E, before declaring v11.0 done — human runs `make ci-local` on clean `master`, confirms exit criterion #18 (10-run or 7-runs-+-7-day flake-free streak).

At this checkpoint, the reviewer walks through every exit criterion (§1.4) and confirms the following specifically for Phase E:

1. **Exit criterion #12:** `ManageAnnotations.vue` ≤700 LoC; `ApproveReview.vue` ≤700 LoC; both pass their Phase C specs with `it.todo` unpinned.
2. **Exit criterion #13:** `ApproveStatus.vue` replaced by a parameterized mount of `ApprovalTableView.vue`.
3. **Exit criterion #14:** `app/src/api/client.ts` exists; `GeneView.vue` migrated as a template; full migration is v11.1 work.
4. **Exit criterion #15:** Per-directory strict scopes exist and pass.
5. **Exit criterion #19:** Every file created or fully rewritten in v11.0 is TypeScript. No new `.js` files shipped.
6. **E7 finding closure:** `grep -rn "localStorage\\.token\\|localStorage\\.user" app/src/` returns only `useAuth.ts` hits.
7. **Exit criterion #18:** Flake-free streak per §4.7 — 10 consecutive green `master` runs on required CI jobs (`lint-api`, `lint-app`, `type-check`, `test-api`, `test-app`, `smoke-test`), triggered-by-push only, scheduled jobs excluded. If the counter hasn't reached 10 within 2 weeks of Phase E completion, the §4.7 exit ramp applies: 7 consecutive green on `master` plus zero red on `master` in the preceding 7-day window. The counter is tracked manually in the v11.0-exit PR checklist.

Also walk through exit criteria #1–#11 and #16, #17, #20 for phases A–D completeness — v11.0 is not shipped until every criterion is confirmed.

**If any criterion fails, v11.0 is not shipped.** Open a reinforcing worktree and re-run the checkpoint.

---

## 8 — Phase gate commands (from §2.3)

Run on clean `master` after every Phase E PR merges:

```bash
# Mechanical "phase done" detection (§2.3)
git branch --list 'v11.0/phase-e/*' | wc -l               # must be 0
git ls-remote --heads origin 'v11.0/phase-e/*' | wc -l    # must be 0
make ci-local                                             # must be green on master
```

Plus the Phase E-specific gate additions (§3 Phase E gate, exit criteria #12/#13/#14/#15/#18/#19):

```bash
# Type-check (both configurations)
cd app && npm run type-check
cd app && npm run type-check:strict

# Exit criterion #12: view LoC targets
wc -l app/src/views/admin/ManageAnnotations.vue | awk '{ if ($1 > 700) exit 1 }'
wc -l app/src/views/curate/ApproveReview.vue | awk '{ if ($1 > 700) exit 1 }'

# Exit criterion #13: ApproveStatus is a thin wrapper
wc -l app/src/views/curate/ApproveStatus.vue | awk '{ if ($1 > 100) exit 1 }'
wc -l app/src/components/ApprovalTableView.vue | awk '{ if ($1 > 700) exit 1 }'

# Exit criterion #14: client.ts exists
test -f app/src/api/client.ts
test -f app/src/api/genes.ts
test -f app/src/api/auth.ts

# Exit criterion #15: strict tsconfigs exist
test -f app/tsconfig.strict.json
test -f app/tsconfig.router.json
test -f app/tsconfig.api.json
test -f app/tsconfig.types.json
test -f app/tsconfig.composables-auth.json

# E7 closure: no direct localStorage reads outside useAuth.ts
(grep -rn "localStorage\\.token\\|localStorage\\.user" app/src/ | grep -v "useAuth.ts" | wc -l | grep -q "^0$")

# All C1–C6 view tests green against new source
cd app && npx vitest run src/views/curate/ApproveReview.spec.ts src/views/review/Review.spec.ts src/views/curate/ApproveStatus.spec.ts src/views/curate/ModifyEntity.spec.ts src/views/admin/ManageAnnotations.spec.ts src/views/admin/ManageUser.spec.ts

# Frontend coverage still ≥55
grep -q '"lines": 55' app/vitest.config.ts

# Exit criterion #19: every file created/rewritten in v11.0 is TypeScript
# (manual audit in the v11.0-exit PR checklist)

# Exit criterion #18: flake-free streak (master-only, required-jobs-only, push-triggered)
# Tracked as a manual checklist in the v11.0-exit PR per §4.7. Verified by:
gh run list --workflow ci.yml --branch master --limit 15 --json conclusion,event \
  | jq '[.[] | select(.event=="push") | .conclusion] | .[0:10] | all(.=="success")'
# Or the 7-consecutive-plus-7-day ramp per Risk 4 exit ramp (§5.4).

# Human Checkpoint #3 sign-off (tracked in v11.0 milestone doc or PR description)
```

**Phase E is done — and v11.0 is shipped — only when every check above passes AND Human Checkpoint #3 has been signed off.** At that point, `v11.0 — Test Foundation & Structural Hardening` is complete; v11.1 opens the next milestone.
