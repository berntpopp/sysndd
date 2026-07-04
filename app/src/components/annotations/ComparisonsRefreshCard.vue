<!-- components/annotations/ComparisonsRefreshCard.vue -->
<template>
  <AdminOperationPanel
    title="Comparisons Data Refresh"
    :meta="metaItems"
    icon="bi-arrow-repeat"
    heading-tag="h2"
  >
    <div class="mb-3">
      <p class="text-muted small mb-2">
        Refresh comparisons data from 7 external NDD databases: Radboudumc, Gene2Phenotype,
        PanelApp, SFARI, NDD GeneHub, OMIM NDD, and Orphanet. This operation downloads fresh data
        and updates the database. Any failure aborts the entire refresh.
      </p>
    </div>

    <div class="d-flex gap-2 mb-3">
      <BButton
        variant="outline-secondary"
        size="sm"
        :disabled="loadingMetadata"
        @click="$emit('refresh-metadata')"
      >
        <BSpinner v-if="loadingMetadata" small type="grow" class="me-1" />
        {{ loadingMetadata ? 'Loading...' : 'Refresh Stats' }}
      </BButton>
      <BButton variant="primary" :disabled="job.isLoading.value" @click="$emit('start-refresh')">
        <BSpinner v-if="job.isLoading.value" small type="grow" class="me-2" />
        {{ job.isLoading.value ? 'Updating...' : 'Refresh Comparisons Data' }}
      </BButton>
    </div>

    <JobProgressDisplay
      :job="job"
      idle-message="Downloading and processing external databases (this may take several minutes)..."
    />

    <BAlert v-if="job.status.value === 'completed'" variant="success" show class="mt-2 mb-0">
      Comparisons data refreshed successfully. Check job history for details.
    </BAlert>

    <BAlert v-if="job.status.value === 'failed'" variant="danger" show class="mt-2 mb-0">
      {{ job.error.value || 'Comparisons refresh failed. Check job history for details.' }}
    </BAlert>
  </AdminOperationPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { formatDate } from '@/composables/annotations/useAnnotationFormatters';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import JobProgressDisplay from './JobProgressDisplay.vue';

export interface ComparisonsMetadata {
  last_full_refresh: string | null;
  last_refresh_status: string;
  last_refresh_error: string | null;
  sources_count: number;
  rows_imported: number;
}

const props = defineProps<{
  job: UseAsyncJobReturn;
  metadata: ComparisonsMetadata;
  loadingMetadata: boolean;
}>();

defineEmits<{
  (e: 'refresh-metadata'): void;
  (e: 'start-refresh'): void;
}>();

const metaItems = computed(() =>
  [
    props.metadata.last_full_refresh
      ? `Last: ${formatDate(props.metadata.last_full_refresh)}`
      : null,
    props.metadata.sources_count > 0 ? `${props.metadata.sources_count} sources` : null,
    props.metadata.rows_imported > 0
      ? `${props.metadata.rows_imported.toLocaleString()} rows`
      : null,
  ].filter((item): item is string => Boolean(item))
);
</script>
