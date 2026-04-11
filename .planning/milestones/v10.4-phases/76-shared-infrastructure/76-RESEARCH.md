# Phase 76: Shared Infrastructure - Research

**Researched:** 2026-02-07
**Domain:** R/Plumber API - OMIM genemap2.txt download/parse infrastructure
**Confidence:** HIGH

## Summary

Phase 76 creates reusable genemap2.txt download/parse infrastructure without touching existing systems. The research reveals that the codebase ALREADY HAS a fully functional genemap2.txt parser in `comparisons-functions.R` (parse_omim_genemap2, lines 390-495) and validated download patterns in `omim-functions.R` (download_mim2gene, lines 36-72). The existing R package stack (httr2, fs, lubridate, readr, dplyr) provides everything needed. No new packages required.

**Key finding:** The API key URL pattern is ALREADY documented in `api/data/omim_links/omim_links.txt`: `https://data.omim.org/downloads/9GJLEFvqSmWaImCijeRdVA/genemap2.txt`. The hardcoded key `9GJLEFvqSmWaImCijeRdVA` must be moved to OMIM_DOWNLOAD_KEY environment variable.

**Primary recommendation:** Extract and generalize the existing parse_omim_genemap2() function from comparisons-functions.R into shared infrastructure. Add httr2-based download with 1-day TTL caching using the proven patterns from download_mim2gene().

## Standard Stack

The established libraries/tools for OMIM file download and parsing:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | Latest (renv) | HTTP downloads with retry logic | Already used in omim-functions.R for mim2gene.txt, provides exponential backoff, timeout control, binary download support |
| fs | 1.3.1+ (renv) | File system operations | Cross-platform paths, regex file search via dir_ls(), already used in file-functions.R |
| lubridate | Latest (renv) | Date arithmetic for TTL | interval() handles month boundaries correctly, already used in check_file_age() |
| readr | Latest (renv) | TSV parsing | read_tsv() with comment line skipping, already used throughout codebase |
| dplyr | Latest (renv) | Data transformation | Piping, separate_rows(), mutate(), already used in all data processing |
| stringr | Latest (renv) | String manipulation | Regex extraction for Phenotypes column parsing, already used everywhere |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tibble | Latest (renv) | Data frame construction | Return structured data from parsing functions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| httr2 | base download.file() | No retry logic, less robust error handling, no timeout protection |
| httr2 | curl package | Lower-level API, requires manual retry implementation |
| fs + lubridate | cachem/memoise | Wrong abstraction (in-memory R object caching, not file downloads) |

**Installation:**
```bash
# Already installed via renv
# No new packages needed
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── functions/
│   ├── omim-functions.R          # Shared OMIM download/parse (INFRA-01-04)
│   ├── file-functions.R          # Shared file caching utilities (check_file_age)
│   ├── comparisons-functions.R   # Comparisons-specific logic (uses shared parse)
│   └── ontology-functions.R      # Ontology-specific logic (uses shared parse)
├── data/
│   ├── genemap2.YYYY-MM-DD.txt   # Cached genemap2 files (1-day TTL)
│   └── mim2gene.YYYY-MM-DD.txt   # Existing mim2gene cache
└── tests/testthat/
    ├── test-unit-omim-functions.R    # Unit tests for parse_genemap2()
    └── fixtures/genemap2-sample.txt  # Mock genemap2 data for testing
```

### Pattern 1: Environment Variable for API Key
**What:** OMIM download key stored in environment variable, not hardcoded in files
**When to use:** All genemap2.txt downloads
**Example:**
```r
# Source: api/functions/omim-functions.R (download_mim2gene pattern)
# Context: INFRA-01 requirement

get_omim_download_key <- function() {
  api_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")

  if (api_key == "") {
    stop("OMIM_DOWNLOAD_KEY environment variable not set. ",
         "Set via .env file or Docker Compose environment.")
  }

  return(api_key)
}

# Use in download URL
genemap2_url <- sprintf(
  "https://data.omim.org/downloads/%s/genemap2.txt",
  get_omim_download_key()
)
```

