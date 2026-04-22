# Phase 46: Model Organism Phenotypes & Final Integration - Research

**Researched:** 2026-01-28
**Domain:** Vue 3 Frontend Components, Backend Proxy Layer, WCAG 2.2 AA Accessibility
**Confidence:** HIGH (existing patterns established, backend infrastructure ready)

## Summary

Phase 46 involves creating a combined Model Organisms card displaying MGI (mouse) and RGD (rat) phenotype data, plus comprehensive accessibility validation for WCAG 2.2 AA compliance across all v8.0 features.

The backend proxy infrastructure for MGI and RGD is already implemented in Phase 40 (`external-proxy-mgi.R` and `external-proxy-rgd.R`), with working endpoints at `/api/external/mgi/phenotypes/<symbol>` and `/api/external/rgd/phenotypes/<symbol>`. The frontend needs to consume these endpoints and render phenotype data in a combined card with two-column layout (mouse left, rat right).

The MGI API returns `phenotype_count` and a list of `phenotypes` with zygosity information when available. The RGD API returns `phenotype_count` only (no zygosity breakdown per CONTEXT.md decision). The card should display colored chips for MGI zygosity breakdown following Bootstrap-Vue-Next patterns already established in GeneClinVarCard.vue.

**Primary recommendation:** Create a new `ModelOrganismsCard.vue` component following the established card pattern (BCard with loading/error/data states), with a two-column layout using Bootstrap grid, and BBadge-based chips for phenotype counts and MGI zygosity breakdown.

## Standard Stack

The established libraries/tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Frontend framework | Already in use, Composition API with script setup |
| Bootstrap-Vue-Next | 0.42.0 | UI components (BCard, BBadge, BSpinner) | Already in use throughout gene page |
| Bootstrap Icons | 1.13.1 | Icons for UI elements | Already in use (bi-* prefix) |
| axios | 1.13.2 | HTTP requests to backend | Already in use for external data fetching |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vitest-axe | 0.1.0 | Automated accessibility testing | Unit tests for a11y compliance |
| @vueuse/core | 14.1.0 | Vue composition utilities | toRef pattern for props |

### Backend (Already Implemented)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| httr2 | (in api) | HTTP requests to MGI/RGD | Implemented in Phase 40 |
| memoise + cachem | (in api) | 14-day cache for phenotype data | Implemented in Phase 40 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| BBadge | Custom chip component | BBadge already used in GeneClinVarCard, consistent with project |
| Two-column flex | CSS Grid | Bootstrap grid more familiar, already used in other cards |

**Installation:**
No new packages required - all dependencies already in project.

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── components/
│   └── gene/
│       ├── ModelOrganismsCard.vue     # New: Combined MGI + RGD card
│       ├── GeneClinVarCard.vue        # Existing: Pattern to follow
│       └── GeneConstraintCard.vue     # Existing: Pattern to follow
├── composables/
│   └── useModelOrganismData.ts        # New: Composable for MGI + RGD data
└── types/
    └── external.ts                     # Extend with MGI/RGD response types
```

### Pattern 1: Card Component with Loading/Error/Data States
**What:** Consistent card component structure with three state handling
**When to use:** All external data cards
**Example:**
```typescript
// Source: GeneClinVarCard.vue (existing pattern)
<BCard
  class="card-class"
  body-class="p-0"
  header-class="p-1"
  border-variant="dark"
  role="region"
  aria-label="Descriptive label for screen readers"
