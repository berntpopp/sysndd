---
phase: 27-advanced-features-filters
verified: 2026-01-25T16:30:00Z
status: gaps_found
score: 4/6 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 4/6
  gaps_closed:
    - "Data tables provide category dropdown filters (CategoryFilter integrated)"
    - "Data tables provide FDR threshold filters (ScoreSlider integrated)"
  gaps_remaining:
    - "Correlation heatmap navigation (architectural limitation - navigates to filtered phenotypes instead of clusters)"
  regressions: []
  new_gaps:
    - "FDR column sorting broken (scientific notation strings)"
    - "FDR filter preset values too high for actual data range"
gaps:
  - truth: "Data tables provide numeric range filters (FDR < 0.05) that work correctly"
    status: partial
    reason: "ScoreSlider component integrated but has two critical issues: (1) FDR column sorting broken due to scientific notation strings, (2) preset values (0.01/0.05/0.1) don't match actual data range (values like 10^-20)"
    artifacts:
      - path: "app/src/components/analyses/AnalyseGeneClusters.vue"
        issue: "FDR column marked sortable but no sortCompare function for scientific notation"
      - path: "app/src/components/filters/ScoreSlider.vue"
        issue: "Default presets [0.01, 0.05, 0.1] too high for actual FDR values (10^-20 range)"
    missing:
      - "Add sortCompare function to FDR field definition that parses scientific notation: (a, b) => parseFloat(a) - parseFloat(b)"
      - "Update ScoreSlider default presets to scientific notation values: [1e-10, 1e-5, 0.05] or allow exponential input"
      - "Consider formatting FDR display values as scientific notation (1.23e-20) instead of raw strings"
  - truth: "Clicking a cluster in correlation heatmap navigates to corresponding phenotype cluster view"
    status: partial
    reason: "Architectural limitation documented in 27-09: phenotype pairs don't map to entity clusters. Click navigation works but goes to filtered phenotypes table, not cluster view. This is semantically correct given the data model."
    artifacts:
      - path: "app/src/components/analyses/AnalysesPhenotypeCorrelogram.vue"
        issue: "Click handler navigates to /Phenotypes with filter, not /Analysis?tab=clusters&cluster=N"
      - path: "api/endpoints/phenotype_endpoints.R"
        issue: "Correlation endpoint cannot include cluster_id due to architectural mismatch (phenotypes are features, clusters are entity groups)"
    missing:
      - "Architectural enhancement: Consider entity-cluster-to-cluster correlation endpoint for cluster navigation"
      - "OR: Accept current behavior as correct (phenotype pair → filtered entities is semantically accurate)"
human_verification:
  - test: "FDR column sort"
    expected: "Clicking FDR column header should sort rows by numeric FDR value (smallest to largest)"
    why_human: "Need to verify actual sort behavior in browser with real data"
  - test: "FDR filter with very small values"
    expected: "Selecting 'Custom' in FDR filter and entering 1e-10 should filter to rows with FDR < 1e-10"
    why_human: "Need to verify custom value input accepts scientific notation"
  - test: "Wildcard search interaction"
    expected: "Enter 'PKD*' in search, network highlights matching nodes, table shows only matching genes"
    why_human: "Real-time visual validation of network highlighting and filter sync"
---

# Phase 27: Advanced Features & Filters Re-Verification Report

**Phase Goal:** Establish competitive differentiators through wildcard gene search, comprehensive filters, bidirectional network-table navigation, and UI polish

**Verified:** 2026-01-25T16:30:00Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure plans 27-06 through 27-10

## Re-Verification Summary

**Previous Verification (2026-01-25T15:00:00Z):**
- Status: gaps_found
- Score: 4/6 truths verified (66%)
- 2 gaps identified

**Current Verification:**
- Status: gaps_found  
- Score: 4/6 truths verified (66%)
- Gaps closed: 2 (CategoryFilter/ScoreSlider integration)
- Gaps remaining: 2 (1 partial + 1 new issue discovered)
- Regressions: 0
- New gaps: 2 (FDR sort + FDR filter range)

### Gap Closure Analysis

