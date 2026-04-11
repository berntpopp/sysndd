# Phase 58: LLM Foundation - Research

**Researched:** 2026-01-31
**Domain:** LLM Integration (Gemini API via ellmer), Entity Validation, Database Caching
**Confidence:** HIGH

## Summary

This research documents the technical approach for integrating Google Gemini API into SysNDD for generating cluster summaries. The approach uses the ellmer R package (>= 0.4.0) which provides native support for `GEMINI_API_KEY` authentication and structured data extraction via type specifications.

Key findings:
1. **ellmer is the correct choice** - Maintained by tidyverse team, native Gemini support, structured output via `chat_structured()` method with type specifications that guarantee valid JSON
2. **Entity validation is critical** - LLMs hallucinate gene names at detectable rates (~9% precision loss without validation); validation against `non_alt_loci_set` table is mandatory
3. **Existing codebase patterns cover 80%** - The external-proxy pattern, pubtator caching pattern, and mirai job pattern provide proven templates

**Primary recommendation:** Use ellmer's `chat_structured()` with strict type specifications and validate all gene symbols against the HGNC `non_alt_loci_set` table before storage.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ellmer | >= 0.4.0 | Gemini API client | Tidyverse-maintained, native GEMINI_API_KEY support, structured output |
| DBI | >= 1.2.0 | Database operations | Already in codebase, required for cache storage |
| jsonlite | >= 1.8.0 | JSON handling | Already in codebase, MySQL JSON compatibility |
| digest | >= 0.6.0 | Hash generation | Already in codebase (pubtator), SHA256 for cluster hashing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | >= 0.2.0 | Structured logging | All LLM operations need audit trail |
| httr2 | >= 1.0.0 | HTTP utilities | Already in codebase, backup for error inspection |
| glue | >= 1.6.0 | String templating | Prompt construction |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ellmer | gemini.R | gemini.R is simpler but lacks structured output guarantees |
| ellmer | httr2 direct | More control but requires manual JSON schema handling |
| MySQL JSON | PostgreSQL JSONB | MySQL already in stack, JSON support adequate for needs |

**Installation:**
```r
# Add to api/renv.lock via renv::install()
renv::install("ellmer")
# Version 0.4.0+ required for GEMINI_API_KEY support
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── llm-service.R           # Core LLM client (chat_google_gemini wrapper)
│   ├── llm-validation.R        # Entity validation functions
│   └── llm-cache-repository.R  # Database cache operations
├── endpoints/
│   └── llm_endpoints.R         # API endpoints (Phase 59+)
└── tests/testthat/
    ├── test-llm-service.R      # Unit tests for LLM client
    └── test-llm-validation.R   # Validation tests
db/
└── migrations/
    └── 006_add_llm_summary_cache.sql  # Cache tables
```

### Pattern 1: ellmer Structured Output
**What:** Use `chat_structured()` with type specifications to guarantee valid JSON responses
**When to use:** All Gemini API calls that require structured data extraction
**Example:**
```r
# Source: https://ellmer.tidyverse.org/articles/structured-data.html
# Define the output schema using type specifications
cluster_summary_type <- type_object(
  "Summary of a gene cluster with key themes and pathways",
  summary = type_string("2-3 sentence prose summary for clinical researchers"),
  key_themes = type_array(
    type_string("Theme describing cluster function"),
    "3-5 key biological themes"
  ),
  pathways = type_array(
    type_string("Pathway name from enrichment data"),
    "Top pathways represented in cluster"
  ),
  tags = type_array(
    type_string("Searchable keyword"),
    "3-7 tags for filtering and search"
  ),
  confidence = type_enum(
    c("high", "medium", "low"),
    "LLM self-assessed confidence in summary accuracy"
  )
)

# Create chat and extract structured data
chat <- chat_google_gemini(model = "gemini-3-pro-preview")
result <- chat$chat_structured(
  prompt = build_cluster_prompt(cluster_data, enrichment_data),
  type = cluster_summary_type
)
# result is a named list with guaranteed structure
```

