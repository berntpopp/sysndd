<template>
  <div class="variant-panel" role="region" aria-label="ClinVar variant selection panel">
    <!-- Panel Header -->
    <div class="panel-header">
      <span class="fw-semibold small">Variants ({{ mappableVariants.length }})</span>
      <BButton
        v-if="selectedResidues.size > 0"
        variant="link"
        size="sm"
        class="text-decoration-none p-0"
        aria-label="Clear all highlighted variants"
        @click="clearAll"
      >
        Clear all
      </BButton>
    </div>

    <!-- No variants state -->
    <div v-if="mappableVariants.length === 0" class="text-center py-3">
      <span class="text-muted small">
        {{ variants.length === 0 ? 'No ClinVar variants available' : 'No variants with protein positions' }}
      </span>
    </div>

    <!-- Variant List (scrollable) -->
    <div v-else ref="listContainer" class="variant-list" role="list" aria-label="ClinVar variants with protein positions">
      <label
        v-for="item in mappableVariants"
        :key="item.variant.variant_id"
        class="variant-item"
        role="listitem"
        @mouseenter="showTooltip($event, item)"
        @mouseleave="hideTooltip"
      >
        <input
          type="checkbox"
          :checked="selectedResidues.has(item.residue)"
          :aria-label="`Highlight ${item.variant.hgvsp || item.variant.variant_id} on 3D structure`"
          @change="toggleVariant(item)"
        />
        <span
          class="acmg-dot"
          :style="{ backgroundColor: item.color }"
          :aria-hidden="true"
        ></span>
        <span class="variant-info">
          <span class="variant-notation small">
            {{ item.variant.hgvsp || item.variant.hgvsc || item.variant.variant_id }}
          </span>
          <span class="variant-class small text-muted">
            {{ item.label }}
          </span>
        </span>
      </label>
    </div>

    <!-- Single shared tooltip (positioned via JS) -->
    <div
      ref="tooltipEl"
      class="variant-tooltip"
      :style="tooltipStyle"
      v-html="tooltipContent"
    ></div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, type CSSProperties } from 'vue';
import { BButton } from 'bootstrap-vue-next';
import type { ClinVarVariant } from '@/types/external';
import {
  ACMG_COLORS,
  ACMG_LABELS,
  parseResidueNumber,
  classifyClinicalSignificance,
  type AcmgClassification,
} from '@/types/alphafold';

