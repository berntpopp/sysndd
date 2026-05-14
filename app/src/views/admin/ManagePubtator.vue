<!-- views/admin/ManagePubtator.vue -->
/** * ManagePubtator component * * @description Admin interface for managing PubTator3 publication
cache. * Allows administrators to: * - Check cache status for queries * - Submit async fetch jobs
with progress tracking * - Clear cache (soft/hard reset) * - Backfill gene symbols for existing
entries * * Uses non-blocking async jobs for fetching to avoid request timeouts. * * @component
ManagePubtator */

<template>
  <AuthenticatedPageShell
    title="Manage PubTator"
    description="Check query coverage, fetch publication annotations, and maintain the PubTator cache."
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="pubtator-admin">
      <AdminOperationPanel
        title="Search coverage"
        description="Start with a PubTator query, then decide whether the local cache needs more pages or gene-symbol backfill."
        icon="bi-search"
        :meta="lastStatus ? cacheStateLabel : 'No query checked'"
      >
        <div data-testid="pubtator-query-workspace">
          <form class="pubtator-query-form" @submit.prevent="checkStatus">
            <BFormGroup
              label="PubTator query"
              label-for="query-input"
              class="pubtator-query-form__field"
            >
              <textarea
                id="query-input"
                v-model="query"
                class="form-control pubtator-query-form__textarea"
                placeholder="PubTator search query"
                :disabled="isJobLoading"
              ></textarea>
            </BFormGroup>
            <div class="pubtator-query-form__actions">
              <BButton
                type="submit"
                variant="primary"
                :disabled="!query.trim() || isCheckingStatus"
              >
                <BSpinner v-if="isCheckingStatus" small class="me-1" />
                <i v-else class="bi bi-search me-1" aria-hidden="true" />
                Check status
              </BButton>
            </div>
          </form>

          <div v-if="lastStatus" class="pubtator-status" data-testid="pubtator-status-metrics">
            <div class="pubtator-status__summary">
              <span
                class="pubtator-status__badge"
                :class="
                  lastStatus.cached
                    ? 'pubtator-status__badge--success'
                    : 'pubtator-status__badge--warning'
                "
              >
                <i
                  :class="lastStatus.cached ? 'bi bi-check-circle' : 'bi bi-exclamation-circle'"
                  aria-hidden="true"
                />
                {{ cacheStateLabel }}
              </span>
              <span v-if="lastStatus.cache_date" class="pubtator-status__updated">
                Updated {{ formatDate(lastStatus.cache_date) }}
              </span>
            </div>

            <div class="pubtator-metrics">
              <div class="pubtator-metric">
                <span class="pubtator-metric__label">Pages cached</span>
                <strong>{{ lastStatus.pages_cached || 0 }}</strong>
              </div>
              <div class="pubtator-metric">
                <span class="pubtator-metric__label">Publications</span>
                <strong>{{ (lastStatus.publications_cached || 0).toLocaleString() }}</strong>
              </div>
              <div class="pubtator-metric">
                <span class="pubtator-metric__label">API results</span>
                <strong>{{ (lastStatus.total_results_available || 0).toLocaleString() }}</strong>
              </div>
              <div class="pubtator-metric">
                <span class="pubtator-metric__label">Pages remaining</span>
                <strong>{{ lastStatus.pages_remaining || 0 }}</strong>
              </div>
              <div class="pubtator-metric">
                <span class="pubtator-metric__label">Estimated fetch</span>
                <strong>{{ lastStatus.estimated_fetch_time_minutes || 0 }} min</strong>
              </div>
            </div>

            <div class="pubtator-cache-progress">
              <div class="pubtator-cache-progress__header">
                <span>Cache coverage</span>
                <strong>{{ cacheProgress }}%</strong>
              </div>
              <BProgress :max="100" height="0.75rem">
                <BProgressBar :value="cacheProgress" variant="success" />
              </BProgress>
            </div>
          </div>

          <div v-else class="pubtator-empty-state">
            <i class="bi bi-info-circle" aria-hidden="true" />
            Check a query to see local cache coverage and PubTator API availability.
          </div>
        </div>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Fetch publications"
        description="Fetches run as background jobs. You can leave this page after submission and return to check progress."
        icon="bi-cloud-arrow-down"
        heading-tag="h2"
      >
        <div class="pubtator-fetch" data-testid="pubtator-fetch-workspace">
          <div class="pubtator-fetch__settings">
            <BFormGroup label="Pages to fetch" label-for="max-pages">
              <BFormInput
                id="max-pages"
                v-model.number="maxPages"
                type="number"
                min="1"
                max="2000"
                :disabled="isJobLoading"
              />
              <BFormText>~{{ Math.round((maxPages * 2.5) / 60) }} min at 10 results/page</BFormText>
            </BFormGroup>

            <BFormGroup label="Update type">
              <BFormCheckbox v-model="clearOld" :disabled="isJobLoading" switch>
                Hard update: clear existing cache first
              </BFormCheckbox>
            </BFormGroup>
          </div>

          <div class="pubtator-fetch__actions">
            <BButton
              variant="primary"
              :disabled="!query.trim() || isJobLoading"
              @click="submitFetch"
            >
              <BSpinner v-if="isJobLoading && jobStatus === 'accepted'" small class="me-1" />
              <i v-else class="bi bi-download me-1" aria-hidden="true" />
              Submit fetch job
            </BButton>
            <BButton v-if="isJobLoading" variant="outline-secondary" @click="stopPolling">
              <i class="bi bi-stop-circle me-1" aria-hidden="true" />
              Stop tracking
            </BButton>
            <BButton
              variant="outline-secondary"
              :disabled="!lastStatus?.cached || isJobLoading || isBackfilling"
              @click="backfillGenes"
            >
              <BSpinner v-if="isBackfilling" small class="me-1" />
              <i v-else class="bi bi-arrow-repeat me-1" aria-hidden="true" />
              Backfill gene symbols
            </BButton>
          </div>

          <div v-if="jobId" class="pubtator-job">
            <div class="pubtator-job__header">
              <div>
                <BBadge :class="statusBadgeClass" class="me-2">{{ jobStatus }}</BBadge>
                <span class="pubtator-job__id">Job {{ jobId.substring(0, 8) }}</span>
              </div>
              <span class="pubtator-job__elapsed">
                <i class="bi bi-clock me-1" aria-hidden="true" />
                {{ elapsedTimeDisplay }}
              </span>
            </div>
            <p v-if="jobStep" class="pubtator-job__step">{{ jobStep }}</p>
            <BProgress :max="100" height="0.875rem">
              <BProgressBar
                :value="hasRealProgress ? (progressPercent ?? 0) : 100"
                :variant="progressVariant"
                :striped="!hasRealProgress"
                :animated="isJobLoading"
              >
                <template v-if="hasRealProgress">
                  {{ jobProgress.current }}/{{ jobProgress.total }} pages
                </template>
                <template v-else-if="isJobLoading">Processing...</template>
              </BProgressBar>
            </BProgress>

            <BAlert v-if="jobError" variant="danger" class="mt-3 mb-0" show>
              <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
              {{ jobError }}
            </BAlert>
            <BAlert v-if="jobStatus === 'completed'" variant="success" class="mt-3 mb-0" show>
              <i class="bi bi-check-circle-fill me-1" aria-hidden="true" />
              Fetch completed successfully. Refresh cache status to see results.
            </BAlert>
          </div>

          <BAlert v-if="feedbackMessage" :variant="feedbackVariant" class="mt-3 mb-0" show>
            <i :class="feedbackIcon" class="me-1" aria-hidden="true" />
            {{ feedbackMessage }}
          </BAlert>
        </div>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Clear cache"
        description="Remove all cached PubTator publications and annotations for every query."
        icon="bi-trash"
        heading-tag="h2"
        tone="danger"
      >
        <div class="pubtator-danger" data-testid="pubtator-danger-zone">
          <p>
            Use this only when the cache is invalid or needs a full rebuild. Fetch jobs should be
            stopped or allowed to finish first.
          </p>
          <BButton
            variant="danger"
            :disabled="isJobLoading || isClearing"
            @click="showClearAllModal = true"
          >
            <BSpinner v-if="isClearing" small class="me-1" />
            Clear all cache
          </BButton>
        </div>
      </AdminOperationPanel>

      <BModal
        v-model="showClearAllModal"
        title="Clear All PubTator Cache"
        ok-variant="danger"
        ok-title="Yes, clear all"
        @ok="clearAllCache"
      >
        <p>
          Are you sure you want to clear <strong>all</strong> cached PubTator data? This will delete
          all publications and annotations for all queries.
        </p>
        <p class="text-danger mb-0">This action cannot be undone.</p>
      </BModal>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import { ref, computed } from 'vue';
