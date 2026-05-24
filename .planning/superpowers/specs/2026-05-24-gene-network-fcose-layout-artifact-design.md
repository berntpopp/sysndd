# Gene Network fCoSE Layout Artifact Design

## Problem

`/GeneNetworks` is slow after the data arrives because the browser computes a Cytoscape fCoSE layout for a large compound graph on the main thread. In local and production probes, the layout step caused roughly 3-5 seconds of blocking work for the default 10,000-edge network.

The API already returns node `x` and `y` coordinates, but those positions are produced by igraph DrL/FR on the backend. The visible UI today is not based on those coordinates. The frontend drops them and runs Cytoscape fCoSE over a compound graph with cluster parent nodes. Directly switching to the existing API `x/y` coordinates would be fast, but it would change the visual representation.

## User Constraint

The UI representation should stay the same. For this work, that means preserving:

- Cytoscape as the browser renderer.
- fCoSE-style compound graph geometry.
- cluster parent compound nodes and gene child nodes.
- the same displayed edge set after `max_edges`.
- current graph styling, filters, interactions, tooltips, export behavior, and table synchronization.

## Evidence

Current code behavior:

- `api/functions/analysis-network-functions.R` computes `x/y` using igraph layout algorithms.
- `app/src/types/models.ts` already declares optional `NetworkNode.x` and `NetworkNode.y`.
- `app/src/composables/useNetworkData.ts` transforms API nodes to Cytoscape elements without `position`.
- `app/src/composables/useCytoscape.ts` runs fCoSE with `numIter: 2500` on updates and reset.
- `app/src/composables/useNetworkData.ts` still uses raw axios instead of the typed analysis API client.

Prototype measurement using captured local `network_edges` JSON:

| Path | Payload | Layout time |
| --- | ---: | ---: |
| Cytoscape `preset` using current API DrL `x/y` | 2,259 nodes / 10,000 edges | 9 ms |
| current browser-style fCoSE | 2,259 nodes / 10,000 edges | 3,105 ms |
| fCoSE initialized from API DrL `x/y` | 2,259 nodes / 10,000 edges | 2,521 ms |
| fCoSE `draft` quality | 2,259 nodes / 10,000 edges | 584 ms |
| Cytoscape `preset` using current API DrL `x/y` | 1,439 nodes / 3,000 edges | 18 ms |
| current browser-style fCoSE | 1,439 nodes / 3,000 edges | 4,981 ms |

## External Research Summary

Cytoscape.js models a layout as a mapping from nodes to positions. Its `preset` layout is the documented way to render predetermined node coordinates without recomputing a layout in the browser: https://js.cytoscape.org/

Cytoscape's layout guide explicitly recommends precomputing and caching layout results on the server when client-side layout is too slow, and notes that direct headless Cytoscape in Node is the simplest route. It also recommends `styleEnabled: true` when layout needs node dimensions from style: https://blog.js.cytoscape.org/2020/05/11/layouts/#headless-use-of-layouts

The fCoSE extension is designed for compound graph layout and supports the current use case. Its documented options include `quality`, `randomize`, `numIter`, node/edge force settings, component packing, and constraints: https://ivis-at-bilkent.github.io/cytoscape.js-fcose/

The Cytoscape.js 2023 Bioinformatics update confirms that Cytoscape.js can run headlessly on servers such as Node.js, which supports using it as a backend graph operation engine: https://academic.oup.com/bioinformatics/article/39/1/btad031/6988031

## Approach Options

### Option A: Use Existing API DrL/FR Coordinates In The Browser

The frontend would add `position: { x, y }` from the existing API payload and use Cytoscape `preset`.

Benefits:

- Smallest code change.
- Removes the browser fCoSE stall.
- Provides deterministic-looking positions from cached API data.

Costs:

- Changes visual geometry because the API layout is igraph DrL/FR, not Cytoscape fCoSE.
- Current coordinates are computed before `max_edges` response limiting, so they do not exactly describe the displayed graph.
- Does not satisfy the "same UI representation" constraint as the production default.

Use this only as a diagnostic fallback or feature-flagged proof path.

### Option B: Worker-Computed fCoSE Layout Artifact

The backend worker builds the same Cytoscape element graph currently built in the browser, runs Cytoscape/fCoSE headlessly in Node, stores a versioned display layout artifact, and the API returns those coordinates. The browser renders with `preset` when all gene positions are present.

Benefits:

- Preserves the fCoSE compound graph representation.
- Moves expensive layout work out of the browser main thread.
- Fits SysNDD's durable async job pattern and existing `/app/cache` volume.
- Allows cache keys to include exact data, edge filtering, layout options, and package versions.

Costs:

- Requires a small Node runtime/helper in the API or worker image.
- Requires explicit artifact invalidation and prewarming.
- Needs careful parity between frontend element construction and backend layout element construction.

This is the recommended path.

