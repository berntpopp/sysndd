# Phase 7: API Dockerfile Optimization - Research

**Researched:** 2026-01-22
**Domain:** Docker image optimization, R package management, BuildKit caching
**Confidence:** HIGH (verified against official documentation and rocker project)

## Summary

This research investigates how to optimize the SysNDD API Dockerfile to reduce build time from approximately 45 minutes to under 5 minutes while improving security and reducing image size. The current Dockerfile already uses rocker/r-ver:4.1.2 with Posit Package Manager and renv, but lacks multi-stage builds, ccache, proper debug symbol stripping, a health check endpoint, and non-root user configuration.

Key findings:
1. **Keep R 4.1.2** - Upgrading to R 4.4.x would break FactoMineR/Matrix dependency chain (Matrix 1.4-0 requires R <= 4.1.x compatible lme4)
2. **Keep renv for reproducibility** - The current renv.lock approach is sound; pak should only be used for supplementary packages not in the lockfile
3. **Multi-stage builds** are essential for separating build dependencies from runtime
4. **ccache with BuildKit cache mounts** can dramatically reduce rebuild times
5. **Health check endpoint** requires adding a simple /health route to the Plumber API

**Primary recommendation:** Implement a 3-stage Dockerfile (base -> packages -> production) with ccache, debug symbol stripping, and non-root user while keeping the current R 4.1.2 + renv approach for package management.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| rocker/r-ver | 4.1.2 | R base image | Lighter than tidyverse, Ubuntu 20.04 focal base |
| Posit Package Manager | latest | Pre-compiled R binaries | 10x faster than source compilation |
| renv | 1.0.x | Reproducible package management | Version locking via renv.lock |
| pak | 0.8.x | Supplementary package installation | Parallel, binary-preferring, Bioconductor support |
| ccache | 4.x | C/C++ compilation caching | 30-40% faster rebuilds |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| BuildKit | Docker build features | Cache mounts for incremental builds |
| curl | Health check utility | Required for HEALTHCHECK instruction |
| strip | Debug symbol removal | Reduce .so file sizes by 20-30% |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| renv | pak only | Loss of exact version reproducibility from lockfile |
| R 4.1.2 | R 4.4.2 | Breaking FactoMineR dependency chain (Matrix version conflict) |
| Multi-stage | Single stage | Larger image, build deps in production |

**Installation (system deps):**
```bash
apt-get install -y --no-install-recommends \
    ccache curl build-essential \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    libmariadb-dev libmysqlclient21 default-jdk \
    libsodium-dev libpcre3-dev libicu-dev \
    libbz2-dev liblzma-dev zlib1g-dev libglpk-dev \
    libpng-dev libsecret-1-dev gfortran cmake pandoc
```

## Architecture Patterns

### Recommended Multi-Stage Dockerfile Structure
```
FROM rocker/r-ver:4.1.2 AS base
    # System dependencies
    # ccache configuration
    # R environment setup

FROM base AS packages
    # renv restore from lockfile
    # pak for supplementary packages
    # BiocManager for Bioconductor
    # Strip debug symbols

FROM base AS production
    # Copy R libraries from packages stage
    # Create non-root user
    # Copy application code
    # HEALTHCHECK instruction
    # USER directive
```

