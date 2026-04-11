# Phase 79: Configuration & Cleanup - Research

**Researched:** 2026-02-07
**Domain:** Configuration management, dead code removal, documentation
**Confidence:** HIGH

## Summary

Phase 79 completes the v10.4 OMIM migration by removing deprecated JAX API code, externalizing the hardcoded OMIM download key to an environment variable, unifying mim2gene.txt caching with Phase 76's shared infrastructure, and updating documentation. This is a cleanup phase with clear patterns established in the codebase.

The codebase already demonstrates strong environment variable practices (ENVIRONMENT, DB_POOL_SIZE, MIRAI_WORKERS, GEMINI_API_KEY, CORS_ALLOWED_ORIGINS) with consistent Sys.getenv() usage and default values. Docker Compose uses the environment section for direct variable passing from .env files, which is the project's established pattern. The existing .env.example provides well-structured documentation with comments, section headers, and security notes.

The JAX API functions (fetch_jax_disease_name, fetch_all_disease_names) are isolated in omim-functions.R and have clear call sites that can be traced with standard grep. The hardcoded OMIM key appears in omim_links.txt and must be replaced with dynamic URL construction using the OMIM_DOWNLOAD_KEY environment variable.

Research confirms that mim2gene.txt is publicly accessible without authentication (unique among OMIM files), while genemap2.txt requires the download key. The Phase 76 shared infrastructure (check_file_age_days, get_newest_file) provides the caching pattern that should be extended to mim2gene.txt.

**Primary recommendation:** Follow the established Sys.getenv() pattern with default values, use Docker Compose's environment section for variable passing, document OMIM_DOWNLOAD_KEY in .env.example with registration URL, aggressively remove all JAX-related code using grep-based tracing, and unify mim2gene.txt caching with the existing check_file_age_days pattern.

## Standard Stack

The established libraries/tools for configuration cleanup:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| base R | 4.x | Sys.getenv() for env vars | Native R function, no dependencies, used throughout codebase |
| Docker Compose | v2 | Environment variable passing | Project standard, documented in docker-compose.yml |
| grep/ripgrep | System | Dead code tracing | Fast, reliable, works with R's function syntax |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| git grep | Code search within repo | Finding function references, import statements |
| lintr | Static analysis | Detecting unused variables (optional verification) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sys.getenv() | config package | Overkill for simple env vars, adds dependency |
| environment section | env_file attribute | Less explicit, harder to trace variable sources |
| grep | CodeDepends/checkglobals | Slower, requires R package installation, overkill for simple function tracing |

**Installation:**
```bash
# No new packages needed - all tools already available
```

## Architecture Patterns

### Recommended Project Structure
```
.env.example                          # Template with OMIM_DOWNLOAD_KEY documented
docker-compose.yml                    # Environment section references ${OMIM_DOWNLOAD_KEY}
api/
├── functions/
│   ├── omim-functions.R             # Remove JAX functions, keep genemap2/mim2gene
│   └── file-functions.R             # Existing caching infrastructure
├── data/
│   └── omim_links/
│       └── omim_links.txt           # DELETE - hardcoded key removal
└── tests/testthat/
    └── test-unit-omim-functions.R   # Remove JAX tests, add mim2gene caching test
```

### Pattern 1: Environment Variable Validation at Startup
**What:** Validate required environment variables when they're first accessed, providing clear error messages
**When to use:** All environment variables that are required for specific features (lazy validation)
**Example:**
```r
# Source: api/functions/omim-functions.R (get_omim_download_key, lines 95-105)
# Existing pattern used in codebase

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

**Rationale:** Lazy validation (fail when feature is used) is appropriate for OMIM_DOWNLOAD_KEY because:
1. Not all deployments use OMIM features
2. The key is only needed when genemap2.txt downloads occur
3. Clear error messages guide users to fix the configuration
4. Matches existing patterns for optional features (GEMINI_API_KEY)

**Contrast with startup validation:** Variables like ENVIRONMENT, DB_POOL_SIZE are validated at startup because they're required for basic API operation.

### Pattern 2: Docker Compose Environment Variable Passing
**What:** Use environment section with ${VAR} interpolation from .env file
**When to use:** All environment variables in docker-compose.yml
**Example:**
```yaml
# Source: docker-compose.yml (lines 154-164)
# Existing pattern used in codebase

services:
  api:
    environment:
      ENVIRONMENT: production
      PASSWORD: ${PASSWORD}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      DB_POOL_SIZE: ${DB_POOL_SIZE:-5}
      MIRAI_WORKERS: ${MIRAI_WORKERS:-2}
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-}
      CACHE_VERSION: ${CACHE_VERSION:-1}
      OMIM_DOWNLOAD_KEY: ${OMIM_DOWNLOAD_KEY}  # ADD THIS
