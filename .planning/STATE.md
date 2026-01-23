# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v3 Frontend Modernization — Phase 15 complete, ready for Phase 16

## Current Position

**Milestone:** v3 Frontend Modernization
**Phase:** 16 - UI/UX Modernization (IN PROGRESS)
**Plan:** 8 of ~8 plans complete
**Status:** Phase 16 nearly complete
**Last activity:** 2026-01-23 — Completed 16-08 Accessibility Polish

```
v3 Frontend Modernization: PHASE 16 IN PROGRESS
Completed: Phase 10 (Vue 3 Core), Phase 11 (Bootstrap-Vue-Next), Phase 12 (Vite), Phase 13 (Composables), Phase 14 (TypeScript), Phase 15 (Testing)
Phase 16 progress: Design tokens (16-01), Card styling (16-02), Table styling (16-03), Form styling (16-04), Button styling (16-05), Search UX (16-06), Mobile responsive (16-07), Accessibility (16-08)
Last completed: 16-08 Accessibility Polish
Progress: █████████████████████████████▓ 49/~50 plans in v3 milestone
```

## v3 Milestone Scope

**Goal:** Modernize frontend from Vue 2 + JavaScript to Vue 3 + TypeScript with comprehensive UI/UX improvements.

**Key deliverables (planned):**
- Vue 3 migration with Composition API
- TypeScript adoption across all components
- Bootstrap-Vue-Next component library
- Vite build tooling
- Vitest + Vue Test Utils for testing
- UI modernization (colors, shadows, spacing, loading states)
- WCAG 2.2 accessibility compliance

**Frontend review:** See `.planning/FRONTEND-REVIEW-REPORT.md`

## Completed Milestones

| Milestone | Phases | Shipped | Archive |
|-----------|--------|---------|---------|
| v1 Developer Experience | 1-5 (19 plans) | 2026-01-21 | milestones/v1-* |
| v2 Docker Infrastructure | 6-9 (8 plans) | 2026-01-22 | milestones/v2-* |

## GitHub Issues

| Issue | Description | Status |
|-------|-------------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | Ready for PR |
| #123 | Implement comprehensive testing | Foundation complete, integration tests deferred |

## Tech Debt (from v1/v2 audits)

- lint-app crashes (esm module compatibility) — will be resolved by Vite migration
- 1240 lintr issues in R codebase
- renv.lock incomplete (Dockerfile workarounds)
- No HTTP endpoint integration tests

## Key Decisions

See PROJECT.md for full decisions table.

