# Phase 42: Constraint Scores & Variant Summaries - Research

**Researched:** 2026-01-27
**Domain:** Vue 3 frontend for gnomAD constraint scores and ClinVar pathogenicity summaries with independent loading states
**Confidence:** HIGH

## Summary

Phase 42 implements visualization cards for gnomAD constraint metrics (pLI, LOEUF, missense Z) and ClinVar variant pathogenicity summaries on the gene page. The backend API layer (Phase 40) already provides the data via `/api/external/gene/<symbol>` aggregation endpoint with per-source error isolation. The frontend challenge is creating Bootstrap-Vue-Next card components that load independently, handle per-source error states, and render constraint tables matching gnomAD's layout without D3.js dependency.

The standard Vue 3 stack provides robust patterns for this:
- **Vue 3 Composition API composables** for data fetching with reactive loading/error states per source
- **Bootstrap-Vue-Next cards** (BCard) for card layout with header links and spinner integration
- **CSS/SVG for confidence interval bars** - simple horizontal bars without D3.js complexity
- **ARIA labels and role attributes** for screen reader accessibility on numeric data

**Key implementation insights:**
1. Composable returns per-source state objects (loading, error, data) for independent card rendering
2. Constraint table matches gnomAD layout: Category/Expected/Observed/Metrics columns with o/e CI bars
3. ClinVar badges use ACMG color mapping (red/orange/yellow/light-green/green) with counts
4. Error states keep cards visible with inline messages and retry buttons (graceful degradation)
5. ARIA labels provide numeric values for screen readers, not just visual gauges

**Primary recommendation:** Create `useGeneExternalData` composable that fetches from combined endpoint and exposes reactive per-source objects. Render constraint table using Bootstrap table classes with pure CSS horizontal bars for o/e confidence intervals. Use Bootstrap badge components for ClinVar pathogenicity counts with ACMG-inspired color scheme.

## Standard Stack

The established libraries/tools for Vue 3 data visualization with Bootstrap:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3.5.25 | 3.5.25 | Reactivity and Composition API | Already in project, provides reactive state for loading/error/data per source |
| Bootstrap-Vue-Next | 0.42.0 | Bootstrap 5 components for Vue 3 | Already in project, provides BCard, BSpinner, BBadge, BTable |
| @vueuse/core | 14.1.0 | Vue composition utilities | Already in project, useIntervalFn for polling cleanup (if retry logic needed) |
| TypeScript | 5.9.3 | Type safety | Already in project, ensures type-safe composable interfaces |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| axios | 1.13.2 | HTTP client | Already in project as devDependency, used for API calls with Authorization headers |
| Bootstrap 5.3.8 | 5.3.8 | CSS framework | Already in project, provides utility classes for card spacing, badge colors |
| Bootstrap Icons | 1.13.1 | Icon fonts | Already in project, external-link icons for gnomAD/ClinVar links |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CSS horizontal bars | D3.js for confidence intervals | User decision: "Small horizontal o/e confidence interval bars rendered with pure CSS/SVG (no D3.js dependency)" - CSS is simpler, no bundle bloat |
| Composable pattern | Direct axios in component | Composables enable reusability, testing, and source-specific state isolation |
| Bootstrap badges | Custom styled spans | Bootstrap badges provide ACMG colors via variant prop, accessibility attributes built-in |

**Installation:**
```bash
# All dependencies already in project
# No additional packages needed
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── composables/
│   └── useGeneExternalData.ts    # New: fetch external data, per-source state
├── components/
│   └── gene/                      # New folder for gene-specific components
│       ├── GeneConstraintCard.vue      # gnomAD constraint table
│       ├── GeneClinVarCard.vue         # ClinVar pathogenicity summary
│       └── ConfidenceIntervalBar.vue   # Reusable o/e CI bar (optional)
├── views/pages/
│   └── GeneView.vue              # Existing: add constraint/ClinVar cards
└── types/
    └── external.ts               # New: TypeScript interfaces for API responses
```

