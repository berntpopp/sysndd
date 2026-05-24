# Gene Network fCoSE Layout Artifact Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Precompute the GeneNetworks Cytoscape/fCoSE display layout in the backend worker, cache it as a versioned artifact, and let the browser render it with Cytoscape `preset` while keeping client fCoSE fallback.

**Architecture:** Keep `gen_network_edges_mem()` as the base network data source, add a Node-based fCoSE layout helper invoked by R worker code, store content-addressed display layout artifacts under `/app/cache/network_layouts`, and attach positions from the artifact in `/api/analysis/network_edges`. The frontend consumes complete positions with `preset`; incomplete or missing positions keep the current fCoSE path.

**Tech Stack:** R/Plumber, durable async jobs, cachem/digest/processx/jsonlite, Node 24, Cytoscape.js 3.33.3, cytoscape-fcose 2.2.0, Vue 3, TypeScript, Vitest, testthat, Playwright.

---

## File Structure

- Create: `api/layout/package.json`
  - Minimal Node package for the layout helper.

- Create: `api/layout/gene-network-fcose-layout.mjs`
  - Reads layout request JSON from stdin.
  - Runs Cytoscape/fCoSE headlessly.
  - Writes strict JSON to stdout.

- Create: `api/layout/gene-network-fcose-layout.test.mjs`
  - Node unit tests for the helper.

- Create: `api/functions/analysis-network-layout-functions.R`
  - Builds Cytoscape-style layout input.
  - Computes layout cache keys.
  - Reads/writes layout artifacts.
  - Invokes the Node helper through `processx`.
  - Attaches display positions to network responses.

- Modify: `api/bootstrap/load_modules.R`
  - Source `analysis-network-layout-functions.R` before `analysis-network-functions.R`.

- Modify: `api/functions/analysis-network-functions.R`
  - Sort edge limiting deterministically.
  - Attach fCoSE layout artifact when available.
  - Report display-layout status metadata.

- Modify: `api/functions/async-job-handlers.R`
  - Add `network_layout_prewarm` durable job handler.

- Modify: `api/start_async_worker.R`
  - Initialize and bind memoised analysis cache wrappers for worker use.

- Modify: `api/endpoints/jobs_endpoints.R`
  - Add admin endpoint for submitting `network_layout_prewarm`.

- Modify: `api/Dockerfile`
  - Add Node 24 and install the minimal `api/layout` dependencies into the API/worker image.

- Modify: `docker-compose.yml`
  - Bind-mount `./api/layout:/app/layout` for development worker/API containers.

- Modify: `app/src/api/analysis.ts`
  - Add layout metadata and node coordinate fields to typed network response.

- Modify: `app/src/composables/useNetworkData.ts`
  - Use typed `getNetworkEdges()`.
  - Convert complete coordinates into Cytoscape element `position`.

- Modify: `app/src/composables/useCytoscape.ts`
  - Use `preset` for fully positioned gene-node sets.
  - Keep fCoSE fallback.
  - Reset to preset positions when available.

- Create: `app/src/composables/useNetworkData.spec.ts`
  - Unit coverage for typed fetch and position conversion.

- Modify: `app/src/composables/useCytoscape.spec.ts`
  - Unit coverage for preset/fCoSE layout choice and reset behavior.

- Modify: `app/src/api/analysis.spec.ts`
  - Unit coverage for layout metadata typing and `max_edges` forwarding.

- Create: `api/tests/testthat/test-analysis-network-layout-functions.R`
  - R unit tests for keying, artifact IO, helper validation, and position attachment.

- Modify: `documentation/08-development.qmd`
  - Document local layout helper install, prewarm job, and verification commands.

- Modify: `documentation/09-deployment.qmd`
  - Document production prewarm and fallback behavior.

- Modify: `AGENTS.md`
  - Add durable guidance for GeneNetworks fCoSE display layout artifacts.

---

### Task 1: Add The Node fCoSE Layout Helper

**Files:**
- Create: `api/layout/package.json`
- Create: `api/layout/gene-network-fcose-layout.mjs`
- Create: `api/layout/gene-network-fcose-layout.test.mjs`

- [ ] **Step 1: Create the minimal Node package**

Create `api/layout/package.json`:

```json
{
  "name": "sysndd-network-layout",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test gene-network-fcose-layout.test.mjs"
  },
  "dependencies": {
    "cytoscape": "3.33.3",
    "cytoscape-fcose": "2.2.0"
  }
}
```

- [ ] **Step 2: Install dependencies and create the lockfile**

Run:

```bash
cd api/layout && npm install
```

Expected: `api/layout/package-lock.json` is created and `npm test` can run.

- [ ] **Step 3: Create the layout helper**

Create `api/layout/gene-network-fcose-layout.mjs` with this public behavior:

