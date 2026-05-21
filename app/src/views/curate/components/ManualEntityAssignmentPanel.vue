<template>
  <div class="re-review-mode-panel re-review-section__body--assignment">
    <div class="re-review-mode-intro">
      <strong>Manual pick</strong>
      <span>Select exact entities, assign a user, then create the exception batch.</span>
      <BButton size="sm" variant="outline-secondary" class="ms-auto" @click="$emit('close')">
        Close setup
      </BButton>
    </div>

    <div class="re-review-manual-controls">
      <div class="re-review-assignment-grid">
        <BFormGroup label="Assign to" label-for="entity-assign-user" class="mb-0">
          <BFormSelect
            id="entity-assign-user"
            :model-value="entityAssignUserId"
            :options="userOptions"
            size="sm"
            aria-label="Select user to assign selected entities to"
            @update:model-value="updateEntityAssignUserId"
          >
            <template #first>
              <option :value="null" disabled>Select a user</option>
            </template>
          </BFormSelect>
        </BFormGroup>

        <BFormGroup label="Batch name" label-for="entity-assign-batch-name" class="mb-0">
          <BFormInput
            id="entity-assign-batch-name"
            :model-value="entityAssignBatchName"
            size="sm"
            placeholder="Auto-generated"
            aria-label="Custom name for the new batch"
            @update:model-value="updateEntityAssignBatchName"
          />
        </BFormGroup>
      </div>

      <div class="re-review-button-row">
        <BButton
          variant="primary"
          size="sm"
          :disabled="selectedEntityIds.length === 0 || !entityAssignUserId || isAssigningEntities"
          @click="$emit('assign-entities')"
        >
          <BSpinner v-if="isAssigningEntities" small class="me-1" />
          <i v-else class="bi bi-person-plus me-1" aria-hidden="true" />
          Assign {{ selectedEntityIds.length || '' }} selected
        </BButton>
        <BButton
          variant="outline-secondary"
          size="sm"
          aria-label="Refresh entity list"
          @click="$emit('refresh-entities')"
        >
          <i class="bi bi-arrow-clockwise me-1" aria-hidden="true" />
          Refresh entities
        </BButton>
      </div>
    </div>

    <BFormGroup label="Entities" label-for="entity-select-table" class="mb-3 re-review-entity-picker">
      <div class="re-review-picker-toolbar">
        <TableSearchInput
          :model-value="manualEntityFilter"
          placeholder="Search available entities"
          :debounce-time="300"
          @update:model-value="updateManualEntityFilter"
          @update="$emit('refresh-entities')"
          @clear="$emit('refresh-entities')"
        />
        <div class="re-review-picker-toolbar__meta">
          <strong>{{ selectedEntityIds.length }}</strong>
          selected
        </div>
        <BButton
          size="sm"
          variant="outline-secondary"
          :disabled="selectedEntityIds.length === 0"
          @click="$emit('clear-selection')"
        >
          Clear
        </BButton>
      </div>
      <BTable
        id="entity-select-table"
        :items="availableEntities"
        :fields="entitySelectFields"
        small
        hover
        responsive
        :busy="isLoadingEntities"
        :tbody-tr-class="manualEntityRowClass"
        class="re-review-pick-table"
      >
        <template #table-busy>
          <div class="text-center my-2">
            <BSpinner class="align-middle" />
            <strong class="ms-2">Loading entities...</strong>
          </div>
        </template>
        <template #cell(selected)="row">
          <input
            type="checkbox"
            class="form-check-input re-review-row-checkbox"
            :checked="isEntitySelected(row.item.entity_id)"
            :aria-label="`Select entity ${row.item.entity_id}`"
            @change="$emit('toggle-entity-selection', row.item.entity_id)"
          />
        </template>
        <template #cell(entity_id)="row">
          <span class="font-monospace">#{{ row.item.entity_id }}</span>
        </template>
        <template #cell(disease_ontology_name)="row">
          <span class="re-review-disease-cell" :title="row.item.disease_ontology_name">
            {{ row.item.disease_ontology_name }}
          </span>
        </template>
      </BTable>
      <small class="text-muted d-block mt-1">
        Showing {{ availableEntities.length }} of {{ availableEntityTotal }} available entities.
      </small>
    </BFormGroup>

    <BAlert
      v-if="boundaryGeneAlertVisible"
      variant="warning"
      show
      class="my-3"
      data-testid="batch-boundary-gene-alert"
    >
      <i class="bi bi-exclamation-triangle me-1" aria-hidden="true" />
      {{ boundaryGeneAlertMessage }}
    </BAlert>
  </div>
</template>

<script setup lang="ts">
import TableSearchInput from '@/components/small/TableSearchInput.vue';

interface UserOption {
  value: number;
  text: string;
  role?: string;
}

interface EntityRow {
  entity_id: number;
  gene_symbol?: string;
  disease_ontology_name?: string;
  review_date?: string;
  status_name?: string;
  [key: string]: unknown;
}

interface TableField {
  key: string;
  label: string;
  sortable?: boolean;
  thStyle?: Record<string, string>;
}

const props = defineProps<{
  userOptions: UserOption[];
  entityAssignUserId: number | null;
  entityAssignBatchName: string;
  selectedEntityIds: number[];
  availableEntities: EntityRow[];
  availableEntityTotal: number;
  entitySelectFields: TableField[];
  manualEntityFilter: string | null;
  isLoadingEntities: boolean;
  isAssigningEntities: boolean;
  boundaryGeneAlertVisible: boolean;
  boundaryGeneAlertMessage: string;
}>();

const emit = defineEmits<{
  (event: 'update:entityAssignUserId', value: number | null): void;
  (event: 'update:entityAssignBatchName', value: string): void;
  (event: 'update:manualEntityFilter', value: string | null): void;
  (event: 'assign-entities'): void;
  (event: 'refresh-entities'): void;
  (event: 'clear-selection'): void;
  (event: 'toggle-entity-selection', entityId: number): void;
  (event: 'close'): void;
}>();

function updateEntityAssignUserId(value: number | null) {
  emit('update:entityAssignUserId', value);
}

function updateEntityAssignBatchName(value: string) {
  emit('update:entityAssignBatchName', value);
}

function updateManualEntityFilter(value: string | null) {
  emit('update:manualEntityFilter', value);
}

function isEntitySelected(entityId: number) {
  return props.selectedEntityIds.includes(entityId);
}

function manualEntityRowClass(item: EntityRow | null) {
  return item && props.selectedEntityIds.includes(item.entity_id)
    ? 're-review-pick-table__row--selected'
    : '';
}
</script>
