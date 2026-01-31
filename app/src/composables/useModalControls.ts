import { useModal } from 'bootstrap-vue-next';
import type { ModalControls } from '@/types/components';

/**
 * Composable for modal controls using Bootstrap-Vue-Next
 * @returns {ModalControls} Modal control methods
 */
export default function useModalControls(): ModalControls {
  const modal = useModal();

  /**
   * Show a modal by ID
   * @param {string} id - Modal ID to show
   */
  const showModal = (id: string): void => {
    modal.show(id);
  };

  /**
   * Hide a modal by ID
   * @param {string} id - Modal ID to hide
   * @param {string} trigger - The trigger reason for hiding (default: 'close')
   */
  const hideModal = (id: string, trigger: string = 'close'): void => {
    modal.hide(trigger, id);
  };

  /**
   * Create a confirmation modal
   * @param {object} options - Modal options
   * @returns {Promise} - Resolves with user's choice
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const confirm = async (options: unknown): Promise<boolean> => (modal as any).confirm(options);

  return { showModal, hideModal, confirm };
}
