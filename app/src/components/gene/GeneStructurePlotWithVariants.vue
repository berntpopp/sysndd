<!-- src/components/gene/GeneStructurePlotWithVariants.vue -->
<!--
  Gene structure visualization with ClinVar variants overlaid at genomic positions.

  Design goals (matching ProteinDomainLollipopPlot):
  - Same visual height and proportions
  - Same font sizes (9px labels, 12px tooltips)
  - Same ACMG color scheme for variants
  - ViewBox-based responsive SVG
  - Same tooltip styling
  - Consistent controls row

  Renders:
  - Exons as rectangles (blue, with UTR distinction)
  - Introns as lines with strand direction arrows
  - Variants as lollipop markers at genomic positions
  - Coordinate axis with Mb/kb/bp formatting

  The controls row + filter legend rows live in the presentational child
  GeneStructurePlotControls.vue (props in, actions emitted out); this
  component keeps the D3 lifecycle (useGeneStructurePlot), the reactive
  filter/coloring state, the filter predicates/colors, and cleanup.
-->
<template>
  <div class="gene-structure-plot">
    <!--
      SVG container (D3 owns this element exclusively).
      role="figure" allows aria-label on the wrapper div; the D3 SVG inside
      carries role="img" + title/desc for AT traversing the SVG element.
    -->
    <div
      ref="plotContainer"
      class="plot-container"
      role="figure"
      :aria-label="`Gene structure diagram for ${geneSymbol}`"
    />

    <GeneStructurePlotControls
      :coloring-mode="filterState.coloringMode"
      :gene-data="geneData"
      :zoom-domain="zoomDomain"
      :has-variants="variants.length > 0"
      :pathogenicity-items="filterItems"
      :effect-items="effectLegendItems"
      @set-coloring-mode="setColoringMode"
      @reset-zoom="resetZoom"
      @download-svg="downloadSVG"
      @download-png="downloadPNG"
      @toggle-pathogenicity="toggleFilter"
      @select-only-pathogenicity="selectOnlyPathogenicity"
      @select-all-pathogenicity="selectAllPathogenicity"
      @toggle-effect="toggleEffectFilter"
      @select-only-effect="selectOnlyEffectType"
      @select-all-effects="selectAllEffectTypes"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import type { GeneStructureRenderData } from '@/types/ensembl';
import type { EffectType, ColoringMode } from '@/types/protein';
import { PATHOGENICITY_COLORS, EFFECT_TYPE_COLORS, normalizeEffectType } from '@/types/protein';
import type { GenomicVariant } from './GenomicVisualizationTabs.vue';
import { isGeneStructureVariantVisible } from './geneStructureVariantPlotUtils';
import {
  useGeneStructurePlot,
  type AggregatedGenomicVariant,
  type GeneStructurePlotInputs,
} from './gene-structure-plot';
import GeneStructurePlotControls, {
  type PathogenicityFilterKey,
  type PathogenicityLegendRow,
  type EffectLegendRow,
} from './GeneStructurePlotControls.vue';

interface Props {
  geneData: GeneStructureRenderData;
  variants: GenomicVariant[];
  geneSymbol: string;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'variant-click', variant: GenomicVariant): void;
}>();

// Template ref for the D3 container element
const plotContainer = ref<HTMLElement | null>(null);

// Reactive UI state
const showVariants = ref(true);

// Filter state for pathogenicity and effect type
// Default: Only show Pathogenic and Likely Pathogenic for clinical focus
// Effect types: all enabled by default
const filterState = reactive({
  pathogenic: true,
  likelyPathogenic: true,
  vus: false,
  likelyBenign: false,
  benign: false,
  effectFilters: {
    missense: true,
    frameshift: true,
    stop_gained: true,
    splice: true,
    inframe_indel: true,
    synonymous: true,
    other: true,
  } as Record<EffectType, boolean>,
  coloringMode: 'acmg' as ColoringMode,
});

/**
 * Count variants by classification
 */
function countByClassification(): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const v of props.variants) {
    counts[v.classification] = (counts[v.classification] || 0) + 1;
  }
  return counts;
}

/**
 * Count variants by effect type
 */
function countByEffectType(): Record<EffectType, number> {
  const counts: Record<EffectType, number> = {
    missense: 0,
    frameshift: 0,
    stop_gained: 0,
    splice: 0,
    inframe_indel: 0,
    synonymous: 0,
    other: 0,
  };
  for (const v of props.variants) {
    const effectType = normalizeEffectType(v.majorConsequence);
    counts[effectType]++;
  }
  return counts;
}