**✅ GAP 1 CLOSED: Filter Components Integration**
- **Previous state:** CategoryFilter and ScoreSlider created but orphaned (not imported/used)
- **Fixed in:** Plan 27-07 (commits c380c24, 642580b, 3c04a05, a831d19)
- **Verification:**
  - ✅ CategoryFilter imported at line 337 of AnalyseGeneClusters.vue
  - ✅ ScoreSlider imported at line 338 of AnalyseGeneClusters.vue
  - ✅ CategoryFilter rendered at lines 169-175 for category column
  - ✅ ScoreSlider rendered at lines 178-182 for fdr column
  - ✅ categoryFilter state (line 432) and watcher (line 649)
  - ✅ fdrThreshold state (line 433) and watcher (line 653)
  - ✅ applyFilters logic uses both (lines 934-945)
- **Status:** VERIFIED — components fully integrated and functional

**⚠️ GAP 2 PARTIAL: Correlation Heatmap Navigation**
- **Previous state:** Click handler imported useFilterSync but didn't call setCluster/setTab
- **Addressed in:** Plans 27-09 and 27-10
- **Plan 27-09 findings:** Architectural analysis revealed phenotype correlations (HPO term pairs) cannot map to entity clusters (gene groups). This is a data model constraint, not an implementation gap.
- **Plan 27-10 fix:** Removed unused useFilterSync import that broke /PhenotypeCorrelations page
- **Current behavior:** Click navigates to `/Phenotypes/?filter=all(modifier_phenotype_id,x,y)` (line 290-294 of AnalysesPhenotypeCorrelogram.vue)
- **Verification:**
  - ✅ Click handler implemented (line 289-294)
  - ✅ Vue Router integration works
  - ✅ useFilterSync correctly removed (not needed for current navigation pattern)
  - ❌ Cluster navigation not possible due to architectural limitation
- **Status:** PARTIAL — Navigation works correctly given the data model, but doesn't achieve original goal (cluster view navigation)
- **Recommendation:** Accept current behavior OR create separate cluster-to-cluster correlation endpoint in future phase

**❌ NEW GAP 3: FDR Column Sorting Broken**
- **Discovered during:** Re-verification code inspection + user feedback
- **Issue:** FDR column marked `sortable: true` (line 558) but values are scientific notation STRINGS ("1.23e-20")
- **Root cause:** No `sortCompare` function to parse strings as numbers → lexicographic sort fails
- **Impact:** Users cannot sort by statistical significance
- **Evidence:**
  - FDR field at lines 556-561: `sortable: true` but no `sortCompare`
  - FDR cell template (line 237): `{{ row.fdr }}` renders raw value
  - Scientific notation strings sort incorrectly: "1e-5" < "1e-20" lexicographically
- **Status:** FAILED — Critical usability issue

**❌ NEW GAP 4: FDR Filter Range Mismatch**
- **Discovered during:** User feedback (actual data has values like 10^-20, not 0.01/0.05)
- **Issue:** ScoreSlider default presets [0.01, 0.05, 0.1] too high for actual FDR range
- **Root cause:** Generic presets don't match domain-specific data distribution
- **Impact:** Users cannot effectively filter by significance (all real results are < 0.01)
- **Evidence:**
  - ScoreSlider presets (lines 42-44 of ScoreSlider.vue): `[0.01, 0.05, 0.1]`
  - User feedback: "actual data has values like 10^-20"
  - Filter logic (line 943): `fdrValue >= this.fdrThreshold` works correctly but thresholds are wrong
