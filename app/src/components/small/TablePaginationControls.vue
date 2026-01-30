<!-- components/small/TablePaginationControls.vue -->
<!--
  Pagination controls for server-side paginated tables.
  Uses Bootstrap-Vue-Next BPagination with Vue 3 Composition API.
-->
<template>
  <div>
    <!-- Page Size Selector -->
    <BInputGroup prepend="Per page" class="mb-1" size="sm">
      <BFormSelect
        id="per-page-select"
        :model-value="localPerPage"
        :options="pageOptions"
        size="sm"
        aria-label="Items per page"
        @update:model-value="handlePerPageUpdate"
      />
    </BInputGroup>

    <!-- Pagination -->
    <BPagination
      :model-value="localCurrentPage"
      :total-rows="totalRows"
      :per-page="localPerPage"
      align="fill"
      size="sm"
      class="my-0"
      limit="2"
      @update:model-value="handlePageUpdate"
    />
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
import { ref, watch } from 'vue';

// Props with TypeScript types
interface Props {
  totalRows?: number;
  initialPerPage?: number;
  pageOptions?: number[];
  currentPage?: number;
}

const props = withDefaults(defineProps<Props>(), {
  totalRows: 0,
  initialPerPage: 10,
  pageOptions: () => [10, 25, 50, 100],
  currentPage: 1,
});

// Emits
const emit = defineEmits<{
  'page-change': [page: number];
  'per-page-change': [perPage: number];
}>();

// Local state - initialize from prop
const localCurrentPage = ref(props.currentPage);
const localPerPage = ref(props.initialPerPage);

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
function handlePerPageUpdate(newPerPage: number | string) {
  const perPage = typeof newPerPage === 'string' ? parseInt(newPerPage, 10) : newPerPage;
  if (!isNaN(perPage) && perPage !== localPerPage.value) {
    localPerPage.value = perPage;
    // Reset to page 1 when changing page size
    localCurrentPage.value = 1;
    emit('per-page-change', perPage);
  }
}
</script>
