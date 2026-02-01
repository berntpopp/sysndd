// views/curate/composables/__tests__/useReviewForm.spec.ts
/**
 * Unit tests for useReviewForm composable
 *
 * BUG-05: When adding a new PMID during re-review, existing PMIDs should be preserved.
 * These tests verify that original publications are stored and merged with new additions.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import useReviewForm from '../useReviewForm';

// Mock axios
vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
  },
}));

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

describe('useReviewForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('BUG-05: Publication preservation during re-review', () => {
    it('stores original publications when loading review data', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
      };

      // Mock API responses
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [
              { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
              { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
              { publication_id: 'PMID:11111111', publication_type: 'gene_review' },
            ],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        // Default review response
        return Promise.resolve({
          data: [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
        });
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
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
      };

      // Mock API responses
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [
              { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
              { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
            ],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        return Promise.resolve({
          data: [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
        });
      });

      mockAxios.put.mockResolvedValue({ data: { success: true } });

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate user adding a new publication
      formData.publications.push('PMID:99999999');

      // Submit the form
      await submitForm(true, true);
      await flushPromises();

      // Verify the PUT request was called with merged publications
      expect(mockAxios.put).toHaveBeenCalledTimes(1);
      const putCall = mockAxios.put.mock.calls[0];
      const submittedData = putCall[1].review_json;

      // Should contain all 3 publications (2 original + 1 new)
      expect(submittedData.literature.additional_references).toHaveLength(3);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
      expect(submittedData.literature.additional_references).toContain('PMID:87654321');
      expect(submittedData.literature.additional_references).toContain('PMID:99999999');
    });

    it('handles scenario where form publications array is empty but originals exist', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
      };

      // Mock API responses with existing publications
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [{ publication_id: 'PMID:12345678', publication_type: 'additional_references' }],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        return Promise.resolve({
          data: [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
        });
      });

      mockAxios.put.mockResolvedValue({ data: { success: true } });

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
      const putCall = mockAxios.put.mock.calls[0];
      const submittedData = putCall[1].review_json;

      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
    });

    it('deduplicates publications when same PMID exists in both original and form', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
      };

      // Mock API responses
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [{ publication_id: 'PMID:12345678', publication_type: 'additional_references' }],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        return Promise.resolve({
          data: [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
        });
      });

      mockAxios.put.mockResolvedValue({ data: { success: true } });

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
      const putCall = mockAxios.put.mock.calls[0];
      const submittedData = putCall[1].review_json;

      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:12345678');
    });

    it('clears original publications on form reset', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
      };

      // Mock API responses
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [{ publication_id: 'PMID:12345678', publication_type: 'additional_references' }],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        return Promise.resolve({
          data: [{ synopsis: 'Test synopsis', comment: '', entity_id: 1 }],
        });
      });

      mockAxios.put.mockResolvedValue({ data: { success: true } });

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
      mockAxios.get.mockImplementation((url: string) => {
        if (url.includes('/publications')) {
          return Promise.resolve({
            data: [{ publication_id: 'PMID:99999999', publication_type: 'additional_references' }],
          });
        }
        if (url.includes('/phenotypes')) {
          return Promise.resolve({ data: [] });
        }
        if (url.includes('/variation')) {
          return Promise.resolve({ data: [] });
        }
        return Promise.resolve({
          data: [{ synopsis: 'Different synopsis', comment: '', entity_id: 2 }],
        });
      });

      await loadReviewData(2);
      await flushPromises();

      // Submit the form - should only have the new publication, not the old one
      await submitForm(true, true);
      await flushPromises();

      const putCall = mockAxios.put.mock.calls[0];
      const submittedData = putCall[1].review_json;

      // Should only contain the new publication
      expect(submittedData.literature.additional_references).toHaveLength(1);
      expect(submittedData.literature.additional_references).toContain('PMID:99999999');
      expect(submittedData.literature.additional_references).not.toContain('PMID:12345678');
    });
  });
});