### Pattern 1: Composable with Per-Source State Isolation
**What:** Composable fetches combined endpoint, exposes reactive objects per source (gnomad, clinvar) with loading/error/data
**When to use:** For any API endpoint that aggregates multiple independent sources
**Example:**
```typescript
// Source: Adapted from existing useAsyncJob.ts pattern + kidney-genetics-db reference
// app/src/composables/useGeneExternalData.ts

import { ref, computed, type Ref } from 'vue'
import axios from 'axios'

interface SourceState<T> {
  loading: Ref<boolean>
  error: Ref<string | null>
  data: Ref<T | null>
}

interface GnomADConstraints {
  pLI: number | null
  oe_lof: number | null
  oe_lof_lower: number | null
  oe_lof_upper: number | null
  oe_mis: number | null
  oe_mis_lower: number | null
  oe_mis_upper: number | null
  oe_syn: number | null
  oe_syn_lower: number | null
  oe_syn_upper: number | null
  exp_lof: number | null
  obs_lof: number | null
  exp_mis: number | null
  obs_mis: number | null
  exp_syn: number | null
  obs_syn: number | null
  lof_z: number | null
  mis_z: number | null
  syn_z: number | null
}

interface ClinVarVariant {
  clinical_significance: string
  clinvar_variation_id: string
  gold_stars: number
  major_consequence: string
  // ... other fields from gnomAD API
}

export function useGeneExternalData(geneSymbol: Ref<string> | string) {
  const symbol = typeof geneSymbol === 'string' ? ref(geneSymbol) : geneSymbol

  // Per-source state objects
  const gnomad: SourceState<GnomADConstraints> = {
    loading: ref(true),
    error: ref(null),
    data: ref(null)
  }

  const clinvar: SourceState<ClinVarVariant[]> = {
    loading: ref(true),
    error: ref(null),
    data: ref(null)
  }

  // Computed: overall loading state (any source still loading)
  const loading = computed(() => gnomad.loading.value || clinvar.loading.value)

  // Fetch from combined endpoint
  async function fetchData() {
    if (!symbol.value) return

    // Reset states
    gnomad.loading.value = true
    gnomad.error.value = null
    clinvar.loading.value = true
    clinvar.error.value = null

    try {
      const response = await axios.get(
        `${import.meta.env.VITE_API_URL}/api/external/gene/${symbol.value}`,
        {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`
          }
        }
      )

      const result = response.data

      // gnomAD constraints - check for source in results or errors
      if (result.sources?.gnomad?.constraints) {
        gnomad.data.value = result.sources.gnomad.constraints
        gnomad.loading.value = false
      } else if (result.errors?.gnomad) {
        gnomad.error.value = result.errors.gnomad.detail || 'Failed to load constraint data'
        gnomad.loading.value = false
      } else {
        gnomad.error.value = 'No constraint data available'
        gnomad.loading.value = false
      }

      // ClinVar variants - check for source in results or errors
      if (result.sources?.gnomad_clinvar?.variants) {
        clinvar.data.value = result.sources.gnomad_clinvar.variants
        clinvar.loading.value = false
      } else if (result.errors?.gnomad) {
        // ClinVar fetched via gnomAD API, so same error source
        clinvar.error.value = result.errors.gnomad.detail || 'Failed to load ClinVar data'
        clinvar.loading.value = false
      } else {
        clinvar.error.value = 'No ClinVar data available'
        clinvar.loading.value = false
      }

    } catch (err: any) {
      // Network error - all sources fail together
      const errorMsg = err.response?.data?.detail || err.message || 'Failed to fetch data'
      gnomad.error.value = errorMsg
      gnomad.loading.value = false
      clinvar.error.value = errorMsg
      clinvar.loading.value = false
    }
  }

  // Retry for individual source
  async function retry() {
    await fetchData()
  }

  return {
    gnomad,
    clinvar,
    loading,
    fetchData,
    retry
  }
}
```

### Pattern 2: gnomAD Constraint Table Card (Bootstrap Card with Table)
**What:** Bootstrap card wrapping constraint table matching gnomAD layout with CSS o/e bars
**When to use:** Displaying constraint metrics (pLI, LOEUF, Z-scores) as table
**Example:**
```vue
<!-- Source: User decisions from CONTEXT.md + kidney-genetics-db GeneConstraints.vue adapted -->
<!-- app/src/components/gene/GeneConstraintCard.vue -->

<template>
  <BCard
    header-tag="header"
    class="constraint-card"
    border-variant="secondary"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h5 class="mb-0">Gene Constraint (gnomAD)</h5>
        <BButton
          variant="link"
          size="sm"
          :href="`https://gnomad.broadinstitute.org/gene/${geneSymbol}`"
          target="_blank"
          class="text-decoration-none"
        >
          <i class="bi bi-box-arrow-up-right" />
          View in gnomAD
        </BButton>
      </div>
    </template>

    <!-- Loading state -->
    <BSpinner v-if="loading" class="d-block mx-auto my-4" label="Loading constraint data..." />

    <!-- Error state -->
    <div v-else-if="error" class="text-center py-3">
      <p class="text-muted mb-2">{{ error }}</p>
      <BButton variant="outline-primary" size="sm" @click="$emit('retry')">
        Retry
      </BButton>
    </div>

    <!-- No data state -->
    <div v-else-if="!data" class="text-center py-3">
      <i class="bi bi-info-circle text-muted" />
      <p class="text-muted mb-0">No constraint data available for this gene</p>
    </div>

    <!-- Constraint table -->
    <BTable
      v-else
      :items="tableItems"
      :fields="tableFields"
      small
      striped
      hover
      class="mb-0"
    >
      <template #cell(category)="data">
        <strong>{{ data.value }}</strong>
      </template>

      <template #cell(metrics)="data">
        <div class="metrics-cell">
          <!-- Z-score -->
          <span class="me-3">
            <strong>Z:</strong> {{ formatNumber(data.item.z_score, 2) }}
          </span>

          <!-- o/e ratio with CI bar -->
          <span class="me-3">
            <strong>o/e:</strong> {{ formatNumber(data.item.oe, 2) }}
          </span>

          <!-- Confidence interval horizontal bar -->
          <div class="ci-bar-container" :aria-label="getCIAriaLabel(data.item)">
            <svg width="100" height="12" role="img">
              <!-- Gray background for range 0-2 -->
              <rect x="0" y="5" width="100" height="2" fill="#e0e0e0" />

              <!-- CI bar (oe_lower to oe_upper mapped to 0-100px for 0-2 range) -->
              <rect
                :x="scaleOE(data.item.oe_lower)"
                y="3"
                :width="scaleOE(data.item.oe_upper) - scaleOE(data.item.oe_lower)"
                height="6"
                :fill="getOEColor(data.item.oe_upper, data.item.category)"
                rx="1"
              />

              <!-- Point estimate marker -->
              <circle
                :cx="scaleOE(data.item.oe)"
                cy="6"
                r="3"
                fill="#333"
              />
            </svg>
            <span class="small text-muted ms-1">
              ({{ formatNumber(data.item.oe_lower, 2) }} - {{ formatNumber(data.item.oe_upper, 2) }})
            </span>
          </div>

          <!-- pLI for pLoF row -->
          <span v-if="data.item.category === 'pLoF'" class="ms-3">
            <strong>pLI:</strong> {{ formatNumber(data.item.pli, 2) }}
          </span>
        </div>
      </template>
    </BTable>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { GnomADConstraints } from '@/types/external'

