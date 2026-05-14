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
                <BRow class="g-3 mb-4">
                  <BCol md="3">
                    <BCard class="text-center h-100">
                      <div class="h2 mb-0">{{ cacheStats?.total_entries ?? 0 }}</div>
                      <small class="text-muted">Total Summaries</small>
                    </BCard>
                  </BCol>
                  <BCol md="3">
                    <BCard class="text-center h-100 border-success">
                      <div class="h2 mb-0 text-success">
                        {{ cacheStats?.by_status?.validated ?? 0 }}
                      </div>
                      <small class="text-muted">Validated</small>
                    </BCard>
                  </BCol>
                  <BCol md="3">
                    <BCard class="text-center h-100 border-warning">
                      <div class="h2 mb-0 text-warning">
                        {{ cacheStats?.by_status?.pending ?? 0 }}
                      </div>
                      <small class="text-muted">Pending Review</small>
                    </BCard>
                  </BCol>
                  <BCol md="3">
                    <BCard class="text-center h-100">
                      <div class="h2 mb-0">
                        ${{ (cacheStats?.estimated_cost_usd ?? 0).toFixed(2) }}
                      </div>
                      <small class="text-muted">Est. Cost (USD)</small>
                    </BCard>
                  </BCol>
                </BRow>

                <!-- Quick Actions -->
                <AdminOperationPanel title="Quick Actions" heading-tag="h3" icon="bi-lightning">
                  <BRow class="g-2">
                    <BCol md="4">
                      <BButton
                        variant="outline-danger"
                        class="w-100"
                        :disabled="!config?.gemini_configured || isAnyRegenerationLoading"
                        @click="showClearModal = true"
                      >
                        <BSpinner v-if="isAnyRegenerationLoading" small class="me-1" />
                        Clear Cache & Regenerate
                      </BButton>
                    </BCol>
                    <BCol md="4">
                      <BButton
                        variant="outline-primary"
                        class="w-100"
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
                    </BCol>
                    <BCol md="4">
                      <BButton
                        variant="outline-primary"
                        class="w-100"
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
                    </BCol>
                  </BRow>
                </AdminOperationPanel>

                <!-- Active Job Progress -->
                <div v-if="regenerationFeedback" class="llm-regeneration-feedback">
                  <BAlert :variant="regenerationFeedbackVariant" show class="mb-3">
                    <i :class="regenerationFeedbackIcon" class="me-1" aria-hidden="true" />
                    {{ regenerationFeedback }}
                  </BAlert>
                </div>

                <div v-if="visibleRegenerationJobs.length" class="llm-job-list mb-4">
                  <BCard
                    v-for="job in visibleRegenerationJobs"
                    :key="job.type"
                    class="llm-job-card"
                    :data-testid="`llm-regeneration-job-${job.type}`"
                  >
                    <div class="llm-job-card__header">
                      <div>
                        <BBadge :class="job.runner.statusBadgeClass.value" class="me-2">
                          {{ job.runner.status.value }}
                        </BBadge>
                        <strong>{{ job.label }}</strong>
                        <span class="llm-job-card__id">Job {{ job.runner.jobId.value }}</span>
                      </div>
                      <span class="llm-job-card__elapsed">
                        <i class="bi bi-clock me-1" aria-hidden="true" />
                        {{ job.runner.elapsedTimeDisplay.value }}
                      </span>
                    </div>
                    <p v-if="job.runner.step.value" class="llm-job-card__step">
                      {{ job.runner.step.value }}
                    </p>
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
                        <template v-else-if="job.runner.isLoading.value">Processing...</template>
                      </BProgressBar>
                    </BProgress>
                    <BAlert v-if="job.runner.error.value" variant="danger" show class="mt-3 mb-0">
                      <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
                      {{ job.runner.error.value }}
                    </BAlert>
                  </BCard>
                </div>
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

const jobStatusUrl = (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`;

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
      regenerationJobs[type].reset();
      regenerationJobs[type].startJob(unwrapValue(jobId));
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
      regenerationFeedback.value = 'Functional regeneration completed. Cache statistics refreshed.';
      regenerationFeedbackVariant.value = 'success';
      makeToast('Functional regeneration completed', 'Success', 'success');
      await fetchCacheStats();
    } else if (newStatus === 'failed') {
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
      regenerationFeedback.value = 'Phenotype regeneration completed. Cache statistics refreshed.';
      regenerationFeedbackVariant.value = 'success';
      makeToast('Phenotype regeneration completed', 'Success', 'success');
      await fetchCacheStats();
    } else if (newStatus === 'failed') {
      regenerationFeedback.value =
        phenotypeRegenerationJob.error.value || 'Phenotype regeneration failed.';
      regenerationFeedbackVariant.value = 'danger';
      makeToast(regenerationFeedback.value, 'Error', 'danger');
    }
  }
);
</script>

<style scoped>
.llm-job-list {
  display: grid;
  gap: 0.75rem;
}

.llm-job-card {
  border-color: #d9e0ea;
}

.llm-job-card__header {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
  justify-content: space-between;
}

.llm-job-card__id {
  display: block;
  margin-top: 0.25rem;
  color: var(--neutral-600, #757575);
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
  overflow-wrap: anywhere;
}

.llm-job-card__elapsed {
  flex: 0 0 auto;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
}

.llm-job-card__step {
  margin: 0.75rem 0 0.5rem;
  color: var(--neutral-700, #424242);
  font-size: 0.875rem;
}

@media (max-width: 575.98px) {
  .admin-tabs {
    gap: 0.25rem;
  }

  .llm-job-card__header {
    display: grid;
  }
}
</style>
