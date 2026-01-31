---
phase: 59
plan: 01
subsystem: llm
tags: [batch-generation, job-chaining, cache, mirai, async]

requires:
  - 58-01  # LLM Infrastructure Setup (llm-service, llm-cache-repository)
  - 58-02  # Entity Validation Pipeline (llm-validation)

provides:
  - Batch LLM generation orchestrator (llm-batch-generator.R)
  - Job chaining from clustering completion
  - Cache-first cluster processing
  - Per-cluster progress reporting
  - Graceful batch failure handling

affects:
  - 59-02  # LLM validation integration (will use batch-generated summaries)
  - 60-01  # LLM display (will display batch-generated summaries)

tech-stack:
  added:
    - None (uses existing ellmer, mirai, logger)
  patterns:
    - Batch processing with cache-first lookup
    - Job chaining via promise callbacks
    - Retry logic with exponential backoff and jitter

key-files:
  created:
    - api/functions/llm-batch-generator.R
    - api/tests/testthat/test-llm-batch.R
  modified:
    - api/functions/job-manager.R

decisions:
  - decision: "Graceful failure for individual clusters"
    rationale: "Failed clusters should not stop entire batch - log and continue"
    impact: "Batch completes even with some failures"
    date: 2026-01-31

  - decision: "Job chaining in promise callback (main process)"
    rationale: "Clustering completes in daemon, promise callback fires in main process where create_job() is safe"
    impact: "Clean separation - no mirai-in-mirai issues"
    date: 2026-01-31

  - decision: "Cache-first lookup for each cluster"
    rationale: "Avoid regenerating summaries when cluster composition hasn't changed"
    impact: "Fast re-runs, cost savings on API calls"
    date: 2026-01-31

metrics:
  duration: "3.3 minutes"
  completed: 2026-01-31
---

# Phase 59 Plan 01: Batch LLM Generation Orchestrator Summary

**One-liner:** Batch LLM generation with cache-first lookup, automatic chaining after clustering, and graceful per-cluster failure handling.

## What Was Built

Created batch orchestrator that automatically triggers LLM summary generation after clustering jobs complete. Processes clusters sequentially with cache-first lookup, retry logic, and progress reporting.

### Core Components

**1. api/functions/llm-batch-generator.R (333 lines)**
- `trigger_llm_batch_generation()`: Entry point for job chaining
  - Checks `is_gemini_configured()` before proceeding
  - Creates async job with `operation="llm_generation"`
  - 1-hour timeout for large batches
- `llm_batch_executor()`: Batch processing logic
  - Cache-first lookup via `get_cached_summary()`
  - Retry with exponential backoff: `2^attempt + runif(1, 0, 1)` seconds
  - Per-cluster progress: "Cluster N (X/Y)"
  - Graceful failure: failed clusters logged but don't stop batch

**2. api/functions/job-manager.R (modified)**
- Conditional source of llm-batch-generator.R
- Job chaining in promise callback (after clustering completion):
  - Detects `clustering` and `phenotype_clustering` operations
  - Extracts clusters from result
  - Determines cluster type (functional/phenotype)
  - Calls `trigger_llm_batch_generation()`
- Added `llm_generation` progress message

**3. api/tests/testthat/test-llm-batch.R (258 lines, 6 tests)**
- Test trigger with missing API key (returns `skipped=TRUE`)
- Test trigger with valid cluster structure
- Test executor with empty cluster list
- Test executor returns correct summary structure
- Test cache-skip behavior (mock cache hit)
- Test graceful hash generation failure handling

## Technical Implementation

### Job Chaining Flow

```
Clustering Job
    ↓
Mirai Daemon: Execute clustering
    ↓
Return result to main process
    ↓
Promise callback fires (main process)
    ↓
Extract clusters from result
    ↓
trigger_llm_batch_generation()
    ↓
Create new mirai job (llm_generation)
    ↓
Mirai Daemon: llm_batch_executor()
    ↓
For each cluster:
  - Check cache (hash-based)
  - If cache hit: skip
  - If cache miss: generate (with retry)
  - Update progress
    ↓
Return summary (total, succeeded, failed, skipped)
```

### Cache-First Processing

Each cluster:
1. Build `cluster_data` structure (identifiers + term_enrichment)
2. Generate `cluster_hash` via `generate_cluster_hash()`
3. Check cache via `get_cached_summary(cluster_hash)`
4. **Cache hit:** Increment `skipped`, continue to next cluster
5. **Cache miss:** Attempt generation (up to 3 retries)
6. On success: Save to cache via `save_summary_to_cache()`
7. On failure: Log warning, increment `failed`, continue

### Retry Logic

```r
max_retries <- 3
while (attempt < max_retries && !generation_success) {
  attempt <- attempt + 1

  if (attempt > 1) {
    backoff_time <- (2^attempt) + runif(1, 0, 1)
    Sys.sleep(backoff_time)
  }

  result <- generate_cluster_summary(cluster_data, cluster_type)

  if (result$success) {
    save_summary_to_cache(...)
    generation_success <- TRUE
  }
}
```

