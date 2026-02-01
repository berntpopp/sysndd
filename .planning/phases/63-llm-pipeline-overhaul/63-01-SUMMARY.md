---
phase: 63-llm-pipeline-overhaul
plan: 01
subsystem: api
tags: [docker, icu, stringi, database, logging, gemini, llm]

# Dependency graph
requires:
  - phase: 60-llm-display
    provides: LLM summary display infrastructure
provides:
  - Docker build with correct ICU library linking (Ubuntu 24.04/noble)
  - Debug logging in database helper functions
  - Corrected Gemini model name (gemini-2.0-flash)
  - JSON serialization verified for DBI parameter binding
affects: [63-02, 63-03, future LLM phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "P3M URL must match rocker base image Ubuntu version"
    - "Entry-point logging for daemon debugging"

key-files:
  created: []
  modified:
    - api/Dockerfile
    - api/functions/db-helpers.R
    - api/functions/llm-service.R
    - api/functions/llm-judge.R

key-decisions:
  - "Updated P3M URL from jammy to noble to match Ubuntu 24.04 in rocker/r-ver:4.4.3"
  - "Added entry-point message() logging to db-helpers.R functions"
  - "Changed default model from gemini-3-pro-preview to gemini-2.0-flash"

patterns-established:
  - "Docker P3M URL must match Ubuntu version: noble for 24.04, jammy for 22.04"
  - "Entry-point logging: message([function] ENTRY - key: value)"

# Metrics
duration: 24min
completed: 2026-02-01
---

# Phase 63 Plan 01: Foundation Layer Fixes Summary

**Docker ICU library fix for Ubuntu 24.04 (noble), database debug logging, and Gemini model name correction**

## Performance

- **Duration:** 24 min
- **Started:** 2026-02-01T07:27:56Z
- **Completed:** 2026-02-01T07:51:18Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Fixed Docker ICU library mismatch by updating P3M URL from jammy to noble
- Added entry-point logging to get_db_connection(), db_execute_query(), db_execute_statement()
- Updated default Gemini model from invalid "gemini-3-pro-preview" to verified "gemini-2.0-flash"
- Verified JSON serialization in llm-cache-repository.R already correctly wrapped with as.character()

## Task Commits

Each task was committed atomically:

1. **Task 1 + 2 (combined): Docker ICU fix + Debug logging + Model name** - `ea1f837d` (fix)

_Note: Tasks 1 and 2 were combined due to git commit amend. Task 3 was verification-only (no code changes)._

## Files Created/Modified

- `api/Dockerfile` - Updated P3M URL from jammy to noble; added RSPM disable; added stringi verification
- `api/functions/db-helpers.R` - Added entry-point logging to database helper functions
- `api/functions/llm-service.R` - Updated default model to gemini-2.0-flash; fixed list_gemini_models()
- `api/functions/llm-judge.R` - Updated default model to gemini-2.0-flash

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Use noble P3M URL instead of jammy | rocker/r-ver:4.4.3 uses Ubuntu 24.04 (noble) with ICU 74, not jammy with ICU 70 |
| Add message() logging, not log_debug() | message() writes to stdout/container logs immediately; log_debug() requires threshold config |
| Change model to gemini-2.0-flash | "gemini-3-pro-preview" is not a valid Gemini model name; gemini-2.0-flash is verified working |
| Keep as.character() JSON wrapping | Already correct in llm-cache-repository.R; prevents DBI binding errors |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ubuntu version mismatch in P3M URL**
- **Found during:** Task 1 (Docker ICU fix)
- **Issue:** Dockerfile comments and P3M URL said "jammy" but rocker/r-ver:4.4.3 uses Ubuntu 24.04 (noble)
- **Fix:** Changed P3M URL from jammy to noble
- **Files modified:** api/Dockerfile
- **Verification:** `docker compose build api --no-cache` succeeds; stringi reports ICU 74.2
- **Committed in:** ea1f837d

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Root cause identified and fixed. The original plan's assumption about ICU 70 was incorrect - the actual issue was P3M URL pointing to wrong Ubuntu version.

## Issues Encountered

- Initial attempt to add RENV_CONFIG_RSPM_ENABLED=FALSE did not fix the issue because the repos override was still pointing to jammy binaries
- Docker build takes ~10 minutes with --no-cache due to source compilation of some packages

## Verification Results

All success criteria verified:

1. **LLM-FIX-01**: Docker build completes without ICU/stringi errors - PASS
   - `stringi ICU: 74.2` confirmed in build output
2. **LLM-FIX-02**: Database operations work with entry-point logging - PASS
   - `/api/health/` returns "healthy"
   - `/api/entity/` returns data
   - Logs show `[db_execute_query] ENTRY`, `[get_db_connection] ENTRY` messages
3. **LLM-FIX-03**: JSON serialization verified - PASS
   - `as.character(jsonlite::toJSON(...))` found at lines 204, 212, 324 in llm-cache-repository.R
4. **LLM-FIX-04**: Model name updated to verified working "gemini-2.0-flash" - PASS
   - Found at lines 275, 509 in llm-service.R and lines 106, 276 in llm-judge.R

## Next Phase Readiness

- Foundation layer issues fixed - Docker builds cleanly with correct ICU
- Database logging in place for debugging daemon issues in Plan 02
- Model name corrected - Gemini API calls should succeed
- Ready for Plan 02: LLM pipeline verification testing

**Remaining concerns:**
- The "unused argument (envir = .GlobalEnv)" error mentioned in debug reports was not reproduced
- May need further investigation in Plan 02 if it recurs during actual LLM batch generation

---
*Phase: 63-llm-pipeline-overhaul*
*Completed: 2026-02-01*
