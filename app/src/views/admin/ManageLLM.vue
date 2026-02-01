<!-- views/admin/ManageLLM.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <h3>LLM Administration</h3>
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-2"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <BRow class="align-items-center">
                <BCol>
                  <h5 class="mb-0 text-start fw-bold">
                    LLM Administration
                    <BBadge
                      v-if="config && !config.gemini_configured"
                      variant="warning"
                      class="ms-2"
                    >
                      Not Configured
                    </BBadge>
                    <BBadge
                      v-else-if="config"
                      variant="success"
                      class="ms-2"
                    >
                      {{ config.current_model }}
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    variant="outline-primary"
                    size="sm"
                    :disabled="loading"
                    @click="refreshAll"
                  >
                    <BSpinner v-if="loading" small class="me-1" />
                    Refresh
                  </BButton>
                </BCol>
              </BRow>
            </template>

            <!-- Tab Navigation -->
            <BTabs v-model="activeTab" pills card nav-class="px-3 pt-2">
              <!-- Overview Tab -->
              <BTab title="Overview">
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
                <BCard class="mb-4">
                  <template #header>
                    <h6 class="mb-0">Quick Actions</h6>
                  </template>
                  <BRow class="g-2">
                    <BCol md="4">
                      <BButton
                        variant="outline-danger"
                        class="w-100"
                        :disabled="!config?.gemini_configured || regenerationJob.isLoading.value"
                        @click="showClearModal = true"
                      >
                        Clear Cache & Regenerate
                      </BButton>
                    </BCol>
                    <BCol md="4">
                      <BButton
                        variant="outline-primary"
                        class="w-100"
                        :disabled="!config?.gemini_configured || regenerationJob.isLoading.value"
                        @click="handleRegenerate('functional')"
                      >
                        Regenerate Functional
                      </BButton>
                    </BCol>
                    <BCol md="4">
                      <BButton
                        variant="outline-primary"
                        class="w-100"
                        :disabled="!config?.gemini_configured || regenerationJob.isLoading.value"
                        @click="handleRegenerate('phenotype')"
                      >
                        Regenerate Phenotype
                      </BButton>
                    </BCol>
                  </BRow>
                </BCard>

                <!-- Active Job Progress -->
                <BCard v-if="regenerationJob.isLoading.value" class="mb-4">
                  <template #header>
                    <h6 class="mb-0">Regeneration in Progress</h6>
                  </template>
                  <BProgress
                    :value="regenerationJob.hasRealProgress.value ? regenerationJob.progressPercent.value ?? 0 : 100"
                    :max="100"
                    show-progress
                    animated
                  />
                  <div class="mt-2 text-muted small">
                    {{ regenerationJob.step.value }}
                    <span class="float-end">{{ regenerationJob.elapsedTimeDisplay.value }}</span>
                  </div>
                </BCard>
              </BTab>

              <!-- Configuration Tab -->
              <BTab title="Configuration">
                <LlmConfigPanel
                  :config="config"
                  :loading="loading"
                  @update-model="handleModelUpdate"
                />
              </BTab>

              <!-- Prompts Tab -->
              <BTab title="Prompts">
                <LlmPromptEditor
                  :prompts="prompts"
                  :loading="loading"
                  @save="handlePromptSave"
                />
              </BTab>

              <!-- Cache Tab -->
              <BTab title="Cache">
                <LlmCacheManager
                  :stats="cacheStats"
                  @clear="handleCacheClear"
                  @validate="handleValidate"
                  @regenerate="handleRegenerate"
                />
              </BTab>

              <!-- Logs Tab -->
              <BTab title="Logs">
                <LlmLogViewer />
              </BTab>
            </BTabs>
          </BCard>
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
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuth } from '@/composables/useAuth';
import { useLlmAdmin } from '@/composables/useLlmAdmin';
import { useAsyncJob } from '@/composables/useAsyncJob';
import useToast from '@/composables/useToast';
import LlmConfigPanel from '@/components/llm/LlmConfigPanel.vue';
import LlmPromptEditor from '@/components/llm/LlmPromptEditor.vue';
import LlmCacheManager from '@/components/llm/LlmCacheManager.vue';
import LlmLogViewer from '@/components/llm/LlmLogViewer.vue';
import type { PromptType, ClusterType } from '@/types/llm';

const { getToken } = useAuth();
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

// Async job tracking for regeneration
const regenerationJob = useAsyncJob(
  (jobId) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

// Local state
const activeTab = ref(0);
const showClearModal = ref(false);
const clearType = ref<ClusterType | 'all'>('all');

const clearOptions = [
  { text: 'All clusters', value: 'all' },
  { text: 'Functional clusters only', value: 'functional' },
  { text: 'Phenotype clusters only', value: 'phenotype' },
];

// Lifecycle
onMounted(async () => {
  await refreshAll();
});

// Methods
async function refreshAll() {
  const token = await getToken();
  if (!token) return;

  try {
    await Promise.all([
      fetchConfig(token),
      fetchPrompts(token),
      fetchCacheStats(token),
    ]);
  } catch {
    makeToast('Failed to load LLM configuration', 'Error', 'danger');
  }
}

async function handleModelUpdate(model: string) {
  const token = await getToken();
  if (!token) return;

  try {
    await updateModel(token, model);
    makeToast(`Model updated to ${model}`, 'Success', 'success');
  } catch {
    makeToast('Failed to update model', 'Error', 'danger');
  }
}

async function handlePromptSave(type: PromptType, template: string, version: string) {
  const token = await getToken();
  if (!token) return;

  try {
    await updatePrompt(token, type, template, version);
    makeToast('Prompt template saved', 'Success', 'success');
    await fetchPrompts(token);
  } catch {
    makeToast('Failed to save prompt', 'Error', 'danger');
  }
}

async function handleCacheClear(type: ClusterType | 'all') {
  const token = await getToken();
  if (!token) return;

  try {
    const result = await clearCache(token, type);
    makeToast(`Cleared ${result.cleared_count} cached summaries`, 'Success', 'success');
    await fetchCacheStats(token);
  } catch {
    makeToast('Failed to clear cache', 'Error', 'danger');
  }
}

async function handleRegenerate(type: ClusterType | 'all', force = false) {
  const token = await getToken();
  if (!token) return;

  try {
    const result = await triggerRegeneration(token, type, force);
    regenerationJob.startJob(result.job_id);
    makeToast('Regeneration job started', 'Info', 'info');
  } catch {
    makeToast('Failed to start regeneration', 'Error', 'danger');
  }
}

async function handleClearAndRegenerate() {
  showClearModal.value = false;
  await handleCacheClear(clearType.value);
  await handleRegenerate(clearType.value, true);
}

async function handleValidate(cacheId: number, action: 'validate' | 'reject') {
  const token = await getToken();
  if (!token) return;

  try {
    await updateValidationStatus(token, cacheId, action);
    makeToast(`Summary ${action}d successfully`, 'Success', 'success');
    await fetchCacheStats(token);
  } catch {
    makeToast(`Failed to ${action} summary`, 'Error', 'danger');
  }
}
</script>
