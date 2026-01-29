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
    <!-- SVG container (D3 owns this element exclusively) -->
    <div
      ref="plotContainer"
      class="plot-container"
      :aria-label="`Gene structure diagram for ${geneSymbol}`"
    />

    <!-- Controls row: Coloring mode + Gene info + Zoom reset + Export buttons -->
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
        <span class="me-2">
          <i class="bi bi-signpost" /> {{ geneData.strand }} strand
        </span>
        <span class="me-2">
          chr{{ geneData.chromosome }}:{{ formatCoord(geneData.geneStart) }}-{{ formatCoord(geneData.geneEnd) }}
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
        <span
          v-for="item in filterItems"
          :key="item.key"
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
            <span v-if="item.count > 0" class="filter-count">{{ item.count }}</span>
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
            <span v-if="item.count > 0" class="filter-count">{{ item.count }}</span>
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
import { ref, reactive, computed, watch, onMounted, onBeforeUnmount } from 'vue';
import * as d3 from 'd3';
import type { GeneStructureRenderData, ClassifiedExon } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';
import type { EffectType, ColoringMode } from '@/types/protein';
import { PATHOGENICITY_COLORS, EFFECT_TYPE_COLORS, normalizeEffectType } from '@/types/protein';
import type { GenomicVariant } from './GenomicVisualizationTabs.vue';

interface Props {
  geneData: GeneStructureRenderData;
  variants: GenomicVariant[];
  geneSymbol: string;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'variant-click', variant: GenomicVariant): void;
}>();

// Template refs
const plotContainer = ref<HTMLElement | null>(null);

// Non-reactive D3 state (critical: do not use ref())
let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null;
let mainGroup: d3.Selection<SVGGElement, unknown, null, undefined> | null = null;
let tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null = null;
let brush: d3.BrushBehavior<unknown> | null = null;
let xScale: d3.ScaleLinear<number, number> | null = null;

// Tooltip lock state for click-to-pin
let isTooltipLocked = false;
let lockedVariant: GenomicVariant | null = null;

// Reactive state
const showVariants = ref(true);
const isInitialized = ref(false);
const zoomDomain = ref<[number, number] | null>(null); // Current zoom range

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

// Constants (matching ProteinDomainLollipopPlot proportions)
const WIDTH = 800;
const HEIGHT = 140;
const MARGIN = { top: 15, right: 20, bottom: 28, left: 40 };

// Exon/intron styling
const CODING_HEIGHT = 12;
const UTR_HEIGHT = 7;
const CODING_COLOR = '#2563eb';
const UTR_COLOR = '#93c5fd';
const INTRON_COLOR = '#9ca3af';
const EXON_STROKE = '#1e40af';

// Variant styling (matching lollipop)
const STEM_BASE_HEIGHT = 18;
const MARKER_RADIUS = 5;
const MARKER_STROKE_WIDTH = 1;

// Adaptive rendering thresholds (matching protein lollipop)
const AGGREGATION_THRESHOLD = 500; // Switch to aggregated mode above this count
const MIN_MARKER_RADIUS = 3; // Minimum marker size in aggregated mode
const MAX_MARKER_RADIUS = 12; // Maximum marker size for high-count positions
const MIN_OPACITY = 0.25;
const MAX_OPACITY = 0.95;
const DENSITY_THRESHOLD = 200;

/**
 * Aggregated variant at a genomic position
 */
interface AggregatedGenomicVariant {
  genomicPosition: number;
  count: number;
  dominantClassification: string;
  classifications: Record<string, number>;
  variants: GenomicVariant[];
}

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
 * Aggregate variants by genomic position for dense regions
 * Uses binning to group nearby variants
 */
function aggregateVariantsByGenomicPosition(
  variants: GenomicVariant[],
  geneLength: number
): AggregatedGenomicVariant[] {
  // Bin size: approximately 100 bins across the gene
  const binSize = Math.max(100, Math.floor(geneLength / 100));

  const binMap = new Map<number, GenomicVariant[]>();

  for (const v of variants) {
    const binKey = Math.floor(v.genomicPosition / binSize) * binSize;
    if (!binMap.has(binKey)) {
      binMap.set(binKey, []);
    }
    binMap.get(binKey)!.push(v);
  }

  const aggregated: AggregatedGenomicVariant[] = [];

  for (const [_binPosition, binVariants] of binMap) {
    // Find dominant classification
    const classCounts: Record<string, number> = {};
    for (const v of binVariants) {
      classCounts[v.classification] = (classCounts[v.classification] || 0) + 1;
    }

    let dominantClassification = 'Uncertain significance';
    let maxCount = 0;
    for (const [cls, count] of Object.entries(classCounts)) {
      if (count > maxCount) {
        maxCount = count;
        dominantClassification = cls;
      }
    }

    // Calculate centroid position
    const avgPosition = binVariants.reduce((sum, v) => sum + v.genomicPosition, 0) / binVariants.length;

    aggregated.push({
      genomicPosition: Math.round(avgPosition),
      count: binVariants.length,
      dominantClassification,
      classifications: classCounts,
      variants: binVariants,
    });
  }

  return aggregated;
}

