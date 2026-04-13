<!-- components/review/ApproveReviewModal.vue -->
<template>
  <BModal
    :id="modalId"
    ref="modalRef"
    size="md"
    centered
    ok-title="Approve"
    ok-variant="success"
    cancel-variant="outline-secondary"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    header-close-label="Close"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-check-circle-fill me-2 text-success" />
        <span class="fw-semibold">Approve Review</span>
      </div>
    </template>

    <div class="bg-light rounded-3 p-3 mb-4">
      <div class="d-flex align-items-center gap-2">
        <span class="text-muted small">Entity:</span>
        <BBadge variant="primary">
          {{ entityTitle }}
        </BBadge>
      </div>
    </div>

    <div class="text-center py-2">
      <p class="mb-3">
        You have finished checking this review and are ready to <strong>approve</strong> it?
      </p>

      <div
        v-if="isDuplicate"
        class="alert alert-info small text-start mt-2 mb-3"
      >
        <i class="bi bi-info-circle me-1" />
        Other pending reviews for this entity will be automatically dismissed.
      </div>
    </div>

    <div v-if="hasStatusChange">
      <h6 class="text-muted border-bottom pb-2 mb-3">
        <i class="bi bi-stoplights me-2" />
        Status Change Detected
      </h6>

      <BFormCheckbox
        id="approveStatusSwitch"
        :model-value="statusApproved"
        switch
        @update:model-value="$emit('update:statusApproved', Boolean($event))"
      >
        <span class="fw-semibold">Also approve new status</span>
        <span class="text-muted small d-block">
          A status change was submitted with this review
        </span>
      </BFormCheckbox>
    </div>
  </BModal>
</template>

<script setup lang="ts">
import { ref } from 'vue';

defineProps({
  modalId: { type: String, default: 'approve-modal' },
  entityTitle: { type: String, default: '' },
  isDuplicate: { type: Boolean, default: false },
  hasStatusChange: { type: Boolean, default: false },
  statusApproved: { type: Boolean, default: false },
});

defineEmits<{
  (e: 'ok'): void;
  (e: 'update:statusApproved', value: boolean): void;
}>();

const modalRef = ref<{ show?: () => void; hide?: () => void } | null>(null);
defineExpose({
  show: (): void => modalRef.value?.show?.(),
  hide: (): void => modalRef.value?.hide?.(),
});
</script>
