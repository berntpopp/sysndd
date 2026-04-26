import { describe, expect, test } from 'vitest';
import { useEntityModifyModals } from '../useEntityModifyModals';

describe('useEntityModifyModals', () => {
  test('open / close per modal type', () => {
    const m = useEntityModifyModals();
    expect(m.isRenameOpen.value).toBe(false);
    m.openRename();
    expect(m.isRenameOpen.value).toBe(true);
    m.close();
    expect(m.isRenameOpen.value).toBe(false);
    m.openDeactivate();
    expect(m.isDeactivateOpen.value).toBe(true);
    m.close();
    m.openReview();
    expect(m.isReviewOpen.value).toBe(true);
    m.close();
    m.openStatus();
    expect(m.isStatusOpen.value).toBe(true);
  });

  test('switching from review to status auto-closes the previous', () => {
    const m = useEntityModifyModals();
    m.openReview();
    m.openStatus();
    expect(m.isReviewOpen.value).toBe(false);
    expect(m.isStatusOpen.value).toBe(true);
  });

  test('discard-confirm flow: requestDiscard sets pendingDiscardTarget; confirmDiscard closes the target', () => {
    const m = useEntityModifyModals();
    m.openReview();
    expect(m.pendingDiscardTarget.value).toBeNull();
    m.requestDiscard('review');
    expect(m.pendingDiscardTarget.value).toBe('review');
    m.confirmDiscard();
    expect(m.pendingDiscardTarget.value).toBeNull();
    expect(m.isReviewOpen.value).toBe(false);
  });

  test('per-modal loading flags toggle independently', () => {
    const m = useEntityModifyModals();
    expect(m.loadingReview.value).toBe(true);
    m.setLoading('review', false);
    expect(m.loadingReview.value).toBe(false);
    expect(m.loadingStatus.value).toBe(true);
  });
});
