# Phase 27: Advanced Features & Filters - Research

**Researched:** 2026-01-25
**Domain:** Wildcard gene search, comprehensive table filters, bidirectional network-table navigation, URL state sync, and UI polish
**Confidence:** HIGH

## Summary

Phase 27 delivers competitive differentiators through four interconnected feature sets: (1) wildcard gene search with network highlighting, (2) comprehensive data table filters (text, numeric range, categorical), (3) bidirectional network-table synchronization, and (4) URL state persistence for shareable/bookmarkable views. Research confirms VueUse's `useUrlSearchParams` as the optimal URL sync solution, integrating seamlessly with Vue 3's reactivity system. The existing SysNDD codebase provides strong foundations: `useUrlParsing.ts` handles filter serialization, `TableSearchInput.vue` implements debounced search, and `DownloadImageButtons.vue` shows export patterns.

The wildcard search implementation uses JavaScript regex conversion (replacing `*` with `.*` and `?` with `.`) matching biologist mental models. Cytoscape.js selector API (`cy.nodes('[symbol ^= "PKD"]')`) enables efficient node matching for network highlighting, with smooth CSS class transitions for glow/pulse effects on matching nodes. User decisions from CONTEXT.md establish clear UX patterns: inline column filters, preset FDR thresholds, horizontal navigation tabs, and bidirectional hover highlighting between table rows and network nodes.

Critical integration points include: (1) shared filter state across all analysis views via composable pattern, (2) URL format following existing Entities table conventions (`/analysis?tab=networks&search=PKD*&fdr=0.05`), (3) click behavior consistency (node click and table row click both navigate to entity detail), and (4) correlation heatmap cluster navigation zooming to cluster members in network view. The implementation leverages existing patterns from Phase 26 (Cytoscape.js composables) and Phase 25 (backend optimizations) for a cohesive analysis experience.

**Primary recommendation:** Create `useFilterSync.ts` composable wrapping VueUse's `useUrlSearchParams` with shared reactive filter state, implement wildcard matching via simple regex conversion, and build reusable filter components (CategoryFilter, ScoreSlider, TermSearch) following existing component patterns.

## Standard Stack

The established libraries and tools for filtering, URL sync, and UI enhancements.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| VueUse | 11.3+ | URL state sync composables | useUrlSearchParams provides reactive URL params, 50K+ weekly downloads, official Vue 3 support, bidirectional history sync |
| Cytoscape.js | 3.33.1 | Network node selection/highlighting | Already integrated in Phase 26, selector API supports wildcard matching, CSS class-based styling |
| Bootstrap-Vue-Next | 0.42.0 | UI components (BTabs, BFormSelect, BFormInput) | Current SysNDD standard, provides BNav for URL-synced tabs, inline form controls |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| wildcard-match | 5.1.3 | Glob pattern compilation to regex | Optional - only if custom regex conversion proves insufficient for complex patterns |
| @vueuse/core | 11.3+ | useDebounceFn, useEventListener | Debounce utilities, event handling for bidirectional highlighting |
| file-saver | 2.0.5 | Already installed | PNG/SVG download triggers (existing pattern in DownloadImageButtons.vue) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| VueUse useUrlSearchParams | Manual history API | VueUse handles edge cases (concurrent updates, mode switching), tested extensively; manual requires significant boilerplate |
| Custom regex for wildcards | wildcard-match library | Simple `*` and `?` patterns trivially converted via regex; library overkill for single-pattern use case |
| BNav with router | BTabs | BTabs inappropriate for URL-changing navigation per Bootstrap accessibility guidelines; BNav with nested routes proper pattern |
| Shared composable state | Pinia store | Composable sufficient for component-tree-scoped state; Pinia adds complexity without cross-tree requirements |

**Installation:**
```bash
# VueUse already likely installed; verify
npm install @vueuse/core@latest

# No additional dependencies needed - leveraging existing stack
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── composables/
│   ├── useFilterSync.ts        # NEW: URL state sync + shared filter state
│   ├── useWildcardSearch.ts    # NEW: Pattern matching for gene search
│   ├── useNetworkHighlight.ts  # NEW: Network node highlighting coordination
│   └── index.ts                # Export barrel (update)
├── components/
│   ├── filters/                # NEW: Reusable filter components
│   │   ├── CategoryFilter.vue  # FILT-06: Dropdown categorical filter
│   │   ├── ScoreSlider.vue     # FILT-07: Numeric range with presets
│   │   └── TermSearch.vue      # FILT-08: Wildcard search input
│   ├── navigation/
│   │   └── AnalysisTabs.vue    # NEW: Shared tab navigation
│   └── analyses/
│       ├── AnalyseGeneClusters.vue        # Update: Add filter integration
│       ├── AnalysesPhenotypeClusters.vue  # Update: Add filter integration
│       └── AnalysesPhenotypeCorrelogram.vue # Update: Add click navigation
└── views/
    └── AnalysisView.vue        # NEW: Parent view with shared state
```

