# Genes Detail UI/UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `/Genes/:symbol` detail-page overflow, missing-data visibility, layout stability, and page-scoped accessibility issues for `/Genes/ARID1B` and `/Genes/NAA10`.

**Architecture:** Keep `GeneView.vue` as the page orchestrator and keep per-source SWR composables unchanged. Source-specific empty states live inside the source cards so card headers and outbound links remain visible; `SectionCard` remains a generic skeleton/error wrapper.

**Tech Stack:** Vue 3 + TypeScript, Bootstrap Vue Next, Vite, Vitest + Vue Test Utils + MSW, Playwright + `@axe-core/playwright`, Lighthouse, local dev stack via `make dev`.

---

## Source Spec

Implement `.planning/superpowers/specs/2026-05-09-genes-detail-ui-ux-fixes-design.md`.

Do not modify API endpoints, DB migrations, SWR composables, `cacheStore`, or `TablesEntities` request timing.

## File Map

- Modify: `app/src/views/pages/GeneView.vue`  
  Changes external-card grid breakpoints, keeps external source cards mounted on no-data responses, adds page `h1`, and improves header metadata contrast hook/class.
- Modify: `app/src/views/pages/__tests__/GeneView.spec.ts`  
  Adds NAA10-style missing gnomAD test and breakpoint assertions.
- Modify: `app/src/components/gene/GeneConstraintCard.vue`  
  Replaces the overflow-prone table with responsive metric rows/blocks, preserves the gnomAD header link in no-data state, and fixes SVG accessibility.
- Create: `app/src/components/gene/GeneConstraintCard.spec.ts`  
  Unit tests constraint parsing, no-data state, outbound link persistence, and responsive markup hooks.
- Modify: `app/src/components/gene/GeneClinVarCard.vue`  
  Ensures zero-count/empty state copy matches the page design and remains visibly distinct from loaded data.
- Modify: `app/src/components/gene/ModelOrganismsCard.vue`  
  Ensures combined no-data state copy matches the page design, remains visibly distinct from errors, and fixes phenotype badge accessible names.
- Modify: `app/src/components/ui/SectionCard.vue`  
  Removes heading-level semantics from generic card-wrapper title fallbacks so loading/error/loaded states do not create heading skips. Existing collapse behavior remains.
- Modify: `app/src/components/ui/__tests__/SectionCard.spec.ts`  
  Pins collapse behavior and state-invariant non-heading title rendering.
- Modify: `app/src/components/gene/ClinicalResourcesCard.vue`  
  Raises compact resource label contrast.
- Modify: `app/src/components/gene/IdentifierCard.vue`  
  Raises compact identifier label contrast.