### Option C: Internal Layout Sidecar

Add a separate internal Node service that computes fCoSE positions over HTTP for the API/worker.

Benefits:

- Keeps the R API image smaller and avoids mixing Node into the API image.
- Makes the layout engine independently restartable and scalable.

Costs:

- Adds another service, healthcheck, network boundary, deployment surface, and failure mode.
- More operational complexity than needed for a single derived artifact.

Keep this as a fallback if adding Node to the worker image becomes too awkward.

## Decision

Implement Option B: a worker-computed fCoSE display layout artifact with a frontend `preset` render path and client fCoSE fallback.

The API will continue to expose the network through `/api/analysis/network_edges`, but the response will distinguish:

- biological network data: nodes, edges, cluster assignment, category, degree.
- legacy API layout: igraph DrL/FR coordinates for fallback/debug.
- display layout: fCoSE-derived coordinates for the exact Cytoscape graph shown by the UI.

## Architecture

### Backend Artifact Flow

1. `gen_network_edges_mem(cluster_type, min_confidence)` keeps producing the base biological network.
2. `limit_network_edges_response(network_data, max_edges)` produces the exact displayed edge set and retained nodes.
3. A new R helper builds Cytoscape-style layout input from the limited network:
   - compound parent nodes: `cluster-<id>`.
   - gene nodes: `hgnc_id`, `parent`, `symbol`, `cluster`, `degree`, `category`, `size`, `color`.
   - edges: `source`, `target`, `confidence`, `width`.
4. A Node helper runs Cytoscape/fCoSE headlessly over that input.
5. The R worker validates the helper output and writes a content-addressed artifact under `/app/cache/network_layouts`.
6. `GET /api/analysis/network_edges` reads the artifact if present and attaches display coordinates plus metadata.
7. If the artifact is missing, stale, or invalid, the API returns the network without display coordinates and sets a recoverable metadata status. The frontend falls back to current fCoSE.

### Node Layout Helper

Location: `api/layout/gene-network-fcose-layout.mjs`

Input over stdin:

```json
{
  "schema_version": 1,
  "elements": [],
  "layout_options": {},
  "metadata": {
    "layout_key": "sha256",
    "node_count": 2259,
    "edge_count": 10000
  }
}
```

Output to stdout:

```json
{
  "schema_version": 1,
  "layout_engine": "cytoscape-fcose",
  "positions": {
    "HGNC:20581": { "x": -2363.4, "y": 4114.2 }
  },
  "metadata": {
    "layout_duration_ms": 3105,
    "node_count": 2259,
    "edge_count": 10000,
    "cytoscape_version": "3.33.3",
    "cytoscape_fcose_version": "2.2.0"
  }
}
```

The helper must write diagnostic logs to stderr only. stdout must remain valid JSON.

### Cache Key

The display layout artifact key must include:

- artifact type: `gene_network_cytoscape_layout`.
- schema version.
- layout version.
- `layout_engine = cytoscape-fcose`.
- Cytoscape version.
- cytoscape-fcose version.
- Node major version.
- `cluster_type`.
- `min_confidence`.
- `max_edges`.
- edge filtering policy: `confidence_desc_top_n`.
- deterministic edge tie-breakers.
- STRING version.
- sorted displayed node IDs.
- sorted displayed edges with confidence.
- cluster membership map.
- node size policy.
- compound parent policy.
- fCoSE options.

The key should be computed with `digest::digest(..., algo = "sha256", serialize = TRUE)` over a canonical R list.

### API Response Contract

The endpoint remains backward compatible. Existing clients can keep reading `nodes`, `edges`, and `metadata`.

Recommended additions:

```json
{
  "metadata": {
    "layout_algorithm": "drl",
    "layout_engine": "cytoscape-fcose",
    "display_layout_status": "available",
    "display_layout_key": "sha256",
    "display_layout_version": 1,
    "display_layout_duration_ms": 3105,
    "display_layout_node_count": 2259,
    "display_layout_edge_count": 10000
  }
}
```

When fCoSE display layout is available, `nodes[].x` and `nodes[].y` should carry the display coordinates used by the frontend. If we need to preserve legacy igraph coordinates for diagnostics, add explicit fields:

```json
{
  "x": -2363.4,
  "y": 4114.2,
  "layout_x": -2363.4,
  "layout_y": 4114.2,
  "igraph_x": 923,
  "igraph_y": 157
}
```

The plan should prefer explicit `layout_x/layout_y` internally, but it may keep `x/y` as the frontend convenience fields for compatibility.

### Worker And Prewarm

Add a durable async job type: `network_layout_prewarm`.

Default payload:

```json
{
  "cluster_type": "clusters",
  "min_confidence": 400,
  "max_edges": 10000,
  "layout_profile": "gene_network_fcose_v1",
  "force": false
}
```

