import { useModal } from 'bootstrap-vue-next'

export function useModalControls() {
  const modal = useModal()

  /**
   * Show a modal by ID
   * @param {string} id - Modal ID to show
   */
  const showModal = (id) => {
    modal.show(id)
  }

  /**
   * Hide a modal by ID
   * @param {string} id - Modal ID to hide
   */
  const hideModal = (id) => {
    modal.hide(id)
  }

  /**
   * Create a confirmation modal
   * @param {object} options - Modal options
   * @returns {Promise} - Resolves with user's choice
   */
  const confirm = async (options) => {
    return modal.confirm(options)
  }

  return { showModal, hideModal, confirm }
}
