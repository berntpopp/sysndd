---
phase: 80-foundation-fixes
plan: 01
type: summary
subsystem: comparisons-api
tags: [bug-fix, data-integrity, category-normalization, api-refactor, testing]

dependencies:
  requires: []
  provides:
    - "normalize_comparison_categories() shared helper"
    - "Per-source category preservation in CurationComparisons"
    - "Comprehensive category normalization test coverage"
  affects:
    - "80-02 (may benefit from shared helper pattern)"
    - "Future comparison endpoint refactors"

tech-stack:
  added: []
  patterns:
    - "Shared helper functions for cross-endpoint reuse"
    - "Regression tests for data display bugs"

key-files:
  created:
    - "api/functions/category-normalization.R"
    - "api/tests/testthat/test-unit-category-normalization.R"
    - "db/migrations/016_fix_comparison_view_active_filter.sql"
  modified:
    - "api/functions/endpoint-functions.R"
    - "api/endpoints/comparisons_endpoints.R"
    - "api/start_sysndd_api.R"
    - "docker-compose.yml"
    - "docker-compose.override.yml"

decisions:
  - id: DISP-02
    decision: "Extract category normalization into shared helper"
    rationale: "DRY principle - category mappings duplicated in generate_comparisons_list and upset endpoint"
    impact: "Single source of truth for category normalization logic"
  - id: DISP-01
    decision: "Remove cross-database max aggregation from generate_comparisons_list"
    rationale: "Bug #173 - collapsed per-source categories into cross-database maximum"
    impact: "Each database shows its own category rating, not the 'best' category across all sources"

metrics:
  duration: "3 minutes (plan) + manual testing/fixes"
  completed: "2026-02-08"
  commits: 4
  tests_added: 37
  tests_passing: 94
  files_changed: 8
---

# Phase 80 Plan 01: Fix CurationComparisons Category Display

**One-liner:** Extract category normalization DRY helper and remove cross-database max aggregation causing per-source category collapse

---

## Objective

Fix bug #173 where the CurationComparisons table collapsed per-source category values into a cross-database maximum, causing all databases to show the same "best" category for a gene instead of each database's own rating.

**Example bug behavior:**
- Gene X is "Definitive" in SysNDD but "Limited" in gene2phenotype
- BEFORE: Both columns showed "Definitive" (cross-database max)
- AFTER: SysNDD shows "Definitive", gene2phenotype shows "Limited" (per-source)

---

## What Was Built

### 1. Shared Category Normalization Helper

**File:** `api/functions/category-normalization.R`

Created `normalize_comparison_categories(data)` function that:
- Maps source-specific category values to standard SysNDD categories
- Handles 7 different data sources with unique category systems:
  - **gene2phenotype**: strong/definitive → Definitive, limited → Limited, etc. (case-insensitive)
  - **panelapp**: Confidence levels 1-3 → Refuted/Limited/Definitive
  - **sfari**: Gene scores 1-3 + NA → Definitive/Moderate/Limited
  - **geisinger_DBD**: All → Definitive
  - **radboudumc_ID**: All → Definitive
  - **SysNDD/omim_ndd/orphanet_id**: Categories unchanged
- Returns ungrouped data frame (prevents accidental aggregation)
- Preserves all input columns except `category` (which gets normalized)

**Documentation:** Full roxygen2 with examples and mapping rules

### 2. Fixed generate_comparisons_list()

**File:** `api/functions/endpoint-functions.R`

**Removed:**
- Cross-database max aggregation logic (lines 94-100)
  - `left_join(status_categories_list, ...)`
  - `group_by(symbol) %>% mutate(category_id = min(category_id))`
  - Second `left_join` to replace category
- Unused `status_categories_list` query (lines 61-64)

**Replaced with:**
```r
ndd_database_comparison_table_norm <- ndd_database_comparison_table_col %>%
  normalize_comparison_categories()
```

**Result:**
- `definitive_only` filter now correctly filters per-source (shows genes where THAT source rates them as Definitive)
- `table_data` uses `category` directly instead of `max_category`
- Each database column shows its own category rating

**Preserved:**
- `generate_panels_list()` still uses `group_by(symbol)` (correct - computes max category per gene WITHIN SysNDD, not across databases)
- `generate_stat_tibble()` still uses `group_by(symbol)` (same reason)

