# Domain Pitfalls: LLM Cluster Summaries for SysNDD v10.0

**Domain:** Adding LLM-generated scientific summaries to a neurodevelopmental disorder gene database
**Researched:** 2026-01-31
**Confidence:** HIGH (verified against 2026 research papers and official Gemini API documentation)

## Executive Summary

Adding LLM-generated cluster summaries to SysNDD poses unique challenges at the intersection of biomedical informatics and generative AI. The critical risks fall into five categories:

1. **Scientific hallucinations** - LLMs can invent non-existent genes, fabricate gene-disease associations, or misattribute pathway involvement
2. **Structured output failures** - JSON schema validation doesn't prevent semantically invalid content
3. **LLM-as-judge unreliability** - 64-68% agreement with domain experts in specialized fields
4. **Cache staleness** - Summaries become incorrect when underlying cluster data changes
5. **Cost/rate limit surprises** - Gemini API quotas are per-project, not per-key

The most dangerous failure mode is a **confident, well-formatted hallucination** that passes validation but contains fabricated scientific claims that users trust because the database is authoritative.

---

## Critical Pitfalls

Mistakes that cause rewrites, data integrity issues, or harm to users.

### Pitfall 1: Hallucinated Gene Names and Disease Associations

**What goes wrong:**
The LLM generates plausible-sounding but non-existent gene names, incorrect gene symbols, or fabricated gene-disease associations. For example, generating "BRCA3" (does not exist), confusing "DMD" the gene with "DMD" Duchenne muscular dystrophy, or claiming "Gene X is associated with autism" when no such evidence exists in the database.

**Why it happens:**
LLMs are trained on scientific literature but lack grounding in the specific SysNDD database content. They pattern-match based on common biomedical conventions, which leads to plausible but incorrect outputs. The 2026 research from Nature Scientific Reports found that even grounded LLMs produce hallucinations in biomedical contexts that "are hard to spot, even for experts" because they use valid domain terminology.

In SysNDD's case, cluster summaries receive:
- Gene symbols from the cluster (real)
- GO enrichment terms (real)
- Phenotype annotations (real)

But the LLM may:
- Invent additional genes that "should" be in the cluster
- Fabricate mechanistic explanations not supported by the enrichment data
- Claim disease associations beyond what the database states

**Consequences:**
- Users trust hallucinated information as database fact
- Researchers make incorrect conclusions based on fabricated associations
- Database credibility is damaged when errors are discovered
- Potential harm if clinical decisions are influenced

**Prevention:**
1. **Strict input grounding:** Prompt must ONLY reference genes actually in the cluster
2. **Entity validation:** Post-process LLM output to verify every gene symbol exists in `non_alt_loci_set`
3. **Claim extraction:** Parse generated text into subject-predicate-object claims, verify each against database
4. **Explicit constraints:** Prompt must state "Only mention genes from this list: {gene_symbols}. Do not add any genes."
5. **Retrieval-augmented generation:** Include actual database records (phenotypes, GO terms) in prompt context

**Warning signs:**
- Summary mentions genes not in the input cluster
- Summary claims disease associations not in `ndd_entity_view`
- Summary describes molecular mechanisms not supported by GO enrichment terms
- Reviewers report "the summary mentions X but I don't see it in the data"

**Detection:**
```r
# Post-generation validation
validate_summary_genes <- function(summary_text, cluster_genes) {
  # Extract gene symbols from summary (regex: uppercase + numbers/hyphens)
  mentioned_genes <- str_extract_all(summary_text, "\\b[A-Z][A-Z0-9-]+\\b")[[1]]
  mentioned_genes <- mentioned_genes[nchar(mentioned_genes) >= 2]

  # Cross-reference against cluster genes
  hallucinated <- setdiff(mentioned_genes, cluster_genes)

  # Filter out common false positives (GO, DNA, RNA, etc.)
  common_terms <- c("GO", "DNA", "RNA", "ATP", "GTP", "mRNA", "HPO")
  hallucinated <- setdiff(hallucinated, common_terms)

  return(hallucinated)  # If length > 0, flag for review
}
```

