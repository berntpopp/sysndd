<!-- src/components/gene/VariantTooltip.vue -->
<!--
  Tooltip component for displaying ClinVar variant details.

  Uses structured data props instead of v-html to avoid XSS vulnerabilities.
  Renders variant notation, classification, and review status.

  Pattern inspired by hnf1b-db TimelineTooltip component.
-->
<template>
  <!-- Teleport to body to avoid positioning issues inside scrollable containers -->
  <Teleport to="body">
    <div
      v-if="visible && data"
      class="variant-tooltip"
      :style="tooltipStyle"
    >
      <!-- Variant notation (primary identifier) -->
      <div class="tooltip-header">
        <strong>{{ data.hgvsp || data.variantId }}</strong>
      </div>

      <!-- Coding notation (if different from protein) -->
      <div v-if="data.hgvsc" class="tooltip-row coding-notation">
        {{ data.hgvsc }}
      </div>

      <!-- Classification with colored dot -->
      <div class="tooltip-row classification-row">
        <span class="classification-dot" :style="{ backgroundColor: data.color }" />
        <span>{{ data.label }}</span>
      </div>

      <!-- ClinVar review stars -->
      <div class="tooltip-row review-row">
        <span class="review-stars">{{ reviewStars }}</span>
        <span class="review-text">ClinVar review</span>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { computed, type CSSProperties } from 'vue';

/**
 * Tooltip data structure for variant display
 */
interface VariantTooltipData {
  /** HGVS protein notation (e.g., "p.Arg123Trp") */
  hgvsp: string | null;
  /** HGVS coding notation (e.g., "c.456A>G") */
  hgvsc: string | null;
  /** Variant ID fallback */
  variantId: string;
  /** ACMG classification label */
  label: string;
  /** ACMG classification color (hex) */
  color: string;
  /** ClinVar gold stars (0-4) */
  goldStars: number;
}

interface Props {
  /** Whether tooltip is visible */
  visible: boolean;
  /** Tooltip data (variant info) */
  data: VariantTooltipData | null;
  /** Position coordinates */
  position: { top: number; left: number };
}

const props = defineProps<Props>();

/**
 * Computed style for tooltip positioning
 */
const tooltipStyle = computed<CSSProperties>(() => ({
  top: `${props.position.top}px`,
  left: `${props.position.left}px`,
  opacity: props.visible ? 1 : 0,
  visibility: props.visible ? 'visible' : 'hidden',
}));

/**
 * Generate star display for ClinVar review status
 */
const reviewStars = computed(() => {
  const stars = props.data?.goldStars ?? 0;
  return '★'.repeat(stars) + '☆'.repeat(4 - stars);
});
</script>

<!-- Note: Not scoped because Teleport renders outside component tree -->
<style>
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

.variant-tooltip .tooltip-header {
  margin-bottom: 4px;
}

.variant-tooltip .tooltip-row {
  margin-bottom: 2px;
}

.variant-tooltip .coding-notation {
  color: #adb5bd;
  font-size: 11px;
}

.variant-tooltip .classification-row {
  display: flex;
  align-items: center;
  gap: 4px;
}

.variant-tooltip .classification-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.variant-tooltip .review-row {
  display: flex;
  align-items: center;
  gap: 4px;
}

.variant-tooltip .review-stars {
  color: #ffc107;
}

.variant-tooltip .review-text {
  color: #adb5bd;
  font-size: 11px;
}
</style>