import {
  BContainer,
  BFormGroup,
  BFormInput,
  BFormText,
  BFormCheckbox,
  BButton,
  BSpinner,
  BBadge,
  BAlert,
  BProgress,
  BProgressBar,
  BModal,
} from 'bootstrap-vue-next';
import { usePubtatorAdmin } from '@/composables/usePubtatorAdmin';

// Composable
const {
  // Local state
  error,
  lastStatus,
  isCheckingStatus,
  isClearing,
  isBackfilling,

  // Async job state
  jobId,
  jobStatus,
  jobStep,
  jobProgress,
  jobError,

  // Async job computed
  hasRealProgress,
  progressPercent,
  elapsedTimeDisplay,
  progressVariant,
  statusBadgeClass,
  isJobLoading,

  // Local computed
  cacheProgress,

  // Methods
  getCacheStatus,
  submitFetchJob,
  clearCache,
  backfillGeneSymbols,

  // Async job controls
  stopPolling,
  resetJob,
} = usePubtatorAdmin();

// Form state
const query = ref(
  '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'
);
const maxPages = ref(50);
const clearOld = ref(false);

// UI state
const showClearAllModal = ref(false);

// Feedback
const feedbackMessage = ref('');
const feedbackVariant = ref<'success' | 'danger' | 'info' | 'warning'>('info');