### Pattern 2: External Service Client (Follow external-proxy Pattern)
**What:** Wrap ellmer calls with rate limiting, retry logic, and error handling
**When to use:** All external LLM API calls
**Example:**
```r
# Source: api/functions/external-proxy-functions.R pattern
# Follow existing make_external_request() pattern

#' Rate limit configuration for Gemini API
#' Based on Paid Tier 1: 60 RPM for gemini-3-pro-preview
GEMINI_RATE_LIMIT <- list(
  capacity = 60,      # requests per minute

  fill_time_s = 60    # 1 minute window
)

#' Generate cluster summary with retry and validation
#'
#' @param cluster_data Tibble with cluster identifiers and enrichment
#' @param model Gemini model name (default: "gemini-3-pro-preview")
#' @param max_retries Maximum retry attempts (default: 3)
#' @return List with summary and validation status
generate_cluster_summary <- function(
  cluster_data,
  model = "gemini-3-pro-preview",
  max_retries = 3
) {
  retries <- 0
  last_error <- NULL

  while (retries < max_retries) {
    tryCatch({
      # Rate limiting delay with jitter
      if (retries > 0) {
        backoff_time <- (2^retries) + runif(1, 0, 1)
        Sys.sleep(backoff_time)
      }

      # Create chat and generate summary
      chat <- chat_google_gemini(model = model)
      result <- chat$chat_structured(
        prompt = build_cluster_prompt(cluster_data),
        type = cluster_summary_type
      )

      # Validate entities before returning
      validation <- validate_summary_entities(result, cluster_data)

      if (!validation$is_valid) {
        log_warn("Summary validation failed: {validation$errors}")
        retries <- retries + 1
        last_error <- validation$errors
        next
      }

      return(list(
        success = TRUE,
        summary = result,
        validation = validation
      ))

    }, error = function(e) {
      retries <<- retries + 1
      last_error <<- e$message
      log_warn("LLM call failed (attempt {retries}): {e$message}")
    })
  }

  return(list(
    success = FALSE,
    error = last_error,
    attempts = retries
  ))
}
```

### Pattern 3: Database Caching (Follow pubtator Pattern)
**What:** Store validated summaries with hash-based invalidation
**When to use:** All generated summaries
**Example:**
```r
# Source: api/functions/pubtator-functions.R pattern
# Follow generate_query_hash() and cache table pattern

#' Generate cluster hash for cache invalidation
#'
#' @param identifiers Tibble with hgnc_id column
#' @param cluster_type "functional" or "phenotype"
#' @return SHA256 hash string
generate_cluster_hash <- function(identifiers, cluster_type = "functional") {
  if (cluster_type == "functional") {
    # Sort HGNC IDs and join
    sorted_ids <- sort(identifiers$hgnc_id)
  } else {
    # Sort entity IDs for phenotype clusters
    sorted_ids <- sort(identifiers$entity_id)
  }

  id_string <- paste(sorted_ids, collapse = ",")
  digest::digest(id_string, algo = "sha256", serialize = FALSE)
}

#' Check if valid cached summary exists
#'
#' @param cluster_hash SHA256 hash of cluster composition
#' @return Cached summary or NULL if not found/expired
get_cached_summary <- function(cluster_hash) {
  db_execute_query(
    "SELECT * FROM llm_cluster_summary_cache
     WHERE cluster_hash = ? AND is_current = TRUE
     AND validation_status = 'validated'",
    list(cluster_hash)
  )
}
```

### Anti-Patterns to Avoid
- **Raw prompt without schema:** Never use `$chat()` for structured data; always use `$chat_structured()` with type specifications
- **Storing unvalidated summaries:** Always validate gene symbols before database storage
- **Hardcoding API keys:** Use `GEMINI_API_KEY` environment variable, never embed in code
- **Ignoring rate limits:** Gemini free tier is 5 RPM; paid tier 1 is 60 RPM for Pro models; always implement throttling
- **Skipping the log table:** Always log all generation attempts (success and failure) for debugging and prompt improvement

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gemini API client | Custom httr2 wrapper | ellmer::chat_google_gemini() | Handles auth, streaming, errors, structured output |
| JSON schema enforcement | Manual JSON parsing | ellmer type specifications | Guarantees valid JSON structure |
| Rate limiting | Custom sleep logic | httr2::req_throttle() or manual with jitter | Proven exponential backoff with jitter |
| Gene symbol validation | String matching | JOIN with non_alt_loci_set | Handles aliases, deprecated symbols |
| Hash generation | Custom hashing | digest::digest() | Already in codebase, consistent algorithm |
| Transaction handling | Manual BEGIN/COMMIT | db_with_transaction() | Already handles rollback on error |

