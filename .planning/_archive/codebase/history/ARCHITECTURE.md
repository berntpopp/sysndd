# Architecture

**Analysis Date:** 2026-01-20

## Pattern Overview

**Overall:** Full-stack client-server architecture with modular microservices pattern

**Key Characteristics:**
- **Separation of concerns:** R-based REST API and Vue.js SPA frontend operate independently
- **Modular endpoints:** API functionality split into specialized endpoint files mounted on a root Plumber router
- **Stateless API:** RESTful design with connection pooling and JWT authentication
- **Client-side rendering:** Vue 2 single-page application with client-side routing and state management
- **Database-centric:** All business logic flows through MariaDB with connection pooling for concurrency

## Layers

**Presentation Layer:**
- Purpose: User interface and client-side logic for displaying and interacting with data
- Location: `app/src/`
- Contains: Vue 2 single-file components, views, routing configuration, global mixins
- Depends on: REST API endpoints, local storage for authentication tokens
- Used by: End users via web browser

**API Gateway / Routing Layer:**
- Purpose: Main entry point that orchestrates all requests, applies filters, manages mounts
- Location: `api/start_sysndd_api.R`
- Contains: Plumber router configuration, CORS filter, authentication filter, hook definitions
- Depends on: All endpoint files, function libraries, database pool
- Used by: Frontend via HTTP requests

**Business Logic Layer:**
- Purpose: Endpoint-specific logic that handles requests, validates input, calls helper functions
- Location: `api/endpoints/`
- Contains: 21 endpoint files (entity, gene, phenotype, review, analysis, etc.)
- Depends on: Helper functions, database-functions, external APIs
- Used by: Plumber router to execute endpoint handlers

**Domain Functions Layer:**
- Purpose: Reusable, domain-specific business logic organized by concern
- Location: `api/functions/`
- Contains: 18 function files (database, helper, analyses, publication, ontology, etc.)
- Depends on: Database pool, external libraries (tidyverse, biomaRt, etc.)
- Used by: Endpoints and other functions

**Data Access Layer:**
- Purpose: Database interactions, connection pooling, query execution
- Location: `api/functions/database-functions.R`
- Contains: Functions for CRUD operations on all database tables
- Depends on: RMariaDB, Pool package, config settings
- Used by: Endpoint handlers and business logic functions

**Database Layer:**
- Purpose: Data persistence for neurodevelopmental disorder entities, reviews, publications
- Location: MariaDB (docker container or localhost connection)
- Contains: 17+ relational tables (ndd_entity, ndd_review, ndd_entity_review, publication, user, etc.)
- Depends on: Application code for queries
- Used by: Data access layer via connection pool

**Frontend State Management:**
- Purpose: Global state and component state for UI responsiveness
- Location: `app/src/` (Pinia store configuration in `main.js`, per-component state in mixins)
- Contains: Event bus (`assets/js/eventBus.js`), table data mixins, color/text constants
- Depends on: Vue components
- Used by: Vue components for reactive data binding

## Data Flow

**Entity Retrieval Flow:**

1. User navigates to `/Entities` route
2. Vue Router renders `views/tables/Entities.vue` component
3. Component mounts `components/tables/TablesEntities.vue` with route query parameters
4. `TablesEntities` mixes in `tableMethodsMixin` and `tableDataMixin` for methods/state
5. `loadData()` method constructs API URL with query params (sort, filter, fields, pagination)
6. Axios HTTP GET request to `/api/entity?sort=...&filter=...&page_after=...&page_size=...`
7. Plumber router receives request, applies `corsFilter` and `checkSignInFilter`
8. Request routed to `endpoints/entity_endpoints.R` handler function
9. Endpoint executes: `generate_sort_expressions()` → `generate_filter_expressions()` → database query
10. Pool connection executes query on `ndd_entity_view` table
11. Results collected, paginated links generated, response serialized to JSON
12. Vue component receives response, updates reactive data properties
13. Template reactively re-renders table with new data

**Authentication Flow:**

1. User enters credentials in `views/Login.vue`
2. POST to `/api/auth/signin` with username/password
3. `endpoints/authentication_endpoints.R` validates against `user` table
4. If valid, generates JWT token using `jose` package with secret from config
5. Returns token to frontend (stored in localStorage)
6. Subsequent requests include `Authorization: Bearer {token}` header
7. `checkSignInFilter` decodes JWT using same secret
8. Sets `req$user_id` and `req$user_role` for downstream handlers
9. GET requests proceed without auth; POST/PUT/DELETE require valid token
10. Token expiry checked; 401 response if expired

**Search/Filter Flow:**

1. User types in search box in table component
2. Debounce delay (500ms) prevents excessive API calls
3. `filtered()` method converts filter object to string format
4. `loadData()` constructs SQL filter expressions using `generate_filter_expressions()`
5. Filters applied with tidy evaluation (`!!!rlang::parse_exprs()`)
6. Database returns filtered subset
7. Cursor pagination applied: returns `page_after` item + next `page_size` rows
8. Response includes `links.next` URL with updated cursor
9. Frontend displays paginated results with previous/next navigation

**State Management:**

- **Frontend State:** Vue reactive data in component `data()`, mixins for shared state (colors, symbols, text constants)
- **API State:** Ephemeral - calculated per request; uses `memoise()` for expensive functions (caching layer)
- **Database State:** Persistent relational data with transaction support
- **Session State:** JWT token stored in browser localStorage; user role embedded in token

## Key Abstractions