**Phase to address:**
Phase 1 (Foundation) - Build entity validation into the generation pipeline from day one. This is non-negotiable infrastructure.

---

### Pitfall 2: Confident Fabrication of Mechanistic Explanations

**What goes wrong:**
The LLM generates detailed mechanistic explanations (e.g., "These genes cooperate in the Wnt signaling pathway to regulate neuronal migration") that sound authoritative but are not supported by the enrichment data provided. The model "connects the dots" based on its training data, not the actual database evidence.

**Why it happens:**
LLMs are excellent at generating coherent explanations. When given a list of genes and GO terms, they will naturally synthesize a narrative. However, this narrative may:
- Over-extrapolate from limited data
- Import knowledge from training that doesn't apply to this specific cluster
- Confuse correlation (genes cluster together) with causation (genes work together mechanistically)

The IEEE JBHI 2025 paper on healthcare hallucinations notes that "medical hallucinations frequently use domain-specific terms and appear to present coherent logic, which can make them difficult to recognize without expert scrutiny."

**Consequences:**
- Researchers may cite these explanations as database-derived facts
- Incorrect pathway attributions propagate into downstream analyses
- Expert curators spend time debunking generated explanations

**Prevention:**
1. **Hedged language requirements:** Prompt must specify "Use phrases like 'may be involved in', 'enrichment suggests', 'potential role in' - never assert causation"
2. **Citation-required format:** Require the LLM to cite which GO term or enrichment result supports each claim
3. **Two-stage generation:** First generate claims, then filter to only those with explicit evidence
4. **Template-based generation:** Use structured templates that limit free-form explanation

**Warning signs:**
- Summary uses definitive language: "These genes control...", "This pathway is responsible for..."
- Summary describes mechanisms not present in any GO enrichment term
- Summary complexity exceeds what the input data could support

**Detection:**
```r
# Check for unsupported mechanism claims
validate_mechanism_claims <- function(summary_text, enrichment_terms) {
  # List of mechanism keywords
  mechanism_words <- c("pathway", "signaling", "cascade", "regulates",
                       "controls", "activates", "inhibits", "binds")

  # Extract sentences containing mechanism words
  sentences <- str_split(summary_text, "[.!?]")[[1]]
  mechanism_sentences <- sentences[str_detect(tolower(sentences),
                                               paste(mechanism_words, collapse = "|"))]

  # Each mechanism sentence should reference a GO/enrichment term
  for (sentence in mechanism_sentences) {
    has_support <- any(sapply(enrichment_terms, function(term) {
      str_detect(tolower(sentence), tolower(term))
    }))
    if (!has_support) {
      # Flag for review: mechanism claim without enrichment support
      return(list(unsupported = TRUE, sentence = sentence))
    }
  }
  return(list(unsupported = FALSE))
}
```

**Phase to address:**
Phase 1 (Foundation) - Prompt engineering must enforce hedged language. Phase 2 (Validation) - Add claim verification.

---

### Pitfall 3: Structured Output Schema Passes But Content is Invalid

**What goes wrong:**
Gemini's structured output validation ensures the response matches the JSON schema (correct types, required fields present), but the content within those fields can still be semantically invalid. For example:
- `gene_symbols: ["BRCA1", "FAKE_GENE"]` - array of strings, schema valid, but contains hallucinated gene
- `confidence: 0.95` - valid float, but fabricated by the model
- `mechanism: "..."` - valid string, but unsupported by evidence

**Why it happens:**
JSON Schema validation is syntactic, not semantic. The Gemini API's structured output feature (announced November 2025) validates that output matches declared types and structure, but cannot validate that:
- Gene symbols exist in a database
- Numeric scores are meaningful
- Text content is factually accurate

Developers often assume "structured output = validated output" which is dangerously incorrect for scientific applications.

**Consequences:**
- Hallucinations pass automated validation
- False confidence in generation quality
- Invalid data stored in database without manual review

**Prevention:**
1. **Separate schema validation from content validation:** JSON schema catches format errors; custom validators catch content errors
2. **Post-processing pipeline:** Every generated field must have a validator
3. **Confidence scores from validation, not LLM:** Don't ask the model for confidence; compute it based on verification results
4. **Human-in-the-loop for novel content:** Flag summaries with new claims for curator review

