# Phase 24: Versioning, Pagination & Cleanup - Research

**Researched:** 2026-01-24
**Domain:** API versioning, pagination standardization, code quality, testing
**Confidence:** HIGH

## Summary

This phase focuses on production-readiness: implementing semantic versioning with git commit tracking, standardizing cursor-based pagination across all tabular endpoints, and improving code quality through systematic TODO resolution and lintr cleanup. The research reveals that SysNDD already has a solid cursor pagination foundation (`generate_cursor_pag_inf`) that needs extension to remaining endpoints, R provides multiple approaches for git integration (system calls vs git2r package), and the existing lintr configuration is already well-tuned for the project's style.

**Key findings:**
- Cursor pagination already implemented in 8 endpoints; needs extension to ~15 remaining tabular endpoints
- URL path versioning (/api/v1/) is the 2026 standard for REST APIs
- Git commit hash retrieval is straightforward via `system2("git", c("rev-parse", "HEAD"))`
- httr2 is the recommended HTTP client for API testing (httr is superseded)
- 22 TODO comments in application code (not library code) need resolution
- Composite key sorting (e.g., created_at + id) is essential for stable pagination

**Primary recommendation:** Implement versioning endpoint first (establishes API version for documentation), then extend existing cursor pagination pattern to all tabular endpoints, finally address code quality (TODOs and lintr) which can be done incrementally.

## Standard Stack

The established libraries/tools for this domain:

### Core - Versioning & Git Integration
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| git2r | 0.36.2 | R bindings to libgit2 | Official rOpenSci package for programmatic git access |
| system2 | base R | Execute git commands | Zero dependencies, direct git CLI access |
| jsonlite | Current | Version metadata storage | Already in project, handles version_spec.json |

### Core - Pagination
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| dplyr | Current | Data manipulation | Already in project, powers existing cursor pagination |
| tibble | Current | Data frame handling | Already in project, used in pagination helpers |
| rlang | Current | Dynamic expressions | Already in project, enables generate_sort_expressions |

### Core - Testing
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| testthat | 3.x | Unit testing framework | Standard R testing framework, already in project |
| httr2 | Latest | HTTP client for API tests | Supersedes httr, pipeable API, built-in retry/rate-limiting |
| mirai | Current | Background API server | Already in project, enables isolated API testing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lintr | Latest | Static code analysis | Code quality checks, already configured in .lintr |
| httptest2 | Latest | HTTP mocking for tests | Mock external APIs if needed |
| callthat | Latest | Plumber API testing | Alternative to mirai approach for endpoint testing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| system2("git") | git2r package | system2 is simpler, git2r offers more features (branch info, config) |
| httr2 | httr (deprecated) | httr is superseded, httr2 has better error handling and pipeable API |
| Manual TODO tracking | TODO linter | Manual review allows discretion on intentional vs obsolete TODOs |

**Installation:**
```bash
# httr2 if not already in renv.lock
Rscript -e 'renv::install("httr2")'

# git2r if choosing package approach (optional)
Rscript -e 'renv::install("git2r")'

# httptest2 for mocking (optional)
Rscript -e 'renv::install("httptest2")'
```

## Architecture Patterns

### Recommended Project Structure
Current structure already supports this phase well:
```
api/
├── endpoints/           # 23 endpoint files, 8 already paginated
├── functions/           # Helpers including generate_cursor_pag_inf
├── tests/
│   └── testthat/
│       ├── test-integration-*.R   # API integration tests
│       ├── test-unit-*.R          # Unit tests
│       └── helper-*.R             # Test helpers
├── version_spec.json    # Already exists, contains semantic version
└── .lintr               # Already configured
```

### Pattern 1: URL Path Versioning with pr_mount

