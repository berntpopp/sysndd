import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import {
  collectGenePositions,
  computeLayout,
  validateRequest
} from './gene-network-fcose-layout.mjs';

const helperPath = fileURLToPath(new URL('./gene-network-fcose-layout.mjs', import.meta.url));

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

test('validateRequest accepts schema version 1 fCoSE requests', () => {
  assert.equal(validateRequest(baseRequest), baseRequest);
});

test('validateRequest rejects invalid schema versions', () => {
  assert.throws(
    () => validateRequest({ ...baseRequest, schema_version: 2 }),
    /schema_version/
  );
});

test('validateRequest rejects non-fCoSE layout requests', () => {
  assert.throws(
    () => validateRequest({ ...baseRequest, layout_options: { name: 'grid' } }),
    /layout_options\.name/
  );
});

test('computeLayout returns finite gene positions and version metadata', async () => {
  const result = await computeLayout(baseRequest);

  assert.equal(result.schema_version, 1);
  assert.equal(result.layout_engine, 'cytoscape-fcose');
  assert.deepEqual(Object.keys(result.positions).sort(), ['HGNC:1', 'HGNC:2']);
  assert.equal(Number.isFinite(result.positions['HGNC:1'].x), true);
  assert.equal(Number.isFinite(result.positions['HGNC:1'].y), true);
  assert.equal(result.metadata.layout_key, 'test-key');
  assert.equal(result.metadata.node_count, 2);
  assert.equal(result.metadata.edge_count, 1);
  assert.equal(typeof result.metadata.cytoscape_version, 'string');
  assert.equal(typeof result.metadata.cytoscape_fcose_version, 'string');
  assert.equal(typeof result.metadata.node_version, 'string');
});

test('computeLayout rejects invalid schemas', async () => {
  await assert.rejects(
    () => computeLayout({ ...baseRequest, schema_version: 2 }),
    /schema_version/
  );
});

test('collectGenePositions omits cluster parents and rounds coordinates', () => {
  const nodes = [
    {
      id: () => 'cluster-1',
      position: () => ({ x: 1.2345, y: 2.3456 })
    },
    {
      id: () => 'HGNC:1',
      position: () => ({ x: 10.12345, y: -20.98765 })
    }
  ];
  const cy = {
    nodes: (selector) => {
      assert.equal(selector, '[!isClusterParent]');
      return {
        forEach: (callback) => {
          nodes.slice(1).forEach(callback);
        }
      };
    }
  };

  assert.deepEqual(collectGenePositions(cy), {
    'HGNC:1': { x: 10.123, y: -20.988 }
  });
});

test('main writes invalid schema errors to stderr and exits non-zero', async () => {
  const result = await runHelper({ schema_version: 2 });

  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');

  const error = JSON.parse(result.stderr);
  assert.match(error.error, /schema_version/);
});

function runHelper(input) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [helperPath], {
      stdio: ['pipe', 'pipe', 'pipe']
    });
    let stdout = '';
    let stderr = '';

    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });
    child.on('error', reject);
    child.on('close', (status) => {
      resolve({ status, stdout, stderr: stderr.trim() });
    });

    child.stdin.end(JSON.stringify(input));
  });
}