- **Status:** FAILED — Usability issue (presets don't match data)

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence | Change |
|---|-------|--------|----------|--------|
| 1 | User can search genes with wildcard patterns (PKD*, BRCA?) | ✓ VERIFIED | useWildcardSearch.ts (218 lines), TermSearch component with autocomplete (213 lines) | No change |
| 2 | Network highlights matching nodes from search query | ✓ VERIFIED | NetworkVisualization watches filterState.search, applies search-match CSS classes (lines 594-605) | No change |
| 3 | Data tables provide column-level text filters, numeric range filters (FDR < 0.05), and dropdown categorical filters | ⚠️ PARTIAL | CategoryFilter & ScoreSlider NOW INTEGRATED (Gap 1 closed), but FDR sort broken + presets wrong (Gaps 3 & 4) | IMPROVED (was PARTIAL) |
| 4 | Clicking cluster in correlation heatmap navigates to cluster view | ⚠️ PARTIAL | Click navigation works → filtered phenotypes table (correct given architecture). Cluster navigation architecturally infeasible. | IMPROVED (was FAILED) |
| 5 | Filter state persists in URL for bookmarkable views | ✓ VERIFIED | useFilterSync.ts uses VueUse useUrlSearchParams with history mode | No change |
| 6 | Navigation tabs connect all analysis pages | ✓ VERIFIED | AnalysisTabs.vue + AnalysisView.vue + /Analysis route in router | No change |

**Score:** 4/6 truths verified (66% — same as previous, but composition changed)

### Required Artifacts

| Artifact | Expected | Status | Details | Change |
|----------|----------|--------|---------|--------|
| `app/src/composables/useFilterSync.ts` | URL-synced filter state | ✓ VERIFIED | 265 lines, VueUse integration | No change |
| `app/src/composables/useWildcardSearch.ts` | Wildcard pattern matching | ✓ VERIFIED | 218 lines, converts * and ? to regex | No change |
| `app/src/composables/useNetworkHighlight.ts` | Bidirectional hover sync | ✓ VERIFIED | 313 lines, source tracking prevents loops | No change |
| `app/src/components/filters/CategoryFilter.vue` | Dropdown filter | ✓ WIRED | 44 lines, NOW integrated in AnalyseGeneClusters | WAS ORPHANED → NOW WIRED |
| `app/src/components/filters/ScoreSlider.vue` | Numeric range filter | ⚠️ PARTIAL | 100 lines, NOW integrated BUT presets wrong (0.01/0.05/0.1 vs 10^-20 data) | WAS ORPHANED → NOW PARTIAL |
| `app/src/components/filters/TermSearch.vue` | Wildcard search input | ✓ VERIFIED | 213 lines, autocomplete suggestions | No change |
| `app/src/components/navigation/AnalysisTabs.vue` | Tab navigation | ✓ VERIFIED | 140 lines, uses useFilterSync | No change |
| `app/src/views/AnalysisView.vue` | Tab orchestrator | ✓ VERIFIED | 163 lines, lazy loads components | No change |
| `app/src/components/analyses/ColorLegend.vue` | Color scale legend | ✓ VERIFIED | 151 lines, used in AnalysesPhenotypeCorrelogram | No change |

### Key Link Verification

| From | To | Via | Status | Details | Change |
|------|----|-----|--------|---------|--------|
| NetworkVisualization | useFilterSync | watch filterState.search | ✓ WIRED | Lines 737-743 watches and updates highlighting | No change |
| NetworkVisualization | useWildcardSearch | searchMatches() | ✓ WIRED | Lines 604-605 applies classes based on matches | No change |
| AnalysisTabs | useFilterSync | setTab() | ✓ WIRED | Lines 91-93 calls setTab on click | No change |
| AnalysisView | components | dynamic :is | ✓ WIRED | Switches based on filterState.tab | No change |
| /Analysis route | AnalysisView | router | ✓ WIRED | Lines 143-145 in routes.ts | No change |
| CategoryFilter | AnalyseGeneClusters | import + v-model | ✓ WIRED | Line 337 import, lines 169-175 template, line 432 state, line 649 watcher | WAS NOT_WIRED → NOW WIRED |
| ScoreSlider | AnalyseGeneClusters | import + v-model | ✓ WIRED | Line 338 import, lines 178-182 template, line 433 state, line 653 watcher | WAS NOT_WIRED → NOW WIRED |
| CorrelogramClick | /Phenotypes | D3 click + router | ✓ WIRED | Lines 289-294 click handler navigates to filtered phenotypes | WAS NOT_WIRED → NOW WIRED |
| FDR field | sortCompare | table field config | ✗ NOT_WIRED | Field marked sortable but no numeric sort function | NEW GAP |

### Requirements Coverage

| Requirement | Status | Blocking Issue | Change |
|-------------|--------|----------------|--------|
| FILT-01 (Column text filters) | ✓ SATISFIED | - | No change |
| FILT-02 (Numeric range filters) | ⚠️ BLOCKED | FDR sort broken + presets wrong | NEW BLOCKER |
| FILT-03 (Dropdown categorical) | ✓ SATISFIED | - | WAS BLOCKED → NOW SATISFIED |
| FILT-04 (Wildcard search) | ✓ SATISFIED | - | No change |
| FILT-05 (Search highlighting) | ✓ SATISFIED | - | No change |
| FILT-06 (CategoryFilter component) | ✓ SATISFIED | - | WAS BLOCKED → NOW SATISFIED |
| FILT-07 (ScoreSlider component) | ⚠️ PARTIAL | Presets don't match data range | WAS BLOCKED → NOW PARTIAL |
| FILT-08 (TermSearch component) | ✓ SATISFIED | - | No change |
| NAVL-01 (Analysis tabs) | ✓ SATISFIED | - | No change |
| NAVL-02 (Heatmap click navigation) | ⚠️ PARTIAL | Architectural limitation (phenotype pairs ≠ clusters) | WAS BLOCKED → NOW PARTIAL |
| NAVL-03 (URL state sync) | ✓ SATISFIED | - | No change |
| NAVL-04 (Bookmarkable views) | ✓ SATISFIED | - | No change |
| NAVL-05 (Bidirectional hover) | ✓ SATISFIED | - | No change |
| NAVL-06 (useFilterSync composable) | ✓ SATISFIED | - | No change |
| NAVL-07 (Fix filter=undefined bug) | ✓ SATISFIED | Fixed in Plan 27-06 | WAS PENDING → NOW SATISFIED |
| UIUX-01 (Color legend) | ✓ SATISFIED | - | No change |
| UIUX-02 (Enhanced tooltips) | ✓ SATISFIED | - | No change |
| UIUX-03 (Download buttons) | ✓ SATISFIED | - | No change |
| UIUX-04 (Loading states) | ✓ SATISFIED | - | No change |
| UIUX-05 (Error retry) | ✓ SATISFIED | - | No change |

**Coverage Summary:**
- Total requirements: 20
- Satisfied: 15 (75%)
- Partial: 3 (15%) — FILT-02, FILT-07, NAVL-02
- Blocked: 0
- Not started: 0

**Improvement:** 2 requirements moved from BLOCKED to SATISFIED (FILT-03, FILT-06), 1 from PENDING to SATISFIED (NAVL-07), 2 from BLOCKED to PARTIAL (FILT-07, NAVL-02). Net: +4 addressed, -1 new blocker (FILT-02 FDR sort).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| AnalyseGeneClusters.vue | 556-561 | FDR field sortable but no sortCompare for scientific notation | 🛑 BLOCKER | Users cannot sort by significance |
| ScoreSlider.vue | 42-44 | Generic presets [0.01, 0.05, 0.1] don't match FDR data range (10^-20) | ⚠️ WARNING | Presets ineffective for real data |

No stub patterns, TODO comments, or placeholder implementations found. Components are substantive.

### Human Verification Required

### 1. Wildcard Search UX
**Test:** Navigate to /Analysis?tab=networks, enter "PKD*" in search
**Expected:** Network nodes matching PKD1, PKD2, etc. highlight with yellow border; non-matching nodes fade to 30% opacity. Autocomplete dropdown shows matching suggestions.
**Why human:** Visual appearance, real-time interaction, autocomplete UX

### 2. Tab Navigation
**Test:** Click each tab (Phenotype Clusters, Gene Networks, Correlation)
**Expected:** URL updates to ?tab=clusters/networks/correlation, corresponding view loads, browser back/forward works
**Why human:** Navigation flow and URL state persistence

### 3. Filter Badge and Clear
**Test:** Enter search pattern, observe "1 filter active" badge, click Clear
**Expected:** Badge shows count, Clear button resets all filters, URL updates
**Why human:** UI feedback and interaction

### 4. Category Dropdown Filter
**Test:** In Gene Networks table (term_enrichment mode), select "GO" from category dropdown
**Expected:** Table filters to show only Gene Ontology terms, other categories hidden
**Why human:** Dropdown interaction and filtering behavior

### 5. FDR Numeric Sort (CRITICAL)
**Test:** In Gene Networks table (term_enrichment mode), click FDR column header
**Expected:** Rows sort by numeric FDR value (smallest to largest, most significant first)
**Likely result:** Incorrect sort order (lexicographic instead of numeric)
**Why human:** Need to verify the broken sort behavior with real data

### 6. FDR Custom Filter Value
**Test:** Select "Custom" in FDR filter, enter 1e-10, observe results
**Expected:** Only rows with FDR < 1e-10 shown (very strict significance threshold)
**Why human:** Verify custom value input accepts scientific notation

### 7. Correlation Heatmap Click
**Test:** Click a cell in the correlation heatmap
**Expected:** Navigate to /Phenotypes page with filter showing entities having both phenotypes from the clicked cell
**Why human:** Navigation behavior and filtered results validation

### 8. Bidirectional Hover Sync
**Test:** In Gene Networks, hover over a node in the network graph
**Expected:** Corresponding row in the identifiers table highlights. Then hover over a row in table.
**Expected:** Corresponding node in network highlights.
**Why human:** Real-time visual synchronization between network and table

## Gaps Summary

**Gap 1: FDR Column Sorting Broken (CRITICAL)**

The FDR column is marked as sortable in the table configuration, but sorting fails because FDR values are scientific notation strings like "1.23e-20". Bootstrap Vue's default sort performs lexicographic comparison, causing incorrect ordering (e.g., "1e-20" sorts before "1e-5" alphabetically).

**Technical details:**
- Field definition (lines 556-561): `{ key: 'fdr', label: 'FDR', sortable: true }`
- Missing: `sortCompare: (a, b, key) => parseFloat(a[key]) - parseFloat(b[key])`
- Impact: Users cannot identify most significant results by sorting

**Fix required:**
```javascript
{
  key: 'fdr',
  label: 'FDR',
  sortable: true,
  sortCompare: (a, b) => parseFloat(a) - parseFloat(b),
  thClass: 'text-start bg-light',
  tdClass: 'text-start',
}
```

**Gap 2: FDR Filter Presets Don't Match Data Range**

ScoreSlider default presets are [0.01, 0.05, 0.1], but user feedback indicates actual FDR values are in the 10^-20 range. These presets are too high to be useful — filtering with "< 0.01" would show nearly all results.

**Technical details:**
- ScoreSlider.vue lines 42-44: Default presets [0.01, 0.05, 0.1]
- User feedback: "actual data has values like 10^-20, not 0.01/0.05"
- Custom value input exists but requires knowing to enter scientific notation

**Fix options:**
1. Update default presets to reflect actual data: `[1e-10, 1e-5, 0.05]`
2. Pass domain-specific presets from AnalyseGeneClusters when rendering ScoreSlider
3. Add scientific notation input support with exponent selector

**Gap 3: Correlation Heatmap Cluster Navigation (Architectural Limitation)**

Original goal was "clicking a cluster in correlation heatmap navigates to corresponding phenotype cluster view." Analysis in Plan 27-09 revealed this is architecturally infeasible:

- Phenotype correlation shows relationships between **HPO terms** (phenotype features)
- Phenotype clustering groups **entities** (genes) by phenotype similarity
- No direct mapping exists from phenotype pair → entity cluster

**Current behavior:**
- Click navigates to `/Phenotypes/?filter=all(modifier_phenotype_id,x,y)`
- Shows entities having BOTH phenotypes from the clicked cell
- This is semantically correct and useful

**Recommendation:** Accept current behavior as architecturally correct OR create a separate cluster-to-cluster correlation endpoint for entity cluster navigation (major feature, would be separate phase).

**Gap 4: Hover Tooltips on Truncated Text (Minor)**

User feedback requested "nice hovers to display truncated text values." Current state:
- ✓ FDR column has tooltip (line 234): `:title="row.fdr != null ? Number(row.fdr).toFixed(10) : ''"`
- ✓ Description column has tooltip (line 251): `:title="row.term"`
- ✓ Symbol column doesn't need tooltip (badges are self-contained)
- ⚠️ STRING_id column has `overflow-hidden text-truncate` (line 288) but no tooltip

This is a minor polish issue, not blocking goal achievement.

---

**Root Cause Analysis:**
- Gap 1 (FDR sort): Missing sortCompare function — simple oversight
- Gap 2 (FDR presets): Generic component used with domain-specific data without customization
- Gap 3 (Cluster navigation): Architectural mismatch discovered during implementation (not a bug, a design constraint)
- Gap 4 (Tooltips): Minor polish item from user feedback

---

*Verified: 2026-01-25T16:30:00Z*
*Verifier: Claude (gsd-verifier)*