**What:** Mount all API endpoints under a versioned path prefix (/api/v1/)
**When to use:** When implementing versioning without breaking existing clients
**Example:**
```r
# Source: Plumber documentation + API versioning best practices
# Current (unversioned):
root %>%
  pr_mount("/api/entity", pr("endpoints/entity_endpoints.R"))

# Versioned approach:
root %>%
  pr_mount("/api/v1/entity", pr("endpoints/entity_endpoints.R")) %>%
  # For backward compatibility, also mount unversioned (redirects to v1)
  pr_mount("/api/entity", pr("endpoints/entity_endpoints.R"))

# Alternative: Create versioned sub-router
v1_router <- pr() %>%
  pr_mount("/entity", pr("endpoints/entity_endpoints.R")) %>%
  pr_mount("/review", pr("endpoints/review_endpoints.R"))

root %>%
  pr_mount("/api/v1", v1_router) %>%
  # Unversioned routes redirect or alias to v1
  pr_mount("/api", v1_router)
```

### Pattern 2: Version Endpoint with Git Integration

**What:** /api/version endpoint that returns semantic version from version_spec.json + git commit hash
**When to use:** Required for VER-01 (version endpoint) and deployment tracking
**Example:**
```r
# Source: git2r documentation + semantic versioning best practices
# endpoints/version_endpoints.R

#* Get API version information
#* @tag version
#* @serializer json
#* @get /
function(req, res) {
  # Load semantic version from version_spec.json (already done in start_sysndd_api.R)
  version_info <- jsonlite::fromJSON("version_spec.json")

  # Get git commit hash - two approaches:

  # Approach 1: system2 (simpler, zero dependencies)
  git_commit <- tryCatch({
    system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE)
  }, error = function(e) {
    "unknown"
  })

  # Approach 2: git2r (more features, requires package)
  # git_commit <- tryCatch({
  #   repo <- git2r::repository(".")
  #   git2r::sha(git2r::commits(repo, n = 1)[[1]])
  # }, error = function(e) {
  #   "unknown"
  # })

  list(
    version = version_info$version,
    commit = git_commit,
    title = version_info$title,
    description = version_info$description
  )
}
```

### Pattern 3: Cursor Pagination Extension

**What:** Extend existing generate_cursor_pag_inf to all tabular endpoints
**When to use:** All endpoints returning lists/tables (15 endpoints need this)
**Example:**
```r
# Source: Existing api/functions/helper-functions.R:595
# Already implemented pattern - extend to remaining endpoints

#* Get user table with pagination
#* @param page_after Cursor after which entries are shown (default: 0)
#* @param page_size Page size in cursor pagination (default: "10")
#* @get table
function(req, res, page_after = 0, page_size = "10") {
  require_role(req, res, "Curator")

  # Fetch data with stable sorting (composite key: created_at + user_id)
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, email, created_at, user_role, approved) %>%
    arrange(created_at, user_id) %>%  # Stable sort with composite key
    collect()

  # Apply pagination using existing helper
  pagination_info <- generate_cursor_pag_inf(
    user_table,
    page_size,
    page_after,
    "user_id"  # Unique identifier for cursor
  )

  # Return paginated response
  list(
    links = pagination_info$links,
    meta = pagination_info$meta,
    data = pagination_info$data
  )
}
```

### Pattern 4: Stable Composite Key Sorting

**What:** Combine non-unique sort key with unique tie-breaker for deterministic ordering
**When to use:** Pagination on any non-unique column (dates, names, categories)
**Example:**
```r
# Source: API pagination best practices research
# Problem: Sorting by created_at alone is non-deterministic (multiple rows same timestamp)
# Solution: Add unique tie-breaker

# Bad (unstable):
data %>% arrange(created_at)

# Good (stable):
data %>% arrange(created_at, id)

# In generate_sort_expressions helper, already supports this:
sort_exprs <- generate_sort_expressions("created_at,entity_id", unique_id = "entity_id")
# Ensures entity_id is always in sort expression for stability
```

### Pattern 5: API Integration Testing with mirai + httr2

