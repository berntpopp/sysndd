# Phase 58 Plan 02: Entity Validation Pipeline Summary

**Completed:** 2026-01-31
**Duration:** ~12 minutes

---

## One-liner

Strict entity validation pipeline ensuring all gene symbols in LLM output exist in HGNC database before storage.

---

## What Was Built

### Validation Functions (llm-validation.R)

Entity validation pipeline with strict rejection policy:

| Function | Purpose |
|----------|---------|
| `extract_gene_symbols()` | Extracts HGNC-style symbols from free text using regex |
| `validate_gene_symbols()` | Validates symbols against `non_alt_loci_set` table |
| `validate_pathways()` | Validates pathways against enrichment input terms |
| `validate_summary_entities()` | Comprehensive validation aggregating gene + pathway checks |

**Key Design Decisions:**

1. **STRICT mode**: Any invalid gene symbol causes entire summary rejection
2. **Common word filtering**: Excludes DNA, RNA, ATP, HPO, OMIM, KEGG, etc.
3. **Case-insensitive pathway matching**: "oxidative phosphorylation" matches "Oxidative Phosphorylation"
4. **Human-readable errors**: Error messages explain which genes/pathways failed and why

### LLM Service Integration

Updated `generate_cluster_summary()` with validation loop:

```r
while (retries < max_retries) {
  result <- chat$chat_structured(prompt, type_spec)
  validation <- validate_summary_entities(result, cluster_data)

  if (validation$is_valid) {
    log_generation_attempt(..., status = "success")
    return(...)
  }

  log_generation_attempt(..., status = "validation_failed",
                        validation_errors = validation$errors)
  retries <- retries + 1
}
```

### Derived Confidence Calculation

New `calculate_derived_confidence()` function provides objective confidence score:

- **high**: avg_fdr < 1e-10 AND significant_terms > 20
- **medium**: avg_fdr < 1e-5 AND significant_terms > 10
- **low**: otherwise

This supplements the LLM's self-assessed confidence with data-driven metrics.

### Cache Repository Update

Updated `save_summary_to_cache()` to accept `validation_status` parameter:
- Rejected summaries saved with `validation_status = 'rejected'`
- Enables tracking of failed generation attempts for analysis

---

## Unit Tests (23 test cases)

### extract_gene_symbols() Tests (7 tests)
- Extracts HGNC-style symbols (BRCA1, TP53, C9orf72)
- Filters common abbreviations (DNA, RNA, ATP)
- Handles empty/NULL text
- Returns unique symbols
- Excludes database abbreviations (HPO, OMIM, KEGG)

### validate_gene_symbols() Tests (4 tests)
- Valid structure for empty/NULL input
- Validates real genes against database
- Detects invalid symbols (FAKEGENE123)
- Strict mode - any invalid causes failure

### validate_pathways() Tests (6 tests)
- Valid structure for empty/NULL pathways
- Validates pathways in enrichment terms
- Detects invalid pathways
- Case-insensitive matching
- Handles empty/NULL enrichment_terms

### validate_summary_entities() Tests (6 tests)
- Validates valid summary content
- Detects invalid gene symbols
- Detects invalid pathways
- Returns human-readable errors
- Handles missing term_enrichment
- Handles NULL summary

---

## Files Changed

| File | Action | Purpose |
|------|--------|---------|
| `api/functions/llm-validation.R` | Created | Entity validation functions |
| `api/functions/llm-service.R` | Modified | Integrated validation into generation |
| `api/functions/llm-cache-repository.R` | Modified | Added validation_status parameter |
| `api/tests/testthat/test-llm-validation.R` | Created | 23 unit tests for validation |

---

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 2c2f3b34 | feat | Add entity validation functions for LLM summaries |
| 0c33beb1 | feat | Integrate entity validation into LLM service |
| a480694b | test | Add unit tests for LLM validation functions |

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Verification Results

1. **Functions exist and export correctly:** PASS
   - validate_summary_entities, validate_gene_symbols, validate_pathways, extract_gene_symbols all exported

2. **Validation integrated into LLM service:** PASS
   - grep confirms validate_summary_entities called in generate_cluster_summary()
   - grep confirms validation_failed status logged

3. **Derived confidence calculation added:** PASS
   - calculate_derived_confidence() returns high/medium/low based on FDR analysis

4. **Unit tests created:** PASS
   - 23 test cases covering all validation functions
   - Database-dependent tests use skip_if pattern

---

## Key Links Verified

| From | To | Via | Status |
|------|-----|-----|--------|
| llm-validation.R | non_alt_loci_set table | db_execute_query | VERIFIED |
| llm-service.R | llm-validation.R | validate_summary_entities call | VERIFIED |
| llm-validation.R | llm-cache-repository.R | log_generation_attempt for failures | VERIFIED |

---

## Success Criteria Met

1. **validate_gene_symbols correctly identifies valid/invalid HGNC symbols:** YES
   - Queries non_alt_loci_set table for validation

2. **validate_pathways correctly checks pathways against enrichment input:** YES
   - Case-insensitive matching implemented

3. **validate_summary_entities aggregates both validations:** YES
   - Returns is_valid, mentioned_genes, invalid_genes, mentioned_pathways, invalid_pathways, errors

4. **generate_cluster_summary retries on validation failure:** YES
   - Up to max_retries (default 3) before marking as failed

5. **Validation failures logged with status = "validation_failed":** YES
   - log_generation_attempt called with detailed errors

6. **Unit tests cover extraction, gene validation, pathway validation, and integration:** YES
   - 23 test cases total

7. **All gene symbols in stored summaries guaranteed to exist in non_alt_loci_set:** YES
   - STRICT mode rejects summaries with any invalid gene

---

## Next Phase Readiness

**Phase 58 Complete:**
- Plan 01: LLM Infrastructure (Gemini client, cache tables)
- Plan 02: Entity Validation (validation pipeline)

**Ready for Phase 59 (LLM Batch & Caching):**
- Validation pipeline operational
- Cache infrastructure with validation_status tracking
- Logging captures all attempts for analysis
- Failed summaries saved as 'rejected' for debugging
