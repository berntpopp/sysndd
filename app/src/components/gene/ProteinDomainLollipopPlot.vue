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

    <!-- Legend below plot (Vue owns this, not D3) -->
    <div class="plot-legend d-flex flex-wrap justify-content-center gap-3 mt-2">
      <button
        v-for="item in legendItems"
        :key="item.label"
        type="button"
        class="legend-item btn btn-sm"
        :class="{ 'legend-item--hidden': !item.visible }"
        :style="{ '--legend-color': item.color }"
        :aria-label="`Toggle ${item.label} variants`"
        :aria-pressed="item.visible"
        @click="toggleFilter(item.key)"
      >
        <span
          class="legend-dot"
          :style="{ backgroundColor: item.visible ? item.color : '#ccc' }"
        />
        <span class="legend-label">{{ item.label }}</span>
        <span
          v-if="item.count > 0"
          class="legend-count text-muted"
        >({{ item.count }})</span>
      </button>
    </div>

    <!-- Domain legend below pathogenicity legend -->
    <div
      v-if="domainLegendItems.length > 0"
      class="domain-legend d-flex flex-wrap justify-content-center gap-2 mt-1"
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
        <span class="domain-label text-muted small">{{ item.label }}</span>
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watchEffect, watch } from 'vue';
import * as d3 from 'd3';
import { useD3Lollipop } from '@/composables';
import type { ProteinPlotData, ProcessedVariant, LollipopFilterState } from '@/types';
import { PATHOGENICITY_COLORS } from '@/types/protein';

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

// Filter state for pathogenicity visibility toggles
const filterState = reactive<LollipopFilterState>({
  pathogenic: true,
  likelyPathogenic: true,
  vus: true,
  likelyBenign: true,
  benign: true,
});

// Initialize D3 lollipop composable
const { isInitialized, renderPlot } = useD3Lollipop({
  container: plotContainer,
  width: 800,
  height: 250,
  margin: { top: 60, right: 30, bottom: 60, left: 50 },
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
function toggleFilter(key: keyof LollipopFilterState): void {
  filterState[key] = !filterState[key];
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
  min-height: 250px;
  position: relative;
}

/* Make SVG responsive via viewBox */
.plot-container :deep(svg) {
  width: 100%;
  height: auto;
}

/* Pathogenicity legend buttons */
.legend-item {
  border: 1px solid #dee2e6;
  border-radius: 4px;
  padding: 2px 8px;
  background: white;
  cursor: pointer;
  transition: opacity 0.2s ease;
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.legend-item:hover {
  border-color: #adb5bd;
}

.legend-item--hidden {
  opacity: 0.4;
}

.legend-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.legend-label {
  font-size: 0.875rem;
}

.legend-count {
  font-size: 0.75rem;
  margin-left: 2px;
}

/* Domain legend items (non-interactive) */
.domain-legend-item {
  display: inline-flex;
  align-items: center;
  gap: 3px;
}

.domain-dot {
  display: inline-block;
  width: 12px;
  height: 8px;
  border-radius: 2px;
  flex-shrink: 0;
}

.domain-label {
  font-size: 0.75rem;
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
</style>
