<template>
  <div class="step-review">
    <section class="review-entity-strip" aria-label="Entity summary">
      <div class="review-entity-strip__main">
        <div class="review-entity-strip__gene">
          {{ formData.geneDisplay || formData.geneId || 'Gene not selected' }}
        </div>
        <div class="review-entity-strip__disease">
          {{ formData.diseaseDisplay || formData.diseaseId || 'Disease not selected' }}
        </div>
      </div>
      <div class="review-entity-strip__meta">
        <span class="review-chip review-chip--inheritance">
          {{ getInheritanceLabel(formData.inheritanceId) || 'Inheritance missing' }}
        </span>
        <span class="review-chip review-chip--ndd">
          NDD
          {{
            formData.nddPhenotype === true ? 'Yes' : formData.nddPhenotype === false ? 'No' : '—'
          }}
        </span>
        <span class="review-chip review-chip--status">
          {{ getStatusLabel(formData.statusId) || 'Status missing' }}
        </span>
      </div>
      <BButton
        variant="outline-primary"
        size="sm"
        class="review-edit"
        @click="$emit('edit-step', 0)"
      >
        <i class="bi bi-pencil" aria-hidden="true" />
        Edit identity
      </BButton>
    </section>

    <section class="review-grid" aria-label="Evidence and classification review">
      <article class="review-panel review-panel--wide">
        <header class="review-panel__header">
          <h3>Synopsis</h3>
          <BButton variant="link" size="sm" @click="$emit('edit-step', 1)">Edit</BButton>
        </header>
        <p class="synopsis-text">{{ formData.synopsis || '—' }}</p>
      </article>

      <article class="review-panel">
        <header class="review-panel__header">
          <h3>Literature</h3>
          <BButton variant="link" size="sm" @click="$emit('edit-step', 1)">Edit</BButton>
        </header>
        <div class="review-value">
          <BBadge
            v-for="pmid in formData.publications"
            :key="pmid"
            variant="secondary"
            class="review-chip review-chip--publication"
          >
            <BLink
              :href="getPubMedUrl(pmid)"
              target="_blank"
              rel="noopener noreferrer"
              class="review-chip__link"
            >
              {{ pmid }}
            </BLink>
          </BBadge>
          <BBadge
            v-for="pmid in formData.genereviews"
            :key="pmid"
            variant="info"
            class="review-chip review-chip--genereview"
          >
            <BLink
              :href="getPubMedUrl(pmid)"
              target="_blank"
              rel="noopener noreferrer"
              class="review-chip__link"
            >
              GeneReviews {{ pmid.replace('PMID:', '') }}
            </BLink>
          </BBadge>
          <span
            v-if="formData.publications.length === 0 && formData.genereviews.length === 0"
            class="review-empty"
            >—</span
          >
        </div>
      </article>

      <article class="review-panel">
        <header class="review-panel__header">
          <h3>Phenotype & Variation</h3>
          <BButton variant="link" size="sm" @click="$emit('edit-step', 2)">Edit</BButton>
        </header>
        <div class="review-value">
          <BBadge
            v-for="p in formData.phenotypes"
            :key="p"
            variant="primary"
            class="review-chip review-chip--phenotype"
          >
            {{ getPhenotypeLabel(p) }}
          </BBadge>
          <BBadge
            v-for="v in formData.variationOntology"
            :key="v"
            variant="info"
            class="review-chip review-chip--variation"
          >
            {{ getVariationLabel(v) }}
          </BBadge>
          <span
            v-if="formData.phenotypes.length === 0 && formData.variationOntology.length === 0"
            class="review-empty"
          >
            None selected
          </span>
        </div>
      </article>

      <article class="review-panel review-panel--wide">
        <header class="review-panel__header">
          <h3>Curator Comment</h3>
          <BButton variant="link" size="sm" @click="$emit('edit-step', 3)">Edit</BButton>
        </header>
        <p class="review-comment">{{ formData.comment || '—' }}</p>
      </article>
    </section>

    <!-- Direct Approval Warning -->
    <section v-if="directApproval" class="review-warning">
      <i class="bi bi-exclamation-triangle" />
      <div>
        <div class="review-warning__title">Direct Approval Enabled</div>
        <small>
          This entity will be approved immediately without double review. This should only be used
          by experienced curators.
        </small>
      </div>
    </section>

    <!-- Validation Summary -->
    <BAlert v-if="!isFormValid" variant="danger" :model-value="true">
      <i class="bi bi-exclamation-circle me-2" />
      <strong>Validation errors:</strong> Please fix the errors above before submitting.
    </BAlert>

    <BAlert v-else variant="success" :model-value="true">
      <i class="bi bi-check-circle me-2" />
      <strong>Ready to submit!</strong> All required fields are complete.
    </BAlert>
  </div>
