# Authenticated Review Routes Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize `/User`, `/ReviewInstructions`, and `/Review` so authenticated review surfaces match the new SysNDD table/home design.

**Architecture:** Add one shared authenticated route shell, migrate the simple instructions page first, split the large user page into focused presentational components, and modernize the review queue table shell without touching data/composable/API behavior.

**Tech Stack:** Vue 3, TypeScript where existing files use it, Bootstrap Vue Next, Vitest, Playwright local smoke checks.

---

### Task 1: Shared Authenticated Page Shell

**Files:**
- Create: `app/src/components/layout/AuthenticatedPageShell.vue`
- Test: `app/src/components/layout/AuthenticatedPageShell.spec.ts`

- [ ] **Step 1: Write failing shell tests**

Create tests that mount the shell with title, description, meta, actions, and default slot. Assert it renders a single `.authenticated-page`, a `.authenticated-frame`, title text, description, meta badge, actions slot, and content.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && npx vitest run src/components/layout/AuthenticatedPageShell.spec.ts`

Expected: FAIL because the component does not exist.

- [ ] **Step 3: Implement shell**

Implement a scoped component with props:

```ts
withDefaults(
  defineProps<{
    title: string;
    description?: string;
    meta?: string;
    contentClass?: string;
  }>(),
  {
    description: '',
    meta: '',
    contentClass: '',
  }
);
```

Template requirements:

- outer `<div class="authenticated-page">`
- inner `<section class="authenticated-frame">`
- header with `<h1 class="authenticated-title">`
- optional description and meta
- optional `actions` slot
- content area with default slot

Style requirements:

- full-width page padding like `AnalysisShell`
- max width near 1480px
- 8px radius, subtle border, white frame, restrained shadow
- mobile padding reduced

- [ ] **Step 4: Run shell test**

Run: `cd app && npx vitest run src/components/layout/AuthenticatedPageShell.spec.ts`

Expected: PASS.

### Task 2: Modernize Review Instructions

**Files:**
- Modify: `app/src/views/review/ReviewInstructions.vue`
- Test: `app/src/views/review/ReviewInstructions.spec.ts`

- [ ] **Step 1: Write failing instructions test**

Mount `ReviewInstructions.vue` with `AuthenticatedPageShell` stubbed. Assert:

- title is "Review instructions"
- all three documentation links render
- no accordion element is rendered
- links use `DOCS_URLS.CURATION_CRITERIA`, `DOCS_URLS.RE_REVIEW_INSTRUCTIONS`, and `DOCS_URLS.TUTORIAL_VIDEOS`

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && npx vitest run src/views/review/ReviewInstructions.spec.ts`

Expected: FAIL before migration.

- [ ] **Step 3: Implement instructions layout**

Replace the accordion/card with `AuthenticatedPageShell`. Render a compact list of instruction rows from a local array:

```ts
const instructionLinks = [
  {
    title: 'Curation criteria',
    description: 'Evidence and classification rules used while reviewing entities.',
    href: DOCS_URLS.CURATION_CRITERIA,
    icon: 'bi-list-check',
  },
  {
    title: 'Re-review instructions',
    description: 'Step-by-step workflow for updating assigned entity reviews.',
    href: DOCS_URLS.RE_REVIEW_INSTRUCTIONS,
    icon: 'bi-arrow-repeat',
  },
  {
    title: 'Tutorial videos',
    description: 'Short walkthroughs for the review workflow and supporting tools.',
    href: DOCS_URLS.TUTORIAL_VIDEOS,
    icon: 'bi-play-btn',
  },
];
```

Keep `useHead` metadata.

- [ ] **Step 4: Run instructions test**

Run: `cd app && npx vitest run src/views/review/ReviewInstructions.spec.ts`

Expected: PASS.

### Task 3: Split and Modernize User View

**Files:**
- Create: `app/src/views/user/UserProfileHeader.vue`
- Create: `app/src/views/user/UserContributionStats.vue`
- Create: `app/src/views/user/UserProfileDetails.vue`
- Create: `app/src/views/user/UserSecurityPanel.vue`
- Modify: `app/src/views/UserView.vue`
- Test: `app/src/views/UserView.spec.ts`
- Test: `app/src/views/user/UserProfileHeader.spec.ts`
- Test: `app/src/views/user/UserProfileDetails.spec.ts`

- [ ] **Step 1: Inspect existing `UserView.vue` behavior**

Before editing, identify the state/methods used by profile editing, ORCID/email validation, password update, and session refresh. Do not move API calls out of the parent unless they are already local presentation-only helpers.

- [ ] **Step 2: Write focused tests**

Add or update tests so they verify:

- `UserView.vue` uses `AuthenticatedPageShell`.
- profile details emit edit/save/cancel events.
- password panel keeps current password fields and emits update/change events.
- identity header renders user name, role, member date, and active status.

- [ ] **Step 3: Run tests to verify failures**

Run: `cd app && npx vitest run src/views/UserView.spec.ts src/views/user/UserProfileHeader.spec.ts src/views/user/UserProfileDetails.spec.ts`

