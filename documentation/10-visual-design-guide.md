# SysNDD Visual Guide

Date: 2026-05-14

Scope: recent curation/admin design refactor plus reference public table/home surfaces

Evidence: fresh Playwright review against `http://localhost:5173`

## Visual Positioning

SysNDD should feel like a clinical research operations tool: compact, trustworthy, table-first, and quiet. The product should avoid marketing-style decoration, oversized cards, and expressive gradients. The strongest current direction is already visible in the home page, public tables, authenticated page shell, `TableShell`, and curation review surfaces.

Use the interface to help expert users scan, compare, and act. Do not make them read decorative explanations before they can use the data.

## Current Reference Surfaces

Use these routes as the current visual baseline when reviewing design changes:

- Home: `/`
- Public table: `/Entities?sort=%2Bentity_id&page_size=10`
- Gene table: `/Genes?sort=%2Bsymbol&page_size=10`
- Wizard: `/CreateEntity`
- Review operations: `/ApproveReview` and `/ManageReReview`
- Mobile records: `/ManageOntology` and `/ManageUser`
- CMS/admin debt example: `/ManageAbout`

Generated screenshot captures belong under `.planning/screenshots/` and are intentionally ignored when they are PNG files.

## Design Tokens

### Color

Primary brand/action blue:

- `--medical-blue-700: #0d47a1`
- `--medical-blue-600: #1e88e5`
- Use for primary navigation, focused active state, primary links, and selected pagination.

Secondary operational accent:

- `--medical-teal-600: #00897b`
- Use sparingly for secondary positive actions and system accents.

Status colors:

- Success: `--status-success: #2e7d32`
- Warning: `--status-warning: #f57c00`
- Danger: `--status-danger: #c62828`
- Info: `--status-info: #0277bd`

Neutral foundation:

- Text: `--neutral-900: #212121`
- Secondary text: `--neutral-600: #757575`
- Surface backgrounds: white and near-white neutrals
- Borders: pale neutral/blue-gray lines with low visual weight
- Canonical surface border token: `--border-subtle: #d9e0ea` (the app-wide low-weight panel/card border used by the home page, public tables, and the user/analyses/curation surfaces). Use this token for card and panel borders; never use a heavy dark Bootstrap card border (`border-variant="dark"` / `.border-dark`). On a Bootstrap `BCard`, add the `.border-subtle` utility class instead of a dark variant.

Rules:

- Do not create a one-hue blue-only screen. Use blue for action and navigation, green/teal for biological identifiers or positive state, amber/red only for status.
- Never rely on color alone for status. Pair color with icons, labels, or both.
- Avoid dark cards and heavy bordered Bootstrap panels in admin/curation pages.

### Typography

Base stack: system sans (`-apple-system`, `Segoe UI`, Roboto, Arial).

Identifier stack: `--font-family-mono` for IDs, gene symbols, protein names, and compact scientific values.

Recommended scale:

- Page title: 18-22px, semibold, compact line height.
- Section title: 16-18px, semibold.
- Table headers and control labels: 12-14px, semibold.
- Body/table text: 14-16px.
- Helper/meta text: 12-14px.

Rules:

- Keep headings tight inside operational tools. Hero-scale type belongs only on true public-facing hero areas.
- Gene names and stable identifiers should be scannable, preferably using existing badge/mono conventions.
- Avoid negative letter spacing. It weakens dense table readability.

### Shape And Density

Radius:

- Default cards/panels: `--radius-md` to `--radius-lg` (`6-8px`).
- Pills/chips: `--radius-full`.
- Avoid `12-16px` cards for normal operational surfaces.

Spacing:

- Dense table controls: 8px gaps.
- Default form groups: 12px.
- Section spacing: 24-32px.
- Mobile row internal spacing: 8-12px.

Rules:

- Prefer one bounded surface per task area.
- Do not put UI cards inside other UI cards unless the inner card is a repeated data record.
- A page can be dense, but it must maintain stable alignment and clear grouping.

## Layout System

### Public Data Pages

Use public table pages as the table reference:

- Single table shell.
- Compact header with entity count and loaded count.
- Search and pagination in predictable rows.
- Filters directly above columns.
- Data chips for identifiers and classification.
- Actions aligned at the far right.

Do:

- Keep table controls close to the data they affect.
- Preserve column alignment and stable pagination width.
- Use compact badges for category, NDD state, inheritance, and identifiers.

Do not:

- Hide core table controls in distant page headers.
- Use large descriptive cards where a tight toolbar is enough.
- Let badges become visually heavier than the data itself.

### Authenticated Operation Pages

Use `AuthenticatedPageShell` for curation/admin routes.

Required structure:

1. Shell title and one-line description.
2. Optional KPI/stat row.
3. Primary operation or table surface.
4. Secondary tools in collapsed or lower-priority panels.
5. Footer-safe scroll area.

Rules:

- Exactly one route-level `h1`.
- Shell actions belong in the header when they affect the whole page.
- Dangerous actions should be visually separated from routine actions.
- Avoid duplicated route titles inside child cards.

