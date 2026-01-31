# Phase 40: Backend External API Layer - Research

**Researched:** 2026-01-27
**Domain:** R/Plumber API proxy layer for external genomic data sources (gnomAD, UniProt, Ensembl, AlphaFold, MGI, RGD)
**Confidence:** MEDIUM-HIGH

## Summary

Phase 40 implements a Backend-for-Frontend (BFF) proxy layer in R/Plumber to integrate external genomic data sources into the gene page. The hybrid architecture stores compact data (scores, URLs) in MySQL via batch updates, while detailed data (variant positions, domain coordinates) is fetched through live proxy endpoints with persistent disk caching.

The standard R ecosystem provides robust tools for this:
- **httr2** for HTTP requests with built-in exponential backoff retry and rate limiting
- **memoise + cachem** for persistent disk-based caching that survives restarts
- **httpproblems** for RFC 9457 compliant error responses
- Existing Plumber patterns for auth allowlisting and error handling

**Key challenges identified:**
1. External APIs have varying rate limits (Ensembl: 15 req/sec documented, others undocumented)
2. Error isolation is critical - one failing source shouldn't break the aggregation endpoint
3. Cache TTLs need balancing between freshness and external API load
4. GraphQL (gnomAD) requires different approach than REST APIs

**Primary recommendation:** Use httr2's built-in req_retry with exponential backoff and req_throttle for rate limiting, memoise with cachem::cache_disk for persistent caching, and implement graceful degradation with partial responses in the aggregation endpoint to maintain service availability even when external sources fail.

## Standard Stack

The established libraries/tools for R/Plumber proxy APIs:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Latest (1.0+) | HTTP client with retry/throttle | Modern successor to httr, built-in exponential backoff and rate limiting, respects Retry-After headers |
| memoise | 2.0+ | Function memoization | Standard R caching solution, flexible cache backends |
| cachem | 1.0+ | Cache backends | Provides cache_disk for persistent caching across R sessions |
| httpproblems | Latest | RFC 9457 error format | Already in use in project (core/errors.R), standard for HTTP APIs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonlite | Latest | JSON parsing | For REST API responses (UniProt, Ensembl, AlphaFold, MGI, RGD) |
| ghql | Latest (0.4+) | GraphQL client | For gnomAD GraphQL API specifically |
| pool | Already in use | Database connection pooling | For batch update operations to MySQL |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 | httr (legacy) | httr2 has better retry/throttle built-in, modern design, but httr is more established |
| memoise | R.cache | R.cache more feature-rich but memoise simpler, better integrated with Plumber |
| httpproblems | Custom error format | httpproblems provides RFC 9457 compliance out-of-box, already in use |

**Installation:**
```bash
# Already in renv.lock based on codebase review
# httr2, memoise, jsonlite, httpproblems already available
# May need to add:
install.packages("cachem")  # For persistent disk cache
install.packages("ghql")    # For gnomAD GraphQL
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── endpoints/
│   └── external_endpoints.R         # Currently exists, extend for proxy routes
├── functions/
│   ├── external-proxy-functions.R   # New: proxy helper functions
│   └── external-batch-functions.R   # New: batch update functions
└── cache/                           # Disk cache directory (gitignored)
```

### Pattern 1: httr2 Retry with Exponential Backoff
**What:** Automatic retry with increasing delays for transient failures
**When to use:** All external API calls (6 sources × 2 pathways = 12+ API calls)
**Example:**
```r
# Source: https://httr2.r-lib.org/reference/req_retry.html
# Existing pattern from omim-functions.R lines 55-62

fetch_gnomad_data <- function(gene_symbol) {
  url <- paste0("https://gnomad.broadinstitute.org/api/...", gene_symbol)

  response <- request(url) %>%
    req_retry(
      max_tries = 5,                    # Up to 5 attempts
      max_seconds = 120,                # Total timeout 2 minutes
      backoff = ~ 2^.x,                 # Exponential: 2s, 4s, 8s, 16s, 32s
      is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
    ) %>%
    req_timeout(30) %>%                 # Per-request timeout
    req_error(is_error = ~FALSE) %>%   # Don't throw on HTTP errors
    req_perform()

  if (resp_status(response) != 200) {
    return(list(error = TRUE, status = resp_status(response)))
  }

  return(resp_body_json(response))
}
```

