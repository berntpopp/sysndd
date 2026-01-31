# Architecture Patterns: LLM Cluster Summaries Integration

**Domain:** LLM-generated cluster summaries for neurodevelopmental disorder gene database
**Researched:** 2026-01-31
**Focus:** Integration with existing SysNDD architecture for v10.0 features

## Executive Summary

SysNDD has a well-established architecture for async operations (mirai job system), external API proxying (httr2 + caching), and database caching (pubtator pattern). The LLM cluster summaries feature integrates naturally by following these existing patterns.

**Key finding:** The existing infrastructure already provides 80% of what's needed. New components primarily involve creating a Gemini API client service and extending the cluster endpoints/views.

---

## Existing Architecture Overview

### Backend Architecture (R/Plumber API)

```
api/
+-- start_sysndd_api.R      # Entry point, loads all modules
+-- endpoints/              # Plumber endpoint definitions
|   +-- jobs_endpoints.R    # Async job submission/polling
|   +-- analysis_endpoints.R # Cluster data endpoints
+-- functions/              # Business logic
|   +-- job-manager.R       # mirai async job orchestration
|   +-- job-progress.R      # File-based progress tracking
|   +-- external-proxy-*.R  # External API clients (httr2)
|   +-- pubtator-functions.R # Database caching pattern
|   +-- db-helpers.R        # Transaction helpers
+-- services/               # Service layer (auth, entity, etc.)
+-- core/                   # Security, middleware, errors
```

### Frontend Architecture (Vue 3 + TypeScript)

```
app/src/
+-- composables/
|   +-- useAsyncJob.ts      # Job polling composable
|   +-- useNetworkData.ts   # Network visualization data
+-- components/analyses/
|   +-- AnalyseGeneClusters.vue       # Functional clusters view
|   +-- AnalysesPhenotypeClusters.vue # Phenotype clusters view
|   +-- NetworkVisualization.vue      # Cytoscape network
+-- views/admin/
|   +-- ManageAnnotations.vue         # Admin async job UI pattern
```

---

## Integration Points for LLM Features

### 1. Gemini API Client (NEW)

**Integration point:** `api/functions/` directory alongside other external proxy modules

**Pattern to follow:** `external-proxy-functions.R` + `external-proxy-gnomad.R`

```r
# New file: api/functions/llm-service.R
# Follows external-proxy pattern:
# - Uses httr2 for HTTP requests
# - Uses cachem for disk-based caching
# - Uses rate limiting (req_throttle)
# - Uses retry logic (req_retry)
# - Returns structured error responses
```

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| API key via env var | Consistent with existing pattern (OMIM_KEY, etc.) |
| httr2 for requests | Already used for all external APIs |
| Structured prompts in code | Prompts are version-controlled, testable |
| Response validation | Ensure JSON schema compliance before storage |

### 2. LLM Summary Storage (NEW)

**Integration point:** Database schema extension + repository layer

**Pattern to follow:** `pubtator_*_cache` tables + `pubtator-functions.R`

```sql
-- New table: llm_cluster_summary_cache
CREATE TABLE IF NOT EXISTS `llm_cluster_summary_cache` (
  `summary_id` INT AUTO_INCREMENT PRIMARY KEY,
  `cluster_type` ENUM('functional', 'phenotype') NOT NULL,
  `cluster_id` INT NOT NULL,
  `cluster_hash` VARCHAR(64) NOT NULL,  -- Hash of cluster gene composition
  `summary_text` TEXT NOT NULL,         -- LLM-generated summary
  `model_version` VARCHAR(50) NOT NULL, -- e.g., "gemini-1.5-pro"
  `prompt_version` VARCHAR(20) NOT NULL,-- e.g., "v1.0"
  `validation_status` ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
  `validated_by` INT NULL,              -- FK to user table
  `validated_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `cluster_type_id_hash` (`cluster_type`, `cluster_id`, `cluster_hash`),
  INDEX `validation_status_idx` (`validation_status`),
  INDEX `cluster_type_idx` (`cluster_type`)
);
```

**Rationale for schema design:**
- `cluster_hash`: Allows cache invalidation when cluster composition changes (genes added/removed)
- `validation_status`: Supports human-in-the-loop validation before public display
- `prompt_version`: Enables regeneration when prompts improve
- Follows pubtator pattern of query hash + data caching

### 3. Batch Summary Generation Job (NEW)

**Integration point:** `api/endpoints/jobs_endpoints.R`

**Pattern to follow:** Existing HGNC update job, ontology update job

```r
# New endpoint: POST /api/jobs/llm_summaries/submit
# Follows existing job submission pattern:
# 1. Extract all data BEFORE mirai call (DB connections can't cross process boundary)
# 2. Check for duplicate job
# 3. Create async job with create_job()
# 4. Return HTTP 202 Accepted with job_id
```

**Job execution flow:**
```
1. Fetch all clusters needing summaries (pending or outdated hash)
2. For each cluster:
   a. Build context (gene list, enrichment terms, phenotypes)
   b. Call Gemini API
   c. Validate response format
   d. Store in llm_cluster_summary_cache with status='pending'
