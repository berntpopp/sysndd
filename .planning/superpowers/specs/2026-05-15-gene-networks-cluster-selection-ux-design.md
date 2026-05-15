# Gene Networks Cluster Selection UX Design

## Problem

`/GeneNetworks` has AI summaries for functional clusters, but the discoverability is weak:

- The route opens in `All Clusters` mode, where the summary card is intentionally hidden.
- Selecting a cluster from the legend pill or cluster dropdown fetches and displays the AI summary.
- Clicking the large visible cluster region in the Cytoscape network does not select the cluster. The current generic node click handler treats every node click as a gene navigation event.
- There is no compact cue in the right pane explaining that a single-cluster selection unlocks the summary.

This makes the feature feel absent even though the API, cache, and summary card path are working.

## Evidence

Runtime checks against `http://localhost:5173/GeneNetworks` showed:

- Initial page state: `All Clusters`, no `AI Summary`, no summary API request.
- Legend cluster pill click: `GET /api/analysis/functional_cluster_summary?...cluster_number=1` returns `200`, and `AI Summary` appears.
- Screenshot evidence was captured at `/tmp/gene-networks-current.png`.

Relevant implementation points:

- `app/src/components/analyses/AnalyseGeneClusters.vue` renders `LlmSummaryCard` only when `currentSummary && !summaryLoading && !showAllClustersInTable`.
- `app/src/components/analyses/NetworkVisualization.vue` already emits `clusters-changed` from legend/dropdown selection.
- `app/src/composables/useNetworkData.ts` creates compound Cytoscape parent nodes with `isClusterParent: true` and ids like `cluster-1`.
- `app/src/composables/useCytoscape.ts` currently exposes one generic `onNodeClick` callback for all nodes.

## Design Goals

1. Make the primary visual object clickable: clicking a cluster container selects that cluster.
2. Preserve existing gene-node behavior: clicking a gene still navigates to the gene detail page.
3. Add a quiet, compact cue in the right pane when all clusters are shown.
4. Keep the design aligned with `documentation/10-visual-design-guide.md`: dense, clinical, table-first, low decoration, compact chips/buttons.
5. Keep the implementation scoped and testable without changing the API.

## Non-Goals

- Do not redesign the full GeneNetworks page.
- Do not add a new persistent sidebar or large explanatory panel.
- Do not change summary-generation or cache behavior.
- Do not change phenotype-cluster behavior.
- Do not alter graph layout algorithms or backend clustering.

## Proposed UX

### Cluster Container Click

Clicking a Cytoscape compound parent node, such as `cluster-1`, selects that cluster. The action must behave the same as clicking the corresponding legend pill:

- `showAllClusters` becomes `false`.
- `selectedClusters` becomes a single-item set containing that cluster id.
- Existing filtering runs.
- `clusters-changed` emits `[clusterId], false`.
- The parent component updates the table to the selected cluster and fetches the functional cluster AI summary.

Clicking a regular gene node keeps the current behavior: navigate to the gene route and emit the existing gene-selection event.

### All-Clusters Summary Cue

When `showAllClustersInTable` is true, show a small unframed/low-chrome cue above the table controls:

Text:

> Select one cluster to view its AI summary and focused enrichment table.

When clusters are loaded, include a compact outline button:

> View cluster 1

The button calls the same parent selection path used by graph/legend selection. It should disappear when one or more clusters are selected.

The cue is not shown during summary loading or after a single-cluster summary is visible. It must not be a nested card.

### Visual Feedback

Selected cluster state should be easier to see:

- Existing selected legend styling remains.
- The selected cluster parent node receives a selected visual treatment through Cytoscape selection or a class.
- The selected-state styling should use existing operational blue/neutral language, not a heavy red error-like border.

The existing gene hover, search, and table hover highlighting should continue to work.

## Architecture

### Cytoscape Event Boundary

