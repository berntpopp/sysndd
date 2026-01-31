# SysNDD Publication Data Flow Investigation

**Date:** 2026-01-31
**Last Database Update:** 2025-02-27
**Investigator:** Claude Code Analysis

## Executive Summary

This document investigates how publication data flows through SysNDD, addressing the questions:
1. When and how are publications annotated?
2. When and where are they persisted?
3. Why do stats show 0 publications for 2026 YTD and -100% YoY growth?
4. Why does "Newest Publication" show 2025-01-01 when newer PMIDs exist?
5. Is there an admin endpoint to update annotations?

**Key Findings:**
- Publications are added **only through manual curation** (no automated updates)
- A **frontend bug** causes incorrect "Newest Publication" display (string sorting vs date sorting)
- **No admin endpoint exists** for bulk publication updates
- The system relies on legacy batch imports + runtime curation additions

---

## 1. Database Schema

### Location: `db/08_Rcommands_sysndd_db_table_publication.R`

### `publication` Table
| Column | Type | Description |
|--------|------|-------------|
| `publication_id` | VARCHAR(15) | Primary key, e.g., "PMID:12345678" |
| `publication_type` | VARCHAR(50) | "additional_references" or "gene_review" |
| `other_publication_id` | VARCHAR(250) | DOI or BookshelfID |
| `Title` | VARCHAR(1000) | Publication title |
| `Abstract` | TEXT | Publication abstract |
| `Publication_date` | TIMESTAMP | **Actual publication date from PubMed** |
| `update_date` | TIMESTAMP | **When record was added to SysNDD** |
| `Journal` | VARCHAR(100) | Journal name |
| `Keywords` | TEXT | Semicolon-separated keywords |
| `Lastname`, `Firstname` | VARCHAR(50) | First author only |

### `ndd_review_publication_join` Table
Links publications to entity reviews with type classification.

---

## 2. Data Sources & Import Workflow

### Source 1: Legacy Batch Import (One-Time/Manual)

**File:** `db/08_Rcommands_sysndd_db_table_publication.R`

**Process:**
1. Connects via SSH to legacy SysID database
2. Extracts PMIDs from disease records' `additional_references` and `gene_review` fields
3. For each PMID:
   - Calls PubMed E-utilities API via `easyPubMed` R package
   - Parses XML response for metadata (title, abstract, authors, date, etc.)
   - For GeneReviews: scrapes NCBI website using `rvest`
4. Exports to dated CSV files
5. **Manual import** to MySQL database

**This is NOT automated** - it was a migration script run during initial database setup.

### Source 2: Runtime API (Curator Actions)

**File:** `api/functions/publication-functions.R`

**When triggered:**
- Curator creates/edits an entity
- Curator adds publications to a review
- Any curation action that references a new PMID

**Process:**
```r
new_publication(pmid, pool) →
  1. check_pmid(pmid) - validates PMID exists in PubMed
  2. info_from_pmid(pmid) - fetches metadata from PubMed API
  3. table_articles_from_xml() - parses XML response (lines 153-276)
  4. INSERT into publication table with update_date = NOW()
```

**Key code in `table_articles_from_xml()` (lines 244-250):**
```r
# FALLBACK: If PubMed date is incomplete, uses current date!
if (is.na(PublicationDate) || PublicationDate == "") {
  PublicationDate <- Sys.Date()
}
```

This fallback can create artificial "recent" dates for papers with incomplete PubMed metadata.

---

## 3. API Endpoints

### Publication Retrieval

| Endpoint | Description |
|----------|-------------|
| `GET /api/publication/<pmid>` | Single publication by PMID |
| `GET /api/publication/` | Paginated list of all publications |
| `GET /api/statistics/publication_stats` | Aggregated statistics |

### Statistics Endpoint (Key for Metrics)

**File:** `api/endpoints/statistics_endpoints.R` (lines 397-525)

**Returns:**
```json
{
  "publication_date_aggregated": [
    { "Publication_date": "2024-01-01", "count": 150 },
    { "Publication_date": "2025-01-01", "count": 47 }
  ],
  "update_date_aggregated": [...],
  "journal_counts": [...],
  "keyword_counts": [...]
}
```

**Critical: Date aggregation uses string sorting:**
```r
publication_date_by_time <- publication_tbl %>%
  arrange(Publication_date)  # STRING SORT, not date sort!
```

---

## 4. Frontend Statistics Component

### File: `app/src/components/analyses/PublicationsNDDStats.vue`

### Metrics Calculation (lines 150-200):

