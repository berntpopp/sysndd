#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { extname, join, normalize, relative } from 'node:path';

const root = process.cwd();
const docsDir = join(root, 'documentation');
const imgDir = join(docsDir, 'static', 'img');
const generatedDir = join(imgDir, 'generated');
const sourceManifestPath = join(root, 'app', 'tests', 'docs-screenshots', 'manifest.ts');
const provenancePath = join(generatedDir, 'screenshot-manifest.generated.json');
const retainedLegacy = new Set([
  normalize(join(imgDir, 'android-chrome-192x192.png')),
  normalize(join(imgDir, 'SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp')),
]);

function walk(dir, predicate, out = []) {
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    const stats = statSync(path);
    if (stats.isDirectory()) {
      walk(path, predicate, out);
    } else if (predicate(path)) {
      out.push(path);
    }
  }
  return out;
}

function localImageRefs(file) {
  const text = readFileSync(file, 'utf8');
  const refs = [];
  const markdownPattern = /!\[[^\]]*]\(([^)]+)\)/g;
  const yamlImagePattern = /^\s*(?:favicon|cover-image|image|fig-path|path):\s*['"]?([^'"\n]+?\.(?:png|jpe?g|gif|svg|webp))['"]?\s*$/gim;

  let match;
  while ((match = markdownPattern.exec(text)) !== null) {
    refs.push(match[1].trim());
  }
  while ((match = yamlImagePattern.exec(text)) !== null) {
    refs.push(match[1].trim());
  }

  return refs
    .map((ref) => ref.replace(/^<|>$/g, '').split(/\s+/)[0].split('#')[0].split('?')[0])
    .filter((ref) => ref && !/^(https?:)?\/\//i.test(ref));
}

function parseSourceManifestOutputs() {
  if (!existsSync(sourceManifestPath)) {
    throw new Error('Missing docs screenshot source manifest: app/tests/docs-screenshots/manifest.ts');
  }
  const source = readFileSync(sourceManifestPath, 'utf8');
  const entries = [];
  const objectPattern = /\{[\s\S]*?slug:\s*['"]([^'"]+)['"][\s\S]*?output:\s*['"]([^'"]+)['"][\s\S]*?\}/g;
  let match;
  while ((match = objectPattern.exec(source)) !== null) {
    entries.push({ slug: match[1], output: match[2] });
  }
  return entries;
}

const docsSources = [
  ...walk(docsDir, (path) => ['.qmd', '.md'].includes(extname(path))),
  join(docsDir, '_quarto.yml'),
].filter((path) => existsSync(path));

const refs = docsSources.flatMap((file) =>
  localImageRefs(file).map((ref) => ({
    file,
    ref,
    resolved: normalize(join(file, '..', ref)),
  })),
);

const referencedImages = new Set(refs.map(({ resolved }) => normalize(resolved)));
const missingRefs = refs.filter(({ resolved }) => !existsSync(resolved));
const errors = [];

for (const item of missingRefs) {
  errors.push(`Missing documentation image reference: ${relative(root, item.file)} -> ${item.ref}`);
}

let manifestOutputs = [];
try {
  manifestOutputs = parseSourceManifestOutputs();
} catch (error) {
  errors.push(error.message);
}

if (manifestOutputs.length === 0) {
  errors.push('No generated screenshot entries found in app/tests/docs-screenshots/manifest.ts');
}

const seenSlugs = new Set();
const seenOutputs = new Set();
for (const entry of manifestOutputs) {
  if (seenSlugs.has(entry.slug)) errors.push(`Duplicate docs screenshot slug: ${entry.slug}`);
  if (seenOutputs.has(entry.output)) errors.push(`Duplicate docs screenshot output: ${entry.output}`);
  seenSlugs.add(entry.slug);
  seenOutputs.add(entry.output);

  if (!entry.output.startsWith('documentation/static/img/generated/') || !entry.output.endsWith('.png')) {
    errors.push(`Generated output must be a PNG under documentation/static/img/generated/: ${entry.output}`);
  }
  if (!existsSync(join(root, entry.output))) {
    errors.push(`Generated manifest entry missing output file: ${entry.output}`);
  }
}

let provenance = { screenshots: [] };
if (!existsSync(provenancePath)) {
  errors.push(
    'Missing generated screenshot provenance manifest: documentation/static/img/generated/screenshot-manifest.generated.json',
  );
} else {
  try {
    provenance = JSON.parse(readFileSync(provenancePath, 'utf8'));
  } catch (error) {
    errors.push(`Invalid generated screenshot provenance JSON: ${error.message}`);
  }
}

const provenanceEntries = Array.isArray(provenance.screenshots) ? provenance.screenshots : [];
const provenanceOutputs = new Set(provenanceEntries.map((entry) => normalize(join(root, entry.output))));

if (provenanceEntries.length !== manifestOutputs.length) {
  errors.push(
    `Provenance entry count mismatch: expected ${manifestOutputs.length}, found ${provenanceEntries.length}`,
  );
}

for (const entry of manifestOutputs) {
  const absoluteOutput = normalize(join(root, entry.output));
  const provenanceEntry = provenanceEntries.find((item) => item.output === entry.output);
  if (!provenanceEntry) {
    errors.push(`Missing provenance entry for generated screenshot: ${entry.output}`);
    continue;
  }
  if (provenanceEntry.slug !== entry.slug) {
    errors.push(`Provenance slug mismatch for ${entry.output}: expected ${entry.slug}`);
  }
  if (!/^[a-f0-9]{64}$/.test(String(provenanceEntry.sha256 ?? ''))) {
    errors.push(`Missing or invalid provenance sha256 for ${entry.output}`);
  }
  if (!Number.isFinite(provenanceEntry.bytes) || provenanceEntry.bytes <= 0) {
    errors.push(`Missing or invalid provenance byte count for ${entry.output}`);
  }
  if (!existsSync(absoluteOutput)) {
    errors.push(`Missing generated docs screenshot: ${entry.output}`);
  }
}

const generatedPngs = walk(generatedDir, (path) => extname(path).toLowerCase() === '.png');
for (const png of generatedPngs) {
  if (!provenanceOutputs.has(normalize(png))) {
    errors.push(`Generated PNG lacks provenance entry: ${relative(root, png)}`);
  }
}

const legacyImages = walk(imgDir, (path) => {
  const normalized = normalize(path);
  return (
    ['.png', '.jpg', '.jpeg', '.webp'].includes(extname(path).toLowerCase()) &&
    !normalized.startsWith(normalize(generatedDir)) &&
    !retainedLegacy.has(normalized)
  );
});

const orphanedLegacy = legacyImages.filter((path) => !referencedImages.has(normalize(path)));
if (orphanedLegacy.length > 0) {
  console.warn('Orphaned legacy screenshots:');
  for (const path of orphanedLegacy) console.warn(`- ${relative(root, path)}`);
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}

console.log(`Documentation screenshot verification passed (${manifestOutputs.length} generated assets).`);
