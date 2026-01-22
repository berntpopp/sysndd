# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-22)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v3 Frontend Modernization — Bootstrap-Vue-Next migration in progress

## Current Position

**Milestone:** v3 Frontend Modernization
**Phase:** 11 - Bootstrap-Vue-Next Migration
**Plan:** 11-05 CSS Class Updates (complete)
**Status:** Wave 3 complete
**Last activity:** 2026-01-23 — Bootstrap 4 utility classes migrated to Bootstrap 5 equivalents

```
v3 Frontend Modernization: PHASE 11 IN PROGRESS
Completed: 10-01 through 10-05, 11-01 Foundation, 11-02 Modal/Toast, 11-03 Tables, 11-04 Forms, 11-05 CSS
Wave 2: 11-02 (complete), 11-03 (complete), 11-04 (complete)
Wave 3: 11-05 (complete)
Progress: ██████████░ 11/16 plans (69%)
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

## Archive Location

- v1 artifacts: `.planning/milestones/v1-*`
- v2 artifacts: `.planning/milestones/v2-*`

## Session Continuity

**Last session:** 2026-01-23T14:48:00Z
**Stopped at:** Completed 11-05-PLAN.md — CSS class updates to Bootstrap 5 equivalents
**Resume file:** None

---
*Last updated: 2026-01-23 — Phase 11 in progress (5/6 plans complete)*