```js
import cytoscape from 'cytoscape';
import fcose from 'cytoscape-fcose';
import cytoscapePkg from 'cytoscape/package.json' with { type: 'json' };
import fcosePkg from 'cytoscape-fcose/package.json' with { type: 'json' };
import { performance } from 'node:perf_hooks';

cytoscape.warnings(false);
cytoscape.use(fcose);

const DEFAULT_TIMEOUT_MS = 120000;

export function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => {
      data += chunk;
    });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

export function validateRequest(request) {
  if (!request || request.schema_version !== 1) {
    throw new Error('layout request schema_version must be 1');
  }
  if (!Array.isArray(request.elements)) {
    throw new Error('layout request elements must be an array');
  }
  if (!request.layout_options || request.layout_options.name !== 'fcose') {
    throw new Error('layout_options.name must be fcose');
  }
  return request;
}

export function collectGenePositions(cy) {
  const positions = {};
  cy.nodes('[!isClusterParent]').forEach((node) => {
    const position = node.position();
    if (!Number.isFinite(position.x) || !Number.isFinite(position.y)) {
      throw new Error(`non-finite position for ${node.id()}`);
    }
    positions[node.id()] = {
      x: Math.round(position.x * 1000) / 1000,
      y: Math.round(position.y * 1000) / 1000
    };
  });
  return positions;
}

export async function computeLayout(request) {
  validateRequest(request);
  const started = performance.now();
  const cy = cytoscape({
    headless: true,
    styleEnabled: true,
    elements: request.elements,
    style: request.style || [],
    layout: { name: 'preset' }
  });

  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('fCoSE layout timed out')), DEFAULT_TIMEOUT_MS);
      const layout = cy.layout({
        ...request.layout_options,
        fit: false,
        animate: false,
        stop: () => {
          clearTimeout(timeout);
          resolve();
        }
      });
      layout.run();
    });

    const positions = collectGenePositions(cy);
    return {
      schema_version: 1,
      layout_engine: 'cytoscape-fcose',
      positions,
      metadata: {
        ...(request.metadata || {}),
        layout_duration_ms: Math.round(performance.now() - started),
        node_count: Object.keys(positions).length,
        edge_count: cy.edges().length,
        cytoscape_version: cytoscapePkg.version,
        cytoscape_fcose_version: fcosePkg.version,
        node_version: process.versions.node
      }
    };
  } finally {
    cy.destroy();
  }
}

export async function main() {
  try {
    const raw = await readStdin();
    const request = JSON.parse(raw);
    const response = await computeLayout(request);
    process.stdout.write(`${JSON.stringify(response)}\n`);
  } catch (error) {
    process.stderr.write(`${JSON.stringify({ error: error.message })}\n`);
    process.exitCode = 1;
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
```

- [ ] **Step 4: Create Node unit tests**

Create `api/layout/gene-network-fcose-layout.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { computeLayout } from './gene-network-fcose-layout.mjs';

const baseRequest = {
  schema_version: 1,
  metadata: { layout_key: 'test-key' },
  style: [
    { selector: 'node[!isClusterParent]', style: { width: 20, height: 20 } },
    { selector: 'node[?isClusterParent]', style: { padding: '30px' } },
    { selector: 'edge', style: { width: 1 } }
  ],
  elements: [
    { data: { id: 'cluster-1', isClusterParent: true } },
    { data: { id: 'HGNC:1', parent: 'cluster-1', symbol: 'AAA', size: 20 } },
    { data: { id: 'HGNC:2', parent: 'cluster-1', symbol: 'BBB', size: 20 } },
    { data: { id: 'e1', source: 'HGNC:1', target: 'HGNC:2', width: 1 } }
  ],
  layout_options: {
    name: 'fcose',
    quality: 'draft',
    randomize: true,
    animate: false,
    nodeDimensionsIncludeLabels: false,
    idealEdgeLength: 80,
    nodeRepulsion: 8000,
    edgeElasticity: 0.45,
    gravity: 0.25,
    numIter: 100,
    boundingBox: { x1: 0, y1: 0, w: 1200, h: 900 }
  }
};

test('computeLayout returns finite gene positions and version metadata', async () => {
  const result = await computeLayout(baseRequest);
  assert.equal(result.schema_version, 1);
  assert.equal(result.layout_engine, 'cytoscape-fcose');
  assert.deepEqual(Object.keys(result.positions).sort(), ['HGNC:1', 'HGNC:2']);
  assert.equal(Number.isFinite(result.positions['HGNC:1'].x), true);
  assert.equal(Number.isFinite(result.positions['HGNC:1'].y), true);
  assert.equal(typeof result.metadata.cytoscape_version, 'string');
  assert.equal(typeof result.metadata.cytoscape_fcose_version, 'string');
});

test('computeLayout rejects invalid schema', async () => {
  await assert.rejects(() => computeLayout({ ...baseRequest, schema_version: 2 }), /schema_version/);
});
```

- [ ] **Step 5: Run helper tests**

Run:

```bash
cd api/layout && npm test
```

Expected: both Node tests pass.

- [ ] **Step 6: Commit**

```bash
git add api/layout/package.json api/layout/package-lock.json api/layout/gene-network-fcose-layout.mjs api/layout/gene-network-fcose-layout.test.mjs
git commit -m "feat: add gene network fcose layout helper"
```

---

### Task 2: Add R Layout Artifact Helpers

