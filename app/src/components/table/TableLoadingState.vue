<template>
  <div
    class="table-loading-state"
    :class="`table-loading-state--${mode}`"
    role="status"
    aria-live="polite"
    :aria-label="label"
  >
    <span class="visually-hidden">{{ label }}</span>
    <div v-for="row in rows" :key="row" class="table-loading-state__row">
      <span class="table-loading-state__cell table-loading-state__cell--primary" />
      <span class="table-loading-state__cell" />
      <span class="table-loading-state__cell" />
      <span class="table-loading-state__cell table-loading-state__cell--short" />
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    label?: string
    rows?: number
    mode?: 'table' | 'cards'
  }>(),
  {
    label: 'Loading table data',
    rows: 8,
    mode: 'table',
  },
)
</script>

<style scoped>
.table-loading-state {
  display: grid;
  gap: 0.5rem;
}

.table-loading-state__row {
  display: grid;
  grid-template-columns:
    minmax(7rem, 1.4fr) repeat(2, minmax(5rem, 1fr))
    minmax(4rem, 0.6fr);
  gap: 0.75rem;
  min-height: 2.75rem;
  align-items: center;
  padding: 0.625rem 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #fff;
}

.table-loading-state__cell {
  display: block;
  height: 0.75rem;
  border-radius: 999px;
  background: linear-gradient(90deg, #eef2f7 25%, #f8fafc 37%, #eef2f7 63%);
  background-size: 400% 100%;
  animation: table-loading-shimmer 1.4s ease infinite;
}

.table-loading-state__cell--primary {
  height: 0.95rem;
}

.table-loading-state__cell--short {
  width: 65%;
}

.table-loading-state--cards .table-loading-state__row {
  grid-template-columns: 1fr;
  min-height: 6rem;
}

@keyframes table-loading-shimmer {
  0% {
    background-position: 100% 0;
  }

  100% {
    background-position: 0 0;
  }
}

@media (max-width: 767.98px) {
  .table-loading-state__row {
    grid-template-columns: 1fr;
    min-height: 5.5rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .table-loading-state__cell {
    animation: none;
    background-size: 100% 100%;
  }
}
</style>
