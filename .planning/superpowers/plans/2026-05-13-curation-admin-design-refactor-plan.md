# Curation and Admin Design Refactor Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Keep PRs small and verify each route locally with Playwright because these authenticated views are local-only visual coverage.

**Goal:** Bring all Curation and Administration views up to the current SysNDD design standard used by `/`, `/Entities?sort=%2Bentity_id&page_size=10`, and the recent table/page shells.

**Architecture:** Reuse the existing `AuthenticatedPageShell.vue` and `TableShell.vue` visual language instead of inventing a second admin system. Convert legacy dark Bootstrap cards and stacked mobile tables into consistent route shells, compact toolbars, purpose-built mobile rows, and footer-safe scroll areas.

**Tech Stack:** Vue 3, TypeScript, Bootstrap Vue Next, existing table/mobile-row patterns, local Playwright visual checks.

---

## Playwright Evidence

Audit run against the active dev app at `http://localhost:5173` after logging in as the deterministic `pw_admin` Playwright fixture user. The fixture user had to be seeded into the current dev DB because the active `make dev` database did not contain the Playwright accounts. The temporary fixture users were removed after the audit.

Artifacts:

- Screenshots and metrics: `.planning/screenshots/2026-05-13-curation-admin-design-audit/`
- Desktop contact sheet: `.planning/screenshots/2026-05-13-curation-admin-design-audit/contact-desktop-top.png`
- Mobile contact sheet: `.planning/screenshots/2026-05-13-curation-admin-design-audit/contact-mobile-top.png`
- Route metrics: `.planning/screenshots/2026-05-13-curation-admin-design-audit/audit-summary.tsv`
- Scroll/overlap metrics: `.planning/screenshots/2026-05-13-curation-admin-design-audit/scroll-overlap-summary.tsv`

Findings from the audit:

- All target routes returned `200` and had no captured console errors.
- Top-level horizontal overflow was not detected at 1440x900 or 390x844.
- Every Curation/Admin target had `shellCount=0`; the reference Entities table had `shellCount=1`.
- The authenticated views are inside `main.scrollable-content`, so document-level full-page screenshots miss lower content. Several pages have internal scroll heights far beyond the visible area.
- Mobile stacked tables are the biggest quality gap: `ManageOntology` measured `8257px`, `ManageUser` `6395px`, `ApproveUser` `3553px`, `ApproveReview` `3143px`, and `ViewLogs` `2979px` of internal scroll content.
- Many routes use dark-bordered Bootstrap cards, nested cards, duplicated headings, or dense controls that do not match the current restrained table/home design.

## Current Standard

A page fits the current standard when it has:

- A single clear page shell with compact title, description, meta, and actions.
- White surfaces with subtle borders/shadows, about 8px radius, and no card-in-card chrome.
- Dense but readable operation controls, aligned in predictable toolbar rows.
- Tables inside `TableShell`, with mobile-specific record rows instead of Bootstrap stacked table output.
- Footer-safe scrolling so important controls and row actions are not covered by the fixed footer.
- One real page heading, accessible icon buttons, and labels for filters/help controls.

## Route Ratings

Scale: `5` fits the standard, `4` mostly fits, `3` functional but inconsistent, `2` legacy/high-priority refactor, `1` serious UX blocker.

### Curation

| Route | Score | Evidence | Refactor Direction |
|---|---:|---|---|
| `/CreateEntity` | 3 | Modern wizard structure, but no authenticated shell; desktop card is overly centered and mobile stepper/form content falls into the fixed-footer danger zone. | Wrap in `AuthenticatedPageShell`; make wizard content footer-safe; tighten stepper and form spacing. |
| `/ModifyEntity` | 2 | Nested dark cards, sparse empty state, no page-level hierarchy. | Replace nested search cards with a shell, search/results split, and entity summary panel. |
| `/ApproveReview` | 2 | Dark bordered card, dense legend, desktop scroll height `1813px`, mobile stacked table `3143px`. | Move to `TableShell`; compact toolbar; purpose-built approval mobile rows. |
| `/ApproveStatus` | 2 | Same approval-table language as review; mobile stacked table `2371px`. | Share the approval table refactor with status-specific chips and row actions. |
| `/ApproveUser` | 2 | Desktop is usable, but mobile stacked user rows are long and visually heavy at `3553px`. | Create user-application mobile cards; move actions into stable icon cluster. |
| `/ManageReReview` | 2 | Four separate cards, mixed create/assign/manage workflows, mobile scroll `2518px`. | Split into shell sections: create batch, assign entities, manage submissions. |

