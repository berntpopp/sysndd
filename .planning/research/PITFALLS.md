# Domain Pitfalls: OMIM Data Integration

**Domain:** OMIM data processing migration (JAX API → genemap2.txt)
**Researched:** 2026-02-07
**Context:** Replacing mim2gene.txt + JAX API approach with genemap2.txt parsing

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or system unavailability.

---

### Pitfall 1: Missing Download Caching Leads to OMIM IP Blocking

**What goes wrong:**
- OMIM enforces rate limiting and IP blocking for repeated downloads
- Without caching, every development restart or test run downloads genemap2.txt
- OMIM's terms require "data must be refreshed at least weekly" but NOT more frequently
- Excessive downloads can result in IP blocking or API key revocation

**Why it happens:**
- Developers overlook that OMIM is a protected resource, not a public CDN
- File download code doesn't check if recent file exists before downloading
- No TTL-based caching strategy implemented

**Consequences:**
- Development environment loses access to OMIM data
- Production deployments fail during data refresh
- Manual intervention required to restore access
- OMIM may require explanation/justification for key reinstatement

**Prevention:**
```r
# Implement TTL-based caching (1 day = 24 hours)
download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age("genemap2", output_path, max_age_days)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("Using cached file: %s", existing_file))
      return(existing_file)
    }
  }

  # Only download if cache miss or expired
  # Include API key from environment variable
  # ...
}
```

**Detection:**
- Warning signs: HTTP 429 (Too Many Requests) from OMIM
- API key suddenly stops working
- Download requests timing out
- Check OMIM API key validity: https://omim.org/downloads/

**Phase-specific guidance:**
- **Phase 1 (Basic genemap2 parsing):** Implement caching FIRST, before any parsing logic
- **Phase 2 (Database integration):** Ensure cache persists across container restarts
- **Phase 3 (Testing):** Use mocked genemap2 files, NOT live downloads in CI

