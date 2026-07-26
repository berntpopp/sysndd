# SysNDD unified UI design implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` task-by-task. Steps use checkbox syntax for tracking. This plan is inactive until the design specification is approved.

**Goal:** Make the Vue application semantically accessible, operationally usable at 390px, and visually coherent without changing clinical meaning, authorisation, API contracts, or workflows.

**Architecture:** Strengthen shared semantic contracts first, then give high-risk operational tables purpose-built mobile presentations, then consolidate the token-backed visual primitives. All production behaviour remains in existing Vue components and typed clients; tests assert DOM/interaction contracts rather than modifying data.

**Tech Stack:** Vue 3, TypeScript, BootstrapVueNext, Sass, Vitest, Playwright, existing authenticated fixtures, Impeccable detector/audit.

## Global constraints

- Do not commit, push, open a PR, or invoke data-changing Playwright actions without explicit user approval.
- Use existing typed clients only; no raw axios or direct auth/localStorage reads in views/components.
- Preserve server-side role gates and current API requests/responses. UI role checks remain presentation only.
- Keep source files focused; do not increase a handwritten source file beyond the 600-line soft ceiling without a cohesive extraction.
- Preserve clinical status, inheritance, and scientific visualisation colours unless the replacement is a documented semantic equivalent with labels and verified contrast.
- Desktop and 390px checks are mandatory; user-facing control targets are at least 44x44px on touch layouts.
- Use `with`-existing test fixtures and read-only navigation only. Never submit review, curation, admin, or entity mutations during verification.

## Pre-execution safety gate

### Task 0: Create isolated, disjoint worktrees and baseline evidence

**Owner:** Lead

**Files:** No production-file ownership. Create separate worktrees named `ui-a11y`, `ui-responsive`, and `ui-design-system`; lead retains integration-only ownership of this plan/spec and test orchestration.

**Steps:**

- [ ] Read `superpowers:using-git-worktrees`, create the three worktrees from the approved base commit, and record each worktree path plus its exclusive ownership list in the task tracker.
- [ ] Run the read-only baseline: `make pre-commit`, `cd app && npm run type-check:strict`, the scoped Vitest suites named below, `npx playwright test tests/e2e/tables-responsive.spec.ts`, and `npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop` when the local E2E stack is available.
- [ ] Capture before screenshots/checks at 1440x900 and 390x844 for `/`, `/Entities?sort=%2Bentity_id&page_size=10`, `/mcp`, `/GeneNetworks`, `/ManageMetadata`, `/ManageReReview`, and `/ManageUser`. Navigate and inspect only; do not activate mutation actions.
- [ ] Run the baseline `$impeccable audit app` and retain its score/findings alongside the supplied 10/20 baseline. If environmental data availability changes results, label it rather than treating it as a visual regression.

**Acceptance:** Worktrees share no writable source file; clean baseline output and known skips are recorded before a change begins.

**Rollback risk:** Worktree setup and read-only checks do not alter product state. Remove only the named temporary worktrees if approval is withdrawn.

---

## Parallel stream A — accessibility semantics

**Exclusive ownership:** `app/src/App.vue`, `app/src/components/AppNavbar.vue`, `app/src/components/AppFooter.vue`, `app/src/views/HomeView.vue`, `app/src/components/analyses/AnalysisShell.vue`, `app/src/components/analyses/AnalyseGeneClusters.vue`, `app/src/views/help/McpInfoView.vue`, `app/src/components/table/MobileTableList.vue`, the public mobile-row files listed in Task 2, `app/src/views/curate/composables/useManageReReview.ts`, `app/src/views/admin/ManageUser.vue`, `app/src/components/tables/TablesLogs.vue`, `app/src/components/tables/LogFilterToolbar.vue`, `app/src/components/review/ReviewTable.vue`, `app/src/components/small/TablePaginationControls.vue`, and their new/updated `*.spec.ts` files. Stream A does **not** edit curation/admin responsive rows owned by stream B or Sass/shared visual primitives owned by stream C.

