import { gzipSync } from 'node:zlib';
import { readFileSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { heavyModules } from '../build/heavy-visualization-packages.mjs';

const DIST_DIR = resolve(import.meta.dirname, '../dist');
const MANIFEST_PATH = resolve(DIST_DIR, '.vite/manifest.json');
const MODULE_GRAPH_PATH = resolve(DIST_DIR, '.vite/route-bundle-modules.json');
const SERVICE_WORKER_PATH = resolve(DIST_DIR, 'sw.js');

const ROUTE_BUDGETS = {
  // Docker production-build baseline (2026-07-13): 247080 B; 21.4% headroom.
  HomeView: { src: 'src/views/HomeView.vue', maxGzipBytes: 300_000 },
  // Docker production-build baseline (2026-07-13): 239677 B; 21.0% headroom.
  SearchView: { src: 'src/views/pages/SearchView.vue', maxGzipBytes: 290_000 },
  // Docker production-build baseline (2026-07-13): 263585 B; 21.4% headroom.
  OntologyView: { src: 'src/views/pages/OntologyView.vue', maxGzipBytes: 320_000 },
  // Docker production-build baseline (2026-07-13): 243720 B; 21.1% headroom.
  AnalysisView: { src: 'src/views/AnalysisView.vue', maxGzipBytes: 295_000 },
};

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new Error(`Cannot read ${path}: ${error instanceof Error ? error.message : error}`);
  }
}

function manifestKeyForSource(manifest, src) {
  const match = Object.entries(manifest).find(([, chunk]) => chunk.src === src);
  if (!match) throw new Error(`No Vite manifest entry found for ${src}`);
  return match[0];
}

function collectStaticClosure(manifest, entryKey) {
  const parents = new Map([[entryKey, null]]);
  const pending = [entryKey];

  for (const key of pending) {
    const chunk = manifest[key];
    if (!chunk) throw new Error(`Manifest references missing static chunk ${key}`);

    for (const importedKey of chunk.imports ?? []) {
      if (!parents.has(importedKey)) {
        parents.set(importedKey, key);
        pending.push(importedKey);
      }
    }
  }

  return parents;
}

function formatImportChain(parents, key) {
  const chain = [];
  for (let current = key; current !== null; current = parents.get(current)) chain.push(current);
  return chain.reverse().join(' -> ');
}

function gzipBytes(file) {
  return gzipSync(readFileSync(resolve(DIST_DIR, file))).byteLength;
}

export function cleanupBundleBudgetMetadata(distDir = DIST_DIR) {
  rmSync(resolve(distDir, '.vite'), { force: true, recursive: true });
}

function workboxPrecacheArray(serviceWorkerSource) {
  const calls = [...serviceWorkerSource.matchAll(/\bprecacheAndRoute\s*\(\s*\[/g)];
  if (calls.length === 0) return '';
  if (calls.length !== 1) {
    throw new Error('Workbox service worker must contain exactly one precacheAndRoute call');
  }
  const [call] = calls;
  if (call.index === undefined) return '';

  const start = call.index + call[0].lastIndexOf('[');
  let depth = 0;
  let quote = null;
  let escaped = false;

  for (let index = start; index < serviceWorkerSource.length; index += 1) {
    const character = serviceWorkerSource[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === quote) quote = null;
      continue;
    }
    if (character === '"' || character === "'") {
      quote = character;
      continue;
    }
    if (character === '[') depth += 1;
    if (character === ']') {
      depth -= 1;
      if (depth === 0) return serviceWorkerSource.slice(start, index + 1);
    }
  }

  throw new Error('Workbox precache array is not balanced');
}

function topLevelRecordUrls(precacheArray) {
  const urls = [];
  let objectDepth = 0;
  let quote = null;
  let escaped = false;

  for (let index = 0; index < precacheArray.length; index += 1) {
    const character = precacheArray[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === quote) quote = null;
      continue;
    }
    if (character === '"' || character === "'") {
      quote = character;
      continue;
    }
    if (character === '{') {
      objectDepth += 1;
      continue;
    }
    if (character === '}') {
      objectDepth -= 1;
      continue;
    }
    if (objectDepth !== 1 || !precacheArray.startsWith('url', index)) continue;

    let previous = index - 1;
    while (/\s/.test(precacheArray[previous] ?? '')) previous -= 1;
    let valueStart = index + 3;
    while (/\s/.test(precacheArray[valueStart] ?? '')) valueStart += 1;
    if (!['{', ','].includes(precacheArray[previous]) || precacheArray[valueStart] !== ':') continue;

    valueStart += 1;
    while (/\s/.test(precacheArray[valueStart] ?? '')) valueStart += 1;
    const valueQuote = precacheArray[valueStart];
    if (valueQuote !== '"' && valueQuote !== "'") continue;

    let value = '';
    let valueEnd = valueStart + 1;
    for (; valueEnd < precacheArray.length; valueEnd += 1) {
      const valueCharacter = precacheArray[valueEnd];
      if (valueCharacter === '\\') {
        throw new Error('Workbox precache URL uses an unsupported escape sequence');
      }
      if (valueCharacter === valueQuote) break;
      value += valueCharacter;
    }
    if (valueEnd === precacheArray.length) {
      throw new Error('Workbox precache URL string is not balanced');
    }
    urls.push(value);
    index = valueEnd;
  }

  return urls;
}

