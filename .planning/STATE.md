# Project State: SysNDD

**Last updated:** 2026-01-31
**Current milestone:** v10.0 Data Quality & AI Insights

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-31)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v10.0 — Bug fixes, Publications/Pubtator improvements, LLM cluster summaries

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Defining requirements
**Progress:** v10.0 ░░░░░░░░░░░░ 0%

**Last completed:** v9.0 Production Readiness milestone shipped
**Last activity:** 2026-01-31 — Milestone v10.0 started

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
- Milestones shipped: 9 (v1-v9)
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
| v9 Production Readiness | 47-54 | 16 | 2026-01-31 |

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
**Stopped at:** v9.0 milestone shipped and archived
**Next action:** Use `/gsd:new-milestone` to start v10.0 planning

**Handoff notes:**

1. **v10.0 Milestone Started (2026-01-31):**
   - Focus: Bug fixes, Publications/Pubtator improvements, LLM cluster summaries
   - Priority: Bugs first, then features
   - LLM: Gemini API with batch pre-generation, LLM-as-judge validation

2. **Known bugs to fix:**
   - #122: EIF2AK2 publication update incomplete
   - #115: GAP43 entity not visible
   - #114: MEF2C entity updating issues
   - Viewer profile / auto-logout
   - PMID deletion during re-review
   - #44: Entities over time counts incorrect
   - #41: Disease renaming / re-reviewer identity

3. **v9.0 Milestone Shipped (2026-01-31):**
   - All 8 phases (47-54) completed with 16 plans
   - Git tag: `v9.0`

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-31 — v9.0 milestone shipped*
