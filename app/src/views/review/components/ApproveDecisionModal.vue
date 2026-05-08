<!-- views/review/components/ApproveDecisionModal.vue -->
<!--
  Approve-decision modal extracted from `Review.vue` during W6 of v11.1
  finish-hardening. Two switches drive the `review_approved` and
  `status_approved` toggles, plus a "Danger zone" Unsubmit button that
  rewinds the entity back to the reviewer.

  Pure presentational shell — the parent owns the modal's `$ref` lookup,
  the `@ok` handler that fires the approve mutation, and the unsubmit
  handler. Modal show/hide stays parent-side.
-->
<template>
  <BModal
    :id="modalDescriptor.id"
    :ref="modalDescriptor.id"
    centered
    ok-title="Approve"
    ok-variant="success"
    cancel-variant="outline-secondary"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-check-circle-fill me-2 text-success" />
        <span class="fw-semibold">Approve Entity</span>
      </div>
    </template>

    <!-- Entity context -->
    <div class="bg-light rounded-3 p-3 mb-4">
      <div class="d-flex align-items-center gap-2">
        <span class="text-muted small">Entity:</span>
        <BBadge variant="primary">
          {{ modalDescriptor.title }}
        </BBadge>
      </div>
    </div>

    <!-- Approval options -->
    <h6 class="text-muted border-bottom pb-2 mb-3">
      <i class="bi bi-check2-square me-2" />
      Select Items to Approve
    </h6>

    <div class="d-flex flex-column gap-2 mb-4">
      <BFormCheckbox
        id="approveReviewSwitch"
        :model-value="reviewApproved"
        switch
        @update:model-value="$emit('update:reviewApproved', $event)"
      >
        <span class="fw-semibold">Review</span>
        <span class="text-muted small d-block">Approve the clinical synopsis and annotations</span>
      </BFormCheckbox>

      <BFormCheckbox
        id="approveStatusSwitch"
        :model-value="statusApproved"
        switch
        @update:model-value="$emit('update:statusApproved', $event)"
      >
        <span class="fw-semibold">Status</span>
        <span class="text-muted small d-block">Approve the entity classification status</span>
      </BFormCheckbox>
    </div>

    <!-- Danger zone -->
    <div class="border border-warning rounded-3 p-3 bg-warning-subtle">
      <h6 class="text-warning mb-2">
        <i class="bi bi-exclamation-triangle me-1" />
        Other Actions
      </h6>
      <BButton size="sm" variant="outline-warning" @click="$emit('unsubmit')">
        <i class="bi bi-unlock me-1" />
        Unsubmit Review
      </BButton>
      <p class="text-muted small mb-0 mt-2">
        Return this entity to the reviewer for further changes
      </p>
    </div>
  </BModal>
</template>

<script>
export default {
  name: 'ApproveDecisionModal',
  props: {
    modalDescriptor: {
      type: Object,
      required: true,
      validator: (value) => typeof value?.id === 'string' && typeof value?.title === 'string',
    },
    reviewApproved: { type: Boolean, default: false },
    statusApproved: { type: Boolean, default: false },
  },
  emits: ['ok', 'unsubmit', 'update:reviewApproved', 'update:statusApproved'],
  methods: {
    show() {
      this.$refs[this.modalDescriptor.id]?.show();
    },
    hide() {
      this.$refs[this.modalDescriptor.id]?.hide();
    },
  },
};
</script>
