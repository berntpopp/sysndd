# Phase 78: Comparisons Integration - Research

**Researched:** 2026-02-07
**Domain:** R/Plumber API - Comparisons system integration with shared genemap2 infrastructure
**Confidence:** HIGH

## Summary

Phase 78 unifies the comparisons system to use the shared genemap2.txt cache from Phase 76, eliminating duplicate downloads and duplicate parsing code. The research reveals that all necessary infrastructure already exists:

1. **Phase 76 provides:** `download_genemap2()` with 1-day TTL caching (omim-functions.R lines 144-186) and `parse_genemap2()` for raw parsing (lines 235-343)
2. **Comparisons currently has:** Its own genemap2 download via comparisons_config table and its own parsing in `parse_omim_genemap2()` (comparisons-functions.R lines 390-495)
3. **Integration point:** Replace comparisons' genemap2 download/parsing with Phase 76 shared functions, while keeping comparisons-specific NDD filtering logic

The comparisons system applies HPO phenotype-based NDD filtering on top of the raw genemap2 data. Only the raw genemap2 parsing and downloading moves to shared infrastructure. The NDD filtering logic (via phenotype.hpoa) stays in comparisons-functions.R.

**Primary recommendation:** Call Phase 76's `download_genemap2()` for the cached file path, call Phase 76's `parse_genemap2()` for raw data extraction, then apply comparisons-specific NDD filtering via phenotype.hpoa before formatting to comparisons schema.

## Standard Stack

All required libraries already exist in the codebase (renv.lock). No new dependencies needed.

### Core (Already in Use)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dplyr | (renv) | Data transformation | Used throughout comparisons-functions.R |
| readr | (renv) | TSV parsing | Already used by Phase 76's parse_genemap2() |
| stringr | (renv) | String manipulation | Phenotype column parsing, inheritance normalization |
| tidyr | (renv) | Data reshaping | separate_rows() for phenotypes and inheritance |

### Supporting (From Phase 76)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| omim-functions.R | internal | download_genemap2(), parse_genemap2() | Shared genemap2 infrastructure |
| file-functions.R | internal | check_file_age_days(), get_newest_file() | 1-day TTL caching logic |

### No New Dependencies Required
Phase 76 provides all necessary download/parse infrastructure. Comparisons just consumes it.

**Installation:** N/A - all dependencies already in api/renv.lock

## Architecture Patterns

### Recommended Project Structure
```
api/functions/
├── omim-functions.R          # Phase 76: download_genemap2(), parse_genemap2()
├── file-functions.R           # Phase 76: check_file_age_days(), get_newest_file()
├── comparisons-functions.R    # THIS PHASE: Modified parse_omim_genemap2()
└── comparisons-sources.R      # THIS PHASE: Remove genemap2 config entry

api/data/
└── genemap2.YYYY-MM-DD.txt    # Shared cache (1-day TTL)
```

### Pattern 1: Call Shared Download Instead of comparisons_config Entry
**What:** Comparisons calls Phase 76's `download_genemap2()` directly instead of using comparisons_config table entry
**When to use:** In `comparisons_update_async()` when processing OMIM data
**Current code:**
```r
# comparisons-functions.R lines 867-873
"omim_genemap2" = {
  # OMIM requires HPO phenotype file
  hpoa_path <- downloaded_files[["phenotype_hpoa"]]
  if (is.null(hpoa_path)) {
    stop("phenotype_hpoa file required for omim_genemap2 parsing")
  }
  parse_omim_genemap2(file_path, hpoa_path)
}
```

**New approach:**
```r
# Call Phase 76 shared infrastructure instead of using downloaded_files[[]]
"omim_genemap2" = {
  # Get shared cached genemap2 file (1-day TTL)
  genemap2_path <- download_genemap2(output_path = "data/", force = FALSE)

  # Get comparisons-specific phenotype.hpoa (stays in tempdir)
  hpoa_path <- downloaded_files[["phenotype_hpoa"]]
  if (is.null(hpoa_path)) {
    stop("phenotype_hpoa file required for omim_genemap2 parsing")
  }

  # Call reduced parse_omim_genemap2 (uses shared parse internally)
  parse_omim_genemap2(genemap2_path, hpoa_path)
}
```

