import { useToast } from 'bootstrap-vue-next';

/**
 * Composable for toast notifications using Bootstrap-Vue-Next
 * @returns {Object} Toast notification methods
 */
export default function useToastNotifications() {
  const { show } = useToast();

  /**
   * Show a toast notification
   * @param {string|object} message - Message to display (or object with message property)
   * @param {string} title - Toast title
   * @param {string} variant - Bootstrap variant (success, danger, warning, info)
   * @param {boolean} autoHide - Whether to auto-dismiss (default: true)
   * @param {number} autoHideDelay - Delay in ms before auto-hide (default: 3000)
   */
  const makeToast = (message, title = null, variant = null, autoHide = true, autoHideDelay = 3000) => {
    const body = typeof message === 'object' && message.message ? message.message : message;

    show({
      props: {
        title,
        body,
        variant,
        pos: 'top-end',
        value: autoHide ? autoHideDelay : 0, // 0 means no auto-hide
      },
    });
  };

  return { makeToast };
}
