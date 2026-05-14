<!-- components/annotations/HgncAnnotationsCard.vue -->
<template>
  <AdminOperationPanel
    title="Updating HGNC Data"
    :meta="lastUpdated ? `Last: ${formatDate(lastUpdated)}` : null"
    icon="bi-database"
    heading-tag="h2"
  >
    <BButton variant="primary" :disabled="hgncJob.isLoading.value" @click="$emit('start-hgnc')">
      <BSpinner v-if="hgncJob.isLoading.value" small type="grow" class="me-2" />
      {{ hgncJob.isLoading.value ? 'Updating...' : 'Update HGNC Data' }}
    </BButton>

    <JobProgressDisplay
      :job="hgncJob"
      idle-message="Downloading HGNC data; enriching with gnomAD constraints, AlphaFold IDs, and Ensembl coordinates. Typically a few minutes."
    />
  </AdminOperationPanel>
</template>

<script setup lang="ts">
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { formatDate } from '@/composables/annotations/useAnnotationFormatters';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import JobProgressDisplay from './JobProgressDisplay.vue';

defineProps<{
  hgncJob: UseAsyncJobReturn;
  lastUpdated: string | null;
}>();

defineEmits<{
  (e: 'start-hgnc'): void;
}>();
</script>
