# Technology Stack: v10.0 LLM & Literature Features

**Project:** SysNDD v10.0
**Researched:** 2026-01-31
**Scope:** Stack additions for LLM cluster summaries, Publications view improvements, Pubtator enhancements
**Overall Confidence:** HIGH

---

## Executive Summary

For v10.0 features, the recommended approach is to **use ellmer for Gemini API integration** rather than the lighter-weight gemini.R package. ellmer provides critical features for production use: structured data extraction with type safety, batch processing, and a unified interface that could accommodate future provider switches. For PubMed metadata, **continue using easyPubMed** (already in codebase) with its updated API functions, and **enhance existing Pubtator integration with httr2** for better rate limiting and error handling.

**Key decisions:**
1. **ellmer >= 0.4.0** for Gemini API (not gemini.R) - structured output, batch processing, LLM-as-judge support
2. **easyPubMed 3.1.x** - already used, update deprecated function calls
3. **httr2 patterns** for Pubtator - align with existing external-proxy-functions.R patterns
4. **mirai integration** - LLM calls run in existing daemon pool for non-blocking operations

---

## Current Stack (Validated, No Changes Needed)

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| R | 4.4.3 | KEEP | Plumber API runtime |
| httr2 | 1.2.1 | KEEP | HTTP client with retry/throttle |
| mirai | 2.5.1 | KEEP | Async job system with 8-worker daemon |
| cachem | 1.0.x | KEEP | Disk-based caching |
| memoise | 2.0.x | KEEP | Function memoization |
| jsonlite | 1.8.x | KEEP | JSON parsing |
| easyPubMed | 3.0.x | UPDATE | Deprecated function calls need updating |

**Already Working:**
- `external-proxy-functions.R` - httr2 retry/throttle patterns, rate limiting
- `job-manager.R` - mirai-based async job execution
- `pubtator-functions.R` - PubTator3 API integration
- `publication-functions.R` - PubMed metadata retrieval

---

## New Addition: ellmer (LLM Integration)

### Why ellmer

| Attribute | Value |
|-----------|-------|
| Package | ellmer |
| Version | >= 0.4.0 |
| CRAN | https://cran.r-project.org/package=ellmer |
| Purpose | Gemini API integration for cluster summaries |
| Confidence | HIGH (Tidyverse/Posit maintained, Hadley Wickham author) |

**Why ellmer over gemini.R:**

| Criterion | ellmer | gemini.R |
|-----------|--------|----------|
| Structured output | Native type_object(), type_array() with R conversion | JSON schema via list, manual parsing |
| Batch processing | batch_chat() with automatic error handling | Manual implementation required |
| Provider flexibility | 15+ providers (OpenAI, Claude, Gemini, etc.) | Gemini only |
| LLM-as-judge | Same interface, different model parameter | Separate implementation needed |
| Error handling | Built-in retry, rate limit handling | Basic error handling |
| Maintenance | Posit/Tidyverse team (Hadley Wickham, Joe Cheng) | Single community maintainer |
| R idioms | Tidyverse-style, pipe-friendly, S7 classes | Functional but basic |

### ellmer Key Features for SysNDD

**1. Structured Data Extraction:**
```r
# Define cluster summary type specification
type_cluster_summary <- type_object(
  "LLM-generated summary for a gene cluster",
  summary = type_string("2-3 sentence plain-language summary of cluster function"),
  key_genes = type_array("Most important genes", type_string()),
  shared_mechanism = type_string("Common biological mechanism"),
  clinical_relevance = type_string("Clinical significance for NDDs"),
  confidence = type_number("Model confidence 0-1"),
  .additional_properties = FALSE
)

# Use with structured output - returns native R types
chat <- chat_google_gemini(model = "gemini-2.5-flash")
result <- chat$chat_structured(
  prompt = cluster_prompt,
  type = type_cluster_summary
)
# result is a named list, not JSON string
```

**2. Batch Processing:**
```r
# Process multiple clusters efficiently
# ellmer 0.4.0 batch_chat() is no longer experimental
results <- batch_chat(
  prompts = cluster_prompts,  # Vector of prompts
  type = type_cluster_summary,
  .provider = chat_google_gemini(model = "gemini-2.5-flash"),
  .progress = TRUE
)

# Returns tibble with results column
# Handles errors gracefully - partial success supported
```

**3. LLM-as-Judge Validation:**
```r
# Define judgment type
type_judgment <- type_object(
  "Evaluation of generated summary quality",
  is_accurate = type_boolean("Summary accurately reflects cluster genes"),
  is_complete = type_boolean("Summary covers key biological functions"),
  issues = type_array("List of identified issues", type_string()),
  quality_score = type_integer("Quality score 1-5"),
  should_regenerate = type_boolean("Whether summary should be regenerated")
)

# Use higher-quality model as judge
judge <- chat_google_gemini(model = "gemini-2.5-pro")
judgment <- judge$chat_structured(
  prompt = validation_prompt,
  type = type_judgment
)
```