### Pattern 2: Rate Limiting with req_throttle
**What:** Token bucket rate limiting to prevent exceeding external API limits
**When to use:** Per-API throttling based on documented limits
**Example:**
```r
# Source: https://httr2.r-lib.org/reference/req_throttle.html

# Ensembl: 15 requests/second = 900/minute
fetch_ensembl_structure <- function(gene_id) {
  url <- paste0("https://rest.ensembl.org/lookup/id/", gene_id)

  response <- request(url) %>%
    req_throttle(
      capacity = 900,     # 900 requests
      fill_time_s = 60    # Per 60 seconds = 15 req/sec
    ) %>%
    req_retry(max_tries = 3, backoff = ~ 2^.x) %>%
    req_perform()

  return(resp_body_json(response))
}

# gnomAD: Conservative 10 requests/minute (undocumented)
fetch_gnomad_constraints <- function(gene_symbol) {
  # GraphQL query construction
  query <- sprintf('{ gene(gene_symbol: "%s") { pLI loeuf } }', gene_symbol)

  response <- request("https://gnomad.broadinstitute.org/api") %>%
    req_throttle(capacity = 10, fill_time_s = 60) %>%  # 10 req/min
    req_retry(max_tries = 3, backoff = ~ 2^.x) %>%
    req_body_json(list(query = query)) %>%
    req_perform()

  return(resp_body_json(response))
}
```

### Pattern 3: Persistent Disk Caching with memoise + cachem
**What:** Cache external API responses to disk, survives R/Plumber restarts
**When to use:** All live proxy endpoints (avoid cold-start thundering herd)
**Example:**
```r
# Source: Existing pattern from start_sysndd_api.R lines 218-230
# Already implemented for analyses-functions.R

# Cache setup (in start_sysndd_api.R)
cm <- cachem::cache_disk(
  dir = "/app/cache",              # Persistent disk location
  max_age = 7 * 24 * 3600,        # 7 days in seconds
  max_size = 500 * 1024^2         # 500 MB max
)

# Memoize proxy functions
fetch_uniprot_domains_mem <- memoise(fetch_uniprot_domains, cache = cm)
fetch_ensembl_structure_mem <- memoise(fetch_ensembl_structure, cache = cm)
fetch_gnomad_variants_mem <- memoise(fetch_gnomad_variants, cache = cm)

# Usage in endpoint
#* @get /api/external/uniprot/domains/<symbol>
function(symbol) {
  # Cached call - first call hits API, subsequent calls return cached data
  fetch_uniprot_domains_mem(symbol)
}
```

### Pattern 4: Graceful Degradation with Error Isolation
**What:** Aggregation endpoint returns partial data when some sources fail
**When to use:** The combined `/api/external/gene/<symbol>` endpoint
**Example:**
```r
# Source: https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends
# Source: https://dev.to/vaib/boost-performance-simplify-microservices-the-api-gateway-aggregation-pattern-52hi

#* @get /api/external/gene/<symbol>
function(symbol, res) {
  results <- list(
    gene_symbol = symbol,
    sources = list(),
    errors = list()
  )

  # Fetch from each source with error isolation
  sources <- list(
    gnomad = function() fetch_gnomad_data_mem(symbol),
    uniprot = function() fetch_uniprot_domains_mem(symbol),
    ensembl = function() fetch_ensembl_structure_mem(symbol),
    alphafold = function() fetch_alphafold_structure_mem(symbol),
    mgi = function() fetch_mgi_phenotypes_mem(symbol)
  )

  for (source_name in names(sources)) {
    result <- tryCatch({
      sources[[source_name]]()
    }, error = function(e) {
      list(error = TRUE, message = conditionMessage(e))
    })

    if (is.list(result) && isTRUE(result$error)) {
      # Source failed - record error but continue
      results$errors[[source_name]] <- list(
        type = "https://sysndd.org/problems/external-api-failure",
        title = paste("Failed to fetch", source_name, "data"),
        status = result$status %||% 503,
        detail = result$message,
        source = source_name
      )
    } else {
      # Source succeeded
      results$sources[[source_name]] <- result
    }
  }

  # Return 200 with partial data if at least one source succeeded
  # Return 503 only if ALL sources failed
  if (length(results$sources) == 0) {
    res$status <- 503
    res$setHeader("Content-Type", "application/problem+json")
    return(list(
      type = "https://sysndd.org/problems/all-sources-failed",
      title = "All external data sources unavailable",
      status = 503,
      detail = sprintf("Failed to retrieve data for gene %s from any source", symbol),
      errors = results$errors
    ))
  }

  return(results)
}
```

