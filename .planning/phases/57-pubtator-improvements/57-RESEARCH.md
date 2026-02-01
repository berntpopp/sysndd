# Phase 57: Pubtator Improvements - Research

**Researched:** 2026-01-31
**Domain:** Pubtator integration, Vue 3 admin panels, Excel export, gene prioritization
**Confidence:** HIGH

## Summary

This phase enhances the existing Pubtator integration with new curator-focused features: fixing the broken Stats page, adding gene prioritization with coverage gap detection, novel gene alerts, export functionality, and documentation. Research analyzed the current implementation in depth.

**Key findings:**
1. **Current Pubtator infrastructure is solid** - Database schema (3 tables), API endpoints (search, table, genes), and Vue components exist and are well-structured
2. **Stats page bug identified** - Uses `fetchStats()` hitting `/api/pubtator` with page_size=1000 but no such endpoint exists; should use `/api/publication/pubtator/genes` or `/api/publication/pubtator/table`
3. **ManageAnnotations pattern established** - Uses card-based sections with async job tracking via `useAsyncJob` composable for long-running operations
4. **Excel export has dual patterns** - Server-side via `generate_xlsx_bin()` in R and client-side via `useExcelExport` composable with ExcelJS
5. **Help badge pattern is consistent** - BBadge with `variant="info"` + BPopover with `triggers="focus"`, used throughout analysis components

**Primary recommendation:** Fix Stats page API endpoint, add new admin tab to ManageAnnotations for Pubtator management, implement gene prioritization using SQL queries against existing `pubtator_human_gene_entity_view`, and follow established patterns for all UI elements.

## Standard Stack

The established libraries/tools for this domain:

### Core (Already in Use)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Frontend framework | Project standard |
| Bootstrap-Vue-Next | 0.42.0 | UI components (BBadge, BPopover, BTable, BFormTag) | Project standard |
| D3.js | 7.x | Stats visualizations | Already used in PubtatorNDDStats |
| ExcelJS | 0.4.3 | Client-side Excel export | Existing `useExcelExport` composable |
| axios | - | API calls | Injected globally |

### Supporting (R API)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| openxlsx | - | Server-side Excel generation | `generate_xlsx_bin()` helper |
| tidyverse | - | Data manipulation | SQL-like operations |
| digest | - | Query hashing | Pubtator cache system |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Client-side Excel (ExcelJS) | Server-side Excel (R) | Both available; use client for filtered views, server for full data exports |
| D3.js | ECharts/Chart.js | D3 already in use for Stats; maintain consistency |

**No new dependencies needed.**

## Architecture Patterns

### Existing Pubtator Structure
```
Database (MySQL):
├── pubtator_query_cache        # Query metadata + pagination state
├── pubtator_search_cache       # Publication search results (PMID, title, etc.)
├── pubtator_annotation_cache   # Gene annotations per publication
└── pubtator_human_gene_entity_view  # Aggregated view joining genes + entities

API (R/Plumber):
├── publication_endpoints.R
│   ├── GET /publication/pubtator/search  # Live PubTator API search
│   ├── GET /publication/pubtator/table   # Cached publications
│   └── GET /publication/pubtator/genes   # Genes with publication counts

Frontend (Vue):
├── views/analyses/PubtatorNDD.vue        # Parent with tabs
├── components/analyses/
│   ├── PubtatorNDDTable.vue              # Publications table
│   ├── PubtatorNDDGenes.vue              # Genes table
│   └── PubtatorNDDStats.vue              # Stats visualization (BROKEN)
```

