<!-- components/small/LogDeleteModal.vue -->
<template>
  <BModal
    :model-value="modelValue"
    title="Delete Logs"
    header-bg-variant="danger"
    header-text-variant="light"
    centered
    @update:model-value="$emit('update:modelValue', $event)"
    @hidden="onHidden"
  >
    <div class="text-center mb-3">
      <i class="bi bi-exclamation-triangle-fill text-danger fs-1" />
    </div>

    <!-- Delete mode selection -->
    <div class="mb-3">
      <label class="form-label fw-semibold">What to delete:</label>
      <BFormSelect
        :model-value="deleteMode"
        class="mb-2"
        @update:model-value="$emit('update:deleteMode', $event)"
      >
        <option value="all">All logs ({{ totalRows.toLocaleString() }} entries)</option>
        <option value="3">Logs older than 3 days</option>
        <option value="7">Logs older than 7 days</option>
        <option value="14">Logs older than 14 days</option>
        <option value="30">Logs older than 30 days</option>
      </BFormSelect>
    </div>

    <p class="text-center">
      <strong>Warning:</strong>
      <span v-if="deleteMode === 'all'">
        This will permanently delete all {{ totalRows.toLocaleString() }} log entries.
      </span>
      <span v-else> This will permanently delete logs older than {{ deleteMode }} days. </span>
    </p>
    <p class="text-center text-muted small">
      This action cannot be undone. Type <code>DELETE</code> to confirm.
    </p>
    <BFormInput
      v-model="deleteConfirmText"
      placeholder="Type DELETE to confirm"
      class="text-center"
      :state="deleteConfirmText === 'DELETE' ? true : deleteConfirmText ? false : null"
    />
    <template #footer>
      <BButton variant="secondary" @click="$emit('update:modelValue', false)"> Cancel </BButton>
      <BButton
        variant="danger"
        :disabled="deleteConfirmText !== 'DELETE' || isDeleting"
        @click="$emit('confirm')"
      >
        <BSpinner v-if="isDeleting" small class="me-1" />
        {{
          isDeleting ? 'Deleting...' : deleteMode === 'all' ? 'Delete All Logs' : `Delete Old Logs`
        }}
      </BButton>
    </template>
  </BModal>
</template>

<script>
export default {
  name: 'LogDeleteModal',
  props: {
    modelValue: { type: Boolean, default: false },
    deleteMode: { type: String, default: 'all' },
    totalRows: { type: Number, default: 0 },
    isDeleting: { type: Boolean, default: false },
  },
  emits: ['update:modelValue', 'update:deleteMode', 'confirm'],
  data() {
    return { deleteConfirmText: '' };
  },
  methods: {
    // Only effective when the parent keeps this component mounted: under
    // v-if the modal unmounts before @hidden fires, so the parent must
    // reset deleteMode explicitly (TablesLogs does, after a delete).
    onHidden() {
      this.deleteConfirmText = '';
      this.$emit('update:deleteMode', 'all');
    },
  },
};
</script>