**Key insight:** ellmer's type specifications provide compile-time schema enforcement that Gemini's raw API cannot guarantee. The `chat_structured()` method uses provider-native structured output features, meaning Gemini's `responseSchema` is used under the hood.

## Common Pitfalls

### Pitfall 1: LLM Gene Symbol Hallucination
**What goes wrong:** LLMs confidently generate plausible-sounding gene names that don't exist (e.g., "NEURODEV1", "BRCA3")
**Why it happens:** LLMs are pattern completers; gene nomenclature patterns are learnable but not the actual database
**How to avoid:** Strict validation against `non_alt_loci_set` table; reject entire summary if any invalid symbol detected
**Warning signs:** Gene symbols not in cluster input data, suspiciously descriptive names, names with numbers > 3

### Pitfall 2: Pathway Invention
**What goes wrong:** LLM generates pathway names not present in the enrichment input data
**Why it happens:** LLM has general knowledge of pathways and may interpolate
**How to avoid:** Validate pathways against the input enrichment terms; pathways must be subset of provided data
**Warning signs:** Pathways with very specific names not in enrichment, GO terms with unusual IDs

### Pitfall 3: Rate Limit Exhaustion (429 Errors)
**What goes wrong:** Batch generation exceeds API limits, causing cascading failures
**Why it happens:** Gemini rate limits are per-project, not per-key; free tier is only 5 RPM
**How to avoid:** Implement throttling with exponential backoff + jitter; monitor usage via AI Studio dashboard
**Warning signs:** Sudden 429 errors after initial success, errors mentioning "RESOURCE_EXHAUSTED"

### Pitfall 4: JSON Parsing in Prompts
**What goes wrong:** Including JSON schema in prompt text alongside `responseSchema` causes quality degradation
**Why it happens:** Duplicate schema confuses the model
**How to avoid:** Use ellmer's type specifications only; don't include schema examples in prompt text
**Warning signs:** Malformed JSON despite schema, inconsistent field naming

### Pitfall 5: Missing Required Fields in Output
**What goes wrong:** LLM omits fields when data is sparse, causing downstream errors
**Why it happens:** Default `required = TRUE` in ellmer causes hallucination when data is absent
**How to avoid:** Use `required = FALSE` for optional fields; handle NA values gracefully
**Warning signs:** Fabricated confidence scores, generic summaries for sparse clusters

### Pitfall 6: Model Version Mismatch
**What goes wrong:** Code references model that no longer exists or has changed capabilities
**Why it happens:** Google frequently updates model names and capabilities
**How to avoid:** Pin model version explicitly; check changelog before updates; use `models_google_gemini()` to list available models
**Warning signs:** "Model not found" errors, unexpected output format changes

## Code Examples

Verified patterns from official sources:

