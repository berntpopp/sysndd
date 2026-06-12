<!-- views/admin/LlmOverviewPanel.vue -->
<!--
  Overview tab content for the LLM Administration view. Extracted from
  ManageLLM.vue so the parent stays a thinner shell. Presents cache status
  and regeneration-job progress for admin-generated cached LLM summaries.
  All status/feedback copy is preserved verbatim from the original view.
-->
<template>
  <TableShell
    title="LLM overview"
    :meta="`Summaries: ${cacheStats?.total_entries ?? 0}`"
    :description="overviewDescription"
    :loading="loading && !cacheStats"
  >
    <template #toolbar>
      <div class="llm-overview-toolbar" aria-label="LLM quick actions">
        <div class="llm-overview-toolbar__group">
          <BButton
            variant="outline-primary"
            size="sm"
            data-testid="llm-regenerate-functional"
            :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
            @click="emit('regenerate', 'functional')"
          >
            <BSpinner v-if="functionalRegenerationJob.isLoading.value" small class="me-1" />
            Regenerate Functional
          </BButton>
          <BButton
            variant="outline-primary"
            size="sm"
            data-testid="llm-regenerate-phenotype"
            :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
            @click="emit('regenerate', 'phenotype')"
          >
            <BSpinner v-if="phenotypeRegenerationJob.isLoading.value" small class="me-1" />
            Regenerate Phenotype
          </BButton>
        </div>
        <BButton
          variant="outline-danger"
          size="sm"
          :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
          @click="emit('open-clear-modal')"
        >
          <BSpinner v-if="isAnyRegenerationLoading" small class="me-1" />
          Clear Cache & Regenerate
        </BButton>
      </div>
    </template>

    <div v-if="regenerationFeedback" class="llm-regeneration-feedback">
      <BAlert :variant="regenerationFeedbackVariant" show class="mb-3">
        <i :class="regenerationFeedbackIcon" class="me-1" aria-hidden="true" />
        {{ regenerationFeedback }}
      </BAlert>
    </div>

    <div class="llm-overview-sections">
      <section class="llm-overview-section" aria-labelledby="llm-cache-heading">
        <div class="llm-section-heading">
          <h3 id="llm-cache-heading">Cache status</h3>
          <span>{{ cacheHealthLabel }}</span>
        </div>
        <div class="llm-table-wrap d-none d-md-block">
          <table class="table table-sm align-middle llm-overview-table">
            <thead>
              <tr>
                <th scope="col">Metric</th>
                <th scope="col">Value</th>
                <th scope="col">Status</th>
                <th scope="col">Notes</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in cacheSummaryRows" :key="row.key">
                <th scope="row">{{ row.label }}</th>
                <td class="llm-overview-table__value">{{ row.value }}</td>
                <td>
                  <span :class="['llm-status-chip', row.tone]">
                    {{ row.status }}
                  </span>
                </td>
                <td>{{ row.note }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="llm-mobile-rows d-md-none">
          <article v-for="row in cacheSummaryRows" :key="row.key" class="llm-mobile-row">
            <div class="llm-mobile-row__main">
              <strong>{{ row.label }}</strong>
              <span class="llm-overview-table__value">{{ row.value }}</span>
            </div>
            <div class="llm-mobile-row__meta">
              <span :class="['llm-status-chip', row.tone]">{{ row.status }}</span>
              <span>{{ row.note }}</span>
            </div>
          </article>
        </div>
      </section>

      <section class="llm-overview-section" aria-labelledby="llm-jobs-heading">
        <div class="llm-section-heading">
          <h3 id="llm-jobs-heading">Regeneration jobs</h3>
          <span>{{ visibleRegenerationJobs.length }} active</span>
        </div>
        <div class="llm-table-wrap d-none d-md-block">
          <table class="table table-sm align-middle llm-overview-table">
            <thead>
              <tr>
                <th scope="col">Type</th>
                <th scope="col">Status</th>
                <th scope="col">Job</th>
                <th scope="col">Progress</th>
                <th scope="col">Elapsed</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!visibleRegenerationJobs.length">
                <td colspan="5" class="llm-empty-row">
                  No active regeneration jobs in this browser session.
                </td>
              </tr>
              <tr
                v-for="job in visibleRegenerationJobs"
                :key="job.type"
                :data-testid="`llm-regeneration-job-${job.type}`"
              >
                <th scope="row">{{ job.label }}</th>
                <td>
                  <BBadge :class="job.runner.statusBadgeClass.value">
                    {{ job.runner.status.value }}
                  </BBadge>
                </td>
                <td class="llm-job-id">Job {{ job.runner.jobId.value }}</td>
                <td class="llm-job-progress-cell">
                  <div v-if="job.runner.step.value" class="llm-job-step">
                    {{ job.runner.step.value }}
                  </div>
                  <BProgress :max="100" height="0.875rem">
                    <BProgressBar
                      :value="
                        job.runner.hasRealProgress.value
                          ? (job.runner.progressPercent.value ?? 0)
                          : 100
                      "
                      :variant="job.runner.progressVariant.value"
                      :striped="!job.runner.hasRealProgress.value"
                      :animated="job.runner.isLoading.value"
                    >
                      <template v-if="job.runner.hasRealProgress.value">
                        {{ job.runner.progress.value.current }}/{{
                          job.runner.progress.value.total
                        }}
                      </template>
                      <template v-else-if="job.runner.isLoading.value"> Processing... </template>
                    </BProgressBar>
                  </BProgress>
                  <BAlert
                    v-if="job.runner.error.value"
                    variant="danger"
                    show
                    class="mt-2 mb-0"
                  >
                    <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
                    {{ job.runner.error.value }}
                  </BAlert>
                </td>
                <td class="llm-job-elapsed">
                  <i class="bi bi-clock me-1" aria-hidden="true" />
                  {{ job.runner.elapsedTimeDisplay.value }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="llm-mobile-rows d-md-none">
          <article v-if="!visibleRegenerationJobs.length" class="llm-mobile-row">
            <div class="llm-mobile-row__main">
              <strong>No active regeneration jobs</strong>
            </div>
            <div class="llm-mobile-row__meta">
              <span>Jobs started here will remain visible after navigation.</span>
            </div>
          </article>
          <article
            v-for="job in visibleRegenerationJobs"
            :key="job.type"
            class="llm-mobile-row"
            :data-testid="`llm-regeneration-job-${job.type}`"
          >
            <div class="llm-mobile-row__main">
              <strong>{{ job.label }}</strong>
              <BBadge :class="job.runner.statusBadgeClass.value">
                {{ job.runner.status.value }}
              </BBadge>
            </div>
            <div class="llm-job-id">Job {{ job.runner.jobId.value }}</div>
            <div v-if="job.runner.step.value" class="llm-job-step">
              {{ job.runner.step.value }}
            </div>
            <BProgress :max="100" height="0.875rem">
              <BProgressBar
                :value="
                  job.runner.hasRealProgress.value
                    ? (job.runner.progressPercent.value ?? 0)
                    : 100
                "
                :variant="job.runner.progressVariant.value"
                :striped="!job.runner.hasRealProgress.value"
                :animated="job.runner.isLoading.value"
              >
                <template v-if="job.runner.hasRealProgress.value">
                  {{ job.runner.progress.value.current }}/{{ job.runner.progress.value.total }}
                </template>
                <template v-else-if="job.runner.isLoading.value"> Processing... </template>
              </BProgressBar>
            </BProgress>
          </article>
        </div>
      </section>
    </div>
  </TableShell>
</template>

<script setup lang="ts">
import { BAlert, BBadge, BButton, BProgress, BProgressBar, BSpinner } from 'bootstrap-vue-next';
import TableShell from '@/components/table/TableShell.vue';
import type { LlmConfig, CacheStats, ClusterType } from '@/types/llm';
import type { LlmCacheSummaryRow } from './useLlmCacheOverview';
import type { VisibleRegenerationJob } from './useLlmRegenerationJobs';
import { useAsyncJob } from '@/composables/useAsyncJob';

type RegenerationRunner = ReturnType<typeof useAsyncJob>;

defineProps<{
  config: LlmConfig | null;
  cacheStats: CacheStats | null;
  loading: boolean;
  overviewDescription: string;
  cacheHealthLabel: string;
  cacheSummaryRows: LlmCacheSummaryRow[];
  regenerationFeedback: string;
  regenerationFeedbackVariant: 'success' | 'danger' | 'info' | 'warning';
  regenerationFeedbackIcon: string;
  isAnyRegenerationLoading: boolean;
  visibleRegenerationJobs: VisibleRegenerationJob[];
  functionalRegenerationJob: RegenerationRunner;
  phenotypeRegenerationJob: RegenerationRunner;
}>();

const emit = defineEmits<{
  (event: 'regenerate', type: ClusterType): void;
  (event: 'open-clear-modal'): void;
}>();
</script>

<style scoped>
.llm-overview-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.llm-overview-toolbar__group {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.llm-overview-sections {
  display: grid;
  gap: 1.25rem;
}

.llm-overview-section {
  min-width: 0;
}

.llm-section-heading {
  display: flex;
  gap: 1rem;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.llm-section-heading h3 {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.35;
}

.llm-section-heading span {
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
  font-weight: 600;
}

.llm-table-wrap {
  overflow-x: auto;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
}

.llm-overview-table {
  min-width: 760px;
  margin: 0;
}

.llm-overview-table :deep(th) {
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
}

.llm-overview-table :deep(td),
.llm-overview-table :deep(th) {
  padding: 0.65rem 0.75rem;
}

.llm-overview-table__value,
.llm-job-id {
  font-family: var(
    --font-family-mono,
    ui-monospace,
    SFMono-Regular,
    Menlo,
    Monaco,
    Consolas,
    monospace
  );
  font-size: 0.8125rem;
}

.llm-job-id {
  color: var(--neutral-600, #757575);
  overflow-wrap: anywhere;
}

.llm-job-progress-cell {
  min-width: 280px;
}

.llm-job-step {
  margin-bottom: 0.35rem;
  color: var(--neutral-700, #424242);
  font-size: 0.8125rem;
}

.llm-job-elapsed,
.llm-empty-row {
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

.llm-status-chip {
  display: inline-flex;
  align-items: center;
  min-height: 1.375rem;
  padding: 0.125rem 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 999px;
  background: #f8fafc;
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  white-space: nowrap;
}

.llm-status-chip.success {
  border-color: rgba(46, 125, 50, 0.18);
  background: rgba(46, 125, 50, 0.08);
  color: var(--status-success, #2e7d32);
}

.llm-status-chip.warning {
  border-color: rgba(245, 124, 0, 0.2);
  background: rgba(245, 124, 0, 0.1);
  color: var(--status-warning, #f57c00);
}

.llm-status-chip.info {
  border-color: rgba(2, 119, 189, 0.18);
  background: rgba(2, 119, 189, 0.08);
  color: var(--status-info, #0277bd);
}

.llm-mobile-rows {
  display: grid;
  gap: 0.5rem;
}

.llm-mobile-row {
  display: grid;
  gap: 0.4rem;
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #fff;
}

.llm-mobile-row__main,
.llm-mobile-row__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.llm-mobile-row__meta {
  justify-content: flex-start;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

@media (max-width: 575.98px) {
  .llm-overview-toolbar {
    align-items: stretch;
  }

  .llm-overview-toolbar,
  .llm-overview-toolbar__group,
  .llm-overview-toolbar :deep(.btn) {
    width: 100%;
  }

  .llm-section-heading {
    display: grid;
    gap: 0.25rem;
  }
}
</style>