- Modify: `app/src/components/gene/GenomicVisualizationTabs.vue`  
  Uses `h2` for the major page section heading.
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue` and `app/src/composables/useD3GeneStructure.ts`  
  Removes prohibited ARIA from raw SVG shapes in the gene-structure path.
- Modify: `app/src/components/AppNavbar.vue`  
  Uses literal `ul.navbar-nav > li.nav-item` wrappers for navbar search so rendered list semantics are valid.
- Create: `app/tests/e2e/genes-detail-ui-ux.spec.ts`  
  Local-only viewport/a11y regression checks for ARID1B and NAA10.

## Task 1: Pin SectionCard Generic Semantics

**Files:**

- Modify: `app/src/components/ui/SectionCard.vue`
- Modify: `app/src/components/ui/__tests__/SectionCard.spec.ts`

- [ ] **Step 1: Add failing SectionCard tests**

Append to `app/src/components/ui/__tests__/SectionCard.spec.ts`:

```ts
  it('keeps collapse behavior for empty resolved sections', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: true, error: null, title: 'Collapsed' },
    });
    expect(w.text()).toBe('');
    expect(w.find('[data-testid="section-card-content"]').exists()).toBe(false);
    expect(w.find('[data-testid="section-card-error"]').exists()).toBe(false);
  });

  it('does not render generic wrapper titles as headings', () => {
    const w = mount(SectionCard, {
      props: { loading: false, empty: false, error: null, title: 'Associated Source' },
      slots: { default: '<p>loaded</p>' },
    });
    expect(w.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(w.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);
  });

  it('uses the same non-heading title pattern for loading and error states', () => {
    const loading = mount(SectionCard, {
      props: { loading: true, empty: false, error: null, title: 'Loading Source' },
    });
    expect(loading.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(loading.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);

    const error = mount(SectionCard, {
      props: { loading: false, empty: false, error: 'boom', title: 'Errored Source' },
    });
    expect(error.find('[data-testid="section-card-title"]').exists()).toBe(true);
    expect(error.find('h1,h2,h3,h4,h5,h6').exists()).toBe(false);
  });
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
cd app && npx vitest run src/components/ui/__tests__/SectionCard.spec.ts
```

Expected: heading tests fail because current fallback titles use `h6`.

- [ ] **Step 3: Replace fallback `h6` titles with non-heading text**

In `app/src/components/ui/SectionCard.vue`, replace fallback header titles in loading, error, and loaded branches with:

```vue
<div data-testid="section-card-title" class="section-card-title text-muted">
  {{ title }}
</div>
```

For the danger/error branch use:

```vue
<div data-testid="section-card-title" class="section-card-title text-danger">
  {{ title }}
</div>
```

Add scoped CSS:

```css
.section-card-title {
  font-size: 0.875rem;
  line-height: 1.2;
  font-weight: 600;
}
```

Do not add `emptyMode` props in this task. `SectionCard` continues to collapse `empty=true`.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```bash
cd app && npx vitest run src/components/ui/__tests__/SectionCard.spec.ts
```

Expected: all SectionCard tests pass.

## Task 2: Keep External Cards Mounted And Fix Grid Breakpoints

**Files:**

- Modify: `app/src/views/pages/GeneView.vue`
- Modify: `app/src/views/pages/__tests__/GeneView.spec.ts`

- [ ] **Step 1: Add failing GeneView tests without stubbing SectionCard**

In `app/src/views/pages/__tests__/GeneView.spec.ts`, keep `BCard` stubbed but do not stub `SectionCard`. Use source-card stubs that expose text:

```ts
  GeneConstraintCard: {
    props: ['geneSymbol', 'constraintsJson'],
    template: `
      <section aria-label="Gene constraint scores from gnomAD">
        <span>Gene Constraint (gnomAD)</span>
        <a :href="'https://gnomad.broadinstitute.org/gene/' + geneSymbol">View on gnomAD</a>
        <p v-if="constraintsJson === null || constraintsJson === ''">No gnomAD constraint data available for this gene.</p>
      </section>
    `,
  },
  GeneClinVarCard: {
    props: ['totalCount'],
    template: '<section><span>ClinVar Variants</span><p v-if="totalCount === 0">No ClinVar variants returned for this gene.</p></section>',
  },
  ModelOrganismsCard: {
    template: '<section><span>Model Organisms</span><slot /></section>',
  },
```

Add tests:

```ts
  it('keeps the gnomAD card mounted with link and no-data message when constraints are missing', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] }),
      ),
      http.get('*/api/gene/NAA10', () =>
        HttpResponse.json([
          {
            symbol: ['NAA10'],
            hgnc_id: ['HGNC:18704'],
            name: ['N-alpha-acetyltransferase 10'],
            gnomad_constraints: null,
          },
        ]),
      ),
      http.get('*/api/external/*/*/NAA10', () => HttpResponse.json({})),
    );

    const router = makeRouter('/Genes/NAA10');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();

    expect(w.text()).toContain('Gene Constraint (gnomAD)');
    expect(w.text()).toContain('No gnomAD constraint data available for this gene.');
    expect(w.find('a[href="https://gnomad.broadinstitute.org/gene/NAA10"]').exists()).toBe(true);
    w.unmount();
  });

  it('uses one/two/three column responsive breakpoints for external cards', async () => {
    server.use(
      http.get('*/api/entity/', () =>
        HttpResponse.json({ data: [], links: [], meta: [{ totalItems: 0 }] }),
      ),
      http.get('*/api/gene/ARID1B', () =>
        HttpResponse.json([{ symbol: ['ARID1B'], hgnc_id: ['HGNC:18040'], gnomad_constraints: '{}' }]),
      ),
      http.get('*/api/external/*/*/ARID1B', () => HttpResponse.json({})),
    );

    const router = makeRouter('/Genes/ARID1B');
    await router.isReady();
    const w = mount(GeneView, {
      global: { plugins: [router], stubs: heavyChildStubs },
    });
    await flushTablesDebounce();

    const externalCols = w.findAll('[data-testid="gene-external-card-col"]');
    expect(externalCols).toHaveLength(3);
    for (const col of externalCols) {
      expect(col.attributes('cols')).toBe('12');
      expect(col.attributes('lg')).toBe('6');
      expect(col.attributes('xxl')).toBe('4');
    }
    w.unmount();
  });
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
cd app && npx vitest run src/views/pages/__tests__/GeneView.spec.ts
```

Expected: NAA10 gnomAD test fails because current `SectionCard` collapses before `GeneConstraintCard` mounts; breakpoint test reports `md="4"`.

- [ ] **Step 3: Update GeneView markup**

In `app/src/views/pages/GeneView.vue`:

- Add one compact `h1` in the gene header:

```vue
<h1 class="gene-page-title mb-0">
  <span v-if="geneSymbol">{{ geneSymbol }}</span>
  <span v-else>Gene</span>