```

**Why this pattern:**
1. Explicit variable listing (easy to audit which vars are passed)
2. Default values visible in Compose file (${VAR:-default})
3. .env file drives all values (single source of truth)
4. Precedence clear: docker compose run -e > environment section > .env

**Best practice from Docker docs:** Use environment section for direct variable passing rather than env_file attribute for better transparency.

### Pattern 3: .env.example Documentation
**What:** Document each environment variable with purpose, format, and where to obtain values
**When to use:** All environment variables, especially API keys and secrets
**Example:**
```bash
# Source: .env.example (lines 60-65 GEMINI_API_KEY pattern)
# Best practice: comment above variable, URL for registration, purpose

# -----------------------------------------------------------------------------
# OMIM Configuration (Phase 79)
# -----------------------------------------------------------------------------
# OMIM download key for authenticated access to genemap2.txt
# Required for: OMIM ontology updates, disease comparisons
# Get your key at: https://www.omim.org/downloads/
# After registration, use the key from your download URLs

OMIM_DOWNLOAD_KEY=your_omim_download_key_here
```

**Documentation best practices:**
1. Section headers for grouping related variables
2. Purpose/use case ("Required for: X, Y")
3. Registration URL for API keys
4. Placeholder values matching expected format
5. Security notes at end of file (already present)

### Pattern 4: Dynamic URL Construction
**What:** Build URLs at runtime using environment variables instead of hardcoded keys in config files
**When to use:** All authenticated API endpoints
**Example:**
```r
# Source: api/functions/omim-functions.R (download_genemap2 pattern)

# BEFORE (hardcoded in omim_links.txt):
# https://data.omim.org/downloads/9GJLEFvqSmWaImCijeRdVA/genemap2.txt

# AFTER (dynamic construction):
download_genemap2 <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  api_key <- get_omim_download_key()
  url <- sprintf("https://data.omim.org/downloads/%s/genemap2.txt", api_key)
  # ... rest of download logic
}

# Same pattern for other authenticated files:
download_mimtitles <- function(...) {
  api_key <- get_omim_download_key()
  url <- sprintf("https://data.omim.org/downloads/%s/mimTitles.txt", api_key)
}
```

**Key insight:** URL construction must happen in code, not static config files. This allows:
1. Environment-specific keys (dev vs production)
2. Key rotation without file edits
3. No secrets in version control

### Pattern 5: Unified File Caching
**What:** Reuse check_file_age_days() and get_newest_file() for all dated file downloads
**When to use:** Any file download with date-stamped caching pattern (filename.YYYY-MM-DD.ext)
**Example:**
```r
# Source: api/functions/omim-functions.R (download_genemap2, lines 144-186)
# Extend this pattern to download_mim2gene

download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists using shared infrastructure
  if (!force && check_file_age_days("mim2gene", output_path, max_age_days)) {
    existing_file <- get_newest_file("mim2gene", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached mim2gene.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from OMIM (public URL, no auth)
  url <- "https://omim.org/static/omim/data/mim2gene.txt"
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "mim2gene.", current_date, ".txt")

  # ... httr2 download logic (same as genemap2)
}
```

**Why unify:** download_mim2gene (lines 36-72) uses the OLDER pattern with check_file_age (months precision), while download_genemap2 uses check_file_age_days (days precision). Unifying to days precision provides:
1. Consistent caching behavior across all OMIM files
2. 1-day TTL matches OMIM's nightly update schedule
3. Less code duplication

### Anti-Patterns to Avoid

- **Hardcoded secrets in config files:** Never store API keys in files committed to git (omim_links.txt must be deleted)
- **env_file without explicit environment section:** Harder to audit which variables are passed to containers
- **Startup validation for optional features:** OMIM_DOWNLOAD_KEY should fail when used, not at API startup (lazy validation)
- **Mixed caching patterns:** Don't use check_file_age (months) for some files and check_file_age_days (days) for others
- **Leaving dead code commented out:** Delete it completely (git history preserves it)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Function dependency tracing | Custom AST parser | grep/ripgrep with pattern matching | R function syntax is simple (function_name <- function), grep is fast and reliable |
| Environment variable validation | Custom validator | Sys.getenv() with default values and stop() | Native R, clear error messages, matches codebase patterns |
| File age checking | Custom date logic | check_file_age_days from file-functions.R | Already handles edge cases (no file, multiple files, date parsing) |
| Dead code detection | lintr/checkglobals packages | Manual grep + test suite verification | Static analysis tools have false positives, grep is definitive for this codebase |

**Key insight:** For configuration cleanup, simple tools (grep, Sys.getenv) are more reliable than complex static analysis. The test suite provides the safety net for detecting broken dependencies.

## Common Pitfalls

### Pitfall 1: Incomplete Dead Code Removal
**What goes wrong:** Removing a function but missing test files, imports, or indirect callers leaves orphaned code
**Why it happens:** Function references span multiple files (tests, imports, documentation)
**How to avoid:**
1. Use multiple grep patterns: exact function name, function definition pattern, test file naming convention
2. Check for indirect calls (functions passed as arguments, used in lapply/map)
3. Run full test suite after removal to catch broken references
**Warning signs:** Tests fail with "object 'function_name' not found" or "could not find function"

**Comprehensive grep strategy:**
```bash
# 1. Direct function calls
grep -r "fetch_jax_disease_name" api/

