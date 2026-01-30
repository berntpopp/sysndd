<template>
  <div class="table-skeleton" role="status" aria-label="Loading table data">
    <!-- Header row -->
    <div class="skeleton-row skeleton-header">
      <div v-for="col in columns" :key="`header-${col}`" class="skeleton-cell">
        <div class="skeleton-shimmer" :style="{ width: getHeaderWidth(col), height: '1rem' }" />
      </div>
    </div>

    <!-- Data rows -->
    <div v-for="row in rows" :key="`row-${row}`" class="skeleton-row">
      <div v-for="col in columns" :key="`cell-${row}-${col}`" class="skeleton-cell">
        <div class="skeleton-shimmer" :style="{ width: getCellWidth(col), height: '0.875rem' }" />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue';

export default defineComponent({
  name: 'TableSkeleton',
  props: {
    rows: {
      type: Number,
      default: 5,
    },
    columns: {
      type: Number,
      default: 4,
    },
  },
  methods: {
    getHeaderWidth(col: number): string {
      // Vary header widths for more realistic appearance
      const widths = ['20%', '40%', '30%', '10%'];
      return widths[(col - 1) % widths.length];
    },
    getCellWidth(col: number): string {
      // Vary cell widths for more realistic appearance
      const widths = ['25%', '50%', '35%', '15%'];
      return widths[(col - 1) % widths.length];
    },
  },
});
</script>

<style scoped>
.table-skeleton {
  width: 100%;
  border: 1px solid var(--border-color, #dee2e6);
  border-radius: var(--radius-md, 0.375rem);
  overflow: hidden;
}

.skeleton-row {
  display: flex;
  padding: 0.75rem;
  border-bottom: 1px solid var(--border-color, #dee2e6);
}

.skeleton-row:last-child {
  border-bottom: none;
}

.skeleton-header {
  background-color: #f8f9fa;
  font-weight: 600;
}

.skeleton-cell {
  flex: 1;
  padding: 0 0.5rem;
}

.skeleton-cell:first-child {
  padding-left: 0;
}

.skeleton-cell:last-child {
  padding-right: 0;
}
</style>
