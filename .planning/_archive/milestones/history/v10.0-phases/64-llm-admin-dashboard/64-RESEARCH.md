# Phase 64: LLM Admin Dashboard - Research

**Researched:** 2026-02-01
**Domain:** R/Plumber API + Vue 3 Admin Interface
**Confidence:** HIGH

## Summary

Researched existing SysNDD patterns for building admin dashboard to manage LLM functionality. The project has established patterns for:

1. **R/Plumber Admin Endpoints** - Authorization with require_role, async job creation with mirai, structured JSON responses
2. **Vue 3 Admin Views** - Tab-based layout, async job composables (useAsyncJob), GenericTable component, Bootstrap-Vue-Next
3. **LLM Infrastructure** - Complete cache and logging system already exists (llm-cache-repository.R, llm-service.R), database tables ready
4. **Job Management** - Sophisticated async job system with progress tracking, deduplication, and automatic cleanup

The implementation can leverage extensive existing code. A detailed implementation plan already exists at `.planning/LLM_ADMIN_DASHBOARD_PLAN.md`.

**Primary recommendation:** Follow existing admin endpoint patterns (require_role, db_with_transaction), reuse GenericTable and useAsyncJob composables, extend llm-cache-repository.R with admin query functions.

## Standard Stack

The established libraries/tools for this domain:

### Backend (R/Plumber API)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| plumber | Latest | REST API framework | Project standard for all API endpoints |
| DBI + RMariaDB | Latest | Database access | Project standard via db-helpers.R |
| jsonlite | Latest | JSON serialization | Standard for API responses |
| logger | Latest | Structured logging | Project-wide logging standard |
| mirai | Latest | Async job execution | Used for all long-running admin operations |
| digest | Latest | Hash generation | Used for cache invalidation (SHA256) |
| ellmer | Latest | Gemini API client | Existing LLM integration |

### Frontend (Vue 3 + TypeScript)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue | 3.5.25 | UI framework | Project standard |
| TypeScript | Latest | Type safety | Project standard for all new code |
| Bootstrap-Vue-Next | 0.42.0 | UI components | Project standard (BTable, BCard, BTabs) |
| axios | Latest | HTTP client | Project standard for API calls |
| @vueuse/core | Latest | Composition utilities | Used in useAsyncJob (useIntervalFn) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| uuid | Latest | Job ID generation | Already used in job-manager.R |
| purrr | Latest | List transformations | Used in R data processing |

**Installation:**
All libraries already installed. No new dependencies required.

## Architecture Patterns

### Recommended Project Structure
```
api/
├── endpoints/
│   └── llm_admin_endpoints.R    # NEW - Admin-only LLM endpoints
├── functions/
│   ├── llm-cache-repository.R   # EXTEND - Add admin query functions
│   ├── llm-service.R            # EXTEND - Add prompt template functions
│   ├── llm-batch-generator.R    # EXISTS - Reuse for regeneration
│   └── job-manager.R            # EXISTS - Reuse for async jobs

app/src/
├── views/admin/
│   └── ManageLLM.vue            # NEW - Main admin view
├── components/llm/
│   ├── LlmConfigPanel.vue       # NEW
│   ├── LlmPromptEditor.vue      # NEW
│   ├── LlmCacheManager.vue      # NEW
│   └── LlmLogViewer.vue         # NEW
├── composables/
│   ├── useLlmAdmin.ts           # NEW - API calls for LLM admin
│   └── useAsyncJob.ts           # EXISTS - Reuse for job tracking
└── types/
    └── llm.ts                   # NEW - TypeScript interfaces
```

### Pattern 1: Admin Endpoint Authorization
**What:** All admin endpoints use require_role for authorization checking
**When to use:** Every LLM admin endpoint (config, prompts, cache, logs)
**Example:**
```r
# api/endpoints/llm_admin_endpoints.R
#* @tag llm-admin
#* @get /config
function(req, res) {
  require_role(req, res, "Administrator")

  list(
    gemini_configured = is_gemini_configured(),
    current_model = get_default_gemini_model(),
    available_models = list_gemini_models()
  )
}
```
**Source:** api/endpoints/admin_endpoints.R (lines 60, 219, 649)

