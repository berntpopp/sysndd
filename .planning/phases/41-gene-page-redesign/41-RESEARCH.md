# Phase 41: Gene Page Redesign - Research

**Researched:** 2026-01-27
**Domain:** Vue 3 UI/UX redesign with Bootstrap-Vue-Next, Composition API migration
**Confidence:** HIGH

## Summary

The current Gene.vue (`/app/src/views/pages/GeneView.vue`) is a 539-line Options API component that displays gene information in a flat, stacked table layout. The redesign transforms this into a modern, card-based layout using Composition API with `<script setup>`, reusable components, and responsive grid patterns.

**Current State:**
- Options API with `data()`, `methods`, lifecycle hooks
- Single BCard containing stacked BTable with custom cell templates
- Inline external link buttons repeated for every identifier (11 fields × duplicate code)
- Clinical resource links (HGNC, SFARI, g2p, PanelApp, ClinGen) mixed into the symbol field
- BSpinner loading state only
- All layout done with BRow/BCol within template slots

**Target State:**
- Composition API with `<script setup>` syntax
- Hero section + multiple organized cards with responsive grid
- Reusable IdentifierRow and ResourceLink components
- Grouped clinical resources in dedicated card
- Simple centered spinner (per CONTEXT.md decision)
- Responsive breakpoints for desktop/tablet/mobile

**Primary recommendation:** Follow existing SysNDD design patterns (3D badge styles, subtle drop shadows, gradient backgrounds), use Bootstrap-Vue-Next grid system with standard breakpoints (sm/md/lg/xl), and migrate incrementally by extracting reusable components first, then refactoring Gene.vue to use them.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue | 3.5.25 | Component framework | Already in project, modern reactivity |
| TypeScript | 5.9.3 | Type safety | Already configured for .vue files |
| Bootstrap-Vue-Next | 0.42.0 | UI components | Already in project, Bootstrap 5 integration |
| @vueuse/core | 14.1.0 | Composition utilities | Already in dependencies, standard Vue utilities |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bootstrap-icons | 1.13.1 | Icon set | External link, copy icons (already used) |
| @unhead/vue | 2.1.2 | Meta tags | Page title/description (already in Gene.vue) |
| vitest | 4.0.18 | Testing framework | Unit tests for new components |
| @testing-library/vue | 8.1.0 | Component testing | Integration tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap-Vue-Next | PrimeVue, Vuetify | Would require major refactor, existing codebase uses BVN |
| Native clipboard API | clipboard.js library | Native API has 95%+ browser support, simpler |
| Custom grid | CSS Grid | BVN grid is already used throughout codebase, consistency |

**Installation:**
No new packages required — all dependencies already in package.json.

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── views/pages/
│   └── GeneView.vue          # Main page component (refactored to script setup)
├── components/gene/
│   ├── GeneHero.vue          # Hero section with symbol, name, location
│   ├── IdentifierCard.vue    # Card containing all gene identifiers
│   ├── IdentifierRow.vue     # Reusable row with copy + external link
│   ├── ResourceLink.vue      # Card-style external resource link
│   └── ClinicalResourcesCard.vue  # Clinical resources grid
└── components/ui/
    └── GeneBadge.vue         # Already exists, reuse
```

### Pattern 1: Composition API with Script Setup
**What:** Modern Vue 3 component syntax that eliminates boilerplate
**When to use:** All new components and refactored pages
**Example:**
```typescript
// Source: https://v3-migration.vuejs.org/ + SysNDD StatCard.vue pattern
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useToast } from '@/composables';
import axios from 'axios';

interface GeneData {
  symbol: string[];
  name: string[];
  entrez_id: string[];
  // ... other fields
}

const route = useRoute();
const { makeToast } = useToast();

const loading = ref(true);
const geneData = ref<GeneData[]>([]);

const geneSymbol = computed(() =>
  geneData.value[0]?.symbol[0] || ''
);

