# Admin Visual Review

Date: 2026-05-14

Scope: `app/src/views/admin/*` authenticated administrator surfaces, reviewed against `documentation/10-visual-design-guide.md`.

## Rating Scale

- `5`: Matches the visual guide; only minor refinements remain.
- `4`: Strong, guide-aligned surface with manageable local debt.
- `3`: Functional and shell-aligned, but still visually inconsistent or too dense.
- `2`: Legacy structure remains; redesign should be prioritized.
- `1`: Serious usability blocker.

## Ratings

| Route | Rating | Notes |
|---|---:|---|
| `/ManageUser` | 4 | Strong `TableShell` and mobile-row implementation. Remaining debt is mobile control height and hidden desktop action-label discoverability. |
| `/ManageAnnotations` | 4 | Operation panels now match the guide and remove dark card chrome. Remaining debt is long mobile scroll caused by many operation groups. |
| `/ManageOntology` | 4 | Strong table/mobile-row surface with no overflow. Remaining debt is high mobile scroll depth and dense filter/pagination stack. |
| `/ManageAbout` | 3.5 | Main CMS wrapper now uses the shared operation panel. Section editor internals still rely on many repeated cards and should eventually become a section-list/editor-pane layout. |
| `/ViewLogs` | 4 | Strong table-shell surface with compact controls and mobile rows. Keep as an admin table reference. |
| `/AdminStatistics` | 3.5 | Legacy dark statistic cards were replaced for text summaries. Chart controls remain dense on mobile and need a tighter responsive toolbar. |
| `/ManageBackups` | 4 | Good `TableShell` plus separated backup/import zones. Remaining debt is action density and modal flow review for destructive operations. |
| `/ManagePubtator` | 4 | Rebuilt as operation panels with clearer fetch and danger zones. Lighthouse on the authenticated route scored Performance `0.96`, Accessibility `1.00`, Best Practices `0.96`. |
| `/ManageLLM` | 3.5 | Outer dark card replaced and quick actions now use the shared panel. KPI/tab internals still use several nested cards but are functional and scannable. |

## Verification Summary

- `cd app && npx vitest run src/components/admin/AdminOperationPanel.spec.ts src/views/admin/ManageAnnotations.spec.ts src/views/admin/AdminStatistics.spec.ts src/views/admin/ManageUser.spec.ts`
- `cd app && npm run type-check`
- `cd app && PLAYWRIGHT_BASE_URL=http://127.0.0.1:5174 npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop`
- Authenticated Playwright interaction audit covered nav/user dropdowns, admin filters/selects, tab switching, and confirmation modals for backups, PubTator cache, and LLM regeneration without hard console errors.
- Lighthouse was run against authenticated `/ManagePubtator`.

## Remaining Design Priorities

1. Compress mobile filter/pagination stacks in `/ManageUser` and `/ManageOntology`.
2. Convert `/ManageAbout` from repeated collapsible cards into a true CMS section-list/editor-pane layout.
3. Tighten `/AdminStatistics` mobile chart controls.
4. Reduce nested KPI/card chrome inside `/ManageLLM`.
