<!-- src/components/forms/BatchCriteriaEntityPicker.vue -->
<!--
  Entity picker for BatchCriteriaForm.vue (#346, Wave 2 Task 4 extraction).

  Search-by-ID/gene/disease, pick a result from the dropdown, and manage
  the selected-entity chip list. Purely presentational: the parent owns
  entitySearchQuery (v-model), the search results/loading state, and the
  entity list; debounce timing and selection delegation live in
  useBatchCriteriaOptions.ts.
-->
<template>
  <section class="batch-form-panel batch-form-panel--wide" aria-labelledby="batch-entities-title">
    <div class="batch-form-panel__header">
      <h3 id="batch-entities-title">Scope</h3>
      <p>Add exact entities, or define a criteria-based batch.</p>
    </div>
    <div class="batch-field">
      <div class="d-flex align-items-center mb-1">
        <label for="entity-search" class="small fw-semibold mb-0"> Search Entities </label>
        <i id="help-search-entities" class="bi bi-question-circle text-muted ms-1" />
        <BTooltip target="help-search-entities" placement="right" triggers="hover">
          Search by entity ID, gene symbol, or disease name. Selected entities are added directly
          to the batch.
        </BTooltip>
      </div>
      <div class="position-relative">
        <BFormInput
          id="entity-search"
          v-model="searchQuery"
          type="search"
          size="sm"
          placeholder="Type to search (ID, gene, disease)..."
          :disabled="isLoading"
          autocomplete="off"
          @input="emit('search')"
          @keydown.enter.prevent
        />
        <BSpinner
          v-if="isSearching"
          small
          class="position-absolute"
          style="right: 10px; top: 50%; transform: translateY(-50%)"
        />
      </div>
      <!-- Search Results Dropdown -->
      <BListGroup v-if="results.length > 0" class="position-absolute shadow-sm entity-search-results">
        <BListGroupItem
          v-for="entity in results"
          :key="entity.entity_id"
          button
          class="py-2 px-3"
          :disabled="selectedEntities.some((e) => e.entity_id === entity.entity_id)"
          @click="emit('select-entity', entity)"
        >
          <div class="d-flex justify-content-between align-items-start">
            <div>
              <span class="fw-bold text-primary">{{ entity.entity_id }}</span>
              <small class="text-muted ms-2">{{ entity.symbol }}</small>
            </div>
            <BBadge
              v-if="selectedEntities.some((e) => e.entity_id === entity.entity_id)"
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
      <div v-if="selectedEntities.length > 0" class="mt-2">
        <span v-for="entity in selectedEntities" :key="entity.entity_id">
          <BFormTag
            :id="`tag-entity-${entity.entity_id}`"
            variant="primary"
            class="me-1 mb-1"
            @remove="emit('remove-entity', entity.entity_id)"
          >
            {{ entity.entity_id }}
          </BFormTag>
          <BTooltip :target="`tag-entity-${entity.entity_id}`" placement="top" triggers="hover">
            {{ entity.symbol }}: {{ entity.disease_ontology_name }}
          </BTooltip>
        </span>
      </div>
      <small v-if="selectedEntities.length > 0" class="batch-field-hint is-success">
        <i class="bi bi-check-circle me-1" />{{ selectedEntities.length }} entities selected
      </small>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { BatchCriteriaEntitySearchResult } from './useBatchCriteriaOptions';

interface SelectedEntity {
  entity_id: number;
  symbol: string;
  disease_ontology_name: string;
}

defineProps<{
  results: BatchCriteriaEntitySearchResult[];
  isSearching: boolean;
  isLoading: boolean;
  selectedEntities: SelectedEntity[];
}>();

const emit = defineEmits<{
  (e: 'search'): void;
  (e: 'select-entity', entity: BatchCriteriaEntitySearchResult): void;
  (e: 'remove-entity', entityId: number): void;
}>();

const searchQuery = defineModel<string>({ default: '' });
</script>

<style scoped>
/* Shared panel chrome — duplicated from BatchCriteriaForm.vue on purpose:
   Vue's scoped CSS does not cross component boundaries, so this section's
   own elements need their own copy of the classes they still share with
   the parent's remaining panels/fields (see BatchCriteriaForm.vue's style
   block for the sibling copy used by its own panels). */
.batch-form-panel {
  min-width: 0;
  padding: 0.8rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
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

.bi-question-circle {
  font-size: 0.75rem;
  cursor: help;
}

/* Entity-picker-specific styling — exclusive to this component, moved
   (not duplicated) out of BatchCriteriaForm.vue. */
.batch-field-hint {
  display: inline-flex;
  align-items: center;
  margin-top: 0.35rem;
  font-size: 0.78rem;
}

.batch-field-hint.is-success {
  color: #16734c;
}

.entity-search-results {
  z-index: 1050;
  max-height: 200px;
  overflow-y: auto;
  width: 100%;
  border: 1px solid #cfd7e3;
  border-top: none;
  border-radius: 0 0 8px 8px;
}
</style>
