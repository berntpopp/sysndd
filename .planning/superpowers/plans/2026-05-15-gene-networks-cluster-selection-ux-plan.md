# Gene Networks Cluster Selection UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/GeneNetworks` cluster selection discoverable by allowing direct cluster-container selection and adding a compact cue for AI summaries in all-clusters mode.

**Architecture:** Extend the Cytoscape interaction boundary so compound parent nodes use a cluster-selection callback while regular gene nodes keep the existing gene navigation callback. Reuse `NetworkVisualization.vue`'s existing `selectSingleCluster()` path so legend, dropdown, canvas cluster clicks, table filtering, and summary fetching stay synchronized.

**Tech Stack:** Vue 3, TypeScript, Cytoscape.js, Vitest + Vue Test Utils, Playwright, Bootstrap Vue Next.

---

## File Structure

- Modify: `app/src/composables/useCytoscape.ts`
  - Add `onClusterClick` option.
  - Route compound parent node taps to `onClusterClick`.
  - Adjust selected parent styling to use operational blue instead of red.

- Modify: `app/src/components/analyses/NetworkVisualization.vue`
  - Pass `onClusterClick` to `useCytoscape`.
  - Reuse `selectSingleCluster(clusterId)` for graph parent selection.
  - Expose a parent-callable method for the all-clusters cue button.

- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue`
  - Add a compact all-clusters summary cue above the table.
  - Add a `selectDefaultClusterForSummary()` method that calls the exposed network selection method.
  - Keep summary card rendering unchanged for selected single-cluster state.

- Create: `app/src/components/analyses/NetworkVisualization.spec.ts`
  - Unit-test parent cluster click and gene click callback behavior through a mocked `useCytoscape`.

- Create: `app/src/components/analyses/AnalyseGeneClusters.spec.ts`
  - Unit-test the all-clusters cue and default cluster action with a stubbed `NetworkVisualization`.

- Modify: `documentation/02-web-tool.qmd`
  - Update the functional clusters section to mention cluster selection from the network/legend/dropdown and AI summary visibility.

---

### Task 1: Add Cluster-Parent Click Contract To `useCytoscape`

**Files:**
- Modify: `app/src/composables/useCytoscape.ts`
- Test indirectly in Task 2 through `NetworkVisualization.spec.ts`

- [ ] **Step 1: Update the options interface**

In `app/src/composables/useCytoscape.ts`, replace the `CytoscapeOptions` interface with:

```ts
export interface CytoscapeOptions {
  /** Ref to the container HTML element */
  container: Ref<HTMLElement | null>;
  /** Initial elements to render */
  elements?: ElementDefinition[];
  /** Callback when a regular gene node is clicked */
  onNodeClick?: (nodeId: string, nodeData: Record<string, unknown>) => void;
  /** Callback when a compound cluster parent node is clicked */
  onClusterClick?: (clusterId: number, nodeData: Record<string, unknown>) => void;
}
```

- [ ] **Step 2: Add cluster id parser near `getCytoscapeStyle()`**

Add this helper before `getCytoscapeStyle()`:

```ts
function parseClusterParentId(nodeId: string, nodeData: Record<string, unknown>): number | null {
  const rawClusterId =
    typeof nodeData.cluster === 'number' || typeof nodeData.cluster === 'string'
      ? nodeData.cluster
      : typeof nodeData.label === 'string'
        ? nodeData.label.replace(/^Cluster\s+/i, '')
        : nodeId.replace(/^cluster-/, '');

  const clusterId =
    typeof rawClusterId === 'number'
      ? rawClusterId
      : Number.parseInt(String(rawClusterId).split('.')[0], 10);

  return Number.isFinite(clusterId) ? clusterId : null;
}
```

- [ ] **Step 3: Replace the node tap handler**

Find the existing block:

```ts
// Event handlers - node click
if (options.onNodeClick) {
  cy.on('tap', 'node', (event) => {
    const node = event.target;
    const nodeId = node.id();
    const nodeData = node.data();
    options.onNodeClick!(nodeId, nodeData);
  });
}
```

Replace it with:

```ts
// Event handlers - node click
if (options.onNodeClick || options.onClusterClick) {
  cy.on('tap', 'node', (event) => {
    const node = event.target;
    const nodeId = node.id();
    const nodeData = node.data();

    if (nodeData.isClusterParent === true) {
      const clusterId = parseClusterParentId(nodeId, nodeData);
      if (clusterId !== null) {
        options.onClusterClick?.(clusterId, nodeData);
      }
      return;
    }

    options.onNodeClick?.(nodeId, nodeData);
  });
}
```

- [ ] **Step 4: Adjust selected styling to operational blue**

In `getCytoscapeStyle()`, replace the `node:selected` style with:

```ts
{
  selector: 'node:selected',
  style: {
    'border-color': '#0d47a1',
    'border-width': 4,
    'font-size': '12px',
    'font-weight': 'bold',
    'z-index': 999,
  },
},
```

- [ ] **Step 5: Run type-check for this file**

Run:

```bash
cd app && npm run type-check
```

Expected: type-check passes, or any failures are unrelated pre-existing project-wide issues. If it fails on `useCytoscape.ts`, fix before continuing.

- [ ] **Step 6: Commit**

```bash
git add app/src/composables/useCytoscape.ts
git commit -m "feat: route cluster parent clicks in cytoscape"
```

---

### Task 2: Wire Cluster-Parent Clicks Through `NetworkVisualization`

**Files:**
- Modify: `app/src/components/analyses/NetworkVisualization.vue`
- Create: `app/src/components/analyses/NetworkVisualization.spec.ts`

- [ ] **Step 1: Write failing component tests**

Create `app/src/components/analyses/NetworkVisualization.spec.ts`:

```ts
import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import { computed, ref } from 'vue';
import NetworkVisualization from './NetworkVisualization.vue';

