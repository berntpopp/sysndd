#!/usr/bin/env node
/**
 * type-check-strict.js — run vue-tsc against strict-scoped tsconfigs and
 * fail only when errors originate inside the scope's own files.
 *
 * Background: vue-tsc walks the full import graph and reports diagnostics
 * for any referenced file. In our codebase, `src/router/routes.ts` pulls
 * in ~40 view .vue files whose transitive dependencies violate strict
 * mode. The root `tsconfig.json` is intentionally permissive so those
 * violations don't block builds.
 *
 * For Phase E.E2, we only care that files INSIDE each strict scope are
 * strict-clean. Out-of-scope violations remain "ignored" under the root
 * permissive config, to be fixed as subsequent scopes get enabled.
 *
 * This runner:
 *   - invokes vue-tsc -p <tsconfig> for each configured scope
 *   - partitions diagnostic lines by file prefix
 *   - prints in-scope errors to stderr and exits non-zero if any are found
 *   - skips the composables-auth scope silently when no useAuth*.ts files
 *     exist yet (E7 creates useAuth.ts in parallel)
 */

import { spawnSync } from 'node:child_process';
import { existsSync, globSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const appDir = resolve(__dirname, '..');

/**
 * @typedef {Object} Scope
 * @property {string} name     - Human label for logging.
 * @property {string} tsconfig - Path to the scope tsconfig, relative to app/.
 * @property {string} prefix   - Path prefix (relative to app/) that marks
 *                               "in scope" error lines.
 * @property {string} [requireGlob] - If set, scope runs only when this glob
 *                                    matches at least one file.
 */

/** @type {Scope[]} */
const scopes = [
  { name: 'router', tsconfig: 'tsconfig.router.json', prefix: 'src/router/' },
  { name: 'api', tsconfig: 'tsconfig.api.json', prefix: 'src/api/' },
  { name: 'types', tsconfig: 'tsconfig.types.json', prefix: 'src/types/' },
  {
    name: 'composables-auth',
    tsconfig: 'tsconfig.composables-auth.json',
    prefix: 'src/composables/useAuth',
    requireGlob: 'src/composables/useAuth*.ts',
  },
];

let failed = false;

for (const scope of scopes) {
  if (scope.requireGlob) {
    const matches = globSync(scope.requireGlob, { cwd: appDir });
    if (matches.length === 0) {
      console.log(
        `[type-check:strict] skipping ${scope.name}: no files match ${scope.requireGlob} yet`
      );
      continue;
    }
  }

  if (!existsSync(resolve(appDir, scope.tsconfig))) {
    console.error(`[type-check:strict] missing tsconfig: ${scope.tsconfig}`);
    failed = true;
    continue;
  }

  const result = spawnSync(
    'npx',
    ['vue-tsc', '--noEmit', '-p', scope.tsconfig],
    { cwd: appDir, encoding: 'utf8' }
  );

  // Spawn failed outright (e.g. npx not on PATH, ENOENT, permission denied).
  // `result.status` is null in this case, so fall-through would surface as
  // "UNEXPECTED TOOL FAILURE (vue-tsc exit null)" and bury the real cause.
  if (result.error) {
    console.error(`[type-check:strict] ${scope.name}: SPAWN FAILED — ${result.error.message}`);
    console.error(result.error.stack ?? '(no stack)');
    failed = true;
    continue;
  }
  // Process was terminated by a signal (e.g. SIGKILL from OOM killer).
  // Again, `result.status` is null here, so we need to surface the signal
  // explicitly before the generic guard below misreports it.
  if (result.signal) {
    console.error(`[type-check:strict] ${scope.name}: KILLED BY SIGNAL ${result.signal}`);
    failed = true;
    continue;
  }

  const output = `${result.stdout || ''}${result.stderr || ''}`;
  const lines = output.split('\n');
  const inScopeErrors = lines.filter((line) => line.startsWith(scope.prefix));

  if (inScopeErrors.length > 0) {
    console.error(`[type-check:strict] ${scope.name}: FAIL (${inScopeErrors.length} errors)`);
    for (const line of inScopeErrors) {
      console.error(line);
    }
    failed = true;
    continue;
  }

  // Catch unexpected tool failures: vue-tsc exited non-zero with no in-scope
  // errors, but also produced no recognizable out-of-scope diagnostics.
  //
  // vue-tsc normally exits non-zero when ANY file in the import graph has
  // errors — out-of-scope diagnostics are expected and intentionally ignored.
  // They look like: `src/foo/bar.vue(12,3): error TS2322: ...`.
  //
  // If the exit is non-zero but NO line matches that shape, vue-tsc itself
  // failed to run (binary missing, tsconfig-level error like TS5058 emitted
  // without a path prefix, process crash, npm ERR!). Without this guard
  // every scope would report "OK" with exit 0 — a silent green pass that
  // hides real failures.
  if (result.status !== 0) {
    // Match any line that looks like a normal TS diagnostic:
    // `path/to/file.ext(line,col): error TSxxxx: message`
    const diagnosticPattern = /^\S+\.\w+\(\d+,\d+\): (?:error|warning) TS\d+:/;
    const hasAnyDiagnostic = lines.some((line) => diagnosticPattern.test(line));
    if (!hasAnyDiagnostic) {
      const rawOutput = output.trim();
      console.error(
        `[type-check:strict] ${scope.name}: UNEXPECTED TOOL FAILURE (vue-tsc exit ${result.status})`
      );
      console.error(rawOutput.length > 0 ? rawOutput : '(no output)');
      failed = true;
      continue;
    }
  }

  console.log(`[type-check:strict] ${scope.name}: OK`);
}

process.exit(failed ? 1 : 0);
