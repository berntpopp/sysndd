<!-- src/components/gene/ProteinLollipopControlsPanel.vue -->
<!--
  Controls, legends, and filters for ProteinDomainLollipopPlot.vue.

  Purely presentational: every field is a read-only prop and every user
  interaction (coloring mode, pathogenicity/effect filter toggles, "only"/"all"
  shortcuts, SVG/PNG export) is surfaced as an event. The parent owns
  `LollipopFilterState`, the legend computations, and the export composable;
  this component never mutates state directly.

  Rows:
   - Controls row: coloring-mode toggle (left) + domain legend (center) +
     export buttons (right)
   - Filter rows: pathogenicity filters (row 1) + effect-type filters (row 2)
-->
<template>
  <!-- Controls row: Coloring toggle (left) + Domain legend (center) + Export buttons (right) -->
  <div
    class="controls-row d-flex align-items-center justify-content-between flex-wrap gap-2 mt-1 px-2"
  >
    <!-- Coloring mode toggle -->
    <div class="btn-group btn-group-sm" role="group" aria-label="Variant coloring mode">
      <button
        type="button"
        class="btn btn-xs"
        :class="coloringMode === 'acmg' ? 'btn-primary' : 'btn-outline-secondary'"
        @click="$emit('update:coloring-mode', 'acmg')"
      >
        Classification
      </button>
      <button
        type="button"
        class="btn btn-xs"
        :class="coloringMode === 'effect' ? 'btn-primary' : 'btn-outline-secondary'"
        @click="$emit('update:coloring-mode', 'effect')"
      >
        Effect
      </button>
    </div>

    <!-- Domain legend (compact, inline, non-interactive) -->
    <div
      v-if="domainLegendItems.length > 0"
      class="domain-legend d-flex flex-wrap justify-content-center gap-2"
    >
      <span v-for="item in domainLegendItems" :key="item.type" class="domain-legend-item">
        <span class="domain-dot" :style="{ backgroundColor: item.color }" />
        <span class="domain-label">{{ item.label }}</span>
      </span>
    </div>

    <!-- Export buttons -->
    <div class="export-buttons d-flex gap-1">
      <button
        type="button"
        class="btn btn-outline-secondary btn-xs"
        title="Download as SVG"
        @click="$emit('download-svg')"
      >
        <i class="bi bi-download" />
        SVG
      </button>
      <button
        type="button"
        class="btn btn-outline-secondary btn-xs"
        title="Download as PNG"
        @click="$emit('download-png')"
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
      <span v-for="item in legendItems" :key="item.label" class="filter-group">
        <button
          type="button"
          class="filter-chip"
          :class="{ 'filter-chip--hidden': !item.visible }"
          :aria-label="`Toggle ${item.label} variants`"
          :aria-pressed="item.visible"
          @click="$emit('toggle-pathogenicity', item.key)"
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
          @click="$emit('select-only-pathogenicity', item.key)"
        >
          only
        </button>
      </span>
      <button
        type="button"
        class="all-btn"
        title="Show all pathogenicity categories"
        @click="$emit('select-all-pathogenicity')"
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
          @click="$emit('toggle-effect', item.key)"
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
          @click="$emit('select-only-effect', item.key)"
        >
          only
        </button>
      </span>
      <button
        type="button"
        class="all-btn"
        title="Show all effect types"
        @click="$emit('select-all-effects')"
      >
        all
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ColoringMode, EffectType } from '@/types';
import type { PathogenicityFilterKey } from './proteinLollipopControls';

/** A single pathogenicity-filter legend entry (Pathogenic/Likely pathogenic/...). */
interface PathogenicityLegendItem {
  key: PathogenicityFilterKey;
  label: string;
  color: string;
  visible: boolean;
  count: number;
}

/** A single effect-type filter legend entry (missense/frameshift/...). */
interface EffectLegendItem {
  key: EffectType;
  label: string;
  color: string;
  visible: boolean;
  count: number;
}

/** A single domain-type legend entry (read-only display, non-interactive). */
interface DomainLegendItem {
  type: string;
  label: string;
  color: string;
}

interface Props {
  /** Current coloring mode (acmg or effect); read-only, changes flow up via emit. */
  coloringMode: ColoringMode;
  /** Domain-type legend items (non-interactive, purely informational). */
  domainLegendItems: DomainLegendItem[];
  /** Pathogenicity filter legend items (visibility + counts). */
  legendItems: PathogenicityLegendItem[];
  /** Effect-type filter legend items (visibility + counts). */
  effectLegendItems: EffectLegendItem[];
}

defineProps<Props>();

defineEmits<{
  /** Coloring mode toggle clicked. */
  (e: 'update:coloring-mode', mode: ColoringMode): void;
  /** A pathogenicity filter chip was clicked (toggle visibility). */
  (e: 'toggle-pathogenicity', key: PathogenicityFilterKey): void;
  /** "only" clicked for a pathogenicity class (isolate it). */
  (e: 'select-only-pathogenicity', key: PathogenicityFilterKey): void;
  /** "all" clicked for pathogenicity classes (show every class). */
  (e: 'select-all-pathogenicity'): void;
  /** An effect-type filter chip was clicked (toggle visibility). */
  (e: 'toggle-effect', effectType: EffectType): void;
  /** "only" clicked for an effect type (isolate it). */
  (e: 'select-only-effect', effectType: EffectType): void;
  /** "all" clicked for effect types (show every type). */
  (e: 'select-all-effects'): void;
  /** SVG export button clicked. */
  (e: 'download-svg'): void;
  /** PNG export button clicked. */
  (e: 'download-png'): void;
}>();
</script>

<style scoped>
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
</style>
