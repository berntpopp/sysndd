# Phase 75: Frontend Fixes & UX Improvements - Research

**Researched:** 2026-02-05
**Domain:** Vue 3 frontend component enhancement and UI refactoring
**Confidence:** HIGH

## Summary

Phase 75 involves four independent frontend improvements to the SysNDD Vue 3 application: (1) restoring column header tooltips across data tables using the existing backend field spec metadata, (2) replacing basic form selects with the TreeMultiSelect component for phenotype and variation ontology in the Create Entity wizard, (3) reordering sections on the Gene detail page to prioritize Associated Entities, and (4) extracting documentation URLs into a constants file for maintainability.

The codebase uses Vue 3.5.25 with Composition API, TypeScript, and Bootstrap-Vue-Next 0.42.0. All patterns and components needed for these fixes already exist in the codebase - TablesGenes.vue demonstrates tooltip implementation, ModifyEntity.vue shows TreeMultiSelect usage with the transformModifierTree pattern, and GeneView.vue contains the section ordering to be adjusted.

**Primary recommendation:** Follow existing codebase patterns strictly - extract tooltip logic into a reusable composable, copy the exact TreeMultiSelect integration from ModifyEntity (including compound modifier_id-ontology_id format), reorder template sections in GeneView.vue without changing internal component logic, and create a TypeScript constants file at src/constants/docs.ts for centralized documentation URLs.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue | 3.5.25 | Frontend framework | Latest stable Vue 3, Composition API with &lt;script setup&gt; |
| TypeScript | 5.9.3 | Type safety | Configured with allowJs and strict: false for gradual adoption |
| Bootstrap-Vue-Next | 0.42.0 | UI components | Vue 3 port of Bootstrap-Vue, provides BTable, BTooltip, BFormTag |
| Vite | 7.3.1 | Build tool | Fast dev server, optimized production builds |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @vueuse/core | 14.2.0 | Composable utilities | Reactive utilities, already used throughout codebase |
| vue-router | 5.0.2 | Routing | Navigation between views |
| Pinia | 3.0.4 | State management | Global state (UI store for scrollbar updates) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap-Vue-Next | PrimeVue, Quasar | Would require full UI library migration, not worth for 4 fixes |
| Custom tooltip | Native title attribute | Loses dynamic filtering counts, less UX polish |
| Duplicate TreeMultiSelect logic | Build custom multiselect | Violates DRY, ModifyEntity pattern proven to work |

**Installation:**
```bash
# All dependencies already installed
npm install
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── components/          # Reusable components
│   ├── forms/          # Form inputs (TreeMultiSelect, AutocompleteInput)
│   ├── tables/         # Table components (TablesGenes, TablesEntities)
│   ├── small/          # Small utilities (GenericTable, TableHeaderLabel)
│   └── ui/             # UI elements (badges, icons)
├── composables/        # Shared composable logic
│   ├── index.ts        # Central export file
│   ├── useTooltip.ts   # NEW: Column tooltip formatting logic
│   └── ...
├── constants/          # NEW: Centralized constants
│   └── docs.ts         # Documentation URLs
├── views/              # Page-level components
│   ├── pages/          # GeneView, EntityView, etc.
│   ├── curate/         # ModifyEntity (TreeMultiSelect reference)
│   └── forms/wizard/   # StepPhenotypeVariation (to be upgraded)
└── types/              # TypeScript interfaces
```

### Pattern 1: Column Tooltip Composable
**What:** Extract tooltip formatting logic from TablesGenes.vue into a reusable composable
**When to use:** Any table that receives field specs with count/count_filtered from API
**Example:**
```typescript
// Source: Existing TablesGenes.vue pattern (lines 76-101)
// NEW: src/composables/useColumnTooltip.ts
import type { TableField } from 'bootstrap-vue-next';

export interface FieldWithCounts extends TableField {
  count?: number;
  count_filtered?: number;
}

export function useColumnTooltip() {
  /**
   * Generate tooltip text for table headers
   * Format: "Column (unique filtered/total values: X/Y)"
   */
  const getTooltipText = (field: FieldWithCounts): string => {
    const label = field.label || field.key;
    const filtered = field.count_filtered ?? 0;
    const total = field.count ?? 0;
    return `${label} (unique filtered/total values: ${filtered}/${total})`;
  };

  return { getTooltipText };
}
```

