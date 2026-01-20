# Architecture Patterns: R API Testing and Docker Development

**Domain:** R/Plumber REST API with Docker-based development
**Researched:** 2026-01-20
**Confidence:** HIGH

## Executive Summary

This research addresses two architectural domains for the SysNDD R API:

1. **Test Infrastructure**: How to structure testthat-based testing for a Plumber API with 21 endpoints and 18 function files
2. **Docker Development Setup**: How to organize Docker Compose for hybrid local/container workflows with hot-reload capabilities

Both domains follow well-established patterns in the R and Docker ecosystems with strong official documentation support.

---

## Part 1: Test Directory Structure

### Recommended Architecture

```
api/
├── endpoints/                    # 21 endpoint files (existing)
├── functions/                    # 18 function files (existing)
├── tests/
│   ├── testthat.R               # Test runner (auto-generated, DO NOT EDIT)
│   └── testthat/
│       ├── setup.R              # Package-level setup (API startup)
│       ├── helper-api.R         # API-specific helpers (URL builders, mock requests)
│       ├── helper-database.R    # Database test helpers (fixtures, cleanup)
│       ├── helper-auth.R        # Authentication helpers (JWT generation)
│       ├── fixtures/            # Test data files
│       │   ├── entities/
│       │   │   ├── valid_entity.json
│       │   │   ├── invalid_entity.json
│       │   │   └── entity_update.json
│       │   ├── users/
│       │   │   └── test_users.json
│       │   └── genes/
│       │       └── gene_list.json
│       ├── test-database-functions.R        # Unit tests for database-functions.R
│       ├── test-endpoint-functions.R        # Unit tests for endpoint-functions.R
│       ├── test-analyses-functions.R        # Unit tests for analyses-functions.R
│       ├── test-helper-functions.R          # Unit tests for helper-functions.R
│       ├── test-entity-endpoints.R          # Integration tests for entity_endpoints.R
│       ├── test-authentication-endpoints.R  # Integration tests for authentication_endpoints.R
│       └── test-gene-endpoints.R            # Integration tests for gene_endpoints.R
├── start_sysndd_api.R           # API entry point (existing)
└── config.yml                   # Configuration (existing)
```

**Key Principles:**

1. **Parallel Structure**: Test files mirror source structure (`database-functions.R` → `test-database-functions.R`)
2. **Two-Layer Testing**: Unit tests (functions) and integration tests (endpoints) separated by file
3. **Helper Files**: Reusable test utilities in `helper-*.R` files (loaded by devtools and test runner)
4. **Setup File**: Package-level initialization in `setup.R` (API startup, database fixtures)
5. **Fixtures Directory**: Test data organized by domain in subdirectories

### File Type Purposes

| File Pattern | Purpose | Loaded By | Use For |
|--------------|---------|-----------|---------|
| `testthat.R` | Test runner | R CMD check | Auto-generated boilerplate (DO NOT EDIT) |
| `setup.R` | Package-level setup | All test runs | API startup, global fixtures |
| `helper-*.R` | Reusable utilities | devtools + tests | URL builders, mock objects, data loaders |
| `test-*.R` | Actual tests | Test runner | Unit tests and integration tests |
| `fixtures/*` | Test data | Explicit load | JSON fixtures, sample data |