</h1>
```

- Keep existing gene badge/name/location nearby, but ensure there is exactly one `h1`.
- Change each external `BCol` from `cols="12" md="4" class="mb-2"` to:

```vue
<BCol cols="12" lg="6" xxl="4" class="mb-2" data-testid="gene-external-card-col">
```

- For the three external `SectionCard` instances, keep `frameless` and `min-height`, but set source no-data emptiness to `false` so the source card mounts:

```vue
:empty="false"
```

Keep `:error` behavior unchanged so true failures still render the `SectionCard` error branch.

- Add scoped styles:

```css
.gene-page-title {
  font-size: 1rem;
  line-height: 1.2;
  font-weight: 700;
}
.gene-card-location {
  font-size: 0.8rem;
  font-family: 'Courier New', monospace;
  color: #495057;
}
```

- [ ] **Step 4: Run the focused tests and confirm they pass**

Run:

```bash
cd app && npx vitest run src/views/pages/__tests__/GeneView.spec.ts
```

Expected: all GeneView tests pass.

## Task 3: Redesign GeneConstraintCard Internals Responsively

**Files:**

- Modify: `app/src/components/gene/GeneConstraintCard.vue`
- Create: `app/src/components/gene/GeneConstraintCard.spec.ts`

- [ ] **Step 1: Write failing GeneConstraintCard tests**

Create `app/src/components/gene/GeneConstraintCard.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import GeneConstraintCard from './GeneConstraintCard.vue';

const constraintsJson = JSON.stringify({
  exp_syn: 100.2,
  obs_syn: 98,
  syn_z: 0.11,
  oe_syn: 0.98,
  oe_syn_lower: 0.82,
  oe_syn_upper: 1.17,
  exp_mis: 255.5,
  obs_mis: 140,
  mis_z: 4.75,
  oe_mis: 0.55,
  oe_mis_lower: 0.47,
  oe_mis_upper: 0.65,
  exp_lof: 32.2,
  obs_lof: 3,
  lof_z: 5.9,
  oe_lof: 0.09,
  oe_lof_lower: 0.03,
  oe_lof_upper: 0.25,
  pLI: 1,
});