# 2. Function definitions
grep -r "fetch_jax_disease_name <- function" api/

# 3. Test files
grep -r "test.*jax" api/tests/

# 4. Higher-order usage (function passed as argument)
grep -r "fetch.*jax.*disease.*name" api/

# 5. Documentation references
grep -r "fetch.*jax.*disease.*name" .planning/
```

### Pitfall 2: Environment Variable Name Inconsistency
**What goes wrong:** Variable named OMIM_API_KEY in .env.example but checked as OMIM_DOWNLOAD_KEY in code
**Why it happens:** Copy-paste from other API key patterns without updating names
**How to avoid:**
1. Use exact same name in .env.example, docker-compose.yml, and Sys.getenv()
2. Search for all references to verify consistency
3. Use descriptive names that match OMIM's terminology ("download key" not "API key")
**Warning signs:** Code stops with "environment variable not set" despite .env being configured

**Verification checklist:**
- [ ] .env.example: OMIM_DOWNLOAD_KEY=...
- [ ] docker-compose.yml: OMIM_DOWNLOAD_KEY: ${OMIM_DOWNLOAD_KEY}
- [ ] R code: Sys.getenv("OMIM_DOWNLOAD_KEY", "")
- [ ] Error message references: "OMIM_DOWNLOAD_KEY"

### Pitfall 3: Breaking Deprecation Tracking
**What goes wrong:** Removing mim2gene.txt download breaks the deprecation detection workflow
**Why it happens:** Misunderstanding that mim2gene is still needed even though JAX API is removed
**How to avoid:**
1. Read CONTEXT.md carefully - "Keep mim2gene.txt download for deprecation tracking"
2. Understand that mim2gene provides moved/removed entry detection (authoritative source)
3. Only remove JAX API functions, not the mim2gene parsing/download
**Warning signs:** check_entities_for_deprecation function references missing data

**Keep these mim2gene functions:**
- download_mim2gene() - needed for deprecation tracking
- parse_mim2gene() - extracts moved/removed entries
- get_deprecated_mim_numbers() - flags deprecated entries
- check_entities_for_deprecation() - database check

**Remove only JAX functions:**
- fetch_jax_disease_name() - replaced by genemap2 parsing
- fetch_all_disease_names() - replaced by genemap2 parsing

### Pitfall 4: Deleting Wrong Migration File
**What goes wrong:** Running a database migration to remove comparisons_config row instead of just code cleanup
**Why it happens:** Confusion about "migration" term (code migration vs database migration)
**How to avoid:**
1. CONTEXT.md explicitly states: "Code-only cleanup for comparisons_config migration"
2. Don't create new .sql files in db/migrations/
3. Just update comparisons-functions.R to not insert omim_genemap2 row
**Warning signs:** New migration file created when it shouldn't be

**Correct approach:**
- Edit comparisons-functions.R to remove omim_genemap2 handling
- No database migration needed (existing deployments keep old row harmlessly)
- Manual removal possible via SQL if operators want to clean database

## Code Examples

Verified patterns from official sources and existing codebase:

### Environment Variable Access Pattern
```r
# Source: api/start_sysndd_api.R (lines 79, 188, 433, 545)
# Pattern: Sys.getenv with default value and type conversion

# Simple with default
env_mode <- Sys.getenv("ENVIRONMENT", "local")

# Integer with default and validation
pool_size <- as.integer(Sys.getenv("DB_POOL_SIZE", "5"))
if (is.na(pool_size)) pool_size <- 5L
pool_size <- max(1L, min(pool_size, 20L))

