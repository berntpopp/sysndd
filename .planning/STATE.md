# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul — API modernization, security fixes, OMIM migration, R upgrade

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Defining requirements
**Last activity:** 2026-01-23 — Milestone v4 started

```
v4 Backend Overhaul: DEFINING REQUIREMENTS
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ Not started
```

## Completed Milestones

| Milestone | Phases | Shipped | Archive |
|-----------|--------|---------|---------|
| v1 Developer Experience | 1-5 (19 plans) | 2026-01-21 | milestones/01-developer-experience/ |
| v2 Docker Infrastructure | 6-9 (8 plans) | 2026-01-22 | milestones/02-docker-infrastructure/ |
| v3 Frontend Modernization | 10-17 (53 plans) | 2026-01-23 | milestones/03-frontend-modernization/ |

## GitHub Issues

| Issue | Description | Status |
|-------|-------------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | Ready for PR |
| #123 | Implement comprehensive testing | Foundation complete, integration tests deferred |

## Tech Debt (from API_CODE_REVIEW_REPORT.md)

**Critical (Security):**
- 66 SQL injection vulnerabilities via string concatenation
- Plaintext password storage/comparison
- Passwords visible in logs

**High:**
- 17 `dbConnect` calls bypassing connection pool
- Missing `on.exit(dbDisconnect(...))` cleanup
- OMIM genemap2 no longer provides required fields

**Medium:**
- 15 global mutable state (`<<-`) usages
- 5 god functions (>200 lines)
- ~100 inconsistent error handling patterns
- 30 incomplete TODO comments
- 1240 lintr issues

**Low:**
- 259 hard-coded configuration accesses
- Magic numbers/strings throughout

## Key Decisions

See PROJECT.md for full decisions table (48 decisions across v1-v3).

## Archive Location

- v1 artifacts: `.planning/milestones/01-developer-experience/`
- v2 artifacts: `.planning/milestones/02-docker-infrastructure/`
- v3 artifacts: `.planning/milestones/03-frontend-modernization/`

## Session Continuity

**Last session:** 2026-01-23
**Stopped at:** Starting v4 milestone, gathering requirements
**Resume file:** None

---
*Last updated: 2026-01-23 — v4 Backend Overhaul started, defining requirements*