describe('GeneConstraintCard', () => {
  it('renders a visible no-data state and keeps the gnomAD link', () => {
    const w = mount(GeneConstraintCard, {
      props: { geneSymbol: 'NAA10', constraintsJson: null },
    });
    expect(w.text()).toContain('Gene Constraint (gnomAD)');
    expect(w.text()).toContain('No gnomAD constraint data available for this gene.');
    expect(w.find('a[href="https://gnomad.broadinstitute.org/gene/NAA10"]').exists()).toBe(true);
  });

  it('renders all three constraint categories and key metrics', () => {
    const w = mount(GeneConstraintCard, {
      props: { geneSymbol: 'ARID1B', constraintsJson },
    });
    expect(w.text()).toContain('Synonymous');
    expect(w.text()).toContain('Missense');
    expect(w.text()).toContain('pLoF');
    expect(w.text()).toContain('Expected');
    expect(w.text()).toContain('Observed');
    expect(w.text()).toContain('pLI');
  });

  it('uses responsive metric rows instead of the overflow-prone table body', () => {
    const w = mount(GeneConstraintCard, {
      props: { geneSymbol: 'ARID1B', constraintsJson },
    });
    expect(w.find('.constraint-metric-list').exists()).toBe(true);
    expect(w.findAll('.constraint-metric-row')).toHaveLength(3);
    expect(w.find('table').exists()).toBe(false);
  });

  it('uses valid SVG accessibility for CI bars', () => {
    const w = mount(GeneConstraintCard, {
      props: { geneSymbol: 'ARID1B', constraintsJson },
    });
    const svg = w.find('svg');
    expect(svg.exists()).toBe(true);
    expect(svg.attributes('role')).toBe('img');
    expect(svg.attributes('aria-label')).toContain('observed/expected ratio');
    expect(w.find('rect[aria-label]').exists()).toBe(false);
    expect(w.find('circle[aria-label]').exists()).toBe(false);
  });
});
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```bash
cd app && npx vitest run src/components/gene/GeneConstraintCard.spec.ts
```

Expected: test fails because current markup uses a table and the no-data copy differs.

- [ ] **Step 3: Implement responsive metric rows and distinct no-data body**

In `app/src/components/gene/GeneConstraintCard.vue`:

- Remove `BTable` import and `tableFields`.
- Keep the `BCard` header and gnomAD link.
- Change the no-data state to:

```vue
<div v-if="!constraintData" class="constraint-empty-state">
  <i class="bi bi-info-circle constraint-empty-state__icon" aria-hidden="true" />
  <p class="constraint-empty-state__message mb-0">
    No gnomAD constraint data available for this gene.
  </p>
</div>
```

- Replace the table with:

```vue
<div v-else class="constraint-metric-list">
  <section
    v-for="item in tableItems"
    :key="item.category"
    class="constraint-metric-row"
    :aria-label="`${item.category} constraint metrics`"
  >
    <div class="constraint-metric-row__heading">
      <strong>{{ item.category }}</strong>
      <span v-if="item.category === 'pLoF' && item.pLI !== null" class="constraint-pill">
        pLI {{ formatNumber(item.pLI, 2) }}
      </span>
    </div>
    <dl class="constraint-stats">
      <div>
        <dt>Expected</dt>
        <dd>{{ item.expected }}</dd>
      </div>
      <div>
        <dt>Observed</dt>
        <dd>{{ item.observed }}</dd>
      </div>
      <div>
        <dt>Z</dt>
        <dd>{{ formatNumber(item.z_score, 2) }}</dd>
      </div>
      <div>
        <dt>o/e</dt>
        <dd>{{ formatNumber(item.oe, 2) }}</dd>
      </div>
    </dl>
    <div class="ci-bar-container">
      <svg viewBox="0 0 100 12" preserveAspectRatio="none" role="img" :aria-label="getCIAriaLabel(item)">
        <rect x="0" y="0" width="100" height="12" fill="#e9ecef" rx="2" aria-hidden="true" />
        <rect
          :x="scaleOE(item.oe_lower)"
          y="2"
          :width="Math.max(0, scaleOE(item.oe_upper) - scaleOE(item.oe_lower))"
          height="8"
          :fill="getOEColor(item.oe_upper, item.category)"
          rx="1"
          aria-hidden="true"
        />
        <circle
          :cx="scaleOE(item.oe)"
          cy="6"
          r="3"
          :fill="getOEColor(item.oe_upper, item.category)"
          stroke="white"
          stroke-width="1"
          aria-hidden="true"
        />
      </svg>
      <span class="ci-text">
        CI {{ formatNumber(item.oe_lower, 2) }} - {{ formatNumber(item.oe_upper, 2) }}
      </span>
    </div>
  </section>
</div>
```

Add scoped CSS:

