# SysNDD Developer Experience Improvements

## What This Is

Developer experience and infrastructure improvements for SysNDD, a neurodevelopmental disorders database. This milestone focuses on finishing the API modularization refactoring, adding comprehensive R API testing, and modernizing the development tooling with a Makefile-based workflow and hybrid Docker setup.

## Core Value

A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## Requirements

### Validated

<!-- Inferred from existing codebase -->

- ✓ Modular R/Plumber API with 21 endpoint files — existing
- ✓ Vue 2 SPA frontend with Bootstrap-Vue — existing
- ✓ JWT-based authentication system — existing
- ✓ Database connection pooling with pool package — existing
- ✓ R code linting with lintr + styler — existing
- ✓ Frontend linting with ESLint — existing
- ✓ Docker Compose multi-service setup — existing
- ✓ npm package-lock.json for frontend dependencies — existing

### Active

<!-- Current scope. Building toward these. -->

**API Refactoring Completion (Issue #109):**
- [ ] Verify all extracted endpoints function correctly
- [ ] Remove legacy `api/_old/` directory
- [ ] Update documentation to reflect new structure

**R API Testing Infrastructure (Issue #123):**
- [ ] Install testthat + callthat testing framework
- [ ] Create test directory structure with helpers
- [ ] Write unit tests for core utility functions
- [ ] Write endpoint tests for authentication flow
- [ ] Write endpoint tests for entity CRUD operations
- [ ] Configure test database connection
- [ ] Add tests for external API mocking (HGNC, PubMed)

**Makefile Automation:**
- [ ] Create Makefile with standard targets
- [ ] Dev setup: `make setup`, `make install`, `make setup-db`
- [ ] Running: `make dev`, `make api`, `make frontend`
- [ ] Testing: `make test`, `make test-api`, `make lint`
- [ ] Docker: `make docker-build`, `make docker-up`, `make docker-down`
- [ ] Quality: `make format`, `make lint-fix`, `make pre-commit`

**Docker/Development Modernization:**
- [ ] Create docker-compose.dev.yml for hybrid local development (DB only)
- [ ] Update docker-compose.yml with Docker Compose Watch for hot-reload
- [ ] Pin Docker base image versions explicitly
- [ ] Add .dockerignore for faster builds
- [ ] Configure renv for R package version locking
- [ ] Create renv.lock from current package state

### Out of Scope

- Vue 3 migration — scheduled for later, keeping Vue 2 for now
- R/Plumber replacement — keeping current stack
- Frontend testing — R API testing is priority; frontend tests later
- CI/CD pipeline — focus on local development first
- Production deployment changes — this is developer experience focused

## Context

**Current state:**
- API refactoring is 95% complete — endpoints extracted, mounted, working
- No testing infrastructure exists — neither R nor Vue
- Docker setup exists but is production-focused, not dev-friendly
- R packages installed manually in Dockerfile without version locking
- No standardized commands — developers need to know specific incantations

**GitHub Issues:**
- #109: Refactor sysndd_plumber.R into smaller endpoint files
- #123: Implement comprehensive testing

**Codebase map:** See `.planning/codebase/` for detailed analysis

## Constraints

- **Stack**: Must stay with R/Plumber for API, Vue 2 for frontend (Vue 3 later)
- **Database**: MariaDB/MySQL 8.0.29 compatibility required
- **Docker**: rocker/tidyverse:4.3.2 base image
- **Compatibility**: Must work on Windows (WSL2), macOS, and Linux

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| testthat + callthat for R testing | callthat designed specifically for Plumber API testing within testthat framework | — Pending |
| renv for R package management | Industry standard for R reproducibility, lockfile support, Docker integration | — Pending |
| Makefile over Taskfile | Universal availability, no extra dependencies, works with AI assistants | — Pending |
| Docker Compose Watch for hot-reload | Modern approach, cross-platform consistent, built into Docker | — Pending |
| Hybrid dev setup (DB in Docker) | Fast iteration on API/frontend locally, consistent DB state | — Pending |

---
*Last updated: 2026-01-20 after initialization*
