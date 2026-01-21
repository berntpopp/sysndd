# syntax=docker/dockerfile:1.4
# SysNDD API - Optimized R Plumber Docker Image
#
# Build time target: 5-10 minutes (down from 45+ minutes)
# Key optimizations:
# - Posit Package Manager (P3M) pre-compiled binaries
# - pak for parallel package installation
# - renv::restore() from lockfile
# - Consolidated system dependencies
# - BuildKit cache for renv library

FROM rocker/r-ver:4.1.2 AS base

# Set R repository to Posit Package Manager for pre-compiled Linux binaries
# rocker/r-ver:4.1.2 uses Ubuntu 20.04 (focal), so we use focal binaries
# This avoids source compilation for most packages
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# Enable pak for faster parallel downloads
ENV RENV_CONFIG_PAK_ENABLED=TRUE

# Global renv cache location (for BuildKit cache mount)
ENV RENV_PATHS_CACHE=/renv_cache

# Disable cache symlinks - copy packages instead so they persist after build
# This is necessary because BuildKit cache mounts are only available during build
ENV RENV_CONFIG_CACHE_SYMLINKS=FALSE

# Install all system dependencies in ONE layer
# These are required by various R packages (RMariaDB, xml2, jose, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/* \
    && R CMD javareconf

# Install renv (required for restore)
RUN R -e 'install.packages("renv", repos = "https://cloud.r-project.org")'

# Set working directory
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
RUN --mount=type=cache,target=/renv_cache \
    R -e 'renv::restore()'

# Install critical packages missing from renv.lock
# Note: These packages should be added to renv.lock in a future update
# The renv.lock was created from a partial snapshot and needs completion
RUN --mount=type=cache,target=/renv_cache \
    R -e 'renv::install(c("plumber", "RMariaDB", "igraph", "xlsx", "BiocManager")); BiocManager::install(c("STRINGdb", "biomaRt"), update=FALSE, ask=FALSE)'

# Copy application code AFTER package installation
# This ensures code changes don't invalidate the package cache layer
COPY endpoints/ endpoints/
COPY functions/ functions/
COPY config.yml config.yml
COPY start_sysndd_api.R start_sysndd_api.R

# Expose API port
EXPOSE 7777

# Start the Plumber API
CMD ["Rscript", "start_sysndd_api.R"]
