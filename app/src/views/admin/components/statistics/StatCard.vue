<template>
  <BCard class="stat-card h-100 text-start">
    <div class="d-flex justify-content-between align-items-start gap-2">
      <div>
        <div class="stat-card__label small">{{ label }}</div>
        <div class="display-6 fw-bold">{{ formattedValue }}</div>
      </div>
      <div v-if="delta !== undefined" class="stat-card__delta" :style="{ color: trendColor }">
        <i :class="trendIcon" aria-hidden="true" />
        <span class="visually-hidden">{{ trendWord }}</span>
        {{ Math.abs(delta) }}%
      </div>
    </div>
    <div v-if="context" class="stat-card__label small mt-2">
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
  decimals?: number; // fixed fraction digits, e.g. 2 for a daily rate
}

const props = defineProps<Props>();

// Okabe-Ito hues, darkened to >= 4.5:1 on white (the originals #009E73 / #D55E00
// were 3.3:1 and 3.9:1).
const TREND_COLORS = {
  up: '#00785a',
  down: '#a94400',
  neutral: '#595959',
};

const formattedValue = computed(() => {
  // Ensure value is a number for toLocaleString()
  const numValue = typeof props.value === 'number' ? props.value : Number(props.value) || 0;
  const formatted = numValue.toLocaleString('en-US', {
    minimumFractionDigits: props.decimals ?? 0,
    maximumFractionDigits: props.decimals ?? 0,
  });
  return props.unit ? `${formatted} ${props.unit}` : formatted;
});

const trendIcon = computed(() => {
  if (props.delta === undefined) return '';
  if (props.delta > 0) return 'bi bi-arrow-up';
  if (props.delta < 0) return 'bi bi-arrow-down';
  return 'bi bi-arrow-right';
});

const trendWord = computed(() => {
  if (props.delta === undefined || props.delta === 0) return 'No change';
  return props.delta > 0 ? 'Up' : 'Down';
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
  border: 1px solid var(--border-subtle);
  background: var(--surface-raised);
  box-shadow: var(--shadow-xs);
}

.stat-card__label {
  color: var(--text-secondary, #616161);
}

.stat-card__delta {
  flex-shrink: 0;
  font-weight: 600;
  white-space: nowrap;
}
</style>
