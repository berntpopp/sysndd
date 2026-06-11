// app/src/views/curate/composables/useCombinedStatusReview.ts
/**
 * Orchestrates the combined Status & Review modify flow (issues #36, #37).
 *
 * The combined modal lets a curator change BOTH the status and the review of
 * an entity in one step, with an optional Curator-gated direct-approval
 * toggle. Rather than invent a new combined endpoint, this composable
 * sequences the two existing write paths the standalone workflows already use:
 *
 *   1. Review  -> `useEntityMutations.submitReview()` (POST /api/review/create)
 *   2. Status  -> `useStatusForm.submitForm()`        (POST /api/status/create)
 *
 * Each write forwards `direct_approval` so the server approves the freshly
 * written row in the same request (Curator+ only; the server re-checks the
 * role). Submitting the review first means a direct-approved review becomes
 * primary before the status approval recomputes the entity's aggregate state.
 *
 * Only the dimensions that actually changed are submitted, so a curator can
 * edit just the status, just the review, or both. Direct-approval may still be
 * requested even when nothing else changed (re-approving the current rows).
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';

export interface SubmitReviewLike {
  (args: {
    review_info: unknown;
    select_phenotype: string[];
    select_variation: string[];
    select_additional_references: string[];
    select_gene_reviews: string[];
    direct_approval?: boolean;
  }): Promise<void>;
}

export interface SubmitStatusLike {
  (isUpdate: boolean, reReview: boolean, directApproval?: boolean): Promise<void>;
}

export interface CombinedSources {
  /** True when the review fields differ from the loaded snapshot. */
  hasReviewChanges: Ref<boolean> | ComputedRef<boolean>;
  /** True when the status fields differ from the loaded snapshot. */
  hasStatusChanges: Ref<boolean> | ComputedRef<boolean>;
  /** Snapshot of the current review selections for the review submit. */
  getReviewArgs: () => {
    review_info: unknown;
    select_phenotype: string[];
    select_variation: string[];
    select_additional_references: string[];
    select_gene_reviews: string[];
  };
  submitReview: SubmitReviewLike;
  submitStatus: SubmitStatusLike;
}

export interface UseCombinedStatusReviewOptions {
  onToast?: (...args: unknown[]) => void;
  onAnnounce?: (msg: string, politeness?: 'polite' | 'assertive') => void;
  /** Marks the shared submit spinner (`useEntityMutations.setSubmittingState`). */
  setSubmittingState?: (state: 'combined' | null) => void;
}

export function useCombinedStatusReview(
  sources: CombinedSources,
  options: UseCombinedStatusReviewOptions = {}
) {
  const { onToast, onAnnounce, setSubmittingState } = options;

  // Curator-gated; defaults off so the cheap path is a plain submit.
  const directApproval = ref(false);

  const hasAnyChange = computed(
    () => sources.hasReviewChanges.value || sources.hasStatusChanges.value
  );

  /** True when there is something to do (a change, or a re-approval request). */
  const canSubmit = computed(() => hasAnyChange.value || directApproval.value);

  function reset(): void {
    directApproval.value = false;
  }

  /**
   * Submit the combined form. Returns true on success, false on a no-op (so
   * the caller can close the workflow without firing a success toast).
   * Rejects only when a write fails — partial-failure semantics are handled
   * inline so the curator sees which dimension failed.
   */
  async function submit(): Promise<boolean> {
    if (!canSubmit.value) {
      return false;
    }

    setSubmittingState?.('combined');
    const approve = directApproval.value;
    let submittedSomething = false;

    try {
      // 1. Review first so a direct-approved review is primary before the
      //    status approval recomputes the entity's aggregate state.
      if (sources.hasReviewChanges.value || approve) {
        await sources.submitReview({
          ...sources.getReviewArgs(),
          direct_approval: approve,
        });
        submittedSomething = true;
      }

      // 2. Status second. `isUpdate=false` mirrors the standalone status flow
      //    (the modify path always POSTs a new status row).
      if (sources.hasStatusChanges.value || approve) {
        await sources.submitStatus(false, false, approve);
        submittedSomething = true;
      }

      if (submittedSomething) {
        const msg = approve
          ? 'Status & review submitted and approved'
          : 'Status & review submitted successfully';
        onToast?.(msg, 'Success', 'success');
        onAnnounce?.(msg);
      }
      return submittedSomething;
    } catch (e) {
      // submitReview already toasts its own error; surface a combined-flow
      // message for the status leg and re-throw so the caller keeps the
      // selection intact for a retry.
      onAnnounce?.('Failed to submit status & review', 'assertive');
      throw e;
    } finally {
      setSubmittingState?.(null);
    }
  }

  return {
    directApproval,
    hasAnyChange,
    canSubmit,
    submit,
    reset,
  };
}

export default useCombinedStatusReview;
