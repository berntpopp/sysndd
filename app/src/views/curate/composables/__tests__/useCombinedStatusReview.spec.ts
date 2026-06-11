// views/curate/composables/__tests__/useCombinedStatusReview.spec.ts
/**
 * Unit tests for the combined Status & Review orchestration composable
 * (issues #36, #37).
 *
 * The composable sequences the two existing write paths (review then status)
 * and threads the Curator-gated `direct_approval` flag through both. These
 * tests assert:
 *   - only-changed submission (status-only, review-only, both)
 *   - direct-approval threading to both writes
 *   - direct-approval-only re-submit even when nothing else changed
 *   - the no-op short-circuit
 *   - review-before-status ordering
 *   - the shared submit-spinner state lifecycle
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ref } from 'vue';
import { useCombinedStatusReview, type CombinedSources } from '../useCombinedStatusReview';

function makeSources(overrides: Partial<CombinedSources> = {}): {
  sources: CombinedSources;
  submitReview: ReturnType<typeof vi.fn>;
  submitStatus: ReturnType<typeof vi.fn>;
  hasReviewChanges: ReturnType<typeof ref<boolean>>;
  hasStatusChanges: ReturnType<typeof ref<boolean>>;
} {
  const hasReviewChanges = ref(false);
  const hasStatusChanges = ref(false);
  const submitReview = vi.fn().mockResolvedValue(undefined);
  const submitStatus = vi.fn().mockResolvedValue(undefined);

  const sources: CombinedSources = {
    hasReviewChanges,
    hasStatusChanges,
    getReviewArgs: () => ({
      review_info: { entity_id: 1, synopsis: 's' },
      select_phenotype: ['1-HP:1'],
      select_variation: [],
      select_additional_references: ['PMID:111'],
      select_gene_reviews: [],
    }),
    submitReview,
    submitStatus,
    ...overrides,
  };

  return { sources, submitReview, submitStatus, hasReviewChanges, hasStatusChanges };
}

describe('useCombinedStatusReview', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('no-op when nothing changed and direct approval is off', async () => {
    const { sources, submitReview, submitStatus } = makeSources();
    const combined = useCombinedStatusReview(sources);

    const result = await combined.submit();

    expect(result).toBe(false);
    expect(submitReview).not.toHaveBeenCalled();
    expect(submitStatus).not.toHaveBeenCalled();
  });

  it('submits only the review when only the review changed', async () => {
    const { sources, submitReview, submitStatus, hasReviewChanges } = makeSources();
    hasReviewChanges.value = true;
    const combined = useCombinedStatusReview(sources);

    const result = await combined.submit();

    expect(result).toBe(true);
    expect(submitReview).toHaveBeenCalledTimes(1);
    expect(submitStatus).not.toHaveBeenCalled();
    expect(submitReview.mock.calls[0][0]).toMatchObject({ direct_approval: false });
  });

  it('submits only the status when only the status changed', async () => {
    const { sources, submitReview, submitStatus, hasStatusChanges } = makeSources();
    hasStatusChanges.value = true;
    const combined = useCombinedStatusReview(sources);

    await combined.submit();

    expect(submitReview).not.toHaveBeenCalled();
    expect(submitStatus).toHaveBeenCalledTimes(1);
    // submitStatus(isUpdate=false, reReview=false, directApproval=false)
    expect(submitStatus).toHaveBeenCalledWith(false, false, false);
  });

  it('submits review BEFORE status when both changed', async () => {
    const order: string[] = [];
    const submitReview = vi.fn().mockImplementation(async () => {
      order.push('review');
    });
    const submitStatus = vi.fn().mockImplementation(async () => {
      order.push('status');
    });
    const { sources, hasReviewChanges, hasStatusChanges } = makeSources({
      submitReview,
      submitStatus,
    });
    hasReviewChanges.value = true;
    hasStatusChanges.value = true;

    const combined = useCombinedStatusReview(sources);
    await combined.submit();

    expect(order).toEqual(['review', 'status']);
  });

  it('threads direct_approval=true to both write paths', async () => {
    const { sources, submitReview, submitStatus, hasReviewChanges, hasStatusChanges } =
      makeSources();
    hasReviewChanges.value = true;
    hasStatusChanges.value = true;
    const combined = useCombinedStatusReview(sources);
    combined.directApproval.value = true;

    await combined.submit();

    expect(submitReview.mock.calls[0][0]).toMatchObject({ direct_approval: true });
    expect(submitStatus).toHaveBeenCalledWith(false, false, true);
  });

  it('re-approves both rows when direct approval is on even with no field changes', async () => {
    const { sources, submitReview, submitStatus } = makeSources();
    const combined = useCombinedStatusReview(sources);
    combined.directApproval.value = true;

    const result = await combined.submit();

    expect(result).toBe(true);
    expect(submitReview).toHaveBeenCalledTimes(1);
    expect(submitStatus).toHaveBeenCalledTimes(1);
  });

  it('toasts and announces success', async () => {
    const onToast = vi.fn();
    const onAnnounce = vi.fn();
    const { sources, hasStatusChanges } = makeSources();
    hasStatusChanges.value = true;
    const combined = useCombinedStatusReview(sources, { onToast, onAnnounce });

    await combined.submit();

    expect(onToast).toHaveBeenCalledWith(
      'Status & review submitted successfully',
      'Success',
      'success'
    );
    expect(onAnnounce).toHaveBeenCalledWith('Status & review submitted successfully');
  });

  it('drives the shared submit-spinner state and clears it after success', async () => {
    const states: Array<'combined' | null> = [];
    const setSubmittingState = vi.fn((s: 'combined' | null) => states.push(s));
    const { sources, hasStatusChanges } = makeSources();
    hasStatusChanges.value = true;
    const combined = useCombinedStatusReview(sources, { setSubmittingState });

    await combined.submit();

    expect(states).toEqual(['combined', null]);
  });

  it('rethrows and clears the spinner when a write fails', async () => {
    const setSubmittingState = vi.fn();
    const onAnnounce = vi.fn();
    const submitStatus = vi.fn().mockRejectedValue(new Error('boom'));
    const { sources, hasStatusChanges } = makeSources({ submitStatus });
    hasStatusChanges.value = true;
    const combined = useCombinedStatusReview(sources, { setSubmittingState, onAnnounce });

    await expect(combined.submit()).rejects.toThrow('boom');
    expect(setSubmittingState).toHaveBeenLastCalledWith(null);
    expect(onAnnounce).toHaveBeenCalledWith('Failed to submit status & review', 'assertive');
  });

  it('reset() turns direct approval back off', () => {
    const { sources } = makeSources();
    const combined = useCombinedStatusReview(sources);
    combined.directApproval.value = true;
    combined.reset();
    expect(combined.directApproval.value).toBe(false);
  });
});