interface Props {
  variants: ClinVarVariant[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'toggle-variant': [payload: { variant: ClinVarVariant; selected: boolean }];
  'clear-all': [];
}>();

// Track selected residues for checkbox state
const selectedResidues = ref<Set<number>>(new Set());

// Refs for tooltip positioning
const listContainer = ref<HTMLElement | null>(null);
const tooltipEl = ref<HTMLElement | null>(null);

// Tooltip state
const tooltipContent = ref('');
const tooltipVisible = ref(false);
const tooltipPosition = ref({ top: 0, left: 0 });

// Computed tooltip style
const tooltipStyle = computed<CSSProperties>(() => ({
  opacity: tooltipVisible.value ? 1 : 0,
  visibility: tooltipVisible.value ? 'visible' : 'hidden',
  top: `${tooltipPosition.value.top}px`,
  left: `${tooltipPosition.value.left}px`,
}));

// Processable variant item (variant + parsed residue + ACMG info)
interface MappableVariant {
  variant: ClinVarVariant;
  residue: number;
  classification: AcmgClassification | null;
  color: string;
  label: string;
}

// Filter variants to only those with parseable protein positions (missense/inframe only)
// parseResidueNumber returns null for frameshift, stop, and splice variants
// Sorted by residue number for spatial ordering
const mappableVariants = computed<MappableVariant[]>(() => {
  const items: MappableVariant[] = [];

  for (const variant of props.variants) {
    const residue = parseResidueNumber(variant.hgvsp);
    if (residue === null) continue; // Skip non-mappable variants (frameshift, stop, splice)

    const classification = classifyClinicalSignificance(variant.clinical_significance);
    items.push({
      variant,
      residue,
      classification,
      color: classification ? ACMG_COLORS[classification] : '#999999',
      label: classification ? ACMG_LABELS[classification] : variant.clinical_significance,
    });
  }

  // Sort by residue number (ascending) for spatial ordering in list
  items.sort((a, b) => a.residue - b.residue);
  return items;
});

// Toggle variant selection
function toggleVariant(item: MappableVariant): void {
  const isCurrentlySelected = selectedResidues.value.has(item.residue);
  const newSelected = !isCurrentlySelected;

  if (newSelected) {
    selectedResidues.value.add(item.residue);
  } else {
    selectedResidues.value.delete(item.residue);
  }

  // Force reactivity update (Set mutation doesn't trigger)
  selectedResidues.value = new Set(selectedResidues.value);

  emit('toggle-variant', { variant: item.variant, selected: newSelected });
}

// Clear all selections
function clearAll(): void {
  selectedResidues.value = new Set();
  emit('clear-all');
}

/**
 * Show tooltip near the hovered element
 * Uses position:fixed with viewport coordinates to avoid overflow clipping
 */
function showTooltip(event: MouseEvent, item: MappableVariant): void {
  // Capture element rect synchronously before it might become stale
  const targetElement = event.currentTarget as HTMLElement;
  if (!targetElement) return;
  const itemRect = targetElement.getBoundingClientRect();

  const stars = '★'.repeat(item.variant.gold_stars) + '☆'.repeat(4 - item.variant.gold_stars);
  tooltipContent.value = `
    <strong>${item.variant.hgvsp || item.variant.variant_id}</strong><br/>
    ${item.variant.hgvsc ? `<span style="color: #adb5bd; font-size: 11px;">${item.variant.hgvsc}</span><br/>` : ''}
    <span style="color: ${item.color};">●</span> ${item.label}<br/>
    <span style="color: #ffc107;">${stars}</span> ClinVar review
  `.trim();

  // Position calculation after content is set (need rAF for tooltip dimensions)
  requestAnimationFrame(() => {
    if (!tooltipEl.value) return;

    const tooltipRect = tooltipEl.value.getBoundingClientRect();

    // Position to the left of the item in viewport coordinates (for position:fixed)
    let left = itemRect.left - tooltipRect.width - 10;
    let top = itemRect.top + (itemRect.height / 2) - (tooltipRect.height / 2);

    // Ensure tooltip stays within viewport bounds
    const minTop = 10;
    const maxTop = window.innerHeight - tooltipRect.height - 10;
    top = Math.max(minTop, Math.min(maxTop, top));

    // If tooltip would go off left edge, position to the right of item instead
    if (left < 10) {
      left = itemRect.right + 10;
    }

    tooltipPosition.value = { top, left };
    tooltipVisible.value = true;
  });
}

/**
 * Hide tooltip
 */
function hideTooltip(): void {
  tooltipVisible.value = false;
}
</script>

<style scoped>
.variant-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  position: relative;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 10px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  flex-shrink: 0;
}

.variant-list {
  overflow-y: auto;
  flex: 1;
  min-height: 0;
  position: relative;
}

.variant-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
  transition: background-color 0.15s;
}

.variant-item:hover {
  background-color: #e9ecef;
}

.variant-item:focus-within {
  background-color: #e9ecef;
  outline: 2px solid #0d6efd;
  outline-offset: -2px;
}

.acmg-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.variant-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.variant-notation {
  font-family: 'Courier New', monospace;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.variant-class {
  font-size: 0.7rem;
}

/* Single shared tooltip - uses position:fixed to avoid overflow clipping */
/* Matches lollipop plot D3 tooltip style */
.variant-tooltip {
  position: fixed;
  background: rgba(0, 0, 0, 0.85);
  color: #fff;
  border-radius: 4px;
  padding: 8px 12px;
  font-size: 12px;
  line-height: 1.4;
  white-space: nowrap;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  z-index: 9999;
  pointer-events: none;
  transition: opacity 0.15s, visibility 0.15s;
  text-align: left;
}

/* Tooltip arrow pointing right (towards the item) */
.variant-tooltip::after {
  content: '';
  position: absolute;
  right: -6px;
  top: 50%;
  transform: translateY(-50%);
  border-width: 6px;
  border-style: solid;
  border-color: transparent transparent transparent rgba(0, 0, 0, 0.85);
}
</style>
