<template>
  <BBadge :id="id" pill href="#" variant="info" class="inline-help-badge" :aria-label="ariaLabel">
    <i class="bi bi-question-circle-fill" aria-hidden="true" />
  </BBadge>
</template>

<script setup lang="ts">
defineProps<{
  id: string;
  ariaLabel: string;
}>();
</script>

<style scoped>
.inline-help-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem !important;
  min-width: 1.5rem !important;
  max-width: 1.5rem !important;
  height: 1.5rem !important;
  min-height: 1.5rem !important;
  max-height: 1.5rem !important;
  padding: 0;
  flex: 0 0 1.5rem;
  line-height: 1;
  text-decoration: none;
  vertical-align: middle;
}

.inline-help-badge :deep(.bi) {
  display: block;
  font-size: 0.875rem;
  line-height: 1;
}
</style>
