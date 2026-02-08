# Technology Stack: OMIM File Download Caching

**Project:** SysNDD OMIM Optimization
**Researched:** 2026-02-07
**Confidence:** HIGH

## Executive Summary

No new packages required. The existing R stack (httr2 + fs + lubridate) already provides everything needed for OMIM file download caching with 1-day TTL. The codebase has validated patterns from `omim-functions.R` and `file-functions.R` that can be unified and enhanced.

**Key finding:** The project already uses date-stamped filenames (`mim2gene.YYYY-MM-DD.txt`) and `check_file_age()` for age-based validation. This pattern should be extended to all OMIM downloads with consistent 1-day TTL.

## Recommended Stack

### Core Dependencies (Already Installed)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| httr2 | Latest (renv) | HTTP downloads | Modern retry logic, timeout control, already used in `omim-functions.R` |
| fs | Latest (renv) | File system ops | Cross-platform paths, already used in `file-functions.R` |
| lubridate | Latest (renv) | Date arithmetic | TTL validation with `interval()`, already used in `check_file_age()` |

### No New Dependencies Required

The existing stack is sufficient. Do NOT add:
- ❌ `cachem` — Designed for in-memory/disk caching of R objects, not file downloads
- ❌ `memoise` — Same as cachem, wrong abstraction layer
- ❌ `curl` — Lower-level than httr2, no retry logic
- ❌ Base `download.file()` — No retry logic, less robust than httr2

## Implementation Pattern

### File Download with Caching (httr2)

**Use httr2 over base download.file():**

```r
# Good: httr2 with retry logic
download_omim_file <- function(url, output_path, api_key, force = FALSE) {
  # Check cache age
  if (!force && check_file_age("genemap2", "data/", 1)) {
    return(get_newest_file("genemap2", "data/"))
  }

  # Build authenticated URL
  auth_url <- str_replace(url, "OMIM_DOWNLOAD_KEY", api_key)

  # Download with httr2
  response <- request(auth_url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  # Save to date-stamped file
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "genemap2.", current_date, ".txt")
  writeBin(resp_body_raw(response), output_file)

  return(output_file)
}
```

**Why httr2:**
- ✅ Exponential backoff retry (validated in Phase 23-01)
- ✅ Timeout protection (30s default)
- ✅ Binary download support (`resp_body_raw()`)
- ✅ Already used in `omim-functions.R` for mim2gene.txt
- ✅ Consistent error handling across codebase

### File Age Validation (fs + lubridate)

**Existing pattern from `file-functions.R`:**

```r
# Already exists, works correctly
check_file_age <- function(file_basename, folder, months) {
  pattern <- paste0(file_basename, "\\.\\d{4}-\\d{2}-\\d{2}")
  files <- dir_ls(folder, regexp = pattern)

  if (length(files) == 0) {
    return(FALSE)  # No cached file exists
  }

  dates <- str_extract(files, "\\d{4}-\\d{2}-\\d{2}")
  newest_date <- max(as.Date(dates), na.rm = TRUE)
  current_date <- Sys.Date()

  time_diff <- interval(newest_date, current_date) / months(1)
  return(time_diff < months)
}
```

**Enhancement for 1-day TTL:**

```r
# Add day-precision variant
check_file_age_days <- function(file_basename, folder, days) {
  pattern <- paste0(file_basename, "\\.\\d{4}-\\d{2}-\\d{2}")
  files <- dir_ls(folder, regexp = pattern)

  if (length(files) == 0) {
    return(FALSE)
  }

  dates <- str_extract(files, "\\d{4}-\\d{2}-\\d{2}")
  newest_date <- max(as.Date(dates), na.rm = TRUE)
  current_date <- Sys.Date()

  time_diff <- as.numeric(current_date - newest_date)
  return(time_diff < days)
}
```

**Why fs + lubridate:**
- ✅ `fs::dir_ls()` with regex is fast and cross-platform
- ✅ `lubridate::interval()` handles edge cases (month boundaries)
- ✅ Date extraction from filename is already battle-tested
- ✅ Consistent with existing `omim-functions.R` pattern

### Environment Variable Pattern

**Existing pattern from `start_sysndd_api.R`:**

```r
# Good: Sys.getenv() with default
api_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")

if (api_key == "") {
  stop("OMIM_DOWNLOAD_KEY environment variable not set")
}
```

**Integration points:**
- Docker Compose: `environment: - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}`
- `.env` file: `OMIM_DOWNLOAD_KEY=9GJLEFvqSmWaImCijeRdVA`
- CI: GitHub Actions secrets

**Why Sys.getenv():**
- ✅ Base R, no dependencies
- ✅ Already used for 7 other env vars (MIRAI_WORKERS, CACHE_VERSION, etc.)
- ✅ Consistent with project patterns
- ✅ Docker Compose native support

## OMIM File Formats

### Files and Their Purposes

| File | Auth Required | Size | Update Frequency | Purpose |
|------|---------------|------|------------------|---------|
| mim2gene.txt | No (public) | ~500 KB | Weekly | MIM→gene mapping, entry types |
| genemap2.txt | Yes (key) | ~5 MB | Weekly | Disease names, phenotypes, MOI |
| mimTitles.txt | Yes (key) | ~2 MB | Weekly | MIM titles (alternative to genemap2) |
| morbidmap.txt | Yes (key) | ~1 MB | Weekly | Legacy format (not recommended) |