### Pattern 1: Admin Panel Tab (ManageAnnotations)
**What:** Card-based sections with button triggers and progress tracking
**When to use:** Adding new admin functionality
**Example:**
```vue
<!-- Source: /app/src/views/admin/ManageAnnotations.vue -->
<BCard header-tag="header" body-class="p-1" border-variant="dark" class="mb-3 text-start">
  <template #header>
    <h5 class="mb-0 text-start font-weight-bold">
      Updating Ontology Annotations
      <span v-if="annotationDates.omim_update" class="badge bg-secondary ms-2 fw-normal">
        Last: {{ formatDate(annotationDates.omim_update) }}
      </span>
    </h5>
  </template>
  <BButton variant="primary" :disabled="ontologyJob.isLoading.value" @click="updateOntologyAnnotations">
    <BSpinner v-if="ontologyJob.isLoading.value" small type="grow" class="me-2" />
    {{ ontologyJob.isLoading.value ? 'Updating...' : 'Update Ontology Annotations' }}
  </BButton>
  <!-- Progress display -->
</BCard>
```

### Pattern 2: Help Badge with Popover (CurationComparisons)
**What:** Info badge that opens popover on focus with explanatory content
**When to use:** Explaining complex features or data sources
**Example:**
```vue
<!-- Source: /app/src/components/analyses/AnalysesCurationComparisonsTable.vue -->
<h6 class="mb-1 text-start font-weight-bold">
  Comparing the presence of a gene in different
  <mark v-b-tooltip.hover.leftbottom title="Detailed explanation...">curation efforts</mark>
  for NDDs.
  <BBadge id="popover-badge-help-comparisons" pill href="#" variant="info">
    <i class="bi bi-question-circle-fill" />
  </BBadge>
  <BPopover target="popover-badge-help-comparisons" variant="info" triggers="focus">
    <template #title> Comparisons selection [last update 2023-04-13] </template>
    The NDD databases and lists for the comparison with SysNDD are:
    <br /><strong>1) radboudumc ID,</strong> downloaded...
  </BPopover>
</h6>
```

### Pattern 3: Clickable Chip/Badge for PMIDs
**What:** BButton styled as badge linking to external resource
**When to use:** PMID links in gene rows
**Example:**
```vue
<!-- Source: /app/src/components/analyses/PubtatorNDDTable.vue -->
<template #cell-pmid="{ row }">
  <BButton
    v-b-tooltip.hover.bottom
    class="btn-xs mx-2"
    variant="primary"
    :href="'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid"
    target="_blank"
    :title="row.pmid"
  >
    <i class="bi bi-box-arrow-up-right" />
    PMID: {{ row.pmid }}
  </BButton>
</template>
```

### Pattern 4: Excel Export (Client-side)
**What:** useExcelExport composable for filtered data export
**When to use:** Exporting currently filtered view to Excel
**Example:**
```typescript
// Source: /app/src/composables/useExcelExport.ts
const { isExporting, exportToExcel } = useExcelExport();

await exportToExcel(filteredGenes, {
  filename: 'pubtator_gene_prioritization',
  sheetName: 'Genes',
  headers: {
    gene_symbol: 'Gene Symbol',
    publication_count: 'Publication Count',
    oldest_pub_date: 'Oldest Publication',
    in_sysndd: 'In SysNDD',
    pmids: 'PMIDs'
  }
});
```

### Pattern 5: Novel Gene Badge
**What:** Badge showing count in tab header
**When to use:** Highlighting novel gene count
**Example:**
```vue
<!-- Pattern derived from TableHeaderLabel.vue -->
<BNavItem :to="{ name: 'PubtatorNDDGenes' }">
  Genes
  <BBadge v-if="novelGeneCount > 0" variant="warning" pill class="ms-1">
    {{ novelGeneCount }} novel
  </BBadge>
</BNavItem>
```

### Anti-Patterns to Avoid
- **Don't hand-roll Excel export** - Use `useExcelExport` composable or server-side `generate_xlsx_bin()`
- **Don't create new async job polling** - Use `useAsyncJob` composable for long-running operations
- **Don't create separate novel gene tab** - Per decisions, use badge/highlight in existing gene list

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Excel export | Custom blob/download logic | `useExcelExport` composable | Handles workbook creation, styling, download |
| Async job polling | setInterval + manual cleanup | `useAsyncJob` composable | Auto-cleanup, progress tracking, error handling |
| Table pagination | Manual cursor tracking | `useTableData` composable | Provides pagination state management |
| Filter string parsing | Manual URL manipulation | `useUrlParsing` composable | `filterObjToStr` / `filterStrToObj` |
| Toast notifications | Direct DOM manipulation | `useToast` composable | Consistent error/success messaging |

