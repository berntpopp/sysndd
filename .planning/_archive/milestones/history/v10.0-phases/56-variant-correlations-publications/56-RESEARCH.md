# Phase 56: Variant Correlations & Publications - Research

**Researched:** 2026-01-31
**Domain:** Vue 3 frontend table patterns, D3.js charts, navigation routing
**Confidence:** HIGH

## Summary

This phase addresses two distinct areas: fixing broken navigation links in variant analysis views and bringing the Publications table to parity with the established Entities table patterns.

**Key findings:**
- The Entities table is a mature implementation using `TablesEntities.vue` component with reusable composables (`useTableData`, `useTableMethods`) for pagination, filtering, sorting, and Excel export
- Variant correlation views (`AnalysesVariantCorrelogram`, `AnalysesVariantCounts`) are working D3 visualizations that generate navigation links to a `/Variants/` route **that doesn't exist in the router**
- Publications table exists (`PublicationsNDDTable.vue`) but lacks the full feature set of Entities table (no expandable row details, simpler filter implementation)
- TimePlot and Stats components exist with basic D3 visualizations but lack interactivity features
- PubMed API integration exists in R backend (`check_pmid`, `info_from_pmid` functions) but no frontend metadata display mechanism
- D3 v7.4.2 is installed; existing charts use simple tooltip patterns with no zoom/brush/pan features

**Primary recommendation:** Implement this phase in two separate plans: (1) Variant navigation fixes (quick bug fix), (2) Publications enhancements (following Entities table patterns exactly).

## Standard Stack

### Core Frontend
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Component framework | Project standard |
| Bootstrap-Vue-Next | 0.42.0 | UI components | Migration from Bootstrap-Vue complete |
| D3.js | 7.4.2 | Data visualization | Standard for all charts in app |
| Vue Router | 5.0.1 | Client-side routing | Project standard |
| Axios | 1.13.4 | HTTP client | Project standard (injected) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pinia | 3.0.4 | State management | Used for UI store (scrollbar updates) |
| exceljs | 4.4.0 | Excel export | Already integrated in useTableMethods |
| @vueuse/core | 14.2.0 | Composition utilities | Optional, not currently used in tables |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap-Vue-Next | Native Bootstrap + Vue | More work, no benefit |
| D3.js zoom | Custom implementation | Would lose D3 ecosystem features |
| GenericTable | Custom table component | Already established pattern |

**Installation:**
```bash
# All dependencies already installed in app/package.json
# No new dependencies required
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── views/
│   ├── tables/EntitiesTable.vue          # Route-level wrapper
│   └── analyses/
│       ├── VariantCorrelations.vue       # Parent with tabs
│       └── PublicationsNDD.vue           # Parent with tabs
├── components/
│   ├── tables/TablesEntities.vue         # Full table implementation
│   ├── analyses/
│   │   ├── AnalysesVariantCorrelogram.vue
│   │   ├── AnalysesVariantCounts.vue
│   │   ├── PublicationsNDDTable.vue
│   │   ├── PublicationsNDDTimePlot.vue
│   │   └── PublicationsNDDStats.vue
│   └── small/
│       ├── GenericTable.vue              # Reusable table component
│       ├── TableHeaderLabel.vue
│       ├── TableSearchInput.vue
│       ├── TablePaginationControls.vue
│       └── TableDownloadLinkCopyButtons.vue
└── composables/
    ├── useTableData.ts                   # Table state management
    ├── useTableMethods.ts                # Table action methods
    ├── useUrlParsing.ts                  # Filter/sort serialization
    └── useD3Lollipop.ts                  # D3 lifecycle example
```

### Pattern 1: Table Component Composition
**What:** Separate route wrapper from table implementation; use composables for state and methods
**When to use:** Any paginated table view
**Example:**
```typescript
// In table component setup()
const tableData = useTableData({
  pageSizeInput: props.pageSizeInput,
  sortInput: props.sortInput,
  pageAfterInput: props.pageAfterInput,
});

const tableMethods = useTableMethods(tableData, {
  filter,
  filterObjToStr,
  apiEndpoint: props.apiEndpoint,
  axios,
});
```

