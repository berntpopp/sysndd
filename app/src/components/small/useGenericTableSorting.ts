// src/components/small/useGenericTableSorting.ts
//
// Sorting behavior extracted from GenericTable.vue (issue #346). Owns the
// legacy-string <-> array sortBy normalization plus the three BTable sort
// handlers (update:sort-by, head-clicked, sorted). Behavior is preserved
// byte-for-byte from the original single-file component so every consumer
// keeps emitting the same `update:sort-by` / `update-sort` payloads.

import { computed, type ComputedRef } from 'vue';
import type { SortBy } from '@/types/components';

/** sortBy accepts the legacy string form or the Bootstrap-Vue-Next array form. */
export type SortByProp = string | SortBy[];

/** Reactive props consumed by the sorting composable. */
export interface GenericTableSortingProps {
  sortBy: SortByProp;
  sortDesc: boolean;
}

/** A single sortable field descriptor as passed by BTable's head-clicked event. */
export interface SortableField {
  sortable?: boolean;
  [key: string]: unknown;
}

/** Sort context emitted by BTable's `sorted` event. */
export interface SortedContext {
  sortBy?: SortByProp;
  sortDesc?: boolean;
}

/** Payload emitted alongside `update-sort`. */
export interface UpdateSortPayload {
  sortBy: string;
  sortDesc: boolean;
}

/** Minimal emit signature matching Vue's component emit. */
export type GenericTableSortingEmit = (event: string, ...args: unknown[]) => void;

export interface UseGenericTableSortingReturn {
  localSortBy: ComputedRef<SortBy[]>;
  handleSortByUpdate: (newSortBy: SortBy[]) => void;
  handleHeadClicked: (key: string, field?: SortableField | null, _event?: Event) => void;
  handleSorted: (ctx?: SortedContext) => void;
}

/**
 * Converts sortBy to the Bootstrap-Vue-Next array format.
 * Handles both the legacy string format and the array format.
 */
export function normalizeSortBy(sortBy: SortByProp, sortDesc: boolean): SortBy[] {
  // If already an array, return as-is
  if (Array.isArray(sortBy)) {
    return sortBy;
  }
  // Convert string to array format for Bootstrap-Vue-Next
  if (typeof sortBy === 'string' && sortBy) {
    return [
      {
        key: sortBy,
        order: sortDesc ? 'desc' : 'asc',
      },
    ];
  }
  // Default to empty array
  return [];
}

/**
 * Provides the reactive `localSortBy` normalization plus the BTable sort event
 * handlers. Server-side sorting only: no local sorting is performed here.
 */
export function useGenericTableSorting(
  props: GenericTableSortingProps,
  emit: GenericTableSortingEmit
): UseGenericTableSortingReturn {
  const localSortBy = computed<SortBy[]>(() => normalizeSortBy(props.sortBy, props.sortDesc));

  function handleSortByUpdate(newSortBy: SortBy[]): void {
    emit('update:sort-by', newSortBy);
    if (newSortBy && newSortBy.length > 0 && newSortBy[0].key) {
      const sortByStr = newSortBy[0].key;
      const sortDescBool = newSortBy[0].order === 'desc';
      emit('update-sort', { sortBy: sortByStr, sortDesc: sortDescBool });
    }
  }

  /**
   * Handle column header click for server-side sorting.
   * Bootstrap-Vue-Next may not emit update:sort-by with no-local-sorting,
   * so we handle head-clicked directly to ensure sorting works.
   */
  function handleHeadClicked(key: string, field?: SortableField | null, _event?: Event): void {
    // Only handle sortable columns
    if (!field || field.sortable === false) {
      return;
    }

    // Determine current sort state and toggle
    const current = localSortBy.value;
    const currentSortKey = current.length > 0 ? current[0].key : null;
    const currentSortOrder = current.length > 0 ? current[0].order : 'asc';

    let newSortOrder: 'asc' | 'desc' = 'asc';
    if (currentSortKey === key) {
      // Same column - toggle order
      newSortOrder = currentSortOrder === 'asc' ? 'desc' : 'asc';
    }

    // Build and emit the new sort state
    const newSortBy: SortBy[] = [{ key, order: newSortOrder }];
    emit('update:sort-by', newSortBy);
    emit('update-sort', { sortBy: key, sortDesc: newSortOrder === 'desc' });
  }

  /**
   * Handle sorted event from BTable (Bootstrap-Vue-Next).
   * This event fires when sorting changes.
   */
  function handleSorted(ctx?: SortedContext): void {
    if (ctx && ctx.sortBy) {
      const sortKey =
        Array.isArray(ctx.sortBy) && ctx.sortBy.length > 0 ? ctx.sortBy[0].key : ctx.sortBy;
      const sortDesc =
        Array.isArray(ctx.sortBy) && ctx.sortBy.length > 0
          ? ctx.sortBy[0].order === 'desc'
          : ctx.sortDesc || false;
      emit('update-sort', { sortBy: sortKey as string, sortDesc });
    }
  }

  return { localSortBy, handleSortByUpdate, handleHeadClicked, handleSorted };
}
