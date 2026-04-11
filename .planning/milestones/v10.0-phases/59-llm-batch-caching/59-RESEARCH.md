# Phase 59: LLM Batch, Caching & Validation - Research

**Researched:** 2026-01-31
**Domain:** Batch LLM generation via mirai, LLM-as-judge validation, chained async jobs
**Confidence:** HIGH

## Summary

This research documents how to implement batch LLM summary generation as part of the clustering pipeline, with LLM-as-judge validation integrated as the final step. Phase 58 built the foundation (ellmer client, cache repository, entity validation) which this phase will use.

Key findings:
1. **Chained job pattern**: Modify clustering job completion callback to trigger LLM generation job. The existing mirai promise-based callback pattern (`%...>%`) can chain jobs by calling `create_job()` in the completion handler.
2. **ellmer batch processing**: Use `parallel_chat_structured()` with `rpm = 30` (conservative rate limit) for batch generation. This handles rate limiting and returns structured data.
3. **LLM-as-judge integration**: Implement as post-generation validation step, not separate job. Use same Gemini model with different prompt to evaluate summary accuracy.
4. **Validation failure handling**: Accept summaries that pass LLM-as-judge, flag low-confidence ones, retry failures up to 3 times.

**Primary recommendation:** Integrate LLM generation into clustering job completion callback using `parallel_chat_structured()`, then run LLM-as-judge validation on each result before caching.

## Standard Stack

### Core (Already in Codebase from Phase 58)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ellmer | 0.4.0 | Gemini API client, batch processing | Native `parallel_chat_structured()` with rate limiting |
| mirai | 1.2.0+ | Async job execution | Already used for clustering jobs |
| DBI | 1.2.0+ | Database operations | Already used for cache storage |
| digest | 0.6.0+ | Hash generation | Already used for cluster hashing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| promises | 1.3.0+ | Async callback chaining | Chain LLM job after clustering completion |
| logger | 0.2.0+ | Structured logging | All LLM operations for audit trail |
| coro | 1.1.0 | Coroutine support | Already added in Phase 58 |

### Not Adding
| Library | Reason Not to Add |
|---------|-------------------|
| hellmer | Overkill for this use case - ellmer's `parallel_chat_structured()` is sufficient |
| future | mirai already provides daemon-based parallelism |

**Installation:**
Already complete from Phase 58. No new packages needed.

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── llm-service.R           # [EXISTS] Core LLM client, add batch wrapper
│   ├── llm-validation.R        # [EXISTS] Entity validation
│   ├── llm-cache-repository.R  # [EXISTS] Database cache operations
│   ├── llm-batch-generator.R   # [NEW] Batch generation orchestrator
│   └── llm-judge.R             # [NEW] LLM-as-judge validation
├── endpoints/
│   └── jobs_endpoints.R        # [MODIFY] Add LLM job status reporting
└── tests/testthat/
    ├── test-llm-batch.R        # [NEW] Batch generation tests
    └── test-llm-judge.R        # [NEW] LLM-as-judge tests
```

### Pattern 1: Chained Job Triggering

**What:** Trigger LLM generation automatically when clustering job completes
**When to use:** Always - clustering completion triggers LLM generation
**How it works:** Modify clustering job's promise callback to call `create_job()` for LLM generation

```r
# Source: api/functions/job-manager.R (existing pattern)
# In clustering job completion callback, chain LLM generation:

# Modified create_job callback pattern:
m %...>% (function(result) {
  if (!mirai::is_mirai_error(result)) {
    jobs_env[[job_id]]$status <- "completed"
    jobs_env[[job_id]]$result <- result

    # CHAIN: Trigger LLM generation for completed clusters
    if (operation == "clustering" && !is.null(result$clusters)) {
      trigger_llm_batch_generation(
        clusters = result$clusters,
        cluster_type = "functional",
        parent_job_id = job_id
      )
    }
  }
  jobs_env[[job_id]]$completed_at <- Sys.time()
  cleanup_job_progress(job_id)
})
```

### Pattern 2: Batch Generation with Rate Limiting

**What:** Generate summaries for multiple clusters in parallel with rate limiting
**When to use:** Processing all clusters from a clustering job
**Key insight:** Use ellmer's built-in rate limiting rather than manual throttling

```r
# Source: https://ellmer.tidyverse.org/reference/parallel_chat.html
# ellmer's parallel_chat_structured handles rate limiting internally

