# Codebase Structure

**Analysis Date:** 2026-01-20

## Directory Layout

```
sysndd/
├── .planning/                          # GSD planning documents
│   └── codebase/                       # Architecture and analysis docs
├── .vscode/                            # VS Code project settings
├── .git/                               # Git repository
├── .github/                            # GitHub workflows and actions
├── api/                                # R Plumber REST API
│   ├── start_sysndd_api.R              # Main API server startup
│   ├── config.yml                      # Database and environment config
│   ├── .lintr                          # R linting rules
│   ├── version_spec.json               # API version and metadata
│   ├── config/
│   │   └── api_spec.json               # OpenAPI specification
│   ├── endpoints/                      # Modular endpoint definitions (21 files)
│   │   ├── entity_endpoints.R
│   │   ├── gene_endpoints.R
│   │   ├── phenotype_endpoints.R
│   │   ├── review_endpoints.R
│   │   ├── authentication_endpoints.R
│   │   └── ... (16 more endpoint files)
│   ├── functions/                      # Domain-specific helper functions (18 files)
│   │   ├── database-functions.R        # CRUD operations
│   │   ├── endpoint-functions.R        # Endpoint utilities
│   │   ├── helper-functions.R          # General utilities
│   │   ├── analyses-functions.R        # Statistical analysis
│   │   ├── ontology-functions.R        # Disease/phenotype ontology
│   │   └── ... (13 more function files)
│   ├── scripts/                        # Development tools
│   │   ├── lint-check.R                # Code linting
│   │   ├── style-code.R                # Code formatting
│   │   ├── lint-and-fix.R              # Combined quality check
│   │   └── pre-commit-check.R          # Pre-commit validation
│   ├── data/                           # Static data files
│   │   ├── mondo_terms/                # MONDO disease ontology
│   │   └── omim_links/                 # OMIM gene-disease links
│   ├── logs/                           # Runtime log files (generated)
│   ├── results/                        # Generated result files
│   │   └── ontology/                   # Ontology calculation outputs
│   ├── _old/                           # Archived old versions
│   ├── Dockerfile                      # Docker image definition
│   └── README.md
├── app/                                # Vue 2 SPA frontend
│   ├── src/
│   │   ├── main.js                     # App entry point
│   │   ├── App.vue                     # Root component
│   │   ├── components/                 # Reusable components
│   │   │   ├── Navbar.vue              # Top navigation
│   │   │   ├── Footer.vue              # Bottom footer
│   │   │   ├── analyses/               # Data visualization components
│   │   │   │   ├── AnalyseGeneClusters.vue
│   │   │   │   ├── AnalysesPhenotypeClusters.vue
│   │   │   │   ├── AnalysesTimePlot.vue
│   │   │   │   └── ... (10+ more analysis components)
│   │   │   ├── tables/                 # Data table components
│   │   │   │   ├── TablesEntities.vue
│   │   │   │   ├── TablesGenes.vue
│   │   │   │   ├── TablesPhenotypes.vue
│   │   │   │   └── TablesLogs.vue
│   │   │   └── small/                  # Reusable UI components
│   │   │       ├── GenericTable.vue
│   │   │       ├── TableHeaderLabel.vue
│   │   │       ├── TableSearchInput.vue
│   │   │       ├── TablePaginationControls.vue
│   │   │       └── ... (20+ more small components)
│   │   ├── views/                      # Page-level route components
│   │   │   ├── Home.vue                # Landing page
│   │   │   ├── Login.vue               # Authentication page
│   │   │   ├── User.vue                # User profile
│   │   │   ├── PasswordReset.vue       # Password recovery
│   │   │   ├── Register.vue            # User registration
│   │   │   ├── API.vue                 # API documentation
│   │   │   ├── tables/                 # Data browser views
│   │   │   │   ├── Entities.vue
│   │   │   │   ├── Genes.vue
│   │   │   │   └── Phenotypes.vue
│   │   │   ├── analyses/               # Visualization views
│   │   │   │   ├── Analyses.vue
│   │   │   │   ├── Publications.vue
│   │   │   │   └── Statistics.vue
│   │   │   ├── review/                 # Peer review interface
│   │   │   │   ├── Review.vue
│   │   │   │   └── ReviewDetail.vue
│   │   │   ├── curate/                 # Data curation interface
│   │   │   │   └── Curate.vue
│   │   │   ├── admin/                  # Administration pages
│   │   │   │   └── Admin.vue
│   │   │   ├── help/                   # Documentation
│   │   │   │   └── Help.vue
│   │   │   └── pages/                  # Static pages
│   │   │       ├── About.vue
│   │   │       └── FAQ.vue
│   │   ├── router/
│   │   │   ├── index.js                # Router initialization
│   │   │   └── routes.js               # Route definitions (50+ routes)
│   │   ├── assets/
│   │   │   ├── js/
│   │   │   │   ├── eventBus.js         # Vue event bus for component communication
│   │   │   │   ├── functions.js        # Global utility functions
│   │   │   │   ├── constants/          # Application constants
│   │   │   │   │   ├── url_constants.js
│   │   │   │   │   ├── role_constants.js
│   │   │   │   │   └── main_nav_constants.js
│   │   │   │   ├── classes/            # Data model classes
│   │   │   │   │   └── submission/
│   │   │   │   │       ├── submissionEntity.js
│   │   │   │   │       ├── submissionReview.js
│   │   │   │   │       └── ... (5 more submission classes)
│   │   │   │   └── mixins/             # Shared component logic
│   │   │   │       ├── tableMethodsMixin.js      # Table pagination/filtering
│   │   │   │       ├── tableDataMixin.js         # Table state management
│   │   │   │       ├── colorAndSymbolsMixin.js   # UI constants
│   │   │   │       ├── textMixin.js              # Text utilities
│   │   │   │       └── ... (5+ more mixins)
│   │   │   ├── css/
│   │   │   │   ├── custom.css           # Global styles
│   │   │   │   └── ... (component styles)
│   │   │   └── scss/
│   │   │       └── custom.scss          # SCSS variables and mixins
│   │   ├── plugins/                    # Vue plugins
│   │   ├── config/                     # Frontend configuration
│   │   └── registerServiceWorker.js    # PWA service worker registration
│   ├── public/                         # Static assets (served as-is)
│   │   ├── index.html                  # HTML entry point
│   │   ├── SysNDD_logo.webp            # Logo image
│   │   └── ... (other static assets)
│   ├── package.json                    # npm dependencies and scripts
│   ├── package-lock.json               # npm lock file
│   ├── vue.config.js                   # Vue CLI build configuration
│   ├── .env.local                      # Local environment variables (git ignored)
│   ├── .browserslistrc                 # Browser compatibility targets
│   ├── babel.config.js                 # Babel transpilation config
│   ├── .eslintrc.js                    # ESLint configuration
│   ├── Dockerfile                      # Docker image definition
│   └── README.md
├── db/                                 # Database setup and migrations
│   ├── 01_Rcommands_sysndd_db_table_hgnc_non_alt_loci_set.R
│   ├── 02_Rcommands_sysndd_db_table_disease_ontology_set.R
│   ├── 03_Rcommands_sysndd_db_table_mode_of_inheritance_list.R
│   ├── 04_Rcommands_sysndd_db_table_ndd_entity.R
│   ├── ... (17+ more migration scripts numbered 01-17)
│   ├── A_Rcommands_create-database-tables.R
│   ├── B_Rcommands_set-table-data-types.R
│   ├── C_Rcommands_set-table-connections.R
│   ├── functions/                      # Database utility functions
│   ├── data/                           # Data files for bulk loading
│   ├── results/                        # Generated database setup results
│   ├── updates/                        # Incremental update scripts
│   ├── sysndd_db.yml                   # Database config
│   └── README.md
├── documentation/                      # Project documentation
├── manuscript/                         # Paper and research documents
├── docker-compose.yml                  # Multi-container orchestration
├── deployment.sh                       # Deployment automation script
├── CLAUDE.md                           # Claude AI guidelines for this project
├── README.md                           # Project overview
├── LICENSE.md                          # MIT-0 license
└── .gitignore
```