### Pattern 1: useFilterSync Composable with VueUse
**What:** Composable wrapping VueUse's useUrlSearchParams to provide reactive filter state synced with URL, shared across analysis views.
**When to use:** Always for filter state that should persist in URL
**Why:** Provides bookmarkable/shareable URLs, browser back/forward navigation, SSR-friendly state management

**Example:**
```typescript
// Source: VueUse useUrlSearchParams docs + existing useUrlParsing.ts pattern
// composables/useFilterSync.ts
import { ref, computed, watch } from 'vue';
import { useUrlSearchParams } from '@vueuse/core';

export interface FilterState {
  tab: 'clusters' | 'networks' | 'correlation';
  search: string;          // Wildcard gene search pattern
  fdr: number | null;      // FDR threshold (0.01, 0.05, 0.1, or custom)
  category: string | null; // GO, KEGG, MONDO
  cluster: number | null;  // Selected cluster ID
}

export function useFilterSync() {
  // VueUse handles URL sync automatically
  const params = useUrlSearchParams('history', {
    removeNullishValues: true,
    removeFalsyValues: false,
    write: true,
    writeMode: 'replace', // Don't spam history
  });

  // Typed reactive filter state derived from URL params
  const filterState = computed<FilterState>(() => ({
    tab: (params.tab as FilterState['tab']) || 'clusters',
    search: (params.search as string) || '',
    fdr: params.fdr ? parseFloat(params.fdr as string) : null,
    category: (params.category as string) || null,
    cluster: params.cluster ? parseInt(params.cluster as string, 10) : null,
  }));

  // Update functions that sync back to URL
  const setTab = (tab: FilterState['tab']) => {
    params.tab = tab;
  };

  const setSearch = (search: string) => {
    params.search = search || undefined; // Remove if empty
  };

  const setFdr = (fdr: number | null) => {
    params.fdr = fdr !== null ? fdr.toString() : undefined;
  };

  const setCategory = (category: string | null) => {
    params.category = category || undefined;
  };

  const setCluster = (cluster: number | null) => {
    params.cluster = cluster !== null ? cluster.toString() : undefined;
  };

  const clearAllFilters = () => {
    // Clear all except tab
    const currentTab = params.tab;
    Object.keys(params).forEach(key => {
      if (key !== 'tab') {
        delete (params as Record<string, unknown>)[key];
      }
    });
    // Restore tab
    if (currentTab) params.tab = currentTab;
  };

  // Active filter count for badge
  const activeFilterCount = computed(() => {
    let count = 0;
    if (filterState.value.search) count++;
    if (filterState.value.fdr !== null) count++;
    if (filterState.value.category) count++;
    if (filterState.value.cluster !== null) count++;
    return count;
  });

  return {
    filterState,
    activeFilterCount,
    setTab,
    setSearch,
    setFdr,
    setCategory,
    setCluster,
    clearAllFilters,
    // Raw params for edge cases
    rawParams: params,
  };
}
```

### Pattern 2: Wildcard Search with Regex Conversion
**What:** Convert biologist-friendly wildcard patterns (PKD*, BRCA?) to JavaScript regex for matching gene symbols.
**When to use:** For gene search matching in network and table views
**Why:** Simple, no library dependency, matches biologist mental models

**Example:**
```typescript
// Source: Pure JavaScript regex pattern matching
// composables/useWildcardSearch.ts
import { ref, computed } from 'vue';

export function useWildcardSearch() {
  const pattern = ref('');

  // Convert wildcard to regex
  // * = any characters (.*), ? = single character (.)
  const regex = computed(() => {
    if (!pattern.value) return null;

    // Escape special regex chars except * and ?
    const escaped = pattern.value
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*')  // * -> match any characters
      .replace(/\?/g, '.');   // ? -> match single character

    // Case-insensitive matching
    return new RegExp(`^${escaped}$`, 'i');
  });

  const matches = (geneSymbol: string): boolean => {
    if (!regex.value) return true; // No pattern = match all
    return regex.value.test(geneSymbol);
  };

  const filterGenes = (genes: Array<{ symbol: string }>): typeof genes => {
    if (!regex.value) return genes;
    return genes.filter(g => regex.value!.test(g.symbol));
  };

  // For Cytoscape.js selector - convert to selector syntax
  // Note: Cytoscape uses different syntax, so we generate a filter function
  const cytoscapeFilter = computed(() => {
    if (!pattern.value) return () => true;
    const re = regex.value;
    return (node: { data: (key: string) => string }) => {
      const symbol = node.data('symbol');
      return re ? re.test(symbol) : true;
    };
  });

  return {
    pattern,
    regex,
    matches,
    filterGenes,
    cytoscapeFilter,
  };
}
```