**Key architecture decisions from TablesEntities.vue:**
- **Module-level caching:** Uses module-level variables (`moduleLastApiParams`, `moduleApiCallInProgress`) to prevent duplicate API calls across component remounts
- **URL sync timing:** Updates browser URL AFTER successful API response to prevent race conditions
- **Debounced loading:** 50ms debounce on `loadData()` to coalesce multiple state changes
- **History API usage:** Uses `window.history.replaceState()` instead of Vue Router to avoid component remount
- **Initialization flag:** `isInitializing` flag prevents watchers from triggering during setup

### Pattern 2: Row Details Expansion
**What:** GenericTable has built-in `details` column with Show/Hide button
**When to use:** When table rows need expandable detail views
**Example:**
```vue
<!-- In fields array -->
{ key: 'details', label: 'Details' }

<!-- GenericTable handles button and expansion automatically -->
<!-- Detail fields defined separately -->
fields_details: [
  { key: 'hgnc_id', label: 'HGNC ID', class: 'text-start' },
  { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' }
]
```

### Pattern 3: D3 Chart Lifecycle
**What:** Direct D3 manipulation in Vue component with proper cleanup
**When to use:** When rendering D3 visualizations
**Example from AnalysesVariantCorrelogram.vue:**
```javascript
// Remove old SVG before rendering new
d3.select('#matrix_dataviz').select('svg').remove();

// Create new SVG
const svg = d3.select('#matrix_dataviz')
  .append('svg')
  .attr('id', 'matrix-svg')
  .attr('viewBox', '0 0 700 700')
  .attr('preserveAspectRatio', 'xMinYMin meet')
  .append('g')
  .attr('transform', `translate(${margin.left},${margin.top})`);
```

**Key insights from existing D3 code:**
- Use `viewBox` and `preserveAspectRatio` for responsive sizing
- Named event handlers (not inline arrow functions) for better memory management
- Tooltips positioned with `event.layerX` and `event.layerY`
- Loading state overlay with spinner while data fetches

### Pattern 4: Advanced D3 Features (from useD3Lollipop)
**What:** Zoom and brush implemented using D3's built-in functions
**When to use:** Interactive charts requiring zoom/pan
**Example:**
```typescript
// Brush-to-zoom pattern from useD3Lollipop
const brush = d3.brushX()
  .extent([[0, 0], [width, height]])
  .on('end', (event) => {
    if (!event.selection) return;
    const [x0, x1] = event.selection.map(xScale.invert);
    // Update domain and re-render
  });

svg.append('g').call(brush);
```

**Note:** Current publications charts do NOT use zoom/brush - this would be new functionality

### Anti-Patterns to Avoid
- **Watching perPage directly:** PublicationsNDDTable watches `perPage` which causes double-calls; TablesEntities only uses `handlePerPageChange` handler
- **Using router.replace for URL updates:** Causes component remount; use `history.replaceState` instead
- **Inline arrow functions for D3 event handlers:** Named functions enable proper cleanup and avoid memory leaks
- **Forgetting isInitializing flag:** Watchers fire during setup, causing duplicate API calls

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paginated table state | Custom pagination logic | `useTableData` composable | Handles pagination, sorting, filtering, loading states with cursor-based pagination |
| Table action methods | Component-specific methods | `useTableMethods` composable | Handles Excel export, clipboard copy, filter management, URL sync |
| Filter serialization | Custom query string builder | `useUrlParsing` composable | Bidirectional filter/sort conversion to URL params |
| Generic table rendering | Custom BTable wrapper | `GenericTable.vue` component | Handles sortable headers, filter row, expandable details |
| D3 lifecycle management | Direct D3 in component | Pattern from `useD3Lollipop` | Proper cleanup, memory leak prevention, reactive integration |

**Key insight:** The codebase has mature table patterns with composables that handle edge cases (cursor pagination, URL sync timing, remount prevention). Don't rebuild - reuse exactly.

## Common Pitfalls

### Pitfall 1: Broken Navigation Links to Non-Existent Routes
**What goes wrong:** AnalysesVariantCorrelogram and AnalysesVariantCounts generate links to `/Variants/` route which doesn't exist in router
**Why it happens:** Links were created assuming a Variants table view exists (similar to Entities, Genes, Phenotypes)
**How to avoid:**
- Check router configuration before generating navigation links
- Use named routes instead of path strings where possible
- Test all generated links in charts
**Warning signs:**
- 404 errors when clicking chart elements
- Router navigation errors in console
- Broken links in line 196 (AnalysesVariantCorrelogram) and line 194 (AnalysesVariantCounts)