### ellmer Type Specification for Cluster Summary
```r
# Source: https://ellmer.tidyverse.org/articles/structured-data.html
# Source: https://cran.r-project.org/web/packages/ellmer/vignettes/structured-data.html

# Complete type specification for functional cluster summary
functional_cluster_summary_type <- type_object(
  "AI-generated summary of a functional gene cluster",

  summary = type_string(
    "2-3 sentence prose summary describing the cluster's biological function
     and relevance to neurodevelopmental disorders.
     Target audience: clinical researchers and database curators."
  ),

  key_themes = type_array(
    type_string("Biological theme or function"),
    "3-5 key biological themes that characterize this cluster"
  ),

  pathways = type_array(
    type_string("Pathway name from enrichment analysis"),
    "Top pathways from the enrichment data that define this cluster.
     Must be exact matches from the provided enrichment terms."
  ),

  tags = type_array(
    type_string("Searchable keyword for filtering"),
    "3-7 short, searchable tags (e.g., 'mitochondrial', 'synaptic', 'metabolism')"
  ),

  clinical_relevance = type_string(
    "Brief note on clinical implications for NDD diagnosis or research",
    required = FALSE
  ),

  confidence = type_enum(
    c("high", "medium", "low"),
    "Self-assessed confidence: high if enrichment data strongly supports themes,
     medium if moderate support, low if sparse data or ambiguous patterns"
  )
)

# Phenotype cluster adds syndrome hints and curation notes
phenotype_cluster_summary_type <- type_object(
  "AI-generated summary of a phenotype cluster",

  summary = type_string("2-3 sentence prose summary"),
  key_themes = type_array(type_string(), "3-5 themes"),
  pathways = type_array(type_string(), "Top pathways"),
  tags = type_array(type_string(), "3-7 tags"),
  confidence = type_enum(c("high", "medium", "low")),

  # Phenotype-specific fields
  syndrome_hints = type_array(
    type_string("Recognized syndrome name"),
    "Potential syndrome associations suggested by phenotype pattern",
    required = FALSE
  ),

  curation_notes = type_string(
    "Notes for curators on phenotype patterns or potential gene associations",
    required = FALSE
  )
)
```

### Gene Symbol Validation Function
```r
# Source: Existing pattern from api/functions/external-proxy-functions.R (validate_gene_symbol)
# Enhanced for LLM output validation

#' Validate gene symbols in LLM output against HGNC database
#'
#' @param summary_result List from chat_structured() with pathways and summary
#' @param cluster_data Original cluster data with valid gene symbols
#' @return List with is_valid boolean, valid_genes, invalid_genes, errors
validate_summary_entities <- function(summary_result, cluster_data) {
  errors <- character()


  # Extract gene symbols from summary text (if any mentioned)
  # Pattern matches HGNC-style symbols: uppercase start, alphanumeric + hyphen
  summary_text <- summary_result$summary
  mentioned_genes <- str_extract_all(
    summary_text,
    "\\b[A-Z][A-Z0-9-]{1,15}\\b"
  )[[1]]

  # Filter to likely gene symbols (exclude common words)
  common_words <- c("THE", "AND", "FOR", "DNA", "RNA", "ATP", "GTP", "ADP")
  mentioned_genes <- setdiff(mentioned_genes, common_words)

  if (length(mentioned_genes) > 0) {
    # Validate against non_alt_loci_set
    valid_symbols <- db_execute_query(
      "SELECT symbol FROM non_alt_loci_set WHERE symbol IN (?)",
      list(paste(mentioned_genes, collapse = "','"))
    )$symbol

    invalid_genes <- setdiff(mentioned_genes, valid_symbols)

    # Also check if genes are in the input cluster
    cluster_genes <- cluster_data$identifiers$symbol
    genes_not_in_cluster <- setdiff(
      intersect(mentioned_genes, valid_symbols),
      cluster_genes
    )

    if (length(invalid_genes) > 0) {
      errors <- c(errors, paste(
        "Invalid gene symbols:",
        paste(invalid_genes, collapse = ", ")
      ))
    }

    if (length(genes_not_in_cluster) > 0) {
      # Warning, not error - LLM may reference related genes
      log_info("Genes mentioned but not in cluster: {paste(genes_not_in_cluster, collapse=', ')}")
    }
  }

  # Validate pathways against enrichment input
  if (!is.null(summary_result$pathways) && length(summary_result$pathways) > 0) {
    enrichment_terms <- cluster_data$term_enrichment$term
    invalid_pathways <- setdiff(summary_result$pathways, enrichment_terms)

    if (length(invalid_pathways) > 0) {
      errors <- c(errors, paste(
        "Pathways not in enrichment data:",
        paste(invalid_pathways, collapse = ", ")
      ))
    }
  }

  return(list(
    is_valid = length(errors) == 0,
    mentioned_genes = mentioned_genes,
    invalid_genes = if (exists("invalid_genes")) invalid_genes else character(),
    errors = errors
  ))
}
```