>
  <template #header>
    <div class="d-flex justify-content-between align-items-center">
      <span class="fw-semibold small">Card Title</span>
      <BButton variant="link" size="sm" :href="externalUrl" target="_blank">
        <i class="bi bi-box-arrow-up-right" />
      </BButton>
    </div>
  </template>

  <!-- Loading State -->
  <div v-if="loading" class="text-center py-3">
    <BSpinner label="Loading..." role="status" small />
  </div>

  <!-- Error State -->
  <div v-else-if="error" class="text-center py-3" role="alert">
    <p class="text-muted mb-2 small">{{ error }}</p>
    <BButton variant="outline-primary" size="sm" @click="$emit('retry')">
      Retry
    </BButton>
  </div>

  <!-- Empty State -->
  <div v-else-if="isEmpty" class="text-center py-3">
    <i class="bi bi-info-circle text-muted me-2" />
    <span class="text-muted small">No data available</span>
  </div>

  <!-- Data State -->
  <div v-else class="data-content">
    <!-- Actual data rendering -->
  </div>
</BCard>
```

### Pattern 2: Two-Column Layout with Bootstrap Grid
**What:** Side-by-side sections for mouse and rat data
**When to use:** Combined organism card
**Example:**
```vue
<BRow class="g-0">
  <!-- Mouse (MGI) Column -->
  <BCol cols="12" md="6" class="border-end-md">
    <div class="p-2">
      <h6 class="mb-2 small fw-semibold">
        <i class="bi bi-mouse" /> Mouse (MGI)
      </h6>
      <!-- Mouse phenotype content -->
    </div>
  </BCol>

  <!-- Rat (RGD) Column -->
  <BCol cols="12" md="6">
    <div class="p-2">
      <h6 class="mb-2 small fw-semibold">
        <i class="bi bi-database" /> Rat (RGD)
      </h6>
      <!-- Rat phenotype content -->
    </div>
  </BCol>
</BRow>
```

### Pattern 3: Colored Chips with Text Labels (A11Y Compliant)
**What:** BBadge components with color AND text for accessibility
**When to use:** Zygosity breakdown, phenotype counts
**Example:**
```vue
<!-- Source: GeneClinVarCard.vue pattern, adapted for zygosity -->
<div class="d-flex flex-wrap gap-2">
  <!-- Total count chip -->
  <BBadge
    variant="primary"
    class="py-2 px-3"
    :aria-label="`${totalCount} phenotypes total`"
  >
    <strong>{{ totalCount }}</strong> phenotypes
  </BBadge>

  <!-- Zygosity breakdown chips (MGI only) -->
  <BBadge
    v-if="homozygousCount > 0"
    variant="danger"
    class="py-1 px-2"
    :aria-label="`${homozygousCount} homozygous phenotypes`"
  >
    <strong>hm</strong> ({{ homozygousCount }})
  </BBadge>

  <BBadge
    v-if="heterozygousCount > 0"
    class="badge-warning-custom py-1 px-2"
    :aria-label="`${heterozygousCount} heterozygous phenotypes`"
  >
    <strong>ht</strong> ({{ heterozygousCount }})
  </BBadge>