**Current broken links:**
```javascript
// AnalysesVariantCorrelogram.vue line 196
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=...`
) // ❌ /Variants/ route doesn't exist

// AnalysesVariantCounts.vue line 194
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=...`
) // ❌ Same issue
```

### Pitfall 2: Component Remount During API Calls
**What goes wrong:** Updating URL with `router.replace()` or `router.push()` triggers component remount, causing duplicate API calls and lost state
**Why it happens:** Vue Router treats URL changes as navigation events
**How to avoid:** Use `window.history.replaceState()` to update URL without triggering router
**Warning signs:**
- Double API calls in network tab
- Component flashing/re-rendering unexpectedly
- Lost filter/sort state during pagination

**Correct pattern from TablesEntities.vue:**
```javascript
updateBrowserUrl() {
  if (this.isInitializing) return;
  const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
  window.history.replaceState({ ...window.history.state }, '', newUrl);
}
```

### Pitfall 3: Watchers Firing During Initialization
**What goes wrong:** Deep watchers on `filter` and `sortBy` trigger `loadData()` during component mount, causing duplicate initial API call
**Why it happens:** Vue watchers fire even during reactive initialization
**How to avoid:** Use `isInitializing` flag and skip watcher execution during setup
**Warning signs:**
- Double API calls on component mount
- Initial page load slower than expected
- Network tab shows identical simultaneous requests

**Solution from TablesEntities.vue:**
```javascript
data() {
  return { isInitializing: true };
},
watch: {
  filter: {
    handler() {
      if (this.isInitializing) return; // ✅ Skip during init
      this.filtered();
    },
    deep: true,
  },
},
mounted() {
  this.loadData(); // Initial load
  this.$nextTick(() => {
    this.isInitializing = false; // Enable watchers AFTER initial load
  });
}
```

### Pitfall 4: Missing Row Details Implementation
**What goes wrong:** Adding a `details` column field but forgetting to define `fields_details` array results in empty expansion panels
**Why it happens:** GenericTable requires both the `details` field AND `fields_details` prop to render detail views
**How to avoid:** Always define `fields_details` array when using expandable rows
**Warning signs:**
- Details button appears but clicking shows empty card
- No error in console (silent failure)

**Correct pattern:**
```javascript
fields: [
  { key: 'details', label: 'Details' } // Adds Show/Hide button
],
fields_details: [  // ✅ Required for content
  { key: 'hgnc_id', label: 'HGNC ID', class: 'text-start' },
  { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' }
]
```

### Pitfall 5: D3 Memory Leaks from Event Listeners
**What goes wrong:** D3 charts create tooltips and event listeners that persist after component unmount
**Why it happens:** D3 operates outside Vue's reactivity system; manual cleanup required
**How to avoid:** Always remove old SVG and tooltips before rendering new chart
**Warning signs:**
- Multiple tooltips appearing simultaneously
- Memory usage growing over time
- Performance degradation after navigation

**Correct cleanup pattern:**
```javascript
generateGraph() {
  // ✅ Remove previous render
  d3.select('#container').select('svg').remove();
  d3.select('#container').selectAll('.tooltip').remove();

  // Create new visualization
  const svg = d3.select('#container').append('svg');
  // ... chart code
}
```

## Code Examples

Verified patterns from official sources:

### Table Component Setup (TablesEntities.vue)
```typescript
// Source: app/src/components/tables/TablesEntities.vue lines 293-356
setup(props) {
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const colorAndSymbols = useColorAndSymbols();
  const text = useText();

  // Table state composable
  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });

  // Component-specific filter
  const filter = ref({
    any: { content: null, join_char: null, operator: 'contains' },
    entity_id: { content: null, join_char: null, operator: 'contains' },
    // ... more filters
  });

  const axios = inject('axios');

  // Table methods composable
  const tableMethods = useTableMethods(tableData, {
    filter,
    filterObjToStr,
    apiEndpoint: props.apiEndpoint,
    axios,
  });

  // Override methods that need component-specific logic
  const {
    filtered: _filtered,
    handlePageChange: _handlePageChange,
    handlePerPageChange: _handlePerPageChange,
    handleSortByOrDescChange: _handleSortByOrDescChange,
    removeFilters: _removeFilters,
    removeSearch: _removeSearch,
    ...restTableMethods
  } = tableMethods;

  return {
    makeToast,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    ...colorAndSymbols,
    ...text,
    ...tableData,
    ...restTableMethods,
    filter,
    axios,
  };
}
```