### Pattern 3: Bidirectional Network-Table Highlighting
**What:** Hover on table row highlights corresponding network node; hover on network node highlights corresponding table row.
**When to use:** When network and table show related data
**Why:** Improves user orientation, enables visual exploration

**Example:**
```typescript
// Source: Cytoscape.js event API + Vue 3 reactivity
// composables/useNetworkHighlight.ts
import { ref, watch, type Ref } from 'vue';
import type { Core, NodeSingular } from 'cytoscape';

export interface HighlightState {
  hoveredNodeId: string | null;
  hoveredRowId: string | null;
}

export function useNetworkHighlight(
  cy: Ref<Core | null>,
  tableRowHoverId: Ref<string | null>
) {
  const highlightState = ref<HighlightState>({
    hoveredNodeId: null,
    hoveredRowId: null,
  });

  // Setup network event listeners
  const setupNetworkListeners = () => {
    if (!cy.value) return;

    // Node hover -> update state
    cy.value.on('mouseover', 'node', (event) => {
      const node = event.target as NodeSingular;
      const nodeId = node.data('hgnc_id') || node.id();
      highlightState.value.hoveredNodeId = nodeId;

      // Visual feedback on network
      node.addClass('hover-highlight');
      node.neighborhood('node').addClass('neighbor-highlight');
    });

    cy.value.on('mouseout', 'node', () => {
      highlightState.value.hoveredNodeId = null;
      cy.value?.elements().removeClass('hover-highlight neighbor-highlight');
    });
  };

  // Table row hover -> highlight network node
  watch(tableRowHoverId, (newId) => {
    if (!cy.value) return;

    // Clear previous highlights
    cy.value.elements().removeClass('table-hover-highlight');

    if (newId) {
      // Find and highlight matching node
      const node = cy.value.getElementById(newId);
      if (node.length > 0) {
        node.addClass('table-hover-highlight');
        // Optionally pan to node
        // cy.value.center(node);
      }
    }
  });

  return {
    highlightState,
    setupNetworkListeners,
    // Computed for table row styling
    isRowHighlighted: (rowId: string) =>
      highlightState.value.hoveredNodeId === rowId,
  };
}
```

### Pattern 4: Inline Column Filters in Header
**What:** Filter inputs/dropdowns directly in column header row, per user decision.
**When to use:** For tables with column-level filtering
**Why:** Inline placement is more discoverable, matches user expectations from spreadsheet tools

**Example:**
```vue
<!-- Source: Existing GenericTable.vue filter-controls slot pattern -->
<!-- components/filters/InlineColumnFilters.vue (conceptual) -->
<template #filter-controls>
  <td v-for="field in fields" :key="field.key">
    <!-- Text filter for text columns -->
    <BFormInput
      v-if="field.filterType === 'text'"
      v-model="filters[field.key]"
      :placeholder="`Filter ${field.label}...`"
      size="sm"
      debounce="300"
      :class="{ 'filter-active': filters[field.key] }"
      @update:model-value="onFilterChange"
    />

    <!-- Dropdown for categorical columns -->
    <CategoryFilter
      v-else-if="field.filterType === 'category'"
      v-model="filters[field.key]"
      :options="field.filterOptions"
      :placeholder="`All ${field.label}`"
      @update:model-value="onFilterChange"
    />

    <!-- Numeric range for score columns -->
    <ScoreSlider
      v-else-if="field.filterType === 'numeric'"
      v-model="filters[field.key]"
      :presets="field.presets"
      :min="field.min"
      :max="field.max"
      @update:model-value="onFilterChange"
    />

    <!-- Empty cell for non-filterable columns -->
    <span v-else />
  </td>
</template>

<style scoped>
.filter-active {
  border-color: var(--bs-primary);
  background-color: rgba(var(--bs-primary-rgb), 0.05);
}
</style>
```

### Pattern 5: Navigation Tabs with URL Sync
**What:** Horizontal tabs for analysis views that update URL and share filter state.
**When to use:** For multi-view analysis interface
**Why:** Maintains context when switching views, enables deep linking to specific view