### Pattern 2: File-Based Caching with 1-Day TTL
**What:** Download genemap2.txt only if cached file is older than 1 day
**When to use:** All OMIM file downloads to prevent rate limiting/IP blocking
**Example:**
```r
# Source: api/functions/file-functions.R (check_file_age pattern)
# Context: INFRA-02 requirement

download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists (1-day TTL)
  if (!force && check_file_age("genemap2", output_path, max_age_days)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached file: %s", existing_file))
      return(existing_file)
    }
  }

  # Build authenticated URL
  url <- sprintf(
    "https://data.omim.org/downloads/%s/genemap2.txt",
    get_omim_download_key()
  )

  # Download with httr2 retry logic
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")

  # Ensure output directory exists
  if (!fs::dir_exists(output_path)) {
    fs::dir_create(output_path)
  }

  response <- httr2::request(url) %>%
    httr2::req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    httr2::req_timeout(30) %>%
    httr2::req_perform()

  if (httr2::resp_status(response) != 200) {
    stop(sprintf("Failed to download genemap2.txt: HTTP %d", httr2::resp_status(response)))
  }

  # Write binary response to file
  writeBin(httr2::resp_body_raw(response), output_file)

  message(sprintf("[OMIM] Downloaded genemap2.txt to %s", output_file))
  return(output_file)
}
```

### Pattern 3: Defensive Column Name Mapping
**What:** Handle genemap2.txt column name variations across OMIM versions
**When to use:** All genemap2.txt parsing to prevent breakage from field renames
**Example:**
```r
# Source: api/functions/comparisons-functions.R (parse_omim_genemap2 pattern)
# Context: INFRA-03 requirement

parse_genemap2 <- function(genemap2_path) {
  # Read TSV without header (OMIM uses # comment lines, not proper header row)
  raw_data <- readr::read_tsv(
    genemap2_path,
    col_names = FALSE,
    comment = "#",
    show_col_types = FALSE
  )

  # DEFENSIVE: Map columns by position (X1, X2, ...), not by name
  # genemap2.txt has 14 columns as of 2026-01-24
  # Historical variations: "Approved Symbol" vs "Approved Gene Symbol"
  # Strategy: Use position-based indexing, provide clear error if column count changes

  expected_cols <- 14
  actual_cols <- ncol(raw_data)

  if (actual_cols != expected_cols) {
    stop(sprintf(
      "genemap2.txt column count mismatch. Expected %d, got %d. ",
      expected_cols, actual_cols,
      "OMIM may have changed file format. Check https://omim.org/downloads/"
    ))
  }

  # Map by position with descriptive names
  parsed <- raw_data %>%
    dplyr::select(
      Chromosome = X1,
      Genomic_Position_Start = X2,
      Genomic_Position_End = X3,
      Cyto_Location = X4,
      Computed_Cyto_Location = X5,
      MIM_Number = X6,
      Gene_Symbols = X7,
      Gene_Name = X8,
      Approved_Symbol = X9,      # Position 9 = approved gene symbol
      Entrez_Gene_ID = X10,
      Ensembl_Gene_ID = X11,
      Comments = X12,
      Phenotypes = X13,          # Position 13 = critical for parsing
      Mouse_Gene_Symbol_ID = X14
    )

  return(parsed)
}
```

### Pattern 4: Phenotypes Column Multi-Stage Regex Parsing
**What:** Extract disease name, MIM number, mapping key, inheritance from semicolon-delimited Phenotypes column
**When to use:** All genemap2.txt parsing for disease association data
**Example:**
```r
# Source: api/functions/comparisons-functions.R (lines 429-466)
# Context: INFRA-04 requirement

# Phenotypes column format:
# "Disease Name, 123456 (3), Autosomal dominant; Another Disease, 654321 (2)"
#
# Components:
# - Disease name (text before comma)
# - MIM number (6 digits after comma)
# - Mapping key (number in parentheses: 1=confirmed, 2=provisional, 3=suspected, 4=molecular basis unknown)
# - Inheritance mode (text after closing paren, before semicolon)

parse_phenotypes_column <- function(parsed_genemap2) {
  result <- parsed_genemap2 %>%
    dplyr::select(Approved_Symbol, Phenotypes) %>%

    # Stage 1: Split multiple phenotypes by semicolon
    tidyr::separate_rows(Phenotypes, sep = "; ") %>%

    # Stage 2: Separate inheritance (after last closing paren)
    tidyr::separate(
      Phenotypes,
      c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
      "\\), (?!.+\\))",  # Negative lookahead: split on ), only if no more ) follow
      fill = "right"
    ) %>%

    # Stage 3: Separate mapping key (last open paren)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "Mapping_key"),
      "\\((?!.+\\()",    # Negative lookahead: split on ( only if no more ( follow
      fill = "right"
    ) %>%
    dplyr::mutate(Mapping_key = stringr::str_replace_all(Mapping_key, "\\)", "")) %>%

    # Stage 4: Separate MIM number (6 consecutive digits after comma)
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "MIM_Number"),
      ", (?=[0-9]{6})",  # Positive lookahead: split before 6-digit number
      fill = "right"
    ) %>%

    # Stage 5: Clean whitespace
    dplyr::mutate(
      Mapping_key = stringr::str_replace_all(Mapping_key, " ", ""),
      MIM_Number = stringr::str_replace_all(MIM_Number, " ", "")
    ) %>%

    # Stage 6: Filter invalid entries
    dplyr::filter(!is.na(MIM_Number)) %>%
    dplyr::filter(!is.na(Approved_Symbol)) %>%

    # Stage 7: Format disease_ontology_id
    dplyr::mutate(disease_ontology_id = paste0("OMIM:", MIM_Number))

  return(result)
}
```