### Expandable Row Details (GenericTable.vue)
```vue
<!-- Source: app/src/components/small/GenericTable.vue lines 235-247 -->
<!-- Details column button -->
<template #cell(details)="row">
  <BButton class="btn-xs" variant="outline-primary" @click="row.toggleDetails">
    {{ row.detailsShowing ? 'Hide' : 'Show' }}
  </BButton>
</template>

<!-- Row details expansion -->
<template #row-details="row">
  <BCard>
    <BTable :items="[row.item]" :fields="fieldDetails" stacked small />
  </BCard>
</template>
```

### D3 Chart with Tooltip (AnalysesVariantCounts.vue)
```javascript
// Source: app/src/components/analyses/AnalysesVariantCounts.vue lines 85-206
generateCountGraph() {
  const margin = { top: 30, right: 30, bottom: 200, left: 150 };
  const width = 760 - margin.left - margin.right;
  const height = 500 - margin.top - margin.bottom;

  // Remove old SVG
  d3.select('#count_dataviz').select('svg').remove();

  // Create new SVG
  const svg = d3.select('#count_dataviz')
    .append('svg')
    .attr('id', 'variant-svg')
    .attr('viewBox', '0 0 760 500')
    .attr('preserveAspectRatio', 'xMinYMin meet')
    .append('g')
    .attr('transform', `translate(${margin.left},${margin.top})`);

  const data = this.itemsCount;

  // X axis
  const x = d3.scaleBand()
    .range([0, width])
    .domain(data.map((d) => d.variant_name))
    .padding(0.2);

  svg.append('g')
    .attr('transform', `translate(0,${height})`)
    .call(d3.axisBottom(x))
    .selectAll('text')
    .attr('transform', 'translate(-10,0)rotate(-45)')
    .style('text-anchor', 'end')
    .style('font-size', '12px');

  // Y axis
  const maxY = d3.max(data, (d) => d.count);
  const y = d3.scaleLinear()
    .domain([0, maxY * 1.1])
    .range([height, 0]);

  svg.append('g').call(d3.axisLeft(y));

  // Tooltip
  const tooltip = d3.select('#count_dataviz')
    .append('div')
    .style('opacity', 0)
    .attr('class', 'tooltip')
    .style('background-color', 'white')
    .style('border', 'solid 1px #ccc')
    .style('border-radius', '5px')
    .style('padding', '4px')
    .style('position', 'absolute')
    .style('pointer-events', 'none');

  // Named event handlers
  const mouseover = function() {
    tooltip.style('opacity', 1);
    d3.select(this).style('stroke', 'black');
  };

  const mousemove = function(event, d) {
    tooltip
      .html(`Count: ${d.count}<br>(${d.variant_name})`)
      .style('left', `${event.layerX + 20}px`)
      .style('top', `${event.layerY + 20}px`);
  };

  const mouseleave = function() {
    tooltip.style('opacity', 0);
    d3.select(this).style('stroke', 'none');
  };

  // Bars with links and event handlers
  svg.selectAll('mybar')
    .data(data)
    .enter()
    .append('a')
    .attr('xlink:href', (d) => `/Variants/?sort=entity_id&filter=...`)
    .attr('aria-label', (d) => `Link to variants table for ${d.vario_id}`)
    .append('rect')
    .attr('x', (d) => x(d.variant_name))
    .attr('y', (d) => y(d.count))
    .attr('width', x.bandwidth())
    .attr('height', (d) => height - y(d.count))
    .attr('fill', '#69b3a2')
    .on('mouseover', mouseover)
    .on('mousemove', mousemove)
    .on('mouseleave', mouseleave);
}
```