const push = vi.fn();
let capturedCytoscapeOptions: Record<string, unknown> | null = null;

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
}));

vi.mock('@/utils/clusterColors', () => ({
  getClusterColor: (cluster: number | string) => `cluster-color-${cluster}`,
}));

vi.mock('@/composables', () => ({
  useNetworkData: () => ({
    isLoading: ref(false),
    error: ref(null),
    metadata: ref({
      node_count: 2,
      edge_count: 1,
      cluster_count: 2,
      total_edges: 1,
      edges_filtered: false,
      total_ndd_genes: 2,
      genes_with_string: 2,
      elapsed_seconds: 0.1,
      category_counts: { Definitive: 2, Moderate: 0, Limited: 0 },
    }),
    fetchNetworkData: vi.fn().mockResolvedValue(undefined),
    cytoscapeElements: ref([]),
  }),
  useNetworkFilters: () => {
    const selectedClusters = ref(new Set<number>());
    const showAllClusters = ref(true);
    return {
      categoryLevel: ref('Definitive'),
      selectedClusters,
      showAllClusters,
      applyFilters: vi.fn(),
      getVisibleNodeCount: vi.fn(() => 2),
      getVisibleEdgeCount: vi.fn(() => 1),
    };
  },
  useFilterSync: () => ({
    filterState: ref({ search: '' }),
  }),
  useWildcardSearch: () => ({
    pattern: ref(''),
    regex: computed(() => null),
    matches: vi.fn(() => false),
  }),
  useNetworkHighlight: () => ({
    highlightState: ref({ hoveredNodeId: null }),
    setupNetworkListeners: vi.fn(),
    highlightNodeFromTable: vi.fn(),
    clearHighlights: vi.fn(),
    isRowHighlighted: vi.fn(() => false),
  }),
  useCytoscape: (options: Record<string, unknown>) => {
    capturedCytoscapeOptions = options;
    return {
      cy: () => null,
      isInitialized: ref(true),
      isLoading: ref(false),
      initializeCytoscape: vi.fn(),
      updateElements: vi.fn(),
      fitToScreen: vi.fn(),
      resetLayout: vi.fn(),
      zoomIn: vi.fn(),
      zoomOut: vi.fn(),
      exportPNG: vi.fn(() => ''),
      exportSVG: vi.fn(() => ''),
    };
  },
}));

const globalStubs = {
  BButton: { template: '<button><slot /></button>' },
  BBadge: { template: '<span><slot /></span>' },
  BSpinner: { template: '<span />' },
  BDropdown: { template: '<div><slot /></div>', props: ['text'] },
  BDropdownItemButton: { template: '<button @click="$emit(`click`)"><slot /></button>' },
  BDropdownDivider: { template: '<hr />' },
};

