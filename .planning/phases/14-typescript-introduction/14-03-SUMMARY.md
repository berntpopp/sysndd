---
phase: 14-typescript-introduction
plan: 03
subsystem: constants
tags: [typescript, const-assertions, satisfies, type-safety]

# Dependency graph
requires:
  - phase: 14-01
    provides: TypeScript infrastructure (tsconfig, vue-tsc, typed env vars)
  - phase: 14-02
    provides: Core type definitions (@/types models, API, components)
provides:
  - Type-safe constant files with const assertions
  - NavMenuItem, NavDropdown, FooterLink type exports
  - UrlConfig, RoleConfig, MainNavConfig, FooterNavConfig type aliases
  - Type imports from @/types in constant files
affects: [14-04-router, 14-05-stores, components-using-constants]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Const assertions with 'as const' for literal type inference"
    - "'satisfies' operator for type validation while preserving literals"
    - "Type aliases exported alongside default exports"
    - "Type assertion 'as unknown as' for branded type constants"

key-files:
  created: []
  modified:
    - app/src/assets/js/constants/url_constants.ts
    - app/src/assets/js/constants/role_constants.ts
    - app/src/assets/js/constants/init_obj_constants.ts
    - app/src/assets/js/constants/main_nav_constants.ts
    - app/src/assets/js/constants/footer_nav_constants.ts

key-decisions:
  - "Use 'satisfies' for type validation while preserving literal types"
  - "Export type aliases for each constant configuration"
  - "Use 'as unknown as' for NEWS_INIT to bypass branded type requirements"
  - "Import types from @/types barrel export for consistency"

patterns-established:
  - "Const assertion pattern: 'const X = {...} as const'"
  - "Satisfies pattern: 'array] satisfies Type[]' for validation"
  - "Type export pattern: 'export type XConfig = typeof X'"
  - "Interface definitions for complex navigation structures"

# Metrics
duration: 5min
completed: 2026-01-23
---

# Phase 14 Plan 03: Constants Conversion Summary

**All 5 constant files converted to TypeScript with const assertions, satisfies validation, and exported type aliases**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-23T11:52:39Z
- **Completed:** 2026-01-23T11:57:35Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Converted all constant files (.js → .ts) in app/src/assets/js/constants/
- Added type safety with const assertions and satisfies operator
- Integrated with @/types for UserRole, NavigationSection, and entity models
- Created interface definitions for navigation structures
- Zero remaining JavaScript files in constants directory

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert URL and role constants** - `1d396cf` (feat)
   - url_constants.ts with UrlConfig type
   - role_constants.ts with RoleConfig type, imports from @/types

2. **Task 2: Convert init_obj_constants** - `25bf9d5` (feat)
   - init_obj_constants.ts with StatisticsInit interface
   - Type imports: StatisticsMeta, CategoryStat, NewsItem

3. **Task 3: Convert navigation constants** - `6f7c5c8` (feat)
   - main_nav_constants.ts with NavMenuItem/NavDropdown interfaces
   - footer_nav_constants.ts with FooterLink interface

4. **Fix: Branded type assertion for NEWS_INIT** - `54a4e43` (fix)
   - Changed from 'satisfies' to 'as unknown as' for branded types

## Files Created/Modified

### Modified
- `app/src/assets/js/constants/url_constants.ts` - URL configuration with as const assertion
- `app/src/assets/js/constants/role_constants.ts` - User role and navigation permission mapping
- `app/src/assets/js/constants/init_obj_constants.ts` - Initial state for statistics and news
- `app/src/assets/js/constants/main_nav_constants.ts` - Navigation dropdown configuration
- `app/src/assets/js/constants/footer_nav_constants.ts` - Footer link configuration with logos

## Decisions Made

**1. Use 'satisfies' operator for type validation**
- Rationale: TypeScript 4.9+ feature that validates types while preserving literal inference
- Better than type annotations which widen types
- Example: `ALLOWED_ROLES: [...] as const satisfies readonly UserRole[]`

**2. Export type aliases alongside default exports**
- Pattern: `export type XConfig = typeof X`
- Enables consumers to reference constant types
- Example: `UrlConfig`, `RoleConfig`, `MainNavConfig`

**3. Use 'as unknown as' for branded type constants**
- Issue: NewsItem extends Entity which uses branded types (EntityId, GeneId)
- Branded types require factory functions for creation
- Solution: Type assertion acceptable for initialization constants
- Maintains type safety at usage sites while allowing constant definition

**4. Import from @/types barrel export**
- All type imports use `from '@/types'` for consistency
- Leverages centralized type export established in plan 14-02
- Avoids direct imports from individual type files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed branded type compatibility for NEWS_INIT**
- **Found during:** Task 2 (TypeScript compilation)
- **Issue:** `satisfies NewsItem[]` failed because NewsItem uses branded types (EntityId, GeneId, HpoTermId, DiseaseId) that require factory functions for creation
- **Fix:** Changed to `as unknown as NewsItem[]` type assertion for initialization data
- **Files modified:** app/src/assets/js/constants/init_obj_constants.ts
- **Verification:** TypeScript compilation passes with no errors in constants/
- **Committed in:** `54a4e43` (separate fix commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Type assertion is standard practice for initialization constants with branded types. No scope creep.

## Issues Encountered

None - all conversions completed smoothly after branded type fix.

## Verification Results

✓ All 5 constant files converted to TypeScript (.ts extension)
✓ No JavaScript (.js) files remain in constants directory
✓ Type imports from @/types working correctly
✓ Const assertions present in all files
✓ TypeScript compilation passes (0 errors in constants/)
✓ App compiles with 55 pre-existing errors (none in constants/)

## Next Phase Readiness

**Ready for phase 14-04 (Router conversion):**
- Constants now provide type exports for route configuration
- NavDropdown interface available for navigation typing
- UserRole types from @/types can be used in route guards

**Ready for phase 14-05 (Store conversion):**
- Type-safe constants available for store initialization
- INIT_OBJECTS provides typed initial state structures
- Role constants provide type-safe permission checking

**No blockers or concerns.**

---
*Phase: 14-typescript-introduction*
*Completed: 2026-01-23*
