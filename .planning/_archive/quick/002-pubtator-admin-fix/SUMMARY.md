# Quick Task 002: PubTator Admin API Serialization Fix

**Date:** 2026-02-01
**Status:** Complete
**Discovered during:** Phase 64 LLM Admin Dashboard testing

---

## Problem

The PubTator admin page (`/ManagePubtator`) was completely non-functional with JavaScript errors:

1. **Check Status button crashed:**
   ```
   TypeError: Cannot read properties of undefined (reading '0')
   at ManagePubtator.vue:367
   ```

2. **Submit Fetch Job button crashed:**
   ```
   TypeError: $setup.jobId.substring is not a function
   at ManagePubtator.vue:689
   ```

## Root Cause

R/plumber's default JSON serialization wraps single values in arrays:

**API returned:**
```json
{
  "job_id": ["40925354-3cf5-4450-9a90-309b2229bf42"],
  "status": ["accepted"],
  "cached": [false]
}
```

**Expected:**
```json
{
  "job_id": "40925354-3cf5-4450-9a90-309b2229bf42",
  "status": "accepted",
  "cached": false
}
```

The frontend code was inconsistent:
- Some places expected scalars (`jobId.substring(0, 8)`)
- Some places expected arrays (`lastStatus.cached[0]`)

## Solution

### 1. API Fixes (added `auto_unbox=TRUE`)

**File:** `api/endpoints/publication_endpoints.R`
```r
# Changed from:
#* @serializer json list(na="string")

# Changed to:
#* @serializer json list(na="string", auto_unbox=TRUE)
```

**Endpoints fixed:**
| Line | Endpoint |
|------|----------|
| 712 | `/pubtator/backfill-genes` |
| 787 | `/pubtator/cache-status` |
| 873 | `/pubtator/update` |
| 1007 | `/pubtator/update/submit` |
| 1141 | `/pubtator/clear-cache` |

**File:** `api/endpoints/jobs_endpoints.R`
| Line | Endpoint |
|------|----------|
| 934 | `/<job_id>/status` |

### 2. Frontend Fixes (removed array accesses)

**File:** `app/src/views/admin/ManagePubtator.vue`

Changed all `lastStatus.property[0]` to `lastStatus.property`:
- Lines 66-67, 72, 75, 77-79, 87, 91, 95, 98, 104, 167
- Lines 390, 394, 395, 408 (script section)

Added type check for cache_date:
```vue
<!-- Before -->
<dt v-if="lastStatus.cache_date">Last Updated:</dt>

<!-- After -->
<dt v-if="lastStatus.cache_date && typeof lastStatus.cache_date === 'string'">Last Updated:</dt>
```

**File:** `app/src/composables/usePubtatorAdmin.ts`

```typescript
// Before
const cached = lastStatus.value.pages_cached[0] || 0;
const total = lastStatus.value.total_pages_available[0] || 1;

// After
const cached = lastStatus.value.pages_cached || 0;
const total = lastStatus.value.total_pages_available || 1;
```

**File:** `app/src/views/admin/ManageAnnotations.vue`

The `fetchPubtatorStats()` function was also affected - the paginated endpoints return `meta` as an array:

```typescript
// Before
const geneCount = genesResponse.data?.meta?.totalItems ?? null;

// After (handle array-wrapped meta from R/plumber)
const geneMeta = Array.isArray(genesResponse.data?.meta)
  ? genesResponse.data.meta[0]
  : genesResponse.data?.meta;
const geneCount = geneMeta?.totalItems ?? null;
```

Fixed 3 similar meta accesses for gene_count, publication_count, and novel_count.

## Verification

Tested with Playwright browser automation:

| Feature | Status | Evidence |
|---------|--------|----------|
| Check Status | ✅ Pass | Shows cache status for MECP2 (1107 pages available) |
| Submit Fetch Job | ✅ Pass | Job `47b77f22...` completed in 9s |
| Job Progress | ✅ Pass | Progress bar shows 2/3 pages |
| Cache Updated | ✅ Pass | 20 publications cached for MECP2 |
| Clear Cache | ✅ Pass | Confirmation dialog works |
| Backfill Gene Symbols | ✅ Pass | Button enabled when cache exists |
| Console Errors | ✅ None | No JavaScript errors |
| ManageAnnotations Stats | ✅ Pass | Shows 580 publications, 180 genes, 180 literature only |

**Screenshots:**
- `.playwright-mcp/pubtator-admin-fully-working.png`
- `.playwright-mcp/manage-annotations-pubtator-stats-fixed.png`

## Files Changed

```
api/endpoints/publication_endpoints.R    (5 serializer annotations)
api/endpoints/jobs_endpoints.R           (1 serializer annotation)
app/src/views/admin/ManagePubtator.vue   (17 array access removals)
app/src/composables/usePubtatorAdmin.ts  (2 array access removals)
app/src/views/admin/ManageAnnotations.vue (3 meta array unwraps)
```

## Commit Message

```
fix(pubtator): resolve admin page crashes from API serialization

- Add auto_unbox=TRUE to 6 API endpoints for proper JSON scalars
- Remove [0] array accesses in ManagePubtator.vue and usePubtatorAdmin.ts
- Add type check for cache_date to prevent "Invalid Date" display
- Fix ManageAnnotations fetchPubtatorStats to unwrap meta array

Closes: BUG-0 from LLM_ADMIN_TESTING_REPORT.md
```

---

*Completed: 2026-02-01*
