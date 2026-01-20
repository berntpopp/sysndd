# Research Summary: SysNDD Developer Experience Improvements

**Project:** SysNDD R/Plumber API + Vue Frontend
**Synthesized:** 2026-01-20
**Overall Confidence:** HIGH

---

## Executive Summary

SysNDD is a production R/Plumber API with Vue 2 frontend requiring modernization of its developer experience. Research across four domains (stack, features, architecture, pitfalls) converges on a clear approach: **testthat 3e with mirai-based API testing** for the R API, **renv for reproducible package management**, **Makefile automation for polyglot workflows**, and **hybrid Docker setup with database in containers and API/frontend running locally**.

The recommended strategy prioritizes test infrastructure first, enabling test-driven development for all subsequent work. The key insight from pitfall research is that testing failures in R/Plumber projects almost always stem from mixing business logic testing with HTTP endpoint testing, and from inadequate database connection cleanup. Both issues must be addressed architecturally from the start, not retrofitted later.

Critical decisions involve rejecting callthat (too experimental) in favor of mirai + httr2 for API testing, using Docker Compose Watch (GA since 2024) for hot-reload rather than manual volume mounts, and establishing strict renv lockfile update workflows to prevent merge conflicts. The project's Windows/WSL2 development environment requires explicit documentation about storing code in the WSL2 filesystem to avoid 20x performance degradation.

---

## Key Findings

### From STACK.md: Technology Recommendations

**Core Testing Stack (HIGH confidence):**
| Package | Version | Purpose |
|---------|---------|---------|
| testthat | 3.3.2 | Unit + integration testing framework |
| mirai | 2.5.3 | Background API process management for tests |
| httr2 | Latest | HTTP client for API testing |
| httptest2 | 1.2.2 | HTTP mocking and fixtures |
| covr | 3.6.5 | Code coverage tracking |
| withr | 3.0.2 | Test fixtures and state cleanup |

**Package Management:**
- **renv 1.1.6** - Use instead of packrat (soft-deprecated)
- Global package cache reduces disk usage
- JSON lockfile for version control
- Critical: Establish team workflow for lockfile updates

**Code Quality (Already partially implemented):**
- lintr 3.3.0-1 + styler 1.11.0 (scripts exist in `api/scripts/`)
- precommit 0.4.3 optional (requires Python)

**What NOT to use:**
- callthat - Experimental lifecycle, no formal releases
- packrat - Superseded by renv
- testthat::with_mock() - Defunct in R 4.5+, use local_mocked_bindings()

### From FEATURES.md: Makefile Best Practices

**Table Stakes (Must Have):**
1. `make help` - Self-documenting with `##` comments
2. `make install` - Setup dependencies (renv + npm)
3. `make dev` - Start local development environment
4. `make test` - Run all tests across components
5. `make lint` / `make format` - Code quality
6. `make docker-up` / `make docker-down` - Docker lifecycle
7. `make clean` - Remove artifacts
8. `.PHONY` declarations for all utility targets

**Differentiators (Add in Phase 2):**
- `make pre-commit` - Combined quality checks
- `make logs` / `make shell-api` - Container access shortcuts
- Namespaced targets using `/` delimiter (e.g., `api/test`, `frontend/test`)
- Version checks for R/Node.js requirements

**Anti-Features (Avoid):**
- Single monolithic Makefile (modularize instead)
- Using `:` or `-` in target names (use `/` for namespacing)
- Hardcoded paths (use variables)
- Complex bash scripts inline (move to separate scripts)
- Missing help target

### From ARCHITECTURE.md: Test and Docker Patterns

**Test Directory Structure:**
```
api/
  tests/
    testthat.R              # Auto-generated entry point (DO NOT EDIT)
    testthat/
      setup.R               # API startup with mirai/callr
      helper-api.R          # URL builders, JWT generation
      helper-database.R     # Test DB creation/cleanup
      helper-auth.R         # Authentication test utilities
      fixtures/             # Test data organized by domain
      test-database-functions.R    # Unit tests
      test-endpoint-functions.R    # Unit tests
      test-entity-endpoints.R      # Integration tests
```

**Three-Layer Testing Strategy:**
1. **Unit tests (functions)** - Fast, no dependencies, test business logic
2. **Unit tests (database)** - With fixtures or mocked connections
3. **Integration tests (endpoints)** - HTTP contract testing only

**Docker Compose Organization:**
- `docker-compose.yml` - Production/base configuration
- `docker-compose.dev.yml` - Development overrides with Watch
- `docker-compose.test.yml` - Test database (tmpfs for speed)
- Use profiles: `--profile dev`, `--profile test`, `--profile prod`

