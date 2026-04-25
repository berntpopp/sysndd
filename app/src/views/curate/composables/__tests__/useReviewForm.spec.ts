// views/curate/composables/__tests__/useReviewForm.spec.ts
/**
 * Unit tests for useReviewForm composable
 *
 * BUG-05: When adding a new PMID during re-review, existing PMIDs should be preserved.
 * These tests verify that original publications are stored and merged with new additions.
 *
 * v11.1 W4: the composable migrated from raw `axios.{get,put,post}(...)` to
 * the typed `@/api/review` clients. The tests now mock those helpers
 * directly — keeps the BUG-05 + change-detection contracts intact while
 * letting the helper layer remain the single source of HTTP shape truth.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

// Mock the typed-API surface BEFORE the composable imports it.
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

interface ResolverMap {
  review?: Array<{ synopsis?: string; comment?: string; entity_id?: number }>;
  phenotypes?: Array<{ phenotype_id: number; modifier_id: number }>;
  variation?: Array<{ vario_id: number; modifier_id: number }>;
  publications?: Array<{ publication_id: string; publication_type: string }>;
}

/**
 * Wires the four read mocks to the per-test fixture map. Mirrors the legacy
 * `mockAxios.get.mockImplementation((url) => ...)` switch on URL substring,
 * but at the typed-helper layer.
 */
function primeReadMocks(map: ResolverMap) {
  reviewApiMocks.getReviewById.mockResolvedValue(
    map.review ?? [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
  );
  reviewApiMocks.getReviewPhenotypes.mockResolvedValue(map.phenotypes ?? []);
  reviewApiMocks.getReviewVariation.mockResolvedValue(map.variation ?? []);
  reviewApiMocks.getReviewPublications.mockResolvedValue(map.publications ?? []);
}

describe('useReviewForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    reviewApiMocks.createReview.mockResolvedValue({ status: 200 });
    reviewApiMocks.updateReview.mockResolvedValue({ status: 200 });
  });

  describe('BUG-05: Publication preservation during re-review', () => {
    it('stores original publications when loading review data', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
          { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
          { publication_id: 'PMID:11111111', publication_type: 'gene_review' },
        ],
      });

      const { formData, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      // Verify publications are loaded into formData
      expect(formData.publications).toHaveLength(2);
      expect(formData.publications).toContain('PMID:12345678');
      expect(formData.publications).toContain('PMID:87654321');

      // Verify genereviews are loaded
      expect(formData.genereviews).toHaveLength(1);
      expect(formData.genereviews).toContain('PMID:11111111');
    });

    it('merges original publications with new additions on submit', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
          { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
        ],
      });

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate user adding a new publication
      formData.publications.push('PMID:99999999');

      // Submit the form (isUpdate=true → PUT)
      await submitForm(true, true);
      await flushPromises();

      // Verify the typed PUT was called with merged publications
      expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);
      const putCall = reviewApiMocks.updateReview.mock.calls[0];
      const submittedData = (putCall[0] as { review_json: { literature: { additional_references: string[] } } })
        .review_json;

      // Should contain all 3 publications (2 original + 1 new)
      expect(submittedData.literature.additional_references).toHaveLength(3);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
      expect(submittedData.literature.additional_references).toContain('PMID:87654321');
      expect(submittedData.literature.additional_references).toContain('PMID:99999999');
    });

    it('handles scenario where form publications array is empty but originals exist', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate form reactivity issue - formData.publications gets cleared
      formData.publications = [];

      // Submit the form - original publications should still be preserved
      await submitForm(true, true);
      await flushPromises();

      // Verify original publication was preserved despite formData being empty
      const putCall = reviewApiMocks.updateReview.mock.calls[0];
      const submittedData = (putCall[0] as { review_json: { literature: { additional_references: string[] } } })
        .review_json;

      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
    });

    it('deduplicates publications when same PMID exists in both original and form', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate user adding the same PMID that already exists
      formData.publications.push('PMID:12345678'); // Duplicate

      // Submit the form
      await submitForm(true, true);
      await flushPromises();

      // Verify no duplicates in submitted data
      const putCall = reviewApiMocks.updateReview.mock.calls[0];
      const submittedData = (putCall[0] as { review_json: { literature: { additional_references: string[] } } })
        .review_json;

      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
    });

    it('clears original publications on form reset', async () => {
      primeReadMocks({
        publications: [
          { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        ],
      });

      const { formData, loadReviewData, resetForm, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      expect(formData.publications).toHaveLength(1);

      // Reset the form
      resetForm();

      // Verify form data is cleared
      expect(formData.publications).toHaveLength(0);
      expect(formData.synopsis).toBe('');

      // Load new review data with different publications
      primeReadMocks({
        review: [{ synopsis: 'Different synopsis', comment: '', entity_id: 2 }],
        publications: [
          { publication_id: 'PMID:99999999', publication_type: 'additional_references' },
        ],
      });

      await loadReviewData(2);
      await flushPromises();

      // Submit the form - should only have the new publication, not the old one
      await submitForm(true, true);
      await flushPromises();

      const putCall = reviewApiMocks.updateReview.mock.calls[0];
      const submittedData = (putCall[0] as { review_json: { literature: { additional_references: string[] } } })
        .review_json;

      // Should only contain the new publication
      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:99999999');
      expect(submittedData.literature.additional_references).not.toContain('PMID:12345678');
    });
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

  // ---------------------------------------------------------------------------
  // v11.1 W4: the F2a header-policy assertion from the legacy spec moved up to
  // the typed-API layer (`@/api/review` → `@/api/client`). The composable
  // forwards a body and a `params` argument; it can no longer attach an
  // inline `headers` field. The typed-helper test suite owns the header
  // contract now (`app/src/api/review.spec.ts`), so this spec asserts only
  // the call shape the composable controls — body wrapping and the
  // `re_review` query param.
  // ---------------------------------------------------------------------------
  describe('Typed-API call shape (post-W4 migration)', () => {
    it('updateReview is called with { review_json } body and re_review param', async () => {
      primeReadMocks({});

      const { loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      await submitForm(true, false);
      await flushPromises();

      expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);
      const [body, params] = reviewApiMocks.updateReview.mock.calls[0];
      const wrappedBody = body as { review_json: unknown };
      expect(wrappedBody).toHaveProperty('review_json');
      expect(params).toEqual({ re_review: false });
    });
  });
});