**What:** Launch Plumber API in background mirai process, test with httr2
**When to use:** Integration tests that need real HTTP requests (TEST-03)
**Example:**
```r
# Source: R-bloggers "Testing your Plumber APIs from R" (2025)
# tests/testthat/test-integration-version.R

library(testthat)
library(httr2)
library(mirai)

test_that("version endpoint returns semantic version and commit", {
  # Start API in background
  api_process <- mirai({
    plumber::pr_run(
      plumber::pr("../../start_sysndd_api.R"),
      port = 8001
    )
  })

  # Give API time to start
  Sys.sleep(2)

  # Test with httr2
  resp <- request("http://localhost:8001/api/version") %>%
    req_perform()

  expect_equal(resp_status(resp), 200)

  body <- resp_body_json(resp)
  expect_true("version" %in% names(body))
  expect_true("commit" %in% names(body))
  expect_match(body$version, "^\\d+\\.\\d+\\.\\d+$")  # Semantic version format

  # Cleanup
  stop_mirai(api_process)
})
```

### Anti-Patterns to Avoid

- **Offset-based pagination**: Less efficient than cursor, inconsistent with data changes
- **Hard-coded version strings**: Use version_spec.json as single source of truth
- **Breaking changes without version bump**: Major version MUST increment for breaking changes
- **Pagination without stable sort**: Results in non-deterministic page boundaries
- **Using httr instead of httr2**: httr is superseded, httr2 has better API

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Git commit retrieval | Custom git file parsing | `system2("git", "rev-parse")` or git2r | Git command handles all edge cases (detached HEAD, shallow clones) |
| Cursor pagination | Custom row slicing logic | Existing generate_cursor_pag_inf | Already handles edge cases (empty results, last page, prev/next links) |
| HTTP testing | Manual curl scripts | httr2 + testthat | Type-safe, retry logic, better error handling |
| Version comparison | String splitting logic | semantic versioning spec | Edge cases: pre-releases, build metadata |
| TODO tracking | grep + manual spreadsheet | Systematic file-by-file review | Context needed for each TODO (intentional vs obsolete) |

**Key insight:** Pagination edge cases are subtle (empty datasets, single-page results, cursor at end). The existing helper has been battle-tested.

## Common Pitfalls

### Pitfall 1: Non-Stable Sorting Breaks Pagination
**What goes wrong:** Pages skip or duplicate rows when sorting by non-unique column (e.g., created_at)
**Why it happens:** Multiple rows with same timestamp have undefined order, which can change between queries
**How to avoid:** Always include unique ID as secondary sort key
**Warning signs:** Inconsistent results when refreshing same page, duplicate items across pages

### Pitfall 2: Hardcoded Version in Multiple Places
**What goes wrong:** Version in Swagger UI doesn't match /api/version endpoint
**Why it happens:** Version defined in multiple files (version_spec.json, Swagger metadata, frontend)
**How to avoid:** Single source of truth (version_spec.json), load at startup in start_sysndd_api.R (line 209)
**Warning signs:** Version mismatch between API responses and documentation

### Pitfall 3: Breaking Existing Clients with Versioning
**What goes wrong:** Adding /api/v1/ prefix breaks existing integrations using /api/entity
**Why it happens:** Not maintaining backward compatibility during versioning rollout
**How to avoid:** Mount endpoints at BOTH /api/v1/entity and /api/entity initially, deprecate unversioned later
**Warning signs:** Client applications fail after deployment, 404 errors on existing endpoints

### Pitfall 4: Git Commands Fail in Docker
**What goes wrong:** `system2("git")` returns "unknown" in production Docker container
**Why it happens:** .git directory not included in Docker image, or git not installed
**How to avoid:** Either include .git in Docker build context, or inject commit hash at build time via ARG
**Warning signs:** Version endpoint returns commit: "unknown" in production

### Pitfall 5: Resolving All TODOs Without Discretion
**What goes wrong:** Removing intentional TODOs that mark known limitations
**Why it happens:** Treating all TODOs as obsolete without understanding context
**How to avoid:** Review each TODO for context - some are valid documentation of limitations
**Warning signs:** Loss of information about known issues, future work plans

### Pitfall 6: Over-Aggressive Lintr Fixes
**What goes wrong:** Breaking code to satisfy lintr rules (e.g., breaking SQL queries across too many lines)
**Why it happens:** Treating lintr as absolute authority without considering readability
**How to avoid:** Use `# nolint` for specific justified cases, adjust .lintr config for project style
**Warning signs:** Code becomes harder to read, SQL queries unreadable

