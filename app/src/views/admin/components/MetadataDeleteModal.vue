<!-- app/src/views/admin/components/MetadataDeleteModal.vue -->
<!--
  Soft-delete confirmation for a curation metadata vocabulary entry (issue #32).
  Deactivation (is_active = 0), not a hard delete: the API blocks deletion of an
  in-use value with a 400 the parent surfaces as a toast.
-->
<template>
  <BModal
    id="metadata-delete-modal"
    v-model="proxyVisible"
    header-bg-variant="warning"
    header-text-variant="dark"
    ok-title="Deactivate"
    ok-variant="warning"
    :ok-disabled="deleting"
    cancel-title="Cancel"
    cancel-variant="outline-secondary"
    @ok.prevent="$emit('confirm')"
    @cancel="$emit('cancel')"
  >
    <template #title>
      <i class="bi bi-exclamation-triangle-fill me-2" />
      Confirm deactivation
    </template>
    <div class="text-center py-3">
      <i class="bi bi-archive text-warning" style="font-size: 2.5rem" />
      <p class="mt-3 mb-0">
        Deactivate
        <strong>{{ label }}</strong>?
      </p>
      <p class="text-muted small mt-2">
        In-use values cannot be removed and will be blocked. Deactivated entries are hidden from
        curation forms but kept for history.
      </p>
    </div>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent } from 'vue';

export default defineComponent({
  name: 'MetadataDeleteModal',
  props: {
    visible: { type: Boolean, default: false },
    label: { type: String, default: '' },
    deleting: { type: Boolean, default: false },
  },
  emits: ['update:visible', 'confirm', 'cancel'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });
    return { proxyVisible };
  },
});
</script>
