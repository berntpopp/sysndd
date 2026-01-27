<!-- views/components/small/TableDownloadLinkCopyButtons.vue -->
<!-- views/components/small/TableDownloadLinkCopyButtons.vue -->
<template>
  <div class="download-buttons">
    <!-- Download CSV Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Download data as Excel file."
      :disabled="downloading"
      @click="$emit('request-excel')"
    >
      <i class="bi bi-table mx-1" />
      <i
        v-if="!downloading"
        class="bi bi-download"
      />
      <BSpinner
        v-if="downloading"
        small
      />
      .xlsx
    </BButton>
    <!-- Download CSV Button -->

    <!-- Copy Link Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Copy link to this page."
      variant="success"
      @click="$emit('copy-link')"
    >
      <i class="bi bi-link" />
    </BButton>
    <!-- Copy Link Button -->

    <!-- Remove Filters Button -->
    <BButton
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      :title="removeFiltersTitle"
      :variant="removeFiltersVariant"
      @click="$emit('remove-filters')"
    >
      <i class="bi bi-filter" />
    </BButton>
    <!-- Remove Filters Button -->
  </div>
</template>

<script>
export default {
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
      default: 'info',
    },
  },
  emits: ['request-excel', 'copy-link', 'remove-filters'],
};
</script>

<style scoped>
.download-buttons {
  display: inline-block;
}

.download-button {
  margin: 0.1rem 0.1rem; /* Vertical margin for small screens */
}
</style>
