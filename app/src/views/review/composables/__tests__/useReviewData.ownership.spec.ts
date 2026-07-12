import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { TreeNode } from '@/api/list';

const {
  getReReviewTableMock,
  getReviewByIdMock,
  getStatusByIdMock,
  listEntitiesMock,
  listPhenotypesTreeMock,
  listStatusCategoriesTreeMock,
  listVariationOntologyTreeMock,
} = vi.hoisted(() => ({
  getReReviewTableMock: vi.fn(),
  getReviewByIdMock: vi.fn(),
  getStatusByIdMock: vi.fn(),
  listEntitiesMock: vi.fn(),
  listPhenotypesTreeMock: vi.fn(),
  listStatusCategoriesTreeMock: vi.fn(),
  listVariationOntologyTreeMock: vi.fn(),
}));

vi.mock('@/api/entity', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/entity')>();
  return { ...actual, listEntities: listEntitiesMock };
});

vi.mock('@/api/list', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/list')>();
  return {
    ...actual,
    listPhenotypesTree: listPhenotypesTreeMock,
    listStatusCategoriesTree: listStatusCategoriesTreeMock,
    listVariationOntologyTree: listVariationOntologyTreeMock,
  };
});

vi.mock('@/api/re_review', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/re_review')>();
  return { ...actual, getReReviewTable: getReReviewTableMock };
});

vi.mock('@/api/review', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/review')>();
  return { ...actual, getReviewById: getReviewByIdMock };
});

vi.mock('@/api/status', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/status')>();
  return { ...actual, getStatusById: getStatusByIdMock };
});

import { useReviewData } from '../useReviewData';

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

const modifierTree = (id: string, label: string): TreeNode[] => [
  { id, label: `present: ${label}`, children: [] },
];

describe('useReviewData request ownership', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('keeps all three concurrently loaded option lists under independent owners', async () => {
    const phenotypes = deferred<TreeNode[]>();
    const variation = deferred<TreeNode[]>();
    const statuses = deferred<TreeNode[]>();
    listPhenotypesTreeMock.mockReturnValue(phenotypes.promise);
    listVariationOntologyTreeMock.mockReturnValue(variation.promise);
    listStatusCategoriesTreeMock.mockReturnValue(statuses.promise);
    const data = useReviewData();

    const phenotypeRequest = data.loadPhenotypesList();
    const variationRequest = data.loadVariationOntologyList();
    const statusRequest = data.loadStatusList();
    variation.resolve(modifierTree('1-VARIO:1', 'Variation'));
    statuses.resolve([{ id: 'status', label: 'Status' }]);
    phenotypes.resolve(modifierTree('1-HP:1', 'Phenotype'));
    await Promise.all([phenotypeRequest, variationRequest, statusRequest]);

    expect(data.phenotypes_options.value[0].label).toBe('Phenotype');
    expect(data.variation_ontology_options.value[0].label).toBe('Variation');
    expect(data.status_options.value).toEqual([{ id: 'status', label: 'Status' }]);
    const phenotypeSignal = listPhenotypesTreeMock.mock.calls[0][0]?.signal;
    const variationSignal = listVariationOntologyTreeMock.mock.calls[0][0]?.signal;
    const statusSignal = listStatusCategoriesTreeMock.mock.calls[0][0]?.signal;
    expect(phenotypeSignal).toBeInstanceOf(AbortSignal);
    expect(phenotypeSignal).not.toBe(variationSignal);
    expect(variationSignal).not.toBe(statusSignal);
  });

  it('reset invalidates entity, review, and status context requests and clears the status spinner', async () => {
    const entity = deferred<{ data: Array<{ entity_id: number; symbol: string }> }>();
    const review = deferred<Array<Record<string, unknown>>>();
    const status = deferred<Array<Record<string, unknown>>>();
    listEntitiesMock.mockReturnValue(entity.promise);
    getReviewByIdMock.mockReturnValue(review.promise);
    getStatusByIdMock.mockReturnValue(status.promise);
    const data = useReviewData();

    const entityRequest = data.getEntity(1);
    const reviewRequest = data.loadReviewInfo(2, 1);
    const statusRequest = data.loadStatusInfo(3, 1);
    expect(data.loading_status_modal.value).toBe(true);
    data.resetEntityContext();

    entity.resolve({ data: [{ entity_id: 1, symbol: 'stale' }] });
    review.resolve([{ review_id: 2, entity_id: 1, review_user_name: 'stale' }]);
    status.resolve([{ status_id: 3, entity_id: 1, category_id: 7, comment: 'stale', problematic: 0 }]);
    await Promise.all([entityRequest, reviewRequest, statusRequest]);

    expect(data.entity_info.symbol).toBe('');
    expect(data.review_info.review_id).toBeNull();
    expect(data.status_info.status_id).toBeNull();
    expect(data.loading_status_modal.value).toBe(false);
  });

  it('clears the spinner for a current status error while stale status errors do nothing', async () => {
    const currentError = deferred<unknown>();
    const stale = deferred<unknown>();
    const current = deferred<Array<Record<string, unknown>>>();
    getStatusByIdMock
      .mockReturnValueOnce(currentError.promise)
      .mockReturnValueOnce(stale.promise)
      .mockReturnValueOnce(current.promise);
    const errors: unknown[] = [];
    const data = useReviewData({ onError: (error) => errors.push(error) });

    const failedCurrentRequest = data.loadStatusInfo(1, 1);
    currentError.reject(new Error('current error'));
    await failedCurrentRequest;
    expect(data.loading_status_modal.value).toBe(false);
    expect(errors).toHaveLength(1);

    const staleRequest = data.loadStatusInfo(2, 2);
    const currentRequest = data.loadStatusInfo(3, 3);
    stale.reject(new Error('stale error'));
    await staleRequest;
    expect(data.loading_status_modal.value).toBe(true);
    expect(errors).toHaveLength(1);

    current.resolve([{ status_id: 3, entity_id: 1, category_id: 7, comment: '', problematic: 0 }]);
    await currentRequest;
    expect(data.loading_status_modal.value).toBe(false);
    expect(data.status_info.status_id).toBe(3);
  });

  it('removes old optional status metadata when the entity context resets', () => {
    const data = useReviewData();
    Object.assign(data.status_info, {
      status_id: 7,
      entity_id: 8,
      status_user_name: 'stale user',
      status_user_role: 'Reviewer',
      status_date: '2026-07-13',
      re_review_status_saved: 1,
    });

    data.resetEntityContext();

    expect(data.status_info.status_id).toBeNull();
    expect(data.status_info.entity_id).toBeNull();
    expect(data.status_info.status_user_name).toBeNull();
    expect(data.status_info.status_user_role).toBeNull();
    expect(data.status_info.status_date).toBeNull();
    expect(data.status_info.re_review_status_saved).toBeNull();
  });
});