interface Props {
  geneSymbol: string
  loading: boolean
  error: string | null
  data: GnomADConstraints | null
}

const props = defineProps<Props>()
defineEmits<{ retry: [] }>()

// Table structure matching gnomAD layout
const tableFields = [
  { key: 'category', label: 'Category', thStyle: 'width: 15%' },
  { key: 'exp', label: 'Expected SNVs', thStyle: 'width: 15%' },
  { key: 'obs', label: 'Observed SNVs', thStyle: 'width: 15%' },
  { key: 'metrics', label: 'Constraint Metrics', thStyle: 'width: 55%' }
]

const tableItems = computed(() => {
  if (!props.data) return []

  return [
    {
      category: 'Synonymous',
      exp: props.data.exp_syn,
      obs: props.data.obs_syn,
      z_score: props.data.syn_z,
      oe: props.data.oe_syn,
      oe_lower: props.data.oe_syn_lower,
      oe_upper: props.data.oe_syn_upper,
      pli: null
    },
    {
      category: 'Missense',
      exp: props.data.exp_mis,
      obs: props.data.obs_mis,
      z_score: props.data.mis_z,
      oe: props.data.oe_mis,
      oe_lower: props.data.oe_mis_lower,
      oe_upper: props.data.oe_mis_upper,
      pli: null
    },
    {
      category: 'pLoF',
      exp: props.data.exp_lof,
      obs: props.data.obs_lof,
      z_score: props.data.lof_z,
      oe: props.data.oe_lof,
      oe_lower: props.data.oe_lof_lower,
      oe_upper: props.data.oe_lof_upper,
      pli: props.data.pLI
    }
  ]
})

// Scale o/e value (0-2 range) to SVG x position (0-100px)
function scaleOE(value: number | null): number {
  if (value === null) return 0
  return Math.max(0, Math.min(100, value * 50)) // 50px per unit (0-2 range = 0-100px)
}

// Color for o/e CI bar - highlight LOEUF < 0.6 in amber (per gnomAD v4 guideline)
function getOEColor(oe_upper: number | null, category: string): string {
  if (category === 'pLoF' && oe_upper !== null && oe_upper < 0.6) {
    return '#ffc107' // Amber for highly constrained (LOEUF < 0.6)
  }
  return '#6c757d' // Gray for normal
}

function formatNumber(value: number | null, decimals: number): string {
  if (value === null) return 'N/A'
  return value.toFixed(decimals)
}

function getCIAriaLabel(item: any): string {
  return `Observed/expected ratio: ${formatNumber(item.oe, 2)}, confidence interval ${formatNumber(item.oe_lower, 2)} to ${formatNumber(item.oe_upper, 2)}`
}
</script>

<style scoped>
.constraint-card {
  height: 100%;
}

.metrics-cell {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
}

.ci-bar-container {
  display: inline-flex;
  align-items: center;
}
</style>
```

### Pattern 3: ClinVar Pathogenicity Badge Row
**What:** Row of colored badges for ACMG pathogenicity classes with counts
**When to use:** Summarizing ClinVar variant pathogenicity distribution
**Example:**
```vue
<!-- Source: User decisions from CONTEXT.md + kidney-genetics-db ClinVarVariants.vue adapted -->
<!-- app/src/components/gene/GeneClinVarCard.vue -->