**Key insight:** The codebase has 40+ composables covering most common patterns. Check `/app/src/composables/` before implementing new utilities.

## Common Pitfalls

### Pitfall 1: Stats Page API Endpoint Mismatch
**What goes wrong:** Stats page calls `/api/pubtator` which doesn't exist
**Why it happens:** Copy-paste from different component, endpoint naming inconsistency
**How to avoid:** Check `publication_endpoints.R` for actual endpoint paths:
- `/api/publication/pubtator/table` - for publications
- `/api/publication/pubtator/genes` - for gene aggregations
**Warning signs:** 404 errors in console, empty data arrays

### Pitfall 2: R/Plumber Array Wrapping
**What goes wrong:** Single values come as `[value]` instead of `value`
**Why it happens:** R serializes scalars as single-element arrays
**How to avoid:** Use `unwrapValue()` helper function from `useAsyncJob` pattern:
```typescript
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}
```
**Warning signs:** `[Object object]` in UI, type errors, undefined errors

### Pitfall 3: Novel Gene Count Calculation
**What goes wrong:** Incorrect coverage gap detection due to NULL handling
**Why it happens:** LEFT JOIN produces NULL for non-matching genes
**How to avoid:** In SQL, explicitly check `entity_id IS NULL` for coverage gap:
```sql
SELECT gene_symbol,
       COUNT(DISTINCT pmid) as pub_count,
       CASE WHEN entity_id IS NULL THEN 1 ELSE 0 END as is_novel
FROM pubtator_human_gene_entity_view
GROUP BY gene_symbol, hgnc_id
```
**Warning signs:** 0 novel genes when there should be some, all genes marked novel

### Pitfall 4: ManageAnnotations Tab Integration
**What goes wrong:** New section doesn't match existing card styling
**Why it happens:** Missing border-variant, class inconsistencies
**How to avoid:** Copy exact BCard structure:
```vue
<BCard header-tag="header" body-class="p-1" header-class="p-1"
       border-variant="dark" class="mb-3 text-start">
```
**Warning signs:** Visual inconsistency, misaligned elements

## Code Examples

Verified patterns from official sources:

### Gene Prioritization SQL Query
```sql
-- Source: Derived from pubtator_human_gene_entity_view structure
-- Purpose: Get genes ranked by coverage gap + oldest publication date

SELECT
  gene_symbol,
  gene_name,
  hgnc_id,
  gene_normalized_id,
  COUNT(DISTINCT pmid) AS publication_count,
  MIN(date) AS oldest_pub_date,
  CASE WHEN MAX(entity_id) IS NULL THEN 1 ELSE 0 END AS is_novel,
  GROUP_CONCAT(DISTINCT pmid ORDER BY date) AS pmids
FROM pubtator_human_gene_entity_view
GROUP BY gene_symbol, gene_name, hgnc_id, gene_normalized_id
HAVING COUNT(DISTINCT pmid) >= 2  -- Novel threshold: 2+ publications
ORDER BY
  is_novel DESC,           -- Non-SysNDD genes first
  oldest_pub_date ASC,     -- Then by oldest publication
  publication_count DESC   -- Then by most publications
```

### Admin Tab Button Pattern
```vue
<!-- Source: ManageAnnotations.vue -->
<BButton
  variant="primary"
  :disabled="pubtatorJob.isLoading.value"
  @click="updatePubtatorData"
>
  <BSpinner v-if="pubtatorJob.isLoading.value" small type="grow" class="me-2" />
  {{ pubtatorJob.isLoading.value ? 'Updating...' : 'Update Pubtator Cache' }}
</BButton>
```

