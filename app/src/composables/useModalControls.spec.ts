// useModalControls.spec.ts
/**
 * Tests for useModalControls composable
 *
 * Pattern: Mocked dependency testing with withSetup
 * This composable wraps bootstrap-vue-next's useModal.
 * Demonstrates testing composables that provide thin wrappers around library APIs.
 *
 * Key learning:
 * - Same mocking pattern as useToast
 * - Test async operations (confirm returns Promise)
 * - Verify method delegation to underlying library
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { withSetup } from '@/test-utils';

// Mock bootstrap-vue-next BEFORE importing the composable
const mockShow = vi.fn();
const mockHide = vi.fn();
const mockConfirm = vi.fn().mockResolvedValue(true);

vi.mock('bootstrap-vue-next', () => ({
  useModal: () => ({
    show: mockShow,
    hide: mockHide,
    confirm: mockConfirm,
  }),
}));

// Import AFTER mock is set up
import useModalControls from './useModalControls';

describe('useModalControls', () => {
  beforeEach(() => {
    mockShow.mockClear();
    mockHide.mockClear();
    mockConfirm.mockClear();
    // Reset the default mock implementation
    mockConfirm.mockResolvedValue(true);
  });

  describe('method availability', () => {
    it('provides showModal method', () => {
      const [result, app] = withSetup(() => useModalControls());

      expect(result.showModal).toBeDefined();
      expect(typeof result.showModal).toBe('function');

      app.unmount();
    });

    it('provides hideModal method', () => {
      const [result, app] = withSetup(() => useModalControls());

      expect(result.hideModal).toBeDefined();
      expect(typeof result.hideModal).toBe('function');

      app.unmount();
    });

    it('provides confirm method', () => {
      const [result, app] = withSetup(() => useModalControls());

      expect(result.confirm).toBeDefined();
      expect(typeof result.confirm).toBe('function');

      app.unmount();
    });
  });

  describe('showModal', () => {
    it('calls modal.show with provided ID', () => {
      const [result, app] = withSetup(() => useModalControls());

      result.showModal('my-modal-id');

      expect(mockShow).toHaveBeenCalledWith('my-modal-id');
      expect(mockShow).toHaveBeenCalledTimes(1);

      app.unmount();
    });

    it('can show different modals', () => {
      const [result, app] = withSetup(() => useModalControls());

      result.showModal('modal-1');
      result.showModal('modal-2');
      result.showModal('confirmation-modal');

      expect(mockShow).toHaveBeenNthCalledWith(1, 'modal-1');
      expect(mockShow).toHaveBeenNthCalledWith(2, 'modal-2');
      expect(mockShow).toHaveBeenNthCalledWith(3, 'confirmation-modal');

      app.unmount();
    });
  });

  describe('hideModal', () => {
    it('calls modal.hide with provided ID', () => {
      const [result, app] = withSetup(() => useModalControls());

      result.hideModal('my-modal-id');

      expect(mockHide).toHaveBeenCalledWith('my-modal-id');
      expect(mockHide).toHaveBeenCalledTimes(1);

      app.unmount();
    });

    it('can hide different modals', () => {
      const [result, app] = withSetup(() => useModalControls());

      result.hideModal('modal-a');
      result.hideModal('modal-b');

      expect(mockHide).toHaveBeenNthCalledWith(1, 'modal-a');
      expect(mockHide).toHaveBeenNthCalledWith(2, 'modal-b');

      app.unmount();
    });
  });

  describe('confirm', () => {
    it('returns a promise that resolves with user choice', async () => {
      const [result, app] = withSetup(() => useModalControls());

      const confirmed = await result.confirm({ title: 'Confirm?' });

      expect(confirmed).toBe(true);
      expect(mockConfirm).toHaveBeenCalledWith({ title: 'Confirm?' });

      app.unmount();
    });

    it('handles user confirmation (true)', async () => {
      mockConfirm.mockResolvedValueOnce(true);
      const [result, app] = withSetup(() => useModalControls());

      const confirmed = await result.confirm({ title: 'Proceed?' });

      expect(confirmed).toBe(true);

      app.unmount();
    });

    it('handles user rejection (false)', async () => {
      mockConfirm.mockResolvedValueOnce(false);
      const [result, app] = withSetup(() => useModalControls());

      const confirmed = await result.confirm({ title: 'Cancel?' });

      expect(confirmed).toBe(false);

      app.unmount();
    });

    it('passes options to underlying confirm method', async () => {
      const [result, app] = withSetup(() => useModalControls());

      const options = {
        title: 'Delete item?',
        body: 'This action cannot be undone.',
        okTitle: 'Delete',
        cancelTitle: 'Keep',
      };

      await result.confirm(options);

      expect(mockConfirm).toHaveBeenCalledWith(options);

      app.unmount();
    });

    it('can be called multiple times', async () => {
      const [result, app] = withSetup(() => useModalControls());

      mockConfirm
        .mockResolvedValueOnce(true)
        .mockResolvedValueOnce(false)
        .mockResolvedValueOnce(true);

      const first = await result.confirm({ title: 'First?' });
      const second = await result.confirm({ title: 'Second?' });
      const third = await result.confirm({ title: 'Third?' });

      expect(first).toBe(true);
      expect(second).toBe(false);
      expect(third).toBe(true);
      expect(mockConfirm).toHaveBeenCalledTimes(3);

      app.unmount();
    });
  });

  describe('integration patterns', () => {
    it('supports show-then-hide workflow', () => {
      const [result, app] = withSetup(() => useModalControls());

      result.showModal('edit-modal');
      // ... user makes changes ...
      result.hideModal('edit-modal');

      expect(mockShow).toHaveBeenCalledWith('edit-modal');
      expect(mockHide).toHaveBeenCalledWith('edit-modal');

      app.unmount();
    });

    it('supports confirmation before action workflow', async () => {
      mockConfirm.mockResolvedValueOnce(true);
      const [result, app] = withSetup(() => useModalControls());

      // Simulate: user clicks delete button
      const shouldDelete = await result.confirm({ title: 'Delete item?' });

      if (shouldDelete) {
        // Would call API to delete item
        result.hideModal('item-list-modal');
      }

      expect(shouldDelete).toBe(true);
      expect(mockHide).toHaveBeenCalledWith('item-list-modal');

      app.unmount();
    });
  });
});