### Pattern 5: RFC 9457 Error Format with Source Identification
**What:** Standardized error responses identifying which external API failed
**When to use:** All error responses from proxy endpoints
**Example:**
```r
# Source: Existing pattern from core/errors.R
# Source: https://www.rfc-editor.org/rfc/rfc9457.html

#* @get /api/external/gnomad/variants/<symbol>
function(symbol, res) {
  result <- tryCatch({
    fetch_gnomad_variants_mem(symbol)
  }, error = function(e) {
    res$status <- 503
    res$setHeader("Content-Type", "application/problem+json")
    return(list(
      type = "https://sysndd.org/problems/external-api-failure",
      title = "gnomAD API unavailable",
      status = 503,
      detail = sprintf("Failed to fetch variant data for %s from gnomAD", symbol),
      source = "gnomad",                    # Identify failing source
      instance = paste0("/api/external/gnomad/variants/", symbol)
    ))
  })

  return(result)
}
```

### Pattern 6: Batch Update with Retry and Progress Tracking
**What:** Admin endpoint processes ~700 genes with per-gene retry and failure tracking
**When to use:** `/api/admin/external-annotations/update` endpoint
**Example:**
```r
#* @post /api/admin/external-annotations/update
function(req, res) {
  require_role(req, res, "Administrator")

  # Get all gene symbols from database
  genes <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(symbol, hgnc_id) %>%
    collect()

  results <- list(
    total = nrow(genes),
    updated = 0,
    failed = list()
  )

  for (i in seq_len(nrow(genes))) {
    gene <- genes[i, ]

    # Try to update this gene with retry
    updated <- tryCatch({
      update_gene_external_annotations(gene$hgnc_id, gene$symbol)
      TRUE
    }, error = function(e) {
      # Log failure but continue
      results$failed[[gene$symbol]] <- conditionMessage(e)
      FALSE
    })

    if (updated) {
      results$updated <- results$updated + 1
    }

    # Rate limiting: ~1 gene per second = 700 genes in ~12 minutes
    if (i < nrow(genes)) {
      Sys.sleep(1)
    }
  }

  return(list(
    message = sprintf("Updated %d/%d genes, %d failed",
                     results$updated, results$total, length(results$failed)),
    updated = results$updated,
    total = results$total,
    failed_genes = names(results$failed)
  ))
}
```

### Anti-Patterns to Avoid
- **No retry logic:** External APIs are flaky; always use req_retry with exponential backoff
- **Blind proxy:** Don't forward user input directly to external APIs; validate gene symbols first
- **In-memory cache only:** Use cache_disk to avoid cold-start after Plumber restarts
- **Fail-fast aggregation:** Don't let one failing source crash the combined endpoint
- **Missing source identification:** Always include "source" field in errors so frontend knows which API failed
- **Synchronous batch updates:** Don't block the API for 12+ minutes; consider async job pattern if needed

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry with backoff | Custom retry loop | httr2::req_retry | Built-in exponential backoff, Retry-After header support, transient error detection |
| Rate limiting | Sleep between requests | httr2::req_throttle | Token bucket algorithm, per-realm tracking, prevents thundering herd |
| Function result caching | Custom cache with saveRDS | memoise + cachem | Thread-safe, automatic cache key generation, TTL support, multiple backends |
| Error response format | Custom JSON structure | httpproblems package | RFC 9457 compliant, already in use in project (core/errors.R) |
| GraphQL queries | String concatenation | ghql package | Query validation, variable substitution, fragment support |
| Partial response aggregation | Manual try-catch per source | purrr::safely or purrr::possibly | Functional error handling, consistent result structure |

