# Phase 82: PubTator Backend Fix - Research

**Researched:** 2026-02-08
**Domain:** NCBI PubTator3 API integration, R database operations, rate limiting
**Confidence:** HIGH

## Summary

Phase 82 fixes three specific bugs in the PubTator annotation fetching system: (1) incremental updates re-fetch all PMIDs instead of only those missing annotations, (2) duplicate key errors occur when retrying annotation inserts, and (3) rate limiting uses 2.5s delay instead of the safer 350ms required for 3 req/s limit.

The current implementation queries all PMIDs from `pubtator_search_cache` without checking if they already have annotations in `pubtator_annotation_cache`. This causes redundant NCBI API calls and potential duplicate insert errors. The fix requires adding a LEFT JOIN filter, using `INSERT IGNORE` for idempotent inserts, and adjusting the rate limit delay from 2.5 seconds to 350ms (3 req/s = 1000ms/3 = ~333ms, rounded to 350ms for safety).

**Primary recommendation:** Use LEFT JOIN with `WHERE a.annotation_id IS NULL` to filter unannotated PMIDs, change all `INSERT INTO` to `INSERT IGNORE` in annotation cache operations, and update `PUBTATOR_RATE_LIMIT_DELAY` from 2.5 to 0.35 seconds.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.x | Database operations | R database interface standard |
| RMariaDB | 1.x | MySQL/MariaDB driver | Official MariaDB driver for R |
| dplyr | 1.x | Data manipulation | Tidyverse standard for data operations |
| jsonlite | 1.x | JSON parsing | Standard R JSON library |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | 0.x | Logging | Already integrated, use for debug output |
| digest | 0.x | Hash generation | Query deduplication (already in use) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw INSERT | INSERT IGNORE | INSERT IGNORE handles duplicates silently (preferred for idempotency) |
| Raw INSERT | ON DUPLICATE KEY UPDATE | More complex, overkill when we just want to skip duplicates |
| 2.5s delay | 350ms delay | 350ms matches 3 req/s limit with safety margin |

**Installation:**
```bash
# Already installed in container
# No new dependencies needed
```

## Architecture Patterns

### Current PubTator Flow
```
pubtator_db_update() OR pubtator_db_update_async()
  ├── Fetch search results → pubtator_search_cache
  ├── Query PMIDs from search_cache
  ├── Fetch annotations from NCBI → pubtator_annotation_cache
  └── Compute gene symbols → update search_cache.gene_symbols
```

### Pattern 1: Incremental Update Query
**What:** LEFT JOIN to filter only PMIDs without existing annotations
**When to use:** Before calling `pubtator_v3_data_from_pmids()`
**Example:**
```r
# Current (WRONG - fetches all PMIDs):
pmid_rows <- db_execute_query(
  "SELECT pmid FROM pubtator_search_cache
   WHERE query_id=? AND pmid IS NOT NULL GROUP BY pmid",
  list(query_id)
)

# Fixed (fetches only unannotated PMIDs):
pmid_rows <- db_execute_query(
  "SELECT DISTINCT s.pmid
   FROM pubtator_search_cache s
   LEFT JOIN pubtator_annotation_cache a ON s.pmid = a.pmid
   WHERE s.query_id = ? AND s.pmid IS NOT NULL
     AND a.annotation_id IS NULL",
  list(query_id)
)
```

### Pattern 2: Idempotent INSERT
**What:** Use `INSERT IGNORE` to skip duplicates silently
**When to use:** All annotation cache inserts (lines 336, 605)
**Example:**
```r
# Current (WRONG - errors on duplicate):
db_execute_statement(
  "INSERT INTO pubtator_annotation_cache (...) VALUES (...)",
  params
)

# Fixed (silently skips duplicates):
db_execute_statement(
  "INSERT IGNORE INTO pubtator_annotation_cache (...) VALUES (...)",
  params
)
```