```css
.constraint-card {
  min-height: clamp(10rem, 30vw, 16rem);
}
.constraint-empty-state {
  min-height: clamp(8rem, 24vw, 13rem);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 1rem;
  text-align: center;
  color: #495057;
  background: #f8f9fa;
  border-top: 1px dashed #adb5bd;
}
.constraint-empty-state__icon {
  font-size: 1.25rem;
  color: #6c757d;
}
.constraint-empty-state__message {
  font-size: 0.875rem;
  font-style: italic;
  color: #343a40;
}
.constraint-metric-list {
  display: grid;
  gap: 0.5rem;
  padding: 0.75rem;
}
.constraint-metric-row {
  min-width: 0;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  padding: 0.65rem;
  background: #fff;
}
.constraint-metric-row__heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}
.constraint-pill {
  flex: 0 0 auto;
  border: 1px solid #dee2e6;
  border-radius: 999px;
  padding: 0.05rem 0.45rem;
  font-size: 0.75rem;
  color: #343a40;
  background: #f8f9fa;
}
.constraint-stats {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.35rem 0.75rem;
  margin: 0 0 0.5rem;
}
.constraint-stats div {
  min-width: 0;
}
.constraint-stats dt {
  font-size: 0.72rem;
  color: #495057;
  font-weight: 600;
}
.constraint-stats dd {
  margin: 0;
  font-size: 0.9rem;
  color: #212529;
}
.ci-bar-container {
  display: grid;
  grid-template-columns: minmax(5rem, 8rem) minmax(0, 1fr);
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}
.ci-bar-container svg {
  width: 100%;
  max-width: 8rem;
  height: 0.75rem;
}
.ci-text {
  min-width: 0;
  font-size: 0.78rem;
  color: #495057;
}
@media (max-width: 575.98px) {
  .constraint-stats {
    grid-template-columns: 1fr;
  }
  .ci-bar-container {
    grid-template-columns: 1fr;
  }
}
```

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```bash
cd app && npx vitest run src/components/gene/GeneConstraintCard.spec.ts
```

Expected: all GeneConstraintCard tests pass.

## Task 4: Align ClinVar And Model Organism Empty Copy

**Files:**

- Modify: `app/src/components/gene/GeneClinVarCard.vue`
- Modify: `app/src/components/gene/ModelOrganismsCard.vue`

- [ ] **Step 1: Add focused assertions to existing or new component specs**

If specs already exist for these components, add tests there. If not, add small specs next to each component:

```ts
expect(wrapper.text()).toContain('No ClinVar variants returned for this gene.');
```

```ts
expect(wrapper.text()).toContain('No mouse or rat phenotype data returned for this gene.');
```

The model-organism assertions should cover:

```ts
expect(wrapper.text()).toContain('No mouse or rat phenotype data returned for this gene.');
expect(wrapper.find('[aria-label^="55 mouse phenotypes"]').exists()).toBe(true);
```

The first assertion covers the combined no-data case where both MGI and RGD are empty and neither is loading or errored. The second assertion covers the audited `label-content-name-mismatch` case: accessible names for phenotype badges must start with the same visible badge text.

- [ ] **Step 2: Run focused tests and confirm they fail**

Run the specific component specs added or updated in Step 1.

Expected: current copy differs from the design copy.

- [ ] **Step 3: Update empty-state copy and visual distinction**

In `GeneClinVarCard.vue`, change the empty copy to:

```vue
No ClinVar variants returned for this gene.
```

In `ModelOrganismsCard.vue`, add a combined empty state before per-species rows when both sources are empty:

```vue
<div class="model-org-empty-state">
  <i class="bi bi-info-circle model-org-empty-state__icon" aria-hidden="true" />
  <p class="model-org-empty-state__message mb-0">
    No mouse or rat phenotype data returned for this gene.
  </p>
</div>
```

Use the same neutral pattern as the constraint card: `bg-light`, dashed or secondary top border, italic body copy, no danger color.

For phenotype count badges, make the accessible name start with the same visible text. For the MGI badge with visible text like `55 mouse phenotypes`, use:

```vue
:aria-label="`${mgiData.phenotype_count} mouse phenotypes from MGI. ${mgiData.phenotype_count > 0 ? 'Click to see all.' : ''}`"
```

For the RGD badge with visible text like `12 rat phenotypes`, use:

