# Phase 18: Foundation - Research

**Researched:** 2026-01-23
**Domain:** R version upgrade (4.1.2 to 4.4.3), renv migration, Docker base image modernization
**Confidence:** HIGH

## Summary

Phase 18 addresses the critical R upgrade from 4.1.2 to 4.4.3, which is the foundation for all subsequent v4 backend work. The primary challenges are:

1. **Matrix/lme4 ABI compatibility** - The current Dockerfile uses a 2022-01-03 P3M snapshot workaround because Matrix 1.4-0 is incompatible with modern lme4. With R 4.4.x, Matrix 1.7-0+ becomes available, eliminating this workaround.

2. **Docker base image transition** - rocker/r-ver:4.4.3 uses Ubuntu 22.04 (jammy) instead of 20.04 (focal), requiring P3M URL updates.

3. **Fresh renv.lock creation** - The current renv.lock is incomplete (requires manual package installs in Dockerfile). A fresh renv.lock on R 4.4.x will properly capture all dependencies.

**Primary recommendation:** Create a fresh renv.lock on R 4.4.3 locally, test in Docker, then update Dockerfile to remove all workarounds.

## Standard Stack

The established libraries/tools for this domain:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| R | 4.4.3 | Runtime environment | Latest stable (Feb 2025) |
| rocker/r-ver | 4.4.3 | Docker base image | Official R Docker images, uses Ubuntu 22.04 |
| renv | 1.1.0+ | Package management | Industry standard for reproducibility |
| Matrix | 1.7-0+ | Sparse/dense matrices | Bundled with R 4.4, ABI version 2 |
| lme4 | 1.1-38+ | Mixed-effects models | FactoMineR dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| P3M | jammy/latest | Binary packages | Ubuntu 22.04 pre-compiled binaries |
| BiocManager | 1.30.25+ | Bioconductor | STRINGdb, biomaRt installation |
| FactoMineR | latest | MCA/clustering | analysis_endpoints.R |
| factoextra | latest | Clustering viz | analysis_endpoints.R |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| rocker/r-ver | r2u | r2u is faster but less mature for production |
| renv | conda | renv is R-native, better ecosystem integration |
| P3M | CRAN source | P3M provides pre-compiled binaries (10x faster) |

**Installation:**
```bash
# Base image (Dockerfile)
FROM rocker/r-ver:4.4.3

# P3M URL for Ubuntu 22.04 (jammy)
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"
```

## Architecture Patterns

### Recommended Docker Structure
```
api/
├── Dockerfile           # Multi-stage build (no workarounds)
├── renv.lock           # Fresh lock on R 4.4.x
├── renv/
│   ├── activate.R      # renv bootstrapper
│   └── settings.json   # renv configuration
└── .Rprofile           # Sources renv/activate.R
```

### Pattern 1: Fresh renv.lock Creation
**What:** Generate a new lockfile on the target R version
**When to use:** Major R version upgrades (4.1 to 4.4)
**Example:**
```r
# Source: https://rstudio.github.io/renv/articles/renv.html
# On machine with R 4.4.x installed

# Option A: Initialize fresh
renv::init(bare = TRUE)
renv::install(c("plumber", "RMariaDB", "tidyverse", ...))
BiocManager::install(c("STRINGdb", "biomaRt"))
renv::snapshot()

# Option B: Update existing
renv::upgrade()  # Update renv itself
renv::update()   # Update all packages
renv::snapshot() # Save new lockfile
```

### Pattern 2: Docker Multi-Stage with renv
**What:** Clean renv::restore() without manual workarounds
**When to use:** Production Docker builds
**Example:**
```dockerfile
# Source: https://rstudio.github.io/renv/articles/docker.html
FROM rocker/r-ver:4.4.3 AS base
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"

# Install renv
RUN R -e 'install.packages("renv")'

FROM base AS packages
WORKDIR /app
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Single restore command - no workarounds needed
RUN --mount=type=cache,target=/renv_cache \
    R --vanilla -s -e 'renv::restore()'
```

### Pattern 3: Matrix/lme4 ABI Handling
**What:** Let R 4.4.x provide compatible Matrix, rebuild lme4
**When to use:** R upgrades involving Matrix changes
**Example:**
```r
# Source: https://github.com/lme4/lme4/issues/768
# With R 4.4.3, Matrix 1.7-0 is available

# In renv.lock, ensure:
# - Matrix version >= 1.6.3
# - lme4 version >= 1.1-35

# The ABI version mismatch warning will NOT appear if both
# are installed from the same P3M snapshot on R 4.4.x
```

### Anti-Patterns to Avoid