**Warning signs:**
- All generated summaries pass schema validation but reviewers find errors
- Automated tests pass but integration tests with real data fail
- "Confidence" scores from LLM don't correlate with actual quality

**Detection:**
```r
# Content validation layer (separate from schema validation)
validate_summary_content <- function(summary, cluster_data) {
  errors <- list()

  # Validate all gene symbols exist
  for (gene in summary$gene_symbols) {
    if (!gene_exists_in_db(gene)) {
      errors <- c(errors, paste("Unknown gene:", gene))
    }
  }

  # Validate phenotype terms exist
  for (hpo in summary$phenotype_terms) {
    if (!hpo_exists_in_db(hpo)) {
      errors <- c(errors, paste("Unknown HPO term:", hpo))
    }
  }

  # Validate GO terms against actual enrichment
  for (go_term in summary$go_terms) {
    if (!go_term %in% cluster_data$enrichment$term) {
      errors <- c(errors, paste("GO term not in enrichment:", go_term))
    }
  }

  return(list(valid = length(errors) == 0, errors = errors))
}
```

**Phase to address:**
Phase 1 (Foundation) - Build content validation pipeline before any production use.

---

### Pitfall 4: LLM-as-Judge Agreement Only 64-68% with Domain Experts

**What goes wrong:**
Using an LLM to validate another LLM's output (LLM-as-judge) has poor reliability for domain-specific content. Research from IUI 2025 found that in specialized fields, experts agreed with LLM judges only 64% (mental health) to 68% (dietetics) of the time. For biomedical gene cluster summaries, agreement could be even lower due to the specialized vocabulary and nuanced claims.

**Why it happens:**
LLM-as-judge works well for general tasks (80% agreement on general instructions) but degrades on:
- Specialized terminology that has domain-specific meanings
- Claims requiring database lookup to verify
- Subtle scientific inaccuracies that appear plausible

The judge LLM has the same hallucination tendencies as the generator LLM, so both may agree on incorrect content.

**Consequences:**
- False sense of quality from automated validation
- Hallucinated content passes LLM review
- Resources wasted on unreliable validation
- Actual errors reach production

**Prevention:**
1. **Don't rely solely on LLM-as-judge:** Use it as one signal, not the decision
2. **Database grounding for judge:** Provide the judge with actual database records to verify against
3. **Rule-based validators first:** Check entity existence, claim support, format compliance with code
4. **Human review for edge cases:** Flag low-confidence validations for curator review
5. **Ensemble validation:** Combine LLM judge, rule-based checks, and confidence scoring

**Warning signs:**
- LLM judge approves summaries that human reviewers reject
- High judge scores don't correlate with actual quality
- Similar summaries get inconsistent judge scores (low reliability)

**Detection:**
```r
# Multi-layer validation (don't rely on LLM-as-judge alone)
validate_summary_multilayer <- function(summary, cluster_data) {
  results <- list()

  # Layer 1: Rule-based (highest confidence)
  results$rule_based <- validate_summary_content(summary, cluster_data)

  # Layer 2: Entity grounding
  results$entity_grounding <- validate_summary_genes(summary$text,
                                                      cluster_data$genes)

  # Layer 3: LLM-as-judge (lower confidence, supplementary)
  results$llm_judge <- call_llm_judge(summary, cluster_data)

  # Final decision: rule-based must pass, LLM judge is advisory
  final_valid <- results$rule_based$valid &&
                 length(results$entity_grounding) == 0

  # Flag for human review if LLM judge disagrees or low confidence
  needs_review <- (results$llm_judge$score < 0.8) ||
                  (!results$llm_judge$valid && final_valid)

  return(list(valid = final_valid, needs_review = needs_review,
              details = results))
}
```

**Phase to address:**
Phase 2 (Validation) - Implement multi-layer validation. Don't ship LLM-as-judge as sole validator.

---

### Pitfall 5: Cache Invalidation When Cluster Composition Changes

**What goes wrong:**
Summaries are generated and cached for clusters, but the underlying cluster data changes when:
- Database is updated with new gene-disease associations
- STRINGdb version changes (affecting clustering)
- Leiden algorithm parameters are tuned
- New entities are added to SysNDD

