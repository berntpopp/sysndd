// app/src/views/review/composables/useReviewActions.ts
//
// W6 of v11.1 finish-hardening — re-review mutation composable for
// `Review.vue`.
//
// Owns the four `/api/re_review/*` mutations:
//   - `submitReReviewEntity(id)`        → `PUT /api/re_review/submit`
//   - `approveEntity(id, params)`       → `PUT /api/re_review/approve/:id`
//   - `unsubmitEntity(id)`              → `PUT /api/re_review/unsubmit/:id`
//   - `applyForBatch()`                 → `GET /api/re_review/batch/apply`
//
// Does NOT own the wizard's form submissions — those stay in the
// `useReviewForm` / `useStatusForm` composables. Those have their own
// loading/saving state. This composable only exposes a single `mutating`
// flag covering the four re-review-level mutations.

import { ref, type Ref } from 'vue';
import {
  applyForReReviewBatch,
  approveReReview,
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
  /** True while any of the four mutations is in flight. */
  mutating: Ref<boolean>;

  /** PUT /api/re_review/submit with submit_json. */
  submitReReviewEntity: (re_review_entity_id: number | string) => Promise<void>;

  /** PUT /api/re_review/approve/:id with status_ok + review_ok params. */
  approveEntity: (
    re_review_entity_id: number | string,
    decision: ApproveDecision,
  ) => Promise<void>;

  /** PUT /api/re_review/unsubmit/:id. */
  unsubmitEntity: (re_review_entity_id: number | string) => Promise<void>;

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
    decision: ApproveDecision,
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
    applyForBatch,
  };
}

export default useReviewActions;
