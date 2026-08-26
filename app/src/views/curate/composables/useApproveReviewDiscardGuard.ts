// views/curate/composables/useApproveReviewDiscardGuard.ts
/**
 * The unsaved-changes guard for the ApproveReview page's two modals.
 *
 * Extracted from `useApproveReviewController.ts` (#612), which sits against the
 * repository's 600-line ceiling. It is a cohesive concern in its own right: one
 * pending target, one dialog, and the rule that closing a dirty modal must ask
 * first.
 *
 * `onDiscardReview` fires only on a CONFIRMED discard, never from the hide
 * handler — that runs before the dialog is answered, so resetting there throws
 * the curator's pending decision away mid-decision (and clears the dirty flag,
 * letting the modal close silently).
 */

import type { Ref } from 'vue';

/** BootstrapVueNext passes a preventable event to `@hide`. */
export interface ModalHideEvent {
  preventDefault: () => void;
}

export interface UseApproveReviewDiscardGuardOptions {
  pendingDiscardTarget: Ref<'review' | 'status' | null>;
  confirmDiscardDialog: Ref<{ show: () => void; hide: () => void } | null>;
  hasReviewChanges: Readonly<Ref<boolean>>;
  hasStatusChanges: Readonly<Ref<boolean>>;
  isBusy: Ref<boolean>;
  hideReview: () => void;
  hideStatus: () => void;
  /** Called only when the curator CONFIRMS discarding the review edit. */
  onDiscardReview?: () => void;
}

export default function useApproveReviewDiscardGuard(
  options: UseApproveReviewDiscardGuardOptions
) {
  const { pendingDiscardTarget, confirmDiscardDialog, isBusy } = options;

  function guard(
    event: ModalHideEvent,
    target: 'review' | 'status',
    isDirty: boolean
  ): void {
    // The second pass: the dialog already ran and the curator chose to discard,
    // so let this hide through.
    if (pendingDiscardTarget.value === target) {
      pendingDiscardTarget.value = null;
      return;
    }
    if (isDirty && !isBusy.value) {
      event.preventDefault();
      pendingDiscardTarget.value = target;
      confirmDiscardDialog.value?.show();
    }
  }

  const onStatusModalHide = (event: ModalHideEvent): void =>
    guard(event, 'status', options.hasStatusChanges.value);

  const onReviewModalHide = (event: ModalHideEvent): void =>
    guard(event, 'review', options.hasReviewChanges.value);

  function onConfirmDiscard(): void {
    if (pendingDiscardTarget.value === 'review') {
      options.onDiscardReview?.();
      options.hideReview();
    } else if (pendingDiscardTarget.value === 'status') {
      options.hideStatus();
    }
  }

  return { onStatusModalHide, onReviewModalHide, onConfirmDiscard };
}
