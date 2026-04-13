<!-- components/review/ApproveAllModal.vue -->
<template>
  <BModal
    :id="modalId"
    :ref="modalId"
    size="md"
    centered
    ok-title="Approve All"
    ok-variant="danger"
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
        <i class="bi bi-check2-all me-2 text-danger" />
        <span class="fw-semibold">Approve All Reviews</span>
      </div>
    </template>

    <div class="text-center py-3">
      <div class="mb-3">
        <span
          class="d-inline-flex align-items-center justify-content-center rounded-circle bg-danger-subtle text-danger"
          style="width: 64px; height: 64px; font-size: 1.5rem"
        >
          <i class="bi bi-exclamation-triangle" />
        </span>
      </div>
      <p class="mb-2">Are you sure you want to approve <strong>ALL</strong> reviews?</p>
      <p class="text-muted small mb-3">
        This will approve {{ totalRows }} pending reviews at once.
      </p>
    </div>

    <div class="border border-danger rounded-3 p-3 bg-danger-subtle">
      <BFormCheckbox
        id="confirmApproveAllSwitch"
        :model-value="selected"
        switch
        @update:model-value="$emit('update:selected', Boolean($event))"
      >
        <span class="fw-semibold">
          {{ selected ? 'Yes' : 'No' }}, I confirm this action
        </span>
      </BFormCheckbox>
    </div>
  </BModal>
</template>

<script setup lang="ts">
defineProps({
  modalId: { type: String, default: 'approveAllModal' },
  totalRows: { type: Number, default: 0 },
  selected: { type: Boolean, default: false },
});

defineEmits<{
  (e: 'ok'): void;
  (e: 'update:selected', value: boolean): void;
}>();
</script>