Backoff times:
- Attempt 2: ~4-5 seconds
- Attempt 3: ~8-9 seconds

### Progress Reporting

Uses file-based progress via `create_progress_reporter()`:

```r
reporter(
  step = "generation",
  message = sprintf("Cluster %d (%d/%d)", cluster_number, i, total),
  current = i,
  total = total
)
```

Frontend can poll `/jobs/{job_id}` to show:
- Current cluster being processed
- Progress bar (X/Y clusters)
- Final summary on completion

## Deviations from Plan

None - plan executed exactly as written.

## Testing Coverage

**Unit Tests (6 test cases):**
1. API key check (skips when not set)
2. Valid cluster structure acceptance
3. Empty cluster list handling
4. Correct summary structure
5. Cache-skip behavior
6. Hash generation failure handling

**Test patterns:**
- Mock functions to avoid side effects (DB, API calls)
- Skip helpers: `skip_if_no_gemini()`, `skip_if_no_db()`
- Verify counters: `total`, `succeeded`, `failed`, `skipped`

**Integration Testing (Manual):**
- Run clustering job
- Verify LLM generation job auto-triggers
- Check cache hits on re-run
- Verify graceful failure (invalid cluster data)

## Success Criteria Met

- [x] `trigger_llm_batch_generation()` creates LLM generation job when called
- [x] `llm_batch_executor()` processes clusters with cache-first, retry, progress
- [x] Clustering job completion automatically triggers LLM generation
- [x] Per-cluster progress format: "Cluster N (X/Y)"
- [x] Failed clusters logged but don't stop batch
- [x] Unit tests cover key scenarios and edge cases

## Must-Haves Verification

**Truths:**
- ✅ Clustering job completion triggers LLM summary generation automatically
- ✅ LLM generation processes each cluster with cache-first lookup
- ✅ Per-cluster progress visible during batch generation
- ✅ Failed clusters do not stop the entire batch
- ✅ Cached clusters are skipped (not regenerated)

**Artifacts:**
- ✅ api/functions/llm-batch-generator.R exports both required functions
- ✅ api/functions/job-manager.R contains `trigger_llm_batch_generation` call
- ✅ api/functions/job-manager.R has `llm_generation` operation message
- ✅ api/tests/testthat/test-llm-batch.R has 258 lines (>50 minimum)

**Key Links:**
- ✅ job-manager.R → llm-batch-generator.R via `trigger_llm_batch_generation` call
- ✅ llm-batch-generator.R → llm-service.R via `generate_cluster_summary` call
- ✅ llm-batch-generator.R → llm-cache-repository.R via cache functions

## Integration Points

**Upstream Dependencies:**
- `llm-service.R`: `generate_cluster_summary()`, `is_gemini_configured()`
- `llm-cache-repository.R`: `get_cached_summary()`, `save_summary_to_cache()`, `generate_cluster_hash()`
- `job-manager.R`: `create_job()`, promise callback infrastructure
- `job-progress.R`: `create_progress_reporter()`

**Downstream Consumers:**
- Phase 59-02: Batch validation (will validate batch-generated summaries)
- Phase 60-01: Display summaries (will fetch from cache)
- Phase 60-02: Admin approval UI (will show batch generation history)

## Performance Characteristics

**Expected Performance (100 clusters):**
- Cache hit rate: ~80% on re-runs (only new/changed clusters regenerated)
- Per-cluster generation: ~2-3 seconds (Gemini API latency)
- Batch time (cold cache): ~200-300 seconds (~5 minutes)
- Batch time (warm cache): ~40-60 seconds (~1 minute, 20% cache miss)

**Cost Optimization:**
- Cache-first avoids redundant API calls
- Hash-based invalidation (only regenerate when cluster composition changes)
- Graceful failure (don't waste retries on permanently broken clusters)

## Next Phase Readiness

**Ready for Phase 59-02 (Batch Validation):**
- ✅ Batch generation creates summaries in cache
- ✅ Summaries have `validation_status = 'pending'`
- ✅ Generation log tracks all attempts

**Ready for Phase 60-01 (Display Summaries):**
- ✅ Summaries stored in `llm_cluster_summary_cache` table
- ✅ Cache lookup by cluster_hash
- ✅ Tags available for filtering

**Blockers/Concerns:**
- None

## Commits

| Hash | Message |
|------|---------|
| 4dc2d712 | feat(59-01): create LLM batch generator module |
| 1c62ead3 | feat(59-01): add job chaining for LLM generation |
| 120dba69 | test(59-01): add unit tests for LLM batch generator |

**Total commits:** 3
**Files changed:** 3 created, 1 modified
**Lines added:** ~629
**Duration:** 3.3 minutes
