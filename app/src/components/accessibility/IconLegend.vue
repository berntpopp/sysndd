<!-- components/accessibility/IconLegend.vue -->
<!-- Visual legend explaining symbolic icons used in tables/interfaces - WCAG 1.3.1 Info and Relationships -->
<template>
  <BCard
    body-class="p-2"
    class="mb-3"
  >
    <div class="d-flex flex-wrap gap-3 align-items-center">
      <strong class="me-2">Icon Legend:</strong>
      <div
        v-for="item in legendItems"
        :key="item.label"
        class="d-flex align-items-center gap-1"
      >
        <!-- Dynamic component rendering (e.g., CategoryIcon) -->
        <component
          :is="item.component"
          v-if="item.component"
          v-bind="item.componentProps"
          aria-hidden="true"
        />
        <!-- Standard icon rendering -->
        <i
          v-else-if="item.icon"
          :class="item.icon"
          :style="{ color: item.color }"
          aria-hidden="true"
        />
        <span class="small">{{ item.label }}</span>
      </div>
    </div>
  </BCard>
</template>

<script setup>
import { BCard } from 'bootstrap-vue-next';

/**
 * IconLegend component displays a visual key for icons used in the interface
 *
 * Always visible (not collapsible) - legends are reference material users may need
 * to consult repeatedly while scanning tables.
 *
 * Usage:
 *   <IconLegend :legend-items="legendItems" />
 *
 * Props:
 * - legendItems: Array of legend items
 *   Each item: {
 *     icon?: string,           // Icon class (e.g., 'bi bi-check-circle-fill')
 *     color?: string,          // Icon color (e.g., '#28a745')
 *     component?: string,      // Component name (e.g., 'CategoryIcon')
 *     componentProps?: object, // Props for component
 *     label: string            // Text label
 *   }
 */
defineProps({
  legendItems: {
    type: Array,
    required: true,
  },
});
</script>