## Directory Purposes

**`api/`:**
- Purpose: R-based REST API service built with Plumber
- Contains: Server startup, endpoint definitions, business logic, database functions
- Key files: `start_sysndd_api.R` (entry point), `endpoints/*.R` (routes), `functions/*.R` (logic)

**`app/`:**
- Purpose: Vue.js single-page application frontend
- Contains: Vue components, routes, assets, build configuration
- Key files: `src/main.js` (entry point), `src/router/routes.js` (routes), `src/views/` and `src/components/` (UI)

**`db/`:**
- Purpose: Database schema, migrations, and initialization scripts
- Contains: Numbered migration files for tables and relationships
- Key files: `0X_Rcommands_*.R` (table creation), `A_Rcommands_*.R` through `C_Rcommands_*.R` (setup)

**`api/endpoints/`:**
- Purpose: Isolated REST endpoint implementations
- Contains: 21 modular R files, each defining one or more routes via `@get`, `@post`, `@put`, `@delete` decorators
- Not imported as dependencies; mounted directly by router

**`api/functions/`:**
- Purpose: Domain-organized reusable helper functions
- Contains: 18 R files organized by concern (database, analyses, ontology, etc.)
- Sourced at startup; used by endpoints and other functions

**`app/src/components/`:**
- Purpose: Reusable Vue single-file components
- Organized by category: `analyses/` (charts), `tables/` (data display), `small/` (UI primitives)
- Used by views and other components via imports

