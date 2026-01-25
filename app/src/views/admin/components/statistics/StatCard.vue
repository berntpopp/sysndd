<template>
  <BCard class="stat-card h-100">
    <div class="d-flex justify-content-between align-items-start">
      <div>
        <div class="text-muted small">{{ label }}</div>
        <div class="display-6 fw-bold">{{ formattedValue }}</div>
      </div>
      <div v-if="delta !== undefined" class="text-end">
        <span :style="{ color: trendColor }"> {{ trendIcon }} {{ Math.abs(delta) }}% </span>
      </div>
    </div>
    <div v-if="context" class="small text-muted mt-2">
      {{ context }}
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard } from 'bootstrap-vue-next';

interface Props {
  label: string;
  value: number;
  delta?: number; // Percentage change vs previous period
  context?: string; // e.g., "vs last month"
  unit?: string; // e.g., "entities"
}

const props = defineProps<Props>();

// Okabe-Ito colorblind-safe colors for accessibility
const TREND_COLORS = {
  up: '#009E73', // Bluish green
  down: '#D55E00', // Vermillion
  neutral: '#666666',
};

const formattedValue = computed(() => {
  // Ensure value is a number for toLocaleString()
  const numValue = typeof props.value === 'number' ? props.value : Number(props.value) || 0;
  const formatted = numValue.toLocaleString();
  return props.unit ? `${formatted} ${props.unit}` : formatted;
});

const trendIcon = computed(() => {
  if (props.delta === undefined) return '';
  if (props.delta > 0) return '\u2191'; // Up arrow
  if (props.delta < 0) return '\u2193'; // Down arrow
  return '\u2192'; // Right arrow for neutral
});

const trendColor = computed(() => {
  if (props.delta === undefined) return TREND_COLORS.neutral;
  if (props.delta > 0) return TREND_COLORS.up;
  if (props.delta < 0) return TREND_COLORS.down;
  return TREND_COLORS.neutral;
});
</script>

<style scoped>
.stat-card {
  border-left: 4px solid #6699cc;
}
</style>
