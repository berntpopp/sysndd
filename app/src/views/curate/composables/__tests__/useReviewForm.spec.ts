// views/curate/composables/__tests__/useReviewForm.spec.ts
/**
 * Unit tests for useReviewForm composable
 *
 * BUG-05: When adding a new PMID during re-review, existing PMIDs should be preserved.
 * These tests verify that original publications are stored and merged with new additions.
 *
 * v11.1 PR-followup: the composable now uses the typed `createReview` /
 * `updateReview` helpers from `@/api/review` for writes (collapsing the
 * earlier W4 `apiClient.put`/`apiClient.post` workaround). `re_review` is
 * passed via the helper's positional `params` argument so the wire-format
 * URL stays clean. The tests below mock the full typed-API surface — read
 * and write helpers alike.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

// Mock the typed-API surface BEFORE the composable imports it. This covers
// both the four read helpers and the two write helpers (createReview /
// updateReview) the composable now calls into.
const reviewApiMocks = vi.hoisted(() => ({
  getReviewById: vi.fn(),
  getReviewPhenotypes: vi.fn(),
  getReviewVariation: vi.fn(),
  getReviewPublications: vi.fn(),
  createReview: vi.fn(),
  updateReview: vi.fn(),
}));

vi.mock('@/api/review', () => reviewApiMocks);

// Mock useFormDraft composable
vi.mock('@/composables/useFormDraft', () => ({
  default: vi.fn(() => ({
    hasDraft: { value: false },
    lastSavedFormatted: { value: '' },
    isSaving: { value: false },
    loadDraft: vi.fn(() => null),
    clearDraft: vi.fn(),
    checkForDraft: vi.fn(() => false),
    scheduleSave: vi.fn(),
  })),
}));

import useReviewForm from '../useReviewForm';

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

interface ResolverMap {
  review?: Array<{ synopsis?: string; comment?: string; entity_id?: number }>;
  // Ontology ids are CURIE strings on the wire ("HP:0001249" / "VariO:0001").
  // `number` is accepted only for the legacy fixtures below; new tests should
  // use the real string shape (see the #600 regression block).
  phenotypes?: Array<{ phenotype_id: string | number; modifier_id: number }>;
  variation?: Array<{ vario_id: string | number; modifier_id: number }>;
  publications?: Array<{ publication_id: string; publication_type: string }>;
}

/**
 * Wires the four read mocks to the per-test fixture map. Mirrors the legacy
 * `mockAxios.get.mockImplementation((url) => ...)` switch on URL substring,
 * but at the typed-helper layer.
 */
function primeReadMocks(map: ResolverMap) {
  reviewApiMocks.getReviewById.mockResolvedValue(
    map.review ?? [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }]
  );
  reviewApiMocks.getReviewPhenotypes.mockResolvedValue(map.phenotypes ?? []);
  reviewApiMocks.getReviewVariation.mockResolvedValue(map.variation ?? []);
  reviewApiMocks.getReviewPublications.mockResolvedValue(map.publications ?? []);
}

