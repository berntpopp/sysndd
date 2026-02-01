# Phase 62: Admin & Infrastructure - Research

**Researched:** 2026-02-01
**Domain:** Admin Data Refresh + Documentation Infrastructure
**Confidence:** HIGH (codebase patterns well-documented, external tooling verified)

## Summary

This phase has two distinct work streams: modernizing the comparisons data import system and migrating documentation from bookdown to Quarto with GitHub Pages environment deployment.

**Comparisons Data Import:** The existing 639-line standalone R script (`db/11_Rcommands_sysndd_db_table_database_comparisons.R`) imports data from 7 external NDD databases. It uses file-based config, downloads data to disk, and performs extensive HGNC symbol lookups. The script needs refactoring into the established mirai async job pattern already used for PubTator, HGNC, and ontology updates.

**Documentation Migration:** The bookdown setup in `/documentation/` has 8 Rmd chapters with a custom `_bookdown.yml` and `_output.yml`. Migration to Quarto involves converting Rmd files to qmd, consolidating config into `_quarto.yml`, and switching the GitHub Actions workflow from `gh-pages` branch deployment to the modern `actions/deploy-pages` environment approach.

**Primary recommendation:** Follow existing patterns exactly - the API job infrastructure (job-manager.R, jobs_endpoints.R) and Vue admin patterns (ManageAnnotations.vue, useAsyncJob.ts) are battle-tested and provide the template for comparisons refresh.

## Standard Stack

The established libraries/tools for this domain:

### Core - Comparisons Data Refresh

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mirai | (renv) | Async daemon pool | Already used for all async jobs in API |
| DBI/RMariaDB | (renv) | Database operations | Standard database layer |
| tidyverse | (renv) | Data manipulation | Existing import script uses it |
| jsonlite | (renv) | JSON parsing | Used for Orphanet, HGNC API calls |
| httr2 or curl | (renv) | HTTP requests | Modern R HTTP client |
| pdftools | (renv) | PDF parsing | Required for Radboud PDF source |

### Core - Documentation

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Quarto | >= 1.4 | Documentation system | Official successor to bookdown |
| quarto-dev/quarto-actions | v2 | GitHub Actions | Official Quarto CI/CD |
| actions/deploy-pages | v4 | Pages deployment | GitHub's recommended approach |
| actions/upload-pages-artifact | v3 | Artifact upload | Required for Pages environment |
| actions/configure-pages | v4 | Pages setup | Required for Pages environment |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | (renv) | Logging | Already used in pubtator-functions.R |
| digest | (renv) | Hashing | Used for job deduplication |
| uuid | (renv) | Job IDs | Used by job-manager.R |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| mirai async | Direct synchronous | Timeouts on long downloads - not viable |
| pdftools | readr::read_lines | Can't parse PDF content |
| actions/deploy-pages | gh-pages branch | Legacy approach, less secure |

**Installation:**
```bash
# R packages already in renv.lock
# Quarto: install from quarto.org or GitHub releases
```

## Architecture Patterns

### Recommended API Structure for Comparisons

```
api/
├── endpoints/
│   └── jobs_endpoints.R          # Add: /comparisons_update/submit
├── functions/
│   ├── job-manager.R             # Existing: create_job(), get_job_status()
│   ├── job-progress.R            # Existing: progress reporting
│   ├── comparisons-functions.R   # NEW: Refactored import logic
│   └── comparisons-sources.R     # NEW: Source URL config fetching
├── data/
│   └── comparisons/              # NEW: Downloaded source files cache
```

### Pattern 1: Async Job Endpoint (from jobs_endpoints.R)