### Pattern 2: Async Job with Progress Tracking
**What:** Long-running operations (regeneration) use create_job with progress reporting
**When to use:** Cache clearing + regeneration (may take minutes)
**Example:**
```r
# Regeneration endpoint (async)
#* @post /regenerate
function(req, res, cluster_type = "all") {
  require_role(req, res, "Administrator")

  # Create async job
  result <- create_job(
    operation = "llm_regenerate",
    params = list(cluster_type = cluster_type, db_config = list(...)),
    executor_fn = function(params) {
      reporter <- create_progress_reporter(params$.__job_id__)
      # ... regeneration logic with reporter("step", "message", current, total)
    },
    timeout_ms = 7200000  # 2 hours for large batches
  )

  res$status <- 202
  return(result)  # Contains job_id
}
```
**Source:** api/endpoints/admin_endpoints.R (lines 217-337, 687-911), api/functions/job-manager.R

**Frontend pattern:**
```typescript
// Use existing useAsyncJob composable
const regenerationJob = useAsyncJob(
  (jobId) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

// Trigger regeneration
const result = await axios.post(`${API_BASE}/regenerate`, { cluster_type: 'all' });
regenerationJob.startJob(result.data.job_id);

// Template shows progress automatically
<BProgress :value="regenerationJob.progressPercent.value" />
<span>{{ regenerationJob.elapsedTimeDisplay.value }}</span>
```
**Source:** app/src/composables/useAsyncJob.ts, app/src/views/admin/ManageAnnotations.vue (lines 34-78)

### Pattern 3: Database Transaction Pattern
**What:** Admin operations that modify data use db_with_transaction for atomicity
**When to use:** Cache clearing, validation status updates, prompt template saves
**Example:**
```r
clear_llm_cache <- function(cluster_type = "all") {
  db_with_transaction({
    # Build WHERE clause
    where <- if (cluster_type == "all") {
      ""
    } else {
      glue::glue("WHERE cluster_type = '{cluster_type}'")
    }

    result <- db_execute_statement(
      glue::glue("DELETE FROM llm_cluster_summary_cache {where}")
    )

    list(count = result)
  })
}
```
**Source:** api/functions/llm-cache-repository.R (update_validation_status, save_summary_to_cache)

### Pattern 4: Vue 3 Admin View with Tabs
**What:** Admin views use BCard with BTabs for organizing multiple sub-sections
**When to use:** Main ManageLLM.vue view (Overview, Config, Prompts, Cache, Logs)
**Example:**
```vue
<template>
  <BContainer fluid>
    <BRow class="justify-content-md-center py-2">
      <BCol col md="12">
        <BCard header-tag="header" body-class="p-0">
          <template #header>
            <h5 class="mb-0">LLM Administration</h5>
          </template>

          <BTabs v-model="activeTab" pills card>
            <BTab title="Overview" active>
              <!-- StatCard components, Quick Actions -->
            </BTab>
            <BTab title="Configuration">
              <LlmConfigPanel :config="config" />
            </BTab>
            <!-- More tabs... -->
          </BTabs>
        </BCard>
      </BCol>
    </BRow>
  </BContainer>
</template>
```
**Source:** app/src/views/admin/ManageAnnotations.vue (lines 1-150)

### Pattern 5: Composable for API State Management
**What:** Create dedicated composable (useLlmAdmin.ts) for all LLM admin API calls
**When to use:** Share API logic between components, centralize error handling
**Example:**
```typescript
// app/src/composables/useLlmAdmin.ts
export function useLlmAdmin() {
  const config = ref<LlmConfig | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchConfig(token: string): Promise<void> {
    loading.value = true;
    try {
      const response = await axios.get(`${API_BASE}/config`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      config.value = response.data;
    } catch (e) {
      error.value = 'Failed to fetch config';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  return { config, loading, error, fetchConfig };
}
```
**Source:** Established pattern from existing composables, documented in .planning/LLM_ADMIN_DASHBOARD_PLAN.md (lines 420-644)

