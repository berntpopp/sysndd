<!-- components/annotations/HgncAnnotationsCard.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-1"
    header-class="p-1"
    border-variant="dark"
    class="mb-3 text-start"
  >
    <template #header>
      <h5 class="mb-0 text-start font-weight-bold">
        Updating HGNC Data
        <span v-if="lastUpdated" class="badge bg-secondary ms-2 fw-normal">
          Last: {{ formatDate(lastUpdated) }}
        </span>
      </h5>
    </template>

    <BButton
      variant="primary"
      :disabled="hgncJob.isLoading.value"
      @click="$emit('start-hgnc')"
    >
      <BSpinner v-if="hgncJob.isLoading.value" small type="grow" class="me-2" />
      {{ hgncJob.isLoading.value ? 'Updating...' : 'Update HGNC Data' }}
    </BButton>

    <JobProgressDisplay
      :job="hgncJob"
      idle-message="Downloading HGNC data; enriching with gnomAD constraints, AlphaFold IDs, and Ensembl coordinates. Typically a few minutes."
    />
  </BCard>
</template>

<script setup lang="ts">
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { formatDate } from '@/composables/annotations/useAnnotationFormatters';
import JobProgressDisplay from './JobProgressDisplay.vue';

defineProps<{
  hgncJob: UseAsyncJobReturn;
  lastUpdated: string | null;
}>();

defineEmits<{
  (e: 'start-hgnc'): void;
}>();
</script>
