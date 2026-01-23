import { useModal } from 'bootstrap-vue-next';

/**
 * Composable for modal controls using Bootstrap-Vue-Next
 * @returns {Object} Modal control methods
 */
export default function useModalControls() {
  const modal = useModal();

  /**
   * Show a modal by ID
   * @param {string} id - Modal ID to show
   */
  const showModal = (id) => {
    modal.show(id);
  };

  /**
   * Hide a modal by ID
   * @param {string} id - Modal ID to hide
   */
  const hideModal = (id) => {
    modal.hide(id);
  };

  /**
   * Create a confirmation modal
   * @param {object} options - Modal options
   * @returns {Promise} - Resolves with user's choice
   */
  const confirm = async (options) => modal.confirm(options);

  return { showModal, hideModal, confirm };
}
