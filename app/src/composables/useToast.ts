import { useToast as useBootstrapToast } from 'bootstrap-vue-next';
import type { ToastVariant } from '@/types/components';

/**
 * Composable for toast notifications with medical app error handling.
 * Error toasts (danger variant) force manual close to ensure critical messages are seen.
 *
 * This differs from useToastNotifications by implementing medical app requirements:
 * - Danger variant toasts never auto-hide (user must manually dismiss)
 * - Ensures critical error messages aren't missed
 *
 * @returns Toast notification methods
 */

interface ToastMethods {
  makeToast: (
    message: string | { message: string },
    title?: string | null,
    variant?: ToastVariant | null,
    autoHide?: boolean,
    autoHideDelay?: number
  ) => void;
}

export default function useToast(): ToastMethods {
  const toast = useBootstrapToast();

  /**
   * Show a toast notification
   * @param message - Message to display (or object with message property)
   * @param title - Toast title
   * @param variant - Bootstrap variant (success, danger, warning, info)
   * @param autoHide - Whether to auto-dismiss (default: true, but false for danger)
   * @param autoHideDelay - Delay in ms before auto-hide (default: 3000)
   */
  const makeToast = (
    message: string | { message: string },
    title: string | null = null,
    variant: ToastVariant | null = null,
    autoHide: boolean = true,
    autoHideDelay: number = 3000
  ): void => {
    const body: string =
      typeof message === 'object' && message.message ? message.message : (message as string);

    // For error toasts (danger variant), disable auto-hide per medical app requirements
    // This ensures users don't miss important error messages
    const shouldAutoHide = variant === 'danger' ? false : autoHide;

    toast.create({
      title,
      body,
      variant,
      pos: 'top-end',
      modelValue: shouldAutoHide ? autoHideDelay : -1, // Negative value disables auto-hide
    });
  };

  return { makeToast };
}
