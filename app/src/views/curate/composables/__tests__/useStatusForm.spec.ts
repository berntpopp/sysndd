// views/curate/composables/__tests__/useStatusForm.spec.ts
/**
 * Unit tests for useStatusForm composable
 *
 * Tests change detection functionality to enable silent skip when no changes are made
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import useStatusForm from '../useStatusForm';

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

describe('useStatusForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Change detection', () => {
    it('hasChanges is false when no data loaded', () => {
      const { hasChanges } = useStatusForm();
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is false immediately after loadStatusByEntity', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      // Mock API response
      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment',
            problematic: false,
          },
        ],
      });

      const { hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      // Should be false immediately after load (no changes yet)
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is true when category_id changes', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment',
            problematic: false,
          },
        ],
      });

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change category_id
      formData.category_id = 3;

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when comment changes', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Original comment',
            problematic: false,
          },
        ],
      });

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change comment
      formData.comment = 'Modified comment';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when problematic changes', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment',
            problematic: false,
          },
        ],
      });

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Toggle problematic flag
      formData.problematic = true;

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges detects whitespace changes in comment (exact comparison)', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment',
            problematic: false,
          },
        ],
      });

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Add trailing space (exact comparison should detect this)
      formData.comment = 'Test comment ';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges returns false after resetForm', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment',
            problematic: false,
          },
        ],
      });

      const { formData, hasChanges, loadStatusByEntity, resetForm } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      // Make changes
      formData.comment = 'Modified';
      expect(hasChanges.value).toBe(true);

      // Reset form
      resetForm();

      // Should be false after reset (no loaded data)
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is false after loadStatusData', async () => {
      const axios = await import('axios');
      const mockAxios = axios.default as unknown as {
        get: ReturnType<typeof vi.fn>;
      };

      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 123,
            category_id: 2,
            comment: 'Test comment via loadStatusData',
            problematic: true,
            status_user_name: 'test_user',
            status_user_role: 'curator',
            status_date: '2024-01-01',
          },
        ],
      });

      const { hasChanges, loadStatusData } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();

      // Should be false immediately after loading via loadStatusData
      expect(hasChanges.value).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // v11.0 closeout F2a: authenticated submit no longer attaches an inline
  // Authorization header — the apiClient request interceptor
  // (`@/api/client`) injects the Bearer token on every outbound call against
  // the shared axios singleton. `useStatusForm.ts` used to read
  // `localStorage.getItem('token')` twice (update + create paths) and
  // attach `Authorization: Bearer <token>` via the request config; both of
  // those are gone. Because this file mocks the axios module wholesale we
  // cannot test interceptor behaviour directly; we assert the *source-
  // level* contract instead — the config passed to axios.put/post has no
  // `headers` field. A regression that re-adds the inline header would
  // fail this assertion.
  // ---------------------------------------------------------------------------
  describe('F2a: submit no longer supplies an inline Authorization header', () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    async function primeAxiosWithStatusRow() {
      const axiosMod = await import('axios');
      const mockAxios = axiosMod.default as unknown as {
        get: ReturnType<typeof vi.fn>;
        put: ReturnType<typeof vi.fn>;
        post: ReturnType<typeof vi.fn>;
      };
      mockAxios.get.mockResolvedValue({
        data: [
          {
            status_id: 1,
            entity_id: 99,
            category_id: 2,
            comment: 'load',
            problematic: false,
          },
        ],
      });
      mockAxios.put.mockResolvedValue({ data: { success: true } });
      mockAxios.post.mockResolvedValue({ data: { success: true } });
      return mockAxios;
    }

    it('axios.put config (update path) has no headers field', async () => {
      const mockAxios = await primeAxiosWithStatusRow();
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(true, false);
      await flushPromises();

      expect(mockAxios.put).toHaveBeenCalledTimes(1);
      const config = mockAxios.put.mock.calls[0][2] as
        | { headers?: Record<string, string>; withCredentials?: boolean }
        | undefined;
      expect(config).toBeDefined();
      expect(config?.withCredentials).toBe(true);
      expect(config?.headers).toBeUndefined();
    });

    it('axios.post config (create path) has no headers field', async () => {
      const mockAxios = await primeAxiosWithStatusRow();
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(false, false);
      await flushPromises();

      expect(mockAxios.post).toHaveBeenCalledTimes(1);
      const config = mockAxios.post.mock.calls[0][2] as
        | { headers?: Record<string, string>; withCredentials?: boolean }
        | undefined;
      expect(config).toBeDefined();
      expect(config?.withCredentials).toBe(true);
      expect(config?.headers).toBeUndefined();
    });
  });
});
