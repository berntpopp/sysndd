# Authenticated Review Routes Modernization Design

## Goal

Unify `/User`, `/ReviewInstructions`, and `/Review` with the newer SysNDD visual system used on the home page, entity/gene tables, and analysis routes while preserving existing authentication, API calls, review composables, request timing, and Bootstrap Vue Next architecture.

## Current Findings

Playwright screenshots were captured at 1440x900, 1024x768, and 390x844 under `/tmp/sysndd-route-review`. None of the target routes has horizontal overflow, but the visual systems diverge:

- `/User` is visually cleaner than the older pages, but it is centered too narrowly on desktop, uses local card styling instead of shared route chrome, and `UserView.vue` is 929 lines.
- `/ReviewInstructions` still uses a nested Bootstrap accordion/card with no page header or clear information architecture.
- `/Review` keeps a dark bordered card, oversized legend area, and Bootstrap stacked mobile table behavior that becomes tall and hard to scan.

## UX Direction

Use one shared authenticated page shell for logged-in utility and review pages. It should match the restrained, modern table/analysis surfaces: full available width, compact header, optional meta/action area, white content frame, subtle border, and responsive padding. It must not introduce landing-page decoration or nested card-in-card layouts.

## Route Behavior

### `/ReviewInstructions`

Replace the accordion/card with a compact instruction surface:

- Header: "Review instructions" with a short description.
- Body: three action rows for curation criteria, re-review instructions, and tutorial videos.
- Each row uses an icon, a short explanation, and a direct documentation link.
- No data loading or API calls are needed.

### `/User`

Keep existing user/profile/security behavior but split the large view into focused presentational components:

- `UserProfileHeader.vue` for identity, role, and session badge.
- `UserContributionStats.vue` for active review/status counts.
- `UserProfileDetails.vue` for username/email/ORCID/abbreviation editing.
- `UserSecurityPanel.vue` for session countdown and password change.

The page should use the shared authenticated shell and a responsive two-column layout on wide screens, stacked on mobile. The header should use available width instead of a narrow centered column.

### `/Review`

Keep existing review data/composables and modal wiring unchanged. Modernize only presentation:

- Wrap the page in the authenticated shell.
- Convert `ReviewQueueTable.vue` from dark `BCard` chrome to the same `TableShell` language as `/Entities`.
- Place filters/search/quick filters on the left and per-page/pagination on the right.
- Make the icon legend compact and less dominant.
- Preserve all existing emits, props, table fields, actions, modal behavior, and data loading timing.
- Replace Bootstrap's stacked mobile table output with a compact mobile row renderer if feasible in this change; otherwise keep desktop table behavior and make stacked output less visually noisy.

## Accessibility

- Page shells need a real heading (`h1` or shell title).
- Buttons must have accessible labels.
- Links that open documentation should have clear text and retain normal keyboard access.
- Help and tooltip triggers should use buttons, not `href="#"`.

## Testing

Add focused Vitest coverage for:

- Authenticated shell slots and responsive structure.
- Review instructions rendering the three documentation rows.
- Split user components preserving display/edit props and emitted events.
- Review queue table using the modern shell and preserving key controls/emits.

Run Playwright visual smoke checks for `/User`, `/ReviewInstructions`, and `/Review` at desktop, tablet, and mobile after implementation.

## Non-Goals

- No API, database, SWR, cache store, or review composable changes.
- No changes to authentication request timing.
- No behavioral rewrite of review submission/approval modals.
- No unrelated table component refactor beyond what `ReviewQueueTable.vue` needs.