**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next BNav + VueUse useUrlSearchParams -->
<!-- components/navigation/AnalysisTabs.vue -->
<template>
  <BNav tabs class="mb-3">
    <BNavItem
      v-for="tab in tabs"
      :key="tab.id"
      :active="activeTab === tab.id"
      @click="setActiveTab(tab.id)"
    >
      <i :class="tab.icon" class="me-1" />
      {{ tab.label }}
    </BNavItem>

    <!-- Filter status badge -->
    <BNavItem disabled class="ms-auto" v-if="activeFilterCount > 0">
      <BBadge variant="primary" pill>
        {{ activeFilterCount }} filters active
      </BBadge>
      <BButton
        size="sm"
        variant="link"
        class="p-0 ms-2"
        @click="clearAllFilters"
      >
        Clear
      </BButton>
    </BNavItem>
  </BNav>
</template>

<script setup lang="ts">
import { useFilterSync } from '@/composables/useFilterSync';

const tabs = [
  { id: 'clusters', label: 'Phenotype Clusters', icon: 'bi bi-diagram-3' },
  { id: 'networks', label: 'Gene Networks', icon: 'bi bi-share' },
  { id: 'correlation', label: 'Correlation', icon: 'bi bi-grid-3x3' },
];

const { filterState, activeFilterCount, setTab, clearAllFilters } = useFilterSync();

const activeTab = computed(() => filterState.value.tab);

const setActiveTab = (tab: string) => {
  setTab(tab as 'clusters' | 'networks' | 'correlation');
};
</script>
```

### Anti-Patterns to Avoid
- **Storing filter state in multiple places:** Use single source of truth (useFilterSync composable). Duplicating state leads to sync bugs.
- **Debouncing URL updates:** VueUse handles this via `writeMode: 'replace'`. Don't add additional debounce that delays URL updates.
- **Using BTabs for URL-changing navigation:** BTabs is for content panels without URL changes. Use BNav with proper ARIA for navigation.
- **Separate filter state per view:** User decision specifies shared filter state across views. Implement once in composable, share across components.
- **Manual history.pushState calls:** Use VueUse's abstraction. Manual calls risk race conditions and don't handle edge cases.

## Don't Hand-Roll

Problems that look simple but have existing solutions.

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL state synchronization | Manual window.history API | VueUse useUrlSearchParams | Handles hash/history modes, concurrent updates, SSR, Vue reactivity integration; 50+ edge cases handled |
| Wildcard to regex conversion | Complex pattern parser | Simple regex replace | `*` -> `.*` and `?` -> `.` covers biologist patterns; library overkill for single-pattern use case |
| Debounced search input | Custom setTimeout logic | Existing TableSearchInput.vue | Already implemented with debounce, loading state, clear button; extend rather than rebuild |
| Network node highlighting | Custom DOM manipulation | Cytoscape.js addClass/removeClass | Cytoscape handles canvas rendering, CSS transitions, performance optimization; DOM manipulation breaks |
| Download buttons | Custom canvas/blob handling | Existing DownloadImageButtons.vue | PNG/SVG export already working for D3 visualizations; extend pattern for Cytoscape |
| Filter serialization | Custom string parsing | Existing useUrlParsing.ts | filterObjToStr and filterStrToObj battle-tested in TablesEntities.vue; reuse for consistency |

**Key insight:** Phase 27 features are primarily integration work. The hard problems (URL sync, debounce, export, serialization) are already solved in the codebase or VueUse. Focus on composing existing solutions into cohesive user experience.

## Common Pitfalls

### Pitfall 1: URL Update Race Conditions
**What goes wrong:** Multiple components updating URL params simultaneously cause inconsistent state. Filter updates overwrite tab changes or vice versa.

**Why it happens:** Without coordination, each component calls history.pushState independently. VueUse's useUrlSearchParams with `writeMode: 'replace'` helps but doesn't prevent all races.

**How to avoid:**
- Use single useFilterSync composable instance (provide/inject or module-level singleton)
- All filter updates go through composable methods, not direct param mutation
- Batch related updates in single reactive tick

**Warning signs:**
- URL flickers between states during rapid filtering
- Browser back button doesn't restore expected state
- Console shows multiple history entries for single user action

### Pitfall 2: Cytoscape Selector Injection
**What goes wrong:** User-provided search pattern contains characters that break Cytoscape selector syntax, causing `cy.filter()` to throw.

**Why it happens:** Cytoscape selectors use special characters (`[`, `]`, `=`, etc.). Directly interpolating user input creates malformed selectors.

**How to avoid:**
- Use filter function instead of selector string: `cy.filter(node => regex.test(node.data('symbol')))`
- If using selectors, escape special characters or validate input pattern
- Limit wildcard syntax to `*` and `?` only (user decision already constrains this)

**Warning signs:**
- Console errors with "Invalid selector" messages
- Network crashes when typing certain patterns
- Filters work for some genes but not others

**Code example:**
```typescript
// WRONG - selector injection risk
const selector = `node[symbol *= "${userInput}"]`; // What if userInput = 'PKD"] or node[foo'?

