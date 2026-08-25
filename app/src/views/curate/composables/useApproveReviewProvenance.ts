// views/curate/composables/useApproveReviewProvenance.ts
/**
 * #612 — the three-zone provenance picker for the ApproveReview edit modal.
 *
 * A thin owner around `useVariationProvenanceZones` so
 * `useApproveReviewController.ts` gains a handful of lines rather than the
 * zones' whole state surface: that file sits close to the repository's 600-line
 * ceiling, and the picker is a self-contained concern with its own lifecycle
 * (load when the modal opens, clear when it closes).
 *
 * WHY ApproveReview NEEDS IT
 * --------------------------
 * The approval modal prefills its variation picker from the review it is about
 * to approve and resubmits every term. Before #612 that meant a curator
 * approving a review reattributed every machine-derived term to themselves with
 * no action distinguishing agreement from inattention. The server has always
 * reconciled regardless — omission records a rejection, and only an explicit
 * `provenance_action: "confirm"` promotes — so this is about making the act
 * available, not about correctness.
 *
 * `confirmedTags` is SESSION-ONLY and cleared whenever the modal closes or a
 * different review is loaded. A confirmation is an act on one review's terms;
 * carrying it across would attribute one curator's reading to another entity.
 */

import { ref, type Ref } from 'vue';

import useVariationProvenanceZones from './useVariationProvenanceZones';

export default function useApproveReviewProvenance(selectedTags: Ref<string[]>) {
  const confirmedTags = ref<string[]>([]);
  const zones = useVariationProvenanceZones({ selectedTags, confirmedTags });

  /**
   * Load provenance for the entity behind the review being edited.
   *
   * Best-effort and non-throwing by design (the underlying loader swallows both
   * a missing route and a 403), so the approval form keeps working when the
   * provenance layer is unavailable — it simply shows no zones.
   */
  async function load(entityId: number | string | null | undefined): Promise<void> {
    if (entityId === null || entityId === undefined || entityId === '') {
      zones.reset();
      return;
    }
    await zones.loadForEntity(entityId);
  }

  function reset(): void {
    confirmedTags.value = [];
    zones.reset();
  }

  return {
    zones,
    confirmedTags,
    load,
    reset,
    /** Passed into the submit payload; `undefined` when no act was taken. */
    actionFor: zones.provenanceActionFor,
  };
}

export type ApproveReviewProvenanceApi = ReturnType<typeof useApproveReviewProvenance>;