### Pattern 1: BuildKit Cache Mounts for R Packages
**What:** Persist package cache between builds to avoid re-downloading
**When to use:** Always for local development; limited benefit in ephemeral CI
**Example:**
```dockerfile
# syntax=docker/dockerfile:1.4
ENV RENV_PATHS_CACHE=/renv_cache
ENV RENV_CONFIG_CACHE_SYMLINKS=FALSE

RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'renv::restore()'
```
Source: [BuildKit cache with renv](https://github.com/howisonlab/test_repo_buildx_renv)

### Pattern 2: ccache Configuration for R
**What:** Cache compiled C/C++ objects for faster rebuilds
**When to use:** When packages require compilation (Rcpp, igraph, etc.)
**Example:**
```dockerfile
# Configure ccache
RUN mkdir -p ~/.R ~/.ccache && \
    echo 'CCACHE=ccache' > ~/.R/Makevars && \
    echo 'CC=$(CCACHE) gcc' >> ~/.R/Makevars && \
    echo 'CXX=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX11=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX14=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX17=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'FC=$(CCACHE) gfortran' >> ~/.R/Makevars && \
    echo 'F77=$(CCACHE) gfortran' >> ~/.R/Makevars && \
    echo 'max_size = 2.0G' > ~/.ccache/ccache.conf && \
    echo 'sloppiness = include_file_ctime' >> ~/.ccache/ccache.conf && \
    echo 'hash_dir = false' >> ~/.ccache/ccache.conf
```
Source: [ccache for R](http://dirk.eddelbuettel.com/blog/2017/11/27/)

### Pattern 3: Non-Root User Setup
**What:** Run container as unprivileged user
**When to use:** Always in production for security
**Example:**
```dockerfile
# Create non-root user with specific UID/GID
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser

# Set ownership before switching user
COPY --chown=apiuser:api . /app/

USER apiuser
```
Source: [Docker USER instruction](https://www.docker.com/blog/understanding-the-docker-user-instruction/)

### Pattern 4: HEALTHCHECK for Plumber API
**What:** Docker health monitoring via HTTP endpoint
**When to use:** Always for orchestration compatibility
**Example:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:7777/health || exit 1
```
Source: [Plumber health endpoints](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html)

### Anti-Patterns to Avoid
- **Multiple small RUN layers for package installation:** Creates unnecessary layers, prevents optimization
- **HTTP CRAN repos:** Security risk (MITM attacks) - always use HTTPS
- **Running as root:** Security vulnerability if container is compromised
- **No cache mounts:** Rebuilds download all packages every time
- **Skipping debug symbol stripping:** Unnecessary bloat in production

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package version management | Custom version pinning scripts | renv with renv.lock | Handles transitive dependencies, snapshots |
| Fast binary installation | Source compilation | Posit Package Manager | Pre-compiled binaries are 10x faster |
| Compilation caching | Custom caching logic | ccache + BuildKit mounts | Battle-tested, works with R's Makevars |
| Health checks | Custom monitoring | Docker HEALTHCHECK + /health endpoint | Native orchestration integration |
| System deps detection | Manual dependency lists | pak::pkg_system_requirements() | Automatic detection from package metadata |

**Key insight:** R package installation is the primary bottleneck. Using binaries from Posit Package Manager with ccache for packages that must compile is the optimal strategy.

## Common Pitfalls

### Pitfall 1: R Version Upgrade Breaking Dependencies
**What goes wrong:** Upgrading from R 4.1.2 to R 4.4.x breaks FactoMineR installation
**Why it happens:** Matrix 1.4-0 in renv.lock requires lme4 compatible versions; newer R versions ship with Matrix 1.5+ which has breaking API changes
**How to avoid:** Stay on R 4.1.2 with the 2022-01-03 P3M snapshot for FactoMineR dependencies
**Warning signs:** lme4 installation errors mentioning Matrix version conflicts

### Pitfall 2: ccache Not Working in Docker
**What goes wrong:** ccache directory is empty/flushed between builds
**Why it happens:** Docker layers are immutable; ccache needs persistent storage
**How to avoid:** Use BuildKit cache mounts: `--mount=type=cache,target=/root/.ccache`
**Warning signs:** Compilation takes same time on rebuilds; `ccache -s` shows 0 hits

### Pitfall 3: P3M Binaries Not Available
**What goes wrong:** Packages compile from source despite P3M configuration
**Why it happens:** Bioconductor packages, arm64 platform, or very new packages lack binaries
**How to avoid:** Accept that STRINGdb/biomaRt will compile; plan for longer Bioconductor stage
**Warning signs:** "Building from source" messages for CRAN packages on amd64

### Pitfall 4: RENV_CONFIG_CACHE_SYMLINKS Issue
**What goes wrong:** Packages work during build but missing at runtime
**Why it happens:** BuildKit cache mounts only exist during build; symlinks point to nowhere
**How to avoid:** Set `RENV_CONFIG_CACHE_SYMLINKS=FALSE` to copy packages instead
**Warning signs:** "Package not found" errors when container runs

### Pitfall 5: Non-Root User Permission Errors
**What goes wrong:** API fails to start with permission denied errors
**Why it happens:** R writes to library paths or log directories owned by root
**How to avoid:** Set ownership with `COPY --chown` and ensure writable directories
**Warning signs:** "cannot open file for writing" errors in container logs

### Pitfall 6: Health Check Fails During Startup
**What goes wrong:** Container marked unhealthy immediately
**Why it happens:** R/Plumber needs time to load packages and start server
**How to avoid:** Use `--start-period=30s` (or longer for many packages)
**Warning signs:** Container restarts repeatedly; "unhealthy" status in docker ps

## Code Examples

### Health Check Endpoint for Plumber
```r
# Add to start_sysndd_api.R or create endpoints/health_endpoints.R
#* Health check endpoint for Docker HEALTHCHECK
#* @get /health
#* @serializer json
function(req, res) {
  list(
    status = "healthy",
    timestamp = Sys.time(),
    version = sysndd_api_version
  )
}
```
Source: [Plumber API endpoints](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html)

### Strip Debug Symbols from R Packages
```dockerfile
# After package installation, strip .so files
RUN find /usr/local/lib/R/site-library -name "*.so" \
    -exec strip --strip-debug {} \; 2>/dev/null || true
```
Source: [r-stripper](https://github.com/dcdillon/r-stripper)

### Posit Package Manager Configuration for R 4.1.2
```dockerfile
# R 4.1.2 uses Ubuntu 20.04 (focal)
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# For FactoMineR compatibility, use 2022-01-03 snapshot
# This gives compatible lme4/pbkrtest/car versions
RUN R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/2022-01-03")); \
    install.packages(c("lme4", "pbkrtest", "car", "FactoMineR", "factoextra"))'
```
Source: [Posit Package Manager](https://packagemanager.posit.co/__docs__/admin/serving-binaries.html)

### pak for Bioconductor Packages
```dockerfile
# pak handles Bioconductor automatically
RUN R -e ' \
    pak::pak(c( \
        "bioc::STRINGdb", \
        "bioc::biomaRt" \
    ), ask = FALSE) \
    '
```
Note: Bioconductor packages do NOT have P3M binaries - they will compile from source.
Source: [pak Bioconductor support](https://pak.r-lib.org/reference/pak_package_sources.html)

### Complete Multi-Stage Dockerfile Pattern
```dockerfile
# syntax=docker/dockerfile:1.4
# =============================================================================
# Stage 1: Base - System dependencies and R configuration
# =============================================================================
FROM rocker/r-ver:4.1.2 AS base

ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest" \
    RENV_PATHS_CACHE=/renv_cache \
    RENV_CONFIG_CACHE_SYMLINKS=FALSE \
    RENV_CONFIG_PAK_ENABLED=FALSE

# System dependencies (single layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ccache build-essential \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    libmariadb-dev libmysqlclient21 default-jdk \
    libsodium-dev libpcre3-dev libicu-dev \
    libbz2-dev liblzma-dev zlib1g-dev libglpk-dev \
    libpng-dev libsecret-1-dev gfortran cmake pandoc git \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

# Configure ccache
RUN mkdir -p ~/.R ~/.ccache && \
    echo 'CCACHE=ccache' > ~/.R/Makevars && \
    echo 'CC=$(CCACHE) gcc' >> ~/.R/Makevars && \
    echo 'CXX=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX11=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX14=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'CXX17=$(CCACHE) g++' >> ~/.R/Makevars && \
    echo 'FC=$(CCACHE) gfortran' >> ~/.R/Makevars && \
    echo 'F77=$(CCACHE) gfortran' >> ~/.R/Makevars && \
    echo 'max_size = 2.0G' > ~/.ccache/ccache.conf && \
    echo 'sloppiness = include_file_ctime' >> ~/.ccache/ccache.conf && \
    echo 'hash_dir = false' >> ~/.ccache/ccache.conf

# Install renv
RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")'

# =============================================================================
# Stage 2: Packages - Install all R packages
# =============================================================================
FROM base AS packages

WORKDIR /app

# Copy renv infrastructure
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
COPY .Rprofile .Rprofile

# Restore packages with BuildKit cache
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'renv::restore()'

# Install additional packages not in renv.lock
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/latest")); \
    install.packages(c("plumber", "RMariaDB", "igraph", "xlsx", "tidyverse", "remotes", "BiocManager"), \
    Ncpus = parallel::detectCores())'

# FactoMineR with compatible versions (2022-01-03 snapshot)
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/2022-01-03")); \
    install.packages(c("nloptr", "lme4", "pbkrtest", "car", "FactoMineR", "factoextra"), \
    Ncpus = parallel::detectCores())'

# Bioconductor packages (will compile from source)
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'BiocManager::install(c("STRINGdb", "biomaRt"), update=FALSE, ask=FALSE)'

# Strip debug symbols
RUN find /usr/local/lib/R/site-library -name "*.so" \
    -exec strip --strip-debug {} \; 2>/dev/null || true

# =============================================================================
# Stage 3: Production - Final slim image
# =============================================================================
FROM base AS production

# Create non-root user
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser

WORKDIR /app

# Copy R libraries from packages stage
COPY --from=packages /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Copy application code with correct ownership
COPY --chown=apiuser:api endpoints/ endpoints/
COPY --chown=apiuser:api functions/ functions/
COPY --chown=apiuser:api config/ config/
COPY --chown=apiuser:api config.yml config.yml
COPY --chown=apiuser:api version_spec.json version_spec.json
COPY --chown=apiuser:api start_sysndd_api.R start_sysndd_api.R

# Create logs directory with correct permissions
RUN mkdir -p /app/logs && chown apiuser:api /app/logs

# Health check (curl installed in base)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:7777/health || exit 1

LABEL maintainer="SysNDD Team" \
      version="2.0" \
      description="SysNDD R Plumber API (Optimized)"

USER apiuser
EXPOSE 7777

CMD ["Rscript", "start_sysndd_api.R"]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| devtools::install_version() | pak::pak() or P3M binaries | 2023+ | 10x faster installation |
| rocker/tidyverse | rocker/r-ver | 2022+ | 50% smaller base image |
| Single-stage builds | Multi-stage builds | 2020+ | Cleaner separation, smaller images |
| HTTP CRAN repos | HTTPS only | 2020+ | Security requirement |
| Root user | Non-root user | 2022+ | Security best practice |
| No health checks | HEALTHCHECK instruction | Docker 1.12+ | Orchestration compatibility |

**Deprecated/outdated:**
- `devtools::install_version()`: Slow, always compiles from source
- `rocker/tidyverse` for APIs: Includes unnecessary RStudio Server
- `links:` directive in Docker Compose: Use networks instead
- HTTP CRAN mirrors: Security risk

## Open Questions

Things that couldn't be fully resolved:

1. **Exact FactoMineR/factoextra version compatibility**
   - What we know: 2022-01-03 P3M snapshot works with R 4.1.2
   - What's unclear: Whether newer versions exist that work
   - Recommendation: Keep current approach; test if upgrade is desired later

2. **Bioconductor package build time**
   - What we know: STRINGdb and biomaRt don't have P3M binaries
   - What's unclear: Exact compilation time on target hardware
   - Recommendation: Accept ~5-10 minute overhead for Bioconductor stage

3. **Health endpoint implementation location**
   - What we know: Need /health endpoint responding to GET
   - What's unclear: Add to start_sysndd_api.R or create health_endpoints.R
   - Recommendation: Add programmatically in start_sysndd_api.R for simplicity

## Sources

### Primary (HIGH confidence)
- [Rocker Project r-ver images](https://rocker-project.org/images/versioned/r-ver) - R version to Ubuntu mapping
- [Posit Package Manager Documentation](https://packagemanager.posit.co/__docs__/admin/serving-binaries.html) - Binary package configuration
- [pak Package Sources](https://pak.r-lib.org/reference/pak_package_sources.html) - Bioconductor installation syntax
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/) - Official Docker documentation

### Secondary (MEDIUM confidence)
- [ccache for R](http://dirk.eddelbuettel.com/blog/2017/11/27/) - R compilation caching
- [renv with Docker](https://rstudio.github.io/renv/articles/docker.html) - Official renv Docker guide
- [Plumber health endpoints](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html) - Health check patterns
- [Docker USER instruction](https://www.docker.com/blog/understanding-the-docker-user-instruction/) - Non-root user best practices

### Tertiary (LOW confidence)
- [r-stripper GitHub](https://github.com/dcdillon/r-stripper) - Debug symbol stripping tool
- [BuildKit renv example](https://github.com/howisonlab/test_repo_buildx_renv) - Cache mount patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified against rocker project and Posit documentation
- Architecture patterns: HIGH - Follows Docker best practices documentation
- Pitfalls: HIGH - Based on existing Dockerfile issues and known R/Docker interactions
- Code examples: MEDIUM - Adapted from multiple sources, not all tested in this specific context

**Research date:** 2026-01-22
**Valid until:** 2026-03-22 (60 days - R ecosystem changes slowly)
