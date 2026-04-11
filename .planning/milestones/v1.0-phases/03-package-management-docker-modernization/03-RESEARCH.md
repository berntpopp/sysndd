# Phase 3: Package Management + Docker Modernization - Research

**Researched:** 2026-01-21
**Domain:** R package management (renv), Docker development workflow, External API mocking
**Confidence:** HIGH (verified against official documentation and existing Docker Review Report)

## Summary

This phase modernizes the development environment across three domains: (1) R package reproducibility via renv, (2) hybrid development workflow with Docker Compose for databases and local R API, and (3) external API mocking for isolated testing.

The primary optimization opportunity is Dockerfile build time reduction from ~45 minutes to ~5 minutes through:
- Replacing `devtools::install_version()` with `pak` package manager
- Using Posit Package Manager (P3M) pre-compiled binaries
- Consolidating 34 separate RUN commands into grouped layers
- Implementing Docker Compose Watch for hot-reload development

The external API mocking focuses on PubMed (via easyPubMed) and PubTator3 APIs, using httptest2 fixtures stored in the test directory.

**Primary recommendation:** Implement renv with pak backend, create docker-compose.dev.yml for hybrid development, and add httptest2 fixtures for PubMed/PubTator3 API calls.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| renv | 1.0+ | R package version locking | Industry standard, replaces deprecated packrat |
| pak | 0.9+ | Fast R package installation | Parallel downloads, automatic binaries, modern |
| httptest2 | 1.0+ | HTTP request mocking | Official httr2 companion, records real responses |
| Docker Compose | 2.22+ | Container orchestration | Required for Watch feature |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| withr | 3.0+ | Test isolation | Already in setup.R, integrates with httptest2 |
| P3M | Latest | Pre-compiled R binaries | Always use for Linux amd64 Docker builds |
| rocker/r-ver | 4.4.2 | Base R Docker image | Lighter than tidyverse (~800MB vs ~2GB) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| renv | packrat | packrat is deprecated, renv is successor |
| pak | install.packages() | pak is 3-5x faster with parallel downloads |
| httptest2 | webmockr/vcr | httptest2 designed for httr2, simpler fixtures |
| P3M binaries | CRAN source | Source compilation adds 30-40 min to build |

**Installation:**
```bash
# In R (for renv initialization)
install.packages("renv")
renv::init()

# For httptest2 (add to DESCRIPTION Suggests)
install.packages("httptest2")
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── renv/                    # renv auto-loader
│   └── activate.R           # Auto-generated activation script
├── renv.lock                 # Package lockfile (version-pinned)
├── .Rprofile                 # Sources renv/activate.R
├── tests/
│   └── testthat/
│       ├── fixtures/         # httptest2 recorded responses
│       │   ├── pubmed/       # PubMed API fixtures
│       │   └── pubtator/     # PubTator3 API fixtures
│       ├── helper-mock-apis.R  # Mock setup helpers
│       └── setup.R           # Test initialization
├── Dockerfile                # Optimized multi-stage build
└── .dockerignore             # Exclude unnecessary files
```

### Pattern 1: renv Lockfile Workflow
**What:** PR author is responsible for updating renv.lock when adding packages
**When to use:** Every time a new package is added to the project
**Example:**
```r
# Developer workflow
# 1. Install new package
pak::pak("newpackage")

# 2. Update lockfile (required before PR)
renv::snapshot()

# 3. Commit both changes
# git add renv.lock DESCRIPTION
# git commit -m "feat: add newpackage for feature X"
```

### Pattern 2: Docker Compose Watch for R API
**What:** File sync from host to container without rebuild
**When to use:** During development for rapid iteration
**Example:**
```yaml
# docker-compose.dev.yml
services:
  api:
    develop:
      watch:
        - action: sync
          path: ./api/endpoints
          target: /app/endpoints
        - action: sync
          path: ./api/functions
          target: /app/functions
        - action: rebuild
          path: ./api/renv.lock
```