generate_batch_summaries <- function(clusters, cluster_type, progress_fn = NULL) {
  # Create chat instance
  chat <- ellmer::chat_google_gemini(model = "gemini-2.0-flash")

  # Build prompts for all clusters
  prompts <- purrr::map_chr(seq_len(nrow(clusters)), function(i) {
    build_cluster_prompt(list(
      identifiers = clusters$identifiers[[i]],
      term_enrichment = clusters$term_enrichment[[i]],
      cluster_number = clusters$cluster[[i]]
    ))
  })

  # Process in parallel with rate limiting
  # rpm = 30 is conservative (half of Paid Tier 1 limit)
  results <- ellmer::parallel_chat_structured(
    chat = chat,
    prompts = prompts,
    type = functional_cluster_summary_type,
    max_active = 5,   # Max concurrent requests
    rpm = 30          # Rate limit: 30 requests per minute
  )

  return(results)
}
```

### Pattern 3: LLM-as-Judge Validation

**What:** Use a second LLM call to validate summary accuracy
**When to use:** After entity validation passes, before final caching
**Key insight:** Same model, different prompt - no extra API setup needed

```r
# Source: https://www.evidentlyai.com/llm-guide/llm-as-a-judge
# LLM-as-judge prompt template

judge_summary_type <- ellmer::type_object(
  "Validation assessment of a cluster summary",

  is_accurate = ellmer::type_boolean(
    "Does the summary accurately reflect the cluster data?"
  ),

  is_grounded = ellmer::type_boolean(
    "Are all claims grounded in the provided enrichment data?"
  ),

  confidence_appropriate = ellmer::type_boolean(
    "Is the confidence level appropriate for the data strength?"
  ),

  reasoning = ellmer::type_string(
    "Brief explanation of the assessment"
  ),

  overall_verdict = ellmer::type_enum(
    c("accept", "reject", "low_confidence"),
    "Final verdict: accept for caching, reject for regeneration,
     low_confidence to flag for review"
  )
)