Extend `useCytoscape` so consumers can distinguish cluster parent clicks from regular node clicks.

Add an optional callback:

```ts
onClusterClick?: (clusterId: number, nodeData: Record<string, unknown>) => void;
```

In the Cytoscape `tap` handler:

1. Read `node.data()`.
2. If `nodeData.isClusterParent === true`, parse the id or label to a numeric cluster id.
3. Call `onClusterClick(clusterId, nodeData)` and return.
4. Otherwise call the existing `onNodeClick(nodeId, nodeData)`.

This keeps the distinction at the graph-interaction boundary rather than forcing every parent component to parse Cytoscape internals.

### NetworkVisualization Selection API

`NetworkVisualization.vue` already has `selectSingleCluster(clusterId)` for legend and dropdown clicks. Reuse it for parent-node clicks:

```ts
onClusterClick: (clusterId: number) => {
  selectSingleCluster(clusterId);
}
```

No new event contract is needed between `NetworkVisualization` and `AnalyseGeneClusters`; the existing `clusters-changed` event remains the single source of cluster selection state.

### Parent Empty-State Action

`AnalyseGeneClusters.vue` receives no direct access to `selectSingleCluster`, but it has a template ref to `NetworkVisualization`. Expose the existing `selectSingleCluster` method so the parent can use the same selection path as the legend and dropdown:

```ts
selectSingleCluster(clusterId: number): void
```

The right-pane cue button calls that exposed method so the network visual state, legend state, table state, and summary fetch stay synchronized.

## Error Handling

- If cluster data has not loaded yet, the empty-state button is hidden or disabled.
- If a parent cluster id cannot be parsed, do nothing and leave current state unchanged.
- Summary endpoint failures continue to use the existing toast and null-summary behavior.
- If the selected cluster has no summary, the existing `404` behavior remains: no summary card is shown.

## Accessibility

- The cue text must be real text, not tooltip-only.
- The cue button must have a clear accessible name, for example `View cluster 1`.
- Cluster selection must remain available through existing legend/dropdown buttons because canvas interactions are not fully keyboard accessible.
- No essential behavior should rely only on canvas click.

## Testing Strategy

### Unit Tests

Add a component test for `NetworkVisualization.vue` with a mocked `useCytoscape` that calls the provided callbacks:

- Parent cluster click invokes existing cluster-selection flow and emits `clusters-changed` with `[1], false`.
- Gene node click still navigates through Vue Router to `{ name: 'Gene', params: { id: 'HGNC:1234' } }`.

Add a component test for `AnalyseGeneClusters.vue`:

- In all-clusters mode, the compact cue is visible.
- Clicking `View cluster 1` calls the network component exposed single-cluster method.

### E2E / Playwright Verification

Run a local Playwright smoke for `/GeneNetworks`:

1. Open route.
2. Wait for network and clustering job responses.
3. Assert initial all-clusters cue is visible.
4. Select cluster 1 using a visible UI control.
5. Assert `AI Summary` appears and `/api/analysis/functional_cluster_summary` returns `200`.

Canvas-click automation is fragile because Cytoscape renders to canvas. The unit test owns the parent-node click contract; Playwright owns end-to-end user-visible behavior.

## Documentation

Update `documentation/02-web-tool.qmd` functional clusters section to reflect current behavior:

- Users can select a cluster from the network cluster area, legend, or dropdown.
- A single-cluster selection displays the AI summary when available.

No API documentation change is needed.

## Acceptance Criteria

- Clicking a cluster parent in the network selects the cluster and triggers the same data path as the legend pill.
- Clicking a gene node still navigates to the gene detail page.
- Initial all-clusters state includes a compact cue explaining how to reveal AI summaries.
- `View cluster 1` cue action selects cluster 1 and causes the summary fetch path to run.
- No nested cards or large instructional panels are introduced.
- Focused unit tests pass.
- A local Playwright check confirms the route still loads and AI summary appears after selection.