**Source:** [R Packages (2e) - Testing Basics](https://r-pkgs.org/testing-basics.html), [testthat version 3.3.2](https://cran.r-project.org/web/packages/testthat/testthat.pdf)

---

## Part 2: Three-Layer Testing Strategy

### Layer 1: Business Logic (Unit Tests)

Test pure R functions without API or database dependencies.

**Example: `test-helper-functions.R`**
```r
test_that("convert_empty handles NULL values", {
  expect_equal(convert_empty(NULL), "")
  expect_equal(convert_empty("value"), "value")
})

test_that("validate_filter parses filters correctly", {
  result <- validate_filter("status:active,category:NDD")
  expect_type(result, "list")
  expect_length(result, 2)
})
```

**Characteristics:**
- Fast execution (milliseconds)
- No external dependencies
- Test edge cases, error conditions
- Use `withr` for temporary state changes

### Layer 2: Database Logic (Unit Tests with Fixtures)

Test database interaction functions with test database or mocked connections.

**Example: `test-database-functions.R`**
```r
test_that("post_db_entity creates entity with valid data", {
  # Arrange
  test_pool <- local_test_database() # Helper creates temp DB
  entity_data <- load_fixture("entities/valid_entity.json")

  # Act
  result <- post_db_entity(entity_data)

  # Assert
  expect_equal(result$status, 200)
  expect_type(result$entity_id, "integer")

  # Verify in database
  entity <- dbGetQuery(test_pool,
    "SELECT * FROM ndd_entity WHERE entity_id = ?",
    params = list(result$entity_id))
  expect_equal(nrow(entity), 1)
})
```

**Characteristics:**
- Medium execution time (seconds)
- Requires test database or mocking
- Test SQL queries, transactions, error handling
- Use `withr::defer()` for cleanup

### Layer 3: API Endpoints (Integration Tests)

Test HTTP contract: request → response structure validation.

**Example: `test-entity-endpoints.R`**
```r
test_that("GET /api/entity/ returns paginated entities", {
  # Arrange
  jwt_token <- generate_test_jwt(user_role = "Viewer")

  # Act
  response <- httr::GET(
    build_api_url("/api/entity/"),
    httr::add_headers(Authorization = paste("Bearer", jwt_token)),
    query = list(page_size = 5, sort = "entity_id")
  )

  # Assert
  expect_equal(httr::status_code(response), 200)

  body <- httr::content(response, as = "parsed")
  expect_named(body, c("data", "meta", "links"))
  expect_type(body$data, "list")
  expect_lte(length(body$data), 5)
})

test_that("POST /api/entity/ requires authentication", {
  # Act
  response <- httr::POST(
    build_api_url("/api/entity/"),
    body = list(hgnc_id = 1234)
  )

  # Assert
  expect_equal(httr::status_code(response), 401)
})
```

**Characteristics:**
- Slower execution (seconds per test)
- Requires running API server
- Test HTTP codes, response structure, authentication
- Don't duplicate business logic tests

**Source:** [API as a Package: Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/), [Testing Plumber APIs from R](https://jakubsobolewski.com/blog/plumber-api/)

---

## Part 3: Helper File Patterns

### `setup.R` - Package-Level Initialization

Runs before all tests. Use for API startup and global fixtures.

```r
# tests/testthat/setup.R

# Start API on random port for testing
port <- httpuv::randomPort()

# Launch API in background process
api_process <- callr::r_bg(
  func = function(port) {
    # Set environment for testing
    Sys.setenv(ENVIRONMENT = "local")
    Sys.setenv(API_CONFIG = "sysndd_db_local")

    # Source and run API
    source("start_sysndd_api.R")
  },
  args = list(port = port),
  supervise = TRUE
)

# Wait for API to start
Sys.sleep(2)

# Verify API is responding
if (!api_is_alive(port)) {
  stop("Test API failed to start on port ", port)
}

# Store port for test helpers
options(sysndd_test_port = port)

# Register cleanup
withr::defer(
  {
    message("Shutting down test API...")
    api_process$kill()
  },
  envir = testthat::teardown_env()
)
```

**Source:** [API as a Package: Testing](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)

### `helper-api.R` - API Testing Utilities

```r
# tests/testthat/helper-api.R

#' Build API URL for testing
#' @param path Endpoint path (e.g., "/api/entity/")
#' @return Full URL with test port
build_api_url <- function(path) {
  port <- getOption("sysndd_test_port", 7778)
  paste0("http://127.0.0.1:", port, path)
}

#' Check if API is responding
#' @param port Port number
#' @return TRUE if API responds, FALSE otherwise
api_is_alive <- function(port = getOption("sysndd_test_port")) {
  tryCatch({
    response <- httr::GET(
      paste0("http://127.0.0.1:", port, "/api/status/"),
      httr::timeout(5)
    )
    httr::status_code(response) == 200
  }, error = function(e) FALSE)
}

#' Skip test if API is not running
skip_if_api_dead <- function() {
  if (!api_is_alive()) {
    testthat::skip("API is not responding")
  }
}

#' Generate test JWT token
#' @param user_id User ID (default: 1)
#' @param user_role User role (default: "Administrator")
#' @param exp Expiration time (default: 1 hour from now)
#' @return JWT token string
generate_test_jwt <- function(user_id = 1,
                              user_role = "Administrator",
                              exp = as.numeric(Sys.time()) + 3600) {
  # Load secret from config
  dw <- config::get("sysndd_db_local")
  key <- charToRaw(dw$secret)

  # Create claims
  claims <- list(
    user_id = user_id,
    user_role = user_role,
    exp = exp
  )

  # Encode
  jose::jwt_encode_hmac(claims, secret = key)
}
```

### `helper-database.R` - Database Test Utilities

```r
# tests/testthat/helper-database.R

#' Create temporary test database
#' @param env Environment for cleanup (default: parent.frame())
#' @return Database connection pool
local_test_database <- function(env = parent.frame()) {
  # Create unique database name
  db_name <- paste0("sysndd_test_",
                    format(Sys.time(), "%Y%m%d_%H%M%S"),
                    "_", sample(1000:9999, 1))

  # Get config
  dw <- config::get("sysndd_db_local")

  # Create test database
  conn <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = dw$host,
    user = dw$user,
    password = dw$password,
    port = dw$port
  )

  DBI::dbExecute(conn, paste0("CREATE DATABASE ", db_name))
  DBI::dbDisconnect(conn)

  # Create connection pool
  test_pool <- pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = db_name,
    host = dw$host,
    user = dw$user,
    password = dw$password,
    port = dw$port
  )

  # Load schema
  source_db_schema(test_pool)

  # Register cleanup
  withr::defer({
    pool::poolClose(test_pool)

    # Drop test database
    conn <- DBI::dbConnect(
      RMariaDB::MariaDB(),
      host = dw$host,
      user = dw$user,
      password = dw$password,
      port = dw$port
    )
    DBI::dbExecute(conn, paste0("DROP DATABASE IF EXISTS ", db_name))
    DBI::dbDisconnect(conn)
  }, envir = env)

  test_pool
}

#' Load test fixture file
#' @param fixture_path Path relative to fixtures/ directory
#' @return Parsed JSON data
load_fixture <- function(fixture_path) {
  full_path <- testthat::test_path("fixtures", fixture_path)
  jsonlite::fromJSON(full_path, simplifyVector = FALSE)
}
```

**Source:** [Test Fixtures - testthat](https://testthat.r-lib.org/articles/test-fixtures.html), [Helper Code for Tests](https://blog.r-hub.io/2020/11/18/testthat-utility-belt/)

---

## Part 4: Docker Compose Organization

### Recommended File Structure

```
/
├── docker-compose.yml           # Production + base configuration
├── docker-compose.dev.yml       # Development overrides (DB only + API watch)
├── docker-compose.test.yml      # Test overrides (test database)
├── .env                         # Environment variables
├── api/
│   ├── Dockerfile               # API image (with renv)
│   ├── renv.lock                # R package lockfile
│   └── ...
└── app/
    ├── Dockerfile               # Frontend image
    └── ...
```

### Configuration Pattern: Base + Overrides

**Base: `docker-compose.yml`** (Production-ready, full stack)
```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0.29
    container_name: mysql
    command: mysqld --default-authentication-plugin=mysql_native_password
    restart: always
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    ports:
      - "7654:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./data/backup:/backup
    profiles: ["prod", "dev"]

  mysql-cron-backup:
    image: fradelg/mysql-cron-backup
    depends_on:
      - mysql
    volumes:
      - ./data/backup:/backup
    environment:
      MYSQL_HOST: mysql
      MYSQL_USER: root
      MYSQL_PASS: ${MYSQL_ROOT_PASSWORD}
      MAX_BACKUPS: 60
      INIT_BACKUP: 1
      CRON_TIME: "0 3 * * *"
      GZIP_LEVEL: 9
    restart: unless-stopped
    profiles: ["prod"]

  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: Rscript /sysndd_api_volume/start_sysndd_api.R
    restart: always
    volumes:
      - ./api:/sysndd_api_volume
      - renv_cache:/renv/cache
    ports:
      - "7777-7787:7777"
    environment:
      PASSWORD: ${PASSWORD}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      API_CONFIG: ${API_CONFIG}
      ENVIRONMENT: ${ENVIRONMENT:-production}
      RENV_PATHS_CACHE: /renv/cache
    depends_on:
      - mysql
    profiles: ["prod", "dev"]

  alb:
    image: dockercloud/haproxy:1.6.7
    links:
      - api
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
    profiles: ["prod"]

  app:
    build: ./app
    container_name: sysndd_app
    restart: always
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - api
    profiles: ["prod"]

volumes:
  mysql_data:
  renv_cache:
```

**Development: `docker-compose.dev.yml`** (Override for local dev)
```yaml
version: '3.8'

services:
  mysql:
    # Development uses same MySQL service but with dev profile
    profiles: ["dev"]

  api:
    # Override for development with file watching
    develop:
      watch:
        # Sync R source files (hot reload)
        - action: sync
          path: ./api/endpoints
          target: /sysndd_api_volume/endpoints
          ignore:
            - "*.log"

        - action: sync
          path: ./api/functions
          target: /sysndd_api_volume/functions
          ignore:
            - "*.log"

        # Restart on config changes
        - action: sync+restart
          path: ./api/config.yml
          target: /sysndd_api_volume/config.yml

        # Rebuild on dependency changes
        - action: rebuild
          path: ./api/renv.lock

    environment:
      ENVIRONMENT: local
      API_CONFIG: sysndd_db_local

    profiles: ["dev"]
```

**Test: `docker-compose.test.yml`** (Override for testing)
```yaml
version: '3.8'

services:
  mysql-test:
    image: mysql:8.0.29
    container_name: mysql-test
    command: mysqld --default-authentication-plugin=mysql_native_password
    tmpfs:
      - /var/lib/mysql  # Use tmpfs for faster tests
    environment:
      MYSQL_DATABASE: sysndd_test
      MYSQL_USER: test_user
      MYSQL_PASSWORD: test_password
      MYSQL_ROOT_PASSWORD: test_root_password
    ports:
      - "7655:3306"
    profiles: ["test"]

  api-test:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: Rscript -e "testthat::test_dir('tests/testthat')"
    volumes:
      - ./api:/sysndd_api_volume
      - renv_cache:/renv/cache
    environment:
      ENVIRONMENT: local
      API_CONFIG: sysndd_db_local
      RENV_PATHS_CACHE: /renv/cache
    depends_on:
      - mysql-test
    profiles: ["test"]

volumes:
  renv_cache:
```

**Source:** [Docker Compose Profiles](https://docs.docker.com/compose/profiles/), [Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/)

---

## Part 5: Docker Compose Usage Patterns

### Development Workflow (DB only, API runs locally)

```bash
# Start only MySQL database
docker-compose -f docker-compose.yml --profile dev up mysql

# In separate terminal, run API locally
cd api/
Rscript start_sysndd_api.R

# In third terminal, run frontend locally
cd app/
npm run serve
```

**Use when:** You want native R debugging, fast iteration, or IDE integration.

### Hybrid Development (DB + API in containers with hot-reload)

```bash
# Start MySQL and API with file watching
docker-compose -f docker-compose.yml \
               -f docker-compose.dev.yml \
               --profile dev \
               up --watch

# In separate terminal, run frontend locally
cd app/
npm run serve
```

**Use when:** You want consistent environment but still need frontend hot-reload.

**How watch works:**
- Editing `api/functions/*.R` → synced instantly to container
- Editing `api/endpoints/*.R` → synced instantly to container
- Editing `api/config.yml` → synced and container restarts
- Editing `api/renv.lock` → image rebuilds

**Source:** [Docker Compose Watch GA Release](https://www.docker.com/blog/announcing-docker-compose-watch-ga-release/)

### Full Stack Development (everything in containers)

```bash
# Start all services with file watching
docker-compose -f docker-compose.yml \
               -f docker-compose.dev.yml \
               --profile dev \
               up --watch
```

**Use when:** You need exact production parity or multi-developer consistency.

### Testing

```bash
# Run tests in container
docker-compose -f docker-compose.yml \
               -f docker-compose.test.yml \
               --profile test \
               run --rm api-test

# Or with coverage
docker-compose -f docker-compose.yml \
               -f docker-compose.test.yml \
               --profile test \
               run --rm api-test \
               Rscript -e "covr::package_coverage()"
```

**Use when:** CI/CD pipeline or verifying tests in production-like environment.

### Production

```bash
# Start full production stack
docker-compose --profile prod up -d
```

**Use when:** Deployment to production server.

---

## Part 6: renv Integration with Docker

### Strategy: Two-Stage Build for Cache Efficiency

**Dockerfile Pattern:**
```dockerfile
# Stage 1: Install R packages
FROM rocker/tidyverse:4.3.2 AS deps

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential git wget libpcre3 libpcre3-dev \
    libssl-dev zlib1g-dev cmake default-jdk \
    libsecret-1-dev libbz2-dev libicu-dev \
    liblzma-dev libsodium-dev libtool

# Install renv
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org')"

# Copy renv files first (for caching)
WORKDIR /sysndd_api_volume
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Restore packages to renv cache
# This layer is cached unless renv.lock changes
ENV RENV_PATHS_CACHE=/renv/cache
RUN mkdir -p /renv/cache
RUN R -e "renv::restore()"

# Stage 2: Copy application code
FROM rocker/tidyverse:4.3.2

# Install system dependencies (same as stage 1)
RUN apt-get update && apt-get install -y \
    build-essential git wget libpcre3 libpcre3-dev \
    libssl-dev zlib1g-dev cmake default-jdk \
    libsecret-1-dev libbz2-dev libicu-dev \
    liblzma-dev libsodium-dev libtool

# Copy renv cache from stage 1
COPY --from=deps /renv/cache /renv/cache

# Copy application files
WORKDIR /sysndd_api_volume
COPY . .

# Restore from cache (fast, links only)
ENV RENV_PATHS_CACHE=/renv/cache
RUN R -e "renv::restore()"

# Expose API port
EXPOSE 7777

# Start API
CMD ["Rscript", "start_sysndd_api.R"]
```

**Key Benefits:**
1. **Layer caching**: Package installation only re-runs if `renv.lock` changes
2. **Fast rebuilds**: Code changes don't trigger package reinstallation
3. **Shared cache**: Volume mount allows cache reuse across containers

**Source:** [Using renv with Docker](https://rstudio.github.io/renv/articles/docker.html), [renv Multi-stage Builds](https://github.com/robertdj/renv-docker)

### renv Cache Management

**Mount cache as volume** for development:
```yaml
services:
  api:
    volumes:
      - ./api:/sysndd_api_volume
      - renv_cache:/renv/cache  # Shared cache across rebuilds
    environment:
      RENV_PATHS_CACHE: /renv/cache
```

**Benefits:**
- Package downloads persist across container recreations
- Faster `docker-compose up` after first run
- Consistent package versions across dev/test/prod

**Trade-off:** Cache can grow large (100s of MB). Periodically clear with:
```bash
docker volume rm sysndd_renv_cache
```

---

## Part 7: Build Order and Setup Sequence

### Initial Project Setup (First Time)

```bash
# 1. Initialize renv in API directory
cd api/
Rscript -e "renv::init()"
Rscript -e "renv::snapshot()"

# 2. Create test structure
mkdir -p tests/testthat/fixtures/{entities,users,genes}
touch tests/testthat.R
touch tests/testthat/setup.R
touch tests/testthat/helper-api.R
touch tests/testthat/helper-database.R
touch tests/testthat/helper-auth.R

# 3. Generate testthat.R content
cat > tests/testthat.R << 'EOF'
# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(sysndd) # Replace with your package name if packaged

test_check("sysndd")
EOF

# 4. Build Docker images
docker-compose -f docker-compose.yml build

# 5. Start development environment
docker-compose -f docker-compose.yml \
               -f docker-compose.dev.yml \
               --profile dev \
               up mysql
```

### Adding New Functionality (Iterative)

**Order matters:**

1. **Write function** in `api/functions/my-functions.R`
2. **Write unit test** in `api/tests/testthat/test-my-functions.R`
3. **Run unit tests locally**: `Rscript -e "testthat::test_file('tests/testthat/test-my-functions.R')"`
4. **Write endpoint** in `api/endpoints/my_endpoints.R`
5. **Write integration test** in `api/tests/testthat/test-my-endpoints.R`
6. **Run integration tests**: (requires API running)
   ```bash
   # Terminal 1: Start API
   Rscript start_sysndd_api.R

   # Terminal 2: Run tests
   Rscript -e "testthat::test_file('tests/testthat/test-my-endpoints.R')"
   ```
7. **Run all tests**: `Rscript -e "testthat::test_dir('tests/testthat')"`
8. **Commit with passing tests**

### Adding New R Package Dependency

```bash
# 1. Install package in renv
cd api/
Rscript -e "install.packages('newpackage')"

# 2. Update lockfile
Rscript -e "renv::snapshot()"

# 3. Rebuild Docker image (renv.lock changed)
docker-compose -f docker-compose.yml build api

# 4. Restart containers
docker-compose -f docker-compose.yml \
               -f docker-compose.dev.yml \
               --profile dev \
               up --watch
```

**Note:** With watch mode, `renv.lock` changes trigger automatic rebuild.

---

## Part 8: Anti-Patterns to Avoid

### Testing Anti-Patterns

| Anti-Pattern | Why Bad | Instead |
|--------------|---------|---------|
| **Duplicate business logic in API tests** | Slow, brittle, unclear failures | Test logic in unit tests, only test HTTP contract in integration tests |
| **Hardcoded ports in tests** | Tests fail if port in use | Use `httpuv::randomPort()` in setup.R |
| **Shared mutable state between tests** | Tests pass/fail based on order | Use `local_*` helpers and `withr::defer()` for cleanup |
| **Testing against production database** | Dangerous, slow, non-isolated | Create temporary test database per run |
| **No skip conditions** | Tests fail when API isn't running | Use `skip_if_api_dead()` helper |
| **Large test files** | Hard to navigate, slow to run specific tests | Split by endpoint/function, one test file per source file |
| **Editing `testthat.R`** | Breaks automated test discovery | Use setup.R and helper files instead |

### Docker Anti-Patterns

| Anti-Pattern | Why Bad | Instead |
|--------------|---------|---------|
| **Single monolithic docker-compose.yml** | Can't selectively run services | Use profiles and override files |
| **Installing packages in Dockerfile without renv** | Version drift, non-reproducible | Use renv.lock and two-stage build |
| **Not using multi-stage builds** | Slow rebuilds on every code change | Separate package installation from code copy |
| **Bind mounting renv cache** | Cache corruption, permission issues | Use named volume for renv cache |
| **Not using watch mode in dev** | Manual restart after every change | Use docker-compose watch for sync |
| **Running tests in same container as dev** | Pollutes dev environment | Separate test profile with test database |

---

## Part 9: Performance Characteristics

### Test Execution Times (Expected)

| Test Type | Count | Time per Test | Total Time | Notes |
|-----------|-------|---------------|------------|-------|
| Unit (functions) | ~100-200 | 10-50ms | 2-10s | Fast, no external dependencies |
| Unit (database) | ~50-100 | 50-200ms | 5-20s | Requires temp DB creation |
| Integration (endpoints) | ~50-100 | 100-500ms | 10-50s | Requires running API |
| **Total** | **200-400** | **varied** | **~17-80s** | Acceptable for CI/CD |

**Optimization strategies:**
- Run unit tests first (fail fast)
- Run integration tests in parallel (if stateless)
- Use in-memory database (tmpfs) for tests
- Skip expensive tests in local dev (`skip_on_ci()`)

### Docker Build Times

| Operation | First Run | Cached Run | Trigger |
|-----------|-----------|------------|---------|
| Build API image (cold) | 10-15 min | - | `docker-compose build` |
| Build API image (warm) | 30s-2min | - | `renv.lock` changed |
| Sync code changes | - | <1s | `.R` file changed (watch mode) |
| Restart container | - | 2-5s | `config.yml` changed |
| Start MySQL | - | 5-10s | First startup |

**Source:** Empirical data from rocker/tidyverse builds and renv restore times

---

## Part 10: CI/CD Integration

### GitHub Actions Example

```yaml
name: R API Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Start test environment
        run: |
          docker-compose -f docker-compose.yml \
                         -f docker-compose.test.yml \
                         --profile test \
                         up -d mysql-test

      - name: Wait for MySQL
        run: |
          timeout 60 bash -c 'until docker-compose exec -T mysql-test mysqladmin ping --silent; do sleep 1; done'

      - name: Run tests
        run: |
          docker-compose -f docker-compose.yml \
                         -f docker-compose.test.yml \
                         --profile test \
                         run --rm api-test

      - name: Generate coverage
        run: |
          docker-compose -f docker-compose.yml \
                         -f docker-compose.test.yml \
                         --profile test \
                         run --rm api-test \
                         Rscript -e "covr::package_coverage()"

      - name: Cleanup
        if: always()
        run: |
          docker-compose -f docker-compose.yml \
                         -f docker-compose.test.yml \
                         --profile test \
                         down -v
```

---

## Roadmap Implications

### Phase Structure Recommendations

**Phase 1: Test Infrastructure Foundation**
- Set up testthat directory structure
- Write helper files (API, database, auth)
- Create setup.R for API startup
- Write first 5-10 unit tests (prove pattern works)
- **Why first:** Enables TDD for all subsequent work

**Phase 2: Unit Test Coverage**
- Test all 18 function files
- Focus on business logic (helper-functions, database-functions, endpoint-functions)
- Target 70%+ coverage of non-endpoint code
- **Why second:** Fast tests, no API dependency, builds confidence

**Phase 3: Integration Test Coverage**
- Test critical endpoints (authentication, entity, gene)
- Add fixtures for complex scenarios
- Test error conditions and edge cases
- **Why third:** Requires working unit tests, verifies API contract

**Phase 4: Docker Development Setup**
- Create docker-compose.dev.yml with profiles
- Add watch configuration for hot-reload
- Configure renv two-stage build
- Document developer workflows
- **Why fourth:** Tests prove code works, now optimize DX

**Phase 5: CI/CD Integration**
- Add docker-compose.test.yml
- Create GitHub Actions workflow
- Set up code coverage reporting
- Add pre-commit hooks
- **Why last:** Requires all previous phases working

### Dependency Chain

```
Phase 1 (Test structure)
    ↓
Phase 2 (Unit tests) ←──┐
    ↓                    │
Phase 3 (Integration) ───┤ (Can parallelize)
    ↓                    │
Phase 4 (Docker dev) ────┘
    ↓
Phase 5 (CI/CD)
```

**Critical path:** 1 → 2 → 3 → 5 (testing pipeline)
**Parallel work:** 4 can happen alongside 2-3

---

## Sources

### Official Documentation (HIGH Confidence)
- [R Packages (2e) - Testing Basics](https://r-pkgs.org/testing-basics.html)
- [R Packages (2e) - Designing Your Test Suite](https://r-pkgs.org/testing-design.html)
- [testthat 3.3.2 (Jan 2026)](https://cran.r-project.org/web/packages/testthat/testthat.pdf)
- [Test Fixtures - testthat](https://testthat.r-lib.org/articles/test-fixtures.html)
- [Docker Compose Profiles](https://docs.docker.com/compose/profiles/)
- [Docker Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/)
- [Using renv with Docker](https://rstudio.github.io/renv/articles/docker.html)

### Community Resources (MEDIUM-HIGH Confidence)
- [API as a Package: Testing - Jumping Rivers](https://www.jumpingrivers.com/blog/api-as-a-package-testing/)
- [Testing Plumber APIs from R - Jakub Sobolewski](https://jakubsobolewski.com/blog/plumber-api/)
- [Helper Code for Tests - R-hub](https://blog.r-hub.io/2020/11/18/testthat-utility-belt/)
- [Docker Compose Watch GA Release](https://www.docker.com/blog/announcing-docker-compose-watch-ga-release/)
- [renv + Docker Guide - robertdj](https://github.com/robertdj/renv-docker)

### Tools Referenced
- [callthat - Test Plumber APIs](https://edgararuiz.github.io/callthat/)
- [callr - Background R Processes](https://callr.r-lib.org/)
- [withr - Manage State](https://withr.r-lib.org/)
- [httpuv - Random Ports](https://github.com/rstudio/httpuv)
