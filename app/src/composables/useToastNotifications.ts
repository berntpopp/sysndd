import type { ToastNotifications } from '@/types/components';
import useToast from './useToast';

/**
 * Composable for toast notifications using Bootstrap-Vue-Next
 * Must be called within setup() context
 * @returns {ToastNotifications} Toast notification methods
 */
export default function useToastNotifications(): ToastNotifications {
  return useToast();
}
