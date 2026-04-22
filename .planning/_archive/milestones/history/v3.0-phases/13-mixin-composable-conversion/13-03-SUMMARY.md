---
phase: 13-mixin-composable-conversion
plan: "03"
title: "URL Parsing Composable"
subsystem: "utilities"
status: complete
completed: 2026-01-23

# Dependencies
requires:
  - "13-01"  # Foundation composables (barrel export pattern)

provides:
  - "useUrlParsing composable with filter and sort URL utilities"
  - "Bootstrap-Vue-Next compatible sortBy array format"

affects:
  - future: "Components currently using urlParsingMixin (e.g., table components)"

# Technical tracking
tech-stack:
  added: []
  patterns:
    - "Composable pattern for URL parameter parsing"
    - "Bootstrap-Vue-Next array-based sortBy format: [{ key, order }]"

# File tracking
key-files:
  created:
    - path: "app/src/composables/useUrlParsing.js"
      purpose: "URL filter and sort parsing utilities"
  modified:
    - path: "app/src/composables/index.js"
      change: "Added useUrlParsing to barrel export"

# Decision tracking
decisions:
  - id: "13-03-001"
    decision: "Return Bootstrap-Vue-Next array format from sortStringToVariables"
    rationale: "Bootstrap-Vue-Next requires sortBy as array of { key, order } objects"
    impact: "Components using this composable get correct format automatically"
    alternatives: "Could return old format and convert at call site (less DRY)"

# Execution metrics
duration: "2 minutes"
tasks: 2
commits: 1

tags: ["composable", "url-parsing", "filters", "sorting", "utilities"]
---

# Phase 13 Plan 03: URL Parsing Composable Summary

**One-liner:** URL filter/sort parsing composable with Bootstrap-Vue-Next compatible sortBy array format

## What Was Built

Converted `urlParsingMixin` to `useUrlParsing` composable providing three URL parsing utilities:

1. **filterObjToStr** - Converts filter objects to URL query strings
   - Format: `eq(field,value)` or `any(field,val1,val2)`
   - Filters out null/empty values automatically
   - Handles both single values and arrays

2. **filterStrToObj** - Parses URL query strings back to filter objects
   - Reverse of filterObjToStr
   - Merges with standard object for defaults
   - Supports custom split delimiters and join characters

3. **sortStringToVariables** - Parses sort strings to Bootstrap-Vue-Next format
   - Input: `'+entity_id'` or `'-symbol'`
   - Output: `{ sortBy: [{ key: 'entity_id', order: 'asc' }] }`
   - Returns array-based sortBy format required by Bootstrap-Vue-Next tables

## Technical Implementation

### Conversion Strategy

Direct 1:1 conversion from mixin methods to composable functions:
- All three methods maintain exact same signatures
- All logic preserved byte-for-byte
- Comments and implementation details unchanged
- Only wrapper changed from Vue mixin to composable function

### Code Structure

```javascript
export default function useUrlParsing() {
  const filterObjToStr = (filter_object) => { /* ... */ };
  const filterStrToObj = (filter_string, standard_object, ...) => { /* ... */ };
  const sortStringToVariables = (sort_string) => { /* ... */ };

  return { filterObjToStr, filterStrToObj, sortStringToVariables };
}
```

### Bootstrap-Vue-Next Compatibility

The mixin was already updated for Bootstrap-Vue-Next array format in a previous phase. This composable inherits that compatibility:
- Returns `{ sortBy: [{ key: string, order: 'asc'|'desc' }] }`
- Compatible with BTable component's sortBy prop
- Works with deep watchers for reactive table sorting

## Files Changed

### Created
- **app/src/composables/useUrlParsing.js** (151 lines)
  - filterObjToStr method (24 lines)
  - filterStrToObj method (45 lines)
  - sortStringToVariables method (9 lines)
  - JSDoc documentation for all methods

### Modified
- **app/src/composables/index.js**
  - Added useUrlParsing to barrel export
  - Maintains alphabetical grouping by function category

## Testing

### Build Verification
- ✓ Vite build succeeds with no errors
- ✓ All exports resolve correctly
- ✓ No import errors

### Logic Verification

Verified behavior matches original mixin for all test cases:

1. **Empty filter** → returns `''`
2. **Single filter** → `eq(symbol,MECP2)`
3. **Array filter** → `any(category,Disease,Syndrome)`
4. **Sort ascending** → `{ sortBy: [{ key: 'entity_id', order: 'asc' }] }`
5. **Sort descending** → `{ sortBy: [{ key: 'symbol', order: 'desc' }] }`

All code paths verified to be identical to original mixin implementation.

## Migration Path

### Current Usage (Mixin)
```javascript
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';

export default {
  mixins: [urlParsingMixin],
  methods: {
    updateUrl() {
      const filterStr = this.filterObjToStr(this.filters);
    }
  }
}
```

### New Usage (Composable)
```javascript
import { useUrlParsing } from '@/composables';

export default {
  setup() {
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();

    const updateUrl = () => {
      const filterStr = filterObjToStr(filters.value);
    };

    return { updateUrl };
  }
}
```

### Affected Components

The following components use urlParsingMixin and will need migration:
- Table components (Entities, Genes, Phenotypes, Logs tables)
- Any component managing URL query parameters for filtering/sorting
- Search-related components with filter state

**Note:** These migrations will be handled in subsequent Wave 2 plans.

## Decisions Made

### Array-Based sortBy Format
**Decision:** Keep Bootstrap-Vue-Next array format in composable
**Rationale:** Mixin was already updated for Bootstrap-Vue-Next compatibility
**Impact:** No additional conversion needed at call sites
**Trade-off:** Composable is coupled to Bootstrap-Vue-Next format, but that's our UI library

### Exact Logic Preservation
**Decision:** Preserve all logic byte-for-byte from mixin
**Rationale:** URL parsing is complex with many edge cases, don't risk regression
**Impact:** Some legacy patterns remain (substr, nested filters)
**Trade-off:** Could modernize (substring, flatMap) but adds risk for no user benefit

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

### Blockers
None

### Concerns
None

### Recommendations
- Consider adding TypeScript types for filter objects in Phase 14 (TypeScript conversion)
- Could add unit tests for complex filter parsing edge cases
- Some table components may need route/router access pattern guidance

## Success Metrics

- ✓ useUrlParsing composable created with all three methods
- ✓ Function signatures match original mixin exactly
- ✓ sortStringToVariables returns Bootstrap-Vue-Next array format
- ✓ Composable exported from index.js
- ✓ Vite build succeeds with no errors

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| a769676 | feat | Create useUrlParsing composable with filter and sort utilities |

**Total commits:** 1
**Total tasks:** 2 (1 implementation, 1 verification)
**Duration:** 2 minutes