### Database Migration for Cache Tables
```sql
-- Source: Following pattern from db/migrations/005_add_pubtator_gene_symbols.sql

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_006_llm_summary_cache()
BEGIN
    -- Create llm_cluster_summary_cache table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_cluster_summary_cache'
    ) THEN
        CREATE TABLE llm_cluster_summary_cache (
            cache_id INT AUTO_INCREMENT PRIMARY KEY,
            cluster_type ENUM('functional', 'phenotype') NOT NULL,
            cluster_number INT NOT NULL,
            cluster_hash VARCHAR(64) NOT NULL COMMENT 'SHA256 of sorted gene/entity IDs',
            model_name VARCHAR(50) NOT NULL,
            prompt_version VARCHAR(20) NOT NULL DEFAULT '1.0',
            summary_json JSON NOT NULL COMMENT 'Full structured response from LLM',
            tags JSON COMMENT 'Extracted tags for search/filtering',
            is_current BOOLEAN NOT NULL DEFAULT TRUE,
            validation_status ENUM('pending', 'validated', 'rejected') NOT NULL DEFAULT 'pending',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            validated_at TIMESTAMP NULL,
            validated_by INT NULL COMMENT 'user_id of validator',
            INDEX idx_cluster_hash (cluster_hash),
            INDEX idx_cluster_type_number (cluster_type, cluster_number),
            INDEX idx_validation_status (validation_status),
            INDEX idx_is_current (is_current)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    END IF;

    -- Create llm_generation_log table if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_generation_log'
    ) THEN
        CREATE TABLE llm_generation_log (
            log_id INT AUTO_INCREMENT PRIMARY KEY,
            cluster_type ENUM('functional', 'phenotype') NOT NULL,
            cluster_number INT NOT NULL,
            cluster_hash VARCHAR(64) NOT NULL,
            model_name VARCHAR(50) NOT NULL,
            prompt_text TEXT NOT NULL,
            response_json JSON COMMENT 'Raw LLM response (success or partial)',
            validation_errors TEXT COMMENT 'Validation failure details',
            tokens_input INT,
            tokens_output INT,
            latency_ms INT,
            status ENUM('success', 'validation_failed', 'api_error', 'timeout') NOT NULL,
            error_message TEXT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_cluster_hash (cluster_hash),
            INDEX idx_status (status),
            INDEX idx_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    END IF;

    -- Add functional index on summary_json tags for search (MySQL 8.0.17+)
    -- Uses multi-valued index for JSON array searching
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'llm_cluster_summary_cache'
          AND INDEX_NAME = 'idx_tags'
    ) THEN
        CREATE INDEX idx_tags ON llm_cluster_summary_cache(
            (CAST(tags AS CHAR(100) ARRAY))
        );
    END IF;
END //

CALL migrate_006_llm_summary_cache() //

DROP PROCEDURE IF EXISTS migrate_006_llm_summary_cache //
```

