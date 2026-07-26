<template>
  <MobileTableList
    :items="items"
    label="Re-review batch assignments"
    empty-text="No batches found."
    :item-key="rowKey"
  >
    <template #default="{ item }">
      <li class="mobile-record-row re-review-mobile-row">
        <div class="mobile-record-row__topline re-review-mobile-row__topline">
          <div class="re-review-mobile-row__identity">
            <strong>Batch #{{ displayValue(item.re_review_batch) }}</strong>
            <span>
              <i :class="item.user_id ? 'bi bi-person-fill' : 'bi bi-person'" aria-hidden="true" />
              {{ item.user_name || 'Unassigned' }}
            </span>
          </div>
          <span
            class="re-review-mobile-row__status"
            :class="{ 're-review-mobile-row__status--assigned': item.user_id }"
          >
            {{ item.user_id ? 'Assigned' : 'Unassigned' }}
          </span>
        </div>

        <div class="mobile-record-row__chips" aria-label="Batch progress">
          <span class="mobile-record-row__chip">{{ entityCountLabel(item.entity_count) }}</span>
          <span class="mobile-record-row__chip">
            {{ displayValue(item.re_review_review_saved) }} reviews saved
          </span>
          <span class="mobile-record-row__chip">
            {{ displayValue(item.re_review_status_saved) }} statuses saved
          </span>
          <span class="mobile-record-row__chip">
            {{ displayValue(item.re_review_submitted) }} submitted
          </span>
          <span class="mobile-record-row__chip">
            {{ displayValue(item.re_review_approved) }} approved
          </span>
        </div>

        <div class="re-review-mobile-row__actions" aria-label="Batch actions">
          <button
            v-if="!item.user_id"
            type="button"
            class="re-review-mobile-row__action"
            :aria-label="`Recalculate batch ${displayValue(item.re_review_batch)}`"
            @click="$emit('open-recalculate', item)"
          >
            <i class="bi bi-calculator" aria-hidden="true" />
            <span>Recalculate</span>
          </button>
          <button
            v-if="item.user_id"
            type="button"
            class="re-review-mobile-row__action re-review-mobile-row__action--reassign"
            :aria-label="`Reassign batch ${displayValue(item.re_review_batch)}`"
            @click="$emit('open-reassign', item)"
          >
            <i class="bi bi-person-lines-fill" aria-hidden="true" />
            <span>Reassign</span>
          </button>
          <button
            v-if="item.user_id"
            type="button"
            class="re-review-mobile-row__action re-review-mobile-row__action--unassign"
            :aria-label="`Unassign batch ${displayValue(item.re_review_batch)}`"
            @click="$emit('unassign', Number(item.re_review_batch))"
          >
            <i class="bi bi-person-dash-fill" aria-hidden="true" />
            <span>Unassign</span>
          </button>
        </div>
      </li>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import MobileTableList from '@/components/table/MobileTableList.vue';
import type { ReReviewBatchRow } from '@/views/curate/utils/reReviewFilters';

defineProps<{
  items: ReReviewBatchRow[];
}>();

defineEmits<{
  (event: 'open-recalculate', row: ReReviewBatchRow): void;
  (event: 'open-reassign', row: ReReviewBatchRow): void;
  (event: 'unassign', batchId: number): void;
}>();

function displayValue(value: unknown): string {
  return value === null || value === undefined || value === '' ? '—' : String(value);
}

function rowKey(row: ReReviewBatchRow, index: number): string {
  return displayValue(row.re_review_batch) || `row-${index}`;
}

function entityCountLabel(value: unknown): string {
  const count = Number(value) || 0;
  return `${count} ${count === 1 ? 'entity' : 'entities'}`;
}
</script>

<style scoped>
.re-review-mobile-row {
  list-style: none;
}

.re-review-mobile-row__topline {
  align-items: flex-start;
}

.re-review-mobile-row__identity {
  min-width: 0;
}

.re-review-mobile-row__identity strong,
.re-review-mobile-row__identity span {
  display: block;
}

.re-review-mobile-row__identity strong {
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono);
  font-size: 0.95rem;
}

.re-review-mobile-row__identity span {
  margin-top: 0.15rem;
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
}

.re-review-mobile-row__status {
  padding: 0.2rem 0.45rem;
  border-radius: var(--radius-full, 999px);
  background: var(--neutral-100, #f5f5f5);
  color: var(--neutral-700, #616161);
  font-size: 0.75rem;
  font-weight: 700;
}

.re-review-mobile-row__status--assigned {
  background: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
}

.re-review-mobile-row__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-top: 0.625rem;
}

.re-review-mobile-row__action {
  display: inline-flex;
  min-width: 2.75rem;
  min-height: 2.75rem;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  padding: 0.45rem 0.7rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-md, 6px);
  background: #fff;
  color: var(--neutral-800, #424242);
  font-size: 0.8125rem;
  font-weight: 700;
}

.re-review-mobile-row__action--reassign {
  color: #8a4b00;
}

.re-review-mobile-row__action--unassign {
  color: var(--status-danger, #c62828);
}

.re-review-mobile-row__action:focus-visible {
  outline: 3px solid var(--medical-blue-600, #1e88e5);
  outline-offset: 2px;
}
</style>
