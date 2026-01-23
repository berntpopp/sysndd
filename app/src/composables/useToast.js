import { useToast as useBootstrapToast } from 'bootstrap-vue-next';

/**
 * Composable for toast notifications with medical app error handling.
 * Error toasts (danger variant) force manual close to ensure critical messages are seen.
 *
 * This differs from useToastNotifications by implementing medical app requirements:
 * - Danger variant toasts never auto-hide (user must manually dismiss)
 * - Ensures critical error messages aren't missed
 *
 * @returns {Object} Toast notification methods
 */
export default function useToast() {
  const toast = useBootstrapToast();

  /**
   * Show a toast notification
   * @param {string|object} message - Message to display (or object with message property)
   * @param {string|null} title - Toast title
   * @param {string|null} variant - Bootstrap variant (success, danger, warning, info)
   * @param {boolean} autoHide - Whether to auto-dismiss (default: true, but false for danger)
   * @param {number} autoHideDelay - Delay in ms before auto-hide (default: 3000)
   */
  const makeToast = (message, title = null, variant = null, autoHide = true, autoHideDelay = 3000) => {
    const body = typeof message === 'object' && message.message ? message.message : message;

    // For error toasts (danger variant), disable auto-hide per medical app requirements
    // This ensures users don't miss important error messages
    const shouldAutoHide = variant === 'danger' ? false : autoHide;

    toast.create({
      title,
      body,
      variant,
      pos: 'top-end',
      modelValue: shouldAutoHide ? autoHideDelay : 0, // 0 means no auto-hide
    });
  };

  return { makeToast };
}