validate_summary_with_judge <- function(summary, cluster_data) {
  chat <- ellmer::chat_google_gemini(model = "gemini-2.0-flash")

  prompt <- glue::glue("
You are evaluating an AI-generated summary for a gene cluster.
Your job is to verify the summary is accurate and grounded in the data.

## Original Cluster Data
- Genes: {paste(cluster_data$identifiers$symbol, collapse = ', ')}
- Top Enrichment Terms: {paste(head(cluster_data$term_enrichment$term, 10), collapse = ', ')}

## Generated Summary
{summary$summary}

## Key Themes Claimed
{paste(summary$key_themes, collapse = ', ')}

## Pathways Listed
{paste(summary$pathways, collapse = ', ')}

## Self-Assessed Confidence
{summary$confidence}

## Evaluation Criteria
1. Summary accurately describes biological function of these genes
2. Key themes are supported by the enrichment data
3. Listed pathways exist in the enrichment input (not invented)
4. Confidence level matches the strength of evidence
5. No hallucinated gene names or pathways
")

  result <- chat$chat_structured(
    prompt = prompt,
    type = judge_summary_type
  )

  return(result)
}
```

### Pattern 4: Batch Processing with Progress Reporting

**What:** Report per-cluster progress during batch generation
**When to use:** Always - matches existing job progress pattern

```r
# Source: api/functions/job-progress.R (existing pattern)
# Use file-based progress reporting for batch status

process_clusters_with_progress <- function(clusters, job_id, cluster_type) {
  progress <- create_progress_reporter(job_id)
  total <- nrow(clusters)

  results <- list()
  succeeded <- 0
  failed <- 0
  skipped <- 0

  for (i in seq_len(total)) {
    cluster <- clusters[i, ]
    cluster_num <- cluster$cluster

    # Report progress
    progress(
      step = "generating",
      message = sprintf("Generating %d/%d clusters (Cluster %d)", i, total, cluster_num),
      current = i,
      total = total
    )

    # Check cache first
    cluster_hash <- generate_cluster_hash(cluster$identifiers[[1]], cluster_type)
    cached <- get_cached_summary(cluster_hash)

    if (!is.null(cached) && nrow(cached) > 0) {
      skipped <- skipped + 1
      results[[i]] <- list(from_cache = TRUE, summary = cached)
      next
    }

    # Generate with retry
    result <- tryCatch({
      generate_and_validate_summary(cluster, cluster_type)
    }, error = function(e) {
      list(success = FALSE, error = e$message)
    })

    if (result$success) {
      succeeded <- succeeded + 1
    } else {
      failed <- failed + 1
    }

    results[[i]] <- result
  }

  # Final progress update
  progress(
    step = "complete",
    message = sprintf("Completed: %d succeeded, %d failed, %d cached",
                      succeeded, failed, skipped),
    current = total,
    total = total
  )

  return(list(
    results = results,
    stats = list(
      succeeded = succeeded,
      failed = failed,
      skipped = skipped
    )
  ))
}
```

### Anti-Patterns to Avoid

- **Separate LLM job queue:** Don't create a separate job type - chain directly from clustering completion
- **Manual rate limiting with Sys.sleep():** Use ellmer's built-in `rpm` parameter instead
- **Blocking main thread for batch:** All batch processing happens in mirai daemon
- **Retrying entire batch on failure:** Retry individual clusters, not the whole batch
- **Storing pending summaries separately:** Use same cache table with validation_status column

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate limiting | Sys.sleep() loops | ellmer `rpm` parameter | Built-in, handles jitter |
| Batch parallelism | purrr::map with delays | `parallel_chat_structured()` | Handles rate limits, errors |
| Job chaining | Custom queue system | promises `%...>%` callback | Already in mirai pattern |
| Progress tracking | Custom progress file | `create_progress_reporter()` | Already exists, tested |
| LLM evaluation | Custom scoring logic | LLM-as-judge pattern | More flexible, domain-aware |
| Confidence scoring | Rule-based only | Combine derived + LLM self-assessment | Hybrid approach more robust |

**Key insight:** Phase 58 built most of the infrastructure. This phase is primarily orchestration (chaining jobs, batch processing) rather than new components.

## Common Pitfalls

### Pitfall 1: Exhausting mirai Worker Pool
**What goes wrong:** LLM batch job blocks all workers, preventing other async operations
**Why it happens:** Default 2 workers, LLM job runs for minutes
**How to avoid:** Use only 1 worker for LLM batch (dedicated), keep 1 for other jobs
**Warning signs:** Job queue timeouts, unresponsive API during batch

### Pitfall 2: Rate Limit Errors Causing Cascade Failures
**What goes wrong:** 429 errors cause batch to fail completely
**Why it happens:** Underestimating actual API usage, bursty traffic
**How to avoid:** Conservative `rpm = 30` (half of limit), exponential backoff on 429
**Warning signs:** Sudden batch failures after initial success, RESOURCE_EXHAUSTED errors

### Pitfall 3: LLM-as-Judge Rejecting Valid Summaries
**What goes wrong:** Judge is too strict, rejects most summaries
**Why it happens:** Prompt too demanding, model different from generator
**How to avoid:** Use same model for generation and judging; calibrate on test set; accept "low_confidence" verdict
**Warning signs:** High rejection rate (>30%), inconsistent verdicts across runs

### Pitfall 4: Memory Growth in Long Batches
**What goes wrong:** Daemon runs out of memory processing large cluster sets
**Why it happens:** Accumulating results, keeping chat history
**How to avoid:** Process in chunks of 10-20; clear intermediate results; fresh chat per cluster
**Warning signs:** Daemon crashes, R memory errors in logs

### Pitfall 5: Ignoring Cached Clusters
**What goes wrong:** Regenerating already-valid cached summaries
**Why it happens:** Cache check after LLM call, or not checking at all
**How to avoid:** Check cache FIRST, only generate for cache misses
**Warning signs:** Identical summaries in cache, high API costs

### Pitfall 6: Validation Failure Infinite Loop
**What goes wrong:** Retry loop never exits because validation always fails
**Why it happens:** No retry limit, fundamental prompt issue
**How to avoid:** Max 3 retries per cluster; after exhausting retries, log and continue
**Warning signs:** Single cluster taking >1 minute, repeating log messages

## Code Examples

### LLM Batch Generator Module

```r
# api/functions/llm-batch-generator.R
# Orchestrates batch LLM generation as part of clustering pipeline

require(ellmer)
require(logger)

#' Trigger batch LLM generation after clustering completes
#'
#' Called from clustering job's completion callback.
#' Creates a new job for LLM generation, respecting job limits.
#'
#' @param clusters Tibble with cluster data (from clustering result)
#' @param cluster_type "functional" or "phenotype"
#' @param parent_job_id Job ID of the clustering job (for linking)
#' @return Job result (job_id or error)
#'
#' @export
trigger_llm_batch_generation <- function(clusters, cluster_type, parent_job_id) {
  log_info("Triggering LLM batch generation for {nrow(clusters)} clusters (parent job: {parent_job_id})")

  # Check if Gemini is configured
  if (!is_gemini_configured()) {
    log_warn("GEMINI_API_KEY not set, skipping LLM generation")
    return(list(skipped = TRUE, reason = "API key not configured"))
  }

  # Create LLM generation job
  result <- create_job(
    operation = "llm_generation",
    params = list(
      clusters = clusters,
      cluster_type = cluster_type,
      parent_job_id = parent_job_id
    ),
    executor_fn = llm_batch_executor,
    timeout_ms = 3600000  # 1 hour for large batches
  )

  return(result)
}

#' Executor function for LLM batch generation
#'
#' Runs in mirai daemon. Processes clusters sequentially with
#' cache checking, generation, validation, and caching.
#'
#' @param params List with clusters, cluster_type, parent_job_id
#' @return Summary of batch processing
llm_batch_executor <- function(params) {
  clusters <- params$clusters
  cluster_type <- params$cluster_type
  job_id <- params$.__job_id__

  # Create progress reporter
  progress <- create_progress_reporter(job_id)

  total <- nrow(clusters)
  succeeded <- 0
  failed <- 0
  skipped <- 0

  for (i in seq_len(total)) {
    cluster <- clusters[i, ]
    cluster_num <- cluster$cluster

    # Update progress
    progress(
      step = "generating",
      message = sprintf("Cluster %d (%d/%d)", cluster_num, i, total),
      current = i,
      total = total
    )

    # Build cluster_data for generation
    cluster_data <- list(
      identifiers = cluster$identifiers[[1]],
      term_enrichment = cluster$term_enrichment[[1]],
      cluster_number = cluster_num
    )

    # Check cache first
    cluster_hash <- generate_cluster_hash(cluster_data$identifiers, cluster_type)
    cached <- get_cached_summary(cluster_hash)

    if (!is.null(cached) && nrow(cached) > 0) {
      skipped <- skipped + 1
      log_debug("Cluster {cluster_num}: cached (cache_id={cached$cache_id[1]})")
      next
    }

    # Generate with retry (up to 3 attempts)
    success <- FALSE
    attempts <- 0
    max_attempts <- 3

    while (!success && attempts < max_attempts) {
      attempts <- attempts + 1

      result <- tryCatch({
        generate_and_validate_with_judge(cluster_data, cluster_type)
      }, error = function(e) {
        log_warn("Cluster {cluster_num} attempt {attempts}: {e$message}")
        list(success = FALSE, error = e$message)
      })

      if (result$success) {
        success <- TRUE
        succeeded <- succeeded + 1
        log_info("Cluster {cluster_num}: generated successfully")
      } else if (attempts < max_attempts) {
        # Backoff before retry
        Sys.sleep(2^attempts + runif(1))
      }
    }

    if (!success) {
      failed <- failed + 1
      log_warn("Cluster {cluster_num}: failed after {max_attempts} attempts")
    }
  }

  # Final progress
  progress(
    step = "complete",
    message = sprintf("Done: %d succeeded, %d failed, %d cached",
                      succeeded, failed, skipped),
    current = total,
    total = total
  )

  return(list(
    total = total,
    succeeded = succeeded,
    failed = failed,
    skipped = skipped
  ))
}
```

### LLM-as-Judge Module

```r
# api/functions/llm-judge.R
# LLM-as-judge validation for cluster summaries

require(ellmer)
require(logger)
require(glue)

#' Type specification for LLM-as-judge verdict
#' @export
llm_judge_verdict_type <- ellmer::type_object(
  "Validation verdict for a cluster summary",

  is_factually_accurate = ellmer::type_boolean(
    "Summary accurately describes biological function of the genes"
  ),

  is_grounded = ellmer::type_boolean(
    "All claims are supported by the enrichment data provided"
  ),

  pathways_valid = ellmer::type_boolean(
    "Listed pathways match the enrichment input (no invented pathways)"
  ),

  confidence_appropriate = ellmer::type_boolean(
    "Self-assessed confidence matches the evidence strength"
  ),

  reasoning = ellmer::type_string(
    "Brief explanation of assessment (2-3 sentences)"
  ),

  verdict = ellmer::type_enum(
    c("accept", "low_confidence", "reject"),
    "Final verdict: accept (cache as validated), low_confidence (cache but flag),
     reject (do not cache, trigger regeneration)"
  )
)

#' Validate summary using LLM-as-judge
#'
#' Calls same Gemini model with judge prompt to evaluate summary.
#' Returns structured verdict.
#'
#' @param summary List with summary, key_themes, pathways, confidence
#' @param cluster_data List with identifiers and term_enrichment
#' @param model Gemini model (default: same as generation)
#' @return List with verdict details
#'
#' @export
validate_with_llm_judge <- function(
  summary,
  cluster_data,
  model = "gemini-2.0-flash"
) {
  # Build context for judge
  genes <- paste(cluster_data$identifiers$symbol, collapse = ", ")
  enrichment_terms <- head(cluster_data$term_enrichment$term, 15)
  enrichment_text <- paste(enrichment_terms, collapse = "\n- ")

  prompt <- glue::glue("
You are a scientific reviewer evaluating an AI-generated summary of a gene cluster.
Your task is to verify accuracy and grounding in the provided data.

## Cluster Data (Source of Truth)
**Genes in cluster:** {genes}
**Gene count:** {nrow(cluster_data$identifiers)}
**Top enrichment terms:**
- {enrichment_text}

## Generated Summary to Evaluate
**Summary:** {summary$summary}

**Key Themes Claimed:** {paste(summary$key_themes, collapse = ', ')}

**Pathways Listed:** {paste(summary$pathways, collapse = ', ')}

**Self-Assessed Confidence:** {summary$confidence}

## Evaluation Instructions
1. Is the summary factually accurate about these genes' biological function?
2. Are all claims grounded in the enrichment data above?
3. Do the listed pathways appear in the enrichment terms (not invented)?
4. Is the confidence level appropriate given the evidence?

Provide your verdict:
- 'accept': Summary is accurate and grounded, cache as validated
- 'low_confidence': Summary is acceptable but uncertain, cache with flag
- 'reject': Summary has significant issues, regenerate
")

  chat <- ellmer::chat_google_gemini(model = model)

  result <- tryCatch({
    chat$chat_structured(
      prompt = prompt,
      type = llm_judge_verdict_type
    )
  }, error = function(e) {
    log_warn("LLM judge failed: {e$message}")
    # Fallback: accept with low_confidence if judge fails
    list(
      is_factually_accurate = TRUE,
      is_grounded = TRUE,
      pathways_valid = TRUE,
      confidence_appropriate = TRUE,
      reasoning = "Judge evaluation failed; defaulting to low_confidence",
      verdict = "low_confidence"
    )
  })

  log_info("LLM judge verdict: {result$verdict} - {result$reasoning}")

  return(result)
}

#' Generate summary and validate with both entity validation and LLM judge
#'
#' Complete pipeline: generate -> entity validate -> LLM judge -> cache
#'
#' @param cluster_data List with identifiers and term_enrichment
#' @param cluster_type "functional" or "phenotype"
#' @return List with success status and summary
#'
#' @export
generate_and_validate_with_judge <- function(cluster_data, cluster_type) {
  # Step 1: Generate summary (includes entity validation in retry loop)
  gen_result <- generate_cluster_summary(
    cluster_data = cluster_data,
    cluster_type = cluster_type,
    max_retries = 3
  )

  if (!gen_result$success) {
    return(list(
      success = FALSE,
      error = gen_result$error,
      stage = "generation"
    ))
  }

  # Step 2: LLM-as-judge validation
  judge_result <- validate_with_llm_judge(
    summary = gen_result$summary,
    cluster_data = cluster_data
  )

  # Step 3: Determine validation status based on verdict
  validation_status <- switch(judge_result$verdict,
    "accept" = "validated",
    "low_confidence" = "pending",  # Flagged but usable
    "reject" = "rejected"
  )

  # Step 4: Cache the summary (even rejected ones for debugging)
  cluster_hash <- generate_cluster_hash(cluster_data$identifiers, cluster_type)
  cluster_number <- cluster_data$cluster_number %||% 0L

  # Add derived confidence and judge assessment to summary
  summary_with_metadata <- gen_result$summary
  summary_with_metadata$derived_confidence <- calculate_derived_confidence(
    cluster_data$term_enrichment
  )
  summary_with_metadata$llm_judge_verdict <- judge_result$verdict
  summary_with_metadata$llm_judge_reasoning <- judge_result$reasoning

  cache_id <- save_summary_to_cache(
    cluster_type = cluster_type,
    cluster_number = as.integer(cluster_number),
    cluster_hash = cluster_hash,
    model_name = "gemini-2.0-flash",
    prompt_version = "1.0",
    summary_json = summary_with_metadata,
    tags = gen_result$summary$tags,
    validation_status = validation_status
  )

  return(list(
    success = judge_result$verdict != "reject",
    summary = summary_with_metadata,
    cache_id = cache_id,
    validation_status = validation_status,
    judge_result = judge_result
  ))
}
```

### Integration with Clustering Job (Modification)

```r
# Modification to api/endpoints/jobs_endpoints.R
# Add chaining logic to clustering job completion

# In the executor_fn for clustering:
executor_fn = function(params) {
  # ... existing clustering logic ...
  clusters <- gen_string_clust_obj(params$genes, ...)

  # Return clusters + metadata for chaining
  result <- list(
    clusters = clusters,
    categories = categories,
    meta = list(
      algorithm = params$algorithm,
      gene_count = length(params$genes),
      cluster_count = nrow(clusters),
      # Signal that LLM generation should follow
      trigger_llm = TRUE,
      cluster_type = "functional"
    )
  )

  return(result)
}

# In create_job callback (job-manager.R), check for trigger:
m %...>% (function(result) {
  # ... existing completion logic ...

  # Check for LLM generation trigger
  if (!is.null(result$meta$trigger_llm) && result$meta$trigger_llm) {
    # Chain LLM generation job
    trigger_llm_batch_generation(
      clusters = result$clusters,
      cluster_type = result$meta$cluster_type,
      parent_job_id = job_id
    )
  }
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate LLM regeneration job | Chained after clustering | This phase | Simpler user flow |
| Manual rate limiting | ellmer `rpm` parameter | ellmer 0.2.0+ | Built-in handling |
| Rule-based validation only | LLM-as-judge + entity validation | 2025 (best practice) | More flexible |
| Binary accept/reject | Three-tier (accept/low_confidence/reject) | LLM-as-judge patterns | Better nuance |
| Sequential processing | `parallel_chat_structured()` | ellmer 0.2.0+ | Faster batches |

**Current best practice for LLM-as-judge:**
- Use same model for generation and judging (consistency)
- Chain-of-thought prompting improves accuracy
- Accept "low_confidence" verdicts rather than forcing regeneration
- Log all verdicts for calibration

## Open Questions

1. **Optimal batch size for parallel processing**
   - What we know: ellmer supports `max_active` parameter (default 10)
   - What's unclear: Best value for Gemini with 30 RPM limit
   - Recommendation: Start with `max_active = 5`, adjust based on error rates

2. **LLM-as-judge rejection threshold**
   - What we know: Accepting all "low_confidence" is safest
   - What's unclear: Whether to retry on "reject" or just log
   - Recommendation: Retry once on reject, then save as rejected for debugging

3. **Phenotype cluster handling**
   - What we know: Phase 58 defined `phenotype_cluster_summary_type`
   - What's unclear: Whether phenotype clustering uses same job pattern
   - Recommendation: Support both types in batch generator, use same chaining pattern

## Sources

### Primary (HIGH confidence)
- [ellmer parallel_chat documentation](https://ellmer.tidyverse.org/reference/parallel_chat.html) - batch processing API
- [ellmer structured data vignette](https://cran.r-project.org/web/packages/ellmer/vignettes/structured-data.html) - type specifications, parallel_chat_structured
- [mirai package documentation](https://mirai.r-lib.org/) - async patterns, promises integration
- [Existing codebase: api/functions/job-manager.R](file://api/functions/job-manager.R) - job creation, callbacks
- [Existing codebase: api/functions/llm-service.R](file://api/functions/llm-service.R) - Phase 58 LLM client

### Secondary (MEDIUM confidence)
- [LLM-as-a-Judge Guide - Evidently AI](https://www.evidentlyai.com/llm-guide/llm-as-a-judge) - best practices
- [LLM-as-Judge Best Practices - Monte Carlo](https://www.montecarlodata.com/blog-llm-as-judge/) - 7 best practices
- [Google Vertex AI Judge Model Docs](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/evaluate-judge-model) - evaluation criteria
- [LLM-as-Judge Tutorial - Patronus AI](https://www.patronus.ai/llm-testing/llm-as-a-judge) - patterns and templates

### Tertiary (LOW confidence)
- WebSearch results on specific rate limits - verify in AI Studio
- hellmer package patterns - not recommended for this use case but informative

## Metadata

**Confidence breakdown:**
- Chained job pattern: HIGH - directly follows existing job-manager.R pattern
- ellmer batch processing: HIGH - documented API, verified in CRAN vignette
- LLM-as-judge: MEDIUM - best practice pattern, needs calibration for domain
- Rate limiting: MEDIUM - using conservative limits, may need adjustment
- Progress reporting: HIGH - directly uses existing create_progress_reporter()

**Research date:** 2026-01-31
**Valid until:** 2026-03-01 (30 days - ellmer actively developed)