**Sources:**
- [OMIM Downloads Terms](https://www.omim.org/downloads/) - "data must be refreshed at least weekly"
- [OMIM API Agreement](https://www.omim.org/help/agreement) - "reserves the right to revoke the key at its discretion"

---

### Pitfall 2: genemap2.txt Field Name Changes Break Parsing

**What goes wrong:**
- OMIM periodically renames column headers in genemap2.txt without versioning
- Hard-coded column name parsing breaks silently
- Known changes: "Approved Symbol" → "Approved Gene Symbol", "Gene Symbols" → "Gene/Locus And Other Related Symbols"
- No formal deprecation notices or changelog published

**Why it happens:**
- OMIM doesn't version their file formats or provide migration guides
- Column header changes are considered "clarifications" not breaking changes
- Parsers use exact string matching on header names

**Consequences:**
- Entire data import fails with cryptic error
- Gene symbol matching fails, resulting in missing hgnc_id values
- Silent data quality degradation (entries imported but missing critical fields)
- Requires emergency hotfix to production

**Prevention:**
```r
# Defensive column name mapping with fallbacks
parse_genemap2 <- function(file_path) {
  raw_data <- read_delim(file_path, delim = "\t", comment = "#", ...)

  # Map column names with historical variations
  colnames_mapping <- list(
    gene_symbol = c("Approved Gene Symbol", "Approved Symbol", "Gene Symbol"),
    gene_symbols_all = c("Gene/Locus And Other Related Symbols", "Gene Symbols"),
    phenotypes = c("Phenotypes", "Disorders")
  )

  # Find actual column name from variations
  actual_cols <- sapply(colnames_mapping, function(variations) {
    found <- intersect(variations, names(raw_data))
    if (length(found) == 0) {
      stop(sprintf("Expected columns not found. Looked for: %s. Available: %s",
                   paste(variations, collapse = "/"),
                   paste(names(raw_data), collapse = ", ")))
    }
    found[1]
  })

  # Rename to standard names
  # ...
}
```

**Detection:**
- Warning signs: Sudden increase in NA gene_symbol values
- Validation errors: "column X not found"
- Compare column names against known variations on each import
- Unit tests should verify column mapping logic with multiple format versions

**Phase-specific guidance:**
- **Phase 1:** Implement flexible column mapping from day one
- **Phase 2:** Add validation that alerts on unexpected column names
- **Phase 3:** Version genemap2.txt file downloads with date suffix for rollback capability

**Sources:**
- [Scout CHANGELOG](https://github.com/Clinical-Genomics/scout/blob/main/CHANGELOG.md) - Documents field renaming encountered in production
- [OMIM genemap2 parsers on GitHub](https://github.com/topics/omim) - Multiple parsers show historical variations

---

### Pitfall 3: Phenotypes Column Regex Fragility

**What goes wrong:**
- The Phenotypes column contains complex nested structures with multiple delimiter types
- Format: `Disease name (mapping_key), MIM_number; Another disease (mapping_key), MIM_number`
- Parentheses contain mapping keys (1, 2, 3, 4) AND inheritance information in some entries
- Brackets may appear in disease names themselves
- The old regex approach from the codebase context was fragile:
  ```r
  separate(Phenotypes, c("name", "inheritance"), "\\), (?!.+\\))")
  separate(name, c("name", "Mapping_key"), "\\((?!.+\\()")
  separate(name, c("name", "MIM_Number"), ", (?=[0-9]{6})")
  ```
- Edge cases: disease names with commas, semicolons in unexpected places, missing mapping keys

**Why it happens:**
- OMIM Phenotypes column is designed for human readability, not machine parsing
- Multiple pieces of information embedded in a single text field
- No formal grammar or schema documentation
- Regex patterns written based on sample data, not comprehensive specification

**Consequences:**
- Silent data corruption: disease names truncated at unexpected commas
- Inheritance information lost or incorrectly extracted
- MIM number extraction fails for edge cases
- Missing entries in database (rows skipped due to parsing failures)

**Prevention:**
```r
# Use robust field-based parsing instead of complex regex chains
parse_phenotypes_column <- function(phenotypes_str) {
  if (is.na(phenotypes_str) || phenotypes_str == "") {
    return(tibble(
      disease_name = NA_character_,
      mapping_key = NA_character_,
      mim_number = NA_character_
    ))
  }

  # Split on semicolon for multiple phenotypes
  entries <- str_split(phenotypes_str, ";\\s*")[[1]]

  # Parse each entry
  results <- map_dfr(entries, function(entry) {
    # Extract MIM number (always 6 digits at end after comma)
    mim_match <- str_match(entry, ",\\s*(\\d{6})\\s*$")
    mim_number <- if (!is.na(mim_match[1, 2])) mim_match[1, 2] else NA_character_

    # Extract mapping key (digit in parentheses)
    key_match <- str_match(entry, "\\((\\d)\\)")
    mapping_key <- if (!is.na(key_match[1, 2])) key_match[1, 2] else NA_character_

    # Disease name is everything before first opening paren
    name_match <- str_match(entry, "^(.+?)\\s*\\(")
    disease_name <- if (!is.na(name_match[1, 2])) {
      str_trim(name_match[1, 2])
    } else {
      # No parentheses - take everything before MIM number
      str_trim(str_remove(entry, ",\\s*\\d{6}\\s*$"))
    }

    tibble(
      disease_name = disease_name,
      mapping_key = mapping_key,
      mim_number = mim_number
    )
  })

  return(results)
}

# Validate extraction
validate_phenotype_extraction <- function(parsed) {
  if (any(is.na(parsed$mim_number))) {
    warning("Failed to extract MIM number from some phenotype entries")
  }
  if (any(is.na(parsed$disease_name))) {
    stop("Failed to extract disease name - parsing logic needs review")
  }
}
```

**Detection:**
- Warning signs: Unexpected NA values in disease_name or mim_number columns
- Validation failures during database insertion
- Compare parsed entry count vs. expected semicolon count + 1
- Unit tests with known complex examples from actual genemap2.txt

**Phase-specific guidance:**
- **Phase 1:** Build comprehensive test cases from real genemap2.txt edge cases
- **Phase 2:** Add validation that compares entry count before/after parsing
- **Phase 3:** Log unparseable entries for manual review, don't skip silently

**Sources:**
- [OMIM genemap2 documentation](https://www.omim.org/downloads/) - Phenotypes field uses semicolon separators for allelic disorders
- [OMIM FAQ](https://www.omim.org/help/faq) - Mapping keys (1, 2, 3, 4) explained
- User-provided regex from project context shows historical fragility

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or maintenance burden.

---

### Pitfall 4: Environment Variable Migration Incomplete

**What goes wrong:**
- Moving OMIM API key from hardcoded value to environment variable
- Incomplete migration: key works in one environment (local with .Renviron) but fails in another (Docker, CI)
- Error messages don't clarify that missing env var is the root cause
- Multiple configuration methods conflict (.Renviron, config.yml, Docker ENV)

**Why it happens:**
- R has multiple configuration mechanisms (.Renviron, .Rprofile, config package, Sys.setenv())
- Docker containers don't inherit local .Renviron files
- CI environments use different variable injection methods
- Developers test locally where .Renviron exists, never see production failure

**Consequences:**
- Production deployment fails to download OMIM data
- CI tests fail intermittently depending on runner environment
- Error message: "Failed to download genemap2.txt: HTTP 401" doesn't mention missing API key
- Time wasted debugging authentication vs. configuration

**Prevention:**
```r
# Helper function with clear error messages
get_omim_api_key <- function() {
  key <- Sys.getenv("OMIM_API_KEY", unset = NA)

  if (is.na(key) || key == "") {
    stop(
      "OMIM_API_KEY environment variable not set.\n",
      "Local: Add to ~/.Renviron or api/.Renviron\n",
      "Docker: Set in docker-compose.yml under environment:\n",
      "  environment:\n",
      "    - OMIM_API_KEY=${OMIM_API_KEY}\n",
      "CI: Set as GitHub Actions secret and add to workflow env:\n",
      "  env:\n",
      "    OMIM_API_KEY: ${{ secrets.OMIM_API_KEY }}\n"
    )
  }

  return(key)
}

# Use in download function
download_genemap2 <- function(...) {
  api_key <- get_omim_api_key()
  url <- paste0("https://data.omim.org/downloads/...", "?apiKey=", api_key)
  # ...
}
```

**Detection:**
- Warning signs: HTTP 401 or 403 from OMIM downloads
- Works locally, fails in Docker/CI
- Check: `Sys.getenv("OMIM_API_KEY")` returns empty string in failing environment
- Verify .Renviron is in .gitignore (should be, to prevent committing secrets)

**Phase-specific guidance:**
- **Phase 1:** Implement env var helper function with clear error messages
- **Phase 2:** Document configuration in README for all environments
- **Phase 3:** Add CI test that explicitly checks env var is set (don't wait for download to fail)

**Sources:**
- [httr secrets management](https://httr.r-lib.org/articles/secrets.html) - Best practices for API keys
- [rhino secrets guide](https://appsilon.github.io/rhino/articles/how-to/manage-secrets-and-environments.html) - Environment variable patterns
- CLAUDE.md - Existing project uses config.yml for database credentials

---

### Pitfall 5: No Rollback Plan for Data Source Migration

**What goes wrong:**
- Cutover from mim2gene.txt + JAX API to genemap2.txt happens atomically
- genemap2.txt parsing has bugs or missing data discovered post-deployment
- No way to fall back to JAX API approach
- Database now contains mixed data from both sources with no source tracking

**Why it happens:**
- Migration treated as a one-way door
- Old code deleted immediately after new code deployed
- No feature flag or dual-write period
- Assumption that new approach is strictly better

**Consequences:**
- Production data quality degradation requires emergency hotfix
- No clean rollback path - must restore from backup or rewrite data
- Curator workflow disrupted during migration period
- Loss of confidence in data pipeline

**Prevention:**
```r
# Feature flag pattern
get_omim_data_source <- function() {
  source <- Sys.getenv("OMIM_DATA_SOURCE", unset = "genemap2")

  if (!source %in% c("genemap2", "jax_api", "both")) {
    stop(sprintf("Invalid OMIM_DATA_SOURCE: %s. Must be genemap2, jax_api, or both", source))
  }

  return(source)
}

fetch_omim_data <- function() {
  source <- get_omim_data_source()

  if (source == "jax_api") {
    return(fetch_omim_via_jax())  # Old approach
  } else if (source == "genemap2") {
    return(fetch_omim_via_genemap2())  # New approach
  } else if (source == "both") {
    # Dual-write: use genemap2, validate against JAX API
    new_data <- fetch_omim_via_genemap2()
    old_data <- fetch_omim_via_jax()
    validate_migration_consistency(new_data, old_data)
    return(new_data)
  }
}

# Track data source in database
build_omim_ontology_set <- function(...) {
  result <- # ... parsing logic ...

  result <- result %>%
    mutate(
      disease_ontology_source = case_when(
        get_omim_data_source() == "genemap2" ~ "omim_genemap2",
        get_omim_data_source() == "jax_api" ~ "omim_jax_api",
        TRUE ~ "omim_genemap2"
      )
    )

  return(result)
}
```

**Detection:**
- Warning signs: Data validation failures increase after deployment
- Curator reports missing or incorrect disease information
- Entity counts change unexpectedly
- Compare database snapshots before/after migration

**Phase-specific guidance:**
- **Phase 1:** Keep JAX API code intact, add genemap2 parsing alongside
- **Phase 2:** Implement "both" mode that validates new vs. old approach
- **Phase 3:** Migration period with feature flag, then deprecate old code
- **Phase 4:** Remove JAX API code only after stable operation confirmed (1-2 weeks)

**Sources:**
- [API backward compatibility guide](https://medium.com/carvago-development/avoiding-backward-compatibility-breaks-in-api-design-a-developers-guide-b6b4d280d423) - Feature flag patterns
- [Feature toggles for migration](https://stackoverflow.blog/2020/05/13/ensuring-backwards-compatibility-in-distributed-systems/) - Gradual rollout strategies

---

### Pitfall 6: httr2 Cache Doesn't Respect Custom TTL

**What goes wrong:**
- Developer assumes `req_cache(max_age = 86400)` sets 1-day TTL
- Actually: httr2's `max_age` prunes old cache entries, but respects HTTP headers from server
- OMIM server returns `Cache-Control: no-cache` or short expiry
- Cache revalidates with server on every request, defeating the purpose
- Downloads still happen frequently despite caching code

**Why it happens:**
- Misunderstanding of HTTP cache semantics vs. application-level caching
- httr2 `req_cache()` is designed for standard HTTP caching, not file archiving
- OMIM's HTTP headers discourage caching (understandably, data freshness is critical)
- Documentation doesn't clearly distinguish "cache pruning" from "cache TTL"

**Consequences:**
- Still hitting OMIM servers frequently despite caching attempt
- Risk of rate limiting or IP blocking persists
- Cache directory grows unbounded (if max_age not set)

**Prevention:**
```r
# Use manual file-based caching, not httr2 req_cache
download_genemap2 <- function(output_path = "data/", max_age_days = 1) {
  cache_file <- get_newest_file("genemap2", output_path)

  # Check if cache is fresh
  if (!is.null(cache_file)) {
    file_age_days <- as.numeric(difftime(Sys.time(), file.mtime(cache_file), units = "days"))

    if (file_age_days < max_age_days) {
      message(sprintf("Using cached file (age: %.1f days): %s", file_age_days, cache_file))
      return(cache_file)
    } else {
      message(sprintf("Cache expired (age: %.1f days), downloading fresh data", file_age_days))
    }
  }

  # Download and save with timestamp
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- file.path(output_path, paste0("genemap2.", current_date, ".txt"))

  # Use httr2 for download with retry, but NOT for caching
  response <- request("https://data.omim.org/downloads/...") %>%
    req_retry(max_tries = 3, backoff = ~ 2^.x) %>%
    req_timeout(60) %>%
    req_perform()

  writeBin(resp_body_raw(response), output_file)

  return(output_file)
}
```

**Detection:**
- Warning signs: Network logs show frequent OMIM requests despite caching
- File timestamp vs. last-used timestamp reveals cache misses
- Monitor: `httr2::cache_info()` shows frequent revalidation
- Check HTTP headers: `curl -I https://data.omim.org/downloads/...`

**Phase-specific guidance:**
- **Phase 1:** Implement file-based caching with explicit TTL, not HTTP cache delegation
- **Phase 2:** Add monitoring/logging of cache hits vs. downloads
- **Phase 3:** Consider periodic refresh job (weekly) vs. on-demand downloads

**Sources:**
- [httr2 req_cache documentation](https://httr2.r-lib.org/reference/req_cache.html) - "max_age prunes cache, respects HTTP headers"
- [HTTP Cache-Control header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) - Server controls caching behavior

---

## Minor Pitfalls

Mistakes that cause annoyance but are easily fixable.

---

### Pitfall 7: Mapping Key Semantics Misunderstood

**What goes wrong:**
- Developer treats mapping keys (1, 2, 3, 4) as quality scores or inheritance codes
- Actually: mapping keys indicate evidence type, not quality
  - (1) = disorder positioned by mapping wildtype gene
  - (2) = disease phenotype itself was mapped
  - (3) = molecular basis known
  - (4) = chromosome deletion/duplication syndrome
- Filtering based on misunderstood semantics excludes valid data

**Why it happens:**
- Mapping key semantics not documented in genemap2.txt header
- Numeric codes suggest ordinal ranking
- No contextual hints in the data itself

**Consequences:**
- Data quality decisions made on wrong criteria
- Valid chromosome deletion syndromes (key 4) incorrectly excluded
- Inconsistent filtering across codebase

**Prevention:**
```r
# Document mapping key semantics clearly
OMIM_MAPPING_KEYS <- list(
  "1" = "Disorder positioned by mapping wildtype gene",
  "2" = "Disease phenotype itself was mapped",
  "3" = "Molecular basis of disorder is known",
  "4" = "Chromosome deletion or duplication syndrome"
)

# Filter with understanding
filter_high_confidence_phenotypes <- function(data) {
  # Keys 3 and 4 indicate well-characterized disorders
  data %>%
    filter(mapping_key %in% c("3", "4"))
}
```

**Detection:**
- Warning signs: Unexpected number of filtered entries
- Curators report missing well-known disorders
- Cross-reference with OMIM web interface results

**Phase-specific guidance:**
- **Phase 1:** Document mapping key semantics in code comments and PITFALLS.md
- **Phase 2:** Preserve mapping key in database for future filtering flexibility
- **Phase 3:** Consider exposing mapping key in UI for curator transparency

**Sources:**
- [OMIM FAQ](https://www.omim.org/help/faq) - Mapping key definitions
- [OMIM search help](https://www.omim.org/help/search) - Phenotype mapping explanation

---

### Pitfall 8: Gene Symbol Ambiguity Not Handled

**What goes wrong:**
- genemap2.txt contains historical gene symbols that may no longer be current
- HGNC symbol matching fails for outdated symbols
- No fallback to Entrez Gene ID or Ensembl ID matching
- Entries missing gene associations despite having valid gene IDs

**Why it happens:**
- Gene symbols change over time (HGNC updates, gene name standardization)
- Exact string matching on symbol assumes current nomenclature
- genemap2.txt includes historical data not updated for symbol changes

**Consequences:**
- Lower-than-expected gene association rate
- Manual curator intervention required to fix associations
- Inconsistency between genemap2 and database gene symbols

**Prevention:**
```r
# Fallback gene matching strategy
match_gene_to_hgnc <- function(gene_symbol, entrez_id, ensembl_id, hgnc_list) {
  # Try current symbol first
  match <- hgnc_list %>%
    filter(symbol == gene_symbol) %>%
    pull(hgnc_id)

  if (length(match) > 0) {
    return(match[1])
  }

  # Try Entrez ID
  if (!is.na(entrez_id)) {
    match <- hgnc_list %>%
      filter(entrez_id == !!entrez_id) %>%
      pull(hgnc_id)

    if (length(match) > 0) {
      message(sprintf("Matched %s via Entrez ID %s (symbol mismatch)", gene_symbol, entrez_id))
      return(match[1])
    }
  }

  # Try Ensembl ID
  if (!is.na(ensembl_id)) {
    match <- hgnc_list %>%
      filter(ensembl_id == !!ensembl_id) %>%
      pull(hgnc_id)

    if (length(match) > 0) {
      message(sprintf("Matched %s via Ensembl ID %s (symbol mismatch)", gene_symbol, ensembl_id))
      return(match[1])
    }
  }

  # No match found
  message(sprintf("No HGNC match for gene_symbol=%s, entrez=%s, ensembl=%s",
                  gene_symbol %||% "NA", entrez_id %||% "NA", ensembl_id %||% "NA"))
  return(NA_character_)
}
```

**Detection:**
- Warning signs: High proportion of NA hgnc_id in parsed data
- Log messages about failed symbol matches
- Compare match rate with expected genemap2 gene coverage

**Phase-specific guidance:**
- **Phase 1:** Use all available IDs (symbol, Entrez, Ensembl) for matching
- **Phase 2:** Consider using HGNChelper package for symbol updates
- **Phase 3:** Track match method (direct symbol vs. ID fallback) for quality monitoring

**Sources:**
- [HGNChelper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7856679/) - Gene symbol correction tool
- [HGNC multi-symbol checker](https://www.genenames.org/tools/multi-symbol-checker/) - Symbol validation service

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Download & Cache | Pitfall 1 (IP blocking), Pitfall 6 (cache semantics) | Implement file-based TTL cache FIRST, test with mocked responses |
| Phase 2: Phenotypes Parsing | Pitfall 3 (regex fragility), Pitfall 7 (mapping keys) | Build comprehensive test suite from real data edge cases |
| Phase 3: Gene Matching | Pitfall 8 (symbol ambiguity), Pitfall 2 (field names) | Multi-ID fallback strategy, defensive column mapping |
| Phase 4: Database Integration | Pitfall 5 (no rollback), Pitfall 4 (env vars) | Feature flag migration, test all environments |
| Phase 5: Deprecation Workflow | (See existing omim-functions.R) | Already implemented, but verify against genemap2 moved/removed entries |

---

## Testing Recommendations

### Unit Tests
- Mock genemap2.txt with edge cases:
  - Disease names containing commas, semicolons, parentheses
  - Missing mapping keys
  - Multiple phenotypes per gene (semicolon-separated)
  - Column header variations (old/new field names)
  - Empty gene symbol fields

### Integration Tests
- Download caching:
  - First call downloads, second call uses cache
  - Expired cache triggers re-download
  - Force flag bypasses cache
- API key handling:
  - Missing env var produces clear error message
  - Valid key succeeds
  - Invalid key fails with descriptive error

### Regression Tests
- Compare genemap2 output vs. JAX API output for known MIM numbers
- Ensure entity count doesn't drop unexpectedly
- Validate disease_ontology_name completeness

---

## Validation Checklist

Before deploying genemap2.txt integration:

- [ ] Cache implementation prevents excessive OMIM downloads (max 1/day)
- [ ] API key loaded from environment variable in all environments (local, Docker, CI)
- [ ] Column name mapping handles historical field variations
- [ ] Phenotypes parsing tested with real genemap2.txt edge cases
- [ ] Gene matching uses symbol + Entrez ID + Ensembl ID fallback
- [ ] Mapping key semantics documented and correctly interpreted
- [ ] Feature flag allows rollback to JAX API if needed
- [ ] Database tracks data source (genemap2 vs. jax_api)
- [ ] Error messages clearly indicate root cause (env var, parsing, API)
- [ ] Unit tests cover all identified edge cases

---

## Sources

**OMIM Official Documentation:**
- [OMIM API Documentation](https://www.omim.org/help/api)
- [OMIM Downloads Access Request](https://www.omim.org/downloads/)
- [OMIM Terms of Use](https://www.omim.org/help/agreement)
- [OMIM FAQ](https://www.omim.org/help/faq)

**R Package Documentation:**
- [httr2 req_cache Reference](https://httr2.r-lib.org/reference/req_cache.html)
- [httr secrets management](https://httr.r-lib.org/articles/secrets.html)
- [rhino secrets guide](https://appsilon.github.io/rhino/articles/how-to/manage-secrets-and-environments.html)

**Community Resources:**
- [Scout CHANGELOG](https://github.com/Clinical-Genomics/scout/blob/main/CHANGELOG.md) - Field renaming documented
- [macarthur-lab OMIM parser](https://github.com/macarthur-lab/omim) - Alternative parsing approaches
- [HGNChelper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7856679/) - Gene symbol updates

**API Design Patterns:**
- [Avoiding Backward Compatibility Breaks](https://medium.com/carvago-development/avoiding-backward-compatibility-breaks-in-api-design-a-developers-guide-b6b4d280d423)
- [Ensuring Backwards Compatibility in Distributed Systems](https://stackoverflow.blog/2020/05/13/ensuring-backwards-compatibility-in-distributed-systems/)

**Project Context:**
- SysNDD CLAUDE.md - Environment variable patterns, testing strategy
- Existing api/functions/omim-functions.R - Current mim2gene + JAX API implementation
- api/scripts/validate-jax-api.R - Rate limiting validation methodology