**Files:**
- Create: `api/functions/analysis-network-layout-functions.R`
- Modify: `api/bootstrap/load_modules.R`
- Create: `api/tests/testthat/test-analysis-network-layout-functions.R`

- [ ] **Step 1: Add focused R tests first**

Create `api/tests/testthat/test-analysis-network-layout-functions.R` with tests for:

```r
test_that("network layout key changes with max_edges and edge set", {
  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("AAA", "BBB"),
      cluster = c(1, 1),
      degree = c(1L, 1L),
      category = c("Definitive", "Definitive")
    ),
    edges = tibble::tibble(
      source = "HGNC:1",
      target = "HGNC:2",
      confidence = 0.99
    ),
    metadata = list(string_version = "11.5", min_confidence = 400)
  )

  key_100 <- network_layout_cache_key(network, cluster_type = "clusters", min_confidence = 400L, max_edges = 100L)
  key_200 <- network_layout_cache_key(network, cluster_type = "clusters", min_confidence = 400L, max_edges = 200L)
  expect_type(key_100, "character")
  expect_equal(nchar(key_100), 64L)
  expect_false(identical(key_100, key_200))
})

test_that("cytoscape layout input contains compound parents and gene node sizes", {
  network <- list(
    nodes = tibble::tibble(
      hgnc_id = c("HGNC:1", "HGNC:2"),
      symbol = c("AAA", "BBB"),
      cluster = c(1, 1),
      degree = c(4L, 1L),
      category = c("Definitive", "Moderate")
    ),
    edges = tibble::tibble(source = "HGNC:1", target = "HGNC:2", confidence = 0.8),
    metadata = list()
  )

  request <- build_network_fcose_layout_request(network, layout_key = "abc")
  ids <- vapply(request$elements, function(element) element$data$id, character(1))
  expect_true("cluster-1" %in% ids)
  expect_true("HGNC:1" %in% ids)
  gene <- request$elements[[which(ids == "HGNC:1")]]
  expect_equal(gene$data$parent, "cluster-1")
  expect_equal(gene$data$size, 15)
  expect_equal(request$layout_options$name, "fcose")
})

test_that("display positions attach only when complete", {
  network <- list(
    nodes = tibble::tibble(hgnc_id = c("HGNC:1", "HGNC:2"), x = c(1, 2), y = c(3, 4)),
    edges = tibble::tibble(),
    metadata = list()
  )
  artifact <- list(
    positions = list("HGNC:1" = list(x = 10, y = 20), "HGNC:2" = list(x = 30, y = 40)),
    metadata = list(layout_duration_ms = 10)
  )
  updated <- attach_network_display_layout(network, artifact, layout_key = "abc")
  expect_equal(updated$nodes$x, c(10, 30))
  expect_equal(updated$nodes$y, c(20, 40))
  expect_equal(updated$metadata$display_layout_status, "available")
})
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-analysis-network-layout-functions.R')"
```

Expected: FAIL because helper functions are not defined.

- [ ] **Step 3: Create `analysis-network-layout-functions.R`**

Create `api/functions/analysis-network-layout-functions.R` with these exported helpers:

```r
NETWORK_LAYOUT_SCHEMA_VERSION <- 1L
NETWORK_LAYOUT_VERSION <- 1L
NETWORK_LAYOUT_PROFILE <- "gene_network_fcose_v1"

network_layout_options <- function() {
  list(
    name = "fcose",
    quality = "default",
    randomize = TRUE,
    animate = FALSE,
    nodeDimensionsIncludeLabels = FALSE,
    fit = FALSE,
    padding = 30,
    idealEdgeLength = 80,
    nodeRepulsion = 8000,
    edgeElasticity = 0.45,
    gravity = 0.25,
    numIter = 2500,
    boundingBox = list(x1 = 0, y1 = 0, w = 1200, h = 900)
  )
}

network_layout_cache_dir <- function(cache_dir = Sys.getenv("NETWORK_LAYOUT_CACHE_DIR", "/app/cache/network_layouts")) {
  cache_dir
}

network_layout_cache_path <- function(layout_key, cache_dir = network_layout_cache_dir()) {
  file.path(cache_dir, paste0(layout_key, ".rds"))
}
```

Implement `build_network_fcose_layout_request(network_data, layout_key)` so it mirrors `useNetworkData.ts`:

- parent IDs are `cluster-<mainCluster>`.
- child IDs are `hgnc_id`.
- child `parent` is `cluster-<mainCluster>`.
- child `size` is `max(15, sqrt(degree) * 6)`.
- edge width is `max(0.5, confidence * 3)`.
- style includes parent padding, gene width/height from `data(size)`, and edge width from `data(width)`.

Implement `network_layout_cache_key(network_data, cluster_type, min_confidence, max_edges)` with `digest::digest(..., algo = "sha256", serialize = TRUE)` over a canonical list containing all dimensions from the design spec.

Implement:

