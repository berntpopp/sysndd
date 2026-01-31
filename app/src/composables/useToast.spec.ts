// useToast.spec.ts
/**
 * Tests for useToast composable
 *
 * Pattern: Mocked dependency testing with withSetup
 * This composable uses bootstrap-vue-next's useToast, which must be mocked.
 * Demonstrates testing composables that depend on external libraries.
 *
 * Key learning:
 * - Mock external dependencies BEFORE importing the composable
 * - Use withSetup helper for composables that need Vue lifecycle context
 * - Always unmount the app after each test to clean up
 * - Test medical app requirement: danger toasts don't auto-hide
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { withSetup } from '@/test-utils';

// Mock bootstrap-vue-next BEFORE importing the composable under test
const mockCreate = vi.fn();
vi.mock('bootstrap-vue-next', () => ({
  useToast: () => ({
    create: mockCreate,
  }),
}));

// Import AFTER mock is set up (module hoisting)
import useToast from './useToast';

describe('useToast', () => {
  beforeEach(() => {
    mockCreate.mockClear();
  });

  describe('makeToast method', () => {
    it('provides makeToast method', () => {
      const [result, app] = withSetup(() => useToast());

      expect(result.makeToast).toBeDefined();
      expect(typeof result.makeToast).toBe('function');

      app.unmount();
    });

    it('creates toast with string message', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Test message', 'Test Title', 'success');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Test message',
          title: 'Test Title',
          variant: 'success',
          pos: 'top-end',
        })
      );

      app.unmount();
    });

    it('extracts message from object with message property', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast({ message: 'Object message' }, 'Title', 'info');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Object message',
        })
      );

      app.unmount();
    });

    it('handles null title', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Message', null, 'success');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Message',
          title: null,
        })
      );

      app.unmount();
    });

    it('handles null variant', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Message', 'Title', null);

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          body: 'Message',
          variant: null,
        })
      );

      app.unmount();
    });

    it('positions toast at top-end', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Message', 'Title', 'success');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          pos: 'top-end',
        })
      );

      app.unmount();
    });
  });

  describe('medical app requirements', () => {
    it('danger toasts do not auto-hide (critical for error visibility)', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Critical error', 'Error', 'danger');

      // modelValue: -1 means no auto-hide (negative value disables auto-hide)
      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'danger',
          modelValue: -1, // No auto-hide for danger
        })
      );

      app.unmount();
    });

    it('danger toasts ignore autoHide parameter', () => {
      const [result, app] = withSetup(() => useToast());

      // Even with autoHide=true, danger should not auto-hide
      result.makeToast('Critical error', 'Error', 'danger', true, 5000);

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'danger',
          modelValue: -1, // Forced to -1 regardless of parameters
        })
      );

      app.unmount();
    });

    it('success toasts auto-hide after default delay', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Success message', 'Success', 'success');

      // Default autoHideDelay is 3000
      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'success',
          modelValue: 3000, // Auto-hide after 3s
        })
      );

      app.unmount();
    });

    it('warning toasts auto-hide after default delay', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Warning message', 'Warning', 'warning');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'warning',
          modelValue: 3000,
        })
      );

      app.unmount();
    });

    it('info toasts auto-hide after default delay', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Info message', 'Info', 'info');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'info',
          modelValue: 3000,
        })
      );

      app.unmount();
    });

    it('respects custom autoHideDelay for non-danger toasts', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Custom delay', 'Info', 'info', true, 5000);

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          modelValue: 5000,
        })
      );

      app.unmount();
    });

    it('can disable auto-hide for non-danger toasts', () => {
      const [result, app] = withSetup(() => useToast());

      result.makeToast('Persistent info', 'Info', 'info', false);

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          modelValue: -1, // Negative value disables auto-hide
        })
      );

      app.unmount();
    });
  });

  describe('toast variants', () => {
    const variants = ['success', 'danger', 'warning', 'info', 'primary', 'secondary'] as const;

    variants.forEach((variant) => {
      it(`handles ${variant} variant`, () => {
        const [result, app] = withSetup(() => useToast());

        result.makeToast(`${variant} message`, 'Title', variant);

        expect(mockCreate).toHaveBeenCalledWith(
          expect.objectContaining({
            variant,
          })
        );

        app.unmount();
      });
    });
  });
});