</div>
```

### Pattern 4: Per-Source State Isolation
**What:** Independent loading/error/data refs for each data source
**When to use:** When fetching from multiple external APIs in parallel
**Example:**
```typescript
// Source: useGeneExternalData.ts pattern
export interface UseModelOrganismDataReturn {
  mgi: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<MGIPhenotypeData | null>;
  };
  rgd: {
    loading: Ref<boolean>;
    error: Ref<string | null>;
    data: Ref<RGDPhenotypeData | null>;
  };
  fetchData: () => Promise<void>;
  retry: () => Promise<void>;
}
```

### Anti-Patterns to Avoid
- **Color-only indicators:** Never use color alone to convey information (WCAG 1.4.1)
- **Missing ARIA labels:** All interactive/informative elements need aria-labels for screen readers
- **Shared error state:** Don't use single error state for multiple sources - isolate per source
- **Hard-coded URLs:** Use computed properties with gene symbol interpolation

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phenotype chips | Custom styled divs | BBadge with variant | Bootstrap accessibility built-in |
| Card layout | Manual CSS flexbox | BCard + BRow/BCol | Consistent with other cards |
| Loading spinners | Custom CSS animation | BSpinner with role="status" | Screen reader accessible |
| External links | Plain anchor tags | BButton with variant="link" | Accessible, keyboard-focusable |
| Error handling | if/else chains | v-if/v-else-if cascade | Vue template pattern |

**Key insight:** Bootstrap-Vue-Next components include built-in accessibility features (ARIA attributes, keyboard handling) that would need to be manually implemented with custom components.

## Common Pitfalls

### Pitfall 1: Color-Only Information (WCAG 1.4.1 Violation)
**What goes wrong:** Using only color to distinguish zygosity types (e.g., red for homozygous, yellow for heterozygous) without text
**Why it happens:** Visual design focuses on quick color recognition
**How to avoid:**
- Always include text labels with colors: "hm" for homozygous, "ht" for heterozygous
- Provide aria-labels with full descriptions
- Use patterns or icons in addition to color where possible
**Warning signs:** Color-blind users cannot distinguish between categories

### Pitfall 2: Missing aria-labels on Badges/Chips
**What goes wrong:** Screen readers announce only the visible text, losing context
**Why it happens:** Abbreviations like "hm" or "ht" are meaningless without context
**How to avoid:**
- Add `:aria-label="fullDescription"` to every badge
- Example: `:aria-label="\`${count} homozygous phenotypes\`"`
**Warning signs:** Lighthouse accessibility audit warnings

### Pitfall 3: Forgetting to Hide Card When Both Sources Empty
**What goes wrong:** Card shows "No data available" messages in both columns
**Why it happens:** Each source handles empty state independently
**How to avoid:**
- Compute `hasBothEmpty` = !mgi.data && !rgd.data
- Hide entire card with v-if="!hasBothEmpty"
**Warning signs:** Empty card visible with no useful information

### Pitfall 4: Error vs Empty State Confusion
**What goes wrong:** Treating API errors the same as "no phenotype data"
**Why it happens:** Both result in null/empty data state
**How to avoid:**
- Error state: Show error icon + "Could not load data" + retry button
- Empty state: Show info icon + "No data available"
- Check `error !== null` separately from `data === null`
**Warning signs:** Users cannot distinguish temporary errors from genes without data

### Pitfall 5: Lighthouse Score Doesn't Guarantee Accessibility
**What goes wrong:** Achieving Lighthouse score 100 but still having accessibility issues
**Why it happens:** Lighthouse automated tests catch only ~30-40% of WCAG issues
**How to avoid:**
- Use Lighthouse as starting point, not final validation
- Manual keyboard navigation testing
- Screen reader testing (VoiceOver, NVDA)
- Color contrast verification
**Warning signs:** Users with disabilities report issues despite "perfect" score

### Pitfall 6: MGI API Response Format Variability
**What goes wrong:** Expecting consistent response structure from MGI
**Why it happens:** MGI API is undocumented, responses vary
**How to avoid:**
- Backend already handles this defensively (external-proxy-mgi.R)
- Frontend should handle `found: false` as "no data" not error
- Check for existence of optional fields before accessing
**Warning signs:** Undefined property errors in console

## Code Examples

Verified patterns from existing SysNDD codebase:

### BBadge with Accessibility
```vue
<!-- Source: GeneClinVarCard.vue -->
<BBadge
  v-if="counts.pathogenic > 0"
  variant="danger"
  class="py-2 px-3"
  :aria-label="`Pathogenic: ${counts.pathogenic} variants`"
>
  <strong>Pathogenic</strong> ({{ counts.pathogenic }})
</BBadge>
```

### Card with Region Role
```vue
<!-- Source: GeneConstraintCard.vue -->
<BCard
  class="constraint-card"
  body-class="p-0"
  header-class="p-1"
  border-variant="dark"
  role="region"
  aria-label="Gene constraint scores from gnomAD"