3. Report progress via file-based progress tracking
```

**Considerations:**
- Rate limiting: Gemini API has quota limits (follow external-proxy pattern)
- Batch size: Process in chunks to avoid timeout (existing job-manager has 30-min timeout)
- Idempotency: Check cluster_hash before regenerating

### 4. Summary Display in Cluster Views (MODIFY)

**Integration point:** Existing cluster visualization components

**Components to modify:**
- `AnalyseGeneClusters.vue` - Add summary display section
- `AnalysesPhenotypeClusters.vue` - Add summary display section

**Pattern to follow:** Existing card/section structure in these components

```vue
<!-- New section within existing cluster detail view -->
<BCard v-if="clusterSummary" class="mb-3">
  <template #header>
    <h6>AI-Generated Summary</h6>
    <BBadge :variant="summaryBadgeVariant">{{ summaryStatus }}</BBadge>
  </template>
  <div v-html="renderedSummary" />
  <template #footer v-if="isAdmin">
    <BButton @click="approveSummary">Approve</BButton>
    <BButton @click="regenerateSummary">Regenerate</BButton>
  </template>
</BCard>
```

**API endpoint needed:**
```
GET /api/analysis/cluster_summary?cluster_type=functional&cluster_id=1
```

### 5. Admin Validation Panel (NEW)

**Integration point:** `app/src/views/admin/` directory

**Pattern to follow:** `ManageAnnotations.vue`

**New component:** `ManageLLMSummaries.vue`

Features:
- List all summaries with validation_status filter
- Inline preview of summary + cluster context
- Approve/Reject/Regenerate actions
- Bulk operations using existing `useBulkSelection` composable
- Async job trigger using existing `useAsyncJob` composable

---

## Component Boundaries

### New Components

| Component | Location | Responsibility | Communicates With |
|-----------|----------|----------------|-------------------|
| `llm-service.R` | api/functions/ | Gemini API client, prompt management | job-manager, db-helpers |
| `llm-repository.R` | api/functions/ | Summary CRUD operations | db-helpers, pool |
| `llm_endpoints.R` | api/endpoints/ | Summary retrieval, validation endpoints | llm-repository, llm-service |
| `ManageLLMSummaries.vue` | app/views/admin/ | Admin validation UI | llm_endpoints, useAsyncJob |
| `ClusterSummary.vue` | app/components/analyses/ | Summary display component | llm_endpoints |

### Modified Components

| Component | Modification |
|-----------|--------------|
| `jobs_endpoints.R` | Add llm_summaries/submit endpoint |
| `AnalyseGeneClusters.vue` | Import and use ClusterSummary component |
| `AnalysesPhenotypeClusters.vue` | Import and use ClusterSummary component |
| `start_sysndd_api.R` | Source new llm-*.R files |
| router/routes.ts | Add ManageLLMSummaries route |

---

## Data Flow

### Summary Generation Flow

```
Admin triggers "Generate Summaries" job
                |
                v
    jobs_endpoints.R receives POST
                |
                v
    job-manager.R creates mirai job
                |
                v
    [In daemon process]
    llm-service.R fetches cluster data
                |
                v
    llm-service.R builds prompt with context
                |
                v
    llm-service.R calls Gemini API (httr2)
                |
                v
    llm-service.R validates response
                |
                v
    llm-repository.R stores in DB (status=pending)
                |
                v
    Job completes, admin notified
                |
                v
    Admin reviews in ManageLLMSummaries.vue
                |
                v
    Admin approves -> status changes to 'approved'
                |
                v
    Public users see summary in cluster views