### Recommended Files for SysNDD

**Primary:**
- `genemap2.txt` — Contains disease names, phenotypes, inheritance, all needed for ontology system

**Secondary:**
- `mim2gene.txt` — Already used, continue using for entry types and deprecation detection

**Not needed:**
- `mimTitles.txt` — Redundant if using genemap2.txt
- `morbidmap.txt` — Legacy format, genemap2.txt is superior

### Download URLs

```r
# Public (no auth)
mim2gene_url <- "https://omim.org/static/omim/data/mim2gene.txt"

# Requires OMIM_DOWNLOAD_KEY
genemap2_url <- paste0(
  "https://data.omim.org/downloads/",
  Sys.getenv("OMIM_DOWNLOAD_KEY"),
  "/genemap2.txt"
)
```

## Integration with Existing Stack

### Unification Points

**Current state:**
1. Ontology system uses `omim-functions.R` (mim2gene.txt + JAX API)
2. Comparisons system uses `comparisons-functions.R` (genemap2.txt parsing)

**After OMIM overhaul:**
1. Both systems use unified `omim-functions.R` (mim2gene.txt + genemap2.txt)
2. Shared caching via enhanced `file-functions.R`
3. Shared parsing utilities (already exists in `comparisons-functions.R`)

### Existing Patterns to Reuse

From `comparisons-functions.R` (lines 390-495):
```r
parse_omim_genemap2 <- function(genemap2_path, phenotype_hpoa_path) {
  # Already parses genemap2.txt with disease names
  # Already handles inheritance mapping
  # Already filters for NDD phenotypes
}
```

From `omim-functions.R` (lines 36-72):
```r
download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_months = 1) {
  # Already checks file age
  # Already uses httr2 with retry
  # Already uses date-stamped filenames
}
```

**Action:** Generalize the download pattern to work for all OMIM files.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| HTTP client | httr2 | base download.file() | No retry logic, less robust error handling |
| HTTP client | httr2 | curl | Lower-level, httr2 provides better abstractions |
| Caching strategy | Date-stamped files | cachem disk cache | Wrong abstraction (for R objects, not files) |
| TTL validation | lubridate intervals | difftime() | Works, but lubridate handles edge cases better |
| Auth pattern | Env var (OMIM_DOWNLOAD_KEY) | Config file | Already use env vars for 7+ settings |

## Installation

No installation needed. All packages already in renv.lock:

```r
# Verify availability (these should all pass)
stopifnot(requireNamespace("httr2"))
stopifnot(requireNamespace("fs"))
stopifnot(requireNamespace("lubridate"))
stopifnot(requireNamespace("readr"))
stopifnot(requireNamespace("stringr"))
```

## Configuration

### Environment Variables

Add to `.env` (not in git):
```bash
OMIM_DOWNLOAD_KEY=9GJLEFvqSmWaImCijeRdVA
```

Add to `docker-compose.yml`:
```yaml
services:
  api:
    environment:
      - OMIM_DOWNLOAD_KEY=${OMIM_DOWNLOAD_KEY}
```

Add to GitHub Actions (if needed for CI):
```yaml
env:
  OMIM_DOWNLOAD_KEY: ${{ secrets.OMIM_DOWNLOAD_KEY }}
```

### Cache Directory Structure

```
data/
├── mim2gene.2026-02-07.txt
├── genemap2.2026-02-07.txt
└── (old files cleaned up manually or via cron)
```

**TTL enforcement:** Check `Sys.Date()` vs file date, re-download if ≥1 day old.

## Migration Path

### Phase 1: Add Env Var Support
1. Add `OMIM_DOWNLOAD_KEY` to environment
2. Update `omim-functions.R` to read env var
3. Keep existing JAX API as fallback

### Phase 2: Add genemap2.txt Download
1. Generalize `download_mim2gene()` to `download_omim_file()`
2. Add `download_genemap2()` wrapper
3. Implement 1-day TTL caching

### Phase 3: Replace JAX API
1. Add genemap2.txt parsing to `omim-functions.R`
2. Replace `fetch_all_disease_names()` calls
3. Remove JAX API dependency

### Phase 4: Unify Comparisons
1. Update comparisons system to use shared OMIM functions
2. Remove duplicate genemap2.txt parsing from `comparisons-functions.R`
3. Both systems now share same OMIM data source

## Sources

- **httr2 documentation:** https://httr2.r-lib.org/ (HIGH confidence)
- **Existing codebase patterns:** `api/functions/omim-functions.R` (HIGH confidence)
- **Existing codebase patterns:** `api/functions/file-functions.R` (HIGH confidence)
- **Existing codebase patterns:** `api/functions/comparisons-functions.R` (HIGH confidence)
- **OMIM download documentation:** https://omim.org/downloads (MEDIUM confidence, based on existing URLs in codebase)
- **Environment variable pattern:** `api/start_sysndd_api.R` lines 79, 96, 188, 370, 433, 545 (HIGH confidence)
