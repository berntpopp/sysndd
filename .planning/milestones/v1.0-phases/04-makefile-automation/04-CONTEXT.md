# Phase 4: Makefile Automation - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Unified command interface (`make <target>`) for all development tasks — installs, builds, tests, linting, Docker operations. Covers both R API and Vue frontend components. Does not include CI/CD pipeline configuration or deployment automation.

</domain>

<decisions>
## Implementation Decisions

### Target naming & organization
- Flat hyphenated names: `test-api`, `lint-app`, `install-api` — GNU-compliant, portable
- No combined shortcuts: must specify component explicitly (no bare `make test` running both)
- Help output grouped by action: Development, Testing, Linting, Docker sections
- Self-documenting via `##` comments parsed by help target

### Output & feedback style
- Colorized output: green for success, red for failure, cyan for target names
- Step announcements: `==> Running API tests...` before major steps
- Single verbosity level: no V=1 flag, keep it simple
- Explicit status at end: `✓ test-api complete` or `✗ test-api failed`

### Error handling behavior
- Fail fast: default Make behavior — stop on first error
- Users can run `make -k` when they want to see all failures
- Prerequisite checks: verify required tools (R, npm, docker) before running
- Clear Docker errors: "Docker is not running. Start Docker Desktop and try again."
- Platform: Linux/Mac/WSL2 only — Windows users must use WSL2

### Default target & workflow
- Bare `make` shows help — safe, discoverable for new developers
- `make pre-commit` target: runs lint-api, lint-app, test-api, test-app
- Separate install targets: `make install-api` (renv::restore) and `make install-app` (npm install)

### Claude's Discretion
- Exact color codes for terminal output
- Help target implementation details (awk vs sed)
- Whether to include a `make clean` target
- Additional utility targets if obviously useful

</decisions>

<specifics>
## Specific Ideas

- Help output should look professional — similar to well-maintained open source projects
- Pre-commit should be fast enough to not discourage use
- Error messages should include actionable next steps ("Run `brew install R` to install R")

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-makefile-automation*
*Context gathered: 2026-01-21*
