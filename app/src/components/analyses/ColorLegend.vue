<!-- src/components/analyses/ColorLegend.vue -->
<template>
  <div :class="['color-legend', `color-legend--${orientation}`]">
    <div
      v-if="title"
      class="color-legend__title"
    >
      {{ title }}
    </div>
    <div
      class="color-legend__bar"
      :style="gradientStyle"
    />
    <div class="color-legend__labels">
      <span
        v-for="label in displayLabels"
        :key="label.value"
        class="color-legend__label"
      >
        {{ label.text }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, type CSSProperties } from 'vue';

/**
 * ColorLegend - Reusable color legend component for visualizations
 *
 * Displays a gradient bar with labels to explain color scales in charts.
 * Commonly used for correlation heatmaps, intensity plots, etc.
 *
 * @example
 * <ColorLegend
 *   :min="-1"
 *   :max="1"
 *   :colors="['#000080', '#fff', '#B22222']"
 *   title="Correlation Coefficient (R)"
 *   :labels="[
 *     { value: -1, text: '-1 (negative)' },
 *     { value: 0, text: '0' },
 *     { value: 1, text: '+1 (positive)' }
 *   ]"
 * />
 */

interface LabelItem {
  value: number;
  text: string;
}

interface Props {
  /** Minimum value for the scale */
  min?: number;
  /** Maximum value for the scale */
  max?: number;
  /** Array of colors for the gradient (start, middle, end) */
  colors?: string[];
  /** Custom labels to display (defaults to min, mid, max) */
  labels?: LabelItem[];
  /** Title text above the legend */
  title?: string;
  /** Layout orientation */
  orientation?: 'horizontal' | 'vertical';
}

const props = withDefaults(defineProps<Props>(), {
  min: -1,
  max: 1,
  colors: () => ['#000080', '#fff', '#B22222'],
  labels: undefined,
  title: '',
  orientation: 'horizontal',
});

/**
 * Computed CSS style for the gradient bar
 */
const gradientStyle = computed<CSSProperties>(() => {
  const direction = props.orientation === 'horizontal' ? 'to right' : 'to top';
  const gradient = `linear-gradient(${direction}, ${props.colors.join(', ')})`;
  return { background: gradient };
});

/**
 * Labels to display - uses custom labels if provided, otherwise generates defaults
 */
const displayLabels = computed<LabelItem[]>(() => {
  if (props.labels) return props.labels;
  // Default: min, mid, max
  const mid = (props.min + props.max) / 2;
  return [
    { value: props.min, text: String(props.min) },
    { value: mid, text: String(mid) },
    { value: props.max, text: String(props.max) },
  ];
});
</script>

<style scoped>
.color-legend {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 0.75rem;
}

.color-legend--horizontal {
  width: 200px;
}

.color-legend--vertical {
  height: 200px;
  flex-direction: row;
}

.color-legend__title {
  font-weight: 600;
  margin-bottom: 2px;
  color: #495057;
}

.color-legend__bar {
  height: 12px;
  border-radius: 2px;
  border: 1px solid #dee2e6;
}

.color-legend--vertical .color-legend__bar {
  width: 12px;
  height: 100%;
}

.color-legend__labels {
  display: flex;
  justify-content: space-between;
}

.color-legend--vertical .color-legend__labels {
  flex-direction: column-reverse;
  justify-content: space-between;
  height: 100%;
}

.color-legend__label {
  color: #6c757d;
  font-size: 0.7rem;
}
</style>
