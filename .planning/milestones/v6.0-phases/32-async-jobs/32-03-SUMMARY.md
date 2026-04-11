# Phase 32 Plan 03: Job History API and UI Summary

**One-liner:** Added GET /api/jobs/history endpoint and job history table in ManageAnnotations.vue with status badges, duration formatting, and error tooltips.

## What Was Built

### Task 1: get_job_history() Function

Added `get_job_history(limit)` function to job-manager.R:

- Returns recent jobs from jobs_env sorted by submitted_at descending
- Calculates duration_seconds (running jobs use current time)
- Extracts error messages from complex error objects
- Handles empty jobs_env and malformed job entries
- Returns data frame with: job_id, operation, status, submitted_at, completed_at, duration_seconds, error_message

### Task 2: Job History API Endpoint

Created `GET /api/jobs/history` endpoint in jobs_endpoints.R:

- Requires Administrator role via `require_role()`
- Accepts optional `limit` query param (default 20, max 100)
- Placed BEFORE catch-all `/<job_id>/status` route
- Returns JSON with `{ data: [...jobs], meta: { count, limit } }`

### Task 3: Job History Table UI

Added Job History section to ManageAnnotations.vue:

- Uses GenericTable component for consistent table styling
- Fetches from `/api/jobs/history` on mount and after job completion
- Custom cell templates for:
  - **operation**: Badge with formatted job type name
  - **status**: Colored badges (green=completed, red=failed, blue=running, light blue=pending)
  - **submitted_at**: Locale datetime format
  - **duration_seconds**: Formatted as "Xm Ys"
  - **error_message**: Truncated to 50 chars with tooltip for full text

## Files Changed

| File | Action | Lines | Purpose |
|------|--------|-------|---------|
| `api/functions/job-manager.R` | Modified | +113 | Add get_job_history() function |
| `api/endpoints/jobs_endpoints.R` | Modified | +52 | Add GET /api/jobs/history endpoint |
| `app/src/views/admin/ManageAnnotations.vue` | Modified | +204 | Add job history table |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| c82be0a | feat | Add get_job_history function to job-manager.R |
| 97e215c | feat | Add GET /api/jobs/history endpoint |
| b736839 | feat | Add job history table to ManageAnnotations.vue |

## Verification Results

- [x] get_job_history() function added to job-manager.R
- [x] GET /api/jobs/history endpoint created
- [x] Endpoint requires Administrator role
- [x] Endpoint returns jobs sorted by submitted_at descending
- [x] Job history table added to ManageAnnotations.vue
- [x] Table uses GenericTable component
- [x] Status column shows colored badges
- [x] Duration column formatted as "Xm Ys"
- [x] Error column truncated with tooltip
- [x] Table refreshes after job completion
- [x] TypeScript check passes

## API Endpoint Details

```r
#* @get /history
# Requires: Administrator role
# Query params: limit (default 20, max 100)
# Response: { data: [...], meta: { count, limit } }
```

Example response:
```json
{
  "data": [
    {
      "job_id": "550e8400-e29b-41d4-a716-446655440000",
      "operation": "ontology_update",
      "status": "completed",
      "submitted_at": "2026-01-25T10:30:00Z",
      "completed_at": "2026-01-25T10:35:00Z",
      "duration_seconds": 300,
      "error_message": null
    }
  ],
  "meta": {
    "count": 1,
    "limit": 20
  }
}
```

## ManageAnnotations.vue Changes

```typescript
// New state
const jobHistory = ref<JobHistoryItem[]>([]);
const jobHistoryLoading = ref(false);

// New fields
const jobHistoryFields = [
  { key: 'operation', label: 'Job Type', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'submitted_at', label: 'Started', sortable: true },
  { key: 'duration_seconds', label: 'Duration', sortable: true },
  { key: 'error_message', label: 'Error', sortable: false },
];

// Fetch on mount and after job completion
onMounted(() => { fetchJobHistory(); });
watch(() => ontologyJob.status.value, () => { fetchJobHistory(); });
watch(() => hgncJob.status.value, () => { fetchJobHistory(); });
```

## Deviations from Plan

None - plan executed exactly as written.

## Next Steps

- Phase 32-04: Final verification and polish (if planned)
- Consider adding job cancellation support in future phase

---

*Completed: 2026-01-26*
*Duration: ~3 minutes*
