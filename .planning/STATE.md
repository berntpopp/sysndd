# Project State: SysNDD

**Last updated:** 2026-01-29
**Current milestone:** v9.0 Production Readiness

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-29)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v9.0 Production Readiness — migrations, backups, user lifecycle, Docker validation

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 51 - SMTP Testing Infrastructure (Complete)
**Plan:** 2 of 2 complete
**Status:** Phase complete
**Progress:** ██████░░░░ 86% (6/7 phases)

**Last completed:** 51-02-PLAN.md (Email Integration Tests)
**Next step:** `/gsd:discuss-phase 52` to plan User Lifecycle E2E

---

## Milestone v9.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 47 | Migration System Foundation | MIGR-01, MIGR-02, MIGR-03, MIGR-05 | Complete |
| 48 | Migration Auto-Run & Health | MIGR-04, MIGR-06 | Complete (2/2 plans) |
| 49 | Backup API Layer | BKUP-01, BKUP-03, BKUP-05, BKUP-06 | Complete (2/2 plans) |
| 50 | Backup Admin UI | BKUP-02, BKUP-04 | Complete (2/2 plans) |
| 51 | SMTP Testing Infrastructure | SMTP-01, SMTP-02 | Complete (2/2 plans) |
| 52 | User Lifecycle E2E | SMTP-03, SMTP-04, SMTP-05 | Not Started |
| 53 | Production Docker Validation | PROD-01, PROD-02, PROD-03, PROD-04 | Not Started |

**Phases:** 7 (47-53)
**Requirements:** 21 mapped (100% coverage)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 253
- Milestones shipped: 8 (v1-v8)
- Phases completed: 51

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |
| v7 Curation Workflow Modernization | 34-39 | 21 | 2026-01-27 |
| v8 Gene Page & Genomic Data | 40-46 | 25 | 2026-01-29 |
| v9 Production Readiness | 47-53 | TBD | In progress |

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 687 passing | 20.3% coverage, 24 integration + 53 migration runner tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 28 | 7 original + 6 admin + 10 curation + 5 gene page |
| **Migrations** | 3 files + runner | api/functions/migration-runner.R ready |
| **Lintr Issues** | 0 | From 1,240 in v4 |
| **ESLint Issues** | 0 | 240 errors fixed in v7 |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Accumulated Context

### Phase Dependencies

```
Phase 47 (Migration Foundation)
    |
    v
Phase 48 (Migration Auto-Run & Health)
    |
    +---------------------------+
    |                           |
    v                           v
Phase 49 (Backup API)     Phase 51 (SMTP Infrastructure)
    |                           |
    v                           v
Phase 50 (Backup Admin UI) Phase 52 (User Lifecycle E2E)
    |                           |
    +---------------------------+
                |
                v
        Phase 53 (Production Docker Validation)
```

### Research Findings (from research/SUMMARY.md)

- **No new R packages needed** - all features use existing stack
- **Mailpit** replaces abandoned MailHog for local SMTP testing
- **Migration 002** now idempotent (stored procedure pattern added in 47-01)
- **Migration 003** uses correct stored procedure pattern (reference)
- **Existing backup container** (fradelg/mysql-cron-backup) already runs
- **pool package** needs explicit sizing for 4-worker setup

### Key Technical Notes

1. **Migration integration point:** `api/start_sysndd_api.R` (between pool creation and endpoint mounting)
2. **Backup patterns:** Follow `api/endpoints/admin_endpoints.R` and `api/functions/job-manager.R`
3. **Email sending:** Already implemented via `blastula` in `send_noreply_email()`
4. **Health check:** Extend existing `/health` endpoint to `/health/ready`

---

## Session Continuity

**Last session:** 2026-01-29
**Stopped at:** Completed Phase 51 (SMTP Testing Infrastructure)
**Next action:** `/gsd:discuss-phase 52` to plan User Lifecycle E2E

**Handoff notes:**

1. **Phase 51 complete (SMTP Testing Infrastructure - 2/2 plans):**
   - 51-01: Mailpit container + SMTP test endpoint (3min)
   - 51-02: Email integration tests + Mailpit helpers (2min)
   - Mailpit v1.28.4 running on localhost:8025 (Web UI) and localhost:1025 (SMTP)
   - GET /api/admin/smtp/test endpoint for connection health monitoring
   - Dev/test config profiles updated to use Mailpit (local changes only, config.yml gitignored)

2. **SMTP requirements fulfilled:**
   - SMTP-01: Mailpit integration tests verify email delivery ✓
   - SMTP-02: SMTP test endpoint + socket connection tests ✓

3. **Complete SMTP Testing System:**
   - Infrastructure: Mailpit container captures all outbound emails locally
   - Testing: helper-mailpit.R with 8 functions + integration tests
   - Monitoring: SMTP test endpoint with raw socketConnection (5s timeout)
   - Configuration: Dev/test profiles point to 127.0.0.1:1025
   - Security: Ports bound to 127.0.0.1 only, accepts any credentials in dev mode

4. **Test patterns established:**
   - Mailpit helper pattern: mailpit_available() → skip_if_no_mailpit() → operation helpers
   - Test isolation: mailpit_delete_all() before each test
   - Async handling: mailpit_wait_for_message() with polling (default 10s timeout)
   - Graceful skipping: Tests skip with informative message when Mailpit unavailable

5. **Key files created:**
   - api/tests/testthat/helper-mailpit.R (133 lines, 8 functions)
   - api/tests/testthat/test-integration-email.R (162 lines, 7 tests)

6. **Ready for Phase 52 (User Lifecycle E2E):**
   - Email infrastructure configured for testing
   - Mailpit Web UI available for manual verification
   - SMTP connection health monitoring endpoint ready
   - Integration test helpers ready for user registration/password reset flows
   - Foundation for user lifecycle E2E testing complete

7. **Important note on config.yml:**
   - api/config.yml is gitignored (contains production credentials)
   - Plan expected it to be committed but it's correctly excluded
   - Developers need to update local config.yml manually for Mailpit settings

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-29 — Phase 51 complete (SMTP Testing Infrastructure, 2/2 plans)*
