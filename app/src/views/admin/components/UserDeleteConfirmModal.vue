<!-- app/src/views/admin/components/UserDeleteConfirmModal.vue -->
<!-- Single-user delete confirmation modal lifted from ManageUser.vue. -->
<template>
  <BModal
    id="delete-usermodal"
    v-model="proxyVisible"
    header-bg-variant="danger"
    header-text-variant="light"
    ok-title="Delete User"
    ok-variant="danger"
    cancel-title="Cancel"
    cancel-variant="outline-secondary"
    @ok.prevent="$emit('confirm')"
    @cancel="$emit('cancel')"
  >
    <template #title>
      <i class="bi bi-exclamation-triangle-fill me-2" />
      Confirm Deletion
    </template>
    <div class="text-center py-3">
      <i class="bi bi-person-x-fill text-danger" style="font-size: 3rem" />
      <p class="mt-3 mb-0">
        Are you sure you want to delete the user
        <strong class="text-danger">{{ user?.user_name }}</strong
        >?
      </p>
      <p class="text-muted small mt-2">This action cannot be undone.</p>
    </div>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';

export default defineComponent({
  name: 'UserDeleteConfirmModal',
  props: {
    visible: { type: Boolean, default: false },
    user: {
      type: Object as PropType<{ user_id: number; user_name: string } | null>,
      default: null,
    },
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