# Optional value (empty string default)
api_key <- Sys.getenv("GEMINI_API_KEY", "")

# Required value (error if missing)
omim_key <- Sys.getenv("OMIM_DOWNLOAD_KEY", "")
if (omim_key == "") {
  stop("OMIM_DOWNLOAD_KEY environment variable not set")
}
```

### Docker Compose Environment Section
```yaml
# Source: docker-compose.yml (lines 154-164)
# Pattern: environment section with ${VAR:-default} interpolation

services:
  api:
    environment:
      ENVIRONMENT: production
      PASSWORD: ${PASSWORD}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      DB_POOL_SIZE: ${DB_POOL_SIZE:-5}
      MIRAI_WORKERS: ${MIRAI_WORKERS:-2}
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-}
      CACHE_VERSION: ${CACHE_VERSION:-1}
      # Phase 79: Add OMIM download key
      OMIM_DOWNLOAD_KEY: ${OMIM_DOWNLOAD_KEY}
```

### .env.example Documentation Pattern
```bash
# Source: .env.example (lines 60-65)
# Pattern: Section header, comment block, variable with placeholder

# -----------------------------------------------------------------------------
# OMIM Configuration (Phase 79)
# -----------------------------------------------------------------------------
# OMIM download key for authenticated access to genemap2.txt
# Required for: OMIM ontology updates, disease comparisons
# Get your key at: https://www.omim.org/downloads/
# After registration, use the key from your download URLs
# Format: 22-character alphanumeric string

OMIM_DOWNLOAD_KEY=your_omim_download_key_here
```

### Unified Caching Pattern
```r
# Source: api/functions/omim-functions.R (download_genemap2, lines 144-186)
# Pattern: check_file_age_days + get_newest_file + httr2 download

download_mim2gene <- function(output_path = "data/", force = FALSE, max_age_days = 1) {
  # Check if recent file exists
  if (!force && check_file_age_days("mim2gene", output_path, max_age_days)) {
    existing_file <- get_newest_file("mim2gene", output_path)
    if (!is.null(existing_file)) {
      message(sprintf("[OMIM] Using cached mim2gene.txt: %s", existing_file))
      return(existing_file)
    }
  }

  # Download from OMIM (public URL, no authentication)
  url <- "https://omim.org/static/omim/data/mim2gene.txt"
  current_date <- format(Sys.Date(), "%Y-%m-%d")
  output_file <- paste0(output_path, "mim2gene.", current_date, ".txt")

  # Ensure output directory exists
  if (!dir_exists(output_path)) {
    dir_create(output_path)
  }

  # Download with retry logic
  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_perform()

  if (resp_status(response) != 200) {
    stop(sprintf("Failed to download mim2gene.txt: HTTP %d", resp_status(response)))
  }

  # Write to file
  writeBin(resp_body_raw(response), output_file)
  message(sprintf("[OMIM] Downloaded mim2gene.txt to %s", output_file))

  return(output_file)
}
```

### Test Pattern for Caching
```r
# Pattern: Verify caching works through unified infrastructure

