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

    <!-- Controls row: Coloring mode + Gene info + Zoom reset + Export buttons -->
    <div
      class="controls-row d-flex align-items-center justify-content-between flex-wrap gap-2 mt-1 px-2"
    >
      <!-- Coloring mode toggle -->
      <div class="btn-group btn-group-sm" role="group" aria-label="Variant coloring mode">
        <button
          type="button"
          class="btn btn-xs"
          :class="filterState.coloringMode === 'acmg' ? 'btn-primary' : 'btn-outline-secondary'"
          @click="setColoringMode('acmg')"
        >
          Classification
        </button>
        <button
          type="button"
          class="btn btn-xs"
          :class="filterState.coloringMode === 'effect' ? 'btn-primary' : 'btn-outline-secondary'"
          @click="setColoringMode('effect')"
        >
          Effect
        </button>
      </div>

      <!-- Gene info summary -->
      <div class="gene-info small text-muted">
        <span class="me-2"> <i class="bi bi-signpost" /> {{ geneData.strand }} strand </span>
        <span class="me-2">
          chr{{ geneData.chromosome }}:{{ formatCoord(geneData.geneStart) }}-{{
            formatCoord(geneData.geneEnd)
          }}
        </span>
        <span>
          {{ geneData.transcriptId }}
        </span>
      </div>

      <!-- Zoom reset button (only when zoomed) -->
      <button
        v-if="zoomDomain"
        type="button"
        class="btn btn-outline-warning btn-xs"
        title="Reset zoom (or double-click plot)"
        @click="resetZoom"
      >
        <i class="bi bi-arrow-counterclockwise" />
        Reset Zoom
      </button>

      <!-- Export buttons -->
      <div class="export-buttons d-flex gap-1">
        <button
          type="button"
          class="btn btn-outline-secondary btn-xs"
          title="Download as SVG"
          @click="downloadSVG"
        >
          <i class="bi bi-download" />
          SVG
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary btn-xs"
          title="Download as PNG"
          @click="downloadPNG"
        >
          <i class="bi bi-image" />
          PNG
        </button>
      </div>
    </div>

    <!-- Filter rows: Pathogenicity (row 1) + Effect type (row 2) -->
    <div v-if="variants.length > 0" class="filter-rows mt-1 px-2">
      <!-- Row 1: Pathogenicity filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1">
        <span v-for="item in filterItems" :key="item.key" class="filter-group">
          <button
            type="button"
            class="filter-chip"
            :class="{ 'filter-chip--hidden': !item.visible }"
            :aria-label="`Toggle ${item.label} variants`"
            :aria-pressed="item.visible"
            @click="toggleFilter(item.key)"
          >
            <span
              class="filter-dot"
              :style="{ backgroundColor: item.visible ? item.color : '#ccc' }"
            />
            <span class="filter-label">{{ item.label }}</span>
            <span v-if="item.count > 0" class="filter-count">{{ item.count }}</span>
          </button>
          <button
            type="button"
            class="only-btn"
            title="Show only this category"
            @click="selectOnlyPathogenicity(item.key)"
          >
            only
          </button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all pathogenicity categories"
          @click="selectAllPathogenicity"
        >
          all
        </button>
      </div>

      <!-- Row 2: Effect type filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1 mt-1">
        <span v-for="item in effectLegendItems" :key="item.key" class="filter-group">
          <button
            type="button"
            class="filter-chip"
            :class="{ 'filter-chip--hidden': !item.visible }"
            :aria-label="`Toggle ${item.label} variants`"
            :aria-pressed="item.visible"
            @click="toggleEffectFilter(item.key)"
          >
            <span
              class="filter-dot"
              :style="{ backgroundColor: item.visible ? item.color : '#ccc' }"
            />
            <span class="filter-label">{{ item.label }}</span>
            <span v-if="item.count > 0" class="filter-count">{{ item.count }}</span>
          </button>
          <button
            type="button"
            class="only-btn"
            title="Show only this effect type"
            @click="selectOnlyEffectType(item.key)"
          >
            only
          </button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all effect types"
          @click="selectAllEffectTypes"
        >
          all
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import type { GeneStructureRenderData } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';
import type { EffectType, ColoringMode } from '@/types/protein';
import { PATHOGENICITY_COLORS, EFFECT_TYPE_COLORS, normalizeEffectType } from '@/types/protein';
import type { GenomicVariant } from './GenomicVisualizationTabs.vue';
import { isGeneStructureVariantVisible } from './geneStructureVariantPlotUtils';
import {
  useGeneStructurePlot,
  type AggregatedGenomicVariant,
  type GeneStructurePlotInputs,
} from './gene-structure-plot';

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
 * Format coordinate for display
 */
function formatCoord(value: number): string {
  return formatGenomicCoordinate(value);
}

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
 * Computed filter items for the legend
 */
const filterItems = computed(() => {
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
 * Computed legend items for effect type filter buttons
 */
const effectLegendItems = computed(() => {
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
function toggleFilter(
  key: 'pathogenic' | 'likelyPathogenic' | 'vus' | 'likelyBenign' | 'benign'
): void {
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
function selectOnlyPathogenicity(
  key: 'pathogenic' | 'likelyPathogenic' | 'vus' | 'likelyBenign' | 'benign'
): void {
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

/* Controls row */
.controls-row {
  border-bottom: 1px solid #eee;
  padding-bottom: 6px;
}

/* Gene info text */
.gene-info {
  font-size: 0.75rem;
}

/* Extra small button size */
.btn-xs {
  padding: 3px 8px;
  font-size: 0.75rem;
  line-height: 1.4;
}

/* Filter chips */
.filter-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border: 1px solid #dee2e6;
  border-radius: 12px;
  background: white;
  cursor: pointer;
  transition: all 0.15s ease;
  font-size: 0.75rem;
  line-height: 1.5;
}

.filter-chip:hover {
  border-color: #adb5bd;
  background: #f8f9fa;
}

.filter-chip--hidden {
  opacity: 0.4;
  background: #f5f5f5;
}

.filter-dot {
  display: inline-block;
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
}

.filter-label {
  white-space: nowrap;
}

.filter-count {
  color: #6c757d;
  font-size: 0.7rem;
}

.filter-group {
  display: inline-flex;
  align-items: center;
  gap: 1px;
}

/* "only" and "all" buttons (gnomAD-style) */
.only-btn,
.all-btn {
  padding: 1px 4px;
  font-size: 0.65rem;
  line-height: 1.2;
  border: 1px solid #dee2e6;
  border-radius: 3px;
  background: #f8f9fa;
  color: #6c757d;
  cursor: pointer;
  transition: all 0.15s ease;
}

.only-btn:hover,
.all-btn:hover {
  background: #e9ecef;
  border-color: #adb5bd;
  color: #495057;
}

.all-btn {
  margin-left: 2px;
}

/* Export buttons */
.export-buttons .btn {
  display: inline-flex;
  align-items: center;
  gap: 2px;
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