### Filter Object Structure
```javascript
// Source: app/src/components/tables/TablesEntities.vue lines 308-319
const filter = ref({
  any: { content: null, join_char: null, operator: 'contains' },
  entity_id: { content: null, join_char: null, operator: 'contains' },
  symbol: { content: null, join_char: null, operator: 'contains' },
  disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
  disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
  hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
  hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
  ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
  category: { content: null, join_char: ',', operator: 'any' },
  entities_count: { content: null, join_char: ',', operator: 'any' },
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Bootstrap-Vue | Bootstrap-Vue-Next | 2024 | All tables migrated to new API |
| router.replace() for URL sync | history.replaceState() | Phase 55 | Prevents component remount |
| Single loadData call | Module-level caching | Phase 55 | Prevents duplicate API calls |
| Inline event handlers | Named handlers | Phase 45 | Better memory management for D3 |
| String sortBy format | Array format [{ key, order }] | Bootstrap-Vue-Next migration | More flexible multi-column sorting |

**Deprecated/outdated:**
- `treeselect`: Vue 2 library, replaced with BFormSelect (multi-select pending proper implementation)
- `bootstrap-vue`: Replaced by bootstrap-vue-next
- Old Bootstrap-Vue `sortBy` string format: Now uses array format `[{ key: 'column', order: 'asc'|'desc' }]`

## Open Questions

Things that couldn't be fully resolved:

1. **PubMed API Caching Strategy**
   - What we know: R backend has `check_pmid()` and `info_from_pmid()` functions that fetch from PubMed API
   - What's unclear: No database schema found for publication metadata cache (title, abstract, authors)
   - Recommendation: Plan should include database schema investigation; may need new table or JSON column in existing `publication` table

2. **Variants Table View**
   - What we know: Links point to `/Variants/` route which doesn't exist in router
   - What's unclear: Was this route removed in a previous phase, or never implemented?
   - Recommendation: Either create minimal Variants table view OR change links to point to Entities table with variant filter

3. **D3 Zoom Implementation Pattern**
   - What we know: `useD3Lollipop` composable shows brush-to-zoom pattern exists
   - What's unclear: Whether to create `useD3TimePlot` composable or keep inline in component
   - Recommendation: For single use case (TimePlot), inline implementation is acceptable; extract to composable if pattern repeats

4. **PublicationsNDD Stats API Endpoint**
   - What we know: Frontend fetches from `/api/statistics/publication_stats`
   - What's unclear: Full parameter schema and response format not verified in R backend
   - Recommendation: Include API endpoint verification in plan tasks

## Variant View Investigation

### Current Navigation Links
Both variant analysis components generate links to filter views:

**AnalysesVariantCorrelogram.vue (line 193-197):**
```javascript
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.x_vario_id},${d.y_vario_id})&page_after=0&page_size=10`
)
```

**AnalysesVariantCounts.vue (line 191-195):**
```javascript
.attr('xlink:href', (d) =>
  `/Variants/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.vario_id})&page_after=0&page_size=10`
)
```

### Problem: Route Doesn't Exist
**Checked:** `app/src/router/routes.ts` - No `/Variants` route defined
**Existing table routes:** `/Entities`, `/Genes`, `/Phenotypes` (all working)
**Impact:** Clicking on any chart element in variant correlation or variant counts views results in 404

### Solutions (Implementation Decision Required)
1. **Create Variants table view** - New route + view + component (more work, but consistent with other views)
2. **Redirect to Entities table with variant filter** - Change links to `/Entities/?filter=...` (simpler, but less clear UX)
3. **Modal/panel detail view** - Show filtered entities in modal instead of navigation (most work, different pattern)

**Recommendation:** Solution 2 (redirect to Entities table) is quickest and maintains existing patterns. Variants are always linked to entities, so showing entity table with variant filter is semantically correct.

## Publications Views

### Current Structure
```
PublicationsNDD.vue (parent with tabs)
├── PublicationsNDDTable (default route)
├── PublicationsNDDTimePlot
└── PublicationsNDDStats
```

### PublicationsNDDTable Current State
**Has:**
- Basic pagination (working)
- Basic sorting (working)
- Basic filtering (per-column and global search)
- Excel export (working)
- Copy link (working)

**Missing (compared to Entities table):**
- Expandable row details (no `details` column)
- `fields_details` array for detail view
- Advanced filter options (dropdown selects for categorical fields)
- Module-level API call caching
- `isInitializing` flag to prevent duplicate calls
- Proper URL sync timing (may have remount issues)

