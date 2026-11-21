<template>
  <BBadge
    v-bind="attrs"
    :id="id"
    pill
    tag="button"
    type="button"
    variant="light"
    class="inline-help-badge"
    :aria-label="resolvedAriaLabel"
  >
    <i class="bi bi-question-lg" aria-hidden="true" />
  </BBadge>
</template>

<script setup lang="ts">
import { computed, useAttrs } from 'vue';

const props = defineProps<{
  id: string;
  ariaLabel?: string;
}>();

defineOptions({
  inheritAttrs: false,
});

const attrs = useAttrs();
const resolvedAriaLabel = computed(
  () => props.ariaLabel ?? (attrs['aria-label'] as string | undefined) ?? 'Explain'
);
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
  /* Outlined in the app's link blue, like the footer pills (cyan + black read as foreign). */
  border: 1px solid #9fb3c8;
  background: #fff !important;
  color: #0d47a1 !important;
  cursor: help;
}

.inline-help-badge:hover,
.inline-help-badge:focus-visible {
  background: #eef4ff !important;
  border-color: #0d47a1;
}

.inline-help-badge :deep(.bi) {
  display: block;
  font-size: 0.875rem;
  line-height: 1;
}
</style>