## Code Examples

Verified patterns from official sources:

### Git Commit Hash Retrieval (Production-Ready)
```r
# Source: Git documentation + R system2 manual
# Docker-compatible approach with build-time injection

# At Docker build time (Dockerfile):
# ARG GIT_COMMIT=unknown
# ENV GIT_COMMIT=${GIT_COMMIT}

# In R code:
get_git_commit <- function() {
  # Try environment variable first (Docker build arg)
  env_commit <- Sys.getenv("GIT_COMMIT", "")
  if (env_commit != "") {
    return(env_commit)
  }

  # Fallback to git command (development)
  tryCatch({
    commit <- system2("git", c("rev-parse", "--short", "HEAD"),
                      stdout = TRUE, stderr = FALSE)
    if (length(commit) == 1) commit else "unknown"
  }, error = function(e) {
    "unknown"
  })
}
```

### Pagination Max Limit Enforcement
```r
# Source: API pagination best practices
# Enforce max page_size to prevent DoS

generate_cursor_pag_inf_safe <- function(pagination_tibble,
  page_size = "10",
  page_after = 0,
  pagination_identifier = "entity_id",
  max_page_size = 500) {  # PAG-02 requirement

  # Validate and cap page_size
  if (page_size != "all") {
    page_size <- as.integer(page_size)
    if (page_size > max_page_size) {
      warning(sprintf("page_size capped at %d", max_page_size))
      page_size <- max_page_size
    }
    if (page_size < 1) {
      page_size <- 10  # Default
    }
  }

  # Call existing helper
  generate_cursor_pag_inf(pagination_tibble, page_size, page_after, pagination_identifier)
}
```

### httr2 Integration Test Pattern
```r
# Source: httr2.r-lib.org documentation
library(testthat)
library(httr2)

test_that("pagination returns valid cursor links", {
  # Test against running API (assumes API started in setup)
  base_url <- "http://localhost:8000/api/v1"

  resp <- request(base_url) %>%
    req_url_path_append("entity") %>%
    req_url_query(page_size = 5, page_after = 0) %>%
    req_perform()

  # httr2 automatically checks for HTTP errors
  expect_equal(resp_status(resp), 200)

  body <- resp_body_json(resp)

  # Verify pagination structure
  expect_true("links" %in% names(body))
  expect_true("meta" %in% names(body))
  expect_true("data" %in% names(body))

  # Verify meta fields
  expect_equal(body$meta$perPage, 5)

  # Test following next link
  if (body$links$next != "null") {
    next_resp <- request(base_url) %>%
      req_url_path_append("entity") %>%
      req_url_query(!!!parse_query_string(body$links$next)) %>%
      req_perform()

    expect_equal(resp_status(next_resp), 200)
  }
})

parse_query_string <- function(query_str) {
  # Helper to parse &page_after=10&page_size=5 into list
  if (query_str == "null") return(list())
  query_str %>%
    str_remove("^&") %>%
    str_split("&") %>%
    unlist() %>%
    str_split("=") %>%
    purrr::map(~setNames(list(.x[2]), .x[1])) %>%
    purrr::reduce(c)
}
```