### Pattern 3: httptest2 Mock Directory Pattern
**What:** Record real API responses, replay in tests
**When to use:** Testing functions that call external APIs
**Example:**
```r
# Source: https://books.ropensci.org/http-testing/httptest2.html
# First run: records responses to fixtures/pubmed/
# Subsequent runs: replays recorded responses
httptest2::with_mock_dir("pubmed", {
  test_that("check_pmid validates real PMID", {
    result <- check_pmid("12345678")
    expect_true(result)
  })
})
```

### Anti-Patterns to Avoid
- **Committing renv cache:** Only commit renv.lock and renv/activate.R, not the library
- **Using HTTP for CRAN repos:** Always use HTTPS (current Dockerfile uses HTTP)
- **One RUN per package:** Consolidate into grouped layers for caching efficiency
- **Bind mounts for everything:** Use Docker Compose Watch sync action instead

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP request recording | Custom mock objects | httptest2::with_mock_dir() | Handles JSON parsing, file paths, redaction |
| Package version pinning | Manual version checks | renv.lock | Automatic dependency resolution, transitive deps |
| Binary package detection | Conditional installation | pak (auto-detects) | Knows when binaries available for platform |
| System deps detection | Manual apt-get lists | pak::pkg_system_requirements() | Queries P3M database automatically |
| File watching in Docker | inotify scripts | Docker Compose Watch | Native integration, cross-platform |

**Key insight:** R's package ecosystem has solved reproducibility with renv + pak. Don't try to manage versions manually in Dockerfiles.

## Common Pitfalls

### Pitfall 1: renv Lockfile Merge Conflicts
**What goes wrong:** Multiple developers modify renv.lock, creating JSON merge conflicts
**Why it happens:** renv.lock is a large JSON file with many lines per package
**How to avoid:**
- Accept both changes, then run `renv::snapshot()` to regenerate
- Alternatively: accept theirs, install your new packages, re-snapshot
**Warning signs:** Git conflict markers in renv.lock during merge

### Pitfall 2: P3M Binary Architecture Mismatch
**What goes wrong:** Build fails or packages don't work on ARM64 Macs
**Why it happens:** P3M only provides binaries for amd64, not arm64
**How to avoid:**
- Document that Docker builds target linux/amd64
- Use `--platform linux/amd64` explicitly in docker build
- Accept longer build times on Apple Silicon for local development
**Warning signs:** Compilation errors for packages that should be pre-built

### Pitfall 3: httptest2 Fixtures Contain Secrets
**What goes wrong:** API keys or tokens recorded in fixture files
**Why it happens:** httptest2 captures full request/response by default
**How to avoid:**
- Use `httptest2::set_redactor()` to scrub sensitive data
- Review fixtures before committing
- Use environment variable placeholders in tests
**Warning signs:** Credential patterns in tests/testthat/fixtures/ files

### Pitfall 4: Docker Compose Watch Not Triggering
**What goes wrong:** File changes don't sync to container
**Why it happens:** Watch paths must be relative to compose file location
**How to avoid:**
- Use `./api/` not `/absolute/path`
- Ensure file extensions match sync patterns
- Check Docker Desktop version (requires 4.24+)
**Warning signs:** Container shows old code after saving

### Pitfall 5: renv Restore Slow in CI
**What goes wrong:** CI builds take 20+ minutes for package restore
**Why it happens:** No cache between builds, downloads from source
**How to avoid:**
- Enable `RENV_CONFIG_PAK_ENABLED=TRUE` for faster installation
- Configure CI cache for renv library path
- Use P3M binaries (set repos option)
**Warning signs:** "Installing from source" messages for common packages

## Code Examples

Verified patterns from official sources:

### renv Initialization
```r
# Source: https://rstudio.github.io/renv/articles/renv.html
# Initialize renv in existing project
renv::init()

# After initialization, .Rprofile will contain:
source("renv/activate.R")

# Install packages (use pak for speed)
options(renv.config.pak.enabled = TRUE)
pak::pak("plumber")

# Snapshot to lockfile
renv::snapshot()

# Restore from lockfile (for new clones)
renv::restore()
```