<template>
  <BCard
    header-tag="header"
    class="clinvar-card"
    border-variant="secondary"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h5 class="mb-0">ClinVar Variants ({{ totalCount }})</h5>
        <BButton
          variant="link"
          size="sm"
          :href="`https://www.ncbi.nlm.nih.gov/clinvar/?term=${geneSymbol}[gene]`"
          target="_blank"
          class="text-decoration-none"
        >
          <i class="bi bi-box-arrow-up-right" />
          View in ClinVar
        </BButton>
      </div>
    </template>

    <!-- Loading state -->
    <BSpinner v-if="loading" class="d-block mx-auto my-4" label="Loading ClinVar data..." />

    <!-- Error state -->
    <div v-else-if="error" class="text-center py-3">
      <p class="text-muted mb-2">{{ error }}</p>
      <BButton variant="outline-primary" size="sm" @click="$emit('retry')">
        Retry
      </BButton>
    </div>

    <!-- No data state -->
    <div v-else-if="totalCount === 0" class="text-center py-3">
      <i class="bi bi-info-circle text-muted" />
      <p class="text-muted mb-0">No ClinVar variants available for this gene</p>
    </div>

    <!-- Badge row with ACMG color coding -->
    <div v-else class="d-flex flex-wrap gap-2 p-3">
      <BBadge
        v-for="category in categories"
        :key="category.key"
        :variant="category.variant"
        :aria-label="`${category.label}: ${category.count} variants`"
        class="py-2 px-3"
      >
        <strong>{{ category.label }}</strong>
        <span class="ms-2">({{ category.count }})</span>
      </BBadge>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { ClinVarVariant } from '@/types/external'

interface Props {
  geneSymbol: string
  loading: boolean
  error: string | null
  data: ClinVarVariant[] | null
}

const props = defineProps<Props>()
defineEmits<{ retry: [] }>()

// Count variants by clinical significance
const counts = computed(() => {
  if (!props.data) return { pathogenic: 0, likely_pathogenic: 0, vus: 0, likely_benign: 0, benign: 0 }

  const result = { pathogenic: 0, likely_pathogenic: 0, vus: 0, likely_benign: 0, benign: 0 }

  props.data.forEach(variant => {
    const sig = variant.clinical_significance?.toLowerCase() || ''

    if (sig.includes('pathogenic') && !sig.includes('likely')) {
      result.pathogenic++
    } else if (sig.includes('likely pathogenic')) {
      result.likely_pathogenic++
    } else if (sig.includes('uncertain')) {
      result.vus++
    } else if (sig.includes('likely benign')) {
      result.likely_benign++
    } else if (sig.includes('benign') && !sig.includes('likely')) {
      result.benign++
    }
  })

  return result
})

const totalCount = computed(() => props.data?.length || 0)

// ACMG color mapping (per user requirements: red, orange, yellow, light green, green)
const categories = computed(() => [
  {
    key: 'pathogenic',
    label: 'Pathogenic',
    count: counts.value.pathogenic,
    variant: 'danger' as const // Red
  },
  {
    key: 'likely_pathogenic',
    label: 'Likely Pathogenic',
    count: counts.value.likely_pathogenic,
    variant: 'warning' as const // Orange/amber
  },
  {
    key: 'vus',
    label: 'VUS',
    count: counts.value.vus,
    variant: 'secondary' as const // Yellow (using secondary, custom CSS needed for true yellow)
  },
  {
    key: 'likely_benign',
    label: 'Likely Benign',
    count: counts.value.likely_benign,
    variant: 'success' as const // Light green
  },
  {
    key: 'benign',
    label: 'Benign',
    count: counts.value.benign,
    variant: 'success' as const // Green (same as likely benign in Bootstrap)
  }
].filter(cat => cat.count > 0)) // Only show categories with variants
</script>

<style scoped>
.clinvar-card {
  height: 100%;
}

/* Custom yellow for VUS badge (Bootstrap secondary is gray by default) */
.badge.bg-secondary {
  background-color: #ffc107 !important; /* Bootstrap warning color - amber/yellow */
  color: #000 !important;
}
</style>
```

### Anti-Patterns to Avoid
- **Single loading state for all sources:** Don't use one `loading` boolean; cards must load independently (per user requirement: COMPOSE-02/03)
- **D3.js for simple bars:** User explicitly decided "pure CSS/SVG (no D3.js dependency)" - don't add D3 for confidence interval bars
- **Hiding failed cards:** User decided "Error state: card stays visible with inline muted error message" - graceful degradation, not removal
- **Interpretation text alongside scores:** User decided "No interpretation text alongside scores — researchers interpret values themselves" - just display numbers
- **Prominent pLI display:** User decided "pLI stays embedded in the pLoF table row (no headline/prominent display)" - matches gnomAD layout

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Data fetching with loading/error states | Manual axios + useState in component | Vue composable pattern | Reusability, testability, source-specific state isolation |
| Retry logic with exponential backoff | Manual setTimeout loops | Backend httr2::req_retry (already implemented) | Edge cases handled (429 responses, Retry-After headers), frontend just calls retry() |
| Color scheme for pathogenicity | Custom CSS classes | Bootstrap badge variants (danger/warning/success) | ACMG colors approximate Bootstrap variants, accessibility built-in |
| Accessible numeric displays | Custom span with title | ARIA labels (aria-label) on visual elements | Screen readers announce numeric values, not visual descriptions |
| Confidence interval calculation | Frontend math | Backend provides oe_lower/oe_upper from gnomAD | gnomAD calculates 90% CI, don't recalculate on frontend |
| Card loading skeletons | Custom animated divs | Bootstrap BSpinner component | Built-in, accessible (role="status"), consistent with project |

**Key insight:** Vue 3 composables are the standard pattern for stateful logic extraction. Don't put API calls directly in components - composables enable per-source state isolation, retry logic, and testing. Backend already handles complex retry/throttle logic; frontend just needs to expose loading/error/data reactively.

## Common Pitfalls

### Pitfall 1: Shared Loading State Blocks Independent Card Rendering
**What goes wrong:** Using single `loading` boolean for entire external data fetch; when gnomAD API is slow, ClinVar card waits even though its data arrived
**Why it happens:** Convenience of single loading flag; not understanding user requirement for independent loading (COMPOSE-02)
**How to avoid:** Composable returns separate state objects per source (`gnomad.loading`, `clinvar.loading`)
**Warning signs:** Cards appear/disappear together, no partial data display when one source fails
**Prevention strategy:**
```typescript
// WRONG: Single loading state
const loading = ref(true)
const data = ref(null)