// RIGHT - function-based filtering
const matches = cy.nodes().filter(node => {
  const symbol = node.data('symbol');
  return regex.test(symbol);
});
```

### Pitfall 3: Filter State Not Persisting on Page Reload
**What goes wrong:** User applies filters, shares URL, recipient sees unfiltered view. Or user refreshes and filters are gone.

**Why it happens:** Filters stored only in component state, not synced to URL. Or URL sync is one-way (write but not read on mount).

**How to avoid:**
- VueUse useUrlSearchParams reads initial state from URL on mount
- Ensure components initialize filter values from composable, not defaults
- Test by copying URL to new tab, verifying filters applied

**Warning signs:**
- Shared links don't reproduce filter state
- Page refresh clears filters
- Browser back button doesn't restore filters

**Code example:**
```typescript
// WRONG - ignoring URL state on mount
const fdr = ref(0.05); // Always starts at 0.05

// RIGHT - initialize from URL state
const { filterState } = useFilterSync();
const fdr = computed(() => filterState.value.fdr ?? 0.05);
```

### Pitfall 4: Bidirectional Highlight Loops
**What goes wrong:** Hovering table row triggers network highlight, which triggers state change, which re-triggers table update, creating infinite loop or flicker.

**Why it happens:** Both table and network listen to same state, both emit on hover, creating feedback loop.

**How to avoid:**
- Use separate state for "source of hover" (table vs network)
- Only respond to hover events from the OTHER view, not your own
- Add debounce or check if state actually changed before updating

**Warning signs:**
- Hover causes flicker or lag
- CPU spikes on hover
- Console shows repeated state updates

**Code example:**
```typescript
// Track which view initiated the hover
const hoverSource = ref<'table' | 'network' | null>(null);

// In table component
const onRowHover = (rowId: string) => {
  if (hoverSource.value === 'network') return; // Ignore if network triggered
  hoverSource.value = 'table';
  highlightNodeId.value = rowId;
};

// In network component
cy.on('mouseover', 'node', () => {
  if (hoverSource.value === 'table') return; // Ignore if table triggered
  hoverSource.value = 'network';
  highlightRowId.value = nodeId;
});
```

### Pitfall 5: FDR Numeric Filter Precision Issues
**What goes wrong:** User selects FDR < 0.05, but rows with FDR 0.0500000001 (floating point) are excluded unexpectedly.

**Why it happens:** JavaScript floating point comparison. `0.1 + 0.2 !== 0.3` problem extends to scientific data.

**How to avoid:**
- Use tolerance-based comparison: `Math.abs(fdr - threshold) < epsilon`
- Or compare rounded values: `Number(fdr.toFixed(10)) <= threshold`
- Store/compare as strings for exact decimal representation if precision critical

**Warning signs:**
- Filters exclude rows that appear to match visually
- Edge cases at threshold boundaries behave inconsistently
- Same filter produces different results with same data

### Pitfall 6: Missing Loading States During Filter Changes
**What goes wrong:** User applies filter, table goes blank during fetch, appears broken. No indication that data is loading.

**Why it happens:** Filter change triggers data refresh, but loading state not shown. Component renders empty state instead of loading state.

**How to avoid:**
- Set `isLoading = true` before filter-triggered fetch
- Show skeleton or spinner during load, not empty state
- Distinguish "no results" from "loading" in template

**Warning signs:**
- Brief flash of empty state between filter changes
- Users report "filters break the table"
- No visual feedback on filter change

### Pitfall 7: Correlation Heatmap Click Navigation Breaking State
**What goes wrong:** User clicks heatmap cell to navigate to cluster, but loses current filter state. Or navigation doesn't properly zoom to cluster.

**Why it happens:** Navigation implemented as full route change rather than state update. Or zoom logic not integrated with filter state.

**How to avoid:**
- Click should update filter state (setCluster), not navigate to different route
- Same view receives cluster update, filters network and table
- Cytoscape zoom/fit to filtered nodes as secondary effect

**Warning signs:**
- Clicking heatmap loses search/FDR filters
- Network doesn't visually change on cluster selection
- URL shows cluster but view not updated

## Code Examples

Verified patterns from official sources and existing codebase.

### Example 1: CategoryFilter.vue Component
```vue
<!-- Source: Bootstrap-Vue-Next BFormSelect + existing TablesEntities.vue pattern -->
<!-- components/filters/CategoryFilter.vue -->
<template>
  <BFormSelect
    v-model="selected"
    :options="options"
    size="sm"
    :class="{ 'filter-active': selected !== null }"
  >
    <template #first>
      <BFormSelectOption :value="null">
        {{ placeholder }}
      </BFormSelectOption>
    </template>
  </BFormSelect>
