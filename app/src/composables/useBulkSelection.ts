import { ref, computed } from 'vue';
import type { Ref, ComputedRef } from 'vue';

export interface BulkSelectionReturn<T = number> {
  selectedIds: Ref<Set<T>>;
  selectionCount: ComputedRef<number>;
  isSelected: (id: T) => boolean;
  toggleSelection: (id: T) => boolean; // Returns false if limit reached
  selectMultiple: (ids: T[]) => number; // Returns count of newly selected
  clearSelection: () => void;
  getSelectedArray: () => T[];
}

/**
 * Composable for Set-based cross-page selection tracking
 *
 * Manages bulk selection state using a reactive Set for efficient lookups
 * and maintains selection across pagination. Enforces a configurable maximum
 * selection limit to prevent performance issues with bulk operations.
 *
 * Based on the NetworkVisualization.vue Set pattern from v5.0.
 *
 * @param maxSelection - Maximum number of items that can be selected (default: 20)
 * @returns Reactive selection state and methods
 *
 * @example
 * const { selectedIds, selectionCount, toggleSelection, clearSelection } = useBulkSelection(20);
 *
 * // In template: @click="toggleSelection(user.id)"
 * // Check limit: if (!toggleSelection(id)) { toast.error('Maximum 20 users') }
 */
export function useBulkSelection<T = number>(
  maxSelection: number = 20
): BulkSelectionReturn<T> {
  const selectedIds = ref(new Set<T>()) as Ref<Set<T>>;

  const selectionCount = computed(() => selectedIds.value.size);

  const isSelected = (id: T): boolean => selectedIds.value.has(id);

  const toggleSelection = (id: T): boolean => {
    const newSet = new Set(selectedIds.value);

    if (newSet.has(id)) {
      newSet.delete(id);
      selectedIds.value = newSet;
      return true;
    }

    // Check limit before adding
    if (newSet.size >= maxSelection) {
      return false; // Limit reached, caller should show warning
    }

    newSet.add(id);
    selectedIds.value = newSet;
    return true;
  };

  const selectMultiple = (ids: T[]): number => {
    const newSet = new Set(selectedIds.value);
    let added = 0;

    for (const id of ids) {
      if (newSet.size >= maxSelection) break;
      if (!newSet.has(id)) {
        newSet.add(id);
        added++;
      }
    }

    selectedIds.value = newSet;
    return added;
  };

  const clearSelection = (): void => {
    selectedIds.value = new Set();
  };

  const getSelectedArray = (): T[] => Array.from(selectedIds.value);

  return {
    selectedIds,
    selectionCount,
    isSelected,
    toggleSelection,
    selectMultiple,
    clearSelection,
    getSelectedArray,
  };
}

export default useBulkSelection;
