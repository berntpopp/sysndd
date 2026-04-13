<!-- components/annotations/PublicationRefreshCard.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-2"
    header-class="p-1"
    border-variant="dark"
    class="mb-3 text-start"
  >
    <template #header>
      <h5 class="mb-0 text-start font-weight-bold d-flex align-items-center">
        Publication Metadata Refresh
        <span v-if="stats.total !== null" class="badge bg-info ms-2 fw-normal">
          {{ stats.total?.toLocaleString() }} publications
        </span>
        <span
          v-if="stats.oldest_update"
          class="badge bg-warning text-dark ms-2 fw-normal"
        >
          Oldest: {{ formatDate(stats.oldest_update) }}
        </span>
        <span
          v-if="stats.outdated_count && stats.outdated_count > 0"
          class="badge bg-danger ms-2 fw-normal"
        >
          {{ stats.outdated_count.toLocaleString() }} outdated
        </span>
      </h5>
    </template>

    <div class="mb-3">
      <p class="text-muted small mb-2">
        Refresh publication metadata from PubMed. Publications are updated in place (no
        deletions). Rate limited to ~3 requests/second to comply with NCBI limits.
      </p>
    </div>

    <div class="mb-3">
      <label class="form-label small text-muted mb-1">Filter by last update:</label>
      <div class="d-flex flex-wrap align-items-center gap-2">
        <BButtonGroup size="sm">
          <BButton
            :variant="preset === 'all' ? 'primary' : 'outline-secondary'"
            @click="$emit('update:preset', 'all')"
          >
            All
          </BButton>
          <BButton
            :variant="preset === '1year' ? 'primary' : 'outline-secondary'"
            @click="$emit('update:preset', '1year')"
          >
            &gt;1 year
          </BButton>
          <BButton
            :variant="preset === '6months' ? 'primary' : 'outline-secondary'"
            @click="$emit('update:preset', '6months')"
          >
            &gt;6 months
          </BButton>
          <BButton
            :variant="preset === '3months' ? 'primary' : 'outline-secondary'"
            @click="$emit('update:preset', '3months')"
          >
            &gt;3 months
          </BButton>
          <BButton
            :variant="preset === 'custom' ? 'primary' : 'outline-secondary'"
            @click="$emit('update:preset', 'custom')"
          >
            Custom
          </BButton>
        </BButtonGroup>

        <input
          v-if="preset === 'custom'"
          :value="customDate"
          type="date"
          class="form-control form-control-sm"
          style="max-width: 160px"
          :max="todayDate"
          @input="onCustomDateInput"
        />

        <span
          v-if="preset !== 'all' && filteredCount !== null"
          class="badge bg-info"
        >
          <BSpinner v-if="loadingFilteredCount" small class="me-1" />
          {{ filteredCount?.toLocaleString() }} publications match filter
        </span>
      </div>
    </div>

    <div class="d-flex gap-2 mb-3">
      <BButton
        variant="outline-secondary"
        size="sm"
        :disabled="loadingStats"
        @click="$emit('refresh-stats')"
      >
        <BSpinner v-if="loadingStats" small type="grow" class="me-1" />
        {{ loadingStats ? 'Loading...' : 'Refresh Stats' }}
      </BButton>
      <BButton
        v-if="preset !== 'all' && filteredCount !== null && filteredCount > 0"
        variant="success"
        :disabled="job.isLoading.value || filteredCount === 0"
        @click="$emit('refresh-filtered')"
      >
        <BSpinner v-if="job.isLoading.value" small type="grow" class="me-2" />
        {{
          job.isLoading.value
            ? 'Refreshing...'
            : `Refresh ${filteredCount?.toLocaleString()} Publications`
        }}
      </BButton>
      <BButton
        variant="primary"
        :disabled="job.isLoading.value || stats.total === null"
        @click="$emit('refresh-all')"
      >
        <BSpinner v-if="job.isLoading.value" small type="grow" class="me-2" />
        {{ job.isLoading.value ? 'Refreshing...' : 'Refresh All Publications' }}
      </BButton>
    </div>

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
            {{ job.progressPercent.value }}% - {{ job.step.value }}
          </span>
          <span v-else>
            {{ job.step.value }} ({{ job.elapsedTimeDisplay.value }})
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

      <BAlert v-if="job.status.value === 'completed'" variant="success" show class="mt-2 mb-0">
        Refresh complete. Check job history for details.
      </BAlert>

      <BAlert v-if="job.status.value === 'failed'" variant="danger" show class="mt-2 mb-0">
        {{ job.error.value || 'Refresh failed. Check job history for details.' }}
      </BAlert>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import type { UseAsyncJobReturn } from '@/composables/useAsyncJob';
import { formatDate } from '@/composables/annotations/useAnnotationFormatters';

export type FilterPreset = 'all' | '1year' | '6months' | '3months' | 'custom';

export interface PublicationStats {
  total: number | null;
  oldest_update: string | null;
  outdated_count: number | null;
}

defineProps<{
  job: UseAsyncJobReturn;
  stats: PublicationStats;
  loadingStats: boolean;
  preset: FilterPreset;
  customDate: string;
  todayDate: string;
  filteredCount: number | null;
  loadingFilteredCount: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:preset', value: FilterPreset): void;
  (e: 'update:customDate', value: string): void;
  (e: 'refresh-stats'): void;
  (e: 'refresh-filtered'): void;
  (e: 'refresh-all'): void;
}>();

function onCustomDateInput(event: Event): void {
  const target = event.target as HTMLInputElement;
  emit('update:customDate', target.value);
}
</script>