### Task 1: Establish valid landmarks and keyboard-operable shared regions

**Owner:** Stream A

**Files:**

- Modify: `app/src/App.vue`, `app/src/components/AppNavbar.vue`, `app/src/components/AppFooter.vue`, `app/src/views/HomeView.vue`, `app/src/components/analyses/AnalysisShell.vue`, `app/src/components/analyses/AnalyseGeneClusters.vue`, `app/src/views/help/McpInfoView.vue`
- Create: `app/src/components/accessibility/AccessibleSplitter.vue`
- Test: `app/src/components/accessibility/AccessibleSplitter.spec.ts`, `app/src/views/help/McpInfoView.spec.ts`, `app/tests/e2e/accessibility-landmarks.spec.ts`

**Interfaces:** `AccessibleSplitter` exposes `v-model:size`, `min`, `max`, `orientation`, and a required `label`; keyboard Arrow/Home/End controls update the same pane size used by `AnalyseGeneClusters`. `App.vue` remains the only document `main` owner.

- [ ] Write failing component/E2E assertions that Home, Data Releases, and Gene Networks each expose exactly one visible `main`; header/footer landmarks resolve respectively to `Primary navigation` and `Footer navigation`; each `.mcp-code` block can receive focus and has a unique accessible name; Gene Networks exposes one named `role=separator` with orientation and valid `aria-valuemin`, `aria-valuemax`, and `aria-valuenow`.
- [ ] Run `cd app && npx vitest run src/components/accessibility/AccessibleSplitter.spec.ts src/views/help/McpInfoView.spec.ts` and the new Playwright spec; confirm the unmodified code fails on the reproduced contracts.
- [ ] Replace nested route `main` elements with labelled route sections, label the two navigation landmarks, add focus/name/scroll guidance to code blocks, and replace/wrap the Splitpanes splitter with `AccessibleSplitter` without changing the network's data or layout options.
- [ ] Re-run the targeted tests at desktop and mobile. Use keyboard-only checks for Tab → code region and separator Arrow/Home/End operation; verify no console/page errors.

**Acceptance:** One `main` per affected route; all navigation landmarks distinguishable; long MCP code scrolls by keyboard; splitter remains pointer- and keyboard-operable with state exposed to assistive technology.

**Rollback risk:** Splitter state synchronisation could affect panel sizing. Revert only the adapter/component while retaining landmark/code fixes; do not revert analysis data or Cytoscape behaviour.

### Task 2: Name filters and restore valid mobile-list semantics

**Owner:** Stream A

**Files:**

- Modify: `app/src/components/table/MobileTableList.vue`, `app/src/components/tables/EntitiesMobileRows.vue`, `app/src/components/tables/GenesMobileRows.vue`, `app/src/components/tables/PhenotypesMobileRows.vue`, `app/src/components/nddscore/NddScoreGeneMobileRows.vue`, `app/src/components/analyses/CurationComparisonMobileRows.vue`, `app/src/views/tables/PanelsMobileRows.vue`, `app/src/components/gene/VariantPanel.vue`, `app/src/views/curate/composables/useManageReReview.ts`, `app/src/views/admin/ManageUser.vue`, `app/src/components/tables/TablesLogs.vue`, `app/src/components/tables/LogFilterToolbar.vue`, `app/src/components/review/ReviewTable.vue`, `app/src/components/small/TablePaginationControls.vue`
- Test: the matching existing mobile-row specs, `app/src/components/tables/LogFilterToolbar.spec.ts`, `app/src/components/table/MobileTableList.spec.ts` (create), `app/src/components/small/TablePaginationControls.spec.ts` (create), `app/tests/e2e/accessibility-controls.spec.ts`

**Interfaces:** `MobileTableList` renders a semantic list container; slot consumers render `li` or a neutral `div[role=listitem]`, never `article[role=listitem]`. Filter/pagination components accept an explicit descriptive label prop when a field label is not visible. `UserOption` uses `userRole` only in application data and BFormSelect receives `{ value, text }` options only.