### Anti-Patterns to Avoid
- **Don't bypass authorization:** Always use require_role, never check roles in frontend only
- **Don't use synchronous endpoints for long operations:** Cache clearing + regeneration MUST be async jobs
- **Don't duplicate table components:** Reuse GenericTable with slots for custom columns
- **Don't mix concerns:** Keep API calls in composables, not in components

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async job tracking | Custom polling logic | useAsyncJob composable | Handles polling, progress, elapsed time, cleanup |
| Job execution | Custom threading | job-manager.R create_job | Capacity limiting, deduplication, progress callbacks |
| Database transactions | Manual BEGIN/COMMIT | db_with_transaction | Automatic rollback, error handling |
| Table pagination | Custom table | GenericTable component | Sorting, filtering, slots for custom cells |
| Cache statistics | Manual aggregation | Extend llm-cache-repository.R | Existing patterns for query functions |
| Regeneration logic | New batch processor | llm-batch-generator.R | Already handles rate limiting, validation |

**Key insight:** The LLM infrastructure already exists. This phase is primarily about exposing existing functionality through admin endpoints and UI, not building new LLM features.

## Common Pitfalls

### Pitfall 1: Forgetting NULL Handling in DBI Parameter Binding
**What goes wrong:** DBI::dbBind requires all parameters to have length 1, but NULL has length 0
**Why it happens:** R's NULL is not the same as SQL NULL
**How to avoid:** Convert NULL to NA_character_ or NA_integer_ before binding
**Warning signs:** Error "all parameters must have length 1" when optional parameters are NULL
**Example:**
```r
# BAD - NULL has length 0
tags_json_str <- if (is.null(tags)) NULL else jsonlite::toJSON(tags)

# GOOD - NA has length 1
tags_json_str <- if (is.null(tags)) {
  NA_character_
} else {
  jsonlite::toJSON(tags)
}
```
**Source:** api/functions/llm-cache-repository.R (lines 207-214, 329-335)

### Pitfall 2: Not Checking Gemini API Configuration Before Operations
**What goes wrong:** Endpoints fail with cryptic errors if GEMINI_API_KEY not set
**Why it happens:** Environment variable may not be set in production
**How to avoid:** Always check is_gemini_configured() before LLM operations
**Warning signs:** "GEMINI_API_KEY environment variable is not set" errors in logs
**Example:**
```r
#* @post /regenerate
function(req, res, cluster_type = "all") {
  if (!is_gemini_configured()) {
    res$status <- 503
    return(list(error = "Gemini API not configured"))
  }
  # ... proceed with regeneration
}
```
**Source:** api/functions/llm-service.R (lines 688-697, 1070-1073)

### Pitfall 3: Forgetting to Pre-Fetch Database Data Before Async Jobs
**What goes wrong:** Database connection pool (pool) not available in mirai daemon workers
**Why it happens:** Mirai runs in separate R process, pool object doesn't cross process boundaries
**How to avoid:** Fetch all required database data BEFORE create_job, pass as params
**Warning signs:** "object 'pool' not found" errors in daemon workers
**Example:**
```r
# BAD - pool not accessible in daemon
result <- create_job(
  operation = "regenerate",
  params = list(cluster_type = cluster_type),
  executor_fn = function(params) {
    clusters <- pool %>% tbl("clusters") %>% collect()  # FAILS
  }
)

# GOOD - fetch before job creation
clusters <- pool %>% tbl("clusters") %>% collect()
result <- create_job(
  operation = "regenerate",
  params = list(clusters = clusters, db_config = list(...)),
  executor_fn = function(params) {
    # Create new connection in daemon
    conn <- DBI::dbConnect(RMariaDB::MariaDB(), ...)
    # Use params$clusters
  }
)
```
**Source:** api/endpoints/admin_endpoints.R (lines 222-243, 804-806)

