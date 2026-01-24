# UI/UX Review: SysNDD Analysis Pages

**Date:** 2026-01-24
**Pages Reviewed:**
- `/PhenotypeCorrelations/PhenotypeClusters`
- `/GeneNetworks`
- `/PhenotypeFunctionalCorrelation`
- `/PhenotypeCorrelations` (correlogram)

---

## Executive Summary

The analysis pages are functional but have significant opportunities for improvement in:
1. **Interlinking** - No navigation between related analysis views
2. **Table Filtering** - Only text-based "contains" filters; needs numeric comparisons and dropdowns
3. **Tooltips** - Basic but functional; could be richer with more context
4. **Visual Consistency** - Different layouts across pages
5. **Data Exploration** - No click-through from correlation heatmap to underlying clusters

---

## 1. Page-by-Page Analysis

### 1.1 Phenotype Clustering (`/PhenotypeCorrelations/PhenotypeClusters`)

**Screenshot Analysis:**

| Aspect | Current State | Issue Severity |
|--------|---------------|----------------|
| Layout | Left: bubble chart, Right: table | Good |
| Navigation tabs | Links to correlogram, counts, clustering | Good |
| Cluster selection | Click bubbles to select | Good |
| Tooltip | Basic "Cluster: X, N entities" | Medium |
| Table filters | Text inputs only | High |
| "Entities for cluster" link | Shows `filter=undefined` | **Critical Bug** |

**Identified Issues:**

1. **Critical Bug:** Link shows `filter=undefined` instead of valid hash
   - Location: `AnalysesPhenotypeClusters.vue` line ~107
   - The `hash_filter` is not being properly extracted

2. **Table Type Selector:** Good - allows switching between phenotypes, inheritance, counts

3. **Missing Features:**
   - No legend for cluster colors
   - No cluster count badge in header
   - Cannot compare multiple clusters

### 1.2 Gene Networks (`/GeneNetworks`)

**Screenshot Analysis:**

| Aspect | Current State | Issue Severity |
|--------|---------------|----------------|
| Layout | Left: bubble chart, Right: table | Good |
| Cluster/Subcluster toggle | Dropdown selector | Good |
| Table type | Term enrichment vs Identifiers | Good |
| Category badges | Colored "Compartments" badges | Good |
| FDR formatting | Scientific notation | Good |
| Description links | External links to STRING | Good |

**Identified Issues:**

1. **No tabs/navigation** - Unlike PhenotypeClusters, this page is standalone
   - Should link to PhenotypeFunctionalCorrelation