```vue
:aria-label="`${rgdData.phenotype_count} rat phenotypes from RGD. ${rgdData.phenotype_count > 0 ? 'Click to see all.' : ''}`"
```

- [ ] **Step 4: Run focused tests and confirm they pass**

Run the specific component specs added or updated in Step 1.

Expected: focused empty-copy tests pass.

## Task 5: Fix Page-Scoped Accessibility Markup

**Files:**

- Modify: `app/src/components/gene/ClinicalResourcesCard.vue`
- Modify: `app/src/components/gene/IdentifierCard.vue`
- Modify: `app/src/components/gene/GenomicVisualizationTabs.vue`
- Modify: `app/src/components/gene/GeneStructurePlotWithVariants.vue`
- Modify: `app/src/composables/useD3GeneStructure.ts`
- Modify: `app/src/components/AppNavbar.vue`

- [ ] **Step 1: Increase compact metadata label contrast**

In `ClinicalResourcesCard.vue`, change `.resources-label`:

```css
.resources-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0;
  color: #495057;
  margin-right: 0.25rem;
}
```

In `IdentifierCard.vue`, change `.identifiers-label`:

```css
.identifiers-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0;
  color: #495057;
  margin-right: 0.25rem;
}
```

- [ ] **Step 2: Normalize major page heading order**

In `GenomicVisualizationTabs.vue`, change:

```vue
<h6 class="mb-0 fw-bold"><i class="bi bi-graph-up" /> Genomic Visualizations</h6>
```

to:

```vue
<h2 class="genomic-visualization-title mb-0 fw-bold">
  <i class="bi bi-graph-up" aria-hidden="true" /> Genomic Visualizations
</h2>
```

Add scoped CSS:

```css
.genomic-visualization-title {
  font-size: 1rem;
  line-height: 1.2;
}
```

- [ ] **Step 3: Remove prohibited SVG ARIA on raw shapes**

In `GeneStructurePlotWithVariants.vue`, keep the parent SVG accessible with `role="img"` and a single `aria-label`.

In this file and `useD3GeneStructure.ts`, remove `.attr('aria-label', ...)` from raw `rect`, `line`, `path`, and non-interactive `circle` elements. Use:

```ts
.attr('aria-hidden', 'true')
```

Do not add shape-level labels unless the shape also has valid interactive role and keyboard behavior.

- [ ] **Step 4: Fix navbar list semantics with literal list items**

In `AppNavbar.vue`, replace the desktop search `BNavbarNav` block with:

```vue
<ul v-if="show_search" class="navbar-nav mx-auto d-none d-lg-flex">
  <li class="nav-item navbar-search-item">
    <SearchCombobox placeholder-string="..." :in-navbar="true" />
  </li>
</ul>
```

Replace the mobile search `BNavbarNav` block with:

```vue
<ul v-if="show_search" class="navbar-nav d-lg-none ms-auto">
  <li class="nav-item navbar-search-item">
    <SearchCombobox placeholder-string="..." :in-navbar="true" />
  </li>
</ul>
```

Do not use `BNavItem` for search because it renders link semantics around interactive input controls.

- [ ] **Step 5: Verify label-content-name-mismatch source**

Use the Lighthouse details to identify the failing nodes:

```bash
jq -r '.audits["label-content-name-mismatch"].details.items[]?.node.snippet' \
  .planning/ui-audit/genes-detail/lighthouse/ARID1B-mid-1280.json
```

Expected pre-fix snippet for ARID1B `1280px` is an MGI phenotype badge:

```html
<span id="mgi-phenotypes-ARID1B" class="badge bg-primary phenotype-badge phenotype-badge-clickable" aria-label="55 mouse phenotypes from MGI. Click to see all." role="button" tabindex="0">
```

This is handled in Task 4 by making the badge accessible name start with the visible badge text. If Lighthouse still reports `label-content-name-mismatch` after Task 4, inspect the new snippet and fix it only if it is in the touched gene-page scope.

- [ ] **Step 6: Run frontend syntax/type checks**

Run:

```bash
cd app && npm run type-check
```

Expected: type-check passes.

## Task 6: Add Browser Regression Verification

**Files:**

- Create: `app/tests/e2e/genes-detail-ui-ux.spec.ts`

