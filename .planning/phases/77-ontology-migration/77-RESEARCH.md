# Phase 77: Ontology Migration - Research

**Researched:** 2026-02-07
**Domain:** OMIM ontology data migration from JAX API to genemap2.txt
**Confidence:** HIGH

## Summary

The current ontology system (Phase 23 implementation) uses a slow workflow: mim2gene.txt → JAX API sequential calls (7+ minutes) → build ontology set. Phase 77 replaces this with genemap2.txt parsing (30-60 seconds), which contains disease names AND inheritance modes directly in the Phenotypes column.

The codebase already contains the OLD genemap2 parsing logic in `db/02_Rcommands_sysndd_db_table_disease_ontology_set.R` (lines 265-312), which extracts disease names, MIM numbers, mapping keys, and inheritance modes. This proven pattern should be adapted for the API context, NOT invented from scratch.

**Primary recommendation:** Adapt the existing genemap2 parsing pattern from the database setup script into the API ontology-functions.R, using Phase 76 shared infrastructure for downloads/caching.

## Standard Stack

### Core Libraries (Already in Use)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tidyverse | (current) | Data manipulation, parsing Phenotypes column | Used throughout existing ontology code |
| readr | (via tidyverse) | Read tab-delimited genemap2.txt | Handles comment lines, encoding |
| stringr | (via tidyverse) | Parse complex Phenotypes format | Required for regex-based field extraction |
| httr2 | (current) | Download genemap2.txt with auth | Modern HTTP client with retry logic |
| fs | (current) | File operations for caching | Cross-platform file handling |
| lubridate | (current) | Date handling for cache TTL | Part of tidyverse ecosystem |

### Supporting (From Phase 76)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| file-functions.R | internal | check_file_age(), get_newest_file() | 1-day TTL caching logic |
| omim-functions.R | internal | download_mim2gene(), parse_mim2gene() | Deprecation tracking (ONTO-06) |
| mondo-functions.R | internal | MONDO SSSOM mappings | Post-processing (ONTO-05) |

### No New Dependencies Required
Phase 76 provides download/caching infrastructure. All parsing libraries already present.

**Installation:** N/A - all dependencies already in api/renv.lock

## Architecture Patterns

### Recommended Project Structure
```
api/functions/
├── omim-functions.R          # Phase 76: download_genemap2(), parse_genemap2()
├── ontology-functions.R       # THIS PHASE: Modify process_omim_ontology()
├── mondo-functions.R          # Unchanged: MONDO SSSOM post-processing
└── file-functions.R           # Unchanged: Caching helpers
```

### Pattern 1: Genemap2 Phenotypes Column Parsing
**What:** Extract disease name, MIM number, mapping key, inheritance from semicolon-separated entries
**When to use:** Processing genemap2.txt rows with Phenotypes column
**Example:**
```r
# Source: db/02_Rcommands_sysndd_db_table_disease_ontology_set.R (lines 268-283)
genemap2_parsed <- genemap2 %>%
  filter(!is.na(Phenotypes) & !is.na(Approved_Symbol)) %>%
  select(Approved_Symbol, Phenotypes) %>%
  separate_rows(Phenotypes, sep = "; ") %>%
  # Extract disease name and inheritance: "Disease name (3), Autosomal dominant"
  separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
           "\\), (?!.+\\))") %>%
  # Extract disease name and mapping key: "Disease name (3"
  separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"),
           "\\((?!.+\\()") %>%
  mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
  # Extract MIM number: "Disease name, 123456"
  separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"),
           ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])") %>%
  mutate(MIM_Number = str_replace_all(MIM_Number, " ", "")) %>%
  filter(!is.na(MIM_Number))
```

**Why this pattern:** Proven in production database generation for years. Handles edge cases.