### 3. Fixed upset Endpoint

**File:** `api/endpoints/comparisons_endpoints.R`

**Replaced inline duplication:**
```r
# BEFORE: 18 lines of inline category mapping
mutate(normalized_category = case_when(...)) %>%
filter(normalized_category == "Definitive")

# AFTER: 2 lines using shared helper
normalize_comparison_categories() %>%
filter(category == "Definitive")
```

**Benefits:**
- DRY: Single source of truth for category mappings
- Consistency: Upset and browse endpoints use identical normalization
- Maintainability: Category mapping changes only need updating in one place

### 4. Comprehensive Unit Tests

**File:** `api/tests/testthat/test-unit-category-normalization.R`

**37 unit tests covering:**
- **gene2phenotype mappings:** 7 tests
  - All category values (strong, definitive, limited, moderate, refuted, disputed, "both rd and if")
  - Case-insensitive handling ("Strong", "STRONG", "strong" all → "Definitive")
- **panelapp mappings:** 1 test (confidence levels 1-3)
- **sfari mappings:** 1 test (gene scores 1-3 + NA)
- **geisinger_DBD/radboudumc_ID:** 1 test (all → Definitive)
- **SysNDD/omim_ndd/orphanet_id:** 1 test (categories unchanged)
- **KEY regression test (bug #173):** 1 test
  - Multi-source fixture where same gene has different categories across sources
  - Verifies GENE1's SysNDD "Definitive" doesn't collapse gene2phenotype "Limited"
  - Verifies GENE2's SysNDD "Limited" doesn't get overwritten by sfari "Definitive"
- **Edge cases:** 5 tests
  - Empty input (0 rows)
  - Result is ungrouped (prevents accidental aggregation)
  - Preserves all input columns
  - Handles NA in category column
  - Preserves extra columns

**Test results:**
- **New tests:** 37 passed, 0 failed
- **Existing tests:** 57 passed, 6 skipped, 0 failed (no regression)
- **Total coverage:** 94 passing tests

---

## Key Decisions

### Decision 1: Extract Category Normalization (DISP-02)

**Context:** Category normalization logic was duplicated in `generate_comparisons_list()` and `upset` endpoint (126 total lines of duplication).

**Options considered:**
1. Keep inline duplication (status quo)
2. Extract to shared helper
3. Move to database view

**Decision:** Extract to shared helper function

**Rationale:**
- DRY principle: Single source of truth for category mappings
- Maintainability: Adding/changing source mappings only requires one update
- Testability: Unit tests can verify normalization in isolation
- Reusability: Other endpoints can use the helper (e.g., future export endpoints)

**Impact:**
- 126 lines of duplication → 2-line function call
- Test coverage increased (isolated tests vs. endpoint integration tests)
- Future source additions require changes in only one place

### Decision 2: Remove Cross-Database Aggregation (DISP-01)

**Context:** `generate_comparisons_list()` used `group_by(symbol) %>% mutate(category_id = min(category_id))` to compute the "best" category across all sources for a gene.

**Problem:** This caused all source columns to show the same category (the cross-database maximum), not each source's own rating.

**Decision:** Remove the aggregation entirely

**Rationale:**
- Bug: Users expect to see each database's own rating, not a computed maximum
- `definitive_only` filter was broken (filtered on collapsed value instead of per-source)
- Violates separation of concerns: Comparison table should show raw source data, not derived aggregations

**Impact:**
- **Breaking change:** CurationComparisons table now shows different values per source column
  - Users who relied on the old behavior (all columns showing max category) will see changes
  - This is the CORRECT behavior per user expectations and bug report #173
- `definitive_only` filter now works correctly (filters per-source)
- Comparison table is now a true "comparison" (shows differences between sources)

**Why not keep for other functions:**
- `generate_panels_list()` uses `group_by(symbol)` to compute max category WITHIN SysNDD (different purpose - aggregating multiple SysNDD entities for the same gene)
- `generate_stat_tibble()` same reasoning - SysNDD internal aggregation, not cross-database

---

## Testing & Verification

### Unit Tests

**New test file:** `test-unit-category-normalization.R`
- 37 tests, all passing
- Key regression test verifies per-source category preservation (bug #173)
- Edge cases: empty input, ungrouped result, NA handling, column preservation

**Existing tests:** No regression
- `test-unit-comparisons-functions.R`: 57 passed, 6 skipped

### Linting

**lintr:** No issues
```
ℹ No lints found in functions/category-normalization.R
```

### Manual Verification

**Verification commands (from plan):**
```bash
# ✓ normalize_comparison_categories defined in shared file
grep -c "normalize_comparison_categories" api/functions/category-normalization.R
# → 2

# ✓ Used in endpoint-functions.R
grep -c "normalize_comparison_categories" api/functions/endpoint-functions.R
# → 1

# ✓ Used in comparisons_endpoints.R
grep -c "normalize_comparison_categories" api/endpoints/comparisons_endpoints.R
# → 1

# ✓ Sourced in start_sysndd_api.R
grep -c "category-normalization" api/start_sysndd_api.R
# → 1

# ✓ Temp column removed from upset endpoint
grep "normalized_category" api/endpoints/comparisons_endpoints.R
# → (no output - temp column removed)

# ✓ group_by(symbol) removed from generate_comparisons_list (still in other functions)
grep -n "group_by(symbol)" api/functions/endpoint-functions.R
# → 430, 463 (in generate_panels_list and generate_stat_tibble - correct)
```

---

## Deviations from Plan

**Plan 01 itself executed as written.** However, manual testing after all plans were executed revealed two additional issues in the comparison view SQL that required a database migration (see Post-Execution Fixes below).

All original requirements satisfied:
- ✓ DISP-01: Per-source category preservation
- ✓ DISP-02: DRY category normalization helper
- ✓ DISP-03: definitive_only filter works per-source
- ✓ TEST-01: 37 unit tests with multi-source fixtures

---

## Post-Execution Fixes (discovered during manual testing)

### Problem: SysNDD column counts in CurationComparisons did not match Stats/Genes/Panels

After deploying Plan 01 and Plan 02 fixes, manual cross-checking revealed:

| Metric | Stats/Genes | CurationComparisons SysNDD | Delta |
|--------|-------------|---------------------------|-------|
| Definitive | 1802 | 1806 | +4 |
| Moderate | 154 | 159 | +5 |
| Limited | 1253 | 1254 | +1 |

### Root Cause 1: `ndd_database_comparison_view` missing `is_active` filter

The SysNDD branch of the `ndd_database_comparison_view` UNION query did not filter on `ndd_entity.is_active = 1`. This allowed 4 inactive MONDO:0001071 entities (genes: ASCC3, INTS8, TRR-CCT1-1, CNOT2) to appear in CurationComparisons but not in Stats/Genes (which use `ndd_entity_view` with `is_active = 1`).

### Root Cause 2: `ndd_database_comparison_view` missing `ndd_phenotype` filter

The view also did not filter on `ndd_entity.ndd_phenotype = 1`. Gene GJA1 (HGNC:4274) has ALL entities with `ndd_phenotype = 0`, so it appeared in CurationComparisons Limited count but not in Stats (which filters `ndd_phenotype == 1`).

### Fix: Migration 016

**File created:** `db/migrations/016_fix_comparison_view_active_filter.sql`

Added `WHERE ndd_entity.is_active = 1 AND ndd_entity.ndd_phenotype = 1` to the SysNDD branch of the `ndd_database_comparison_view`. Uses idempotent `CREATE OR REPLACE VIEW` pattern — safe to run multiple times on both fresh installs and existing databases.

### Additional Fix: Cache invalidation improvements

**Commit `8535814c`:**
- Bumped `CACHE_VERSION` from 1 to 2 in `docker-compose.yml` (forces immediate cache invalidation)
- Changed `max_age` from `Inf` to `86400` (24h safety net) in `api/start_sysndd_api.R`
- Added `localhost` Host() matchers to `docker-compose.override.yml` for dev routing (Traefik refused requests to `localhost` after production Host() matchers were added in Plan 02)

### Verified After Fix

All three sources now match exactly:
- **Stats API:** Definitive 1802, Moderate 154, Limited 1253
- **Comparisons SysNDD API:** Definitive 1802, Moderate 154, Limited 1253
- **Genes page (browser):** 1802
- **CurationComparisons/Table (browser):** Total 4977, table renders correctly

---

## Integration & Deployment

### Source Order

**Critical:** `category-normalization.R` must be sourced BEFORE `endpoint-functions.R`

**Location in start_sysndd_api.R:**
```r
source("functions/hash-repository.R", local = TRUE)
source("functions/category-normalization.R", local = TRUE)  # ← Added here
source("functions/endpoint-functions.R", local = TRUE)
```

### API Compatibility

**Breaking change:** CurationComparisons table response structure

**Before:**
```json
{
  "symbol": "GENE1",
  "SysNDD": "Definitive",
  "gene2phenotype": "Definitive",  // ← Cross-database max
  "panelapp": "Definitive"         // ← Cross-database max
}
```

**After:**
```json
{
  "symbol": "GENE1",
  "SysNDD": "Definitive",
  "gene2phenotype": "Limited",     // ← Actual gene2phenotype rating
  "panelapp": "Limited"            // ← Actual panelapp rating
}
```

**Frontend impact:**
- Vue component may need updates if it assumed all columns show same category
- `definitive_only` filter behavior changes (more restrictive - only shows genes where THAT source rates as Definitive)

### Deployment Notes

**Migration required:** Run `db/migrations/016_fix_comparison_view_active_filter.sql` on the database. This is idempotent (`CREATE OR REPLACE VIEW`) and safe to run multiple times.

**Cache invalidation:** `CACHE_VERSION` bumped to 2 — API containers will automatically use fresh caches on restart.

**Rollback plan:** Revert commits 5eb1ef40 and a109e49d for R logic changes; revert e6e2d0b4 and re-run migration 009 (original view definition) for the SQL view change.

**Monitoring:** Watch for user reports about CurationComparisons showing "different values than before" - this is expected and correct.

---

## Next Phase Readiness

### Artifacts Provided

1. **Shared helper pattern:** Other endpoints can use `normalize_comparison_categories()`
2. **Test pattern:** `test-unit-category-normalization.R` demonstrates fixture-based testing for multi-source data
3. **Documentation:** Roxygen2 comments show all category mapping rules

### Potential Future Work

**Not in scope for this phase, but enabled by this work:**

1. **Export endpoints:** CSV/Excel exports can use `normalize_comparison_categories()` for consistent category display
2. **Admin comparison preview:** Could show side-by-side raw vs. normalized categories
3. **Category mapping UI:** Admin panel could visualize source-to-standard mappings (all rules now in one place)
4. **Historical analysis:** Could track category changes over time (now that per-source data is preserved)

### Blockers/Concerns

**None.**

---

## Commits

| Commit | Type | Description | Files |
|--------|------|-------------|-------|
| 5eb1ef40 | refactor | Extract category normalization and fix cross-database aggregation | category-normalization.R, endpoint-functions.R, comparisons_endpoints.R, start_sysndd_api.R |
| a109e49d | test | Add comprehensive unit tests for category normalization | test-unit-category-normalization.R |
| 8535814c | fix | Improve cache invalidation and Traefik dev routing | start_sysndd_api.R, docker-compose.yml, docker-compose.override.yml |
| e6e2d0b4 | fix | Add migration to filter inactive/non-NDD entities from comparison view | 016_fix_comparison_view_active_filter.sql |

**Total:** 4 commits, 8 files changed (5 original + 3 post-execution fixes)

---

## Success Criteria

All success criteria met:

- ✓ normalize_comparison_categories() is a standalone reusable function (DISP-02)
- ✓ generate_comparisons_list() returns per-source category values without cross-database max aggregation (DISP-01)
- ✓ definitive_only filter works per-source (DISP-03)
- ✓ upset endpoint uses shared helper instead of inline duplication (DISP-02)
- ✓ 37 unit tests pass with multi-source test fixtures (TEST-01 - exceeded minimum of 9)
- ✓ No regression in existing comparisons tests (57 passed)
- ✓ SysNDD counts in CurationComparisons match Stats/Genes/Panels exactly (post-execution fix)
- ✓ Comparison view correctly filters inactive and non-NDD entities (post-execution fix)
- ✓ Cache invalidation works reliably on code changes (post-execution fix)

---

*Summary completed: 2026-02-08*
*Duration: 3 minutes (plan execution) + manual testing and post-execution fixes*
*Status: ✓ All tasks complete, all tests passing, all counts verified*
