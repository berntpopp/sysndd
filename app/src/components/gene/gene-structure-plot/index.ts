/**
 * gene-structure-plot/index.ts
 *
 * Public barrel for the gene-structure-plot module. Only the composable and
 * its option/state/layout types are part of the public surface consumed by
 * GeneStructurePlotWithVariants.vue.
 */

export { useGeneStructurePlot } from './useGeneStructurePlot';
export type {
  UseGeneStructurePlotOptions,
  GeneStructurePlotState,
} from './useGeneStructurePlot';
export type {
  GeneStructurePlotLayout,
  GeneStructurePlotMargin,
  GeneStructurePlotInputs,
  GeneStructureContext,
  AggregatedGenomicVariant,
} from './gene-structure-context';