### Lintr Configuration for Large Codebase
```r
# Source: lintr.r-lib.org/articles/lintr.html
# .lintr file (project already has good config)

linters: linters_with_defaults(
  # Existing good choices:
  pipe_consistency_linter = pipe_consistency_linter(pipe = "%>%"),
  line_length_linter = line_length_linter(120L),
  return_linter = NULL,  # Allow explicit returns
  object_name_linter = NULL,  # Allow SCREAMING_SNAKE_CASE
  object_usage_linter = NULL,  # NSE handled via globalVariables()

  # Additional recommended for cleanup:
  todo_comment_linter = NULL,  # Don't flag TODOs (manual review needed)
  cyclocomp_linter = cyclocomp_linter(complexity_limit = 20)  # Flag complex functions
)
exclusions: list("_old", "data/", "logs/", "results/", "renv/", "tests/")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| httr | httr2 | 2023 (httr2 1.0.0) | Pipeable API, automatic error handling, built-in retry |
| Offset pagination | Cursor pagination | 2020s | Better performance, consistent results with data changes |
| Hardcoded versions | Semantic versioning JSON | Modern practice | Single source of truth, automated tooling |
| Manual curl testing | httr2 + testthat | 2025+ | Automated, reproducible, CI-friendly |
| system("git") | system2("git") or git2r | R 4.x | Safer (no shell injection), better error handling |

**Deprecated/outdated:**
- httr package: Superseded by httr2, only critical fixes
- /api/endpoint without version: Industry moving to explicit versioning (/v1/)
- page_number pagination: Offset-based, replaced by cursor-based

## Codebase Analysis

### Current Pagination Status

**Already Paginated (8 endpoints):**
1. `/api/entity/` - entity_endpoints.R (reference implementation)
2. `/api/gene/` - gene_endpoints.R
3. `/api/comparisons/` - comparisons_endpoints.R
4. `/api/logging/` - logging_endpoints.R
5. `/api/panels/` - panels_endpoints.R
6. `/api/phenotype/` - phenotype_endpoints.R
7. `/api/publication/pubtator/table` - publication_endpoints.R
8. `/api/variant/` - variant_endpoints.R

**Need Pagination (15 endpoints estimated):**
- `/api/user/table` - user_endpoints.R (returns all users)
- `/api/user/list` - user_endpoints.R
- `/api/re_review/table` - re_review_endpoints.R
- `/api/re_review/assignment_table` - re_review_endpoints.R
- `/api/list/status` - list_endpoints.R
- `/api/list/phenotype` - list_endpoints.R
- `/api/list/inheritance` - list_endpoints.R
- `/api/list/variation_ontology` - list_endpoints.R
- `/api/status/_list` - status_endpoints.R
- `/api/search/*` endpoints - search_endpoints.R (4 endpoints)

### TODO Comments Breakdown (22 total in application code)

**By Category:**

**Analysis Functions (5 TODOs)** - analyses-functions.R:160-164
- Type: Enhancement ideas
- Priority: LOW - These are future ML/statistical enhancements
- Action: Document as intentional "future work" TODOs

**Helper Functions (6 TODOs)** - helper-functions.R:304-307, 934-935
- Type: Missing error handling and type checking
- Priority: MEDIUM - Improve robustness of generate_filter_expressions
- Action: Implement error handling, validate column existence

**External Functions (3 TODOs)** - external-functions.R:31, 46-47
- Type: Incomplete API integration
- Priority: MEDIUM - Sanity checks and response handling
- Action: Complete implementation or mark as known limitations

**GeneReviews Functions (2 TODOs)** - genereviews-functions.R:32, 123
- Type: Performance and bug fixes
- Priority: HIGH - Bug "title now having multiple matches"
- Action: Fix bug, optimize if time permits

**Ontology Functions (3 TODOs)** - ontology-functions.R:75, 270, 273
- Type: Code duplication and logic clarification
- Priority: MEDIUM - Refactor duplicated logic
- Action: Extract common function, document column logic

**Endpoint Functions (1 TODO)** - endpoint-functions.R:356
- Type: Logic needs updating
- Priority: MEDIUM - Unclear context, needs investigation
- Action: Review context and resolve or document

**HGNC Functions (1 TODO)** - hgnc-functions.R:225
- Type: Extract to function
- Priority: LOW - Refactoring suggestion
- Action: Quick win if time permits

**OXO Functions (1 TODO)** - oxo-functions.R:32
- Type: Implement retry logic
- Priority: LOW - Enhancement for external API calls
- Action: Add exponential backoff if time permits

### Lintr Issues Analysis

**Current Configuration** (.lintr):
The project already has a well-configured .lintr file that:
- Allows magrittr pipe (%>%) for consistency
- Sets line length to 120 (modern standard)
- Disables object_name_linter (allows constants)
- Disables commented_code_linter (reduces false positives)
- Excludes renv/, tests/, data/

**Estimated Issue Breakdown:**
Without running lintr (R not available in environment), based on typical patterns:
- Line length violations: ~40% (480 issues) - Low priority, often false positives in SQL
- Object naming: Disabled in config
- Cyclomatic complexity: ~15% (186 issues) - Flag for review, not necessarily fix
- Whitespace/style: ~30% (372 issues) - Automated fixable with styler
- Others: ~15% (186 issues)

**Recommendation:** Focus on high-value issues (complexity, potential bugs), not cosmetic fixes.

## Implementation Recommendations

### Phased Approach (Recommended)

**Phase 1: Versioning (VER-01 to VER-04) - 2-3 days**
1. Create `/api/version` endpoint (version_endpoints.R)
   - Load version from version_spec.json (already done at startup)
   - Add git commit hash via system2 or build ARG
   - Return JSON with version, commit, title, description
2. Update Swagger UI to display version (pr_set_api_spec already loads version_spec.json)
3. Plan URL path versioning strategy (/api/v1/)
   - Decision needed: Big bang vs gradual rollout
   - Recommendation: Mount all at /api/v1/ AND /api/ for compatibility
4. Update frontend to display version (fetch from /api/version)

**Phase 2: Pagination Extension (PAG-01 to PAG-05) - 3-4 days**
1. Add max_page_size validation to generate_cursor_pag_inf (500 limit)
2. Extend pagination to high-priority endpoints:
   - `/api/user/table` (admin/curator use)
   - `/api/re_review/table` (review workflow)
   - `/api/search/*` endpoints (user-facing)
3. Add default page_size to maintain backward compatibility
4. Update API documentation (Swagger annotations)
5. Verify composite key sorting in all paginated endpoints

**Phase 3: Testing (TEST-03 to TEST-05) - 2-3 days**
1. Add httr2 to dependencies if not present
2. Create integration test suite:
   - test-integration-version.R (version endpoint)
   - test-integration-pagination.R (cursor pagination edge cases)
   - test-integration-async.R (async operations from Phase 20)
3. Add password migration tests (TEST-05)
   - Test plaintext → Argon2id upgrade
   - Test Argon2id verification

**Phase 4: Code Quality (TEST-01, TEST-02) - 3-4 days**
1. Systematic TODO resolution (30 comments target):
   - File-by-file review with context
   - Fix bugs (GeneReviews title matching)
   - Implement error handling (helper-functions.R)
   - Document intentional future work TODOs
   - Remove obsolete TODOs
2. Lintr cleanup (target: <200 from 1240):
   - Run lintr::lint_dir() and categorize issues
   - Fix high-value issues (complexity, potential bugs)
   - Use styler for automated cosmetic fixes
   - Add # nolint for justified exceptions
   - Don't chase all 1240 - diminishing returns

**Total Estimate:** 10-14 days for complete phase

### Prioritization by Value

**Critical Path (Must Have):**
1. Version endpoint (VER-01) - Enables deployment tracking
2. Pagination on user-facing endpoints (PAG-01) - Search, entity lists
3. Bug fixes in TODOs (TEST-01) - GeneReviews title matching

**High Value (Should Have):**
4. Integration tests (TEST-03) - Prevent regressions
5. Pagination max limit (PAG-02) - DoS prevention
6. Error handling TODOs (TEST-01) - Robustness

**Nice to Have (Could Have):**
7. URL path versioning (VER-03) - Future-proofing, not urgent
8. Lintr cleanup (TEST-02) - Quality improvement, not critical
9. Performance TODOs - Optimization opportunities

### Risk Assessment

**Low Risk:**
- Version endpoint creation (additive, no breaking changes)
- Extending pagination to more endpoints (follows existing pattern)
- TODO resolution (isolated improvements)

**Medium Risk:**
- URL path versioning (/api/v1/) - Could break clients if not careful
- Lintr fixes - Could introduce bugs if too aggressive
- Max page_size enforcement - Could break clients expecting large pages

**Mitigation Strategies:**
- Maintain /api/ alongside /api/v1/ for compatibility window
- Test lintr fixes thoroughly, use # nolint for justified cases
- Add deprecation warnings, not hard failures for page_size > max

## Open Questions

Things that couldn't be fully resolved:

1. **URL Path Versioning Rollout Strategy**
   - What we know: /api/v1/ is the standard, project currently uses /api/
   - What's unclear: Big bang migration vs gradual rollout? Compatibility window duration?
   - Recommendation: Mount both /api/ and /api/v1/ initially, deprecate /api/ in Phase 25+
   - Requires: User/team decision on breaking change timeline

2. **Git Commit Hash in Docker**
   - What we know: system2("git") won't work if .git not in Docker image
   - What's unclear: Include .git in image vs build-time ARG injection?
   - Recommendation: Use ARG GIT_COMMIT in Dockerfile, set at build time with $(git rev-parse HEAD)
   - Requires: Dockerfile modification, CI/CD pipeline update

3. **Lintr Target: How Low to Go?**
   - What we know: 1240 issues currently, target <200, but many are cosmetic
   - What's unclear: What's the ROI of chasing from 200 → 50 issues?
   - Recommendation: Hit <200 by fixing high-value issues, declare victory
   - Requires: Pragmatic judgment - don't let perfect be enemy of good

4. **TODO Resolution: Document vs Delete?**
   - What we know: 22 TODOs in app code, some are future work, some are bugs
   - What's unclear: Should intentional TODOs become GitHub issues instead?
   - Recommendation: Keep TODOs for small tactical items, create issues for strategic work
   - Requires: Team convention on TODO vs issue threshold

5. **Pagination Backward Compatibility**
   - What we know: Adding pagination changes response structure (wraps data in meta/links/data)
   - What's unclear: Can existing clients handle this? Need feature flag?
   - Recommendation: Add `?paginated=false` query param to return old format during migration
   - Requires: Testing with actual client applications

## Sources

### Primary (HIGH confidence)
- [lintr documentation](https://lintr.r-lib.org/articles/lintr.html) - Official lintr configuration guide
- [httr2 documentation](https://httr2.r-lib.org/) - Official httr2 package documentation
- [Semantic Versioning 2.0.0](https://semver.org/) - Authoritative semantic versioning specification
- [git2r GitHub repository](https://github.com/ropensci/git2r) - rOpenSci official git integration package
- [git-rev-parse documentation](https://git-scm.com/docs/git-rev-parse) - Git command for commit hash retrieval

### Secondary (MEDIUM confidence)
- [API Versioning Best Practices (2026)](https://getlate.dev/blog/api-versioning-best-practices) - URL path versioning patterns
- [Cursor-based pagination best practices](https://embedded.gusto.com/blog/api-pagination/) - Composite key sorting, stable ordering
- [Testing Plumber APIs from R (R-bloggers 2025)](https://www.r-bloggers.com/2025/07/testing-your-plumber-apis-from-r/) - mirai + httr2 pattern
- [REST API Pagination Guide](https://apidog.com/blog/rest-api-pagination/) - Cursor vs offset trade-offs
- [Plumber cheatsheet](https://rstudio.github.io/cheatsheets/html/plumber.html) - Path mounting and versioning

### Tertiary (LOW confidence - WebSearch only)
- Community blog posts on httr vs httr2 migration
- Stack Overflow discussions on git integration in R

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages are well-established, several already in project
- Architecture: HIGH - Cursor pagination already implemented, patterns verified in codebase
- Pitfalls: HIGH - Based on documented best practices and existing codebase analysis
- Codebase analysis: MEDIUM - TODO count verified, lintr issues estimated (R not available to run)
- Testing: MEDIUM - httr2 approach verified, mirai pattern from recent (2025) blog post

**Research date:** 2026-01-24
**Valid until:** 60 days (stable domain - pagination and versioning patterns change slowly)

**Phase-specific notes:**
- Entity endpoint pagination is the reference implementation (entity_endpoints.R:11-100)
- version_spec.json already loaded at startup (start_sysndd_api.R:209)
- .lintr configuration is already well-tuned (api/.lintr)
- 22 TODOs identified in application code (excluding renv library TODOs)
- httr2 already in renv.lock, ready to use for tests