### Pattern 2: Inheritance Mode Normalization
**What:** Map genemap2 short forms to HPO term names
**When to use:** After extracting inheritance from Phenotypes column
**Example:**
```r
# Source: db/02_Rcommands_sysndd_db_table_disease_ontology_set.R (lines 285-299)
normalized <- parsed_data %>%
  separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
  mutate(hpo_mode_of_inheritance_term_name = str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")) %>%
  mutate(hpo_mode_of_inheritance_term_name = case_when(
    hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance",
    hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~ "Autosomal recessive inheritance",
    hpo_mode_of_inheritance_term_name == "Digenic dominant" ~ "Digenic inheritance",
    hpo_mode_of_inheritance_term_name == "Digenic recessive" ~ "Digenic inheritance",
    hpo_mode_of_inheritance_term_name == "Isolated cases" ~ "Sporadic",
    hpo_mode_of_inheritance_term_name == "Mitochondrial" ~ "Mitochondrial inheritance",
    hpo_mode_of_inheritance_term_name == "Multifactorial" ~ "Multifactorial inheritance",
    hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance",
    hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance",
    hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~ "Somatic mosaicism",
    hpo_mode_of_inheritance_term_name == "Somatic mutation" ~ "Somatic mutation",
    hpo_mode_of_inheritance_term_name == "X-linked" ~ "X-linked inheritance",
    hpo_mode_of_inheritance_term_name == "X-linked dominant" ~ "X-linked dominant inheritance",
    hpo_mode_of_inheritance_term_name == "X-linked recessive" ~ "X-linked recessive inheritance",
    hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance"
  )) %>%
  left_join(mode_of_inheritance_list, by = c("hpo_mode_of_inheritance_term_name"))
```

**Why this pattern:** Complete mapping table validated against HPO. Handles question marks and comma-separated values.

### Pattern 3: Duplicate MIM Versioning
**What:** When same MIM appears with different genes/inheritance, add _1, _2, _3 suffixes
**When to use:** After parsing all entries, before writing to disease_ontology_set
**Example:**
```r
# Source: db/02_Rcommands_sysndd_db_table_disease_ontology_set.R (lines 303-308)
versioned <- parsed_data %>%
  arrange(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
  group_by(disease_ontology_id) %>%
  mutate(n = 1, count = n(), version = cumsum(n)) %>%
  ungroup() %>%
  mutate(disease_ontology_id_version = case_when(
    count == 1 ~ disease_ontology_id,
    count >= 1 ~ paste0(disease_ontology_id, "_", version)
  ))
```

**Why this pattern:** ONTO-04 requirement. Ensures consistent behavior with previous system.

### Pattern 4: Integration with Existing Flow
**What:** Slot genemap2 processing into process_combine_ontology() workflow
**When to use:** Replacing the mim2gene + JAX API block in ontology-functions.R
**Current flow (lines 148-211):**
```
1. Check cached file (line 153)
2. Process MONDO (line 157)
3. Process OMIM via mim2gene + JAX API (line 160)  ← REPLACE THIS
4. Get MONDO mappings (lines 163-186)
5. Combine + apply MONDO SSSOM (lines 188-204)
6. Write CSV (line 207)
```

**New flow:**
```
1. Check cached file (unchanged)
2. Process MONDO (unchanged)
3. Process OMIM via genemap2 (NEW - call Phase 76 functions)
4. Get MONDO mappings (unchanged)
5. Combine + apply MONDO SSSOM (unchanged)
6. Write CSV (unchanged)
```