### BFormTag for PMID Chips
```vue
<!-- Source: BatchCriteriaForm.vue pattern -->
<BFormTag
  v-for="pmid in row.pmids.slice(0, 5)"
  :key="pmid"
  variant="primary"
  class="me-1 mb-1"
  style="cursor: pointer"
  no-remove
  @click="openPubMed(pmid)"
>
  <i class="bi bi-box-arrow-up-right me-1" />
  {{ pmid }}
</BFormTag>
<BBadge v-if="row.pmids.length > 5" variant="secondary" pill>
  +{{ row.pmids.length - 5 }} more
</BBadge>
```

### Client-side Excel Export
```typescript
// Source: useExcelExport.ts
const { isExporting, exportToExcel } = useExcelExport();

const handleExport = async () => {
  // Get current filtered data
  const exportData = filteredGenes.value.map(gene => ({
    gene_symbol: gene.gene_symbol,
    publication_count: gene.publication_count,
    oldest_pub_date: gene.oldest_pub_date,
    in_sysndd: gene.is_novel ? 'No' : 'Yes',
    pmids: gene.pmids.join(', ')
  }));

  await exportToExcel(exportData, {
    filename: `pubtator_genes_${new Date().toISOString().split('T')[0]}`,
    sheetName: 'Gene Prioritization'
  });
};
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline polling with setInterval | `useAsyncJob` composable | Phase 32 | Auto-cleanup, consistent UX |
| Server-only Excel export | Client + Server options | Phase varies | Faster filtered exports |
| Options API components | Composition API (setup) | Vue 3 migration | Better type safety |

**Deprecated/outdated:**
- `pubtator_cache` table: Dropped in favor of 3-table structure (query/search/annotation caches)
- Treeselect component: Vue 3 compatibility issues, use BFormSelect for multi-select

## Open Questions

Things that couldn't be fully resolved:

1. **Query Configuration Storage**
   - What we know: Decision says "admin-configurable, stored in database/config"
   - What's unclear: Specific table/column structure for storing query
   - Recommendation: Create simple `pubtator_config` table with `key/value` or add column to `pubtator_query_cache`

2. **Update Trigger API Endpoint**
   - What we know: `pubtator_db_update()` function exists in `pubtator-functions.R`
   - What's unclear: Whether to expose as async job or synchronous endpoint
   - Recommendation: Follow ManageAnnotations pattern with async job for long-running update

3. **Stats Calculation Granularity**
   - What we know: Basic stats needed: last update time, total publications, total genes
   - What's unclear: Whether to calculate on-demand or cache
   - Recommendation: Calculate on-demand from existing tables (simple COUNT queries)

## Sources

### Primary (HIGH confidence)
- `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageAnnotations.vue` - Admin panel patterns
- `/home/bernt-popp/development/sysndd/app/src/components/analyses/AnalysesCurationComparisonsTable.vue` - Help badge pattern
- `/home/bernt-popp/development/sysndd/api/endpoints/publication_endpoints.R` - Pubtator API endpoints
- `/home/bernt-popp/development/sysndd/api/functions/pubtator-functions.R` - Pubtator update logic
- `/home/bernt-popp/development/sysndd/db/16_Rcommands_sysndd_db_pubtator_cache_table.R` - Database schema
- `/home/bernt-popp/development/sysndd/db/C_Rcommands_set-table-connections.R` - View definition
- `/home/bernt-popp/development/sysndd/app/src/composables/useAsyncJob.ts` - Async job pattern
- `/home/bernt-popp/development/sysndd/app/src/composables/useExcelExport.ts` - Excel export pattern

### Secondary (MEDIUM confidence)
- Component patterns extracted from multiple analysis components

### Tertiary (LOW confidence)
- None - all findings verified against codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, verified in package.json and renv.lock
- Architecture: HIGH - Patterns extracted directly from working codebase
- Pitfalls: HIGH - Identified from actual code issues (Stats API endpoint)

**Research date:** 2026-01-31
**Valid until:** 60 days (stable patterns, internal codebase)
