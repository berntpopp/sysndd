# Phase 23: OMIM Migration - Research

**Researched:** 2026-01-24
**Domain:** OMIM data source migration, external API integration, async job processing
**Confidence:** MEDIUM

## Summary

Phase 23 replaces genemap2.txt as the OMIM data source with mim2gene.txt + JAX Ontology API for disease names, while adding MONDO disease equivalence mappings. The migration requires integration of three external data sources: OMIM's mim2gene.txt file, JAX Ontology API for disease names, and MONDO SSSOM mappings for cross-ontology references.

The standard approach involves async job execution with progress tracking (already implemented in Phase 20), HTTP request retry logic with exponential backoff (httr2 package), and single database transactions for atomic updates (DBI package). The codebase already has file management utilities (check_file_age, get_newest_file) and the job-manager framework for long-running operations.

Key challenges include JAX API rate limiting (no official documentation found), data completeness validation (mim2gene.txt contains phenotype entries without gene symbols), and MONDO mapping integration (SSSOM format needs parsing).

**Primary recommendation:** Use httr2 for JAX API calls with automatic retry/backoff, integrate OMIM update into existing job-manager framework with 4 progress steps, download MONDO SSSOM mappings as static file (monthly releases), and implement comprehensive validation before database writes using DBI transactions.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Latest (CRAN) | HTTP API requests with retry logic | Modern replacement for httr, built-in exponential backoff with full jitter for rate limiting |
| DBI | 1.2.3+ | Database transactions | Standard R database interface, provides dbBegin/dbCommit/dbRollback for atomic operations |
| readr | (tidyverse) | File parsing | Already in use, handles tab-delimited files efficiently |
| pool | (existing) | Database connection pooling | Already integrated, used for read operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httptest | Latest (CRAN) | Mock API responses in tests | Testing JAX API integration without live calls |
| digest | (existing) | Content hashing | Already used in job-manager for deduplication, useful for ETag/content comparison |
| later | (existing) | Async scheduling | Already used in job cleanup, could support retry scheduling |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 | httr (v1) | httr lacks automatic retry with Retry-After header support, httr2 is recommended for new code |
| Static MONDO file | OxO API | Current code uses OxO but it's slow/unreliable (noted in db/02_Rcommands line 336), SSSOM files are official and faster |
| httptest | vcr package | Both work, httptest has simpler API for recording/playback |

**Installation:**
```bash
# In api/DESCRIPTION, add to Imports:
httr2,
httptest
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── omim-functions.R        # New: OMIM-specific logic
│   ├── mondo-functions.R       # New: MONDO mapping utilities
│   ├── ontology-functions.R    # Existing: refactor to use new functions
│   └── job-manager.R           # Existing: add "omim_update" operation
├── endpoints/
│   └── admin_endpoints.R       # Modify: update_ontology endpoint to use async job
├── data/
│   ├── omim_links/omim_links.txt  # Existing: already has mim2gene.txt URL
│   └── mondo_mappings/         # New: store SSSOM files
└── tests/testthat/
    ├── test-omim-functions.R   # New: mim2gene parsing tests
    ├── test-mondo-functions.R  # New: SSSOM parsing tests
    └── fixtures/               # New: httptest fixtures for JAX API
```

### Pattern 1: Async Job Integration with Progress Tracking
**What:** Long-running OMIM update as async job with step-by-step progress reporting
**When to use:** Any operation taking >2 seconds that blocks API responsiveness
**Example:**
```r
# In admin_endpoints.R
#* @put /admin/update_ontology_async
function(req, res) {
  if (req$user_role != "Administrator") {
    res$status <- 403
    return(list(error = "Access forbidden."))
  }

  # Create async job using existing job-manager
  result <- create_job(
    operation = "omim_update",
    params = list(force_download = FALSE),
    executor_fn = function(params) {
      update_omim_ontology(
        force_download = params$force_download,
        progress_callback = function(step, current, total) {
          # Progress stored in job state via mirai
          list(step = step, current = current, total = total)
        }
      )
    }
  )

  return(result)
}

# In job-manager.R, add to get_progress_message():
omim_update = "Downloading OMIM data and fetching disease names..."
```