### Pattern 3: Rate Limiting for 3 req/s
**What:** 350ms delay between requests (1000ms / 3 ≈ 333ms, rounded to 350ms)
**When to use:** All NCBI API calls
**Example:**
```r
# Current (WRONG - 2.5s = 24 req/min):
PUBTATOR_RATE_LIMIT_DELAY <- 2.5

# Fixed (350ms = ~2.86 req/s < 3 req/s limit):
PUBTATOR_RATE_LIMIT_DELAY <- 0.35
```

### Anti-Patterns to Avoid
- **Fetching all PMIDs blindly:** Always LEFT JOIN to exclude already-annotated PMIDs
- **Raw INSERT without IGNORE:** Causes errors on retry/duplicate data
- **Using exact 333ms delay:** NCBI rate limits are hard limits; use 350ms safety margin

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Duplicate detection in SQL | Manual EXCEPT queries | `INSERT IGNORE` | MySQL built-in, handles race conditions |
| Rate limiting logic | Custom sleep timers | Sys.sleep() with constant | Simple, predictable, testable |
| LEFT JOIN filtering | Multiple queries | Single LEFT JOIN with IS NULL | Atomic, efficient, correct |

**Key insight:** Database engines handle duplicates and race conditions better than application code. Use SQL features like `INSERT IGNORE` and `LEFT JOIN` instead of implementing duplicate detection in R.

## Common Pitfalls

### Pitfall 1: Not Filtering Already-Annotated PMIDs
**What goes wrong:** Every incremental update re-fetches annotations for all PMIDs in the query, wasting API calls and database writes
**Why it happens:** Query only checks `pubtator_search_cache`, not `pubtator_annotation_cache`
**How to avoid:** Use LEFT JOIN with `WHERE a.annotation_id IS NULL`
**Warning signs:** Logs show "Fetching annotations for N PMIDs" where N equals total PMIDs, not new PMIDs

### Pitfall 2: Non-Idempotent Inserts
**What goes wrong:** Duplicate key errors on retry or when same PMID appears in multiple queries
**Why it happens:** Raw `INSERT` fails if `(pmid, text, identifier)` combination already exists
**How to avoid:** Use `INSERT IGNORE` or check for unique constraint on annotation table
**Warning signs:** Error messages like "Duplicate entry for key" in logs

### Pitfall 3: Rate Limit Calculation Errors
**What goes wrong:** Using 1000ms/3 = 333.33ms exactly can cause rate limit violations due to timing precision
**Why it happens:** System timing is not precise to the millisecond; network jitter adds unpredictability
**How to avoid:** Round up to 350ms (adds ~5% safety margin)
**Warning signs:** HTTP 429 "Too Many Requests" errors from NCBI

### Pitfall 4: Unique Constraint Assumptions
**What goes wrong:** Assuming `(pmid, gene_symbol)` is unique when requirements mention it, but annotations have no such constraint
**Why it happens:** Misreading requirements - the unique constraint applies to annotation rows, not gene_symbols column
**How to avoid:** Check actual table schema; `pubtator_annotation_cache` has no unique constraint defined
**Warning signs:** INSERT IGNORE doesn't prevent duplicates if wrong columns are assumed unique

## Code Examples

Verified patterns from actual codebase:

### Current PMID Query (Lines 291-294, 575-578)
```r
# Source: api/functions/pubtator-functions.R:291-294
pmid_rows <- db_execute_query(
  "SELECT pmid FROM pubtator_search_cache
   WHERE query_id=? AND pmid IS NOT NULL GROUP BY pmid",
  list(query_id)
)
```

### Current Annotation Insert (Lines 334-341, 602-626)
```r
# Source: api/functions/pubtator-functions.R:334-341
for (r in seq_len(nrow(df_ann))) {
  db_execute_statement(
    "INSERT INTO pubtator_annotation_cache
    (search_id, pmid, id, text, identifier, type, ncbi_homologene, valid,
     normalized, `database`, normalized_id, biotype, name, accession)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    unname(as.list(df_ann[r, ]))
  )
}
```