</template>

<script setup lang="ts">
import { computed } from 'vue';

interface Props {
  modelValue: string | null;
  options: Array<{ value: string; text: string }>;
  placeholder?: string;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'All categories',
});

const emit = defineEmits<{
  'update:modelValue': [value: string | null];
}>();

const selected = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value),
});
</script>

<style scoped>
.filter-active {
  border-color: var(--bs-primary);
}
</style>
```

### Example 2: ScoreSlider.vue with Presets
```vue
<!-- Source: User decision (FDR presets) + Bootstrap form controls -->
<!-- components/filters/ScoreSlider.vue -->
<template>
  <div class="score-slider">
    <BInputGroup size="sm">
      <BFormSelect
        v-model="selectedPreset"
        :options="presetOptions"
        :class="{ 'filter-active': modelValue !== null }"
      >
        <template #first>
          <BFormSelectOption :value="null">
            All FDR values
          </BFormSelectOption>
        </template>
      </BFormSelect>

      <!-- Custom value input (shown when "Custom" selected) -->
      <BFormInput
        v-if="selectedPreset === 'custom'"
        v-model.number="customValue"
        type="number"
        step="0.001"
        min="0"
        max="1"
        placeholder="0.05"
        class="custom-input"
      />
    </BInputGroup>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';

interface Props {
  modelValue: number | null;
  presets?: Array<{ value: number; label: string }>;
}

const props = withDefaults(defineProps<Props>(), {
  presets: () => [
    { value: 0.01, label: '< 0.01' },
    { value: 0.05, label: '< 0.05' },
    { value: 0.1, label: '< 0.1' },
  ],
});

const emit = defineEmits<{
  'update:modelValue': [value: number | null];
}>();

const customValue = ref<number | null>(null);
const selectedPreset = ref<number | 'custom' | null>(null);

// Convert presets to dropdown options
const presetOptions = computed(() => [
  ...props.presets.map(p => ({ value: p.value, text: p.label })),
  { value: 'custom', text: 'Custom...' },
]);

// Sync preset selection to model
watch(selectedPreset, (preset) => {
  if (preset === null) {
    emit('update:modelValue', null);
  } else if (preset === 'custom') {
    emit('update:modelValue', customValue.value);
  } else {
    emit('update:modelValue', preset);
  }
});

// Sync custom value changes
watch(customValue, (value) => {
  if (selectedPreset.value === 'custom') {
    emit('update:modelValue', value);
  }
});

// Initialize from modelValue
watch(() => props.modelValue, (value) => {
  if (value === null) {
    selectedPreset.value = null;
  } else if (props.presets.some(p => p.value === value)) {
    selectedPreset.value = value;
  } else {
    selectedPreset.value = 'custom';
    customValue.value = value;
  }
}, { immediate: true });
</script>

<style scoped>
.custom-input {
  max-width: 80px;
}
</style>
```

### Example 3: TermSearch.vue with Wildcard Support
```vue
<!-- Source: Existing TableSearchInput.vue + wildcard pattern matching -->
<!-- components/filters/TermSearch.vue -->
<template>
  <div class="term-search">
    <TableSearchInput
      v-model="searchPattern"
      :placeholder="placeholder"
      :debounce-time="300"
      :loading="isSearching"
    />
    <small v-if="noResults && searchPattern" class="text-muted d-block mt-1">
      No genes match '{{ searchPattern }}'
    </small>
    <small v-else-if="searchPattern" class="text-muted d-block mt-1">
      Wildcards: * (any chars), ? (one char)
    </small>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';

interface Props {
  modelValue: string;
  matchCount?: number;
  isSearching?: boolean;
  placeholder?: string;
}

const props = withDefaults(defineProps<Props>(), {
  matchCount: 0,
  isSearching: false,
  placeholder: 'Search genes (e.g., PKD*, BRCA?)',
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const searchPattern = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value),
});

const noResults = computed(() =>
  props.matchCount === 0 && props.modelValue.length > 0 && !props.isSearching
);
</script>
```

### Example 4: Network Node Search Highlighting
```typescript
// Source: Cytoscape.js API + Phase 26 useCytoscape pattern
// Integration in NetworkVisualization.vue

import { useWildcardSearch } from '@/composables/useWildcardSearch';
import { useFilterSync } from '@/composables/useFilterSync';

const { filterState } = useFilterSync();
const { regex, matches } = useWildcardSearch();

// Sync search pattern from URL state
watch(() => filterState.value.search, (newPattern) => {
  regex.pattern.value = newPattern;
  updateNetworkHighlighting();
});

