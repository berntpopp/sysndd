<template>
  <div class="panel-controls" :aria-busy="busy ? 'true' : 'false'">
    <div class="panel-controls__row">
      <label class="panel-controls__field">
        <span>Category</span>
        <BFormSelect
          :model-value="selectedCategory"
          :options="categories"
          text-field="value"
          size="sm"
          :disabled="busy"
          @update:model-value="emit('update:category', String($event))"
        />
      </label>

      <label class="panel-controls__field">
        <span>Inheritance</span>
        <BFormSelect
          :model-value="selectedInheritance"
          :options="inheritance"
          text-field="value"
          size="sm"
          :disabled="busy"
          @update:model-value="emit('update:inheritance', String($event))"
        />
      </label>

      <label class="panel-controls__field">
        <span>Sort field</span>
        <BFormSelect
          :model-value="sortField"
          :options="columns"
          text-field="value"
          value-field="value"
          size="sm"
          :disabled="busy"
          @update:model-value="updateSortField"
        />
      </label>

      <label class="panel-controls__field panel-controls__field--small">
        <span>Order</span>
        <BFormSelect
          :model-value="sortOrder"
          :options="sortOrderOptions"
          size="sm"
          :disabled="busy"
          @update:model-value="updateSortOrder"
        />
      </label>

      <label class="panel-controls__field panel-controls__field--small">
        <span>Rows</span>
        <BFormSelect
          :model-value="perPage"
          :options="pageOptions"
          size="sm"
          :disabled="busy"
          @update:model-value="emit('update:per-page', $event as string | number)"
        />
      </label>
    </div>

    <div class="panel-controls__columns">
      <div class="panel-controls__columns-head">
        <span>Columns</span>
        <span>{{ selectedColumns.length }}/{{ columns.length }}</span>
      </div>
      <div class="panel-controls__checks">
        <label v-for="column in columns" :key="column.value" class="panel-controls__check">
          <input
            type="checkbox"
            :value="column.value"
            :checked="selectedColumns.includes(column.value)"
            :disabled="busy || requiredColumns.includes(column.value)"
            @change="toggleColumn(column.value)"
          />
          <span>{{ column.value }}</span>
        </label>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

interface Option {
  value: string;
}

const props = defineProps<{
  categories: Option[];
  inheritance: Option[];
  columns: Option[];
  selectedCategory: string | null;
  selectedInheritance: string | null;
  selectedColumns: string[];
  sortBy: Array<{ key: string; order: 'asc' | 'desc' }>;
  perPage: number;
  pageOptions: number[];
  busy?: boolean;
}>();

const emit = defineEmits<{
  (event: 'update:category', value: string): void;
  (event: 'update:inheritance', value: string): void;
  (event: 'update:columns', value: string[]): void;
  (event: 'update:sort', value: Array<{ key: string; order: 'asc' | 'desc' }>): void;
  (event: 'update:per-page', value: string | number): void;
}>();

const requiredColumns = ['symbol'];
const sortOrderOptions = [
  { value: 'asc', text: 'A-Z' },
  { value: 'desc', text: 'Z-A' },
];

const sortField = computed(() => props.sortBy[0]?.key || 'symbol');
const sortOrder = computed(() => props.sortBy[0]?.order || 'asc');

function updateSortField(value: string) {
  emit('update:sort', [{ key: value || 'symbol', order: sortOrder.value }]);
}

function updateSortOrder(value: 'asc' | 'desc') {
  emit('update:sort', [{ key: sortField.value, order: value || 'asc' }]);
}

function toggleColumn(value: string) {
  const selected = new Set(props.selectedColumns);
  if (selected.has(value)) {
    selected.delete(value);
  } else {
    selected.add(value);
  }
  requiredColumns.forEach((required) => selected.add(required));
  emit('update:columns', Array.from(selected));
}
</script>

<style scoped>
.panel-controls {
  display: grid;
  gap: 0.75rem;
}

.panel-controls__row {
  display: grid;
  grid-template-columns: repeat(5, minmax(8rem, 1fr));
  gap: 0.65rem;
  align-items: end;
}

.panel-controls__field {
  display: grid;
  gap: 0.25rem;
  margin: 0;
  color: #334155;
  font-size: 0.78rem;
  font-weight: 700;
}

.panel-controls__field--small {
  min-width: 6rem;
}

.panel-controls__columns {
  display: grid;
  gap: 0.4rem;
  padding: 0.55rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  background: #fff;
}

.panel-controls__columns-head {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  color: #334155;
  font-size: 0.78rem;
  font-weight: 800;
}

.panel-controls__checks {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.panel-controls__check {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  margin: 0;
  padding: 0.3rem 0.45rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 999px;
  background: #f8fafc;
  color: #334155;
  font-size: 0.76rem;
  font-weight: 700;
}

.panel-controls__check input {
  margin: 0;
}

@media (max-width: 991.98px) {
  .panel-controls__row {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 575.98px) {
  .panel-controls__row {
    grid-template-columns: 1fr;
  }
}
</style>