### Pattern 2: TreeMultiSelect Integration
**What:** Replace BFormSelect with TreeMultiSelect in Create Entity step 3
**When to use:** Multi-selection of hierarchical ontology data (phenotypes, variations)
**Example:**
```vue
<!-- Source: ModifyEntity.vue lines 501-508, 516-523 -->
<TreeMultiSelect
  id="review-phenotype-select"
  v-model="formData.phenotypes"
  :options="phenotypeOptions"
  placeholder="Select phenotypes..."
  search-placeholder="Search phenotypes (name or HP:ID)..."
/>

<!-- Data format: compound modifier_id-ontology_id -->
<!-- formData.phenotypes = ["1-HP:0001999", "2-HP:0002011"] -->
```

**Key transformation:**
```javascript
// Source: ModifyEntity.vue lines 856-887
transformModifierTree(nodes) {
  return nodes.map((node) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = node.id.replace(/^\d+-/, '');

    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children || []).map((child) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    };
  });
}
```

### Pattern 3: Constants File Organization
**What:** Single source of truth for documentation URLs
**When to use:** Any URL referenced in multiple files
**Example:**
```typescript
// Source: WebSearch verified pattern + existing URLs in codebase
// NEW: src/constants/docs.ts
export const DOCS_BASE_URL = 'https://berntpopp.github.io/sysndd';

export const DOCS_URLS = {
  HOME: `${DOCS_BASE_URL}/`,
  CURATION_CRITERIA: `${DOCS_BASE_URL}/05-curation-criteria.html`,
  RE_REVIEW_INSTRUCTIONS: `${DOCS_BASE_URL}/06-re-review-instructions.html`,
  TUTORIAL_VIDEOS: `${DOCS_BASE_URL}/07-tutorial-videos.html`,
} as const;

// Usage in components:
import { DOCS_URLS } from '@/constants/docs';
// <BLink :href="DOCS_URLS.CURATION_CRITERIA">
```

### Pattern 4: GenericTable Tooltip Support
**What:** Add optional tooltip support to GenericTable via slot override
**When to use:** Tables using GenericTable component that want tooltips
**Example:**
```vue
<!-- GenericTable.vue enhancement -->
<template #head()="data">
  <slot name="head" :data="data" :field="fields.find(f => f.key === data.column)">
    {{ data.label }}
  </slot>
</template>

<!-- Consumer (TablesEntities.vue) -->
<GenericTable :items="items" :fields="fields">
  <template #head="{ data, field }">
    <div v-b-tooltip.hover.top :title="getTooltipText(field)">
      {{ data.label }}
    </div>
  </template>
</GenericTable>
```

### Anti-Patterns to Avoid
- **Don't modify TreeMultiSelect component:** It's stable and used in ModifyEntity - copy usage pattern exactly
- **Don't change compound ID format:** API expects "modifier_id-ontology_id" format (e.g., "1-HP:0001999")
- **Don't add new backend fields:** All needed data (count, count_filtered) already in field specs
- **Don't inline URLs:** Defeats purpose of constants file - import from constants/docs.ts

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-select with search | Custom dropdown with filter logic | TreeMultiSelect component | Handles hierarchy, search, selection state, keyboard nav, accessibility |
| Tooltip formatting | Template string in each table | useColumnTooltip composable | DRY principle, consistent format, tested pattern |
| Hierarchical ontology data | Flat list with indentation | transformModifierTree function | Preserves parent-child relationships, enables drill-down navigation |
| URL management | Hardcoded strings | Constants file | Single source of truth, type safety, easy updates |

**Key insight:** The codebase already solved all these problems - TablesGenes has tooltips, ModifyEntity has TreeMultiSelect with transformation, both patterns are proven. Don't reinvent, reuse.

## Common Pitfalls

### Pitfall 1: Breaking TreeMultiSelect Data Format
**What goes wrong:** Entity creation API fails with 400/500 errors due to wrong data format
**Why it happens:** StepPhenotypeVariation currently uses simple IDs ("HP:0001999"), but ModifyEntity and API expect compound format ("1-HP:0001999")
**How to avoid:**
- Copy ModifyEntity's exact TreeMultiSelect usage (lines 501-523)
- Use transformModifierTree to process API tree data
- Store formData.phenotypes as compound IDs (modifier_id-ontology_id)
- Test entity creation before submitting fix
**Warning signs:**
- API returns validation errors
- Entity created without phenotype modifiers
- Console errors about malformed IDs