### Administration

| Route | Score | Evidence | Refactor Direction |
|---|---:|---|---|
| `/ManageUser` | 2 | Functional table, but legacy dark card and severe mobile stacked table height `6395px`. | Convert to `TableShell`; add compact user mobile rows and bulk toolbar. |
| `/ManageAnnotations` | 3 | Operation cards are understandable, but the page is a loose card stack without shell rhythm. | Turn into an operations board with status chips, descriptions, and grouped actions. |
| `/ManageOntology` | 2 | Functional table, but mobile stacked table height `8257px`; old table frame. | Use `TableShell` plus compact variation-term mobile rows. |
| `/ManageAbout` | 2 | Nine cards with seven nested cards; editing surface feels like a card stack rather than CMS tooling. | Build an editor layout with section list, editor pane, and publish actions. |
| `/ViewLogs` | 3 | Inherits table behavior and is functional, but still has legacy chrome and mobile stacked height `2979px`. | Move to authenticated table shell; compact log mobile rows. |
| `/AdminStatistics` | 4 | Closest to current standard; KPI/chart hierarchy works, but filters/header are disconnected and chart content can meet the footer. | Wrap in shell; compress filters; make charts footer-safe. |
| `/ManageBackups` | 3 | Usable admin table, but backup/restore actions and danger flows are visually crowded. | Use shell plus operations/action panels and safer destructive zones. |
| `/ManagePubtator` | 2 | Nested cards, heavy bordered form, oversized danger zone. | Rebuild as an operation page with query/status/fetch/cache panels. |
| `/ManageLLM` | 3 | Dashboard intent is good, but duplicate heading, nested cards, dark border, and oversized tabs feel legacy. | Use shell, KPI grid, segmented tabs, and compact job/cache panels. |

## Small PR Sequence

### PR 1: Shared Authenticated Surface And Scroll Safety

**Files:**

- Modify: `app/src/components/layout/AuthenticatedPageShell.vue`
- Modify: `app/src/App.vue`
- Modify: target route wrappers under `app/src/views/admin/` and `app/src/views/curate/`
- Add: `app/tests/e2e/authenticated-admin-curation-design.spec.ts`

Steps:

- Extend `AuthenticatedPageShell` only if needed for `meta`, `actions`, and full-width content variants.
- Ensure `main.scrollable-content` and shell content reserve footer-safe bottom space. The fixed footer must not cover form controls, table actions, or chart legends.
- Add a local-only Playwright design spec that logs in as admin and asserts:
  - route loads with no hard console errors,
  - no horizontal overflow at 1440 and 390,
  - exactly one visible route heading,
  - target routes use an authenticated shell,
  - visible content does not sit under the fixed footer.
- Apply the shell wrapper to routes without changing API calls or data timing.

### PR 2: Approval And User Management Tables

**Files:**

- Modify: `app/src/views/curate/ApproveReview.vue`
- Modify: `app/src/views/curate/ApproveStatus.vue`
- Modify: `app/src/views/curate/ApproveUser.vue`
- Modify: `app/src/components/ApprovalTableView.vue`
- Modify: `app/src/views/admin/ManageUser.vue`
- Add: `app/src/views/curate/components/ApprovalMobileRows.vue`
- Add: `app/src/views/curate/components/UserApplicationMobileRows.vue`
- Add: `app/src/views/admin/components/UserAdminMobileRows.vue`