/**
 * Human-readable labels for effect types
 */
const EFFECT_TYPE_LABELS: Record<EffectType, string> = {
  missense: 'Missense',
  frameshift: 'Frameshift',
  stop_gained: 'Stop gained',
  splice: 'Splice',
  inframe_indel: 'In-frame indel',
  synonymous: 'Synonymous',
  other: 'Other',
};

/**
 * Computed filter items for the legend, fed to GeneStructurePlotControls
 */
const filterItems = computed<PathogenicityLegendRow[]>(() => {
  const counts = countByClassification();
  return [
    {
      key: 'pathogenic' as const,
      label: 'Pathogenic',
      color: PATHOGENICITY_COLORS['Pathogenic'],
      visible: filterState.pathogenic,
      count: counts['Pathogenic'] || 0,
    },
    {
      key: 'likelyPathogenic' as const,
      label: 'Likely pathogenic',
      color: PATHOGENICITY_COLORS['Likely pathogenic'],
      visible: filterState.likelyPathogenic,
      count: counts['Likely pathogenic'] || 0,
    },
    {
      key: 'vus' as const,
      label: 'VUS',
      color: PATHOGENICITY_COLORS['Uncertain significance'],
      visible: filterState.vus,
      count: counts['Uncertain significance'] || 0,
    },
    {
      key: 'likelyBenign' as const,
      label: 'Likely benign',
      color: PATHOGENICITY_COLORS['Likely benign'],
      visible: filterState.likelyBenign,
      count: counts['Likely benign'] || 0,
    },
    {
      key: 'benign' as const,
      label: 'Benign',
      color: PATHOGENICITY_COLORS['Benign'],
      visible: filterState.benign,
      count: counts['Benign'] || 0,
    },
  ];
});

/**
 * Computed legend items for effect type filter buttons, fed to
 * GeneStructurePlotControls
 */
const effectLegendItems = computed<EffectLegendRow[]>(() => {
  const counts = countByEffectType();
  const effectTypes: EffectType[] = [
    'missense',
    'frameshift',
    'stop_gained',
    'splice',
    'inframe_indel',
    'synonymous',
    'other',
  ];
  return effectTypes.map((effectType) => ({
    key: effectType,
    label: EFFECT_TYPE_LABELS[effectType],
    color: EFFECT_TYPE_COLORS[effectType],
    visible: filterState.effectFilters[effectType],
    count: counts[effectType],
  }));
});

/**
 * Set the coloring mode (acmg or effect)
 */
function setColoringMode(mode: ColoringMode): void {
  filterState.coloringMode = mode;
}

/**
 * Toggle pathogenicity filter
 */
function toggleFilter(key: PathogenicityFilterKey): void {
  filterState[key] = !filterState[key];
}

/**
 * Toggle filter visibility for an effect type
 */
function toggleEffectFilter(effectType: EffectType): void {
  filterState.effectFilters[effectType] = !filterState.effectFilters[effectType];
}

/**
 * Select only one pathogenicity class (deselect all others)
 */
function selectOnlyPathogenicity(key: PathogenicityFilterKey): void {
  filterState.pathogenic = key === 'pathogenic';
  filterState.likelyPathogenic = key === 'likelyPathogenic';
  filterState.vus = key === 'vus';
  filterState.likelyBenign = key === 'likelyBenign';
  filterState.benign = key === 'benign';
}

/**
 * Select all pathogenicity classes
 */
function selectAllPathogenicity(): void {
  filterState.pathogenic = true;
  filterState.likelyPathogenic = true;
  filterState.vus = true;
  filterState.likelyBenign = true;
  filterState.benign = true;
}

/**
 * Select only one effect type (deselect all others)
 */
function selectOnlyEffectType(effectType: EffectType): void {
  const effectTypes: EffectType[] = [
    'missense',
    'frameshift',
    'stop_gained',
    'splice',
    'inframe_indel',
    'synonymous',
    'other',
  ];
  for (const et of effectTypes) {
    filterState.effectFilters[et] = et === effectType;
  }
}

/**
 * Select all effect types
 */
