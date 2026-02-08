# Architecture Patterns: OMIM Genemap2 Integration

**Domain:** OMIM data processing for ontology and comparisons systems  
**Researched:** 2026-02-07  
**Confidence:** HIGH (based on direct code analysis)

## Executive Summary

The unified genemap2.txt architecture consolidates two currently divergent OMIM data flows:

1. **ONTOLOGY system**: Currently uses mim2gene.txt + JAX API
2. **COMPARISONS system**: Already uses genemap2.txt with HPO filtering

By migrating the ontology system to genemap2.txt, both systems will share common download/parsing infrastructure, unified OMIM download key management, consistent file caching (1-day TTL), and reduced API dependencies (eliminates JAX API). The integration maintains existing component boundaries while introducing shared infrastructure at the data layer.

## Current Architecture (As-Is)

### Ontology System (mim2gene.txt + JAX API)

**Data Flow:**
1. download_mim2gene() downloads data/mim2gene.YYYY-MM-DD.txt from https://omim.org/static/omim/data/mim2gene.txt with 1-month cache
2. parse_mim2gene() filters phenotype entries with gene_symbol, includes moved/removed for deprecation tracking
3. fetch_all_disease_names() calls JAX API (50ms delay, approximately 7 minutes for 8500 entries) at https://ontology.jax.org/api/network/annotation/OMIM:{mim}
4. build_omim_ontology_set() creates disease_ontology_set schema with HGNC matching via hgnc_list lookup and versioning for duplicate MIM numbers (OMIM:123456_1, _2, etc.) but has NO MOI information (mim2gene.txt lacks this)
5. apply MONDO SSSOM mappings adds mondo_equivalent column
6. Database insert performs TRUNCATE + INSERT on disease_ontology_set table

**Components:**
- api/functions/omim-functions.R (mim2gene logic)
- api/functions/mondo-functions.R (SSSOM mapping)
- api/functions/ontology-functions.R (orchestrator)
- api/endpoints/admin_endpoints.R:update_ontology_async

### Comparisons System (genemap2.txt)

**Data Flow:**
1. download_source_data() downloads genemap2.txt (with download key) from https://data.omim.org/downloads/{KEY}/genemap2.txt stored in comparisons_config table, downloaded to temp_dir during async job
2. parse_omim_genemap2() requires phenotype.hpoa (HPO annotations), filters HPO terms under HP:0012759 (Neurodevelopmental abnormality), parses Phenotypes column into disease_ontology_name, MIM_Number, MOI, has MOI information (genemap2.txt includes inheritance)
3. standardize_comparison_data() normalizes to ndd_database_comparison schema
4. resolve_hgnc_symbols() performs batch lookup with temp table JOIN (optimized) via hgnc_symbol_lookup table
5. Database merge performs DELETE + INSERT in transaction on ndd_database_comparison table

**Components:**
- api/functions/comparisons-functions.R (parse_omim_genemap2)
- api/functions/comparisons-sources.R (config management)
- db/migrations/007_comparisons_config.sql (source URLs)

### Key Differences

| Aspect | Ontology (mim2gene) | Comparisons (genemap2) |
|--------|---------------------|------------------------|
| Data source | mim2gene.txt (public) | genemap2.txt (download key required) |
| Disease names | JAX API (slow, 7 minutes) | Parsed from genemap2 Phenotypes column |
| MOI information | NO | YES (from genemap2 inheritance) |
| Gene associations | Limited (phenotype entries often lack genes) | Comprehensive (gene-centric file) |
| HPO filtering | NO | YES (NDD-specific terms) |
| Cache location | data/mim2gene.YYYY-MM-DD.txt | temp_dir (ephemeral) |
| Versioning | OMIM:123456_1, _2 for duplicates | No versioning |

## Recommended Architecture (To-Be)

### Unified Genemap2 Data Layer

**New Component: api/functions/genemap2-functions.R**

Core genemap2.txt download/parse shared by both systems:
- download_genemap2_with_key() returns data/omim_genemap2.YYYY-MM-DD.txt using check_file_age() and get_newest_file() with key from Sys.getenv("OMIM_DOWNLOAD_KEY") or database fallback
- parse_genemap2() returns tibble with ALL genemap2 columns: Chromosome, Genomic_Position_Start, Genomic_Position_End, Cyto_Location, MIM_Number, Gene_Symbols, Gene_Name, Approved_Symbol, Entrez_Gene_ID, Ensembl_Gene_ID, Comments, Phenotypes, Mouse_Gene_Symbol_ID
- Parsing separates Phenotypes column into disease_name, MIM, inheritance

