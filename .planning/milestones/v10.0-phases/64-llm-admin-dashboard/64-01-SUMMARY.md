---
phase: 64-llm-admin-dashboard
plan: 01
subsystem: api
tags: [llm, admin, api, cache, logging]

dependency-graph:
  requires:
    - 59-llm-batch: LLM batch generator and cache schema
    - 63-llm-pipeline: LLM pipeline fixes
  provides:
    - LLM admin API endpoints at /api/llm/*
    - Cache management (stats, list, clear)
    - Generation log viewing
    - Manual validation capability
    - Prompt template viewing
  affects:
    - 64-02: Frontend will consume these endpoints

tech-stack:
  added: []
  patterns:
    - Admin-only endpoints via require_role()
    - Paginated list responses
    - Async job triggering via trigger_llm_batch_generation()

key-files:
  created:
    - api/endpoints/llm_admin_endpoints.R
  modified:
    - api/functions/llm-cache-repository.R
    - api/start_sysndd_api.R

decisions:
  - id: D-64-01-01
    decision: Use session-only model changes
    rationale: Sys.setenv() is sufficient; no need for DB persistence
    impact: Model changes reset on API restart

  - id: D-64-01-02
    decision: Prompt templates are read-only (code-defined)
    rationale: No llm_prompt_templates table exists yet
    impact: PUT /prompts/:type logs but doesn't persist

  - id: D-64-01-03
    decision: Cost estimation uses Gemini 2.0 Flash pricing
    rationale: $0.075/1M input + $0.30/1M output is standard pricing
    impact: Cost estimates may need adjustment for other models

metrics:
  duration: ~4 minutes
  completed: 2026-02-01
---

# Phase 64 Plan 01: LLM Admin Backend API Summary

REST API endpoints at /api/llm/* enabling admin dashboard to manage LLM config, cache, logs, and prompts.

## Changes Made

### Task 1: Admin Query Functions (fe72b1c6)

Extended `api/functions/llm-cache-repository.R` with 4 new functions:

| Function | Purpose |
|----------|---------|
| `get_cache_statistics()` | Aggregate stats for dashboard (totals, by status/type, tokens, cost) |
| `get_cached_summaries_paginated()` | Paginated cache browser with cluster_type and status filters |
| `clear_llm_cache()` | Delete cache entries by type with transaction safety |
| `get_generation_logs_paginated()` | Paginated log viewer with date range filters |

Cost calculation uses Gemini 2.0 Flash pricing:
- Input: $0.075 per 1M tokens
- Output: $0.30 per 1M tokens

### Task 2: LLM Admin Endpoints (bd4d391d)

Created `api/endpoints/llm_admin_endpoints.R` with 10 endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/config` | GET | Get model configuration and API status |
| `/config` | PUT | Change active model (session-only) |
| `/cache/stats` | GET | Get aggregate cache statistics |
| `/cache/summaries` | GET | Paginated cache browser with filters |
| `/cache` | DELETE | Clear cache entries by type |
| `/regenerate` | POST | Trigger batch LLM regeneration job |
| `/logs` | GET | Paginated generation logs with filters |
| `/cache/:id/validate` | POST | Manual validation/rejection of summaries |
| `/prompts` | GET | Get all 4 prompt templates |
| `/prompts/:type` | PUT | Update template (placeholder for future) |

All endpoints require `Administrator` role via `require_role()`.

### Task 3: Router Mount (bfefd621)

Updated `api/start_sysndd_api.R`:
- Added `pr_mount("/api/llm", pr("endpoints/llm_admin_endpoints.R"))`
- Fixed lintr line length issue in cache repository

## Verification Results

| Criterion | Status |
|-----------|--------|
| 4 new cache repository functions exist | PASS |
| 10 endpoints in llm_admin_endpoints.R | PASS |
| /api/llm mount in start_sysndd_api.R | PASS |
| No lines > 120 characters | PASS |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| fe72b1c6 | feat | Add admin query functions to llm-cache-repository |
| bd4d391d | feat | Create LLM admin endpoints (10 endpoints) |
| bfefd621 | feat | Mount LLM admin router at /api/llm |

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

Plan 64-02 (Frontend Dashboard) can proceed:
- All required API endpoints are available
- Response formats match expected structure for Vue components
- Authentication pattern consistent with existing admin endpoints

## API Reference

### GET /api/llm/config
```json
{
  "gemini_configured": true,
  "current_model": "gemini-3-flash-preview",
  "available_models": ["gemini-3-pro-preview", "gemini-3-flash-preview", ...],
  "rate_limit": { "capacity": 30, "fill_time_s": 60, ... }
}
```

### GET /api/llm/cache/stats
```json
{
  "total_entries": 25,
  "by_status": { "pending": 5, "validated": 18, "rejected": 2 },
  "by_type": { "functional": 15, "phenotype": 10 },
  "last_generation": "2026-02-01T15:30:00Z",
  "total_tokens_input": 125000,
  "total_tokens_output": 45000,
  "estimated_cost_usd": 0.0229
}
```

### POST /api/llm/regenerate
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "accepted",
  "status_url": "/api/jobs/550e8400-...",
  "cluster_types": ["functional", "phenotype"],
  "results": { ... }
}
```
