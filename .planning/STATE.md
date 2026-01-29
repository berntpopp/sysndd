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

**Phase:** 47 - Migration System Foundation (Not Started)
**Plan:** —
**Status:** Ready to plan
**Progress:** ░░░░░░░░░░ 0%

**Last completed:** v8.0 Gene Page & Genomic Data Integration (2026-01-29)
**Next step:** `/gsd:plan-phase 47` to create execution plan

---

## Milestone v9.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 47 | Migration System Foundation | MIGR-01, MIGR-02, MIGR-03, MIGR-05 | Not Started |
| 48 | Migration Auto-Run & Health | MIGR-04, MIGR-06 | Not Started |
| 49 | Backup API Layer | BKUP-01, BKUP-03, BKUP-05, BKUP-06 | Not Started |
| 50 | Backup Admin UI | BKUP-02, BKUP-04 | Not Started |
| 51 | SMTP Testing Infrastructure | SMTP-01, SMTP-02 | Not Started |
| 52 | User Lifecycle E2E | SMTP-03, SMTP-04, SMTP-05 | Not Started |
| 53 | Production Docker Validation | PROD-01, PROD-02, PROD-03, PROD-04 | Not Started |

**Phases:** 7 (47-53)
**Requirements:** 21 mapped (100% coverage)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 244
- Milestones shipped: 8 (v1-v8)
- Phases completed: 46

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
| **Backend Tests** | 634 passing | 20.3% coverage, 24 integration tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 28 | 7 original + 6 admin + 10 curation + 5 gene page |
| **Migrations** | 3 files | In db/migrations/, no auto-runner yet |
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
- **Migration 002** is not idempotent (needs IF NOT EXISTS guards)
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
**Stopped at:** Roadmap created
**Next action:** `/gsd:plan-phase 47` to plan Migration System Foundation

**Handoff notes:**

1. **Roadmap complete:**
   - 7 phases (47-53)
   - 21 requirements mapped with 100% coverage
   - Success criteria defined for all phases
   - Dependencies documented

2. **Ready for planning:**
   - Phase 47 is foundation with no dependencies
   - Phases 49 and 51 can run in parallel after Phase 48
   - Phase 53 is integration testing (requires all others)

3. **Research notes:**
   - Research SUMMARY.md mentions credential remediation blocker
   - Not included in provided requirements
   - May need to address separately if blocking

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-29 — v9.0 roadmap created*
