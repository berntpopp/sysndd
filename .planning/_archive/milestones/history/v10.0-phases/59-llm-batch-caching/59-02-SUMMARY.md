# Phase 59 Plan 02: LLM-as-judge Validation Pipeline Summary

**One-liner:** Three-tier LLM-as-judge validation (accept/low_confidence/reject) integrated into batch pipeline with automatic verdict-to-status mapping and metadata storage.

---

## Plan Metadata

**Phase:** 59-llm-batch-caching
**Plan:** 02
**Type:** execute
**Status:** ✅ Complete
**Completed:** 2026-01-31

---

## Objectives Achieved

Implemented LLM-09 (LLM-as-judge validates accuracy) and LLM-10 (confidence scoring with metadata) from requirements.

✅ Created `api/functions/llm-judge.R` with three-tier validation system
✅ Integrated judge into `llm-batch-generator.R` batch executor
✅ Added `update_validation_status()` to `llm-cache-repository.R` for manual admin overrides
✅ Created comprehensive unit tests (13 test cases covering all judge functions)

---

## What Was Built

### Core Deliverables

1. **api/functions/llm-judge.R** (386 lines)
   - `llm_judge_verdict_type`: Type specification with three-tier verdict enum (accept/low_confidence/reject)
   - `validate_with_llm_judge()`: Evaluates summary accuracy and grounding using Gemini
   - `generate_and_validate_with_judge()`: Full pipeline: generate → entity validate → judge → cache
   - Graceful error handling: returns low_confidence verdict if judge fails
   - Stores judge verdict and reasoning in summary metadata

2. **api/functions/llm-batch-generator.R** (modified)
   - Replaced `generate_cluster_summary()` call with `generate_and_validate_with_judge()`
   - Added source loading for `llm-judge.R` module
   - Updated success tracking based on judge verdict
   - Logs validation_status and judge verdict for each cluster
   - Simplified caching flow (judge function handles cache save)

3. **api/functions/llm-cache-repository.R** (modified)
   - Added `update_validation_status()` function for manual admin validation overrides
   - Validates status input (pending/validated/rejected)
   - Updates validated_at timestamp and validated_by user

4. **api/tests/testthat/test-llm-judge.R** (280 lines, 13 test cases)
   - Tests for `llm_judge_verdict_type` structure
   - Tests for `validate_with_llm_judge()` with NULL inputs and valid data
   - Tests for `generate_and_validate_with_judge()` verdict mapping
   - Tests for `update_validation_status()` input validation
   - End-to-end integration test for full pipeline
   - Skip helpers for Gemini API and database requirements

---

## Technical Implementation

### Three-Tier Verdict System

**Verdict → Validation Status Mapping:**
- `accept` → `validated` (high confidence, cache for immediate use)
- `low_confidence` → `pending` (cache but flag for review)
- `reject` → `rejected` (trigger regeneration, up to 3 retries)

### Judge Validation Criteria

LLM-as-judge evaluates summaries on four criteria:

1. **is_factually_accurate**: Summary accurately describes biological function
2. **is_grounded**: All claims supported by enrichment data
3. **pathways_valid**: Listed pathways match enrichment input (no hallucinations)
4. **confidence_appropriate**: Self-assessed confidence matches evidence strength

### Pipeline Flow

```
1. generate_cluster_summary() → entity validation (existing)
2. validate_with_llm_judge() → judge verdict
3. Map verdict to validation_status
4. Add judge metadata to summary:
   - llm_judge_verdict
   - llm_judge_reasoning
   - derived_confidence
5. save_summary_to_cache() with validation_status
6. Return success = FALSE for rejected summaries (triggers retry)
```

### Error Handling

- **Judge API failure**: Returns `low_confidence` verdict with error reason
- **NULL summary**: Returns `reject` verdict
- **NULL cluster_data**: Returns `low_confidence` verdict
- **Generation failure**: Returns `rejected` status without judge call

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Use same model for judging as generation | Consistency in evaluation approach | All judgments use gemini-2.0-flash by default |
| Graceful degradation on judge failure | Prefer usability over perfection | Failed judge → low_confidence (pending) instead of hard error |
| Judge function handles caching | Simplify batch executor logic | Reduced duplicate cache save logic in batch executor |
| Store judge metadata in summary JSON | Enable judge calibration analysis | llm_judge_verdict and llm_judge_reasoning available for debugging |

---

## Files Changed

