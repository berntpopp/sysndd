# Phase 32 Plan 02: HGNC Async Endpoint + ManageAnnotations Refactor Summary

**One-liner:** Added HGNC async job endpoint and refactored ManageAnnotations.vue to use useAsyncJob composable for both ontology and HGNC updates with progress UI.

## What Was Built

### Task 1: HGNC Async Job Endpoint

Created `POST /api/jobs/hgnc_update/submit` endpoint in jobs_endpoints.R following the established async job pattern:

- Requires Administrator role via `require_role()`
- Checks for duplicate running jobs via `check_duplicate_job()`
- Returns HTTP 202 Accepted with `job_id` and `status_url`
- Uses `estimated_seconds = 120` and `Retry-After = 10` (faster than ontology)
- Calls `update_process_hgnc_data()` in mirai daemon

### Task 2: ManageAnnotations.vue Refactor

Converted ManageAnnotations.vue from Options API to Composition API with `<script setup>`:

1. **Composable Integration**: Two `useAsyncJob` instances for ontology and HGNC jobs
2. **Removed Manual Polling**: Eliminated `setInterval`/`clearInterval` and manual timer code
3. **HGNC Progress UI**: Added identical progress display to ontology section
4. **Watch-Based Completion**: Uses Vue `watch()` to detect job completion/failure and show toast

### Key Changes

| Aspect | Before | After |
|--------|--------|-------|
| API Style | Options API (`data`, `computed`, `methods`) | Composition API (`<script setup>`) |
| Job Polling | Manual `setInterval`/`clearInterval` | `useAsyncJob` composable |
| HGNC Update | Synchronous `/api/admin/update_hgnc_data` | Async `/api/jobs/hgnc_update/submit` |
| Progress UI | Ontology only | Both ontology and HGNC |
| Error Messages | Generic "Job failed" | Specific error from `job.error.value` |

## Files Changed

| File | Action | Lines | Purpose |
|------|--------|-------|---------|
| `api/endpoints/jobs_endpoints.R` | Modified | +70 | Add HGNC async job endpoint |
| `app/src/views/admin/ManageAnnotations.vue` | Modified | -37 net | Refactor to use useAsyncJob |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| f295ed2 | feat | Add HGNC async job submission endpoint |
| ba056c4 | feat | Refactor ManageAnnotations.vue to use useAsyncJob |

## Verification Results

- [x] POST /api/jobs/hgnc_update/submit endpoint created
- [x] Endpoint requires Administrator role
- [x] Endpoint returns 202 Accepted with job_id
- [x] ManageAnnotations.vue imports and uses useAsyncJob
- [x] HGNC section has progress bar with elapsed time
- [x] HGNC card header shows "Last: YYYY-MM-DD" badge
- [x] No manual setInterval/clearInterval in ManageAnnotations.vue
- [x] Both ontology and HGNC jobs show specific error messages on failure
- [x] TypeScript check passes

## API Endpoint Details

```r
#* @post /hgnc_update/submit
# Requires: Administrator role
# Duplicate check: "hgnc_update" operation
# Returns: 202 Accepted
# Response: { job_id, status, estimated_seconds, status_url }
# Retry-After: 10 seconds
# Estimated: 120 seconds (~2 minutes)
```

## ManageAnnotations.vue Structure

```typescript
// Two job instances
const ontologyJob = useAsyncJob((jobId) => `${API_URL}/api/jobs/${jobId}/status`);
const hgncJob = useAsyncJob((jobId) => `${API_URL}/api/jobs/${jobId}/status`);

// Watchers for completion/failure
watch(() => ontologyJob.status.value, (status) => { ... });
watch(() => hgncJob.status.value, (status) => { ... });

// Submit handlers
async function updateOntologyAnnotations() { ontologyJob.startJob(response.data.job_id); }
async function updateHgncData() { hgncJob.startJob(response.data.job_id); }
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed TypeScript errors in template**
- **Found during:** Task 2
- **Issue:** `align="left"` attribute not valid for BCard, variant type casting needed
- **Fix:** Replaced `align="left"` with `class="text-start"`, cast variant props
- **Files modified:** ManageAnnotations.vue

## Next Steps

- Phase 32-03: Job queue enhancements (if planned)
- Phase 32-04: Verify all async jobs work end-to-end

---

*Completed: 2026-01-26*
*Duration: ~5 minutes*
