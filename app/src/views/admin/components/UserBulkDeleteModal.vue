<!-- app/src/views/admin/components/UserBulkDeleteModal.vue -->
<!-- Bulk-delete confirmation modal with type-to-confirm, lifted from ManageUser.vue. -->
<template>
  <BModal
    v-model="proxyVisible"
    title="Delete Users"
    ok-variant="danger"
    ok-title="Delete"
    cancel-title="Cancel"
    :ok-disabled="confirmText !== 'DELETE'"
    @ok.prevent="$emit('confirm')"
    @cancel="$emit('cancel')"
  >
    <p class="text-danger fw-bold">This action cannot be undone.</p>
    <p>You are about to delete {{ usernames.length }} user(s):</p>
    <div class="border rounded p-2 mb-3 bg-light" style="max-height: 200px; overflow-y: auto">
      <div v-for="username in usernames" :key="username" class="small">
        {{ username }}
      </div>
    </div>
    <BFormGroup label="Type DELETE to confirm:" label-for="delete-confirm-input">
      <BFormInput
        id="delete-confirm-input"
        :value="confirmText"
        placeholder="DELETE"
        autocomplete="off"
        @input="emitConfirmInput($event)"
      />
    </BFormGroup>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';

export default defineComponent({
  name: 'UserBulkDeleteModal',
  props: {
    visible: { type: Boolean, default: false },
    usernames: { type: Array as PropType<string[]>, default: () => [] },
    confirmText: { type: String, default: '' },
  },
  emits: ['update:visible', 'update:confirm-text', 'confirm', 'cancel'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });
    function emitConfirmInput(event: Event): void {
      const t = event.target as HTMLInputElement;
      emit('update:confirm-text', t.value);
    }
    return { proxyVisible, emitConfirmInput };
  },
});
</script>
