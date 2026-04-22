# Phase 58 Plan 01: LLM Infrastructure Setup Summary

**Completed:** 2026-01-31
**Duration:** ~8 minutes

---

## One-liner

Gemini API client using ellmer with structured JSON output and MySQL cache infrastructure for cluster summaries.

---

## What Was Built

### Database Schema (Migration 006)

Created two new tables for LLM summary storage and audit logging:

**llm_cluster_summary_cache:**
- Stores validated cluster summaries with structured JSON
- SHA256 cluster_hash for cache invalidation on composition changes
- is_current flag for versioning (old summaries kept for history)
- validation_status workflow (pending/validated/rejected)
- Multi-valued JSON index on tags for efficient search

**llm_generation_log:**
- Complete audit trail for all generation attempts
- Tracks success, validation_failed, api_error, timeout statuses
- Stores prompt text, response, tokens, latency for debugging
- Enables prompt improvement analysis

### Cache Repository (llm-cache-repository.R)

Repository functions following pubtator-functions.R patterns:

| Function | Purpose |
|----------|---------|
| `generate_cluster_hash()` | SHA256 from sorted gene/entity IDs |
| `get_cached_summary()` | Lookup with validation status awareness |
| `save_summary_to_cache()` | Atomic update (mark old + insert new) |
| `log_generation_attempt()` | Complete audit trail for all attempts |
| `get_generation_history()` | Debug/analyze cluster generation |
| `get_generation_stats()` | Aggregate LLM usage statistics |

### LLM Service (llm-service.R)

Gemini API client using ellmer package:

| Function | Purpose |
|----------|---------|
| `functional_cluster_summary_type` | Type spec for functional clusters |
| `phenotype_cluster_summary_type` | Type spec for phenotype clusters |
| `build_cluster_prompt()` | Construct prompt from cluster data |
| `generate_cluster_summary()` | API call with retry/backoff |
| `get_or_generate_summary()` | Cache-first with generation fallback |
| `is_gemini_configured()` | Check if API key is set |
| `list_gemini_models()` | Available model names |

---

## Key Implementation Details

### Type Specifications

Used ellmer's structured output for guaranteed JSON:
- `type_string()` for prose fields
- `type_array()` for lists (key_themes, pathways, tags)
- `type_enum()` for confidence (high/medium/low)
- `required = FALSE` for optional fields (clinical_relevance, syndrome_hints)

### Rate Limiting

Conservative Gemini API limits:
- 30 RPM capacity (half of Paid Tier 1)
- Exponential backoff with jitter: `2^retries + runif(0,1)`
- Max 3 retries before failure

### Hash-Based Cache Invalidation

When cluster composition changes:
- Functional: `SHA256(sorted(hgnc_ids).join(','))`
- Phenotype: `SHA256(sorted(entity_ids).join(','))`
- Old summaries marked `is_current=FALSE`, not deleted

### Model Configuration

Default model: `gemini-2.0-flash` (fast, cost-effective)
Alternative: `gemini-3-pro-preview` (best quality, preview)

---

## Files Changed

| File | Action | Purpose |
|------|--------|---------|
| `db/migrations/006_add_llm_summary_cache.sql` | Created | LLM cache tables |
| `api/functions/llm-cache-repository.R` | Created | Database cache operations |
| `api/functions/llm-service.R` | Created | Gemini API client |
| `api/renv.lock` | Modified | Added ellmer 0.4.0, coro 1.1.0 |

---

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 95dc5ecf | feat | Database migration for LLM cache tables |
| 2eaff520 | feat | Cache repository functions |
| c6c05db2 | feat | Gemini API client with ellmer |

---

## Deviations from Plan

### [Rule 3 - Blocking] Multi-valued JSON index in stored procedure

**Found during:** Task 1
**Issue:** MySQL does not allow `CAST(...AS...ARRAY)` syntax inside stored procedures
**Fix:** Applied multi-valued index outside the procedure using prepared statements with conditional check
**Files modified:** db/migrations/006_add_llm_summary_cache.sql

### [Adjustment] Changed default model

**Found during:** Task 3
**Issue:** Plan specified `gemini-3-pro-preview` but this is a preview model
**Fix:** Changed default to `gemini-2.0-flash` for production stability, kept preview as alternative
**Files modified:** api/functions/llm-service.R

---

## Verification Results

1. Migration creates tables: PASS
   - Both llm_cluster_summary_cache and llm_generation_log exist
   - All columns and indexes correct
   - idx_tags multi-valued JSON index working

2. R files load without error: PASS
   - llm-service.R sources successfully
   - All dependencies available

3. ellmer in renv.lock: PASS
   - Version 0.4.0 with coro 1.1.0 dependency

4. No hardcoded API keys: PASS
   - GEMINI_API_KEY read from environment variable

---

## Next Phase Readiness

**Ready for Plan 02 (Entity Validation):**
- Type specifications ready for validation layer
- Cache infrastructure operational
- Generation logging captures all attempts for analysis

**Dependencies for Plan 02:**
- Need `non_alt_loci_set` table access for gene symbol validation
- Existing `db_execute_query()` pattern available

**Note:** Entity validation (Plan 02) should validate:
1. Gene symbols in summary text against HGNC database
2. Pathways against provided enrichment terms
3. Reject summaries with invalid entities
