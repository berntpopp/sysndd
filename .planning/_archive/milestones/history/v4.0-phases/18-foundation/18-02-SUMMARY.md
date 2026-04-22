---
phase: 18-foundation
plan: 02
status: complete
completed: 2026-01-23
commits:
  - hash: (combined with 18-01)
    message: "feat(18): upgrade R to 4.4.3 with complete renv.lock"
---

# Summary: Update Dockerfile to R 4.4.3

## Objective Achieved
Updated Dockerfile to R 4.4.3 base image and removed all package installation workarounds. The simplified Dockerfile now uses only renv::restore() for package installation.

## Deliverables

### Created/Modified Files
- `api/Dockerfile` - Updated to R 4.4.3 with simplified package installation

### What Was Built
1. **Modernized Dockerfile**
   - Base image: rocker/r-ver:4.4.3 (was 4.1.2)
   - P3M URL: noble/latest (was focal/latest)
   - Version label: 3.0

2. **Removed Workarounds**
   - No 2022-01-03 P3M snapshot workaround
   - No manual install.packages() for FactoMineR/lme4
   - No separate Bioconductor installation block
   - Single renv::restore() call handles everything

3. **Additional System Dependencies**
   - Added libfontconfig1-dev, libfreetype6-dev for ragg/systemfonts
   - Added libtiff5-dev, libjpeg-dev for image processing
   - Added libharfbuzz-dev, libfribidi-dev for text rendering
   - Added libgit2-dev for gert/usethis packages

## Changes Made

### Base Image
```dockerfile
# Before
FROM rocker/r-ver:4.1.2 AS base

# After
FROM rocker/r-ver:4.4.3 AS base
```

### P3M URL
```dockerfile
# Before
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# After
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/noble/latest"
```

### Package Installation (Simplified)
```dockerfile
# Before: Multiple RUN blocks with workarounds
RUN R -e 'renv::restore(library = "/usr/local/lib/R/site-library")'
RUN R -e 'install.packages(c("plumber", "RMariaDB", ...))'  # workaround
RUN R -e 'options(repos = c(CRAN = "...focal/2022-01-03")); install.packages(...)'  # workaround
RUN R -e 'BiocManager::install(c("STRINGdb", "biomaRt"), ...)'  # workaround

# After: Single renv::restore()
RUN R -e 'renv::restore(library = "/usr/local/lib/R/site-library")'
```

## Verification
- [x] Docker build completes successfully (with pre-built binaries)
- [x] R 4.4.3 confirmed in container
- [x] Matrix 1.7.2 confirmed in container
- [x] FactoMineR, lme4 load without ABI errors
- [x] API health endpoint returns healthy status
- [x] Frontend loads and displays data from API
- [x] Database statistics visible (1942 Definitive entities, etc.)

## Performance
- Build time: ~8 minutes (down from original 45+ minutes)
- All packages installed as pre-built binaries (no source compilation)
- BuildKit cache mounts preserved for incremental builds

## Notes
- The libmysqlclient21 package is required for P3M RMariaDB binary compatibility
- Ubuntu 24.04 (noble) is the base OS for rocker/r-ver:4.4.3
- The simplified Dockerfile is easier to maintain and understand