Cached summaries become stale - they describe the old cluster composition, not the current one.

**Consequences:**
- Users see summaries that don't match visible data
- Summary mentions genes no longer in cluster (or misses new ones)
- Trust erosion when inconsistencies are noticed
- Potentially harmful if old associations are relied upon

**Prevention:**
1. **Cache key includes data hash:** Generate hash of cluster gene list + enrichment terms + summary version
2. **Automatic invalidation:** When cluster data changes, mark summary as stale
3. **TTL with regeneration:** Set maximum age (e.g., 30 days) and regenerate proactively
4. **Version tracking:** Store summary_version, cluster_data_version, model_version
5. **On-demand regeneration:** Provide admin endpoint to regenerate specific cluster summaries

**Warning signs:**
- Summary mentions gene not in current cluster view
- Summary's gene count doesn't match actual cluster size
- Users report "summary doesn't match what I see"
- Old STRINGdb edges described but cluster uses new version

**Detection:**
```r
# Cache key generation with data hashing
generate_summary_cache_key <- function(cluster_id, cluster_data, model_version) {
  # Hash the actual data that the summary describes
  data_hash <- digest::digest(list(
    genes = sort(cluster_data$genes),
    enrichment = cluster_data$enrichment$term,
    phenotypes = cluster_data$phenotypes
  ), algo = "sha256")

  # Include model version and summary schema version
  key <- paste(
    "summary",
    cluster_id,
    substr(data_hash, 1, 16),
    model_version,
    "v1",  # Summary schema version
    sep = "_"
  )

  return(key)
}

# Staleness check
is_summary_stale <- function(cached_summary, current_cluster_data) {
  cached_key <- cached_summary$cache_key
  current_key <- generate_summary_cache_key(
    cached_summary$cluster_id,
    current_cluster_data,
    cached_summary$model_version
  )

  return(cached_key != current_key)
}
```

**Phase to address:**
Phase 1 (Foundation) - Build cache invalidation into the storage layer from the start.

---

### Pitfall 6: Gemini API Rate Limits Per-Project, Not Per-Key

**What goes wrong:**
Developers create multiple API keys expecting separate rate limits, but Gemini quotas are enforced at the Google Cloud Project level. All keys in a project share the same quota pool. When batch regeneration runs alongside user-triggered generation, they compete for the same quota, causing 429 errors.

**Why it happens:**
This is a documented Gemini API architecture decision that many developers miss. The 2026 rate limit documentation explicitly states: "Rate limits apply per project, not per API key. Creating multiple API keys within the same project won't multiply your limits."

For SysNDD's batch pre-generation use case, this means:
- Admin batch job uses same quota as potential user-triggered regenerations
- Multiple API servers share quota if using same project
- Cannot isolate batch processing from real-time requests with API keys alone

**Consequences:**
- Batch processing causes 429 errors for user requests
- Unpredictable rate limit errors during peak usage
- Batch jobs fail partway through when quota exhausted
- Retry storms when multiple processes hit limits simultaneously

**Prevention:**
1. **Separate GCP projects:** Use different projects for batch vs real-time (if budget allows)
2. **Batch processing during off-peak:** Schedule batch jobs when user traffic is minimal
3. **Rate limit awareness:** Implement client-side rate limiting below API limits
4. **Exponential backoff:** Handle 429s gracefully with proper retry logic
5. **Quota monitoring:** Track quota usage and alert before exhaustion
6. **Batch API usage:** Use Gemini's Batch API for 50% cost reduction and separate quota pool

**Warning signs:**
- Intermittent 429 errors during batch processing
- User-facing summary requests fail during scheduled regeneration
- Batch job completes fewer clusters than expected
- API usage spikes in GCP console don't correlate with expected traffic