```r
read_network_layout_artifact <- function(layout_key, cache_dir = network_layout_cache_dir()) { ... }
write_network_layout_artifact <- function(layout_key, artifact, cache_dir = network_layout_cache_dir()) { ... }
validate_network_layout_artifact <- function(artifact, expected_gene_ids) { ... }
attach_network_display_layout <- function(network_data, artifact, layout_key) { ... }
run_network_fcose_layout_helper <- function(request, helper_path = Sys.getenv("NETWORK_LAYOUT_HELPER", "/app/layout/gene-network-fcose-layout.mjs")) { ... }
generate_network_display_layout_artifact <- function(network_data, cluster_type, min_confidence, max_edges, force = FALSE) { ... }
```

`run_network_fcose_layout_helper()` must call:

```r
processx::run(
  command = "node",
  args = helper_path,
  input = jsonlite::toJSON(request, auto_unbox = TRUE, null = "null", digits = NA),
  timeout = as.numeric(Sys.getenv("NETWORK_LAYOUT_HELPER_TIMEOUT_SECONDS", "120")),
  error_on_status = FALSE
)
```

It must parse stdout as JSON only when exit status is 0. On non-zero status, stop with a message containing stderr.

- [ ] **Step 4: Source the new helper file**

In `api/bootstrap/load_modules.R`, add `"functions/analysis-network-layout-functions.R"` immediately before `"functions/analysis-network-functions.R"`.

- [ ] **Step 5: Run the R helper tests**

Run:

```bash
cd api && Rscript --no-init-file -e "source('bootstrap/init_libraries.R'); bootstrap_init_libraries(); source('functions/analysis-network-layout-functions.R'); testthat::test_file('tests/testthat/test-analysis-network-layout-functions.R')"
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add api/functions/analysis-network-layout-functions.R api/bootstrap/load_modules.R api/tests/testthat/test-analysis-network-layout-functions.R
git commit -m "feat: add gene network layout artifact helpers"
```

---

### Task 3: Integrate Display Layout Metadata Into `network_edges`

**Files:**
- Modify: `api/functions/analysis-network-functions.R`
- Modify: `api/tests/testthat/test-analysis-network-layout-functions.R`

- [ ] **Step 1: Add test coverage for request-time cache-only attachment**

Extend `test-analysis-network-layout-functions.R` with:

```r
test_that("apply cached display layout reports missing without computing", {
  network <- list(
    nodes = tibble::tibble(hgnc_id = c("HGNC:1"), x = 1, y = 2),
    edges = tibble::tibble(),
    metadata = list()
  )
  updated <- apply_cached_network_display_layout(
    network,
    cluster_type = "clusters",
    min_confidence = 400L,
    max_edges = 10000L,
    cache_dir = tempfile("missing-layout-cache")
  )
  expect_equal(updated$metadata$display_layout_status, "missing")
  expect_equal(updated$nodes$x, 1)
  expect_equal(updated$nodes$y, 2)
})
```

- [ ] **Step 2: Implement cache-only attachment**

In `api/functions/analysis-network-layout-functions.R`, add:

```r
apply_cached_network_display_layout <- function(network_data,
                                                cluster_type,
                                                min_confidence,
                                                max_edges,
                                                cache_dir = network_layout_cache_dir()) {
  layout_key <- network_layout_cache_key(
    network_data,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )
  artifact <- read_network_layout_artifact(layout_key, cache_dir = cache_dir)
  if (is.null(artifact)) {
    network_data$metadata$layout_engine <- network_data$metadata$layout_algorithm %||% "unknown"
    network_data$metadata$display_layout_status <- "missing"
    network_data$metadata$display_layout_key <- layout_key
    return(network_data)
  }
  attach_network_display_layout(network_data, artifact, layout_key = layout_key)
}
```

Define a file-local null-coalescing helper so this source file is independent of source-order surprises:

```r
.network_layout_or <- function(x, y) {
  if (is.null(x)) y else x
}
```

- [ ] **Step 3: Make edge limiting deterministic**

In `limit_network_edges_response()`, replace:

```r
network_data$edges <- network_data$edges[order(-network_data$edges$confidence), ]
```

with:

```r
network_data$edges <- network_data$edges[
  order(-network_data$edges$confidence, network_data$edges$source, network_data$edges$target),
]
```

- [ ] **Step 4: Attach cached display layout after edge limiting**

In `generate_network_edges_response()`, after:

```r
network_data <- limit_network_edges_response(network_data, max_edges = max_edges)
```

add:

```r
if (exists("apply_cached_network_display_layout", mode = "function")) {
  network_data <- apply_cached_network_display_layout(
    network_data,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )
}
```

- [ ] **Step 5: Run focused R tests**

Run:

```bash
cd api && Rscript --no-init-file -e "source('bootstrap/init_libraries.R'); bootstrap_init_libraries(); source('functions/analysis-network-layout-functions.R'); source('functions/analysis-network-functions.R'); testthat::test_file('tests/testthat/test-analysis-network-layout-functions.R')"
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add api/functions/analysis-network-functions.R api/functions/analysis-network-layout-functions.R api/tests/testthat/test-analysis-network-layout-functions.R
git commit -m "feat: attach cached gene network display layout"
```

