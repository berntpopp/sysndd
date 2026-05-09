<template>
  <div class="mobile-table-list" role="list" :aria-label="label">
    <div v-if="items.length === 0" class="mobile-table-list__empty">
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
type Item = Record<string, unknown>
type ItemKey = string | ((item: Item, index: number) => string | number)

const props = withDefaults(
  defineProps<{
    items: Item[]
    label: string
    emptyText?: string
    itemKey?: ItemKey
  }>(),
  {
    emptyText: 'No records found.',
    itemKey: undefined,
  },
)

function resolveItemKey(item: Item, index: number): string | number {
  if (typeof props.itemKey === 'function') {
    return props.itemKey(item, index)
  }

  if (typeof props.itemKey === 'string') {
    const value = item[props.itemKey]
    return typeof value === 'string' || typeof value === 'number' ? value : index
  }

  return index
}
</script>

<style scoped>
.mobile-table-list {
  display: grid;
  gap: 0.75rem;
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
</style>
