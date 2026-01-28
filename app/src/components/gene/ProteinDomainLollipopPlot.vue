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
    <!-- SVG container (D3 owns this element exclusively) -->
    <div
      ref="plotContainer"
      class="plot-container"
      :aria-label="`Protein domain lollipop plot for ${geneSymbol}`"
    />

    <!-- Controls row: Coloring toggle (left) + Domain legend (center) + Export buttons (right) -->
    <div class="controls-row d-flex align-items-center justify-content-between flex-wrap gap-2 mt-1 px-2">
      <!-- Coloring mode toggle -->
      <div
        class="btn-group btn-group-sm"
        role="group"
        aria-label="Variant coloring mode"
      >
        <button
          type="button"
          class="btn btn-xs"
          :class="filterState.coloringMode === 'acmg' ? 'btn-primary' : 'btn-outline-secondary'"
          @click="setColoringMode('acmg')"
        >
          ACMG
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

      <!-- Domain legend (compact, inline) -->
      <div
        v-if="domainLegendItems.length > 0"
        class="domain-legend d-flex flex-wrap justify-content-center gap-2"
      >
        <span
          v-for="item in domainLegendItems"
          :key="item.type"
          class="domain-legend-item"
        >
          <span
            class="domain-dot"
            :style="{ backgroundColor: item.color }"
          />
          <span class="domain-label">{{ item.label }}</span>
        </span>
      </div>

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
    <div class="filter-rows mt-1 px-2">
      <!-- Row 1: Pathogenicity filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1">
        <span
          v-for="item in legendItems"
          :key="item.label"
          class="filter-group"
        >
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
            <span
              v-if="item.count > 0"
              class="filter-count"
            >{{ item.count }}</span>
          </button>
          <button
            type="button"
            class="only-btn"
            title="Show only this category"
            @click="selectOnlyPathogenicity(item.key)"
          >only</button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all pathogenicity categories"
          @click="selectAllPathogenicity"
        >all</button>
      </div>

      <!-- Row 2: Effect type filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1 mt-1">
        <span
          v-for="item in effectLegendItems"
          :key="item.key"
          class="filter-group"
        >
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
            <span
              v-if="item.count > 0"
              class="filter-count"
            >{{ item.count }}</span>
          </button>
          <button
            type="button"
            class="only-btn"
            title="Show only this effect type"
            @click="selectOnlyEffectType(item.key)"
          >only</button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all effect types"
          @click="selectAllEffectTypes"
        >all</button>
      </div>
    </div>
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
import {
  PATHOGENICITY_COLORS,
  EFFECT_TYPE_COLORS,
  normalizeEffectType,
} from '@/types/protein';

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
  height: 200,
  margin: { top: 45, right: 20, bottom: 35, left: 40 },
  onVariantClick: (variant) => emit('variant-click', variant),
  onVariantHover: (variant) => emit('variant-hover', variant),
});

/**
 * Count variants by pathogenicity classification
 */
function countByClassification(
  variants: ProcessedVariant[]
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const variant of variants) {
    const key = variant.classification;
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

/**
 * Count variants by effect type
 */
function countByEffectType(
  variants: ProcessedVariant[]
): Record<EffectType, number> {
  const counts: Record<EffectType, number> = {
    missense: 0,
    frameshift: 0,
    stop_gained: 0,
    splice: 0,
    inframe_indel: 0,
    synonymous: 0,
    other: 0,
  };
  for (const variant of variants) {
    const effectType = normalizeEffectType(variant.majorConsequence);
    counts[effectType]++;
  }
  return counts;
}

/**
 * Set the coloring mode (acmg or effect)
 */
function setColoringMode(mode: ColoringMode): void {
  filterState.coloringMode = mode;
}

/**
 * Format domain type code to human-readable label
 * e.g., 'DOMAIN' -> 'Domain', 'ZN_FING' -> 'Zinc finger', 'DNA_BIND' -> 'DNA binding'
 */
function formatDomainType(type: string): string {
  const typeMap: Record<string, string> = {
    DOMAIN: 'Domain',
    REGION: 'Region',
    MOTIF: 'Motif',
    ZN_FING: 'Zinc finger',
    DNA_BIND: 'DNA binding',
    REPEAT: 'Repeat',
    COILED: 'Coiled coil',
    TRANSMEM: 'Transmembrane',
    SIGNAL: 'Signal peptide',
    PROPEP: 'Propeptide',
    TRANSIT: 'Transit peptide',
    CHAIN: 'Chain',
    ACT_SITE: 'Active site',
    BINDING: 'Binding site',
    SITE: 'Site',
    DISULFID: 'Disulfide bond',
    CARBOHYD: 'Glycosylation',
    LIPID: 'Lipidation',
    CROSSLNK: 'Cross-link',
    VAR_SEQ: 'Variant sequence',
  };

  if (typeMap[type]) {
    return typeMap[type];
  }

  // Fall back to title case with underscore replacement
  return type
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
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
 * Computed legend items for effect type filter buttons
 */
const effectLegendItems = computed(() => {
  const counts = countByEffectType(props.data.variants);
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
function toggleFilter(key: 'pathogenic' | 'likelyPathogenic' | 'vus' | 'likelyBenign' | 'benign'): void {
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
function selectOnlyPathogenicity(key: 'pathogenic' | 'likelyPathogenic' | 'vus' | 'likelyBenign' | 'benign'): void {
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
  const effectTypes: EffectType[] = ['missense', 'frameshift', 'stop_gained', 'splice', 'inframe_indel', 'synonymous', 'other'];
  for (const et of effectTypes) {
    filterState.effectFilters[et] = et === effectType;
  }
}

/**
 * Select all effect types
 */
function selectAllEffectTypes(): void {
  const effectTypes: EffectType[] = ['missense', 'frameshift', 'stop_gained', 'splice', 'inframe_indel', 'synonymous', 'other'];
  for (const et of effectTypes) {
    filterState.effectFilters[et] = true;
  }
}

/**
 * Download SVG export
 */
function downloadSVG(): void {
  const svgString = exportSVG();
  if (!svgString) return;

  const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${props.geneSymbol}_lollipop_plot.svg`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Download PNG export
 */
async function downloadPNG(): Promise<void> {
  const dataUrl = await exportPNG(2);
  if (!dataUrl) return;

  const link = document.createElement('a');
  link.href = dataUrl;
  link.download = `${props.geneSymbol}_lollipop_plot.png`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
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
  min-height: 200px;
  position: relative;
}

/* Make SVG responsive via viewBox */
.plot-container :deep(svg) {
  width: 100%;
  height: auto;
}

/* Controls row */
.controls-row {
  border-bottom: 1px solid #eee;
  padding-bottom: 6px;
}

/* Extra small button size */
.btn-xs {
  padding: 3px 8px;
  font-size: 0.75rem;
  line-height: 1.4;
}

/* Filter chips - compact toggle buttons */
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

.filter-separator {
  color: #ccc;
  margin: 0 4px;
  font-size: 0.8rem;
}

/* Filter group with "only" button */
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

/* Domain legend items (compact, non-interactive) */
.domain-legend-item {
  display: inline-flex;
  align-items: center;
  gap: 3px;
}

.domain-dot {
  display: inline-block;
  width: 12px;
  height: 7px;
  border-radius: 2px;
  flex-shrink: 0;
}

.domain-label {
  font-size: 0.7rem;
  color: #6c757d;
  white-space: nowrap;
}

/* Export buttons */
.export-buttons .btn {
  display: inline-flex;
  align-items: center;
  gap: 2px;
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