**Hybrid Development Pattern (Recommended):**
- Database runs in Docker (consistent, isolated)
- API runs locally (fast iteration, debugger access)
- Frontend runs locally (hot-reload via npm)

### From PITFALLS.md: Critical Issues to Prevent

**Top 5 Critical Pitfalls:**

1. **Testing business logic inside HTTP layer** (Phase 1)
   - Leads to slow, brittle tests
   - Prevention: Two-layer testing from day one

2. **Database connection pool leaks in tests** (Phase 1)
   - Causes intermittent "too many connections" failures
   - Prevention: Always use `withr::defer()` for cleanup

3. **renv::restore() taking 15+ minutes in Docker** (Phase 2)
   - Prevention: Multi-stage builds with BuildKit cache mounts

4. **WSL2 bind mount 20x performance degradation** (Phase 2)
   - Prevention: Store project in WSL2 filesystem (`~/development/`), NOT `/mnt/c/`

5. **renv lockfile merge conflicts** (Phase 2)
   - Prevention: Document "one person updates at a time" workflow

**Additional Moderate Pitfalls:**
- Makefile SHELL variable scoping breaks polyglot targets (use `private` keyword)
- .Renviron committed to git (add to .gitignore, create .example template)
- Parallel testthat creates race conditions (use withr for state isolation)
- Production docker-compose used for development (create dev override)

---

## Implications for Roadmap

### Suggested Phase Structure

**Phase 1: Test Infrastructure Foundation** (Week 1-2)
| Aspect | Detail |
|--------|--------|
| Rationale | Enables TDD for all subsequent work |
| Delivers | Working test suite with first 5-10 tests proving pattern |
| Features | testthat 3e setup, helper files, mirai API startup, fixtures |
| Pitfalls | #1 (HTTP layer testing), #2 (connection cleanup), #8 (parallel state) |
| Research needed | No - well-documented patterns |

Key deliverables:
- `tests/testthat/` directory structure
- `setup.R` with mirai-based API startup
- `helper-api.R`, `helper-database.R`, `helper-auth.R`
- 5-10 unit tests for existing functions
- 3-5 integration tests for critical endpoints

**Phase 2: Package Management + Docker Modernization** (Week 3-4)
| Aspect | Detail |
|--------|--------|
| Rationale | Reproducible environments enable collaboration |
| Delivers | renv lockfile, Docker Compose Watch, hybrid dev setup |
| Features | renv init/snapshot, multi-stage Dockerfile, docker-compose.dev.yml |
| Pitfalls | #3 (slow renv), #4 (WSL2), #5 (lockfile conflicts), #7 (.Renviron) |
| Research needed | No - official documentation sufficient |

Key deliverables:
- `renv.lock` committed (packages locked)
- Multi-stage `api/Dockerfile` with cache mounts
- `docker-compose.dev.yml` with Watch configuration
- Developer setup documentation (especially WSL2 path requirements)
- `.Renviron.example` template

**Phase 3: Makefile Automation** (Week 5)
| Aspect | Detail |
|--------|--------|
| Rationale | Unified interface for polyglot project |
| Delivers | Single `make` interface for all common tasks |
| Features | help, install, dev, test, lint, format, docker targets |
| Pitfalls | #6 (SHELL scoping), #12 (path separators) |
| Research needed | No - standard patterns |

Key deliverables:
- Root `Makefile` with namespaced targets
- Self-documenting help target
- API and frontend targets separated
- Docker lifecycle targets
- Pre-commit quality check target

**Phase 4: Expanded Test Coverage** (Week 6-8)
| Aspect | Detail |
|--------|--------|
| Rationale | Build confidence before refactoring |
| Delivers | 70%+ coverage of function files |
| Features | Unit tests for all 18 function files |
| Pitfalls | #9 (fixture cleanup) |
| Research needed | No - apply Phase 1 patterns |

Key deliverables:
- Test files for all `functions/*.R` files
- Integration tests for all critical endpoints
- Coverage report via covr
- Pre-commit hook enforcing tests pass

**Phase 5: CI/CD Integration** (Week 9-10, optional)
| Aspect | Detail |
|--------|--------|
| Rationale | Automated quality gates |
| Delivers | GitHub Actions running tests on every PR |
| Features | Workflow file, renv caching, coverage reporting |
| Pitfalls | #11 (cache misses) |
| Research needed | Minimal - r-lib/actions provides templates |

Key deliverables:
- `.github/workflows/test.yml`
- renv cache configured correctly
- Coverage badge in README
- PR required to pass tests

### Dependency Chain

