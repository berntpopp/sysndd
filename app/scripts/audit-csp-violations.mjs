// app/scripts/audit-csp-violations.mjs
//
// Audit the built frontend (app/dist/) for content that would violate a
// strict CSP without 'unsafe-inline' or 'unsafe-eval'. Outputs:
//   * inline <script> tags with their content hash (sha256-base64) so the
//     hash can be added to the CSP directive
//   * inline style="..." attributes (counted; CSP cannot hash these — they
//     have to be extracted to a stylesheet OR the directive must keep
//     'unsafe-inline' for style-src)
//   * dynamic eval-like calls (new Function(...), eval(...)) found via a
//     regex scan of the built JS chunks
//
// Usage:
//   node app/scripts/audit-csp-violations.mjs --build app/dist
//
// Exit status:
//   0 — clean
//   1 — violations present (inventory printed to stdout)

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

// When this module is imported (e.g. by Vitest specs) we want the regex
// exports to be available without triggering CLI side effects. The audit
// pipeline only runs when this file is invoked directly via
// `node app/scripts/audit-csp-violations.mjs --build <dist-dir>`.
const isCli =
  process.argv[1] && process.argv[1] === fileURLToPath(import.meta.url);

// Files that are produced by the build but are not part of the deployed
// SPA surface. They live in dist/ but are NOT served by the production
// nginx config to end users. Skipping them keeps the audit focused on
// content the browser will actually load.
//
//   stats.html — rollup-plugin-visualizer bundle analyzer report
//   google*.html — Google site-verification token files
const SKIP_FILES = new Set(['stats.html']);
const SKIP_PREFIXES = ['google'];

function shouldSkipHtml(rel) {
  if (SKIP_FILES.has(rel)) return true;
  for (const p of SKIP_PREFIXES) {
    if (rel.startsWith(p) && rel.endsWith('.html')) return true;
  }
  return false;
}

function* walk(dir) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      yield* walk(full);
    } else {
      yield full;
    }
  }
}

export const inlineScriptRe =
  /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
export const inlineStyleAttrRe = /\bstyle="([^"]*)"/gi;
// Match eval(, new Function(, or Function( as standalone token starts.
// The previous form `Function\s*\(` consumed a literal `(` and then
// required `\s*\(` again, so plain `Function('...')` calls were missed.
export const evalishRe = /\b(?:eval|new\s+Function|Function)\s*\(/g;

/**
 * Compute the sha256-base64 hash of an inline <script> body, exactly as
 * the browser will hash it for CSP `script-src 'sha256-…'` matching.
 *
 * IMPORTANT: do NOT pre-trim the body. Leading/trailing whitespace and
 * indentation are part of the byte sequence the browser hashes; trimming
 * here would yield a hash that the browser never produces, so a CSP
 * directive built from this audit would silently block valid inline
 * scripts. Trimming is only ever appropriate for the emptiness check.
 *
 * Exported so the Vitest spec can pin this contract in place.
 */
export function hashInlineScript(rawBody) {
  return createHash('sha256').update(rawBody, 'utf8').digest('base64');
}

function runAudit(buildDir) {
  let scriptHits = 0;
  let styleAttrHits = 0;
  let evalHits = 0;
  const scriptHashes = [];
  const evalLocations = [];

  for (const file of walk(buildDir)) {
    const rel = relative(buildDir, file);
    if (file.endsWith('.html')) {
      if (shouldSkipHtml(rel)) continue;
      const html = readFileSync(file, 'utf8');
      let m;
      while ((m = inlineScriptRe.exec(html)) !== null) {
        // CSP hash MUST be computed over the exact byte sequence the
        // browser sees in the delivered HTML — leading/trailing
        // whitespace and indentation are part of that sequence. Trim
        // ONLY for the emptiness check; hash the raw captured body.
        const rawBody = m[1];
        if (!rawBody.trim()) continue; // empty <script> is harmless
        scriptHits++;
        const sha = hashInlineScript(rawBody);
        scriptHashes.push({
          file: rel,
          hash: `'sha256-${sha}'`,
          length: rawBody.length,
        });
      }
      let s;
      while ((s = inlineStyleAttrRe.exec(html)) !== null) {
        styleAttrHits++;
      }
    } else if (file.endsWith('.js') || file.endsWith('.mjs')) {
      const js = readFileSync(file, 'utf8');
      let e;
      while ((e = evalishRe.exec(js)) !== null) {
        evalHits++;
        evalLocations.push({ file: rel, index: e.index });
      }
    }
  }

  const violations = scriptHits + styleAttrHits + evalHits;

  console.log('CSP audit results for', buildDir);
  console.log('  inline <script> blocks:', scriptHits);
  for (const s of scriptHashes) {
    console.log('    ', s.file, s.hash, '(' + s.length + ' chars)');
  }
  console.log('  inline style="" attrs:', styleAttrHits);
  console.log('  eval-like calls (eval / new Function):', evalHits);
  for (const e of evalLocations) {
    console.log('    ', e.file, '@', e.index);
  }
  console.log('TOTAL violations:', violations);

  return violations;
}

if (isCli) {
  const args = process.argv.slice(2);
  const buildIdx = args.indexOf('--build');
  if (buildIdx === -1 || !args[buildIdx + 1]) {
    console.error('Usage: audit-csp-violations.mjs --build <dist-dir>');
    process.exit(2);
  }
  const buildDir = args[buildIdx + 1];
  const violations = runAudit(buildDir);
  process.exit(violations === 0 ? 0 : 1);
}
