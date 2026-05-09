<template>
  <div class="panel-controls" :aria-busy="busy ? 'true' : 'false'">
    <div class="panel-controls__primary">
      <label class="panel-controls__field">
        <span>Category</span>
        <BFormSelect
          :model-value="selectedCategory"
          :options="categories"
          text-field="value"
          size="sm"
          :disabled="busy"
          @update:model-value="emitString('update:category', $event)"
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
          @update:model-value="emitString('update:inheritance', $event)"
        />
      </label>

      <label class="panel-controls__field panel-controls__field--sort">
        <span>Sort</span>
        <span class="panel-controls__sort-group">
          <BFormSelect
            :model-value="sortField"
            :options="columns"
            text-field="value"
            value-field="value"
            size="sm"
            :disabled="busy"
            @update:model-value="updateSortField"
          />
          <BFormSelect
            :model-value="sortOrder"
            :options="sortOrderOptions"
            size="sm"
            :disabled="busy"
            aria-label="Sort order"
            @update:model-value="updateSortOrder"
          />
        </span>
      </label>

      <label class="panel-controls__field">
        <span>Rows</span>
        <BFormSelect
          :model-value="perPage"
          :options="pageOptions"
          size="sm"
          :disabled="busy"
          @update:model-value="emit('update:per-page', $event as string | number)"
        />
      </label>

      <button
        class="panel-controls__advanced-toggle"
        type="button"
        :aria-expanded="showColumns ? 'true' : 'false'"
        aria-controls="panel-controls-columns"
        :disabled="busy"
        @click="showColumns = !showColumns"
      >
        <i class="bi bi-layout-three-columns" aria-hidden="true" />
        <span>Columns</span>
        <strong>{{ selectedColumns.length }}/{{ columns.length }}</strong>
      </button>
    </div>

    <div v-if="showColumns" id="panel-controls-columns" class="panel-controls__columns">
      <div class="panel-controls__columns-head">
        <span>Visible columns</span>
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
import { computed, ref } from 'vue';

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
const showColumns = ref(false);

const sortField = computed(() => props.sortBy[0]?.key || 'symbol');
const sortOrder = computed(() => props.sortBy[0]?.order || 'asc');

type SelectValue = string | string[] | number | null;

function normalizeSelectValue(value: SelectValue, fallback: string): string {
  if (Array.isArray(value)) {
    return value[0] || fallback;
  }

  if (value === null || value === undefined || value === '') {
    return fallback;
  }

  return String(value);
}

function emitString(event: 'update:category' | 'update:inheritance', value: SelectValue) {
  const normalized = normalizeSelectValue(value, 'All');
  if (event === 'update:category') {
    emit('update:category', normalized);
  } else {
    emit('update:inheritance', normalized);
  }
}

function updateSortField(value: SelectValue) {
  emit('update:sort', [{ key: normalizeSelectValue(value, 'symbol'), order: sortOrder.value }]);
}

function updateSortOrder(value: SelectValue) {
  const order = normalizeSelectValue(value, 'asc') === 'desc' ? 'desc' : 'asc';
  emit('update:sort', [{ key: sortField.value, order }]);
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
  gap: 0.5rem;
}

.panel-controls__primary {
  display: grid;
  grid-template-columns:
    minmax(8rem, 1fr) minmax(8rem, 1fr) minmax(13rem, 1.35fr) minmax(5rem, 0.55fr)
    auto;
  gap: 0.5rem;
  align-items: end;
}

.panel-controls__field {
  display: grid;
  gap: 0.2rem;
  margin: 0;
  color: #334155;
  font-size: 0.72rem;
  font-weight: 700;
}

.panel-controls__sort-group {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 5.25rem;
  gap: 0.35rem;
}

.panel-controls__advanced-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-height: 1.95rem;
  padding: 0.25rem 0.6rem;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 0.45rem;
  background: #fff;
  color: #334155;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1;
}

.panel-controls__advanced-toggle:hover,
.panel-controls__advanced-toggle:focus {
  border-color: rgba(13, 110, 253, 0.35);
  background: #f8fafc;
  color: #0f172a;
}

.panel-controls__advanced-toggle strong {
  color: #0d6efd;
  font-weight: 800;
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
  .panel-controls__primary {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .panel-controls__field--sort {
    grid-column: span 2;
  }
}

@media (max-width: 575.98px) {
  .panel-controls__primary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .panel-controls__field--sort {
    grid-column: 1 / -1;
  }

  .panel-controls__advanced-toggle {
    width: 100%;
  }
}
</style>
