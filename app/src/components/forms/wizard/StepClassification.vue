<template>
  <div class="step-classification">
    <p class="text-muted mb-4">
      Classify this gene-disease entity based on available evidence. Status is required.
    </p>

    <!-- Status Selection -->
    <BFormGroup
      label="Status"
      label-for="status-select"
      :state="getFieldState('statusId')"
      :invalid-feedback="getFieldError('statusId')"
      class="mb-4"
    >
      <template #label>
        <span class="fw-bold">Status <span class="text-danger">*</span></span>
      </template>
      <BFormSelect
        id="status-select"
        v-model="formData.statusId"
        :options="statusOptions"
        :state="getFieldState('statusId')"
        size="sm"
        required
        aria-describedby="status-help"
        @blur="touchField('statusId')"
      >
        <template #first>
          <BFormSelectOption :value="null"> Select classification status... </BFormSelectOption>
        </template>
      </BFormSelect>
      <small id="status-help" class="text-muted d-block mt-1">
        Evidence strength classification for this gene-disease relationship
      </small>

      <!-- Status explanation -->
      <BAlert variant="light" :model-value="true" class="mt-3 status-guide">
        <div class="fw-bold mb-2">Classification Guide:</div>
        <ul class="mb-0 ps-3">
          <li><strong>Definitive:</strong> 3+ unrelated cases with consistent phenotype</li>
          <li><strong>Strong:</strong> 2-3 unrelated cases or functional evidence</li>
          <li><strong>Moderate:</strong> 2 cases from single report or limited evidence</li>
          <li><strong>Limited:</strong> 1 case or circumstantial evidence</li>
          <li><strong>Refuted:</strong> Evidence does not support association</li>
        </ul>
      </BAlert>
    </BFormGroup>

    <!-- Comment -->
    <BFormGroup label="Comment" label-for="comment-textarea" class="mb-3">
      <template #label>
        <span class="fw-bold">Comment</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <BFormTextarea
        id="comment-textarea"
        v-model="formData.comment"
        rows="3"
        size="sm"
        placeholder="Additional comments relevant for the reviewer..."
        aria-describedby="comment-help"
      />
      <small id="comment-help" class="text-muted">
        Add any notes or context that may be helpful for the review process
      </small>
    </BFormGroup>
  </div>
</template>

<script lang="ts">
import { defineComponent, inject, type PropType } from 'vue';
import {
  BFormGroup,
  BFormSelect,
  BFormSelectOption,
  BFormTextarea,
  BAlert,
} from 'bootstrap-vue-next';
import type { EntityFormData, SelectOption } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepClassification',

  components: {
    BFormGroup,
    BFormSelect,
    BFormSelectOption,
    BFormTextarea,
    BAlert,
  },

  props: {
    statusOptions: {
      type: Array as PropType<SelectOption[]>,
      default: () => [],
    },
  },

  setup() {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;
    const getFieldError = inject<(field: string) => string | null>('getFieldError')!;
    const getFieldState = inject<(field: string) => boolean | null>('getFieldState')!;
    const touchField = inject<(field: string) => void>('touchField')!;

    return {
      formData,
      getFieldError,
      getFieldState,
      touchField,
    };
  },
});
</script>

<style scoped>
.step-classification {
  max-width: 700px;
}

.status-guide {
  font-size: 0.875rem;
  background-color: #f8f9fa;
  border: 1px solid #e9ecef;
}

.status-guide ul li {
  margin-bottom: 0.25rem;
}

.status-guide ul li:last-child {
  margin-bottom: 0;
}
</style>