describe('useReviewForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    reviewApiMocks.updateReview.mockResolvedValue({ status: 200 });
    reviewApiMocks.createReview.mockResolvedValue({ status: 200 });
  });

  describe('Change detection', () => {
    it('hasChanges is false when no data loaded', () => {
      const { hasChanges } = useReviewForm();
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is false immediately after loadReviewData', async () => {
      primeReadMocks({
        review: [{ synopsis: 'Test synopsis', comment: 'Test comment', entity_id: 1 }],
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { hasChanges, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      // Should be false immediately after load (no changes yet)
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is true when synopsis changes', async () => {
      primeReadMocks({
        review: [{ synopsis: 'Original synopsis', comment: '', entity_id: 1 }],
      });

      const { formData, hasChanges, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change synopsis
      formData.synopsis = 'Modified synopsis';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when comment changes', async () => {
      primeReadMocks({
        review: [{ synopsis: 'Test synopsis', comment: 'Original comment', entity_id: 1 }],
      });

      const { formData, hasChanges, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change comment
      formData.comment = 'Modified comment';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when publications change', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { formData, hasChanges, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Add a new publication
      formData.publications.push('PMID:99999999');

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges returns false after resetForm', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { formData, hasChanges, loadReviewData, resetForm } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      // Make changes
      formData.synopsis = 'Modified synopsis';
      expect(hasChanges.value).toBe(true);

      // Reset form
      resetForm();

      // Should be false after reset (no loaded data)
      expect(hasChanges.value).toBe(false);
    });
  });

  describe('request ownership', () => {
    it('keeps B form state when older A review data resolves last', async () => {
      const aReview = deferred<Array<{ synopsis: string; comment: string; entity_id: number }>>();
      const aPhenotypes = deferred<Array<{ phenotype_id: number; modifier_id: number }>>();
      const aVariation = deferred<Array<{ vario_id: number; modifier_id: number }>>();
      const aPublications = deferred<Array<{ publication_id: string; publication_type: string }>>();
      const bReview = deferred<Array<{ synopsis: string; comment: string; entity_id: number }>>();
      const bPhenotypes = deferred<Array<{ phenotype_id: number; modifier_id: number }>>();
      const bVariation = deferred<Array<{ vario_id: number; modifier_id: number }>>();
      const bPublications = deferred<Array<{ publication_id: string; publication_type: string }>>();
      reviewApiMocks.getReviewById.mockImplementation((id: number) =>
        id === 1 ? aReview.promise : bReview.promise
      );
      reviewApiMocks.getReviewPhenotypes.mockImplementation((id: number) =>
        id === 1 ? aPhenotypes.promise : bPhenotypes.promise
      );
      reviewApiMocks.getReviewVariation.mockImplementation((id: number) =>
        id === 1 ? aVariation.promise : bVariation.promise
      );
      reviewApiMocks.getReviewPublications.mockImplementation((id: number) =>
        id === 1 ? aPublications.promise : bPublications.promise
      );
      const { formData, loadReviewData } = useReviewForm();

      const loadA = loadReviewData(1);
      const loadB = loadReviewData(2);
      bReview.resolve([{ synopsis: 'B synopsis', comment: 'B', entity_id: 2 }]);
      bPhenotypes.resolve([]);
      bVariation.resolve([]);
      bPublications.resolve([]);
      await loadB;
      aReview.resolve([{ synopsis: 'A synopsis', comment: 'A', entity_id: 1 }]);
      aPhenotypes.resolve([]);
      aVariation.resolve([]);
      aPublications.resolve([]);
      await loadA;

      expect(formData.synopsis).toBe('B synopsis');
      expect(formData.comment).toBe('B');
    });
  });

  // ---------------------------------------------------------------------------
  // v11.1 PR-followup: the composable now uses the typed `updateReview` /
  // `createReview` helpers and passes `re_review` via their positional
  // `params` argument. The call shape this composable owns is:
  //   - first arg: `{ review_json }` body wrapper
  //   - second arg: `{ re_review: <boolean> }` params object
  // The wire-format URL stays clean (`/api/review/update` or `/api/review/
  // create`); axios serialises `re_review` onto the query string at request
  // time inside the helpers.
  // ---------------------------------------------------------------------------
  describe('typed helper call shape (post-PR-followup collapse)', () => {
    it('PUT update path: updateReview gets { review_json } body and { re_review: true } params', async () => {
      primeReadMocks({});

      const { loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      await submitForm(true, true);
      await flushPromises();

      expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);
      const [body, params] = reviewApiMocks.updateReview.mock.calls[0];
      expect(body).toHaveProperty('review_json');
      expect(params).toEqual({ re_review: true });
    });

    it('POST create path: createReview gets { review_json } body and { re_review: false } params', async () => {
      primeReadMocks({});

      const { loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      await submitForm(false, false);
      await flushPromises();

      expect(reviewApiMocks.createReview).toHaveBeenCalledTimes(1);
      const [body, params] = reviewApiMocks.createReview.mock.calls[0];
      expect(body).toHaveProperty('review_json');
      expect(params).toEqual({ re_review: false });
    });
  });

  // Regression: #600 — "Impossible to add tags and PubMed ID in Edit Review".
  //
  // Phenotype and variation-ontology ids are ONTOLOGY CURIEs ("HP:0001249",
  // "VariO:0001"), not integers — both `/api/review/<id>/phenotypes` and the
  // `/api/list/phenotype?tree=true` option ids encode them as
  // "<modifier_id>-<CURIE>". Coercing the CURIE half with `Number()` yields
  // NaN, which `JSON.stringify` serialises as `null`, so the API received
  // `phenotype_id: null` / `vario_id: null` and answered 500 ("Error
  // connecting phenotypes."). The ids must be submitted verbatim, exactly as
  // the working `useEntityMutations` create/modify path already does.
  describe('#600: ontology ids survive submission as CURIE strings', () => {
    it('submits phenotype/vario CURIEs verbatim instead of NaN', async () => {
      primeReadMocks({
        phenotypes: [
          { phenotype_id: 'HP:0001249', modifier_id: 1 },
          { phenotype_id: 'HP:0001250', modifier_id: 5 },
        ],
        variation: [{ vario_id: 'VariO:0015', modifier_id: 1 }],
      });

      const { formData, loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      // The loaded tags round-trip through the "<modifier>-<CURIE>" encoding
      // shared with the TreeMultiSelect option ids.
      expect(formData.phenotypes).toEqual(['1-HP:0001249', '5-HP:0001250']);
      expect(formData.variationOntology).toEqual(['1-VariO:0015']);

      // Simulate the reporter adding one more phenotype tag in the modal.
      formData.phenotypes.push('1-HP:0000707');

      await submitForm(true, true);
      await flushPromises();

      const submitted = (
        reviewApiMocks.updateReview.mock.calls[0][0] as {
          review_json: {
            phenotypes: Array<{ phenotype_id: unknown; modifier_id: unknown }>;
            variation_ontology: Array<{ vario_id: unknown; modifier_id: unknown }>;
          };
        }
      ).review_json;

      expect(submitted.phenotypes).toEqual([
        { phenotype_id: 'HP:0001249', modifier_id: 1 },
        { phenotype_id: 'HP:0001250', modifier_id: 5 },
        { phenotype_id: 'HP:0000707', modifier_id: 1 },
      ]);
      expect(submitted.variation_ontology).toEqual([{ vario_id: 'VariO:0015', modifier_id: 1 }]);

      // Guard the exact failure mode: nothing may serialise to null.
      const wire = JSON.parse(JSON.stringify(submitted));
      expect(wire.phenotypes.every((p: { phenotype_id: unknown }) => p.phenotype_id !== null)).toBe(
        true
      );
      expect(wire.variation_ontology.every((v: { vario_id: unknown }) => v.vario_id !== null)).toBe(
        true
      );
    });

    it('names the synopsis field when the blocking rule rejects the submit', async () => {
      // Re-review batches routinely contain reviews with no synopsis yet; the
      // old generic message made that read as "adding tags is broken".
      primeReadMocks({ review: [{ synopsis: '', comment: '', entity_id: 1 }] });

      const { loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      await expect(submitForm(true, true)).rejects.toThrow(/Synopsis is required/);
      expect(reviewApiMocks.updateReview).not.toHaveBeenCalled();
    });

    it('keeps the CURIE intact when it contains no separator ambiguity', async () => {
      primeReadMocks({ phenotypes: [{ phenotype_id: 'HP:0011451', modifier_id: 3 }] });

      const { loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      await submitForm(true, true);
      await flushPromises();

      const submitted = (
        reviewApiMocks.updateReview.mock.calls[0][0] as {
          review_json: { phenotypes: Array<{ phenotype_id: unknown; modifier_id: unknown }> };
        }
      ).review_json;

      expect(submitted.phenotypes).toEqual([{ phenotype_id: 'HP:0011451', modifier_id: 3 }]);
    });
  });
});