### Pattern 2: HTTP Retry with Exponential Backoff
**What:** Automatic retry on rate limiting (429) or transient failures (503)
**When to use:** Any external API call (JAX, MONDO downloads)
**Example:**
```r
# Source: httr2 official documentation
library(httr2)

fetch_jax_disease_name <- function(mim_number) {
  url <- paste0("https://ontology.jax.org/api/network/annotation/OMIM:", mim_number)

  response <- request(url) %>%
    req_retry(
      max_tries = 5,
      max_seconds = 120,
      backoff = ~ 2^.x  # Exponential: 2, 4, 8, 16, 32 seconds
    ) %>%
    req_perform()

  resp_body_json(response)
}
```

### Pattern 3: Transaction-Based Atomic Updates
**What:** All database changes in single transaction, rollback on any failure
**When to use:** Multi-table updates that must succeed/fail together
**Example:**
```r
# Source: Existing admin_endpoints.R update_ontology (lines 139-177)
sysndd_db <- dbConnect(RMariaDB::MariaDB(), ...)
dbBegin(sysndd_db)

tryCatch({
  dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 0;")
  dbExecute(sysndd_db, "TRUNCATE TABLE disease_ontology_set;")
  dbAppendTable(sysndd_db, "disease_ontology_set", validated_data)
  dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 1;")

  dbCommit(sysndd_db)
  list(status = "Success")
}, error = function(e) {
  dbRollback(sysndd_db)  # Undo ALL changes
  list(error = e$message)
}, finally = {
  dbDisconnect(sysndd_db)
})
```

### Pattern 4: File Freshness Detection
**What:** Check if remote file has changed before re-downloading
**When to use:** Large static files that update infrequently (mim2gene.txt, MONDO SSSOM)
**Example:**
```r
# Using HTTP HEAD request to check Last-Modified header
check_remote_file_freshness <- function(url, local_path) {
  if (!file.exists(local_path)) return(TRUE)  # Need download

  local_mtime <- file.mtime(local_path)

  # HEAD request to get headers without downloading
  response <- request(url) %>%
    req_method("HEAD") %>%
    req_perform()

  # Check Last-Modified header
  remote_modified <- resp_header(response, "Last-Modified")
  if (is.null(remote_modified)) return(TRUE)  # Can't determine, re-download

  remote_mtime <- as.POSIXct(remote_modified, format = "%a, %d %b %Y %H:%M:%S", tz = "GMT")

  return(remote_mtime > local_mtime)
}
```

### Anti-Patterns to Avoid
- **Synchronous blocking in endpoint:** Don't call long-running updates directly in PUT endpoint, use job-manager instead
- **No validation before write:** Don't TRUNCATE table then discover data is invalid, validate completely first
- **Silent API failures:** Don't continue if JAX API is down, abort entire update (per CONTEXT decision)
- **Manual retry loops:** Don't implement custom retry logic, use httr2's req_retry()

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry with backoff | Custom retry loop with Sys.sleep() | httr2::req_retry() | Handles Retry-After header, jitter prevents thundering herd, respects rate limits |
| Database transactions | Manual BEGIN/COMMIT SQL strings | DBI::dbBegin/dbCommit/dbRollback | Cross-database compatibility, proper error handling, connection cleanup |
| API mocking in tests | Custom stub functions | httptest::with_mock_api() | Records real responses, replays in tests, no maintenance of fake data |
| File age checking | Manual date parsing | Existing check_file_age() function | Already handles edge cases (no file, date extraction, interval math) |
| Progress tracking | Custom state variables | Existing job-manager with get_progress_message() | Integrated with frontend polling, handles cleanup, prevents memory leaks |
| JSON parsing | Manual text manipulation | jsonlite::fromJSON() | Handles nested structures, type coercion, error handling |
| SSSOM parsing | Custom TSV parser | readr::read_tsv() with SSSOM column mapping | SSSOM is standardized TSV, readr handles types correctly |

