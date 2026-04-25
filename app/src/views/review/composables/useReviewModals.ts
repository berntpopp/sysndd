// app/src/views/review/composables/useReviewModals.ts
//
// W6 of v11.1 finish-hardening — modal-state composable for `Review.vue`.
//
// The four modals (review / status / submit / approve) have stable DOM
// ids, dynamic titles ("sysndd:<entity_id>"), and an `entity[]` queue
// that the submit + approve modals read on confirm. Bootstrap-Vue-Next
// `BModal`s are still shown/hidden via `$refs[id].show()` inside
// `Review.vue` — that DOM concern stays in the view. The composable
// owns everything else (descriptors, target row, approval toggles).

import { reactive, ref, type Ref } from 'vue';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ModalDescriptor {
  id: string;
  title: string;
  content: unknown[];
}

/** Subset of a re-review row the modal callbacks read. Other fields are
 * carried opaquely so callers can pass the raw row through. */
export interface ModalTargetRow {
  entity_id: number;
  re_review_entity_id?: number;
  [key: string]: unknown;
}

export interface UseReviewModals {
  reviewModal: ModalDescriptor;
  statusModal: ModalDescriptor;
  submitModal: ModalDescriptor;
  approveModal: ModalDescriptor;

  /** Single-element queue Approve/Submit confirm handlers read on `@ok`. */
  entity: Ref<ModalTargetRow[]>;

  status_approved: Ref<boolean>;
  review_approved: Ref<boolean>;

  setReviewTarget: (row: ModalTargetRow) => void;
  setStatusTarget: (row: ModalTargetRow) => void;
  openSubmit: (row: ModalTargetRow) => void;
  openApprove: (row: ModalTargetRow) => void;

  resetApproveModal: () => void;
  clearTarget: () => void;
}

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

function makeDescriptor(id: string): ModalDescriptor {
  return { id, title: '', content: [] };
}

export function useReviewModals(): UseReviewModals {
  const reviewModal = reactive(makeDescriptor('review-modal'));
  const statusModal = reactive(makeDescriptor('status-modal'));
  const submitModal = reactive(makeDescriptor('submit-modal'));
  const approveModal = reactive(makeDescriptor('approve-modal'));

  const entity = ref<ModalTargetRow[]>([]);
  const status_approved = ref(false);
  const review_approved = ref(false);

  function setReviewTarget(row: ModalTargetRow): void {
    reviewModal.title = `sysndd:${row.entity_id}`;
  }

  function setStatusTarget(row: ModalTargetRow): void {
    statusModal.title = `sysndd:${row.entity_id}`;
  }

  function openSubmit(row: ModalTargetRow): void {
    submitModal.title = `sysndd:${row.entity_id}`;
    entity.value = [row];
  }

  function openApprove(row: ModalTargetRow): void {
    approveModal.title = `sysndd:${row.entity_id}`;
    entity.value = [row];
  }

  function resetApproveModal(): void {
    status_approved.value = false;
    review_approved.value = false;
  }

  function clearTarget(): void {
    entity.value = [];
  }

  return {
    reviewModal,
    statusModal,
    submitModal,
    approveModal,
    entity,
    status_approved,
    review_approved,
    setReviewTarget,
    setStatusTarget,
    openSubmit,
    openApprove,
    resetApproveModal,
    clearTarget,
  };
}

export default useReviewModals;
