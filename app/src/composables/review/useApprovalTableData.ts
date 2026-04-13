// composables/review/useApprovalTableData.ts
/**
 * Composable for approval-table data (pagination, filters, loading).
 *
 * Phase E.E5 — extracted from `ApproveReview.vue` so the same pattern can
 * back the generic `ApprovalTableView` introduced in E.E6. The composable is
 * intentionally shape-agnostic at the row level (`Row extends Record<string, unknown>`)
 * so E.E6 can point it at reviews, statuses, or any other approval stream.
 *
 * This composable delegates all pagination plumbing to `useTableData` from
 * `@/composables/useTableData` and layers client-side filters on top:
 *  - text filter (free-text over fields marked filterable)
 *  - category filter (exact match)
 *  - user filter (exact match)
 *  - date range filter (review_date / status_date)
 *
 * E6 will either accept this composable as-is or wrap it behind a
 * resource-kind switch. Do not inline review semantics here.
 */

import { computed, ref, watch, type ComputedRef, type Ref } from 'vue';
import useTableData from '@/composables/useTableData';

export interface ApprovalRowLike extends Record<string, unknown> {
  // Lax constraint: rows carry some identifier + a date for range filtering.
  // Both are optional so the composable stays usable for other resource kinds.
  review_date?: string;
  status_date?: string;
  active_category?: string | number;
  review_user_name?: string;
  status_user_name?: string;
}

export interface ApprovalTableFilters {
  text: Ref<string | null>;
  category: Ref<string | null>;
  user: Ref<string | null>;
  dateStart: Ref<string | null>;
  dateEnd: Ref<string | null>;
}

export interface UseApprovalTableDataReturn<Row extends ApprovalRowLike> {
  // state from useTableData
  items: Ref<Row[]>;
  totalRows: Ref<number>;
  currentPage: Ref<number>;
  perPage: Ref<number>;
  pageOptions: Ref<number[]>;
  sortBy: ReturnType<typeof useTableData>['sortBy'];
  isBusy: Ref<boolean>;
  loading: Ref<boolean>;

  // filter state
  filters: ApprovalTableFilters;

  // filter options (derived from items)
  categoryOptions: ComputedRef<Array<{ value: string | null; text: string }>>;
  userOptions: ComputedRef<Array<{ value: string | null; text: string }>>;

  // filtered projection
  filteredItems: ComputedRef<Row[]>;

  // helpers
  clearAllFilters: () => void;
}

/**
 * Configuration for filter field mapping. Each approval stream names its
 * "category" and "user" and "date" fields slightly differently (reviews vs
 * statuses). Defaults match review rows.
 */
export interface ApprovalTableDataOptions {
  categoryField?: string;
  userField?: string;
  dateField?: string;
  initialSortBy?: { key: string; order: 'asc' | 'desc' }[];
  initialPerPage?: number;
}

export default function useApprovalTableData<Row extends ApprovalRowLike>(
  options: ApprovalTableDataOptions = {}
): UseApprovalTableDataReturn<Row> {
  const categoryField = options.categoryField ?? 'active_category';
  const userField = options.userField ?? 'review_user_name';
  const dateField = options.dateField ?? 'review_date';

  const table = useTableData({
    pageSizeInput: options.initialPerPage ?? 100,
  });

  // Seed sort if provided
  if (options.initialSortBy && options.initialSortBy.length > 0) {
    table.sortBy.value = options.initialSortBy;
  }

  // Narrow the generic item type via a typed alias (useTableData returns unknown[]).
  const items = table.items as unknown as Ref<Row[]>;

  const filters: ApprovalTableFilters = {
    text: ref<string | null>(null),
    category: ref<string | null>(null),
    user: ref<string | null>(null),
    dateStart: ref<string | null>(null),
    dateEnd: ref<string | null>(null),
  };

  const uniqueStrings = (values: Array<unknown>): string[] =>
    [...new Set(values)].filter((v): v is string => typeof v === 'string' && v.length > 0);

  const categoryOptions = computed(() => {
    const values = uniqueStrings(
      items.value.map((row) => (row as Record<string, unknown>)[categoryField])
    );
    return [
      { value: null, text: 'All Categories' },
      ...values.map((c) => ({ value: c, text: c })),
    ];
  });

  const userOptions = computed(() => {
    const values = uniqueStrings(
      items.value.map((row) => (row as Record<string, unknown>)[userField])
    );
    return [{ value: null, text: 'All Users' }, ...values.map((u) => ({ value: u, text: u }))];
  });

  const textMatches = (row: Row, needle: string): boolean => {
    const n = needle.toLowerCase();
    return Object.values(row).some((v) => {
      if (v == null) return false;
      return String(v).toLowerCase().includes(n);
    });
  };

  const filteredItems = computed<Row[]>(() => {
    let list = items.value;

    if (filters.category.value) {
      list = list.filter(
        (row) => (row as Record<string, unknown>)[categoryField] === filters.category.value
      );
    }
    if (filters.user.value) {
      list = list.filter(
        (row) => (row as Record<string, unknown>)[userField] === filters.user.value
      );
    }
    if (filters.dateStart.value || filters.dateEnd.value) {
      list = list.filter((row) => {
        const raw = (row as Record<string, unknown>)[dateField];
        if (typeof raw !== 'string' || raw.length === 0) return false;
        const rowDate = new Date(raw.substring(0, 10));
        if (filters.dateStart.value && rowDate < new Date(filters.dateStart.value)) {
          return false;
        }
        if (filters.dateEnd.value && rowDate > new Date(filters.dateEnd.value)) {
          return false;
        }
        return true;
      });
    }
    if (filters.text.value && filters.text.value.trim().length > 0) {
      const needle = filters.text.value.trim();
      list = list.filter((row) => textMatches(row, needle));
    }

    return list;
  });

  // Whenever a column filter changes, reset pagination and recompute totalRows
  // so pagination-component drives the right page count.
  watch(
    [filters.category, filters.user, filters.dateStart, filters.dateEnd],
    () => {
      table.currentPage.value = 1;
      table.totalRows.value = filteredItems.value.length;
    }
  );

  const clearAllFilters = () => {
    filters.text.value = null;
    filters.category.value = null;
    filters.user.value = null;
    filters.dateStart.value = null;
    filters.dateEnd.value = null;
  };

  return {
    items,
    totalRows: table.totalRows,
    currentPage: table.currentPage,
    perPage: table.perPage,
    pageOptions: table.pageOptions,
    sortBy: table.sortBy,
    isBusy: table.isBusy,
    loading: table.loading,

    filters,

    categoryOptions,
    userOptions,

    filteredItems,

    clearAllFilters,
  };
}