### Pitfall 2: Tooltip Performance with Large Tables
**What goes wrong:** Browser lag when rendering 1000+ rows with tooltips
**Why it happens:** v-b-tooltip creates popper instances for each cell header
**How to avoid:**
- Apply tooltips only to column headers (thead), not body cells
- Use .hover modifier to defer initialization until interaction
- GenericTable already limits to header row - don't add to tbody
**Warning signs:**
- Scroll lag on tables with 100+ rows
- DevTools shows thousands of popper instances
- High memory usage in performance profiler

### Pitfall 3: Section Reordering Breaking Refs
**What goes wrong:** Components lose reactive data or event handlers after reordering
**Why it happens:** Moving template blocks without checking ref dependencies
**How to avoid:**
- Only move the outermost container divs (the ones with container-fluid class)
- Don't change component props or event handlers
- Keep internal component structure untouched
- Test all interactive features after reordering (filters, sorting, pagination)
**Warning signs:**
- Entities table stops loading data
- Visualizations don't update
- Console errors about undefined refs

### Pitfall 4: Constants File Not Tree-Shakeable
**What goes wrong:** Bundle includes unused documentation URLs
**Why it happens:** Using default export or mutable objects
**How to avoid:**
- Use named exports (export const DOCS_URLS)
- Add "as const" assertion for literal types
- Import only needed constants: import { DOCS_URLS } from '@/constants/docs'
- TypeScript will infer literal string types, enabling dead code elimination
**Warning signs:**
- Bundle size increases unexpectedly
- Vite warns about large chunks
- Constants file imported in many places but bundle doesn't shrink

## Code Examples

Verified patterns from official sources:

### Bootstrap-Vue-Next Tooltip Directive
```vue
<!-- Source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/directives/BTooltip -->
<template>
  <!-- Basic usage -->
  <div v-b-tooltip="'Tooltip text'">Hover me</div>

  <!-- With modifiers (placement + trigger) -->
  <div v-b-tooltip.hover.top="'Top tooltip'">Hover me</div>

  <!-- Dynamic content -->
  <div v-b-tooltip.hover.top="getTooltipText(field)">{{ field.label }}</div>
</template>
```

### Existing TablesGenes Tooltip Pattern
```vue
<!-- Source: TablesGenes.vue lines 76-101 -->
<template #head()="data">
  <div
    v-b-tooltip.hover.top
    :data="data"
    data-html="true"
    :title="
      data.label +
      ' (unique filtered/total values: ' +
      fields
        .filter((item) => item.label === data.label)
        .map((item) => item.count_filtered)[0] +
      '/' +
      fields
        .filter((item) => item.label === data.label)
        .map((item) => item.count)[0] +
      ')'
    "
  >
    {{ truncate(data.label.replace(/( word)|( name)/g, ''), 20) }}
  </div>
</template>
```

### ModifyEntity TreeMultiSelect Usage
```vue
<!-- Source: ModifyEntity.vue lines 501-508, 516-523 -->
<template>
  <!-- Phenotype selection -->
  <TreeMultiSelect
    v-if="phenotypes_options && phenotypes_options.length > 0"
    id="review-phenotype-select"
    v-model="select_phenotype"
    :options="phenotypes_options"
    placeholder="Select phenotypes..."
    search-placeholder="Search phenotypes (name or HP:ID)..."
  />

  <!-- Variation ontology selection -->
  <TreeMultiSelect
    v-if="variation_ontology_options && variation_ontology_options.length > 0"
    id="review-variation-select"
    v-model="select_variation"
    :options="variation_ontology_options"
    placeholder="Select variations..."
    search-placeholder="Search variation types..."
  />
</template>

<script>
export default {
  data() {
    return {
      phenotypes_options: null,
      variation_ontology_options: null,
      select_phenotype: [],
      select_variation: [],
    };
  },
  methods: {
    async loadPhenotypesList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
      const response = await this.axios.get(apiUrl);
      const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
      this.phenotypes_options = this.transformModifierTree(rawData);
    },
    transformModifierTree(nodes) {
      return nodes.map((node) => {
        const phenotypeName = node.label.replace(/^present:\s*/, '');
        const ontologyCode = node.id.replace(/^\d+-/, '');
        return {
          id: `parent-${ontologyCode}`,
          label: phenotypeName,
          children: [
            { id: node.id, label: `present: ${phenotypeName}` },
            ...(node.children || []).map((child) => {
              const modifier = child.label.replace(/:\s*.*$/, '');
              return { id: child.id, label: `${modifier}: ${phenotypeName}` };
            }),
          ],
        };
      });
    },
  },
};
</script>
```

