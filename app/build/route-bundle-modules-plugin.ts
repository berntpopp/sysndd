import type { OutputChunk } from 'rollup';
import type { Plugin } from 'vite';

const MODULE_GRAPH_FILE = '.vite/route-bundle-modules.json';

/**
 * Emits the Rollup module IDs for every JavaScript chunk beside Vite's manifest.
 *
 * Vite's standard manifest intentionally maps source entries and chunk imports,
 * but does not retain the package modules contained in each emitted chunk. The
 * route bundle-budget check needs both facts to prove that a route's static
 * closure has not picked up a heavyweight package through a barrel export.
 */
export function routeBundleModulesPlugin(): Plugin {
  return {
    name: 'sysndd:route-bundle-modules',
    apply: 'build',
    generateBundle(_options, bundle) {
      const chunks = Object.values(bundle)
        .filter((output): output is OutputChunk => output.type === 'chunk')
        .sort((left, right) => left.fileName.localeCompare(right.fileName));
      const moduleGraph = Object.fromEntries(
        chunks.map((chunk) => [chunk.fileName, Object.keys(chunk.modules).sort()])
      );

      this.emitFile({
        type: 'asset',
        fileName: MODULE_GRAPH_FILE,
        source: `${JSON.stringify({ schemaVersion: 1, chunks: moduleGraph }, null, 2)}\n`,
      });
    },
  };
}
