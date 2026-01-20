# Domain Pitfalls: R API Testing and Development Tooling

**Domain:** R/Plumber API Testing and Development Infrastructure
**Researched:** 2026-01-20
**Context:** Existing production R/Plumber + Vue 2 project, no tests, adding testthat/callthat, renv, Makefile, Docker Compose for dev

---

## Critical Pitfalls

Mistakes that cause rewrites, major delays, or production issues.

### Pitfall 1: Testing Business Logic Inside HTTP Layer

**What goes wrong:** Tests only verify endpoints work via HTTP, mixing business logic validation with API contract testing. When a function changes, dozens of slow HTTP tests break instead of fast unit tests.

**Why it happens:** It's easier to start by testing the full API endpoint than separating logic from routing. callthat makes it trivially easy to spin up the API and test via HTTP, which creates the temptation to skip unit testing.

**Consequences:**
- Test suite becomes painfully slow (5-10 minutes for 50 tests)
- Hard to test edge cases without complex HTTP setup
- Database fixtures required for every test
- Can't test utility functions in isolation
- Debugging failures requires inspecting HTTP responses instead of function outputs

**Prevention:**
1. **Two-layer testing strategy** from the start:
   - **Unit tests**: Test R functions directly with testthat (no HTTP, no database)
   - **Integration tests**: Test API contracts with callthat (response codes, structure)
2. **Extract business logic** from endpoint functions into separate testable functions
3. **Rule of thumb**: If a function doesn't need `req` or `res` parameters, it shouldn't be in the endpoint file

**Detection:**
- Tests take >30 seconds to run
- Every test starts with `callthat::ct_start_server()`
- Test files mirror endpoint files one-to-one
- No tests in `tests/testthat/test-utils-*.R` or `test-functions-*.R`

**Example structure:**
```r
# BAD: Everything in endpoint
#* @get /entities
function(req, res) {
  # 50 lines of business logic here
}

# GOOD: Separated concerns
#* @get /entities
function(req, res) {
  entities <- get_entities_for_user(req$user_id)
  format_entity_response(entities)
}

# Now test get_entities_for_user() and format_entity_response()
# directly without HTTP overhead
```

**Phase impact:** Must be addressed in Phase 1 (testing infrastructure setup). If delayed to later phases, will require rewriting all tests.

