# Technology Stack: R API Testing and Development Tooling

**Project:** SysNDD R/Plumber API Testing Infrastructure
**Researched:** 2026-01-20
**Overall Confidence:** HIGH

## Executive Summary

This document recommends the 2025/2026 standard stack for adding testing infrastructure and modern development tooling to an existing R/Plumber API. All recommendations are based on current CRAN packages (verified January 2026), official documentation, and established best practices in the R ecosystem.

**Key Philosophy:** Prioritize official r-lib ecosystem tools with active maintenance, proven scalability, and wide adoption. Avoid deprecated packages and experimental tools for core infrastructure.

---

## Core Testing Framework

### Primary: testthat 3.3.2

| Aspect | Details |
|--------|---------|
| **Version** | 3.3.2 (CRAN: 2026-01-11) |
| **Purpose** | Unit testing framework for R packages |
| **Why** | De facto standard for R testing. Third edition (3e) brings improved snapshot testing, parallel execution, mocking, and better fixtures. Required by virtually all R packages. |
| **Confidence** | HIGH (official r-lib package, actively maintained by Hadley Wickham) |

**Key Features for this project:**
- **Snapshot testing** - Perfect for API response validation
- **Parallel test execution** - Speed up test suites as they grow
- **Native mocking** - `local_mocked_bindings()` for database/external service mocking
- **Test fixtures** - Clean setup/teardown with `withr` integration
- **Edition 3e** - Modern best practices (must opt-in via DESCRIPTION)

**Installation:**
```r
install.packages("testthat")
# In DESCRIPTION:
# Suggests: testthat (>= 3.0.0)
# Config/testthat/edition: 3
```

**Alternative considered:** None. testthat is the standard.