**Key insight:** The codebase already has infrastructure for async jobs (job-manager.R), file management (file-functions.R), and database transactions (admin_endpoints.R). The migration should extend existing patterns rather than introduce new ones.

## Common Pitfalls

### Pitfall 1: JAX API Rate Limiting Without Documentation
**What goes wrong:** JAX Ontology API has no published rate limits, excessive requests may get 429 responses or IP blocks
**Why it happens:** No official documentation found at https://ontology.jax.org/ or via WebSearch
**How to avoid:**
- Start with conservative retry (max 5 tries, 2-minute max wait)
- Implement exponential backoff with jitter (prevents synchronized retries)
- Log all 429 responses to detect patterns
- Consider batching with delays between MIM numbers (e.g., 50ms delay)
**Warning signs:**
- 429 status codes in logs
- Increasing retry counts
- Timeout errors after working initially

### Pitfall 2: mim2gene.txt Phenotype Entries Lack Gene Symbols
**What goes wrong:** mim2gene.txt contains "phenotype" entries with MIM_Number but no gene symbols/IDs, can't be used directly
**Why it happens:** File is gene-to-ID mapping, phenotypes don't map to genes (they map to multiple genes via genemap2)
**How to avoid:**
- Filter mim2gene.txt to MIM_Entry_Type == "phenotype" for disease name lookups only
- Don't expect Approved_Gene_Symbol_HGNC for phenotype entries
- Use genemap2 phenotype mappings (existing code) for gene-disease associations
- JAX API provides disease names for phenotype MIM numbers
**Warning signs:**
- Validation errors for "missing gene symbols" on phenotype entries
- Fewer OMIM entries than expected after filtering

### Pitfall 3: MONDO SSSOM Mappings Are Not 1:1
**What goes wrong:** Single OMIM ID may map to multiple MONDO IDs, or vice versa, breaking assumptions about unique equivalence
**Why it happens:** Ontologies have different granularities, MONDO aggregates related conditions
**How to avoid:**
- Handle semicolon-separated MONDO IDs (existing code pattern at ontology-functions.R line 126-135)
- Store all mappings, let curator choose preferred MONDO equivalent
- Document "no mapping" vs "multiple mappings" in UI
- Use first MONDO mapping as suggested default
**Warning signs:**
- Multiple MONDO IDs in mapping column
- OMIM without any MONDO mapping (valid, not all are mapped)

### Pitfall 4: JAX API Response Structure Changes
**What goes wrong:** JAX API returns nested JSON, changes to structure break parsing code
**Why it happens:** API lacks versioning, subject to change without notice
**How to avoid:**
- Use safe navigation with explicit NULL checks (purrr::pluck with .default)
- Wrap parsing in tryCatch with fallback to NA
- Log unparseable responses with full JSON for debugging
- Test with multiple MIM numbers in validation script
**Warning signs:**
- Unexpected NULL values
- JSON parsing errors
- Disease names suddenly missing

### Pitfall 5: Database Transaction Isolation with Pool
**What goes wrong:** Using global pool for transaction fails, pool connections can be reused mid-transaction
**Why it happens:** pool package designed for short-lived connections, transactions need dedicated connection
**How to avoid:**
- Create dedicated connection for transactions (existing pattern in admin_endpoints.R lines 140-148)
- Use pool only for read operations (existing pattern)
- Always dbDisconnect() in finally block
- Never mix pool queries inside dbBegin/dbCommit block
**Warning signs:**
- Transaction rollback doesn't undo changes
- "connection busy" errors
- Partial data writes

### Pitfall 6: ManageAnnotations Frontend Assumes Synchronous Response
**What goes wrong:** Converting to async breaks existing UI (button shows "Success" before job completes)
**Why it happens:** Current PUT /admin/update_ontology returns synchronously after database write
**How to avoid:**
- Update ManageAnnotations.vue to handle job_id response
- Implement polling loop to check job status (GET /api/jobs/{job_id})
- Show progress steps in UI ("Downloading OMIM data...", "Fetching disease names: 45/100")
- Display final result (success/error) when job completes
**Warning signs:**
- UI shows success immediately
- No progress indication
- User refreshes page to see result

## Code Examples

