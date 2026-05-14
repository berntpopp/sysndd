<template>
  <MobileTableList
    :items="items"
    label="Ontology terms"
    empty-text="No ontology terms found."
    :item-key="rowKey"
  >
    <template #default="{ item }">
      <article class="mobile-record-row ontology-mobile-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="ontology-mobile-row__identity">
            <span class="ontology-mobile-row__id">{{ displayValue(item.vario_id) }}</span>
            <span class="ontology-mobile-row__name">{{ displayValue(item.vario_name) }}</span>
          </div>
          <button
            type="button"
            class="ontology-mobile-row__action"
            :aria-label="`Edit ontology ${displayValue(item.vario_id)}`"
            @click="$emit('edit', item)"
          >
            <i class="bi bi-pencil-square" aria-hidden="true" />
          </button>
        </div>

        <p v-if="hasValue(item.definition)" class="ontology-mobile-row__definition">
          {{ displayValue(item.definition) }}
        </p>

        <div class="mobile-record-row__chips" aria-label="Ontology metadata">
          <span class="mobile-record-row__chip">
            <i
              :class="isActive(item.is_active) ? 'bi bi-check-circle-fill' : 'bi bi-dash-circle'"
              aria-hidden="true"
            />
            <span>{{ isActive(item.is_active) ? 'Active' : 'Inactive' }}</span>
          </span>
          <span class="mobile-record-row__chip">
            <i
              :class="
                isObsolete(item.obsolete) ? 'bi bi-exclamation-circle' : 'bi bi-journal-check'
              "
              aria-hidden="true"
            />
            <span>{{ isObsolete(item.obsolete) ? 'Obsolete' : 'Current' }}</span>
          </span>
          <span v-if="hasValue(item.sort)" class="mobile-record-row__chip">
            <i class="bi bi-sort-numeric-down" aria-hidden="true" />
            <span>Sort {{ displayValue(item.sort) }}</span>
          </span>
          <span v-if="hasValue(item.update_date)" class="mobile-record-row__chip">
            <i class="bi bi-calendar3" aria-hidden="true" />
            <span>{{ formatDate(item.update_date) }}</span>
          </span>
        </div>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import MobileTableList from '@/components/table/MobileTableList.vue';

type Item = Record<string, unknown>;

defineProps<{
  items: Item[];
}>();

defineEmits<{
  (e: 'edit', item: Item): void;
}>();

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '';
}

function truthyFlag(value: unknown): boolean {
  return value === true || value === 1 || value === '1';
}

function isActive(value: unknown): boolean {
  return truthyFlag(value);
}

function isObsolete(value: unknown): boolean {
  return truthyFlag(value);
}

function rowKey(item: Item, index: number): string {
  return displayValue(item.vario_id) || `row-${index}`;
}

function formatDate(value: unknown): string {
  return displayValue(value).substring(0, 10) || '—';
}
</script>

<style scoped>
.ontology-mobile-row__identity {
  min-width: 0;
}

.ontology-mobile-row__id,
.ontology-mobile-row__name {
  display: block;
  overflow-wrap: anywhere;
}

.ontology-mobile-row__id {
  color: #0d6efd;
  font-size: 0.8125rem;
  font-weight: 800;
}

.ontology-mobile-row__name {
  color: #0f172a;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.25;
}

.ontology-mobile-row__definition {
  display: -webkit-box;
  margin: 0.45rem 0 0;
  overflow: hidden;
  color: #475569;
  font-size: 0.8125rem;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
}

.ontology-mobile-row__action {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  border: 1px solid rgba(13, 110, 253, 0.35);
  border-radius: 0.375rem;
  background: #fff;
  color: #0d6efd;
}
</style>