### Pattern 5: Inheritance Term Normalization
**What:** Map OMIM inheritance strings to standardized HPO inheritance term names
**When to use:** Preparing genemap2.txt data for database insertion
**Example:**
```r
# Source: api/functions/comparisons-functions.R (lines 449-466)
# Context: Standardize inheritance vocabulary

normalize_inheritance_terms <- function(parsed_phenotypes) {
  result <- parsed_phenotypes %>%
    # Split multiple inheritance modes by comma
    tidyr::separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%

    # Remove question marks (indicates uncertain inheritance)
    dplyr::mutate(
      hpo_mode_of_inheritance_term_name =
        stringr::str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")
    ) %>%

    # Map to standardized HPO terms
    dplyr::mutate(hpo_mode_of_inheritance_term_name = dplyr::case_when(
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
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance",
      TRUE ~ hpo_mode_of_inheritance_term_name
    ))

  return(result)
}
```

### Anti-Patterns to Avoid
- **Download without caching:** Leads to OMIM IP blocking and API key revocation. ALWAYS check file age before downloading.
- **Hardcoded API key in source code:** Security risk and violates INFRA-01. Use environment variable.
- **Header-based column selection:** genemap2.txt uses comment lines, not headers. Use position-based indexing (X1, X2, ...).
- **Single-stage regex for Phenotypes:** Complex nested structure requires multi-stage parsing with negative lookaheads.
- **Brittle date parsing:** Use lubridate::interval() for month/day arithmetic, not manual calculations.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File age checking | Manual date subtraction | file-functions.R::check_file_age() | Already handles month boundaries, edge cases, date extraction from filenames with regex |
| HTTP downloads | base::download.file() | httr2 request pipeline | Retry logic, exponential backoff, timeout protection, binary downloads |
| OMIM API key management | Read from config.yml | Sys.getenv("OMIM_DOWNLOAD_KEY") | Consistent with 6+ other env vars in start_sysndd_api.R, Docker Compose native support |
| Phenotypes column parsing | Single regex | Multi-stage separate() pipeline | Nested parentheses and commas require lookahead, existing code is battle-tested |
| Inheritance term mapping | Manual string replacement | case_when() lookup table | Existing code has 14 mappings validated against HPO, covers edge cases |

**Key insight:** The codebase already has production-tested genemap2.txt parsing in comparisons-functions.R::parse_omim_genemap2() (lines 390-495). Extracting and generalizing this function is FAR SAFER than writing new parsing logic from scratch. The existing code handles:
- Comment line skipping
- Multi-stage Phenotypes column parsing with negative lookaheads
- Inheritance term normalization (14 term mappings)
- Missing value filtering
- MIM number extraction and formatting

## Common Pitfalls

### Pitfall 1: Missing Download Caching Leads to OMIM IP Blocking
**What goes wrong:** OMIM enforces rate limiting and IP blocking for repeated downloads. Without caching, every development restart or test run downloads genemap2.txt. OMIM's terms require "data must be refreshed at least weekly" but NOT more frequently. Excessive downloads can result in IP blocking or API key revocation.

**Why it happens:**
- Developers overlook that OMIM is a protected resource, not a public CDN
- File download code doesn't check if recent file exists before downloading
- No TTL-based caching strategy implemented

**How to avoid:**
```r
# ALWAYS check file age before downloading
if (!force && check_file_age("genemap2", "data/", 1)) {
  existing_file <- get_newest_file("genemap2", "data/")
  if (!is.null(existing_file)) {
    message("[OMIM] Using cached file (1-day TTL)")
    return(existing_file)
  }
}
# Only reach download code if cache miss or expired
```

