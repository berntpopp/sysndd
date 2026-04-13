<!-- components/review/DismissReviewModal.vue -->
<template>
  <BModal
    :id="modalId"
    ref="modalRef"
    size="md"
    centered
    ok-title="Dismiss"
    ok-variant="danger"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    header-close-label="Close"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-x-circle-fill me-2 text-danger" />
        <span class="fw-semibold">Dismiss Review</span>
      </div>
    </template>

    <div class="text-center py-3">
      <div class="mb-3">
        <i class="bi bi-x-circle text-danger" style="font-size: 2.5rem" />
      </div>
      <p class="mb-2">
        Dismiss this pending review for entity
        <BBadge variant="primary" class="mx-1">
          {{ entityTitle }}
        </BBadge>
        ?
      </p>
      <p class="text-muted small">
        The review will be removed from the pending queue. This does not delete the record.
      </p>
    </div>
  </BModal>
</template>

<script setup lang="ts">
import { ref } from 'vue';

defineProps({
  modalId: { type: String, default: 'dismiss-modal' },
  entityTitle: { type: String, default: '' },
});

defineEmits<{ (e: 'ok'): void }>();

const modalRef = ref<{ show?: () => void; hide?: () => void } | null>(null);
defineExpose({
  show: (): void => modalRef.value?.show?.(),
  hide: (): void => modalRef.value?.hide?.(),
});
</script>
