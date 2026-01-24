# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul - Phase 19 Security Hardening in progress

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** 19 of 24 (Security Hardening)
**Plan:** 5/8 complete
**Status:** In progress
**Last activity:** 2026-01-24 - Completed 19-05-PLAN.md (Verification and Testing)

```
v4 Backend Overhaul: PHASE 19 IN PROGRESS
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 21% (1/7 phases + 5/8 plans)
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
- Passwords visible in logs - **SANITIZED** (19-04)

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
| 2026-01-23 | 19-02 | params = list() for simple parameterized queries | Standard RMariaDB pattern |
| 2026-01-23 | 19-02 | Dynamic IN clause with placeholder generation | paste(rep("?", n)) pattern for batch operations |
| 2026-01-23 | 19-03 | Combined UPDATE statements in user approval | Single parameterized query more efficient than 3 separate |
| 2026-01-23 | 19-03 | Silent password upgrade on login | No user notification needed for transparent migration |
| 2026-01-23 | 19-04 | Sanitize JSON body by parsing then sanitize_object | More reliable than regex replacement |
| 2026-01-23 | 19-04 | Generic 500 for unhandled exceptions | Don't expose stack traces or internal error messages |
| 2026-01-24 | 19-05 | Use $7$ prefix for libsodium hash detection | sodium::password_store produces $7$ hashes, not $argon2 |
| 2026-01-24 | 19-05 | Plumber sourcing via find.package path | Relative paths fail when Plumber sources endpoints |
| 2026-01-24 | 19-05 | Mount core/ directory in Docker | Core modules must be accessible at container runtime |

### Pending Todos

None yet.

### Blockers/Concerns

**From Research:**
- ~~Matrix ABI breaking change (must upgrade Matrix to 1.6.3+ BEFORE R upgrade)~~ RESOLVED - Matrix 1.7.2 in R 4.4.3
- ~~Password migration requires dual-hash verification (avoid user lockout)~~ RESOLVED - verify_password() supports both modes
- mim2gene.txt lacks disease names (need MONDO/HPO integration)

## Session Continuity

**Last session:** 2026-01-24
**Stopped at:** Completed 19-05-PLAN.md
**Resume file:** None
**Next action:** Execute 19-06-PLAN.md for entity endpoints security hardening

---
*Last updated: 2026-01-24 - Phase 19 Plan 05 complete (Verification and Testing)*
