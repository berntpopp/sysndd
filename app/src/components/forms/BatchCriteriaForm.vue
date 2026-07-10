<!-- src/components/forms/BatchCriteriaForm.vue -->
<!--
  Re-Review Batch Creation Form. The entity search/picker UI lives in
  BatchCriteriaEntityPicker.vue; option loading, entity-search debounce,
  and the gene-filter picker are orchestrated by useBatchCriteriaOptions.ts
  (#346, Wave 2 Task 4). This file keeps useBatchForm, the form schema,
  validation, and the component's public emits.
-->
<template>
  <BForm class="batch-criteria-form" @submit.prevent="onSubmit">
    <div class="batch-form-grid batch-form-grid--top">
      <BatchCriteriaEntityPicker
        v-model="entitySearchQuery"
        :results="entitySearchResults"
        :is-searching="isEntitySearching"
        :is-loading="isLoading"
        :selected-entities="formData.entity_list"
        @search="onEntitySearch"
        @select-entity="selectEntity"
        @remove-entity="removeEntity"
      />

      <section class="batch-form-panel" aria-labelledby="batch-settings-title">
        <div class="batch-form-panel__header">
          <h3 id="batch-settings-title">Batch details</h3>
          <p>Name, size, assignment, and final confirmation.</p>
        </div>
        <div class="batch-details-grid">
          <BFormGroup class="batch-field">
            <template #label>
              <div class="d-flex align-items-center">
                <span class="small fw-semibold">Batch Name</span>
                <i id="help-batch-name" class="bi bi-question-circle text-muted ms-1" />
                <BTooltip target="help-batch-name" placement="right" triggers="hover">
                  Optional name for this batch. If left empty, a name will be auto-generated based
                  on criteria.
                </BTooltip>
              </div>
            </template>
            <BFormInput
              id="batch-name"
              v-model="formData.batch_name"
              size="sm"
              placeholder="Auto-generated if empty"
              :disabled="isLoading"
            />
          </BFormGroup>

          <BFormGroup class="batch-field">
            <template #label>
              <div class="d-flex align-items-center">
                <span class="small fw-semibold">Size</span>
                <i id="help-batch-size" class="bi bi-question-circle text-muted ms-1" />
                <BTooltip target="help-batch-size" placement="right" triggers="hover">
                  Maximum entities per batch (1-100). Use to limit workload per assignment.
                </BTooltip>
              </div>
            </template>
            <BFormInput
              id="batch-size"
              v-model.number="formData.batch_size"
              type="number"
              min="1"
              max="100"
              size="sm"
              :disabled="isLoading"
            />
          </BFormGroup>

          <BFormGroup class="batch-field">
            <template #label>
              <div class="d-flex align-items-center">
                <span class="small fw-semibold">Assign to</span>
                <i id="help-assign-to" class="bi bi-question-circle text-muted ms-1" />
                <BTooltip target="help-assign-to" placement="right" triggers="hover">
                  Select a curator to assign this batch to immediately. Choose 'Later' to assign
                  after creation.
                </BTooltip>
              </div>
            </template>
            <BFormSelect
              id="user-select"
              v-model="formData.assigned_user_id"
              :options="userOptions"
              size="sm"
              :disabled="isLoading"
            >
              <template #first>
                <option :value="null">Assign later</option>
              </template>
            </BFormSelect>
          </BFormGroup>
        </div>
      </section>
    </div>

    <section
      class="batch-form-panel batch-form-panel--filters"
      aria-labelledby="batch-filters-title"
    >
      <div class="batch-form-panel__header">
        <h3 id="batch-filters-title">Criteria filters</h3>
        <p>Use one or more filters. Exact entities can also be added above.</p>
      </div>
      <div class="batch-filters-grid">
        <!-- Date Range -->
        <BFormGroup class="batch-field">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Date Range</span>
              <i id="help-date-range" class="bi bi-question-circle text-muted ms-1" />
              <BTooltip target="help-date-range" placement="right" triggers="hover">
                Filter entities by their last review date. Both start and end dates required.
              </BTooltip>
            </div>
          </template>
          <BInputGroup size="sm">
            <BFormInput
              id="date-start"
              v-model="formData.date_range.start"
              type="date"
              :disabled="isLoading"
              aria-label="Start date"
            />
            <BInputGroupText class="px-2 bg-light">
              <i class="bi bi-arrow-right" />
            </BInputGroupText>
            <BFormInput
              id="date-end"
              v-model="formData.date_range.end"
              type="date"
              :disabled="isLoading"
              aria-label="End date"
            />
          </BInputGroup>
        </BFormGroup>

        <!-- Gene Filter (Alternative to Entity Search) -->
        <BFormGroup class="batch-field">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Gene Filter</span>
              <i id="help-gene-filter" class="bi bi-question-circle text-muted ms-1" />
              <BTooltip target="help-gene-filter" placement="right" triggers="hover">
                Select genes to include ALL their associated entities in the batch. Use Ctrl+Click
                (Cmd+Click on Mac) to select multiple.
              </BTooltip>
            </div>
          </template>
          <div class="gene-picker">
            <BFormInput
              id="gene-select"
              v-model="geneSearchQuery"
              size="sm"
              type="search"
              placeholder="Search genes"
              :disabled="isLoading"
              autocomplete="off"
              aria-label="Search genes"
            />
            <div v-if="filteredGeneOptions.length > 0" class="gene-picker__results">
              <button
                v-for="gene in filteredGeneOptions"
                :key="gene.value"
                type="button"
                class="gene-picker__option"
                @click="addGene(gene.value)"
              >
                {{ gene.text }}
              </button>
            </div>
          </div>
          <div v-if="selectedGeneOptions.length > 0" class="batch-chip-list">
            <BButton
              v-for="gene in selectedGeneOptions"
              :key="gene.value"
              size="sm"
              variant="outline-primary"
              class="batch-chip"
              @click="removeGene(gene.value)"
            >
              {{ gene.text }}
              <i class="bi bi-x ms-1" aria-hidden="true" />
            </BButton>
          </div>
          <small v-if="formData.gene_list.length > 0" class="text-muted">
            {{ formData.gene_list.length }} gene(s) selected.
          </small>
        </BFormGroup>

        <!-- Status Filter -->
        <BFormGroup class="batch-field">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Status</span>
              <i id="help-status-filter" class="bi bi-question-circle text-muted ms-1" />
              <BTooltip target="help-status-filter" placement="right" triggers="hover">
                Filter entities by their current curation status.
              </BTooltip>
            </div>
          </template>
          <BFormSelect
            id="status-filter"
            v-model="formData.status_filter"
            :options="statusOptions"
            size="sm"
            :disabled="isLoading"
          >
            <template #first>
              <option :value="null">Any status</option>
            </template>
          </BFormSelect>
        </BFormGroup>
      </div>
    </section>

    <section
      class="batch-form-panel batch-form-panel--actions"
      aria-label="Batch review and actions"
    >
      <div class="batch-action-grid">
        <!-- Validation Message -->
        <BAlert v-if="!isFormValid" variant="warning" class="py-2 px-3 mb-2 batch-form-alert">
          <i class="bi bi-exclamation-triangle me-1" />
          <small>Select entities, set date range, or choose a gene/status filter</small>
        </BAlert>

        <!-- Summary -->
        <div v-if="isFormValid" class="batch-summary">
          <small>Batch summary</small>
          <ul class="mb-0 ps-3 small">
            <li v-if="formData.entity_list.length > 0">
              {{ formData.entity_list.length }} specific entities
            </li>
            <li v-if="formData.date_range.start && formData.date_range.end">
              Reviews: {{ formData.date_range.start }} → {{ formData.date_range.end }}
            </li>
            <li v-if="formData.gene_list.length > 0">
              {{ formData.gene_list.length }} gene(s) selected
            </li>
            <li v-if="formData.status_filter !== null">
              Status:
              {{
                statusOptions.find((s) => s.value === formData.status_filter)?.text || 'Selected'
              }}
            </li>
            <li>Max size: {{ formData.batch_size }}</li>
          </ul>
        </div>

        <!-- Action Buttons -->
        <div class="batch-actions">
          <BButton
            size="sm"
            variant="outline-primary"
            :disabled="isLoading || isPreviewLoading || !isFormValid"
            @click="onPreview"
          >
            <BSpinner v-if="isPreviewLoading" small class="me-1" />
            <i v-else class="bi bi-eye me-1" />
            Preview
          </BButton>
          <BButton type="submit" size="sm" variant="primary" :disabled="isLoading || !isFormValid">
            <BSpinner v-if="isLoading" small class="me-1" />
            <i v-else class="bi bi-plus-circle me-1" />
            Create Batch
          </BButton>
          <BButton
            size="sm"
            variant="outline-secondary"
            :disabled="isLoading"
            title="Reset form"
            @click="onReset"
          >
            <i class="bi bi-x-circle" />
          </BButton>
        </div>
      </div>
    </section>

    <!-- Preview Modal -->
    <BModal
      v-model="showPreviewModal"
      title="Preview: Matching Entities"
      size="lg"
      ok-only
      ok-title="Close"
      body-class="p-2"
    >
      <div v-if="previewEntities.length > 0">
        <div class="mb-2 small text-success fw-semibold">
          <i class="bi bi-check-circle me-1" />
          {{ previewEntities.length }} entities match (max {{ formData.batch_size }})
        </div>
        <!-- Gene-atomic boundary warning (issue #29) -->
        <BAlert
          v-if="previewBoundaryGene"
          variant="warning"
          show
          class="py-2 px-3 mb-2"
          data-testid="batch-boundary-gene-alert"
        >
          <i class="bi bi-exclamation-triangle me-1" aria-hidden="true" />
          Batch is gene-atomic: to keep gene <strong>{{ previewBoundaryGene }}</strong> together,
          the batch will hold {{ previewEntityCount }} entities across
          {{ previewGeneCount }} gene(s) (you requested {{ formData.batch_size }}). The last gene
          was extended past the cap to avoid splitting it. Tighten criteria or increase batch size
          to avoid the overflow.
        </BAlert>
        <BTable
          :items="previewEntities"
          :fields="previewFields"
          small
          striped
          hover
          responsive
          class="mb-0 compact-table"
        />
      </div>
      <BAlert v-else variant="warning" class="py-2 px-3 mb-0">
        <i class="bi bi-exclamation-triangle me-1" />
        No matching entities found. Try broader criteria.
      </BAlert>
    </BModal>
  </BForm>
</template>

<script setup lang="ts">
import { useBatchForm } from '@/composables/useBatchForm';
import BatchCriteriaEntityPicker from './BatchCriteriaEntityPicker.vue';
import useBatchCriteriaOptions from './useBatchCriteriaOptions';

const emit = defineEmits<{
  (e: 'batch-created'): void;
}>();

const {
  formData,
  isLoading,
  isPreviewLoading,
  isFormValid,
  // Entity search
  entitySearchQuery,
  entitySearchResults,
  isEntitySearching,
  searchEntities,
  addEntity,
  removeEntity,
  // Options
  geneOptions,
  statusOptions,
  userOptions,
  // Preview
  previewEntities,
  previewFields,
  showPreviewModal,
  previewBoundaryGene,
  previewGeneCount,
  previewEntityCount,
  // Methods
  loadOptions,
  handlePreview,
  handleSubmit,
  resetForm,
} = useBatchForm();

// Option loading, entity-search debounce, and the gene-filter picker are
// orchestrated by useBatchCriteriaOptions.ts (#346, Wave 2 Task 4) over
// the pieces of useBatchForm's return value above.
const {
  geneSearchQuery,
  selectedGeneOptions,
  filteredGeneOptions,
  addGene,
  removeGene,
  onEntitySearch,
  selectEntity,
} = useBatchCriteriaOptions({
  formData,
  geneOptions,
  entitySearchQuery,
  searchEntities,
  addEntity,
  loadOptions,
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
.batch-criteria-form {
  display: grid;
  gap: 0.8rem;
  min-width: 0;
}
.batch-form-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(20rem, 0.85fr);
  gap: 0.8rem;
  align-items: start;
}
.batch-form-panel {
  min-width: 0;
  padding: 0.8rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
}
.batch-form-panel--filters,
.batch-form-panel--actions {
  background: #f8fafc;
}
.batch-form-panel__header {
  margin-bottom: 0.7rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e6ebf2;
}
.batch-form-panel__header h3 {
  margin: 0;
  color: #172033;
  font-size: 0.9rem;
  font-weight: 700;
  line-height: 1.25;
}
.batch-form-panel__header p {
  margin: 0.15rem 0 0;
  color: #526070;
  font-size: 0.78rem;
}
.batch-field {
  margin-bottom: 0;
}

.batch-details-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(5rem, 0.35fr);
  gap: 0.65rem;
}
.batch-details-grid > :first-child,
.batch-details-grid > :last-child {
  grid-column: 1 / -1;
}

.batch-filters-grid {
  display: grid;
  grid-template-columns: minmax(18rem, 1.1fr) minmax(14rem, 1fr) minmax(12rem, 0.8fr);
  gap: 0.7rem;
  align-items: start;
}
.gene-picker {
  position: relative;
}
.gene-picker__results {
  position: absolute;
  z-index: 1060;
  top: calc(100% + 0.2rem);
  right: 0;
  left: 0;
  overflow: auto;
  max-height: 14rem;
  border: 1px solid #cfd7e3;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 12px 24px rgba(15, 23, 42, 0.12);
}
.gene-picker__option {
  display: block;
  width: 100%;
  padding: 0.45rem 0.65rem;
  border: 0;
  border-bottom: 1px solid #edf1f6;
  background: #fff;
  color: #172033;
  font-size: 0.84rem;
  text-align: left;
}
.gene-picker__option:hover,
.gene-picker__option:focus-visible {
  background: #eef6ff;
  outline: 0;
}

.batch-chip-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.45rem;
}
.batch-chip {
  border-radius: 999px;
}

.batch-form-alert {
  margin-bottom: 0 !important;
  border-radius: 8px;
}

.batch-summary {
  margin-bottom: 0;
  padding: 0.65rem 0.75rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
}
.batch-summary small {
  display: block;
  margin-bottom: 0.25rem;
  color: #526070;
  font-weight: 700;
  text-transform: uppercase;
}

.batch-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  justify-content: flex-end;
}
.batch-action-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.75rem;
  align-items: center;
}