**`app/src/views/`:**
- Purpose: Page-level components matching routes
- Organized by feature area: `tables/`, `analyses/`, `review/`, `curate/`, `admin/`, `help/`
- Each view typically wraps one or more reusable components

**`app/src/assets/js/`:**
- Purpose: JavaScript utilities and shared logic
- Organized: `mixins/` (Vue mixins), `classes/` (data models), `constants/` (app config)
- mixins are the primary code-sharing mechanism for Vue components

## Key File Locations

**Entry Points:**

- `api/start_sysndd_api.R`: API server initialization; loads config, creates pool, mounts endpoints
- `app/src/main.js`: Frontend app initialization; bootstraps Vue instance, router, Pinia
- `db/A_Rcommands_create-database-tables.R`: Initial database schema creation
- `db/B_Rcommands_set-table-data-types.R`: Database table column type definitions
- `db/C_Rcommands_set-table-connections.R`: Foreign key and relationship setup

**Configuration:**

- `api/config.yml`: Database credentials, API ports, secrets, mail settings
- `api/version_spec.json`: API version, title, description for OpenAPI spec
- `app/.env.local`: Frontend API endpoint URL and app configuration (git ignored)
- `app/vue.config.js`: Vue CLI build settings, proxy configuration
- `.planning/codebase/`: GSD planning documents (ARCHITECTURE.md, STRUCTURE.md, etc.)

**Core Logic:**

- `api/functions/database-functions.R`: All database CRUD operations
- `api/functions/endpoint-functions.R`: Shared endpoint utilities (pagination, filtering)
- `api/functions/helper-functions.R`: General-purpose utilities
- `api/functions/analyses-functions.R`: Statistical analysis implementations
- `app/src/assets/js/mixins/tableMethodsMixin.js`: Shared table pagination/filtering logic
- `app/src/assets/js/mixins/tableDataMixin.js`: Shared table state management

**Testing:**

- No automated test files detected; testing appears manual
- `api/scripts/pre-commit-check.R`: Pre-commit validation script
- `api/scripts/lint-and-fix.R`: Code quality and linting script

**Build & Deployment:**

- `docker-compose.yml`: Multi-container orchestration (API, frontend, database, backup)
- `api/Dockerfile`: API container build recipe
- `app/Dockerfile`: Frontend container build recipe
- `deployment.sh`: Deployment automation with config extraction

## Naming Conventions

**Files:**