>
```

### External Link Button Pattern
```vue
<!-- Source: GeneClinVarCard.vue -->
<BButton
  variant="link"
  size="sm"
  :href="`https://www.ncbi.nlm.nih.gov/clinvar/?term=${geneSymbol}[gene]`"
  target="_blank"
  rel="noopener noreferrer"
  class="text-decoration-none p-0"
>
  <i class="bi bi-box-arrow-up-right"></i>
</BButton>
```

### Loading State with Accessible Spinner
```vue
<!-- Source: GeneClinVarCard.vue -->
<div v-if="loading" class="text-center py-3">
  <BSpinner label="Loading ClinVar data..." role="status" small />
</div>
```

### Error State with Alert Role
```vue
<!-- Source: GeneClinVarCard.vue -->
<div v-else-if="error" class="text-center py-3" role="alert">
  <p class="text-muted mb-2 small">{{ error }}</p>
  <BButton variant="outline-primary" size="sm" @click="$emit('retry')">
    Retry
  </BButton>
</div>
```

### Backend Endpoint Pattern (Already Implemented)
```r
# Source: api/endpoints/external_endpoints.R
#* @get mgi/phenotypes/<symbol>
function(symbol, res) {
  # Validate input
  if (!validate_gene_symbol(symbol)) {
    res$status <- 400L
    res$setHeader("Content-Type", "application/problem+json")
    return(create_external_error("mgi", ...))
  }

  # Fetch data (memoised with 14-day cache)
  result <- fetch_mgi_phenotypes_mem(symbol)

  # Handle not found (gene has no phenotypes - not error)
  if (is.list(result) && isTRUE(result$found == FALSE)) {
    res$status <- 404L
    ...
  }

  # Success
  return(result)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Color-only indicators | Color + text labels | WCAG 2.2 (Oct 2023) | Required for AA compliance |
| Lighthouse as final test | Lighthouse + manual testing | Ongoing | 30-40% coverage only |
| Single error state | Per-source error isolation | Phase 40 | Better partial success handling |

**Deprecated/outdated:**
- Using `color` attribute alone for meaning - always supplement with text (WCAG 1.4.1)
- Relying solely on automated accessibility testing - manual validation required

## API Response Structures

### MGI Phenotype Response (Backend)
```json
{
  "source": "mgi",
  "gene_symbol": "SCN1A",
  "mgi_id": "MGI:98246",
  "mouse_symbol": "Scn1a",
  "marker_name": "sodium channel, voltage-gated, type I, alpha",
  "phenotype_count": 37,
  "phenotypes": [
    {
      "phenotype_id": "MP:0000001",
      "term": "lethal",
      "zygosity": "homozygous"
    }
  ],
  "mgi_url": "https://www.informatics.jax.org/marker/MGI:98246"
}
```

### RGD Phenotype Response (Backend)
```json
{
  "source": "rgd",
  "gene_symbol": "SCN1A",
  "rgd_id": "621676",
  "rat_symbol": "Scn1a",
  "rat_name": "sodium voltage-gated channel alpha subunit 1",
  "phenotype_count": 12,
  "phenotypes": [
    {
      "term": "seizures",
      "annotation_type": "phenotype"
    }
  ],
  "rgd_url": "https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=621676"
}
```

### TypeScript Interfaces (Frontend)
```typescript
// Types to add to types/external.ts
export interface MGIPhenotypeData {
  source: 'mgi';
  gene_symbol: string;
  mgi_id: string;
  mouse_symbol: string;
  marker_name: string;
  phenotype_count: number;
  phenotypes: Array<{
    phenotype_id?: string;
    term?: string;
    zygosity?: 'homozygous' | 'heterozygous' | 'conditional' | string;
  }>;
  mgi_url: string;
}

export interface RGDPhenotypeData {
  source: 'rgd';
  gene_symbol: string;
  rgd_id: string;
  rat_symbol: string;
  rat_name: string;
  phenotype_count: number;
  phenotypes: Array<{
    term?: string;
    annotation_type?: string;
  }>;
  rgd_url: string;
}
```

## WCAG 2.2 AA Compliance Checklist

For Phase 46 accessibility validation:

### 1.4.1 Use of Color (Level A)
- [ ] Color not sole indicator of meaning
- [ ] Text labels accompany all colored elements
- [ ] ACMG badges have text (Pathogenic, Likely Pathogenic, etc.)
- [ ] Zygosity chips have text (hm, ht, cn)

### 1.4.3 Contrast (Minimum) (Level AA)
- [ ] Text contrast ratio >= 4.5:1 for normal text
- [ ] Large text contrast ratio >= 3:1
- [ ] UI component contrast ratio >= 3:1

### 1.4.11 Non-text Contrast (Level AA)
- [ ] UI component boundaries contrast >= 3:1
- [ ] Focus indicators visible

### 2.1.1 Keyboard (Level A)
- [ ] All interactive elements keyboard accessible
- [ ] Tab order logical
- [ ] No keyboard traps

### 2.4.7 Focus Visible (Level AA)
- [ ] Focus indicator visible on all interactive elements
- [ ] Focus not obscured by other content

### 4.1.2 Name, Role, Value (Level A)
- [ ] All elements have accessible names (aria-label)
- [ ] Interactive elements have appropriate roles
- [ ] State changes announced (aria-live regions)

## Open Questions

Things that couldn't be fully resolved:

1. **MGI Zygosity Data Availability**
   - What we know: Backend attempts to extract zygosity from phenotype annotations
   - What's unclear: Whether all MGI phenotypes have zygosity data
   - Recommendation: Handle missing zygosity gracefully (show total count only)

2. **Kidney-genetics-db MousePhenotypes Pattern**
   - What we know: CONTEXT.md references this pattern
   - What's unclear: Could not find the specific repository/component
   - Recommendation: Follow GeneClinVarCard.vue pattern instead (BBadge-based chips)

3. **Lighthouse MCP Tool**
   - What we know: Available for accessibility verification per CONTEXT.md
   - What's unclear: Exact usage and integration
   - Recommendation: Use standard Lighthouse in Chrome DevTools, supplement with vitest-axe

## Sources

### Primary (HIGH confidence)
- SysNDD codebase analysis: `api/functions/external-proxy-mgi.R` - MGI proxy implementation
- SysNDD codebase analysis: `api/functions/external-proxy-rgd.R` - RGD proxy implementation
- SysNDD codebase analysis: `api/endpoints/external_endpoints.R` - Endpoint definitions
- SysNDD codebase analysis: `app/src/components/gene/GeneClinVarCard.vue` - Card pattern
- SysNDD codebase analysis: `app/src/types/protein.ts` - PATHOGENICITY_COLORS constant

### Secondary (MEDIUM confidence)
- [WCAG 2.2 accessiBe Guide](https://accessibe.com/blog/knowledgebase/wcag-two-point-two) - WCAG 2.2 requirements
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) - Contrast ratio tool
- [Section508.gov Color Usage](https://www.section508.gov/create/making-color-usage-accessible/) - Color accessibility guidelines
- [Lighthouse Accessibility Scoring](https://developer.chrome.com/docs/lighthouse/accessibility/scoring) - Lighthouse limitations

### Tertiary (LOW confidence)
- [MGI Mouse Genome Informatics](https://www.informatics.jax.org/) - MGI documentation (API not well documented)
- [RGD Rat Genome Database](https://rgd.mcw.edu/) - RGD REST API (swagger unavailable)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in project
- Architecture patterns: HIGH - Patterns established in existing gene page cards
- Backend infrastructure: HIGH - Already implemented and tested in Phase 40
- Accessibility requirements: MEDIUM - WCAG 2.2 documented, but Lighthouse limitations noted
- MGI/RGD API responses: MEDIUM - Backend implementation exists but APIs are undocumented

**Research date:** 2026-01-28
**Valid until:** 2026-02-28 (30 days - stable patterns)