**What:** POST endpoint that submits mirai job, returns job_id for polling
**When to use:** Any long-running operation (>30 seconds)
**Example:**
```r
# Source: api/endpoints/jobs_endpoints.R lines 501-679
#* Submit Comparisons Update Job
#* @tag jobs
#* @post /comparisons_update/submit
function(req, res) {
  require_role(req, res, "Administrator")

  # CRITICAL: Extract database config BEFORE mirai
  db_config <- list(
    dbname   = dw$dbname,
    host     = dw$host,
    user     = dw$user,
    password = dw$password,
    port     = dw$port
  )

  # Check for duplicate
  dup_check <- check_duplicate_job("comparisons_update", list(operation = "comparisons_update"))
  if (dup_check$duplicate) {
    res$status <- 409
    # ... return existing job info
  }

  # Create async job
  result <- create_job(
    operation = "comparisons_update",
    params = list(db_config = db_config),
    timeout_ms = 1800000, # 30 min
    executor_fn = function(params) {
      progress <- create_progress_reporter(params$.__job_id__)
      # ... download and process all sources
    }
  )

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  list(job_id = result$job_id, status = "accepted", estimated_seconds = 300)
}
```

### Pattern 2: Progress Reporting in Daemon

**What:** File-based progress updates readable from main process
**When to use:** Multi-step operations with quantifiable progress
**Example:**
```r
# Source: api/functions/job-progress.R pattern
progress <- create_progress_reporter(params$.__job_id__)

# Report progress at each step
progress("download", "Downloading Radboud PDF...", current = 1, total = 7)
# ... download
progress("download", "Downloading gene2phenotype...", current = 2, total = 7)
# ... etc

progress("process", "Processing and merging data...", current = 7, total = 7)
```

### Pattern 3: All-or-Nothing Transaction

**What:** Wrap entire update in transaction, rollback on any failure
**When to use:** Multi-source data imports where partial success is invalid
**Example:**
```r
# Source: pubtator-functions.R db_with_transaction pattern
tryCatch({
  DBI::dbBegin(conn)

  # Delete existing comparisons data
  DBI::dbExecute(conn, "DELETE FROM ndd_database_comparison")

  # Insert all new data
  DBI::dbAppendTable(conn, "ndd_database_comparison", merged_data)

  # Update metadata timestamp
  DBI::dbExecute(conn,
    "UPDATE comparisons_config SET last_updated = NOW()")

  DBI::dbCommit(conn)
}, error = function(e) {
  DBI::dbRollback(conn)
  stop("Comparisons update failed: ", e$message)
})
```

### Pattern 4: Vue Admin Section (from ManageAnnotations.vue)

**What:** Card-based admin section with job status and progress
**When to use:** Any admin-triggered background job
**Example:**
```vue
<!-- Source: ManageAnnotations.vue lines 151-229 -->
<BCard header-tag="header" border-variant="dark" class="mb-3 text-start">
  <template #header>
    <h5 class="mb-0 font-weight-bold">
      Comparisons Data Refresh
      <span v-if="lastUpdated" class="badge bg-secondary ms-2 fw-normal">
        Last: {{ formatDate(lastUpdated) }}
      </span>
    </h5>
  </template>

  <BButton
    variant="primary"
    :disabled="comparisonsJob.isLoading.value"
    @click="refreshComparisons"
  >
    <BSpinner v-if="comparisonsJob.isLoading.value" small type="grow" class="me-2" />
    {{ comparisonsJob.isLoading.value ? 'Updating...' : 'Refresh Comparisons Data' }}
  </BButton>

  <!-- Progress display from useAsyncJob -->
  <div v-if="comparisonsJob.isLoading.value" class="mt-3">
    <BProgress :value="progressPercent" :animated="true" />
    <div class="small text-muted mt-1">{{ comparisonsJob.step.value }}</div>
  </div>
</BCard>
```

### Anti-Patterns to Avoid

- **Synchronous long downloads:** Never block the API process with 30+ second operations
- **Partial database updates:** Use transactions to ensure all-or-nothing semantics
- **Hardcoded source URLs:** Store in database config table for admin editability
- **Silent failures:** Report all source failures in job result, abort entire refresh

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async job management | Custom background threads | mirai daemons via job-manager.R | Process isolation, cleanup, timeout handling |
| Job progress tracking | Custom polling | useAsyncJob composable | Handles all edge cases, auto-cleanup |
| PDF parsing | Custom regex | pdftools package | Handles encoding, page extraction |
| HGNC symbol lookup | Direct API calls | Batch with rate limiting | Existing functions handle fallbacks |
| Quarto GitHub deploy | Custom scripts | quarto-dev/quarto-actions + deploy-pages | Maintained, handles edge cases |