---

### Task 4: Add Durable `network_layout_prewarm` Worker Job

**Files:**
- Modify: `api/functions/async-job-handlers.R`
- Modify: `api/start_async_worker.R`
- Modify: `api/endpoints/jobs_endpoints.R`

- [ ] **Step 1: Bind memoised cache wrappers in the async worker**

In `api/start_async_worker.R`, after `bootstrap_load_modules()` and before worker startup, add:

```r
source("bootstrap/init_cache.R", local = FALSE)
bootstrap_init_cache_version()
bootstrap_bind_memoised(envir = .GlobalEnv)
```

Expected behavior: worker can call `gen_network_edges_mem()` and reuse `/app/cache`.

- [ ] **Step 2: Add the job runner**

In `api/functions/async-job-handlers.R`, add a runner near other `.async_job_run_*` functions:

```r
.async_job_run_network_layout_prewarm <- function(job, payload, state, worker_config) {
  cluster_type <- payload$cluster_type %||% "clusters"
  min_confidence <- as.integer(payload$min_confidence %||% 400L)
  max_edges <- as.integer(payload$max_edges %||% 10000L)
  force <- isTRUE(payload$force)

  network_data <- generate_network_edges_response(
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges
  )

  artifact <- generate_network_display_layout_artifact(
    network_data,
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges,
    force = force
  )

  list(
    status = "completed",
    cluster_type = cluster_type,
    min_confidence = min_confidence,
    max_edges = max_edges,
    layout_key = artifact$metadata$layout_key,
    cache_hit = isTRUE(artifact$metadata$cache_hit),
    node_count = artifact$metadata$node_count,
    edge_count = artifact$metadata$edge_count,
    layout_duration_ms = artifact$metadata$layout_duration_ms %||% NA_integer_
  )
}
```

`generate_network_display_layout_artifact()` must build from `network_data$nodes` and `network_data$edges` after removing display-only fields `layout_x`, `layout_y`, `display_layout_status`, and `display_layout_key` from its internal key/input object. This prevents a previous layout artifact from changing the key for the next artifact.

- [ ] **Step 3: Register the job handler**

In `async_job_handler_registry`, add:

```r
network_layout_prewarm = list(
  cancel_mode = "best_effort",
  run = .async_job_run_network_layout_prewarm,
  after_success = .async_job_after_success_noop
),
```

- [ ] **Step 4: Add a submit endpoint**

In `api/endpoints/jobs_endpoints.R`, add an admin-authenticated endpoint following existing job submit patterns:

```r
#* Submit gene network layout prewarm job
#* @post /network_layout/submit
function(req, res) {
  require_role(req, res, "Administrator")
  payload <- req$argsBody
  params <- list(
    cluster_type = payload$cluster_type %||% "clusters",
    min_confidence = as.integer(payload$min_confidence %||% 400L),
    max_edges = as.integer(payload$max_edges %||% 10000L),
    force = isTRUE(payload$force)
  )

  submitted <- async_job_service_submit(
    job_type = "network_layout_prewarm",
    request_payload = params,
    submitted_by = req$user_id %||% NULL
  )

  job <- submitted$job
  job_id <- job$job_id[[1]]
  status_url <- paste0("/api/jobs/", job_id, "/status")

  res$status <- if (isTRUE(submitted$duplicate)) 409L else 202L
  res$setHeader("Location", status_url)
  res$setHeader("Retry-After", "10")

  list(
    job_id = job_id,
    status = if (isTRUE(submitted$duplicate)) "already_running" else "accepted",
    job_status = job$status[[1]],
    status_url = status_url
  )
}
```

- [ ] **Step 5: Run API parse/source smoke**

Run:

```bash
cd api && Rscript --no-init-file -e "source('bootstrap/init_libraries.R'); bootstrap_init_libraries(); source('bootstrap/load_modules.R'); bootstrap_load_modules(); source('functions/async-job-handlers.R'); stopifnot(!is.null(async_job_get_handler('network_layout_prewarm')))"
```

Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add api/functions/async-job-handlers.R api/start_async_worker.R api/endpoints/jobs_endpoints.R
git commit -m "feat: add gene network layout prewarm job"
```

---

### Task 5: Add Runtime Packaging For The Layout Helper

**Files:**
- Modify: `api/Dockerfile`
- Modify: `docker-compose.yml`
- Modify: `.dockerignore`

- [ ] **Step 1: Update API Docker image with Node 24**

In `api/Dockerfile`, add Node 24 installation in the base stage using a reproducible package source. Keep it near the system dependencies section and avoid installing development-only frontend dependencies.

Use this pattern:

```dockerfile
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && node --version \
    && npm --version \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 2: Install minimal layout dependencies in the image**

After API source copy steps, add:

```dockerfile
COPY layout/package.json layout/package-lock.json /app/layout/
RUN cd /app/layout && npm ci --omit=dev
COPY layout/gene-network-fcose-layout.mjs /app/layout/gene-network-fcose-layout.mjs
```

Keep `api/layout/gene-network-fcose-layout.test.mjs` out of the production copy. Image build tests are outside this implementation plan.

