<!-- src/components/gene/ProteinDomainLollipopPlot.vue -->
<!--
  Protein domain lollipop plot visualization component

  Renders an interactive D3.js lollipop plot showing:
  - Protein backbone as horizontal bar with amino acid scale
  - UniProt protein domains as colored rectangles
  - ClinVar variants as lollipop markers (circle for coding, diamond for splice)
  - Markers colored by ACMG pathogenicity classification
  - Stacked markers for overlapping variants at the same position
  - Hover tooltips with variant details
  - Brush-to-zoom with double-click reset
  - Clickable legend to filter by pathogenicity class

  D3 owns the SVG element exclusively (CONTEXT pitfall #4).
  Vue owns the legend elements.
-->
<template>
  <div class="protein-lollipop-plot">
    <!--
      SVG container (D3 owns this element exclusively).
      role="figure" on the wrapper allows aria-label to provide a figure-level
      accessible description; the D3-rendered SVG inside has role="img" + title/desc
      for AT that traverses the SVG element. role="figure" is the correct landmark
      for a chart container div that needs naming without being interactive.
    -->
    <div
      ref="plotContainer"
      class="plot-container"
      role="figure"
      :aria-label="`Protein domain lollipop plot for ${geneSymbol}`"
    />

    <ProteinLollipopControlsPanel
      :coloring-mode="filterState.coloringMode"
      :domain-legend-items="domainLegendItems"
      :legend-items="legendItems"
      :effect-legend-items="effectLegendItems"
      @update:coloring-mode="setColoringMode"
      @toggle-pathogenicity="toggleFilter"
      @select-only-pathogenicity="selectOnlyPathogenicity"
      @select-all-pathogenicity="selectAllPathogenicity"
      @toggle-effect="toggleEffectFilter"
      @select-only-effect="selectOnlyEffectType"
      @select-all-effects="selectAllEffectTypes"
      @download-svg="downloadSVG"
      @download-png="downloadPNG"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watchEffect, watch } from 'vue';
import * as d3 from 'd3';
import { useD3Lollipop } from '@/composables';
import type {
  ProteinPlotData,
  ProcessedVariant,
  LollipopFilterState,
  EffectType,
  ColoringMode,
} from '@/types';
import { PATHOGENICITY_COLORS, EFFECT_TYPE_COLORS } from '@/types/protein';
import ProteinLollipopControlsPanel from './ProteinLollipopControlsPanel.vue';
import { useProteinLollipopExport } from './useProteinLollipopExport';
import {
  EFFECT_TYPE_ORDER,
  EFFECT_TYPE_LABELS,
  formatDomainType,
  countByClassification,
  countByEffectType,
  selectOnlyPathogenicity as selectOnlyPathogenicityFor,
  selectAllPathogenicity as selectAllPathogenicityFor,
  selectOnlyEffectType as selectOnlyEffectTypeFor,
  selectAllEffectTypes as selectAllEffectTypesFor,
  type PathogenicityFilterKey,
} from './proteinLollipopControls';

/**
 * Component props
 */
interface Props {
  /** Protein plot data including domains and variants */
  data: ProteinPlotData;
  /** Gene symbol for ARIA labels and accessibility text */
  geneSymbol: string;
}

const props = defineProps<Props>();

/**
 * Component emits
 */
const emit = defineEmits<{
  /** Emitted when a variant marker is clicked (for Phase 45 3D viewer linking) */
  (e: 'variant-click', variant: ProcessedVariant): void;
  /** Emitted when a variant marker is hovered (for Phase 45 3D viewer linking) */
  (e: 'variant-hover', variant: ProcessedVariant | null): void;
}>();

// Template ref for D3 container
const plotContainer = ref<HTMLElement | null>(null);

// Filter state for pathogenicity and effect type visibility toggles
// Default: Only show Pathogenic and Likely Pathogenic for clinical focus
// Effect types: all enabled by default
const filterState = reactive<LollipopFilterState>({
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
  },
  coloringMode: 'acmg',
});