**Modified: api/functions/omim-functions.R**

REMOVE: download_mim2gene(), parse_mim2gene(), fetch_jax_disease_name(), fetch_all_disease_names()

KEEP: validate_omim_data(), get_deprecated_mim_numbers() (adapt to genemap2 format), check_entities_for_deprecation()

ADD: build_omim_ontology_set_from_genemap2() maps genemap2 inheritance to hpo_mode_of_inheritance_term, creates disease_ontology_id_version with same versioning logic, handles same OMIM ID with different genes/inheritance

**Modified: api/functions/ontology-functions.R**

Rewrite process_omim_ontology() to:
1. Call download_genemap2_with_key()
2. Call parse_genemap2()
3. Call build_omim_ontology_set_from_genemap2()
4. Apply MONDO SSSOM mappings (unchanged)
REMOVE: Progress callbacks for JAX API (no longer needed)

**Modified: api/functions/comparisons-functions.R**

Rewrite parse_omim_genemap2() to call shared parse_genemap2() OR duplicate logic if coupling undesired. KEEP: HPO phenotype.hpoa requirement for filtering.

### Configuration Management

**Option C: Hybrid (Selected)**
- Use OMIM_DOWNLOAD_KEY environment variable for production (secure)
- Fallback to database for local dev/admin override
- Third fallback: Check omim_links.txt for backward compatibility

**Access Function:**
```r
get_omim_download_key <- function(pool = NULL) {
  # First: Check environment variable
  key <- Sys.getenv("OMIM_DOWNLOAD_KEY")
  if (key != "") return(key)
  
  # Second: Check database config (if pool provided)
  if (!is.null(pool)) {
    result <- db_execute_query(
      "SELECT config_value FROM omim_config WHERE config_key = 'download_key'",
      conn = pool
    )
    if (nrow(result) > 0) return(result$config_value[1])
  }
  
  # Third: Check omim_links.txt for backward compatibility
  links_file <- "data/omim_links/omim_links.txt"
  if (file.exists(links_file)) {
    lines <- readLines(links_file)
    genemap2_line <- lines[grepl("genemap2.txt", lines)]
    if (length(genemap2_line) > 0) {
      key_match <- regmatches(genemap2_line, regexpr("[A-Za-z0-9_-]{22}", genemap2_line))
      if (length(key_match) > 0) return(key_match[1])
    }
  }
  
  stop("OMIM download key not found. Set OMIM_DOWNLOAD_KEY env var or database config.")
}
```

### Data Flow Changes

**Ontology System (New):**

1. download_genemap2_with_key() downloads to data/omim_genemap2.YYYY-MM-DD.txt with 1-day TTL via check_file_age
2. parse_genemap2() returns full genemap2 dataset with all columns including Phenotypes, Approved_Symbol, inheritance
3. build_omim_ontology_set_from_genemap2() parses Phenotypes column format "{disease}, {MIM}), {inheritance}", maps inheritance to hpo_mode_of_inheritance_term, performs HGNC matching via Approved_Symbol to hgnc_list, applies versioning (same as current OMIM:123456_1 for duplicates), now HAS MOI information from genemap2 inheritance column
4. apply MONDO SSSOM mappings adds mondo_equivalent (UNCHANGED)
5. Database insert to disease_ontology_set table (UNCHANGED)

**Performance:** ELIMINATES JAX API fetching (approximately 7 minutes for 8500 entries), GAINS immediate disease names from genemap2.txt, Total time approximately 30 seconds (was approximately 8 minutes)

**Comparisons System (Minimal Changes):**

Option 1: Keep download_source_data() UNCHANGED (still downloads to temp_dir)  
Option 2: Call shared download_genemap2_with_key() if cache sharing desired

Refactor parse_omim_genemap2() to use shared parse_genemap2() OR keep duplicate parsing if coupling undesired. HPO filtering remains UNCHANGED.

### Caching Strategy