The worker computes and stores the artifact. It should be non-destructive, idempotent, and safe to run repeatedly. If an artifact for the current key already exists and `force = false`, the job should return cache-hit metadata without recomputing.

The worker startup must bind the memoised analysis wrappers or otherwise use the same base network cache path as the API. Today `start_async_worker.R` loads modules and creates the DB pool, but it does not call `bootstrap_init_cache_version()` or `bootstrap_bind_memoised()`.

### Frontend Behavior

`useNetworkData.ts` should:

- use `getNetworkEdges()` from `app/src/api/analysis.ts`.
- convert complete finite coordinates into Cytoscape `position`.
- leave cluster parent nodes unpositioned because compound parents are derived from child bounds.
- expose enough metadata for diagnostics.

`useCytoscape.ts` should:

- choose `preset` when every non-parent node has finite `position.x` and `position.y`.
- keep the current fCoSE path when positions are missing or partial.
- make `resetLayout()` restore preset positions when available.
- keep browser-side "recompute fCoSE" behavior limited to the current reset fallback for this initial change.

This preserves graph styling and interactions because only the layout selection changes.

## Error Handling

- Missing artifact: API sets `display_layout_status = "missing"` and frontend falls back to fCoSE.
- Stale artifact: API ignores it if the key does not match the current graph and reports `display_layout_status = "missing"`.
- Node helper failure: worker records a failed job with stderr excerpt; API keeps serving the previous valid artifact if its key matches, otherwise fallback.
- Partial positions: frontend treats the graph as not prepositioned and runs fCoSE.
- Invalid JSON from helper: worker rejects the artifact and fails the job.
- Timeout: worker kills the helper process and fails the job.

## Performance And Resource Controls

- Run fCoSE layout only in worker/prewarm, not in public request path.
- Set a helper timeout, initially 120 seconds.
- Limit stdin/stdout payload size by using the same `max_edges` cap as the displayed graph.
- Use `styleEnabled: true` in headless Cytoscape so node dimensions match layout needs.
- Keep `pixelRatio` and renderer browser-only; the helper computes positions, not images.
- Do not run live external providers for this artifact. It only uses existing SysNDD/STRING-derived cached data.

## Testing Strategy

### Node Helper

- Unit test a tiny compound graph and assert finite positions for all gene nodes.
- Unit test invalid input returns a non-zero exit code and JSON error on stderr or a structured R error after wrapper validation.
- Unit test output includes package version metadata.

### R API

- Unit test canonical layout key changes when `max_edges`, fCoSE options, edge set, or node set changes.
- Unit test artifact read/write round trip.
- Unit test API attaches display coordinates only when all displayed gene nodes have positions.
- Unit test API reports missing layout status without computing fCoSE in the request path.

### Worker

- Unit test `network_layout_prewarm` cache-hit behavior.
- Unit test `force = true` recomputes the artifact.
- Integration smoke can run inside the dev stack after the Node helper is available.

### Frontend

- Unit test `useNetworkData` converts `x/y` into Cytoscape `position`.
- Unit test `useCytoscape.updateElements()` uses `preset` for fully positioned gene nodes.
- Unit test fallback to fCoSE for missing or partial positions.
- Unit test `resetLayout()` restores preset positions when available.

### Browser Verification

- Use Playwright on `/GeneNetworks`.
- Assert no 3-5 second fCoSE long task when display layout status is available.
- Assert route still renders, filters work, and clicking genes/clusters behaves as before.

## Rollout

1. Ship Node helper and R artifact code behind a disabled or non-public prewarm path.
2. Prewarm local and compare screenshots/perf against current browser fCoSE.
3. Enable frontend `preset` path only when `display_layout_status = "available"`.
4. Add admin/prewarm command and deployment documentation.
5. Deploy with fallback enabled. If artifact generation fails, users keep current behavior.
6. After confidence, make prewarm part of release/deploy runbook.

## Documentation

Update these when implementation changes behavior:

- `documentation/08-development.qmd`: local prewarm command and Node helper requirements.
- `documentation/09-deployment.qmd`: production prewarm/deploy behavior and cache invalidation.
- `AGENTS.md`: durable guidance that GeneNetworks fCoSE display layouts are worker-precomputed and browser `preset` is the default only when display layout metadata is available.

## Acceptance Criteria

- `/api/analysis/network_edges` remains backward compatible.
- A worker/admin prewarm job can compute a fCoSE display layout artifact for `cluster_type=clusters`, `min_confidence=400`, `max_edges=10000`.
- The artifact key changes when the displayed graph or layout profile changes.
- The frontend uses Cytoscape `preset` only when all displayed gene nodes have complete positions.
- Browser-side fCoSE remains a fallback.
- The default visual representation remains fCoSE-style compound graph layout.
- Playwright shows the main-thread layout stall is removed or materially reduced when the artifact is available.
- Relevant frontend, API, worker, and helper tests pass.