- [ ] Write failing Vitest assertions for semantic `ul/li` (or equivalent valid ARIA list) structure, labels for every affected search/select/pagination control, and sanitised re-review options without a `role` property. Add Playwright checks by accessible name for Manage User, Logs, Review, and Manage Re-review.
- [ ] Run the focused tests and confirm failures: missing accessible names, invalid `article[role=listitem]`, and invalid role-bearing select options.
- [ ] Make the smallest semantic changes: retain current fields, filter values, events, request timing, and mobile visual layout; only add labels/ids, normalise select options, and exchange invalid list item markup for valid list semantics.
- [ ] Run `cd app && npx vitest run` on every listed spec, then Playwright at 1440x900 and 390x844. Verify values continue to filter/paginate but do not execute bulk/assignment actions.

**Acceptance:** Axe finds no invalid ARIA role or unnamed affected control; list records preserve their text/action order and desktop table behaviour; selecting a filter still emits the existing model/event payload.

**Rollback risk:** BFormSelect normalisation can change selected-value types. Keep `value` numeric/string/null types unchanged and roll back just the option mapping if a downstream selection test detects a changed payload.

---

## Parallel stream B — responsive operational UX

**Exclusive ownership:** `app/src/views/admin/ManageMetadata.vue`, `app/src/views/admin/ManageMetadata.spec.ts`, `app/src/views/admin/components/MetadataMobileRows.vue` (new), `app/src/views/admin/components/MetadataMobileRows.spec.ts` (new), `app/src/views/curate/components/ReReviewAssignmentTable.vue`, `app/src/views/curate/components/ReReviewAssignmentMobileRows.vue` (new), `app/src/views/curate/components/ReReviewAssignmentMobileRows.spec.ts` (new), `app/src/views/curate/components/ApprovalMobileRows.vue`, `app/src/views/curate/components/ApprovalMobileRows.spec.ts`, and `app/tests/e2e/operational-mobile-rows.spec.ts` (new). Stream B must not edit Stream A semantic primitives or Stream C Sass/tokens.

### Task 3: Give metadata and re-review work a mobile-first operational alternative

**Owner:** Stream B

**Files:** exact files owned by stream B above.

**Interfaces:** The new row components receive existing item/field/action callbacks; they do not call API clients. `ManageMetadata` and `ReReviewAssignmentTable` select desktop table above the existing responsive breakpoint and mobile rows below it. Existing edit/deactivate/recalculate/reassign/unassign handlers and role/disabled conditions are passed through unchanged.

- [ ] Write failing Vitest tests asserting metadata rows expose term/status plus named Edit/Deactivate actions, re-review rows expose batch/user/status plus named Recalculate/Reassign/Unassign actions, and disabled/role-limited states are preserved.
- [ ] Add failing 390px Playwright checks that no primary metadata or re-review action is outside the first horizontal view, each operational action has a 44px hit rectangle, and no horizontal document/main overflow occurs. Use fixture navigation only.
- [ ] Implement compact record rows with identity line, status/chips, essential assigned-user/date context, and stable action group. Keep a labelled desktop horizontal-scroll fallback only for secondary columns. Add visible labels or precise `aria-label`s for re-review filters in this owned table.
- [ ] Run the unit specs, `npx playwright test tests/e2e/operational-mobile-rows.spec.ts --project=chromium-mobile`, and the authenticated design spec at mobile/desktop. Do not click action buttons that write.

**Acceptance:** At 390px, a curator/admin can identify a record and locate its permitted action without sideways scrolling; each action meets 44x44px; at desktop the current dense table and sort/filter semantics remain intact.

**Rollback risk:** Responsive component switching may desynchronise selection or pagination. Keep state in the parent and pass only props/events; the desktop table remains a safe immediate rollback path.

### Task 4: Apply the 44px policy to existing curation mobile actions

