<template>
  <!-- Compact badge mode -->
  <span
    v-if="compact"
    class="identifier-badge"
    :class="{ 'identifier-badge--unavailable': !value }"
  >
    <span class="identifier-badge__label">{{ label }}</span>
    <span v-if="value" class="identifier-badge__value">{{ value }}</span>
    <span v-else class="identifier-badge__empty">n/a</span>
    <a
      v-if="value && showCopy"
      v-b-tooltip.hover.bottom
      href="#"
      class="identifier-badge__action"
      :aria-label="`Copy ${label} to clipboard`"
      title="Copy to clipboard"
      @click.prevent="handleCopy"
    >
      <i class="bi bi-clipboard" aria-hidden="true" />
    </a>
    <a
      v-if="externalUrl"
      v-b-tooltip.hover.bottom
      class="identifier-badge__action identifier-badge__action--external"
      :href="externalUrl"
      :aria-label="`Open ${label} in ${resolvedExternalLabel} (opens in new tab)`"
      :title="`View in ${resolvedExternalLabel}`"
      target="_blank"
      rel="noopener noreferrer"
      @click.stop
    >
      <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
    </a>
  </span>

  <!-- Full row mode (default) -->
  <div v-else class="identifier-row d-flex align-items-center">
    <div class="identifier-row__label text-end fw-semibold pe-2">
      {{ label }}
    </div>
    <div class="identifier-row__content">
      <span v-if="!value || value === ''" class="text-muted fst-italic">Not available</span>
      <span v-else class="d-inline-flex align-items-center gap-1">
        <span class="identifier-row__value">{{ value }}</span>
        <a
          v-if="showCopy"
          v-b-tooltip.hover.bottom
          href="#"
          class="identifier-row__action"
          :aria-label="`Copy ${label} to clipboard`"
          title="Copy to clipboard"
          @click.prevent="handleCopy"
        >
          <i class="bi bi-clipboard" aria-hidden="true" />
        </a>
        <a
          v-if="externalUrl"
          v-b-tooltip.hover.bottom
          class="identifier-row__action identifier-row__action--external"
          :href="externalUrl"
          :aria-label="`Open ${label} in ${resolvedExternalLabel} (opens in new tab)`"
          :title="`View in ${resolvedExternalLabel}`"
          target="_blank"
          rel="noopener noreferrer"
        >
          <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
        </a>
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import useToast from '@/composables/useToast';

interface Props {
  label: string;
  value?: string;
  externalUrl?: string;
  externalLabel?: string;
  showCopy?: boolean;
  compact?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  value: undefined,
  externalUrl: undefined,
  externalLabel: undefined,
  showCopy: true,
  compact: false,
});

const resolvedExternalLabel = computed(() => props.externalLabel || props.label);

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
/* ── Full row mode ── */
.identifier-row {
  border-bottom: 1px solid #f0f0f0;
  padding: 0.25rem 0.75rem;
  min-height: 1.75rem;
}

.identifier-row:nth-child(even) {
  background-color: #f9fafb;
}

.identifier-row:last-child {
  border-bottom: none;
}

.identifier-row__label {
  flex: 0 0 35%;
  max-width: 35%;
  font-size: 0.8rem;
  color: #495057;
}

.identifier-row__content {
  flex: 1;
  min-width: 0;
  font-size: 0.8rem;
}

.identifier-row__value {
  font-family: 'Courier New', monospace;
  font-size: 0.8rem;
}

.identifier-row__action {
  color: #868e96;
  font-size: 0.7rem;
  text-decoration: none;
  padding: 0.1rem;
  line-height: 1;
  transition: color 0.15s ease;
}

.identifier-row__action:hover {
  color: #212529;
}

.identifier-row__action--external {
  color: #6c8ebf;
}

.identifier-row__action--external:hover {
  color: #0d6efd;
}

/* ── Compact badge mode ── */
.identifier-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.15rem 0.5rem;
  border: 1px solid #dee2e6;
  border-radius: 1rem;
  background: white;
  font-size: 0.75rem;
  white-space: nowrap;
}

.identifier-badge__label {
  font-weight: 600;
  color: #6c757d;
}

.identifier-badge__value {
  font-family: 'Courier New', monospace;
  color: #333;
}

.identifier-badge__empty {
  color: #adb5bd;
  font-style: italic;
}

.identifier-badge--unavailable {
  opacity: 0.45;
}

.identifier-badge__action {
  color: #868e96;
  font-size: 0.65rem;
  text-decoration: none;
  padding: 0 0.1rem;
  line-height: 1;
  transition: color 0.15s ease;
}

.identifier-badge__action:hover {
  color: #212529;
}

.identifier-badge__action--external {
  color: #6c8ebf;
}

.identifier-badge__action--external:hover {
  color: #0d6efd;
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .identifier-row__action,
  .identifier-badge__action {
    transition: none;
  }
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .identifier-row {
    flex-wrap: wrap;
  }
  .identifier-row__label {
    flex: 0 0 100%;
    max-width: 100%;
    text-align: start !important;
    margin-bottom: 0.1rem;
  }
}
</style>