### Pitfall 4: Not Setting Adequate Timeout for Long Jobs
**What goes wrong:** Jobs timeout prematurely (default 30 minutes)
**Why it happens:** Large regeneration jobs may take hours
**How to avoid:** Set timeout_ms parameter in create_job based on expected duration
**Warning signs:** Jobs fail with timeout status after exactly 30 minutes
**Example:**
```r
# For large batch regeneration (all clusters)
result <- create_job(
  operation = "llm_regenerate",
  params = list(...),
  executor_fn = function(params) { ... },
  timeout_ms = 7200000  # 2 hours (like publication refresh)
)
```
**Source:** api/endpoints/admin_endpoints.R (line 898), api/functions/job-manager.R (lines 67, 102)

### Pitfall 5: Incorrect Cluster Type Detection for Prompts
**What goes wrong:** Wrong prompt template used (functional prompt for phenotype cluster)
**Why it happens:** Cluster type must be explicitly tracked, not inferred from data
**How to avoid:** Always pass cluster_type parameter explicitly, validate against enum
**Warning signs:** Phenotype summaries mention genes/pathways instead of phenotypes
**Example:**
```r
# Validate cluster_type
if (!cluster_type %in% c("functional", "phenotype")) {
  rlang::abort("Invalid cluster_type - must be 'functional' or 'phenotype'")
}

# Use appropriate prompt builder
prompt <- if (cluster_type == "phenotype") {
  build_phenotype_cluster_prompt(cluster_data, vtest_threshold = 2)
} else {
  build_cluster_prompt(cluster_data, top_n_terms = 20)
}
```
**Source:** api/functions/llm-service.R (lines 700-705, 730-736)

### Pitfall 6: Frontend: Not Using Exact Column Names from R Response
**What goes wrong:** Table columns show undefined or empty data
**Why it happens:** R uses snake_case (cluster_type), Vue expects exact match
**How to avoid:** Match field keys to R response column names exactly
**Warning signs:** Table displays but columns are empty
**Example:**
```typescript
// BAD - camelCase doesn't match R response
const fields = [
  { key: 'cacheId', label: 'ID' },
  { key: 'clusterType', label: 'Type' }
]

// GOOD - snake_case matches R response
const fields = [
  { key: 'cache_id', label: 'ID' },
  { key: 'cluster_type', label: 'Type' }
]
```

## Code Examples

Verified patterns from existing codebase:

### Admin Endpoint with Pagination
```r
# api/endpoints/llm_admin_endpoints.R (NEW)
#* Get cached summaries with filtering
#* @tag llm-admin
#* @get /cache/summaries
#* @param cluster_type:str Filter by type
#* @param validation_status:str Filter by status
#* @param page:int Page number
#* @param per_page:int Items per page
#* @serializer json
function(req, res, cluster_type = NULL, validation_status = NULL,
         page = 1, per_page = 20) {
  require_role(req, res, "Administrator")

  get_cached_summaries_paginated(
    cluster_type = cluster_type,
    validation_status = validation_status,
    page = as.integer(page),
    per_page = as.integer(per_page)
  )
}
```
**Source:** Pattern from .planning/LLM_ADMIN_DASHBOARD_PLAN.md (lines 134-150)

### Paginated Query Function (Add to llm-cache-repository.R)
```r
# api/functions/llm-cache-repository.R (EXTEND)
#' Get cached summaries with pagination and filtering
#'
#' @param cluster_type Character, "functional", "phenotype", or NULL for all
#' @param validation_status Character, "pending", "validated", "rejected", or NULL
#' @param page Integer, page number (1-indexed)
#' @param per_page Integer, items per page
#'
#' @return List with data (tibble), total (count), page (current page)
#' @export
get_cached_summaries_paginated <- function(
  cluster_type = NULL,
  validation_status = NULL,
  page = 1,
  per_page = 20
) {
  # Build WHERE clause
  conditions <- c()
  params <- list()

  if (!is.null(cluster_type)) {
    conditions <- c(conditions, "cluster_type = ?")
    params <- c(params, cluster_type)
  }

  if (!is.null(validation_status)) {
    conditions <- c(conditions, "validation_status = ?")
    params <- c(params, validation_status)
  }

  where_clause <- if (length(conditions) > 0) {
    paste("WHERE", paste(conditions, collapse = " AND "))
  } else {
    ""
  }

  # Get total count
  total_query <- sprintf("SELECT COUNT(*) as total FROM llm_cluster_summary_cache %s", where_clause)
  total_result <- db_execute_query(total_query, params)
  total <- total_result$total[1]

  # Get paginated data
  offset <- (page - 1) * per_page
  data_query <- sprintf(
    "SELECT * FROM llm_cluster_summary_cache %s ORDER BY created_at DESC LIMIT ? OFFSET ?",
    where_clause
  )
  data_params <- c(params, list(as.integer(per_page), as.integer(offset)))
  data <- db_execute_query(data_query, data_params)

  list(
    data = data,
    total = total,
    page = page,
    per_page = per_page
  )
}
```