**Owner:** Stream B

**Files:** `app/src/views/curate/components/ApprovalMobileRows.vue`, `app/src/views/curate/components/ApprovalMobileRows.spec.ts`, `app/tests/e2e/operational-mobile-rows.spec.ts`.

- [ ] Add failing dimension assertions for expand/edit/status/approve/dismiss controls at 390px, including icon-only controls whose glyph remains compact.
- [ ] Implement local mobile-only hit-area wrappers/minimum dimensions without increasing desktop row density or changing the handlers, confirmation flow, colours, or labels.
- [ ] Re-run the focused Vitest spec and mobile Playwright checks. Check keyboard focus remains visible and actions retain their current accessible names.

**Acceptance:** Every sampled Approval control is at least 44px in both dimensions on touch layouts, maintains a clear visual order, and does not cause row clipping or overflow.

**Rollback risk:** Enlarged targets may increase row height. Retain the test's compact-row height threshold and adjust interior spacing before compromising action size.

---

## Parallel stream C — design-system unification

**Exclusive ownership:** `app/src/assets/scss/partials/_semantic-tokens.scss` (new), `app/src/assets/scss/custom.scss`, `app/src/components/layout/AuthenticatedPageShell.vue`, `app/src/components/table/TableShell.vue`, `app/src/views/admin/components/statistics/StatCard.vue`, `app/src/views/help/AboutView.vue`, `app/src/components/nddscore/NddScoreGeneDetail.vue`, `app/src/components/nddscore/NddScorePredictionCard.vue`, `app/src/views/pages/SearchView.vue`, and their direct Vitest specs. Stream C does not edit Stream A/B components during the parallel phase.

### Task 5: Introduce semantic aliases and migrate the shared shell hierarchy

**Owner:** Stream C

**Files:** `app/src/assets/scss/partials/_semantic-tokens.scss` (new), `app/src/assets/scss/custom.scss`, `app/src/components/layout/AuthenticatedPageShell.vue`, `app/src/components/table/TableShell.vue`, `app/src/components/layout/AuthenticatedPageShell.spec.ts`, `app/src/components/table/TableShell.spec.ts`.

**Interfaces:** Token aliases map only to current approved primitives; no component consumes raw colour literals for routine canvas/surface/text/border/action states. Shell props and heading-level APIs remain unchanged.

- [ ] Write failing source/component assertions that the two shared shells use semantic surface/text/border tokens, retain `TableShell` heading levels, and expose existing slots/classes unchanged.
- [ ] Implement semantic aliases for canvas, raised/subtle surfaces, primary/secondary/muted text, strong/subtle borders, and action focus states. Migrate only the shared shell CSS to aliases; keep existing medical/status primitives as their source values.
- [ ] Run `cd app && npx vitest run src/components/layout/AuthenticatedPageShell.spec.ts src/components/table/TableShell.spec.ts`, `npm run type-check:strict`, and desktop/mobile screenshots of a public table plus authenticated page.

**Acceptance:** The shell hierarchy is visually unchanged or calmer, token ownership is apparent, heading/slot consumers are compatible, and no new palette or dark-mode claim is introduced.

**Rollback risk:** CSS custom-property load order can produce fallback regressions. Ensure `_semantic-tokens.scss` is imported after primitive tokens and revert its import plus the two shell declarations together if a runtime variable is missing.

### Task 6: Consolidate visual drift without erasing clinical meaning

**Owner:** Stream C

**Files:** `app/src/views/admin/components/statistics/StatCard.vue`, `app/src/views/help/AboutView.vue`, `app/src/components/nddscore/NddScoreGeneDetail.vue`, `app/src/components/nddscore/NddScorePredictionCard.vue`, `app/src/views/pages/SearchView.vue`, `app/src/components/nddscore/NddScoreGeneDetail.spec.ts`, `app/src/components/nddscore/NddScorePredictionCard.spec.ts`.

