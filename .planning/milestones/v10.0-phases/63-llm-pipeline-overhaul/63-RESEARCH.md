# Phase 63: LLM Pipeline Overhaul - Research

**Researched:** 2026-02-01
**Domain:** R/Docker debugging, database connectivity, LLM integration
**Confidence:** HIGH (issues are code-level, not technology choice)

## Summary

The LLM batch generation pipeline has a cascading failure chain with four distinct root causes identified in debug reports. This is fundamentally a debugging and fix phase, not a technology selection phase. The issues span Docker build configuration (ICU library mismatch), R function scoping (base function masking), DBI parameter binding (jsonlite JSON class objects), and mirai daemon database connectivity patterns.

The primary finding is that rocker/r-ver:4.4.3 uses Ubuntu 22.04 (jammy) which ships with ICU version 70, but the Posit Package Manager binaries for stringi may be compiled against a different ICU version. The "unused argument (envir = .GlobalEnv)" error is likely a red herring - the actual function receiving the unexpected argument needs to be identified through systematic debugging. The JSON serialization issue with DBI's `dbBind()` is caused by `jsonlite::toJSON()` returning a `json` class object rather than a plain character string.

**Primary recommendation:** Fix Docker ICU compatibility first to enable clean rebuilds, then systematically debug the "envir" error with function-level tracing.

## Standard Stack

The stack is already established; this phase fixes integration issues.

### Core (Already in Use)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| ellmer | 0.4.0+ | Gemini API client | Working |
| mirai | current | Async job execution | Daemon setup needs fix |
| DBI | current | Database interface | Parameter binding issue |
| RMariaDB | current | MySQL driver | Working |
| jsonlite | current | JSON serialization | Needs `as.character()` wrapper |
| pool | current | Connection pooling | Main process only |

### Docker Stack
| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| rocker/r-ver | 4.4.3 | Base R image | ICU version mismatch |
| Ubuntu | 22.04 (jammy) | Base OS | Ships with ICU 70 |
| Posit Package Manager | latest | Binary packages | May use different ICU |

## Architecture Patterns

### Pattern 1: Database Connection in Mirai Daemons

**What:** Mirai daemons run in separate R processes without access to the main process's `pool` object.

**Correct Pattern (from mirai documentation):**
```r
# Option A: Use everywhere() at daemon startup
everywhere({
  library(DBI)
  library(RMariaDB)
  con <<- dbConnect(
    RMariaDB::MariaDB(),
    host = host, port = port, dbname = dbname,
    user = user, password = password
  )
}, host = db_host, port = db_port, ...)

# Clean up before shutdown
everywhere(dbDisconnect(con))
daemons(0)
```

**Current Implementation Issue:** The code passes `db_config` through job params and creates connection in executor, which is acceptable but requires careful lifecycle management. The connection should be assigned to global environment for db-helpers to find.

