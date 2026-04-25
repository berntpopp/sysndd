<!-- views/review/components/SubmitConfirmModal.vue -->
<!--
  Submit-confirmation modal extracted from `Review.vue` during W6 of v11.1
  finish-hardening. Pure presentational shell — the parent owns the
  modal id (`submit-modal`) and the `@ok` handler that fires the
  re-review submit mutation.

  No business logic lives here: the BModal `$ref` lookup that the parent
  calls `.show()` on is keyed off the prop'd `id`, so the parent can keep
  using `this.$refs[this.submitModal.id].show()` exactly as before.
-->
<template>
  <BModal
    :id="modalDescriptor.id"
    :ref="modalDescriptor.id"
    size="md"
    centered
    ok-title="Submit Review"
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
        <i class="bi bi-send-check me-2 text-success" />
        <span class="fw-semibold">Submit Review</span>
      </div>
    </template>

    <div class="text-center py-3">
      <div class="mb-3">
        <span
          class="d-inline-flex align-items-center justify-content-center rounded-circle bg-success-subtle text-success"
          style="width: 64px; height: 64px; font-size: 1.5rem"
        >
          <i class="bi bi-check2-circle" />
        </span>
      </div>
      <p class="mb-2">You have finished the re-review of entity</p>
      <p class="mb-3">
        <BBadge variant="primary" class="fs-6">
          {{ modalDescriptor.title }}
        </BBadge>
      </p>
      <p class="text-muted small mb-0">Ready to submit for curator approval?</p>
    </div>
  </BModal>
</template>

<script>
export default {
  name: 'SubmitConfirmModal',
  props: {
    modalDescriptor: {
      type: Object,
      required: true,
      validator: (value) =>
        typeof value?.id === 'string' && typeof value?.title === 'string',
    },
  },
  emits: ['ok'],
  methods: {
    show() {
      // Forward to the inner BModal so the parent can call
      // `<modalComponent>.show()` exactly the way the legacy view did.
      this.$refs[this.modalDescriptor.id]?.show();
    },
    hide() {
      this.$refs[this.modalDescriptor.id]?.hide();
    },
  },
};
</script>
