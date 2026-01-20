# Technology Stack

**Analysis Date:** 2026-01-20

## Languages

**Primary:**
- R 4.3.2 - REST API backend using Plumber framework
- JavaScript (ES6+) - Vue 2 frontend application
- Shell/Bash - Docker configuration and deployment scripts

**Secondary:**
- SQL - Database queries via DBI/RMariaDB

## Runtime

**Environment:**
- R 4.3.2 (from rocker/tidyverse:4.3.2 Docker image)
- Node.js (implied from npm scripts, version not explicitly specified)
- MySQL 8.0.29 (containerized database)

**Package Manager:**
- R: Uses `install.packages()` and `BiocManager::install()` with explicit version pinning in `Dockerfile`
- npm - Frontend dependency manager
- Lockfile: `app/package-lock.json` (present, version 3 format)

## Frameworks

**Core:**
- **Plumber** 1.2.1 - REST API framework for R (`api/start_sysndd_api.R`)
- **Vue** 2.7.8 - Progressive JavaScript framework
- **Bootstrap-Vue** 2.21.2 - Bootstrap Vue component library
- **Vue Router** 3.5.3 - Client-side routing
- **Pinia** 2.0.14 - State management (Vue 3 composition API compatible)

**Testing:**
- No test framework detected in configuration

**Build/Dev:**
- Vue CLI 5.0.8 - Build tool and dev server
- Webpack 4.10.0 - Module bundler
- Babel 7.x - JavaScript transpiler
- ESLint 6.8.0 - JavaScript linting
- Sass 1.53.0 - CSS preprocessor
- PostCSS 8.4.14 - CSS post-processing

## Key Dependencies

**Critical:**
- **RMariaDB** 1.2.2 - MariaDB/MySQL database driver
- **pool** 1.0.1 - Database connection pooling
- **jose** 1.2.0 - JWT token encoding/decoding for authentication
- **biomaRt** - Bioinformatics data access (uses BiocManager)
- **STRINGdb** - Protein interaction database (uses BiocManager)
- **tidyverse** - Data manipulation (ggplot2, dplyr, tidyr, etc.)
- **Axios** 0.21.4 - HTTP client for Vue app

**Infrastructure/Data Processing:**
- **easyPubMed** 2.13 - PubMed API integration for publication queries
- **httr** - HTTP requests to external APIs (Internet Archive, HGNC, etc.)
- **jsonlite** 1.8.4 - JSON parsing and generation
- **xml2** 1.3.4 - XML parsing (used with web scraping)
- **rvest** 1.0.3 - Web scraping utilities
- **memoise** 2.0.1 - Function result caching
- **logger** 0.2.2 - Structured logging
- **blastula** 0.3.3 - Email sending capabilities
- **keyring** 1.3.1 - Credential storage access

**Analysis/Visualization:**
- **D3.js** 7.4.2 - Data visualization on frontend
- **FactoMineR** 2.8 - Multivariate analysis
- **factoextra** - FactoMineR visualization
- **STRINGdb** - Network analysis
- **coop** 0.6-3 - Correlation matrices
- **stringdist** 0.9.10 - String distance metrics
- **UpsetJS** 1.11.0 - Set intersection visualization

**Utilities:**
- **config** 0.3.1 - Configuration management (config.yml)
- **dotenv** 1.0.3 - Environment variable loading
- **tictoc** 1.2 - Timing/profiling
- **fs** 1.6.2 - File system operations
- **lubridate** 1.9.2 - Date/time manipulation
- **future** 1.32.0 - Parallel/async processing
- **joi** 17.6.0 - Schema validation (frontend)
- **vee-validate** 3.4.14 - Form validation (frontend)
- **file-saver** 2.0.5 - Export file generation (frontend)
- **html2canvas** 1.4.1 - Screenshot/canvas rendering (frontend)

## Configuration

**Environment:**
- `.env` file at `api/.env` loads via dotenv library
- `config.yml` at `api/config.yml` contains environment-specific settings (local/production)
- Environments determined by `ENVIRONMENT` variable (defaults to "local")
- Local: `sysndd_db_local` config, API on port 7778, DB on 127.0.0.1:7654
- Production: `sysndd_db` config, API on port 7777, DB on docker mysql service

**Build:**
- `app/.eslintrc*` - ESLint configuration (Airbnb preset)
- `api/.lintr` - R linting configuration (tidyverse style, 100 char line limit)
- Frontend build output: `app/dist/`
- API runs directly from source with Rscript

## Platform Requirements

**Development:**
- R 4.3.2 with build tools (gcc, cmake, java, etc.)
- Node.js with npm
- MySQL 8.0.29 (or MariaDB)
- Docker and Docker Compose (for containerized setup)

**Production:**
- Docker containers for isolated deployment
- MySQL 8.0.29 service
- HAProxy (dockercloud/haproxy:1.6.7) for load balancing
- Automated MySQL backups via fradelg/mysql-cron-backup

---

*Stack analysis: 2026-01-20*