Steps:

- Replace dark `BCard` table frames with `TableShell`.
- Keep desktop columns and existing approve/dismiss/edit behavior.
- Replace `stacked="md"` output with compact mobile rows:
  - primary line: entity/user identifier,
  - secondary line: disease/email/status,
  - chip row: category, role, user, date,
  - action cluster: details/edit/approve/dismiss.
- Keep legends but move them into a compact help/disclosure row.
- Add Vitest coverage for mobile row rendering and emitted actions.

### PR 3: Admin Table Surfaces

**Files:**

- Modify: `app/src/views/admin/ManageOntology.vue`
- Modify: `app/src/views/admin/ViewLogs.vue`
- Modify: `app/src/views/admin/ManageBackups.vue`
- Add: `app/src/views/admin/components/OntologyMobileRows.vue`
- Add: `app/src/views/admin/components/LogMobileRows.vue`
- Add: `app/src/views/admin/components/BackupMobileRows.vue`

Steps:

- Put each table in `TableShell` with consistent toolbar placement.
- Replace mobile stacked tables with compact rows.
- Keep export, copy-link, filter presets, pagination, and destructive actions.
- Move backup restore/delete confirmations into clearer danger panels/modals with stable footer-safe actions.

### PR 4: Curation Workflow Forms

**Files:**

- Modify: `app/src/views/curate/CreateEntity.vue`
- Modify: `app/src/views/curate/ModifyEntity.vue`
- Modify: `app/src/views/curate/ManageReReview.vue`
- Modify: `app/src/views/curate/components/EntitySearchPanel.vue`
- Modify: `app/src/views/curate/components/EntityInfoHeader.vue`

Steps:

- Keep existing composables and submission behavior unchanged.
- `CreateEntity`: keep the five-step wizard, but place it in the authenticated shell and make the stepper responsive.
- `ModifyEntity`: replace nested dark search cards with a two-zone layout: search/results first, selected entity summary and edit actions second.
- `ManageReReview`: separate create-batch, assignment, and submissions management into clear sections with compact headers and status chips.
- Add empty, loading, and selected states that do not rely on large bordered cards.

### PR 5: Admin Operation Pages And Dashboards

**Files:**

- Modify: `app/src/views/admin/ManageAnnotations.vue`
- Modify: `app/src/views/admin/ManageAbout.vue`
- Modify: `app/src/views/admin/AdminStatistics.vue`
- Modify: `app/src/views/admin/ManagePubtator.vue`
- Modify: `app/src/views/admin/ManageLLM.vue`

Steps:

- `ManageAnnotations`: convert the cards into grouped operation panels with status chips and primary/secondary action hierarchy.
- `ManageAbout`: move to a CMS-style layout: section navigation on the left, editor/preview on the right, publish actions in the shell action area.
- `AdminStatistics`: keep the KPI/dashboard direction; move filters into shell actions and keep charts within footer-safe panels.
- `ManagePubtator`: split search/status, fetch job, and clear-cache danger zone into separate operation panels.
- `ManageLLM`: remove duplicate heading and nested cards; use KPI grid, segmented tabs, and compact job/cache controls.

## Verification Gates

Run after each PR:

```bash
make lint-app
cd app && npm run type-check
cd app && npm run type-check:strict
cd app && npm run test:unit
```

Run local Playwright after each visual PR:

```bash
cd app && npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts
```

Manual evidence to update per PR:

- Capture desktop `1440x900` and mobile `390x844` screenshots for each changed route.
- Update `.planning/screenshots/<date>-curation-admin-design-audit/` or a new dated folder.
- Confirm no page regresses from the ratings above.

## Non-Goals

- No API endpoint, data contract, request timing, auth guard, or database behavior changes.
- No replacement of Bootstrap Vue Next.
- No destructive admin action should be exercised by the design audit.
- No global marketing-style redesign; these are operational tools and should stay dense, calm, and scannable.