### Cache Statistics Function (Add to llm-cache-repository.R)
```r
# api/functions/llm-cache-repository.R (EXTEND)
#' Get cache statistics for admin dashboard
#'
#' @return List with summary statistics
#' @export
get_cache_statistics <- function() {
  # Overall stats
  overall <- db_execute_query(
    "SELECT
      COUNT(*) as total_entries,
      SUM(CASE WHEN validation_status = 'pending' THEN 1 ELSE 0 END) as pending,
      SUM(CASE WHEN validation_status = 'validated' THEN 1 ELSE 0 END) as validated,
      SUM(CASE WHEN validation_status = 'rejected' THEN 1 ELSE 0 END) as rejected,
      MAX(created_at) as last_generation
    FROM llm_cluster_summary_cache
    WHERE is_current = TRUE"
  )

  # By type stats
  by_type <- db_execute_query(
    "SELECT
      cluster_type,
      COUNT(*) as count,
      SUM(CASE WHEN validation_status = 'validated' THEN 1 ELSE 0 END) as validated,
      SUM(CASE WHEN validation_status = 'pending' THEN 1 ELSE 0 END) as pending,
      SUM(CASE WHEN validation_status = 'rejected' THEN 1 ELSE 0 END) as rejected
    FROM llm_cluster_summary_cache
    WHERE is_current = TRUE
    GROUP BY cluster_type"
  )

  # Token usage and cost
  tokens <- db_execute_query(
    "SELECT
      SUM(tokens_input) as total_input,
      SUM(tokens_output) as total_output
    FROM llm_generation_log
    WHERE status = 'success'"
  )

  # Rough cost estimate (Gemini 2.5 Flash: $0.075/1M input, $0.30/1M output)
  cost_usd <- (tokens$total_input[1] %||% 0) * 0.075 / 1e6 +
              (tokens$total_output[1] %||% 0) * 0.30 / 1e6

  list(
    total_entries = overall$total_entries[1],
    by_status = list(
      pending = overall$pending[1],
      validated = overall$validated[1],
      rejected = overall$rejected[1]
    ),
    by_type = setNames(
      lapply(split(by_type, by_type$cluster_type), as.list),
      by_type$cluster_type
    ),
    last_generation = overall$last_generation[1],
    total_tokens_used = (tokens$total_input[1] %||% 0) + (tokens$total_output[1] %||% 0),
    estimated_cost_usd = cost_usd
  )
}
```

### Frontend Composable Pattern
```typescript
// app/src/composables/useLlmAdmin.ts (NEW)
import { ref, readonly } from 'vue';
import axios from 'axios';

const API_BASE = `${import.meta.env.VITE_API_URL}/api/llm`;

export function useLlmAdmin() {
  const config = ref<LlmConfig | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchConfig(token: string): Promise<void> {
    loading.value = true;
    error.value = null;
    try {
      const response = await axios.get<LlmConfig>(`${API_BASE}/config`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      config.value = response.data;
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch config';
      throw e;
    } finally {
      loading.value = false;
    }
  }

  async function clearCache(
    token: string,
    clusterType: 'all' | 'functional' | 'phenotype'
  ): Promise<{ cleared_count: number }> {
    const response = await axios.delete(`${API_BASE}/cache`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { cluster_type: clusterType }
    });
    return response.data;
  }

  return {
    config: readonly(config),
    loading: readonly(loading),
    error: readonly(error),
    fetchConfig,
    clearCache
  };
}
```
**Source:** Pattern from existing composables (useAsyncJob.ts)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synchronous ontology update | Async jobs with mirai | Phase 63 | Admin operations must be async |
| Manual polling loops | useAsyncJob composable | Recent | All async jobs use this pattern |
| Bootstrap-Vue 2 | Bootstrap-Vue-Next | Migration | Use BTable, BCard, BTabs from new library |
| Options API | Composition API + script setup | Project standard | All new components use Composition API |