- **Manual package installs in Dockerfile:** If renv.lock is complete, `renv::restore()` should install everything. Manual installs indicate incomplete lockfile.
- **P3M snapshot workarounds:** Using old snapshots (like 2022-01-03) for compatibility should not be needed with R 4.4.x.
- **Installing packages to site-library:** Use renv's project library path, not system paths.
- **Mixing renv::restore() with direct install.packages():** This breaks reproducibility.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| R version management | Manual R install | rocker/r-ver tagged images | Pre-configured, tested |
| Package binary compilation | Source compilation | P3M pre-compiled binaries | 10x faster builds |
| Dependency resolution | Manual version pinning | renv::snapshot() | Captures transitive deps |
| Matrix ABI tracking | Manual version checks | renv handles this | ABI tracked in lockfile metadata |

**Key insight:** The current Dockerfile complexity exists because renv.lock is incomplete. A properly created renv.lock on R 4.4.x eliminates all workarounds.

## Common Pitfalls

### Pitfall 1: Matrix Package ABI Breaking Changes
**What goes wrong:** After upgrading R, lme4/FactoMineR fail with "function 'cholmod_factor_ldetA' not provided by package 'Matrix'"
**Why it happens:** Matrix 1.7-0 (for R 4.4+) has ABI version 2; packages compiled against Matrix 1.4-0 (ABI version 0) are incompatible.
**How to avoid:**
1. Create fresh renv.lock on R 4.4.x (not upgrade existing lock)
2. Ensure all packages are installed from same P3M snapshot
3. Remove 2022-01-03 snapshot workaround from Dockerfile
**Warning signs:** `Error in initializePtr()`, CHOLMOD errors at startup

### Pitfall 2: renv Restore Failures After R Upgrade
**What goes wrong:** `renv::restore()` fails repeatedly, requiring manual intervention for each package
**Why it happens:** Old renv.lock references package versions incompatible with R 4.4.x
**How to avoid:**
1. Don't try to upgrade existing renv.lock - create fresh
2. Test restore in Docker before committing changes
3. Ensure Bioconductor version is compatible (3.18 or 3.19 for R 4.4)
**Warning signs:** "Package X was installed before R 4.0.0: please re-install"

### Pitfall 3: P3M URL Mismatch
**What goes wrong:** Package installation fails or downloads wrong binaries
**Why it happens:** Using focal (Ubuntu 20.04) URL with jammy (22.04) base image
**How to avoid:**
1. Match P3M URL to Ubuntu version: jammy for R 4.4.3
2. Use consistent URLs throughout Dockerfile
**Warning signs:** Binary package not found, falls back to source compilation

### Pitfall 4: Incomplete Test Coverage After Upgrade
**What goes wrong:** API appears to start but clustering endpoints return wrong results
**Why it happens:** Subtle behavioral changes in lme4/FactoMineR not caught by tests
**How to avoid:**
1. Run all existing tests BEFORE upgrade (baseline)
2. Run all tests AFTER upgrade
3. Specifically test MCA/HCPC endpoints with known data
**Warning signs:** Numerical differences in clustering results

## Code Examples

Verified patterns from official sources:

### Dockerfile Base Image Update
```dockerfile
# Source: https://hub.docker.com/r/rocker/r-ver/tags
# BEFORE (R 4.1.2 with Ubuntu 20.04)
FROM rocker/r-ver:4.1.2 AS base
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# AFTER (R 4.4.3 with Ubuntu 22.04)
FROM rocker/r-ver:4.4.3 AS base
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"
```

### Creating Fresh renv.lock
```r
# Source: https://rstudio.github.io/renv/articles/renv.html
# Run on local machine with R 4.4.x installed

# 1. Start fresh
renv::init(bare = TRUE)

# 2. Install all packages needed by the API
# Core packages
renv::install(c(
  "plumber", "RMariaDB", "pool", "DBI",
  "tidyverse", "jsonlite", "jose", "config",
  "logger", "tictoc", "fs", "memoise"
))

# Additional packages from start_sysndd_api.R
renv::install(c(
  "biomaRt", "RCurl", "stringdist", "xlsx",
  "easyPubMed", "xml2", "rvest", "lubridate",
  "coop", "reshape2", "blastula", "keyring",
  "future", "knitr", "rlang", "timetk",
  "factoextra", "FactoMineR", "vctrs", "httr",
  "ellipsis", "ontologyIndex", "dotenv"
))

# Bioconductor packages
BiocManager::install(c("STRINGdb", "biomaRt"))

# Testing packages
renv::install(c(
  "testthat", "dittodb", "withr", "httr2"
))

# 3. Snapshot
renv::snapshot()
```

### Simplified Dockerfile (After Fresh renv.lock)
```dockerfile
# Source: https://rstudio.github.io/renv/articles/docker.html
# No more workarounds needed

FROM rocker/r-ver:4.4.3 AS base

ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"
ENV RENV_CONFIG_PAK_ENABLED=FALSE
ENV RENV_PATHS_CACHE=/renv_cache
ENV RENV_CONFIG_CACHE_SYMLINKS=FALSE

# System dependencies (same as before)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl build-essential libssl-dev libcurl4-openssl-dev \
    libxml2-dev libmariadb-dev libmysqlclient21 \
    default-jdk libsodium-dev libpcre3-dev libicu-dev \
    libbz2-dev liblzma-dev zlib1g-dev git libsecret-1-dev \
    gfortran libglpk-dev libpng-dev cmake pandoc libx11-dev \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

RUN R -e 'install.packages("renv")'

FROM base AS packages
WORKDIR /app

COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Single restore - everything in renv.lock
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    R --vanilla -s -e 'renv::restore()'

# NO MORE:
# - Manual install.packages() calls
# - 2022-01-03 P3M snapshot workaround
# - BiocManager::install() calls
```

