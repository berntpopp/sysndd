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
    message: unknown,
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
    message: unknown,
    title: string | null = null,
    variant: ToastVariant | null = null,
    autoHide: boolean = true,
    autoHideDelay: number = 3000
  ): void => {
    // Extract meaningful message from various error shapes (Axios errors, Error objects, strings)
    let body: string;
    if (typeof message === 'string') {
      body = message;
    } else if (typeof message === 'object' && message !== null) {
      const msg = message as Record<string, unknown>;
      const resp = msg.response as Record<string, unknown> | undefined;
      const respData = resp?.data as Record<string, unknown> | undefined;
      body =
        (respData?.message as string) ||
        (respData?.error as string) ||
        (msg.message as string) ||
        String(message);
    } else {
      body = String(message);
    }

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
