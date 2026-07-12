import { describe, expect, it, vi } from 'vitest';
import Review from './Review.vue';

interface ModalItem {
  entity_id: number;
  review_id: number;
  status_id: number;
  re_review_review_saved: number;
  re_review_status_saved: number;
}

interface ModalContext {
  modalLoadGeneration: number;
  reviewModals: {
    setReviewTarget: (item: ModalItem) => void;
    setStatusTarget: (item: ModalItem) => void;
  };
  reviewData: {
    getEntity: (entityId: number) => Promise<void>;
    loadReviewInfo: (reviewId: number, saved: number) => Promise<void>;
  };
  reviewForm: {
    clearDraft: () => void;
    loadReviewData: (reviewId: number, saved: number) => Promise<void>;
  };
  statusForm: {
    clearDraft: () => void;
    loadStatusData: (statusId: number, saved: number) => Promise<void>;
  };
  $refs: { reviewModalRef: { show: () => void }; statusModalRef: { show: () => void } };
}

interface ReviewMethods {
  infoReview: (this: ModalContext, item: ModalItem) => Promise<void>;
  infoStatus: (this: ModalContext, item: ModalItem) => Promise<void>;
}

const methods = (Review as unknown as { methods: ReviewMethods }).methods;

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function item(entityId: number): ModalItem {
  return {
    entity_id: entityId,
    review_id: entityId + 100,
    status_id: entityId + 200,
    re_review_review_saved: 0,
    re_review_status_saved: 0,
  };
}

function context(getEntity: ModalContext['reviewData']['getEntity']): ModalContext {
  return {
    modalLoadGeneration: 0,
    reviewModals: { setReviewTarget: vi.fn(), setStatusTarget: vi.fn() },
    reviewData: { getEntity, loadReviewInfo: vi.fn().mockResolvedValue(undefined) },
    reviewForm: { clearDraft: vi.fn(), loadReviewData: vi.fn().mockResolvedValue(undefined) },
    statusForm: { clearDraft: vi.fn(), loadStatusData: vi.fn().mockResolvedValue(undefined) },
    $refs: {
      reviewModalRef: { show: vi.fn() },
      statusModalRef: { show: vi.fn() },
    },
  };
}

describe('Review.vue modal request ownership', () => {
  it('rapid A→B review opens do not load A data into B modal', async () => {
    const first = deferred<void>();
    const vm = context(vi.fn().mockReturnValueOnce(first.promise).mockResolvedValueOnce(undefined));

    const openA = methods.infoReview.call(vm, item(1));
    const openB = methods.infoReview.call(vm, item(2));
    await openB;
    first.resolve();
    await openA;

    expect(vm.reviewForm.loadReviewData).toHaveBeenCalledOnce();
    expect(vm.reviewForm.loadReviewData).toHaveBeenCalledWith(102, 0);
    expect(vm.$refs.reviewModalRef.show).toHaveBeenCalledOnce();
  });

  it('rapid A→B status opens do not load A data into B modal', async () => {
    const first = deferred<void>();
    const vm = context(vi.fn().mockReturnValueOnce(first.promise).mockResolvedValueOnce(undefined));

    const openA = methods.infoStatus.call(vm, item(1));
    const openB = methods.infoStatus.call(vm, item(2));
    await openB;
    first.resolve();
    await openA;

    expect(vm.statusForm.loadStatusData).toHaveBeenCalledOnce();
    expect(vm.statusForm.loadStatusData).toHaveBeenCalledWith(202, 0);
    expect(vm.$refs.statusModalRef.show).toHaveBeenCalledOnce();
  });

  it('allows form loaders to own A→B review data after both child loads start', async () => {
    const firstLoad = deferred<void>();
    const secondLoad = deferred<void>();
    const vm = context(vi.fn().mockResolvedValue(undefined));
    vm.reviewForm.loadReviewData = vi
      .fn()
      .mockReturnValueOnce(firstLoad.promise)
      .mockReturnValueOnce(secondLoad.promise);

    const openA = methods.infoReview.call(vm, item(1));
    await Promise.resolve();
    const openB = methods.infoReview.call(vm, item(2));
    await Promise.resolve();
    expect(vm.reviewForm.loadReviewData).toHaveBeenCalledTimes(2);

    secondLoad.resolve();
    await openB;
    firstLoad.resolve();
    await openA;

    expect(vm.reviewData.loadReviewInfo).toHaveBeenCalledTimes(1);
    expect(vm.reviewData.loadReviewInfo).toHaveBeenCalledWith(102, 0);
    expect(vm.$refs.reviewModalRef.show).toHaveBeenCalledOnce();
  });

  it('allows form loaders to own A→B status data after both child loads start', async () => {
    const firstLoad = deferred<void>();
    const secondLoad = deferred<void>();
    const vm = context(vi.fn().mockResolvedValue(undefined));
    vm.statusForm.loadStatusData = vi
      .fn()
      .mockReturnValueOnce(firstLoad.promise)
      .mockReturnValueOnce(secondLoad.promise);

    const openA = methods.infoStatus.call(vm, item(1));
    await Promise.resolve();
    const openB = methods.infoStatus.call(vm, item(2));
    await Promise.resolve();
    expect(vm.statusForm.loadStatusData).toHaveBeenCalledTimes(2);

    secondLoad.resolve();
    await openB;
    firstLoad.resolve();
    await openA;

    expect(vm.$refs.statusModalRef.show).toHaveBeenCalledOnce();
  });
});
