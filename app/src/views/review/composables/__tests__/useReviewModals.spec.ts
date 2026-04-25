// app/src/views/review/composables/__tests__/useReviewModals.spec.ts
/**
 * Unit tests for `useReviewModals` — modal-state composable extracted
 * during W6 of v11.1 finish-hardening.
 *
 * The composable owns:
 *   - the four modal descriptors (`reviewModal`, `statusModal`, `submitModal`,
 *     `approveModal`) the template binds against, with id/title fields
 *   - the currently-targeted entity (`entity` legacy single-element array)
 *     the submit/approve modals read on confirm
 *   - the approve-modal toggle state (`status_approved`, `review_approved`)
 *     and the `resetApproveModal()` helper
 *   - `openSubmit(item)` / `openApprove(item)` info* methods (no-op for
 *     `infoReview` / `infoStatus` whose data side effects belong to
 *     `useReviewData` — those are wired in `Review.vue` itself)
 *
 * No DOM access in tests — the modal show/hide is delegated to BModal
 * `$refs` inside `Review.vue`, NOT to this composable. The composable is
 * pure state.
 */

import { describe, it, expect } from 'vitest';
import { useReviewModals } from '../useReviewModals';

describe('useReviewModals', () => {
  it('exposes default modal descriptors', () => {
    const m = useReviewModals();
    expect(m.reviewModal.id).toBe('review-modal');
    expect(m.statusModal.id).toBe('status-modal');
    expect(m.submitModal.id).toBe('submit-modal');
    expect(m.approveModal.id).toBe('approve-modal');
    expect(m.reviewModal.title).toBe('');
    expect(m.statusModal.title).toBe('');
  });

  it('starts with no targeted entity and approval flags off', () => {
    const m = useReviewModals();
    expect(m.entity.value).toEqual([]);
    expect(m.status_approved.value).toBe(false);
    expect(m.review_approved.value).toBe(false);
  });

  it('setReviewTarget updates the review-modal title without touching entity[]', () => {
    const m = useReviewModals();
    m.setReviewTarget({ entity_id: 42 } as { entity_id: number });
    expect(m.reviewModal.title).toBe('sysndd:42');
    // Review/Status modals do NOT push into the entity[] queue — only submit
    // and approve do.
    expect(m.entity.value).toEqual([]);
  });

  it('setStatusTarget updates the status-modal title only', () => {
    const m = useReviewModals();
    m.setStatusTarget({ entity_id: 7 } as { entity_id: number });
    expect(m.statusModal.title).toBe('sysndd:7');
    expect(m.entity.value).toEqual([]);
  });

  it('openSubmit pushes the row into entity[] and sets the submit-modal title', () => {
    const m = useReviewModals();
    const row = { entity_id: 9, re_review_entity_id: 909 };
    m.openSubmit(row as never);
    expect(m.submitModal.title).toBe('sysndd:9');
    expect(m.entity.value).toHaveLength(1);
    // Vue wraps stored objects in reactive proxies, so use deep equality
    // for the row comparison rather than reference identity.
    expect(m.entity.value[0]).toEqual(row);
  });

  it('openApprove pushes the row into entity[] and sets the approve-modal title', () => {
    const m = useReviewModals();
    const row = { entity_id: 11, re_review_entity_id: 211 };
    m.openApprove(row as never);
    expect(m.approveModal.title).toBe('sysndd:11');
    expect(m.entity.value).toHaveLength(1);
    expect(m.entity.value[0]).toEqual(row);
  });

  it('openSubmit replaces the previous targeted entity rather than appending', () => {
    const m = useReviewModals();
    m.openSubmit({ entity_id: 1 } as never);
    m.openSubmit({ entity_id: 2 } as never);
    expect(m.entity.value).toHaveLength(1);
    expect(m.entity.value[0]).toMatchObject({ entity_id: 2 });
  });

  it('resetApproveModal flips both approval toggles back to false', () => {
    const m = useReviewModals();
    m.status_approved.value = true;
    m.review_approved.value = true;

    m.resetApproveModal();

    expect(m.status_approved.value).toBe(false);
    expect(m.review_approved.value).toBe(false);
  });

  it('clearTarget empties the entity[] queue', () => {
    const m = useReviewModals();
    m.openSubmit({ entity_id: 4 } as never);
    expect(m.entity.value).toHaveLength(1);

    m.clearTarget();
    expect(m.entity.value).toEqual([]);
  });
});
