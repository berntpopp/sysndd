<!-- views/components/small/TableDownloadLinkCopyButtons.vue -->
<!-- views/components/small/TableDownloadLinkCopyButtons.vue -->
<template>
  <div class="download-buttons">
    <!-- Download CSV Button -->
    <b-button
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Download data as Excel file."
      :disabled="downloading"
      @click="$emit('request-excel')"
    >
      <b-icon
        icon="table"
        class="mx-1"
      />
      <b-icon
        v-if="!downloading"
        icon="download"
      />
      <b-spinner
        v-if="downloading"
        small
      />
      .xlsx
    </b-button>
    <!-- Download CSV Button -->

    <!-- Copy Link Button -->
    <b-button
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      title="Copy link to this page."
      variant="success"
      @click="$emit('copy-link')"
    >
      <b-icon
        icon="link"
        font-scale="1.0"
      />
    </b-button>
    <!-- Copy Link Button -->

    <!-- Remove Filters Button -->
    <b-button
      v-b-tooltip.hover.bottom
      class="download-button"
      size="sm"
      :title="removeFiltersTitle"
      :variant="removeFiltersVariant"
      @click="$emit('remove-filters')"
    >
      <b-icon
        icon="filter"
        font-scale="1.0"
      />
    </b-button>
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
