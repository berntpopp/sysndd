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
                <LlmOverviewPanel
                  :config="config"
                  :cache-stats="cacheStats"
                  :loading="loading"
                  :overview-description="overviewDescription"
                  :cache-health-label="cacheHealthLabel"
                  :cache-summary-rows="cacheSummaryRows"
                  :regeneration-feedback="regenerationFeedback"
                  :regeneration-feedback-variant="regenerationFeedbackVariant"
                  :regeneration-feedback-icon="regenerationFeedbackIcon"
                  :is-any-regeneration-loading="isAnyRegenerationLoading"
                  :visible-regeneration-jobs="visibleRegenerationJobs"
                  :functional-regeneration-job="functionalRegenerationJob"
                  :phenotype-regeneration-job="phenotypeRegenerationJob"
                  @regenerate="handleRegenerate"
                  @open-clear-modal="showClearModal = true"
                />
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
import LlmOverviewPanel from './LlmOverviewPanel.vue';
import { ref, onMounted } from 'vue';
import { useLlmAdmin } from '@/composables/useLlmAdmin';
import useToast from '@/composables/useToast';
import LlmConfigPanel from '@/components/llm/LlmConfigPanel.vue';
import LlmPromptEditor from '@/components/llm/LlmPromptEditor.vue';
import LlmCacheManager from '@/components/llm/LlmCacheManager.vue';
import LlmLogViewer from '@/components/llm/LlmLogViewer.vue';
import type { PromptType, ClusterType } from '@/types/llm';
import { useLlmAdminTabs } from './useLlmAdminTabs';
import { useLlmCacheOverview } from './useLlmCacheOverview';
import { useLlmRegenerationJobs } from './useLlmRegenerationJobs';

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

// Local state
const showClearModal = ref(false);
const clearType = ref<ClusterType | 'all'>('all');
const regenerationFeedback = ref('');
const regenerationFeedbackVariant = ref<'success' | 'danger' | 'info' | 'warning'>('info');

const { tabs, activeTab, setActiveTab } = useLlmAdminTabs();

const { overviewDescription, cacheHealthLabel, cacheSummaryRows } = useLlmCacheOverview(
  config,
  cacheStats
);

const {
  regenerationFeedbackIcon,
  isAnyRegenerationLoading,
  visibleRegenerationJobs,
  functionalRegenerationJob,
  phenotypeRegenerationJob,
  rehydrateRegenerationJobs,
  startRegenerationTrackers,
} = useLlmRegenerationJobs(
  { makeToast, fetchCacheStats },
  { regenerationFeedback, regenerationFeedbackVariant }
);

const clearOptions = [
  { text: 'All clusters', value: 'all' },
  { text: 'Functional clusters only', value: 'functional' },
  { text: 'Phenotype clusters only', value: 'phenotype' },
];

// Lifecycle
onMounted(async () => {
  rehydrateRegenerationJobs();
  await refreshAll();
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
</script>

<style scoped>
@media (max-width: 575.98px) {
  .admin-tabs {
    gap: 0.25rem;
  }
}
</style>