</template>

<script lang="ts">
import { defineComponent, inject, type PropType } from 'vue';
import { BBadge, BButton, BLink, BAlert } from 'bootstrap-vue-next';
import type { EntityFormData, SelectOption } from '@/composables/useEntityForm';
import type { TreeNode } from '@/composables';

export default defineComponent({
  name: 'StepReview',

  components: {
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
      type: Array as PropType<TreeNode[]>,
      default: () => [],
    },
    variationOptions: {
      type: Array as PropType<TreeNode[]>,
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

    // Helper to get label from tree options (for TreeMultiSelect)
    const getTreeOptionLabel = (treeOptions: TreeNode[], value: string): string => {
      // Search through tree structure to find the label by ID
      const searchTree = (nodes: TreeNode[]): string | null => {
        for (const node of nodes) {
          if (node.id === value) {
            return node.label;
          }
          if (node.children) {
            const found = searchTree(node.children);
            if (found) return found;
          }
        }
        return null;
      };

      return searchTree(treeOptions) || value;
    };

    const getInheritanceLabel = (value: string | null) =>
      getOptionLabel(props.inheritanceOptions, value);

    const getStatusLabel = (value: string | null) => getOptionLabel(props.statusOptions, value);

    const getPhenotypeLabel = (value: string) => getTreeOptionLabel(props.phenotypeOptions, value);

    const getVariationLabel = (value: string) => getTreeOptionLabel(props.variationOptions, value);

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
  display: grid;
  gap: 0.85rem;
  max-width: none;
  color: #172033;
  text-align: left;
}

.review-entity-strip,
.review-panel,
.review-warning {
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
}

.review-entity-strip {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.75rem;
  align-items: center;
  padding: 0.75rem 0.85rem;
  background: #f8fafc;
}

.review-entity-strip__main {
  min-width: 0;
}

.review-entity-strip__gene {
  color: #172033;
  font-size: 1rem;
  font-weight: 800;
  line-height: 1.2;
}

.review-entity-strip__disease {
  overflow: hidden;
  color: #475569;
  font-size: 0.84rem;
  font-weight: 650;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.review-entity-strip__meta,
.review-value {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  min-width: 0;
}

.review-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.review-panel {
  min-width: 0;
  padding: 0.75rem;
  text-align: left;
}

.review-panel--wide {
  grid-column: 1 / -1;
}

.review-panel__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem;
  margin-bottom: 0.45rem;
}

.review-panel__header h3 {
  margin: 0;
  color: #172033;
  font-size: 0.86rem;
  font-weight: 800;
  line-height: 1.2;
}

.synopsis-text,
.review-comment {
  margin: 0;
  white-space: pre-wrap;
  color: #172033;
  font-size: 0.9rem;
  line-height: 1.5;
  text-align: left;
}

.review-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  padding: 0.14rem 0.42rem;
  border: 1px solid #7c3aed;
  border-radius: 999px;
  background-color: #ede9fe !important;
  color: #0f172a !important;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.07);
  white-space: normal;
}

.review-chip--publication {
  border-color: #0891b2;
  background-color: #cffafe !important;
}

.review-chip--genereview,
.review-chip--variation {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.review-chip--ndd {
  border-color: #16a34a;
  background-color: #dcfce7 !important;
}

.review-chip--status {
  border-color: #334155;
  background-color: #f1f5f9 !important;
}

.review-chip--inheritance {
  border-color: #2563eb;
  background-color: #dbeafe !important;
}

.review-chip__link {
  color: inherit;
  text-decoration: none;
}

.review-empty {
  color: #64748b;
  font-size: 0.84rem;
  font-weight: 650;
}

.review-warning {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  padding: 0.75rem;
  border-color: #f59e0b;
  background: #fffbeb;
  color: #92400e;
}

.review-warning__title {
  font-weight: 800;
}

.review-edit {
  white-space: nowrap;
}

@media (max-width: 767.98px) {
  .review-entity-strip,
  .review-grid {
    grid-template-columns: 1fr;
  }

  .review-edit {
    justify-self: flex-start;
  }
}
</style>