**API Endpoint:** `/api/publication` (confirmed in component line 206)

### PublicationsNDDTimePlot Current State
**Has:**
- Basic line plot for publication/update dates
- Basic bar plot for publication types
- Mode selector (publication_date, update_date, type_counts)
- Simple tooltips

**Missing:**
- Zoom (mouse wheel)
- Pan (drag)
- Brush (range selection)
- Click-to-filter (link to Publications table with date filter)
- Cumulative view toggle
- Time aggregation options (year/month/quarter selector)

**API Endpoint:** `/api/statistics/publication_stats` (confirmed line 83)

### PublicationsNDDStats Current State
**Has:**
- Bar charts for journals, authors, keywords
- Category selector
- Min count filters for each category
- Tooltips

**Missing:**
- Metrics cards (publications this year, growth rate, newest date)
- Visual consistency polish
- Responsive sizing improvements

**API Endpoint:** `/api/statistics/publication_stats` (same as TimePlot)

## API Endpoints

### Variant Endpoints
```
GET /api/variant/browse
  - Params: sort, filter, fields, page_after, page_size, fspec, format
  - Returns: Cursor pagination with entities filtered by variant
  - Used by: Would be used by Variants table (if created)

GET /api/variant/correlation
  - Params: filter
  - Returns: Correlation matrix data (x, y, value)
  - Used by: AnalysesVariantCorrelogram.vue

GET /api/variant/count
  - Params: None (implied filter in implementation)
  - Returns: Variant count data (variant_name, vario_id, count)
  - Used by: AnalysesVariantCounts.vue
```

### Publication Endpoints
```
GET /api/publication
  - Params: sort, filter, fields, page_after, page_size, format
  - Returns: Cursor pagination with publication data
  - Used by: PublicationsNDDTable.vue

GET /api/publication/<pmid>
  - Returns: Single publication metadata by PMID
  - Fields: publication_id, Title, Abstract, Lastname, Firstname, Publication_date, Journal, Keywords
  - Used by: Not currently used in frontend

GET /api/statistics/publication_stats
  - Params: min_journal_count, min_lastname_count, min_keyword_count, time_aggregate
  - Returns: Complex object with:
    - publication_date_aggregated: [{ Publication_date, count }]
    - update_date_aggregated: [{ update_date, count }]
    - publication_type_counts: [{ publication_type, count }]
    - journal_counts: [{ Journal, count }]
    - last_name_counts: [{ Lastname, count }]
    - keyword_counts: [{ Keywords, count }]
  - Used by: PublicationsNDDTimePlot.vue, PublicationsNDDStats.vue
```

### PubMed API Integration (Backend)
```
R functions in api/functions/publication-functions.R:
  - check_pmid(pmid_input): Validates PMIDs exist in PubMed
  - info_from_pmid(pmid): Fetches metadata from PubMed API
  - new_publication(publications_received): Adds new publications to database

Backend fetches: title, abstract, authors, journal, publication date, keywords
Frontend display: Currently missing; needs implementation
```

## Implementation Notes

### Variant Navigation Fix
**Scope:** VCOR-01, VCOR-02
**Approach:** Change hardcoded `/Variants/` links to `/Entities/` with same filter parameters
**Files to modify:**
- `app/src/components/analyses/AnalysesVariantCorrelogram.vue` (line 193-197)
- `app/src/components/analyses/AnalysesVariantCounts.vue` (line 191-195)
**Testing:** Click on correlation matrix cells and variant bars to verify navigation works

### Publications Table Enhancement
**Scope:** PUB-01
**Approach:** Refactor `PublicationsNDDTable.vue` to match `TablesEntities.vue` patterns exactly
**Key changes:**
1. Add `isInitializing` flag and guard watchers
2. Implement module-level API caching pattern
3. Add `fields_details` array with metadata fields
4. Add `details` column to fields
5. Change URL sync to use `history.replaceState()`
6. Remove `perPage` watcher (use only `handlePerPageChange`)
**Files to modify:** `app/src/components/analyses/PublicationsNDDTable.vue`