### Optimized Dockerfile with renv
```dockerfile
# Source: https://rstudio.github.io/renv/articles/docker.html
# syntax=docker/dockerfile:1.4
FROM rocker/r-ver:4.4.2 AS base

# Enable pak for faster installation
ENV RENV_CONFIG_PAK_ENABLED=TRUE
ENV RENV_PATHS_CACHE=/renv_cache

# Install system dependencies (consolidated)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    libmariadb-dev default-jdk libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Install renv
RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")'

WORKDIR /app

# Copy lockfile first for layer caching
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R

# Restore packages with cache mount
RUN --mount=type=cache,target=/renv_cache \
    R -e 'renv::restore()'

# Copy application code
COPY . .

CMD ["Rscript", "start_sysndd_api.R"]
```

### docker-compose.dev.yml with Watch
```yaml
# Source: https://docs.docker.com/compose/how-tos/file-watch/
# Database services for hybrid development
services:
  mysql-dev:
    image: mysql:8.0.40
    container_name: sysndd_mysql_dev
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE:-sysndd_db}
      MYSQL_USER: ${MYSQL_USER:-bernt}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-Nur7DoofeFliegen.}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root}
    ports:
      - "7654:3306"
    volumes:
      - mysql_dev_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  mysql-test:
    image: mysql:8.0.40
    container_name: sysndd_mysql_test
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: sysndd_db_test
      MYSQL_USER: ${MYSQL_USER:-bernt}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-Nur7DoofeFliegen.}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root}
    ports:
      - "7655:3306"
    volumes:
      - mysql_test_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysql_dev_data:
    name: sysndd_mysql_dev_data
  mysql_test_data:
    name: sysndd_mysql_test_data
```

### httptest2 Setup for External API Mocking
```r
# Source: https://books.ropensci.org/http-testing/httptest2.html
# tests/testthat/helper-mock-apis.R

# Set up redactor to remove sensitive data from fixtures
httptest2::set_redactor(function(resp) {
  # Redact any API keys in headers
  resp <- httptest2::gsub_response(
    resp,
    "api_key=[^&]+",
    "api_key=REDACTED"
  )
  resp
})

# Helper to use PubMed mock directory
with_pubmed_mock <- function(code) {
  httptest2::with_mock_dir(
    test_path("fixtures", "pubmed"),
    code
  )
}

# Helper to use PubTator mock directory
with_pubtator_mock <- function(code) {
  httptest2::with_mock_dir(
    test_path("fixtures", "pubtator"),
    code
  )
}
```