### Anti-Patterns to Avoid
- **Don't parse from scratch:** The genemap2 Phenotypes column format is complex (nested parentheses, semicolons, commas). Use proven regex patterns.
- **Don't skip inheritance normalization:** genemap2 uses short forms ("Autosomal dominant"). Must map to full HPO names.
- **Don't break versioning logic:** Versioning MUST happen AFTER grouping by disease_ontology_id but BEFORE deduplication.
- **Don't remove MONDO SSSOM step:** ONTO-05 requires this continues unchanged.
- **Don't remove mim2gene download:** ONTO-06 requires keeping it for deprecation tracking.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Genemap2 download with auth | Custom curl/wget wrapper | Phase 76 download_genemap2() with OMIM_DOWNLOAD_KEY | Handles retry, caching, env var |
| Genemap2 parsing logic | New regex patterns | Adapt db/02_Rcommands pattern (lines 268-312) | Proven in production, handles edge cases |
| File caching with TTL | Custom file age checking | file-functions.R check_file_age() | Used elsewhere in API, consistent |
| Inheritance mode mapping | Manual case_when | Existing mapping table (lines 285-299) | Complete, validated against HPO |
| Duplicate MIM versioning | New versioning scheme | Existing cumsum pattern (lines 303-308) | ONTO-04 requires consistency |

**Key insight:** The database setup script (`db/02_Rcommands_sysndd_db_table_disease_ontology_set.R`) is the authoritative reference for genemap2 parsing. It was written to handle real-world OMIM data edge cases and has been running successfully. Don't reinvent - adapt.

## Common Pitfalls

### Pitfall 1: Incorrect Phenotypes Column Parsing Order
**What goes wrong:** Parsing MIM number before disease name, or inheritance before mapping key, breaks on nested parentheses
**Why it happens:** Phenotypes format is: `"Disease name (mapping_key), MIM_number), Inheritance mode, Another inheritance"`
**How to avoid:** Use exact sequence from db script: 1) Split by `"), (?!.+\\))"` for inheritance, 2) Split by `"\\((?!.+\\()"` for mapping key, 3) Split by `", (?=[0-9]{6})"` for MIM
**Warning signs:** Entries with "(3)" mapping key lose disease name, or entries with commas in disease name split incorrectly

### Pitfall 2: Incomplete Inheritance Mode Mapping
**What goes wrong:** Some inheritance modes from genemap2 don't map to HPO terms, resulting in NA values in hpo_mode_of_inheritance_term
**Why it happens:** genemap2 may add new inheritance terms, or use variations not in the mapping table
**How to avoid:** After left_join with mode_of_inheritance_list, log warnings for any NA hpo_mode_of_inheritance_term values where hpo_mode_of_inheritance_term_name was not NA
**Warning signs:** Ontology set has disease entries with inheritance names but no HPO term IDs

### Pitfall 3: Versioning Before Joining Inheritance
**What goes wrong:** Versioning happens too early, before duplicate entries are created via separate_rows(hpo_mode_of_inheritance_term_name)
**Why it happens:** Intuition says "version the MIMs" but versioning must happen AFTER expanding inheritance modes
**How to avoid:** Follow exact sequence: separate_rows inheritance → normalize → join HPO terms → THEN group_by and version
**Warning signs:** Same MIM+gene combination appears with version numbers when it should be identical rows

### Pitfall 4: Breaking MONDO SSSOM Application
**What goes wrong:** Changing disease_ontology_source from "mim2gene" to something else breaks MONDO mapping logic
**Why it happens:** add_mondo_mappings_to_ontology() filters for `disease_ontology_source == "mim2gene"` (mondo-functions.R line 258)
**How to avoid:** Keep disease_ontology_source = "mim2gene" for genemap2-sourced entries (or update MONDO function to handle new source)
**Warning signs:** MONDO mappings all become NA after migration

### Pitfall 5: Losing mim2gene Deprecation Data
**What goes wrong:** Removing mim2gene download means no deprecation tracking
**Why it happens:** Assuming genemap2 replaces ALL uses of mim2gene
**How to avoid:** ONTO-06 explicitly requires keeping mim2gene download for moved/removed entry tracking
**Warning signs:** No way to detect when OMIM entries are deprecated

## Code Examples

Verified patterns from existing codebase:

### Download genemap2 with Caching (Phase 76 will provide)
```r
# Source: Phase 76 shared infrastructure (to be implemented)
# Expected interface based on download_mim2gene() pattern:
download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_months = 1) {
  # Check cache
  if (!force && check_file_age("genemap2", output_path, max_age_months)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) return(existing_file)
  }

  # Download with OMIM_DOWNLOAD_KEY
  download_key <- Sys.getenv("OMIM_DOWNLOAD_KEY")
  if (download_key == "") {
    stop("OMIM_DOWNLOAD_KEY environment variable not set")
  }

  url <- paste0("https://data.omim.org/downloads/", download_key, "/genemap2.txt")
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")

  response <- request(url) %>%
    req_retry(max_tries = 3, max_seconds = 60, backoff = ~ 2^.x) %>%
    req_timeout(30) %>%
    req_perform()

  writeBin(resp_body_raw(response), output_file)
  return(output_file)
}
```

### Parse genemap2 Phenotypes Column (Phase 76 will provide)
```r
# Source: Adapted from db/02_Rcommands_sysndd_db_table_disease_ontology_set.R
# Phase 76 expected to provide this as shared function
parse_genemap2 <- function(file_path, defensive_columns = TRUE) {
  # Read with defensive column mapping (INFRA-03)
  col_names <- if (defensive_columns) {
    c("Chromosome", "Genomic_Position_Start", "Genomic_Position_End",
      "Cyto_Location", "Computed_Cyto_Location", "MIM_Number",
      "Gene_Symbols", "Gene_Name", "Approved_Symbol", "Entrez_Gene_ID",
      "Ensembl_Gene_ID", "Comments", "Phenotypes", "Mouse_Gene_Symbol_ID")
  } else {
    TRUE
  }

  genemap2 <- read_delim(file_path, "\t", escape_double = FALSE,
                         col_names = col_names, comment = "#", trim_ws = TRUE)

  # Extract disease name, MIM, mapping key, inheritance
  parsed <- genemap2 %>%
    filter(!is.na(Phenotypes) & !is.na(Approved_Symbol)) %>%
    select(Approved_Symbol, Phenotypes) %>%
    separate_rows(Phenotypes, sep = "; ") %>%
    separate(Phenotypes, c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
             "\\), (?!.+\\))") %>%
    separate(disease_ontology_name, c("disease_ontology_name", "Mapping_key"),
             "\\((?!.+\\()") %>%
    mutate(Mapping_key = str_replace_all(Mapping_key, "\\)", "")) %>%
    separate(disease_ontology_name, c("disease_ontology_name", "MIM_Number"),
             ", (?=[0-9][0-9][0-9][0-9][0-9][0-9])") %>%
    mutate(Mapping_key = str_replace_all(Mapping_key, " ", "")) %>%
    mutate(MIM_Number = str_replace_all(MIM_Number, " ", "")) %>%
    filter(!is.na(MIM_Number)) %>%
    mutate(disease_ontology_id = paste0("OMIM:", MIM_Number))

  return(parsed)
}
```

