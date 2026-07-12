import { beforeEach, describe, expect, it, vi } from 'vitest';

const {
  getEntityPhenotypesMock,
  getEntityPublicationsMock,
  getEntityReviewMock,
  getEntityStatusMock,
  getEntityVariationMock,
  listEntitiesMock,
} = vi.hoisted(() => ({
  getEntityPhenotypesMock: vi.fn(),
  getEntityPublicationsMock: vi.fn(),
  getEntityReviewMock: vi.fn(),
  getEntityStatusMock: vi.fn(),
  getEntityVariationMock: vi.fn(),
  listEntitiesMock: vi.fn(),
}));

vi.mock('@/api/entity', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/entity')>();
  return {
    ...actual,
    getEntityPhenotypes: getEntityPhenotypesMock,
    getEntityPublications: getEntityPublicationsMock,
    getEntityReview: getEntityReviewMock,
    getEntityStatus: getEntityStatusMock,
    getEntityVariation: getEntityVariationMock,
    listEntities: listEntitiesMock,
  };
});

import { useEntityInfo } from '../useEntityInfo';

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

describe('useEntityInfo request ownership', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getEntityPhenotypesMock.mockResolvedValue([]);
    getEntityPublicationsMock.mockResolvedValue([]);
    getEntityVariationMock.mockResolvedValue([]);
  });

  it('reset aborts and invalidates entity and review successes that settle afterwards', async () => {
    const entity = deferred<{ data: Array<{ entity_id: number; symbol: string }> }>();
    const review = deferred<Array<Record<string, unknown>>>();
    listEntitiesMock.mockReturnValue(entity.promise);
    getEntityReviewMock.mockReturnValue(review.promise);
    const data = useEntityInfo();

    const entityRequest = data.loadEntity(1);
    const reviewRequest = data.loadReview(1);
    data.reset();

    entity.resolve({ data: [{ entity_id: 1, symbol: 'STALE' }] });
    review.resolve([{ synopsis: 'stale', comment: '', review_id: 1, entity_id: 1 }]);
    await Promise.all([entityRequest, reviewRequest]);

    expect(data.entity_info.value).toEqual({});
    expect(data.reviewLoadedData.value).toBeNull();
    expect(data.review_info.value.synopsis).toBeUndefined();
  });

  it('reset prevents a stale status rejection from showing a toast', async () => {
    const status = deferred<unknown>();
    const toasts: unknown[][] = [];
    getEntityStatusMock.mockReturnValue(status.promise);
    const data = useEntityInfo({ onToast: (...args) => toasts.push(args) });

    const statusRequest = data.loadStatus(1);
    data.reset();
    status.reject(new Error('stale failure'));
    await statusRequest;

    expect(toasts).toEqual([]);
    expect(data.status_info.value.status_id).toBeUndefined();
  });

  it('passes the review subresource abort signal as the typed client config', async () => {
    getEntityReviewMock.mockResolvedValue([{ synopsis: '', comment: '', review_id: 1, entity_id: 1 }]);
    const data = useEntityInfo();

    await data.loadReview(1);

    const config = expect.objectContaining({ signal: expect.any(AbortSignal) });
    expect(getEntityPhenotypesMock).toHaveBeenCalledWith(1, {}, config);
    expect(getEntityVariationMock).toHaveBeenCalledWith(1, {}, config);
    expect(getEntityPublicationsMock).toHaveBeenCalledWith(1, {}, config);
  });
});
