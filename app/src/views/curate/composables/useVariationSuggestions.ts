// app/src/views/curate/composables/useVariationSuggestions.ts
/**
 * #612 Phase 6 — state for the cross-entity variation-ontology curation queue.
 *
 * WHAT THE QUEUE IS FOR
 * ---------------------
 * The February 2026 backfill wrote 8,083 machine-derived assertions, ~1,981 of
 * them resting on 1-star ClinVar evidence alone. Every one is served on a public
 * entity page today and none has been read by a curator. This page is what makes
 * that backlog workable.
 *
 * THE ACTION ASYMMETRY (read this before changing `canConfirm`/`canDismiss`)
 * -------------------------------------------------------------------------
 * The public entity read filters provenance to
 * `state IN ('active_unconfirmed','confirmed')`. Writing `rejected` onto an
 * `active_unconfirmed` assertion drops it out of that filter WHILE THE TERM IS
 * STILL SERVED, so the card would render it as CURATOR-AUTHORED — the exact
 * fabrication #608 exists to prevent. So:
 *
 *   Confirm  offered when  state === 'active_unconfirmed' && served
 *   Dismiss  offered when  state === 'suggested'          && !served
 *
 * The other direction of each pair has to ADD or REMOVE a curated term, which is
 * a review write: the row links out to the entity for that.
 *
 * These predicates decide what to OFFER. The server re-derives both under a row
 * lock before it writes, so a stale row here produces a reported `skipped`
 * entry, never a wrong write.
 */

import { computed, ref, type ComputedRef, type Ref } from 'vue';

import {
  confirmVariationSuggestions,
  dismissVariationSuggestions,
  listVariationSuggestions,
  type VariationSuggestionApplyResult,
  type VariationSuggestionRow,
  type VariationSuggestionSort,
  type VariationSuggestionState,
} from '@/api/curate_variation';

export interface VariationSuggestionFilters {
  state: VariationSuggestionState | null;
  source_key: string | null;
  max_strength: number | null;
  moved: boolean;
  q: string;
}

/** Which bulk action a selection permits, if any. */
export type SelectionKind = 'confirm' | 'dismiss' | 'mixed' | 'none';

export interface UseVariationSuggestionsOptions {
  onError?: (message: string) => void;
}

const emptyFilters = (): VariationSuggestionFilters => ({
  state: null,
  source_key: null,
  max_strength: null,
  moved: false,
  q: '',
});

/** Identity key. ALWAYS carries the modifier — present and absent are distinct. */
export function suggestionRowKey(row: VariationSuggestionRow): string {
  return `${row.entity_id}:${row.vario_id}:${row.modifier_id}`;
}

/** Confirm is safe only for a term the entity actually serves. */
export function canConfirmRow(row: VariationSuggestionRow): boolean {
  return row.state === 'active_unconfirmed' && row.served;
}

/** Dismiss is safe only for a term the entity does NOT serve. */
export function canDismissRow(row: VariationSuggestionRow): boolean {
  return row.state === 'suggested' && !row.served;
}

/**
 * Summarise a batch result for a curator.
 *
 * Every skip is named with its reason. A silent partial success on a provenance
 * surface is the failure mode this whole feature exists to avoid, so "10 of 12
 * confirmed — 2 no longer served" is the honest sentence, not "done".
 */
export function describeApplyResult(result: VariationSuggestionApplyResult): string {
  const verb = `${result.applied} of ${result.requested}`;
  if (result.skipped.length === 0) return `${verb} applied.`;

  const counts = new Map<string, number>();
  result.skipped.forEach((skip) => {
    counts.set(skip.reason, (counts.get(skip.reason) ?? 0) + 1);
  });
  const reasons = [...counts.entries()]
    .map(([reason, count]) => `${count} ${reason.replace(/_/g, ' ')}`)
    .join(', ');
  return `${verb} applied — skipped: ${reasons}.`;
}