### Pattern 2: Reduced parse_omim_genemap2() Calls Shared Infrastructure
**What:** Comparisons' parse_omim_genemap2() becomes a thin wrapper around Phase 76's shared functions
**When to use:** Parsing genemap2.txt for comparisons NDD filtering
**Current code (lines 390-495):**
```r
parse_omim_genemap2 <- function(genemap2_path, phenotype_hpoa_path) {
  # Lines 407-466: Direct parsing of genemap2.txt with position-based columns
  # Lines 449-466: Inline inheritance normalization (14 case_when terms)
  # Lines 468-495: NDD filtering via phenotype.hpoa
}
```

**New approach:**
```r
parse_omim_genemap2 <- function(genemap2_path, phenotype_hpoa_path) {
  # Step 1: Call shared Phase 76 parser for raw data extraction
  genemap_data <- parse_genemap2(genemap2_path)

  # Step 2: Apply comparisons-specific NDD filtering via phenotype.hpoa
  ndd_phenotypes <- c(
    "HP:0012759", "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )

  phenotype_hpoa <- readr::read_tsv(
    phenotype_hpoa_path,
    skip = 4,
    show_col_types = FALSE
  )

  phenotype_hpoa_omim_ndd <- phenotype_hpoa %>%
    dplyr::filter(stringr::str_detect(database_id, "OMIM")) %>%
    dplyr::filter(hpo_id %in% ndd_phenotypes) %>%
    dplyr::select(database_id) %>%
    unique()

  # Step 3: Join NDD-filtered OMIM IDs with genemap data
  result <- phenotype_hpoa_omim_ndd %>%
    left_join(genemap_data, by = c("database_id" = "disease_ontology_id")) %>%
    dplyr::filter(!is.na(Approved_Symbol)) %>%
    mutate(
      list = "omim_ndd",
      version = format(Sys.Date(), "%Y-%m-%d"),  # Date-based, not filename-based
      category = "Definitive"
    ) %>%
    dplyr::select(
      gene_symbol = Approved_Symbol,
      disease_ontology_id = database_id,
      disease_ontology_name,
      inheritance = hpo_mode_of_inheritance_term_name,
      list,
      version,
      category
    )

  return(result)
}
```

**Key changes:**
- Raw parsing delegated to Phase 76's `parse_genemap2()`
- Inheritance normalization delegated to Phase 76's `parse_genemap2()` (already includes 14-term case_when)
- NDD filtering (HPO-based) stays in comparisons-functions.R
- Version field switches from `basename(genemap2_path)` to `format(Sys.Date(), "%Y-%m-%d")`

### Pattern 3: Remove genemap2 Config Entry from Database
**What:** Delete the genemap2 config row from comparisons_config table since download moves to shared infrastructure
**When to use:** Migration cutover (one-time operation)
**Migration SQL:**
```sql
-- Remove genemap2 entry from comparisons_config
-- phenotype_hpoa stays (comparisons-only, downloads from HPO)
DELETE FROM comparisons_config WHERE source_name = 'omim_genemap2';
```

**Impact:**
- `get_active_sources(conn)` no longer returns omim_genemap2
- comparisons_update_async() downloads loop skips omim_genemap2
- genemap2 download now happens via explicit `download_genemap2()` call in switch() block

### Pattern 4: Date-Based Version Instead of Filename-Based
**What:** Comparisons OMIM version field switches from filename extraction to date-based
**Why:** genemap2 files are now cached with date in filename (genemap2.2026-02-07.txt), but the version field should just be the date
**Current code (line 481):**
```r
version = basename(genemap2_path) %>% str_remove(pattern = "\\.txt$")
# Result: "genemap2.2026-02-07" (includes prefix)
```

**New code:**
```r
version = format(Sys.Date(), "%Y-%m-%d")
# Result: "2026-02-07" (clean date only)
```

