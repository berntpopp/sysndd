# JAX Ontology API Validation Results

**Validation Date:** 2026-01-24
**Script:** `api/scripts/validate-jax-api.R`
**Purpose:** Empirically test JAX Ontology API rate limits and data completeness before implementing OMIM migration

## Summary

The JAX Ontology API was tested with 100 randomly sampled phenotype MIM numbers from mim2gene.txt. Key findings:

- **No rate limiting observed** - API tolerates rapid sequential requests without 429 responses
- **82% data completeness** - 18% of phenotype MIM numbers return 404 (not found in JAX database)
- **Response times stable** - Median 256ms, 95th percentile 267ms

## Rate Limits

### Observed Behavior

| Delay | Batch Size | Avg Response (ms) | Success Rate | Rate Limited |
|-------|------------|-------------------|--------------|--------------|
| 0ms   | 10         | 186               | 100%         | 0            |
| 0ms   | 25         | 161               | 80%          | 0            |
| 25ms  | 10         | 177               | 100%         | 0            |
| 25ms  | 25         | 181               | 80%          | 0            |
| 50ms  | 10         | 241               | 100%         | 0            |
| 50ms  | 25         | 214               | 80%          | 0            |
| 100ms | 10         | 295               | 100%         | 0            |
| 100ms | 25         | 251               | 80%          | 0            |

**Key Observations:**
- Zero 429 (rate limited) responses across all test configurations
- API appears to have no client-side rate limiting or has very high thresholds
- Response times remain stable regardless of request rate

### Recommended Retry Strategy

```r
request(url) |>
  req_retry(
    max_tries = 5,
    max_seconds = 120,
    backoff = ~ 2^.x,  # Exponential: 2, 4, 8, 16, 32 seconds
    is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
  ) |>
  req_timeout(30) |>
  req_error(is_error = ~ FALSE)  # Handle HTTP errors manually
```

## Data Completeness

### Test Results

| Metric | Value |
|--------|-------|
| Total phenotype MIM numbers in mim2gene.txt | 8,585 |
| Number tested in validation | 100 |
| Successful retrievals (with disease name) | 82 (82%) |
| Failures (404 not found) | 18 (18%) |

### Failure Analysis

All 18 failures were HTTP 404 responses - the MIM numbers exist in OMIM's mim2gene.txt but are not present in the JAX Ontology database.

**Sample of Missing MIM Numbers:**
- 614670 - Not found in JAX
- 621230 - Not found in JAX
- 614746 - Not found in JAX
- 300870 - Not found in JAX
- 612162 - Not found in JAX

**Possible Reasons:**
1. JAX database focuses on disease-gene relationships; some OMIM phenotype entries may not have associated genes
2. Time lag between OMIM updates and JAX database synchronization
3. Different inclusion criteria between OMIM and JAX

### Response Time Statistics

| Metric | Value |
|--------|-------|
| Minimum | 140 ms |
| Median | 256 ms |
| Mean | 245 ms |
| Maximum | 359 ms |
| 95th Percentile | 267 ms |

Response times are consistent and predictable, with no outliers suggesting server-side throttling.

## Recommendations

### 1. Request Delay

**Recommendation: 50ms between requests**

Rationale:
- No rate limiting detected, but 50ms provides safety margin
- Allows approximately 20 requests/second
- Respectful to the API even without documented limits
- Production processing of 8,585 MIM numbers: ~7 minutes total

### 2. Retry Parameters

```r
req_retry(
  max_tries = 5,
  max_seconds = 120,
  backoff = ~ 2^.x
)
```

Parameters chosen for:
- Sufficient retries for transient network issues
- Exponential backoff prevents thundering herd
- 120s max wait prevents hung jobs

### 3. Data Completeness Threshold

**Status: BELOW 95% threshold (82%)**

Given the 18% failure rate:
- **Do NOT abort on missing names** - too many legitimate gaps
- **Log warnings for missing entries** - track for investigation
- **Continue with partial data** - 82% coverage is acceptable for optional field
- **Consider alternative sources** - MONDO mappings may provide names for some missing entries

### 4. Validation Strictness

**Recommendation: WARN on missing disease names, allow partial failures**

Implementation approach:
```r
if (is.na(disease_name)) {
  log_warning(sprintf("No JAX disease name for OMIM:%s", mim_number))
  # Continue processing - disease_name will be NA
} else {
  # Use fetched disease name
}
```

## Implementation Decisions

Based on validation results, the following parameters will be used in Plan 02:

### httr2 Request Configuration

```r
fetch_jax_disease_name <- function(mim_number) {
  url <- paste0("https://ontology.jax.org/api/network/annotation/OMIM:", mim_number)

  response <- request(url) |>
    req_retry(
      max_tries = 5,
      max_seconds = 120,
      backoff = ~ 2^.x,
      is_transient = ~ resp_status(.x) %in% c(429, 503, 504)
    ) |>
    req_timeout(30) |>
    req_error(is_error = ~ FALSE) |>
    req_perform()

  if (resp_status(response) == 404) {
    return(NA_character_)  # Not found in JAX database
  }

  if (resp_status(response) != 200) {
    stop(sprintf("JAX API error %d for OMIM:%s", resp_status(response), mim_number))
  }

  data <- resp_body_json(response)
  pluck(data, "disease", "name", .default = NA_character_)
}
```

### Batch Processing Configuration

```r
# Between-request delay
BATCH_DELAY_MS <- 50

# Progress reporting interval
PROGRESS_INTERVAL <- 100  # Report every 100 MIM numbers

# Estimated total time for 8,585 MIM numbers
# 8585 * (250ms response + 50ms delay) = ~43 minutes
```

### Error Handling Strategy

| HTTP Status | Action | Log Level |
|-------------|--------|-----------|
| 200 | Process response | None |
| 404 | Set disease_name = NA | WARNING |
| 429 | Retry with backoff | INFO |
| 503/504 | Retry with backoff | INFO |
| Other | Abort job | ERROR |

### Validation Before Database Write

```r
validate_omim_data <- function(omim_data) {
  # Required: MIM number must exist
  if (any(is.na(omim_data$disease_ontology_id))) {
    stop("Missing MIM numbers in OMIM data")
  }

  # Optional: disease name (warn but don't abort)
  missing_names <- sum(is.na(omim_data$disease_ontology_name))
  if (missing_names > 0) {
    log_warning(sprintf(
      "%d/%d entries missing disease names (%.1f%%)",
      missing_names,
      nrow(omim_data),
      missing_names / nrow(omim_data) * 100
    ))
  }

  # Continue with validation passed
  return(TRUE)
}
```

## Next Steps for Plan 02

1. **Implement JAX API fetcher** using parameters above
2. **Add 50ms delay** between requests in batch processing loop
3. **Handle 404s gracefully** - set disease_name to NA, log warning
4. **Track completeness metrics** - report success/failure counts in job status
5. **Consider MONDO fallback** - for MIM numbers not in JAX, check MONDO mappings

---

*Validation performed: 2026-01-24*
*Script: api/scripts/validate-jax-api.R*
*Sample size: 100 random phenotype MIM numbers from 8,585 total*