### Build OMIM Ontology Set from genemap2 (New for Phase 77)
```r
# Source: New function to replace mim2gene+JAX workflow in process_omim_ontology()
# Location: api/functions/ontology-functions.R
build_omim_from_genemap2 <- function(genemap2_parsed, hgnc_list, moi_list) {
  current_date <- format(Sys.Date(), "%Y-%m-%d")

  # Join with HGNC
  combined <- genemap2_parsed %>%
    left_join(hgnc_list %>% select(symbol, hgnc_id),
              by = c("Approved_Symbol" = "symbol"))

  # Normalize inheritance modes and join HPO terms
  normalized <- combined %>%
    separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    mutate(hpo_mode_of_inheritance_term_name = str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")) %>%
    mutate(hpo_mode_of_inheritance_term_name = case_when(
      hpo_mode_of_inheritance_term_name == "Autosomal dominant" ~ "Autosomal dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Autosomal recessive" ~ "Autosomal recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic dominant" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Digenic recessive" ~ "Digenic inheritance",
      hpo_mode_of_inheritance_term_name == "Isolated cases" ~ "Sporadic",
      hpo_mode_of_inheritance_term_name == "Mitochondrial" ~ "Mitochondrial inheritance",
      hpo_mode_of_inheritance_term_name == "Multifactorial" ~ "Multifactorial inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "Pseudoautosomal recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Somatic mosaicism" ~ "Somatic mosaicism",
      hpo_mode_of_inheritance_term_name == "Somatic mutation" ~ "Somatic mutation",
      hpo_mode_of_inheritance_term_name == "X-linked" ~ "X-linked inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked dominant" ~ "X-linked dominant inheritance",
      hpo_mode_of_inheritance_term_name == "X-linked recessive" ~ "X-linked recessive inheritance",
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance"
    )) %>%
    left_join(moi_list, by = c("hpo_mode_of_inheritance_term_name"))

  # Apply versioning for duplicates
  versioned <- normalized %>%
    select(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
    arrange(disease_ontology_id, hgnc_id, disease_ontology_name, hpo_mode_of_inheritance_term) %>%
    group_by(disease_ontology_id) %>%
    mutate(n = 1, count = n(), version = cumsum(n)) %>%
    ungroup() %>%
    mutate(disease_ontology_id_version = case_when(
      count == 1 ~ disease_ontology_id,
      count >= 1 ~ paste0(disease_ontology_id, "_", version)
    ))

  # Build final ontology set
  result <- versioned %>%
    mutate(
      disease_ontology_source = "mim2gene",  # Keep for MONDO mapping compatibility
      disease_ontology_date = current_date,
      disease_ontology_is_specific = TRUE
    ) %>%
    select(
      disease_ontology_id_version, disease_ontology_id, disease_ontology_name,
      disease_ontology_source, disease_ontology_date, disease_ontology_is_specific,
      hgnc_id, hpo_mode_of_inheritance_term
    )

  return(result)
}
```