// Computed
const feedbackIcon = computed(() => {
  switch (feedbackVariant.value) {
    case 'success':
      return 'bi bi-check-circle-fill';
    case 'danger':
      return 'bi bi-exclamation-triangle-fill';
    case 'warning':
      return 'bi bi-exclamation-circle-fill';
    default:
      return 'bi bi-info-circle-fill';
  }
});

const cacheStateLabel = computed(() => {
  if (!lastStatus.value) return 'No status';
  return lastStatus.value.cached ? 'Cached' : 'Not cached';
});

// Methods
function formatDate(dateStr: string | null): string {
  if (!dateStr) return 'N/A';
  const date = new Date(dateStr);
  return date.toLocaleString();
}

async function checkStatus() {
  if (!query.value.trim()) return;
  feedbackMessage.value = '';

  try {
    await getCacheStatus(query.value);
  } catch (_err) {
    feedbackMessage.value = `Error checking status: ${error.value}`;
    feedbackVariant.value = 'danger';
  }
}

async function submitFetch() {
  if (!query.value.trim()) return;
  feedbackMessage.value = '';
  resetJob(); // Clear any previous job state

  try {
    await submitFetchJob(query.value, maxPages.value, clearOld.value);
    feedbackMessage.value = `Job submitted! Fetching ${maxPages.value} pages (~${Math.round((maxPages.value * 2.5) / 60)} min)`;
    feedbackVariant.value = 'info';
  } catch (_err) {
    feedbackMessage.value = `Error submitting job: ${error.value}`;
    feedbackVariant.value = 'danger';
  }
}

async function backfillGenes() {
  if (!lastStatus.value?.query_id) return;
  feedbackMessage.value = '';

  try {
    const backfillResult = await backfillGeneSymbols(lastStatus.value.query_id);
    feedbackMessage.value = backfillResult.message;
    feedbackVariant.value = 'success';
  } catch (_err) {
    feedbackMessage.value = `Error backfilling: ${error.value}`;
    feedbackVariant.value = 'danger';
  }
}

async function clearAllCache() {
  feedbackMessage.value = '';

  try {
    const clearResult = await clearCache();
    feedbackMessage.value = clearResult.message;
    feedbackVariant.value = 'success';
    lastStatus.value = null;
  } catch (_err) {
    feedbackMessage.value = `Error clearing cache: ${error.value}`;
    feedbackVariant.value = 'danger';
  } finally {
    showClearAllModal.value = false;
  }
}
</script>