const updateNetworkHighlighting = () => {
  if (!cy.value) return;

  const hasPattern = regex.value !== null;

  cy.value.nodes().forEach(node => {
    const symbol = node.data('symbol');
    const isMatch = matches(symbol);

    // Clear existing classes
    node.removeClass('search-match search-no-match');

    if (hasPattern) {
      if (isMatch) {
        node.addClass('search-match');
      } else {
        node.addClass('search-no-match');
      }
    }
  });
};

// Cytoscape styles for search highlighting
const searchStyles = [
  {
    selector: 'node.search-match',
    style: {
      'border-color': '#ffc107',
      'border-width': 4,
      'z-index': 999,
      // Glow effect via shadow (requires cytoscape-node-html-label or custom)
    },
  },
  {
    selector: 'node.search-no-match',
    style: {
      'opacity': 0.3,
    },
  },
];
```

### Example 5: Fixing filter=undefined Bug (NAVL-07)
```typescript
// Source: Existing AnalysesPhenotypeClusters.vue footer link
// Problem: Link includes 'filter=undefined' when hash_filter is undefined

// BEFORE (buggy)
<BLink :href="'/Entities/?filter=' + selectedCluster.hash_filter">

// AFTER (fixed)
<BLink
  :href="selectedCluster.hash_filter
    ? `/Entities/?filter=${selectedCluster.hash_filter}`
    : '/Entities/'"
>

// Or with computed for cleaner template
const entitiesLink = computed(() => {
  const base = '/Entities/';
  if (selectedCluster.value?.hash_filter) {
    return `${base}?filter=${selectedCluster.value.hash_filter}`;
  }
  return base;
});
```

### Example 6: Correlation Heatmap Click Navigation
```typescript
// Source: Existing AnalysesPhenotypeCorrelogram.vue + navigation requirement
// Add click handler to correlogram cells for cluster navigation

// In generateMatrixGraph method, update click handler:
svg
  .selectAll()
  .data(data, (d) => `${d.x}:${d.y}`)
  .enter()
  .append('rect')
  // ... existing attrs ...
  .on('click', (event, d) => {
    // Navigate to cluster view with this cluster selected
    // Instead of hard link, update filter state
    const { setTab, setCluster } = useFilterSync();
    setCluster(d.cluster_id); // Assuming data includes cluster_id
    setTab('networks'); // Switch to network view
    // Network will zoom to cluster members automatically via watch
  });
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual URL query parsing | VueUse useUrlSearchParams | VueUse 8.0 (2022) | Automatic reactivity, history handling, type safety; eliminates ~100 lines of manual code |
| Individual component filter state | Shared composable with URL sync | Vue 3 patterns (2021+) | Single source of truth, bookmarkable views, cross-component coordination |
| Dropdown for FDR selection only | Dropdown + custom input hybrid | UX best practice | Covers common cases with presets, power users can set exact values |
| Click navigates to new page | Click updates filter state, same view | SPA best practice | Maintains context, faster interaction, preserves filter state |
| Text-only search | Wildcard pattern matching | Bioinformatics standard | Matches biologist mental models, reduces clicks for common patterns |

**Deprecated/outdated:**
- **vue-router query params without reactivity:** Use VueUse for reactive sync; manual query access is read-only and requires refresh
- **Separate filter state per component:** Leads to sync bugs; shared composable is current pattern
- **Full page navigation between analysis views:** Tabs with shared state provide better UX; reserve navigation for entity detail pages

## Open Questions

Things that couldn't be fully resolved during research.

### 1. Glow/Pulse Animation Implementation for Matching Nodes
**What we know:**
- User decision specifies "matching nodes glow/pulse in network"
- Cytoscape.js supports CSS-like styling but not CSS animations directly
- Options: CSS class with keyframe animation (if using HTML overlay), periodic style update, or background-position animation

**What's unclear:**
- Does Cytoscape canvas renderer support glow effect natively?
- Performance impact of animating many nodes simultaneously
- Should animation loop indefinitely or pulse once on match?

**Recommendation:** Start with static highlight (border + z-index) for MVP. Add pulse animation in refinement if static highlight insufficient. Test with 200+ nodes to verify performance.

### 2. Filter State Sharing Mechanism
**What we know:**
- User decision: "shared filter state across all analysis views"
- Options: provide/inject, Pinia store, module-level singleton composable

**What's unclear:**
- Are views in same component tree (provide/inject works) or separate routes (need store/singleton)?
- Does state need to persist beyond session (localStorage integration)?

**Recommendation:** Start with module-level singleton composable (simplest). Upgrade to Pinia if component tree changes or persistence needed. VueUse handles URL sync either way.

### 3. Bidirectional Hover Performance with 500+ Nodes
**What we know:**
- Hover highlighting requires DOM/canvas updates on mouse move
- Table rows and network nodes may both have 500+ items