```
Phase 1 (Test Infrastructure)
    |
    v
Phase 2 (renv + Docker) <--+
    |                      |
    v                      | (Can parallelize)
Phase 3 (Makefile) --------+
    |
    v
Phase 4 (Test Coverage)
    |
    v
Phase 5 (CI/CD) [Optional]
```

**Critical path:** 1 -> 2 -> 4 (testing pipeline)
**Parallel work:** Phase 3 can proceed alongside Phase 2

### Research Flags

| Phase | Needs Research | Notes |
|-------|----------------|-------|
| Phase 1 | NO | testthat + mirai patterns well-documented |
| Phase 2 | NO | renv + Docker officially documented |
| Phase 3 | NO | Makefile patterns standard |
| Phase 4 | NO | Apply Phase 1 patterns |
| Phase 5 | MINIMAL | Use r-lib/actions templates |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (testthat, renv, mirai) | HIGH | All CRAN-verified, official r-lib/Posit packages, Jan 2026 versions |
| Features (Makefile patterns) | HIGH | Community consensus, multiple authoritative sources |
| Architecture (test structure) | HIGH | Official R Packages book, testthat docs |
| Pitfalls | HIGH | Verified via official docs, GitHub issues, community validation |

### Gaps to Address During Implementation

1. **Hot-reload for R Plumber API** - Docker Compose Watch syncs files, but Plumber may need restart signal. Test whether sync alone triggers reload or if `sync+restart` is needed.

2. **httptest2 + httr2 compatibility** - Verify httptest2 works with latest httr2 version before committing to this stack.

3. **Existing endpoint structure** - Current 21 endpoint files need review to determine which business logic can be extracted for unit testing.

4. **Test database seeding** - Schema migration scripts exist in `db/`, but test fixture seeding strategy needs definition.

---

## Critical Decisions Required

### Decision 1: API Testing Approach
**Recommendation:** mirai + httr2 (NOT callthat)

callthat is experimental with no formal releases. mirai is production-ready, actively maintained, and recommended by best practices sources. Use mirai to start API in background during test setup, httr2 for HTTP requests.

### Decision 2: Development Environment
**Recommendation:** Hybrid (DB in Docker, API/frontend local)

This provides the best developer experience: consistent database, fast iteration on code, debugger access, IDE integration. Full-Docker option available via `docker compose watch` for those who prefer it.

### Decision 3: renv Adoption
**Recommendation:** Adopt immediately in Phase 2

Lock package versions now to prevent "works on my machine" issues. Establish team workflow for lockfile updates before merge conflicts become a problem.

### Decision 4: Test Coverage Target
**Recommendation:** 70% for function files, 50% for endpoints

Higher coverage on business logic (testable without HTTP), lower on endpoints (HTTP contract testing only). Coverage enforcement in CI optional for Phase 5.

---

## Implementation Priorities

### Immediate (Phase 1)
1. Create `tests/testthat/` directory structure
2. Write `setup.R` with mirai-based API startup
3. Create helper files for API, database, and auth utilities
4. Write first unit tests for `helper-functions.R`
5. Write first integration tests for `/api/status/` endpoint

### Short-term (Phase 2)
1. Run `renv::init()` and commit `renv.lock`
2. Create multi-stage `api/Dockerfile`
3. Create `docker-compose.dev.yml` with Watch config
4. Document WSL2 requirements for Windows developers
5. Add `.Renviron` to `.gitignore`, create `.Renviron.example`

### Medium-term (Phase 3-4)
1. Create root `Makefile` with namespaced targets
2. Expand test coverage to all function files
3. Add coverage reporting via covr
4. Implement pre-commit quality checks

---

## Sources

### Primary Sources (HIGH Confidence)
- [CRAN Package Repository](https://cran.r-project.org/) - Package versions verified Jan 2026
- [testthat.r-lib.org](https://testthat.r-lib.org/) - Official testthat documentation
- [rstudio.github.io/renv](https://rstudio.github.io/renv/) - Official renv documentation
- [mirai.r-lib.org](https://mirai.r-lib.org/) - Official mirai documentation
- [docs.docker.com](https://docs.docker.com/) - Docker Compose Watch and profiles
- [R Packages (2e)](https://r-pkgs.org/) - Hadley Wickham's official guide

### Secondary Sources (MEDIUM-HIGH Confidence)
- [Jumping Rivers: API Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)
- [rOpenSci HTTP Testing Book](https://books.ropensci.org/http-testing/)
- [Docker WSL2 Best Practices](https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/)
- Makefile best practices from Shipyard, FreeCodeCamp, community guides

### Pitfall Documentation
- Official GitHub issues for renv, testthat, Docker
- Community discussion threads validating real-world problems
- Docker for Windows performance issues (#10476)