// RIGHT: Per-source state objects
const gnomad = { loading: ref(true), error: ref(null), data: ref(null) }
const clinvar = { loading: ref(true), error: ref(null), data: ref(null) }

// In template:
// <GeneConstraintCard :loading="gnomad.loading.value" :error="gnomad.error.value" />
// <GeneClinVarCard :loading="clinvar.loading.value" :error="clinvar.error.value" />
```

### Pitfall 2: Missing Null Checks in Table Rendering
**What goes wrong:** Runtime errors "Cannot read property 'pLI' of null" when constraint data is missing fields (non-coding genes, gnomAD API doesn't return all metrics)
**Why it happens:** Assuming all gnomAD constraint fields are always present; some genes lack certain metrics
**How to avoid:** Null-safe formatting functions, display "N/A" for missing values
**Warning signs:** Console errors on certain genes, white screen of death for non-coding genes
**Prevention strategy:**
```typescript
// WRONG: Direct property access
<span>{{ data.pLI.toFixed(2) }}</span>

// RIGHT: Null-safe formatting
function formatNumber(value: number | null, decimals: number): string {
  if (value === null || value === undefined) return 'N/A'
  return value.toFixed(decimals)
}

// Usage: {{ formatNumber(data?.pLI, 2) }}
```

### Pitfall 3: Hardcoded Color Thresholds Incompatible with gnomAD v4
**What goes wrong:** Using gnomAD v2 thresholds (LOEUF < 0.35) to highlight constrained genes; gnomAD v4 uses LOEUF < 0.6 (per research: threshold shifted due to larger sample size)
**Why it happens:** Outdated knowledge from training data; not checking gnomAD v4 release notes
**How to avoid:** Use gnomAD v4 guideline: LOEUF < 0.6 for "highly constrained" highlighting
**Warning signs:** Too few genes highlighted as constrained, literature says gene is constrained but no highlighting
**Prevention strategy:**
```typescript
// WRONG: gnomAD v2 threshold
if (oe_upper < 0.35) {
  return 'highly-constrained'
}

// RIGHT: gnomAD v4 threshold (per GNOMAD-05 requirement)
if (oe_upper < 0.6) {
  return '#ffc107' // Amber highlight for LOEUF < 0.6
}
```

### Pitfall 4: Inaccessible Visual-Only Constraint Bars
**What goes wrong:** Screen reader users hear "constraint metrics" but get no numeric values, only visual SVG bars
**Why it happens:** Forgetting aria-label on SVG visualizations; assuming visual representation is enough
**How to avoid:** Add aria-label with numeric values to SVG elements (per A11Y-02 requirement)
**Warning signs:** Screen reader testing reveals no numeric values announced for gauges/bars
**Prevention strategy:**
```vue
<!-- WRONG: SVG without accessibility -->
<svg width="100" height="12">
  <rect :width="scaleOE(oe_upper)" fill="gray" />
</svg>

<!-- RIGHT: SVG with ARIA label -->
<svg
  width="100"
  height="12"
  role="img"
  :aria-label="`Observed/expected ratio: ${oe}, confidence interval ${oe_lower} to ${oe_upper}`"
>
  <rect :width="scaleOE(oe_upper)" fill="gray" />
</svg>
```

### Pitfall 5: Bootstrap Badge Variant Doesn't Match ACMG Yellow
**What goes wrong:** Using Bootstrap `secondary` variant for VUS (Uncertain Significance) produces gray badge instead of yellow (per CLINVAR-02 requirement: "VUS=yellow")
**Why it happens:** Bootstrap doesn't have built-in yellow variant; `secondary` is gray, `warning` is orange
**How to avoid:** Use `warning` variant for VUS or custom CSS to override background color
**Warning signs:** VUS badges appear gray instead of yellow in visual review
**Prevention strategy:**
```vue
<!-- Option A: Use warning variant (orange/amber, closest to yellow) -->
<BBadge variant="warning">VUS (23)</BBadge>

<!-- Option B: Custom CSS override -->
<BBadge variant="secondary" class="vus-badge">VUS (23)</BBadge>