**Detection:**
```r
# Implement client-side rate limiting
gemini_rate_limiter <- function() {
  # Track requests per minute
  request_times <- new.env()
  request_times$times <- numeric(0)

  function(wait_if_exceeded = TRUE) {
    now <- Sys.time()

    # Clear requests older than 60 seconds
    request_times$times <- request_times$times[
      request_times$times > now - 60
    ]

    # Check against limit (leave headroom below API limit)
    rpm_limit <- 100  # Conservative limit below Tier 1's 150-300 RPM

    if (length(request_times$times) >= rpm_limit) {
      if (wait_if_exceeded) {
        oldest <- min(request_times$times)
        wait_time <- as.numeric(oldest + 60 - now, units = "secs")
        if (wait_time > 0) {
          Sys.sleep(wait_time)
        }
      } else {
        stop("Rate limit exceeded, try again later")
      }
    }

    request_times$times <- c(request_times$times, now)
    return(TRUE)
  }
}
```

**Phase to address:**
Phase 1 (Foundation) - Implement rate limiting and batch scheduling from the start.

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or user confusion.

### Pitfall 7: Prompt Injection via Cluster Data

**What goes wrong:**
Cluster data (gene symbols, GO term descriptions, phenotype text) is inserted into prompts. Malicious or malformed data could contain instructions that override the system prompt, causing the LLM to generate incorrect summaries or leak information.

**Why it happens:**
While SysNDD data is curated, some fields come from external sources (HPO, GO ontologies, STRING). If these sources are compromised or contain unusual text, it could be interpreted as instructions. The 2025 JAMA Network Open study found that prompt injection attacks succeeded in 94.4% of trials in medical LLM contexts.

**Consequences:**
- Summaries contain unexpected content
- System prompt instructions ignored
- Potential data exfiltration (less relevant for batch processing)
- Model behavior becomes unpredictable

**Prevention:**
1. **Input sanitization:** Strip or escape special characters from data before prompt inclusion
2. **Structured data injection:** Use JSON format with explicit field markers
3. **Delimiter protection:** Use unique delimiters that won't appear in data
4. **Output validation:** Verify output stays within expected bounds

**Warning signs:**
- Summary contains text not related to cluster
- Summary ignores formatting instructions
- Unexpected content appears in specific clusters (investigate their data)

**Phase to address:**
Phase 1 (Foundation) - Sanitize inputs before prompt construction.

---

### Pitfall 8: Model Version Changes Break Generation

**What goes wrong:**
Google deprecates Gemini model versions (e.g., "Gemini 2.0 Flash will be retired on March 3, 2026"). Summaries generated by different model versions may have inconsistent quality, format, or content. When switching models, cached summaries don't match new generation style.

**Why it happens:**
LLM providers regularly update and retire models. Each version has different capabilities, biases, and output characteristics. The official Gemini documentation announces "Gemini 2.0 Flash and Flash-Lite models will be retired on March 3, 2026."

**Consequences:**
- Application breaks when deprecated model is removed
- Inconsistent summary quality across clusters
- Migration requires regenerating all cached summaries
- Testing against one version, deploying with another

**Prevention:**
1. **Pin model version explicitly:** Use `gemini-2.5-flash` not `gemini-flash-latest`
2. **Monitor deprecation notices:** Track Google's model retirement announcements
3. **Version in cache key:** Include model version in summary metadata
4. **Batch regeneration on upgrade:** Plan for regenerating all summaries when switching models
5. **A/B testing before migration:** Compare new model output quality before full switch

**Warning signs:**
- Warnings in API response about upcoming deprecation
- Sudden quality changes in new summaries
- Inconsistent formatting between old and new summaries

**Phase to address:**
Phase 1 (Foundation) - Pin model version, track in metadata. Phase 3 (Production) - Monitor deprecation, plan migrations.

---

### Pitfall 9: Cost Estimation Errors for Batch Processing

**What goes wrong:**
Initial cost estimates for batch summary generation are significantly off because:
- Token counts underestimated (cluster context + enrichment is large)
- Retry costs not included (transient failures, validation failures requiring regeneration)
- Output tokens cost 2.5-10x more than input tokens (Gemini 2.5 pricing)
- Long context (>200K tokens) costs 2x for Pro models

**Why it happens:**
Developers estimate based on input size but underestimate context size and output costs. A cluster with 50 genes, GO enrichment (20+ terms), and phenotype data can easily exceed 2000 input tokens. Output summaries of 300-500 words add significant output token costs.

