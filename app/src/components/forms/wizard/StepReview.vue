<template>
  <div class="step-review">
    <p class="text-muted mb-4">
      Review all information before submitting. Click on section headers to edit.
    </p>

    <!-- Core Entity Summary -->
    <BCard
      class="mb-3 review-card"
      no-body
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <span class="fw-bold">
            <i class="bi bi-1-circle me-2" />
            Core Entity
          </span>
          <BButton
            variant="link"
            size="sm"
            class="p-0 text-primary"
            @click="$emit('edit-step', 0)"
          >
            <i class="bi bi-pencil me-1" />
            Edit
          </BButton>
        </div>
      </template>
      <BCardBody>
        <BRow>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Gene</div>
            <div class="review-value">
              {{ formData.geneDisplay || formData.geneId || '—' }}
            </div>
          </BCol>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Disease</div>
            <div class="review-value">
              {{ formData.diseaseDisplay || formData.diseaseId || '—' }}
            </div>
          </BCol>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Inheritance</div>
            <div class="review-value">
              {{ getInheritanceLabel(formData.inheritanceId) || '—' }}
            </div>
          </BCol>
          <BCol sm="6" class="mb-2">
            <div class="review-label">NDD Phenotype</div>
            <div class="review-value">
              <BBadge :variant="formData.nddPhenotype ? 'success' : 'secondary'">
                {{ formData.nddPhenotype === true ? 'Yes' : formData.nddPhenotype === false ? 'No' : '—' }}
              </BBadge>
            </div>
          </BCol>
        </BRow>
      </BCardBody>
    </BCard>

    <!-- Evidence Summary -->
    <BCard
      class="mb-3 review-card"
      no-body
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <span class="fw-bold">
            <i class="bi bi-2-circle me-2" />
            Evidence
          </span>
          <BButton
            variant="link"
            size="sm"
            class="p-0 text-primary"
            @click="$emit('edit-step', 1)"
          >
            <i class="bi bi-pencil me-1" />
            Edit
          </BButton>
        </div>
      </template>
      <BCardBody>
        <div class="mb-3">
          <div class="review-label">Publications</div>
          <div class="review-value">
            <template v-if="formData.publications.length > 0">
              <BBadge
                v-for="pmid in formData.publications"
                :key="pmid"
                variant="secondary"
                class="me-1 mb-1"
              >
                <BLink
                  :href="getPubMedUrl(pmid)"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-light text-decoration-none"
                >
                  {{ pmid }}
                </BLink>
              </BBadge>
            </template>
            <span v-else class="text-muted">—</span>
          </div>
        </div>
        <div v-if="formData.genereviews.length > 0" class="mb-3">
          <div class="review-label">GeneReviews</div>
          <div class="review-value">
            <BBadge
              v-for="pmid in formData.genereviews"
              :key="pmid"
              variant="info"
              class="me-1 mb-1"
            >
              <BLink
                :href="getPubMedUrl(pmid)"
                target="_blank"
                rel="noopener noreferrer"
                class="text-light text-decoration-none"
              >
                {{ pmid }}
              </BLink>
            </BBadge>
          </div>
        </div>
        <div>
          <div class="review-label">Synopsis</div>
          <div class="review-value synopsis-text">
            {{ formData.synopsis || '—' }}
          </div>
        </div>
      </BCardBody>
    </BCard>

    <!-- Phenotype & Variation Summary -->
    <BCard
      class="mb-3 review-card"
      no-body
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <span class="fw-bold">
            <i class="bi bi-3-circle me-2" />
            Phenotype & Variation
          </span>
          <BButton
            variant="link"
            size="sm"
            class="p-0 text-primary"
            @click="$emit('edit-step', 2)"
          >
            <i class="bi bi-pencil me-1" />
            Edit
          </BButton>
        </div>
      </template>
      <BCardBody>
        <BRow>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Phenotypes</div>
            <div class="review-value">
              <template v-if="formData.phenotypes.length > 0">
                <BBadge
                  v-for="p in formData.phenotypes"
                  :key="p"
                  variant="primary"
                  pill
                  class="me-1 mb-1"
                >
                  {{ getPhenotypeLabel(p) }}
                </BBadge>
              </template>
              <span v-else class="text-muted fst-italic">None selected</span>
            </div>
          </BCol>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Variation Ontology</div>
            <div class="review-value">
              <template v-if="formData.variationOntology.length > 0">
                <BBadge
                  v-for="v in formData.variationOntology"
                  :key="v"
                  variant="info"
                  pill
                  class="me-1 mb-1"
                >
                  {{ getVariationLabel(v) }}
                </BBadge>
              </template>
              <span v-else class="text-muted fst-italic">None selected</span>
            </div>
          </BCol>
        </BRow>
      </BCardBody>
    </BCard>

    <!-- Classification Summary -->
    <BCard
      class="mb-4 review-card"
      no-body
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <span class="fw-bold">
            <i class="bi bi-4-circle me-2" />
            Classification
          </span>
          <BButton
            variant="link"
            size="sm"
            class="p-0 text-primary"
            @click="$emit('edit-step', 3)"
          >
            <i class="bi bi-pencil me-1" />
            Edit
          </BButton>
        </div>
      </template>
      <BCardBody>
        <BRow>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Status</div>
            <div class="review-value">
              <BBadge variant="dark">
                {{ getStatusLabel(formData.statusId) || '—' }}
              </BBadge>
            </div>
          </BCol>
          <BCol sm="6" class="mb-2">
            <div class="review-label">Comment</div>
            <div class="review-value">
              {{ formData.comment || '—' }}
            </div>
          </BCol>
        </BRow>
      </BCardBody>
    </BCard>

    <!-- Direct Approval Warning -->
    <BCard
      v-if="directApproval"
      border-variant="warning"
      class="mb-3"
    >
      <div class="d-flex align-items-start">
        <i class="bi bi-exclamation-triangle text-warning me-3 fs-4" />
        <div>
          <div class="fw-bold text-warning">Direct Approval Enabled</div>
          <small class="text-muted">
            This entity will be approved immediately without double review.
            This should only be used by experienced curators.
          </small>
        </div>
      </div>
    </BCard>

    <!-- Validation Summary -->
    <BAlert
      v-if="!isFormValid"
      variant="danger"
      :model-value="true"
    >
      <i class="bi bi-exclamation-circle me-2" />
      <strong>Validation errors:</strong> Please fix the errors above before submitting.
    </BAlert>

    <BAlert
      v-else
      variant="success"
      :model-value="true"
    >
      <i class="bi bi-check-circle me-2" />
      <strong>Ready to submit!</strong> All required fields are complete.
    </BAlert>
  </div>
