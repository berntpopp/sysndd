// assets/js/mixins/toastMixin.js

/**
 * @fileoverview Mixin for handling toast notifications in the Vue application.
 *
 * This mixin provides a method to display toast notifications. It is designed to be used across
 * different components for consistent toast behavior. The method allows customization of the message,
 * title, style variant, and auto-hide behavior of the toast.
 *
 * Updated for Bootstrap-Vue-Next: Now delegates to useToastNotifications composable.
 */

import useToastNotifications from '@/composables/useToastNotifications';

export default {
  methods: {
    /**
     * Displays a toast notification.
     *
     * @param {string|Object} message - The message to be displayed in the toast.
     *                                  Can be a string or an object with a message property.
     * @param {string|null} [title=null] - The title of the toast. If null, no title is shown.
     * @param {string|null} [variant=null] - The variant of the toast for styling (e.g., 'success', 'danger').
     * @param {boolean} [autoHide=true] - Whether the toast should automatically disappear.
     * @param {number} [autoHideDelay=3000] - Delay in milliseconds before the toast disappears.
     */
    makeToast(message, title = null, variant = null, autoHide = true, autoHideDelay = 3000) {
      const { makeToast: showToast } = useToastNotifications();

      // For error toasts (danger variant), disable auto-hide per CONTEXT.md requirements
      // This ensures users don't miss important error messages in a medical application
      const shouldAutoHide = variant === 'danger' ? false : autoHide;

      showToast(message, title, variant, shouldAutoHide, autoHideDelay);
    },
  },
};
