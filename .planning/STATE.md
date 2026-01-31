# Project State: SysNDD

**Last updated:** 2026-01-31
**Current milestone:** v9.0 Production Readiness (Complete)

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-29)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v9.0 Production Readiness — migrations, backups, user lifecycle, Docker validation

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** 54 - Docker Infrastructure Hardening (Complete)
**Plan:** 2 of 2 complete
**Status:** Milestone complete + post-milestone enhancements
**Progress:** ████████████ 100% (8/8 phases)

**Last completed:** Post-milestone enhancements (batch email, profile editing)
**Next step:** v9.0 milestone merge to master, then v10.0 planning

---

## Milestone v9.0 Roadmap

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 47 | Migration System Foundation | MIGR-01, MIGR-02, MIGR-03, MIGR-05 | Complete |
| 48 | Migration Auto-Run & Health | MIGR-04, MIGR-06 | Complete (2/2 plans) |
| 49 | Backup API Layer | BKUP-01, BKUP-03, BKUP-05, BKUP-06 | Complete (2/2 plans) |
| 50 | Backup Admin UI | BKUP-02, BKUP-04 | Complete (2/2 plans) |
| 51 | SMTP Testing Infrastructure | SMTP-01, SMTP-02 | Complete (2/2 plans) |
| 52 | User Lifecycle E2E | SMTP-03, SMTP-04, SMTP-05 | Complete (2/2 plans) |
| 53 | Production Docker Validation | PROD-01, PROD-02, PROD-03, PROD-04 | Complete (2/2 plans) |
| 54 | Docker Infrastructure Hardening | DOCKER-01 to DOCKER-08 | Complete (2/2 plans) |

**Phases:** 8 (47-54)
**Requirements:** 29 mapped (100% coverage)

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 256
- Milestones shipped: 8 (v1-v8)
- Phases completed: 54

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
| v9 Production Readiness | 47-54 | 16 | 2026-01-30 |

**Post-v9.0 Enhancements (2026-01-31):**
- Batch assignment email notification (re_review_endpoints.R, email-templates.R)
- Self-service profile editing for email and ORCID (user_endpoints.R, UserView.vue)

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 687 + 11 E2E | 20.3% coverage, 24 integration + 53 migration + 11 E2E tests |
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
                |
                v
        Phase 54 (Docker Infrastructure Hardening)
```

### Roadmap Evolution

- Phase 54 added: Docker Infrastructure Hardening (from DOCKER-INFRASTRUCTURE-REVIEW-2026-01-30.md)
- v9.0 milestone complete with 16 plans across 8 phases

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
5. **Docker security:** All containers use no-new-privileges, CPU limits, and log rotation

---

## Session Continuity

**Last session:** 2026-01-31
**Stopped at:** Post-milestone enhancements complete
**Next action:** v9.0 milestone merge to master, then v10.0 planning

**Handoff notes:**

1. **Phase 54 complete (Docker Infrastructure Hardening - 2/2 plans):**
   - 54-01: Nginx hardening (image pinning, access logging, static asset caching)
   - 54-02: Security hardening (no-new-privileges, CPU limits, log rotation)
   - All DOCKER-01 through DOCKER-08 requirements resolved

2. **Post-v9.0 Enhancements (2026-01-31):**

   a. **Batch Assignment Email Notification:**
      - Added `email_batch_assigned()` template function in `api/functions/email-templates.R`
      - Updated `PUT /api/batch/assign` endpoint in `api/endpoints/re_review_endpoints.R`
      - Email includes batch number, entity count, and "Start Reviewing" CTA button
      - BCC to curator@sysndd.org for monitoring
      - Commit: `e49cc74c` - feat(email): add batch assignment notification email

   b. **Self-Service Profile Editing:**
      - Added `PUT /api/profile` endpoint in `api/endpoints/user_endpoints.R`
      - Users can update their own email and ORCID
      - Email validation: format check + uniqueness check
      - ORCID validation: pattern `^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$`
      - Updated `UserView.vue` with inline editing, real-time validation, Save/Cancel UI
      - Commit: `ab917f6c` - feat(user): add self-service profile editing for email and ORCID

3. **Key files modified:**
   - `api/functions/email-templates.R` - Added batch assignment template
   - `api/endpoints/re_review_endpoints.R` - Added email notification on batch assign
   - `api/endpoints/user_endpoints.R` - Added PUT /profile endpoint
   - `app/src/views/UserView.vue` - Added profile editing UI with validation

4. **v9.0 Milestone Complete:**
   - All 8 phases (47-54) completed
   - All 29 requirements addressed
   - Production-ready Docker infrastructure
   - Plus 2 post-milestone user experience enhancements

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-31 — Post-v9.0 enhancements (batch email, profile editing) complete*