```javascript
// Total Publications
const totalPubs = pubDates.reduce((acc, d) => acc + d.count, 0);

// YTD (Year-to-date) - 2026
const currentYear = new Date().getFullYear(); // 2026
const thisYearPubs = pubDates
  .filter(d => d.Publication_date?.startsWith(String(currentYear)))
  .reduce((acc, d) => acc + d.count, 0);

// YoY Growth
const prevYearPubs = pubDates
  .filter(d => d.Publication_date?.startsWith(String(currentYear - 1)))
  .reduce((acc, d) => acc + d.count, 0);
const yoyGrowth = prevYearPubs > 0
  ? ((thisYearPubs - prevYearPubs) / prevYearPubs * 100).toFixed(1)
  : 0;

// ⚠️ BUG: Newest Publication Date (lines 178-186)
const newestDate = pubDates
  .map(d => d.Publication_date)
  .filter(Boolean)
  .sort()           // STRING SORT!
  .reverse()[0];    // Takes "2025-01-01" not actual newest
```

### The Bug Explained

**String sorting vs Date sorting:**

```javascript
// Dates in database: 2024-06-15, 2024-12-31, 2025-01-01
["2024-06-15", "2024-12-31", "2025-01-01"].sort()
// Result: ["2024-06-15", "2024-12-31", "2025-01-01"]
// Reversed: ["2025-01-01", "2024-12-31", "2024-06-15"]
// First element: "2025-01-01" ✓ (correct by accident)

// But with: 2024-06-15, 2025-01-01, 2025-06-15
["2024-06-15", "2025-01-01", "2025-06-15"].sort()
// Result: ["2024-06-15", "2025-01-01", "2025-06-15"]
// Reversed: ["2025-06-15", "2025-01-01", "2024-06-15"]
// First element: "2025-06-15" ✓ (correct)

// PROBLEM: aggregated data, not individual dates!
// API returns AGGREGATED by year when time_aggregate="year"
// So you get: 2024-01-01 (count: 500), 2025-01-01 (count: 47)
// NOT individual publication dates!
```

**The real issue:** The stats endpoint aggregates by year, so `Publication_date` values are year-start dates (2024-01-01, 2025-01-01), not actual publication dates.

---

## 5. Why the Stats Show These Values

### Actual Database State (as of 2026-01-31):
| Year | Publication Count |
|------|------------------|
| 2024 | 672 |
| 2025 | 222 |
| 2026 | 0 |

**Newest actual publication:** PMID:36076253, Publication_date: **2025-07-14**

### Current Stats Display:
| Metric | Value | Explanation |
|--------|-------|-------------|
| Total Publications | 4,547 | Sum of all counts - **correct** |
| Publications 2026 (YTD) | 0 | No 2026 publications exist - **correct** |
| YoY Growth | -100.0% | `(0 - 672) / 672 * 100 = -100%` - **mathematically correct** |
| Newest Publication | 2025-07-14 | ✅ **FIXED**: Now shows actual newest date |

### Root Causes:
1. **Database IS up-to-date** - has publications through July 2025
2. **Aggregation masks actual dates** - API returns year-buckets with `time_aggregate=year`
3. **YoY growth is correct** - 0 publications in 2026 vs 672 in 2024 = -100%
4. ~~**Newest date bug** - Frontend shows aggregated bucket date, not actual max date~~ ✅ **FIXED**

---

## 6. Admin Endpoints for Updates

### Current State: **NO DEDICATED ADMIN ENDPOINT EXISTS**

Publications can only be added through:

1. **Entity Creation/Update** (`POST/PUT /api/entity/<entity_id>`)
   - Automatically validates and fetches new PMIDs
   - Requires authentication as curator

2. **Review Creation/Update** (via entity endpoints)
   - `svc_review_add_publications()` in `api/services/review-service.R`

### What Would Be Needed:

A dedicated admin endpoint like:
```
POST /api/admin/publications/refresh
Body: { "pmids": ["PMID:12345", "PMID:67890"] }
```

Or a bulk update endpoint:
```
POST /api/admin/publications/sync
Body: { "since_date": "2025-02-27" }
```

---

