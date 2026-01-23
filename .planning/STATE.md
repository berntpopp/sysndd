# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul - Phase 19 Security Hardening in progress

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** 19 of 24 (Security Hardening)
**Plan:** 1/8 complete
**Status:** In progress
**Last activity:** 2026-01-23 - Completed 19-01-PLAN.md (Core Security Infrastructure)

```
v4 Backend Overhaul: PHASE 19 IN PROGRESS
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 16% (1/7 phases + 1/8 plans)
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

**Critical (Security) - Addressed in Phase 19:**
- 66 SQL injection vulnerabilities via string concatenation
- Plaintext password storage/comparison - **UTILITIES READY** (19-01)
- Passwords visible in logs - **SANITIZER READY** (19-01)

**High - Addressed in Phases 20-22:**
- 17 `dbConnect` calls bypassing connection pool
- Missing `on.exit(dbDisconnect(...))` cleanup
- OMIM genemap2 no longer provides required fields

**Medium - Addressed in Phases 22-24:**
- 15 global mutable state (`<<-`) usages
- 5 god functions (>200 lines)
- ~100 inconsistent error handling patterns
- 30 incomplete TODO comments
- 1240 lintr issues

## Key Decisions

See PROJECT.md for full decisions table. Pending v4 decisions will be logged as they are made.

## Accumulated Context

### Decisions

| Date | Phase | Decision | Rationale |
|------|-------|----------|-----------|
| 2026-01-23 | 19-01 | Use sodium::password_store for Argon2id | OWASP recommended, superior to bcrypt for new implementations |
| 2026-01-23 | 19-01 | Progressive migration via dual-verification | Zero-downtime migration without forcing password resets |
| 2026-01-23 | 19-01 | Use httpproblems for RFC 9457 errors | Industry standard Problem Details format |
| 2026-01-23 | 19-01 | Centralize sensitive fields in constant | Consistent sanitization across all logging |

### Pending Todos

None yet.

### Blockers/Concerns

**From Research:**
- ~~Matrix ABI breaking change (must upgrade Matrix to 1.6.3+ BEFORE R upgrade)~~ RESOLVED - Matrix 1.7.2 in R 4.4.3
- ~~Password migration requires dual-hash verification (avoid user lockout)~~ RESOLVED - verify_password() supports both modes
- mim2gene.txt lacks disease names (need MONDO/HPO integration)

## Session Continuity

**Last session:** 2026-01-23
**Stopped at:** Completed 19-01-PLAN.md
**Resume file:** None
**Next action:** Execute 19-02-PLAN.md for authentication endpoints hardening

---
*Last updated: 2026-01-23 - Phase 19 Plan 01 complete (Core Security Infrastructure)*