- [ ] **Step 1: Create deterministic Playwright regression spec**

Create `app/tests/e2e/genes-detail-ui-ux.spec.ts`:

```ts
import { test, expect } from '@playwright/test';
import { AxeBuilder } from '@axe-core/playwright';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost';

const viewports = [
  { name: 'mobile-390', width: 390, height: 844 },
  { name: 'tablet-768', width: 768, height: 1024 },
  { name: 'laptop-1024', width: 1024, height: 768 },
  { name: 'mid-1280', width: 1280, height: 800 },
  { name: 'mid-1366', width: 1366, height: 768 },
  { name: 'desktop-1440', width: 1440, height: 900 },
  { name: 'wide-1920', width: 1920, height: 1080 },
];

async function gotoGene(page, symbol: string) {
  await page.goto(`${baseURL}/Genes/${symbol}`);
  await expect(page.getByText('Associated Entities')).toBeVisible();
}

test.describe('Genes detail UI/UX', () => {
  for (const viewport of viewports) {
    test(`ARID1B constraint card does not overflow at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'ARID1B');

      const card = page.getByRole('region', { name: /gene constraint scores from gnomad/i });
      await expect(card).toBeVisible();

      const overflow = await card.evaluate((el) => {
        const cardEl = el as HTMLElement;
        const descendants = Array.from(cardEl.querySelectorAll<HTMLElement>('*'));
        return [cardEl, ...descendants].some((node) => node.scrollWidth > node.clientWidth + 1);
      });

      expect(overflow).toBe(false);
    });

    test(`NAA10 keeps gnomAD no-data card and link visible at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await gotoGene(page, 'NAA10');

      await expect(page.getByText('Gene Constraint (gnomAD)').first()).toBeVisible();
      await expect(page.getByText('No gnomAD constraint data available for this gene.')).toBeVisible();
      await expect(page.getByRole('link', { name: /view gene on gnomad/i })).toBeVisible();
    });
  }

  test('ARID1B page-scoped axe target rules pass at 1280', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await gotoGene(page, 'ARID1B');

    const result = await new AxeBuilder({ page })
      .include('main')
      .exclude('header, nav, footer')
      .analyze();

    const targetIds = new Set([
      'aria-prohibited-attr',
      'color-contrast',
      'heading-order',
      'page-has-heading-one',
      'label-content-name-mismatch',
    ]);
    const targetViolations = result.violations.filter((violation) => targetIds.has(violation.id));
    expect(targetViolations).toEqual([]);
  });

  test('navbar search is rendered with valid list semantics', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await gotoGene(page, 'ARID1B');

    const invalidDirectChildren = await page.locator('ul.navbar-nav').evaluateAll((lists) =>
      lists.flatMap((list) =>
        Array.from(list.children)
          .filter((child) => child.tagName.toLowerCase() !== 'li')
          .map((child) => child.outerHTML),
      ),
    );
    expect(invalidDirectChildren).toEqual([]);
  });
});
```

Policy: the axe test is scoped to the gene-page `main` content and excludes shell landmarks. The navbar list rule has a separate rendered-DOM assertion because it is intentionally shell markup touched by this plan.

- [ ] **Step 2: Run with local stack**

Start stack if needed:

```bash
make dev
```

Run:

```bash
cd app && npx playwright test tests/e2e/genes-detail-ui-ux.spec.ts
```

Expected: all viewport and target accessibility tests pass.

## Task 7: Full Verification And Lighthouse

**Files:**

- No code files; update planning notes only if verification finds a residual issue.

- [ ] **Step 1: Run focused unit/spec tests**

Run:

```bash
cd app && npx vitest run \
  src/components/ui/__tests__/SectionCard.spec.ts \
  src/views/pages/__tests__/GeneView.spec.ts \
  src/components/gene/GeneConstraintCard.spec.ts
```

Expected: all tests pass.

- [ ] **Step 2: Run frontend quality gates**

Run:

```bash
make lint-app
cd app && npm run type-check
cd app && npm run test:unit
```

Expected: all pass.

- [ ] **Step 3: Run local Playwright checks**

Run:

```bash
make playwright-stack
cd app && npx playwright test tests/e2e/genes-detail-ui-ux.spec.ts
cd ..
make playwright-stack-down
```

Expected: all pass. Keep the stack-down command even if the test fails.

- [ ] **Step 4: Run the existing perf/axe bench**

Run from repo root with the local stack up:

```bash
make playwright-stack
cd app && BENCH_STRICT=1 npx playwright test tests/perf/genes-entities.bench.spec.ts --project=chromium
cd ..
make playwright-stack-down
```

Expected: no strict axe failures on the gene probes. If entity probes fail for unrelated reasons, record the gene probe results and unrelated entity failure separately.

- [ ] **Step 5: Re-run Lighthouse at key widths**

With the app available at `http://localhost`, run:

```bash
cd app
npx lighthouse http://localhost/Genes/ARID1B --preset=desktop --screenEmulation.width=1280 --screenEmulation.height=800 --output=json --output-path=../.planning/ui-audit/genes-detail/lighthouse/ARID1B-mid-1280-after.json --quiet
npx lighthouse http://localhost/Genes/ARID1B --preset=desktop --screenEmulation.width=1024 --screenEmulation.height=768 --output=json --output-path=../.planning/ui-audit/genes-detail/lighthouse/ARID1B-laptop-1024-after.json --quiet
npx lighthouse http://localhost/Genes/ARID1B --preset=desktop --screenEmulation.width=768 --screenEmulation.height=1024 --output=json --output-path=../.planning/ui-audit/genes-detail/lighthouse/ARID1B-tablet-768-after.json --quiet
npx lighthouse http://localhost/Genes/ARID1B --preset=desktop --screenEmulation.width=1440 --screenEmulation.height=900 --output=json --output-path=../.planning/ui-audit/genes-detail/lighthouse/ARID1B-desktop-1440-after.json --quiet
npx lighthouse http://localhost/Genes/NAA10 --preset=desktop --screenEmulation.width=1280 --screenEmulation.height=800 --output=json --output-path=../.planning/ui-audit/genes-detail/lighthouse/NAA10-mid-1280-after.json --quiet
```

Expected:

- ARID1B `1280x800` CLS improves from `0.152`; target `<0.10`.
- ARID1B `768x1024` CLS improves from `0.226`; target `<0.15`.
- ARID1B `1024x768` has no constraint-card overflow and no obvious external-card jump.
- ARID1B `1280x800` accessibility score is `>=0.95`, or residual lower score is documented with failing audit IDs and whether each is in or out of this plan's scope.

## Acceptance Checklist

- [ ] `/Genes/ARID1B` Gene Constraint card reports no card/body/descendant horizontal overflow at `390`, `768`, `1024`, `1280`, and `1366` px.
- [ ] `/Genes/NAA10` visibly renders `Gene Constraint (gnomAD)`, `No gnomAD constraint data available for this gene.`, and the outbound gnomAD link at all audited widths.
- [ ] External cards use `cols=12`, `lg=6`, `xxl=4`.
- [ ] Empty source states are visible and neutral; errors remain visually distinct.
- [ ] The page has exactly one coherent `h1`; generic card wrappers do not create heading skips.
- [ ] Target axe/Lighthouse failures are resolved for the gene page, including the model-organism phenotype badge `label-content-name-mismatch`.
- [ ] `make lint-app`, `cd app && npm run type-check`, and relevant Vitest specs pass.

## Plan Self-Review

- Spec coverage: every design requirement maps to a task: visible source-owned empty states in Tasks 2-4, responsive grid in Task 2, constraint internals in Task 3, accessibility in Task 5, browser/Lighthouse verification in Tasks 6-7.
- Placeholder scan: no unfinished-marker placeholders remain.
- Type consistency: prop names and test selectors are consistent across snippets.
- Scope check: plan stays on `/Genes/:symbol` UI/UX and shared components needed by that page; no API/SWR refactor is included.

## Execution Handoff

Plan complete and saved to `.planning/superpowers/plans/2026-05-09-genes-detail-ui-ux-fixes-plan.md`. Do not implement until the plan is approved.

Execution options after approval:

1. Subagent-Driven: dispatch a fresh worker per task and review between tasks.
2. Inline Execution: execute tasks in this session with checkpoints.