- [ ] **Step 3: Bind-mount layout helper in development**

In `docker-compose.yml`, under API and worker service volumes, add:

```yaml
- ./api/layout:/app/layout
```

- [ ] **Step 4: Ignore host node_modules**

Add this line to `.dockerignore`:

```gitignore
api/layout/node_modules
```

- [ ] **Step 5: Build API image locally**

Run:

```bash
docker compose build api
```

Expected: build succeeds and `node --version` reports major `24` in the image logs.

- [ ] **Step 6: Commit**

```bash
git add api/Dockerfile docker-compose.yml .dockerignore
git commit -m "build: package gene network layout helper"
```

---

### Task 6: Add Frontend Preset Layout Consumption

**Files:**
- Modify: `app/src/api/analysis.ts`
- Modify: `app/src/api/analysis.spec.ts`
- Modify: `app/src/composables/useNetworkData.ts`
- Create: `app/src/composables/useNetworkData.spec.ts`
- Modify: `app/src/composables/useCytoscape.ts`
- Modify: `app/src/composables/useCytoscape.spec.ts`

- [ ] **Step 1: Extend typed API models**

In `app/src/api/analysis.ts`, update `NetworkNode`:

```ts
export interface NetworkNode {
  hgnc_id: string;
  symbol: string;
  cluster: string | number;
  degree: number;
  category?: string;
  x?: number;
  y?: number;
  layout_x?: number;
  layout_y?: number;
  igraph_x?: number;
  igraph_y?: number;
  [key: string]: unknown;
}
```

Update `NetworkMetadata` with:

```ts
layout_algorithm?: string;
layout_engine?: string;
display_layout_status?: 'available' | 'missing' | 'invalid' | 'error';
display_layout_key?: string;
display_layout_version?: number;
display_layout_duration_ms?: number;
display_layout_node_count?: number;
display_layout_edge_count?: number;
```

- [ ] **Step 2: Update API client test**

In `app/src/api/analysis.spec.ts`, add `max_edges` to the existing network test:

```ts
await getNetworkEdges({ cluster_type: 'subclusters', min_confidence: '700', max_edges: '3000' });
expect(q.get('max_edges')).toBe('3000');
```

Also add an `ok` response node with `x` and `y` so the type contract is exercised.

- [ ] **Step 3: Add `useNetworkData` tests**

Create `app/src/composables/useNetworkData.spec.ts` with mocked `getNetworkEdges()`:

```ts
import { describe, expect, it, vi } from 'vitest';
import { nextTick } from 'vue';
import { useNetworkData } from './useNetworkData';

vi.mock('@/api/analysis', () => ({
  getNetworkEdges: vi.fn().mockResolvedValue({
    nodes: [
      { hgnc_id: 'HGNC:1', symbol: 'AAA', cluster: 1, degree: 4, category: 'Definitive', x: 10, y: 20 },
      { hgnc_id: 'HGNC:2', symbol: 'BBB', cluster: 1, degree: 1, category: 'Moderate', x: 30, y: 40 }
    ],
    edges: [{ source: 'HGNC:1', target: 'HGNC:2', confidence: 0.8 }],
    metadata: {
      node_count: 2,
      edge_count: 1,
      cluster_count: 1,
      total_edges: 1,
      edges_filtered: false,
      elapsed_seconds: 0.1,
      display_layout_status: 'available'
    }
  })
}));

describe('useNetworkData', () => {
  it('converts finite API coordinates into Cytoscape positions', async () => {
    const state = useNetworkData();
    await state.fetchNetworkData('clusters');
    await nextTick();
    const gene = state.cytoscapeElements.value.find((element) => element.data?.id === 'HGNC:1');
    expect(gene?.position).toEqual({ x: 10, y: 20 });
  });
});
```

- [ ] **Step 4: Switch `useNetworkData` to typed client and positions**

In `app/src/composables/useNetworkData.ts`, replace raw axios import/use with:

```ts
import { getNetworkEdges } from '@/api/analysis';
```

In `fetchNetworkData()`, replace `axios.get` with:

```ts
const data = await getNetworkEdges({
  cluster_type: clusterType,
  max_edges: String(maxEdges),
});
networkData.value = data as NetworkResponse;
```

In node transformation, add:

```ts
const hasPosition = Number.isFinite(node.x) && Number.isFinite(node.y);
return {
  data: { ... },
  ...(hasPosition ? { position: { x: Number(node.x), y: Number(node.y) } } : {}),
};
```

- [ ] **Step 5: Add Cytoscape layout choice helpers**

In `app/src/composables/useCytoscape.ts`, add:

```ts
function isGeneNodeElement(element: ElementDefinition): boolean {
  return Boolean(element.data?.id) && element.data?.isClusterParent !== true && !element.data?.source && !element.data?.target;
}

function hasFinitePosition(element: ElementDefinition): boolean {
  return Number.isFinite(element.position?.x) && Number.isFinite(element.position?.y);
}

function shouldUsePresetLayout(elements: ElementDefinition[]): boolean {
  const geneNodes = elements.filter(isGeneNodeElement);
  return geneNodes.length > 0 && geneNodes.every(hasFinitePosition);
}

function presetLayoutOptions() {
  return { name: 'preset', fit: true, padding: 30, animate: false };
}
```