<style scoped>
.vus-badge {
  background-color: #ffc107 !important; /* Bootstrap warning color - amber/yellow */
  color: #000 !important;
}
</style>
```

### Pitfall 6: Card Height Inconsistency When Loading/Error
**What goes wrong:** Cards resize dramatically when switching between loading spinner (50px) and full table (200px), causing layout shift
**Why it happens:** Not setting min-height on card body; spinner is much smaller than content
**How to avoid:** Set min-height on card or use skeleton loader matching content size
**Warning signs:** Cumulative Layout Shift (CLS) issues, cards jumping during loading
**Prevention strategy:**
```vue
<!-- Option A: Min-height on card -->
<BCard class="constraint-card" style="min-height: 300px">
  <!-- Content -->
</BCard>

<!-- Option B: Skeleton loader with content dimensions -->
<div v-if="loading" style="height: 250px; display: flex; align-items: center; justify-content: center;">
  <BSpinner />
</div>
```

## Code Examples

Verified patterns from official sources and existing codebase:

### Composable Integration in GeneView Component
```vue
<!-- Source: Adapted from existing GeneView.vue + useAsyncJob.ts pattern -->
<!-- app/src/views/pages/GeneView.vue -->

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useGeneExternalData } from '@/composables/useGeneExternalData'
import GeneConstraintCard from '@/components/gene/GeneConstraintCard.vue'
import GeneClinVarCard from '@/components/gene/GeneClinVarCard.vue'

const route = useRoute()
const geneSymbol = ref(route.params.symbol as string)

// Composable provides per-source state objects
const { gnomad, clinvar, fetchData, retry } = useGeneExternalData(geneSymbol)

onMounted(() => {
  fetchData()
})
</script>

<template>
  <BContainer>
    <!-- Existing gene info card -->

    <!-- External data cards grid -->
    <BRow class="mt-3">
      <BCol md="6">
        <GeneConstraintCard
          :gene-symbol="geneSymbol"
          :loading="gnomad.loading.value"
          :error="gnomad.error.value"
          :data="gnomad.data.value"
          @retry="retry"
        />
      </BCol>

      <BCol md="6">
        <GeneClinVarCard
          :gene-symbol="geneSymbol"
          :loading="clinvar.loading.value"
          :error="clinvar.error.value"
          :data="clinvar.data.value"
          @retry="retry"
        />
      </BCol>
    </BRow>
  </BContainer>
</template>
```

### TypeScript Interfaces for External API Data
```typescript
// Source: gnomAD GraphQL API schema + existing types pattern
// app/src/types/external.ts

export interface GnomADConstraints {
  // pLI and LOEUF
  pLI: number | null
  oe_lof: number | null
  oe_lof_lower: number | null
  oe_lof_upper: number | null

  // Missense constraint
  oe_mis: number | null
  oe_mis_lower: number | null
  oe_mis_upper: number | null
  mis_z: number | null

  // Synonymous constraint
  oe_syn: number | null
  oe_syn_lower: number | null
  oe_syn_upper: number | null
  syn_z: number | null

  // Expected and observed counts
  exp_lof: number | null
  obs_lof: number | null
  exp_mis: number | null
  obs_mis: number | null
  exp_syn: number | null
  obs_syn: number | null

  // Z-scores
  lof_z: number | null
}

export interface ClinVarVariant {
  clinical_significance: string
  clinvar_variation_id: string
  gold_stars: number
  hgvsc: string
  hgvsp: string
  in_gnomad: boolean
  major_consequence: string
  pos: number
  review_status: string
  variant_id: string
}

export interface ExternalDataResponse {
  gene_symbol: string
  sources: {
    gnomad?: {
      source: string
      gene_symbol: string
      gene_id: string
      constraints: GnomADConstraints
    }
    gnomad_clinvar?: {
      source: string
      gene_symbol: string
      gene_id: string
      variants: ClinVarVariant[]
      variant_count: number
    }
  }
  errors: {
    [source: string]: {
      type: string
      title: string
      status: number
      detail: string
      source: string
    }
  }
}
```

### Retry Button Component Pattern
```vue
<!-- Source: Existing error handling pattern from useAsyncJob.ts + user requirements -->

<template>
  <div class="error-state text-center py-4">
    <i class="bi bi-exclamation-triangle text-warning mb-2" style="font-size: 2rem;" />
    <p class="text-muted mb-3">{{ errorMessage }}</p>
    <BButton
      variant="outline-primary"
      size="sm"
      @click="handleRetry"
      :disabled="retrying"
    >
      <BSpinner v-if="retrying" small class="me-1" />
      <i v-else class="bi bi-arrow-clockwise me-1" />
      Retry
    </BButton>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

interface Props {
  errorMessage: string
}

defineProps<Props>()

const emit = defineEmits<{
  retry: []
}>()

const retrying = ref(false)