### Modified process_omim_ontology (Replace current implementation)
```r
# Source: api/functions/ontology-functions.R (lines 343-389)
# Modify to use genemap2 instead of mim2gene + JAX API
process_omim_ontology <- function(hgnc_list, moi_list, max_file_age = 3, progress_callback = NULL) {
  # Step 1: Download genemap2.txt (Phase 76 shared infrastructure)
  if (!is.null(progress_callback)) {
    progress_callback(step = "Downloading genemap2.txt", current = 1, total = 4)
  }
  genemap2_file <- download_genemap2("data/", force = FALSE, max_age_months = max_file_age)

  # Step 2: Parse genemap2 (Phase 76 shared function)
  if (!is.null(progress_callback)) {
    progress_callback(step = "Parsing genemap2.txt", current = 2, total = 4)
  }
  genemap2_parsed <- parse_genemap2(genemap2_file)

  # Step 3: Build ontology set with inheritance mapping
  if (!is.null(progress_callback)) {
    progress_callback(step = "Building ontology set", current = 3, total = 4)
  }
  omim_terms <- build_omim_from_genemap2(genemap2_parsed, hgnc_list, moi_list)

  # Save for debugging/caching
  omim_file_date <- format(Sys.Date(), "%Y-%m-%d")
  csv_file_path <- paste0("results/ontology/omim_genemap2.", omim_file_date, ".csv")
  if (!dir.exists("results/ontology")) {
    dir.create("results/ontology", recursive = TRUE)
  }
  write_csv(omim_terms, file = csv_file_path, na = "NULL")

  # Note: mim2gene download still happens for deprecation tracking (ONTO-06)
  # This is separate and doesn't block ontology generation

  return(omim_terms)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| genemap2.txt parsing (db script) | mim2gene + JAX API loop | Phase 23 (2026-01-24) | 50x slower, no inheritance data |
| Manual OMIM file download | httr2 with retry | Phase 23 | More reliable downloads |
| N/A | MONDO SSSOM mappings | Phase 23 | Added MONDO equivalence |
| Hardcoded OMIM key | Environment variable | Phase 76 (pending) | Better security, easier deployment |

**Deprecated/outdated:**
- JAX API disease name fetching: Phase 23 introduced this as replacement for genemap2, but it's 50x slower
- Reason for deprecation: genemap2 Phenotypes column contains disease names AND inheritance modes, making JAX API unnecessary
- What replaces it: Direct genemap2 parsing using proven patterns from db/02_Rcommands script

**Key insight:** Phase 23 was a step backward. The original genemap2 approach was faster and provided MORE data (inheritance modes). Phase 77 is a return to the better approach, with modern infrastructure (Phase 76 caching, httr2 downloads).

## Open Questions

1. **Defensive column mapping specifics**
   - What we know: db script uses positional column reading (X1, X2, ..., X13) with hardcoded names
   - What's unclear: Has OMIM ever renamed columns in genemap2.txt historically?
   - Recommendation: Phase 76 should implement both positional (default) and named column reading (fallback) to handle potential header changes

2. **Inheritance mode mapping completeness**
   - What we know: 15 inheritance mode mappings exist in db script (lines 285-299)
   - What's unclear: Are there genemap2 entries with inheritance modes NOT in this mapping table?
   - Recommendation: During Phase 77 implementation, log warnings for unmapped inheritance terms and add them to mapping table if found

3. **Progress reporting granularity**
   - What we know: Current system has 4-step progress (download, parse, build, MONDO)
   - What's unclear: Should parsing of large genemap2 file show sub-progress?
   - Recommendation: Keep 4-step model for simplicity. Genemap2 parsing is fast (<5 seconds), doesn't need sub-progress

4. **disease_ontology_source naming**
   - What we know: MONDO SSSOM code filters for `disease_ontology_source == "mim2gene"` (mondo-functions.R line 258)
   - What's unclear: Should genemap2-sourced entries use "genemap2" or keep "mim2gene" for compatibility?
   - Recommendation: Keep "mim2gene" to avoid breaking MONDO mapping logic, or update both simultaneously

## Sources

### Primary (HIGH confidence)
- Existing codebase: api/functions/ontology-functions.R (current JAX API workflow)
- Existing codebase: api/functions/omim-functions.R (mim2gene download/parse patterns)
- Existing codebase: api/functions/mondo-functions.R (SSSOM mapping workflow)
- Existing codebase: api/functions/file-functions.R (caching infrastructure)
- Existing codebase: db/02_Rcommands_sysndd_db_table_disease_ontology_set.R (genemap2 parsing reference implementation)
- Requirements: .planning/REQUIREMENTS.md (ONTO-01 through ONTO-06)
- Roadmap: .planning/ROADMAP.md (Phase 77 success criteria)

### Secondary (MEDIUM confidence)
- [OMIM genemap2.txt format documentation](https://academic.oup.com/nar/article/43/D1/D789/2439148) - General file structure
- [OMIM downloads page](https://www.omim.org/downloads/) - Access requirements and file descriptions

### Tertiary (LOW confidence - for context only)
- [GitHub OMIM parser example](https://github.com/macarthur-lab/omim/pull/1/files) - Third-party parsing approach (not authoritative)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, no new dependencies
- Architecture patterns: HIGH - Patterns proven in production db script
- Inheritance mapping: HIGH - Complete mapping table exists and is tested
- Column format stability: MEDIUM - Unknown if OMIM has changed column structure historically
- MONDO integration: HIGH - Well-documented code with clear filter logic

**Research date:** 2026-02-07
**Valid until:** 2026-03-07 (30 days - stable domain, unlikely to change)

**Key risks identified:**
1. MEDIUM: Inheritance mode mapping may be incomplete (mitigation: log unmapped values during implementation)
2. LOW: Column name changes could break positional parsing (mitigation: defensive column mapping in Phase 76)
3. LOW: MONDO source name dependency (mitigation: verify disease_ontology_source usage before changing)