</template>

<script lang="ts">
import { defineComponent, inject, type PropType } from 'vue';
import {
  BCard,
  BCardBody,
  BRow,
  BCol,
  BBadge,
  BButton,
  BLink,
  BAlert,
} from 'bootstrap-vue-next';
import type {
  EntityFormData,
  SelectOption,
  GroupedSelectOptions,
} from '@/composables/useEntityForm';

export default defineComponent({
  name: 'StepReview',

  components: {
    BCard,
    BCardBody,
    BRow,
    BCol,
    BBadge,
    BButton,
    BLink,
    BAlert,
  },

  props: {
    inheritanceOptions: {
      type: Array as PropType<SelectOption[]>,
      default: () => [],
    },
    statusOptions: {
      type: Array as PropType<SelectOption[]>,
      default: () => [],
    },
    phenotypeOptions: {
      type: Array as PropType<GroupedSelectOptions>,
      default: () => [],
    },
    variationOptions: {
      type: Array as PropType<GroupedSelectOptions>,
      default: () => [],
    },
  },

  emits: ['edit-step'],

  setup(props) {
    // Inject form state from parent
    const formData = inject<EntityFormData>('formData')!;
    const isFormValid = inject<boolean>('isFormValid', true);
    const directApproval = inject<boolean>('directApproval', false);

    // Helper to get label from flat options
    const getOptionLabel = (options: SelectOption[], value: string | number | null): string => {
      if (!value) return '';
      const option = options.find((opt) => opt.value === value);
      return option?.text || String(value);
    };

    // Helper to get label from grouped options
    const getGroupedOptionLabel = (groupedOptions: GroupedSelectOptions, value: string): string => {
      for (const group of groupedOptions) {
        if ('options' in group && Array.isArray(group.options)) {
          const option = group.options.find((opt) => opt.value === value);
          if (option) {
            return `${option.text}: ${group.label}`;
          }
        }
      }
      return value;
    };

    const getInheritanceLabel = (value: string | null) =>
      getOptionLabel(props.inheritanceOptions, value);

    const getStatusLabel = (value: string | null) =>
      getOptionLabel(props.statusOptions, value);

    const getPhenotypeLabel = (value: string) =>
      getGroupedOptionLabel(props.phenotypeOptions, value);

    const getVariationLabel = (value: string) =>
      getGroupedOptionLabel(props.variationOptions, value);

    // PubMed URL helper
    const getPubMedUrl = (pmid: string): string => {
      const id = pmid.replace('PMID:', '').trim();
      return `https://pubmed.ncbi.nlm.nih.gov/${id}`;
    };

    return {
      formData,
      isFormValid,
      directApproval,
      getInheritanceLabel,
      getStatusLabel,
      getPhenotypeLabel,
      getVariationLabel,
      getPubMedUrl,
    };
  },
});
</script>

<style scoped>
.step-review {
  max-width: 800px;
}

.review-card {
  border-radius: 0.5rem;
}

.review-card :deep(.card-header) {
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
  padding: 0.75rem 1rem;
}

.review-label {
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #6c757d;
  margin-bottom: 0.25rem;
}

.review-value {
  font-size: 0.9375rem;
}

.synopsis-text {
  white-space: pre-wrap;
  background-color: #f8f9fa;
  padding: 0.75rem;
  border-radius: 0.375rem;
  max-height: 150px;
  overflow-y: auto;
}
</style>