### Test Example with httptest2
```r
# Source: https://enpiar.com/httptest2/articles/httptest2.html
# tests/testthat/test-external-pubmed.R

test_that("check_pmid returns TRUE for valid PMID", {
  with_pubmed_mock({
    # First run records to fixtures/pubmed/
    # Subsequent runs replay recorded response
    result <- check_pmid("12345678")
    expect_true(result)
  })
})

test_that("check_pmid returns FALSE for invalid PMID", {
  with_pubmed_mock({
    result <- check_pmid("0000000")
    expect_false(result)
  })
})

test_that("pubtator_v3_total_pages_from_query returns page count", {
  with_pubtator_mock({
    query <- '("intellectual disability" OR "epilepsy")'
    pages <- pubtator_v3_total_pages_from_query(query)
    expect_type(pages, "integer")
    expect_gt(pages, 0)
  })
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| packrat | renv | 2019 | renv is official replacement |
| devtools::install_version() | pak::pak("pkg@version") | 2023 | 3-5x faster, parallel |
| MRAN (Microsoft R Archive) | P3M (Posit Package Manager) | 2022 | MRAN deprecated July 2023 |
| docker-compose.yml version: | (omit version field) | 2023 | Version field now obsolete |
| Volume mounts for hot reload | Docker Compose Watch | 2023 | Native cross-platform support |
| httptest (httr) | httptest2 (httr2) | 2022 | httr2 is modern replacement |

**Deprecated/outdated:**
- **packrat**: Use renv instead (packrat officially deprecated)
- **MRAN**: Microsoft shut down July 2023, use P3M for binary packages
- **HTTP CRAN repos**: Security risk, always use HTTPS
- **docker-compose version field**: Ignored by modern Docker Compose, remove it

## Open Questions

Things that couldn't be fully resolved:

1. **renv lockfile merge conflict resolution automation**
   - What we know: Manual resolution works (accept both, re-snapshot)
   - What's unclear: Can git merge driver automate this?
   - Recommendation: Document manual process; automation is low priority

2. **httptest2 recording live responses for PubTator**
   - What we know: httptest2 records HTTP responses automatically
   - What's unclear: Does PubTator3's non-standard JSON format (newline-separated) record correctly?
   - Recommendation: Test with simple endpoint first, then complex ones

3. **Docker Compose Watch performance on WSL2**
   - What we know: Watch uses inotify-based file watching
   - What's unclear: WSL2 file system performance for watch events
   - Recommendation: Test and document any latency; may need WATCHPACK_POLLING=true

## Sources

### Primary (HIGH confidence)
- [renv Docker integration](https://rstudio.github.io/renv/articles/docker.html) - Official renv documentation
- [Docker Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/) - Official Docker documentation
- [httptest2 documentation](https://enpiar.com/httptest2/articles/httptest2.html) - Package author documentation
- [Rocker extending images](https://rocker-project.org/use/extending.html) - Official Rocker project
- [pak package](https://pak.r-lib.org/) - Official pak documentation
- [P3M binary serving](https://docs.posit.co/rspm/admin/serving-binaries.html) - Posit official docs

### Secondary (MEDIUM confidence)
- [HTTP testing in R book](https://books.ropensci.org/http-testing/httptest2.html) - rOpenSci comprehensive guide
- [renv-docker guide](https://github.com/robertdj/renv-docker) - Community best practices
- [Docker hot reloading 2026](https://oneuptime.com/blog/post/2026-01-06-docker-hot-reloading/view) - Recent guidance

### Tertiary (LOW confidence)
- Docker Review Report (.plan/DOCKER-REVIEW-REPORT.md) - Internal document, well-researched

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are well-documented, actively maintained
- Architecture: HIGH - Patterns verified against official documentation
- Pitfalls: MEDIUM - Some based on community experience, not all personally verified

**Research date:** 2026-01-21
**Valid until:** 2026-02-21 (30 days - stable technologies)

---

## Appendix: External APIs to Mock

Based on code analysis, the following external APIs need httptest2 fixtures:

### PubMed API (via easyPubMed)
**Functions using it:**
- `check_pmid()` in `functions/publication-functions.R`
- `info_from_pmid()` in `functions/publication-functions.R`

**Endpoints:**
- `get_pubmed_ids(query)` - NCBI E-utilities search
- `fetch_pubmed_data(ids)` - NCBI E-utilities fetch

**Fixture files needed:**
- `fixtures/pubmed/valid-pmid.json` - Response for valid PMID lookup
- `fixtures/pubmed/invalid-pmid.json` - Response for non-existent PMID
- `fixtures/pubmed/batch-lookup.json` - Response for batch PMID fetch

### PubTator3 API
**Functions using it:**
- `pubtator_v3_total_pages_from_query()` in `functions/pubtator-functions.R`
- `pubtator_v3_pmids_from_request()` in `functions/pubtator-functions.R`
- `pubtator_v3_data_from_pmids()` in `functions/pubtator-functions.R`

**Endpoints:**
- `https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/?text=...` - Search
- `https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson?pmids=...` - Annotations

**Fixture files needed:**
- `fixtures/pubtator/search-page1.json` - First page of search results
- `fixtures/pubtator/search-empty.json` - Empty search results
- `fixtures/pubtator/annotations-single.json` - Annotations for single PMID
- `fixtures/pubtator/annotations-batch.json` - Annotations for multiple PMIDs

**Note:** PubTator3 returns non-standard JSON (newline-separated objects). The `pubtator_v3_parse_nonstandard_json()` function handles this. Fixtures may need manual formatting.

---

## Appendix: Dockerfile Optimization Summary

From the Docker Review Report, key optimizations:

| Current | Optimized | Impact |
|---------|-----------|--------|
| 34 separate RUN commands | 3-4 grouped layers | -60% image size |
| devtools::install_version() | pak::pak() | -70% install time |
| HTTP CRAN repos | HTTPS + P3M | Security + binaries |
| rocker/tidyverse | rocker/r-ver | -60% base image size |
| No .dockerignore | With .dockerignore | -50% build context |

**Target build time:** ~5 minutes (from current ~45 minutes)
