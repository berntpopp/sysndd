<!-- src/components/forms/BatchCriteriaForm.vue -->
<!--
  Re-Review Batch Creation Form
  Expert UX design with:
  - Entity search with autocomplete and chip display
  - Help icons with tooltips explaining each field
  - Clean 2-column layout with clear visual hierarchy
  - Accessible form controls with proper ARIA attributes
-->
<template>
  <BForm @submit.prevent="onSubmit">
    <BRow>
      <!-- Left Column: Selection Criteria -->
      <BCol
        lg="7"
        class="pe-lg-4"
      >
        <!-- Entity Search Section -->
        <div class="mb-3">
          <div class="d-flex align-items-center mb-1">
            <label
              for="entity-search"
              class="small fw-semibold mb-0"
            >
              Search Entities
            </label>
            <i
              id="help-search-entities"
              class="bi bi-question-circle text-muted ms-1"
            />
            <BTooltip
              target="help-search-entities"
              placement="right"
              triggers="hover"
            >
              Search by entity ID, gene symbol, or disease name. Selected entities are added directly to the batch.
            </BTooltip>
          </div>
          <div class="position-relative">
            <BFormInput
              id="entity-search"
              v-model="entitySearchQuery"
              type="search"
              size="sm"
              placeholder="Type to search (ID, gene, disease)..."
              :disabled="isLoading"
              autocomplete="off"
              @input="onEntitySearch"
              @keydown.enter.prevent
            />
            <BSpinner
              v-if="isEntitySearching"
              small
              class="position-absolute"
              style="right: 10px; top: 50%; transform: translateY(-50%);"
            />
          </div>
          <!-- Search Results Dropdown -->
          <BListGroup
            v-if="entitySearchResults.length > 0"
            class="position-absolute shadow-sm entity-search-results"
          >
            <BListGroupItem
              v-for="entity in entitySearchResults"
              :key="entity.entity_id"
              button
              class="py-2 px-3"
              :disabled="formData.entity_list.some(e => e.entity_id === entity.entity_id)"
              @click="selectEntity(entity)"
            >
              <div class="d-flex justify-content-between align-items-start">
                <div>
                  <span class="fw-bold text-primary">{{ entity.entity_id }}</span>
                  <small class="text-muted ms-2">{{ entity.symbol }}</small>
                </div>
                <BBadge
                  v-if="formData.entity_list.some(e => e.entity_id === entity.entity_id)"
                  variant="secondary"
                >
                  Added
                </BBadge>
              </div>
              <small class="text-muted d-block text-truncate">
                {{ entity.disease_ontology_name }}
              </small>
            </BListGroupItem>
          </BListGroup>
          <!-- Selected Entities as Chips -->
          <div
            v-if="formData.entity_list.length > 0"
            class="mt-2"
          >
            <span
              v-for="entity in formData.entity_list"
              :key="entity.entity_id"
            >
              <BFormTag
                :id="`tag-entity-${entity.entity_id}`"
                variant="primary"
                class="me-1 mb-1"
                @remove="removeEntity(entity.entity_id)"
              >
                {{ entity.entity_id }}
              </BFormTag>
              <BTooltip
                :target="`tag-entity-${entity.entity_id}`"
                placement="top"
                triggers="hover"
              >
                {{ entity.symbol }}: {{ entity.disease_ontology_name }}
              </BTooltip>
            </span>
          </div>
          <small
            v-if="formData.entity_list.length > 0"
            class="text-success"
          >
            <i class="bi bi-check-circle me-1" />{{ formData.entity_list.length }} entities selected
          </small>
        </div>

        <!-- Divider with OR -->
        <div class="divider-or mb-3">
          <span class="text-muted small bg-body px-2">OR filter by criteria</span>
        </div>

        <!-- Date Range -->
        <BFormGroup class="mb-2">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Date Range</span>
              <i
                id="help-date-range"
                class="bi bi-question-circle text-muted ms-1"
              />
              <BTooltip
                target="help-date-range"
                placement="right"
                triggers="hover"
              >
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
        <BFormGroup class="mb-2">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Gene Filter</span>
              <i
                id="help-gene-filter"
                class="bi bi-question-circle text-muted ms-1"
              />
              <BTooltip
                target="help-gene-filter"
                placement="right"
                triggers="hover"
              >
                Select genes to include ALL their associated entities in the batch. Use Ctrl+Click (Cmd+Click on Mac) to select multiple.
              </BTooltip>
            </div>
          </template>
          <BFormSelect
            id="gene-select"
            v-model="formData.gene_list"
            :options="geneOptions"
            multiple
            :select-size="3"
            size="sm"
            :disabled="isLoading"
            aria-label="Select genes"
          >
            <template #first>
              <option
                :value="null"
                disabled
              >
                -- Select genes --
              </option>
            </template>
          </BFormSelect>
          <small
            v-if="formData.gene_list.length > 0"
            class="text-muted"
          >
            {{ formData.gene_list.length }} gene(s) → all related entities
          </small>
        </BFormGroup>

        <!-- Status Filter -->
        <BFormGroup class="mb-2">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Status</span>
              <i
                id="help-status-filter"
                class="bi bi-question-circle text-muted ms-1"
              />
              <BTooltip
                target="help-status-filter"
                placement="right"
                triggers="hover"
              >
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
              <option :value="null">
                Any status
              </option>
            </template>
          </BFormSelect>
        </BFormGroup>
      </BCol>

      <!-- Right Column: Batch Settings -->
      <BCol
        lg="5"
        class="ps-lg-4 border-start-lg"
      >
        <!-- Batch Name -->
        <BFormGroup class="mb-2">
          <template #label>
            <div class="d-flex align-items-center">
              <span class="small fw-semibold">Batch Name</span>
              <i
                id="help-batch-name"
                class="bi bi-question-circle text-muted ms-1"
              />
              <BTooltip
                target="help-batch-name"
                placement="right"
                triggers="hover"
              >
                Optional name for this batch. If left empty, a name will be auto-generated based on criteria.
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

        <!-- Batch Size & User Row -->
        <BRow class="mb-2">
          <BCol cols="5">
            <BFormGroup>
              <template #label>
                <div class="d-flex align-items-center">
                  <span class="small fw-semibold">Size</span>
                  <i
                    id="help-batch-size"
                    class="bi bi-question-circle text-muted ms-1"
                  />
                  <BTooltip
                    target="help-batch-size"
                    placement="right"
                    triggers="hover"
                  >
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
          </BCol>
          <BCol cols="7">
            <BFormGroup>
              <template #label>
                <div class="d-flex align-items-center">
                  <span class="small fw-semibold">Assign to</span>
                  <i
                    id="help-assign-to"
                    class="bi bi-question-circle text-muted ms-1"
                  />
                  <BTooltip
                    target="help-assign-to"
                    placement="right"
                    triggers="hover"
                  >
                    Select a curator to assign this batch to immediately. Choose 'Later' to assign after creation.
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
                  <option :value="null">
                    Assign later
                  </option>
                </template>
              </BFormSelect>
            </BFormGroup>
          </BCol>
        </BRow>

        <!-- Validation Message -->
        <BAlert
          v-if="!isFormValid"
          variant="warning"
          class="py-2 px-3 mb-2"
        >
          <i class="bi bi-exclamation-triangle me-1" />
          <small>Select entities, set date range, or choose a gene/status filter</small>
        </BAlert>

        <!-- Summary -->
        <div
          v-if="isFormValid"
          class="bg-light rounded p-2 mb-2"
        >
          <small class="text-muted d-block fw-semibold mb-1">Batch Summary:</small>
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
              Status: {{ statusOptions.find(s => s.value === formData.status_filter)?.text || 'Selected' }}
            </li>
            <li>Max size: {{ formData.batch_size }}</li>
          </ul>
        </div>

        <!-- Action Buttons -->
        <div class="d-flex gap-2">
          <BButton
            size="sm"
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
            Preview
          </BButton>
          <BButton
            type="submit"
            size="sm"
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
            size="sm"
            variant="outline-secondary"
            :disabled="isLoading"
            title="Reset form"
            @click="onReset"
          >
            <i class="bi bi-x-circle" />
          </BButton>
        </div>
      </BCol>
    </BRow>

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
      <BAlert
        v-else
        variant="warning"
        class="py-2 px-3 mb-0"
      >
        <i class="bi bi-exclamation-triangle me-1" />
        No matching entities found. Try broader criteria.
      </BAlert>
    </BModal>
  </BForm>
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
  // Methods
  loadOptions,
  handlePreview,
  handleSubmit,
  resetForm,
} = useBatchForm();

onMounted(() => {
  loadOptions();
});

// Debounced entity search
let searchTimeout: ReturnType<typeof setTimeout> | null = null;
const onEntitySearch = () => {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    searchEntities(entitySearchQuery.value);
  }, 300);
};

const selectEntity = (entity: { entity_id: number; symbol: string; disease_ontology_name: string }) => {
  addEntity(entity as Parameters<typeof addEntity>[0]);
};

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
/* Responsive border for column separation */
@media (min-width: 992px) {
  .border-start-lg {
    border-left: 1px solid #dee2e6 !important;
  }
}

/* Entity search results dropdown */
.entity-search-results {
  z-index: 1050;
  max-height: 200px;
  overflow-y: auto;
  width: 100%;
  border: 1px solid #dee2e6;
  border-top: none;
  border-radius: 0 0 0.375rem 0.375rem;
}

/* Divider with centered text */
.divider-or {
  display: flex;
  align-items: center;
  text-align: center;
}

.divider-or::before,
.divider-or::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid #dee2e6;
}

.divider-or::before {
  margin-right: 0.5rem;
}

.divider-or::after {
  margin-left: 0.5rem;
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
</style>
