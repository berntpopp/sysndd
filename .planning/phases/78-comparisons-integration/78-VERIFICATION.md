---
phase: 78-comparisons-integration
verified: 2026-02-07T18:00:17Z
status: gaps_found
score: 7/8 must-haves verified
gaps:
  - truth: "Comparisons OMIM download uses shared download_genemap2() with 1-day TTL cache"
    status: failed
    reason: "omim-functions.R not sourced in mirai daemon context - download_genemap2() not available at runtime"
    artifacts:
      - path: "api/start_sysndd_api.R"
        issue: "Missing source('/app/functions/omim-functions.R') in mirai daemon initialization (lines 475-512)"
    missing:
      - "Add source('/app/functions/omim-functions.R', local = FALSE) to mirai daemon context before comparisons-functions.R"
      - "Verify download_genemap2(), parse_genemap2(), and download_hpoa() are accessible in daemon"
  - truth: "Comparisons OMIM parsing delegates raw genemap2 extraction to shared parse_genemap2()"
    status: failed
    reason: "omim-functions.R not sourced in mirai daemon context - parse_genemap2() not available at runtime"
    artifacts:
      - path: "api/start_sysndd_api.R"
        issue: "Missing source('/app/functions/omim-functions.R') in mirai daemon initialization (lines 475-512)"
    missing:
      - "Add source('/app/functions/omim-functions.R', local = FALSE) to mirai daemon context"
  - truth: "phenotype.hpoa is cached with 1-day TTL in data/ directory"
    status: failed
    reason: "omim-functions.R not sourced in mirai daemon context - download_hpoa() not available at runtime"
    artifacts:
      - path: "api/start_sysndd_api.R"
        issue: "Missing source('/app/functions/omim-functions.R') in mirai daemon initialization (lines 475-512)"
    missing:
      - "Add source('/app/functions/omim-functions.R', local = FALSE) to mirai daemon context"
---

# Phase 78: Comparisons Integration Verification Report

**Phase Goal:** Unify comparisons system to use shared genemap2 cache (single download per day across both systems)

**Verified:** 2026-02-07T18:00:17Z

**Status:** gaps_found

**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Comparisons OMIM parsing delegates raw genemap2 extraction to shared parse_genemap2() | ✗ FAILED | Function call exists in code (line 835) but omim-functions.R not sourced in mirai daemon - will fail at runtime |
| 2 | Comparisons OMIM download uses shared download_genemap2() with 1-day TTL cache | ✗ FAILED | Function call exists in code (line 834) but omim-functions.R not sourced in mirai daemon - will fail at runtime |
| 3 | Only one genemap2.txt download occurs per day regardless of which system triggers it | ✓ VERIFIED | Both systems call download_genemap2() which uses check_file_age_days() for 1-day TTL |
| 4 | omim_genemap2 entry no longer exists in comparisons_config table | ✓ VERIFIED | Migration 014 removes it (line 24), skip logic added (line 925) |
| 5 | update_source_last_updated() is skipped for omim_genemap2 since config row is removed | ✓ VERIFIED | Skip logic at line 924-926 in comparisons-functions.R |
| 6 | Comparisons OMIM version field is date-based (YYYY-MM-DD) not filename-based | ✓ VERIFIED | Line 419: version = format(Sys.Date(), "%Y-%m-%d") |
| 7 | phenotype.hpoa is cached with 1-day TTL in data/ directory | ✗ FAILED | Function call exists in code (line 776-780) but omim-functions.R not sourced in mirai daemon - will fail at runtime |
| 8 | adapt_genemap2_for_comparisons() receives pre-parsed tibble, not a file path | ✓ VERIFIED | Function signature (line 390) takes genemap2_data (tibble), tests verify (line 517 test rejects file path) |