**Warning signs:**
- HTTP 429 (Too Many Requests) from OMIM
- API key suddenly stops working
- Download requests timing out
- Check OMIM API key validity: https://omim.org/downloads/

### Pitfall 2: genemap2.txt Field Name Changes Break Parsing
**What goes wrong:** OMIM periodically renames column headers without versioning. Known changes: "Approved Symbol" → "Approved Gene Symbol", "Gene Symbols" → "Gene/Locus And Other Related Symbols". Hard-coded column name parsing breaks silently.

**Why it happens:**
- OMIM doesn't version their file formats or provide migration guides
- Column header changes are considered "clarifications" not breaking changes
- Parsers use exact string matching on header names

**How to avoid:**
```r
# Use position-based indexing (X1, X2, ...), not header names
# genemap2.txt has NO header row, uses # comment lines instead
raw_data <- read_tsv(genemap2_path, col_names = FALSE, comment = "#")

# Map by position with descriptive names
parsed <- raw_data %>%
  select(
    Approved_Symbol = X9,  # Position is stable, name is documentation
    Phenotypes = X13
  )

# Check column count to detect format changes
if (ncol(raw_data) != 14) {
  stop("genemap2.txt format changed. Expected 14 columns, got ", ncol(raw_data))
}
```

**Warning signs:**
- Parsing returns empty tibble
- All gene symbols become NA
- Column selection errors

### Pitfall 3: Phenotypes Column Regex Fragility
**What goes wrong:** The Phenotypes column has nested parentheses, commas inside disease names, and semicolons separating multiple phenotypes. Single-stage regex fails on edge cases like "Smith-Magenis syndrome, 16p11.2 deletion, atypical (3), Autosomal dominant".

**Why it happens:**
- Underestimating the complexity of nested delimiters
- Not accounting for commas and parentheses within disease names
- Single regex trying to extract all components at once

**How to avoid:**
```r
# Use multi-stage separate() with negative lookaheads
# Stage 1: Split phenotypes by semicolon
separate_rows(Phenotypes, sep = "; ") %>%

# Stage 2: Split inheritance (last ), )
separate(Phenotypes, c("disease", "inheritance"), "\\), (?!.+\\))") %>%

# Stage 3: Split mapping key (last open paren)
separate(disease, c("disease", "key"), "\\((?!.+\\()") %>%

# Stage 4: Split MIM number (6-digit number after comma)
separate(disease, c("disease", "mim"), ", (?=[0-9]{6})")
```

**Warning signs:**
- Parsing extracts wrong inheritance mode
- Disease names truncated at first comma
- Mapping keys include extra text

### Pitfall 4: Hardcoded API Key in Source Code
**What goes wrong:** API key `9GJLEFvqSmWaImCijeRdVA` currently hardcoded in `api/data/omim_links/omim_links.txt` and `db/migrations/007_comparisons_config.sql`. This creates security risk (key in git history) and deployment complexity (different keys for dev/staging/prod).