**v3 decisions made:**
- Bootstrap-Vue-Next over PrimeVue (minimize visual disruption)
- Include UI/UX polish in v3 (not separate milestone)
- Include Vitest testing infrastructure
- Quality over speed approach
- Used --legacy-peer-deps for Vue 3 migration (third-party libraries expect Vue 2)
- Disabled BootstrapVueLoader during Vue 3 migration (requires vue-template-compiler)
- @vue/compat MODE 2 for maximum compatibility during migration
- Changed routes import from require() to ES import for Vue 3 consistency
- Added ESLint exceptions for Pinia store patterns (named exports, counter increment)
- No additional array watchers need deep: true (existing configuration correct)
- Counter pattern for Pinia watcher triggering (more reliable than boolean toggle)
- UI store for cross-cutting concerns (scrollbar, future: loading states, toasts)
- Upgraded Bootstrap 4.6.2 to 5.3.8 for Bootstrap-Vue-Next compatibility
- Keep both Bootstrap-Vue and Bootstrap-Vue-Next CSS during transition
- Fixed esm package incompatibility with Node.js 18+ in vue.config.js
- Added babel-loader cache path to /tmp to avoid permission issues
- toastMixin delegates to useToastNotifications for backward compatibility
- Error toasts (danger variant) force manual close for medical app reliability
- Composables use default exports for ESLint compliance
- Array-based sortBy format for Bootstrap-Vue-Next tables: [{ key, order }]
- Deep watchers for sortBy instead of separate sortDesc watcher
- sortDesc as computed getter/setter for backward compatibility
- Bootstrap 5 RTL-first utility class naming: ms-*/me-* for margin, ps-*/pe-* for padding
- text-start/text-end for alignment, float-start/float-end for positioning
- @unhead/vue for meta management (replaces vue-meta)
- vee-validate 4 Composition API with useForm/useField (replaces vee-validate 3)
- @r2rka/vue3-treeselect for hierarchical selection (replaces @riophae/vue-treeselect)
- Native scrollbars instead of vue2-perfect-scrollbar
- @upsetjs/bundle for set visualization (replaces @upsetjs/vue)
- @vitejs/plugin-vue@6.0.3 required for Vite 7 support (5.x only supports Vite 5-6)
- SCSS uses @use syntax with modern-compiler API for Vite compatibility
- Dual build system during migration: npm run dev (Vite) vs npm run serve (Vue CLI)
- Vite entry point: index.html in app root (not public/) with module script
- Removed webpack magic comments - Vite handles chunk splitting automatically
- Environment variables: VITE_* prefix, import.meta.env access pattern
- Development port: 5173 (Vite default) instead of 8080 (Vue CLI default)
- Production mode detection: import.meta.env.PROD instead of process.env.NODE_ENV
- Node 24 LTS for Docker images (Vite 7 compatibility)
- Port 5173 for Vite dev server in Docker (differentiates from webpack 8080)
- Reduced memory limits for Vite Docker (2GB vs 4GB for webpack)
- Stateless composables return plain objects (no reactive/ref for constant mappings)
- Barrel export pattern for composables (composables/index.js)
- Convert stateless mixins first (no external dependencies, constant data)
- useToast differs from useToastNotifications: danger toasts never auto-hide (medical app requirement)
- Components with existing setup() functions extended rather than replaced
- Medical app error handling pattern: critical errors force manual user acknowledgment
- useTableData creates fresh state per call (per-instance pattern for independent tables)
- useTableMethods uses dependency injection (accepts tableData and options parameters)
- Dependency injection pattern for composables requiring external component state
- Fix circular dependencies by importing composables directly instead of from barrel
- Reorder functions to avoid use-before-define ESLint errors
- Remove duplicate filtered() methods when components already have implementations
- Extend existing setup() functions in view components rather than replacing
- TypeScript relaxed strict mode (strict: false) for gradual migration
- Single tsconfig.json approach (no project references) for simplicity
- allowJs: true enables .js/.ts coexistence during incremental migration
- Separate type imports: import type { ... } from 'vue'
- Type assertions (as any) acceptable for incomplete third-party types (e.g., Vite SCSS options)
- Pinia setup syntax preferred over Options API for better TypeScript inference
- Export store types (e.g., UIStoreType) for component usage
- Explicit return types for composables improve type inference and IDE support
- Class-based API service with singleton export for backward compatibility
- Type-only imports for AxiosResponse to satisfy verbatimModuleSyntax
- Module augmentation for RouteMeta instead of global type extension
- Route params handled as string | string[] with Array.isArray checks
- Const assertions ('as const') for literal type inference in constants
- 'satisfies' operator validates types while preserving literal types
- Export type aliases alongside default exports (XConfig = typeof X pattern)
- Type assertion ('as unknown as') acceptable for branded type constants
- ESLint 9 flat config format for modern linting infrastructure
- TypeScript/Vue rules set to 'warn' during migration (not 'error')
- Prettier for code formatting, eslint-config-prettier disables conflicts
- vue-eslint-parser required for eslint-plugin-vue@10.x compatibility
- Husky 9 pre-commit hooks with lint-staged for automated code quality
- --max-warnings=50 during TypeScript migration allows commits while fixing warnings
- Separate lint-staged rules: TS/Vue get ESLint+Prettier, other files Prettier only
- Type assertion (as Component) for Bootstrap-Vue-Next component registration (BFormDatalist generic slot types)
- Environment variables contain base URL only, code adds /api/ prefix for consistency
- ColorAndSymbols interface uses Record<string | number, string> for flexible style mappings
- FilterField interface defines content as string | string[] | null for flexible filtering
- TableDataState exported as type for component usage (dependency injection pattern)
- ScrollbarControls types scrollRef as Ref<{ update: () => void }> | null for optional usage
- MSW onUnhandledRequest: 'warn' logs unmocked endpoints instead of failing tests
- MSW generic fallback handler returns 500 for unmocked /api/* requests
- MSW handlers reset after each test via server.resetHandlers() in afterEach
- AnyComponent type alias for Vue Test Utils generic constraints (DefineComponent<any, any, any>)
- withSetup returns [result!, app] tuple for composable lifecycle testing
- Barrel export in test-utils/index.ts re-exports common testing utilities
- Stateless composables tested directly without Vue context (no withSetup needed)
- Pure function composables tested with comprehensive edge cases and round-trips
- vi.mock must precede import for external dependency mocking (module hoisting)
- app.unmount() required after each withSetup test for cleanup
- vitest-axe/matchers import pattern for expect.extend() in accessibility tests
- Type assertion (as unknown as) for vitest-axe matcher TypeScript compatibility
- Disable axe region rule for isolated component tests (not within page landmarks)
- Disable axe blink rule for Vue compat stub rendering issues
- *.a11y.spec.ts naming convention for accessibility test files
- shallowMount with explicit stubs for Bootstrap-Vue-Next component isolation in tests
- Test component methods directly when DOM interaction unreliable with stubs
- vi.mock for constants decouples tests from actual constant values
- CSS custom properties over SCSS variables for runtime flexibility and theming
- SCSS variables ($text-main, $primary) kept for component backward compatibility
- Medical blue (#0d47a1) as primary brand color with subtle shadows
- Colorblind-safe status colors for medical context (WCAG 2.2 AAA compliance)
- Compact spacing scale (0.5rem base) for dense data tables
- Transition tokens with prefers-reduced-motion for accessibility (NFR-03.6)
- Form focus states: colored border (medical-blue-500) + glow using design tokens
- Validation feedback: inline below field using status-danger/success colors
- Required fields: red asterisk with aria-label for accessibility
- Disabled inputs: not-allowed cursor with reduced opacity for clear indication
- Table zebra striping: 2% opacity for subtle visual distinction without overwhelming data
- Table row hover: 5% medical blue for tracking across wide tables
- Sort indicators: CSS triangles (pseudo-elements) instead of icon fonts for performance
- Active sort column: 8% background + font-weight 600 for clear visual feedback
- Compact table variant (.table-compact) with tighter padding for genes/entities tables
- Sortable headers styled via aria-sort attribute for semantic accessibility
- Card hover elevation only for .card-interactive class (not all cards)
- Compact card body variant (.card-body-compact) for data-heavy views
- SCSS namespace aliases to avoid module name collisions (spacing-utilities)
- Tighter mobile padding in .container-compact for maximum content area
- Keyboard focus indicators on interactive cards for WCAG 2.2 compliance
- Clear button uses Bootstrap Icon (bi-x-circle-fill) for consistency with existing UI
- Clear button only visible when input has value (conditional rendering)
- Loading state replaces clear button position to avoid layout shift
- Focus returns to input after clear for better keyboard navigation
- Instant feedback uses subtle border color change (medical-blue-500)
- Search component pattern: container with relative positioning, clear button absolute
- Conditional UI elements based on state (clearable, loading, has value)
- Shimmer animation using CSS gradient with background-position animation
- prefers-reduced-motion media query disables animation for accessibility (WCAG 2.2)
- EmptyState uses Bootstrap Icons (bi-) without 'bi-' prefix in prop
- ColorVariant PropType for type-safe button variants
- Global registration via defineAsyncComponent for performance
- UI component directory structure: app/src/components/ui/
- Loading states use skeleton-shimmer class from _loading.scss
- Empty states follow icon + title + message + optional action pattern
- Accessibility: aria-label and role=status on loading components
- Enhanced Bootstrap-Vue-Next stacked tables with card styling (shadows, borders, padding)
- 44x44px minimum touch targets throughout for WCAG 2.2 compliance
- Full-width search and filters on mobile with vertical stacking
- Flexbox layout for label-value pairs in stacked table cells
- Comprehensive breakpoint coverage from 320px (small phones) to 1024px+ (desktop)
- Mobile card transformation: Each table row becomes visually distinct card
- Data label pattern: ::before pseudo-element with attr(data-label) shows column headers
- Focus-visible pattern: Use :focus-visible selector for keyboard-only focus indicators
- Skip link pattern: Positioned off-screen, visible on focus for screen reader navigation
- High contrast mode: @media (prefers-contrast: more) increases border widths to 2px
- Text-muted uses neutral-600 (#757575) for verified 4.54:1 contrast ratio
- Links in prose content underlined; UI links distinguishable by context

## Archive Location

- v1 artifacts: `.planning/milestones/v1-*`
- v2 artifacts: `.planning/milestones/v2-*`

## Session Continuity

**Last session:** 2026-01-23
**Stopped at:** Completed 16-08 Accessibility Polish
**Resume file:** None

---
*Last updated: 2026-01-23 — Phase 16 in progress, 16-08 complete (WCAG 2.2 AA accessibility with focus-visible, color contrast, high contrast mode)*
