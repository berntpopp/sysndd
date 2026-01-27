<template>
  <BRow class="identifier-row align-items-center py-2">
    <BCol cols="12" md="4" class="identifier-row__label">
      <span class="text-muted">{{ label }}</span>
    </BCol>
    <BCol cols="12" md="8" class="identifier-row__content">
      <div v-if="!value || value === ''" class="text-muted">
        Not available
      </div>
      <div v-else class="d-flex align-items-center gap-2">
        <span class="identifier-row__value">{{ value }}</span>
        <BButton
          v-if="showCopy"
          v-b-tooltip.hover.bottom
          size="sm"
          variant="outline-secondary"
          class="btn-xs"
          :aria-label="`Copy ${label} to clipboard`"
          title="Copy to clipboard"
          @click="handleCopy"
        >
          <i class="bi bi-clipboard" />
        </BButton>
        <BButton
          v-if="externalUrl"
          v-b-tooltip.hover.bottom
          size="sm"
          variant="outline-primary"
          class="btn-xs"
          :href="externalUrl"
          :aria-label="`Open ${label} in ${externalLabel}`"
          :title="`View in ${externalLabel}`"
          target="_blank"
          rel="noopener noreferrer"
        >
          <i class="bi bi-box-arrow-up-right" />
        </BButton>
      </div>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
import { BRow, BCol, BButton } from 'bootstrap-vue-next';
import useToast from '@/composables/useToast';

interface Props {
  label: string;
  value?: string;
  externalUrl?: string;
  externalLabel?: string;
  showCopy?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  value: undefined,
  externalUrl: undefined,
  externalLabel: undefined,
  showCopy: true,
});

// For externalLabel, default to label if not provided
const externalLabel = props.externalLabel || props.label;

const { makeToast } = useToast();

async function handleCopy() {
  if (!props.value) return;

  try {
    await navigator.clipboard.writeText(props.value);
    makeToast('Copied!', 'Info', 'info');
  } catch (_e) {
    makeToast('Failed to copy to clipboard', 'Error', 'danger');
  }
}
</script>

<style scoped>
.identifier-row {
  border-bottom: 1px solid #eee;
}

.identifier-row:last-child {
  border-bottom: none;
}

.identifier-row__label {
  font-weight: 500;
}

.identifier-row__value {
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
}

/* Small button variant matching GeneView.vue pattern */
.btn-xs {
  padding: 0.15rem 0.4rem;
  font-size: 0.75rem;
  line-height: 1.2;
}

.btn-xs i {
  font-size: 0.85rem;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .identifier-row__label {
    margin-bottom: 0.25rem;
  }
}
</style>
