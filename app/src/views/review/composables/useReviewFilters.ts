// app/src/views/review/composables/useReviewFilters.ts
//
// W6 of v11.1 finish-hardening — filter-state composable for `Review.vue`.
//
// Owns three filter dimensions plus the derived options/availability
// computeds the template binds against:
//
//   - free-text search (`filter`) — drives BTable's stock filter prop;
//     reactive but applied INSIDE BTable, not by `filteredItems` here.
//     (BTable owns substring matching across the configured fields.)
//   - column filters (`categoryFilter`, `userFilter`) — applied AND-style
//     inside `filteredItems`. Drop-down options derived from unique
//     non-null values in the input list.
//   - quick filters (`pending` / `submitted` / `needsStatus`) — boolean
//     toggles applied AND-style on top of the column filters.
//
// Does NOT own data loading (see `useReviewData`), modal state (see
// `useReviewModals`), or mutations (see `useReviewActions`).

import { computed, reactive, ref, type ComputedRef, type Ref } from 'vue';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Subset of re-review-row fields the filter logic actually inspects. */
export interface FilterableRow {
  category?: string | null;
  review_user_name?: string | null;
  re_review_review_saved?: number | null;
  re_review_status_saved?: number | null;
  status_id?: number | null;
  approved?: number | null;
  [key: string]: unknown;
}

export type QuickFilterKey = 'pending' | 'submitted' | 'needsStatus';

export interface QuickFilterDef {
  key: QuickFilterKey;
  label: string;
}

export interface DropdownOption<T = unknown> {
  value: T;
  text: string;
}

export interface UseReviewFilters<T extends FilterableRow> {
  // Free-text + sort hooks (BTable bindings)
  filter: Ref<string | null>;
  filterOn: Ref<string[]>;
  sortBy: Ref<Array<{ key: string; order: string }>>;

  // Column filters
  categoryFilter: Ref<string | null>;
  userFilter: Ref<string | null>;

  // Quick filters
  quickFilters: Record<QuickFilterKey, boolean>;
  quickFilterDefs: QuickFilterDef[];
  activeQuickFilters: ComputedRef<QuickFilterDef[]>;
  availableQuickFilters: ComputedRef<QuickFilterDef[]>;
  addQuickFilter: (key: QuickFilterKey) => void;
  removeQuickFilter: (key: QuickFilterKey) => void;

  // Derived dropdown options
  categoryFilterOptions: ComputedRef<DropdownOption<string | null>[]>;
  userFilterOptions: ComputedRef<DropdownOption<string | null>[]>;

  // The bound filter result
  filteredItems: ComputedRef<T[]>;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const QUICK_FILTER_DEFS: readonly QuickFilterDef[] = [
  { key: 'pending', label: 'Pending Review' },
  { key: 'submitted', label: 'Submitted' },
  { key: 'needsStatus', label: 'Needs Status' },
] as const;

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

export function useReviewFilters<T extends FilterableRow>(source: Ref<T[]>): UseReviewFilters<T> {
  // BTable bindings
  const filter = ref<string | null>(null);
  const filterOn = ref<string[]>([]);
  const sortBy = ref<Array<{ key: string; order: string }>>([{ key: 'entity_id', order: 'asc' }]);

  // Column filters
  const categoryFilter = ref<string | null>(null);
  const userFilter = ref<string | null>(null);

  // Quick filters
  const quickFilters = reactive<Record<QuickFilterKey, boolean>>({
    pending: false,
    submitted: false,
    needsStatus: false,
  });
  const quickFilterDefs: QuickFilterDef[] = [...QUICK_FILTER_DEFS];

  function addQuickFilter(key: QuickFilterKey): void {
    quickFilters[key] = true;
  }

  function removeQuickFilter(key: QuickFilterKey): void {
    quickFilters[key] = false;
  }

  const activeQuickFilters = computed(() => quickFilterDefs.filter((qf) => quickFilters[qf.key]));
  const availableQuickFilters = computed(() =>
    quickFilterDefs.filter((qf) => !quickFilters[qf.key])
  );

  // Derived dropdown options — null-safe Set dedup, then prepend a sentinel.
  const categoryFilterOptions = computed<DropdownOption<string | null>[]>(() => {
    const categories = [...new Set(source.value.map((item) => item.category))].filter(
      (v): v is string => Boolean(v)
    );
    return [
      { value: null, text: 'All Categories' },
      ...categories.map((cat) => ({ value: cat, text: cat })),
    ];
  });

  const userFilterOptions = computed<DropdownOption<string | null>[]>(() => {
    const users = [...new Set(source.value.map((item) => item.review_user_name))].filter(
      (v): v is string => Boolean(v)
    );
    return [{ value: null, text: 'All Users' }, ...users.map((u) => ({ value: u, text: u }))];
  });

  const filteredItems = computed<T[]>(() => {
    let result = source.value;

    if (categoryFilter.value) {
      result = result.filter((item) => item.category === categoryFilter.value);
    }
    if (userFilter.value) {
      result = result.filter((item) => item.review_user_name === userFilter.value);
    }
    if (quickFilters.pending) {
      result = result.filter((item) => !item.re_review_review_saved);
    }
    if (quickFilters.submitted) {
      result = result.filter((item) => item.re_review_review_saved && !item.approved);
    }
    if (quickFilters.needsStatus) {
      result = result.filter((item) => !item.status_id || !item.re_review_status_saved);
    }

    return result;
  });

  return {
    filter,
    filterOn,
    sortBy,
    categoryFilter,
    userFilter,
    quickFilters,
    quickFilterDefs,
    activeQuickFilters,
    availableQuickFilters,
    addQuickFilter,
    removeQuickFilter,
    categoryFilterOptions,
    userFilterOptions,
    filteredItems,
  };
}

export default useReviewFilters;