**Key insight:** The R ecosystem has mature, battle-tested packages for API proxy patterns. httr2 is specifically designed for this use case with retry/throttle built-in. Don't reimplement these - the edge cases (Retry-After headers, circuit breaking, cache invalidation) are harder than they look.

## Common Pitfalls

### Pitfall 1: Rate Limit Blocking from Aggressive Retry
**What goes wrong:** Retry logic without rate limiting can trigger API blocking (e.g., gnomAD returns 429, retry immediately, trigger IP ban)
**Why it happens:** req_retry alone doesn't prevent rapid successive requests; exponential backoff only applies AFTER failures
**How to avoid:** Combine req_retry with req_throttle to prevent exceeding limits in the first place
**Warning signs:** Sudden 429 responses, API returning "rate limit exceeded" messages, IP temporarily blocked
**Prevention strategy:**
```r
# WRONG: Retry without throttle
request(url) %>%
  req_retry(max_tries = 5) %>%
  req_perform()

# RIGHT: Throttle + Retry
request(url) %>%
  req_throttle(capacity = 10, fill_time_s = 60) %>%  # Preventive rate limiting
  req_retry(max_tries = 3, backoff = ~ 2^.x) %>%    # Recovery from failures
  req_perform()
```

### Pitfall 2: Cache Cold Start Thundering Herd
**What goes wrong:** Plumber restarts, cache is empty (if using in-memory), first request triggers 700 genes × 5 APIs = 3500 API calls simultaneously
**Why it happens:** cache_mem() doesn't persist across restarts; memoized functions all miss cache at once
**How to avoid:** Use cachem::cache_disk with persistent directory (/app/cache), survive restarts
**Warning signs:** Slow response times after deployments, external API rate limit errors after restart, high CPU/network after startup
**Prevention strategy:**
```r
# WRONG: In-memory cache
cm <- cachem::cache_mem(max_size = 500 * 1024^2)

# RIGHT: Persistent disk cache
cm <- cachem::cache_disk(
  dir = "/app/cache",           # Persists across restarts
  max_age = 7 * 24 * 3600,     # 7 day TTL
  max_size = 500 * 1024^2
)
```

### Pitfall 3: Undifferentiated Cache TTL
**What goes wrong:** Using same TTL (e.g., 7 days) for all sources; gnomAD constraint scores rarely change (30 day TTL fine), but ClinVar variants update frequently (7 day TTL needed)
**Why it happens:** Convenience of single cache configuration; lack of understanding of data update frequencies
**How to avoid:** Per-source cache with different TTLs based on data volatility
**Warning signs:** Users report stale ClinVar data, excessive cache invalidation requests, outdated gene constraint scores
**Prevention strategy:**
```r
# Create separate cache backends per data type
cache_static <- cachem::cache_disk(dir = "/app/cache/static", max_age = 30 * 24 * 3600)  # 30 days
cache_dynamic <- cachem::cache_disk(dir = "/app/cache/dynamic", max_age = 7 * 24 * 3600) # 7 days

# Static data (constraint scores, protein domains, gene structure)
fetch_gnomad_constraints_mem <- memoise(fetch_gnomad_constraints, cache = cache_static)
fetch_uniprot_domains_mem <- memoise(fetch_uniprot_domains, cache = cache_static)

# Dynamic data (ClinVar variants, phenotype associations)
fetch_gnomad_clinvar_mem <- memoise(fetch_gnomad_clinvar, cache = cache_dynamic)
```

### Pitfall 4: Missing Source Identification in Aggregation Errors
**What goes wrong:** Combined endpoint returns generic "503 Service Unavailable", frontend can't tell which of 5 sources failed, displays "Error loading gene data" instead of "UniProt unavailable, showing data from 4 other sources"
**Why it happens:** Using standard HTTP error responses without RFC 9457 "source" extension field
**How to avoid:** Always include "source" field in error objects within aggregation endpoint
**Warning signs:** Users report "everything is broken" when only one API is down, support tickets can't diagnose which source failed
**Prevention strategy:**
```r
# Add "source" field to error objects
results$errors[[source_name]] <- list(
  type = "https://sysndd.org/problems/external-api-failure",
  title = paste("Failed to fetch", source_name, "data"),
  status = result$status %||% 503,
  detail = result$message,
  source = source_name,           # Frontend can show "UniProt unavailable" banner
  timestamp = Sys.time()
)
```

