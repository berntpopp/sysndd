<template>
  <div class="step-phenotype-variation">
    <p class="text-muted mb-4">
      Add phenotype and variation ontology terms. These fields are optional but help with data classification.
    </p>

    <!-- Phenotypes -->
    <BFormGroup
      label="Phenotypes"
      label-for="phenotype-select"
      class="mb-4"
    >
      <template #label>
        <span class="fw-bold">Phenotypes</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <BFormSelect
        id="phenotype-select"
        v-model="selectedPhenotype"
        :options="phenotypeOptions"
        size="sm"
        aria-describedby="phenotype-help"
        @change="addPhenotype"
      >
        <template #first>
          <BFormSelectOption :value="null">
            Add a phenotype term...
          </BFormSelectOption>
        </template>
      </BFormSelect>
      <small id="phenotype-help" class="text-muted">
        Select HPO (Human Phenotype Ontology) terms that describe this phenotype
      </small>

      <!-- Selected phenotypes display -->
      <div v-if="formData.phenotypes.length > 0" class="mt-3">
        <div class="selected-items-label mb-2">
          <small class="text-muted">Selected phenotypes:</small>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <BBadge
            v-for="phenotype in formData.phenotypes"
            :key="phenotype"
            variant="primary"
            pill
            class="selected-item-badge"
          >
            {{ getPhenotypeLabel(phenotype) }}
            <BCloseButton
              class="ms-2"
              variant="white"
              aria-label="Remove"
              @click="removePhenotype(phenotype)"
            />
          </BBadge>
        </div>
      </div>
    </BFormGroup>

    <!-- Variation Ontology -->
    <BFormGroup
      label="Variation Ontology"
      label-for="variation-select"
      class="mb-3"
    >
      <template #label>
        <span class="fw-bold">Variation Ontology</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <BFormSelect
        id="variation-select"
        v-model="selectedVariation"
        :options="variationOptions"
        size="sm"
        aria-describedby="variation-help"
        @change="addVariation"
      >
        <template #first>
          <BFormSelectOption :value="null">
            Add a variation ontology term...
          </BFormSelectOption>
        </template>
      </BFormSelect>
      <small id="variation-help" class="text-muted">
        Select variation ontology terms that describe the type of genetic variation
      </small>

      <!-- Selected variations display -->
      <div v-if="formData.variationOntology.length > 0" class="mt-3">
        <div class="selected-items-label mb-2">
          <small class="text-muted">Selected variation terms:</small>
        </div>
        <div class="d-flex flex-wrap gap-2">
          <BBadge
            v-for="variation in formData.variationOntology"
            :key="variation"
            variant="info"
            pill
            class="selected-item-badge"
          >
            {{ getVariationLabel(variation) }}
            <BCloseButton
              class="ms-2"
              variant="white"
              aria-label="Remove"
              @click="removeVariation(variation)"
            />
          </BBadge>
        </div>
      </div>
    </BFormGroup>

    <!-- Info alert for optional step -->
    <BAlert
      variant="info"
      :model-value="true"
      class="mt-4"
    >
      <i class="bi bi-info-circle me-2" />
      This step is optional. You can proceed without selecting any terms.
    </BAlert>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, inject, nextTick, type PropType } from 'vue';
import {
  BFormGroup,
  BFormSelect,
  BFormSelectOption,
  BBadge,
  BCloseButton,
  BAlert,
} from 'bootstrap-vue-next';
import type {
  EntityFormData,
  SelectOption,
  SelectOptionGroup,
  GroupedSelectOptions,
} from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepPhenotypeVariation',

  components: {
    BFormGroup,
    BFormSelect,
    BFormSelectOption,
    BBadge,
    BCloseButton,
    BAlert,
  },

  props: {
    phenotypeOptions: {
      type: Array as PropType<GroupedSelectOptions>,
      default: () => [],
    },
    variationOptions: {
      type: Array as PropType<GroupedSelectOptions>,
      default: () => [],
    },
  },

  setup(props) {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;

    // Local selection state
    const selectedPhenotype = ref<string | null>(null);
    const selectedVariation = ref<string | null>(null);

    // Add phenotype to list
    const addPhenotype = async () => {
      if (selectedPhenotype.value && !formData.phenotypes.includes(selectedPhenotype.value)) {
        formData.phenotypes.push(selectedPhenotype.value);
      }
      // Reset to placeholder after Vue updates
      await nextTick();
      selectedPhenotype.value = null;
    };

    // Remove phenotype from list
    const removePhenotype = (value: string) => {
      const index = formData.phenotypes.indexOf(value);
      if (index > -1) {
        formData.phenotypes.splice(index, 1);
      }
    };

    // Get phenotype label by value (searches through grouped options)
    const getPhenotypeLabel = (value: string): string => {
      for (const group of props.phenotypeOptions) {
        // Check if it's a group with options
        if ('options' in group && Array.isArray(group.options)) {
          const option = group.options.find((opt) => opt.value === value);
          if (option) {
            return `${option.text}: ${group.label}`;
          }
        }
      }
      return value;
    };

    // Add variation to list
    const addVariation = async () => {
      if (selectedVariation.value && !formData.variationOntology.includes(selectedVariation.value)) {
        formData.variationOntology.push(selectedVariation.value);
      }
      // Reset to placeholder after Vue updates
      await nextTick();
      selectedVariation.value = null;
    };

    // Remove variation from list
    const removeVariation = (value: string) => {
      const index = formData.variationOntology.indexOf(value);
      if (index > -1) {
        formData.variationOntology.splice(index, 1);
      }
    };

    // Get variation label by value (searches through grouped options)
    const getVariationLabel = (value: string): string => {
      for (const group of props.variationOptions) {
        // Check if it's a group with options
        if ('options' in group && Array.isArray(group.options)) {
          const option = group.options.find((opt) => opt.value === value);
          if (option) {
            return `${option.text}: ${group.label}`;
          }
        }
      }
      return value;
    };

    return {
      formData,
      selectedPhenotype,
      selectedVariation,
      addPhenotype,
      removePhenotype,
      getPhenotypeLabel,
      addVariation,
      removeVariation,
      getVariationLabel,
    };
  },
});
</script>

<style scoped>
.step-phenotype-variation {
  max-width: 700px;
}

.selected-item-badge {
  display: inline-flex;
  align-items: center;
  font-size: 0.875rem;
  padding: 0.5rem 0.75rem;
}

.selected-item-badge :deep(.btn-close) {
  font-size: 0.65rem;
  padding: 0;
  margin-left: 0.5rem;
  opacity: 0.8;
}

.selected-item-badge :deep(.btn-close):hover {
  opacity: 1;
}
</style>
