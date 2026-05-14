# Table Modernization Hybrid Responsive Design Spec

## Context

The shared data-table experience is functionally strong, but the current Bootstrap stacked mobile behavior makes the primary data views too tall and hard to scan. The target pages are:

- `/CurationComparisons/Table`
- `/Entities?sort=%2Bentity_id&page_size=10`
- `/Genes?sort=%2Bsymbol&page_after=0&page_size=10`
- `/Panels/All/All`

These views must stay compatible with the existing Vue 3, TypeScript, Bootstrap Vue Next stack. API behavior, SWR composables, cache store behavior, and request timing must not change.

## Current Evidence

Playwright review at 390 px width showed no horizontal overflow, but severe vertical expansion:

- Curation comparison table: about 3553 px table height for one page of rows.
- Entities table: about 3106 px table height.
- Genes table: about 2326 px table height.
- Panels table: about 2757 px table height.

Lighthouse mobile results also showed weak perceived performance and accessibility issues:

- Comparison table: accessibility issues from unnamed help controls.
- Genes table: contrast issue on the details button.
- Panels table: high CLS and unnamed help controls.
- All pages include large unused JavaScript warnings linked to development source maps and likely eager `exceljs` loading through the composable barrel.

## Problem

`BTable stacked="md"` converts each row into a vertical label/value mini-table. This preserves all data, but it makes scan paths long and duplicates labels on every record. The result is especially costly for entity, gene, panel, and curation-comparison rows where users need to compare many compact records.

The page shells also differ visually:

- `GenericTable.vue` users get one table treatment.
- `TablesGenes.vue` and `PanelsTable.vue` render direct `BTable` implementations.
- Header, toolbar, loading, and mobile behavior are inconsistent.

## Goals

1. Keep full desktop table functionality and density.
2. Replace mobile stacked tables on the target pages with compact, purpose-built mobile record rows.
3. Introduce a shared table shell for title, count, actions, toolbar, loader, table, and mobile-list regions.
4. Preserve search, filters, pagination, download/copy actions, row details, and existing navigation.
5. Improve accessibility for table controls and help buttons.
6. Reduce visible layout shift and improve loader quality.
7. Avoid eager `exceljs` loading before export actions.

## Non-Goals

- Do not change API endpoints, response contracts, SWR composables, cache store behavior, or request timing.
- Do not redesign the reused table data model.
- Do not remove existing desktop table columns.
- Do not replace Bootstrap Vue Next.
- Do not introduce a virtualized table dependency in this iteration.

## Design Direction

Use a hybrid responsive table pattern.

Desktop and tablet:

- Keep real tables for comparison, sorting, filtering, copying, and scanning.
- Use a shared modern shell around the table.
- Use denser, aligned controls with predictable wrapping.
- Use sticky headers where the containing table supports it without breaking layout.

Mobile:

- Hide the full data table below the `md` breakpoint on the target pages.
- Render compact record rows instead of Bootstrap stacked mini-tables.
- Put the main identifier on the first line.
- Put the most important chips/status values on the first or second line.
- Collapse secondary fields behind an explicit details toggle.
- Keep search/filter/pagination controls available above or below the list.

## Component Architecture

Create focused shared components under `app/src/components/table/`:

- `TableShell.vue`: shared visual frame for table-like pages.
- `TableLoadingState.vue`: consistent skeleton loader for tables and mobile rows.
- `MobileTableList.vue`: shared wrapper for mobile record rows with empty and loading states.

Create page-specific mobile row components so each data domain stays readable:

- `CurationComparisonMobileRows.vue`
- `EntitiesMobileRows.vue`
- `GenesMobileRows.vue`
- `PanelsMobileRows.vue`

Update `GenericTable.vue` to support disabling Bootstrap stacked mode. This keeps existing users compatible while allowing target pages to opt into the hybrid pattern.

## Page-Specific Requirements

### Curation Comparisons Table

Desktop:

- Keep source columns and source status cells.
- Use the new shell title, description, metadata, and actions.
- Fix help button accessible names.

Mobile:

- One row per gene or comparison record.
- First line: gene symbol or primary comparison label.
- Second line: compact source status strip.
- Expand area: source names, source values, and notes.

### Entities

Desktop:

- Preserve `GenericTable`, filters, search, pagination, details links, and export/copy actions.
- Use the new shell and loader.

Mobile:

- First line: entity identifier and gene.
- Second line: disease and inheritance.
- Chip row: category, NDD status, classification/status where available.
- Expand area: remaining columns and details link.

### Genes

Desktop:

- Preserve row expansion and existing sort behavior.
- Use the new shell and loader.
- Fix details button contrast.

Mobile:

- First line: gene badge and entity count.
- Second line: canonical gene name or aliases where available.
- Chip row: inheritance, category, NDD status.
- Expand area: comments, identifiers, and the existing details action.

### Panels

Desktop:

- Preserve column selection, category filter, inheritance filter, sorting, pagination, and download.
- Use the new shell and loader.
- Fix help button accessible names and label associations.

Mobile:

- First line: symbol and category.
- Second line: disease or panel label.
- Chip row: inheritance and selected identifiers.
- Expand area: selected optional columns.

## Performance Requirements

- Initial page load must not eagerly import `exceljs` before an export action.
- Skeletons should reserve stable table/list space during initial loading.
- Mobile rows should reduce average rendered row height from the current 225-348 px range to a target of 110-155 px before expansion.
- No horizontal overflow at 390, 768, 1024, 1366, or 1440 px.

## Accessibility Requirements

- Help controls must have accessible names.
- Icon-only controls must expose `aria-label` or visually hidden text.
- Mobile detail toggles must expose expanded state with `aria-expanded`.
- Desktop table semantics must remain intact.
- Color alone must not be the only source status indicator.

## Verification

Required local checks after implementation:

```bash
cd app && npm run format:check
make lint-app
cd app && npm run type-check
cd app && npm run test:unit
make pre-commit
```

Required local UI checks, when the stack is available:

```bash
make playwright-stack
cd app && npx playwright test tests/e2e/tables-responsive.spec.ts
cd .. && make playwright-stack-down
```

Manual Playwright review must capture 390, 768, 1024, 1366, and 1440 px screenshots for all four target routes.

Lighthouse should be rerun for the four target routes in mobile and desktop mode. Expected result is not a perfect score in local dev, but there should be no new accessibility failures, no horizontal overflow, reduced mobile table height, and lower CLS on Panels.