### Tables

Use `TableShell` or match it closely.

Desktop:

- Toolbar first, table second.
- Column filters sit immediately above column headers.
- Row actions form a stable icon/action cluster.
- Empty, loading, and error states occupy the table body, not a separate detached card.

Mobile:

- Replace stacked Bootstrap table output with purpose-built record rows.
- Each row should have a primary identity line, secondary detail line, chip row, and action cluster.
- Keep row actions fixed in placement across records.

## Component Patterns

### Page Shell

Good pattern:

- White surface
- Thin border
- Compact header
- Subtle shadow
- Footer-safe bottom spacing

Avoid:

- Full-page stacks of unrelated cards
- Duplicate headings
- Heavy black/dark borders
- Centered narrow admin tools on desktop when the workflow is table-driven

### Wizard

The Create Entity wizard is a good baseline:

- Horizontal desktop stepper
- Short labels
- One focused step body
- Primary next action at bottom-right
- Toggle-style binary input for NDD phenotype

Improve next:

- On mobile, ensure step navigation does not become a cramped horizontal strip.
- Make required/optional field rhythm consistent across all steps.
- Keep review/submit summary visually closer to table/detail page conventions.

### Chips And Badges

Use chips for:

- Entity IDs
- Gene symbols
- Disease names
- Inheritance mode
- Category/classification
- Review/user/status labels

Rules:

- Chips should be compact, readable, and semantically colored.
- Avoid mixing several unrelated chip styles on one row.
- Use icons only where they improve recognition. Icon-only controls need accessible labels/tooltips.

### Forms

Forms should be dense but not cryptic.

Rules:

- Labels above controls for normal forms.
- Inline controls only when the relationship is obvious and the row remains scannable.
- Primary action belongs at the end of the flow.
- Secondary actions should be outline/neutral.
- Destructive actions should be red outline or danger-confirmed, not placed next to primary success actions without separation.

## Findings From Fresh Review

Playwright audit:

- 30 authenticated design checks passed across desktop and mobile.
- Fresh screenshots captured for 13 representative routes at `1440x900` and `390x844`.
- No captured route had document or main horizontal overflow.
- Authenticated routes consistently used the authenticated shell in the tested design spec.

Measured remaining debt:

| Surface | Evidence | Recommendation |
|---|---|---|
| `ManageOntology` mobile | `5183px` captured main scroll height | Keep compact rows, but reduce toolbar vertical stack and compress pagination/filter controls. |
| `ManageUser` mobile | `4400px` captured main scroll height | Move quick filters and pagination into denser segmented/filter rows; keep user rows compact. |
| `AdminStatistics` mobile | `3764px` captured main scroll height | Convert date controls and chart mode toggles into a tighter responsive control bar. |
| `ManageReReview` | `68` visible buttons on desktop capture | Reduce simultaneous action exposure; progressive disclosure is correct, but action density remains high. |
| `ManageAbout` | `16` card elements and nested publication sections | Convert to a true CMS layout: section list plus editor/preview pane, not repeated collapsible cards. |
| `ManageLLM` | `14` card elements | Keep dashboard intent but flatten nested card chrome. |

## Design Priorities

1. Finish converging admin/curation pages on the shell/table language.
2. Reduce mobile control stacks before reducing data density.
3. Replace nested card stacks with task-specific layouts.
4. Standardize action hierarchy: primary, secondary, icon utility, danger.
5. Keep public data pages stable; they are currently the best visual anchor.

## Practical Acceptance Checklist

For every new or changed page:

- Has one route-level `h1`.
- Uses `AuthenticatedPageShell` when authenticated.
- Uses `TableShell` or matching structure for data tables.
- Has no horizontal overflow at `1440x900` or `390x844`.
- Has visible interactive content above the fixed footer at the bottom of scroll.
- Has mobile-specific record rows for complex tables.
- Uses no nested cards except repeated record rows or true disclosure panels.
- Keeps cards at `8px` radius or less.
- Uses existing token colors rather than new one-off palette values.
- Has icon-only controls labelled for assistive tech.

## Route Guidance

### Keep As Reference

- `/`
- `/Entities`
- `/Genes`
- `/CreateEntity`
- `/ApproveReview`

### Improve Next

- `/ManageAbout`: rebuild as CMS editor layout.
- `/ManageOntology`: compress mobile controls.
- `/ManageUser`: compress mobile controls and quick filters.
- `/ManageReReview`: reduce visible action count and continue guided batch-builder work.
- `/AdminStatistics`: tighten mobile date/filter/chart controls.
- `/ManageLLM`: flatten dashboard card nesting.

## Verification Commands

Use these for visual/design safety:

```bash
cd app && PLAYWRIGHT_BASE_URL=http://localhost:5173 npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts --project=chromium-desktop
```

Use these before handoff:

```bash
make lint-app
cd app && npm run type-check
cd app && npm run type-check:strict
cd app && npm run test:unit
```

For full local parity:

```bash
make ci-local
```