### Created
- `api/functions/llm-judge.R` (386 lines)
- `api/tests/testthat/test-llm-judge.R` (280 lines)

### Modified
- `api/functions/llm-batch-generator.R` (+7 lines, -28 lines)
- `api/functions/llm-cache-repository.R` (+45 lines)

**Total:** 2 new files, 2 modified files

---

## Integration Points

### Upstream Dependencies
- `api/functions/llm-service.R`: `generate_cluster_summary()`, `calculate_derived_confidence()`, `is_gemini_configured()`
- `api/functions/llm-cache-repository.R`: `save_summary_to_cache()`, `generate_cluster_hash()`
- `api/functions/llm-validation.R`: Entity validation (integrated into `generate_cluster_summary()`)

### Downstream Consumers
- `api/functions/llm-batch-generator.R`: `llm_batch_executor()` calls `generate_and_validate_with_judge()`
- Future admin endpoints: `update_validation_status()` for manual review workflows

---

## Testing Coverage

**13 test cases:**
- Type specification structure validation (2 tests)
- NULL input handling (2 tests)
- Valid verdict structure and enum values (2 tests)
- Generation failure handling (1 test)
- Verdict-to-status mapping validation (1 test)
- Judge result presence (1 test)
- Manual status update validation (3 tests)
- End-to-end integration test (1 test)

**Skip conditions:**
- Tests requiring Gemini API skip if `GEMINI_API_KEY` not set
- Tests requiring database skip if DB helpers not loaded

---

## Success Criteria Met

✅ `validate_with_llm_judge()` calls Gemini with judge prompt and returns structured verdict
✅ `generate_and_validate_with_judge()` chains generation → entity validation → judge validation → cache
✅ Three-tier verdict (accept/low_confidence/reject) maps to validation_status (validated/pending/rejected)
✅ Judge verdict and reasoning stored in summary metadata (llm_judge_verdict, llm_judge_reasoning)
✅ Rejected summaries return success=FALSE to trigger retry in batch executor
✅ Low_confidence summaries are cached but flagged (validation_status = pending)
✅ Unit tests cover key scenarios including error handling

---

## Performance Notes

**Execution time:** ~3.25 minutes (195 seconds)

**Judge overhead per cluster:**
- Additional LLM call: ~1-3 seconds
- Negligible cache save overhead (status field update)

**Retry impact:**
- Rejected summaries retry up to 3 times
- Expected rejection rate: <5% (well-grounded enrichment data)

---

## Next Phase Readiness

### Provides for Phase 59-03 (Batch Progress UI)
- ✅ Validation status available for display (`validated`, `pending`, `rejected`)
- ✅ Judge verdict and reasoning available for admin review UI
- ✅ Batch executor logs validation outcomes for progress tracking

### Provides for Phase 59-04 (Admin Validation Dashboard)
- ✅ `update_validation_status()` ready for manual review workflows
- ✅ Judge metadata (verdict, reasoning) stored for calibration analysis
- ✅ Derived confidence available for confidence comparison studies

### Known Limitations
- Judge uses same prompt as generation (may have consistent blind spots)
- No judge calibration metrics yet (accuracy of judge vs human reviewers)
- Manual validation still required for `pending` summaries

---

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 9a0745c2 | feat | Create LLM-as-judge validation module |
| 12e5e7a9 | feat | Integrate LLM-as-judge into batch generator |
| fd0663e0 | test | Add unit tests for LLM-as-judge module |

---

## Metadata

**Dependencies:**
```yaml
requires:
  - 58-llm-foundation (LLM service, cache repository)
  - 59-01 (batch generation orchestrator)

provides:
  - LLM-as-judge validation with three-tier verdicts
  - Validation status tracking (validated/pending/rejected)
  - Judge metadata storage for calibration
  - Manual validation override function

affects:
  - 59-03 (needs validation status for UI)
  - 59-04 (needs manual validation workflow)
```

**Tech Stack:**
```yaml
added:
  - ellmer::type_enum for three-tier verdict

patterns:
  - LLM-as-judge validation pattern
  - Graceful degradation on judge failure
  - Verdict-to-status mapping
```

**Key Files:**
```yaml
created:
  - api/functions/llm-judge.R
  - api/tests/testthat/test-llm-judge.R

modified:
  - api/functions/llm-batch-generator.R
  - api/functions/llm-cache-repository.R
```

**Tags:** llm, validation, gemini, batch-processing, quality-assurance, api

**Subsystem:** llm-generation