### Pattern 5: Comparisons Schema Requirements
**What:** Output from parse_omim_genemap2() must match comparisons schema exactly
**Schema (from ndd_database_comparison table):**
```
Required columns:
- gene_symbol (maps to symbol column)
- disease_ontology_id (VARCHAR(100))
- disease_ontology_name (TEXT)
- inheritance (VARCHAR(200), maps to hpo_mode_of_inheritance_term_name)
- list (VARCHAR(50), must be "omim_ndd")
- version (VARCHAR(500))
- category (VARCHAR(100), must be "Definitive" for OMIM)

Optional columns (standardize_comparison_data adds these):
- hgnc_id (resolved later via resolve_hgnc_symbols)
- pathogenicity_mode (NA for OMIM)
- phenotype (NA for OMIM)
- publication_id (NA for OMIM)
- import_date (set by standardize_comparison_data)
- granularity (set by standardize_comparison_data)
```

**Mapping from parse_genemap2() output:**
| parse_genemap2() column | comparisons schema column | Transform |
|------------------------|---------------------------|-----------|
| Approved_Symbol | gene_symbol | Direct rename |
| disease_ontology_id | disease_ontology_id | Already "OMIM:123456" format |
| disease_ontology_name | disease_ontology_name | Direct |
| hpo_mode_of_inheritance_term_name | inheritance | Direct (already normalized by Phase 76) |
| N/A | list | Set to "omim_ndd" |
| N/A | version | Set to format(Sys.Date(), "%Y-%m-%d") |
| N/A | category | Set to "Definitive" |