Verified patterns from official sources:

### JAX API Disease Name Fetch with Retry
```r
# Source: WebFetch of JAX API + httr2 documentation
library(httr2)
library(purrr)

fetch_jax_disease_name <- function(mim_number, max_retries = 5) {
  url <- paste0("https://ontology.jax.org/api/network/annotation/OMIM:", mim_number)

  tryCatch({
    response <- request(url) %>%
      req_retry(
        max_tries = max_retries,
        max_seconds = 120,
        backoff = ~ 2^.x,  # 2, 4, 8, 16, 32 seconds
        is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
      ) %>%
      req_timeout(30) %>%  # 30 second timeout per request
      req_perform()

    data <- resp_body_json(response)

    # Safe extraction with fallback to NA
    disease_name <- pluck(data, "disease", "name", .default = NA_character_)

    if (is.na(disease_name) || disease_name == "") {
      warning(sprintf("Empty disease name for MIM:%s", mim_number))
      return(NA_character_)
    }

    return(disease_name)

  }, error = function(e) {
    warning(sprintf("Failed to fetch disease name for MIM:%s: %s", mim_number, e$message))
    return(NA_character_)
  })
}
```

### MONDO SSSOM Mapping Download and Parse
```r
# Source: WebSearch MONDO GitHub + readr documentation
library(httr2)
library(readr)

download_mondo_omim_mappings <- function(output_path = "data/mondo_mappings/") {
  # MONDO releases monthly, use latest
  url <- "https://github.com/monarch-initiative/mondo/raw/master/src/ontology/mappings/mondo-omim.sssom.tsv"

  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

  date_iso <- format(Sys.Date(), "%Y-%m-%d")
  local_file <- paste0(output_path, "mondo-omim.", date_iso, ".sssom.tsv")

  # Download with retry
  request(url) %>%
    req_retry(max_tries = 3, backoff = ~ 2^.x) %>%
    req_perform(path = local_file)

  # Parse SSSOM format (tab-delimited with specific columns)
  mappings <- read_tsv(
    local_file,
    comment = "#",  # SSSOM has metadata comments
    col_types = cols(
      subject_id = col_character(),
      predicate_id = col_character(),
      object_id = col_character(),
      mapping_justification = col_character()
    )
  ) %>%
    filter(
      str_detect(subject_id, "^MONDO:"),
      str_detect(object_id, "^OMIM:")
    ) %>%
    select(MONDO = subject_id, OMIM = object_id) %>%
    unique()

  return(mappings)
}
```

### Batch JAX API Calls with Progress
```r
# Source: Combining httr2 + job-manager pattern
fetch_all_disease_names <- function(mim_numbers, progress_callback = NULL) {
  total <- length(mim_numbers)
  results <- vector("list", total)

  for (i in seq_along(mim_numbers)) {
    # Progress callback for job-manager integration
    if (!is.null(progress_callback)) {
      progress_callback(
        step = "Fetching disease names from JAX API",
        current = i,
        total = total
      )
    }

    results[[i]] <- fetch_jax_disease_name(mim_numbers[i])

    # Small delay to avoid overwhelming API (conservative approach)
    if (i < total) Sys.sleep(0.05)  # 50ms delay = max 20 req/sec
  }

  tibble(
    mim_number = mim_numbers,
    disease_name = unlist(results)
  )
}
```

