---
phase: 79-configuration-cleanup
plan: 01
subsystem: infra
tags: [docker, environment-variables, security, omim, config]

# Dependency graph
requires:
  - phase: 76-shared-infrastructure
    provides: get_omim_download_key() function using OMIM_DOWNLOAD_KEY env var
  - phase: 78-comparisons-integration
    provides: comparisons system using shared genemap2 infrastructure
provides:
  - Docker Compose configured to pass OMIM_DOWNLOAD_KEY to API container
  - .env.example documents OMIM_DOWNLOAD_KEY with registration URL
  - All hardcoded OMIM API keys removed from version-controlled source files
affects: [deployment, production-setup, security-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Environment variable externalizing secrets from version control"
    - "DEPRECATED placeholder in migrations for removed config rows"

key-files:
  created: []
  modified:
    - docker-compose.yml
    - .env.example
    - db/data/ndd_databases_links/ndd_databases_links.txt
    - db/migrations/007_comparisons_config.sql
    - app/src/components/analyses/AnalysesCurationComparisonsTable.vue
  deleted:
    - api/data/omim_links/omim_links.txt

key-decisions:
  - "OMIM_DOWNLOAD_KEY passed via Docker Compose environment (no default value, required secret)"
  - "api/config.yml not modified (gitignored local file, not in version control)"
  - "Migration 007 uses DEPRECATED placeholder to preserve idempotency (row removed by migration 014)"

patterns-established:
  - "Secret management: Use environment variables for API keys, document in .env.example with registration URLs"
  - "Migration cleanup: Use DEPRECATED placeholders for removed rows to maintain SQL validity"

# Metrics
duration: 2min
completed: 2026-02-07
---

# Phase 79 Plan 01: Configuration & Cleanup Summary

**OMIM API key externalized to OMIM_DOWNLOAD_KEY environment variable, all hardcoded keys removed from source files**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-07T18:15:11Z
- **Completed:** 2026-02-07T18:17:15Z
- **Tasks:** 2
- **Files modified:** 5 (+ 1 deleted)

## Accomplishments
- Docker Compose passes OMIM_DOWNLOAD_KEY to API container for genemap2.txt downloads
- .env.example documents OMIM_DOWNLOAD_KEY with OMIM registration URL and usage guidance
- Zero hardcoded OMIM API keys (9GJLEFvqSmWaImCijeRdVA) in version-controlled source files
- Security posture improved: No plaintext secrets in git history going forward

## Task Commits

Each task was committed atomically:

1. **Task 1: Add OMIM_DOWNLOAD_KEY to Docker Compose and .env.example** - `feb77349` (feat)
2. **Task 2: Remove hardcoded OMIM API key from all non-planning files** - `e1eb7a32` (fix)

## Files Created/Modified
- `docker-compose.yml` - Added OMIM_DOWNLOAD_KEY env var to API service (line 166-167)
- `.env.example` - Added OMIM Configuration section with OMIM_DOWNLOAD_KEY documentation
- `db/data/ndd_databases_links/ndd_databases_links.txt` - Removed omim_genemap2 row (line 10) with hardcoded key
- `db/migrations/007_comparisons_config.sql` - Replaced hardcoded URL with DEPRECATED placeholder on line 48
- `app/src/components/analyses/AnalysesCurationComparisonsTable.vue` - Replaced hardcoded URL with generic reference (line 45)
- `api/data/omim_links/omim_links.txt` - **DELETED** (contained hardcoded key, unused by runtime code)

## Decisions Made

**1. OMIM_DOWNLOAD_KEY as required environment variable (no default value)**
- Rationale: OMIM download key is a required secret for ontology/comparisons features. No sensible default exists. Absence should cause explicit error via get_omim_download_key().

**2. api/config.yml not modified**
- Rationale: config.yml is gitignored (local development file), not in version control. Plan scope focused on version-controlled source files. Local dev files are developer-specific.

**3. Migration 007 uses DEPRECATED placeholder instead of deletion**
- Rationale: Migration 014 (Phase 78) removes the omim_genemap2 row. Keeping line 48 with DEPRECATED placeholder preserves migration idempotency while eliminating the hardcoded key. SQL remains valid.

**4. Deleted entire api/data/omim_links/ directory**
- Rationale: File contained only hardcoded URLs with API keys. The download functions in omim-functions.R construct URLs dynamically. No runtime code references this file (only legacy db/ R scripts used it).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all operations succeeded on first attempt.

## User Setup Required

**Production deployment requires OMIM download key configuration.**

**Steps:**
1. Register for OMIM download access at: https://www.omim.org/downloads/
2. After approval, obtain your download key from the OMIM download URLs
3. Add to `.env` file (or server environment): `OMIM_DOWNLOAD_KEY=your_key_here`
4. Restart API container: `docker compose restart api`
5. Verify: `docker compose logs api | grep "OMIM_DOWNLOAD_KEY"` should not show "not set" errors

**Verification:**
- GET `/api/admin/ontology/refresh` should succeed (uses genemap2.txt download)
- GET `/api/comparisons/metadata` should show successful data refresh

**Note:** Without OMIM_DOWNLOAD_KEY, ontology updates and comparisons refresh will fail with error: "OMIM_DOWNLOAD_KEY environment variable not set."

## Next Phase Readiness

**Phase 79-02 (if planned):** Ready to proceed with additional configuration cleanup tasks.

**v10.4 milestone completion:**
- CFG-01 (environment variable configuration) ✅ Complete
- CFG-03 (remove hardcoded credentials) ✅ Partially complete (OMIM key removed)
- Additional credential audits may identify other hardcoded secrets

**No blockers:** All configuration changes are backward-compatible via environment variable fallbacks in existing code.

---
*Phase: 79-configuration-cleanup*
*Completed: 2026-02-07*