**Sources:**
- [Unit Testing for R • testthat](https://testthat.r-lib.org/)
- [CRAN: Package testthat](https://cran.r-project.org/web/packages/testthat/testthat.pdf)
- [13 Testing basics – R Packages (2e)](https://r-pkgs.org/testing-basics.html)

---

## API-Specific Testing

### Recommended: Direct httr2 + mirai Pattern

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| **mirai** | 2.5.3 (2025-12-01) | Async API process management | HIGH |
| **httr2** | Latest (via httptest2) | HTTP client for API testing | HIGH |
| **httptest2** | 1.2.2 (2025-11-16) | HTTP mocking and fixtures | HIGH |

**Why this stack:**

1. **mirai for background APIs**: Modern, scalable async evaluation framework. Powers Shiny ExtendedTask and plumber2's @async. Start API once in `tests/testthat/setup.R`, test against it, clean up in teardown.

2. **httr2 for HTTP requests**: Modern HTTP client with pipeable API. Successor to httr (which httptest2 originally supported). Clean request/response handling.

3. **httptest2 for mocking**: Record real API responses, replay in tests. Enables offline testing, fast test execution, and vignette building without live servers.

**Testing Pattern (Recommended):**
```r
# tests/testthat/setup.R
api_daemon <- mirai::daemons(1)
api_mirai <- mirai::mirai({
  plumber::plumb("path/to/plumber.R")$run(port = 8888)
})

withr::defer(
  {
    mirai::daemons(0)  # Stop daemons
  },
  teardown_env()
)

# tests/testthat/test-endpoints.R
test_that("GET /entities returns 200", {
  resp <- httr2::request("http://localhost:8888/entities") %>%
    httr2::req_perform()

  expect_equal(httr2::resp_status(resp), 200)
})
```

**Confidence:** HIGH for mirai + httr2, MEDIUM for httptest2 (requires httr2 >= 0.2.0, verify compatibility)

**Sources:**
- [API as a package: Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)
- [Minimalist Async Evaluation Framework for R • mirai](https://mirai.r-lib.org/)
- [Test Helpers for httr2 • httptest2](https://enpiar.com/httptest2/)

### Alternative: callthat (NOT RECOMMENDED)

| Library | Version | Status | Why Not |
|---------|---------|--------|---------|
| **callthat** | 0.0.0.9007 | Experimental (no releases) | Too immature for production use |

**Why NOT callthat:**
- Lifecycle badge: "experimental" (subject to breaking changes)
- No formal releases on GitHub or CRAN
- Limited community adoption compared to mirai
- Purpose-built for package distribution (inst/plumber pattern) - doesn't fit non-package API structure
- Last meaningful development unclear (no release dates)

**When to reconsider:** If SysNDD API is restructured as an R package and callthat reaches stable 1.0 release.

**Confidence:** HIGH (verified via GitHub inspection, official lifecycle badge)

**Sources:**
- [GitHub - edgararuiz/callthat](https://github.com/edgararuiz/callthat)

### Alternative: vcr + webmockr (CONSIDERED)

| Library | Purpose | Why Not Primary |
|---------|---------|----------------|
| **vcr** | HTTP request mocking (YAML/JSON fixtures) | Good alternative to httptest2, but httptest2 integrates better with httr2 |
| **webmockr** | Low-level HTTP mocking (vcr dependency) | Required by vcr, not standalone |

**Use case:** If httptest2 doesn't meet needs (e.g., prefer YAML fixtures over httptest2's R-based approach).

**Confidence:** MEDIUM (both are mature rOpenSci packages, but httptest2 is more modern)

**Sources:**
- [Chapter 6 Use vcr (& webmockr) | HTTP testing in R](https://books.ropensci.org/http-testing/vcr.html)
- [Chapter 11 vcr (& webmockr), httptest, webfakes | HTTP testing in R](https://books.ropensci.org/http-testing/pkgs-comparison.html)

---

## Code Coverage

### Recommended: covr 3.6.5

| Aspect | Details |
|--------|---------|
| **Version** | 3.6.5 (CRAN: 2025-11-09) |
| **Purpose** | Test coverage tracking for R and compiled code |
| **Why** | Standard coverage tool. Integrates with codecov.io and coveralls.io for CI/CD. Tracks both R and C/C++/Fortran. |
| **Confidence** | HIGH (official r-lib package) |

**Key Features:**
- `package_coverage()` - One function to rule them all
- Works with any test framework (not just testthat)
- Exclusion support (`.covrignore` file, function exclusions)
- CI/CD integration with GitHub Actions via `usethis`

**Setup:**
```r
install.packages("covr")

# Run locally
covr::package_coverage()

# In GitHub Actions (via usethis)
usethis::use_coverage()
```

**Minimum target:** 80% coverage for new code. Existing code can be lower initially.

**Sources:**
- [Test Coverage for Packages • covr](https://covr.r-lib.org/)
- [CRAN: Package covr](https://cran.r-project.org/web/packages/covr/index.html)

---

## Package Management

### Recommended: renv 1.1.6

| Aspect | Details |
|--------|---------|
| **Version** | 1.1.6 (CRAN: 2026-01-16) |
| **Purpose** | Project-local package version locking |
| **Why** | Successor to packrat (soft-deprecated). Industry standard for reproducible R environments. Uses global cache to save disk space. JSON lockfile format. |
| **Confidence** | HIGH (official Posit package, actively maintained) |

**Key Features:**
- **Global package cache** - Symlinks reduce duplication across projects
- **JSON lockfile** (`renv.lock`) - Easy to read, version control friendly
- **Minimal overhead** - Only `utils` dependency, no compilation needed
- **Binary packages** - Fast installation on Windows/macOS
- **R version tracking** - Documents R version in lockfile

**Workflow:**
```r
# Initialize (once per project)
renv::init()

# After installing packages
renv::snapshot()

# On new machine / teammate setup
renv::restore()

# Update packages
renv::update()
```

**Best Practices:**
1. **Commit `renv.lock`** - Version control the lockfile
2. **Ignore `renv/library`** - Don't commit actual packages
3. **Use binary packages** - Set `options(renv.config.install.binary = TRUE)`
4. **Global cache location** - Set `RENV_PATHS_ROOT` if home directory space is limited
5. **Snapshot regularly** - After adding/updating packages

**Alternative considered:** packrat (soft-deprecated, superseded by renv)

**Why NOT packrat:**
- Soft-deprecated in favor of renv
- No global package cache (wastes disk space)
- Source tarballs tracked in project (confusing, rarely useful)
- Lockfile format less tooling-friendly

**Migration:** Use `renv::migrate()` if migrating from packrat.

**Sources:**
- [Introduction to renv • renv](https://rstudio.github.io/renv/articles/renv.html)
- [CRAN: Package renv](https://cran.r-project.org/web/packages/renv/index.html)
- [packrat vs. renv • renv](https://rstudio.github.io/renv/articles/packrat.html)

---

## Code Quality and Formatting

### Recommended: lintr 3.3.0-1 + styler 1.11.0

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| **lintr** | 3.3.0-1 (2025-11-27) | Static code analysis / linting | HIGH |
| **styler** | 1.11.0 (2025-10-13) | Automated code formatting | HIGH |

**Why both:**
- **Complementary roles**: lintr *detects* style issues, styler *fixes* them
- **lintr** - Syntax errors, semantic issues, style violations (checks adherence)
- **styler** - Automatic code reformatting (applies tidyverse style guide)
- Both maintained by r-lib, designed to work together

**Existing Setup (api/):**
- `.lintr` configuration exists
- `scripts/lint-check.R`, `scripts/style-code.R`, `scripts/lint-and-fix.R` exist
- Already integrated into pre-commit workflow

**Enhancement recommendation:**
```r
# Add to DESCRIPTION Suggests:
# lintr (>= 3.3.0)
# styler (>= 1.11.0)

# Ensure scripts use package versions, not system installs
```

**IDE Integration:**
- RStudio: Built-in support for both
- VS Code: R extension supports lintr diagnostics
- Vim/Emacs: Plugins available

**Sources:**
- [A Linter for R Code • lintr](https://lintr.r-lib.org/)
- [Changelog • styler](https://styler.r-lib.org/news/index.html)
- [Using lintr and styler](https://riffomonas.org/code_club/2024-08-26-lintr-styler)

---

## Test Fixtures and Setup/Teardown

### Recommended: withr 3.0.2

| Aspect | Details |
|--------|---------|
| **Version** | 3.0.2 (CRAN: 2024-10-28) |
| **Purpose** | Temporary state changes with automatic cleanup |
| **Why** | Modern replacement for testthat's deprecated `setup()`/`teardown()`. Integrates seamlessly with testthat 3e. Self-cleaning test fixtures. |
| **Confidence** | HIGH (official r-lib package) |

**Key Pattern:**
```r
# Create custom local_* functions
local_test_db <- function(env = parent.frame()) {
  # Setup: create temp database connection
  conn <- DBI::dbConnect(...)

  # Register cleanup
  withr::defer(DBI::dbDisconnect(conn), envir = env)

  # Return resource
  conn
}

# Use in tests
test_that("database query works", {
  conn <- local_test_db()
  result <- DBI::dbGetQuery(conn, "SELECT 1")
  expect_equal(result[[1]], 1)
  # conn automatically disconnected after test
})
```

**Use cases for SysNDD:**
- Temporary database connections
- Mock config.yml files
- Temporary directories for file outputs
- Environment variable changes

**Built-in helpers:**
- `local_options()` - Temporary option changes
- `local_tempdir()` - Temporary directories
- `local_envvar()` - Environment variables
- `defer()` - Generic deferred cleanup

**Sources:**
- [Test fixtures • testthat](https://testthat.r-lib.org/articles/test-fixtures.html)
- [14 Designing your test suite – R Packages (2e)](https://r-pkgs.org/testing-design.html)
- [Self-cleaning test fixtures - Tidyverse](https://tidyverse.org/blog/2020/04/self-cleaning-test-fixtures/)

---

## Mocking

### Recommended: testthat native mocking

| Function | Purpose | Confidence |
|----------|---------|------------|
| **`local_mocked_bindings()`** | Mock functions for test duration | HIGH |
| **`with_mocked_bindings()`** | Mock functions for code block | HIGH |

**Why native mocking:**
- Built into testthat 3.0+
- Replaces defunct `with_mock()` (removed in R 4.5.0)
- No additional dependencies
- Sufficient for most use cases

**Pattern:**
```r
test_that("database error is handled", {
  local_mocked_bindings(
    dbGetQuery = function(...) stop("Database connection failed")
  )

  expect_error(
    fetch_entities(),
    "Database connection failed"
  )
})
```

**When to use external mocking:**

If native mocking insufficient, consider:
- **mockery** 0.4.5 (2025-09-04) - More advanced mocking, but now superseded by testthat's native functions
- **mockr** - Alternative mocking approach

**Recommendation:** Start with `local_mocked_bindings()`. Only add mockery/mockr if needed.

**Confidence:** HIGH (official testthat functionality, verified in 3.3.2)

**Sources:**
- [Temporarily redefine function definitions — local_mocked_bindings • testthat](https://testthat.r-lib.org/reference/local_mocked_bindings.html)
- [Mocking • testthat](https://testthat.r-lib.org/articles/mocking.html)
- [testthat with_mock deprecated](https://github.com/r-lib/testthat/pull/1986)

---

## Docker Compose Development Setup

### Recommended: Docker Compose Watch (GA since 2.22.0)

| Aspect | Details |
|--------|---------|
| **Feature** | Docker Compose Watch |
| **Version** | Docker Desktop 4.24+ / Compose 2.22.0+ |
| **Status** | Generally Available (GA announced 2024) |
| **Why** | Native hot-reload without third-party tools. Sync files, rebuild containers, or sync+restart on changes. |
| **Confidence** | HIGH (official Docker feature, widely adopted) |

**Three Action Types:**

1. **`sync`** - File changes instantly mirrored to container (hot reload frameworks)
2. **`rebuild`** - Rebuild image and recreate container (Dockerfile/dependency changes)
3. **`sync+restart`** - Sync files, then restart service (config file changes)

**Recommended Configuration for SysNDD:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: ./api/
    command: Rscript /sysndd_api_volume/start_sysndd_api.R
    restart: always
    volumes:
      - ./api/:/sysndd_api_volume/
    ports:
      - "7777:7777"
    develop:
      watch:
        # Sync R files for hot reload (plumber supports reload)
        - path: ./api/endpoints/
          target: /sysndd_api_volume/endpoints/
          action: sync

        - path: ./api/functions/
          target: /sysndd_api_volume/functions/
          action: sync

        # Sync+restart for config changes
        - path: ./api/config.yml
          target: /sysndd_api_volume/config.yml
          action: sync+restart

        # Rebuild if Dockerfile or system dependencies change
        - path: ./api/Dockerfile
          action: rebuild

        # Ignore these
        - path: ./api/renv/
          action: ignore

  mysql:
    # ... existing config ...

  app:
    # ... existing config ...
    develop:
      watch:
        - path: ./app/src/
          target: /app/src/
          action: sync

        - path: ./app/package.json
          action: rebuild
```

**Usage:**
```bash
# Start with watch enabled
docker compose watch

# Or traditional up + watch
docker compose up -d
docker compose watch
```

**Best Practices:**
- **Exclude large directories** - Ignore `renv/library/`, `node_modules/`
- **Use `.dockerignore`** - Complement watch with proper Docker ignore patterns
- **Ownership** - Use `COPY --chown` in Dockerfile for write permissions
- **Binaries required** - Container needs `stat`, `mkdir`, `rmdir` for sync

**Alternative considered:** docker-compose-dev with volumes + nodemon/watchdog (DEPRECATED approach)

**Why NOT manual watch tools:**
- Compose Watch is native, no additional dependencies
- Better performance (uses Docker's file watching)
- Standardized across projects
- Supports all three patterns (sync/rebuild/restart)

**Sources:**
- [Use Compose Watch | Docker Docs](https://docs.docker.com/compose/how-tos/file-watch/)
- [Announcing Docker Compose Watch GA Release | Docker](https://www.docker.com/blog/announcing-docker-compose-watch-ga-release/)
- [Docker Compose Watch: The Feature That Finally Killed Live-Reload Pain](https://aws.plainenglish.io/docker-compose-watch-the-feature-that-finally-killed-live-reload-pain-a91467f39917)

---

## Makefile-Based Automation

### Recommended: GNU Make with R-specific targets

| Aspect | Details |
|--------|---------|
| **Tool** | GNU Make (standard on macOS/Linux, via Git Bash on Windows) |
| **Purpose** | Task automation, consistent developer interface |
| **Why** | Standard automation tool. Simple, portable, low learning curve. Documents common tasks. |
| **Confidence** | HIGH (decades-old standard, universal availability) |

**Recommended Makefile Structure:**

```makefile
# Makefile for SysNDD API
.PHONY: help install test lint format check docker-up docker-down clean

# Default target: show help
help:
	@echo "SysNDD API Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install       Install R dependencies via renv"
	@echo "  make setup         Complete project setup"
	@echo ""
	@echo "Testing:"
	@echo "  make test          Run all tests"
	@echo "  make test-coverage Run tests with coverage report"
	@echo "  make test-watch    Run tests in watch mode (interactive)"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint          Check code style with lintr"
	@echo "  make format        Format code with styler"
	@echo "  make check         Run lint + format + test"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-up     Start services with Docker Compose"
	@echo "  make docker-watch  Start services with watch mode"
	@echo "  make docker-down   Stop Docker services"
	@echo "  make docker-logs   Show container logs"
	@echo ""
	@echo "Database:"
	@echo "  make db-migrate    Run database migrations"
	@echo "  make db-seed       Seed database with test data"

# Setup and installation
install:
	cd api && Rscript -e "renv::restore()"

setup: install
	@echo "Project setup complete"

# Testing
test:
	cd api && Rscript -e "devtools::test()"

test-coverage:
	cd api && Rscript -e "covr::package_coverage()"

test-watch:
	cd api && Rscript -e "testthat::test_dir('tests/testthat', reporter = 'progress', stop_on_failure = FALSE)"

# Code quality
lint:
	cd api && Rscript scripts/lint-check.R

format:
	cd api && Rscript scripts/style-code.R

check: lint format test
	@echo "All checks passed"

# Docker
docker-up:
	docker compose up -d

docker-watch:
	docker compose watch

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f api

# Database
db-migrate:
	cd api && Rscript -e "source('db/migrate.R')"

db-seed:
	cd api && Rscript -e "source('db/seed.R')"

# Cleanup
clean:
	rm -rf api/logs/*.log
	rm -rf api/results/tmp/*
```

**Key Principles:**

1. **`.PHONY` targets** - Prevent conflicts with files named "test", "clean", etc.
2. **`help` as default** - Running `make` shows available commands
3. **Consistent naming** - Use `make <action>` pattern (test, lint, format)
4. **Compose paths** - `cd api && Rscript ...` ensures correct working directory
5. **Silent commands** - Use `@echo` for messages (suppress command echo)

**Alternative Tools:**

| Tool | Purpose | Why Not Primary |
|------|---------|----------------|
| **just** | Modern Make alternative | Not standard, requires installation |
| **task** | YAML-based task runner | Go dependency, less portable |
| **npm scripts** | JavaScript-style scripts | Requires Node.js, API is R-based |
| **R Makevars** | R package build system | Limited to package build tasks |

**When to use alternatives:** If team already standardized on one, or if project has complex cross-platform requirements beyond Make's capabilities.

**Sources:**
- [GitHub - josherrickson/MaRP: Makefile for R Package development](https://github.com/josherrickson/MaRP)
- [Makefile Conventions (GNU Coding Standards)](https://www.gnu.org/prep/standards/html_node/Makefile-Conventions.html)
- [minimal make](https://kbroman.org/minimal_make/)

---

## Git Hooks (Pre-commit)

### Recommended: precommit 0.4.3

| Aspect | Details |
|--------|---------|
| **Version** | 0.4.3 (CRAN: 2024-07-22) |
| **Purpose** | Git pre-commit hooks for R projects |
| **Why** | R wrapper around multi-language pre-commit framework. Automated code quality checks before commits. |
| **Confidence** | MEDIUM (mature but not r-lib official, relies on Python pre-commit framework) |

**What it provides:**
- Wrapper around [pre-commit.com](https://pre-commit.com/) framework
- Pre-configured hooks for R: styler, lintr, roxygen, spell checking
- Prevents commits of code style violations
- Integrates with existing scripts

**Setup:**
```r
# Install R package
install.packages("precommit")

# Install pre-commit framework (Python)
precommit::install_precommit()

# Initialize in project
precommit::use_precommit()

# Configure hooks in .pre-commit-config.yaml
```

**Recommended hooks for SysNDD:**
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/lorenzwalthert/precommit
    rev: v0.4.3
    hooks:
      - id: style-files
        args: [--style_pkg=styler, --style_fun=tidyverse_style]
      - id: lintr
      - id: parsable-R
      - id: no-browser-statement
      - id: readme-rmd-rendered
```

**Alternative: Manual Git Hooks**

Can create `.git/hooks/pre-commit` manually:
```bash
#!/bin/bash
cd api
Rscript scripts/pre-commit-check.R || exit 1
```

**Pros of precommit package:**
- Cross-platform (no shell scripting)
- Easy to share (config in repo)
- Multi-language support (if frontend needs pre-commit too)

**Cons:**
- Python dependency
- Additional complexity for pure-R teams

**Recommendation:** Use precommit if team comfortable with Python tooling. Otherwise, stick with existing `scripts/pre-commit-check.R` and manual git hook.

**Sources:**
- [GitHub - lorenzwalthert/precommit](https://github.com/lorenzwalthert/precommit)
- [Pre-Commit Hooks • precommit](https://lorenzwalthert.github.io/precommit/)
- [CRAN: Package precommit](https://cran.r-project.org/web/packages/precommit/index.html)

---

## Additional Utilities

### Recommended Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **callr** | Latest | Background R processes | Alternative to mirai for simpler use cases |
| **webfakes** | Latest | Mock HTTP servers | Complex API mocking (OAuth flows, slow connections) |
| **DBI + RSQLite** | Latest | Test database | In-memory SQLite for unit tests (avoid real DB) |
| **jsonlite** | Latest | JSON validation | Already used, ensure in DESCRIPTION |

**callr vs mirai:**

Use **mirai** for:
- Long-running background processes (API servers)
- Distributed computing
- Production async workflows

Use **callr** for:
- Simple background R sessions
- Package testing (isolation)
- One-off parallel tasks

**For SysNDD:** mirai is better choice for API testing (matches recommendation from testing best practices).

**Sources:**
- [Launching tasks with mirai • promises](https://rstudio.github.io/promises/articles/promises_04_mirai.html)

---

## R Version Recommendation

### Target: R 4.5.2

| Aspect | Details |
|--------|---------|
| **Current Stable** | R 4.5.2 (2025-10-31) |
| **Project Current** | R 4.3.2 (from CLAUDE.md context) |
| **Recommendation** | Upgrade to R 4.5.2 for new testing infrastructure |
| **Why** | testthat 3.3.2 works with R 4.5+, old `with_mock()` removed in R 4.5.0 |
| **Confidence** | HIGH (official R release) |

**Migration considerations:**
- Breaking change: `with_mock()` removed (use `local_mocked_bindings()`)
- Benefits: Better performance, modern features
- Risk: Low (minor version jump, well-documented)

**Timeline:** Upgrade as part of testing infrastructure implementation (not blocking).

**Alternative:** Stay on R 4.3.2 temporarily, but plan upgrade within 6 months.

**Sources:**
- [R Version 4.5.0 is Out! | Credibly Curious](https://www.njtierney.com/post/2025/04/14/r-version-4-5-0-is-out/)
- [Download R-4.5.2 Patched](https://cran.csail.mit.edu/bin/windows/base/rpatched.html)

---

## Plumber Version

### Target: plumber 1.3.2

| Aspect | Details |
|--------|---------|
| **Current Stable** | 1.3.2 (CRAN: 2025-12-23) |
| **Project Current** | 1.2.1 (from CLAUDE.md) |
| **Recommendation** | Upgrade to 1.3.2 |
| **Why** | Latest features, bug fixes, security updates |
| **Confidence** | HIGH (official RStudio package) |

**Breaking changes:** Review [plumber NEWS](https://cran.r-project.org/web/packages/plumber/NEWS.html) for 1.3.x changes.

**Sources:**
- [CRAN: Package plumber](https://cran.r-project.org/web/packages/plumber/index.html)

---

## Summary: Complete Stack

### Installation Script

```r
# Install testing infrastructure
install.packages(c(
  "testthat",      # 3.3.2 - Testing framework
  "covr",          # 3.6.5 - Coverage tracking
  "withr",         # 3.0.2 - Test fixtures
  "mirai",         # 2.5.3 - Async API management
  "httptest2",     # 1.2.2 - HTTP mocking
  "httr2",         # Latest - HTTP client
  "renv",          # 1.1.6 - Package management
  "lintr",         # 3.3.0-1 - Code linting
  "styler",        # 1.11.0 - Code formatting
  "precommit"      # 0.4.3 - Git hooks (optional)
))

# Update existing packages
install.packages(c(
  "plumber"        # 1.3.2 (from 1.2.1)
))
```

### DESCRIPTION File Updates

```yaml
# api/DESCRIPTION (create if not exists)
Package: sysnddapi
Title: SysNDD API
Version: 0.1.0
Suggests:
    testthat (>= 3.0.0),
    covr,
    withr,
    mirai,
    httptest2,
    httr2,
    lintr (>= 3.3.0),
    styler (>= 1.11.0)
Config/testthat/edition: 3
```

### Directory Structure

```
api/
├── tests/
│   ├── testthat.R              # Entry point
│   └── testthat/
│       ├── setup.R             # Start API with mirai
│       ├── helper-*.R          # Helper functions
│       ├── fixtures/           # httptest2 mock files
│       └── test-*.R            # Test files
├── renv/                       # renv package cache (ignored)
├── renv.lock                   # Package versions (committed)
├── .Rprofile                   # renv activation
├── Makefile                    # Task automation
└── .pre-commit-config.yaml     # Pre-commit hooks (optional)
```

---

## What NOT to Use

### Deprecated / Superseded

| Package/Feature | Status | Use Instead |
|----------------|--------|-------------|
| **packrat** | Soft-deprecated | **renv** (official successor) |
| **testthat::with_mock()** | Defunct (R 4.5+) | **testthat::local_mocked_bindings()** |
| **testthat::setup()/teardown()** | Superseded | **withr::defer()** with custom `local_*()` |
| **mockery** | Superseded | **testthat native mocking** (sufficient for most cases) |

### Experimental / Immature

| Package | Status | Why Avoid |
|---------|--------|-----------|
| **callthat** | Experimental | No releases, lifecycle: experimental, limited adoption |

### Non-Standard Tools

| Tool | Why Avoid |
|------|-----------|
| **just/task** | Not standard, requires additional installation vs Make |
| **nodemon/watchdog** | Obsolete with Docker Compose Watch |

---

## Confidence Assessment

| Category | Confidence | Basis |
|----------|------------|-------|
| Testing (testthat, covr) | HIGH | CRAN verified, official r-lib packages, Jan 2026 versions |
| API Testing (mirai, httptest2) | HIGH | CRAN verified, well-documented, recommended by best practices |
| Package Management (renv) | HIGH | CRAN verified, official Posit package, packrat successor |
| Code Quality (lintr, styler) | HIGH | CRAN verified, official r-lib packages, existing setup |
| Docker Compose Watch | HIGH | Official Docker feature, GA since 2024, widely adopted |
| Makefile | HIGH | GNU standard, universal availability, decades of use |
| Git Hooks (precommit) | MEDIUM | CRAN package but Python dependency, not r-lib official |
| callthat NOT recommended | HIGH | Direct GitHub inspection, lifecycle badge verified |

---

## Next Steps

1. **Initialize renv** - Lock current package versions
2. **Create DESCRIPTION** - Document package dependencies
3. **Set up testthat 3e** - Create `tests/testthat/` structure
4. **Implement mirai API testing** - Background process in `setup.R`
5. **Add Makefile** - Standardize common tasks
6. **Update docker-compose.yml** - Add `develop.watch` configuration
7. **Configure pre-commit** - Optional but recommended

---

## Sources

**Primary Sources (High Confidence):**
- [CRAN Package Repository](https://cran.r-project.org/) - All package versions verified Jan 2026
- [testthat.r-lib.org](https://testthat.r-lib.org/) - Official testthat documentation
- [rstudio.github.io/renv](https://rstudio.github.io/renv/) - Official renv documentation
- [mirai.r-lib.org](https://mirai.r-lib.org/) - Official mirai documentation
- [docs.docker.com](https://docs.docker.com/) - Docker Compose Watch official docs
- [R Packages (2e)](https://r-pkgs.org/) - Hadley Wickham's official R packaging guide

**Secondary Sources (Medium Confidence):**
- [Jumping Rivers: API Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/) - Best practices
- [rOpenSci HTTP Testing Book](https://books.ropensci.org/http-testing/) - HTTP testing guide
- [GitHub repositories](https://github.com/) - Package source code inspection

**Version Verification:**
All CRAN package versions verified via WebFetch to official CRAN index pages between 2026-01-20.
