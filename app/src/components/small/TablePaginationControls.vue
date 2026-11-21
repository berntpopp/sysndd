<!-- components/small/TablePaginationControls.vue -->
<!--
  Pagination controls for server-side paginated tables.
  Uses Bootstrap-Vue-Next BPagination with Vue 3 Composition API.
-->
<template>
  <div role="group" :aria-label="label">
    <!-- Page Size Selector -->
    <BInputGroup prepend="Per page" class="mb-1" size="sm">
      <BFormSelect
        id="per-page-select"
        :model-value="localPerPage"
        :options="pageOptions"
        size="sm"
        :aria-label="perPageLabel"
        @update:model-value="handlePerPageUpdate"
      />
    </BInputGroup>

    <!-- Pagination: a 3-page window plus "Page x of y" so the position is always
         stated; below sm only the active page number stays (see styles). A single
         page hides the buttons but keeps their height, so rows arriving after the
         count do not push the table down. The count sits left of the right-aligned
         buttons so its arrival does not move them. -->
    <div
      class="table-pager"
      :class="[
        `justify-content-${align === 'fill' ? 'between' : align}`,
        { 'table-pager--single': pageCount <= 1 },
      ]"
    >
      <span v-if="pageCount > 1" class="table-pager__count">
        Page {{ formatCount(localCurrentPage) }} of {{ formatCount(pageCount) }}
      </span>
      <BPagination
        :model-value="localCurrentPage"
        :total-rows="totalRows"
        :per-page="localPerPage"
        size="sm"
        class="my-0"
        limit="3"
        :aria-label="label"
        @update:model-value="handlePageUpdate"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * TablePaginationControls - Pagination controls for data tables
 *
 * Uses Bootstrap-Vue-Next BPagination with explicit one-way binding
 * and @update:model-value event for Vue 3 compatibility.
 *
 * The parent component should pass currentPage prop to keep pagination
 * synchronized with actual data state.
 */
import { computed, ref, watch } from 'vue';
import { formatCount } from './tableCountFormat';

// Props with TypeScript types
interface Props {
  totalRows?: number;
  initialPerPage?: number;
  pageOptions?: number[];
  currentPage?: number;
  label?: string;
  perPageLabel?: string;
  align?: 'start' | 'center' | 'end' | 'fill';
}

const props = withDefaults(defineProps<Props>(), {
  totalRows: 0,
  initialPerPage: 10,
  pageOptions: () => [10, 25, 50, 100],
  currentPage: 1,
  label: 'Table pagination',
  perPageLabel: 'Items per page',
  align: 'end',
});

// Emits
const emit = defineEmits<{
  'page-change': [page: number];
  'per-page-change': [perPage: number];
}>();

// Local state - initialize from prop
const localCurrentPage = ref(props.currentPage);
const localPerPage = ref(props.initialPerPage);

const pageCount = computed(() => Math.ceil(props.totalRows / (localPerPage.value || 1)));

// Watch for parent's currentPage changes and sync local state
watch(
  () => props.currentPage,
  (newPage) => {
    if (newPage !== localCurrentPage.value) {
      localCurrentPage.value = newPage;
    }
  }
);

/**
 * Handle page update from BPagination
 * Always emit to parent - let parent decide if reload is needed
 */
function handlePageUpdate(newPage: number) {
  // Always update local state and emit - parent handles the logic
  localCurrentPage.value = newPage;
  emit('page-change', newPage);
}

/**
 * Handle per-page update from BFormSelect
 */
function handlePerPageUpdate(newPerPage: number | number[]) {
  const perPage = Array.isArray(newPerPage) ? newPerPage[0] : newPerPage;
  if (!isNaN(perPage) && perPage !== localPerPage.value) {
    localPerPage.value = perPage;
    // Reset to page 1 when changing page size
    localCurrentPage.value = 1;
    emit('per-page-change', perPage);
  }
}
</script>

<style scoped>
.table-pager {
  display: flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}

.table-pager--single :deep(.pagination) {
  visibility: hidden;
}

.table-pager :deep(.pagination) {
  flex-wrap: nowrap;
  margin-bottom: 0;
}

/* Phones: first/prev, the active page, next/last, and the page count. bvn's own
   below-sm hiding leaves gaps ("1 3"); this keeps one predictable pattern. */
@media (max-width: 575.98px) {
  .table-pager :deep(.page-item:not(.active):not(:nth-child(-n + 2)):not(:nth-last-child(-n + 2))) {
    display: none;
  }
}

.table-pager__count {
  flex-shrink: 0;
  color: var(--text-secondary, #526070);
  font-size: 0.75rem;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}
</style>
