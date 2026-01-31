# External Integrations

**Analysis Date:** 2026-01-20

## APIs & External Services

**Publication & Gene Data:**
- **PubTator API v3** - PubMed article mining and gene/protein entity extraction
  - SDK/Client: Custom integration via `httr` and `fromJSON()`
  - Endpoint: `https://www.ncbi.nlm.nih.gov/research/pubtator3-api/`
  - Implementation: `api/functions/pubtator-functions.R` - Queries, pagination, result storage
  - Usage: Gene news, article discovery, mention extraction

- **PubMed/easyPubMed** - Publication metadata retrieval
  - SDK/Client: `easyPubMed` 2.13 package
  - Usage: Check PMIDs, retrieve publication metadata for curation
  - Implementation: `api/functions/publication-functions.R`, `api/endpoints/publication_endpoints.R`

- **HGNC REST API** - Human Gene Nomenclature Committee reference data
  - SDK/Client: Custom integration via `fromJSON()` and `httr::GET()`
  - Endpoints: `http://rest.genenames.org/search/` (symbol, alias, previous symbol)
  - Implementation: `api/functions/hgnc-functions.R`
  - Usage: Gene name standardization, ID mapping

- **BiomaRt/Ensembl** - Ensembl gene annotation and cross-references
  - SDK/Client: `biomaRt` package (BiocManager)
  - Implementation: `api/functions/ensembl-functions.R`, `api/endpoints/gene_endpoints.R`
  - Usage: Gene coordinates, transcript data, orthology

- **STRING DB** - Protein interaction network database
  - SDK/Client: `STRINGdb` package (BiocManager)
  - Implementation: Used in analysis endpoints for network visualization
  - Usage: Protein-protein interaction data in comparison analyses

**Web Archiving:**
- **Internet Archive (Wayback Machine) SPN2 API** - URL archiving and preservation
  - Endpoint: `https://web.archive.org/save`
  - Auth: LOW authentication (access key + secret key from config)
  - Implementation: `api/functions/external-functions.R`
  - Endpoint route: `POST /api/internet_archive` in `api/endpoints/external_endpoints.R`
  - Config keys: `archive_access_key`, `archive_secret_key`, `archive_base_url`

**Ontology & Terminology:**
- **HPO (Human Phenotype Ontology)** - Phenotype term standardization
  - SDK/Client: `ontologyIndex` package
  - Implementation: `api/functions/hpo-functions.R`
  - Usage: Phenotype curation and validation

- **OXO (EMBL-EBI Ontology Cross-references)** - Ontology term mapping
  - SDK/Client: Custom REST integration via `fromJSON()`
  - Implementation: `api/functions/oxo-functions.R`
  - Usage: Cross-reference phenotype/disease terms

## Data Storage

**Databases:**
- **MySQL/MariaDB** 8.0.29
  - Connection: `api/config.yml` specifies host (127.0.0.1 local, mysql container production)
  - Port: 3306 (internal), mapped to 7654 locally in docker-compose
  - Credentials: User `bernt`, password in config.yml (production/local split)
  - Client: `RMariaDB` 1.2.2 with `DBI` abstraction
  - Connection pooling: `pool` 1.0.1 creates global `pool` object in `start_sysndd_api.R`
  - Databases:
    - `sysndd_db` (default database name, configured in `config.yml`)
    - Tables: publication, gene, phenotype, entity, user, review, etc.

**File Storage:**
- Local filesystem only - no cloud storage detected
- Log files: `api/logs/` directory (created on startup)
- Temporary files: System temp directory for plumber logs
- Export formats: XLSX via `xlsx` package, JSON via `jsonlite`

**Caching:**
- In-memory cache: `cachem` with 100MB max size, 1-hour TTL
- Memoized functions: `generate_stat_tibble_mem`, `generate_gene_news_tibble_mem`, `nest_gene_tibble_mem`, `gen_string_clust_obj_mem`, `read_log_files_mem`, `nest_pubtator_gene_tibble_mem`
- Implementation: `api/start_sysndd_api.R` lines 182-194

## Authentication & Identity

**Auth Provider:**
- Custom JWT-based authentication (no third-party auth provider)
- JWT Generation/Validation:
  - SDK/Client: `jose` 1.2.0 package
  - Implementation: `api/functions/config-functions.R` (assumed from auth endpoints)
  - Token claims: user_id, user_name, email, user_role, user_created, abbreviation, orcid, iat, exp
  - Secret: `dw$secret` from config.yml (production/local specific)
  - Bearer tokens in Authorization headers

- User Roles (defined in `api/start_sysndd_api.R`):
  - Administrator
  - Curator
  - Reviewer
  - Viewer

- Implementation: `api/endpoints/authentication_endpoints.R`
  - Signup endpoint: Creates user, sends confirmation email
  - Login endpoint: Returns JWT token
  - Token refresh: Configurable refresh timeout (default 3600 seconds)

## Monitoring & Observability

**Error Tracking:**
- No external error tracking service detected
- Application exceptions handled via R's try-catch patterns

**Logs:**
- **Logger framework**: `logger` 0.2.2 package in R API
- Log files written to: `api/logs/` directory
- Temporary log files created per plumber session
- Frontend: Browser console logging (no external aggregation)

**Audit Trails:**
- Database logging likely stored in database tables (not explicitly detected)

## CI/CD & Deployment

**Hosting:**
- Docker containerization for all services
- Docker Compose orchestration: `docker-compose.yml`
- Services:
  - mysql:8.0.29 - Database
  - api (R Plumber) - REST API
  - alb (HAProxy 1.6.7) - Load balancer/reverse proxy
  - app (Vue/nginx) - Frontend SPA
  - mysql-cron-backup - Automated backup service

**CI Pipeline:**
- No CI service detected (GitHub Actions, GitLab CI, etc.)
- Pre-commit validation scripts available:
  - `api/scripts/pre-commit-check.R`
  - `api/scripts/lint-check.R`
  - `api/scripts/lint-and-fix.R`
  - `api/scripts/style-code.R`

**Deployment:**
- `deployment.sh` script accepts `config.tar.gz` for full deployment
- Environment variables via `.env` or docker-compose environment
- Database setup scripts in `db/` directory

## Environment Configuration

**Required env vars:**
- `ENVIRONMENT` - "local" or "production" (defaults to "local")
- `API_CONFIG` - Maps to config.yml section (sysndd_db or sysndd_db_local)
- `PASSWORD` - Database user password (for docker-compose)
- `SMTP_PASSWORD` - Email server password (for notifications)
- `MYSQL_DATABASE` - Database name
- `MYSQL_USER` - MySQL user
- `MYSQL_PASSWORD` - MySQL user password
- `MYSQL_ROOT_PASSWORD` - MySQL root password

**Secrets location:**
- `api/config.yml` - Contains all secrets (passwords, API keys, JWT secret)
- `.env` - Environment variable overrides (local only, not committed)
- **WARNING:** config.yml contains plaintext secrets (archive_access_key, archive_secret_key, omim_token, mail passwords)

## Webhooks & Callbacks

**Incoming:**
- No webhook endpoints detected

**Outgoing:**
- **Email notifications** via SMTP
  - SMTP Server: `smtp.strato.de` (configured for production)
  - Port: 587 with SSL
  - From: `noreply@sysndd.org`
  - Usage: User signup confirmations, review notifications
  - Implementation: `blastula` 0.3.3 package
  - Config keys: `mail_noreply_user`, `mail_noreply_host`, `mail_noreply_port`, `mail_noreply_use_ssl`, `mail_noreply_password`

---

*Integration audit: 2026-01-20*