// Initialize D3 lollipop composable
const { isInitialized, renderPlot, exportSVG, exportPNG } = useD3Lollipop({
  container: plotContainer,
  width: 800,
  height: 140,
  margin: { top: 15, right: 20, bottom: 28, left: 40 },
  onVariantClick: (variant) => emit('variant-click', variant),
  onVariantHover: (variant) => emit('variant-hover', variant),
});

// DOM download mechanics (object-URL/anchor plumbing) for the export buttons
const { downloadSVG, downloadPNG } = useProteinLollipopExport({
  geneSymbol: () => props.geneSymbol,
  exportSVG,
  exportPNG,
});

/**
 * Set the coloring mode (acmg or effect)
 */
function setColoringMode(mode: ColoringMode): void {
  filterState.coloringMode = mode;
}

/**
 * Computed legend items for pathogenicity filter buttons
 */
const legendItems = computed(() => {
  const counts = countByClassification(props.data.variants);
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
 * Computed legend items for effect type filter buttons
 */
const effectLegendItems = computed(() => {
  const counts = countByEffectType(props.data.variants);
  return EFFECT_TYPE_ORDER.map((effectType) => ({
    key: effectType,
    label: EFFECT_TYPE_LABELS[effectType],
    color: EFFECT_TYPE_COLORS[effectType],
    visible: filterState.effectFilters[effectType],
    count: counts[effectType],
  }));
});

/**
 * Computed domain legend items with consistent color scale
 * Uses d3.schemeSet2 (same as composable) for domain type colors
 */
const domainLegendItems = computed(() => {
  if (!props.data.domains || props.data.domains.length === 0) {
    return [];
  }

  // Get unique domain types
  const uniqueTypes = [...new Set(props.data.domains.map((d) => d.type))];

  // Create color scale matching the composable
  const colorScale = d3.scaleOrdinal(d3.schemeSet2).domain(uniqueTypes);

  return uniqueTypes.map((type) => ({
    type,
    label: formatDomainType(type),
    color: colorScale(type) as string,
  }));
});

/**
 * Toggle filter visibility for a pathogenicity class
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
  selectOnlyPathogenicityFor(filterState, key);
}

/**
 * Select all pathogenicity classes
 */
function selectAllPathogenicity(): void {
  selectAllPathogenicityFor(filterState);
}

/**
 * Select only one effect type (deselect all others)
 */
function selectOnlyEffectType(effectType: EffectType): void {
  selectOnlyEffectTypeFor(filterState, effectType);
}

/**
 * Select all effect types
 */
function selectAllEffectTypes(): void {
  selectAllEffectTypesFor(filterState);
}

/**
 * Reactive rendering: re-render when data or filter state changes
 */
watchEffect(() => {
  if (isInitialized.value && props.data) {
    renderPlot(props.data, filterState);
  }
});

/**
 * Watch for data prop changes (deep watch for nested object changes)
 */
watch(
  () => props.data,
  (newData) => {
    if (isInitialized.value && newData) {
      renderPlot(newData, filterState);
    }
  },
  { deep: true }
);
</script>

<style scoped>
.protein-lollipop-plot {
  width: 100%;
}

.plot-container {
  width: 100%;
  max-width: 1400px;
  min-height: 140px;
  position: relative;
  margin: 0 auto;
}

/* Make SVG responsive via viewBox */
.plot-container :deep(svg) {
  width: 100%;
  height: auto;
}

/* D3-created tooltip styling (scoped with :deep) */
.plot-container :deep(.lollipop-tooltip) {
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

/* Locked tooltip needs pointer events for link clicking */
.plot-container :deep(.lollipop-tooltip--locked) {
  pointer-events: auto;
}

.plot-container :deep(.lollipop-tooltip a) {
  color: #6ea8fe;
  text-decoration: none;
}

.plot-container :deep(.lollipop-tooltip a:hover) {
  text-decoration: underline;
}
</style>
