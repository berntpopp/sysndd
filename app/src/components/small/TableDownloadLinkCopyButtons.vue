<!-- views/components/small/TableDownloadLinkCopyButtons.vue -->
<template>
  <div class="download-buttons" role="group" aria-label="Table export and sharing actions">
    <!-- Download CSV/Excel Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      variant="outline-secondary"
      title="Download table data as .xlsx Excel file"
      aria-label="Download table data as .xlsx Excel file"
      :disabled="downloading"
      @click="$emit('request-excel')"
    >
      <i class="bi bi-table me-1" aria-hidden="true" />
      <i v-if="!downloading" class="bi bi-download" aria-hidden="true" />
      <BSpinner v-if="downloading" small />
      <span>.xlsx</span>
    </BButton>

    <!-- Copy Link Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      variant="outline-secondary"
      title="Copy link to this page"
      aria-label="Copy link to this page"
      @click="$emit('copy-link')"
    >
      <i class="bi bi-link-45deg" aria-hidden="true" />
    </BButton>

    <!-- Remove Filters Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      variant="outline-secondary"
      :title="removeFiltersTitle"
      :aria-label="removeFiltersTitle"
      @click="$emit('remove-filters')"
    >
      <i class="bi bi-funnel" aria-hidden="true" />
    </BButton>
  </div>
</template>

<script>
export default {
  name: 'TableDownloadLinkCopyButtons',
  props: {
    downloading: {
      type: Boolean,
      default: false,
    },
    removeFiltersTitle: {
      type: String,
      default: 'Click to remove all filters.',
    },
    removeFiltersVariant: {
      type: String,
      default: 'outline-secondary',
    },
  },
  emits: ['request-excel', 'copy-link', 'remove-filters'],
};
</script>

<style scoped>
.download-buttons {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.download-button {
  display: inline-flex;
  align-items: center;
  min-height: 1.85rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-sm, 0.25rem);
  background: var(--surface-raised, #ffffff);
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
  font-weight: 500;
  line-height: 1.2;
  transition:
    background-color 0.15s ease-in-out,
    border-color 0.15s ease-in-out,
    color 0.15s ease-in-out;

  &:hover,
  &:focus-visible {
    border-color: var(--medical-blue-600, #1e88e5);
    background: var(--medical-blue-50, #e3f2fd);
    color: var(--medical-blue-700, #0d47a1);
    outline: none;
  }
}
</style>