**Deprecated/outdated:**
- Synchronous admin endpoints for long operations (use async jobs instead)
- Custom polling logic (use useAsyncJob)
- Direct pool usage in daemon workers (pre-fetch data, pass db_config)

## Open Questions

Things that couldn't be fully resolved:

1. **Prompt Template Storage Migration**
   - What we know: Current prompts hardcoded in llm-service.R (build_cluster_prompt, build_phenotype_cluster_prompt)
   - What's unclear: Best migration path to database-stored templates without breaking existing summaries
   - Recommendation: Phase 1 - Add llm_prompt_templates table, keep hardcoded as "v1.0" defaults. Phase 2 - Add UI for editing. Prompts are versioned (prompt_version field), so summaries always know which prompt generated them.

2. **Model Selection Persistence**
   - What we know: get_default_gemini_model reads GEMINI_MODEL env var
   - What's unclear: Should model changes persist across API restarts or be session-only?
   - Recommendation: Session-only (current behavior). For persistence, would need database config table or .env file writes (security concern).

3. **Cache Regeneration Scope**
   - What we know: trigger_llm_batch_generation exists and handles batch processing
   - What's unclear: Should regeneration skip existing validated summaries or force regenerate all?
   - Recommendation: Add 'force' parameter (default false). If false, skip validated. If true, regenerate all and mark old as non-current.

4. **Manual Validation vs LLM Judge**
   - What we know: LLM judge auto-validates, but admins can override
   - What's unclear: Should manual validation override LLM judge verdict permanently?
   - Recommendation: Yes - add validated_by user_id field. Manual validation is authoritative. Store both llm_judge_verdict and manual validation in cache table.

## Sources

### Primary (HIGH confidence)
- api/endpoints/admin_endpoints.R - Admin endpoint patterns (authorization, async jobs, transactions)
- api/functions/llm-cache-repository.R - Existing cache operations (hash, lookup, save, logging)
- api/functions/llm-service.R - LLM service patterns (prompts, generation, validation)
- api/functions/job-manager.R - Async job creation and management (mirai, progress)
- api/functions/llm-judge.R - LLM validation patterns
- app/src/composables/useAsyncJob.ts - Async job tracking composable
- app/src/views/admin/ManageAnnotations.vue - Admin view structure (tabs, jobs, progress)
- app/src/components/small/GenericTable.vue - Table component patterns
- db/migrations/006_add_llm_summary_cache.sql - Database schema (cache and log tables)
- .planning/LLM_ADMIN_DASHBOARD_PLAN.md - Detailed implementation plan

### Secondary (MEDIUM confidence)
- Project CLAUDE.md - CI/CD patterns, testing requirements
- Existing admin composables - State management patterns

### Tertiary (LOW confidence)
- None required - all critical patterns verified in codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, verified in package manifests
- Architecture: HIGH - Patterns extracted from existing admin endpoints and views
- Pitfalls: HIGH - Documented in existing code comments and error handling

**Research date:** 2026-02-01
**Valid until:** 2026-03-01 (30 days - stable patterns, unlikely to change)

**Files that must be read during planning:**
- api/endpoints/admin_endpoints.R (authorization, async job patterns)
- api/functions/llm-cache-repository.R (extend with admin queries)
- api/functions/job-manager.R (async job creation)
- app/src/composables/useAsyncJob.ts (job tracking pattern)
- db/migrations/006_add_llm_summary_cache.sql (schema)

**Key implementation decision:** This is primarily a UI exposure phase, not a new feature phase. 95% of backend logic already exists. Focus on creating clean admin endpoints that expose existing llm-cache-repository.R and llm-service.R functions.