describe('NetworkVisualization', () => {
  it('selects a cluster when the Cytoscape cluster parent is clicked', async () => {
    const wrapper = mount(NetworkVisualization, {
      global: { stubs: globalStubs },
    });

    const onClusterClick = capturedCytoscapeOptions?.onClusterClick as
      | ((clusterId: number) => void)
      | undefined;

    expect(onClusterClick).toBeTypeOf('function');
    onClusterClick?.(1);
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('clusters-changed')).toEqual([[[1], false]]);
  });

  it('keeps gene node clicks routed to the gene page', () => {
    mount(NetworkVisualization, {
      global: { stubs: globalStubs },
    });

    const onNodeClick = capturedCytoscapeOptions?.onNodeClick as
      | ((nodeId: string) => void)
      | undefined;

    expect(onNodeClick).toBeTypeOf('function');
    onNodeClick?.('HGNC:1234');

    expect(push).toHaveBeenCalledWith({ name: 'Gene', params: { id: 'HGNC:1234' } });
  });
});
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts
```

Expected: first test fails because `onClusterClick` is not passed into `useCytoscape`.

- [ ] **Step 3: Add the `onClusterClick` option**

In `NetworkVisualization.vue`, update the `useCytoscape` call from:

```ts
const {
  cy,
  isInitialized,
  isLoading: isCytoscapeLoading,
  initializeCytoscape,
  updateElements,
  fitToScreen,
  resetLayout,
  zoomIn,
  zoomOut,
  exportPNG,
  exportSVG,
} = useCytoscape({
  container: cytoscapeContainer,
  onNodeClick: (nodeId: string) => {
    // Navigate to entity detail page
    router.push({ name: 'Gene', params: { id: nodeId } });
    // Emit for potential table sync
    emit('cluster-selected', nodeId);
  },
});
```

to:

```ts
const {
  cy,
  isInitialized,
  isLoading: isCytoscapeLoading,
  initializeCytoscape,
  updateElements,
  fitToScreen,
  resetLayout,
  zoomIn,
  zoomOut,
  exportPNG,
  exportSVG,
} = useCytoscape({
  container: cytoscapeContainer,
  onNodeClick: (nodeId: string) => {
    router.push({ name: 'Gene', params: { id: nodeId } });
    emit('cluster-selected', nodeId);
  },
  onClusterClick: (clusterId: number) => {
    selectSingleCluster(clusterId);
  },
});
```

- [ ] **Step 4: Expose a parent-callable single-select method**

At the bottom of `NetworkVisualization.vue`, replace:

```ts
defineExpose({
  highlightNodeFromTable,
  isRowHighlighted,
  clearHighlights,
  searchMatchCount,
  selectCluster,
});
```

with:

```ts
defineExpose({
  highlightNodeFromTable,
  isRowHighlighted,
  clearHighlights,
  searchMatchCount,
  selectCluster,
  selectSingleCluster,
});
```

- [ ] **Step 5: Run the focused component test**

Run:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts
```

Expected: both tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/src/components/analyses/NetworkVisualization.vue app/src/components/analyses/NetworkVisualization.spec.ts
git commit -m "feat: select network clusters from graph"
```

---

### Task 3: Add The All-Clusters AI Summary Cue

**Files:**
- Modify: `app/src/components/analyses/AnalyseGeneClusters.vue`
- Create: `app/src/components/analyses/AnalyseGeneClusters.spec.ts`

- [ ] **Step 1: Write failing component tests**

Create `app/src/components/analyses/AnalyseGeneClusters.spec.ts`:

```ts
import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AnalyseGeneClusters from './AnalyseGeneClusters.vue';

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: vi.fn() }),
  useColorAndSymbols: () => ({}),
  useFilterSync: () => ({
    filterState: { search: '' },
    setSearch: vi.fn(),
  }),
  useWildcardSearch: () => ({
    pattern: { value: '' },
    matches: vi.fn(() => true),
  }),
  useExcelExport: () => ({
    isExporting: false,
    exportToExcel: vi.fn(),
  }),
}));

vi.mock('@/api/jobs', () => ({
  submitClustering: vi.fn(),
  getJobStatus: vi.fn(),
}));

vi.mock('@/api/analysis', () => ({
  getFunctionalClustering: vi.fn(),
  getFunctionalClusterSummary: vi.fn(),
}));

const networkSelectSingleCluster = vi.fn();

