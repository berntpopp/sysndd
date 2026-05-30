<!-- views/admin/ManageLLM.vue -->
<template>
  <AuthenticatedPageShell
    title="LLM Administration"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol col md="12">
            <AdminOperationPanel
              title="LLM Configuration"
              :meta="
                config ? (config.gemini_configured ? config.current_model : 'Not configured') : null
              "
              icon="bi-cpu"
            >
              <template #actions>
                <BButton
                  variant="outline-primary"
                  size="sm"
                  :disabled="loading"
                  @click="refreshAll"
                >
                  <BSpinner v-if="loading" small class="me-1" />
                  Refresh
                </BButton>
              </template>

              <!-- Tab Navigation -->
              <nav class="nav nav-pills admin-tabs mb-3" aria-label="LLM administration sections">
                <RouterLink
                  v-for="tab in tabs"
                  :key="tab.id"
                  :to="{ path: '/ManageLLM', hash: tab.hash }"
                  class="nav-link"
                  :class="{ active: activeTab === tab.id }"
                  :aria-current="activeTab === tab.id ? 'page' : undefined"
                  @click="setActiveTab(tab.id)"
                >
                  {{ tab.label }}
                </RouterLink>
              </nav>

              <section v-show="activeTab === 'overview'" id="overview" role="tabpanel">
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
                          @click="handleRegenerate('functional')"
                        >
                          <BSpinner
                            v-if="functionalRegenerationJob.isLoading.value"
                            small
                            class="me-1"
                          />
                          Regenerate Functional
                        </BButton>
                        <BButton
                          variant="outline-primary"
                          size="sm"
                          data-testid="llm-regenerate-phenotype"
                          :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
                          @click="handleRegenerate('phenotype')"
                        >
                          <BSpinner
                            v-if="phenotypeRegenerationJob.isLoading.value"
                            small
                            class="me-1"
                          />
                          Regenerate Phenotype
                        </BButton>
                      </div>
                      <BButton
                        variant="outline-danger"
                        size="sm"
                        :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
                        @click="showClearModal = true"
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
                        <article
                          v-for="row in cacheSummaryRows"
                          :key="row.key"
                          class="llm-mobile-row"
                        >
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
                                    <template v-else-if="job.runner.isLoading.value">
                                      Processing...
                                    </template>
                                  </BProgressBar>
                                </BProgress>
                                <BAlert
                                  v-if="job.runner.error.value"
                                  variant="danger"
                                  show
                                  class="mt-2 mb-0"
                                >
                                  <i
                                    class="bi bi-exclamation-triangle-fill me-1"
                                    aria-hidden="true"
                                  />
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
                                {{ job.runner.progress.value.current }}/{{
                                  job.runner.progress.value.total
                                }}
                              </template>
                              <template v-else-if="job.runner.isLoading.value">
                                Processing...
                              </template>
                            </BProgressBar>
                          </BProgress>
                        </article>
                      </div>
                    </section>
                  </div>
                </TableShell>
              </section>

              <!-- Configuration Tab -->
              <section v-show="activeTab === 'configuration'" id="configuration" role="tabpanel">
                <LlmConfigPanel
                  :config="config"
                  :loading="loading"
                  @update-model="handleModelUpdate"
                />
              </section>

              <!-- Prompts Tab -->
              <section v-show="activeTab === 'prompts'" id="prompts" role="tabpanel">
                <LlmPromptEditor :prompts="prompts" :loading="loading" @save="handlePromptSave" />
              </section>

              <!-- Cache Tab -->
              <section v-show="activeTab === 'cache'" id="cache" role="tabpanel">
                <LlmCacheManager
                  :stats="cacheStats"
                  @clear="handleCacheClear"
                  @validate="handleValidate"
                  @regenerate="handleRegenerate"
                />
              </section>

              <!-- Logs Tab -->
              <section v-show="activeTab === 'logs'" id="logs" role="tabpanel">
                <LlmLogViewer />
              </section>
            </AdminOperationPanel>
          </BCol>
        </BRow>

        <!-- Clear Cache Confirmation Modal -->
        <BModal v-model="showClearModal" title="Clear Cache & Regenerate" ok-variant="danger">
          <template #default>
            <p>This will:</p>
            <ol>
              <li>Delete all cached LLM summaries</li>
              <li>Trigger regeneration for all clusters</li>
              <li>This may take several minutes and incur API costs</li>
            </ol>
            <BFormGroup label="Clear which clusters?">
              <BFormRadioGroup v-model="clearType" :options="clearOptions" stacked />
            </BFormGroup>
          </template>
          <template #footer>
            <BButton variant="secondary" @click="showClearModal = false">Cancel</BButton>
            <BButton variant="danger" @click="handleClearAndRegenerate">
              Clear & Regenerate
            </BButton>
          </template>
        </BModal>
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import TableShell from '@/components/table/TableShell.vue';
import { computed, ref, onMounted, onUnmounted, watch } from 'vue';
import { useLlmAdmin } from '@/composables/useLlmAdmin';
import { useAsyncJob } from '@/composables/useAsyncJob';
import useToast from '@/composables/useToast';
import LlmConfigPanel from '@/components/llm/LlmConfigPanel.vue';
import LlmPromptEditor from '@/components/llm/LlmPromptEditor.vue';
import LlmCacheManager from '@/components/llm/LlmCacheManager.vue';
import LlmLogViewer from '@/components/llm/LlmLogViewer.vue';
import type { PromptType, ClusterType, RegenerationJobResponse } from '@/types/llm';

