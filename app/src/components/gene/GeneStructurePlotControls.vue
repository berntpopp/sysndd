<!-- src/components/gene/GeneStructurePlotControls.vue -->
<!--
  Controls row + filter legend rows for GeneStructurePlotWithVariants.vue.

  Presentational only: renders the coloring-mode toggle, the gene info
  summary, the zoom-reset button, the SVG/PNG export buttons, and the
  pathogenicity/effect-type filter chip rows (with "only"/"all" shortcuts
  and count labels). All reactive filter state, D3 rendering, and lifecycle
  stay in the parent; this component receives computed legend rows as props
  and emits the requested action back up. It does not own D3.
-->
<template>
  <div class="gene-structure-plot-controls">
    <!-- Controls row: Coloring mode + Gene info + Zoom reset + Export buttons -->
    <div
      class="controls-row d-flex align-items-center justify-content-between flex-wrap gap-2 mt-1 px-2"
    >
      <!-- Coloring mode toggle -->
      <div class="btn-group btn-group-sm" role="group" aria-label="Variant coloring mode">
        <button
          type="button"
          class="btn btn-xs"
          :class="coloringMode === 'acmg' ? 'btn-primary' : 'btn-outline-secondary'"
          @click="emit('set-coloring-mode', 'acmg')"
        >
          Classification
        </button>
        <button
          type="button"
          class="btn btn-xs"
          :class="coloringMode === 'effect' ? 'btn-primary' : 'btn-outline-secondary'"
          @click="emit('set-coloring-mode', 'effect')"
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

      <!-- Zoom reset button (only when zoomed): resets zoom so all variants are visible again -->
      <button
        v-if="zoomDomain"
        type="button"
        class="btn btn-outline-warning btn-xs"
        title="Reset zoom (or double-click plot)"
        @click="emit('reset-zoom')"
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
          @click="emit('download-svg')"
        >
          <i class="bi bi-download" />
          SVG
        </button>
        <button
          type="button"
          class="btn btn-outline-secondary btn-xs"
          title="Download as PNG"
          @click="emit('download-png')"
        >
          <i class="bi bi-image" />
          PNG
        </button>
      </div>
    </div>

    <!-- Filter rows: Pathogenicity (row 1) + Effect type (row 2) -->
    <div v-if="hasVariants" class="filter-rows mt-1 px-2">
      <!-- Row 1: Pathogenicity filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1">
        <span v-for="item in pathogenicityItems" :key="item.key" class="filter-group">
          <button
            type="button"
            class="filter-chip"
            :class="{ 'filter-chip--hidden': !item.visible }"
            :aria-label="`Toggle ${item.label} variants`"
            :aria-pressed="item.visible"
            @click="emit('toggle-pathogenicity', item.key)"
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
            @click="emit('select-only-pathogenicity', item.key)"
          >
            only
          </button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all pathogenicity categories"
          @click="emit('select-all-pathogenicity')"
        >
          all
        </button>
      </div>

      <!-- Row 2: Effect type filters -->
      <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1 mt-1">
        <span v-for="item in effectItems" :key="item.key" class="filter-group">
          <button
            type="button"
            class="filter-chip"
            :class="{ 'filter-chip--hidden': !item.visible }"
            :aria-label="`Toggle ${item.label} variants`"
            :aria-pressed="item.visible"
            @click="emit('toggle-effect', item.key)"
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
            @click="emit('select-only-effect', item.key)"
          >
            only
          </button>
        </span>
        <button
          type="button"
          class="all-btn"
          title="Show all effect types"
          @click="emit('select-all-effects')"
        >
          all
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { GeneStructureRenderData } from '@/types/ensembl';
import { formatGenomicCoordinate } from '@/types/ensembl';
import type { EffectType, ColoringMode } from '@/types/protein';

/** Pathogenicity filter keys on the gene-structure plot filter state. */
export type PathogenicityFilterKey =
  | 'pathogenic'
  | 'likelyPathogenic'
  | 'vus'
  | 'likelyBenign'
  | 'benign';

/** A single pathogenicity legend row: chip label/color/visibility + count. */
export interface PathogenicityLegendRow {
  key: PathogenicityFilterKey;
  label: string;
  color: string;
  visible: boolean;
  count: number;
}

/** A single effect-type legend row: chip label/color/visibility + count. */
export interface EffectLegendRow {
  key: EffectType;
  label: string;
  color: string;
  visible: boolean;
  count: number;
}

interface Props {
  /** Current variant marker coloring mode (ACMG classification or effect type) */
  coloringMode: ColoringMode;
  /** Gene structure metadata backing the strand/coordinate/transcript summary */
  geneData: GeneStructureRenderData;
  /** Current zoom domain; the reset-zoom button only renders while zoomed in */
  zoomDomain: [number, number] | null;
  /** Whether any variants are available (hides the filter rows when empty) */
  hasVariants: boolean;
  /** Computed pathogenicity legend rows (label/color/visibility/count) */
  pathogenicityItems: PathogenicityLegendRow[];
  /** Computed effect-type legend rows (label/color/visibility/count) */
  effectItems: EffectLegendRow[];
}

defineProps<Props>();

const emit = defineEmits<{
  /** Emitted when the Classification/Effect coloring toggle is clicked */
  (e: 'set-coloring-mode', mode: ColoringMode): void;
  /** Emitted when the zoom-reset button is clicked (shows all variants again) */
  (e: 'reset-zoom'): void;
  /** Emitted when the SVG export button is clicked */
  (e: 'download-svg'): void;
  /** Emitted when the PNG export button is clicked */
  (e: 'download-png'): void;
  /** Emitted when a pathogenicity filter chip is toggled */
  (e: 'toggle-pathogenicity', key: PathogenicityFilterKey): void;
  /** Emitted when a pathogenicity "only" shortcut is clicked */
  (e: 'select-only-pathogenicity', key: PathogenicityFilterKey): void;
  /** Emitted when the pathogenicity "all" shortcut is clicked */
  (e: 'select-all-pathogenicity'): void;
  /** Emitted when an effect-type filter chip is toggled */
  (e: 'toggle-effect', effectType: EffectType): void;
  /** Emitted when an effect-type "only" shortcut is clicked */
  (e: 'select-only-effect', effectType: EffectType): void;
  /** Emitted when the effect-type "all" shortcut is clicked */
  (e: 'select-all-effects'): void;
}>();

/**
 * Format a genomic coordinate for the gene info summary (Mb/kb/bp units).
 */
function formatCoord(value: number): string {
  return formatGenomicCoordinate(value);
}
</script>

<style scoped>
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
</style>