export default function useVariationSuggestions(options: UseVariationSuggestionsOptions = {}) {
  const rows = ref<VariationSuggestionRow[]>([]);
  const total = ref(0);
  const page = ref(1);
  const pageSize = ref(25);
  const loading = ref(false);
  const filters = ref<VariationSuggestionFilters>(emptyFilters());
  const sort = ref<VariationSuggestionSort>('strength_desc');
  const selected = ref<string[]>([]);
  const lastResult = ref<VariationSuggestionApplyResult | null>(null);

  const reportError = (message: string): void => {
    if (options.onError) options.onError(message);
  };

  const selectedRows: ComputedRef<VariationSuggestionRow[]> = computed(() => {
    const keys = new Set(selected.value);
    return rows.value.filter((row) => keys.has(suggestionRowKey(row)));
  });

  /**
   * A selection is actionable only when every row permits the SAME action.
   * A mixed selection offers neither, rather than silently applying one to the
   * rows that happen to qualify.
   */
  const selectionKind: ComputedRef<SelectionKind> = computed(() => {
    const chosen = selectedRows.value;
    if (chosen.length === 0) return 'none';
    if (chosen.every(canConfirmRow)) return 'confirm';
    if (chosen.every(canDismissRow)) return 'dismiss';
    return 'mixed';
  });

  const totalPages = computed(() =>
    Math.max(1, Math.ceil(total.value / Math.max(1, pageSize.value)))
  );

  async function load(): Promise<void> {
    loading.value = true;
    try {
      const response = await listVariationSuggestions({
        state: filters.value.state ?? undefined,
        source_key: filters.value.source_key ?? undefined,
        max_strength: filters.value.max_strength ?? undefined,
        moved: filters.value.moved,
        q: filters.value.q.trim() || undefined,
        sort: sort.value,
        page: page.value,
        page_size: pageSize.value,
      });
      rows.value = response.data;
      total.value = response.meta.total;
      // A selection that survived a reload would let a bulk action target rows
      // the curator can no longer see.
      selected.value = [];
    } catch (error) {
      rows.value = [];
      total.value = 0;
      reportError(error instanceof Error ? error.message : 'Could not load suggestions.');
    } finally {
      loading.value = false;
    }
  }

  /** Reset to page 1 and reload — any filter change changes the result set. */
  async function applyFilters(): Promise<void> {
    page.value = 1;
    await load();
  }

  async function resetFilters(): Promise<void> {
    filters.value = emptyFilters();
    sort.value = 'strength_desc';
    await applyFilters();
  }

  async function goToPage(next: number): Promise<void> {
    const target = Math.min(Math.max(1, next), totalPages.value);
    if (target === page.value) return;
    page.value = target;
    await load();
  }

  function toggleRow(row: VariationSuggestionRow): void {
    const key = suggestionRowKey(row);
    selected.value = selected.value.includes(key)
      ? selected.value.filter((item) => item !== key)
      : [...selected.value, key];
  }

  /** Select every row on this page that permits `kind`. */
  function selectAllEligible(kind: 'confirm' | 'dismiss'): void {
    const predicate = kind === 'confirm' ? canConfirmRow : canDismissRow;
    selected.value = rows.value.filter(predicate).map(suggestionRowKey);
  }

  function clearSelection(): void {
    selected.value = [];
  }

  async function applySelected(
    action: 'confirm' | 'dismiss'
  ): Promise<VariationSuggestionApplyResult | null> {
    const items = selectedRows.value.map((row) => ({
      entity_id: row.entity_id,
      vario_id: row.vario_id,
      modifier_id: row.modifier_id,
    }));
    if (items.length === 0) return null;

    loading.value = true;
    try {
      const result =
        action === 'confirm'
          ? await confirmVariationSuggestions(items)
          : await dismissVariationSuggestions(items);
      lastResult.value = result;
      return result;
    } catch (error) {
      reportError(error instanceof Error ? error.message : `Could not ${action} the selection.`);
      return null;
    } finally {
      loading.value = false;
      // Reload regardless: an applied row leaves the queue, and a skipped one
      // needs its fresh server-side state before it can be acted on again.
      await load();
    }
  }

  const confirmSelected = (): Promise<VariationSuggestionApplyResult | null> =>
    applySelected('confirm');
  const dismissSelected = (): Promise<VariationSuggestionApplyResult | null> =>
    applySelected('dismiss');
  /** Bulk-apply whichever action the current selection permits. */
  const confirmDismiss = (
    action: 'confirm' | 'dismiss'
  ): Promise<VariationSuggestionApplyResult | null> => applySelected(action);

  /** Act on one row without disturbing an existing selection. */
  async function applyRow(
    row: VariationSuggestionRow,
    action: 'confirm' | 'dismiss'
  ): Promise<VariationSuggestionApplyResult | null> {
    const previous = selected.value;
    selected.value = [suggestionRowKey(row)];
    try {
      return await applySelected(action);
    } finally {
      selected.value = previous.filter((key) => key !== suggestionRowKey(row));
    }
  }

  return {
    rows,
    total,
    totalPages,
    page,
    pageSize,
    loading,
    filters,
    sort,
    selected,
    selectedRows,
    selectionKind,
    lastResult,
    rowKey: suggestionRowKey,
    canConfirm: canConfirmRow,
    canDismiss: canDismissRow,
    describeResult: describeApplyResult,
    load,
    applyFilters,
    resetFilters,
    goToPage,
    toggleRow,
    selectAllEligible,
    clearSelection,
    confirmSelected,
    dismissSelected,
    confirmDismiss,
    applyRow,
  };
}

export type VariationSuggestionsApi = ReturnType<typeof useVariationSuggestions>;