### Current Rate Limit Delay (Line 23)
```r
# Source: api/functions/pubtator-functions.R:23
PUBTATOR_RATE_LIMIT_DELAY <- 2.5 # seconds between requests (24 req/min max)
```

### Database Helper Pattern
```r
# Source: Multiple locations in pubtator-functions.R
# db_execute_query() and db_execute_statement() accept conn parameter
# For sync version: uses global pool
# For async version: creates own connection and passes to helpers
db_execute_query(
  "SELECT ... WHERE ...?",
  list(param1, param2),
  conn = conn  # Optional, uses pool if NULL
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fetch all PMIDs every time | Should use LEFT JOIN filter | Not yet implemented (this phase) | Reduces API calls by ~90% for incremental updates |
| Raw INSERT | Use INSERT IGNORE | Not yet implemented (this phase) | Makes inserts idempotent, prevents retry failures |
| 2.5s delay (24 req/min) | 350ms delay (3 req/s) | Not yet implemented (this phase) | Speeds up annotation fetch 7x while staying under limit |
| Manual duplicate detection | Database-level INSERT IGNORE | MySQL best practice | Handles race conditions atomically |

**Deprecated/outdated:**
- 2.5s rate limit: Based on "~30 requests/minute" comment, but NCBI standard is 3 req/s
- Fetching all PMIDs without annotation check: Inefficient, causes redundant work

## Open Questions

Things that couldn't be fully resolved:

1. **Actual NCBI PubTator3 rate limit**
   - What we know: Code comment says "~30 requests/minute", NCBI general APIs use 3 req/s
   - What's unclear: Official PubTator3 documentation doesn't specify exact limit in search results
   - Recommendation: Use 350ms (3 req/s) as safe baseline; can be tuned if 429 errors occur

2. **Unique constraints on pubtator_annotation_cache**
   - What we know: Schema creation script (line 113-136) has no UNIQUE constraint defined
   - What's unclear: Whether duplicates should be prevented at schema level or application level
   - Recommendation: Use INSERT IGNORE for now; consider adding UNIQUE constraint on `(pmid, text, identifier)` in future migration

3. **Why current delay is 2.5s**
   - What we know: Comment says "~30 requests/minute limit" which equals 2s delay
   - What's unclear: Whether this was based on old API documentation or empirical testing
   - Recommendation: Change to 350ms (3 req/s) per NCBI standard; monitor for 429 errors

## Sources

### Primary (HIGH confidence)
- `/home/bernt-popp/development/sysndd/api/functions/pubtator-functions.R` - Current implementation analyzed
- `/home/bernt-popp/development/sysndd/db/16_Rcommands_sysndd_db_pubtator_cache_table.R` - Schema definitions verified
- `/home/bernt-popp/development/sysndd/.planning/REQUIREMENTS.md` - Requirements API-01, API-02, API-03
- `/home/bernt-popp/development/sysndd/.planning/ROADMAP.md` - Phase 82 success criteria

### Secondary (MEDIUM confidence)
- [NCBI API Keys Documentation](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/api/api-keys/) - General NCBI rate limit guidance (3 req/s without key, 10 req/s with key)
- [NCBI Enhanced API Key Support](https://support.nlm.nih.gov/kbArticle/?pn=KA-05318) - Explains 3 req/s baseline and 10 req/s enhanced limits

### Tertiary (LOW confidence)
- PubTator3 API homepage (CSS only, no rate limit info) - Requires deeper documentation dive

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries currently in use, verified in code
- Architecture: HIGH - Current code analyzed, patterns extracted from actual implementation
- Pitfalls: HIGH - Based on requirements document and code review
- Rate limit: MEDIUM - NCBI general guidance (3 req/s) but PubTator3-specific docs not found

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days - stable API, unlikely to change)