<style scoped>
.pubtator-admin {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

.pubtator-query-form {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.75rem;
  align-items: end;
}

.pubtator-query-form__field {
  margin-bottom: 0;
}

.pubtator-query-form__textarea {
  min-height: 5.25rem;
  resize: vertical;
  font-family: var(
    --font-family-mono,
    ui-monospace,
    SFMono-Regular,
    Menlo,
    Monaco,
    Consolas,
    monospace
  );
  font-size: 0.875rem;
  line-height: 1.4;
}

.pubtator-query-form__actions {
  display: flex;
  justify-content: flex-end;
}

.pubtator-status {
  display: grid;
  gap: 0.875rem;
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #e6ebf2;
}

.pubtator-status__summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 0.75rem;
  align-items: center;
  justify-content: space-between;
}

.pubtator-status__badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 1.6rem;
  padding: 0.2rem 0.6rem;
  border-radius: var(--radius-full, 999px);
  font-size: 0.8125rem;
  font-weight: 700;
}

.pubtator-status__badge--success {
  border: 1px solid rgba(46, 125, 50, 0.28);
  background: #edf7ed;
  color: var(--status-success, #2e7d32);
}

.pubtator-status__badge--warning {
  border: 1px solid rgba(245, 124, 0, 0.3);
  background: #fff7ed;
  color: var(--status-warning, #f57c00);
}

.pubtator-status__updated {
  color: #64748b;
  font-size: 0.8125rem;
}

.pubtator-metrics {
  display: grid;
  grid-template-columns: repeat(5, minmax(8rem, 1fr));
  gap: 0.625rem;
}

.pubtator-metric {
  min-width: 0;
  padding: 0.75rem;
  border: 1px solid #e1e7ef;
  border-radius: 8px;
  background: #f8fafc;
}

.pubtator-metric__label {
  display: block;
  margin-bottom: 0.25rem;
  color: #64748b;
  font-size: 0.75rem;
  font-weight: 700;
}

.pubtator-metric strong {
  color: #172033;
  font-size: 1rem;
}

.pubtator-cache-progress {
  display: grid;
  gap: 0.35rem;
}

.pubtator-cache-progress__header {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  color: #41576f;
  font-size: 0.8125rem;
}

.pubtator-empty-state {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-top: 1rem;
  padding: 0.75rem;
  border: 1px dashed #cbd5e1;
  border-radius: 8px;
  background: #f8fafc;
  color: #526070;
  font-size: 0.875rem;
}

.pubtator-fetch {
  display: grid;
  gap: 1rem;
}

.pubtator-fetch__settings {
  display: grid;
  grid-template-columns: minmax(10rem, 16rem) minmax(14rem, 1fr);
  gap: 1rem;
  align-items: start;
}

.pubtator-fetch__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.pubtator-job {
  display: grid;
  gap: 0.625rem;
  padding: 0.875rem;
  border: 1px solid #d7dee8;
  border-radius: 8px;
  background: #f8fafc;
}

.pubtator-job__header {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  align-items: center;
  justify-content: space-between;
}

.pubtator-job__id {
  color: #24364b;
  font-weight: 700;
}

.pubtator-job__elapsed,
.pubtator-job__step {
  color: #64748b;
  font-size: 0.8125rem;
}

.pubtator-job__step {
  margin: 0;
}

.pubtator-danger {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  align-items: center;
  justify-content: space-between;
}

.pubtator-danger p {
  max-width: 58rem;
  margin: 0;
  color: #526070;
  font-size: 0.875rem;
}

@media (max-width: 991.98px) {
  .pubtator-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 767.98px) {
  .pubtator-admin {
    padding: 0.75rem;
  }

  .pubtator-query-form,
  .pubtator-fetch__settings {
    grid-template-columns: 1fr;
  }

  .pubtator-query-form__actions,
  .pubtator-query-form__actions :deep(.btn),
  .pubtator-fetch__actions,
  .pubtator-fetch__actions :deep(.btn),
  .pubtator-danger,
  .pubtator-danger :deep(.btn) {
    width: 100%;
  }

  .pubtator-fetch__actions,
  .pubtator-danger {
    align-items: stretch;
  }

  .pubtator-metrics {
    grid-template-columns: 1fr;
  }
}
</style>