.batch-criteria-form :deep(.form-label),
.batch-criteria-form :deep(label) {
  color: #172033;
}
.batch-criteria-form :deep(.form-control),
.batch-criteria-form :deep(.form-select),
.batch-criteria-form :deep(.input-group-text) {
  border-color: #cfd7e3;
  border-radius: 6px;
}
.batch-criteria-form :deep(.input-group .form-control),
.batch-criteria-form :deep(.input-group .form-select),
.batch-criteria-form :deep(.input-group .input-group-text) {
  border-radius: 0;
}
.batch-criteria-form :deep(.input-group > :first-child) {
  border-top-left-radius: 6px;
  border-bottom-left-radius: 6px;
}
.batch-criteria-form :deep(.input-group > :last-child) {
  border-top-right-radius: 6px;
  border-bottom-right-radius: 6px;
}

/* Compact table styling */
.compact-table {
  font-size: 0.85rem;
}
.compact-table th,
.compact-table td {
  padding: 0.35rem 0.5rem;
}

/* Help icon styling */
.bi-question-circle {
  font-size: 0.75rem;
  cursor: help;
}

@media (max-width: 991.98px) {
  .batch-form-grid {
    grid-template-columns: 1fr;
  }
  .batch-details-grid,
  .batch-filters-grid,
  .batch-action-grid {
    grid-template-columns: 1fr;
  }
  .batch-details-grid > :first-child,
  .batch-details-grid > :last-child {
    grid-column: auto;
  }
  .batch-actions {
    justify-content: flex-start;
  }
}
</style>
