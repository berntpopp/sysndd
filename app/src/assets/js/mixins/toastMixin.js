// assets/js/mixins/toastMixin.js
export default {
  methods: {
    /**
     * Displays a toast notification.
     *
     * @param {string|Object} message - The message to be displayed in the toast.
     *                                  Can be a string or an object with a message property.
     * @param {string|null} [title=null] - The title of the toast. If null, no title is shown.
     * @param {string|null} [variant=null] - The variant of the toast for styling (e.g., 'success', 'danger').
     * @param {string} [toaster='b-toaster-top-right'] - The position of the toast on the screen.
     * @param {boolean} [autoHide=true] - Whether the toast should automatically disappear.
     * @param {number} [autoHideDelay=2000] - Delay in milliseconds before the toast disappears.
     */
    makeToast(message, title = null, variant = null, toaster = 'b-toaster-top-right', autoHide = true, autoHideDelay = 2000) {
      // If message is an object, extract its message property
      const content = typeof message === 'object' && message.message ? message.message : message;

      this.$bvToast.toast(content, {
        title,
        toaster,
        variant,
        solid: true,
        autoHideDelay,
        noAutoHide: !autoHide,
      });
    },
  },
};
