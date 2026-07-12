import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import test from 'node:test';
import { heavyModules } from '../build/heavy-visualization-packages.mjs';
import {
  cleanupBundleBudgetMetadata,
  parsePrecacheUrls,
} from './verify-route-bundle-budget.mjs';

test('runs the bundle budget against the deploy production build mode', () => {
  const packageJson = JSON.parse(readFileSync(resolve(import.meta.dirname, '../package.json'), 'utf8'));
  const command = packageJson.scripts['build:bundle-budget'];

  assert.match(command, /BUNDLE_BUDGET=true npm run build:production/);
  assert.doesNotMatch(command, /build:docker/);
});

test('parses Workbox URL records across formatting and normalizes their paths', () => {
  const precacheUrls = parsePrecacheUrls(`
    self.precacheAndRoute([
      {url:"assets/app.js",revision:null},
      { url : 'https://sysndd.example/assets/core.js?revision=1' },
      {url: './index.html'}
    ]);
  `);

  assert.deepEqual([...precacheUrls].sort(), ['assets/app.js', 'assets/core.js', 'index.html']);
});

test('rejects a service worker with no parseable Workbox URL records', () => {
  assert.throws(
    () => parsePrecacheUrls('self.precacheAndRoute([]);'),
    /no precache URL records/i
  );
});

test('does not accept an unrelated URL field as a Workbox precache record', () => {
  assert.throws(
    () =>
      parsePrecacheUrls(`
        self.precacheAndRoute([{href: 'assets/cytoscape-heavy.js'}, {href: 'index.html'}]);
        const unrelated = {url: 'index.html'};
      `),
    /no precache URL records/i
  );
});

test('ignores nested URL fields in Workbox precache records', () => {
  const precacheUrls = parsePrecacheUrls(`
    self.precacheAndRoute([
      {url: 'index.html', metadata: {url: 'assets/cytoscape-heavy.js'}}
    ]);
  `);

  assert.deepEqual([...precacheUrls], ['index.html']);
});

test('rejects multiple Workbox precache calls rather than inspecting only the first', () => {
  assert.throws(
    () =>
      parsePrecacheUrls(`
        self.precacheAndRoute([{url: 'index.html'}]);
        self.precacheAndRoute([{url: 'assets/cytoscape-heavy.js'}]);
      `),
    /exactly one precache/i
  );
});

test('removes the ephemeral bundle-attribution metadata before artifact handoff', () => {
  const distDir = mkdtempSync(resolve(tmpdir(), 'sysndd-route-budget-'));
  const metadataDir = resolve(distDir, '.vite');
  mkdirSync(metadataDir);

  try {
    cleanupBundleBudgetMetadata(distDir);
    assert.equal(existsSync(metadataDir), false);
  } finally {
    rmSync(distDir, { force: true, recursive: true });
  }
});

test('classifies Cytoscape support packages and all UpSet packages as heavyweight', () => {
  const matches = heavyModules([
    '/app/node_modules/cose-base/src/index.js',
    '/app/node_modules/layout-base/src/index.js',
    '/app/node_modules/cytoscape-fcose/cytoscape-fcose.js',
    '/app/node_modules/@upsetjs/react/dist/index.js',
  ]);

  assert.deepEqual(
    matches.map(({ name }) => name),
    ['Cytoscape', 'UpSet.js']
  );
});

test('classifies Cytoscape layout support packages without a Cytoscape wrapper', () => {
  const matches = heavyModules([
    '/app/node_modules/cose-base/src/index.js',
    '/app/node_modules/layout-base/src/index.js',
  ]);

  assert.deepEqual(matches.map(({ name }) => name), ['Cytoscape']);
});

test('classifies Cytoscape core and extension packages as heavyweight', () => {
  const matches = heavyModules([
    '/app/node_modules/cytoscape/dist/cytoscape.esm.mjs',
    '/app/node_modules/cytoscape-fcose/cytoscape-fcose.js',
    '/app/node_modules/cytoscape-svg/cytoscape-svg.js',
  ]);

  assert.deepEqual(matches.map(({ name }) => name), ['Cytoscape']);
});