- [ ] Write failing tests/source assertions that decorative side accents are absent from generic stat/about surfaces, NDDScore warning content remains labelled and uses the approved warning semantic surface, and Search has no `transition: width`.
- [ ] Replace decorative stripes with the shared surface/border hierarchy. For NDDScore, retain the warning label/icon and warning-state meaning, but express it with the documented status surface rather than a one-off stripe/gradient. Do not alter prediction values, category logic, or chart/data colours.
- [ ] Replace the low-value width animation with an opacity/transform-free state change (or no animation) that preserves loading/progress status and reduced-motion behaviour.
- [ ] Run the NDDScore Vitest specs, target Search’s existing suite if present, and visual checks at both sizes. Run detector and manually classify any remaining side border as either a semantic status treatment or a false positive in the report.

**Acceptance:** Decorative side-accent and width-transition detector findings are eliminated; NDDScore retains clear warning meaning and AA text contrast; visual information density does not increase.

**Rollback risk:** A warning treatment may be mistaken for decoration. Keep a labelled, tokenised warning surface and revert only presentation CSS if domain review rejects it—never remove the warning copy/status.

---

## Lead-only integration after parallel streams merge

### Task 7: Integrate, resolve only planned overlaps, and perform security/API-boundary review

**Owner:** Lead

**Files:** Integration changes only where a post-merge conflict makes them essential; otherwise no new production changes. Potential ordered follow-up: migrate `MobileTableList.vue` styles to semantic tokens only after Stream A has merged.

- [ ] Review each worktree diff against exclusive ownership, `git diff --check`, 600-line file sizes, and source patterns. Reject/split any file edited by more than one stream.
- [ ] Verify no raw axios, direct localStorage reads, API payload changes, route changes, role-gate changes, or write actions were added. Confirm no credentials/test tokens appear in diffs, screenshots, logs, or reports.
- [ ] Resolve only mechanical integration conflicts; schedule any genuine cross-stream design work as a new sequential task rather than editing it opportunistically.
- [ ] Run `make code-quality-audit`, `make lint-app`, `cd app && npm run type-check:strict`, all focused Vitest suites, and `git diff --check`.

**Acceptance:** A clean combined diff retains typed-client/API/authorisation boundaries, has no ownership conflict, and all deterministic checks pass.

**Rollback risk:** A semantic token import or shared markup change may affect unrelated routes. Revert the single stream commit/worktree patch that introduced the regression; retain successful independent streams.

### Task 8: Full UX/a11y verification and audit comparison

**Owner:** Lead

**Files:** Create/update only final evidence artifacts under `.impeccable/audits/` if the audit tool produces them; do not alter application code.

- [ ] Run `make pre-commit`, `cd app && npm run type-check:strict`, the relevant Vitest suites, `npx playwright test tests/e2e/accessibility-landmarks.spec.ts tests/e2e/accessibility-controls.spec.ts tests/e2e/operational-mobile-rows.spec.ts tests/e2e/tables-responsive.spec.ts`, and `npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts` at both configured viewports.
- [ ] Inspect the target routes at 1440x900 and 390x844: landmark tree, focus order, named controls, code-block keyboard scrolling, splitter keys, 44px action measurements, no document/main overflow, loading/empty/error states, and unchanged clinical badge/visualisation meaning.
- [ ] Re-run `$impeccable audit app` and compare every changed dimension against the supplied 10/20 baseline. Report score changes separately from environment/data-dependent differences and list remaining conscious deferrals.

**Acceptance:** The final report contains command output/status, viewport coverage, before/after audit result, changed files by stream, verified fixes, and remaining issues; no mutation was performed.

**Rollback risk:** Verification is read-only. If a test exposes a workflow regression, revert the responsible stream patch and re-run the smallest failing test before attempting a scoped correction.

## Approval and execution boundary

Approval authorises only Tasks 0–8 and the files named above. It does not authorise commits, pushes, PRs, production data changes, copy/provenance changes on Home, or workflow redesigns outside this plan.
