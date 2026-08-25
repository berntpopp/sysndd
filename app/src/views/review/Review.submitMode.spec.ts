// views/review/Review.submitMode.spec.ts
/**
 * `submitReviewChange()` must decide create-vs-update from the review the FORM
 * loaded, never from separately-fetched display metadata.
 *
 * The defect (found by adversarial review of #635, same save path): the flag came
 * from `review_info.review_id`, populated by `useReviewData.loadReviewInfo()` — which
 * catches its errors, calls `reportError()`, and returns. `infoReview()` then shows
 * the modal regardless, so a failed or empty metadata fetch left `review_id` null,
 * flipped `isUpdate` to `false`, and made the save POST `/api/review/create`. That
 * mints a SECOND review for an entity that already has one, and its publications are
 * INSERTed onto the new row rather than replacing those on the old one — a silent
 * fork of the curation record from a failure the curator never sees.
 *
 * `useReviewForm.loadReviewData()` is the authoritative source: it is atomic (a
 * rejection propagates out of `infoReview()` before `show()`), so whenever this modal
 * is open its `reviewId` is exactly the id the modal was opened with.
 *
 * This calls the method against a hand-built context rather than mounting the view.
 * The regression is entirely in that one expression, and `Review.spec.ts`'s mount
 * harness is ~500 lines of axios/interceptor scaffolding that this assertion does not
 * need — duplicating it here would also push that file further over the size ceiling.
 */

import { describe, it, expect, vi } from 'vitest';
import { ref } from 'vue';

import Review from './Review.vue';

interface SubmitContext {
  reviewForm: {
    reviewId: { value: number | null };
    submitForm: ReturnType<typeof vi.fn>;
    resetForm: ReturnType<typeof vi.fn>;
  };
  review_info: { review_id: number | null };
  makeToast: ReturnType<typeof vi.fn>;
  announce: ReturnType<typeof vi.fn>;
  loadReReviewData: ReturnType<typeof vi.fn>;
}

function submitContext(overrides: {
  formReviewId: number | null;
  metadataReviewId: number | null;
}): SubmitContext {
  return {
    reviewForm: {
      reviewId: ref(overrides.formReviewId) as { value: number | null },
      submitForm: vi.fn().mockResolvedValue(undefined),
      resetForm: vi.fn(),
    },
    review_info: { review_id: overrides.metadataReviewId },
    makeToast: vi.fn(),
    announce: vi.fn(),
    loadReReviewData: vi.fn().mockResolvedValue(undefined),
  };
}

/** The options-API method under test, invoked with an explicit `this`. */
async function runSubmit(context: SubmitContext): Promise<void> {
  const method = (
    Review as unknown as { methods: { submitReviewChange: (this: SubmitContext) => Promise<void> } }
  ).methods.submitReviewChange;
  await method.call(context);
}

describe('Review.vue submitReviewChange — create vs update', () => {
  it('updates when the form loaded a review, even if the metadata fetch failed', async () => {
    const context = submitContext({ formReviewId: 123, metadataReviewId: null });

    await runSubmit(context);

    // isUpdate === true -> PUT /api/review/update. Before the fix this was `false`
    // and the save minted a duplicate review.
    expect(context.reviewForm.submitForm).toHaveBeenCalledWith(true, true);
  });

  it('updates on the ordinary path where both ids are present', async () => {
    const context = submitContext({ formReviewId: 123, metadataReviewId: 123 });

    await runSubmit(context);

    expect(context.reviewForm.submitForm).toHaveBeenCalledWith(true, true);
  });

  it('creates only when the form genuinely has no loaded review', async () => {
    const context = submitContext({ formReviewId: null, metadataReviewId: 123 });

    await runSubmit(context);

    expect(context.reviewForm.submitForm).toHaveBeenCalledWith(false, true);
  });

  it('surfaces a submit failure as an error toast and an assertive announcement', async () => {
    const context = submitContext({ formReviewId: 123, metadataReviewId: 123 });
    context.reviewForm.submitForm.mockRejectedValue(new Error('boom'));

    await runSubmit(context);

    expect(context.makeToast).toHaveBeenCalledWith(expect.anything(), 'Error', 'danger');
    expect(context.announce).toHaveBeenCalledWith('Failed to submit review', 'assertive');
    expect(context.reviewForm.resetForm).not.toHaveBeenCalled();
  });
});
