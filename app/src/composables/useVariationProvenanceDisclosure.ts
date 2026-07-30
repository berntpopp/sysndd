// app/src/composables/useVariationProvenanceDisclosure.ts
//
// Which variation-ontology term's provenance is open, and where focus goes when
// it closes (#608). Extracted from EntityEvidenceGrid.vue so that card stays
// under the 600-line ceiling and this a11y contract is testable on its own.
//
// The identity of a variation row is `(vario_id, modifier_id)`, NEVER `vario_id`
// alone: the same term can be asserted `present` and `absent` with independent
// provenance, so a CURIE-only key would collapse two distinct assertions into
// one and open the wrong evidence.

import { computed, nextTick, ref, type ComputedRef, type Ref } from 'vue';

export type VariationRow = Record<string, unknown>;

const asString = (value: unknown): string => (value == null ? '' : String(value));

/** Stable per-assertion key. */
export function variationAssertionKey(variant: VariationRow): string {
  return `${asString(variant.vario_id)}|${asString(variant.modifier_id)}`;
}

export interface VariationProvenanceDisclosure<T> {
  /** Target descriptor for the currently open assertion, or `null`. */
  openTarget: ComputedRef<T | null>;
  isOpen: (variant: VariationRow) => boolean;
  open: (variant: VariationRow) => void;
  /** Closes and returns focus to the trigger the reader came from. */
  close: () => Promise<void>;
  /** Template `:ref` callback that records each trigger element. */
  registerTrigger: (variant: VariationRow, el: unknown) => void;
}

/**
 * @param rows      Reactive list of variation rows currently rendered.
 * @param toTarget  Maps a row to the dialog's target descriptor; return `null`
 *                  to refuse to open (e.g. the row has no usable provenance).
 */
export function useVariationProvenanceDisclosure<T>(
  rows: Ref<VariationRow[]> | ComputedRef<VariationRow[]>,
  toTarget: (variant: VariationRow) => T | null
): VariationProvenanceDisclosure<T> {
  const openKey = ref<string | null>(null);
  // Plain Map: trigger ELEMENTS are not reactive state, and making them
  // reactive would deep-proxy DOM nodes.
  const triggers = new Map<string, HTMLElement>();

  function registerTrigger(variant: VariationRow, el: unknown): void {
    const key = variationAssertionKey(variant);
    if (el instanceof HTMLElement) triggers.set(key, el);
    else triggers.delete(key);
  }

  function isOpen(variant: VariationRow): boolean {
    return openKey.value === variationAssertionKey(variant);
  }

  const openTarget = computed<T | null>(() => {
    if (openKey.value === null) return null;
    const variant = rows.value.find((v) => variationAssertionKey(v) === openKey.value);
    return variant ? toTarget(variant) : null;
  });

  function open(variant: VariationRow): void {
    openKey.value = variationAssertionKey(variant);
  }

  async function close(): Promise<void> {
    const key = openKey.value;
    openKey.value = null;
    // Wait for the dialog to unmount before moving focus, otherwise the dialog's
    // own focus handling can win the race.
    await nextTick();
    if (key !== null) triggers.get(key)?.focus();
  }

  return { openTarget, isOpen, open, close, registerTrigger };
}

export default useVariationProvenanceDisclosure;