### Pitfall 5: Synchronous Batch Update Blocking API
**What goes wrong:** Admin triggers batch update for 700 genes, Plumber thread is blocked for 12+ minutes (700 genes × 1 second), other API requests queue up or timeout
**Why it happens:** R is single-threaded per process; long-running endpoint blocks the worker
**How to avoid:** Use async job pattern with mirai (already in use for clustering jobs) or clearly document that batch update is admin-only during maintenance windows
**Warning signs:** API unresponsive during batch updates, timeout errors on other endpoints, user complaints about slow API
**Prevention strategy:**
```r
# Option A: Async job (recommended if batch updates during production)
#* @post /api/admin/external-annotations/update
function(req, res) {
  require_role(req, res, "Administrator")

  job_id <- submit_batch_update_job()

  return(list(
    job_id = job_id,
    message = "Batch update job submitted",
    status_url = paste0("/api/jobs/", job_id, "/status")
  ))
}

# Option B: Document as maintenance-only operation
# In endpoint docs: "WARNING: This endpoint blocks the API for ~12 minutes.
#                    Run during maintenance windows only."
```

### Pitfall 6: GraphQL Query Injection
**What goes wrong:** User-supplied gene symbol directly interpolated into GraphQL query string; attacker sends symbol like `" } evil_query { ` to manipulate query structure
**Why it happens:** GraphQL queries are strings; naive sprintf interpolation is vulnerable
**How to avoid:** Use parameterized queries via ghql package, validate input gene symbols against HGNC list before querying
**Warning signs:** Unexpected GraphQL errors, attempts to query non-gene data, security scanner alerts
**Prevention strategy:**
```r
# WRONG: String interpolation
query <- sprintf('{ gene(gene_symbol: "%s") { pLI } }', symbol)

# RIGHT: Validate input first
if (!symbol %in% valid_hgnc_symbols) {
  stop_for_bad_request("Invalid gene symbol")
}

# RIGHT: Use parameterized queries (ghql)
library(ghql)
query <- 'query($symbol: String!) { gene(gene_symbol: $symbol) { pLI } }'
variables <- list(symbol = symbol)
```

## Code Examples

Verified patterns from official sources and existing codebase:

### External API Call with Full Error Handling
```r
# Source: Adapted from omim-functions.R lines 163-207
# Pattern: httr2 retry + timeout + error handling

fetch_external_data <- function(api_name, url, max_tries = 5) {
  tryCatch({
    response <- request(url) %>%
      req_retry(
        max_tries = max_tries,
        max_seconds = 120,
        backoff = ~ 2^.x,
        is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
      ) %>%
      req_timeout(30) %>%
      req_error(is_error = ~FALSE) %>%  # Don't throw, handle manually
      req_perform()

    # Handle 404 - gene not found in external database (expected)
    if (resp_status(response) == 404) {
      return(list(found = FALSE))
    }

    # Handle other non-200 responses
    if (resp_status(response) != 200) {
      warning(sprintf(
        "%s API error %d for URL: %s",
        api_name, resp_status(response), url
      ))
      return(list(error = TRUE, status = resp_status(response)))
    }

    # Success
    data <- resp_body_json(response)
    return(data)

  }, error = function(e) {
    warning(sprintf(
      "Failed to fetch from %s - %s",
      api_name, e$message
    ))
    return(list(error = TRUE, message = conditionMessage(e)))
  })
}
```