/**
 * Calculate marker radius for aggregated variant based on count
 */
function calculateAggregatedRadius(count: number, maxCount: number): number {
  const scale = Math.sqrt(count / Math.max(maxCount, 1));
  return MIN_MARKER_RADIUS + scale * (MAX_MARKER_RADIUS - MIN_MARKER_RADIUS);
}

/**
 * Calculate dynamic opacity based on variant density
 */
function calculateDynamicOpacity(visibleCount: number): number {
  const densityFactor = Math.min(1, DENSITY_THRESHOLD / Math.max(visibleCount, 1));
  const opacity = 0.4 + 0.6 * densityFactor;
  return Math.max(MIN_OPACITY, Math.min(MAX_OPACITY, opacity));
}

/**
 * Determine rendering mode based on visible variant count
 */
function determineRenderingMode(visibleCount: number): 'aggregated' | 'individual' {
  return visibleCount > AGGREGATION_THRESHOLD ? 'aggregated' : 'individual';
}

/**
 * Reset zoom to full gene view
 */
function resetZoom(): void {
  zoomDomain.value = null;
  render();
}

/**
 * Setup brush for zoom selection
 * Brush is added BEFORE variant markers so markers receive click events (higher z-order)
 */
function setupBrush(innerWidth: number, innerHeight: number): void {
  if (!mainGroup) return;

  brush = d3
    .brushX()
    .extent([
      [0, 0],
      [innerWidth, innerHeight],
    ])
    .on('end', (event: d3.D3BrushEvent<unknown>) => {
      if (!event.selection || !xScale) return;

      const [x0, x1] = event.selection as [number, number];
      const newDomain: [number, number] = [xScale.invert(x0), xScale.invert(x1)];

      // Only zoom if selection is meaningful (at least 1kb)
      if (newDomain[1] - newDomain[0] > 1000) {
        zoomDomain.value = newDomain;
        // Clear the brush selection visually
        mainGroup?.select('.brush').call(brush!.move as unknown as never, null);
        render();
      } else {
        mainGroup?.select('.brush').call(brush!.move as unknown as never, null);
      }
    });

  // Add brush to main group (variants will be added after, on top)
  mainGroup.append('g').attr('class', 'brush').call(brush);

  // Add double-click to reset zoom
  svg?.on('dblclick', () => {
    if (zoomDomain.value) {
      resetZoom();
    }
  });
}

/**
 * Hide tooltip (respects lock state)
 * Note: Kept for potential future use with hover interactions
 */
function _hideTooltipIfUnlocked(): void {
  if (!tooltipDiv || isTooltipLocked) return;
  tooltipDiv.style('opacity', 0);
}

/**
 * Force hide tooltip (used when clicking elsewhere)
 */
function forceHideTooltip(): void {
  if (!tooltipDiv) return;
  isTooltipLocked = false;
  lockedVariant = null;
  tooltipDiv.style('opacity', 0).style('pointer-events', 'none');
}

/**
 * Check if variant is visible based on filters (AND logic: both pathogenicity AND effect type)
 */
function isVariantVisible(variant: GenomicVariant): boolean {
  // Check pathogenicity filter
  let pathogenicityVisible = true;
  switch (variant.classification) {
    case 'Pathogenic':
      pathogenicityVisible = filterState.pathogenic;
      break;
    case 'Likely pathogenic':
      pathogenicityVisible = filterState.likelyPathogenic;
      break;
    case 'Uncertain significance':
      pathogenicityVisible = filterState.vus;
      break;
    case 'Likely benign':
      pathogenicityVisible = filterState.likelyBenign;
      break;
    case 'Benign':
      pathogenicityVisible = filterState.benign;
      break;
  }

  // Check effect type filter
  const effectType = normalizeEffectType(variant.majorConsequence);
  const effectVisible = filterState.effectFilters[effectType];

  // AND logic: both must be true
  return pathogenicityVisible && effectVisible;
}

