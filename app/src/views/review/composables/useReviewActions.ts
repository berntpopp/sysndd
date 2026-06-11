// app/src/views/review/composables/useReviewActions.ts
//
// W6 of v11.1 finish-hardening — re-review mutation composable for
// `Review.vue`.
//
// Owns the `/api/re_review/*` mutations:
//   - `submitReReviewEntity(id)`        → `PUT /api/re_review/submit`
//   - `approveEntity(id, params)`       → `PUT /api/re_review/approve/:id`
//   - `unsubmitEntity(id)`              → `PUT /api/re_review/unsubmit/:id`
//   - `refuseEntity(id, reason)`        → `PUT /api/re_review/refuse/:id`
//   - `applyForBatch()`                 → `GET /api/re_review/batch/apply`
//
// Does NOT own the wizard's form submissions — those stay in the
// `useReviewForm` / `useStatusForm` composables. Those have their own
// loading/saving state. This composable only exposes a single `mutating`
// flag covering the re-review-level mutations.

import { ref, type Ref } from 'vue';
import {
  applyForReReviewBatch,
  approveReReview,
  refuseReReview,
  submitReReview,
  unsubmitReReview,
} from '@/api/re_review';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ApproveDecision {
  status_ok: boolean;
  review_ok: boolean;
}

export interface UseReviewActionsOptions {
  /** Optional error sink — called once per rejected mutation. */
  onError?: (err: unknown) => void;
}

export interface UseReviewActions {
  /** True while any mutation is in flight. */
  mutating: Ref<boolean>;

  /** PUT /api/re_review/submit with submit_json. */
  submitReReviewEntity: (re_review_entity_id: number | string) => Promise<void>;

  /** PUT /api/re_review/approve/:id with status_ok + review_ok params. */
  approveEntity: (re_review_entity_id: number | string, decision: ApproveDecision) => Promise<void>;

  /** PUT /api/re_review/unsubmit/:id. */
  unsubmitEntity: (re_review_entity_id: number | string) => Promise<void>;

  /**
   * PUT /api/re_review/refuse/:id with an optional reason (issue #54).
   * Resolves true on success and false when the mutation was reported as
   * failed, so the caller can keep the confirm modal open on failure.
   */
  refuseEntity: (re_review_entity_id: number | string, reason?: string | null) => Promise<boolean>;

  /** GET /api/re_review/batch/apply (email send). */
  applyForBatch: () => Promise<void>;
}

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

export function useReviewActions(options: UseReviewActionsOptions = {}): UseReviewActions {
  const { onError } = options;
  const mutating = ref(false);

  function reportError(err: unknown): void {
    if (onError) onError(err);
  }

  async function submitReReviewEntity(re_review_entity_id: number | string): Promise<void> {
    mutating.value = true;
    try {
      await submitReReview({
        submit_json: {
          re_review_entity_id,
          re_review_submitted: 1,
        },
      });
    } catch (err) {
      reportError(err);
    } finally {
      mutating.value = false;
    }
  }

  async function approveEntity(
    re_review_entity_id: number | string,
    decision: ApproveDecision
  ): Promise<void> {
    mutating.value = true;
    try {
      await approveReReview(re_review_entity_id, {
        status_ok: decision.status_ok,
        review_ok: decision.review_ok,
      });
    } catch (err) {
      reportError(err);
    } finally {
      mutating.value = false;
    }
  }

  async function unsubmitEntity(re_review_entity_id: number | string): Promise<void> {
    mutating.value = true;
    try {
      await unsubmitReReview(re_review_entity_id);
    } catch (err) {
      reportError(err);
    } finally {
      mutating.value = false;
    }
  }

  async function refuseEntity(
    re_review_entity_id: number | string,
    reason?: string | null
  ): Promise<boolean> {
    mutating.value = true;
    try {
      const trimmed = typeof reason === 'string' ? reason.trim() : '';
      await refuseReReview(re_review_entity_id, { reason: trimmed.length ? trimmed : null });
      return true;
    } catch (err) {
      reportError(err);
      return false;
    } finally {
      mutating.value = false;
    }
  }

  async function applyForBatch(): Promise<void> {
    mutating.value = true;
    try {
      await applyForReReviewBatch();
    } catch (err) {
      reportError(err);
    } finally {
      mutating.value = false;
    }
  }

  return {
    mutating,
    submitReReviewEntity,
    approveEntity,
    unsubmitEntity,
    refuseEntity,
    applyForBatch,
  };
}

export default useReviewActions;
