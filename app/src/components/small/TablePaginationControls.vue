<!-- components/small/TablePaginationControls.vue -->
<!--
  Pagination controls for server-side paginated tables.
  Uses Bootstrap-Vue-Next BPagination with Vue 3 Composition API.
-->
<template>
  <div>
    <!-- Page Size Selector -->
    <BInputGroup
      prepend="Per page"
      class="mb-1"
      size="sm"
    >
      <BFormSelect
        id="per-page-select"
        :model-value="localPerPage"
        :options="pageOptions"
        size="sm"
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
 */
import { ref } from 'vue';

// Props with TypeScript types
interface Props {
  totalRows: number;
  initialPerPage?: number;
  pageOptions?: number[];
}

const props = withDefaults(defineProps<Props>(), {
  totalRows: 0,
  initialPerPage: 10,
  pageOptions: () => [10, 25, 50, 100],
});

// Emits
const emit = defineEmits<{
  'page-change': [page: number];
  'per-page-change': [perPage: number];
}>();

// Local state
const localCurrentPage = ref(1);
const localPerPage = ref(props.initialPerPage);

/**
 * Handle page update from BPagination
 */
function handlePageUpdate(newPage: number) {
  if (newPage !== localCurrentPage.value) {
    localCurrentPage.value = newPage;
    emit('page-change', newPage);
  }
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