### GeneView Section Order (Current)
```vue
<!-- Source: GeneView.vue lines 10-127 -->
<template>
  <template v-else>
    <!-- 1. Gene info card (symbol, name, location, resources, identifiers) -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol col md="12">
            <BCard><!-- Gene info --></BCard>
          </BCol>
        </BRow>
      </BContainer>
    </div>

    <!-- 2. Constraint Scores + ClinVar + Model Organisms (two-column layout) -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol cols="12" md="6" class="mb-2">
            <GeneConstraintCard />
          </BCol>
          <BCol cols="12" md="6" class="mb-2">
            <GeneClinVarCard class="mb-2" />
            <ModelOrganismsCard />
          </BCol>
        </BRow>
      </BContainer>
    </div>

    <!-- 3. Genomic Visualizations (protein view, gene structure, 3D structure) -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol cols="12">
            <GenomicVisualizationTabs />
          </BCol>
        </BRow>
      </BContainer>
    </div>

    <!-- 4. Associated Entities Table (currently last) -->
    <TablesEntities
      v-if="geneData.length !== 0"
      :show-filter-controls="false"
      :show-pagination-controls="false"
      header-label="Associated "
      :filter-input="filterInput"
      :disable-url-sync="true"
    />
  </template>
</template>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| BFormSelect for ontologies | TreeMultiSelect with hierarchy | ModifyEntity.vue (already done) | Better UX, searchable, shows modifiers |
| Inline URLs | Not yet centralized | Needs implementation | Maintainability issue |
| No column tooltips | TablesGenes has them | TablesGenes only | Other tables lack metadata display |
| Generic template order | Task-specific ordering | Per-view basis | Gene view needs reordering |

**Deprecated/outdated:**
- vue3-treeselect: Disabled in migration to Bootstrap-Vue-Next, comments remain in codebase (TablesGenes.vue line 305-309)
- BFormSelect for multi-select ontologies: Works but poor UX compared to TreeMultiSelect

## Open Questions

Things that couldn't be fully resolved:

1. **Entity creation API modifier support**
   - What we know: ModifyEntity uses "modifier_id-ontology_id" format (e.g., "1-HP:0001999")
   - What's unclear: Whether POST /api/entity/create accepts same format (context says "verify thoroughly")
   - Recommendation: Test entity creation with compound IDs before implementing TreeMultiSelect upgrade

2. **GenericTable tooltip opt-in mechanism**
   - What we know: GenericTable is used by multiple tables, shouldn't force tooltips on all
   - What's unclear: Best way to pass tooltip flag (prop, slot presence detection, or caller-side template override)
   - Recommendation: Use slot override pattern - callers provide #head template with tooltip if desired

3. **Tooltip count data availability**
   - What we know: Backend computes count/count_filtered via generate_tibble_fspec() for all tables
   - What's unclear: Whether Phenotypes and Comparisons tables receive these fields (context says "backend already computes")
   - Recommendation: Verify field specs in browser DevTools Network tab before implementing tooltips

## Sources

### Primary (HIGH confidence)
- Codebase analysis:
  - app/src/components/forms/TreeMultiSelect.vue - Reference implementation
  - app/src/components/tables/TablesGenes.vue - Tooltip pattern (lines 76-101)
  - app/src/views/curate/ModifyEntity.vue - TreeMultiSelect integration (lines 501-523, 856-887)
  - app/src/views/pages/GeneView.vue - Section ordering to be changed
  - app/src/components/small/GenericTable.vue - Base table component
  - app/package.json - Verified versions (Vue 3.5.25, Bootstrap-Vue-Next 0.42.0)

### Secondary (MEDIUM confidence)
- [Bootstrap-Vue-Next BTooltip Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/directives/BTooltip) - Official directive docs
- [Vue 3 Composables Guide](https://vuejs.org/guide/reusability/composables.html) - Composable patterns
- [Vue 3 TypeScript Guide](https://vuejs.org/guide/typescript/overview) - TypeScript integration

### Tertiary (LOW confidence)
- [Vue 3 Best Practices Medium Article](https://medium.com/@ignatovich.dm/vue-3-best-practices-cb0a6e281ef4) - General best practices
- [Constants in Vue Files DEV.to](https://dev.to/thejaredwilcurt/where-to-put-constants-in-a-vue-file-2k5h) - Constants organization patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All versions verified from package.json, patterns from working code
- Architecture: HIGH - All patterns exist and functional in codebase (TablesGenes, ModifyEntity)
- Pitfalls: MEDIUM - Based on codebase patterns and Vue 3 best practices, not field-tested for this specific phase

**Research date:** 2026-02-05
**Valid until:** 30 days (stable libraries, established patterns)
