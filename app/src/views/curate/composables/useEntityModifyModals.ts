// app/src/views/curate/composables/useEntityModifyModals.ts
import { ref } from 'vue';

export type ModalKind = 'rename' | 'deactivate' | 'review' | 'status';

export function useEntityModifyModals() {
  const isRenameOpen = ref(false);
  const isDeactivateOpen = ref(false);
  const isReviewOpen = ref(false);
  const isStatusOpen = ref(false);

  const loadingRename = ref(true);
  const loadingDeactivate = ref(true);
  const loadingReview = ref(true);
  const loadingStatus = ref(true);

  const pendingDiscardTarget = ref<ModalKind | null>(null);

  function closeAll(): void {
    isRenameOpen.value = false;
    isDeactivateOpen.value = false;
    isReviewOpen.value = false;
    isStatusOpen.value = false;
  }

  function openRename(): void {
    closeAll();
    isRenameOpen.value = true;
  }

  function openDeactivate(): void {
    closeAll();
    isDeactivateOpen.value = true;
  }

  function openReview(): void {
    closeAll();
    isReviewOpen.value = true;
  }

  function openStatus(): void {
    closeAll();
    isStatusOpen.value = true;
  }

  function close(): void {
    closeAll();
    pendingDiscardTarget.value = null;
  }

  function setLoading(kind: ModalKind, value: boolean): void {
    switch (kind) {
      case 'rename':
        loadingRename.value = value;
        break;
      case 'deactivate':
        loadingDeactivate.value = value;
        break;
      case 'review':
        loadingReview.value = value;
        break;
      case 'status':
        loadingStatus.value = value;
        break;
    }
  }

  function requestDiscard(target: ModalKind): void {
    pendingDiscardTarget.value = target;
  }

  function confirmDiscard(): void {
    const t = pendingDiscardTarget.value;
    pendingDiscardTarget.value = null;
    if (!t) return;
    switch (t) {
      case 'rename':
        isRenameOpen.value = false;
        break;
      case 'deactivate':
        isDeactivateOpen.value = false;
        break;
      case 'review':
        isReviewOpen.value = false;
        break;
      case 'status':
        isStatusOpen.value = false;
        break;
    }
  }

  function cancelDiscard(): void {
    pendingDiscardTarget.value = null;
  }

  return {
    isRenameOpen,
    isDeactivateOpen,
    isReviewOpen,
    isStatusOpen,
    loadingRename,
    loadingDeactivate,
    loadingReview,
    loadingStatus,
    pendingDiscardTarget,
    openRename,
    openDeactivate,
    openReview,
    openStatus,
    close,
    setLoading,
    requestDiscard,
    confirmDiscard,
    cancelDiscard,
  };
}
