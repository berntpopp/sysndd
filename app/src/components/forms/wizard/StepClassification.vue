<template>
  <div class="step-classification step-classification__grid">
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
    </BFormGroup>

    <!-- Comment -->
    <BFormGroup
      label="Comment"
      label-for="comment-textarea"
      class="mb-3 step-classification__comment"
    >
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
import { BFormGroup, BFormSelect, BFormSelectOption, BFormTextarea } from 'bootstrap-vue-next';
import type { EntityFormData, SelectOption } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepClassification',

  components: {
    BFormGroup,
    BFormSelect,
    BFormSelectOption,
    BFormTextarea,
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
  max-width: none;
  align-items: start;
  text-align: left;
}

.step-classification :deep(.form-label),
.step-classification :deep(legend) {
  margin-bottom: 0.4rem;
  color: #172033;
  font-size: 0.86rem;
  font-weight: 750;
  line-height: 1.2;
  text-align: left;
}

.step-classification :deep(small.text-muted) {
  display: block;
  margin-top: 0.3rem;
  color: #64748b !important;
  font-size: 0.76rem;
  text-align: left;
}

.step-classification__comment {
  min-width: 0;
}
</style>