For SysNDD with ~50 clusters at top level and subclusters, costs can multiply unexpectedly.

**Consequences:**
- Budget overruns
- Batch processing halted mid-way
- Reduced generation frequency to stay within budget
- Pressure to reduce quality (shorter prompts, less context)

**Prevention:**
1. **Token counting before generation:** Estimate costs before batch run
2. **Pilot with sample clusters:** Generate 10% of clusters, extrapolate cost
3. **Use Batch API:** 50% cost reduction for non-real-time workloads
4. **Context caching:** Reuse common context (system prompt, schema) for 75% savings
5. **Budget alerts:** Set GCP budget alerts at 50%, 80%, 100% of expected cost
6. **Tiered quality:** Use cheaper models (Flash-Lite) for initial drafts, Pro for final

**Warning signs:**
- Actual costs 2-5x higher than estimated
- Batch job reaches budget limit before completion
- Token usage metrics much higher than expected
- Many retries increasing total cost

**Detection:**
```r
# Pre-generation cost estimation
estimate_batch_cost <- function(clusters, model = "gemini-2.5-flash") {
  # Pricing per 1M tokens (January 2026)
  pricing <- list(
    "gemini-2.5-flash" = list(input = 0.30, output = 2.50),
    "gemini-2.5-flash-lite" = list(input = 0.10, output = 0.40),
    "gemini-2.5-pro" = list(input = 1.25, output = 10.00)
  )

  total_input_tokens <- 0
  total_output_tokens <- 0

  for (cluster in clusters) {
    # Estimate tokens
    system_prompt_tokens <- 500  # Base system prompt
    context_tokens <- length(cluster$genes) * 10 +  # Gene symbols
                      nrow(cluster$enrichment) * 50 +  # GO terms
                      length(cluster$phenotypes) * 30  # HPO terms
    output_tokens <- 400  # Target summary length

    total_input_tokens <- total_input_tokens + system_prompt_tokens + context_tokens
    total_output_tokens <- total_output_tokens + output_tokens
  }

  # Add retry overhead (assume 10% retries)
  total_input_tokens <- total_input_tokens * 1.1
  total_output_tokens <- total_output_tokens * 1.1

  # Calculate cost
  cost <- (total_input_tokens / 1e6 * pricing[[model]]$input) +
          (total_output_tokens / 1e6 * pricing[[model]]$output)

  return(list(
    input_tokens = total_input_tokens,
    output_tokens = total_output_tokens,
    estimated_cost_usd = round(cost, 4),
    model = model
  ))
}
```

**Phase to address:**
Phase 1 (Foundation) - Cost estimation and budgeting before any batch processing.

---

### Pitfall 10: Batch Job Failures Leave Partial Results

**What goes wrong:**
A batch job generating summaries for 50 clusters fails after completing 35 (due to API error, rate limit, or timeout). The job leaves:
- 35 clusters with new summaries
- 15 clusters with old/no summaries
- No record of which clusters failed
- Inconsistent state in the database

**Why it happens:**
Batch processing without proper checkpointing and error handling. Single failure causes entire batch to abort without cleanup. No idempotent restart mechanism.

