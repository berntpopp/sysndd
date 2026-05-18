---
name: sysndd-code-quality
description: Use when reviewing or changing SysNDD code for maintainability, modularity, file size, duplication, simplicity, typed boundaries, tests, or architecture quality before handoff
---

# SysNDD Code Quality

Use this skill as a focused review pass before handoff, during refactors, or when touching large or shared SysNDD files.

## Review Workflow

1. Inspect the diff and the nearby implementation patterns before judging the change.
2. Run deterministic checks first when they are relevant: `make code-quality-audit`, `git diff --check`, targeted tests, `make lint-api`, `make lint-app`, `cd app && npm run type-check`, `cd app && npm run type-check:strict`, or the smallest useful single-test command from `AGENTS.md`.
3. Review the changed files for the quality risks below.
4. Report concrete findings with file and line references. Distinguish must-fix issues from optional cleanup.

## Quality Checks

- **Modularity:** each file/module should have one clear responsibility and a readable public surface. Prefer cohesive helpers, composables, services, or repository functions over adding another mode to an already broad file.
- **600-line soft ceiling:** flag handwritten source files that exceed or approach 600 lines when the change makes them larger. `make code-quality-audit` enforces the deterministic ratchet: new oversized files fail, and baseline oversized files may not grow. Tests, migrations, fixtures, generated files, and tightly coupled implementations may exceed the ceiling when splitting would reduce clarity.
- **KISS:** prefer direct, local solutions that match existing patterns. Push back on speculative abstractions, new dependencies, clever generic utilities, and cross-layer shortcuts.
- **DRY:** remove meaningful duplicated business logic, API normalization, query construction, or UI state handling. Do not extract tiny one-off code if it makes call flow harder to follow.
- **SOLID, pragmatically:** apply dependency direction and single-responsibility thinking, but do not introduce class-heavy architecture just to satisfy a slogan.
- **Frontend boundaries:** views and components should use typed clients from `app/src/api/*`; do not add raw axios calls or direct `localStorage.token` / `localStorage.user` access.
- **API boundaries:** endpoint files should stay thin and delegate reusable logic to services/repositories/helpers without dropping required `svc_` or `service_` prefixes.
- **Tests:** behavior changes need targeted tests or a documented deterministic check. API integration tests that write DB state should use `with_test_db_transaction()` or document why rollback is not possible.
- **Docs:** update durable docs when behavior, commands, runtime assumptions, or contributor expectations change.

## Output

Lead with findings ordered by severity. If there are no findings, say that and list any checks run plus residual risk.