**Score:** 5/8 truths verified (3 failed due to same root cause: missing omim-functions.R sourcing)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| api/functions/omim-functions.R | download_hpoa() function with 1-day TTL caching | ✓ VERIFIED | Function exists at line 227, uses check_file_age_days() at line 229, date-stamped filenames |
| api/functions/comparisons-functions.R | adapt_genemap2_for_comparisons() replacing parse_omim_genemap2() | ✓ VERIFIED | Adapter at line 390 (~43 lines), old function deleted (0 matches for parse_omim_genemap2) |
| db/migrations/014_remove_genemap2_config.sql | Migration to remove omim_genemap2 from comparisons_config | ✓ VERIFIED | Migration exists, deletes only omim_genemap2 (line 24), verifies phenotype_hpoa preserved (lines 27-32) |
| api/start_sysndd_api.R | Source omim-functions.R in mirai daemon context | ✗ MISSING | **CRITICAL GAP**: omim-functions.R NOT sourced in mirai daemon (lines 475-512) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| api/functions/comparisons-functions.R | api/functions/omim-functions.R | parse_genemap2(), download_genemap2(), download_hpoa() calls | ✗ NOT_WIRED | **CRITICAL**: Calls exist (lines 776, 834-835, 840) but omim-functions.R not sourced in mirai daemon context |
| api/functions/comparisons-functions.R | api/functions/comparisons-sources.R | update_source_last_updated() skip for omim_genemap2 | ✓ WIRED | Skip logic at lines 924-926 |
| api/tests/testthat/test-unit-comparisons-functions.R | api/functions/comparisons-functions.R | adapt_genemap2_for_comparisons() tests | ✓ WIRED | 7 tests reference function (lines 406-528) |
| api/tests/testthat/test-unit-comparisons-functions.R | api/functions/omim-functions.R | parse_genemap2() called to produce test input | ✓ WIRED | Tests call parse_genemap2() at lines 414, 432, etc. |

### Requirements Coverage

**COMP-01:** Comparisons system uses shared genemap2 cache (single download per day across both systems)

- Status: ✗ BLOCKED
- Issue: Code calls download_genemap2() but function not available at runtime (omim-functions.R not sourced in mirai daemon)
- Supporting truths: #2 (failed), #3 (verified)

**COMP-02:** Comparisons omim_genemap2 parsing calls shared parse_genemap2() to eliminate code duplication

- Status: ✗ BLOCKED
- Issue: Code calls parse_genemap2() but function not available at runtime (omim-functions.R not sourced in mirai daemon)
- Supporting truths: #1 (failed)
- Evidence: No duplicate parsing code remains (0 matches for "read_tsv.*genemap2", 0 matches for "case_when.*inheritance")

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| api/start_sysndd_api.R | 505 | comparisons-functions.R sourced without dependency (omim-functions.R) | 🛑 Blocker | Runtime failure when comparisons_update_async() calls download_genemap2(), parse_genemap2(), download_hpoa() |

### Gaps Summary

**Root Cause:** The Phase 78 implementation correctly refactored comparisons-functions.R to call shared infrastructure (download_genemap2(), parse_genemap2(), download_hpoa()), but failed to ensure those functions are available in the mirai daemon execution context where comparisons_update_async() runs.

**Impact:** At runtime, when a comparisons update job executes in the mirai daemon, it will fail with "object 'download_genemap2' not found" (and similar for parse_genemap2 and download_hpoa).

**Evidence of Gap:**

1. comparisons-functions.R calls these functions (lines 776, 834-835, 840)
2. Functions are defined only in omim-functions.R
3. omim-functions.R is sourced in main API context via ontology-functions.R (line 142 of start_sysndd_api.R)
4. omim-functions.R is NOT sourced in mirai daemon context (lines 475-512 of start_sysndd_api.R)
5. Docker exec test confirms: sourcing comparisons-functions.R alone results in exists('download_genemap2') → FALSE

**What's Missing:**

Add one line to api/start_sysndd_api.R in the mirai daemon initialization block (after line 484, before line 503):

```r
# Source OMIM functions (download_genemap2, parse_genemap2, download_hpoa) for comparisons
source("/app/functions/omim-functions.R", local = FALSE)
```

This enables comparisons_update_async() to call the shared infrastructure functions at runtime.

**Positive Findings:**

- All code artifacts exist and are substantive (download_hpoa 39 lines, adapter 43 lines, migration 40 lines)
- No duplicate parsing code remains (parse_omim_genemap2 deleted, no raw genemap2 reads, no inheritance normalization)
- Adapter pattern correctly implemented (receives tibble, not file path)
- Version field correctly changed to date-based format
- Skip logic for update_source_last_updated() correctly added
- Migration correctly removes only omim_genemap2, preserves phenotype_hpoa
- Test coverage comprehensive (7 tests, synthetic fixtures, no network/OMIM licensing issues)
- Cache sharing logic correct (check_file_age_days with 1-day TTL in data/ directory)

---

_Verified: 2026-02-07T18:00:17Z_
_Verifier: Claude (gsd-verifier)_
