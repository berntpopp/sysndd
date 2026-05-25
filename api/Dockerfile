# syntax=docker/dockerfile:1.4
# =============================================================================
# SysNDD API - Multi-Stage Optimized R Plumber Docker Image
# =============================================================================
#
# Build time target: 3-5 minutes (pre-built P3M binaries for R 4.6.0)
# Key optimizations:
# - Multi-stage build (base -> packages -> production)
# - Posit Package Manager (P3M) pre-compiled binaries for Ubuntu 24.04 (noble)
# - Complete renv.lock with all dependencies (no manual installs needed)
# - Debug symbol stripping
# - Non-root user (default uid 1000, configurable via --build-arg)
# - HEALTHCHECK instruction
#
# Build command:
#   DOCKER_BUILDKIT=1 docker build -t sysndd-api:latest -f api/Dockerfile api/

# =============================================================================
# Stage 1: Base - System dependencies and R configuration
# =============================================================================
FROM rocker/r-ver:4.6.0 AS base

# Set R repository to Posit Package Manager for pre-compiled Linux binaries
# rocker/r-ver:4.6.0 uses Ubuntu 24.04 (noble), so we use noble binaries
#
# IMPORTANT: pin to a dated snapshot (not /latest) so that CRAN pruning old
# versions cannot silently drift the build. Bump this date intentionally,
# together with renv.lock "Repositories.URL", when refreshing dependencies.
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/2026-05-08"

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
    # ccache for compilation caching (if any source builds needed)
    ccache \
    # Build essentials (for any packages not available as binaries)
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
    # MySQL client binaries for backup/restore operations (mysqldump, mysql)
    default-mysql-client \
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
    # Font and text rendering for ragg, systemfonts
    libfontconfig1-dev \
    libfreetype6-dev \
    libtiff5-dev \
    libjpeg-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    # Git library for gert/usethis
    libgit2-dev \
    # Poppler for pdftools (PDF parsing)
    libpoppler-cpp-dev \
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

# Install Node for headless Cytoscape/fCoSE layout artifact generation.
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*

# Configure ccache for R package compilation (if any source builds needed)
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
# NOTE: Do NOT copy .Rprofile to avoid renv auto-activation during build
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

# Disable RSPM auto-detection to use our explicit repos override
# The repos override above uses noble (Ubuntu 24.04) binaries with correct ICU 74
# This prevents renv from auto-detecting and using incorrect binary versions
ENV RENV_CONFIG_RSPM_ENABLED=FALSE

# Restore all packages from lockfile with BuildKit cache. Restore packages with
# known lockfile ordering issues first: tseries before forecast, and mcptools'
# runtime dependencies before the GitHub mcptools package.
# The renv.lock now contains ALL dependencies including Bioconductor packages
# No manual install.packages() calls needed - everything is in the lockfile
RUN --mount=type=cache,target=/renv_cache,sharing=locked \
    --mount=type=cache,target=/root/.ccache,sharing=locked \
    R -e 'deps <- c("tseries", "ellmer", "httpuv", "httr2", "nanonext", "processx", "promises", "rlang"); renv::restore(packages = deps, library = "/usr/local/lib/R/site-library", prompt = FALSE); renv::restore(packages = "mcptools", library = "/usr/local/lib/R/site-library", prompt = FALSE); renv::restore(library = "/usr/local/lib/R/site-library", prompt = FALSE)'

# Verify stringi loads correctly (links against correct ICU version)
RUN R -e 'library(stringi); cat("stringi ICU:", stri_info()$ICU.version, "\n")'

# Strip debug symbols from compiled libraries to reduce image size
# This can reduce .so file sizes by 20-30%
RUN find /usr/local/lib/R/site-library -name "*.so" \
    -exec strip --strip-debug {} \; 2>/dev/null || true

# =============================================================================
# Stage 3: Production - Final slim image
# =============================================================================
FROM base AS production

# Accept git commit hash as build argument for version tracking
ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=${GIT_COMMIT}

# Build-time UID/GID configuration for host bind mount compatibility
# Default 1000 matches most Linux host users; override with --build-arg UID=1001
ARG UID=1000
ARG GID=1000

# Create non-root user with configurable UID/GID for security
RUN groupadd -g ${GID} api && \
    useradd -u ${UID} -g api -m -s /bin/bash apiuser

WORKDIR /app

# Copy R libraries from packages stage (multi-stage optimization)
COPY --from=packages /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Copy application code with correct ownership
COPY --chown=apiuser:api endpoints/ endpoints/
COPY --chown=apiuser:api functions/ functions/
COPY --chown=apiuser:api core/ core/
COPY --chown=apiuser:api services/ services/
COPY --chown=apiuser:api bootstrap/ bootstrap/
COPY --chown=apiuser:api config/ config/
COPY --chown=apiuser:api version_spec.json version_spec.json
COPY --chown=apiuser:api start_sysndd_api.R start_sysndd_api.R

# Install the minimal headless Cytoscape layout helper runtime.
COPY --chown=apiuser:api layout/package.json layout/package-lock.json /app/layout/
RUN cd /app/layout && npm ci --omit=dev
COPY --chown=apiuser:api layout/gene-network-fcose-layout.mjs /app/layout/gene-network-fcose-layout.mjs

# Create logs, results, and cache directories with correct permissions
RUN mkdir -p /app/logs /app/results /app/cache && \
    chown apiuser:api /app/logs /app/results /app/cache

# Health check instruction for Docker orchestration
# Checks the health endpoint mounted by start_sysndd_api.R
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:7777/api/health/ || exit 1

# Image metadata
LABEL maintainer="SysNDD Team" \
      version="3.2" \
      description="SysNDD R Plumber API (R 4.6.0, Multi-Stage Optimized)"

# Switch to non-root user for security
USER apiuser

# Expose API port
EXPOSE 7777

# Start the Plumber API
CMD ["Rscript", "start_sysndd_api.R"]
