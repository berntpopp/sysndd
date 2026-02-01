<!-- components/llm/LlmPromptEditor.vue -->
<template>
  <BCard>
    <template #header>
      <BRow class="align-items-center">
        <BCol>
          <h6 class="mb-0">Prompt Templates</h6>
        </BCol>
        <BCol class="text-end">
          <BFormSelect
            v-model="selectedPrompt"
            :options="promptOptions"
            size="sm"
            class="w-auto"
          />
        </BCol>
      </BRow>
    </template>

    <div v-if="currentPrompt">
      <BFormGroup :label="`${promptLabels[selectedPrompt]} Prompt`">
        <BFormTextarea
          v-model="editedTemplate"
          rows="20"
          class="font-monospace"
          style="font-size: 0.85rem; line-height: 1.4;"
          :disabled="loading"
        />
      </BFormGroup>

      <BRow class="align-items-center mt-3">
        <BCol>
          <BFormGroup label="Version" label-cols="auto" class="mb-0">
            <BFormInput
              v-model="editedVersion"
              size="sm"
              class="w-auto"
              style="max-width: 120px;"
            />
          </BFormGroup>
        </BCol>
        <BCol class="text-end">
          <BButton
            variant="secondary"
            size="sm"
            class="me-2"
            :disabled="!hasChanges"
            @click="resetPrompt"
          >
            Reset
          </BButton>
          <BButton
            variant="primary"
            size="sm"
            :disabled="!hasChanges || loading"
            @click="savePrompt"
          >
            Save Changes
          </BButton>
        </BCol>
      </BRow>

      <BAlert v-if="hasChanges" variant="warning" :model-value="true" class="mt-3 mb-0">
        <small>You have unsaved changes. Remember to save before switching prompts.</small>
      </BAlert>

      <!-- Template Description -->
      <BCard v-if="currentPrompt.description" class="mt-3" bg-variant="light">
        <template #header>
          <small class="fw-bold">Template Description</small>
        </template>
        <small class="text-muted">{{ currentPrompt.description }}</small>
      </BCard>

      <!-- Template Variables Help -->
      <BCard class="mt-3" bg-variant="light">
        <template #header>
          <small class="fw-bold">Available Template Variables</small>
        </template>
        <div class="small text-muted">
          <p class="mb-2">
            The following placeholders are replaced at generation time:
          </p>
          <ul class="mb-0 ps-3">
            <li v-if="selectedPrompt.includes('functional')">
              <code>{cluster_genes}</code> - Comma-separated list of gene symbols in the cluster
            </li>
            <li v-if="selectedPrompt.includes('functional')">
              <code>{gene_count}</code> - Number of genes in the cluster
            </li>
            <li v-if="selectedPrompt.includes('phenotype')">
              <code>{cluster_phenotypes}</code> - Comma-separated list of HPO terms
            </li>
            <li v-if="selectedPrompt.includes('phenotype')">
              <code>{phenotype_count}</code> - Number of phenotypes in the cluster
            </li>
            <li v-if="selectedPrompt.includes('judge')">
              <code>{summary_json}</code> - The generated summary to evaluate
            </li>
            <li v-if="selectedPrompt.includes('judge')">
              <code>{cluster_data}</code> - Original cluster data for comparison
            </li>
          </ul>
        </div>
      </BCard>
    </div>

    <BAlert v-else variant="info" :model-value="true">
      No prompt templates loaded. Click Refresh to load templates.
    </BAlert>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { PromptTemplates, PromptType } from '@/types/llm';

const props = defineProps<{
  prompts: PromptTemplates | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'save', type: PromptType, template: string, version: string): void;
}>();

const selectedPrompt = ref<PromptType>('functional_generation');
const editedTemplate = ref('');
const editedVersion = ref('');

const promptOptions = [
  { value: 'functional_generation', text: 'Functional - Generation' },
  { value: 'functional_judge', text: 'Functional - Judge' },
  { value: 'phenotype_generation', text: 'Phenotype - Generation' },
  { value: 'phenotype_judge', text: 'Phenotype - Judge' },
];

const promptLabels: Record<PromptType, string> = {
  functional_generation: 'Functional Cluster Generation',
  functional_judge: 'Functional Cluster Validation',
  phenotype_generation: 'Phenotype Cluster Generation',
  phenotype_judge: 'Phenotype Cluster Validation',
};

const currentPrompt = computed(() => props.prompts?.[selectedPrompt.value]);

watch(
  [selectedPrompt, () => props.prompts],
  () => {
    if (currentPrompt.value) {
      editedTemplate.value = currentPrompt.value.template_text;
      editedVersion.value = currentPrompt.value.version;
    }
  },
  { immediate: true }
);

const hasChanges = computed(() => {
  if (!currentPrompt.value) return false;
  return (
    editedTemplate.value !== currentPrompt.value.template_text ||
    editedVersion.value !== currentPrompt.value.version
  );
});

function resetPrompt() {
  if (currentPrompt.value) {
    editedTemplate.value = currentPrompt.value.template_text;
    editedVersion.value = currentPrompt.value.version;
  }
}

function savePrompt() {
  emit('save', selectedPrompt.value, editedTemplate.value, editedVersion.value);
}
</script>