### Endpoint with RFC 9457 Error Response
```r
# Source: core/errors.R + RFC 9457 spec
# Pattern: Standardized error format with source identification

#* @get /api/external/ensembl/structure/<gene_id>
function(gene_id, res) {
  # Validate input
  if (is.null(gene_id) || nchar(gene_id) == 0) {
    res$status <- 400
    res$setHeader("Content-Type", "application/problem+json")
    return(bad_request(detail = "Missing required parameter: gene_id"))
  }

  # Fetch data with error handling
  result <- fetch_ensembl_structure_mem(gene_id)

  if (is.list(result) && isTRUE(result$error)) {
    res$status <- result$status %||% 503
    res$setHeader("Content-Type", "application/problem+json")
    return(list(
      type = "https://sysndd.org/problems/external-api-failure",
      title = "Ensembl API request failed",
      status = res$status,
      detail = sprintf("Failed to fetch gene structure for %s", gene_id),
      source = "ensembl",
      instance = paste0("/api/external/ensembl/structure/", gene_id),
      gene_id = gene_id
    ))
  }

  return(result)
}
```

### Batch Update Function with Progress Tracking
```r
# Source: Adapted from omim-functions.R batch pattern
# Pattern: Iterate with retry per item, track failures

update_gene_external_annotations <- function(hgnc_id, symbol) {
  # Fetch from multiple sources
  annotations <- list(
    pli = NULL,
    loeuf = NULL,
    alphafold_url = NULL
  )

  # gnomAD constraint scores
  gnomad <- tryCatch({
    fetch_gnomad_constraints(symbol)
  }, error = function(e) NULL)

  if (!is.null(gnomad)) {
    annotations$pli <- gnomad$pLI
    annotations$loeuf <- gnomad$loeuf
  }

  # AlphaFold structure URL
  alphafold <- tryCatch({
    fetch_alphafold_metadata(symbol)
  }, error = function(e) NULL)

  if (!is.null(alphafold)) {
    annotations$alphafold_url <- alphafold$structure_url
  }

  # Update database (only if we got at least some data)
  if (!all(sapply(annotations, is.null))) {
    pool %>%
      tbl("non_alt_loci_set") %>%
      filter(hgnc_id == !!hgnc_id) %>%
      # Use SQL UPDATE here - need to construct proper query
      # This is placeholder for the actual DB update logic
      collect()

    # Actual UPDATE would be:
    # DBI::dbExecute(pool, "UPDATE non_alt_loci_set SET pli = ?, loeuf = ?,
    #                       alphafold_url = ? WHERE hgnc_id = ?",
    #                params = list(annotations$pli, annotations$loeuf,
    #                             annotations$alphafold_url, hgnc_id))
  }

  return(TRUE)
}
```

### AUTH_ALLOWLIST Extension
```r
# Source: core/middleware.R lines 19-37
# Pattern: Add external endpoints to public allowlist

AUTH_ALLOWLIST <- c(
  "/api/gene/hash",
  "/api/entity/hash",
  # ... existing entries ...

  # External API proxy endpoints (public read access)
  "/api/external/gnomad/variants",
  "/api/external/gnomad/constraints",
  "/api/external/uniprot/domains",
  "/api/external/ensembl/structure",
  "/api/external/alphafold/structure",
  "/api/external/mgi/phenotypes",
  "/api/external/rgd/phenotypes",
  "/api/external/gene"  # Aggregation endpoint
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| httr package | httr2 package | 2023+ | httr2 has built-in retry/throttle, better ergonomics, req_perform replaces old workflow |
| Manual retry loops | req_retry with backoff | httr2 release | Exponential backoff, Retry-After header support, circuit breaking built-in |
| saveRDS/readRDS cache | memoise + cachem | memoise 2.0 (2021) | Automatic cache key generation, thread-safe, multiple backends, TTL support |
| Custom error JSON | RFC 9457 Problem Details | RFC published 2023 (supersedes RFC 7807) | Standardized format, client-friendly, source identification field |
| In-memory rate limiting | req_throttle token bucket | httr2 release | Per-realm tracking, automatic token refill, prevents thundering herd |

**Deprecated/outdated:**
- **httr::RETRY()**: Use httr2::req_retry() - better backoff, more flexible transient error detection
- **In-memory cache (cache_mem) for long-lived data**: Use cache_disk to survive restarts
- **String interpolation for GraphQL**: Use ghql package with parameterized queries to prevent injection
- **Fail-fast aggregation**: Use error isolation with partial responses - modern BFF pattern

## External API Rate Limits

Research findings on documented rate limits for each external API:

| API | Rate Limit | Source | Confidence |
|-----|-----------|--------|------------|
| Ensembl REST | 15 req/sec (54,000/hour) | [Ensembl REST API docs](https://rest.ensembl.org/) | HIGH |
| UniProt/EBI Proteins | 200 req/sec (conservative: 100 req/sec) | [EBI Proteins API docs](https://www.ebi.ac.uk/proteins/api/doc/) | MEDIUM |
| gnomAD GraphQL | Not documented (conservative: 10 req/min) | [gnomAD docs](https://gnomad.broadinstitute.org/help) | LOW |
| AlphaFold API | Not documented (conservative: 20 req/min) | [AlphaFold API docs](https://alphafold.ebi.ac.uk/api-docs) | LOW |
| MGI/MouseMine | Not documented (conservative: 30 req/min) | [MouseMine docs](https://www.mousemine.org/) | LOW |
| RGD API | Not documented (conservative: 30 req/min) | [RGD website](https://rgd.mcw.edu/) | LOW |

**Recommended throttle settings:**
```r
# Documented limits
ensembl_throttle <- list(capacity = 900, fill_time_s = 60)    # 15/sec
uniprot_throttle <- list(capacity = 100, fill_time_s = 1)     # 100/sec (conservative)