/**
 * Get variant color based on current coloring mode
 */
function getVariantColor(variant: GenomicVariant): string {
  if (filterState.coloringMode === 'effect') {
    const effectType = normalizeEffectType(variant.majorConsequence);
    return EFFECT_TYPE_COLORS[effectType] || '#888';
  }
  return PATHOGENICITY_COLORS[variant.classification as keyof typeof PATHOGENICITY_COLORS] || '#888';
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
      const count = agg.variants.filter(av => normalizeEffectType(av.majorConsequence) === effectType).length;
      if (count > maxCount) {
        maxCount = count;
        dominantEffect = effectType;
      }
    }
    return EFFECT_TYPE_COLORS[dominantEffect] || '#888';
  }
  return PATHOGENICITY_COLORS[agg.dominantClassification as keyof typeof PATHOGENICITY_COLORS] || '#888';
}

/**
 * Initialize and render the visualization
 */
function render(): void {
  if (!plotContainer.value) return;

  // Reset tooltip lock on re-render
  forceHideTooltip();

  const innerWidth = WIDTH - MARGIN.left - MARGIN.right;
  const innerHeight = HEIGHT - MARGIN.top - MARGIN.bottom;

  // Clear previous render
  d3.select(plotContainer.value).select('svg').remove();
  d3.select(plotContainer.value).select('.gene-tooltip').remove();

  // Create responsive SVG with viewBox
  svg = d3
    .select(plotContainer.value)
    .append('svg')
    .attr('viewBox', `0 0 ${WIDTH} ${HEIGHT}`)
    .attr('preserveAspectRatio', 'xMinYMin meet')
    .attr('role', 'img')
    .attr('aria-label', `Gene structure diagram for ${props.geneSymbol}`)
    .style('width', '100%')
    .style('height', 'auto');

  // Click on SVG background to dismiss locked tooltip
  svg.on('click', (event: MouseEvent) => {
    // Only dismiss if clicking on SVG background (not on markers)
    if ((event.target as Element).tagName === 'svg') {
      forceHideTooltip();
    }
  });

  // Create main group with margin transform
  mainGroup = svg
    .append('g')
    .attr('class', 'main-group')
    .attr('transform', `translate(${MARGIN.left}, ${MARGIN.top})`);

  // Determine domain (use zoom or full gene)
  const domain: [number, number] = zoomDomain.value ?? [props.geneData.geneStart, props.geneData.geneEnd];

  // Create x scale (genomic coordinates)
  xScale = d3.scaleLinear()
    .domain(domain)
    .range([0, innerWidth]);

  // Y positions
  const exonY = innerHeight - 30;
  const variantBaseY = exonY - CODING_HEIGHT / 2 - 5;

  // Create strand arrow marker
  const defs = svg.append('defs');
  const marker = defs
    .append('marker')
    .attr('id', 'gene-strand-arrow')
    .attr('markerWidth', 6)
    .attr('markerHeight', 6)
    .attr('refX', props.geneData.strand === '+' ? 6 : 0)
    .attr('refY', 3)
    .attr('orient', 'auto');

  marker
    .append('path')
    .attr('d', props.geneData.strand === '+' ? 'M 0 0 L 6 3 L 0 6 Z' : 'M 6 0 L 0 3 L 6 6 Z')
    .attr('fill', INTRON_COLOR);

  // Render intron lines (back layer)
  props.geneData.introns.forEach((intron) => {
    mainGroup
      .append('line')
      .attr('class', 'intron')
      .attr('x1', xScale(intron.start))
      .attr('y1', exonY)
      .attr('x2', xScale(intron.end))
      .attr('y2', exonY)
      .attr('stroke', INTRON_COLOR)
      .attr('stroke-width', 1)
      .attr('marker-end', 'url(#gene-strand-arrow)');
  });

  // Render exon rectangles
  props.geneData.exons.forEach((exon: ClassifiedExon) => {
    const exonWidth = Math.max(xScale(exon.end) - xScale(exon.start), 2);
    const height = exon.type === 'coding' ? CODING_HEIGHT : UTR_HEIGHT;
    const fillColor = exon.type === 'coding' ? CODING_COLOR : UTR_COLOR;

    mainGroup
      .append('rect')
      .attr('class', 'exon')
      .attr('x', xScale(exon.start))
      .attr('y', exonY - height / 2)
      .attr('width', exonWidth)
      .attr('height', height)
      .attr('fill', fillColor)
      .attr('stroke', EXON_STROKE)
      .attr('stroke-width', 0.5)
      .attr('cursor', 'pointer')
      .on('mouseover', (event: MouseEvent) => {
        showExonTooltip(event, exon);
      })
      .on('mouseout', hideTooltip);
  });

  // Setup brush-to-zoom BEFORE variants (so variants are on top and can receive clicks)
  setupBrush(innerWidth, innerHeight);

  // Create a variant group that will be on top of the brush
  const variantGroup = mainGroup.append('g').attr('class', 'variant-group');

  // Render variants (if enabled) with adaptive density-aware rendering
  if (showVariants.value && props.variants.length > 0) {
    // Filter by pathogenicity and by visible domain
    const visibleVariants = props.variants.filter((v) => {
      if (!isVariantVisible(v)) return false;
      // Filter by zoom domain
      if (zoomDomain.value) {
        return v.genomicPosition >= zoomDomain.value[0] && v.genomicPosition <= zoomDomain.value[1];
      }
      return true;
    });
    const geneLength = domain[1] - domain[0];
    const renderMode = determineRenderingMode(visibleVariants.length);
    const opacity = calculateDynamicOpacity(visibleVariants.length);

    if (renderMode === 'aggregated') {
      // Aggregated mode for dense regions
      const aggregated = aggregateVariantsByGenomicPosition(visibleVariants, geneLength);
      const maxCount = Math.max(...aggregated.map(a => a.count), 1);

      aggregated.forEach((agg) => {
        const x = xScale(agg.genomicPosition);
        const radius = calculateAggregatedRadius(agg.count, maxCount);
        const stemHeight = STEM_BASE_HEIGHT;
        const markerY = variantBaseY - stemHeight;

        // Stem line
        variantGroup
          .append('line')
          .attr('class', 'variant-stem')
          .attr('x1', x)
          .attr('y1', variantBaseY)
          .attr('x2', x)
          .attr('y2', markerY)
          .attr('stroke', '#999')
          .attr('stroke-width', 1)
          .attr('opacity', 0.4);

        // Aggregated marker circle (size = count)
        const color = getAggregatedColor(agg);

        variantGroup
          .append('circle')
          .attr('class', 'variant-marker aggregated')
          .attr('cx', x)
          .attr('cy', markerY)
          .attr('r', radius)
          .attr('fill', color)
          .attr('stroke', '#fff')
          .attr('stroke-width', MARKER_STROKE_WIDTH)
          .attr('opacity', opacity)
          .attr('cursor', 'pointer')
          .on('mouseover', (event: MouseEvent) => {
            showAggregatedTooltip(event, agg);
          })
          .on('mouseout', hideTooltip);
      });
    } else {
      // Individual mode for sparse regions
      // Group by genomic position to handle stacking
      const variantGroups = d3.group(visibleVariants, (v) => Math.round(v.genomicPosition / 100) * 100);

      // Render stems and markers
      variantGroups.forEach((group) => {
        group.forEach((variant, index) => {
          const x = xScale(variant.genomicPosition);
          const stemHeight = STEM_BASE_HEIGHT + Math.min(index, 8) * 10;
          const markerY = variantBaseY - stemHeight;

          // Stem line
          variantGroup
            .append('line')
            .attr('class', 'variant-stem')
            .attr('x1', x)
            .attr('y1', variantBaseY)
            .attr('x2', x)
            .attr('y2', markerY)
            .attr('stroke', '#999')
            .attr('stroke-width', 1)
            .attr('opacity', 0.6);

          // Marker circle
          const color = getVariantColor(variant);

          variantGroup
            .append('circle')
            .attr('class', 'variant-marker')
            .attr('cx', x)
            .attr('cy', markerY)
            .attr('r', MARKER_RADIUS)
            .attr('fill', color)
            .attr('stroke', '#fff')
            .attr('stroke-width', MARKER_STROKE_WIDTH)
            .attr('opacity', opacity)
            .attr('cursor', 'pointer')
            .on('mouseover', (event: MouseEvent) => {
              if (!isTooltipLocked) {
                showVariantTooltip(event, variant);
              }
            })
            .on('mouseout', hideTooltip)
            .on('click', (event: MouseEvent) => {
              event.stopPropagation(); // Prevent SVG click handler
              showVariantTooltip(event, variant, true);
              emit('variant-click', variant);
            });
        });
      });
    }
  }

  // Render X axis
  const xAxis = d3.axisBottom(xScale)
    .ticks(6)
    .tickFormat((d) => formatGenomicCoordinate(d as number));

  mainGroup
    .append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0, ${innerHeight})`)
    .call(xAxis)
    .append('text')
    .attr('x', innerWidth / 2)
    .attr('y', 30)
    .attr('fill', '#666')
    .attr('text-anchor', 'middle')
    .style('font-size', '11px')
    .text(`Genomic Position (chr${props.geneData.chromosome})`);

  // Style axis
  mainGroup.selectAll('.x-axis text').style('font-size', '9px');

  // Create tooltip
  tooltipDiv = d3
    .select(plotContainer.value)
    .append('div')
    .attr('class', 'gene-tooltip')
    .style('position', 'absolute')
    .style('padding', '8px 12px')
    .style('background', 'rgba(0, 0, 0, 0.85)')
    .style('color', '#fff')
    .style('border-radius', '4px')
    .style('font-size', '12px')
    .style('pointer-events', 'none')
    .style('opacity', 0)
    .style('z-index', '1000')
    .style('max-width', '280px')
    .style('line-height', '1.4');

  isInitialized.value = true;
}

/**
 * Show exon tooltip
 */
function showExonTooltip(event: MouseEvent, exon: ClassifiedExon): void {
  if (!tooltipDiv || !plotContainer.value) return;

  const typeLabel =
    exon.type === 'coding' ? 'Coding exon' : exon.type === '5_utr' ? "5' UTR" : "3' UTR";
  const exonSize = exon.end - exon.start;

  const html = `
    <div style="font-weight: bold; margin-bottom: 4px;">Exon ${exon.exonNumber}</div>
    <div style="color: #ccc; margin-bottom: 4px;">${typeLabel}</div>
    <div style="color: #aaa; font-size: 11px;">
      Size: ${formatGenomicCoordinate(exonSize)}
    </div>
    <div style="color: #aaa; font-size: 11px;">
      ${exon.start.toLocaleString()} - ${exon.end.toLocaleString()}
    </div>
  `;

  showTooltipAt(event, html);
}

/**
 * Show variant tooltip (with optional click-to-pin)
 */
function showVariantTooltip(event: MouseEvent, variant: GenomicVariant, locked = false): void {
  if (!tooltipDiv || !plotContainer.value) return;

  // If clicking to lock, check if already locked on this variant
  if (locked && isTooltipLocked && lockedVariant === variant) {
    forceHideTooltip();
    return;
  }

  if (locked) {
    isTooltipLocked = true;
    lockedVariant = variant;
  }

  const colorStyle = `color: ${PATHOGENICITY_COLORS[variant.classification as keyof typeof PATHOGENICITY_COLORS]};`;
  const starsDisplay = '★'.repeat(variant.goldStars) + '☆'.repeat(4 - variant.goldStars);

  // ClinVar link (only shown when locked)
  const clinvarLink = locked && variant.clinvarId
    ? `<div style="margin-top: 8px; padding-top: 8px; border-top: 1px solid #444;">
         <a href="https://www.ncbi.nlm.nih.gov/clinvar/variation/${variant.clinvarId}/"
            target="_blank"
            rel="noopener noreferrer"
            style="color: #6ea8fe; text-decoration: none;">
           View in ClinVar →
         </a>
       </div>`
    : '';

  // Dismiss hint
  const dismissHint = locked
    ? '<div style="margin-top: 6px; font-size: 10px; color: #888;">Click elsewhere to dismiss</div>'
    : '<div style="margin-top: 6px; font-size: 10px; color: #888;">Click to pin</div>';

  const html = `
    <div style="font-weight: bold; margin-bottom: 4px;">${variant.proteinHGVS}</div>
    <div style="color: #ccc;">${variant.codingHGVS}</div>
    <div style="${colorStyle} margin-top: 4px;">${variant.classification}</div>
    <div style="margin-top: 4px;">Review: ${starsDisplay}</div>
    <div style="color: #aaa; font-size: 11px;">${variant.reviewStatus}</div>
    <div style="margin-top: 4px; color: #aaa; font-size: 11px;">
      Genomic pos: ${variant.genomicPosition.toLocaleString()}
    </div>
    ${clinvarLink}
    ${dismissHint}
  `;

  showTooltipAt(event, html, locked);
}

/**
 * Show tooltip for aggregated variants (dense region)
 */
function showAggregatedTooltip(event: MouseEvent, agg: AggregatedGenomicVariant): void {
  if (!tooltipDiv || !plotContainer.value) return;

  // Build classification breakdown
  const classificationLines = Object.entries(agg.classifications)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5) // Show top 5 classifications
    .map(([cls, count]) => {
      const color = PATHOGENICITY_COLORS[cls as keyof typeof PATHOGENICITY_COLORS] || '#888';
      return `<div style="color: ${color}; font-size: 11px;">${cls}: ${count}</div>`;
    })
    .join('');

  const html = `
    <div style="font-weight: bold; margin-bottom: 4px;">${agg.count} variants at this position</div>
    <div style="color: #aaa; font-size: 11px; margin-bottom: 4px;">
      Genomic pos: ${agg.genomicPosition.toLocaleString()}
    </div>
    <div style="margin-top: 4px; border-top: 1px solid #444; padding-top: 4px;">
      ${classificationLines}
    </div>
    <div style="margin-top: 4px; color: #888; font-size: 10px;">
      (Aggregated view - zoom to see individual variants)
    </div>
  `;

  showTooltipAt(event, html);
}

/**
 * Position tooltip with edge detection
 */
function showTooltipAt(event: MouseEvent, html: string, locked = false): void {
  if (!tooltipDiv || !plotContainer.value) return;

  tooltipDiv
    .html(html)
    .style('opacity', 1)
    .style('pointer-events', locked ? 'auto' : 'none');

  const tooltipNode = tooltipDiv.node();
  if (!tooltipNode) return;

  const tooltipRect = tooltipNode.getBoundingClientRect();
  const containerRect = plotContainer.value.getBoundingClientRect();

  let left = event.clientX - containerRect.left + 15;
  let top = event.clientY - containerRect.top - 10;

  if (left + tooltipRect.width > containerRect.width) {
    left = event.clientX - containerRect.left - tooltipRect.width - 15;
  }
  if (top + tooltipRect.height > containerRect.height) {
    top = event.clientY - containerRect.top - tooltipRect.height - 10;
  }

  left = Math.max(0, left);
  top = Math.max(0, top);

  tooltipDiv.style('left', `${left}px`).style('top', `${top}px`);
}

/**
 * Hide tooltip (respects lock state)
 */
function hideTooltip(): void {
  if (!tooltipDiv || isTooltipLocked) return;
  tooltipDiv.style('opacity', 0);
}

/**
 * Export as SVG
 */
function downloadSVG(): void {
  if (!svg) return;

  const svgNode = svg.node();
  if (!svgNode) return;

  const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;
  clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const serializer = new XMLSerializer();
  const svgString = serializer.serializeToString(clonedSvg);
  const blob = new Blob([svgString], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.href = url;
  link.download = `${props.geneSymbol}_gene_structure.svg`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Export as PNG
 */
async function downloadPNG(): Promise<void> {
  if (!svg) return;

  const svgNode = svg.node();
  if (!svgNode) return;

  const scale = 2;
  const clonedSvg = svgNode.cloneNode(true) as SVGSVGElement;
  clonedSvg.setAttribute('width', String(WIDTH));
  clonedSvg.setAttribute('height', String(HEIGHT));
  clonedSvg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const serializer = new XMLSerializer();
  const svgString = serializer.serializeToString(clonedSvg);
  const base64 = btoa(unescape(encodeURIComponent(svgString)));
  const dataUrl = `data:image/svg+xml;base64,${base64}`;

  const img = new Image();
  img.onload = () => {
    const canvas = document.createElement('canvas');
    canvas.width = WIDTH * scale;
    canvas.height = HEIGHT * scale;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.scale(scale, scale);
    ctx.drawImage(img, 0, 0, WIDTH, HEIGHT);

    const pngUrl = canvas.toDataURL('image/png');
    const link = document.createElement('a');
    link.href = pngUrl;
    link.download = `${props.geneSymbol}_gene_structure.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };
  img.src = dataUrl;
}

/**
 * Cleanup
 */
function cleanup(): void {
  if (svg) {
    svg.selectAll('*').remove();
    svg.remove();
    svg = null;
  }
  if (tooltipDiv) {
    tooltipDiv.remove();
    tooltipDiv = null;
  }
  isInitialized.value = false;
}

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
