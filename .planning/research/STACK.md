# Technology Stack — v10.5 Bug Fixes

**Project:** SysNDD v10.5
**Researched:** 2026-02-08
**Confidence:** HIGH

## Executive Summary

v10.5 requires NO new library dependencies. All bug fixes can be implemented using existing stack capabilities with better patterns:

| Bug Category | Required Pattern | Existing Stack Solution |
|--------------|------------------|-------------------------|
| Time-series aggregation (#171) | Forward-fill for sparse categorical data | TypeScript pure functions + Chart.js |
| Race conditions (#172-3) | Request cancellation | AbortController (browser native, axios v1.13.4 supports) |
| PubTator rate limiting (#170) | Exponential backoff + batch deduplication | httr2 v1.2.2 req_retry + R digest package |
| Admin data integrity UI (#167) | Entity audit tables with curator actions | Bootstrap-Vue-Next BTable + BAlert + BButton patterns |
| Traefik TLS (#169) | Host() matcher configuration | Traefik v3.6 (already present) |
| Category normalization (#173) | Cross-database aggregation | dplyr::group_by + dplyr::summarise |

**Key principle:** Leverage existing capabilities properly rather than adding dependencies.

---

## Frontend Patterns

### 1. AbortController for Request Cancellation (Bug #172-3)

**Status:** Available natively in all modern browsers (axios v1.13.4 supports)

**When to use:** Any long-running API request that may become stale due to user navigation or UI state changes.

**Pattern:**
```typescript
// Store controller in component scope
const controller = new AbortController();

try {
  const response = await axios.get('/api/endpoint', {
    signal: controller.signal,
    headers: getAuthHeaders(),
  });
} catch (error) {
  if (axios.isCancel(error)) {
    // Request was cancelled, not an error
    return;
  }
  // Handle real errors
}

// Cancel on cleanup (e.g., component unmount, route change)
onUnmounted(() => controller.abort());
```

**Why not use deprecated CancelToken:** The axios CancelToken API was deprecated in v0.22.0. AbortController is the web standard used by Fetch API and is the recommended approach for all modern projects.

**Integration points:**
- `AdminStatistics.vue:fetchStatistics()` — Cancel in-flight requests when date range changes
- `ManageAnnotations.vue` — Cancel ontology updates when navigating away

**Sources:**
- [Axios Cancellation Documentation](https://axios-http.com/docs/cancellation)
- [MDN AbortController](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)

---

### 2. Time-Series Aggregation with Forward-Fill (Bug #171)

**Status:** Implement as pure TypeScript utility function

**Problem:** Per-category cumulative time series have sparse dates. When category A has data on Day 1 but not Day 2, and category B has data on Day 2 but not Day 1, naively summing incremental counts produces incorrect global totals.

**Solution:** Forward-fill missing dates using last known cumulative value.

**Pattern:**
```typescript
// app/src/utils/timeSeriesUtils.ts (NEW FILE)

export interface TimeSeriesPoint {
  entry_date: string;
  count: number;
  cumulative_count: number;
}

export interface GroupedTimeSeries {
  group: string;
  values: TimeSeriesPoint[];
}

export interface AggregatedPoint {
  date: string;
  count: number;
}

/**
 * Merges per-group cumulative time series into a single global cumulative series.
 * Handles sparse data with forward-fill: when a group has no entry at a date,
 * its last known cumulative value is carried forward.
 */
export function mergeGroupedCumulativeSeries(
  groups: GroupedTimeSeries[]
): AggregatedPoint[] {
  // 1. Collect union of all dates
  const allDates = new Set<string>();
  for (const g of groups) {
    for (const v of g.values ?? []) {
      allDates.add(v.entry_date);
    }
  }

  // 2. Build per-group lookup: date -> cumulative_count
  const groupMaps = groups.map((g) => {
    const map = new Map<string, number>();
    for (const v of g.values ?? []) {
      map.set(v.entry_date, v.cumulative_count);
    }
    return map;
  });

  // 3. Forward-fill and sum across groups at each date
  const sortedDates = Array.from(allDates).sort();
  const lastSeen = new Array<number>(groups.length).fill(0);

  return sortedDates.map((date) => {
    let total = 0;
    for (let i = 0; i < groupMaps.length; i++) {
      const val = groupMaps[i].get(date);
      if (val !== undefined) {
        lastSeen[i] = val;
      }
      total += lastSeen[i];
    }
    return { date, count: total };
  });
}
```

**Why pure function:**
- **Testable:** No side effects, easy to unit test with Vitest
- **Reusable:** Any future admin view needing sparse time-series aggregation can import this
- **KISS:** Forward-fill is the simplest correct algorithm
- **OCP:** New group types work without modifying the function

**Integration with Chart.js:**
```typescript
// AdminStatistics.vue
import { mergeGroupedCumulativeSeries } from '@/utils/timeSeriesUtils';

async function fetchTrendData(): Promise<void> {
  const response = await axios.get(`${apiUrl}/api/statistics/entities_over_time`, {
    params: { aggregate: 'entity_id', group: 'category', summarize: granularity.value },
    headers: getAuthHeaders(),
  });

  const allData = response.data.data ?? [];
  trendData.value = mergeGroupedCumulativeSeries(allData);
  // Chart.js EntityTrendChart component consumes trendData as { date, count }[]
}
```

**Chart.js v4.5.1 already registered in EntityTrendChart.vue:**
- CategoryScale, LinearScale, PointElement, LineElement for time-series
- Filler for area charts (optional)
- Paul Tol Muted color palette for scientific credibility

**No new dependencies required.**

---

### 3. Admin Data Integrity UI Patterns (Bug #167)

**Status:** Bootstrap-Vue-Next v0.42.0 provides all required components

**Requirements:**
- Display 13 suffix-gene misalignment cases in sortable table
- Show entity details (gene, disease, inheritance, category)
- Curator action buttons (Approve Fix, Reassign, Dismiss)
- Status badges (Pending, Resolved, Flagged)
- Alert boxes for critical issues requiring manual review

**Pattern (existing ManageAnnotations.vue as reference):**
```vue
<template>
  <BCard>
    <template #header>
      <h5>Entity Data Integrity Issues</h5>
      <span class="badge bg-warning">{{ pendingCount }} pending review</span>
    </template>

    <!-- Critical issues alert -->
    <BAlert v-if="hasCriticalIssues" variant="danger" show>
      <h6 class="alert-heading">Critical Issues Detected</h6>
      <p class="mb-2 small">
        {{ criticalCount }} entities have suffix-gene misalignments requiring curator review.
      </p>
    </BAlert>

    <!-- Issues table -->
    <BTable
      :items="integrityIssues"
      :fields="[
        { key: 'entity_id', label: 'Entity', sortable: true },
        { key: 'hgnc_id', label: 'Gene', sortable: true },
        { key: 'symbol', label: 'Symbol', sortable: true },
        { key: 'disease_ontology_name', label: 'Disease', sortable: false },
        { key: 'issue_type', label: 'Issue', sortable: true },
        { key: 'actions', label: 'Actions', sortable: false },
      ]"
      striped
      hover
      responsive
      class="mb-0"
    >
      <!-- Custom action column -->
      <template #cell(actions)="{ item }">
        <BButton
          size="sm"
          variant="success"
          @click="approveFixForEntity(item.entity_id)"
        >
          Approve Fix
        </BButton>
        <BButton
          size="sm"
          variant="outline-secondary"
          class="ms-1"
          @click="reassignEntity(item.entity_id)"
        >
          Reassign
        </BButton>
      </template>
    </BTable>

    <!-- User assignment dropdown (curator selection) -->
    <BFormSelect
      v-model="selectedCuratorId"
      :options="curatorOptions"
      size="sm"
      style="max-width: 250px"
      class="mt-3"
    >
      <BFormSelectOption :value="null">Assign to curator...</BFormSelectOption>
    </BFormSelect>
  </BCard>
</template>
```

**Key components (all in Bootstrap-Vue-Next v0.42.0):**
- **BTable**: Sortable, responsive tables with custom cell rendering
- **BAlert**: Color-coded alert boxes (danger, warning, info)
- **BButton**: Action buttons with size/variant control
- **BFormSelect**: Dropdown for curator assignment
- **BCard**: Consistent card layout with header/body
- **BSpinner**: Loading indicators for async operations

**Pattern already validated in:**
- `ManageAnnotations.vue` — Ontology update blocked entities table (lines 103-116)
- `ManagePubtator.vue` — Publication annotation management
- `AdminStatistics.vue` — KPI cards and charts

**No new dependencies required.**

---

## Backend Patterns

### 4. PubTator3 API Rate Limiting (Bug #170)

**Status:** httr2 v1.2.2 provides req_retry with exponential backoff

**Official rate limit:** 3 requests per second (per PubTator3 API documentation)

**Current implementation issues:**
- `pubtator-functions.R` has placeholder rate limiting (2.5s delay)
- Missing batch deduplication logic (96% annotation storage failures)
- No exponential backoff on transient errors

**Corrected pattern:**
```r
# functions/pubtator-functions.R (EXISTING FILE)

# PubTator3 API Rate Limiting Configuration
# Official limit: 3 requests/second
PUBTATOR_RATE_LIMIT_DELAY <- 0.35  # 350ms = ~2.8 req/s (conservative)
PUBTATOR_MAX_PMIDS_PER_REQUEST <- 100  # Batch size (API recommendation)
PUBTATOR_MAX_RETRIES <- 3
PUBTATOR_BACKOFF_BASE <- 2  # Exponential backoff (2^x seconds)

#' Execute PubTator API call with rate limiting and exponential backoff
pubtator_rate_limited_call <- function(api_func, ..., max_retries = PUBTATOR_MAX_RETRIES) {
  retries <- 0
  while (retries <= max_retries) {
    tryCatch(
      {
        if (retries > 0) {
          backoff_time <- PUBTATOR_BACKOFF_BASE^retries + runif(1, 0, 1)
          log_info("Retry {retries}/{max_retries}, backing off {round(backoff_time, 1)}s...")
          Sys.sleep(backoff_time)
        }
        result <- api_func(...)
        Sys.sleep(PUBTATOR_RATE_LIMIT_DELAY)  # Rate limit after successful call
        return(result)
      },
      error = function(e) {
        retries <<- retries + 1
        if (retries > max_retries) {
          log_error(skip_formatter(paste("API call failed after", max_retries, "retries:", e$message)))
          return(NULL)
        }
        log_warn(skip_formatter(paste("API call failed (attempt", retries, "):", e$message)))
      }
    )
  }
  return(NULL)
}
```

**httr2 req_retry pattern (existing in omim-functions.R as reference):**
```r
# functions/omim-functions.R (lines 73-79)
response <- request(url) %>%
  req_retry(
    max_tries = 3,
    max_seconds = 60,
    backoff = ~ 2^.x  # Exponential backoff: 2s, 4s, 8s
  ) %>%
  req_timeout(30) %>%
  req_perform()
```

**Batch deduplication pattern:**
```r
# Before inserting annotations, deduplicate by (pmid, type, identifier, start_pos, end_pos)
annotations_to_insert <- annotations %>%
  dplyr::distinct(pmid, type, identifier, start_pos, end_pos, .keep_all = TRUE)

# Hash for change detection (existing: digest package in renv.lock)
annotation_hash <- digest::digest(list(pmid, annotations), algo = "xxhash64")
```

**Why httr2 over base httr:**
- httr2 v1.2.2 is modern reimagining with pipe-based interface
- Built-in retry logic with backoff (no manual loops needed)
- Better error handling for API wrapping packages
- Already used in 17+ API function files (omim-functions.R, mondo-functions.R, etc.)

**Sources:**
- [PubTator3 API Documentation](https://www.ncbi.nlm.nih.gov/research/pubtator3/) — Official rate limits
- [httr2 Documentation](https://httr2.r-lib.org/) — req_retry patterns

---

### 5. Cross-Database Category Normalization (Bug #173)

**Status:** dplyr v1.1.4 group_by + summarise (already in renv.lock)

**Problem:** `CurationComparisons.vue` shows cross-database maximum category instead of per-source categories. When PanelApp has "Definitive" (4) and OMIM has "Moderate" (2), the display shows "Definitive" for both, losing per-source granularity.

**Root cause:** Backend aggregation uses `MAX(category_numeric)` across all sources, not per-source.

**Solution pattern:**
```r
# Repository function (e.g., functions/comparison-repository.R)

get_curation_comparisons <- function(gene_id, conn = NULL) {
  query <- "
    SELECT
      cs.source_name,
      cs.category,
      ndd.hgnc_id,
      ndd.disease_ontology_id_version
    FROM ndd_curation_sources cs
    LEFT JOIN ndd_entity ndd
      ON cs.hgnc_id = ndd.hgnc_id
      AND cs.disease_ontology_id_version = ndd.disease_ontology_id_version
    WHERE ndd.hgnc_id = ?
  "

  result <- db_execute_query(query, params = list(gene_id), conn = conn)

  # Normalize categories per source (not across sources)
  result %>%
    dplyr::group_by(source_name, hgnc_id, disease_ontology_id_version) %>%
    dplyr::summarise(
      category = dplyr::first(category),  # Per-source category
      .groups = "drop"
    )
}
```

**Why dplyr over base R:**
- Explicit namespace (`dplyr::group_by`) prevents masking by biomaRt::select
- Pipe-based interface matches existing codebase style
- Well-tested in existing API functions (285 packages in renv.lock include dplyr)

**Integration:** No frontend changes needed. Backend returns per-source categories, frontend CurationComparisons table displays them correctly.

---

### 6. Traefik v3 Host() Matcher (Bug #169)

**Status:** Traefik v3.6 already in docker-compose.yml

**Problem:** TLS certificate selection requires Host() matcher in router rules. Current configuration may be missing explicit Host() for some routes.

**Traefik v3 syntax (verified):**
```yaml
# docker-compose.yml service labels
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=Host(`sysndd.example.com`) && PathPrefix(`/api`)"
  - "traefik.http.routers.api.entrypoints=web"
  - "traefik.http.routers.api.tls=true"
  - "traefik.http.routers.api.tls.certresolver=letsencrypt"
```

**Key points (Traefik v3.6 documentation):**
- Host() matcher matches request's Host header (case-insensitive)
- Non-ASCII domains require punycode encoding (RFC 3492)
- HostHeader() was removed in v3 — use Host() instead
- Multiple matchers can be combined with && operator

**Example for SysNDD:**
```yaml
api:
  labels:
    - "traefik.http.routers.api.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api`)"
    - "traefik.http.routers.api.tls.certresolver=letsencrypt"
    - "traefik.http.routers.api.tls.domains[0].main=sysndd.dbmr.unibe.ch"

app:
  labels:
    - "traefik.http.routers.app.rule=Host(`sysndd.dbmr.unibe.ch`)"
    - "traefik.http.routers.app.tls.certresolver=letsencrypt"
```

**No code changes required — configuration only.**

**Sources:**
- [Traefik v3.6 HTTP Routers Documentation](https://doc.traefik.io/traefik/v3.6/routing/routers/)
- [Traefik v3 Rules & Priority](https://doc.traefik.io/traefik/reference/routing-configuration/http/routing/rules-and-priority/)

---

## What NOT to Add

### Lodash/Underscore for Array Operations
**Why not:** TypeScript/ES2024 provides `.map()`, `.filter()`, `.reduce()`, `.sort()` natively. Forward-fill is 10 lines of vanilla code.

### RxJS for Request Cancellation
**Why not:** AbortController is browser native and axios-integrated. RxJS adds 50KB+ for functionality we don't need.

### Moment.js for Date Handling
**Why not:** date-fns v4.1.0 already in package.json. For simple ISO date strings, native Date is sufficient.

### Special Rate Limiting Library for R
**Why not:** httr2 v1.2.2 has built-in req_retry. Manual Sys.sleep() for inter-request delay is 1 line.

### New Charting Library
**Why not:** Chart.js v4.5.1 + vue-chartjs v5.3.3 already handle line charts with time-series. EntityTrendChart.vue proves pattern works.

---

## Version Summary

All stack elements verified as current:

| Component | Current Version | Latest (2026-02-08) | Status |
|-----------|----------------|---------------------|--------|
| **Frontend** | | | |
| Vue | 3.5.25 | 3.5.x | Current |
| TypeScript | 5.9.3 | 5.9.x | Current |
| Axios | 1.13.4 | 1.13.x | Current, AbortController support |
| Bootstrap-Vue-Next | 0.42.0 | 0.42.x | Current |
| Chart.js | 4.5.1 | 4.x | Current |
| vue-chartjs | 5.3.3 | 5.x | Current |
| date-fns | 4.1.0 | 4.x | Current |
| Vitest | 4.0.18 | 4.x | Current |
| **Backend** | | | |
| R | 4.5.2 | 4.5.x | Current |
| httr2 | 1.2.2 | 1.2.x | Current |
| dplyr | 1.1.4 | 1.1.x | Current |
| digest | (in renv.lock) | — | Present |
| DBI + pool | (in renv.lock) | — | Present |
| logger | (in renv.lock) | — | Present |
| **Infrastructure** | | | |
| Traefik | v3.6 | 3.x | Current |
| MySQL | 8.4.8 | 8.4.x | Current |

---

## Installation

**No new packages required.** All bug fixes use existing dependencies.

**Verification commands:**
```bash
# Frontend — verify axios supports AbortController (v0.22.0+)
cd app && npm list axios

# Backend — verify httr2 and dplyr versions
cd api && Rscript -e "packageVersion('httr2'); packageVersion('dplyr')"

# Infrastructure — verify Traefik v3.6
docker compose config | grep "traefik:v3"
```

---

## Pattern Integration Checklist

Before implementing bug fixes, verify:

- [ ] `app/src/utils/timeSeriesUtils.ts` created with `mergeGroupedCumulativeSeries()`
- [ ] Vitest unit tests written for time-series forward-fill edge cases
- [ ] AbortController pattern documented in `AdminStatistics.vue` for other developers
- [ ] PubTator rate limiting constants verified against official docs (3 req/s)
- [ ] httr2 req_retry backoff tested with mock failures
- [ ] Bootstrap-Vue-Next BTable pattern validated in ManageAnnotations.vue
- [ ] Traefik Host() matcher syntax verified in docker-compose.yml
- [ ] dplyr namespace usage explicit (`dplyr::group_by`, `dplyr::summarise`) to prevent biomaRt masking

---

## Sources

### Browser APIs
- [Cancellation | Axios Docs](https://axios-http.com/docs/cancellation)
- [AbortController - Web APIs | MDN](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)
- [Efficient Request Handling in React with Axios and AbortController](https://medium.com/@rakeshraj2097/efficient-request-handling-in-react-with-axios-and-abortcontroller-e47bafab87c9)

### External APIs
- [PubTator3 API Documentation](https://www.ncbi.nlm.nih.gov/research/pubtator3/)
- [PubTator3 Paper (Nucleic Acids Research)](https://academic.oup.com/nar/article-pdf/52/W1/W540/58436124/gkae235.pdf)

### R Packages
- [httr2: Perform HTTP Requests](https://httr2.r-lib.org/)
- [dplyr: A Grammar of Data Manipulation](https://dplyr.tidyverse.org/)
- [tidyr::fill() Documentation](https://tidyr.tidyverse.org/reference/fill.html)

### Infrastructure
- [Traefik HTTP Routers Rules & Priority](https://doc.traefik.io/traefik/reference/routing-configuration/http/routing/rules-and-priority/)
- [Traefik v3 Routers Documentation](https://doc.traefik.io/traefik/v3.6/routing/routers/)

### UI Components
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)
- [Chart.js Documentation](https://www.chartjs.org/docs/latest/)

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| AbortController | HIGH | Browser standard, axios v1.13.4 verified support, official docs |
| Time-series aggregation | HIGH | Pure TypeScript, Chart.js v4.5.1 already used in EntityTrendChart.vue |
| PubTator rate limits | MEDIUM | Official docs say 3 req/s, but empirical testing needed for batch size |
| httr2 patterns | HIGH | Already used in 17+ API files (omim-functions.R, mondo-functions.R), req_retry documented |
| Bootstrap-Vue-Next | HIGH | v0.42.0 BTable pattern validated in ManageAnnotations.vue lines 103-116 |
| Traefik Host() | HIGH | Traefik v3.6 official docs, syntax verified in docker-compose.yml |
| dplyr aggregation | HIGH | dplyr v1.1.4 in renv.lock, group_by + summarise well-established pattern |

**Overall confidence:** HIGH — No new dependencies, all patterns validated in existing codebase.
