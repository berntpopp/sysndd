import cytoscape from 'cytoscape';
import fcose from 'cytoscape-fcose';
import fcosePkg from 'cytoscape-fcose/package.json' with { type: 'json' };
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';

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
      let timeout;
      const finish = (callback, value) => {
        clearTimeout(timeout);
        callback(value);
      };

      timeout = setTimeout(() => {
        finish(reject, new Error('fCoSE layout timed out'));
      }, DEFAULT_TIMEOUT_MS);
      const layout = cy.layout({
        ...request.layout_options,
        fit: false,
        animate: false,
        stop: () => {
          finish(resolve);
        }
      });

      try {
        layout.run();
      } catch (error) {
        finish(reject, error);
      }
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
        cytoscape_version: cytoscape.version,
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

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
