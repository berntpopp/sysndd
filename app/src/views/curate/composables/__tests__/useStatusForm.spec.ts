// views/curate/composables/__tests__/useStatusForm.spec.ts
/**
 * Unit tests for useStatusForm composable
 *
 * Tests change detection functionality to enable silent skip when no changes are made
 *
 * v11.1 W4: the composable migrated from raw `axios.{get,put,post}(...)` to
 * the typed `@/api/status` + `@/api/entity` clients. The tests now mock
 * those helpers directly — keeps the change-detection contract intact while
 * letting the helper layer remain the single source of HTTP shape truth.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

// Mock the typed-API surface BEFORE the composable imports it.
const statusApiMocks = vi.hoisted(() => ({
  getStatusById: vi.fn(),
  createStatus: vi.fn(),
  updateStatus: vi.fn(),
}));
const entityApiMocks = vi.hoisted(() => ({
  getEntityStatus: vi.fn(),
}));

vi.mock('@/api/status', () => statusApiMocks);
vi.mock('@/api/entity', () => entityApiMocks);

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

import useStatusForm from '../useStatusForm';

describe('useStatusForm', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    statusApiMocks.createStatus.mockResolvedValue({ status: 200 });
    statusApiMocks.updateStatus.mockResolvedValue({ status: 200 });
  });

  describe('Change detection', () => {
    it('hasChanges is false when no data loaded', () => {
      const { hasChanges } = useStatusForm();
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is false immediately after loadStatusByEntity', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Test comment',
          problematic: false,
        },
      ]);

      const { hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      // Should be false immediately after load (no changes yet)
      expect(hasChanges.value).toBe(false);
    });

    it('hasChanges is true when category_id changes', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Test comment',
          problematic: false,
        },
      ]);

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change category_id
      formData.category_id = 3;

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when comment changes', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Original comment',
          problematic: false,
        },
      ]);

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Change comment
      formData.comment = 'Modified comment';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges is true when problematic changes', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Test comment',
          problematic: false,
        },
      ]);

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Toggle problematic flag
      formData.problematic = true;

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges detects whitespace changes in comment (exact comparison)', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Test comment',
          problematic: false,
        },
      ]);

      const { formData, hasChanges, loadStatusByEntity } = useStatusForm();

      await loadStatusByEntity(123);
      await flushPromises();

      expect(hasChanges.value).toBe(false);

      // Add trailing space (exact comparison should detect this)
      formData.comment = 'Test comment ';

      expect(hasChanges.value).toBe(true);
    });

    it('hasChanges returns false after resetForm', async () => {
      entityApiMocks.getEntityStatus.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 123,
          category_id: 2,
          comment: 'Test comment',
          problematic: false,
        },
      ]);

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
      statusApiMocks.getStatusById.mockResolvedValue([
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
      ]);

      const { hasChanges, loadStatusData } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();

      // Should be false immediately after loading via loadStatusData
      expect(hasChanges.value).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // v11.1 W4: the F2a header-policy assertion from the legacy spec moved up to
  // the typed-API layer (`@/api/status` → `@/api/client`). The composable
  // forwards a body and a `params` argument; it can no longer attach an
  // inline `headers` field. The typed-helper test suite owns the header
  // contract now (`app/src/api/status.spec.ts`), so this spec asserts only
  // the call shape the composable controls — body wrapping plus the
  // re_review query param toggle.
  // ---------------------------------------------------------------------------
  describe('Typed-API call shape (post-W4 migration)', () => {
    beforeEach(() => {
      statusApiMocks.getStatusById.mockResolvedValue([
        {
          status_id: 1,
          entity_id: 99,
          category_id: 2,
          comment: 'load',
          problematic: false,
        },
      ]);
    });

    it('updateStatus is called with { status_json } body and re_review=false by default', async () => {
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(true, false);
      await flushPromises();

      expect(statusApiMocks.updateStatus).toHaveBeenCalledTimes(1);
      const [body, params] = statusApiMocks.updateStatus.mock.calls[0];
      expect(body).toHaveProperty('status_json');
      // Default behaviour: when re_review=false the composable passes an
      // empty params object (only sets the flag when re_review is truthy).
      expect(params).toEqual({});
    });

    it('createStatus is called with { status_json } body and re_review=true when requested', async () => {
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(false, true);
      await flushPromises();

      expect(statusApiMocks.createStatus).toHaveBeenCalledTimes(1);
      const [body, params] = statusApiMocks.createStatus.mock.calls[0];
      expect(body).toHaveProperty('status_json');
      expect(params).toEqual({ re_review: true });
    });

    // Issue #37 — direct approval is threaded as a query param so the server
    // can approve the freshly written status in the same request.
    it('createStatus is called with direct_approval=true when requested', async () => {
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(false, false, true);
      await flushPromises();

      expect(statusApiMocks.createStatus).toHaveBeenCalledTimes(1);
      const [, params] = statusApiMocks.createStatus.mock.calls[0];
      expect(params).toEqual({ direct_approval: true });
    });

    it('createStatus omits direct_approval when the flag is false', async () => {
      const { loadStatusData, submitForm } = useStatusForm();

      await loadStatusData(1, 0);
      await flushPromises();
      await submitForm(false, false, false);
      await flushPromises();

      const [, params] = statusApiMocks.createStatus.mock.calls[0];
      expect(params).toEqual({});
    });
  });
});
