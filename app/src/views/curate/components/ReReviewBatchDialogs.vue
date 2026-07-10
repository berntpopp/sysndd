<template>
  <div>
    <!-- Reassign Modal -->
    <BModal
      :model-value="reassignShow"
      title="Reassign Batch"
      ok-title="Reassign"
      cancel-title="Cancel"
      header-close-label="Close"
      @update:model-value="$emit('update:reassignShow', $event)"
      @ok="$emit('reassign')"
    >
      <BFormGroup label="Select new user:" label-for="reassign-user-select">
        <BFormSelect
          id="reassign-user-select"
          :model-value="reassignNewUserId"
          :options="userOptions"
          aria-label="Select user to reassign batch to"
          @update:model-value="onReassignUser"
        />
      </BFormGroup>
      <small class="text-muted">
        This will reassign batch {{ reassignBatchId }} to the selected user.
      </small>
    </BModal>

    <!-- Recalculate Modal (RRV-05) -->
    <BModal
      :model-value="recalculateShow"
      title="Recalculate Batch Contents"
      size="lg"
      ok-title="Recalculate"
      cancel-title="Cancel"
      header-close-label="Close"
      :ok-disabled="isRecalculating"
      @update:model-value="$emit('update:recalculateShow', $event)"
      @ok="$emit('recalculate')"
    >
      <BAlert variant="info" show class="mb-3">
        <i class="bi bi-info-circle me-1" />
        This will replace the current entities in batch {{ recalculateBatchId }} with entities
        matching the new criteria. Only unassigned batches can be recalculated.
      </BAlert>

      <!-- Date Range -->
      <BFormGroup label="Review Date Range" class="mb-3">
        <div class="d-flex gap-2">
          <BFormInput
            :model-value="recalculateCriteria.date_range.start"
            type="date"
            :disabled="isRecalculating"
            aria-label="Start date for review date range"
            @update:model-value="updateStart"
          />
          <span class="align-self-center">to</span>
          <BFormInput
            :model-value="recalculateCriteria.date_range.end"
            type="date"
            :disabled="isRecalculating"
            aria-label="End date for review date range"
            @update:model-value="updateEnd"
          />
        </div>
      </BFormGroup>

      <!-- Status Filter -->
      <BFormGroup label="Status Category" class="mb-3">
        <BFormSelect
          :model-value="recalculateCriteria.status_filter"
          :options="statusOptions"
          :disabled="isRecalculating"
          aria-label="Filter by entity status category"
          @update:model-value="updateStatusFilter"
        >
          <template #first>
            <option :value="null">-- Any status --</option>
          </template>
        </BFormSelect>
      </BFormGroup>

      <!-- Batch Size -->
      <BFormGroup label="Batch Size" class="mb-3">
        <BFormInput
          :model-value="recalculateCriteria.batch_size"
          type="number"
          min="1"
          max="100"
          :disabled="isRecalculating"
          aria-label="Maximum number of entities in recalculated batch"
          @update:model-value="updateBatchSize"
        />
      </BFormGroup>

      <BSpinner v-if="isRecalculating" class="me-2" small />
    </BModal>
  </div>
</template>

<script setup lang="ts">
import type {
  RecalculateCriteria,
  SelectOption,
  UserOption,
} from '@/views/curate/composables/useManageReReview';

const props = defineProps<{
  // Reassign modal
  reassignShow: boolean;
  reassignBatchId: number | null;
  reassignNewUserId: number | null;
  userOptions: UserOption[];
  // Recalculate modal
  recalculateShow: boolean;
  recalculateBatchId: number | null;
  recalculateCriteria: RecalculateCriteria;
  statusOptions: SelectOption[];
  isRecalculating: boolean;
}>();

const emit = defineEmits<{
  (event: 'update:reassignShow', value: boolean): void;
  (event: 'update:reassignNewUserId', value: number | null): void;
  (event: 'update:recalculateShow', value: boolean): void;
  (event: 'update:recalculateCriteria', value: RecalculateCriteria): void;
  (event: 'reassign'): void;
  (event: 'recalculate'): void;
}>();

// BootstrapVueNext emit unions.
type BvSelectValue = string | number | (string | number | null)[] | null;
type BvInputValue = string | number | null;

function pickScalar(value: BvSelectValue): string | number | null {
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

// Emit a fresh criteria object rather than mutating the prop (vue/no-mutating-props).
function emitCriteria(patch: Partial<RecalculateCriteria>): void {
  emit('update:recalculateCriteria', { ...props.recalculateCriteria, ...patch });
}

function updateStart(value: BvInputValue): void {
  emitCriteria({
    date_range: {
      ...props.recalculateCriteria.date_range,
      start: value == null ? null : String(value),
    },
  });
}

function updateEnd(value: BvInputValue): void {
  emitCriteria({
    date_range: {
      ...props.recalculateCriteria.date_range,
      end: value == null ? null : String(value),
    },
  });
}

function updateStatusFilter(value: BvSelectValue): void {
  const next = pickScalar(value);
  emitCriteria({ status_filter: next == null ? null : Number(next) });
}

function updateBatchSize(value: BvInputValue): void {
  const next = typeof value === 'number' ? value : Number(value);
  emitCriteria({ batch_size: Number.isFinite(next) ? next : props.recalculateCriteria.batch_size });
}

function onReassignUser(value: BvSelectValue): void {
  const next = pickScalar(value);
  emit('update:reassignNewUserId', next == null ? null : Number(next) || null);
}
</script>