- R scripts: `snake_case.R` (e.g., `database-functions.R`, `entity_endpoints.R`)
- Vue components: PascalCase (e.g., `TablesEntities.vue`, `GenericTable.vue`)
- Database migration: `NN_Rcommands_<description>.R` where NN is 01-17 (e.g., `04_Rcommands_sysndd_db_table_ndd_entity.R`)
- Configuration: `*.yml`, `*.json` (e.g., `config.yml`, `api_spec.json`)
- Scripts: Descriptive names in `scripts/` subdirectory (e.g., `lint-and-fix.R`)

**Directories:**

- R API: `api/` root with `endpoints/`, `functions/`, `scripts/`, `data/` subdirectories
- Vue app: `app/src/` with `components/`, `views/`, `router/`, `assets/` subdirectories
- Feature grouping: Named after domain (e.g., `analyses/`, `tables/`, `review/`, `curate/`)

**Functions:**

- R functions: `snake_case()` (e.g., `post_db_entity()`, `generate_sort_expressions()`)
- Vue methods: camelCase (e.g., `loadData()`, `handlePageChange()`)
- Vue computed/data: camelCase (e.g., `sortBy`, `filterString`, `currentPage`)

**Types:**

- R data types: Explicit (e.g., `as_tibble()`, `as.integer()`, `as.logical()`)
- Vue props: camelCase with type hints (e.g., `:sort-input="sort"` prop type String)

## Where to Add New Code

**New REST Endpoint:**
- Primary code: `api/endpoints/<feature>_endpoints.R` (create new file if feature doesn't exist)
- Helper functions: `api/functions/<domain>-functions.R` (add to existing or create new domain file)
- Database queries: `api/functions/database-functions.R` (if CRUD operation) or domain file
- Mount in: `api/start_sysndd_api.R` via `pr_mount("/api/<path>", pr("endpoints/<feature>_endpoints.R"))`

**New Vue Page/View:**
- Implementation: `app/src/views/<feature>/<PageName>.vue` (organize by feature area)
- Reusable components: `app/src/components/<category>/<ComponentName>.vue`
- Route definition: `app/src/router/routes.js` (add route object)
- Shared logic: `app/src/assets/js/mixins/<logicName>Mixin.js` (if shared across components)

**New Utility Function:**
- Shared R utilities: `api/functions/helper-functions.R` or new domain file if specialized
- Frontend utilities: `app/src/assets/js/functions.js` or new mixin in `app/src/assets/js/mixins/`
- Constants: `app/src/assets/js/constants/<domain>_constants.js`

**Database Schema Change:**
- Migration script: `db/NN_Rcommands_<description>.R` (incremental numbering starting after latest)
- Connection updates: `db/C_Rcommands_set-table-connections.R` (update foreign keys if applicable)
- Backup: Run before deploying to production

## Special Directories

**`api/_old/`:**
- Purpose: Archive of deprecated endpoint implementations
- Generated: No (manually maintained)
- Committed: Yes; kept for reference during refactoring
- Content: Old versions of monolithic files replaced by modular endpoints

**`api/results/`:**
- Purpose: Generated output files from analyses and ontology operations
- Generated: Yes; created at runtime by analysis functions
- Committed: Partially; `README.md` committed, generated files ignored
- Content: Ontology classification results, analysis outputs

**`api/logs/`:**
- Purpose: Runtime application logs
- Generated: Yes; created at startup
- Committed: No; `.gitignore` excludes
- Content: Plumber request logs with timestamps, methods, status codes, durations

**`app/public/`:**
- Purpose: Static files served as-is without processing
- Generated: No (manually maintained)
- Committed: Yes
- Content: `index.html`, logo images, favicon

**`app/dist/`:**
- Purpose: Production build output (not in repo)
- Generated: Yes; created by `npm run build`
- Committed: No; `.gitignore` excludes
- Content: Minified bundles, static assets

**`.planning/codebase/`:**
- Purpose: GSD (Getting Stuff Done) planning documents
- Generated: Yes; created by `/gsd:map-codebase` command
- Committed: Yes; maintained in git for team reference
- Content: `ARCHITECTURE.md`, `STRUCTURE.md`, `CONVENTIONS.md`, `TESTING.md`, `STACK.md`, `INTEGRATIONS.md`, `CONCERNS.md`

---

*Structure analysis: 2026-01-20*