**Consequences:**
- Inconsistent user experience (some clusters have summaries, others don't)
- Manual intervention needed to identify and regenerate failed clusters
- Repeated full-batch runs waste resources on already-complete clusters
- State confusion between cache and database

**Prevention:**
1. **Per-cluster status tracking:** Record pending/completed/failed status for each cluster
2. **Checkpointing:** Save progress after each successful generation
3. **Idempotent restart:** Job can resume from last checkpoint
4. **Separate success/failure handling:** Commit successful summaries even if batch fails
5. **Batch status API:** Provide endpoint to check batch progress and failed items
6. **Automatic retry queue:** Failed clusters queued for retry with backoff

**Warning signs:**
- Batch job logs show partial completion but no summary
- Some clusters show summaries while others don't
- Manual queries needed to find incomplete clusters
- Batch runs take full time even when most are complete

**Detection:**
```r
# Batch job with checkpointing
run_batch_summary_generation <- function(cluster_ids) {
  # Track status per cluster
  status <- data.frame(
    cluster_id = cluster_ids,
    status = "pending",
    attempt = 0,
    error = NA_character_,
    completed_at = as.POSIXct(NA)
  )

  for (i in seq_along(cluster_ids)) {
    cluster_id <- cluster_ids[i]

    tryCatch({
      # Generate summary
      summary <- generate_cluster_summary(cluster_id)

      # Save to database
      save_summary(cluster_id, summary)

      # Update status
      status$status[i] <- "completed"
      status$completed_at[i] <- Sys.time()

      # Checkpoint progress
      saveRDS(status, "batch_progress.rds")

    }, error = function(e) {
      status$status[i] <<- "failed"
      status$attempt[i] <<- status$attempt[i] + 1
      status$error[i] <<- conditionMessage(e)

      # Checkpoint even on failure
      saveRDS(status, "batch_progress.rds")
    })
  }

  return(status)
}

# Resume from checkpoint
resume_batch <- function() {
  if (file.exists("batch_progress.rds")) {
    status <- readRDS("batch_progress.rds")
    remaining <- status$cluster_id[status$status != "completed"]
    run_batch_summary_generation(remaining)
  }
}
```

**Phase to address:**
Phase 2 (Validation) - Build robust batch processing with checkpointing.

---

## Minor Pitfalls

Issues that cause annoyance but are easily fixable.

### Pitfall 11: Summary Length Inconsistency

**What goes wrong:**
Different clusters get summaries of vastly different lengths - some 50 words, others 500 words - creating inconsistent user experience.

**Prevention:**
- Specify exact word count ranges in prompt
- Post-process to truncate or flag outliers
- Use `max_output_tokens` parameter

**Phase to address:** Phase 1 (Foundation)

---

### Pitfall 12: Environment Variable Exposure in Logs

**What goes wrong:**
The Gemini API key stored in environment variable gets logged during debugging, appearing in CI logs or error reports.

**Prevention:**
- Use secrets management (Docker secrets, GCP Secret Manager)
- Sanitize API keys from all log output
- Never log full request/response including auth headers

**Phase to address:** Phase 1 (Foundation)

---

### Pitfall 13: Missing Retry Logic for Transient Errors

**What goes wrong:**
Single 503 or 429 response causes generation to fail without retry, leaving gaps in batch processing.

**Prevention:**
- Implement exponential backoff (already done in `external-proxy-functions.R` - follow this pattern)
- Distinguish transient vs permanent errors
- Set appropriate retry limits (5 attempts over 120 seconds)

**Phase to address:** Phase 1 (Foundation)

---

### Pitfall 14: UI Shows Stale Summary While Regeneration Pending

**What goes wrong:**
Admin triggers regeneration, but UI shows old summary until new one is ready. Users see outdated content during the generation window.

**Prevention:**
- Show "Regenerating..." status during processing
- Implement optimistic UI updates
- Clear cache atomically (read old until new is ready)

**Phase to address:** Phase 3 (Production)

---

## Phase-Specific Warnings Summary

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Phase 1: Foundation | Hallucinated gene names (#1) | Build entity validation into pipeline from day one |
| Phase 1: Foundation | Structured output trust (#3) | Implement content validation layer separate from schema |
| Phase 1: Foundation | Rate limits per-project (#6) | Design for shared quota, implement client-side limits |
| Phase 2: Validation | LLM-as-judge unreliability (#4) | Multi-layer validation with rule-based as primary |
| Phase 2: Validation | Batch job failures (#10) | Per-cluster status tracking and checkpointing |
| Phase 3: Production | Cache staleness (#5) | Hash-based invalidation with data versioning |
| Phase 3: Production | Model deprecation (#8) | Pin versions, monitor announcements, plan migrations |

---

## SysNDD-Specific Integration Concerns

### Integration with Existing Analysis Pipeline

The current `gen_string_clust_obj` function in `analyses-functions.R` returns:
- `identifiers` (gene symbols, hgnc_ids)
- `term_enrichment` (GO terms with p-values, FDR)
- `cluster_size`
- `hash_filter`

Summary generation should consume this exact structure without modification. Create a new function `generate_cluster_summary()` that takes the cluster tibble as input.

### Integration with Existing Cache Pattern

Follow the existing `cachem::cache_disk` pattern in `external-proxy-functions.R`:
- Use `cache_static` tier (30-day TTL) for summaries
- Include data hash in cache key (not just cluster ID)
- Store model version in cached summary metadata

### Integration with Job Manager

For admin batch processing, use the existing `mirai`-based job manager pattern from `job-manager.R`:
- Submit batch as async job
- Track progress via job status endpoint
- Handle timeouts and failures gracefully

### Database Considerations

Consider storing summaries in a new table rather than just cache:
- `cluster_summaries` table with columns: cluster_hash, summary_text, model_version, generated_at, data_version
- Enables querying which summaries need regeneration
- Provides audit trail of summary history
- Survives cache clears

---

## Sources

**Biomedical LLM Hallucinations:**
- [Mitigating LLM Hallucinations - BioStrand](https://blog.biostrand.ai/mitigating-llm-hallucinations)
- [Medical Hallucination in Foundation Models - medRxiv](https://www.medrxiv.org/content/10.1101/2025.02.28.25323115v2.full.pdf)
- [Grounded but Misguided: Mitigating Hallucinations in Clinical LLMs](https://sonishsivarajkumar.medium.com/grounded-but-misguided-mitigating-hallucinations-in-clinical-llms-and-rag-systems-using-electronic-af0bf936d304)
- [IEEE JBHI - Mitigating Hallucinations in LLMs for Healthcare](https://www.embs.org/jbhi/wp-content/uploads/sites/18/2025/11/Mitigating-Hallucinations-in-Large-Language-Models-for-Healthcare-Towards-Trustworthy-Medical-AI.pdf)
- [Automated Identification of Biomedical Entities with Grounded LLMs - Nature Scientific Reports](https://www.nature.com/articles/s41598-026-35492-8)

**Gemini API Structured Output:**
- [Google Gemini API Structured Outputs Announcement](https://blog.google/technology/developers/gemini-api-structured-outputs/)
- [Structured Output Documentation - Google AI](https://ai.google.dev/gemini-api/docs/structured-output)
- [Generate Structured Output - Firebase AI Logic](https://firebase.google.com/docs/ai-logic/generate-structured-output)

**LLM-as-Judge Reliability:**
- [Can You Trust LLM Judgments? - arXiv](https://arxiv.org/abs/2412.12509)
- [LLM-as-a-Judge: 2026 Guide - Label Your Data](https://labelyourdata.com/articles/llm-as-a-judge)
- [Limitations of LLM-as-a-Judge in Expert Knowledge Tasks - ACM IUI 2025](https://dl.acm.org/doi/10.1145/3708359.3712091)

**Rate Limits and Costs:**
- [Gemini API Rate Limits - Google AI](https://ai.google.dev/gemini-api/docs/rate-limits)
- [Gemini API Pricing 2026 - MetaCTO](https://www.metacto.com/blogs/the-true-cost-of-google-gemini-a-guide-to-api-pricing-and-integration)
- [Gemini API Pricing Calculator - CostGoat](https://costgoat.com/pricing/gemini-api)

**Prompt Injection Security:**
- [Prompt Injection in Medical LLMs - JAMA Network Open](https://jamanetwork.com/journals/jamanetworkopen/fullarticle/2842987)
- [LLM Security Risks 2026 - Sombra Inc](https://sombrainc.com/blog/llm-security-risks-2026)
- [OWASP Top 10 for LLM Applications - Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)

**Caching Strategies:**
- [Semantic Caching - VentureBeat](https://venturebeat.com/orchestration/why-your-llm-bill-is-exploding-and-how-semantic-caching-can-cut-it-by-73)
- [Cache the Prompt, Not the Response - Amit Kothari](https://amitkoth.com/llm-caching-strategies/)
- [LLM Caching Strategies - Reintech](https://reintech.io/blog/how-to-implement-llm-caching-strategies-for-faster-response-times)

---

*Pitfalls research for SysNDD v10.0 LLM Cluster Summaries: 2026-01-31*