const globalStubs = {
  AnalysisPanel: {
    template: '<section><slot name="actions" /><slot /></section>',
  },
  InlineHelpBadge: { template: '<button />' },
  BPopover: { template: '<div />' },
  BRow: { template: '<div><slot /></div>' },
  BCol: { template: '<div><slot /></div>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BFormSelect: { template: '<select />' },
  BButton: {
    template: '<button :disabled="disabled" @click="$emit(`click`)"><slot /></button>',
    props: ['disabled'],
  },
  BSpinner: { template: '<span />' },
  BCard: { template: '<div><slot name="header" /><slot /></div>' },
  BCardText: { template: '<div><slot /></div>' },
  BBadge: { template: '<span><slot /></span>' },
  GenericTable: { template: '<table />' },
  TablePaginationControls: { template: '<nav />' },
  TermSearch: { template: '<input />' },
  CategoryFilter: { template: '<select />' },
  ScoreSlider: { template: '<input />' },
  LlmSummaryCard: { template: '<article>AI Summary</article>' },
  Splitpanes: { template: '<div><slot /></div>' },
  Pane: { template: '<div><slot /></div>' },
  NetworkVisualization: {
    template: '<div data-testid="network-viz" />',
    methods: {
      selectSingleCluster: networkSelectSingleCluster,
    },
  },
};

function mountComponent() {
  return mount(AnalyseGeneClusters, {
    global: { stubs: globalStubs },
  });
}

describe('AnalyseGeneClusters', () => {
  it('shows a compact AI summary cue in all-clusters mode', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Select one cluster to view its AI summary');
    expect(wrapper.text()).toContain('View cluster 1');
  });

  it('selects cluster 1 through the network ref from the cue button', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = false;
    wrapper.vm.itemsCluster = [
      {
        cluster: 1,
        cluster_size: 10,
        hash_filter: 'equals(hash,abc)',
        term_enrichment: [],
        identifiers: [],
      },
    ];
    wrapper.vm.showAllClustersInTable = true;
    await wrapper.vm.$nextTick();

    await wrapper.get('button[aria-label="View cluster 1 summary"]').trigger('click');

    expect(networkSelectSingleCluster).toHaveBeenCalledWith(1);
  });
});
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/analyses/AnalyseGeneClusters.spec.ts
```

Expected: tests fail because the cue and method do not exist yet.

- [ ] **Step 3: Add the cue above the table card**

In `AnalyseGeneClusters.vue`, place this block after the summary loading block and before the `<BCard>` that wraps the table:

```vue
<div v-else-if="showAllClustersInTable" class="cluster-summary-cue" role="status">
  <div class="cluster-summary-cue__text">
    <i class="bi bi-stars" aria-hidden="true" />
    <span>Select one cluster to view its AI summary and focused enrichment table.</span>
  </div>
  <BButton
    v-if="firstAvailableCluster"
    size="sm"
    variant="outline-primary"
    class="cluster-summary-cue__action"
    aria-label="View cluster 1 summary"
    @click="selectDefaultClusterForSummary"
  >
    View cluster {{ firstAvailableCluster }}
  </BButton>
</div>
```

- [ ] **Step 4: Add computed `firstAvailableCluster`**

In the `computed` section of `AnalyseGeneClusters.vue`, add:

```js
firstAvailableCluster() {
  const firstCluster = this.itemsCluster?.[0]?.cluster;
  return firstCluster == null ? null : Number(firstCluster);
},
```

- [ ] **Step 5: Add method `selectDefaultClusterForSummary`**

In `methods`, add:

```js
selectDefaultClusterForSummary() {
  if (!this.firstAvailableCluster) return;
  this.$refs.networkVisualization?.selectSingleCluster?.(this.firstAvailableCluster);
},
```

- [ ] **Step 6: Add compact cue styles**

In the scoped style block of `AnalyseGeneClusters.vue`, add:

```css
.cluster-summary-cue {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  padding: 0.625rem 0.75rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #f8fbff;
  color: #495057;
  font-size: 0.875rem;
}

.cluster-summary-cue__text {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}

.cluster-summary-cue__text .bi {
  color: #0d47a1;
}

.cluster-summary-cue__action {
  flex: 0 0 auto;
}

@media (max-width: 767.98px) {
  .cluster-summary-cue {
    align-items: flex-start;
    flex-direction: column;
  }
}
```

- [ ] **Step 7: Run the focused component test**

Run:

```bash
cd app && npx vitest run src/components/analyses/AnalyseGeneClusters.spec.ts
```

Expected: both tests pass.

- [ ] **Step 8: Commit**

```bash
git add app/src/components/analyses/AnalyseGeneClusters.vue app/src/components/analyses/AnalyseGeneClusters.spec.ts
git commit -m "feat: cue gene network summary selection"
```

---

### Task 4: Update User Documentation

**Files:**
- Modify: `documentation/02-web-tool.qmd`

- [ ] **Step 1: Update the functional clusters paragraph**

Find the paragraph under `### Functional clusters` that starts:

```md
By clicking on the different colored bubbles on the panel to the left, the user can select the respective main- or sub-clusters.
```

Replace that paragraph with:

```md
Users can focus the functional cluster view by selecting a cluster directly in the network visualization, from the cluster legend, or from the cluster dropdown. A single-cluster selection filters the enrichment and gene tables to that cluster and displays the AI-generated cluster summary when an approved summary is available. The all-clusters view remains available for broad comparison across clusters.
```

- [ ] **Step 2: Commit documentation**

```bash
git add documentation/02-web-tool.qmd
git commit -m "docs: describe gene network cluster selection"
```

---

### Task 5: End-To-End Verification

**Files:**
- No source files changed in this task.

- [ ] **Step 1: Run focused unit tests**

Run:

```bash
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts src/components/analyses/AnalyseGeneClusters.spec.ts
```

Expected: all tests pass.

- [ ] **Step 2: Run frontend type-check**

Run:

```bash
cd app && npm run type-check
```

Expected: pass.

- [ ] **Step 3: Run local Playwright check**

With the dev stack running at `http://localhost:5173`, run:

```bash
cd app && node - <<'NODE'
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const summaryResponses = [];

  page.on('response', (res) => {
    if (res.url().includes('/api/analysis/functional_cluster_summary')) {
      summaryResponses.push({ status: res.status(), url: res.url() });
    }
  });

  await page.goto('http://localhost:5173/GeneNetworks', { waitUntil: 'domcontentloaded' });

  const modal = page.locator('.modal.show');
  if (await modal.count()) {
    const ok = modal.getByRole('button').filter({ hasText: /accept|agree|ok|continue|close/i }).first();
    if (await ok.count()) await ok.click();
    else await page.keyboard.press('Escape');
  }

  await page.waitForResponse(
    (res) => res.url().includes('/api/analysis/network_edges') && res.status() === 200,
    { timeout: 60_000 },
  );
  await page.waitForResponse(
    (res) => /\/api\/jobs\/[^/]+\/status/.test(res.url()) && res.status() === 200,
    { timeout: 90_000 },
  );

  await page.getByRole('button', { name: 'View cluster 1 summary' }).click();
  await page.waitForResponse(
    (res) => res.url().includes('/api/analysis/functional_cluster_summary') && res.status() === 200,
    { timeout: 30_000 },
  );

  const body = await page.locator('body').innerText();
  console.log(JSON.stringify({
    hasAISummary: body.includes('AI Summary'),
    hasAllClustersCue: body.includes('Select one cluster to view its AI summary'),
    summaryResponses,
  }, null, 2));

  await browser.close();
})();
NODE
```

Expected JSON:

```json
{
  "hasAISummary": true,
  "hasAllClustersCue": false,
  "summaryResponses": [
    {
      "status": 200
    }
  ]
}
```

The exact URL in `summaryResponses[0].url` may vary by cluster hash.

- [ ] **Step 4: Run the repo pre-commit verification lane**

Run:

```bash
make pre-commit
```

Expected: pass. If this is too slow for the active session, run at least:

```bash
cd app && npm run type-check
cd app && npx vitest run src/components/analyses/NetworkVisualization.spec.ts src/components/analyses/AnalyseGeneClusters.spec.ts
```

and record that full `make pre-commit` was not run.

- [ ] **Step 5: Final commit if verification caused fixes**

If verification required additional source fixes:

```bash
git add app/src/components/analyses app/src/composables/useCytoscape.ts documentation/02-web-tool.qmd
git commit -m "fix: harden gene network cluster selection"
```

If no additional fixes were needed, do not create an empty commit.

---

## Plan Self-Review

- Spec coverage: cluster parent click, all-clusters cue, selected-state styling, docs, unit tests, and Playwright verification are each covered by tasks.
- Placeholder scan: no `TBD`, `TODO`, or vague testing steps remain.
- Type consistency: `onClusterClick`, `selectSingleCluster`, `firstAvailableCluster`, and `selectDefaultClusterForSummary` are named consistently across tasks.
- Scope check: the plan is focused on the GeneNetworks UI/UX path and does not change backend summary generation.
