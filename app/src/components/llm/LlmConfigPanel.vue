<!-- components/llm/LlmConfigPanel.vue -->
<template>
  <BCard>
    <template #header>
      <h6 class="mb-0">Model Configuration</h6>
    </template>

    <BAlert v-if="!config?.gemini_configured" variant="warning" :model-value="true">
      <strong>Gemini API not configured.</strong>
      Set the <code>GEMINI_API_KEY</code> environment variable to enable LLM features.
    </BAlert>

    <BForm v-else @submit.prevent>
      <BFormGroup label="Current Model" label-for="model-select">
        <BFormSelect
          id="model-select"
          v-model="selectedModel"
          :options="modelOptions"
          :disabled="loading"
          @change="handleModelChange"
        />
        <BFormText v-if="selectedModelInfo">
          {{ selectedModelInfo.description }}
          <br />
          <small class="text-muted">
            Rate limit: {{ selectedModelInfo.rpm_limit?.toLocaleString() ?? 'N/A' }} RPM
            <span
              v-if="
                typeof selectedModelInfo.rpd_limit === 'number' && selectedModelInfo.rpd_limit > 0
              "
            >
              , {{ selectedModelInfo.rpd_limit.toLocaleString() }} RPD
            </span>
          </small>
        </BFormText>
      </BFormGroup>

      <BFormGroup label="Rate Limiting" class="mt-4">
        <BRow>
          <BCol md="6">
            <BFormGroup label="Capacity (requests)" label-size="sm">
              <BFormInput
                :model-value="config?.rate_limit?.capacity"
                type="number"
                disabled
                size="sm"
              />
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="Window (seconds)" label-size="sm">
              <BFormInput
                :model-value="config?.rate_limit?.fill_time_s"
                type="number"
                disabled
                size="sm"
              />
            </BFormGroup>
          </BCol>
        </BRow>
        <BFormText>
          Rate limiting is configured in the API. Edit
          <code>llm-service.R</code> to change.
        </BFormText>
      </BFormGroup>

      <BFormGroup label="Additional Settings" class="mt-4">
        <BRow>
          <BCol md="6">
            <BFormGroup label="Backoff Base (seconds)" label-size="sm">
              <BFormInput
                :model-value="config?.rate_limit?.backoff_base"
                type="number"
                disabled
                size="sm"
              />
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="Max Retries" label-size="sm">
              <BFormInput
                :model-value="config?.rate_limit?.max_retries"
                type="number"
                disabled
                size="sm"
              />
            </BFormGroup>
          </BCol>
        </BRow>
      </BFormGroup>
    </BForm>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import {
  BCard,
  BAlert,
  BForm,
  BFormGroup,
  BFormSelect,
  BFormText,
  BFormInput,
  BRow,
  BCol,
} from 'bootstrap-vue-next';
import type { LlmConfig } from '@/types/llm';

const props = defineProps<{
  config: LlmConfig | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'update-model', model: string): void;
}>();

const selectedModel = ref(props.config?.current_model || '');

watch(
  () => props.config?.current_model,
  (newVal) => {
    if (newVal) selectedModel.value = newVal;
  }
);

const modelOptions = computed(
  () =>
    props.config?.available_models?.map((m) => ({
      value: m.model_id,
      text: `${m.display_name} - ${m.recommended_for}`,
    })) ?? []
);

const selectedModelInfo = computed(() =>
  props.config?.available_models?.find((m) => m.model_id === selectedModel.value)
);

function handleModelChange() {
  emit('update-model', selectedModel.value);
}
</script>