Track last positioned elements inside `useCytoscape()`:

```ts
let lastElements: ElementDefinition[] = [];
let lastUsedPreset = false;
```

In `updateElements()`, set `lastElements = elements`, choose preset when complete, otherwise use the existing fCoSE options.

In `resetLayout()`, if `lastUsedPreset` is true, rerun `presetLayoutOptions()` instead of fCoSE.

- [ ] **Step 6: Extend Cytoscape tests**

In `app/src/composables/useCytoscape.spec.ts`, add tests that inspect `mocks.core.layout` calls:

```ts
it('uses preset layout when all gene nodes have positions', () => {
  const container = document.createElement('div');
  const { initializeCytoscape, updateElements } = useCytoscape({ container: ref(container) });
  initializeCytoscape();
  updateElements([
    { data: { id: 'cluster-1', isClusterParent: true } },
    { data: { id: 'HGNC:1', parent: 'cluster-1' }, position: { x: 1, y: 2 } },
    { data: { id: 'HGNC:2', parent: 'cluster-1' }, position: { x: 3, y: 4 } },
    { data: { id: 'e1', source: 'HGNC:1', target: 'HGNC:2' } }
  ]);
  expect(mocks.core.layout).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'preset' }));
});

it('falls back to fcose when a gene node lacks position', () => {
  const container = document.createElement('div');
  const { initializeCytoscape, updateElements } = useCytoscape({ container: ref(container) });
  initializeCytoscape();
  updateElements([
    { data: { id: 'HGNC:1' }, position: { x: 1, y: 2 } },
    { data: { id: 'HGNC:2' } }
  ]);
  expect(mocks.core.layout).toHaveBeenLastCalledWith(expect.objectContaining({ name: 'fcose' }));
});
```

- [ ] **Step 7: Run frontend tests and type-check**

Run:

```bash
cd app && npx vitest run src/api/analysis.spec.ts src/composables/useNetworkData.spec.ts src/composables/useCytoscape.spec.ts
cd app && npm run type-check
```

Expected: targeted tests and type-check pass.

- [ ] **Step 8: Commit**

```bash
git add app/src/api/analysis.ts app/src/api/analysis.spec.ts app/src/composables/useNetworkData.ts app/src/composables/useNetworkData.spec.ts app/src/composables/useCytoscape.ts app/src/composables/useCytoscape.spec.ts
git commit -m "feat: render precomputed gene network layouts"
```

---

### Task 7: Verify End-To-End Layout Artifact Flow

**Files:**
- No expected file edits.

- [ ] **Step 1: Start stack**

Run:

```bash
make dev
```

Expected: app is reachable at `http://localhost:5173/GeneNetworks`.

- [ ] **Step 2: Generate a live layout-helper request**

Run:

```bash
cd api && Rscript --no-init-file -e "source('bootstrap/init_libraries.R'); bootstrap_init_libraries(); source('bootstrap/load_modules.R'); bootstrap_load_modules(); network <- generate_network_edges_response(cluster_type = 'clusters', min_confidence = 400L, max_edges = 10000L); request <- build_network_fcose_layout_request(network, layout_key = 'smoke'); writeLines(jsonlite::toJSON(request, auto_unbox = TRUE, null = 'null', digits = NA), '/tmp/sysndd-network-layout-request.json')"
```

Expected: `/tmp/sysndd-network-layout-request.json` exists and contains `layout_options.name = "fcose"`.

- [ ] **Step 3: Run local helper against the live request**

Run:

```bash
node api/layout/gene-network-fcose-layout.mjs < /tmp/sysndd-network-layout-request.json > /tmp/sysndd-network-layout-response.json
jq '.layout_engine, (.positions | keys | length), .metadata.layout_duration_ms' /tmp/sysndd-network-layout-response.json
```

Expected: helper produces JSON with `layout_engine = "cytoscape-fcose"` and positions for all gene nodes.

- [ ] **Step 4: Submit prewarm job**

Using an admin session, submit:

```bash
JOB_ID=$(curl -sS -X POST http://localhost/api/jobs/network_layout/submit \
  -H 'Content-Type: application/json' \
  -b /tmp/sysndd-admin-cookies.txt \
  -d '{"cluster_type":"clusters","min_confidence":400,"max_edges":10000,"force":true}' \
  | jq -r '.job_id')
test -n "$JOB_ID" && echo "$JOB_ID" | tee /tmp/sysndd-network-layout-job-id
```

Expected: `JOB_ID` prints a non-empty job id.

- [ ] **Step 5: Poll job status**

Run:

```bash
JOB_ID=$(cat /tmp/sysndd-network-layout-job-id)
curl -sS "http://localhost/api/jobs/${JOB_ID}/status" -b /tmp/sysndd-admin-cookies.txt
```

Expected: job completes with `layout_key`, `node_count`, and `edge_count`.