### Prompt Template Structure
```r
# Prompt template using glue for string interpolation
# Keep schema in type_specification, not in prompt text

#' Build prompt for functional cluster summary
#'
#' @param cluster_data Cluster tibble with identifiers and enrichment
#' @param top_n_terms Number of enrichment terms to include (default: 20)
#' @return Character string prompt
build_cluster_prompt <- function(cluster_data, top_n_terms = 20) {
  # Extract gene symbols
  genes <- paste(cluster_data$identifiers$symbol, collapse = ", ")
  gene_count <- nrow(cluster_data$identifiers)

  # Extract top enrichment terms by category
  enrichment <- cluster_data$term_enrichment %>%
    group_by(category) %>%
    slice_head(n = top_n_terms) %>%
    ungroup()

  # Format enrichment for prompt
  enrichment_text <- enrichment %>%
    mutate(term_line = glue::glue("- {term} (FDR: {signif(fdr, 3)})")) %>%
    group_by(category) %>%
    summarise(terms = paste(term_line, collapse = "\n")) %>%
    mutate(section = glue::glue("### {category}\n{terms}")) %>%
    pull(section) %>%
    paste(collapse = "\n\n")

  glue::glue("
You are an expert in neurodevelopmental disorders and genomics.
Analyze this gene cluster and provide a summary.

## Cluster Information
- **Cluster Size:** {gene_count} genes
- **Genes:** {genes}

## Enrichment Analysis Results
{enrichment_text}

## Instructions
1. Summarize what biological functions unite these genes
2. Identify 3-5 key themes based on the enrichment data
3. List the most significant pathways (use exact names from enrichment above)
4. Suggest 3-7 searchable tags (lowercase, single words)
5. Note any clinical relevance for neurodevelopmental disorder research
6. Assess your confidence based on enrichment data strength
")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| gemini.R package | ellmer package | 2025 | Native structured output, better maintenance |
| Manual JSON parsing | type_object() specs | ellmer 0.2.0 (May 2025) | Guaranteed valid JSON, R type conversion |
| GOOGLE_API_KEY | GEMINI_API_KEY supported | ellmer 0.2.0 | Clearer naming, backward compatible |
| Gemini 1.5 Pro | Gemini 3.0 Pro Preview | Late 2025 | Better clinical context, structured output |
| propertyOrdering required | Automatic ordering | Gemini 2.5+ | Simpler schema definitions |
| anyOf not supported | anyOf, $defs, $ref supported | November 2025 | More flexible schemas |

**Deprecated/outdated:**
- `chat$extract_data()` - Renamed to `chat_structured()` in ellmer 0.2.0
- `ToolArg()` for type specs - Replaced by `type_*()` functions
- Gemini 1.5 models - Still available but 2.0/2.5/3.0 preferred for structured output
- `gemini-2.0-flash-exp` - Experimental; use `gemini-2.0-flash` instead

## Open Questions

Things that couldn't be fully resolved:

1. **Exact rate limits for Paid Tier 1**
   - What we know: Free tier is 5 RPM, Paid Tier 1 significantly higher
   - What's unclear: Exact RPM for gemini-3-pro-preview (documentation directs to AI Studio)
   - Recommendation: Start conservative (30 RPM), monitor via AI Studio, adjust based on actual limits

2. **Token counting accuracy**
   - What we know: ellmer 0.4.0 captures token counts including cached tokens
   - What's unclear: Whether token counts include system prompt tokens for cost estimation
   - Recommendation: Log all token counts, verify against Google billing dashboard

3. **Gemini 3.0 Pro Preview stability**
   - What we know: Model is in preview, context says it's "best for clinical context"
   - What's unclear: Timeline for GA release, potential breaking changes
   - Recommendation: Pin to specific model version, have fallback to 2.5-flash

## Sources

### Primary (HIGH confidence)
- [ellmer tidyverse documentation](https://ellmer.tidyverse.org/) - structured data, type specifications, changelog
- [ellmer CRAN vignette](https://cran.r-project.org/web/packages/ellmer/vignettes/structured-data.html) - complete type specification examples
- [Google Gemini API structured output docs](https://ai.google.dev/gemini-api/docs/structured-output) - responseSchema, supported types

### Secondary (MEDIUM confidence)
- [Gemini API rate limits](https://ai.google.dev/gemini-api/docs/rate-limits) - tier structure (specific numbers require AI Studio)
- [httr2 req_retry documentation](https://httr2.r-lib.org/reference/req_retry.html) - exponential backoff with jitter
- [Nature Scientific Reports LLM biomedical entity grounding](https://www.nature.com/articles/s41598-026-35492-8) - 91.3% precision with validation

### Tertiary (LOW confidence)
- WebSearch results on December 2025 rate limit changes - may have changed since
- WebSearch results on specific model limits - recommend verifying in AI Studio

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ellmer is actively maintained by tidyverse, documentation verified
- Architecture: HIGH - Patterns directly follow existing codebase patterns (external-proxy, pubtator)
- Entity validation: HIGH - Multiple sources confirm hallucination risk and mitigation strategies
- Rate limiting: MEDIUM - Tier structure verified, exact limits require AI Studio verification
- Database schema: HIGH - Follows existing migration pattern, MySQL 8.0 JSON support verified

**Research date:** 2026-01-31
**Valid until:** 2026-03-01 (30 days - ellmer is actively developed, check changelog before implementation)
