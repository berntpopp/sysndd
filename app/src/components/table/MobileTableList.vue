<template>
  <div class="mobile-table-list" :role="items.length === 0 ? undefined : 'list'" :aria-label="label">
    <div v-if="items.length === 0" class="mobile-table-list__empty" role="status">
      {{ emptyText }}
    </div>
    <template v-else>
      <slot
        v-for="(item, index) in items"
        :key="resolveItemKey(item, index)"
        :item="item"
        :index="index"
      />
    </template>
  </div>
</template>

<script setup lang="ts">
type Item = Record<string, unknown>;
type ItemKey = string | ((item: Item, index: number) => string | number);

const props = withDefaults(
  defineProps<{
    items: Item[];
    label: string;
    emptyText?: string;
    itemKey?: ItemKey;
  }>(),
  {
    emptyText: 'No records found.',
    itemKey: undefined,
  }
);

function resolveItemKey(item: Item, index: number): string | number {
  if (typeof props.itemKey === 'function') {
    return props.itemKey(item, index);
  }

  if (typeof props.itemKey === 'string') {
    const value = item[props.itemKey];
    return typeof value === 'string' || typeof value === 'number' ? value : index;
  }

  return index;
}
</script>

<style>
.mobile-table-list {
  display: grid;
  gap: 0.5rem;
}

.mobile-table-list__empty {
  padding: 1rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #f8fafc;
  color: #64748b;
  font-size: 0.875rem;
  text-align: center;
}

.mobile-record-row {
  padding: 0.625rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  background: #fff;
}

.mobile-record-row__topline,
.mobile-record-row__chips,
.mobile-record-row__chip {
  display: flex;
  align-items: center;
}

.mobile-record-row__topline {
  justify-content: space-between;
  gap: 0.75rem;
}

.mobile-record-row__chips {
  flex-wrap: wrap;
  gap: 0.375rem;
  min-width: 0;
}

.mobile-record-row__topline + .mobile-record-row__chips,
.mobile-record-row__chips + .mobile-record-row__chips {
  margin-top: 0.4rem;
}

.mobile-record-row__chip {
  gap: 0.25rem;
  min-height: 1.5rem;
  padding: 0.15rem 0.4rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 999px;
  background: #f8fafc;
  color: #0f172a;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
}

.mobile-record-row__details-button {
  flex: 0 0 auto;
  min-height: 1.85rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid #0d6efd;
  border-radius: 0.375rem;
  background: #fff;
  color: #0d6efd;
  font-size: 0.8125rem;
  font-weight: 600;
  line-height: 1.2;
}

.mobile-record-row__details-button:hover,
.mobile-record-row__details-button:focus {
  background: rgba(13, 110, 253, 0.08);
}

.mobile-record-row__fallback {
  color: #475569;
  font-size: 0.875rem;
  font-weight: 700;
}

.mobile-record-row__details {
  display: grid;
  gap: 0.375rem;
  margin: 0.875rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.mobile-record-row__detail {
  display: grid;
  grid-template-columns: minmax(6.5rem, 0.8fr) minmax(0, 1.2fr);
  gap: 0.5rem;
  align-items: start;
}

.mobile-record-row__detail--full {
  align-items: center;
}

.mobile-record-row__detail dt {
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
}

.mobile-record-row__detail dd {
  min-width: 0;
  margin: 0;
  color: #0f172a;
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}
</style>
