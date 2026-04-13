<!-- components/annotations/JobProgressDisplay.vue -->
<template>
  <div v-if="job.isLoading.value || job.status.value !== 'idle'" class="mt-3">
    <div class="d-flex align-items-center mb-2">
      <span class="badge me-2" :class="job.statusBadgeClass.value">
        {{ job.status.value }}
      </span>
      <span class="text-muted">{{ job.step.value }}</span>
    </div>

    <BProgress
      v-if="job.isLoading.value"
      :value="job.hasRealProgress.value ? job.progressPercent.value : 100"
      :max="100"
      :animated="true"
      :striped="!job.hasRealProgress.value"
      :variant="job.progressVariant.value"
      height="1.5rem"
    >
      <template #default>
        <span v-if="job.hasRealProgress.value">
          {{ job.progressPercent.value }}% - {{ shortStepLabel(job.step.value) }}
        </span>
        <span v-else>
          {{ shortStepLabel(job.step.value) }} ({{ job.elapsedTimeDisplay.value }})
        </span>
      </template>
    </BProgress>

    <div
      v-if="job.progress.value.current && job.progress.value.total"
      class="small text-muted mt-1"
    >
      {{ job.progress.value.current.toLocaleString() }} /
      {{ job.progress.value.total.toLocaleString() }}
      ({{ job.elapsedTimeDisplay.value }})
    </div>
    <div v-else-if="job.isLoading.value && idleMessage" class="small text-muted mt-1">
      Elapsed: {{ job.elapsedTimeDisplay.value }} - {{ idleMessage }}
    </div>
  </div>
</template>

<script setup lang="ts">
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { shortStepLabel } from '@/composables/annotations/useAnnotationFormatters';

defineProps<{
  job: UseAsyncJobReturn;
  idleMessage?: string;
}>();
</script>
