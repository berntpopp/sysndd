<!-- src/components/forms/BatchCriteriaForm.vue -->
<template>
  <BCard
    header="Create Re-Review Batch"
    header-class="bg-primary text-white"
    class="mb-3"
  >
    <BForm @submit.prevent="onSubmit">
      <!-- Batch Name (optional) -->
      <BFormGroup
        label="Batch Name (optional)"
        label-for="batch-name"
        class="mb-3"
      >
        <BFormInput
          id="batch-name"
          v-model="formData.batch_name"
          placeholder="Auto-generated if empty (e.g., Batch 2026-01-26 14:30)"
          :disabled="isLoading"
        />
        <BFormText>Leave empty for auto-generated name based on creation time</BFormText>
      </BFormGroup>

      <!-- Date Range -->
      <BFormGroup
        label="Review Date Range"
        label-for="date-start"
        class="mb-3"
      >
        <div class="d-flex gap-2">
          <BFormInput
            id="date-start"
            v-model="formData.date_range.start"
            type="date"
            placeholder="Start date"
            :disabled="isLoading"
            aria-label="Start date for review date range"
          />
          <span class="align-self-center">to</span>
          <BFormInput
            id="date-end"
            v-model="formData.date_range.end"
            type="date"
            placeholder="End date"
            :disabled="isLoading"
            aria-label="End date for review date range"
          />
        </div>
        <BFormText>Include entities last reviewed between these dates</BFormText>
      </BFormGroup>

      <!-- Gene List (multi-select) -->
      <BFormGroup
        label="Genes (optional)"
        label-for="gene-select"
        class="mb-3"
      >
        <BFormSelect
          id="gene-select"
          v-model="formData.gene_list"
          :options="geneOptions"
          multiple
          :select-size="6"
          :disabled="isLoading"
          aria-label="Select genes to include in batch"
        >
          <template #first>
            <option
              :value="null"
              disabled
            >
              -- Select genes (hold Ctrl/Cmd for multiple) --
            </option>
          </template>
        </BFormSelect>
        <BFormText>
          {{ formData.gene_list.length }} gene(s) selected.
          Hold Ctrl/Cmd to select multiple genes.
        </BFormText>
      </BFormGroup>

      <!-- Status Filter -->
      <BFormGroup
        label="Status Category (optional)"
        label-for="status-filter"
        class="mb-3"
      >
        <BFormSelect
          id="status-filter"
          v-model="formData.status_filter"
          :options="statusOptions"
          :disabled="isLoading"
          aria-label="Filter by entity status category"
        >
          <template #first>
            <option :value="null">
              -- Any status --
            </option>
          </template>
        </BFormSelect>
      </BFormGroup>

      <!-- Batch Size -->
      <BFormGroup
        label="Batch Size"
        label-for="batch-size"
        class="mb-3"
      >
        <BFormInput
          id="batch-size"
          v-model.number="formData.batch_size"
          type="number"
          min="1"
          max="100"
          :disabled="isLoading"
          aria-label="Maximum number of entities in this batch"
        />
        <BFormText>Maximum entities to include (default: 20, max: 100)</BFormText>
      </BFormGroup>

      <!-- User Assignment -->
      <BFormGroup
        label="Assign to User (optional)"
        label-for="user-select"
        class="mb-3"
      >
        <BFormSelect
          id="user-select"
          v-model="formData.assigned_user_id"
          :options="userOptions"
          :disabled="isLoading"
          aria-label="Select user to assign batch to"
        >
          <template #first>
            <option :value="null">
              -- Assign later --
            </option>
          </template>
        </BFormSelect>
        <BFormText>Leave unassigned to assign after creation</BFormText>
      </BFormGroup>

      <!-- Validation message -->
      <BAlert
        v-if="!isFormValid"
        variant="info"
        show
        class="mb-3"
      >
        <i class="bi bi-info-circle me-1" />
        Please select at least one criterion (date range, genes, or status).
      </BAlert>

      <!-- Actions -->
      <div class="d-flex gap-2">
        <BButton
          variant="outline-primary"
          :disabled="isLoading || isPreviewLoading || !isFormValid"
          @click="onPreview"
        >
          <BSpinner
            v-if="isPreviewLoading"
            small
            class="me-1"
          />
          <i
            v-else
            class="bi bi-eye me-1"
          />
          Preview Matching Entities
        </BButton>
        <BButton
          type="submit"
          variant="primary"
          :disabled="isLoading || !isFormValid"
        >
          <BSpinner
            v-if="isLoading"
            small
            class="me-1"
          />
          <i
            v-else
            class="bi bi-plus-circle me-1"
          />
          Create Batch
        </BButton>
        <BButton
          variant="outline-secondary"
          :disabled="isLoading"
          @click="onReset"
        >
          <i class="bi bi-x-circle me-1" />
          Reset
        </BButton>
      </div>
    </BForm>

    <!-- Preview Modal -->
    <BModal
      v-model="showPreviewModal"
      title="Preview: Matching Entities"
      size="lg"
      ok-only
      ok-title="Close"
    >
      <div v-if="previewEntities.length > 0">
        <BAlert
          variant="success"
          show
        >
          <strong>{{ previewEntities.length }}</strong> entities match your criteria
          (limited to batch size of {{ formData.batch_size }}).
        </BAlert>
        <BTable
          :items="previewEntities"
          :fields="previewFields"
          small
          striped
          hover
          responsive
        />
      </div>
      <BAlert
        v-else
        variant="warning"
        show
      >
        <i class="bi bi-exclamation-triangle me-1" />
        No entities match the selected criteria. Try broadening your selection.
      </BAlert>
    </BModal>
  </BCard>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useBatchForm } from '@/composables/useBatchForm';

const emit = defineEmits<{
  (e: 'batch-created'): void;
}>();

const {
  formData,
  isLoading,
  isPreviewLoading,
  isFormValid,
  geneOptions,
  statusOptions,
  userOptions,
  previewEntities,
  previewFields,
  showPreviewModal,
  loadOptions,
  handlePreview,
  handleSubmit,
  resetForm,
} = useBatchForm();

onMounted(() => {
  loadOptions();
});

const onPreview = () => {
  handlePreview();
};

const onSubmit = async () => {
  const success = await handleSubmit();
  if (success) {
    emit('batch-created');
  }
};

const onReset = () => {
  resetForm();
};
</script>

<style scoped>
/* Component-specific styles if needed */
</style>