```

### Summary Retrieval Flow

```
User views cluster visualization
            |
            v
AnalyseGeneClusters.vue loads cluster data
            |
            v
Component fetches summary from /api/analysis/cluster_summary
            |
            v
llm_endpoints.R queries llm-repository
            |
            v
Returns summary if status='approved', else null
            |
            v
ClusterSummary.vue renders if available
```

---

## Patterns to Follow

### Pattern 1: External API Client (from external-proxy-*.R)

**What:** Standardized way to call external APIs with retry, caching, rate limiting

**When:** Any new external API integration (Gemini, future LLM providers)

**Example:**
```r
# From external-proxy-functions.R pattern
make_gemini_request <- function(prompt, model = "gemini-1.5-pro") {
  tryCatch({
    req <- request(gemini_endpoint) %>%
      req_throttle(rate = GEMINI_RATE_LIMIT$capacity / GEMINI_RATE_LIMIT$fill_time_s) %>%
      req_retry(max_tries = 3, max_seconds = 60, backoff = ~ 2^.x) %>%
      req_timeout(30) %>%
      req_headers(Authorization = paste("Bearer", Sys.getenv("GEMINI_API_KEY"))) %>%
      req_body_json(list(prompt = prompt, model = model)) %>%
      req_error(is_error = ~FALSE)

    response <- req_perform(req)
    # ... handle response
  }, error = function(e) {
    create_external_error("gemini", conditionMessage(e))
  })
}
```

### Pattern 2: Database Caching with Hashing (from pubtator-functions.R)

**What:** Cache external/computed data in DB with hash-based invalidation

**When:** Storing LLM summaries, any expensive computed results

**Example:**
```r
# Generate hash from cluster composition
generate_cluster_hash <- function(cluster_genes) {
  genes_sorted <- sort(cluster_genes)
  digest::digest(paste(genes_sorted, collapse = ","), algo = "sha256")
}