**Sources:**
- [API as a package: Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/) — "The key to effective API testing lies in separating business logic from API contracts"
- [Testing your Plumber APIs from R](https://jakubsobolewski.com/blog/plumber-api/) — Two-layer approach: business logic vs API behavior
- [callthat package documentation](https://edgararuiz.github.io/callthat/) — Designed for API contract testing, not business logic testing

---

### Pitfall 2: Database Connection Pool Not Cleaned Up in Tests

**What goes wrong:** Tests leave database connections open. After running tests 3-4 times, new tests fail with "too many connections" errors. In CI, tests fail intermittently.

**Why it happens:** Plumber uses the `pool` package for connection pooling, which manages connections across requests. Tests start the API, run tests, but never explicitly close the pool. The pool's `exit` hook only runs when the R process terminates, not between tests.

**Consequences:**
- Database connection limit exhausted (especially on MySQL with default 151 connections)
- Tests fail non-deterministically in CI
- Developers restart database to "fix" the problem
- Tests pollute each other's database state
- Memory leaks in long-running test sessions

**Prevention:**
1. **Always close pools explicitly in test teardown:**
   ```r
   # tests/testthat/helper-db.R
   test_pool <- NULL

   create_test_pool <- function() {
     test_pool <<- pool::dbPool(
       drv = RMariaDB::MariaDB(),
       dbname = "sysndd_test",
       # ... connection params
       minSize = 1,
       maxSize = 5  # Low for tests
     )
     test_pool
   }

   teardown_test_pool <- function() {
     if (!is.null(test_pool)) {
       pool::poolClose(test_pool)
       test_pool <<- NULL
     }
   }
   ```

2. **Use `withr::defer()` or `on.exit()` for cleanup:**
   ```r
   test_that("entities endpoint returns data", {
     pool <- create_test_pool()
     withr::defer(pool::poolClose(pool))
     # ... test code
   })
   ```

3. **Configure lower connection limits in tests** to fail fast rather than slowly exhaust connections

4. **Use test fixtures** that create and destroy resources:
   ```r
   local_test_api <- function(env = parent.frame()) {
     pr <- plumber::pr("api/plumber.R")
     pool <- create_test_pool()
     withr::defer(pool::poolClose(pool), envir = env)
     withr::defer(callthat::ct_stop_server(), envir = env)
     callthat::ct_start_server(pr)
   }
   ```

**Detection:**
- MySQL/MariaDB error: "Too many connections"
- Tests pass individually but fail when run as suite
- `SHOW PROCESSLIST` shows dozens of idle connections from test database
- Tests fail after 2-3 runs, succeed after database restart

**Phase impact:** Must be addressed in Phase 1 (testing infrastructure). Setting up proper cleanup patterns from the start prevents hours of debugging later.

**Sources:**
- [Plumber runtime documentation](https://www.rplumber.io/articles/execution-model.html) — Execution model and lifecycle hooks
- [Where to place DB connections within plumber APIs?](https://forum.posit.co/t/where-to-place-db-connections-within-plumber-apis/35329) — Community discussion on pool management
- [Provide example on maintaining database connection](https://github.com/trestletech/plumber/issues/295) — GitHub issue about connection cleanup

---

### Pitfall 3: renv::restore() Takes 15+ Minutes in Docker Builds

**What goes wrong:** Every Docker build runs `renv::restore()` which downloads and compiles 100+ R packages from source. A single failed package 90% through means starting over. CI builds timeout. Developers wait 20 minutes for image builds.

**Why it happens:** Basic renv + Docker integration runs restore in a single `RUN` layer without caching intermediate results. Each package is downloaded and compiled sequentially. If the build fails, Docker discards all progress.

**Consequences:**
- Docker builds take 15-30 minutes
- Failed builds waste developer time
- CI/CD pipelines timeout or consume excessive resources
- Developers avoid rebuilding images, leading to environment drift
- No layer caching for packages means repeated work

**Prevention:**

**Strategy 1: Multi-stage builds with cache mounting (Recommended):**
```dockerfile
# Stage 1: Package installation
FROM rocker/tidyverse:4.3.2 AS builder

WORKDIR /app
COPY renv.lock renv.lock
COPY renv/ renv/

# Use BuildKit cache mount to persist renv cache across builds
RUN --mount=type=cache,target=/root/.cache/R/renv \
    R -e "renv::restore()"

# Stage 2: Runtime
FROM rocker/tidyverse:4.3.2

COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library
COPY . .
```

**Strategy 2: Pre-install common packages in base layer:**
```dockerfile
FROM rocker/tidyverse:4.3.2

# Install system dependencies first (cached)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libmariadb-dev

# Install stable base packages before renv (cached)
RUN install2.r --error --deps TRUE \
    plumber \
    pool \
    jose \
    jsonlite

# Now renv only installs project-specific packages
COPY renv.lock renv.lock
COPY renv/ renv/
RUN R -e "renv::restore()"
```

**Strategy 3: Leverage renv cache with volume mount (Development only):**
```yaml
# docker-compose.dev.yml
services:
  api:
    build: ./api
    volumes:
      - renv-cache:/root/.cache/R/renv
volumes:
  renv-cache:
```

**Additional tactics:**
- Use `RENV_PATHS_CACHE` environment variable to control cache location
- Set `renv::restore(prompt = FALSE)` to avoid interactive prompts
- Use binary packages where possible (configure CRAN mirror with binaries)
- Split renv::restore() into chunks if specific packages are problematic

**Detection:**
- Docker builds take >10 minutes
- Repeated package compilations on each build
- "Downloading package X" messages on every build
- CI pipeline timeout errors
- Developers complaining about slow builds

**Phase impact:** Must be addressed in Phase 2 (Docker modernization). Affects developer productivity immediately once renv is introduced.

**Sources:**
- [Using renv with Docker](https://rstudio.github.io/renv/articles/docker.html) — Official renv Docker integration guide
- [renv-docker GitHub guide](https://github.com/robertdj/renv-docker) — Multi-stage build patterns
- [Renv with Docker: How to Dockerize a Shiny Application](https://www.appsilon.com/post/renv-with-docker) — Practical examples and cache strategies
- [Improve general docker interoperability Issue #2078](https://github.com/rstudio/renv/issues/2078) — Known challenges with Docker integration

---

### Pitfall 4: WSL2 Bind Mounts Cause 20x Slower Docker Performance

**What goes wrong:** Developer on Windows with WSL2 experiences painfully slow Docker performance. API takes 60 seconds to start. File watching doesn't trigger rebuilds. Tests timeout.

**Why it happens:** Project files stored in Windows filesystem (`/mnt/c/development/sysndd`) are bind-mounted into WSL2 Docker containers. Cross-filesystem operations between Windows NTFS and Linux ext4 are extremely slow due to translation overhead.

**Consequences:**
- API startup: 60 seconds instead of 3 seconds
- File changes not detected by watchers
- Tests run 10-20x slower
- Package installation extremely slow
- Development becomes frustrating, people give up on Docker

**Prevention:**

**Rule: Store project in WSL2 filesystem, NOT Windows filesystem**

```bash
# BAD: Project in Windows filesystem
/mnt/c/development/sysndd     # Slow with Docker

# GOOD: Project in WSL2 filesystem
~/development/sysndd           # Fast with Docker
# Or: /home/username/development/sysndd
```

**Migration steps for Windows developers:**
1. Clone repository into WSL2 home directory: `cd ~ && git clone ...`
2. Access from Windows via `\\wsl$\Ubuntu\home\username\development\sysndd`
3. Update VS Code to open the WSL path, not Windows path
4. Run all Docker commands from within WSL2

**For unavoidable Windows filesystem access:**
Use named volumes instead of bind mounts:
```yaml
# docker-compose.dev.yml
services:
  api:
    volumes:
      # BAD: Bind mount from Windows
      # - .:/app

      # GOOD: Named volume with initialization
      - api-code:/app

volumes:
  api-code:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/username/development/sysndd/api
```

**Detection:**
- Docker operations extremely slow on Windows but fast on Mac/Linux
- `docker-compose up` takes >60 seconds
- File watcher doesn't detect changes
- `pwd` shows `/mnt/c/...` in WSL2
- Colleagues on Mac report "works fine for me"

**Warning signs:**
- Developer says "I'm on Windows"
- Project path includes `/mnt/c/`
- Docker Compose logs show slow startup

**Phase impact:** Must be documented in Phase 2 (Docker modernization) setup instructions. Affects all Windows developers immediately.

**Sources:**
- [Docker Desktop: WSL 2 Best practices](https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/) — Official WSL2 best practices
- [Increase WSL2 and Docker Performance on Windows By 20x](https://medium.com/@suyashsingh.stem/increase-docker-performance-on-windows-by-20x-6d2318256b9a) — Performance comparison and solutions
- [Docker with WSL2 on has bad performance with mounted local volumes Issue #10476](https://github.com/docker/for-win/issues/10476) — Community discussion of bind mount performance issues
- [Confused by how to apply 'best practices' for wsl2 and file performance](https://forums.docker.com/t/confused-by-how-to-apply-best-practices-for-wsl2-and-file-performance/135455) — Real-world confusion and solutions

---

### Pitfall 5: renv Lockfile Conflicts From Concurrent Updates

**What goes wrong:** Developer A installs package X and updates renv.lock. Developer B installs package Y and updates renv.lock. Both push to git. Merge conflict in renv.lock is 2000 lines of JSON. No one knows how to resolve it correctly.

**Why it happens:** Multiple developers running `renv::snapshot()` simultaneously create competing versions of the lockfile. Git can't auto-merge JSON structures. Manual resolution is error-prone.

**Consequences:**
- Lost package dependencies after bad merge
- Tests fail with "package X not found" after merge
- Hours wasted resolving lockfile conflicts
- Developers avoid updating dependencies to prevent conflicts
- Divergent environments between team members

**Prevention:**

**1. Establish lockfile update workflow:**
```
Rule: Only ONE person updates renv.lock at a time
Process:
1. Coordinate in team chat: "Updating dependencies for feature X"
2. Pull latest changes
3. Install new packages: renv::install("package")
4. Run renv::snapshot()
5. Test that renv::restore() works
6. Commit and push immediately
7. Notify team: "renv.lock updated, please run renv::restore()"
```

**2. Use renv status checks before committing:**
```r
# In pre-commit hook or Makefile
check_renv_status <- function() {
  status <- renv::status()
  if (!is.null(status)) {
    stop("renv not synchronized. Run renv::snapshot() or renv::restore()")
  }
}
```

**3. Automated conflict resolution (advanced):**
```bash
# .git/config
[merge "renv-lock"]
    name = renv lockfile merge driver
    driver = Rscript -e 'renv::merge_lockfiles("%O", "%A", "%B", "%A")'
```

**4. Document the merge resolution process:**
```
If renv.lock conflict occurs:
1. Accept THEIRS version: git checkout --theirs renv.lock
2. Restore their packages: R -e "renv::restore()"
3. Re-install your new packages: R -e "renv::install('yourpackage')"
4. Snapshot combined state: R -e "renv::snapshot()"
5. Test: R -e "renv::restore()"
6. Commit resolved lockfile
```

**Detection:**
- Git merge conflicts in renv.lock
- Tests fail after merging branches
- "Package X is not available" errors post-merge
- Multiple PRs touching renv.lock simultaneously

**Phase impact:** Must be addressed in Phase 2 (renv setup) with clear team workflow documentation.

**Sources:**
- [Collaborating with renv](https://rstudio.github.io/renv/articles/collaborating.html) — Official collaboration guidance: "A bit of care is required if multiple collaborators are installing new packages"
- [renv.lock git conflict Issue #1825](https://github.com/rstudio/renv/issues/1825) — Community discussion of merge conflicts
- [installing dependencies issue when using renv to share code Issue #1740](https://github.com/rstudio/renv/issues/1740) — Collaboration challenges

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or frustration but are recoverable.

### Pitfall 6: Makefile SHELL Variable Scoping Creates Polyglot Chaos

**What goes wrong:** Makefile defines `SHELL := Rscript` to run R commands inline. Works great for R targets. Then JavaScript `npm install` target mysteriously fails. Or vice versa: setting `SHELL := /bin/bash` breaks R targets.

**Why it happens:** In Makefiles, `SHELL` is inherited by all targets and their dependencies. Overriding it for one target affects everything it depends on. Polyglot projects (R + JavaScript + Bash) need different shells for different targets.

**Consequences:**
- R targets try to run with bash, fail with syntax errors
- JavaScript targets try to run with Rscript, fail mysteriously
- Hours debugging "works manually, fails in Makefile"
- Developers add workarounds that break other targets
- Makefile becomes unmaintainable

**Prevention:**

**Use target-specific private variables:**
```makefile
# WRONG: Global SHELL override
SHELL := Rscript
setup:
    install.packages("testthat")  # Works
    npm install                    # FAILS - tries to run with Rscript!

# RIGHT: Target-specific private SHELL
setup: setup-r setup-npm

setup-r: private SHELL := Rscript
setup-r: private .SHELLFLAGS := -e
setup-r:
    install.packages("testthat")
    renv::restore()

setup-npm:  # Uses default /bin/bash
    cd app && npm install

# ALTERNATIVE: Explicit command wrapping
setup-r:
    Rscript -e 'install.packages("testthat")'
    Rscript -e 'renv::restore()'
```

**Key pattern: `private` keyword prevents scope leakage**
```makefile
target: private SHELL := Rscript
target: private .SHELLFLAGS := -e
target:
    # R code here
```

**Additional best practices:**
- Keep default SHELL as `/bin/bash` for maximum compatibility
- Use explicit `Rscript -e` for small R commands
- Use `npm --prefix app` instead of `cd app && npm`
- Document which targets use non-standard shells

**Detection:**
- `npm: command not found` in JavaScript targets after R changes
- R syntax errors when running R targets
- Targets work individually, fail when dependencies run
- Mysterious "file not found" errors

**Phase impact:** Must be addressed in Phase 2 (Makefile creation). Getting this wrong forces complete Makefile rewrite later.

**Sources:**
- [Polyglot Makefiles](https://agdr.org/blog/polyglot-makefiles/) — Using SHELL and .SHELLFLAGS for polyglot projects
- [Polyglot Makefiles | Hacker News discussion](https://news.ycombinator.com/item?id=23193952) — Community discussion of target-specific variables and `private` keyword

---

### Pitfall 7: .Renviron File Precedence Silently Overrides Production Config

**What goes wrong:** Developer creates project-level `.Renviron` for local database credentials. Works great locally. Deploys to production. Production uses same `.Renviron` with development credentials. Production app connects to dev database. Data corruption ensues.

**Why it happens:** R's environment variable precedence is: project `.Renviron` > user `~/.Renviron` > system `/etc/R/Renviron`. Project-level `.Renviron` always wins, even in production. If `.Renviron` is committed to git, it deploys everywhere.

**Consequences:**
- Production connects to development database
- Credentials leak into version control
- Environment variables not overrideable in production
- Different behavior locally vs production
- Security vulnerabilities

**Prevention:**

**1. Never commit .Renviron to version control:**
```bash
# .gitignore
.Renviron
.Renviron.*

# Provide template instead
echo ".Renviron" >> .gitignore
cp .Renviron .Renviron.example
# Edit .Renviron.example to remove sensitive values
git add .Renviron.example
```

**2. Use config package for environment-specific settings:**
```yaml
# config.yml (safe to commit)
default:
  database:
    host: localhost
    port: 3306
    name: sysndd_test

production:
  database:
    host: !expr Sys.getenv("DB_HOST")
    port: !expr Sys.getenv("DB_PORT")
    name: !expr Sys.getenv("DB_NAME")
```

```r
# Use config instead of direct Sys.getenv()
config <- config::get()
pool <- dbPool(
  host = config$database$host,
  port = config$database$port,
  dbname = config$database$name
)
```

**3. Set R_CONFIG_ACTIVE in environment-specific locations:**
```bash
# Production server: /etc/R/Renviron or ~/.Renviron
R_CONFIG_ACTIVE=production
DB_HOST=production-db.example.com
DB_PASSWORD=secret

# Development: project .Renviron (not committed)
R_CONFIG_ACTIVE=default
DB_HOST=localhost
DB_PASSWORD=devpassword
```

**4. Validate environment in startup:**
```r
# api/startup.R
required_vars <- c("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
missing <- required_vars[!nzchar(Sys.getenv(required_vars))]
if (length(missing) > 0) {
  stop("Missing required environment variables: ", paste(missing, collapse = ", "))
}
```

**Detection:**
- `.Renviron` file exists in git repository
- Production logs show development database connections
- Environment variables can't be overridden
- "It works on my machine" bugs
- Different behavior between environments

**Warning signs:**
- Developer says "just create a .Renviron file"
- .Renviron in git history
- Credentials in code comments
- No .Renviron.example template

**Phase impact:** Must be addressed in Phase 2 (environment setup documentation). Critical for security.

**Sources:**
- [R Startup – What They Forgot to Teach You About R](https://rstats.wtf/r-startup.html) — Environment variable precedence and startup sequence
- [R config: How to Manage Environment-Specific Configuration Files](https://www.appsilon.com/post/r-config) — config package best practices
- [Chapter 7 Environment Management | Best Coding Practices for R](https://bookdown.org/content/d1e53ac9-28ce-472f-bc2c-f499f18264a3/envManagement.html) — "Never Ever Commit .Renviron file into version control"

---

### Pitfall 8: Parallel testthat Tests Create Race Conditions

**What goes wrong:** Tests pass individually and when run sequentially. Enable parallel testing to speed up suite. Tests now fail randomly. Different tests fail each run. No obvious pattern.

**Why it happens:** testthat 3.0+ supports parallel test execution. Tests share global state (options, environment variables, loaded packages, temp files). Race conditions emerge when tests modify shared state concurrently.

**Consequences:**
- Flaky tests that fail non-deterministically
- CI failures that can't be reproduced locally
- Hours debugging phantom issues
- Team loses trust in test suite
- Parallel testing disabled, losing speed benefits

**Prevention:**

**1. Follow testthat state isolation rules:**
```r
# Each test file must leave the world as it finds it

# BAD: Modifies global state
test_that("config works", {
  options(sysndd.debug = TRUE)
  # ... test code
  # Forgets to reset option
})

# GOOD: Use withr for automatic cleanup
test_that("config works", {
  withr::local_options(list(sysndd.debug = TRUE))
  # ... test code
  # Automatically reset when test exits
})
```

**2. Use local_ functions from withr package:**
```r
# Temporary files
test_that("file processing works", {
  tmp <- withr::local_tempfile()
  # File automatically deleted after test
})

# Environment variables
test_that("auth works", {
  withr::local_envvar(c(API_KEY = "test-key"))
  # Automatically restored after test
})

# Package loading
test_that("functionality works", {
  withr::local_package("specialpackage")
  # Not loaded for other tests
})
```

**3. Detect state changes with set_state_inspector():**
```r
# tests/testthat/helper-state.R
testthat::set_state_inspector(function() {
  list(
    options = options(),
    envvars = Sys.getenv(),
    search = search(),
    wd = getwd()
  )
})
# testthat will report if tests change state
```

**4. Debug race conditions:**
```r
# Temporarily disable parallel testing
Sys.setenv(TESTTHAT_PARALLEL = "false")
testthat::test_local()

# Or test specific file
testthat::test_file("tests/testthat/test-problematic.R")
```

**5. Review fixtures for parallel safety:**
```r
# BAD: Global setup in setup.R
# setup.R
test_db <- create_database()  # Created once, shared by all tests

# GOOD: Local setup per test
# helper-db.R
local_test_db <- function(env = parent.frame()) {
  db <- create_database()
  withr::defer(close_database(db), envir = env)
  db
}

# In test
test_that("query works", {
  db <- local_test_db()  # Each test gets its own DB
  # ...
})
```

**Detection:**
- Tests pass with `TESTTHAT_PARALLEL=false`, fail with parallel enabled
- Different tests fail on each run
- Error messages about "object already exists" or "file not found"
- testthat warns about state changes
- Tests fail in CI but pass locally

**Phase impact:** Must be addressed in Phase 1 (testing infrastructure setup). Easier to build state isolation from the start than retrofit later.

**Sources:**
- [Running tests in parallel • testthat](https://testthat.r-lib.org/articles/parallel.html) — Official parallel testing guide: "State is persisted across test files"
- [Test fixtures • testthat](https://testthat.r-lib.org/articles/test-fixtures.html) — Using fixtures safely in parallel tests
- [testthat 3.0.0 - Tidyverse](https://tidyverse.org/blog/2020/10/testthat-3-0-0/) — Introduction of parallel testing and state management

---

### Pitfall 9: Test Database Fixtures Don't Clean Up Between Tests

**What goes wrong:** Test A creates user "test@example.com". Test B also creates "test@example.com". Test B fails with unique constraint violation. Tests pass individually, fail as suite. Test order matters.

**Why it happens:** Tests insert data into shared test database but don't clean up. Each test assumes clean slate. Data from previous tests pollutes later tests.

**Consequences:**
- Tests coupled to execution order
- `testthat::test_file()` works, `testthat::test_dir()` fails
- Parallel tests fail due to data conflicts
- "Works on my machine" (because local DB state differs)
- Developers add hacky WHERE clauses to filter old data

**Prevention:**

**Strategy 1: Transaction rollback (Fastest):**
```r
# tests/testthat/helper-db.R
local_db_transaction <- function(pool, env = parent.frame()) {
  conn <- pool::poolCheckout(pool)
  DBI::dbBegin(conn)

  withr::defer({
    DBI::dbRollback(conn)
    pool::poolReturn(conn)
  }, envir = env)

  conn
}

# In test
test_that("creates user", {
  conn <- local_db_transaction(test_pool)
  # All changes rolled back automatically
})
```

**Strategy 2: Truncate tables after each test:**
```r
# tests/testthat/helper-db.R
reset_test_database <- function(pool) {
  tables <- c("users", "entities", "reviews", "variations")
  for (table in tables) {
    DBI::dbExecute(pool, paste0("TRUNCATE TABLE ", table))
  }
}

# In test file
teardown({
  reset_test_database(test_pool)
})
```

**Strategy 3: Isolated test database per file (Slowest but safest):**
```r
# tests/testthat/helper-db.R
local_test_database <- function(env = parent.frame()) {
  db_name <- paste0("sysndd_test_", sample(1:99999, 1))

  # Create isolated database
  admin_pool <- create_admin_pool()
  DBI::dbExecute(admin_pool, paste0("CREATE DATABASE ", db_name))

  # Run migrations
  test_pool <- create_pool(dbname = db_name)
  run_migrations(test_pool)

  withr::defer({
    pool::poolClose(test_pool)
    DBI::dbExecute(admin_pool, paste0("DROP DATABASE ", db_name))
    pool::poolClose(admin_pool)
  }, envir = env)

  test_pool
}
```

**Strategy 4: Use dittodb to mock database entirely:**
```r
# tests/testthat/test-entities-mocked.R
test_that("get_entities returns correct structure", {
  dittodb::with_mock_db({
    # Uses pre-recorded fixtures instead of real database
    result <- get_entities(user_id = 1)
    expect_s3_class(result, "data.frame")
  })
})
```

**Best practice combination:**
- Use **dittodb mocks** for unit tests (fast, no database)
- Use **transactions** for integration tests (fast, real database)
- Use **isolated databases** only for tests that modify schema

**Detection:**
- Tests fail in different order each run
- Error: "Duplicate entry 'X' for key 'PRIMARY'"
- Test A creates data, Test B expects it exists
- Tests pass when run individually, fail as suite
- Need to manually clear database before running tests

**Phase impact:** Must be addressed in Phase 1 (testing infrastructure). Painful to retrofit into existing test suite.

**Sources:**
- [Getting Started with dittodb](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html) — Database mocking for tests
- [Best practices of testing database manipulation code](https://www.sciencedirect.com/science/article/pii/S0306437922000886) — Research on database testing patterns
- [Mocking is catching - R-hub blog](https://blog.r-hub.io/2019/10/29/mocking/) — Overview of mocking tools in R

---

### Pitfall 10: Docker Compose Production Config Used for Development

**What goes wrong:** Developer runs `docker-compose up` to start local environment. Uses production `docker-compose.yml`. No volume mounts for code. Must rebuild image after every code change. Development becomes painfully slow.

**Why it happens:** Project has production-focused `docker-compose.yml` without development alternative. Documentation says "run docker-compose up". New developers don't know they need different config.

**Consequences:**
- 5-minute rebuild cycle for every code change
- No hot-reload during development
- Can't attach debugger to running containers
- Production-like resource limits slow local dev
- Developers abandon Docker and run manually

**Prevention:**

**1. Provide separate development and production configs:**
```yaml
# docker-compose.yml (production-focused, committed)
services:
  api:
    build: ./api
    restart: always
    # No volume mounts
    # Production resource limits

# docker-compose.dev.yml (development, committed)
services:
  api:
    build: ./api
    volumes:
      - ./api:/app:cached  # Mount code for live editing
    environment:
      - R_DEBUG=true
    # No restart policy (fail fast)

# docker-compose.override.yml (local overrides, NOT committed)
# Automatically loaded by docker-compose
services:
  api:
    environment:
      - DB_PASSWORD=local-secret
```

**2. Use Docker Compose Watch for hot-reload (modern approach):**
```yaml
# docker-compose.dev.yml
services:
  api:
    develop:
      watch:
        - action: sync
          path: ./api
          target: /app
          ignore:
            - node_modules/
        - action: rebuild
          path: ./api/renv.lock
```

**3. Hybrid development setup (DB in Docker, API/frontend local):**
```yaml
# docker-compose.dev.yml (only database in Docker)
services:
  db:
    image: mariadb:10.5
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: dev
      MYSQL_DATABASE: sysndd_test
    volumes:
      - db-data:/var/lib/mysql
      - ./db/migrations:/docker-entrypoint-initdb.d

volumes:
  db-data:

# Run API and frontend locally for fastest iteration
# Makefile targets: make api, make frontend
```

**4. Document different modes clearly:**
```markdown
## Development Modes

### Mode 1: Hybrid (Recommended)
Database in Docker, API and frontend run locally.
Fast iteration, easy debugging.

make docker-db    # Start only database
make api          # Run API locally
make frontend     # Run frontend locally

### Mode 2: Full Docker with Hot-Reload
Everything in Docker with live code sync.

docker-compose -f docker-compose.dev.yml up

### Mode 3: Production-Like
Test production configuration locally.

docker-compose up
```

**Detection:**
- Developers complaining about slow Docker builds
- Only one docker-compose.yml file exists
- No volume mounts in docker-compose.yml
- Documentation says "rebuild image to see changes"
- Code changes require `docker-compose up --build`

**Phase impact:** Must be addressed in Phase 2 (Docker modernization). Critical for developer productivity.

**Sources:**
- [Docker Compose for Development Environments](https://www.mindfulchase.com/deep-dives/docker-dynamics/docker-compose-for-development-environments.html) — Development-specific patterns
- [6 Docker Compose Best Practices for Dev and Prod](https://release.com/blog/6-docker-compose-best-practices-for-dev-and-prod) — Separating dev and prod configs
- [Use Compose in production | Docker Docs](https://docs.docker.com/compose/how-tos/production/) — Official production vs development guidance
- [Local Docker Best Practices](https://www.viget.com/articles/local-docker-best-practices) — Volume mounting and development workflows

---

## Minor Pitfalls

Mistakes that cause annoyance but are quickly fixable.

### Pitfall 11: GitHub Actions renv Cache Misses Every Build

**What goes wrong:** GitHub Actions workflow runs `renv::restore()` on every build, even when renv.lock hasn't changed. Each CI run takes 15 minutes to install packages. CI costs spike.

**Why it happens:** GitHub Actions cache key doesn't include renv.lock hash, or cache path doesn't match renv's actual location. Cache technically exists but is never hit.

**Prevention:**

**Use r-lib/actions with proper cache key:**
```yaml
# .github/workflows/test.yml
name: R Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-r@v2
        with:
          r-version: '4.3.2'

      - uses: r-lib/actions/setup-renv@v2
        # Automatically handles caching based on renv.lock hash

      # OR manual caching:
      - name: Cache R packages
        uses: actions/cache@v4
        with:
          path: ~/.cache/R/renv
          key: renv-${{ runner.os }}-${{ hashFiles('**/renv.lock') }}
          restore-keys: |
            renv-${{ runner.os }}-

      - name: Restore R packages
        run: Rscript -e "renv::restore()"

      - name: Run tests
        run: Rscript -e "testthat::test_dir('tests')"
```

**Common cache issues:**

1. **Wrong cache path:**
   ```yaml
   # Wrong: renv cache is not at ./renv/
   path: ./renv/

   # Correct: Check with renv::paths$cache()
   path: ~/.cache/R/renv  # Linux
   path: ~/Library/Caches/R/renv  # macOS
   ```

2. **Cache key doesn't change when lockfile changes:**
   ```yaml
   # Wrong: Static key
   key: renv-cache

   # Correct: Include lockfile hash
   key: renv-${{ hashFiles('**/renv.lock') }}
   ```

3. **Not setting RENV_PATHS_ROOT:**
   ```yaml
   env:
     RENV_PATHS_ROOT: ~/.cache/R/renv
   ```

**Detection:**
- CI logs show "Downloading package X" on every run
- renv.lock unchanged but packages reinstalled
- Cache size is 0 bytes in GitHub Actions UI
- "Cache not found" in workflow logs

**Phase impact:** Addressed in Phase 3 (CI/CD) if CI is included. Low priority for initial development.

**Sources:**
- [Using renv with continuous integration](https://rstudio.github.io/renv/articles/ci.html) — Official CI/CD setup guide
- [r-lib/actions](https://github.com/r-lib/actions) — setup-renv action with caching
- [GitHub Actions cache documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows) — General caching patterns

---

### Pitfall 12: Cross-Platform Path Separators Break Makefile

**What goes wrong:** Makefile works on macOS and Linux. Windows developer runs `make test`. Error: "C:/Users/dev/project: No such file or directory". Forward slashes vs backslashes.

**Why it happens:** Windows uses `\` for paths, Unix uses `/`. Makefile variables containing Windows paths break Unix commands. WSL2 uses Unix paths but Windows tools may return Windows paths.

**Prevention:**

**1. Always use forward slashes in Makefiles:**
```makefile
# Works on all platforms including Windows with WSL2
API_DIR := api
FRONTEND_DIR := app/src

test:
    cd $(API_DIR) && Rscript -e "testthat::test_dir('tests')"
```

**2. Use $(CURDIR) built-in variable:**
```makefile
# CURDIR is always Unix-style paths in Make
PROJECT_ROOT := $(CURDIR)
API_DIR := $(PROJECT_ROOT)/api

setup:
    cd $(API_DIR) && Rscript -e "renv::restore()"
```

**3. Avoid Windows-specific tools in Makefile:**
```makefile
# BAD: Assumes Windows cmd.exe
clean:
    del /Q *.log

# GOOD: Use Unix tools (available in WSL2, Git Bash, macOS, Linux)
clean:
    rm -f *.log
```

**4. Use platform detection if necessary:**
```makefile
ifeq ($(OS),Windows_NT)
    # Windows-specific commands (rarely needed)
    RM := cmd /C del /Q
else
    # Unix commands (macOS, Linux, WSL2)
    RM := rm -f
endif

clean:
    $(RM) *.log
```

**For SysNDD specifically:**
Since project requires WSL2 on Windows, always assume Unix environment:
```makefile
# Assume Unix environment (macOS, Linux, Windows WSL2)
.POSIX:

API_DIR := api
FRONTEND_DIR := app

test-api:
    cd $(API_DIR) && Rscript -e "testthat::test_dir('tests')"
```

**Detection:**
- Makefile works on Mac, fails on Windows
- Error messages about path syntax
- Backslashes appearing in error messages
- `cd` commands failing

**Phase impact:** Addressed in Phase 2 (Makefile creation). Easy to fix if caught during development.

---

### Pitfall 13: Missing System Dependencies in Docker Image

**What goes wrong:** renv::restore() fails with cryptic compilation errors. "libcurl not found". "SSL error". Package installations work locally but fail in Docker.

**Why it happens:** R packages with compiled code (curl, openssl, RMariaDB) require system libraries. Base image doesn't include them. Error messages don't clearly state what's missing.

**Prevention:**

**Install system dependencies before renv::restore():**
```dockerfile
FROM rocker/tidyverse:4.3.2

# Install system dependencies for common R packages
RUN apt-get update && apt-get install -y \
    # For RMariaDB
    libmariadb-dev \
    # For curl
    libcurl4-openssl-dev \
    # For openssl
    libssl-dev \
    # For xml2
    libxml2-dev \
    # For sodium (encryption)
    libsodium-dev \
    # For gdal (spatial)
    gdal-bin \
    libgdal-dev \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Now renv::restore() will succeed
COPY renv.lock renv.lock
RUN R -e "renv::restore()"
```

**Common package → system dependency mappings:**
| R Package | System Dependency | Used For |
|-----------|------------------|----------|
| RMariaDB | libmariadb-dev | Database connections |
| curl | libcurl4-openssl-dev | HTTP requests |
| openssl | libssl-dev | Encryption |
| xml2 | libxml2-dev | XML parsing |
| sf | gdal-bin, libgdal-dev | Spatial data |
| sodium | libsodium-dev | Cryptography |
| magick | libmagick++-dev | Image processing |

**Detection:**
- Package installation fails with "library not found"
- Error: "configuration failed for package X"
- Works locally (because system has libraries), fails in Docker
- Compilation errors mentioning .h files

**Prevention for SysNDD:**
```dockerfile
FROM rocker/tidyverse:4.3.2

# System deps for sysndd R packages
RUN apt-get update && apt-get install -y \
    libmariadb-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*
```

**Phase impact:** Addressed in Phase 2 (Docker modernization). Easy fix once identified.

---

### Pitfall 14: Forgetting to Ignore Test Fixtures in Version Control

**What goes wrong:** Test database fixtures (SQL dumps, mock data, recorded HTTP responses) committed to git. Repository grows to 500MB. Clones take 10 minutes. CI runs out of disk space.

**Why it happens:** dittodb records database responses to `tests/testthat/fixtures/`. Developers don't add to .gitignore. Each test run creates more fixtures. Eventually dozens of MB committed.

**Prevention:**

**Add fixtures to .gitignore with exceptions:**
```gitignore
# In api/.gitignore

# Ignore all test fixtures
tests/testthat/fixtures/*

# But keep example fixtures for documentation
!tests/testthat/fixtures/example-*.R
!tests/testthat/fixtures/README.md

# Ignore test databases
*.sqlite
*.db
test_*.sql
```

**For dittodb specifically:**
```r
# Record fixtures once, then commit specific ones
dittodb::start_db_capturing()
# ... run code to record
dittodb::stop_db_capturing()

# Review what was recorded
list.files("tests/testthat/fixtures", recursive = TRUE)

# Keep only essential fixtures, delete rest
# Add keepers to git: git add tests/testthat/fixtures/users/SELECT-*.R
```

**Best practice: Minimize fixture size**
```r
# BAD: Records entire 100K row table
dittodb::with_db_mock({
  result <- dbGetQuery(conn, "SELECT * FROM large_table")
})

# GOOD: Records only test subset
dittodb::with_db_mock({
  result <- dbGetQuery(conn, "SELECT * FROM large_table LIMIT 10")
})
```

**Detection:**
- Git repo size growing rapidly
- `.git/objects` directory hundreds of MB
- Many files in `tests/testthat/fixtures/`
- Slow git operations

**Phase impact:** Addressed in Phase 1 (testing infrastructure setup). Add to .gitignore immediately.

---

## Phase-Specific Warnings

| Phase | Topic | Likely Pitfall | Mitigation |
|-------|-------|---------------|------------|
| Phase 1 | Testing Infrastructure | Mixing business logic with HTTP testing | Establish two-layer testing from start; review architecture in PR |
| Phase 1 | Database Testing | Connection pools not cleaned up | Create `helper-db.R` with cleanup functions; use withr::defer() |
| Phase 1 | Test Organization | No separation of unit/integration tests | Create separate test directories; document in README |
| Phase 2 | renv Setup | First renv::restore() takes 15 minutes | Set expectations; document multi-stage Docker builds |
| Phase 2 | renv Collaboration | Lockfile merge conflicts | Document workflow; establish "one at a time" rule |
| Phase 2 | Docker Development | Windows developers hit performance issues | Require WSL2 filesystem location in docs; add troubleshooting section |
| Phase 2 | Makefile Creation | SHELL variable breaks polyglot targets | Use `private` keyword; test on all platforms before PR |
| Phase 2 | Environment Config | .Renviron committed to git | Add to .gitignore immediately; create .Renviron.example |
| Phase 3 | Parallel Testing | Race conditions in test suite | Use withr for state isolation; enable parallel testing late |
| Phase 3 | Docker Compose | Only production config exists | Create docker-compose.dev.yml first; document modes |
| Phase 3 | CI/CD (if included) | GitHub Actions cache misses | Use r-lib/actions; verify cache hit rate |

---

## Summary: Top 5 Critical Pitfalls to Avoid

For this specific project (SysNDD R API testing and tooling), prioritize preventing:

1. **Testing business logic through HTTP** (Pitfall #1)
   - Impact: Makes entire test suite slow and brittle
   - Prevention: Separate unit tests from integration tests from day one
   - Phase: Must address in Phase 1

2. **Database connection pool leaks in tests** (Pitfall #2)
   - Impact: Tests fail intermittently, hard to debug
   - Prevention: Use withr::defer() for cleanup, create helper functions
   - Phase: Must address in Phase 1

3. **Slow renv::restore() in Docker** (Pitfall #3)
   - Impact: 15-minute builds kill productivity
   - Prevention: Multi-stage builds with cache mounting
   - Phase: Must address in Phase 2

4. **WSL2 bind mount performance** (Pitfall #4)
   - Impact: 20x slower development on Windows
   - Prevention: Require WSL2 filesystem location in documentation
   - Phase: Must address in Phase 2 documentation

5. **renv lockfile merge conflicts** (Pitfall #5)
   - Impact: Hours wasted resolving conflicts, broken dependencies
   - Prevention: Document workflow, coordinate updates
   - Phase: Must address in Phase 2

---

## Research Confidence Assessment

| Area | Confidence | Source Quality |
|------|-----------|----------------|
| testthat + Plumber API testing | HIGH | Official documentation, r-lib sources, recent blog posts |
| renv + Docker integration | HIGH | Official renv docs, GitHub issues, community guides |
| Makefile polyglot patterns | MEDIUM | Community blogs, Hacker News discussions, limited official docs |
| Docker Compose dev practices | HIGH | Official Docker docs, recent (2025-2026) best practice guides |
| WSL2 performance issues | HIGH | Official Docker WSL2 docs, widespread community validation |
| Database testing patterns | MEDIUM | Mix of R-specific (dittodb) and general sources |
| Cross-platform compatibility | MEDIUM | Based on general knowledge + WSL2-specific sources |

---

## Sources

### testthat and Plumber API Testing
- [API as a package: Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)
- [Testing your Plumber APIs from R](https://jakubsobolewski.com/blog/plumber-api/)
- [Testing your Plumber APIs from R | R-bloggers](https://www.r-bloggers.com/2025/07/testing-your-plumber-apis-from-r/)
- [Test plumber APIs inside an R package • callthat](https://edgararuiz.github.io/callthat/)
- [Plumber runtime documentation](https://www.rplumber.io/articles/execution-model.html)

### renv and Docker
- [Using renv with Docker • renv](https://rstudio.github.io/renv/articles/docker.html)
- [renv-docker GitHub guide](https://github.com/robertdj/renv-docker)
- [Renv with Docker: How to Dockerize a Shiny Application](https://www.appsilon.com/post/renv-with-docker)
- [Improve general docker interoperability Issue #2078](https://github.com/rstudio/renv/issues/2078)
- [Collaborating with renv](https://rstudio.github.io/renv/articles/collaborating.html)

### Docker and WSL2
- [Docker Desktop: WSL 2 Best practices](https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/)
- [Increase WSL2 and Docker Performance on Windows By 20x](https://medium.com/@suyashsingh.stem/increase-docker-performance-on-windows-by-20x-6d2318256b9a)
- [Docker with WSL2 bad performance with mounted local volumes Issue #10476](https://github.com/docker/for-win/issues/10476)

### Docker Compose Development
- [6 Docker Compose Best Practices for Dev and Prod](https://release.com/blog/6-docker-compose-best-practices-for-dev-and-prod)
- [Docker Compose for Development Environments](https://www.mindfulchase.com/deep-dives/docker-dynamics/docker-compose-for-development-environments.html)
- [Top 10 Docker Best Practices for R Developers 2025](https://collabnix.com/10-essential-docker-best-practices-for-r-developers-in-2025/)
- [Use Compose in production | Docker Docs](https://docs.docker.com/compose/how-tos/production/)

### Makefile Polyglot
- [Polyglot Makefiles](https://agdr.org/blog/polyglot-makefiles/)
- [Polyglot Makefiles | Hacker News](https://news.ycombinator.com/item?id=23193952)

### Database Testing
- [Getting Started with dittodb](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html)
- [Best practices of testing database manipulation code](https://www.sciencedirect.com/science/article/pii/S0306437922000886)
- [Mocking is catching - R-hub blog](https://blog.r-hub.io/2019/10/29/mocking/)

### testthat Parallel Testing
- [Running tests in parallel • testthat](https://testthat.r-lib.org/articles/parallel.html)
- [Test fixtures • testthat](https://testthat.r-lib.org/articles/test-fixtures.html)
- [testthat 3.0.0 - Tidyverse](https://tidyverse.org/blog/2020/10/testthat-3-0-0/)

### Environment Management
- [R Startup – What They Forgot to Teach You About R](https://rstats.wtf/r-startup.html)
- [R config: How to Manage Environment-Specific Configuration Files](https://www.appsilon.com/post/r-config)
- [Chapter 7 Environment Management | Best Coding Practices for R](https://bookdown.org/content/d1e53ac9-28ce-472f-bc2c-f499f18264a3/envManagement.html)

### CI/CD with renv
- [Using renv with continuous integration](https://rstudio.github.io/renv/articles/ci.html)
- [r-lib/actions GitHub](https://github.com/r-lib/actions)