function selectAllEffectTypes(): void {
  const effectTypes: EffectType[] = [
    'missense',
    'frameshift',
    'stop_gained',
    'splice',
    'inframe_indel',
    'synonymous',
    'other',
  ];
  for (const et of effectTypes) {
    filterState.effectFilters[et] = true;
  }
}

/**
 * Check if variant is visible based on filters (AND logic: both pathogenicity AND effect type)
 */
function isVariantVisible(variant: GenomicVariant): boolean {
  return isGeneStructureVariantVisible(variant, {
    pathogenicity: {
      Pathogenic: filterState.pathogenic,
      'Likely pathogenic': filterState.likelyPathogenic,
      'Uncertain significance': filterState.vus,
      'Likely benign': filterState.likelyBenign,
      Benign: filterState.benign,
    },
    effectFilters: filterState.effectFilters,
  });
}

/**
 * Get variant color based on current coloring mode
 */
function getVariantColor(variant: GenomicVariant): string {
  if (filterState.coloringMode === 'effect') {
    const effectType = normalizeEffectType(variant.majorConsequence);
    return EFFECT_TYPE_COLORS[effectType] || '#888';
  }
  return (
    PATHOGENICITY_COLORS[variant.classification as keyof typeof PATHOGENICITY_COLORS] || '#888'
  );
}

/**
 * Get aggregated variant color based on current coloring mode
 */
function getAggregatedColor(agg: AggregatedGenomicVariant): string {
  if (filterState.coloringMode === 'effect') {
    // Find dominant effect type
    let dominantEffect: EffectType = 'other';
    let maxCount = 0;
    for (const v of agg.variants) {
      const effectType = normalizeEffectType(v.majorConsequence);
      // Count occurrences - simple approach
      const count = agg.variants.filter(
        (av) => normalizeEffectType(av.majorConsequence) === effectType
      ).length;
      if (count > maxCount) {
        maxCount = count;
        dominantEffect = effectType;
      }
    }
    return EFFECT_TYPE_COLORS[dominantEffect] || '#888';
  }
  return (
    PATHOGENICITY_COLORS[agg.dominantClassification as keyof typeof PATHOGENICITY_COLORS] || '#888'
  );
}

/**
 * D3 lifecycle is owned by the gene-structure-plot composable. The component
 * keeps the reactive filter/coloring state and feeds the latest snapshot into
 * each render via getInputs(). Layout constants match ProteinDomainLollipopPlot
 * proportions.
 */
function getInputs(): GeneStructurePlotInputs {
  return {
    geneData: props.geneData,
    variants: props.variants,
    geneSymbol: props.geneSymbol,
    showVariants: showVariants.value,
    isVariantVisible,
    getVariantColor,
    getAggregatedColor,
    onVariantClick: (variant) => emit('variant-click', variant),
  };
}

const { zoomDomain, render, resetZoom, downloadSVG, downloadPNG, cleanup } = useGeneStructurePlot({
  container: plotContainer,
  layout: {
    width: 800,
    height: 140,
    margin: { top: 15, right: 20, bottom: 28, left: 40 },
    // Exon/intron styling
    codingHeight: 12,
    utrHeight: 7,
    codingColor: '#2563eb',
    utrColor: '#93c5fd',
    intronColor: '#9ca3af',
    exonStroke: '#1e40af',
    // Variant styling (matching lollipop)
    stemBaseHeight: 18,
    markerRadius: 5,
    markerStrokeWidth: 1,
  },
  getInputs,
});

// Lifecycle
onMounted(() => {
  render();
});

onBeforeUnmount(() => {
  cleanup();
});

// Watch for data changes
watch(
  () => [props.geneData, props.variants, showVariants.value, filterState],
  () => {
    if (plotContainer.value) {
      render();
    }
  },
  { deep: true }
);
</script>

<style scoped>
.gene-structure-plot {
  width: 100%;
}

.plot-container {
  width: 100%;
  max-width: 1400px;
  min-height: 140px;
  position: relative;
  margin: 0 auto;
}

/* Make SVG responsive */
.plot-container :deep(svg) {
  width: 100%;
  height: auto;
}

/* D3-created tooltip styling */
.plot-container :deep(.gene-tooltip) {
  position: absolute;
  background: rgba(0, 0, 0, 0.85);
  color: #fff;
  border-radius: 4px;
  padding: 8px 12px;
  pointer-events: none;
  z-index: 1000;
  font-size: 12px;
  max-width: 280px;
  line-height: 1.4;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}
</style>