### Comprehensive Data Validation Before Write
```r
# Source: CONTEXT.md requirement + DBI patterns
validate_omim_data <- function(omim_data) {
  errors <- list()

  # Required fields check
  if (any(is.na(omim_data$disease_ontology_id))) {
    missing <- sum(is.na(omim_data$disease_ontology_id))
    errors <- append(errors, sprintf("%d entries missing MIM number", missing))
  }

  if (any(is.na(omim_data$hgnc_id))) {
    missing <- sum(is.na(omim_data$hgnc_id))
    errors <- append(errors, sprintf("%d entries missing gene symbol", missing))
  }

  if (any(is.na(omim_data$disease_ontology_name) | omim_data$disease_ontology_name == "")) {
    missing <- sum(is.na(omim_data$disease_ontology_name) | omim_data$disease_ontology_name == "")
    missing_mims <- omim_data %>%
      filter(is.na(disease_ontology_name) | disease_ontology_name == "") %>%
      pull(disease_ontology_id) %>%
      head(10)  # First 10 for logging

    errors <- append(errors, sprintf(
      "%d entries missing disease name. Examples: %s",
      missing,
      paste(missing_mims, collapse = ", ")
    ))
  }

  # Duplicate ID check
  duplicates <- omim_data %>%
    count(disease_ontology_id_version) %>%
    filter(n > 1)

  if (nrow(duplicates) > 0) {
    errors <- append(errors, sprintf(
      "%d duplicate ontology IDs found",
      nrow(duplicates)
    ))
  }

  # Return validation result
  if (length(errors) > 0) {
    return(list(
      valid = FALSE,
      errors = errors
    ))
  } else {
    return(list(
      valid = TRUE,
      message = sprintf("All %d entries validated successfully", nrow(omim_data))
    ))
  }
}
```

