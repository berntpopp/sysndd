# syntax=docker/dockerfile:1.4
# =============================================================================
# SysNDD API - Multi-Stage Optimized R Plumber Docker Image
# =============================================================================
#
# Build time target: 5-8 minutes (down from 45+ minutes)
# Key optimizations:
# - Multi-stage build (base -> packages -> production)
# - Posit Package Manager (P3M) pre-compiled binaries
# - ccache for compilation caching
# - Debug symbol stripping
# - Non-root user (uid 1001)
# - HEALTHCHECK instruction
#
# Build command:
#   DOCKER_BUILDKIT=1 docker build -t sysndd-api:latest -f api/Dockerfile api/

# =============================================================================
# Stage 1: Base - System dependencies and R configuration
# =============================================================================
FROM rocker/r-ver:4.1.2 AS base

# Set R repository to Posit Package Manager for pre-compiled Linux binaries
# rocker/r-ver:4.1.2 uses Ubuntu 20.04 (focal), so we use focal binaries
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# Disable pak to avoid version conflicts
ENV RENV_CONFIG_PAK_ENABLED=FALSE

# Global renv cache location (for BuildKit cache mount)
ENV RENV_PATHS_CACHE=/renv_cache

# Disable cache symlinks - copy packages instead so they persist after build
# This is necessary because BuildKit cache mounts are only available during build
ENV RENV_CONFIG_CACHE_SYMLINKS=FALSE

# Install all system dependencies in ONE layer
# These are required by various R packages (RMariaDB, xml2, jose, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # curl for health checks
    curl \
    # ccache for compilation caching
    ccache \
    # Build essentials
    build-essential \
    # OpenSSL for jose, httr, curl
    libssl-dev \
    # curl for httr, RCurl
    libcurl4-openssl-dev \
    # XML for xml2, rvest
    libxml2-dev \
    # MariaDB/MySQL client for RMariaDB
    libmariadb-dev \
    # MySQL client runtime library for RMariaDB binary (P3M binaries linked against MySQL)
    libmysqlclient21 \
    # Java for rJava, xlsx
    default-jdk \
    # Sodium for secure hashing
    libsodium-dev \
    # PCRE for stringr regex
    libpcre3-dev \
    # ICU for stringi
    libicu-dev \
    # Compression libraries
    libbz2-dev \
    liblzma-dev \
    zlib1g-dev \
    # Git for devtools (if needed for any GitHub packages)
    git \
    # libsecret for keyring package
    libsecret-1-dev \
    # Fortran compiler for some numerical packages
    gfortran \
    # GLPK for igraph
    libglpk-dev \
    # PNG for Bioconductor packages
    libpng-dev \
    # cmake for nloptr package
    cmake \
    # pandoc for knitr/rmarkdown
    pandoc \
    # libx11 for clipboard support
    libx11-dev \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

# Configure ccache for R package compilation
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

# Install renv (required for restore)
RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")'

# =============================================================================
# Stage 2: Packages - Install all R packages (build-time only)
# =============================================================================
FROM base AS packages

WORKDIR /app

# Copy renv infrastructure first (for layer caching)
# If renv.lock hasn't changed, Docker will use cached layers
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
COPY .Rprofile .Rprofile

# Restore packages from lockfile with BuildKit cache
# The cache mount persists the renv cache across builds
# This dramatically speeds up rebuilds when only a few packages change
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'renv::restore()'

# Install critical packages missing from renv.lock
# Note: These packages should be added to renv.lock in a future update
# Key issue: renv.lock has Matrix 1.4-0, lme4 >= 1.1-28 requires Matrix >= 1.5.0 (needs R >= 4.2)
# Solution: Use 2022-01-03 P3M snapshot for FactoMineR dependencies (compatible with R 4.1.2)
#           Use latest P3M for other packages (plumber, RMariaDB, etc.)
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/latest")); \
    install.packages(c("plumber", "RMariaDB", "igraph", "xlsx", "tidyverse", "remotes", "BiocManager"), Ncpus = parallel::detectCores())'

# Install FactoMineR/factoextra with R 4.1.2-compatible versions from 2022-01-03 snapshot
# This gives us lme4 1.1-27.1, pbkrtest 0.5-0.1, car 3.0-12, which all work with Matrix 1.4-0
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/2022-01-03")); \
    install.packages(c("nloptr", "lme4", "pbkrtest", "car", "FactoMineR", "factoextra"), Ncpus = parallel::detectCores())'

# Install Bioconductor packages (use latest versions)
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/focal/latest")); \
    BiocManager::install(c("STRINGdb", "biomaRt"), update=FALSE, ask=FALSE)'

# Strip debug symbols from compiled libraries to reduce image size
# This can reduce .so file sizes by 20-30%
RUN find /usr/local/lib/R/site-library -name "*.so" \
    -exec strip --strip-debug {} \; 2>/dev/null || true

# =============================================================================
# Stage 3: Production - Final slim image
# =============================================================================
FROM base AS production

# Create non-root user with specific UID/GID for security
RUN groupadd -g 1001 api && \
    useradd -u 1001 -g api -m -s /bin/bash apiuser

WORKDIR /app

# Copy R libraries from packages stage (multi-stage optimization)
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

# Health check instruction for Docker orchestration
# Checks /health endpoint created in 07-01
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:7777/health || exit 1

# Image metadata
LABEL maintainer="SysNDD Team" \
      version="2.0" \
      description="SysNDD R Plumber API (Multi-Stage Optimized)"

# Switch to non-root user for security
USER apiuser

# Expose API port
EXPOSE 7777

# Start the Plumber API
CMD ["Rscript", "start_sysndd_api.R"]
