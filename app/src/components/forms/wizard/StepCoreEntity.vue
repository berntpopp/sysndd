<template>
  <div class="step-core-entity">
    <p class="text-muted mb-4">
      Enter the core information for this gene-disease entity. All fields are required.
    </p>

    <!-- Gene Selection -->
    <BFormGroup
      label="Gene"
      label-for="gene-select"
      :state="getFieldState('geneId')"
      :invalid-feedback="getFieldError('geneId')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Gene <span class="text-danger">*</span></span>
      </template>
      <AutocompleteInput
        v-model="formData.geneId"
        v-model:display-value="formData.geneDisplay"
        :results="geneResults"
        :loading="geneLoading"
        label="Gene"
        input-id="gene-select"
        help-id="gene-help"
        placeholder="Search gene by symbol (e.g., MECP2)"
        item-key="id"
        item-label="symbol"
        item-secondary="id"
        item-description="name"
        :state="getFieldState('geneId')"
        :required="true"
        @search="searchGene"
        @blur="touchField('geneId')"
      />
      <small id="gene-help" class="text-muted">
        Select HGNC gene symbol associated with this disease
      </small>
    </BFormGroup>

    <!-- Disease Selection -->
    <BFormGroup
      label="Disease"
      label-for="disease-select"
      :state="getFieldState('diseaseId')"
      :invalid-feedback="getFieldError('diseaseId')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Disease <span class="text-danger">*</span></span>
      </template>
      <AutocompleteInput
        v-model="formData.diseaseId"
        v-model:display-value="formData.diseaseDisplay"
        :results="diseaseResults"
        :loading="diseaseLoading"
        label="Disease"
        input-id="disease-select"
        help-id="disease-help"
        placeholder="Search disease (e.g., Rett syndrome)"
        item-key="id"
        item-label="disease_ontology_name"
        item-secondary="id"
        :state="getFieldState('diseaseId')"
        :required="true"
        @search="searchDisease"
        @blur="touchField('diseaseId')"
      />
      <small id="disease-help" class="text-muted">
        Select OMIM or Mondo disease identifier
      </small>
    </BFormGroup>

    <!-- Inheritance Selection -->
    <BFormGroup
      label="Inheritance"
      label-for="inheritance-select"
      :state="getFieldState('inheritanceId')"
      :invalid-feedback="getFieldError('inheritanceId')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Inheritance <span class="text-danger">*</span></span>
      </template>
      <BFormSelect
        id="inheritance-select"
        v-model="formData.inheritanceId"
        :options="inheritanceOptions"
        :state="getFieldState('inheritanceId')"
        size="sm"
        required
        aria-describedby="inheritance-help"
        @blur="touchField('inheritanceId')"
      >
        <template #first>
          <BFormSelectOption :value="null">
            Select inheritance pattern...
          </BFormSelectOption>
        </template>
      </BFormSelect>
      <small id="inheritance-help" class="text-muted">
        Select the mode of inheritance for this gene-disease relationship
      </small>
    </BFormGroup>

    <!-- NDD Phenotype Selection -->
    <BFormGroup
      label="NDD Phenotype"
      :state="getFieldState('nddPhenotype')"
      :invalid-feedback="getFieldError('nddPhenotype')"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">NDD Phenotype <span class="text-danger">*</span></span>
      </template>
      <div class="mt-2">
        <BFormRadioGroup
          v-model="formData.nddPhenotype"
          :state="getFieldState('nddPhenotype')"
          stacked
          @change="touchField('nddPhenotype')"
        >
          <BFormRadio :value="true" class="mb-2">
            <span class="fw-medium">Yes</span>
            <small class="text-muted d-block">
              This is a neurodevelopmental disorder phenotype
            </small>
          </BFormRadio>
          <BFormRadio :value="false">
            <span class="fw-medium">No</span>
            <small class="text-muted d-block">
              This is not a neurodevelopmental phenotype
            </small>
          </BFormRadio>
        </BFormRadioGroup>
      </div>
    </BFormGroup>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, inject } from 'vue';
import {
  BFormGroup,
  BFormSelect,
  BFormSelectOption,
  BFormRadioGroup,
  BFormRadio,
} from 'bootstrap-vue-next';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';
import type { EntityFormData, SelectOption } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepCoreEntity',

  components: {
    BFormGroup,
    BFormSelect,
    BFormSelectOption,
    BFormRadioGroup,
    BFormRadio,
    AutocompleteInput,
  },

  props: {
    inheritanceOptions: {
      type: Array as () => SelectOption[],
      default: () => [],
    },
  },

  emits: ['search-gene', 'search-disease'],

  setup(props, { emit }) {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;
    const getFieldError = inject<(field: string) => string | null>('getFieldError')!;
    const getFieldState = inject<(field: string) => boolean | null>('getFieldState')!;
    const touchField = inject<(field: string) => void>('touchField')!;

    // Local search state
    const geneResults = ref<Record<string, unknown>[]>([]);
    const geneLoading = ref(false);
    const diseaseResults = ref<Record<string, unknown>[]>([]);
    const diseaseLoading = ref(false);

    // Search handlers
    const searchGene = async (query: string) => {
      geneLoading.value = true;
      emit('search-gene', query, (results: Record<string, unknown>[]) => {
        geneResults.value = results;
        geneLoading.value = false;
      });
    };

    const searchDisease = async (query: string) => {
      diseaseLoading.value = true;
      emit('search-disease', query, (results: Record<string, unknown>[]) => {
        diseaseResults.value = results;
        diseaseLoading.value = false;
      });
    };

    return {
      formData,
      getFieldError,
      getFieldState,
      touchField,
      geneResults,
      geneLoading,
      diseaseResults,
      diseaseLoading,
      searchGene,
      searchDisease,
    };
  },
});
</script>

<style scoped>
.step-core-entity {
  max-width: 600px;
}
</style>