async function loadGeneInfo() {
  loading.value = true;
  try {
    const symbol = route.params.symbol;
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/gene/${symbol}?input_type=symbol`
    );
    geneData.value = response.data;
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  loadGeneInfo();
});
</script>
```

### Pattern 2: Reusable Component with Props & Emits
**What:** Extract repeated UI patterns into typed, reusable components
**When to use:** When same pattern appears 3+ times (identifier rows, resource links)
**Example:**
```typescript
// Source: SysNDD GeneBadge.vue + EntityBadge.vue pattern
<script setup lang="ts">
interface Props {
  label: string;
  value?: string;
  externalUrl?: string;
  showCopy?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  value: undefined,
  externalUrl: undefined,
  showCopy: true,
});

const emit = defineEmits<{
  copy: [value: string];
}>();

function handleCopy() {
  if (props.value) {
    emit('copy', props.value);
  }
}
</script>
```

### Pattern 3: Bootstrap-Vue-Next Responsive Grid
**What:** Use BContainer/BRow/BCol with breakpoint props for responsive layouts
**When to use:** All card layouts, hero sections, multi-column displays
**Example:**
```vue
<!-- Source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/grid-system -->
<BContainer fluid>
  <BRow>
    <!-- Full width on mobile, half width on medium+ -->
    <BCol cols="12" md="6">
      <IdentifierCard :gene-data="geneData" />
    </BCol>
    <BCol cols="12" md="6">
      <ClinicalResourcesCard :gene-symbol="geneSymbol" />
    </BCol>
  </BRow>
</BContainer>
```

### Pattern 4: Card with Drop Shadow (Existing SysNDD Pattern)
**What:** BCard without visible border, using box-shadow for elevation
**When to use:** All cards in redesigned layout
**Example:**
```vue
<!-- Source: Existing SysNDD pattern in EntityView.vue, AdminStatistics.vue -->
<BCard
  class="gene-info-card"
  border-variant="light"
>
  <!-- content -->
</BCard>

<style scoped>
.gene-info-card {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  border: none;
}
</style>
```

### Anti-Patterns to Avoid
- **Skeleton loaders:** CONTEXT.md explicitly requests simple centered spinner instead
- **Hiding empty fields:** Show "Not available" instead, users need to see what data is missing
- **Database-specific logos:** Use generic icons (bi-box-arrow-up-right), no vendor branding
- **Tooltip on spinner:** Keep loading state minimal, just centered spinner

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Copy to clipboard | Custom fallback chain | `navigator.clipboard.writeText()` | Native API, 95%+ browser support, simpler error handling |
| Responsive breakpoints | Custom media queries | BVN grid props (sm/md/lg/xl) | Consistent with Bootstrap, tested across devices |
| Loading states | Custom skeleton components | BSpinner centered | User explicitly requested simple spinner |
| Toast notifications | Custom toast system | `useToast` composable | Already in codebase, tested, accessible |
| Icon rendering | Custom SVG components | `bootstrap-icons` classes | Already in project, 2000+ icons available |
| Badge styling | Custom CSS classes | GeneBadge component | Already exists, 3D style, consistent |

**Key insight:** SysNDD already has comprehensive UI patterns and utilities. Reuse GeneBadge, useToast, BVN grid, bootstrap-icons rather than creating new patterns. Consistency > novelty.

## Common Pitfalls

### Pitfall 1: Forgetting to Handle Array Fields from API
**What goes wrong:** API returns `symbol: ["MECP2"]` (array), template expects string, displays "[object Array]"
**Why it happens:** API gene endpoint wraps all fields in arrays (line 236 in gene_endpoints.R: `mutate(across(everything(), ~ str_split(., pattern = "\\|")))`)
**How to avoid:** Always access first element: `geneData[0]?.symbol[0]` or use computed properties
**Warning signs:** Vue warnings about object being rendered as text, display shows "[object Array]"

### Pitfall 2: Not Using Computed Properties for Derived State
**What goes wrong:** Directly accessing nested reactive data in template causes excessive re-renders
**Why it happens:** Vue 3 reactivity triggers on all property access in template
**How to avoid:** Extract derived values into computed properties:
```typescript
const geneSymbol = computed(() => geneData.value[0]?.symbol[0] || '');
const hasOmimId = computed(() =>
  geneData.value[0]?.omim_id?.[0] && geneData.value[0].omim_id[0] !== ''
);
```
**Warning signs:** Performance issues, unnecessary API calls, console warnings

### Pitfall 3: Missing Type Definitions for API Response
**What goes wrong:** TypeScript errors, autocomplete doesn't work, runtime errors from wrong field names
**Why it happens:** API response structure not typed
**How to avoid:** Define interface matching API response structure:
```typescript
interface GeneApiResponse {
  hgnc_id: string[];
  symbol: string[];
  name: string[];
  entrez_id: string[];
  // ... match all fields from gene_endpoints.R line 218-232
}
```
**Warning signs:** TypeScript `any` types, incorrect property access, IDE doesn't suggest fields

### Pitfall 4: Clipboard API Requires HTTPS/Localhost
**What goes wrong:** `navigator.clipboard.writeText()` throws error in production
**Why it happens:** Clipboard API requires secure context (HTTPS or localhost)
**How to avoid:** Wrap in try-catch, show helpful error message. SysNDD is served over HTTPS in production, but test locally first.
**Warning signs:** Works in development (localhost), fails in production

### Pitfall 5: Over-Engineering Empty States
**What goes wrong:** Trying to predict which IDs are "important" and hide others
**Why it happens:** Designer instinct to clean up UI
**How to avoid:** CONTEXT.md is explicit: show all rows with "Not available" text. Users need to see the full set of possible identifiers.
**Warning signs:** Logic for conditional rendering of identifier rows, complaints from users about missing info

## Code Examples

Verified patterns from official sources:

### Copy to Clipboard with Toast Feedback
```typescript
// Source: SysNDD pattern from PublicationsNDDTable.vue line 547-554
async function copyToClipboard(value: string, label: string) {
  try {
    await navigator.clipboard.writeText(value);
    makeToast(`${label} copied to clipboard`, 'Info', 'info');
  } catch (e) {
    makeToast('Failed to copy to clipboard', 'Error', 'danger');
  }
}
```

### Responsive Card Grid Layout
```vue
<!-- Source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/card -->
<BContainer fluid>
  <BRow class="g-3"> <!-- g-3 adds gap between columns -->
    <BCol cols="12" lg="6">
      <BCard class="h-100"> <!-- h-100 makes cards same height -->
        <h4>Identifiers</h4>
        <!-- content -->
      </BCard>
    </BCol>
    <BCol cols="12" lg="6">
      <BCard class="h-100">
        <h4>Clinical Resources</h4>
        <!-- content -->
      </BCard>
    </BCol>
  </BRow>
</BContainer>
```

### External Link Button (Existing Pattern)
```vue
<!-- Source: Current GeneView.vue lines 61-75, standardized -->
<BButton
  v-b-tooltip.hover.bottom
  size="sm"
  variant="outline-primary"
  :href="externalUrl"
  :title="`${label} in ${databaseName}`"
  target="_blank"
>
  <i class="bi bi-box-arrow-up-right" />
  <span class="font-italic">{{ label }}</span>
</BButton>
```

### Empty State Display
```vue
<!-- Source: CONTEXT.md decision + SysNDD neutral tone -->
<div v-if="!value || value === ''" class="text-muted">
  Not available
</div>
<div v-else>
  {{ value }}
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Options API | Composition API with `<script setup>` | Vue 3.2+ (2021) | Better TypeScript support, less boilerplate |
| Inline template logic | Computed properties | Vue 3 best practices | Cleaner templates, better performance |
| Manual reactive variables | `ref()` and `reactive()` | Vue 3.0 (2020) | Explicit reactivity, easier debugging |
| Class-based styling | Utility classes + scoped CSS | Bootstrap 5 (in BVN) | Faster development, consistent spacing |
| Custom icons | Icon fonts (bootstrap-icons) | Industry standard 2020+ | Better accessibility, easier updates |

**Deprecated/outdated:**
- `this.$refs` in Composition API: Use `ref()` with template refs instead
- `v-b-tooltip` directive: Still works in BVN but prefer programmatic tooltips for dynamic content
- `BTable` stacked mode for identifiers: Better UX with custom card layout and explicit rows

## Open Questions

Things that couldn't be fully resolved:

1. **Chromosome location field availability**
   - What we know: API endpoint returns fields from `non_alt_loci_set` table (lines 218-232 of gene_endpoints.R)
   - What's unclear: No chromosome_band/location field visible in returned fields
   - Recommendation: Check database schema or add to API response if needed. Hero section should show "Chromosome: 17q21.1" (example), but this field may need to be added to API.

2. **Clinical resource grouping categories**
   - What we know: CONTEXT.md says group by type like "Curation", "Disease", "Genome"
   - What's unclear: Exact categorization for 6 resources (OMIM, ClinGen, SFARI, PanelApp, g2p, HGNC)
   - Recommendation: Suggest grouping as:
     - **Curation:** ClinGen, SFARI
     - **Disease/Phenotype:** OMIM, gene2phenotype, PanelApp
     - **Gene Information:** HGNC
   - This should be validated with domain expert during planning

3. **MANE Select transcript display**
   - What we know: API returns `mane_select` field (line 228)
   - What's unclear: Should this be displayed prominently in redesign or kept in "other identifiers"?
   - Recommendation: Include in identifier card but not in hero section. MANE is important for clinical users but secondary to gene symbol/name.

## Sources

### Primary (HIGH confidence)
- SysNDD codebase analysis:
  - `/app/src/views/pages/GeneView.vue` - Current implementation
  - `/app/src/components/ui/GeneBadge.vue` - Badge component pattern
  - `/app/src/components/ui/EntityBadge.vue` - 3D styling pattern
  - `/app/src/components/ui/EmptyState.vue` - Empty state component
  - `/app/src/views/admin/components/statistics/StatCard.vue` - Script setup pattern
  - `/app/src/composables/useToast.ts` - Toast notification pattern
  - `/app/package.json` - Dependencies and versions
  - `/api/endpoints/gene_endpoints.R` - API response structure
- Bootstrap-Vue-Next official documentation (v0.42.0 compatible)
- Vue 3 official migration guide

### Secondary (MEDIUM confidence)
- [Ten simple rules for developing visualization tools in genomics](https://pmc.ncbi.nlm.nih.gov/articles/PMC9648702/) - Performance and design principles
- [Ensembl Browsing Guide](https://training.ensembl.org/pdf_walkthrough.pdf) - Gene page structure (tabs, transcript tables)
- [NCBI Gene Help](https://www.ncbi.nlm.nih.gov/books/NBK3841/) - External links, browser integration patterns
- [GeneCards Guide](https://www.genecards.org/Guide/GeneCard) - Card-based design, compact display, tooltips
- [Vue 3 Composition API Migration](https://dev.to/nicolasmontielf/migrate-option-api-to-composition-api-on-vue3-4o3p) - Script setup patterns
- [Bootstrap-Vue-Next Grid System](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/grid-system) - Responsive layouts
- [Bootstrap-Vue-Next Card](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/card) - Card component usage

### Tertiary (LOW confidence)
- Web search results for genomic UI best practices - General principles only
- Dribbble genomic UI designs - Visual inspiration but not authoritative for genomic database standards

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in package.json, versions confirmed
- Architecture: HIGH - Patterns extracted from existing SysNDD components (StatCard, GeneBadge, EntityBadge)
- API data model: MEDIUM - Gene endpoint structure verified in R code, but chromosome location field unclear
- Pitfalls: HIGH - Based on actual code patterns and Vue 3 Composition API documentation
- Clinical resource grouping: LOW - Needs domain expert validation

**Research date:** 2026-01-27
**Valid until:** 30 days (stable libraries, established patterns)