**Key insight:** The entire async job infrastructure exists and is well-tested. Focus on the business logic (source fetching, data transformation) not the infrastructure.

## Common Pitfalls

### Pitfall 1: Database Connection in mirai Daemon

**What goes wrong:** Pool connections cannot cross process boundaries
**Why it happens:** mirai daemons run in separate R processes
**How to avoid:** Pass db_config values (strings), create connection inside daemon
**Warning signs:** "connection closed" errors, silent failures
```r
# Source: jobs_endpoints.R HGNC update pattern
# WRONG: result <- create_job(params = list(conn = pool))
# RIGHT: result <- create_job(params = list(db_config = list(host=..., port=...)))
```

### Pitfall 2: External Source URL Changes

**What goes wrong:** Download fails because source moved/changed format
**Why it happens:** External databases update their APIs/download locations
**How to avoid:** Store URLs in database table, validate before using, log failures clearly
**Warning signs:** HTTP 404, unexpected file formats, parse errors

### Pitfall 3: Quarto YAML Boolean Syntax

**What goes wrong:** `yes`/`no` values fail in Quarto
**Why it happens:** Quarto uses YAML 1.2 which requires `true`/`false`
**How to avoid:** Use `true`/`false` only in `_quarto.yml`
**Warning signs:** "invalid boolean" errors during render

### Pitfall 4: GitHub Pages Permissions

**What goes wrong:** Deploy fails with permission denied
**Why it happens:** New Pages environment requires specific permissions
**How to avoid:** Set `pages: write` and `id-token: write` in workflow permissions
**Warning signs:** 403 errors on deploy step

## Code Examples

Verified patterns from the codebase:

### Job Submission with Progress (from jobs_endpoints.R)

```r
# Source: api/endpoints/jobs_endpoints.R HGNC update endpoint
result <- create_job(
  operation = "comparisons_update",
  params = list(db_config = db_config),
  timeout_ms = 1800000,
  executor_fn = function(params) {
    progress <- create_progress_reporter(params$.__job_id__)
    job_id <- params$.__job_id__

    progress("init", "Loading source configuration...", current = 0, total = 8)

    # ... load source config from database

    sources <- list(
      radboudumc = list(url = "...", format = "pdf"),
      gene2phenotype = list(url = "...", format = "csv.gz"),
      # ... etc
    )

    all_data <- list()
    for (i in seq_along(sources)) {
      source_name <- names(sources)[i]
      progress("download", sprintf("Downloading %s...", source_name),
               current = i, total = length(sources) + 1)

      # Download and parse
      data <- download_and_parse_source(sources[[i]])

      if (is.null(data)) {
        stop(sprintf("Failed to fetch data from %s", source_name))
      }

      all_data[[source_name]] <- data
    }

    # Merge and write to database
    progress("write", "Writing to database...", current = length(sources) + 1, total = length(sources) + 1)
    # ... database transaction

    list(
      status = "completed",
      sources_updated = length(sources),
      rows_written = nrow(merged_data)
    )
  }
)
```

### useAsyncJob Usage (from ManageAnnotations.vue)

```typescript
// Source: app/src/views/admin/ManageAnnotations.vue
import { useAsyncJob } from '@/composables/useAsyncJob';

const comparisonsJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

async function refreshComparisons() {
  comparisonsJob.reset();

  try {
    const response = await axios.post(
      `${import.meta.env.VITE_API_URL}/api/jobs/comparisons_update/submit`,
      {},
      { headers: { Authorization: `Bearer ${localStorage.getItem('token')}` } }
    );

    if (response.data.error) {
      makeToast(response.data.message, 'Error', 'danger');
      return;
    }

    comparisonsJob.startJob(response.data.job_id);
  } catch (error) {
    makeToast('Failed to start comparisons update', 'Error', 'danger');
  }
}
```

### Quarto Website Configuration