async function handleRetry() {
  retrying.value = true
  emit('retry')
  // Reset after a delay (parent composable will update loading state)
  setTimeout(() => {
    retrying.value = false
  }, 1000)
}
</script>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Options API data() | Composition API composables | Vue 3 release (2020) | Reusable stateful logic, better TypeScript support, per-source state isolation |
| Bootstrap-Vue (Vue 2) | Bootstrap-Vue-Next (Vue 3) | 2023+ | Vue 3 compatibility, Composition API integration, TypeScript support |
| D3.js for all charts | Pure CSS/SVG for simple visualizations | Modern CSS capabilities (2020+) | Smaller bundle size, no D3 learning curve for simple bars, better performance |
| Manual ARIA attributes | Semantic HTML + ARIA labels | WCAG 2.1 (2018) | Screen reader compatibility, role="img" for SVG visualizations |
| gnomAD v2 thresholds | gnomAD v4 thresholds | gnomAD v4 release (March 2024) | LOEUF < 0.6 (was < 0.35), pLI >= 0.9 unchanged, reflects 6x larger sample size |

**Deprecated/outdated:**
- **gnomAD v2 constraint thresholds**: Use v4 guidelines (LOEUF < 0.6, not < 0.35)
- **Single composable loading state**: Use per-source state objects for independent card loading
- **D3.js for confidence interval bars**: User decision to use pure CSS/SVG
- **Interpretation text in constraint display**: User decision to show only numbers, researchers interpret

## gnomAD v4 Constraint Score Guidelines

Research findings on official gnomAD v4 interpretation thresholds:

| Metric | Threshold | Interpretation | Source |
|--------|-----------|----------------|--------|
| pLI | >= 0.9 | Likely haploinsufficient / LoF intolerant | gnomAD v4.0 documentation (unchanged from v2) |
| LOEUF | < 0.6 | Highly constrained against LoF | gnomAD v4.0 release notes (changed from v2's < 0.35) |
| Missense Z | >= 3.09 | Extremely intolerant (p < 0.001) | Statistical significance threshold |
| Missense Z | >= 2 | Intolerant | Standard deviation threshold |

**Key changes in v4:**
- LOEUF threshold relaxed from < 0.35 to < 0.6 due to distribution shift with 6x larger sample size (730,947 exomes vs 125,748 in v2)
- pLI threshold unchanged (>= 0.9 for "LoF constrained")
- v4 metrics still experimental (beta stage); v2.1.1 metrics remain established version

**User requirement alignment:**
- GNOMAD-05: "Constraint thresholds use gnomAD v4 guidelines (pLI >= 0.9, LOEUF < 0.6)" - matches research findings

## ACMG Pathogenicity Color Mapping

Standard color scheme for ClinVar clinical significance display:

| Classification | Bootstrap Variant | Color | ACMG Tier | User Requirement |
|----------------|------------------|-------|-----------|------------------|
| Pathogenic | `danger` | Red | 1 | CLINVAR-02 specifies red |
| Likely Pathogenic | `warning` | Orange/Amber | 2 | CLINVAR-02 specifies orange |
| VUS | `warning` (or custom) | Yellow | 3 | CLINVAR-02 specifies yellow (need CSS override) |
| Likely Benign | `success` | Light Green | 4 | CLINVAR-02 specifies light green |
| Benign | `success` | Green | 5 | CLINVAR-02 specifies green |

**Implementation notes:**
- Bootstrap-Vue-Next doesn't have distinct yellow variant (secondary is gray)
- Use `warning` variant (orange/amber) for VUS or custom CSS override for true yellow
- All badges must include text + count for accessibility (not color-only signaling)

## Accessibility Implementation Checklist

Requirements from A11Y-01 and A11Y-02:

| Element | ARIA Attribute | Purpose | Implementation |
|---------|---------------|---------|----------------|
| Constraint card | `role="region"` | Landmark for navigation | Apply to card wrapper |
| Loading spinner | `role="status"` | Announce loading state | BSpinner has built-in |
| SVG confidence interval bar | `role="img"` + `aria-label` | Describe numeric values | Include o/e ratio and CI bounds in label |
| ClinVar badges | `aria-label` | Announce category and count | "Pathogenic: 15 variants" (not just visual color) |
| Error message | `role="alert"` | Announce errors immediately | Apply to error div |
| Retry button | Clear button text | Screen reader action | "Retry" text, not just icon |

**Example ARIA labels:**
- Confidence interval bar: `aria-label="Observed/expected ratio: 0.45, confidence interval 0.32 to 0.68"`
- ClinVar badge: `aria-label="Pathogenic: 15 variants"`
- Card header: `aria-label="Gene constraint scores from gnomAD"`

## Open Questions

Things that couldn't be fully resolved:

1. **Exact Bootstrap-Vue-Next BSpinner props**
   - What we know: BSpinner component exists in 0.42.0, provides loading indicator
   - What's unclear: Exact prop names for size/label (documentation limited for latest version)
   - Recommendation: Use `<BSpinner label="Loading..." />` pattern from existing codebase, verify props in component testing
   - Action: Check Bootstrap-Vue-Next source or test locally

2. **Custom CSS for VUS yellow vs warning variant**
   - What we know: Bootstrap `warning` is orange/amber, user wants yellow for VUS
   - What's unclear: Whether orange/amber is acceptable as "yellow" or if custom CSS override is required
   - Recommendation: Start with `warning` variant (orange), add custom CSS override if user feedback requests true yellow
   - Action: User acceptance testing for color scheme

3. **Non-coding genes without constraint data**
   - What we know: Some genes (non-coding) don't have gnomAD constraint metrics
   - What's unclear: Exact message to display (user said "No constraint data available for this gene")
   - Recommendation: Use info-level message with icon, not error state (expected for non-coding genes)
   - Action: Verify UX for non-coding gene display with stakeholder

4. **Confidence interval SVG dimensions for responsive design**
   - What we know: User wants "small horizontal o/e confidence interval bars"
   - What's unclear: Exact pixel dimensions, responsive behavior on mobile
   - Recommendation: 100px width × 12px height for desktop, test on mobile (may need viewBox for scaling)
   - Action: Responsive testing and potential media query adjustments

5. **Card border and shadow styling**
   - What we know: User said "Claude's discretion" for "Card border, shadow, and spacing"
   - What's unclear: Whether to match existing card styling in project or use Bootstrap defaults
   - Recommendation: Use `border-variant="secondary"` for subtle border, no custom shadow (Bootstrap default)
   - Action: Verify with existing card patterns in project (check other BCard usage)

## Sources

### Primary (HIGH confidence)
- [Vue 3 Composables Official Documentation](https://vuejs.org/guide/reusability/composables) - Composable pattern for data fetching with loading/error states
- [gnomAD v4.0 Gene Constraint Release Notes](https://gnomad.broadinstitute.org/news/2024-03-gnomad-v4-0-gene-constraint/) - LOEUF < 0.6 threshold for v4
- kidney-genetics-db project: `frontend/src/components/gene/GeneConstraints.vue` - Real-world Vue 3 gnomAD constraint display
- kidney-genetics-db project: `frontend/src/components/gene/ClinVarVariants.vue` - Real-world Vue 3 ClinVar badge row
- Existing codebase: `api/functions/external-proxy-gnomad.R` - Backend data structure for constraints and ClinVar
- Existing codebase: `app/src/composables/useAsyncJob.ts` - Composable pattern with per-state reactivity
- Phase 40 RESEARCH.md - Backend architecture, per-source error isolation, httr2 retry patterns

### Secondary (MEDIUM confidence)
- [Good Practices for Vue Composables (DEV Community)](https://dev.to/jacobandrewsky/good-practices-and-design-patterns-for-vue-composables-24lk) - Single responsibility principle for composables
- [W3C SVG Accessibility ARIA Roles for Charts](https://www.w3.org/wiki/SVG_Accessibility/ARIA_roles_for_charts) - ARIA labels for SVG visualizations
- [CSS-Tricks: How to Make Charts with SVG](https://css-tricks.com/how-to-make-charts-with-svg/) - Pure CSS/SVG bar chart techniques
- [Accessible Charts with ARIA (Tenon.io)](https://blog.tenon.io/accessible-charts-with-aria/) - Screen reader best practices for data visualizations
- [gnomAD Constraint Help Documentation](https://gnomad.broadinstitute.org/help/constraint) - Constraint metric definitions
- [ACMG/AMP Variant Interpretation Guidelines (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4544753/) - 5-tier pathogenicity classification system

### Tertiary (LOW confidence - flagged for validation)
- [Bootstrap-Vue-Next GitHub Repository](https://github.com/bootstrap-vue-next/bootstrap-vue-next) - BSpinner, BCard, BBadge component props (documentation incomplete for 0.42.0)
- WebSearch results for ACMG color scheme - No official standard found, community conventions vary
- WebSearch results for confidence interval visualization techniques - General patterns, not Vue-specific

## Metadata

**Confidence breakdown:**
- Vue 3 composable pattern: HIGH - Official Vue documentation + existing codebase usage validates approach
- gnomAD v4 thresholds: HIGH - Official gnomAD release notes specify LOEUF < 0.6, pLI >= 0.9
- Bootstrap-Vue-Next integration: MEDIUM-HIGH - Library in project, but 0.42.0 documentation incomplete for some props
- ACMG color mapping: MEDIUM - User requirements specify colors, no official ACMG color standard found
- CSS/SVG confidence interval bars: HIGH - User decision to avoid D3.js, CSS/SVG techniques well-documented
- Accessibility patterns: HIGH - W3C ARIA guidelines, WCAG 2.1 standards, kidney-genetics-db implementation reference

**Research date:** 2026-01-27
**Valid until:** 2026-02-27 (30 days - Vue 3 and Bootstrap stable, gnomAD v4 thresholds current, accessibility standards unchanged)

**Validation recommendations:**
1. Test Bootstrap-Vue-Next BSpinner props in local environment (label, size attributes)
2. User acceptance testing for ACMG color scheme (verify orange is acceptable for "yellow" VUS)
3. Screen reader testing for ARIA labels on SVG confidence interval bars
4. Responsive design testing for card layout on mobile (column stacking behavior)
5. Non-coding gene handling (verify "no data" message UX with stakeholder)
