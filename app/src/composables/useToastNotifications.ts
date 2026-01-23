import { useToast } from 'bootstrap-vue-next';
import type { ToastNotifications, ToastVariant } from '@/types/components';

/**
 * Composable for toast notifications using Bootstrap-Vue-Next
 * Must be called within setup() context
 * @returns {ToastNotifications} Toast notification methods
 */
export default function useToastNotifications(): ToastNotifications {
  const toast = useToast();

  /**
   * Show a toast notification
   * @param {string|object} message - Message to display (or object with message property)
   * @param {string} title - Toast title
   * @param {string} variant - Bootstrap variant (success, danger, warning, info)
   * @param {boolean} autoHide - Whether to auto-dismiss (default: true)
   * @param {number} autoHideDelay - Delay in ms before auto-hide (default: 3000)
   */
  const makeToast = (
    message: string | { message: string },
    title: string | null = null,
    variant: ToastVariant | null = null,
    autoHide: boolean = true,
    autoHideDelay: number = 3000,
  ): void => {
    const body = typeof message === 'object' && message.message ? message.message : message;

    toast.create({
      title,
      body,
      variant,
      pos: 'top-end',
      modelValue: autoHide ? autoHideDelay : 0, // 0 means no auto-hide
    });
  };

  return { makeToast };
}