const { makeToast } = useToast();
const {
  config,
  prompts,
  cacheStats,
  loading,
  fetchConfig,
  fetchPrompts,
  fetchCacheStats,
  updateModel,
  updatePrompt,
  clearCache,
  triggerRegeneration,
  updateValidationStatus,
} = useLlmAdmin();

const jobStatusUrl = (jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`;

// Async job tracking for regeneration. The LLM endpoint can submit one child
// job per cluster type, so each type gets its own visible tracker.
const functionalRegenerationJob = useAsyncJob(jobStatusUrl);
const phenotypeRegenerationJob = useAsyncJob(jobStatusUrl);

const regenerationJobs = {
  functional: functionalRegenerationJob,
  phenotype: phenotypeRegenerationJob,
};

const regenerationJobLabels: Record<ClusterType, string> = {
  functional: 'Functional regeneration',
  phenotype: 'Phenotype regeneration',
};

const regenerationStorageKey = 'sysndd.llm.activeRegenerationJobs.v1';
type StoredRegenerationJobs = Partial<Record<ClusterType, string>>;

// Local state
const showClearModal = ref(false);
const clearType = ref<ClusterType | 'all'>('all');
const regenerationFeedback = ref('');
const regenerationFeedbackVariant = ref<'success' | 'danger' | 'info' | 'warning'>('info');

type LlmAdminTabId = 'overview' | 'configuration' | 'prompts' | 'cache' | 'logs';

const tabs: Array<{ id: LlmAdminTabId; label: string; hash: string }> = [
  { id: 'overview', label: 'Overview', hash: '#overview' },
  { id: 'configuration', label: 'Configuration', hash: '#configuration' },
  { id: 'prompts', label: 'Prompts', hash: '#prompts' },
  { id: 'cache', label: 'Cache', hash: '#cache' },
  { id: 'logs', label: 'Logs', hash: '#logs' },
];

const activeTab = ref<LlmAdminTabId>('overview');

const isAnyRegenerationLoading = computed(() =>
  Object.values(regenerationJobs).some((job) => job.isLoading.value)
);

const visibleRegenerationJobs = computed(() =>
  (Object.keys(regenerationJobs) as ClusterType[])
    .map((type) => ({
      type,
      label: regenerationJobLabels[type],
      runner: regenerationJobs[type],
    }))
    .filter((job) => Boolean(job.runner.jobId.value))
);

const overviewDescription = computed(() => {
  const model = config.value?.gemini_configured ? config.value.current_model : 'Not configured';
  return `Model ${model}. Cache and regeneration controls use the same compact table layout as public data views.`;
});

const cacheHealthLabel = computed(() => {
  if (!config.value?.gemini_configured) return 'Provider not configured';
  const pending = cacheStats.value?.by_status?.pending ?? 0;
  return pending > 0 ? `${pending} pending review` : 'No pending reviews';
});

const cacheSummaryRows = computed(() => [
  {
    key: 'total',
    label: 'Total summaries',
    value: String(cacheStats.value?.total_entries ?? 0),
    status: 'Cached',
    tone: 'neutral',
    note: 'All stored functional and phenotype summaries',
  },
  {
    key: 'validated',
    label: 'Validated',
    value: String(cacheStats.value?.by_status?.validated ?? 0),
    status: 'Accepted',
    tone: 'success',
    note: 'Summaries approved for display',
  },
  {
    key: 'pending',
    label: 'Pending review',
    value: String(cacheStats.value?.by_status?.pending ?? 0),
    status: 'Needs review',
    tone: 'warning',
    note: 'Generated summaries awaiting validation',
  },
  {
    key: 'cost',
    label: 'Estimated cost',
    value: `$${(cacheStats.value?.estimated_cost_usd ?? 0).toFixed(2)}`,
    status: 'USD',
    tone: 'info',
    note: 'Approximate generation spend',
  },
]);

const regenerationFeedbackIcon = computed(() => {
  switch (regenerationFeedbackVariant.value) {
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

const clearOptions = [
  { text: 'All clusters', value: 'all' },
  { text: 'Functional clusters only', value: 'functional' },
  { text: 'Phenotype clusters only', value: 'phenotype' },
];

function tabFromHash(hash: string): LlmAdminTabId {
  const normalized = hash.replace(/^#/, '');
  return tabs.find((tab) => tab.id === normalized)?.id ?? 'overview';
}

function syncActiveTabFromLocation() {
  activeTab.value = tabFromHash(window.location.hash);
}

function setActiveTab(tabId: LlmAdminTabId) {
  activeTab.value = tabId;
}

function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

function getSessionStorage(): Storage | null {
  return typeof window === 'undefined' ? null : window.sessionStorage;
}

function readStoredRegenerationJobs(): StoredRegenerationJobs {
  const storage = getSessionStorage();
  if (!storage) return {};

  try {
    const parsed = JSON.parse(storage.getItem(regenerationStorageKey) || '{}') as unknown;
    if (!parsed || typeof parsed !== 'object') return {};

    return (['functional', 'phenotype'] as ClusterType[]).reduce<StoredRegenerationJobs>(
      (jobs, type) => {
        const jobId = (parsed as Record<string, unknown>)[type];
        if (typeof jobId === 'string' && jobId.length > 0) {
          jobs[type] = jobId;
        }
        return jobs;
      },
      {}
    );
  } catch {
    return {};
  }
}

function writeStoredRegenerationJobs(jobs: StoredRegenerationJobs) {
  const storage = getSessionStorage();
  if (!storage) return;

  if (Object.keys(jobs).length === 0) {
    storage.removeItem(regenerationStorageKey);
    return;
  }

  storage.setItem(regenerationStorageKey, JSON.stringify(jobs));
}

function persistRegenerationJob(type: ClusterType, jobId: string) {
  writeStoredRegenerationJobs({
    ...readStoredRegenerationJobs(),
    [type]: jobId,
  });
}

function clearPersistedRegenerationJob(type: ClusterType) {
  const jobs = readStoredRegenerationJobs();
  delete jobs[type];
  writeStoredRegenerationJobs(jobs);
}

function rehydrateRegenerationJobs() {
  const storedJobs = readStoredRegenerationJobs();
  const resumed = (Object.keys(regenerationJobs) as ClusterType[]).filter((type) => {
    const jobId = storedJobs[type];
    if (!jobId || regenerationJobs[type].jobId.value) return false;

    regenerationJobs[type].startJob(jobId);
    return true;
  });

  if (resumed.length) {
    regenerationFeedback.value = `Resumed tracking ${resumed
      .map((type) => regenerationJobLabels[type].toLowerCase())
      .join(' and ')} from this browser session.`;
    regenerationFeedbackVariant.value = 'info';
  }
}

function requestedClusterTypes(type: ClusterType | 'all'): ClusterType[] {
  return type === 'all' ? ['functional', 'phenotype'] : [type];
}

function jobIdFromRegenerationResult(result: RegenerationJobResponse, type: ClusterType) {
  return result.results?.[type]?.job_id ?? null;
}

function startRegenerationTrackers(
  result: RegenerationJobResponse,
  requestedType: ClusterType | 'all'
) {
  const started: ClusterType[] = [];
  const skipped: string[] = [];

  requestedClusterTypes(requestedType).forEach((type) => {
    const child = result.results?.[type];
    const jobId = jobIdFromRegenerationResult(result, type);

    if (jobId) {
      const unwrappedJobId = unwrapValue(jobId);
      regenerationJobs[type].reset();
      regenerationJobs[type].startJob(unwrappedJobId);
      persistRegenerationJob(type, unwrappedJobId);
      started.push(type);
      return;
    }

    if (child?.skipped) {
      skipped.push(`${regenerationJobLabels[type]} skipped: ${child.reason || 'No job created'}`);
    }
  });

  if (started.length) {
    regenerationFeedback.value = `Tracking ${started
      .map((type) => regenerationJobLabels[type].toLowerCase())
      .join(' and ')}. You can leave this page and return to Logs or Cache later.`;
    regenerationFeedbackVariant.value = 'info';
    return;
  }

  if (skipped.length) {
    regenerationFeedback.value = skipped.join(' ');
    regenerationFeedbackVariant.value = 'warning';
    return;
  }

  regenerationFeedback.value = 'No regeneration job was created. Check the API response and logs.';
  regenerationFeedbackVariant.value = 'warning';
}

// Lifecycle
onMounted(async () => {
  syncActiveTabFromLocation();
  rehydrateRegenerationJobs();
  window.addEventListener('hashchange', syncActiveTabFromLocation);
  window.addEventListener('popstate', syncActiveTabFromLocation);
  await refreshAll();
});

onUnmounted(() => {
  window.removeEventListener('hashchange', syncActiveTabFromLocation);
  window.removeEventListener('popstate', syncActiveTabFromLocation);
});

// Methods.
// v11.0 closeout F2a: the `useLlmAdmin` composable no longer accepts a
// `token` parameter — the `apiClient` request interceptor reads
// `useAuth().token.value` on every outbound call and injects the Bearer
// header. Call sites therefore just call `fetchConfig()` / `fetchPrompts()`
// / etc. directly. See `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2a.
async function refreshAll() {
  try {
    await Promise.all([fetchConfig(), fetchPrompts(), fetchCacheStats()]);
  } catch {
    makeToast('Failed to load LLM configuration', 'Error', 'danger');
  }
}

async function handleModelUpdate(model: string) {
  try {
    await updateModel(model);
    makeToast(`Model updated to ${model}`, 'Success', 'success');
  } catch {
    makeToast('Failed to update model', 'Error', 'danger');
  }
}

async function handlePromptSave(type: PromptType, template: string, version: string) {
  try {
    await updatePrompt(type, template, version);
    makeToast('Prompt template saved', 'Success', 'success');
    await fetchPrompts();
  } catch {
    makeToast('Failed to save prompt', 'Error', 'danger');
  }
}

async function handleCacheClear(type: ClusterType | 'all') {
  try {
    const result = await clearCache(type);
    makeToast(`Cleared ${result.cleared_count} cached summaries`, 'Success', 'success');
    await fetchCacheStats();
  } catch {
    makeToast('Failed to clear cache', 'Error', 'danger');
  }
}

async function handleRegenerate(type: ClusterType | 'all', force = false) {
  try {
    regenerationFeedback.value = '';
    const result = await triggerRegeneration(type, force);
    startRegenerationTrackers(result, type);
    makeToast('Regeneration job submitted', 'Info', 'info');
  } catch {
    regenerationFeedback.value =
      'Failed to start regeneration. Check your configuration and API logs.';
    regenerationFeedbackVariant.value = 'danger';
    makeToast('Failed to start regeneration', 'Error', 'danger');
  }
}

async function handleClearAndRegenerate() {
  showClearModal.value = false;
  await handleCacheClear(clearType.value);
  await handleRegenerate(clearType.value, true);
}

async function handleValidate(cacheId: number, action: 'validate' | 'reject') {
  try {
    await updateValidationStatus(cacheId, action);
    makeToast(`Summary ${action}d successfully`, 'Success', 'success');
    await fetchCacheStats();
  } catch {
    makeToast(`Failed to ${action} summary`, 'Error', 'danger');
  }
}

watch(
  () => functionalRegenerationJob.status.value,
  async (newStatus) => {
    if (newStatus === 'completed') {
      clearPersistedRegenerationJob('functional');
      regenerationFeedback.value = 'Functional regeneration completed. Cache statistics refreshed.';
      regenerationFeedbackVariant.value = 'success';
      makeToast('Functional regeneration completed', 'Success', 'success');
      await fetchCacheStats();
    } else if (newStatus === 'failed') {
      clearPersistedRegenerationJob('functional');
      regenerationFeedback.value =
        functionalRegenerationJob.error.value || 'Functional regeneration failed.';
      regenerationFeedbackVariant.value = 'danger';
      makeToast(regenerationFeedback.value, 'Error', 'danger');
    }
  }
);

watch(
  () => phenotypeRegenerationJob.status.value,
  async (newStatus) => {
    if (newStatus === 'completed') {
      clearPersistedRegenerationJob('phenotype');
      regenerationFeedback.value = 'Phenotype regeneration completed. Cache statistics refreshed.';
      regenerationFeedbackVariant.value = 'success';
      makeToast('Phenotype regeneration completed', 'Success', 'success');
      await fetchCacheStats();
    } else if (newStatus === 'failed') {
      clearPersistedRegenerationJob('phenotype');
      regenerationFeedback.value =
        phenotypeRegenerationJob.error.value || 'Phenotype regeneration failed.';
      regenerationFeedbackVariant.value = 'danger';
      makeToast(regenerationFeedback.value, 'Error', 'danger');
    }
  }
);
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
  .admin-tabs {
    gap: 0.25rem;
  }

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
