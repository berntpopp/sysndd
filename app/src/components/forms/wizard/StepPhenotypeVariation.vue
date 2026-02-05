<template>
  <div class="step-phenotype-variation">
    <p class="text-muted mb-4">
      Add phenotype and variation ontology terms. These fields are optional but help with data
      classification.
    </p>

    <!-- Phenotypes -->
    <BFormGroup label="Phenotypes" label-for="phenotype-select" class="mb-4">
      <template #label>
        <span class="fw-bold">Phenotypes</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <TreeMultiSelect
        v-if="phenotypeOptions && phenotypeOptions.length > 0"
        id="phenotype-select"
        v-model="formData.phenotypes"
        :options="phenotypeOptions"
        placeholder="Select phenotypes..."
        search-placeholder="Search phenotypes (name or HP:ID)..."
      />
      <BSpinner v-else-if="phenotypeOptions === null" small label="Loading phenotypes..." />
      <small id="phenotype-help" class="text-muted">
        Select HPO (Human Phenotype Ontology) terms that describe this phenotype
      </small>
    </BFormGroup>

    <!-- Variation Ontology -->
    <BFormGroup label="Variation Ontology" label-for="variation-select" class="mb-3">
      <template #label>
        <span class="fw-bold">Variation Ontology</span>
        <span class="text-muted fw-normal ms-1">(optional)</span>
      </template>
      <TreeMultiSelect
        v-if="variationOptions && variationOptions.length > 0"
        id="variation-select"
        v-model="formData.variationOntology"
        :options="variationOptions"
        placeholder="Select variation types..."
        search-placeholder="Search variation types..."
      />
      <BSpinner v-else-if="variationOptions === null" small label="Loading variation types..." />
      <small id="variation-help" class="text-muted">
        Select variation ontology terms that describe the type of genetic variation
      </small>
    </BFormGroup>

    <!-- Info alert for optional step -->
    <BAlert variant="info" :model-value="true" class="mt-4">
      <i class="bi bi-info-circle me-2" />
      This step is optional. You can proceed without selecting any terms.
    </BAlert>
  </div>
</template>

<script lang="ts">
import { defineComponent, inject, type PropType } from 'vue';
import { BFormGroup, BAlert, BSpinner } from 'bootstrap-vue-next';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';
import type { EntityFormData } from '@/composables/useEntityForm';
import type { TreeNode } from '@/composables';

export default defineComponent({
  name: 'StepPhenotypeVariation',

  components: {
    BFormGroup,
    BAlert,
    BSpinner,
    TreeMultiSelect,
  },

  props: {
    phenotypeOptions: {
      type: Array as PropType<TreeNode[] | null>,
      default: null,
    },
    variationOptions: {
      type: Array as PropType<TreeNode[] | null>,
      default: null,
    },
  },

  setup() {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;

    return {
      formData,
    };
  },
});
</script>

<style scoped>
.step-phenotype-variation {
  max-width: 700px;
}
</style>