**Plumber Router Pattern:**
- Purpose: Central HTTP request dispatcher with pluggable middleware (filters, hooks)
- Examples: `pr_filter()` for CORS/auth, `pr_hook()` for pre/post-route logging, `pr_mount()` for endpoints
- Pattern: Functional composition with `%>%` pipe operator chains filters and mounts

**Endpoint Module Pattern:**
- Purpose: Isolated, self-contained API route definitions
- Examples: `api/endpoints/entity_endpoints.R`, `api/endpoints/gene_endpoints.R`
- Pattern: Each file contains `@get`, `@post`, `@put`, `@delete` roxygen-tagged functions; no cross-endpoint dependencies

**Function Library Organization:**
- Purpose: Reusable logic organized by domain/concern
- Examples: `database-functions.R` for DB operations, `analyses-functions.R` for statistical functions
- Pattern: Standalone R scripts sourced in `start_sysndd_api.R`; no circular dependencies

**Vue Component Composition:**
- Purpose: Encapsulate UI logic and presentation in single-file components
- Examples: `TablesEntities.vue` combines template, script, and scoped styles
- Pattern: Mixins provide shared methods (`tableMethodsMixin`), props pass data from parent routes

**Cursor Pagination Abstraction:**
- Purpose: Efficient pagination for large datasets without offset overhead
- Examples: `page_after` cursor tracks position; next page fetched from last item ID
- Pattern: Response includes `links.next` and `links.prev` for navigation

**Memoization for Performance:**
- Purpose: Cache expensive computations (statistical functions, gene clustering)
- Examples: `generate_stat_tibble_mem`, `gen_string_clust_obj_mem`
- Pattern: Functions wrapped with `memoise()` using 1-hour TTL cache

**Connection Pool Pattern:**
- Purpose: Efficient database access across concurrent requests
- Examples: `pool <<- dbPool(RMariaDB::MariaDB(), ...)`
- Pattern: Global pool object created at startup; all queries use `pool %>% tbl()` dplyr syntax

## Entry Points

**API Server Startup:**
- Location: `api/start_sysndd_api.R`
- Triggers: `Rscript start_sysndd_api.R` (local) or docker container startup
- Responsibilities:
  - Load configuration and environment variables
  - Source all helper function files
  - Create global database connection pool
  - Define authentication and CORS filters
  - Mount all endpoint modules
  - Start Plumber HTTP server on configured port

**Frontend Application Startup:**
- Location: `app/src/main.js`
- Triggers: Browser request to `/` (served by Vue dev server or nginx)
- Responsibilities:
  - Import Vue and plugins (VueRouter, Pinia, Bootstrap-Vue, VeeValidate)
  - Register global components and icons
  - Initialize Pinia store
  - Mount root Vue instance to `#app` element
  - Boot router for client-side navigation

**API Endpoint Handler:**
- Location: `api/endpoints/*.R` (e.g., `entity_endpoints.R`)
- Triggers: HTTP request matching route pattern (e.g., GET `/api/entity/`)
- Responsibilities:
  - Parse query parameters and validate input
  - Execute business logic (filtering, sorting, pagination)
  - Query database via connection pool
  - Format and serialize response
  - Return HTTP response with status code

**Frontend Route Handler:**
- Location: `app/src/router/routes.js`
- Triggers: Browser URL navigation or programmatic `this.$router.push()`
- Responsibilities:
  - Match URL to route definition
  - Lazy-load component if needed
  - Parse query parameters and pass as props
  - Render component in router-view outlet
  - Set meta tags (title, description)

## Error Handling

**Strategy:** Layered error handling with graceful degradation

**Patterns:**

**API Level (R):**
- Try-catch blocks in database operations; return error message if query fails
- HTTP status codes: 200 (success), 400 (bad input), 401 (auth failed), 500 (server error)
- Example: `tryCatch({ dbAppendTable(...) }, error = function(e) { return(e$message) })`

**Frontend Level (Vue):**
- Axios error interceptors log failed requests and display toast notifications
- Component error boundaries with try-catch in lifecycle hooks
- Loading spinner shown during requests; error message displayed if request fails
- Example: `this.$bvToast.toast('Error loading data', { variant: 'danger' })`

**Database Level:**
- Foreign key constraints prevent data integrity violations
- NOT NULL constraints on required columns
- Transaction rollback on operation failure
- Connection pool timeout after 60 seconds of inactivity

## Cross-Cutting Concerns

**Logging:**
- Approach: Dual logging to file and database
- File: Temp log file using `logger` package; rotated per request
- Database: API requests logged to `api_log` table with method, path, status, duration, user_agent
- Hook: `pr_hook("postroute")` captures all request metadata before response sent

**Validation:**
- API: Input validation in endpoint handlers (e.g., checking sort column exists)
- Frontend: Form validation with VeeValidate; real-time error feedback on input
- Database: Constraints enforce data type and relationship validation

**Authentication:**
- Approach: JWT bearer tokens in Authorization header
- Token generation: `/api/auth/signin` endpoint creates JWT with user_id, user_role, exp
- Token verification: `checkSignInFilter` decodes and validates expiry on each request
- Roles: Administrator, Curator, Reviewer, Viewer (embedded in token)

**CORS:**
- Approach: Permissive CORS filter allowing all origins
- Filter: `corsFilter` sets `Access-Control-Allow-Origin: *`
- Handles OPTIONS preflight requests for non-simple requests

**Database Concurrency:**
- Approach: Connection pool with 60-second idle timeout
- Pool manages multiple concurrent connections to MariaDB
- Serializable isolation level for transactions (configurable)

---

*Architecture analysis: 2026-01-20*
