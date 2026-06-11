<!-- views/review/components/RefuseConfirmModal.vue -->
<!--
  Refuse / decline-confirmation modal for the re-review queue (issue #54).

  A re-reviewer uses this to DECLINE a particularly complex or out-of-scope
  entry, flagging it for specialist / curator attention instead of forcing a
  review. The optional reason is captured here and emitted on `@ok`; the parent
  owns the modal id (`refuse-modal`) and the mutation that fires
  `PUT /api/re_review/refuse/:id`.

  Refusal is a "needs specialist" flag, not a destructive delete, so it uses
  the warning variant and is visually separated from the success/submit action.
-->
<template>
  <BModal
    :id="modalDescriptor.id"
    :ref="modalDescriptor.id"
    centered
    ok-title="Refuse (needs specialist)"
    ok-variant="warning"
    cancel-variant="outline-secondary"
    no-close-on-esc
    no-close-on-backdrop
    header-class="border-bottom-0 pb-0"
    footer-class="border-top-0 pt-0"
    @ok="$emit('ok')"
  >
    <template #title>
      <div class="d-flex align-items-center">
        <i class="bi bi-flag-fill me-2 text-warning" aria-hidden="true" />
        <span class="fw-semibold">Refuse re-review</span>
      </div>
    </template>

    <div class="py-2">
      <div class="text-center mb-3">
        <span
          class="d-inline-flex align-items-center justify-content-center rounded-circle bg-warning-subtle text-warning"
          style="width: 64px; height: 64px; font-size: 1.5rem"
        >
          <i class="bi bi-flag" aria-hidden="true" />
        </span>
      </div>
      <p class="mb-2 text-center">
        Decline the re-review of entity
        <BBadge variant="primary" class="fs-6 ms-1">
          {{ modalDescriptor.title }}
        </BBadge>
      </p>
      <p class="text-muted small text-center mb-3">
        Use this for entries that are too complex or out of scope. The item
        leaves your queue and is flagged for specialist / curator attention. It
        will not change the curated classification.
      </p>

      <BFormGroup
        label="Reason (optional)"
        label-for="refuse-reason-input"
        description="Briefly explain why this entry needs specialist attention."
      >
        <BFormTextarea
          id="refuse-reason-input"
          :model-value="reason"
          placeholder="e.g. Complex inheritance / outside my expertise"
          rows="3"
          max-rows="6"
          maxlength="1000"
          aria-label="Optional reason for refusing this re-review"
          @update:model-value="$emit('update:reason', $event)"
        />
      </BFormGroup>
    </div>
  </BModal>
</template>

<script>
export default {
  name: 'RefuseConfirmModal',
  props: {
    modalDescriptor: {
      type: Object,
      required: true,
      validator: (value) => typeof value?.id === 'string' && typeof value?.title === 'string',
    },
    reason: {
      type: String,
      default: '',
    },
  },
  emits: ['ok', 'update:reason'],
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