# Check if regeneration needed
needs_regeneration <- function(cluster_id, cluster_type, current_genes) {
  current_hash <- generate_cluster_hash(current_genes)
  stored <- get_summary_by_cluster(cluster_id, cluster_type)
  is.null(stored) || stored$cluster_hash != current_hash
}
```

### Pattern 3: Async Job with Progress (from job-manager.R + ManageAnnotations.vue)

**What:** Long-running operations via mirai with polling UI

**When:** Batch summary generation, any operation > 5 seconds

**Backend pattern:**
```r
create_job(
  operation = "llm_summaries",
  params = list(cluster_data = cluster_data),
  executor_fn = function(params) {
    progress <- create_progress_reporter(params$.__job_id__)
    total <- length(params$cluster_data)

    for (i in seq_along(params$cluster_data)) {
      progress("processing", sprintf("Cluster %d of %d", i, total), i, total)
      # ... process cluster
    }
    list(status = "completed", processed = total)
  }
)
```

**Frontend pattern:**
```typescript
const { startJob, status, progress, elapsedTimeDisplay } = useAsyncJob(
  (jobId) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

async function generateSummaries() {
  const response = await axios.post('/api/jobs/llm_summaries/submit');
  startJob(response.data.job_id);
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Synchronous LLM Calls in Request Handler

**What:** Calling Gemini API directly in a GET/POST handler

**Why bad:** LLM calls can take 5-30 seconds, blocking the Plumber thread

**Instead:** Use async job system for any LLM generation

### Anti-Pattern 2: Storing Raw LLM Output Without Validation

**What:** Blindly storing whatever Gemini returns

**Why bad:** LLM output can be malformed, contain hallucinations, or miss required fields

**Instead:** Validate response schema, check for required sections, flag for human review

### Anti-Pattern 3: Public Display of Unvalidated Summaries

**What:** Showing LLM summaries to users before human approval

**Why bad:** Medical/scientific database requires accuracy; LLMs can hallucinate

**Instead:** Always require validation_status='approved' before public display

### Anti-Pattern 4: Regenerating on Every View

**What:** Calling LLM API each time a user views a cluster

**Why bad:** Expensive, slow, wastes API quota

**Instead:** Pre-generate in batch job, serve from cache, regenerate only when cluster composition changes

---

## Scalability Considerations

| Concern | At 100 clusters | At 1,000 clusters | At 10,000 clusters |
|---------|-----------------|-------------------|-------------------|
| Initial generation | ~5-10 min batch job | ~1-2 hour batch job | Consider chunking/scheduling |
| Storage | ~100KB | ~1MB | ~10MB (trivial for MySQL) |
| Cache invalidation | Check all on cluster update | Index on cluster_hash | Consider async invalidation queue |
| Admin validation | Manual review feasible | Need bulk approve tools | Consider auto-approve for minor changes |

---

## Suggested Build Order

Based on dependencies and existing infrastructure:

### Phase 1: Foundation (Backend)
- Create `llm-service.R` with Gemini client
- Create `llm-repository.R` with CRUD operations
- Add database migration for `llm_cluster_summary_cache`
- Add to `start_sysndd_api.R` source list

### Phase 2: Batch Generation (Backend)
- Add `llm_summaries/submit` endpoint to `jobs_endpoints.R`
- Implement batch generation logic with progress
- Add summary retrieval endpoint

### Phase 3: Display (Frontend)
- Create `ClusterSummary.vue` component
- Integrate into `AnalyseGeneClusters.vue`
- Integrate into `AnalysesPhenotypeClusters.vue`

### Phase 4: Admin Validation (Frontend)
- Create `ManageLLMSummaries.vue`
- Add route and navigation
- Implement approve/reject/regenerate actions

### Phase 5: Polish
- Add LLM-as-judge validation pipeline (optional, if time)
- Add summary versioning/history
- Add regeneration triggers on cluster changes

---

## Configuration Requirements

```yaml
# config.yml additions
llm:
  provider: gemini
  model: gemini-1.5-pro
  api_key_env: GEMINI_API_KEY
  rate_limit:
    requests_per_minute: 10
  cache_ttl_days: 30
  prompt_version: v1.0
```

```bash
# .env additions
GEMINI_API_KEY=your_api_key_here
```

---

## Roadmap Implications

Based on this architecture analysis, the suggested phase structure for v10.0 LLM features:

1. **Phase: LLM Foundation** - Create service layer, DB schema, basic repository
   - Addresses: Gemini integration, summary storage
   - Avoids: Premature frontend work before backend is stable

2. **Phase: Batch Generation** - Implement async job for summary generation
   - Addresses: Scalable generation, progress tracking
   - Avoids: Synchronous API calls, timeout issues

3. **Phase: User-Facing Display** - Add summaries to cluster views
   - Addresses: Value delivery to end users
   - Requires: Phases 1-2 complete

4. **Phase: Admin Validation** - Human-in-the-loop review
   - Addresses: Scientific accuracy, quality control
   - Avoids: Unvalidated content reaching users

5. **Phase: Automation (Optional)** - LLM-as-judge, auto-regeneration
   - Addresses: Reduced manual review burden
   - Requires: All previous phases stable

**Research flags for phases:**
- Phase 1: Standard patterns, LOW research risk
- Phase 2: Standard patterns, LOW research risk
- Phase 3: Standard patterns, LOW research risk
- Phase 4: Standard patterns, LOW research risk
- Phase 5: May need research on LLM-as-judge approaches

---

## Sources

- Existing SysNDD codebase analysis (HIGH confidence)
- External proxy pattern: `api/functions/external-proxy-*.R`
- Job manager pattern: `api/functions/job-manager.R`
- Pubtator caching pattern: `api/functions/pubtator-functions.R`
- Admin UI pattern: `app/src/views/admin/ManageAnnotations.vue`
- Async job composable: `app/src/composables/useAsyncJob.ts`
- Cluster visualization: `app/src/components/analyses/AnalyseGeneClusters.vue`
- Database schema patterns: `db/16_Rcommands_sysndd_db_pubtator_cache_table.R`

**Confidence Assessment:** HIGH - Based entirely on existing codebase patterns with minimal new external dependencies.