# Undocumented - use conservative limits
gnomad_throttle <- list(capacity = 10, fill_time_s = 60)      # 10/min
alphafold_throttle <- list(capacity = 20, fill_time_s = 60)   # 20/min
mgi_throttle <- list(capacity = 30, fill_time_s = 60)         # 30/min
rgd_throttle <- list(capacity = 30, fill_time_s = 60)         # 30/min
```

**Validation strategy:** Start conservative, monitor response headers (X-RateLimit-*, Retry-After), increase if no 429 errors observed over 1 week of testing.

## Cache TTL Recommendations

Based on data volatility and external API load considerations:

| Data Type | Recommended TTL | Rationale |
|-----------|----------------|-----------|
| Gene constraint scores (pLI, LOEUF, mis_z) | 30 days | gnomAD releases are infrequent (~yearly), scores stable |
| AlphaFold structure URLs | 30 days | Structure predictions rarely change for published genes |
| Protein domains (UniProt) | 14 days | UniProt updates quarterly, domains stable |
| Gene structure (Ensembl exons/transcripts) | 14 days | Genome builds stable, but annotations can be refined |
| ClinVar variants | 7 days | ClinVar updates frequently, clinical significance changes |
| MGI/RGD phenotypes | 14 days | Model organism data updates monthly |

**Implementation:**
```r
# Multiple cache backends by data type
cache_static <- cachem::cache_disk(
  dir = "/app/cache/static",
  max_age = 30 * 24 * 3600,  # 30 days
  max_size = 300 * 1024^2    # 300 MB
)

cache_stable <- cachem::cache_disk(
  dir = "/app/cache/stable",
  max_age = 14 * 24 * 3600,  # 14 days
  max_size = 150 * 1024^2    # 150 MB
)