2. **Hover tooltip** - Need to verify if working (couldn't trigger in test)

3. **Category filter** - Should be a dropdown with available categories, not text input

4. **FDR filter** - Should support `< 0.05` or `> 1e-10` comparisons

### 1.3 Phenotype-Functional Correlation (`/PhenotypeFunctionalCorrelation`)

**Screenshot Analysis:**

| Aspect | Current State | Issue Severity |
|--------|---------------|----------------|
| Heatmap | Clear red-blue color scale | Good |
| Axis labels | fc_1-5, pc_1-5 visible | Good |
| Tooltip | Shows "fc_X vs. pc_Y, Corr: value" | Good |
| Boundary lines | Separates fc and pc quadrants | Good |
| Download buttons | **Missing** (commented out) | Medium |

**Identified Issues:**

1. **No click-through navigation** - Clicking a cell should link to the corresponding cluster
   - e.g., clicking fc_2 vs pc_3 cell should offer links to:
     - `/GeneNetworks?cluster=2`
     - `/PhenotypeCorrelations/PhenotypeClusters?cluster=3`

2. **No color legend** - Should show -1 to +1 scale

3. **Standalone page** - No tabs linking to the two cluster pages

4. **Download buttons commented out** - Should enable PNG/SVG export

5. **Axis label readability** - "fc_1" and "pc_1" could be more descriptive
   - e.g., "Functional Cluster 1" or at minimum a legend

### 1.4 Phenotype Correlogram (`/PhenotypeCorrelations`)

**Screenshot Analysis:**

| Aspect | Current State | Issue Severity |
|--------|---------------|----------------|
| Matrix size | 38x38 phenotypes | Large but manageable |
| Color scale | Red-white-blue | Good |
| Axis labels | Rotated 45° | Readable |
| Diagonal | Shows self-correlations (red) | Expected |
| Navigation tabs | Links to counts, clustering | Good |

**Identified Issues:**

1. **Hover tooltips** - Need to verify correlation values shown on hover

2. **Click interaction** - Clicking a cell could show which entities share both phenotypes

3. **No zoom/pan** - Large matrix would benefit from zoom controls

4. **No search** - Cannot search for specific phenotype in the matrix

---

## 2. Table Filtering Analysis

### Current Implementation

```javascript
// Current filter structure in AnalyseGeneClusters.vue
filter: {
  any: { content: null, operator: 'contains' },
  category: { content: null, operator: 'contains' },
  number_of_genes: { content: null, operator: 'contains' },
  fdr: { content: null, operator: 'contains' },
  // ...
}
```

**Problem:** All filters use `'contains'` operator with text input, even for numeric columns.

### Recommended Filter Types by Column

| Column | Current | Recommended | Example |
|--------|---------|-------------|---------|
| Category | Text input | **Dropdown select** | Select: [GO, KEGG, MONDO, Compartments] |
| #Genes | Text input | **Numeric range** | Min: 10, Max: 500 |
| FDR | Text input | **Numeric with operators** | `< 0.05`, `<= 1e-10` |
| p-value | Text input | **Numeric with operators** | `< 0.001` |
| v-test | Text input | **Numeric range** | Min: 2, Max: 25 |
| Variable | Text input | Text input (OK) | Contains: "seizure" |
| Description | Text input | Text input (OK) | Contains: "synapse" |
| Symbol | Text input | Text input (OK) | Contains: "PKD" |

### Proposed Filter Component Architecture

```vue
<!-- components/small/ColumnFilter.vue -->
<template>
  <div class="column-filter">
    <!-- Categorical: Dropdown -->
    <BFormSelect
      v-if="type === 'categorical'"
      v-model="localValue"
      :options="options"
      size="sm"
    />

    <!-- Numeric: Comparison operator + value -->
    <BInputGroup v-else-if="type === 'numeric'" size="sm">
      <BFormSelect
        v-model="operator"
        :options="numericOperators"
        style="max-width: 60px"
      />
      <BFormInput
        v-model="localValue"
        type="number"
        :step="step"
        placeholder="Value"
      />
    </BInputGroup>

    <!-- Text: Simple contains -->
    <BFormInput
      v-else
      v-model="localValue"
      :placeholder="placeholder"
      size="sm"
    />
  </div>
</template>

<script setup>
const numericOperators = [
  { value: '=', text: '=' },
  { value: '>', text: '>' },
  { value: '>=', text: '>=' },
  { value: '<', text: '<' },
  { value: '<=', text: '<=' },
  { value: '!=', text: '!=' },
];
</script>
```

---

## 3. Interlinking Recommendations

### Proposed Navigation Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  ANALYSES HUB (New Landing Page)                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Phenotype    │  │ Functional   │  │ Correlation Matrix   │   │
│  │ Clusters     │  │ Clusters     │  │ (Links Both)         │   │
│  │ (MCA/HCPC)   │  │ (STRING)     │  │                      │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘   │
│         │                 │                      │               │
│         └────────────┬────┴──────────────────────┘               │
│                      ▼                                           │
│              Pheno-Func Correlation                              │
│              (Click cell → navigate to cluster)                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation: Add Tabs to All Analysis Pages

```vue
<!-- components/analyses/AnalysisNavigationTabs.vue -->
<template>
  <BNav tabs class="mb-3">
    <BNavItem
      :to="{ name: 'PhenotypeClusters' }"
      :active="$route.name === 'PhenotypeClusters'"
    >
      <i class="bi bi-diagram-3" /> Phenotype Clusters
    </BNavItem>
    <BNavItem
      :to="{ name: 'GeneNetworks' }"
      :active="$route.name === 'GeneNetworks'"
    >
      <i class="bi bi-share" /> Functional Clusters
    </BNavItem>
    <BNavItem
      :to="{ name: 'PhenotypeFunctionalCorrelation' }"
      :active="$route.name === 'PhenotypeFunctionalCorrelation'"
    >
      <i class="bi bi-grid-3x3" /> Cluster Correlation
    </BNavItem>
  </BNav>
</template>
```

### Click-Through from Correlation Heatmap

```javascript
// In AnalysesPhenotypeFunctionalCorrelation.vue
// Add click handler to heatmap cells

function handleCellClick(event, d) {
  // Parse cluster IDs
  const xCluster = d.x; // e.g., "fc_2"
  const yCluster = d.y; // e.g., "pc_3"

  // Show context menu or modal with navigation options
  showClusterNavigationModal({
    correlation: d.value,
    clusters: [
      {
        id: xCluster,
        type: xCluster.startsWith('fc_') ? 'functional' : 'phenotype',
        link: xCluster.startsWith('fc_')
          ? `/GeneNetworks?cluster=${xCluster.replace('fc_', '')}`
          : `/PhenotypeCorrelations/PhenotypeClusters?cluster=${xCluster.replace('pc_', '')}`
      },
      {
        id: yCluster,
        type: yCluster.startsWith('fc_') ? 'functional' : 'phenotype',
        link: yCluster.startsWith('fc_')
          ? `/GeneNetworks?cluster=${yCluster.replace('fc_', '')}`
          : `/PhenotypeCorrelations/PhenotypeClusters?cluster=${yCluster.replace('pc_', '')}`
      }
    ]
  });
}

// Add to rect elements
.on('click', handleCellClick)
.style('cursor', 'pointer')
```

---

## 4. Tooltip Enhancements

### Current Tooltip Implementation

| Page | Current Content | Rating |
|------|-----------------|--------|
| PhenotypeClusters | "Cluster: X, N entities" | Basic |
| GeneNetworks | "Cluster: X.Y, N genes" | Basic |
| Correlation Heatmap | "fc_X vs. pc_Y, Corr: value" | Basic |

### Recommended Tooltip Enhancements

#### For Cluster Bubbles

```javascript
// Enhanced tooltip content
const tooltipContent = `
  <div class="cluster-tooltip">
    <h6>Cluster ${d.cluster}</h6>
    <table>
      <tr><td>Size:</td><td><strong>${d.cluster_size}</strong> genes</td></tr>
      <tr><td>Top enrichment:</td><td>${d.top_enrichment || 'N/A'}</td></tr>
      <tr><td>FDR:</td><td>${d.top_fdr ? d.top_fdr.toExponential(2) : 'N/A'}</td></tr>
    </table>
    <small class="text-muted">Click to view details</small>
  </div>
`;
```

#### For Correlation Heatmap

```javascript
// Enhanced correlation tooltip
const tooltipContent = `
  <div class="correlation-tooltip">
    <h6>${d.x} vs. ${d.y}</h6>
    <div class="correlation-value" style="color: ${colorScale(d.value)}">
      r = ${d.value.toFixed(3)}
    </div>
    <div class="interpretation">
      ${d.value > 0.5 ? 'Strong positive correlation' :
        d.value > 0.2 ? 'Moderate positive correlation' :
        d.value > -0.2 ? 'Weak/no correlation' :
        d.value > -0.5 ? 'Moderate negative correlation' :
        'Strong negative correlation'}
    </div>
    <small class="text-muted">Click to explore clusters</small>
  </div>
`;
```

---

## 5. Visual & Layout Recommendations

### 5.1 Consistent Header Structure

All analysis pages should have:
1. Title with info badge/popover
2. Download buttons (PNG/SVG)
3. Navigation tabs to related views

### 5.2 Color Legend for Heatmaps

```vue
<!-- components/small/ColorLegend.vue -->
<template>
  <div class="color-legend d-flex align-items-center">
    <span class="legend-label">{{ minLabel }}</span>
    <div
      class="legend-gradient mx-2"
      :style="gradientStyle"
    />
    <span class="legend-label">{{ maxLabel }}</span>
  </div>
</template>

<style scoped>
.legend-gradient {
  width: 100px;
  height: 15px;
  border: 1px solid #ccc;
}
</style>
```

### 5.3 Responsive Design Improvements

Current issues:
- Tables don't handle narrow screens well
- Heatmap labels overlap on small screens

Recommendations:
- Use `stacked="md"` on tables (already done)
- Add zoom controls for correlation matrix
- Consider horizontal scroll for wide tables

### 5.4 Loading States

Current: Simple spinner with "Loading..."

Recommended:
```vue
<template>
  <div v-if="loading" class="loading-state text-center p-4">
    <BSpinner />
    <p class="mt-2">{{ loadingMessage }}</p>
    <small v-if="loadingTime > 5" class="text-muted">
      First load may take longer due to computation...
    </small>
    <BProgress
      v-if="loadingProgress"
      :value="loadingProgress"
      class="mt-2"
    />
  </div>
</template>
```

---

## 6. Bugs Identified

### 6.1 Critical: `filter=undefined` in Entity Links

**Location:** `AnalysesPhenotypeClusters.vue`
**Issue:** The "Entities for cluster X" link shows `filter=undefined`

**Root Cause:** The `hash_filter` property from API response is not being properly accessed.

**Fix Required:** Check API response structure and correct property access.

### 6.2 Medium: Download Buttons Disabled

**Location:** `AnalysesPhenotypeFunctionalCorrelation.vue` lines 50-55
**Issue:** Download buttons are commented out

**Fix:** Uncomment and verify they work with the SVG ID.

### 6.3 Low: Inconsistent Tooltip Styling

**Issue:** Each page creates its own tooltip div with slightly different styles.

**Fix:** Create a shared `useTooltip` composable with consistent styling.

---

## 7. Accessibility Considerations

| Issue | Severity | Recommendation |
|-------|----------|----------------|
| Color-only information in heatmaps | Medium | Add patterns or text labels |
| No keyboard navigation in cluster bubbles | Medium | Add tabindex and keydown handlers |
| Tooltips not accessible to screen readers | Medium | Use ARIA live regions |
| Low contrast in some badges | Low | Ensure WCAG 2.1 AA compliance |

---

## 8. Implementation Priority Matrix

| Enhancement | Effort | Impact | Priority |
|-------------|--------|--------|----------|
| Fix `filter=undefined` bug | Low | High | **P0** |
| Enable download buttons | Low | Medium | **P0** |
| Add navigation tabs to all pages | Medium | High | **P1** |
| Implement numeric column filters | Medium | High | **P1** |
| Implement dropdown filters for categories | Medium | High | **P1** |
| Add click-through from correlation heatmap | Medium | High | **P1** |
| Add color legend to heatmaps | Low | Medium | **P2** |
| Enhance tooltips with more context | Medium | Medium | **P2** |
| Add search to correlogram | High | Medium | **P3** |
| Add zoom/pan to correlogram | High | Low | **P3** |

---

## 9. Research Sources

### Table Filter UX
- [Filter UX Design Patterns & Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-filtering)
- [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)
- [Best Practices for Data Tables](https://uxplanet.org/best-practices-for-usable-and-efficient-data-table-in-applications-4a1d1fb29550)

### Coordinated Visualization
- [Interactive and coordinated visualization approaches](https://academic.oup.com/bib/article/20/4/1513/4953976)
- [Ten simple rules for developing visualization tools in genomics](https://pmc.ncbi.nlm.nih.gov/articles/PMC9648702/)

### Vue.js Components
- [Vuetify Data Table Filtering](https://vuetifyjs.com/en/components/data-tables/filtering/)
- [Vue Good Table Column Filter Options](https://xaksis.github.io/vue-good-table/guide/configuration/column-filter-options.html)
- [PrimeVue DataTable](https://primevue.org/datatable/)

---

## 10. Deep Dive: Correlogram Click-Through with URL State

### 10.1 Current State

The analysis pages don't read from URL query parameters:
- `AnalysesPhenotypeClusters.vue`: Uses `activeCluster` local state (line 247)
- `AnalyseGeneClusters.vue`: Uses `activeParentCluster` and `activeSubCluster` local state
- `AnalysesPhenotypeFunctionalCorrelation.vue`: No state management

The routes in `app/src/router/routes.ts` don't define props for query params (unlike `/Entities` which does).

### 10.2 Proposed URL Schema

```
# Phenotype Clusters
/PhenotypeCorrelations/PhenotypeClusters?cluster=3&tableType=quali_inp_var

# Functional Clusters (Gene Networks)
/GeneNetworks?cluster=2&subcluster=1&selectType=subclusters&tableType=term_enrichment

# Correlation Heatmap (for highlighting a cell)
/PhenotypeFunctionalCorrelation?highlight=fc_2,pc_3
```

### 10.3 Implementation: Route Configuration

**Update `app/src/router/routes.ts`:**

```typescript
// PhenotypeClusters with query param support
{
  path: 'PhenotypeClusters',
  name: 'PhenotypeClusters',
  component: () => import(
    '@/components/analyses/AnalysesPhenotypeClusters.vue'
  ),
  props: (route) => ({
    initialCluster: route.query.cluster ? String(route.query.cluster) : '1',
    initialTableType: route.query.tableType || 'quali_inp_var',
  }),
},

// GeneNetworks with query param support
{
  path: '/GeneNetworks',
  name: 'GeneNetworks',
  component: () => import('@/views/analyses/GeneNetworks.vue'),
  props: (route) => ({
    initialCluster: route.query.cluster ? Number(route.query.cluster) : 1,
    initialSubcluster: route.query.subcluster ? Number(route.query.subcluster) : 1,
    initialSelectType: route.query.selectType || 'clusters',
    initialTableType: route.query.tableType || 'term_enrichment',
  }),
},

// Correlation with highlight support
{
  path: '/PhenotypeFunctionalCorrelation',
  name: 'PhenotypeFunctionalCorrelation',
  component: () => import('@/views/analyses/PhenotypeFunctionalCorrelation.vue'),
  props: (route) => ({
    highlightCell: route.query.highlight || null, // e.g., "fc_2,pc_3"
  }),
},
```

### 10.4 Implementation: Component URL Sync

**Create `app/src/composables/useUrlState.js`:**

```javascript
import { ref, watch, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';

/**
 * Composable for syncing component state with URL query parameters
 * @param {Object} stateConfig - Configuration object mapping state keys to URL param names
 * @example
 * const { state, updateUrl } = useUrlState({
 *   cluster: { param: 'cluster', default: '1', type: 'string' },
 *   tableType: { param: 'tableType', default: 'quali_inp_var', type: 'string' }
 * });
 */
export function useUrlState(stateConfig) {
  const router = useRouter();
  const route = useRoute();

  // Initialize state from URL or defaults
  const state = {};
  Object.entries(stateConfig).forEach(([key, config]) => {
    const urlValue = route.query[config.param];
    const initialValue = urlValue !== undefined
      ? parseValue(urlValue, config.type)
      : config.default;
    state[key] = ref(initialValue);
  });

  // Parse URL value to correct type
  function parseValue(value, type) {
    switch (type) {
      case 'number': return Number(value);
      case 'boolean': return value === 'true';
      case 'array': return value.split(',');
      default: return String(value);
    }
  }

  // Update URL when state changes
  function updateUrl() {
    const query = { ...route.query };

    Object.entries(stateConfig).forEach(([key, config]) => {
      const value = state[key].value;
      if (value !== config.default) {
        query[config.param] = config.type === 'array' ? value.join(',') : String(value);
      } else {
        delete query[config.param]; // Remove default values from URL
      }
    });

    router.replace({ query });
  }

  // Watch for state changes and update URL
  Object.keys(state).forEach(key => {
    watch(state[key], updateUrl, { immediate: false });
  });

  return { state, updateUrl };
}
```

### 10.5 Implementation: Phenotype Clusters with URL State

**Update `AnalysesPhenotypeClusters.vue`:**

```vue
<script>
import { useUrlState } from '@/composables/useUrlState';

export default {
  name: 'AnalysesPhenotypeClusters',
  setup() {
    // URL state management
    const { state } = useUrlState({
      activeCluster: { param: 'cluster', default: '1', type: 'string' },
      tableType: { param: 'tableType', default: 'quali_inp_var', type: 'string' },
    });

    return {
      activeCluster: state.activeCluster,
      tableType: state.tableType,
    };
  },
  // ... rest of component uses activeCluster.value instead of this.activeCluster
};
</script>
```

### 10.6 Implementation: Clickable Correlogram with Pinned Tooltip

**Update `AnalysesPhenotypeFunctionalCorrelation.vue`:**

```javascript
data() {
  return {
    loadingCorrelation: false,
    correlationMatrix: {},
    correlationMelted: [],
    // NEW: Pinned cell state
    pinnedCell: null, // { x: 'fc_2', y: 'pc_3', value: 0.85 }
  };
},

methods: {
  renderHeatmap() {
    // ... existing setup code ...

    // Tooltip with pinned state
    const tooltip = d3
      .select('#phenotypeFunctionalCorrelationViz')
      .append('div')
      .attr('class', 'tooltip')
      .style('opacity', 0)
      .style('position', 'absolute')
      .style('background-color', 'white')
      .style('border', '1px solid #ccc')
      .style('padding', '10px')
      .style('border-radius', '8px')
      .style('box-shadow', '0 2px 8px rgba(0,0,0,0.15)')
      .style('pointer-events', 'auto') // Allow interaction with tooltip
      .style('z-index', '9999');

    const self = this;

    // Click handler - pins the tooltip
    function handleClick(event, d) {
      event.stopPropagation();

      // Toggle pin: if clicking same cell, unpin
      if (self.pinnedCell && self.pinnedCell.x === d.x && self.pinnedCell.y === d.y) {
        self.pinnedCell = null;
        tooltip.style('opacity', 0);
        d3.selectAll('rect').style('stroke', 'none');
        return;
      }

      // Pin this cell
      self.pinnedCell = { x: d.x, y: d.y, value: d.value };

      // Highlight the clicked cell
      d3.selectAll('rect').style('stroke', 'none');
      d3.select(event.target).style('stroke', 'black').style('stroke-width', 2);

      // Generate navigation links
      const fcLink = d.x.startsWith('fc_')
        ? `/GeneNetworks?cluster=${d.x.replace('fc_', '')}`
        : `/PhenotypeCorrelations/PhenotypeClusters?cluster=${d.x.replace('pc_', '')}`;
      const pcLink = d.y.startsWith('pc_')
        ? `/PhenotypeCorrelations/PhenotypeClusters?cluster=${d.y.replace('pc_', '')}`
        : `/GeneNetworks?cluster=${d.y.replace('fc_', '')}`;

      // Build tooltip with links
      tooltip
        .html(`
          <div class="pinned-tooltip">
            <div class="tooltip-header">
              <strong>${d.x} vs. ${d.y}</strong>
              <button class="close-btn" onclick="document.querySelector('.pinned-tooltip').closest('.tooltip').style.opacity=0">×</button>
            </div>
            <div class="correlation-value" style="font-size: 1.5em; color: ${self.getCorrelationColor(d.value)}; margin: 8px 0;">
              r = ${d.value.toFixed(3)}
            </div>
            <div class="interpretation" style="margin-bottom: 12px; color: #666;">
              ${self.interpretCorrelation(d.value)}
            </div>
            <div class="navigation-links">
              <a href="${d.x.startsWith('fc_') ? fcLink : pcLink}" class="cluster-link" style="display: block; margin: 4px 0; color: #0066cc;">
                → View ${d.x} cluster details
              </a>
              <a href="${d.y.startsWith('fc_') ? fcLink : pcLink}" class="cluster-link" style="display: block; margin: 4px 0; color: #0066cc;">
                → View ${d.y} cluster details
              </a>
            </div>
          </div>
        `)
        .style('opacity', 1)
        .style('left', `${event.pageX + 15}px`)
        .style('top', `${event.pageY - 15}px`);
    }

    // Modified mouseover - don't show if pinned
    function handleMouseOver(event, d) {
      if (self.pinnedCell) return; // Don't hover if pinned
      tooltip.style('opacity', 1);
      d3.select(event.target).style('stroke', 'black');
    }

    // Modified mouseleave - don't hide if pinned
    function handleMouseLeave(event, d) {
      if (self.pinnedCell) return; // Keep showing if pinned
      tooltip.style('opacity', 0);
      d3.select(event.target).style('stroke', 'none');
    }

    // Draw rectangles with click handler
    svg
      .selectAll('rect')
      .data(data)
      .enter()
      .append('rect')
      .attr('x', (d) => x(d.x))
      .attr('y', (d) => y(d.y))
      .attr('width', x.bandwidth())
      .attr('height', y.bandwidth())
      .style('fill', (d) => colorScale(d.value))
      .style('cursor', 'pointer')
      .on('mouseover', handleMouseOver)
      .on('mousemove', handleMouseMove)
      .on('mouseleave', handleMouseLeave)
      .on('click', handleClick);

    // Click outside to unpin
    d3.select('#phenotypeFunctionalCorrelationViz').on('click', function(event) {
      if (event.target.tagName !== 'rect' && !event.target.closest('.tooltip')) {
        self.pinnedCell = null;
        tooltip.style('opacity', 0);
        d3.selectAll('rect').style('stroke', 'none');
      }
    });
  },

  // Helper methods
  getCorrelationColor(value) {
    if (value > 0.5) return '#d73027';
    if (value > 0.2) return '#fc8d59';
    if (value > -0.2) return '#999';
    if (value > -0.5) return '#91bfdb';
    return '#4575b4';
  },

  interpretCorrelation(value) {
    if (value > 0.7) return 'Strong positive correlation';
    if (value > 0.4) return 'Moderate positive correlation';
    if (value > 0.2) return 'Weak positive correlation';
    if (value > -0.2) return 'No significant correlation';
    if (value > -0.4) return 'Weak negative correlation';
    if (value > -0.7) return 'Moderate negative correlation';
    return 'Strong negative correlation';
  },
},
```

### 10.7 Tooltip CSS Styling

```css
/* Add to AnalysesPhenotypeFunctionalCorrelation.vue <style> */
.pinned-tooltip {
  min-width: 200px;
}

.tooltip-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #eee;
  padding-bottom: 8px;
  margin-bottom: 8px;
}

.close-btn {
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  color: #999;
  padding: 0 4px;
}

.close-btn:hover {
  color: #333;
}

.cluster-link {
  text-decoration: none;
  padding: 4px 8px;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.cluster-link:hover {
  background-color: #f0f0f0;
}

.navigation-links {
  border-top: 1px solid #eee;
  padding-top: 8px;
  margin-top: 8px;
}
```

### 10.8 Complete Data Flow

```
User clicks heatmap cell (fc_2, pc_3)
         │
         ▼
┌─────────────────────────────────┐
│  Tooltip pins with:             │
│  • Correlation value: r=0.65    │
│  • Interpretation: Moderate +   │
│  • Link: View fc_2 cluster →    │
│  • Link: View pc_3 cluster →    │
└─────────────────────────────────┘
         │
         │ User clicks "View fc_2 cluster"
         ▼
┌─────────────────────────────────┐
│  Navigation to:                 │
│  /GeneNetworks?cluster=2        │
│                                 │
│  Component reads URL param      │
│  Sets activeParentCluster = 2   │
│  Highlights cluster 2 bubble    │
│  Shows cluster 2 enrichment     │
└─────────────────────────────────┘
```

### 10.9 Browser Back/Forward Support

With URL state management, users can:
- **Bookmark** a specific cluster view
- **Share links** to specific cluster selections
- Use **browser back/forward** to navigate between selections
- **Deep link** from external sources

### 10.10 Implementation Checklist

- [ ] Create `useUrlState` composable
- [ ] Update routes to pass query params as props
- [ ] Update `AnalysesPhenotypeClusters.vue` to use URL state
- [ ] Update `AnalyseGeneClusters.vue` to use URL state
- [ ] Add click handler to correlation heatmap
- [ ] Implement pinned tooltip with navigation links
- [ ] Add close button and click-outside-to-close behavior
- [ ] Test browser back/forward navigation
- [ ] Test bookmarking and link sharing

---

## 11. Conclusion

The SysNDD analysis pages provide valuable scientific visualizations but need improvements in:

1. **Navigation** - Add consistent tabs linking all analysis views
2. **Filtering** - Replace text-only filters with type-appropriate controls (dropdowns, numeric comparisons)
3. **Interlinking** - Make correlation heatmap cells clickable to navigate to clusters
4. **Tooltips** - Enrich with more contextual information
5. **Bug fixes** - Fix `filter=undefined` issue and enable download buttons

### Recommended Implementation Order

1. **P0 (Immediate):** Fix bugs - `filter=undefined`, enable downloads
2. **P1 (Next Sprint):** Navigation tabs, numeric/dropdown filters, heatmap click-through
3. **P2 (Following):** Enhanced tooltips, color legends
4. **P3 (Backlog):** Correlogram search/zoom

With these improvements, users will be able to explore the relationships between phenotype and functional clusters much more effectively, moving seamlessly between different views and filtering data with appropriate controls.