### Testing JAX API with httptest
```r
# Source: httptest documentation
library(testthat)
library(httptest)

test_that("fetch_jax_disease_name handles valid response", {
  with_mock_api({
    # First run: httptest records real API response to tests/testthat/fixtures/
    # Subsequent runs: httptest replays recorded response

    result <- fetch_jax_disease_name("618891")

    expect_type(result, "character")
    expect_false(is.na(result))
    expect_match(result, "Microcephaly.*brittle hair", ignore.case = TRUE)
  })
})

test_that("fetch_jax_disease_name handles 404 not found", {
  with_mock_api({
    # Can create custom mock in tests/testthat/fixtures/ontology.jax.org/api/network/annotation/OMIM-999999.json
    # {"error": "Not found"}

    result <- fetch_jax_disease_name("999999")

    expect_true(is.na(result))
  })
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| genemap2.txt for all OMIM data | mim2gene.txt + JAX API | Phase 23 (planned) | Eliminates genemap2 dependency, preserves OMIM disease names |
| OxO API for ontology mappings | MONDO SSSOM static files | Phase 23 (planned) | Faster, more reliable, officially maintained |
| Synchronous PUT /admin/update_ontology | Async job with progress tracking | Phase 20 (completed) | Non-blocking updates, progress visibility |
| httr package | httr2 package | 2023+ | Better retry logic, modern request pipeline |
| Manual retry with Sys.sleep() | httr2::req_retry() | 2023+ | Automatic backoff, Retry-After header support |
| testthat mocks | httptest package | 2020+ | Record/replay for external APIs |

**Deprecated/outdated:**
- genemap2.txt: Will be removed in Phase 23, replaced by mim2gene.txt
- OxO API for MONDO mappings: Slow/unreliable (noted in existing code), replace with SSSOM files
- httr::RETRY(): Use httr2::req_retry() for new code
- Synchronous admin endpoints: All long-running operations should use job-manager (Phase 20 pattern)

## Open Questions

Things that couldn't be fully resolved:

1. **JAX Ontology API Rate Limits**
   - What we know: No official documentation found at https://ontology.jax.org/ or via WebSearch
   - What's unclear: Actual rate limit threshold, whether limits are per-IP or global, acceptable request patterns
   - Recommendation: Create validation script that tests with 10, 50, 100, 500 sequential requests to empirically determine limits. Log all response times and 429 occurrences. Conservative initial approach: 5 max retries, 2-minute timeout, 50ms delays between requests.

2. **MONDO SSSOM File Update Frequency**
   - What we know: MONDO releases monthly (around 1st of month per WebSearch), SSSOM files in GitHub master branch
   - What's unclear: Whether to download from master (latest) or specific release tag, cache duration
   - Recommendation: Download from latest release tag (https://github.com/monarch-initiative/mondo/releases/latest), check once per OMIM update run, cache for 30 days using existing check_file_age() pattern.

3. **Data Completeness - Phenotypes Without JAX Names**
   - What we know: mim2gene.txt contains phenotype entries, JAX API should have names for them
   - What's unclear: Percentage of phenotype MIM numbers that lack JAX API records, acceptable failure rate
   - Recommendation: Validation script should test sample of phenotype MIM numbers (e.g., 100 random). If >5% fail, document expected gaps. Make decision during planning: abort update on any missing name, or allow NA with curator review.

4. **ManageAnnotations Frontend Conversion to Async**
   - What we know: Current UI assumes synchronous response, needs polling for job status
   - What's unclear: Whether to update in Phase 23 or defer to separate UI modernization phase
   - Recommendation: Minimum viable change in Phase 23: return job_id, update UI to poll GET /api/jobs/{job_id} every 2 seconds, show progress.step message. Full progress bar UI can be deferred to Phase 16 (UI/UX modernization).

5. **Transaction Size and Performance**
   - What we know: Current update truncates disease_ontology_set and writes ~thousands of rows
   - What's unclear: Expected row count after migration, transaction timeout risks
   - Recommendation: Test with current data volume first. If >10k rows, consider batch inserts (1000 rows at a time) within single transaction. Monitor dbAppendTable() performance.

## Sources

### Primary (HIGH confidence)
- DBI Package Documentation - [Begin/commit/rollback SQL transactions](https://dbi.r-dbi.org/reference/transactions.html)
- httr2 Package Documentation - [req_retry automatic retry](https://httr2.r-lib.org/reference/req_retry.html)
- Existing codebase patterns:
  - `/mnt/c/development/sysndd/api/functions/job-manager.R` (async job framework)
  - `/mnt/c/development/sysndd/api/endpoints/admin_endpoints.R` (transaction pattern lines 139-177)
  - `/mnt/c/development/sysndd/api/functions/file-functions.R` (check_file_age, get_newest_file)

### Secondary (MEDIUM confidence)
- JAX Ontology API response structure - [WebFetch of live endpoint](https://ontology.jax.org/api/network/annotation/OMIM:618891) (verified JSON structure)
- mim2gene.txt format - [WebFetch of OMIM file](https://omim.org/static/omim/data/mim2gene.txt) (verified column structure)
- MONDO Documentation - [Mondo Disease Ontology FAQ](https://mondo.monarchinitiative.org/pages/faq/)
- MONDO SSSOM Mappings - [GitHub monarch-initiative/mondo mappings](https://github.com/monarch-initiative/mondo/tree/master/src/ontology/mappings)
- httptest Package - [Testing HTTP Requests in R](https://cran.r-project.org/web/packages/httptest/vignettes/httptest.html)
- Plumber Async - [Runtime execution model](https://www.rplumber.io/articles/execution-model.html)

### Tertiary (LOW confidence)
- JAX Ontology Service general description - [ontology.jax.org landing page](https://ontology.jax.org/) (no API documentation found, needs empirical testing)
- R download.file headers parameter - [Multiple WebSearch results](https://www.rdocumentation.org/packages/utils/versions/3.6.2/topics/download.file) (added in R 3.6.0, but httr2 is better for HTTP downloads)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - httr2 and DBI are official R packages with comprehensive documentation, existing codebase patterns are verified
- Architecture: HIGH - job-manager framework already implemented (Phase 20), transaction pattern proven in admin_endpoints.R
- Pitfalls: MEDIUM - JAX API rate limits unknown (no official docs), MONDO mapping complexity needs validation, frontend async conversion is architectural change
- Data sources: MEDIUM - JAX API response structure verified via WebFetch, mim2gene.txt format verified, but completeness/coverage unknown until tested
- MONDO integration: MEDIUM - SSSOM format is standard, GitHub location verified, but parsing integration untested

**Research date:** 2026-01-24
**Valid until:** 2026-02-24 (30 days - APIs and data formats are relatively stable, but JAX API behavior needs validation script before implementation)

**Next steps for planning:**
1. Create validation script to test JAX API limits and mim2gene.txt completeness
2. Download sample MONDO SSSOM file and verify parsing logic
3. Determine acceptable failure thresholds for missing disease names
4. Design ManageAnnotations UI changes (minimal vs full progress UI)
5. Estimate row counts and transaction performance requirements