### Publication Metadata Display
**Scope:** PUB-02
**Approach:**
1. Verify `/api/publication/<pmid>` endpoint returns required fields
2. Add metadata fields to `fields_details` array
3. Implement abstract truncation in detail view (GenericTable already handles stacked display)
**Open question:** Database schema for caching - needs investigation
**Files to modify:**
- `app/src/components/analyses/PublicationsNDDTable.vue` (add fields_details)
- Potentially: `api/endpoints/publication_endpoints.R` (if caching needed)

### TimePlot Interactivity
**Scope:** PUB-03
**Approach:**
1. Add D3 zoom behavior for mouse wheel zoom
2. Add D3 drag behavior for panning
3. Add D3 brush for date range selection
4. Add click handlers that construct filter URL and navigate to Publications table
5. Add time aggregation selector (year/month/quarter radio buttons)
6. Add cumulative view toggle (checkbox)
**Pattern reference:** `useD3Lollipop` composable for brush-to-zoom example
**Files to modify:** `app/src/components/analyses/PublicationsNDDTimePlot.vue`

### Stats View Polish
**Scope:** PUB-04
**Approach:**
1. Add metrics cards component above charts
2. Fetch summary metrics from same API endpoint
3. Calculate derived metrics (this year, growth rate) from aggregated data
4. Match card styling from other analysis views
**Files to modify:** `app/src/components/analyses/PublicationsNDDStats.vue`

### Technical Considerations
**Bootstrap-Vue-Next compatibility:**
- All table components use new array-based `sortBy` format: `[{ key: 'column', order: 'asc'|'desc' }]`
- GenericTable handles both legacy string and new array formats via computed property

**Performance considerations:**
- Module-level caching prevents duplicate API calls (critical for good UX)
- Debouncing prevents filter/sort changes from overwhelming API
- D3 chart cleanup prevents memory leaks on re-render

**Accessibility:**
- All chart links need `aria-label` attributes (already present in variant components)
- Expandable row details work with keyboard navigation (GenericTable handles)
- Form controls need proper labeling (existing pattern in Stats component)

## Sources

### Primary (HIGH confidence)
- **Codebase investigation:** Direct file reading of all components, composables, and router configuration
- `app/src/components/tables/TablesEntities.vue` - Complete table implementation pattern
- `app/src/components/small/GenericTable.vue` - Reusable table component specification
- `app/src/composables/useTableData.ts` - Table state management composable
- `app/src/composables/useTableMethods.ts` - Table action methods composable
- `app/src/composables/useD3Lollipop.ts` - D3 lifecycle and brush-to-zoom pattern
- `app/src/components/analyses/AnalysesVariantCorrelogram.vue` - Variant correlation view with broken links
- `app/src/components/analyses/AnalysesVariantCounts.vue` - Variant counts view with broken links
- `app/src/components/analyses/PublicationsNDDTable.vue` - Current publications table implementation
- `app/src/components/analyses/PublicationsNDDTimePlot.vue` - Current time plot implementation
- `app/src/components/analyses/PublicationsNDDStats.vue` - Current stats implementation
- `app/src/router/routes.ts` - Complete routing configuration
- `api/endpoints/variant_endpoints.R` - Variant API endpoints specification
- `api/endpoints/publication_endpoints.R` - Publication API endpoints specification
- `api/functions/publication-functions.R` - PubMed API integration functions
- `app/package.json` - Dependencies and versions (D3 v7.4.2, Bootstrap-Vue-Next v0.42.0)

### Secondary (MEDIUM confidence)
- Phase 55 context - Prior decisions on authorization, logging, validation patterns

### Tertiary (LOW confidence)
- None - All research based on direct codebase investigation

## Metadata

**Confidence breakdown:**
- Existing patterns: HIGH - Direct codebase investigation with full file access
- Variant navigation issue: HIGH - Verified routes.ts lacks /Variants route
- Publications table gaps: HIGH - Side-by-side comparison with TablesEntities.vue
- D3 patterns: HIGH - Multiple examples in codebase (variant charts, lollipop composable)
- API endpoints: MEDIUM - Frontend usage verified, backend stubs seen but not fully traced
- PubMed integration: MEDIUM - Backend functions exist but caching strategy unclear

**Research date:** 2026-01-31
**Valid until:** 30 days (stable established patterns; framework versions unlikely to change rapidly)