### ellmer Configuration

**config.yml addition:**
```yaml
# LLM Configuration
llm:
  provider: "google"
  model: "gemini-2.5-flash"         # Cost-effective for generation
  judge_model: "gemini-2.5-pro"     # Higher quality for validation
  timeout_seconds: 120
  max_retries: 3
  cache_ttl_days: 90                # LLM summaries cached long-term
```

**Environment variable:**
```bash
# .env or docker-compose
GEMINI_API_KEY=your-api-key-here
```

**API key handling pattern (match existing):**
```r
# In start_sysndd_api.R or llm-functions.R
get_gemini_api_key <- function() {
  key <- Sys.getenv("GEMINI_API_KEY", "")
  if (key == "") {
    # Fall back to config.yml if available
    config <- config::get()
    key <- config$llm$api_key %||% ""
  }
  if (key == "") {
    stop("GEMINI_API_KEY not configured")
  }
  return(key)
}
```

### Sources (HIGH confidence)

- [ellmer 0.4.0 Tidyverse blog](https://tidyverse.org/blog/2025/11/ellmer-0-4-0/)
- [ellmer structured data vignette](https://ellmer.tidyverse.org/articles/structured-data.html)
- [ellmer CRAN](https://cran.r-project.org/package=ellmer)
- [ellmer Type documentation](https://ellmer.tidyverse.org/reference/Type.html)

---

## Update Required: easyPubMed

### Current State

The existing `publication-functions.R` uses easyPubMed functions that are deprecated and will be retired in 2026:

| Current Function | Replacement | Status |
|-----------------|-------------|--------|
| `get_pubmed_ids()` | `epm_query()` | DEPRECATED - MUST update |
| `fetch_pubmed_data()` | `epm_fetch()` | DEPRECATED - MUST update |
| `custom_grep()` | Internal (not exported) | DEPRECATED - MUST update |

### Required Changes

**Update publication-functions.R:**
```r
# BEFORE (deprecated, retiring 2026)
check_pmid <- function(pmid_input) {
  # ...
  mutate(count = extract_pubmed_count(get_pubmed_ids(publication_id)))
  # ...
}

info_from_pmid <- function(pmid_value, request_max = 200) {
  # ...
  mutate(response = fetch_pubmed_data(get_pubmed_ids(publication_id)))
  # ...
}

# AFTER (new API)
check_pmid <- function(pmid_input) {
  # ...
  query_result <- epm_query(publication_id)
  count <- query_result@count
  # ...
}

info_from_pmid <- function(pmid_value, request_max = 200) {
  # ...
  query_result <- epm_query(publication_id)
  records <- epm_fetch(query_result)
  parsed <- epm_parse(records)
  # ...
}
```

**Why NOT switch to rentrez:**
- easyPubMed already integrated and working
- rentrez 1.2.4 is "stable release, unlikely additional functionality will be added"
- Switching would require rewriting XML parsing logic in `table_articles_from_xml()`
- Both use same underlying NCBI EUtils API
- easyPubMed's new API (epm_*) is more R-idiomatic

### Sources (HIGH confidence)

- [easyPubMed CRAN PDF](https://cran.r-project.org/web/packages/easyPubMed/easyPubMed.pdf) - States 2026 retirement
- [easyPubMed vignette](https://cran.r-project.org/web/packages/easyPubMed/vignettes/easyPubMed_demo.html)

---

## Enhancement: Pubtator httr2 Integration

### Current State Analysis

The existing `pubtator-functions.R` uses `jsonlite::fromJSON()` directly with `URLencode()`:

```r
# Current pattern (pubtator-functions.R line 53)
response_search <- fromJSON(URLencode(url_search), flatten = TRUE)
```

This bypasses the httr2 retry/throttle patterns already established in `external-proxy-functions.R`.

### Recommended Changes

**1. Add Pubtator rate limit config:**
```r
# Add to EXTERNAL_API_THROTTLE in external-proxy-functions.R
EXTERNAL_API_THROTTLE <- list(
  # ... existing configs
  pubtator = list(capacity = 3, fill_time_s = 1)  # 3 req/sec (NCBI documented)
)
```

**2. Create Pubtator-specific request helper:**
```r
# In pubtator-functions.R or external-proxy-functions.R
make_pubtator_request <- function(url, parse_json = TRUE) {
  result <- make_external_request(
    url = url,
    api_name = "pubtator",
    throttle_config = EXTERNAL_API_THROTTLE$pubtator
  )

  if (!is.null(result$error)) {
    log_warn("PubTator request failed: {result$message}")
    return(NULL)
  }

  return(result)
}
```

**3. Refactor existing functions:**
```r
# Update pubtator_v3_total_pages_from_query
pubtator_v3_total_pages_from_query <- function(query, ...) {
  url_search <- paste0(api_base_url, endpoint_search, query_parameter, query, "&page=1")

  response <- make_pubtator_request(URLencode(url_search))
  if (is.null(response)) {
    return(NULL)
  }

  return(response$total_pages)
}
```

### PubTator3 API Reference

| Endpoint | Purpose | Rate Limit |
|----------|---------|------------|
| `/research/pubtator3-api/search/` | Text search, paginated | 3 req/sec |
| `/research/pubtator3-api/publications/export/biocjson` | Export annotations by PMID | 3 req/sec |
| `/research/pubtator3-api/entity/autocomplete/` | Entity ID lookup | 3 req/sec |
| `/research/pubtator3-api/relations` | Related entities | 3 req/sec |

**Entity types supported:** Gene, Disease, Chemical, Species, CellLine, Mutation, SNP

### Sources (HIGH confidence)

- [PubTator3 API](https://www.ncbi.nlm.nih.gov/research/pubtator3/api)
- [PubTator 3.0 NAR paper](https://academic.oup.com/nar/article/52/W1/W540/7640526)

---

## Integration with Existing Stack

### mirai Daemon Pool Integration

LLM calls should run in the existing mirai daemon pool:

**Add to job-manager.R:**
```r
# Add operation progress messages
get_progress_message <- function(operation) {
  messages <- list(
    # ... existing
    llm_cluster_summary = "Generating cluster summaries with Gemini...",
    llm_summary_validation = "Validating summaries with LLM-as-judge..."
  )
  messages[[operation]] %||% "Processing request..."
}
```

**LLM executor function:**
```r
# In llm-functions.R
llm_cluster_summary_executor <- function(params) {
  # Load ellmer inside daemon (clean environment)
  library(ellmer)

  # Initialize chat with API key from params
  chat <- chat_google_gemini(
    api_key = params$api_key,
    model = params$model
  )

  # Define type specification
  type_spec <- type_object(
    summary = type_string(),
    key_genes = type_array(type_string()),
    shared_mechanism = type_string(),
    confidence = type_number()
  )

  # Process clusters in batch
  results <- batch_chat(
    prompts = params$prompts,
    type = type_spec,
    .provider = chat,
    .progress = FALSE  # No interactive progress in daemon
  )

  return(results)
}
```

**Create job via existing pattern:**
```r
# In llm-endpoints.R or admin-endpoints.R
create_job(
  operation = "llm_cluster_summary",
  params = list(
    api_key = get_gemini_api_key(),
    model = config$llm$model,
    prompts = cluster_prompts
  ),
  executor_fn = llm_cluster_summary_executor,
  timeout_ms = 3600000  # 1 hour for batch LLM
)
```

### Cache Strategy

**Add LLM cache tier:**
```r
# Add to external-proxy-functions.R
cache_llm_dir <- "/app/cache/llm"
dir.create(cache_llm_dir, recursive = TRUE, showWarnings = FALSE)
cache_llm <- cache_disk(
  dir = cache_llm_dir,
  max_age = 90 * 24 * 3600,  # 90 days (summaries rarely change)
  max_size = 100 * 1024^2    # 100 MB
)
```

**Cache key pattern:**
```r
# Hash cluster members + model version for cache key
generate_summary_cache_key <- function(cluster_genes, model) {
  genes_sorted <- sort(cluster_genes)
  digest::digest(
    list(genes = genes_sorted, model = model),
    algo = "sha256"
  )
}
```

---

## Alternatives Considered

### LLM Integration

| Option | Verdict | Reason |
|--------|---------|--------|
| **ellmer** | RECOMMENDED | Structured output, batch processing, multi-provider, Tidyverse maintained |
| gemini.R | Not recommended | Limited features, single provider lock-in, single maintainer |
| Raw httr2 | Not recommended | Would reinvent ellmer's structured output wheel |
| tidyprompt | Not recommended | Focus on prompt engineering, not API integration |
| langchain R | Not recommended | Python-centric, overkill for single-provider use |

### PubMed/Literature

| Option | Verdict | Reason |
|--------|---------|--------|
| **easyPubMed (update)** | RECOMMENDED | Already integrated, just update deprecated calls |
| rentrez | Not recommended | Would require rewriting XML parsing logic |
| europepmc | Not recommended | Different API, less PubMed-specific coverage |
| Direct EUtils | Not recommended | Low-level, no benefits over easyPubMed |

### Pubtator

| Option | Verdict | Reason |
|--------|---------|--------|
| **httr2 refactor** | RECOMMENDED | Aligns with existing external-proxy patterns |
| pubtatordb | Not recommended | Bulk download model, not real-time API |
| Keep jsonlite direct | Not recommended | Misses retry/throttle benefits |

---

## What NOT to Add

| Technology | Reason NOT to add |
|------------|-------------------|
| langchain R bindings | Overkill, Python-centric |
| OpenAI SDK | Not using OpenAI, ellmer abstracts this |
| chromadb / vector store | No RAG requirement in current features |
| LiteLLM | Python-centric |
| Additional XML parsers | xml2 already in stack |
| rentrez | easyPubMed already works |
| New logging framework | logger already in stack |

---

## Installation Summary

### R Packages

**New (add to renv):**
```r
install.packages("ellmer")
```

**Update (in renv):**
```r
update.packages("easyPubMed")  # Ensure >= 3.1.3
```

### renv.lock additions

```json
{
  "ellmer": {
    "Package": "ellmer",
    "Version": "0.4.0",
    "Source": "Repository",
    "Repository": "CRAN"
  }
}
```

### Environment Variables

```bash
# Add to .env or docker-compose
GEMINI_API_KEY=your-api-key-here
```

### config.yml additions

```yaml
# LLM Configuration
llm:
  provider: "google"
  model: "gemini-2.5-flash"
  judge_model: "gemini-2.5-pro"
  timeout_seconds: 120
  max_retries: 3
  cache_ttl_days: 90
```

---

## Version Matrix

| Package | Current | Required | Action |
|---------|---------|----------|--------|
| httr2 | 1.2.1 | >= 1.2.1 | No change |
| mirai | 2.5.1 | >= 2.5.1 | No change |
| cachem | 1.0.x | >= 1.0.x | No change |
| jsonlite | 1.8.x | >= 1.8.x | No change |
| easyPubMed | 3.0.x | >= 3.1.3 | UPDATE (deprecated functions) |
| **ellmer** | N/A | >= 0.4.0 | **NEW** |

---

## Roadmap Implications

Based on this research:

### Phase 1: Infrastructure
- Add ellmer to renv
- Update easyPubMed function calls
- Add Pubtator httr2 patterns
- Configure GEMINI_API_KEY handling

### Phase 2: LLM Core
- Implement type specifications for cluster summaries
- Build batch processing executor
- Integrate with mirai job system
- Add LLM cache tier

### Phase 3: LLM-as-Judge
- Implement validation type specification
- Build judgment executor
- Add quality metrics tracking
- Handle regeneration workflow

### Phase 4: Publications
- Update deprecated easyPubMed calls
- Add publication metadata endpoint
- Integrate with frontend Publications view

### Phase 5: Pubtator
- Refactor to httr2 patterns
- Add gene prioritization endpoint
- Update curator interface

---

## Confidence Assessment

| Component | Confidence | Basis |
|-----------|------------|-------|
| ellmer recommendation | HIGH | Official Tidyverse docs, 0.4.0 release notes, Posit maintained |
| ellmer version 0.4.0 | HIGH | CRAN verified Nov 2025 |
| ellmer structured output | HIGH | Vignette with examples, Type system documented |
| easyPubMed deprecations | HIGH | CRAN PDF explicitly states 2026 retirement |
| Pubtator rate limits | HIGH | NCBI official documentation |
| mirai integration pattern | HIGH | Existing codebase patterns working |
| Gemini model availability | MEDIUM | Model names may change; 2.5-flash verified Jan 2026 |

---

## Sources

### Primary (HIGH confidence)
- [ellmer 0.4.0 Tidyverse blog](https://tidyverse.org/blog/2025/11/ellmer-0-4-0/)
- [ellmer structured data vignette](https://ellmer.tidyverse.org/articles/structured-data.html)
- [ellmer CRAN](https://cran.r-project.org/package=ellmer)
- [easyPubMed CRAN PDF](https://cran.r-project.org/web/packages/easyPubMed/easyPubMed.pdf)
- [httr2 CRAN](https://cran.r-project.org/package=httr2)
- [PubTator 3.0 NAR paper](https://academic.oup.com/nar/article/52/W1/W540/7640526)

### Secondary (MEDIUM confidence)
- [Gemini API structured output docs](https://ai.google.dev/gemini-api/docs/structured-output)
- [rentrez 1.2.4 CRAN](https://cran.r-project.org/web/packages/rentrez/rentrez.pdf)
- [LLM-as-judge patterns](https://www.evidentlyai.com/llm-guide/llm-as-a-judge)
- [gemini.R CRAN](https://cran.r-project.org/web/packages/gemini.R/)

---

**Document Version:** 1.0
**Last Updated:** 2026-01-31
**Next Review:** After Phase 1 completion (ellmer integration)