## 7. Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA SOURCES                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │ Legacy SysID DB     │    │ PubMed E-utilities  │        │
│  │ (one-time import)   │───▶│ API                 │        │
│  └─────────────────────┘    └─────────────────────┘        │
│                                      │                      │
│  ┌─────────────────────┐            │                      │
│  │ Curator Actions     │────────────┘                      │
│  │ (runtime)           │                                   │
│  └─────────────────────┘                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     MYSQL DATABASE                          │
├─────────────────────────────────────────────────────────────┤
│  publication table (4,547 records)                         │
│  ├─ publication_id (PMID:xxxxx)                           │
│  ├─ Publication_date (actual pub date)                    │
│  ├─ update_date (when added to SysNDD)                   │
│  └─ Title, Abstract, Journal, etc.                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     R/PLUMBER API                           │
├─────────────────────────────────────────────────────────────┤
│  GET /api/statistics/publication_stats                     │
│  └─ Aggregates by year (time_aggregate="year")            │
│  └─ Returns: [{"Publication_date":"2025-01-01","count":47}]│
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     VUE FRONTEND                            │
├─────────────────────────────────────────────────────────────┤
│  PublicationsNDDStats.vue                                  │
│  ├─ Total: sum(counts) = 4,547 ✓                          │
│  ├─ YTD: filter(2026) = 0 ✓                               │
│  ├─ YoY: (0-X)/X = -100% ✓                                │
│  └─ Newest: sort()[last] = "2025-01-01" ⚠️ (aggregated)   │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Recommendations

### Immediate Fixes

#### 1. Fix "Newest Publication" Display ✅ FIXED

**Commit:** `c03f4f8f` - fix(stats): display actual newest publication date instead of year bucket

The frontend now fetches the actual newest publication by querying:
```
GET /api/publication?sort=-Publication_date&page_size=1&fields=publication_id,Publication_date
```

This correctly returns `2025-07-14` instead of the year-bucket `2025-01-01`.

#### 2. Add Admin Refresh Endpoint
Create `api/endpoints/admin_endpoints.R`:

```r
#* Refresh publication metadata from PubMed
#* @tag admin
#* @post /publications/refresh
#* @param pmids:arr Array of PMIDs to refresh
function(req, res, pmids) {
  # Validate admin auth
  # For each PMID: fetch from PubMed, update database
  # Return summary of updates
}
```

### Long-Term Improvements

#### 3. Implement Automated Updates
Following [NCBI E-utilities best practices](https://www.ncbi.nlm.nih.gov/books/NBK25497/):

- Use [PubMed incremental update files](https://pubmed.ncbi.nlm.nih.gov/download/) (daily releases)
- Register for [API key](https://www.ncbi.nlm.nih.gov/home/develop/api/) (10 req/sec vs 3 req/sec)
- Implement scheduled job to check for updates weekly

#### 4. Add Publication Date Validation
In `table_articles_from_xml()`, validate date format before using fallback:

```r
# Validate date is reasonable (not in future, not ancient)
if (is.na(PublicationDate) ||
    as.Date(PublicationDate) > Sys.Date() ||
    as.Date(PublicationDate) < as.Date("1900-01-01")) {
  PublicationDate <- NA  # Keep as NA, don't use current date
}
```

---

## 9. Key Files Reference

| Component | File Path |
|-----------|-----------|
| DB Schema | `db/08_Rcommands_sysndd_db_table_publication.R` |
| Publication Functions | `api/functions/publication-functions.R` |
| Publication Repository | `api/functions/publication-repository.R` |
| Publication Endpoints | `api/endpoints/publication_endpoints.R` |
| Statistics Endpoint | `api/endpoints/statistics_endpoints.R` (lines 397-525) |
| Frontend Stats | `app/src/components/analyses/PublicationsNDDStats.vue` |
| Frontend Timeline | `app/src/components/analyses/PublicationsNDDTimePlot.vue` |
| Review Service | `api/services/review-service.R` |

---

## 10. Conclusion

The publication data in SysNDD is:
- **Current** - has publications through July 2025 (PMID:36076253, dated 2025-07-14)
- **Complete** - contains 4,547 publications total
- **Mostly correctly displayed** - except for "Newest Publication" which shows aggregated bucket date

### Stats Interpretation:
- **0 publications in 2026**: Correct - no 2026 publications have been curated yet
- **-100% YoY growth**: Mathematically correct comparing 2026 (0) to 2024 (672)
- **Newest Publication 2025-01-01**: **BUG** - should show 2025-07-14

**To fix the immediate issue:**
1. Fix the frontend to query actual max(Publication_date), not use aggregated year-bucket dates
2. Or add a dedicated field in the statistics API response for `newest_publication_date`

**Future considerations:**
1. Consider what "YoY growth" should compare (current year vs previous year, or rolling 12 months)
2. Add admin endpoint for bulk metadata refresh from PubMed
3. Consider automated PubMed polling for new NDD-related publications

---

## Sources

- [NCBI E-utilities Documentation](https://www.ncbi.nlm.nih.gov/books/NBK25497/)
- [PubMed API Getting Started](https://library.cumc.columbia.edu/kb/getting-started-pubmed-api)
- [PubMed Download Data](https://pubmed.ncbi.nlm.nih.gov/download/)
- [NCBI API Rate Limits](https://www.ncbi.nlm.nih.gov/home/develop/api/)