export function parsePrecacheUrls(serviceWorkerSource) {
  const urls = new Set();
  for (const url of topLevelRecordUrls(workboxPrecacheArray(serviceWorkerSource))) {
    const normalizedPath = new URL(url, 'https://bundle-budget.invalid/').pathname.replace(/^\/+/, '');
    urls.add(normalizedPath);
  }
  if (urls.size === 0) {
    throw new Error('Workbox service worker contains no precache URL records');
  }
  return urls;
}

function verifyPrecacheExcludesHeavyChunks(moduleGraph) {
  const precacheUrls = parsePrecacheUrls(readFileSync(SERVICE_WORKER_PATH, 'utf8'));
  if (!precacheUrls.has('index.html')) {
    throw new Error('Workbox precache is missing the expected index.html core asset');
  }
  const preloadedHeavyChunks = Object.entries(moduleGraph.chunks ?? []).flatMap(([file, moduleIds]) => {
    const heavy = heavyModules(moduleIds);
    return precacheUrls.has(file) && heavy.length > 0
      ? [`${file} (${heavy.map(({ name }) => name).join(', ')})`]
      : [];
  });

  if (preloadedHeavyChunks.length > 0) {
    throw new Error(
      `Workbox precache includes heavy route-only chunks:\n  ${preloadedHeavyChunks.join('\n  ')}`
    );
  }
}

function verifyRoute(name, config, manifest, moduleGraph) {
  const entryKey = manifestKeyForSource(manifest, config.src);
  const parents = collectStaticClosure(manifest, entryKey);
  const seenFiles = new Set();
  const failures = [];

  for (const key of parents.keys()) {
    const chunk = manifest[key];
    if (!chunk.file.endsWith('.js')) continue;
    seenFiles.add(chunk.file);

    const moduleIds = moduleGraph.chunks?.[chunk.file];
    if (!Array.isArray(moduleIds)) {
      throw new Error(`No Rollup module list found for ${chunk.file}`);
    }

    for (const heavy of heavyModules(moduleIds)) {
      failures.push(`${heavy.name} (${heavy.moduleId}) via ${formatImportChain(parents, key)}`);
    }
  }

  const totalGzipBytes = [...seenFiles].reduce((total, file) => total + gzipBytes(file), 0);
  if (totalGzipBytes > config.maxGzipBytes) {
    failures.push(`gzip ${totalGzipBytes} B exceeds ${config.maxGzipBytes} B static-path budget`);
  }

  if (failures.length > 0) {
    throw new Error(`${name} route-critical bundle regression:\n  ${failures.join('\n  ')}`);
  }

  return { name, totalGzipBytes, fileCount: seenFiles.size };
}

export function main() {
  const manifest = readJson(MANIFEST_PATH);
  const moduleGraph = readJson(MODULE_GRAPH_PATH);
  const results = [];
  const failures = [];

  for (const [name, config] of Object.entries(ROUTE_BUDGETS)) {
    try {
      results.push(verifyRoute(name, config, manifest, moduleGraph));
    } catch (error) {
      failures.push(error instanceof Error ? error.message : String(error));
    }
  }

  for (const result of results) {
    console.log(
      `OK ${result.name}: ${result.totalGzipBytes} B gzip across ${result.fileCount} static JS chunks`
    );
  }
  if (failures.length > 0) throw new Error(failures.join('\n'));
  verifyPrecacheExcludesHeavyChunks(moduleGraph);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(`Route bundle budget failed: ${error instanceof Error ? error.message : error}`);
    process.exitCode = 1;
  } finally {
    // These build-attribution files are CI-only diagnostics. Never leave source
    // paths or dependency inventories in an artifact that could be deployed.
    cleanupBundleBudgetMetadata();
  }
}