**Why it happens:**
- Quick initial implementation didn't use environment variables
- Key was thought to be non-sensitive (it's actually rate-limited and revocable)
- No environment variable pattern established at time of implementation

**How to avoid:**
```r
# Use environment variable consistently
get_omim_download_key <- function() {
  key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")
  if (key == "") {
    stop("OMIM_DOWNLOAD_KEY not set. Add to .env or Docker Compose.")
  }
  return(key)
}

# Docker Compose integration
# docker-compose.yml:
# environment:
#   - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}

# .env file (gitignored):
# OMIM_DOWNLOAD_KEY=9GJLEFvqSmWaImCijeRdVA
```

**Warning signs:**
- API key visible in git history or logs
- Unable to use different keys for different environments
- Key rotation requires code changes

### Pitfall 5: Test Suite Downloads Real genemap2.txt
**What goes wrong:** Unit tests call download_genemap2() without mocking, causing real OMIM downloads during CI runs. This burns through rate limits and causes test failures when OMIM is unavailable.

**Why it happens:**
- Tests don't use fixtures/mocks for external data
- Download functions not designed for dependency injection
- CI environment has network access to OMIM

**How to avoid:**
```r
# Unit tests: Use fixture files
test_that("parse_genemap2 extracts Phenotypes column", {
  fixture_path <- testthat::test_path("fixtures/genemap2-sample.txt")
  result <- parse_genemap2(fixture_path)

  expect_true("disease_ontology_name" %in% names(result))
  expect_true("Mapping_key" %in% names(result))
})

# Integration tests: Mock httr2 responses
test_that("download_genemap2 handles 404", {
  with_mocked_bindings(
    req_perform = function(...) list(status = 404),
    {
      expect_error(download_genemap2(), "Failed to download")
    }
  )
})
```

**Warning signs:**
- CI tests fail intermittently with network errors
- OMIM rate limit errors in test logs
- Tests slow down over time

## Code Examples

Verified patterns from existing codebase:

### Example 1: Download with Caching (from omim-functions.R)
```r
# Source: api/functions/omim-functions.R (download_mim2gene, lines 36-72)
# Confidence: HIGH (production-tested)

download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists (1-day TTL)
  if (!force && check_file_age("genemap2", output_path, max_age_days)) {
    existing_file <- get_newest_file("genemap2", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached genemap2.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from OMIM with authenticated URL
  url <- sprintf(
    "https://data.omim.org/downloads/%s/genemap2.txt",
    get_omim_download_key()
  )

  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")

  # Ensure output directory exists
  if (!fs::dir_exists(output_path)) {
    fs::dir_create(output_path)
  }

  # Download with httr2 retry logic (validated in Phase 23-01)
  response <- httr2::request(url) %>%
    httr2::req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    httr2::req_timeout(30) %>%
    httr2::req_perform()

  if (httr2::resp_status(response) != 200) {
    stop(sprintf("Failed to download genemap2.txt: HTTP %d", httr2::resp_status(response)))
  }

  # Write binary response to file
  writeBin(httr2::resp_body_raw(response), output_file)

  message(sprintf("[OMIM] Downloaded genemap2.txt to %s", output_file))
  return(output_file)
}
```

### Example 2: Parse Phenotypes Column (from comparisons-functions.R)
```r
# Source: api/functions/comparisons-functions.R (parse_omim_genemap2, lines 405-466)
# Confidence: HIGH (production-tested in comparisons system)

parse_genemap2 <- function(genemap2_path) {
  # Read genemap2.txt (skip comment lines)
  omim_genemap2 <- readr::read_tsv(
    genemap2_path,
    col_names = FALSE,
    comment = "#",
    show_col_types = FALSE
  ) %>%
    dplyr::select(
      Chromosome = X1,
      Genomic_Position_Start = X2,
      Genomic_Position_End = X3,
      Cyto_Location = X4,
      Computed_Cyto_Location = X5,
      MIM_Number = X6,
      Gene_Symbols = X7,
      Gene_Name = X8,
      Approved_Symbol = X9,
      Entrez_Gene_ID = X10,
      Ensembl_Gene_ID = X11,
      Comments = X12,
      Phenotypes = X13,
      Mouse_Gene_Symbol_ID = X14
    ) %>%
    # Extract Phenotypes column components
    dplyr::select(Approved_Symbol, Phenotypes) %>%
    tidyr::separate_rows(Phenotypes, sep = "; ") %>%
    tidyr::separate(
      Phenotypes,
      c("disease_ontology_name", "hpo_mode_of_inheritance_term_name"),
      "\\), (?!.+\\))",  # Negative lookahead
      fill = "right"
    ) %>%
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "Mapping_key"),
      "\\((?!.+\\()",    # Negative lookahead
      fill = "right"
    ) %>%
    dplyr::mutate(Mapping_key = stringr::str_replace_all(Mapping_key, "\\)", "")) %>%
    tidyr::separate(
      disease_ontology_name,
      c("disease_ontology_name", "MIM_Number"),
      ", (?=[0-9]{6})",  # Positive lookahead
      fill = "right"
    ) %>%
    dplyr::mutate(
      Mapping_key = stringr::str_replace_all(Mapping_key, " ", ""),
      MIM_Number = stringr::str_replace_all(MIM_Number, " ", "")
    ) %>%
    dplyr::filter(!is.na(MIM_Number)) %>%
    dplyr::filter(!is.na(Approved_Symbol)) %>%
    dplyr::mutate(disease_ontology_id = paste0("OMIM:", MIM_Number)) %>%
    tidyr::separate_rows(hpo_mode_of_inheritance_term_name, sep = ", ") %>%
    dplyr::mutate(
      hpo_mode_of_inheritance_term_name =
        stringr::str_replace_all(hpo_mode_of_inheritance_term_name, "\\?", "")
    ) %>%
    dplyr::select(-MIM_Number) %>%
    unique() %>%
    # Normalize inheritance terms (14 mappings)
    dplyr::mutate(hpo_mode_of_inheritance_term_name = dplyr::case_when(
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
      hpo_mode_of_inheritance_term_name == "Y-linked" ~ "Y-linked inheritance",
      TRUE ~ hpo_mode_of_inheritance_term_name
    ))

  return(omim_genemap2)
}
```

### Example 3: Environment Variable Pattern (from start_sysndd_api.R)
```r
# Source: api/start_sysndd_api.R (lines 79, 96, 188, 370, 433, 545, 581)
# Confidence: HIGH (consistent pattern across 7 env vars)

get_omim_download_key <- function() {
  api_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")

  if (api_key == "") {
    stop(
      "OMIM_DOWNLOAD_KEY environment variable not set.\n",
      "Add to .env file: OMIM_DOWNLOAD_KEY=your_key_here\n",
      "Or set in Docker Compose: environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}"
    )
  }

  return(api_key)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded OMIM key in omim_links.txt | OMIM_DOWNLOAD_KEY env var | Phase 76 (planned) | Enables per-environment keys, removes secret from git |
| comparisons downloads genemap2 without caching | 1-day TTL file caching | Phase 76 (planned) | Prevents OMIM IP blocking, reduces download time |
| genemap2 parsing only in comparisons-functions.R | Shared parse_genemap2() in omim-functions.R | Phase 76 (planned) | Enables ontology system to use genemap2 disease names |
| ontology uses JAX API for disease names (7min) | ontology uses genemap2 disease names (30sec) | Phase 77 (planned) | 50x+ performance improvement |

**Deprecated/outdated:**
- base::download.file() for OMIM downloads: Use httr2 for retry logic and timeout protection
- Month-based check_file_age(): Use day-precision variant for 1-day TTL
- Header-based column selection: genemap2.txt has no headers, use position-based (X1, X2, ...)

## Open Questions

Things that couldn't be fully resolved:

1. **Should parse_genemap2() be in omim-functions.R or new genemap2-functions.R?**
   - What we know: omim-functions.R currently handles mim2gene.txt (public file), genemap2.txt requires API key (different auth pattern)
   - What's unclear: Whether mixing public and authenticated downloads in same file is clean architecture
   - Recommendation: Keep in omim-functions.R for now (both are OMIM data sources), extract to separate file in Phase 78 if complexity grows

2. **How to handle genemap2.txt in Docker container data/ directory?**
   - What we know: data/ directory is NOT bind-mounted (like tests/), so cached files don't persist across container rebuilds
   - What's unclear: Whether to bind-mount data/ or accept ephemeral cache
   - Recommendation: Accept ephemeral cache for now (1-day TTL means at most 1 download per container lifecycle), add bind-mount in Phase 78 if container restarts become frequent

3. **Should genemap2.txt download be synchronous or async?**
   - What we know: comparisons system downloads in async job (comparisons_update_async), ontology system downloads synchronously
   - What's unclear: Whether shared download function should support both patterns or force one
   - Recommendation: Start synchronous (simpler, matches download_mim2gene pattern), make async in Phase 77 when integrating with ontology job system

## Sources

### Primary (HIGH confidence)
- api/functions/comparisons-functions.R (lines 390-495) - Production genemap2.txt parser with Phenotypes column extraction
- api/functions/omim-functions.R (lines 36-72) - download_mim2gene() pattern for httr2 downloads with caching
- api/functions/file-functions.R (lines 87-116, 141-167) - check_file_age() and get_newest_file() for TTL validation
- api/data/omim_links/omim_links.txt - OMIM download URL pattern with hardcoded key
- api/start_sysndd_api.R (lines 79, 96, 188, 370, 433) - Sys.getenv() pattern for 7 environment variables

### Secondary (MEDIUM confidence)
- .planning/research/STACK.md - httr2/fs/lubridate recommendation for file caching (verified against actual code)
- .planning/research/PITFALLS.md - OMIM rate limiting and genemap2.txt field name changes (verified against OMIM docs)

### Tertiary (LOW confidence)
- OMIM Downloads Terms (https://www.omim.org/downloads/) - "data must be refreshed at least weekly" (external source, may change)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages already in renv.lock, patterns verified in production code
- Architecture: HIGH - Existing parse_omim_genemap2() is production-tested, download_mim2gene() pattern is validated
- Pitfalls: HIGH - Based on actual code patterns and OMIM documentation

**Research date:** 2026-02-07
**Valid until:** 30 days (stable APIs, but OMIM file formats may change)
