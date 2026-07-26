<template>
  <MobileTableList
    :items="items"
    :label="`${vocabulary.label} entries`"
    empty-text="No entries."
    :item-key="rowKey"
  >
    <template #default="{ item }">
      <li class="mobile-record-row metadata-mobile-row">
        <div class="mobile-record-row__topline metadata-mobile-row__topline">
          <div class="metadata-mobile-row__identity">
            <strong>{{ rowLabel(item) }}</strong>
            <span>{{ rowIdentifier(item) }}</span>
          </div>
          <div class="metadata-mobile-row__actions" aria-label="Metadata entry actions">
            <button
              type="button"
              class="metadata-mobile-row__action"
              :aria-label="`Edit metadata entry ${rowLabel(item)}`"
              @click="emitEdit(item)"
            >
              <i class="bi bi-pencil" aria-hidden="true" />
            </button>
            <button
              v-if="canDeactivate"
              type="button"
              class="metadata-mobile-row__action metadata-mobile-row__action--deactivate"
              :aria-label="`Deactivate metadata entry ${rowLabel(item)}`"
              @click="emitDeactivate(item)"
            >
              <i class="bi bi-archive" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div class="mobile-record-row__chips" aria-label="Metadata entry status">
          <span class="mobile-record-row__chip">
            <i
              :class="isActive(item) ? 'bi bi-check-circle-fill' : 'bi bi-dash-circle'"
              aria-hidden="true"
            />
            <span>{{ isActive(item) ? 'Active' : 'Inactive' }}</span>
          </span>
          <span v-for="field in secondaryFields" :key="field" class="mobile-record-row__chip">
            {{ humanizeLabel(field) }}: {{ formatValue(item[field]) }}
          </span>
          <span v-if="vocabulary.has_sort && hasValue(item.sort)" class="mobile-record-row__chip">
            Sort: {{ displayValue(item.sort) }}
          </span>
        </div>
      </li>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import MobileTableList from '@/components/table/MobileTableList.vue';
import type { MetadataRow, MetadataVocabulary } from '@/api/metadata';

type MobileItem = Record<string, unknown>;

const props = defineProps<{
  items: MetadataRow[];
  vocabulary: MetadataVocabulary;
  canDeactivate: boolean;
}>();

const emit = defineEmits<{
  (event: 'edit', row: MetadataRow): void;
  (event: 'deactivate', row: MetadataRow): void;
}>();

const primaryField = computed(() => props.vocabulary.fields[0] ?? props.vocabulary.pk);
const secondaryFields = computed(() =>
  props.vocabulary.fields.filter((field) => field !== primaryField.value)
);

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '—';
}

function truthy(value: unknown): boolean {
  return value === true || value === 1 || value === '1';
}

function rowLabel(row: MobileItem): string {
  return displayValue(row[primaryField.value] ?? row[props.vocabulary.pk]);
}

function rowIdentifier(row: MobileItem): string {
  const value = displayValue(row[props.vocabulary.pk]);
  return props.vocabulary.pk === primaryField.value ? '' : value;
}

function rowKey(row: MobileItem, index: number): string {
  return displayValue(row[props.vocabulary.pk]) || `row-${index}`;
}

function isActive(row: MobileItem): boolean {
  return !props.vocabulary.has_is_active || truthy(row.is_active);
}

function humanizeLabel(field: string): string {
  return field
    .replace(/^allowed_/, '')
    .replace(/_/g, ' ')
    .replace(/^\w/, (character) => character.toUpperCase());
}

function formatValue(value: unknown): string {
  if (
    value === true ||
    value === false ||
    value === 1 ||
    value === 0 ||
    value === '1' ||
    value === '0'
  ) {
    return truthy(value) ? 'Yes' : 'No';
  }
  return displayValue(value);
}

function emitEdit(row: MobileItem): void {
  emit('edit', row as MetadataRow);
}

function emitDeactivate(row: MobileItem): void {
  emit('deactivate', row as MetadataRow);
}
</script>

<style scoped>
.metadata-mobile-row {
  list-style: none;
}

.metadata-mobile-row__topline {
  align-items: flex-start;
}

.metadata-mobile-row__identity {
  min-width: 0;
}

.metadata-mobile-row__identity strong,
.metadata-mobile-row__identity span {
  display: block;
  overflow-wrap: anywhere;
}

.metadata-mobile-row__identity strong {
  color: var(--neutral-900, #212121);
  font-size: 0.95rem;
  line-height: 1.25;
}

.metadata-mobile-row__identity span {
  color: var(--neutral-700, #616161);
  font-family: var(--font-family-mono);
  font-size: 0.75rem;
}

.metadata-mobile-row__identity span:empty {
  display: none;
}

.metadata-mobile-row__actions {
  display: inline-flex;
  flex: 0 0 auto;
  gap: 0.25rem;
}

.metadata-mobile-row__action {
  display: inline-grid;
  width: 2.75rem;
  min-width: 2.75rem;
  height: 2.75rem;
  padding: 0;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-md, 6px);
  background: #fff;
  color: var(--medical-blue-700, #0d47a1);
  place-items: center;
}

.metadata-mobile-row__action--deactivate {
  color: var(--status-warning, #f57c00);
}

.metadata-mobile-row__action:focus-visible {
  outline: 3px solid var(--medical-blue-600, #1e88e5);
  outline-offset: 2px;
}
</style>