- [ ] **Step 6: Verify API layout metadata**

Run:

```bash
curl -sS 'http://localhost/api/analysis/network_edges?cluster_type=clusters&max_edges=10000' \
  | jq '.metadata.display_layout_status, .metadata.layout_engine, (.nodes[0] | {hgnc_id,x,y})'
```

Expected:

```text
"available"
"cytoscape-fcose"
{
  "hgnc_id": "...",
  "x": <number>,
  "y": <number>
}
```

- [ ] **Step 7: Run a Playwright route smoke**

Run:

```bash
cd app && node <<'NODE'
const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const started = Date.now();
  await page.goto('http://localhost:5173/GeneNetworks', { waitUntil: 'domcontentloaded' });
  const response = await page.waitForResponse(
    (res) => res.url().includes('/api/analysis/network_edges') && res.status() === 200,
    { timeout: 60000 }
  );
  const payload = await response.json();
  if (payload.metadata.display_layout_status !== 'available') {
    throw new Error(`display layout status was ${payload.metadata.display_layout_status}`);
  }
  await page.waitForTimeout(1000);
  console.log(JSON.stringify({
    status: payload.metadata.display_layout_status,
    layoutEngine: payload.metadata.layout_engine,
    elapsedMs: Date.now() - started
  }));
  await browser.close();
})().catch(async (error) => {
  console.error(error);
  process.exit(1);
});
NODE
```

Expected: script prints JSON with `status = "available"` and `layoutEngine = "cytoscape-fcose"`.

---

### Task 8: Update Durable Documentation

**Files:**
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `AGENTS.md`

- [ ] **Step 1: Update development docs**

In `documentation/08-development.qmd`, add a GeneNetworks layout subsection with:

````markdown
### GeneNetworks fCoSE Layout Prewarm

The GeneNetworks browser graph uses precomputed Cytoscape/fCoSE display positions when available. The worker computes the layout artifact with the Node helper in `api/layout/` and stores it under `/app/cache/network_layouts`.

For local verification:

```bash
cd api/layout && npm test
make dev
curl -sS 'http://localhost/api/analysis/network_edges?cluster_type=clusters&max_edges=10000' | jq '.metadata.display_layout_status'
```

If the status is `missing`, the frontend falls back to browser fCoSE.
````

- [ ] **Step 2: Update deployment docs**

In `documentation/09-deployment.qmd`, document:

- the worker image contains Node 24 and the minimal layout helper dependencies.
- `network_layout_prewarm` should run after data/cache refreshes.
- public requests do not compute fCoSE in the request path.
- fallback is browser fCoSE if the artifact is absent.
- cache invalidation depends on layout key and `CACHE_VERSION`.

- [ ] **Step 3: Update AGENTS.md**

Add a short invariant under the analysis or background jobs section:

```markdown
GeneNetworks display layouts are derived analysis artifacts. To preserve the current fCoSE compound-graph representation without browser main-thread stalls, workers precompute Cytoscape/fCoSE positions for the exact displayed network and the frontend renders them with Cytoscape `preset`. Public API requests must not run fCoSE synchronously; missing artifacts fall back to browser fCoSE. Keep layout cache keys data-aware: include displayed node/edge set, `cluster_type`, `min_confidence`, `max_edges`, layout options, and Cytoscape/fCoSE versions.
```

- [ ] **Step 4: Run docs/code checks**

Run:

```bash
git diff --check
make code-quality-audit
```

Expected: both pass.

- [ ] **Step 5: Commit**

```bash
git add documentation/08-development.qmd documentation/09-deployment.qmd AGENTS.md
git commit -m "docs: document gene network layout artifacts"
```

---

### Task 9: Final Verification

**Files:**
- No expected edits.

- [ ] **Step 1: Run focused frontend verification**

```bash
cd app && npx vitest run src/api/analysis.spec.ts src/composables/useNetworkData.spec.ts src/composables/useCytoscape.spec.ts
cd app && npm run type-check
```

Expected: pass.

- [ ] **Step 2: Run focused API verification**

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-analysis-network-layout-functions.R')"
```

Expected: pass.

- [ ] **Step 3: Run helper verification**

```bash
cd api/layout && npm test
```

Expected: pass.

- [ ] **Step 4: Run repo quality gate**

```bash
make code-quality-audit
```

Expected: pass.

- [ ] **Step 5: Run app route smoke**

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:5173/GeneNetworks
```

Expected: `200`.

- [ ] **Step 6: Review diff for boundaries**

Check:

```bash
git status --short
git diff --stat
rg -n "from 'axios'|from \"axios\"" app/src/composables/useNetworkData.ts app/src/components/analyses app/src/views || true
```

Expected:

- only intentional files are changed.
- no raw axios remains in `useNetworkData.ts`.
- large files were not expanded unnecessarily beyond the code-quality ratchet.

- [ ] **Step 7: Final commit or handoff**

If all checks pass:

```bash
git status --short
```

Then hand off with:

- changed files summary.
- verification commands and outcomes.
- residual risk: first production deploy depends on successful worker prewarm.