**Shared Cache (Recommended):**
```
data/
  omim_genemap2.YYYY-MM-DD.txt     # Shared by both systems
  mondo-omim.YYYY-MM-DD.sssom.tsv  # MONDO mappings (unchanged)
  disease_ontology_set.YYYY-MM-DD.csv  # Combined output cache
```

**Benefits:** Single download per day regardless of which system runs first, consistent data version across ontology and comparisons, reduces OMIM server load, 1-day TTL aligns with daily update frequency

**Implementation:** In comparisons-functions.R, if source_name equals "omim_genemap2", use shared download_genemap2_with_key(output_path = "data/", force = FALSE, max_age_months = 1) instead of ephemeral temp download.

### Database Migration Needs

**No schema changes required** for core integration. Existing tables handle new data flow:

1. disease_ontology_set: Already has all needed columns, hpo_mode_of_inheritance_term column now populated (was NA for mim2gene), no migration needed
2. ndd_database_comparison: Unchanged schema, already receives genemap2 data
3. comparisons_config: Already has omim_genemap2 row, may need URL update if download key changes, migration 007 already exists

**Optional Enhancement: OMIM Config Table** (only if choosing database storage for download key)

## Build Order Recommendation

### Phase 1: Shared Infrastructure (Foundation)
**Goal:** Create reusable genemap2 download/parse without touching existing systems

**Tasks:**
1. Create api/functions/genemap2-functions.R with get_omim_download_key(), download_genemap2_with_key(), parse_genemap2()
2. Add tests for new functions: test-genemap2-download.R, test-genemap2-parse.R
3. Optional: Database migration for omim_config table (only if storing key in database)

**Deliverables:** Working shared infrastructure, no impact on existing systems (new code only), tests passing

**Risk:** LOW (additive only, no modifications)

### Phase 2: Ontology System Migration (Primary Goal)
**Goal:** Replace mim2gene + JAX API with genemap2 in ontology system