**What's unclear:**
- Performance impact of finding matching element on each hover
- Should highlighting be throttled/debounced for performance?

**Recommendation:** Implement without throttle initially. If performance issues observed, add 16ms throttle (60fps). Consider using Map for O(1) lookup instead of array filter.

### 4. Color Legend Component Reusability
**What we know:**
- UIUX-01 requires color legend for correlation heatmap (-1 to +1)
- May also need legends for other visualizations (cluster colors)

**What's unclear:**
- Should legend be generic component or visualization-specific?
- Horizontal or vertical orientation preference?

**Recommendation:** Create generic ColorLegend.vue with configurable scale, labels, and orientation. Start with horizontal gradient for correlation. Extend for discrete cluster colors later.

## Sources

### Primary (HIGH confidence)

**VueUse:**
- [useUrlSearchParams | VueUse](https://vueuse.org/core/useurlsearchparams/) - Official documentation for URL state sync composable
- [VueUse GitHub - useUrlSearchParams](https://github.com/vueuse/vueuse/blob/main/packages/core/useUrlSearchParams/index.ts) - Source code showing implementation details

**Cytoscape.js:**
- [Cytoscape.js Official Documentation](https://js.cytoscape.org/) - Selector API, filtering, styling
- [cytoscape.js-view-utilities](https://github.com/iVis-at-Bilkent/cytoscape.js-view-utilities) - Highlighting extension patterns

**Bootstrap-Vue-Next:**
- [Nav | BootstrapVueNext](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/nav) - Tab navigation with URL sync
- [Tabs | BootstrapVueNext](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/tabs.html) - Tab component API

**SysNDD Codebase:**
- `/app/src/composables/useUrlParsing.ts` - Existing filter serialization patterns
- `/app/src/components/small/TableSearchInput.vue` - Debounced search input with loading state
- `/app/src/components/tables/TablesEntities.vue` - URL link copy, filter controls
- `/app/src/components/small/DownloadImageButtons.vue` - PNG/SVG export pattern
- `/app/src/components/analyses/AnalyseGeneClusters.vue` - Cluster visualization with filters
- `.planning/phases/26-network-visualization/26-RESEARCH.md` - Phase 26 Cytoscape patterns

### Secondary (MEDIUM confidence)

**Wildcard Matching:**
- [wildcard-match npm](https://www.npmjs.com/package/wildcard-match) - Glob pattern to regex library
- [Wildcard Pattern Matching in JavaScript - GeeksforGeeks](https://www.geeksforgeeks.org/wildcard-pattern-matching-in-javascript/) - Pure JS regex approach

**Vue 3 Patterns:**
- [URL Query Parameters with JavaScript, Vue 2 and Vue 3 | Server Side Up](https://serversideup.net/blog/url-query-parameters-with-javascript-vue-2-and-vue-3/) - URL param handling patterns
- [How to Debounce Input in Vue 3](https://codecourse.com/articles/debounce-input-in-vue-3) - Debounce composable patterns

**Table Filtering:**
- [Build a data table in vue 3: Part 4 - With Filter Feature | Medium](https://medium.com/@teddymczieuwa/build-a-data-table-in-vue-3-part-4-with-filter-feature-a92de8505fba) - Vue 3 table filtering patterns
- [Column Filter Options | vue-good-table](https://xaksis.github.io/vue-good-table/guide/configuration/column-filter-options.html) - Column filter configuration patterns

**Highlighting:**
- [How to highlight neighbouring nodes in Cytoscape.js](https://javascriptio.com/view/842663/how-to-highlight-neighbouring-nodes-in-cytoscape-js) - Neighborhood highlighting patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - VueUse documented extensively, Cytoscape.js proven in Phase 26, Bootstrap-Vue-Next already in use
- Architecture: HIGH - Composable patterns established in existing codebase, URL sync patterns well-documented
- Pitfalls: HIGH - Race conditions and bidirectional highlighting issues documented in GitHub issues and community posts
- Filter components: MEDIUM - General patterns clear, exact implementation details require prototyping

**Research date:** 2026-01-25
**Valid until:** 60 days (stable ecosystem - VueUse mature, Vue 3 stable, Cytoscape.js established)

**Phase-specific notes:**
- User decisions in CONTEXT.md provide clear UX constraints (inline filters, presets, shared state)
- Phase 26 Cytoscape patterns directly applicable for network highlighting
- Existing codebase provides strong foundation (useUrlParsing, TableSearchInput, filter patterns)
- NAVL-07 bug (filter=undefined) is simple fix, include in first task
- Download buttons (UIUX-03) extend existing DownloadImageButtons.vue pattern
