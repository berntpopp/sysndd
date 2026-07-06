---
name: sysndd-frontend-integration
description: Use when wiring a SysNDD Vue 3 view or component to the backend API, adding a typed API client, handling API errors, or binding backend data into BootstrapVueNext tables and tooltips — especially around Plumber response shapes and BVN table/tooltip quirks
---

# SysNDD Frontend Integration Boundaries

Use this skill when connecting the frontend to the API or binding backend data into the UI. These are the boundary rules and BootstrapVueNext (BVN) quirks that repeatedly bite. For visual/layout work, use `sysndd-visual-design` instead.

## API Access Goes Through Typed Clients

All backend access goes through the typed clients in `app/src/api/*` (`client.ts` is the shared base). **Do not** add raw `axios` calls in views/components, and **do not** read `localStorage.token` / `localStorage.user` directly. Add or extend a typed client method (with its `.spec.ts`) instead.

## Plumber Response Shapes

- **JSON scalars come back as arrays.** Plumber serializes a scalar as `["abc"]`. Unwrap with `unwrapValue` before feeding a value back into `axios` params — otherwise axios encodes `param[]=value`, which Plumber won't match (e.g. an async `job_id`).
- **Errors are RFC 9457 problem+json.** Read them via `extractApiErrorMessage(err, fallback)` (`app/src/utils/api-errors.ts`, which prefers `detail` → `title`). Don't hand-parse error response shapes.

## BootstrapVueNext Table & Tooltip Traps

- **Dotted field keys render blank.** BVN `BTable` (and the `GenericTable` wrapper) cannot display a field whose `key` contains a dot: the cell resolver renders blank, and a `#cell-a.b` slot parses as `cell-a` + `.b` modifier. Alias dotted source columns (e.g. MCA stats `p.value`, `v.test`) to flat keys (`p_value`, `v_test`) before binding them as field keys — see `normalizePhenotypeClusterRows()` in `app/src/components/analyses/phenotypeClusterTable.ts`. Keep the original dotted keys on the row if the Excel export header map still reads them.
- **`v-b-tooltip` is reactive to its binding *value*, not a bound `:title`.** For a tooltip whose text changes (e.g. faceted "filtered/total" counts), bind through the directive value — `v-b-tooltip.hover.bottom="getTooltipText(field)"` — never `:title="getTooltipText(field)"` (that patches `data-original-title` but never re-renders the popover). Static `:title` tooltips whose text never changes are fine. Guard: `app/src/components/tables/columnHeaderTooltipReactivity.spec.ts`.

## Performance

Importing composables from the `@/composables` barrel drags `ngl`/`markdown`/`d3` (~600 KB) onto a route's critical path. On perf-sensitive routes, import composables by their **direct path**, not the barrel.

## Verify

```bash
cd app && npm run type-check          # (+ npm run type-check:strict for touched scope)
cd app && npm run test:unit           # or: npx vitest run <spec> / -t "<name>"
make lint-app                         # ESLint + MSW↔OpenAPI drift check
```