cache_dynamic <- cachem::cache_disk(
  dir = "/app/cache/dynamic",
  max_age = 7 * 24 * 3600,   # 7 days
  max_size = 50 * 1024^2     # 50 MB
)
```

## Open Questions

Things that couldn't be fully resolved:

1. **gnomAD GraphQL rate limits**
   - What we know: GraphQL endpoint exists, no documented rate limits found
   - What's unclear: Actual rate limit policy, whether it differs from REST API
   - Recommendation: Start with conservative 10 req/min, monitor response headers, contact Broad Institute if needed
   - Action: Include monitoring in Phase 40 to collect data on actual limits

2. **MGI and RGD API endpoints**
   - What we know: MouseMine and RGD web interfaces exist, some APIs documented
   - What's unclear: Specific REST endpoints for phenotype data by gene symbol, rate limits
   - Recommendation: Research phase task to explore MouseMine REST API and RGD web services during planning
   - Action: May need to contact MGI/RGD support for API documentation

3. **Batch update parallelism**
   - What we know: ~700 genes, sequential at 1 req/sec = 12 minutes per source
   - What's unclear: Can we parallelize across sources? Would 5 parallel workers × 5 APIs trigger rate limits?
   - Recommendation: Sequential by source (5 sources × 12 min = ~60 minutes total), or async job pattern
   - Action: Validate with rate limit testing in development

4. **GraphQL query complexity**
   - What we know: gnomAD has constraint scores and ClinVar variants
   - What's unclear: Can we query both in single GraphQL request? Does complexity affect rate limits?
   - Recommendation: Start with separate queries, optimize to combined query if rate limits allow
   - Action: Test query complexity during implementation

5. **Cache invalidation strategy**
   - What we know: TTL-based expiration works for normal operations
   - What's unclear: How to handle manual cache invalidation when external data is updated (e.g., new ClinVar release)?
   - Recommendation: Admin endpoint to clear specific cache partitions (by source or data type)
   - Action: Include cache management endpoint in Phase 40 admin routes

## Sources

### Primary (HIGH confidence)
- [httr2 req_retry documentation](https://httr2.r-lib.org/reference/req_retry.html) - Retry logic and exponential backoff
- [httr2 req_throttle documentation](https://httr2.r-lib.org/reference/req_throttle.html) - Rate limiting with token bucket
- [RFC 9457 Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457.html) - Official error format specification
- [memoise GitHub repository](https://github.com/r-lib/memoise) - Function memoization
- Existing codebase patterns:
  - `api/functions/omim-functions.R` - Verified httr2 retry pattern
  - `api/core/errors.R` - RFC 9457 implementation
  - `api/core/middleware.R` - AUTH_ALLOWLIST pattern
  - `api/start_sysndd_api.R` - cachem disk cache setup

### Secondary (MEDIUM confidence)
- [Appsilon: R Plumber Error Responses](https://www.appsilon.com/post/api-oopsies-101) - Plumber error handling best practices
- [Structured Errors in Plumber APIs](https://unconj.ca/blog/structured-errors-in-plumber-apis.html) - Error handling patterns
- [Azure BFF Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/backends-for-frontends) - Backend for Frontend architecture
- [API Aggregation Pattern](https://dev.to/vaib/boost-performance-simplify-microservices-the-api-gateway-aggregation-pattern-52hi) - Error isolation and partial responses
- [Ensembl REST API documentation](https://rest.ensembl.org/) - Rate limits and endpoints
- [UniProt API documentation](https://www.uniprot.org/api-documentation/uniprotkb) - REST API details
- [AlphaFold API documentation](https://alphafold.ebi.ac.uk/api-docs) - Structure metadata endpoints

### Tertiary (LOW confidence - flagged for validation)
- [gnomAD help documentation](https://gnomad.broadinstitute.org/help) - General API info, no specific rate limits
- [MGI software tools](https://www.informatics.jax.org/software.shtml) - MouseMine API references
- [RGD website](https://rgd.mcw.edu/) - General database info, limited API documentation
- WebSearch results for bioinformatics API caching strategies - General patterns, not R-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - httr2, memoise, cachem are established R packages with official documentation
- Architecture patterns: HIGH - BFF/proxy patterns are industry standard, verified with existing codebase
- httr2 usage: HIGH - Official documentation + existing usage in omim-functions.R validates approach
- External API endpoints: MEDIUM - Ensembl/UniProt well-documented, gnomAD/MGI/RGD need validation
- Rate limits: LOW-MEDIUM - Only Ensembl documented (HIGH), others undocumented (LOW), need testing
- Cache TTLs: MEDIUM - Based on data volatility analysis, needs real-world validation

**Research date:** 2026-01-27
**Valid until:** 2026-02-27 (30 days - rate limits and API endpoints may change, core R packages stable)

**Validation recommendations:**
1. Contact gnomAD Broad Institute for official rate limit documentation
2. Test throttle settings in development with real API calls, monitor for 429 responses
3. Verify MGI MouseMine and RGD API endpoints for phenotype data by gene symbol
4. Validate GraphQL query complexity limits with gnomAD
5. Test cache TTLs with real usage patterns, adjust based on cache hit rates
