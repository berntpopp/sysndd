# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul - Phase 18 Foundation (R upgrade)

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** 18 of 24 (Foundation)
**Plan:** Not started
**Status:** Ready to plan
**Last activity:** 2026-01-23 - Roadmap created, 7 phases defined

```
v4 Backend Overhaul: ROADMAP COMPLETE
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0% (0/7 phases)
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
- Plaintext password storage/comparison
- Passwords visible in logs

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

None yet for v4. Decisions logged in PROJECT.md Key Decisions table.

### Pending Todos

None yet.

### Blockers/Concerns

**From Research:**
- Matrix ABI breaking change (must upgrade Matrix to 1.6.3+ BEFORE R upgrade)
- Password migration requires dual-hash verification (avoid user lockout)
- mim2gene.txt lacks disease names (need MONDO/HPO integration)

## Session Continuity

**Last session:** 2026-01-23
**Stopped at:** Roadmap created for v4 Backend Overhaul
**Resume file:** None
**Next action:** `/gsd:plan-phase 18` to plan Foundation phase

---
*Last updated: 2026-01-23 - v4 roadmap created with 7 phases (18-24)*