**Tasks:**
1. Create build_omim_ontology_set_from_genemap2() in omim-functions.R: parse Phenotypes column, map inheritance terms to HPO MOI, implement versioning logic, HGNC matching
2. Rewrite process_omim_ontology() in ontology-functions.R: call shared download_genemap2_with_key(), call build_omim_ontology_set_from_genemap2(), remove JAX API logic, keep MONDO SSSOM application
3. Update update_ontology_async endpoint: remove JAX API progress tracking, update progress messages
4. Deprecate old functions (don't delete yet): comment out download_mim2gene, parse_mim2gene, fetch_*_disease_name, keep temporarily for rollback option
5. Add tests: test-ontology-genemap2-integration.R, compare output schema with existing (ensure compatibility)

**Deliverables:** Ontology system using genemap2, performance improvement (8 min to 30 sec), MOI data now populated, backward-compatible database schema

**Risk:** MEDIUM (modifies critical path, but good rollback with old code commented)

### Phase 3: Comparisons System Integration (Optional Optimization)
**Goal:** Unify comparisons to use shared cache, eliminate duplicate parsing

**Tasks:**
1. Modify download_source_data() in comparisons-functions.R: special case for omim_genemap2 to use shared download_genemap2_with_key(), return cached file path instead of temp download
2. Refactor parse_omim_genemap2() in comparisons-functions.R: call shared parse_genemap2(), apply HPO filtering on top of shared parsed data, keep existing standardization logic
3. Update tests: test-comparisons-omim-integration.R

**Deliverables:** Single genemap2 download per day (shared cache), consistent data version across systems, reduced code duplication

**Risk:** LOW (comparisons system already uses genemap2, just consolidating infrastructure)

### Phase 4: Cleanup (Maintenance)
**Goal:** Remove deprecated code, update documentation

**Tasks:**
1. Delete deprecated functions from omim-functions.R: download_mim2gene, parse_mim2gene, fetch_jax_*
2. Remove mim2gene references from omim_links.txt
3. Update CLAUDE.md with new architecture: document genemap2 pattern, note download key requirement
4. Update API documentation: update endpoint descriptions, note performance improvement

**Deliverables:** Clean codebase, updated documentation, no legacy code

**Risk:** MINIMAL (cleanup only)

## Critical Integration Points

### 1. Progress Reporting (Async Jobs)

**Current (Ontology):** 4 steps (Download mim2gene, Fetch disease names 7 MINUTES, Build ontology set, Apply MONDO mappings)

**New (Ontology):** 3 steps (Download genemap2, Build ontology set FAST, Apply MONDO mappings)

**Impact:** Frontend expects 4 steps. Change to 3 steps or keep 4 with dummy step for UI compatibility. Recommendation: Change to 3, simpler is better.

### 2. HGNC Resolution

**Ontology:** Uses Approved_Symbol from genemap2 with left_join(hgnc_list)  
**Comparisons:** Uses resolve_hgnc_symbols() with hgnc_symbol_lookup table

**Decision:** Keep separate approaches. Ontology has pre-loaded hgnc_list (in memory), comparisons has database connection for batch lookup. No need to unify.

### 3. Deprecation Tracking

**Current:** get_deprecated_mim_numbers() reads mim2gene "moved/removed" entries

**New:** Genemap2.txt doesn't have explicit moved/removed flag. Options:
1. Keep mim2gene download for deprecation checking only
2. Infer deprecation from missing MIM numbers in genemap2 vs. previous version
3. Remove deprecation tracking (defer to Phase N)

**Recommendation:** Phase 2 removes deprecation tracking temporarily. Add back in Phase 4 with diff-based approach.

### 4. MOI (Mode of Inheritance) Mapping

**Challenge:** Genemap2 uses free text inheritance, need mapping to HPO terms

**Mapping Table (from comparisons-functions.R):**
- "Autosomal dominant" maps to "Autosomal dominant inheritance"
- "Autosomal recessive" maps to "Autosomal recessive inheritance"
- "Digenic dominant" maps to "Digenic inheritance"
- "Digenic recessive" maps to "Digenic inheritance"
- "Isolated cases" maps to "Sporadic"
- "Mitochondrial" maps to "Mitochondrial inheritance"
- "Multifactorial" maps to "Multifactorial inheritance"
- "Pseudoautosomal dominant" maps to "X-linked dominant inheritance"
- "Pseudoautosomal recessive" maps to "X-linked recessive inheritance"
- "Somatic mosaicism" maps to "Somatic mosaicism"
- "Somatic mutation" maps to "Somatic mutation"
- "X-linked" maps to "X-linked inheritance"
- "X-linked dominant" maps to "X-linked dominant inheritance"
- "X-linked recessive" maps to "X-linked recessive inheritance"
- "Y-linked" maps to "Y-linked inheritance"

**Implementation:** Reuse this mapping in build_omim_ontology_set_from_genemap2()

### 5. Phenotypes Column Parsing

**Format:** `{disease_name}, {MIM_NUMBER}), {inheritance1}, {inheritance2}; {next_phenotype}...`

**Parsing Logic (from comparisons-functions.R lines 430-445):**
```r
separate_rows(Phenotypes, sep = "; ") %>%
separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
         "\\), (?!.+\\))", fill = "right") %>%
separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"),
         "\\((?!.+\\()", fill = "right") %>%
separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"),
         ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])", fill = "right") %>%
separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ")
```

**Reusable:** Extract to shared function in genemap2-functions.R: parse_phenotypes_column()

## Anti-Patterns to Avoid

### 1. Tight Coupling via Shared Parse Function

**Bad:** comparisons-functions.R directly calls parse_genemap2() creating tight coupling

**Why bad:** Changes to shared parse_genemap2() could break comparisons

**Recommendation:** Option A for Phase 2 (keep comparisons parsing isolated). Unify in Phase 3 if desired.

### 2. Cache Inconsistency

**Bad:** ontology using data/omim_genemap2.YYYY-MM-DD.txt (1-day cache) while comparisons using temp_dir/omim_genemap2.txt (ephemeral)

**Why bad:** Systems see different genemap2 versions on same day

**Good:** Both systems using download_genemap2_with_key(output_path = "data/", max_age_months = 1) for single source of truth

### 3. Download Key Hardcoding

**Bad:** url equals "https://data.omim.org/downloads/9GJLEFvqSmWaImCijeRdVA/genemap2.txt"

**Why bad:** Key rotation requires code change

**Good:** key equals get_omim_download_key(), url equals sprintf("https://data.omim.org/downloads/%s/genemap2.txt", key)

### 4. Progress Callback in Shared Functions

**Bad:** download_genemap2_with_key() accepting progress_callback parameter

**Why bad:** Shared function now coupled to async job system

**Good:** Shared function has no progress reporting (pure data function). Caller handles progress.

## Testing Strategy

### Unit Tests

**genemap2-functions.R:**
- test_download_genemap2_cache_hit() verifies check_file_age prevents re-download
- test_download_genemap2_cache_miss() verifies download when file old
- test_parse_genemap2_structure() verifies all columns present
- test_parse_phenotypes_column() verifies regex parsing correctness
- test_get_omim_download_key_env() verifies env var takes precedence
- test_get_omim_download_key_fallback() verifies database fallback works

**omim-functions.R:**
- test_build_omim_ontology_set_from_genemap2() verifies schema matches expected
- test_inheritance_mapping() verifies all genemap2 MOI terms mapped
- test_versioning_logic() verifies duplicate MIM numbers get _1, _2

**ontology-functions.R:**
- test_process_omim_ontology_integration() verifies end-to-end ontology flow
- test_ontology_output_schema_compatibility() verifies output matches old schema

### Integration Tests

**database-integration.R:**
- test_ontology_update_transaction() verifies TRUNCATE + INSERT atomicity
- test_hgnc_resolution() verifies gene symbols resolve correctly

### Performance Tests

**benchmarks.R:**
- benchmark_ontology_update_time() should be less than 60 seconds (vs 8 minutes)
- benchmark_cache_vs_download() cached should be less than 1 second

## Rollback Plan

### If Phase 2 Fails in Production

**Immediate:**
1. Revert api/functions/ontology-functions.R to previous version
2. Uncomment old mim2gene functions in api/functions/omim-functions.R
3. Restart API containers

**Time to rollback:** Less than 5 minutes (code revert + container restart)

**Data loss:** None (database unchanged until transaction commits)

### Rollback Testing

**Pre-deployment:**
1. Tag current working version: git tag v0.7.0-pre-genemap2
2. Deploy genemap2 version
3. Test ontology update async job
4. If failure: git revert and redeploy

## Success Metrics

### Performance
- **Ontology update time:** Less than 60 seconds (currently approximately 8 minutes)
- **Cache hit rate:** Greater than 90% for daily usage
- **API latency:** No change (async job)

### Reliability
- **Transaction success rate:** 100% (same as current)
- **HGNC resolution rate:** Greater than or equal to 95% (same as current)
- **MOI mapping coverage:** Greater than or equal to 90% (new, was 0%)

### Code Quality
- **Test coverage:** Greater than or equal to 80% for new functions
- **Duplication:** Less than 10 lines of duplicate parsing logic
- **Coupling:** Zero function calls between ontology-functions and comparisons-functions

## Open Questions for Implementation

1. **Deprecation tracking:** Keep mim2gene download for moved/removed entries, or remove this feature?  
   **Recommendation:** Remove in Phase 2, add back diff-based approach in Phase 4

2. **Cache sharing:** Should comparisons system use shared cache or keep ephemeral temp downloads?  
   **Recommendation:** Shared cache (Phase 3) for consistency

3. **Progress steps:** Keep 4 steps for UI compatibility or change to 3?  
   **Recommendation:** Change to 3, simpler is better

4. **Download key storage:** Environment variable only, or database fallback?  
   **Recommendation:** Hybrid (env var + database fallback)

5. **Phenotype parsing:** Shared function or duplicate logic?  
   **Recommendation:** Shared (low risk, high value for maintainability)

## References

**Code Files Analyzed:**
- api/functions/omim-functions.R (mim2gene + JAX API)
- api/functions/ontology-functions.R (orchestrator)
- api/functions/comparisons-functions.R (genemap2 parsing, lines 390-495)
- api/functions/comparisons-sources.R (config management)
- api/functions/mondo-functions.R (SSSOM mappings)
- api/functions/file-functions.R (check_file_age, get_newest_file)
- api/endpoints/admin_endpoints.R (update_ontology_async)
- db/migrations/007_comparisons_config.sql (source config)

**Data Files:**
- api/data/omim_links/omim_links.txt (download URLs with key)

**External APIs:**
- OMIM: https://data.omim.org/downloads/{KEY}/genemap2.txt
- JAX Ontology (deprecated): https://ontology.jax.org/api/network/annotation/OMIM:{mim}
- MONDO SSSOM: https://github.com/monarch-initiative/mondo/raw/master/src/ontology/mappings/mondo_exactmatch_omim.sssom.tsv
