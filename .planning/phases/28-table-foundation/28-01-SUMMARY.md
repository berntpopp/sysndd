---
phase: 28-table-foundation
plan: 01
subsystem: api
tags: [plumber, pagination, filtering, sorting, R, dplyr, rlang]

# Dependency graph
requires:
  - phase: v4-backend
    provides: API endpoint structure, pagination helpers, filter/sort utilities
provides:
  - Server-side pagination for user and ontology table endpoints
  - Filter/sort query parameters for both endpoints
  - Field specification (fspec) metadata for dynamic table columns
affects: [28-02, 28-03, admin-panel-frontend]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Server-side filtering using generate_filter_expressions helper
    - Server-side sorting using generate_sort_expressions helper
    - Field specification metadata pattern for table columns
    - Execution time tracking in API responses

key-files:
  created: []
  modified:
    - api/endpoints/user_endpoints.R
    - api/endpoints/ontology_endpoints.R

key-decisions:
  - "Use existing generate_filter_expressions and generate_sort_expressions helpers for consistency"
  - "Follow entity_endpoints.R pattern for filter/sort/pagination implementation"
  - "Include fspec metadata in API response for frontend dynamic table generation"
  - "Preserve role-based access control (Admin sees all, Curator sees unapproved)"

patterns-established:
  - "Table endpoint pattern: filter, sort, page_after, page_size, fspec parameters"
  - "Response format: { links, meta: [{ totalItems, fspec, executionTime }], data }"
  - "Filter before pagination, sort after filter, paginate last"

# Metrics
duration: 3.5min
completed: 2026-01-25
---

# Phase 28 Plan 01: Table Foundation Summary

**Server-side pagination, filtering, and sorting added to user and ontology table API endpoints with fspec metadata for dynamic column generation**

## Performance

- **Duration:** 3.5 min
- **Started:** 2026-01-25T19:29:47Z
- **Completed:** 2026-01-25T19:33:18Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- User table endpoint supports filter, sort, page_after, page_size, and fspec parameters
- Ontology variant table endpoint supports filter, sort, page_after, page_size, and fspec parameters
- Both endpoints return consistent { data, meta, links } response format matching entity endpoint pattern
- Field specification metadata enables frontend to dynamically build table columns
- Execution time tracking added to all responses
- Role-based access control preserved (Admin sees all users, Curator sees only unapproved)

## Task Commits

All tasks were committed together as they form a cohesive feature:

1. **Tasks 1-3: Table endpoint enhancements** - `ea38b4b` (feat)
   - Task 1: Enhanced user table endpoint with filter and sort support
   - Task 2: Added pagination and filter support to ontology variant table endpoint
   - Task 3: Added fspec parameter for column selection to both endpoints

## Files Created/Modified
- `api/endpoints/user_endpoints.R` - Added filter, sort, fspec parameters; server-side filtering/sorting; execution time tracking
- `api/endpoints/ontology_endpoints.R` - Added filter, sort, fspec parameters; server-side filtering/sorting; execution time tracking

## Decisions Made

**1. Followed entity_endpoints.R pattern exactly**
- Rationale: entity_endpoints.R already implements the proven pattern for filter/sort/pagination. Reusing the same helper functions (generate_filter_expressions, generate_sort_expressions, generate_cursor_pag_inf_safe) ensures consistency and reduces maintenance burden.

**2. Added execution time tracking**
- Rationale: Matches entity endpoint pattern and provides performance visibility for API consumers.

**3. Implemented fspec metadata for both endpoints**
- Rationale: Enables frontend to dynamically generate table columns without hardcoding field definitions. Matches the TablesEntities pattern from the frontend research.

**4. Preserved role-based filtering**
- Rationale: Admin users see all users, Curator users see only unapproved users. Applied filter AFTER role-based filtering to maintain security constraints while allowing additional user-provided filters.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - implementation followed existing patterns from entity_endpoints.R successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for frontend implementation:**
- User table API endpoint ready at `/api/user/table` with filter/sort/pagination support
- Ontology table API endpoint ready at `/api/ontology/variant/table` with filter/sort/pagination support
- Both endpoints return fspec metadata for dynamic column generation
- Response format matches TablesEntities pattern from research

**API response format:**
```json
{
  "links": {
    "prev": "...",
    "next": "...",
    "first": "...",
    "last": "..."
  },
  "meta": [{
    "totalItems": 42,
    "currentPage": 1,
    "totalPages": 5,
    "prevItemID": 0,
    "currentItemID": 10,
    "nextItemID": 20,
    "lastItemID": 50,
    "fspec": [
      { "key": "user_name", "label": "Username", "sortable": true, "filterable": true, "class": "text-start" },
      ...
    ],
    "executionTime": "0.02 secs"
  }],
  "data": [
    { "user_id": 1, "user_name": "john", ... },
    ...
  ]
}
```

**Filter examples:**
- `filter=user_name:contains:john` - Search by username
- `filter=user_role:equals:Administrator` - Filter by role
- `filter=approved:equals:1` - Show only approved users

**Sort examples:**
- `sort=+user_name` - Sort ascending by username
- `sort=-created_at` - Sort descending by creation date

**No blockers or concerns.**

---
*Phase: 28-table-foundation*
*Completed: 2026-01-25*