```yaml
# _quarto.yml for SysNDD documentation
project:
  type: website
  output-dir: _site

website:
  title: "SysNDD Documentation"
  repo-url: https://github.com/berntpopp/sysndd
  repo-branch: master
  repo-subdir: documentation
  navbar:
    left:
      - href: index.qmd
        text: Home
      - href: web-tool.qmd
        text: Web Tool
      - href: api.qmd
        text: API
      - href: database.qmd
        text: Database
      - href: curation.qmd
        text: Curation
  sidebar:
    style: "docked"
    search: true
    contents:
      - section: "Overview"
        contents:
          - index.qmd
          - intro.qmd
      - section: "Usage"
        contents:
          - web-tool.qmd
          - api.qmd
          - database-structure.qmd
      - section: "Curation"
        contents:
          - curation-criteria.qmd
          - re-review-instructions.qmd
          - tutorial-videos.qmd
  page-footer:
    center: "SysNDD - Neurodevelopmental Disorder Gene Database"

format:
  html:
    theme: cosmo
    css: styles.css
    toc: true
    toc-depth: 3

bibliography: sysndd.bib
csl: apa.csl
```

### GitHub Actions Pages Deployment

```yaml
# .github/workflows/gh-pages.yml modernized
name: Documentation

on:
  push:
    branches: [master]
    paths:
      - 'documentation/**'
      - '.github/workflows/gh-pages.yml'

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: quarto-dev/quarto-actions/setup@v2

      - name: Render Quarto Project
        uses: quarto-dev/quarto-actions/render@v2
        with:
          path: documentation

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: documentation/_site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| gh-pages branch deploy | actions/deploy-pages environment | 2023 | Better security, no branch pollution |
| bookdown::render_book | quarto render | 2022-2023 | Multi-format, modern tooling |
| JamesIves/github-pages-deploy | actions/deploy-pages | 2023 | Official GitHub approach |
| Synchronous API imports | mirai async daemons | SysNDD v10 | Non-blocking, progress tracking |

**Deprecated/outdated:**
- `JamesIves/github-pages-deploy-action@v4`: Still works but not official approach
- `gh-pages` branch: Legacy, prefer Pages environment deployment
- `bookdown`: Not deprecated but Quarto is the successor

## Open Questions

Things that couldn't be fully resolved:

1. **External Source URL Stability**
   - What we know: Current URLs from 2023-04-13 in `ndd_databases_links.txt`
   - What's unclear: Which URLs have changed since then
   - Recommendation: Add URL validation step in job, log failures clearly

2. **Orphanet JSON Endpoint**
   - What we know: Uses `https://id-genes.orphanet.app/es/index/sysid_index_1`
   - What's unclear: Whether this endpoint is stable/official
   - Recommendation: Add fallback handling, contact Orphanet if issues

3. **OMIM API Key Handling**
   - What we know: genemap2.txt URL contains an API key
   - What's unclear: Whether key needs rotation/refresh
   - Recommendation: Store in environment variable, not database

## Sources

### Primary (HIGH confidence)
- api/endpoints/jobs_endpoints.R - Async job submission patterns
- api/functions/job-manager.R - create_job(), get_job_status()
- api/functions/pubtator-functions.R - Database transaction patterns
- app/src/views/admin/ManageAnnotations.vue - Admin UI patterns
- app/src/composables/useAsyncJob.ts - Job polling composable
- .github/workflows/gh-pages.yml - Current deployment workflow

### Secondary (MEDIUM confidence)
- [Quarto GitHub Pages Documentation](https://quarto.org/docs/publishing/github-pages.html)
- [quarto-dev/quarto-actions](https://github.com/quarto-dev/quarto-actions)
- [actions/deploy-pages](https://github.com/actions/deploy-pages)
- [Bookdown to Quarto Migration Guide](https://julianfaraway.github.io/post/converting-from-bookdown-to-quarto/)

### Tertiary (LOW confidence)
- WebSearch results for Quarto best practices 2026
- WebSearch results for bookdown migration patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All patterns exist in codebase
- Architecture: HIGH - Direct examples in jobs_endpoints.R, ManageAnnotations.vue
- Pitfalls: HIGH - Based on observed codebase patterns and documented issues

**Research date:** 2026-02-01
**Valid until:** 60 days (stable patterns, external APIs may change)