### Testing MCA/lme4 After Upgrade
```r
# Source: api/endpoints/analysis_endpoints.R
# Test that clustering still works correctly

test_that("MCA clustering works after R upgrade", {
  # Create test data similar to phenotype_clustering
  test_data <- data.frame(
    inheritance = c("AD", "AD", "AR", "AR"),
    id_count = c(1, 2, 1, 3),
    non_id_count = c(3, 2, 4, 1),
    feature1 = c("yes", "no", "yes", "no"),
    row.names = c("E1", "E2", "E3", "E4")
  )

  # This should not throw an error
  expect_no_error({
    mca_result <- FactoMineR::MCA(test_data,
      ncp = 2,
      quali.sup = 1,
      quanti.sup = 2:3,
      graph = FALSE
    )
  })

  # HCPC should also work
  expect_no_error({
    hcpc_result <- FactoMineR::HCPC(mca_result,
      nb.clust = 2,
      graph = FALSE
    )
  })
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| R 4.1.2 with Matrix 1.4-0 | R 4.4.3 with Matrix 1.7-0 | R 4.4.0 (April 2024) | ABI version 2, lme4 compatible |
| Ubuntu 20.04 (focal) | Ubuntu 22.04 (jammy) | rocker images for R >= 4.2 | P3M URL changes |
| P3M focal snapshots | P3M jammy/latest | With jammy images | Better binary availability |
| Manual Dockerfile workarounds | Complete renv.lock | Best practice | Reproducible builds |

**Deprecated/outdated:**
- **P3M 2022-01-03 snapshot:** This workaround was needed for FactoMineR/lme4 on R 4.1.2 but is unnecessary on R 4.4.3
- **Matrix 1.4-0:** Bundled with R 4.1.2, incompatible with modern lme4 (ABI version 0)
- **Ubuntu 20.04 focal:** Still works but rocker moved to jammy for R >= 4.2

## Open Questions

Things that couldn't be fully resolved:

1. **Bioconductor Version for R 4.4.3**
   - What we know: BiocManager::install() auto-detects, likely 3.18 or 3.19
   - What's unclear: Exact version compatibility with STRINGdb/biomaRt
   - Recommendation: Let BiocManager auto-select, verify in Docker test

2. **R 4.4.3 NCOL(NULL) Behavior**
   - What we know: R 4.4.0+ changed `NCOL(NULL)` from 1 to 0
   - What's unclear: Whether current code relies on old behavior
   - Recommendation: Grep codebase for NCOL usage, test manually

3. **libmysqlclient21 Availability on jammy**
   - What we know: Ubuntu 22.04 may use different MySQL client library
   - What's unclear: Whether current apt package name works
   - Recommendation: Test Docker build, may need to adjust package name

## Sources

### Primary (HIGH confidence)
- [R 4.4.3 Release Announcement](https://stat.ethz.ch/pipermail/r-announce/2025/000708.html) - Release details
- [Matrix Package NEWS](https://cran.r-project.org/web/packages/Matrix/news.html) - ABI version changes
- [lme4 Matrix ABI Documentation](https://github.com/lme4/lme4/issues/768) - ABI compatibility
- [Rocker r-ver Images](https://rocker-project.org/images/versioned/r-ver) - Docker base images
- [renv Documentation](https://rstudio.github.io/renv/articles/renv.html) - Package management
- [renv Docker Article](https://rstudio.github.io/renv/articles/docker.html) - Docker integration

### Secondary (MEDIUM confidence)
- [Posit Package Manager](https://packagemanager.posit.co/__docs__/admin/serving-binaries.html) - P3M jammy URLs
- [Rocker GitHub Issue #282](https://github.com/rocker-org/rocker-versioned2/issues/282) - Ubuntu 22.04 switch
- [Databricks lme4 Matrix Guide](https://kb.databricks.com/libraries/installing-lme4-fails-with-a-matrix-version-error) - Troubleshooting

### Tertiary (LOW confidence)
- Project-specific prior research: `.planning/research/STACK-v4-backend.md`
- Project-specific pitfalls: `.planning/research/PITFALLS-backend-v4.md`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official documentation verified
- Architecture: HIGH - renv + Docker patterns well-documented
- Pitfalls: HIGH - Documented in lme4/Matrix issues, observed in current Dockerfile

**Research date:** 2026-01-23
**Valid until:** 2026-04-23 (R 4.4.x should remain stable for 3+ months)
