<!-- views/admin/ManagePubtator.vue -->
/**
 * ManagePubtator component
 *
 * @description Admin interface for managing PubTator3 publication cache.
 * Allows administrators to:
 * - Check cache status for queries
 * - Submit async fetch jobs with progress tracking
 * - Clear cache (soft/hard reset)
 * - Backfill gene symbols for existing entries
 *
 * Uses non-blocking async jobs for fetching to avoid request timeouts.
 *
 * @component ManagePubtator
 */

<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="10">
          <BCard header-tag="header" border-variant="dark">
            <template #header>
              <h5 class="mb-0">
                <i class="bi bi-journal-medical me-2" />
                <strong>PubTator Cache Management</strong>
              </h5>
            </template>

            <!-- Query Input Section -->
            <BRow class="mb-4">
              <BCol md="8">
                <BFormGroup label="Search Query" label-for="query-input">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-search" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="query-input"
                      v-model="query"
                      placeholder="e.g., epilepsy gene variant"
                      :disabled="isJobLoading"
                      @keyup.enter="checkStatus"
                    />
                    <BButton
                      variant="outline-primary"
                      :disabled="!query.trim() || isCheckingStatus"
                      @click="checkStatus"
                    >
                      <BSpinner v-if="isCheckingStatus" small class="me-1" />
                      Check Status
                    </BButton>
                  </BInputGroup>
                </BFormGroup>
              </BCol>
            </BRow>

            <!-- Cache Status Display -->
            <BCard v-if="lastStatus" class="mb-4" bg-variant="light">
              <BRow>
                <BCol md="6">
                  <h6><i class="bi bi-info-circle me-1" /> Cache Status</h6>
                  <dl class="row mb-0">
                    <dt class="col-6">Status:</dt>
                    <dd class="col-6">
                      <BBadge :variant="lastStatus.cached ? 'success' : 'warning'">
                        {{ lastStatus.cached ? 'Cached' : 'Not Cached' }}
                      </BBadge>
                    </dd>

                    <dt class="col-6">Pages Cached:</dt>
                    <dd class="col-6">{{ lastStatus.pages_cached || 0 }}</dd>

                    <dt class="col-6">Publications:</dt>
                    <dd class="col-6">{{ lastStatus.publications_cached || 0 }}</dd>

                    <dt v-if="lastStatus.cache_date && typeof lastStatus.cache_date === 'string'" class="col-6">Last Updated:</dt>
                    <dd v-if="lastStatus.cache_date && typeof lastStatus.cache_date === 'string'" class="col-6">
                      {{ formatDate(lastStatus.cache_date) }}
                    </dd>
                  </dl>
                </BCol>
                <BCol md="6">
                  <h6><i class="bi bi-cloud-download me-1" /> Available from API</h6>
                  <dl class="row mb-0">
                    <dt class="col-6">Total Pages:</dt>
                    <dd class="col-6">{{ lastStatus.total_pages_available || 0 }}</dd>

                    <dt class="col-6">Total Results:</dt>
                    <dd class="col-6">
                      {{ (lastStatus.total_results_available || 0).toLocaleString() }}
                    </dd>

                    <dt class="col-6">Pages Remaining:</dt>
                    <dd class="col-6">{{ lastStatus.pages_remaining || 0 }}</dd>

                    <dt class="col-6">Est. Fetch Time:</dt>
                    <dd class="col-6">~{{ lastStatus.estimated_fetch_time_minutes || 0 }} min</dd>
                  </dl>
                </BCol>
              </BRow>

              <!-- Cache Progress Bar -->
              <BRow v-if="lastStatus.cached" class="mt-3">
                <BCol>
                  <BProgress :max="100" height="1.5rem" show-value>
                    <BProgressBar :value="cacheProgress" variant="success">
                      {{ cacheProgress }}% cached
                    </BProgressBar>
                  </BProgress>
                </BCol>
              </BRow>
            </BCard>

            <!-- Fetch Controls -->
            <BCard class="mb-4">
              <h6><i class="bi bi-cloud-arrow-down me-1" /> Fetch Publications (Async)</h6>
              <p class="text-muted small mb-3">
                Fetches run in the background. You can close this page and the job will continue.
              </p>

              <BRow class="mb-3">
                <BCol md="4">
                  <BFormGroup label="Pages to Fetch" label-for="max-pages">
                    <BFormInput
                      id="max-pages"
                      v-model.number="maxPages"
                      type="number"
                      min="1"
                      max="2000"
                      :disabled="isJobLoading"
                    />
                    <BFormText>
                      ~{{ Math.round((maxPages * 2.5) / 60) }} min at 10 results/page
                    </BFormText>
                  </BFormGroup>
                </BCol>
                <BCol md="4">
                  <BFormGroup label="Update Type">
                    <BFormCheckbox v-model="clearOld" :disabled="isJobLoading" switch>
                      Hard Update (clear existing cache first)
                    </BFormCheckbox>
                  </BFormGroup>
                </BCol>
              </BRow>

              <BButtonGroup>
                <BButton
                  variant="primary"
                  :disabled="!query.trim() || isJobLoading"
                  @click="submitFetch"
                >
                  <BSpinner v-if="isJobLoading && jobStatus === 'accepted'" small class="me-1" />
                  <i v-else class="bi bi-download me-1" />
                  Submit Fetch Job
                </BButton>
                <BButton
                  v-if="isJobLoading"
                  variant="outline-secondary"
                  @click="stopPolling"
                >
                  <i class="bi bi-stop-circle me-1" />
                  Stop Tracking
                </BButton>
                <BButton
                  variant="outline-secondary"
                  :disabled="!lastStatus?.cached || isJobLoading || isBackfilling"
                  @click="backfillGenes"
                >
                  <BSpinner v-if="isBackfilling" small class="me-1" />
                  <i v-else class="bi bi-arrow-repeat me-1" />
                  Backfill Gene Symbols
                </BButton>
              </BButtonGroup>

              <!-- Job Progress Panel -->
              <BCard v-if="jobId" class="mt-3" :border-variant="progressVariant">
                <BRow>
                  <BCol md="8">
                    <h6 class="mb-2">
                      <BBadge :class="statusBadgeClass" class="me-2">{{ jobStatus }}</BBadge>
                      Job: {{ jobId.substring(0, 8) }}...
                    </h6>
                    <p v-if="jobStep" class="mb-2 text-muted small">{{ jobStep }}</p>

                    <!-- Progress bar -->
                    <BProgress :max="100" height="1.5rem" class="mb-2">
                      <BProgressBar
                        :value="hasRealProgress ? (progressPercent ?? 0) : 100"
                        :variant="progressVariant"
                        :striped="!hasRealProgress"
                        :animated="isJobLoading"
                      >
                        <template v-if="hasRealProgress">
                          {{ jobProgress.current }}/{{ jobProgress.total }} pages
                        </template>
                        <template v-else-if="isJobLoading"> Processing... </template>
                      </BProgressBar>
                    </BProgress>
                  </BCol>
                  <BCol md="4" class="text-end">
                    <div class="text-muted">
                      <i class="bi bi-clock me-1" />
                      {{ elapsedTimeDisplay }}
                    </div>
                  </BCol>
                </BRow>

                <!-- Job error -->
                <BAlert v-if="jobError" variant="danger" class="mt-2 mb-0" show>
                  <i class="bi bi-exclamation-triangle-fill me-1" />
                  {{ jobError }}
                </BAlert>

                <!-- Job completed -->
                <BAlert v-if="jobStatus === 'completed'" variant="success" class="mt-2 mb-0" show>
                  <i class="bi bi-check-circle-fill me-1" />
                  Fetch completed successfully! Refresh cache status to see results.
                </BAlert>
              </BCard>

              <!-- Feedback messages -->
              <BAlert v-if="feedbackMessage" :variant="feedbackVariant" class="mt-3 mb-0" show>
                <i :class="feedbackIcon" class="me-1" />
                {{ feedbackMessage }}
              </BAlert>
            </BCard>

            <!-- Clear Cache Section -->
            <BCard border-variant="danger">
              <h6 class="text-danger"><i class="bi bi-trash me-1" /> Clear Cache</h6>
              <p class="text-muted small mb-3">
                Remove all cached publications and annotations. Use with caution.
              </p>

              <BButton
                variant="danger"
                :disabled="isJobLoading || isClearing"
                @click="showClearAllModal = true"
              >
                <BSpinner v-if="isClearing" small class="me-1" />
                Clear ALL Cache
              </BButton>
            </BCard>
          </BCard>
        </BCol>
      </BRow>

      <!-- Clear All Confirmation Modal -->
      <BModal
        v-model="showClearAllModal"
        title="Clear All PubTator Cache"
        ok-variant="danger"
        ok-title="Yes, Clear All"
        @ok="clearAllCache"
      >
        <p>
          Are you sure you want to clear <strong>all</strong> cached PubTator data? This will
          delete all publications and annotations for all queries.
        </p>
        <p class="text-danger mb-0">This action cannot be undone.</p>
      </BModal>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import {
  BContainer,
  BRow,
  BCol,
  BCard,
  BFormGroup,
  BInputGroup,
  BInputGroupText,
  BFormInput,
  BFormText,
  BFormCheckbox,
  BButton,
  BButtonGroup,
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
const query = ref('epilepsy gene variant');
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
dl.row dt {
  font-weight: 500;
}

dl.row dd {
  color: var(--bs-body-color);
}
</style>
