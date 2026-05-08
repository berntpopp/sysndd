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
 *   - logs a skip notice and continues (exits 0) for the composables-auth
 *     scope when no useAuth*.ts files exist yet (E7 creates useAuth.ts in
 *     parallel); the notice is intentional so CI logs show why the scope
 *     was deferred rather than silently missed
 */

import { spawnSync } from 'node:child_process';
import { existsSync, globSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const appDir = resolve(__dirname, '..');
const vueTscBin = resolve(appDir, 'node_modules/vue-tsc/bin/vue-tsc.js');

/**
 * @typedef {Object} Scope
 * @property {string} name     - Human label for logging.
 * @property {string} tsconfig - Path to the scope tsconfig, relative to app/.
 * @property {string} prefix   - Path prefix (relative to app/) that marks
 *                               "in scope" error lines.
 * @property {string[]} [excludePrefixes] - Optional list of file path prefixes
 *                                          (relative to app/) that should NOT
 *                                          count as in-scope errors even when
 *                                          they match `prefix`. Used by the
 *                                          `global` scope to honour the
 *                                          tsconfig-level `exclude` list.
 *                                          Without this, vue-tsc's import-graph
 *                                          walk would surface diagnostics from
 *                                          excluded files because they're still
 *                                          referenced by included ones.
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
  {
    name: 'plugins-axios',
    tsconfig: 'tsconfig.plugins-axios.json',
    prefix: 'src/plugins/axios',
  },
  {
    name: 'views-review',
    tsconfig: 'tsconfig.views-review.json',
    prefix: 'src/views/review/',
  },
  // global is the catch-all strict scope. It includes everything in src/
  // (minus tests) and explicitly excludes the files that still carry strict
  // violations. New files default into this scope, so the exclusion list
  // is the ratchet: shrinking it is a net-positive change, growing it
  // requires a documented reason. The exclusion list lives in
  // tsconfig.global.json AND in `excludePrefixes` below — both are needed
  // because vue-tsc still reports diagnostics from excluded files when the
  // import graph references them. Keep the two lists in sync.
  {
    name: 'global',
    tsconfig: 'tsconfig.global.json',
    prefix: 'src/',
    // Exclusions are grouped by root cause so each cohort can be retired
    // together. Categories: (D3) needs @types/d3 or local ambient types;
    // (CYTO-EXT) cytoscape-fcose / cytoscape-svg ship no published types;
    // (FS) file-saver needs @types/file-saver; (BV3-OVERLOAD) bootstrap-
    // vue-next BFormSelect overload incompatibility with our setup() shape;
    // (BV3-NULL) bootstrap-vue-next props expect undefined where we pass
    // null; (NULL-NARROW) ordinary null/undefined narrowing fixes; (ANY-
    // PARAM) implicit-any callback params; (INDEX) index-type narrowing;
    // (TOAST-SHIM) toast wrapper type misalignment with consumers.
    excludePrefixes: [
      // D3
      'src/components/analyses/PubtatorNDDStats.vue',
      'src/components/gene/GeneStructurePlotWithVariants.vue',
      'src/components/gene/ProteinDomainLollipopPlot.vue',
      'src/composables/useD3GeneStructure.ts',
      'src/composables/useD3Lollipop.ts',
      // CYTO-EXT
      'src/composables/useCytoscape.ts',
      'src/composables/usePhenotypeCytoscape.ts',
      // FS
      'src/composables/useExcelExport.ts',
      // BV3-OVERLOAD
      'src/components/forms/wizard/StepClassification.vue',
      'src/components/forms/wizard/StepCoreEntity.vue',
      // BV3-NULL
      'src/components/annotations/JobProgressDisplay.vue',
      'src/components/annotations/PublicationRefreshCard.vue',
      'src/components/small/TablePaginationControls.vue',
      // NULL-NARROW
      'src/components/forms/wizard/StepEvidence.vue',
      'src/components/review/ReviewTable.vue',
      'src/composables/useFilterSync.ts',
      'src/views/curate/CreateEntity.vue',
      // ANY-PARAM / API response narrowing
      'src/components/analyses/PubtatorNDDGenes.vue',
      'src/components/analyses/PubtatorNDDTable.vue',
      'src/composables/annotations/useAnnotationsApi.ts',
      // INDEX
      'src/components/review/EditReviewModal.vue',
      'src/components/review/EditStatusModal.vue',
      'src/components/cms/SectionEditor.vue',
      'src/composables/useTableMethods.ts',
      'src/views/curate/ApproveReview.vue',
      // TOAST-SHIM
      'src/composables/useToast.ts',
      'src/composables/useToastNotifications.ts',
      'src/views/admin/AdminStatistics.vue',
    ],
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

  const result = spawnSync(process.execPath, [vueTscBin, '--noEmit', '-p', scope.tsconfig], {
    cwd: appDir,
    encoding: 'utf8',
  });

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
  const excludePrefixes = scope.excludePrefixes ?? [];
  const inScopeErrors = lines.filter((line) => {
    if (!line.startsWith(scope.prefix)) return false;
    return !excludePrefixes.some((p) => line.startsWith(p));
  });

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
