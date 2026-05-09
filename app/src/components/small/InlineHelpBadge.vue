<template>
  <BBadge
    v-bind="attrs"
    :id="id"
    pill
    tag="button"
    type="button"
    variant="info"
    class="inline-help-badge"
    :aria-label="resolvedAriaLabel"
  >
    <i class="bi bi-question-circle-fill" aria-hidden="true" />
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
  border: 0;
  cursor: help;
}

.inline-help-badge :deep(.bi) {
  display: block;
  font-size: 0.875rem;
  line-height: 1;
}
</style>