Source: [mirai Databases documentation](https://mirai.r-lib.org/articles/databases.html)

### Pattern 2: JSON Serialization for DBI Parameter Binding

**What:** DBI's `dbBind()` expects scalar character strings for text parameters, but `jsonlite::toJSON()` returns a `json` class object (character with attributes).

**Correct Pattern:**
```r
# WRONG - returns json class object
json_str <- jsonlite::toJSON(data, auto_unbox = TRUE)
# class(json_str) is c("json", "character") with length attribute

# CORRECT - plain character scalar
json_str <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE))
# class(json_str) is "character" with length 1
```

Source: [jsonlite unbox documentation](https://rdrr.io/cran/jsonlite/man/unbox.html)

### Pattern 3: Ellmer Gemini Authentication

**What:** ellmer's `chat_google_gemini()` supports multiple authentication methods.

**Correct Pattern:**
```r
# Environment variable (preferred for Docker)
Sys.setenv(GEMINI_API_KEY = "your-key")
chat <- ellmer::chat_google_gemini(model = "gemini-2.5-flash")

# Explicitly specify model - don't rely on defaults
result <- chat$chat_structured(prompt = prompt, type = type_spec)
```

**Note:** The default model is "gemini-2.5-flash" - code currently uses "gemini-3-pro-preview" which needs verification.

Source: [ellmer chat_google_gemini documentation](https://ellmer.tidyverse.org/reference/chat_google_gemini.html)

### Anti-Patterns to Avoid

- **Passing pool object to daemons:** Pool objects cannot be serialized. Create fresh connections in daemons.
- **Using bare `exists()`/`get()` in packages:** Can be masked by other packages. Use `base::exists()` etc.
- **Passing jsonlite output directly to DBI:** Always wrap with `as.character()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connection pooling in daemons | Custom pool sharing | Fresh `dbConnect()` per daemon | Pool objects not serializable |
| ICU in Docker | Manual ICU installation | Force source install or pin binary | System library compatibility |
| JSON scalar conversion | Custom JSON serializer | `as.character(jsonlite::toJSON(...))` | Well-tested, handles edge cases |

## Common Pitfalls

### Pitfall 1: ICU Library Version Mismatch in Docker

**What goes wrong:** stringi binary from Posit Package Manager compiled against different ICU version than Ubuntu base provides.

**Why it happens:** RSPM builds binaries for specific Ubuntu versions. If base image ICU differs from build environment, shared library loading fails.

**How to avoid:**
1. Force source installation: `options(renv.config.rspm.enabled = FALSE)` then `renv::restore()`
2. Or install matching ICU version explicitly in Dockerfile
3. Or use r2u images which have tighter package/system alignment

**Warning signs:** "cannot open shared object file: libicui18n.so.XX"

**Fix options for Dockerfile:**
```dockerfile
# Option 1: Force source compilation of stringi
ENV RENV_CONFIG_RSPM_ENABLED=FALSE

# Option 2: Install specific ICU version (if known)
RUN apt-get install -y libicu70  # Ubuntu 22.04

# Option 3: Check what ICU version is installed and verify match
RUN ldconfig -p | grep libicu
```

Source: [Bioconductor Docker stringi issue](https://github.com/Bioconductor/bioconductor_docker/issues/59)

### Pitfall 2: "unused argument (envir = .GlobalEnv)" Error

**What goes wrong:** A function receives `envir = .GlobalEnv` but doesn't accept that parameter.

**Why it happens:** Most likely causes:
1. Function masking - a package exports a function with same name but different signature
2. Cached bytecode from old function definition
3. Different code path than expected

**How to avoid:**
1. Use explicit namespaces: `base::exists()`, `base::get()`, `base::assign()`, `base::rm()`
2. Add entry-point logging to identify which function actually fails
3. Rebuild container with `--no-cache` after fixing code

**Diagnostic approach:**
```r
# Add at function entry points
db_execute_query <- function(sql, params = list(), conn = NULL) {
  message("[db_execute_query] ENTRY")
  message("[db_execute_query] sql: ", substr(sql, 1, 50))
  ...
}

# Check for function masking
find("exists")  # Should show base::exists first
getNamespaceExports("SomePackage")  # Check if package exports exists()
```

### Pitfall 3: DBI Parameter Length Mismatch

**What goes wrong:** "Parameter 6 does not have length 1" when binding JSON to SQL.

**Why it happens:** `jsonlite::toJSON()` returns a `json` class object which has attributes that make DBI think it's not a scalar.

**How to avoid:** Always wrap `toJSON()` result with `as.character()`:
```r
# Before
summary_json_str <- jsonlite::toJSON(summary_json, auto_unbox = TRUE)

# After
summary_json_str <- as.character(jsonlite::toJSON(summary_json, auto_unbox = TRUE))
```

**Verification:**
```r
x <- jsonlite::toJSON(list(a = 1), auto_unbox = TRUE)
class(x)  # [1] "json"
length(x)  # [1] 1 (but has attributes)

y <- as.character(x)
class(y)  # [1] "character"
length(y)  # [1] 1 (plain scalar)
```

### Pitfall 4: Mirai Daemon Function Availability

**What goes wrong:** Functions not found in daemon context.

**Why it happens:** Mirai daemons are separate R processes. They don't inherit the main process's function definitions automatically.

**How to avoid:** Use `everywhere()` to source required files:
```r
everywhere({
  source("/app/functions/db-helpers.R", local = FALSE)
  source("/app/functions/llm-service.R", local = FALSE)
  # ... other required files
})
```

**Current code does this correctly** in `start_sysndd_api.R` lines 325-382.

## Code Examples

### Verified: ellmer Structured Output

```r
# Source: ellmer documentation
chat <- ellmer::chat_google_gemini(model = "gemini-2.5-flash")

# Define type specification
type_spec <- ellmer::type_object(
  "Summary structure",
  summary = ellmer::type_string("Summary text"),
  tags = ellmer::type_array(ellmer::type_string("Tag"), "Tags for filtering")
)

# Generate structured response
result <- chat$chat_structured(prompt = "...", type = type_spec)
# result is a list matching type_spec structure
```

### Verified: Database Connection in Daemon

```r
# Source: mirai documentation
llm_batch_executor <- function(params) {
  db_config <- params$db_config

  # Create fresh connection (not pool)
  conn <- DBI::dbConnect(
    RMariaDB::MariaDB(),
    host = db_config$db_host,
    port = db_config$db_port,
    dbname = db_config$db_name,
    user = db_config$db_user,
    password = db_config$db_password
  )

  # Ensure cleanup
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  # Make available to db-helpers
  base::assign("daemon_db_conn", conn, envir = .GlobalEnv)
  on.exit(base::rm("daemon_db_conn", envir = .GlobalEnv), add = TRUE)

  # ... rest of executor
}
```

### Verified: JSON Serialization for DBI

```r
# Source: jsonlite documentation + DBI requirements
save_summary_to_cache <- function(..., summary_json, ...) {
  # Convert to plain character scalar
  summary_json_str <- if (is.character(summary_json) && length(summary_json) == 1) {
    summary_json
  } else {
    as.character(jsonlite::toJSON(summary_json, auto_unbox = TRUE))
  }

  # Now safe for dbBind
  db_execute_statement(
    "INSERT INTO cache (summary_json) VALUES (?)",
    list(summary_json_str)
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| r-base Docker images | rocker/r-ver with RSPM | 2024+ | Faster builds, but ICU compatibility issues |
| Manual LLM API calls | ellmer package | 2025 | Standardized interface, structured output |
| Sync job processing | mirai async daemons | Already implemented | Non-blocking API, but connection management complexity |

**Note on Gemini models:**
- Current code uses `"gemini-3-pro-preview"` which may not be valid
- ellmer default is `"gemini-2.5-flash"`
- Verify current model names in Gemini API documentation

## Open Questions

1. **Actual model name validity**
   - What we know: Code uses "gemini-3-pro-preview"
   - What's unclear: Whether this model name is valid in current Gemini API
   - Recommendation: Verify with Gemini API docs, consider using ellmer's default "gemini-2.5-flash"

2. **Root cause of "envir" error**
   - What we know: Error mentions `envir = .GlobalEnv` as unused argument
   - What's unclear: Which function actually receives this argument incorrectly
   - Recommendation: Add entry-point logging to trace execution path

3. **ICU version in rocker/r-ver:4.4.3**
   - What we know: Ubuntu 22.04 ships with ICU 70
   - What's unclear: Exact ICU version in current rocker/r-ver:4.4.3 image
   - Recommendation: Check with `ldconfig -p | grep libicu` in container

## Sources

### Primary (HIGH confidence)
- [mirai Databases documentation](https://mirai.r-lib.org/articles/databases.html) - daemon database connection patterns
- [ellmer chat_google_gemini](https://ellmer.tidyverse.org/reference/chat_google_gemini.html) - Gemini API authentication
- [jsonlite unbox documentation](https://rdrr.io/cran/jsonlite/man/unbox.html) - JSON scalar handling
- [rocker r-ver documentation](https://rocker-project.org/images/versioned/r-ver.html) - Docker base image info

### Secondary (MEDIUM confidence)
- [Bioconductor Docker stringi issue](https://github.com/Bioconductor/bioconductor_docker/issues/59) - ICU mismatch pattern
- [r2u documentation](https://github.com/eddelbuettel/r2u) - Alternative binary package approach
- [rspm package documentation](https://cran4linux.github.io/rspm/) - Binary installation troubleshooting

### Tertiary (LOW confidence)
- Debug reports in `.planning/` - detailed error traces specific to this codebase

## Metadata

**Confidence breakdown:**
- Docker ICU fix: HIGH - well-documented issue with known solutions
- Database daemon pattern: HIGH - official mirai documentation
- JSON serialization: HIGH - standard jsonlite/DBI behavior
- "envir" error root cause: MEDIUM - requires local debugging to confirm

**Research date:** 2026-02-01
**Valid until:** 30 days (stable technologies, debugging phase)

## Appendix: Debugging Checklist

For the planner to reference when creating tasks:

### Docker Build Fix
- [ ] Check current ICU version in container: `ldconfig -p | grep libicu`
- [ ] Check stringi linkage: `ldd /path/to/stringi.so`
- [ ] Try source compilation: `RENV_CONFIG_RSPM_ENABLED=FALSE renv::restore()`
- [ ] Verify with `docker compose build api --no-cache`

### "envir" Error Debug
- [ ] Add logging at entry of `db_execute_query`
- [ ] Add logging at entry of `get_db_connection`
- [ ] Check for function masking: `find("exists")`
- [ ] Verify code in container matches source files
- [ ] Test isolated function call in R console inside container

### JSON Serialization Verify
- [ ] Check all `toJSON()` calls wrapped with `as.character()`
- [ ] Verify parameter counts match SQL placeholders
- [ ] Test save_summary_to_cache with dummy data

### End-to-End Verification
- [ ] Trigger clustering job
- [ ] Monitor `/tmp/llm_executor_debug.log`
- [ ] Check `llm_cluster_summary_cache` table
- [ ] Verify frontend receives 200 response