test_that("download_mim2gene uses 1-day TTL caching", {
  skip_if_offline()

  temp_dir <- tempdir()

  # First download
  file1 <- download_mim2gene(output_path = temp_dir, force = TRUE)
  expect_true(file.exists(file1))
  expect_match(file1, "mim2gene\\.\\d{4}-\\d{2}-\\d{2}\\.txt")

  # Second call should use cache
  file2 <- download_mim2gene(output_path = temp_dir, force = FALSE)
  expect_equal(file1, file2)  # Same file returned

  # Verify check_file_age_days is working
  expect_true(check_file_age_days("mim2gene", temp_dir, max_age_days = 1))
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JAX Ontology API for disease names | genemap2.txt Phenotypes column | Phase 77-78 (Feb 2026) | 50x faster, no API rate limits, no ~18% missing names |
| Hardcoded API key in omim_links.txt | OMIM_DOWNLOAD_KEY environment variable | Phase 76-79 (Feb 2026) | Security improvement, easier key rotation, no secrets in git |
| check_file_age (months) for caching | check_file_age_days (days) for OMIM files | Phase 76 (Feb 2026) | 1-day TTL matches OMIM nightly updates, more precise control |
| Two separate parsers (comparisons vs ontology) | Shared parse_genemap2() infrastructure | Phase 76 (Feb 2026) | Single source of truth, easier maintenance |

**Deprecated/outdated:**
- fetch_jax_disease_name: Remove completely (Phase 79)
- fetch_all_disease_names: Remove completely (Phase 79)
- omim_links.txt: Delete file, replace with dynamic URL construction (Phase 79)
- omim_genemap2 row in comparisons_config: Remove from code (Phase 79)

## Open Questions

Things that couldn't be fully resolved:

1. **mim2gene.txt Authentication Status**
   - What we know: Official OMIM documentation states "provided without registration to help interconnectivity of MIM numbers among other data resources"
   - What's unclear: Whether this public access will remain permanent or is subject to change
   - Recommendation: Use public URL without authentication, monitor for HTTP 401/403 errors in production logs. If OMIM changes policy, fail with clear message directing to download key configuration.
   - Confidence: HIGH - Multiple authoritative sources confirm public access as of Feb 2026

2. **Existing JAX Test Fixtures**
   - What we know: Tests for JAX functions may have httptest2 fixtures for mocked responses
   - What's unclear: Whether removing test files will leave orphaned fixture directories
   - Recommendation: After removing test files, search for fixture directories matching JAX patterns (e.g., `fixtures/jax*`, `fixtures/ontology*`) and remove if empty
   - Confidence: MEDIUM - Need to inspect test directory structure

3. **omim_genemap2 Migration Row Usage**
   - What we know: Phase 78 removed omim_genemap2 from being written to comparisons_config
   - What's unclear: Are there existing database records that reference this row, and will leaving them cause issues?
   - Recommendation: Leave existing rows in database (harmless), just ensure new code doesn't reference them. Operators can manually DELETE FROM comparisons_config WHERE config_key = 'omim_genemap2' if they want to clean up.
   - Confidence: HIGH - Unused rows are harmless

## Sources

### Primary (HIGH confidence)
- Official Docker documentation: [Environment variables best practices](https://docs.docker.com/compose/how-tos/environment-variables/best-practices/)
- Official Docker documentation: [Set environment variables](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/)
- Official OMIM downloads page: [OMIM Downloads](https://www.omim.org/downloads/) - Confirms mim2gene.txt public access
- FastAPI best practices: [Production 2026 Guide](https://fastlaunchapi.dev/blog/fastapi-best-practices-production-2026) - Fail-fast validation patterns
- Codebase files:
  - /home/bernt-popp/development/sysndd/api/functions/omim-functions.R (existing patterns)
  - /home/bernt-popp/development/sysndd/api/functions/file-functions.R (caching infrastructure)
  - /home/bernt-popp/development/sysndd/api/start_sysndd_api.R (env var patterns)
  - /home/bernt-popp/development/sysndd/docker-compose.yml (environment section pattern)
  - /home/bernt-popp/development/sysndd/.env.example (documentation pattern)

### Secondary (MEDIUM confidence)
- Medium article: [Environment Variables in Elysia.js](https://maxifjaved.com/blogs/fail-fast-environment-validation-in-elysiajs/) - Fail-fast vs lazy validation
- TheLinuxCode: [Python os.getenv() guide](https://thelinuxcode.com/python-osgetenv-read-environment-variables-safely-validate-them-and-scale-configuration/) - Validation best practices
- Medium article: [.env file best practices](https://medium.com/@oadaramola/a-pitfall-i-almost-fell-into-d1d3461b2fb8) - API key security
- codestudy.net: [.env file comments best practices](https://www.codestudy.net/blog/how-to-add-comments-to-env-file/) - Documentation patterns

### Tertiary (LOW confidence - for awareness)
- R-bloggers: [checkglobals package](https://www.r-bloggers.com/2025/03/checkglobals-another-r-package-for-static-code-analysis/) - Alternative to grep for dependency detection
- CRAN: [CodeDepends package](https://cran.r-project.org/web/packages/CodeDepends/vignettes/intro.html) - Static analysis option (not needed for this phase)

## Metadata

**Confidence breakdown:**
- Environment variable patterns: HIGH - Multiple official sources + existing codebase patterns
- Docker Compose configuration: HIGH - Official Docker documentation + existing usage
- mim2gene.txt authentication: HIGH - Official OMIM documentation + community confirmation
- Dead code removal: HIGH - Simple grep patterns, verified by test suite
- Documentation patterns: HIGH - Existing .env.example provides template

**Research date:** 2026-02-07
**Valid until:** 30 days (stable technologies - env vars and Docker Compose patterns don't change frequently)

**Key risks:**
- OMIM changing public access policy for mim2gene.txt (LOW risk - documented as permanent public resource)
- Missing indirect function references during dead code removal (MEDIUM risk - mitigated by test suite)
- Environment variable name typos breaking deployments (LOW risk - mitigated by verification checklist)
