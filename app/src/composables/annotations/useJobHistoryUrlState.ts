// composables/annotations/useJobHistoryUrlState.ts
/**
 * URL query-state helpers for the Manage Annotations "Job History" table.
 * Extracted from the view (Phase E.E4) so the view can focus on
 * orchestration.
 *
 * Reads from `vue-router`'s `route.query` on init and writes back via
 * `history.replaceState` (same as the original view — we do not want a
 * new history entry for every pagination change).
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';
import type { RouteLocationNormalizedLoaded } from 'vue-router';

export interface JobHistoryUrlStateOptions {
  defaultPageSize?: number;
  defaultSortField?: string;
  defaultSortOrder?: 'asc' | 'desc';
  pageSizeOptions?: number[];
}

export interface JobHistoryUrlStateReturn {
  currentPage: Ref<number>;
  pageSize: Ref<number>;
  sortField: Ref<string>;
  sortOrder: Ref<'asc' | 'desc'>;
  searchFilter: Ref<string>;
  pageSizeOptions: number[];
  sortBy: ComputedRef<Array<{ key: string; order: 'asc' | 'desc' }>>;
  initFromUrl: () => void;
  updateUrl: () => void;
  handlePageChange: (page: number) => void;
  handlePageSizeChange: (size: number) => void;
  handleSortUpdate: (event: { sortBy: string; sortDesc: boolean }) => void;
  handleSearchChange: (value: string) => void;
  clearSearch: () => void;
  clearAllFilters: () => void;
}

export function useJobHistoryUrlState(
  route: RouteLocationNormalizedLoaded,
  options: JobHistoryUrlStateOptions = {}
): JobHistoryUrlStateReturn {
  const defaultPageSize = options.defaultPageSize ?? 10;
  const defaultSortField = options.defaultSortField ?? 'submitted_at';
  const defaultSortOrder: 'asc' | 'desc' = options.defaultSortOrder ?? 'desc';
  const pageSizeOptions = options.pageSizeOptions ?? [10, 25, 50, 100];

  const currentPage = ref(1);
  const pageSize = ref(defaultPageSize);
  const sortField = ref(defaultSortField);
  const sortOrder = ref<'asc' | 'desc'>(defaultSortOrder);
  const searchFilter = ref('');

  const sortBy = computed(() => [{ key: sortField.value, order: sortOrder.value }]);

  function initFromUrl(): void {
    const query = route.query;
    if (query.page) currentPage.value = parseInt(String(query.page), 10) || 1;
    if (query.page_size) {
      const ps = parseInt(String(query.page_size), 10);
      if (pageSizeOptions.includes(ps)) pageSize.value = ps;
    }
    if (query.sort) {
      const sortStr = String(query.sort);
      if (sortStr.startsWith('-')) {
        sortField.value = sortStr.slice(1);
        sortOrder.value = 'desc';
      } else if (sortStr.startsWith('+')) {
        sortField.value = sortStr.slice(1);
        sortOrder.value = 'asc';
      } else {
        sortField.value = sortStr;
        sortOrder.value = 'asc';
      }
    }
    if (query.search) searchFilter.value = String(query.search);
  }

  function updateUrl(): void {
    const query: Record<string, string> = {};
    if (currentPage.value !== 1) query.page = String(currentPage.value);
    if (pageSize.value !== defaultPageSize) query.page_size = String(pageSize.value);
    const prefix = sortOrder.value === 'desc' ? '-' : '+';
    if (sortField.value !== defaultSortField || sortOrder.value !== defaultSortOrder) {
      query.sort = `${prefix}${sortField.value}`;
    }
    if (searchFilter.value.trim()) query.search = searchFilter.value.trim();
    const url = new URL(window.location.href);
    url.search = new URLSearchParams(query).toString();
    window.history.replaceState({}, '', url.toString());
  }

  function handlePageChange(page: number): void {
    currentPage.value = page;
    updateUrl();
  }

  function handlePageSizeChange(size: number): void {
    pageSize.value = size;
    currentPage.value = 1;
    updateUrl();
  }

  function handleSortUpdate(event: { sortBy: string; sortDesc: boolean }): void {
    sortField.value = event.sortBy;
    sortOrder.value = event.sortDesc ? 'desc' : 'asc';
    updateUrl();
  }

  function handleSearchChange(value: string): void {
    searchFilter.value = value;
    currentPage.value = 1;
    updateUrl();
  }

  function clearSearch(): void {
    searchFilter.value = '';
    currentPage.value = 1;
    updateUrl();
  }

  function clearAllFilters(): void {
    searchFilter.value = '';
    sortField.value = defaultSortField;
    sortOrder.value = defaultSortOrder;
    currentPage.value = 1;
    pageSize.value = defaultPageSize;
    updateUrl();
  }

  return {
    currentPage,
    pageSize,
    sortField,
    sortOrder,
    searchFilter,
    pageSizeOptions,
    sortBy,
    initFromUrl,
    updateUrl,
    handlePageChange,
    handlePageSizeChange,
    handleSortUpdate,
    handleSearchChange,
    clearSearch,
    clearAllFilters,
  };
}