Expected: new component tests fail before components exist or before view uses the shell.

- [ ] **Step 4: Extract presentational components**

Move markup only. Keep data loading, API calls, validation computed properties, and mutation methods in `UserView.vue`. Pass state as props and emit user actions back to parent.

- [ ] **Step 5: Rebuild layout**

Use `AuthenticatedPageShell` in `UserView.vue`. Place profile header full width, stats in a compact row, profile details and security panel in a responsive two-column grid on desktop, stacked on mobile.

- [ ] **Step 6: Run tests**

Run: `cd app && npx vitest run src/views/UserView.spec.ts src/views/user/UserProfileHeader.spec.ts src/views/user/UserProfileDetails.spec.ts`

Expected: PASS.

### Task 4: Modernize Review Queue Table Shell

**Files:**
- Modify: `app/src/views/review/Review.vue`
- Modify: `app/src/views/review/components/ReviewQueueTable.vue`
- Test: `app/src/views/review/Review.spec.ts`

- [ ] **Step 1: Write failing review shell tests**

Update tests to assert:

- `Review.vue` uses `AuthenticatedPageShell`.
- `ReviewQueueTable` no longer renders a dark card header.
- search/filter controls remain present.
- pagination and per-page controls remain present.
- refresh emit still fires.

- [ ] **Step 2: Run tests to verify failures**

Run: `cd app && npx vitest run src/views/review/Review.spec.ts`

Expected: FAIL on new shell expectations before implementation.

- [ ] **Step 3: Wrap Review view**

Use `AuthenticatedPageShell` around the existing `ReviewQueueTable` and modals. Do not change `setup()`, composable calls, watchers, mounted loading, or emitted action handlers.

- [ ] **Step 4: Convert queue table chrome**

Replace the dark `BCard` wrapper in `ReviewQueueTable.vue` with `TableShell`. Preserve every prop and emit. Move controls into the `toolbar` slot, use a compact legend row, and keep `BTable` desktop behavior.

- [ ] **Step 5: Improve mobile density**

At minimum, reduce stacked table noise with scoped CSS. If local complexity remains reasonable, hide `BTable` below `md` and render compact mobile rows using the same row action emits. Do not alter the item array or pagination/filter behavior.

- [ ] **Step 6: Run review tests**

Run: `cd app && npx vitest run src/views/review/Review.spec.ts`

Expected: PASS.

### Task 5: Verification and Cleanup

**Files:**
- Modify as needed only for formatting or test compatibility.

- [ ] **Step 1: Run affected unit tests**

Run:

```bash
cd app && npx vitest run \
  src/components/layout/AuthenticatedPageShell.spec.ts \
  src/views/review/ReviewInstructions.spec.ts \
  src/views/UserView.spec.ts \
  src/views/user/UserProfileHeader.spec.ts \
  src/views/user/UserProfileDetails.spec.ts \
  src/views/review/Review.spec.ts \
  src/components/small/InlineHelpBadge.spec.ts \
  src/components/small/FooterNavItem.spec.ts \
  src/components/small/FooterNavItem.a11y.spec.ts
```

Expected: PASS.

- [ ] **Step 2: Run formatting/lint/type checks**

Run:

```bash
cd app && npx prettier --check \
  src/components/layout/AuthenticatedPageShell.vue \
  src/components/layout/AuthenticatedPageShell.spec.ts \
  src/views/review/ReviewInstructions.vue \
  src/views/review/ReviewInstructions.spec.ts \
  src/views/UserView.vue \
  src/views/user/UserProfileHeader.vue \
  src/views/user/UserContributionStats.vue \
  src/views/user/UserProfileDetails.vue \
  src/views/user/UserSecurityPanel.vue \
  src/views/review/Review.vue \
  src/views/review/components/ReviewQueueTable.vue
cd app && npx eslint \
  src/components/layout/AuthenticatedPageShell.vue \
  src/components/layout/AuthenticatedPageShell.spec.ts \
  src/views/review/ReviewInstructions.vue \
  src/views/review/ReviewInstructions.spec.ts \
  src/views/UserView.vue \
  src/views/user/UserProfileHeader.vue \
  src/views/user/UserContributionStats.vue \
  src/views/user/UserProfileDetails.vue \
  src/views/user/UserSecurityPanel.vue \
  src/views/review/Review.vue \
  src/views/review/components/ReviewQueueTable.vue
cd app && npm run type-check
cd app && npm run type-check:strict
```

Expected: PASS or report exact pre-existing unrelated failures.

- [ ] **Step 3: Run Playwright visual smoke**

Use a local authenticated session and inspect `/User`, `/ReviewInstructions`, and `/Review` at 1440x900, 1024x768, and 390x844. Confirm:

- no horizontal overflow
- route shell is consistent
- `/Review` controls do not sprawl on mobile
- `/User` uses desktop width better

- [ ] **Step 4: Commit**

Commit all relevant changes on `codex/curation-comparisons-upset-layout` with a message such as:

```bash
git commit -m "feat: modernize authenticated review routes"
```