### Anti-Patterns to Avoid
- **Don't copy genemap2.txt to tempdir:** Read directly from shared cache location (api/data/)
- **Don't duplicate inheritance normalization:** Phase 76's parse_genemap2() already normalizes 14 OMIM terms to HPO vocabulary
- **Don't remove phenotype.hpoa download:** It's comparisons-only and NOT shared (ontology doesn't use it)
- **Don't break version field format:** Must be clean date string, not filename with prefix
- **Don't modify comparisons schema output:** parse_omim_genemap2() output must match existing columns exactly

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| genemap2.txt download | Custom download in comparisons | Phase 76 download_genemap2() | Already handles caching, auth, retry logic |
| genemap2.txt parsing | New parser for comparisons | Phase 76 parse_genemap2() | Position-based column mapping, defensive handling |
| Inheritance normalization | Duplicate case_when in comparisons | Phase 76's parse_genemap2() | Single source of truth (14 terms), already tested |
| File caching logic | Custom age checking | Phase 76's check_file_age_days() | 1-day TTL already implemented |
| Column name handling | Hardcoded column names | Phase 76's position-based mapping | Defensive against OMIM format changes |

**Key insight:** Phase 76 already extracted and generalized the proven genemap2 parsing patterns from comparisons-functions.R. Don't recreate what was just refactored - consume it.

## Common Pitfalls

### Pitfall 1: Forgetting to Source file-functions.R
**What goes wrong:** `download_genemap2()` calls `check_file_age_days()` and `get_newest_file()` but they're not in scope
**Why it happens:** omim-functions.R doesn't explicitly source file-functions.R (assumes Plumber sourcing order)
**How to avoid:** Verify that start_sysndd_api.R sources file-functions.R BEFORE omim-functions.R
**Warning signs:** Error "could not find function 'check_file_age_days'" during comparisons refresh

### Pitfall 2: Removing phenotype.hpoa from comparisons_config
**What goes wrong:** parse_omim_genemap2() fails because phenotype.hpoa wasn't downloaded
**Why it happens:** Assuming all OMIM files move to shared infrastructure, but phenotype.hpoa is comparisons-only
**How to avoid:** Keep phenotype_hpoa config entry in comparisons_config (only remove omim_genemap2)
**Warning signs:** Error "phenotype_hpoa file required for omim_genemap2 parsing"

### Pitfall 3: Wrong Version Field Format
**What goes wrong:** Version field contains "genemap2.2026-02-07" instead of just "2026-02-07"
**Why it happens:** Using `basename(genemap2_path) %>% str_remove("\\.txt$")` instead of date extraction
**How to avoid:** Use `format(Sys.Date(), "%Y-%m-%d")` directly, not filename manipulation
**Warning signs:** Comparisons view shows version with "genemap2." prefix

### Pitfall 4: Breaking NDD Filtering Logic
**What goes wrong:** All genemap2 entries imported instead of just NDD-related ones
**Why it happens:** Removing the phenotype.hpoa filtering step when switching to Phase 76 parser
**How to avoid:** Keep the NDD filtering logic (lines 468-495) in reduced parse_omim_genemap2()
**Warning signs:** Massive increase in omim_ndd rows (should be ~4,000-5,000 NDD entries, not all ~10,000+ OMIM entries)

### Pitfall 5: Schema Mismatch After Parsing
**What goes wrong:** standardize_comparison_data() fails because parse_omim_genemap2() returns wrong column names
**Why it happens:** Phase 76's parse_genemap2() returns different column names than comparisons expects
**How to avoid:** Explicitly rename columns in reduced parse_omim_genemap2() before return (see Pattern 2)
**Warning signs:** Error in standardize_comparison_data() about missing expected columns

### Pitfall 6: Losing comparisons_config Update Timestamps
**What goes wrong:** update_source_last_updated() tries to update omim_genemap2 row that no longer exists
**Why it happens:** comparisons_update_async() still loops through all parsed sources including omim_genemap2
**How to avoid:** Skip update_source_last_updated() for omim_genemap2 (or handle missing rows gracefully)
**Warning signs:** Database error during metadata update phase of comparisons refresh

## Code Examples

### Example 1: Modified comparisons_update_async() Download Loop
```r
# Source: api/functions/comparisons-functions.R (lines 826-846)
# Modified for Phase 78

for (i in seq_len(nrow(sources))) {
  source <- sources[i, ]
  source_name <- source$source_name

  # phenotype_hpoa downloads normally via comparisons_config
  # omim_genemap2 is NO LONGER in sources (removed from config)
  file_path <- download_source_data(source, temp_dir)

  if (is.null(file_path)) {
    stop(sprintf("Failed to download source: %s", source_name))
  }

  downloaded_files[[source_name]] <- file_path
}

# genemap2 downloaded separately via shared infrastructure (NOT in loop)
# This happens in the parsing switch() block below
```

### Example 2: Modified Parsing Switch Block
```r
# Source: api/functions/comparisons-functions.R (lines 859-877)
# Modified for Phase 78

parsed_data <- tryCatch({
  switch(source_name,
    "radboudumc_ID" = parse_radboudumc_pdf(file_path),
    "gene2phenotype" = parse_gene2phenotype_csv(file_path),
    "panelapp" = parse_panelapp_tsv(file_path),
    "sfari" = parse_sfari_csv(file_path),
    "geisinger_DBD" = parse_geisinger_csv(file_path),
    "orphanet_id" = parse_orphanet_json(file_path),
    "phenotype_hpoa" = NULL,  # Used by omim_genemap2, not parsed separately
    stop(sprintf("Unknown source: %s", source_name))
  )
}, error = function(e) {
  stop(sprintf("Failed to parse %s: %s", source_name, e$message))
})

# After main loop, parse OMIM separately using shared infrastructure
omim_parsed <- tryCatch({
  # Call Phase 76 shared download (1-day TTL cache)
  genemap2_path <- download_genemap2(output_path = "data/", force = FALSE)

  # Get phenotype.hpoa from downloaded_files
  hpoa_path <- downloaded_files[["phenotype_hpoa"]]
  if (is.null(hpoa_path)) {
    stop("phenotype_hpoa file required for omim_genemap2 parsing")
  }

  # Call reduced parse_omim_genemap2 (uses Phase 76 parse internally)
  parse_omim_genemap2(genemap2_path, hpoa_path)
}, error = function(e) {
  stop(sprintf("Failed to parse omim_genemap2: %s", e$message))
})

# Add OMIM data to all_parsed_data list
all_parsed_data[["omim_genemap2"]] <- omim_parsed
```

### Example 3: Reduced parse_omim_genemap2() Function
```r
# Source: api/functions/comparisons-functions.R (modified lines 390-495)
# Phase 78 version - thin wrapper around Phase 76 shared functions

parse_omim_genemap2 <- function(genemap2_path, phenotype_hpoa_path) {
  # Step 1: Call Phase 76 shared parser for raw data extraction
  # This handles:
  # - Position-based column mapping (X1-X14)
  # - Phenotypes column multi-stage parsing
  # - Inheritance normalization (14 OMIM terms to HPO)
  # - disease_ontology_id formatting (OMIM:123456)
  genemap_data <- parse_genemap2(genemap2_path)

  # Step 2: Define NDD-related HPO terms (comparisons-specific filtering)
  ndd_phenotypes <- c(
    "HP:0012759", "HP:0001249", "HP:0001256", "HP:0002187",
    "HP:0002342", "HP:0006889", "HP:0010864"
  )

  # Step 3: Read phenotype.hpoa (comparisons-only file)
  phenotype_hpoa <- readr::read_tsv(
    phenotype_hpoa_path,
    skip = 4,
    show_col_types = FALSE
  )

  # Step 4: Filter for NDD-related OMIM entries via HPO phenotypes
  phenotype_hpoa_omim_ndd <- phenotype_hpoa %>%
    dplyr::filter(stringr::str_detect(database_id, "OMIM")) %>%
    dplyr::filter(hpo_id %in% ndd_phenotypes) %>%
    dplyr::select(database_id) %>%
    unique()

  # Step 5: Join NDD filter with genemap data and format to comparisons schema
  result <- phenotype_hpoa_omim_ndd %>%
    dplyr::left_join(genemap_data, by = c("database_id" = "disease_ontology_id")) %>%
    dplyr::filter(!is.na(Approved_Symbol)) %>%
    dplyr::mutate(
      list = "omim_ndd",
      version = format(Sys.Date(), "%Y-%m-%d"),  # Date-based, not filename
      category = "Definitive"
    ) %>%
    dplyr::select(
      gene_symbol = Approved_Symbol,
      disease_ontology_id = database_id,
      disease_ontology_name,
      inheritance = hpo_mode_of_inheritance_term_name,
      list,
      version,
      category
    )

  return(result)
}
```

### Example 4: Database Migration to Remove genemap2 Config
```sql
-- Migration: Remove genemap2 entry from comparisons_config
-- Phase 78: genemap2 download moves to shared infrastructure
-- phenotype_hpoa stays (comparisons-only, downloads from HPO)

-- Delete genemap2 config entry
DELETE FROM comparisons_config WHERE source_name = 'omim_genemap2';

-- Verify removal
SELECT source_name, source_url, is_active
FROM comparisons_config
ORDER BY id;

-- Expected result: 7 sources remain (phenotype_hpoa stays, omim_genemap2 removed)
```

### Example 5: Modified update_source_last_updated() Call
```r
# Source: api/functions/comparisons-functions.R (lines 963-966)
# Modified for Phase 78

# Update source timestamps
for (source_name in names(all_parsed_data)) {
  # Skip omim_genemap2 - it's not in comparisons_config anymore
  if (source_name == "omim_genemap2") {
    next
  }

  update_source_last_updated(conn, source_name)
}
```

## State of the Art

### Current Approach (Before Phase 78)
| Component | Implementation | Performance |
|-----------|----------------|-------------|
| genemap2 download | Via comparisons_config entry, downloaded to tempdir each time | Slow (downloads daily even if both systems need it) |
| genemap2 parsing | Inline in parse_omim_genemap2() (lines 407-466) | Duplicate code vs Phase 76 |
| Inheritance mapping | Inline case_when with 14 terms (lines 449-466) | Duplicate code vs Phase 76 |
| Caching | No caching, fresh download each comparisons refresh | Inefficient if ontology and comparisons both run same day |

### New Approach (Phase 78)
| Component | Implementation | Performance |
|-----------|----------------|-------------|
| genemap2 download | Phase 76 download_genemap2() with 1-day TTL cache | Fast (single download per day shared across both systems) |
| genemap2 parsing | Phase 76 parse_genemap2() for raw extraction | Shared code, single source of truth |
| Inheritance mapping | Phase 76 parse_genemap2() includes normalization | Shared code, single source of truth |
| Caching | Shared api/data/ cache with date-stamped files | Efficient (both systems share cache) |

### When Changed
- Phase 76 (2026-02-07): Created shared infrastructure
- Phase 77 (2026-02-07): Migrated ontology to use shared infrastructure
- Phase 78 (THIS PHASE): Migrate comparisons to use shared infrastructure

### Impact
- **Performance:** 50x+ faster OMIM processing (proven in Phase 77)
- **Code quality:** Eliminates ~100 lines of duplicate parsing/normalization logic
- **Maintainability:** Single source of truth for OMIM data processing
- **Cache efficiency:** Single genemap2.txt download per day (not per system)

**Deprecated/outdated:**
- comparisons_config.omim_genemap2 entry: Replaced by Phase 76 download_genemap2() call
- Inline genemap2 parsing in comparisons-functions.R: Replaced by Phase 76 parse_genemap2()
- Inline inheritance normalization in comparisons-functions.R: Replaced by Phase 76's case_when

## Open Questions

### Question 1: Should comparisons version field match genemap2 cache file date or refresh date?

**What we know:**
- Current code: `version = basename(genemap2_path) %>% str_remove("\\.txt$")` produces "genemap2.2026-02-07"
- Phase 76 cache: Files named genemap2.YYYY-MM-DD.txt with 1-day TTL
- Comparisons may run multiple times per day using same cached file

**What's unclear:**
- Should version reflect when genemap2 was downloaded (cache file date) or when comparisons refresh ran (today's date)?
- If comparisons refreshes twice in one day, should both use same version or different?

**Recommendation:**
Use `format(Sys.Date(), "%Y-%m-%d")` (refresh date) for consistency with other comparisons sources. All sources use import_date for "when we got this data" tracking. Version field can reflect "which dataset version" (the date it was current).

### Question 2: How to handle update_source_last_updated() for omim_genemap2?

**What we know:**
- update_source_last_updated() expects source_name to exist in comparisons_config
- omim_genemap2 will be removed from comparisons_config
- Loop calls update_source_last_updated() for all parsed sources (lines 963-966)

**What's unclear:**
- Should we silently skip missing sources, or error?
- Should we add a check in update_source_last_updated() to handle missing rows?

**Recommendation:**
Add explicit skip in the update loop (see Example 5 above). This makes the special case visible and avoids silent failures if other sources are accidentally removed.

### Question 3: Should we add a migration script or manual SQL for comparisons_config cleanup?

**What we know:**
- Migration 007 created comparisons_config with omim_genemap2 entry
- Phase 78 removes this entry (no longer needed)
- Database is in production

**What's unclear:**
- Create a formal migration file (e.g., 014_remove_genemap2_config.sql)?
- Or just document the DELETE statement for manual execution?

**Recommendation:**
Create a migration file for clean versioning and documentation. Even though it's a single DELETE, having it in migrations/ makes the change traceable and reversible.

## Sources

### Primary (HIGH confidence)
- api/functions/comparisons-functions.R - Current comparisons OMIM parsing (lines 390-495)
- api/functions/omim-functions.R - Phase 76 shared infrastructure (lines 144-343)
- db/migrations/009_ndd_database_comparison.sql - Comparisons table schema
- db/migrations/007_comparisons_config.sql - Comparisons config table schema
- api/functions/comparisons-sources.R - Config management functions
- api/tests/testthat/test-unit-comparisons-functions.R - Existing test patterns

### Secondary (MEDIUM confidence)
- .planning/phases/76-shared-infrastructure/76-RESEARCH.md - Phase 76 patterns and rationale
- .planning/phases/77-ontology-migration/77-RESEARCH.md - Ontology migration patterns (similar integration)
- api/functions/file-functions.R - Caching helper functions

### Tertiary (Context only)
- .planning/phases/78-comparisons-integration/78-CONTEXT.md - User decisions for this phase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in renv.lock, proven in Phase 76/77
- Architecture: HIGH - Integration pattern matches Phase 77 ontology migration
- Pitfalls: HIGH - Based on actual code inspection and Phase 76/77 learnings
- Schema requirements: HIGH - Verified against db/migrations/009 and actual comparisons-functions.R output

**Research date:** 2026-02-07
**Valid until:** 30 days (2026-03-09) - Stable infrastructure, low churn expected
